library(readr)
library(dplyr)
library(cointReg)
library(urca)
library(lmtest)
library(sandwich)

root <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma"
master <- file.path(root, "400-Data/440-Custom-Datasets/gold_research_master.csv")
out_md <- file.path(root, "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/fmols_summary.md")
out_csv <- file.path(root, "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/fmols_predictions.csv")

df <- read_csv(master, show_col_types = FALSE) %>%
  mutate(DATE = as.Date(DATE)) %>%
  arrange(DATE) %>%
  mutate(across(-DATE, log)) %>%
  filter(if_all(-DATE, ~ is.finite(.x)))

train <- df %>% filter(DATE <= as.Date("2020-12-31"))
test <- df %>% filter(DATE >= as.Date("2021-01-01"))

xvars <- c("DXY", "USDJPY", "USDCHF", "SP500", "OIL", "VIX")
x_train <- as.matrix(train %>% select(all_of(xvars)))
y_train <- train$GOLD
deter <- matrix(1, nrow = nrow(x_train), ncol = 1)
fmols_fit <- cointReg::cointRegFM(x = x_train, y = y_train, deter = deter)

coef_vec <- coef(fmols_fit)
testX <- as.matrix(test %>% select(all_of(xvars)))
test_deter <- matrix(1, nrow = nrow(testX), ncol = 1)
pred <- as.numeric(fmols_fit$delta + testX %*% fmols_fit$beta)

y_true <- test$GOLD
rmse <- sqrt(mean((y_true - pred)^2, na.rm = TRUE))
mae <- mean(abs(y_true - pred), na.rm = TRUE)

write_csv(tibble(DATE = test$DATE, pred = pred, actual = y_true), out_csv)

writeLines(c(
  "# FMOLS Summary",
  "",
  paste0("- Train window: ", min(train$DATE), " -> ", max(train$DATE)),
  paste0("- Test window: ", min(test$DATE), " -> ", max(test$DATE)),
  paste0("- RMSE: ", signif(rmse, 6)),
  paste0("- MAE: ", signif(mae, 6)),
  "",
  "## Note",
  "- FMOLS is used here as a long-run cointegration benchmark."
), out_md)

cat("FMOLS RMSE:", rmse, "\n")
cat("FMOLS MAE:", mae, "\n")
