# run_shap.R
# SHAP (SHapley Additive exPlanations) for ANN Models 1, 3, 4
# Reference: Lundberg & Lee (2017); Xi, Boateng & Agyei (2025 Q1 Sustainable Development)
# Package: fastshap (Greenwell 2021) — model-agnostic, permutation-based

suppressPackageStartupMessages({
  library(fastshap)
  library(neuralnet)
  library(ggplot2)
  library(dplyr)
})

DATA_PATH <- "../../../../400-Data/2026-Gulistan-Collaboration/data/ssa_tarim_29_ulke_v7_climate.csv"
df <- read.csv(DATA_PATH)
df$year <- as.integer(df$year)
set.seed(42)

# -----------------------------------------------------------------------
# Helper: normalize
# -----------------------------------------------------------------------
norm_fn <- function(x, mn, mx) (x - mn) / (mx - mn)

# -----------------------------------------------------------------------
# [1] TRAIN MODELS (replicate QMD setup)
# -----------------------------------------------------------------------
index <- sample(1:nrow(df), round(0.8 * nrow(df)))
train_raw <- df[index, ]; test_raw <- df[-index, ]

# Model 1 (4 vars)
vars_m1 <- c("Agri_GDP","Labor","Land","Fertilizer","Exports")
mn1 <- sapply(train_raw[,vars_m1], min, na.rm=TRUE)
mx1 <- sapply(train_raw[,vars_m1], max, na.rm=TRUE)
tr1 <- train_raw; te1 <- test_raw
for (v in vars_m1) { tr1[[v]] <- norm_fn(train_raw[[v]], mn1[v], mx1[v])
                     te1[[v]] <- norm_fn(test_raw[[v]],  mn1[v], mx1[v]) }
set.seed(42)
nn1 <- neuralnet(Agri_GDP ~ Labor + Land + Fertilizer + Exports, data=tr1,
                 hidden=c(6,3), threshold=0.01, stepmax=1e6)

# Model 3 (7 vars)
vars_m3 <- c("Agri_GDP","Labor","Land","Fertilizer","Exports","Technology","Resource_Rent","Electricity")
mn3 <- sapply(train_raw[,vars_m3], min, na.rm=TRUE)
mx3 <- sapply(train_raw[,vars_m3], max, na.rm=TRUE)
tr3 <- train_raw; te3 <- test_raw
for (v in vars_m3) { tr3[[v]] <- norm_fn(train_raw[[v]], mn3[v], mx3[v])
                     te3[[v]] <- norm_fn(test_raw[[v]],  mn3[v], mx3[v]) }
set.seed(42)
nn3 <- neuralnet(Agri_GDP ~ Labor + Land + Fertilizer + Exports + Technology +
                   Resource_Rent + Electricity, data=tr3,
                 hidden=c(6,3), threshold=0.01, stepmax=1e6)

# Model 4 (16 vars)
vars_m4 <- c("Agri_GDP","Labor","Land","Fertilizer","Exports","Technology",
             "Resource_Rent","Electricity","gdp_pc","urban","trade_open",
             "fdi","renewable","adj_savings","wgi_composite","enso_index",
             "d_ecowas","d_sadc","d_eac","d_cemac")
df_m4 <- df[complete.cases(df[,vars_m4]), ]
set.seed(42); idx4 <- sample(1:nrow(df_m4), round(0.8*nrow(df_m4)))
tr4r <- df_m4[idx4,]; te4r <- df_m4[-idx4,]
mn4 <- sapply(tr4r[,vars_m4], min, na.rm=TRUE)
mx4 <- sapply(tr4r[,vars_m4], max, na.rm=TRUE)
tr4 <- tr4r; te4 <- te4r
for (v in vars_m4) { tr4[[v]] <- norm_fn(tr4r[[v]], mn4[v], mx4[v])
                     te4[[v]] <- norm_fn(te4r[[v]], mn4[v], mx4[v]) }
set.seed(42)
nn4 <- neuralnet(
  Agri_GDP ~ Labor + Land + Fertilizer + Exports + Technology +
    Resource_Rent + Electricity + gdp_pc + urban + trade_open +
    fdi + renewable + adj_savings + wgi_composite + enso_index +
    d_ecowas + d_sadc + d_eac + d_cemac,
  data=tr4, hidden=c(10,5), threshold=0.01, stepmax=2e6)

cat("Models trained.\n\n")

# -----------------------------------------------------------------------
# [2] SHAP — fastshap permutation approach
# -----------------------------------------------------------------------
shap_for_nn <- function(nn_model, X_data, x_vars, nsim=100, seed=42) {
  pred_fn <- function(model, newdata) {
    as.vector(predict(model, newdata))
  }
  set.seed(seed)
  shap_vals <- fastshap::explain(
    object       = nn_model,
    feature_names = x_vars,
    X            = X_data[, x_vars, drop=FALSE],
    pred_wrapper = pred_fn,
    nsim         = nsim
  )
  shap_vals
}

cat(rep("=",72), "\n", sep="")
cat("SHAP VALUE ANALYSIS — ANN Models 1, 3, 4\n")
cat("Method: fastshap permutation (Greenwell 2021); nsim=100\n")
cat(rep("=",72), "\n\n", sep="")

# -----------------------------------------------------------------------
# Model 1 SHAP
# -----------------------------------------------------------------------
x1 <- c("Labor","Land","Fertilizer","Exports")
cat("[1] Model 1 (4 variables) SHAP:\n")
cat(rep("-",50), "\n", sep="")
shap1 <- tryCatch(shap_for_nn(nn1, te1, x1), error=function(e){ cat("ERROR:",conditionMessage(e),"\n"); NULL })
if (!is.null(shap1)) {
  mean_abs <- sort(colMeans(abs(shap1)), decreasing=TRUE)
  cat("Mean |SHAP| (global importance):\n")
  for (v in names(mean_abs)) cat(sprintf("  %-20s  %8.5f\n", v, mean_abs[v]))
  cat("\nOlden vs SHAP directional comparison:\n")
  shap_sign <- sign(colMeans(shap1))
  for (v in x1) cat(sprintf("  %-20s  SHAP direction: %+d  (mean SHAP = %+.5f)\n",
                             v, shap_sign[v], colMeans(shap1)[v]))
}

# -----------------------------------------------------------------------
# Model 3 SHAP
# -----------------------------------------------------------------------
x3 <- c("Labor","Land","Fertilizer","Exports","Technology","Resource_Rent","Electricity")
cat("\n[3] Model 3 (7 variables) SHAP:\n")
cat(rep("-",50), "\n", sep="")
shap3 <- tryCatch(shap_for_nn(nn3, te3, x3), error=function(e){ cat("ERROR:",conditionMessage(e),"\n"); NULL })
if (!is.null(shap3)) {
  mean_abs3 <- sort(colMeans(abs(shap3)), decreasing=TRUE)
  cat("Mean |SHAP| — ranked global importance:\n")
  for (v in names(mean_abs3)) {
    dir <- sign(colMeans(shap3)[v])
    cat(sprintf("  %-22s  |SHAP|=%8.5f  dir=%+d\n", v, mean_abs3[v], dir))
  }
}

# -----------------------------------------------------------------------
# Model 4 SHAP
# -----------------------------------------------------------------------
x4 <- vars_m4[-1]   # all except Agri_GDP
cat("\n[4] Model 4 (19 variables) SHAP:\n")
cat(rep("-",50), "\n", sep="")
shap4 <- tryCatch(shap_for_nn(nn4, te4, x4), error=function(e){ cat("ERROR:",conditionMessage(e),"\n"); NULL })
if (!is.null(shap4)) {
  mean_abs4 <- sort(colMeans(abs(shap4)), decreasing=TRUE)
  cat("Mean |SHAP| — top 10 global drivers:\n")
  for (v in names(mean_abs4)[1:min(10,length(mean_abs4))]) {
    dir <- sign(colMeans(shap4)[v])
    cat(sprintf("  %-25s  |SHAP|=%8.5f  dir=%+d\n", v, mean_abs4[v], dir))
  }
}

# -----------------------------------------------------------------------
# [3] COMPARISON: Olden vs SHAP (Model 3)
# -----------------------------------------------------------------------
if (!is.null(shap3)) {
  cat("\n[COMPARISON] Olden Algorithm vs SHAP — Model 3:\n")
  cat(rep("-",55), "\n", sep="")
  library(NeuralNetTools)
  olden3 <- tryCatch(NeuralNetTools::olden(nn3, bar_plot=FALSE), error=function(e) NULL)
  if (!is.null(olden3)) {
    cat(sprintf("%-22s  %10s  %10s  %10s\n","Variable","Olden","SHAP|mean|","Agreement"))
    cat(rep("-",55), "\n", sep="")
    shap_mean <- colMeans(shap3)
    for (v in x3) {
      old_v  <- if (v %in% rownames(olden3)) olden3[v,"importance"] else NA
      shap_v <- if (v %in% names(shap_mean)) shap_mean[v] else NA
      agree  <- if (!is.na(old_v) && !is.na(shap_v)) {
        if (sign(old_v)==sign(shap_v)) "✓ Same direction" else "✗ Opposite direction"
      } else NA
      cat(sprintf("%-22s  %10.4f  %10.5f  %s\n", v, old_v, shap_v, agree))
    }
  }
}

# -----------------------------------------------------------------------
# [4] SAVE PLOTS
# -----------------------------------------------------------------------
OUT_DIR <- "../03-Results"
if (!dir.exists(OUT_DIR)) dir.create(OUT_DIR, recursive=TRUE)

if (!is.null(shap3)) {
  df_shap3 <- data.frame(
    Variable  = names(mean_abs3),
    Importance = as.numeric(mean_abs3),
    Direction  = sign(colMeans(shap3)[names(mean_abs3)])
  )
  df_shap3$Variable <- factor(df_shap3$Variable, levels=rev(df_shap3$Variable))

  p3 <- ggplot(df_shap3, aes(x=Variable, y=Importance, fill=factor(Direction))) +
    geom_col(width=0.65) +
    coord_flip() +
    scale_fill_manual(values=c("-1"="#d73027","1"="#4575b4"),
                      labels=c("Negative","Positive"), name="Effect Direction") +
    labs(title="Figure SHAP-3: SHAP Global Variable Importance — Model 3",
         subtitle="Mean |SHAP| values (permutation, nsim=100)",
         x=NULL, y="Mean |SHAP| value") +
    theme_minimal(base_size=12) +
    theme(plot.title=element_text(face="bold"), legend.position="bottom")

  ggsave(file.path(OUT_DIR,"shap_model3.png"), p3, width=8, height=5, dpi=150)
  cat("\nSaved: 03-Results/shap_model3.png\n")
}

if (!is.null(shap4)) {
  top10 <- names(mean_abs4)[1:min(10,length(mean_abs4))]
  df_shap4 <- data.frame(
    Variable  = top10,
    Importance = as.numeric(mean_abs4[top10]),
    Direction  = sign(colMeans(shap4)[top10])
  )
  df_shap4$Variable <- factor(df_shap4$Variable, levels=rev(df_shap4$Variable))

  p4 <- ggplot(df_shap4, aes(x=Variable, y=Importance, fill=factor(Direction))) +
    geom_col(width=0.65) +
    coord_flip() +
    scale_fill_manual(values=c("-1"="#d73027","1"="#4575b4"),
                      labels=c("Negative","Positive"), name="Effect Direction") +
    labs(title="Figure SHAP-4: SHAP Global Importance — Model 4 (Top 10)",
         subtitle="Mean |SHAP| values (permutation, nsim=100)",
         x=NULL, y="Mean |SHAP| value") +
    theme_minimal(base_size=12) +
    theme(plot.title=element_text(face="bold"), legend.position="bottom")

  ggsave(file.path(OUT_DIR,"shap_model4.png"), p4, width=8, height=5, dpi=150)
  cat("Saved: 03-Results/shap_model4.png\n")
}

cat("\n", rep("=",72), "\n", sep="")
cat("SHAP ANALYSIS COMPLETE\n")
cat(rep("=",72), "\n", sep="")
