## ============================================================
## Script 03 — M3: Makro Panel + M4: Dumitrescu-Hurlin
## Author : Dr. M. Gökhan Özdemir | 2026-04-08
## Input  : 400-Data/processed/macro_CBI_panel_full.csv
## Output : 600-Results/CE_pilot_v3/{cd, cips, westerlund,
##           mg, pmg, fe_between, dh, webb}.csv
## Metodoloji:
##   M3a MG (Mean Group, Pesaran & Smith 1995)
##   M3b PMG (Pooled MG, Pesaran Shin Smith 1999)
##   M3c FE-Between (CBI_pca_2021 × cross-sectional)
##   M4  Dumitrescu-Hurlin (2012) panel Granger
##   Pre: Pesaran CD, CIPS birim kök, Westerlund (Gt)
## ============================================================

suppressPackageStartupMessages({
  library(plm)
  library(lmtest)
  library(sandwich)
  library(fixest)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(broom)
})

RESU <- "600-Results/CE_pilot_v3"
dir.create(RESU, showWarnings = FALSE, recursive = TRUE)

## ---- 0. Veri ----
panel <- read_csv("400-Data/processed/macro_CBI_panel_full.csv",
                  show_col_types = FALSE) |>
  filter(!is.na(ln_cmu), !is.na(ln_gdp), !is.na(ln_educ),
         !is.na(ln_prod), !is.na(CBI_eq_interp)) |>
  arrange(country, year)

cat("Panel:", nrow(panel), "obs |", n_distinct(panel$country), "ülke |",
    n_distinct(panel$year), "yıl\n")

pdat <- pdata.frame(panel, index = c("country","year"))

## ============================================================
## BÖLÜM 1 — ÖN-TANI
## ============================================================

## ---- 1a. Pesaran CD testi ----
cat("\n--- Pesaran CD ---\n")
cd_vars <- c("ln_cmu","CBI_eq_interp","ln_gdp","ln_educ","ln_prod")
cd_res <- lapply(cd_vars, function(v) {
  tryCatch({
    f  <- as.formula(paste(v, "~ 1"))
    ct <- plm::pcdtest(f, data = pdat, test = "cd")
    data.frame(var=v, CD=round(ct$statistic,3), p=round(ct$p.value,4))
  }, error=function(e) data.frame(var=v, CD=NA, p=NA))
}) |> bind_rows()
print(cd_res)
write_csv(cd_res, file.path(RESU, "cd.csv"))

## ---- 1b. CIPS birim kök (Pesaran 2007) ----
## Uygulamalı yaklaşım: her ülke için ADF(1) + kesit ortalama → CADF istatistiği
cat("\n--- CIPS yaklaşımı ---\n")
cips_approx <- function(dat, var) {
  # Pesaran (2007) CIPS: panel ortalama CADF istatistiği
  x     <- dat[[var]]
  cnt   <- dat[["country"]]
  yr    <- dat[["year"]]
  stats <- c()
  for (c in unique(cnt)) {
    xi <- x[cnt==c]
    xm <- tapply(x, yr, mean, na.rm=TRUE)[as.character(yr[cnt==c])]
    if (sum(!is.na(xi)) < 6) next
    dx  <- diff(xi); dxm <- diff(xm)
    xi1 <- xi[-length(xi)]; xm1 <- xm[-length(xm)]
    tmp <- data.frame(dx=dx, xi1=xi1, xm1=xm1, dxm=dxm)
    tmp <- tmp[complete.cases(tmp),]
    if (nrow(tmp) < 4) next
    m  <- tryCatch(lm(dx ~ xi1 + xm1 + dxm, data=tmp), error=function(e) NULL)
    if (is.null(m)) next
    cf <- coef(summary(m))
    if ("xi1" %in% rownames(cf)) stats <- c(stats, cf["xi1","t value"])
  }
  data.frame(var=var, CIPS=round(mean(stats,na.rm=TRUE),3),
             N_used=length(stats),
             reject_5pct = mean(stats,na.rm=TRUE) < -2.15)
}

## CBI_eq_interp lineer interpolasyon → CIPS'te patlama; CBI yerine CBI_pca_2021 kullan
## (indeks [0,1] arasında bounded → teorik olarak I(0); birim kök testi anlamsız)
cips_vars <- c("ln_cmu","ln_gdp","ln_educ","ln_prod")
cips_res <- lapply(cips_vars, function(v) cips_approx(panel, v)) |> bind_rows()
cips_res <- bind_rows(cips_res,
  data.frame(var="CBI_eq_interp", CIPS=NA, N_used=NA,
             reject_5pct=NA,
             note="Bounded [0,1] index — unit root test not meaningful"))
print(cips_res)
write_csv(cips_res, file.path(RESU, "cips.csv"))

## ---- 1c. Westerlund (2007) Gt istatistiği ----
cat("\n--- Westerlund Gt (yaklaşım) ---\n")
# Gt: bireysel hata-düzeltme katsayısı t-istatistikleri ortalaması
wt_gt <- function(dat, yvar, xvars) {
  tstats <- c()
  for (c in unique(dat$country)) {
    sub <- dat[dat$country==c,]
    if (nrow(sub) < 8) next
    # Error correction: Δy = ρ*(y_t-1 - β*X_t-1) + ...
    y  <- sub[[yvar]]
    xs <- sub[, xvars, drop=FALSE]
    dy <- diff(y)
    y1 <- y[-length(y)]
    x1 <- xs[-nrow(xs),, drop=FALSE]
    dx <- apply(xs, 2, diff)
    tmp <- data.frame(dy=dy, y1=y1, x1, dx)
    tmp <- tmp[complete.cases(tmp),]
    if (nrow(tmp) < 5) next
    rhs <- paste(c("y1", names(x1), names(as.data.frame(dx))), collapse="+")
    m   <- tryCatch(lm(as.formula(paste("dy ~", rhs)), data=tmp), error=function(e) NULL)
    if (is.null(m)) next
    cf <- coef(summary(m))
    if ("y1" %in% rownames(cf)) tstats <- c(tstats, cf["y1","t value"])
  }
  Gt <- mean(tstats, na.rm=TRUE)
  # Yaklaşık p: standart normal (büyük N için)
  pval <- pnorm(Gt)
  data.frame(test="Westerlund Gt (yaklaşım)", stat=round(Gt,3),
             N=length(tstats), p_approx=round(pval,4))
}
west_res <- wt_gt(panel, "ln_cmu",
                  c("CBI_eq_interp","ln_gdp","ln_educ","ln_prod"))
print(west_res)
write_csv(west_res, file.path(RESU, "westerlund.csv"))

## ============================================================
## BÖLÜM 2 — PANEL REGRESYON
## ============================================================

## ---- 2a. M3a: Mean Group (Pesaran & Smith 1995) ----
cat("\n--- M3a: Mean Group ---\n")
## pmg → broom desteklemiyor; manuel extraction
pmg_to_tbl <- function(m, label) {
  cf <- coef(m); se <- sqrt(diag(vcov(m)))
  tstat <- cf / se; pval <- 2 * pt(-abs(tstat), df=Inf)
  tibble(model=label, term=names(cf),
         estimate=round(cf,4), std.error=round(se,4),
         statistic=round(tstat,3), p.value=round(pval,4))
}

m3a_mg <- plm::pmg(
  ln_cmu ~ CBI_eq_interp + ln_gdp + ln_educ + ln_prod,
  data  = pdat,
  model = "mg"
)
mg_tbl <- pmg_to_tbl(m3a_mg, "MG")
print(mg_tbl)
write_csv(mg_tbl, file.path(RESU, "mg.csv"))

## ---- 2b. M3b: Pooled Mean Group (Pesaran Shin Smith 1999) ----
cat("\n--- M3b: Pooled Mean Group ---\n")
## M3b: CMG — Cross-sectionally augmented MG (Pesaran 2006, CCE)
## CD baskısı altında tercih edilen tahmincidir
m3b_cmg <- plm::pmg(
  ln_cmu ~ CBI_eq_interp + ln_gdp + ln_educ + ln_prod,
  data  = pdat,
  model = "cmg"
)
pmg_tbl <- pmg_to_tbl(m3b_cmg, "CMG")
print(pmg_tbl)
write_csv(pmg_tbl, file.path(RESU, "pmg.csv"))

## Hausman: CMG vs MG
cat("\nHausman CMG vs MG:\n")
haus <- tryCatch(phtest(m3b_cmg, m3a_mg), error=function(e) {
  cat("Hausman atlandı:", e$message, "\n"); NULL })
if (!is.null(haus)) print(haus)

## ---- 2c. M3c: FE (within) + CBI interaksiyon ----
cat("\n--- M3c: FE + CBI_pca_2021 × yıl eğilimi ---\n")
# CBI zaman-değişmez → FE absorb eder; yıl trendine ekle
panel_fe <- panel |>
  mutate(year_c    = year - 2017,    # merkezlenmiş yıl
         cbi_trend = CBI_pca_2021 * year_c)

m3c_fe <- fixest::feols(
  ln_cmu ~ CBI_pca_2021 + ln_gdp + ln_educ + ln_prod + cbi_trend |
    country + year,
  data    = panel_fe,
  cluster = ~country,
  warn    = FALSE
)
cat("\nFE + CBI×trend:\n")
print(fixest::etable(m3c_fe, digits=3))

fe_tbl <- broom::tidy(m3c_fe) |>
  mutate(across(where(is.numeric), ~round(.x, 4))) |>
  mutate(model="FE+CBI_trend")
write_csv(fe_tbl, file.path(RESU, "fe_between.csv"))

## ---- 2d. M3d: Between FE (saf kesit) ----
cat("\n--- M3d: Between Estimator ---\n")
m3d_be <- plm::plm(
  ln_cmu ~ CBI_pca_2021 + ln_gdp + ln_educ + ln_prod,
  data  = pdat,
  model = "between"
)
be_tbl <- broom::tidy(m3d_be) |>
  mutate(across(where(is.numeric), ~round(.x, 4))) |>
  mutate(model="Between")
print(be_tbl)
write_csv(be_tbl, file.path(RESU, "between.csv"))

## ============================================================
## BÖLÜM 3 — M4 Dumitrescu-Hurlin
## ============================================================
cat("\n--- M4: Dumitrescu-Hurlin (2012) ---\n")

dh_pairs <- list(
  list(y="ln_cmu", x="CBI_eq_interp"),
  list(y="CBI_eq_interp", x="ln_cmu"),
  list(y="ln_cmu", x="ln_gdp"),
  list(y="ln_gdp", x="ln_cmu")
)

dh_res <- lapply(dh_pairs, function(pr) {
  f <- as.formula(paste(pr$y, "~", pr$x))
  tryCatch({
    t <- plm::pgrangertest(f, data=pdat, test="Ztilde", order=1L)
    data.frame(
      H0    = paste0(pr$x, " \u219b ", pr$y),
      Wbar  = round(t$statistic[["Wbar"]], 3),
      Zbar  = round(t$statistic[["Zbar"]], 3),
      p     = round(t$p.value[["Zbar"]], 4),
      N     = n_distinct(panel$country)
    )
  }, error=function(e) {
    data.frame(H0=paste0(pr$x," \u219b ",pr$y), Wbar=NA, Zbar=NA, p=NA, N=NA)
  })
}) |> bind_rows()

print(dh_res)
write_csv(dh_res, file.path(RESU, "dh.csv"))

## ============================================================
## BÖLÜM 4 — ÖZET
## ============================================================
cat("\n=== M3-M4 tamamlandı ===\n")
cat("Çıktı klasörü:", RESU, "\n")
cat("\n--- MG Uzun Dönem ---\n")
print(mg_tbl |> select(term, estimate, std.error, p.value))
cat("\n--- PMG Uzun Dönem ---\n")
print(pmg_tbl |> select(term, estimate, std.error, p.value))
cat("\n--- DH Nedensellik ---\n")
print(dh_res)
