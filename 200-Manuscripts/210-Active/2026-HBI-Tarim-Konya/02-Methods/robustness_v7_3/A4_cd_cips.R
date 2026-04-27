suppressPackageStartupMessages({ library(plm) })
setwd("/tmp/hbi_rds")
v <- readRDS("veri_tam_panel.rds")
# Balanced panel check
v <- v[order(v$iso3c, v$year),]
vars <- c("tarim_gsyh","emek","toprak","gubre","verim","ticaret","ekipman")

# Pesaran (2004) CD test using pcdtest with pseries per variable
pdat <- pdata.frame(v, index=c("iso3c","year"))

# Manual Pesaran (2007) CIPS via auxiliary CADF regressions
# For each i: Δy_it = a_i + b_i*y_{i,t-1} + c_i*ȳ_{t-1} + d_i*Δȳ_t + e_it  (lag 0)
# CIPS = mean(t-stat of b_i). Critical values from Pesaran (2007) Table II(b): panel with intercept
# N=105, T=21 -> 5% ≈ -2.12 (approx from table, linear interpolation)

cips_one <- function(x, id, time, lags=0) {
  df <- data.frame(id=id, time=time, x=x)
  df <- df[order(df$id, df$time),]
  # cross-section means per time
  ybar <- tapply(df$x, df$time, mean, na.rm=TRUE)
  df$ybar <- ybar[as.character(df$time)]
  df$dx <- ave(df$x, df$id, FUN=function(z) c(NA, diff(z)))
  df$x_l <- ave(df$x, df$id, FUN=function(z) c(NA, head(z,-1)))
  df$dybar <- ave(df$ybar, df$id, FUN=function(z) c(NA, diff(z)))
  df$ybar_l <- ave(df$ybar, df$id, FUN=function(z) c(NA, head(z,-1)))
  ids <- unique(df$id)
  tstats <- sapply(ids, function(i){
    sub <- df[df$id==i & complete.cases(df[,c("dx","x_l","ybar_l","dybar")]),]
    if (nrow(sub) < 6) return(NA)
    fit <- try(lm(dx ~ x_l + ybar_l + dybar, data=sub), silent=TRUE)
    if (inherits(fit,"try-error")) return(NA)
    cf <- summary(fit)$coefficients
    if (!"x_l" %in% rownames(cf)) return(NA)
    cf["x_l","t value"]
  })
  # truncation a la Pesaran(2007): bound CADF t between -6.19 and 2.61
  tstats <- pmin(pmax(tstats, -6.19, na.rm=TRUE), 2.61, na.rm=TRUE)
  cips <- mean(tstats, na.rm=TRUE)
  list(cips=cips, n_ok=sum(!is.na(tstats)))
}

cat("A.4a Pesaran (2004) CD test\n")
cat(sprintf("%-12s %8s %8s %s\n","Var","CD","p-value","Decision (H0: CS independence)"))
for (vv in vars) {
  r <- try(pcdtest(as.formula(paste(vv,"~1")), data=pdat, test="cd"), silent=TRUE)
  if (inherits(r,"try-error")) { cat(vv,"ERROR\n"); next }
  dec <- ifelse(r$p.value<0.01,"Reject (***)", ifelse(r$p.value<0.05,"Reject (**)",
                ifelse(r$p.value<0.10,"Reject (*)","Fail to reject")))
  cat(sprintf("%-12s %8.3f %8.4f %s\n", vv, as.numeric(r$statistic), r$p.value, dec))
}

cat("\nA.4b Pesaran (2007) CIPS (lag=0)\n")
cat("Approx 5% CV (N=105,T=21, intercept): -2.12; 1% CV: -2.22\n")
cat(sprintf("%-12s %8s %6s %s\n","Var","CIPS","N_ok","Decision (H0: unit root)"))
for (vv in vars) {
  r <- cips_one(v[[vv]], v$iso3c, v$year)
  dec <- ifelse(r$cips < -2.22, "Stationary (1%)",
         ifelse(r$cips < -2.12, "Stationary (5%)",
         ifelse(r$cips < -1.99, "Stationary (10%)","Unit root (fail to reject)")))
  cat(sprintf("%-12s %8.3f %6d %s\n", vv, r$cips, r$n_ok, dec))
}
