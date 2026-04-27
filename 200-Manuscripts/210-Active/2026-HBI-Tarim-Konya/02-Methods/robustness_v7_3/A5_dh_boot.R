suppressPackageStartupMessages({ library(plm); library(parallel) })
setwd("/tmp/hbi_rds")
v <- readRDS("veri_tam_panel.rds")
v <- v[order(v$iso3c, v$year),]
vars <- c("emek","toprak","gubre","verim","ticaret","ekipman")   # 6 inputs
target <- "tarim_gsyh"
P <- 2   # lag order
ids <- unique(v$iso3c); N <- length(ids); T <- length(unique(v$year))

# Dumitrescu-Hurlin (2012) statistic: average of individual Wald F stats standardized
# W_i: Wald stat from testing lag coefs of X=0 in Δy_it regression
# Z = sqrt(N/(2P)) * (W_bar - P),  Z_tilde uses (N,T) adjusted form

dh_stat <- function(y, x, id, time, P=2) {
  df <- data.frame(id=id, time=time, y=y, x=x)
  df <- df[order(df$id, df$time),]
  # Build lags per id
  lag_y <- function(z,k) ave(z, df$id, FUN=function(zz) c(rep(NA,k), head(zz,-k)))
  for (k in 1:P) {
    df[[paste0("y_l",k)]] <- lag_y(df$y,k)
    df[[paste0("x_l",k)]] <- lag_y(df$x,k)
  }
  df2 <- df[complete.cases(df),]
  W_i <- numeric(0)
  for (i in ids) {
    sub <- df2[df2$id==i,]
    if (nrow(sub) < 2*P+2) next
    f_full <- as.formula(paste("y ~", paste(paste0("y_l",1:P), collapse="+"), "+", paste(paste0("x_l",1:P), collapse="+")))
    f_res  <- as.formula(paste("y ~", paste(paste0("y_l",1:P), collapse="+")))
    full <- try(lm(f_full, data=sub), silent=TRUE)
    rest <- try(lm(f_res,  data=sub), silent=TRUE)
    if (inherits(full,"try-error") || inherits(rest,"try-error")) next
    # F-test -> W = P*F (approx)
    an <- try(anova(rest, full), silent=TRUE)
    if (inherits(an,"try-error")) next
    Fst <- an$F[2]
    if (is.na(Fst)) next
    W_i <- c(W_i, P * Fst)  # Wald = P*F
  }
  W_bar <- mean(W_i)
  Z_bar <- sqrt(N/(2*P)) * (W_bar - P)
  # Z_tilde per D-H eq (11):
  Z_tilde <- sqrt(N/(2*P)*(T-3*P-5)/(T-2*P-3)) * ((T-3*P-3)/(T-3*P-1)*W_bar - P)
  list(W_bar=W_bar, Z_bar=Z_bar, Z_tilde=Z_tilde, N_ok=length(W_i))
}

# Block bootstrap on panel residuals under H0 (no causality): resample blocks within i
block_bootstrap_pval <- function(y, x, id, time, P=2, B=1000, l=3, cores=4) {
  obs <- dh_stat(y, x, id, time, P)
  Z_obs <- obs$Z_tilde
  # Under H0: x doesn't cause y. Resample (y,x) pairs by block per country while preserving time order.
  df <- data.frame(id=id, time=time, y=y, x=x)
  df <- df[order(df$id, df$time),]
  ids_local <- unique(df$id)
  one_boot <- function(b) {
    set.seed(b*101 + 7)
    df_b <- df
    for (i in ids_local) {
      rows <- which(df_b$id==i); Ti <- length(rows)
      n_blocks <- ceiling(Ti/l)
      starts <- sample(1:max(1,Ti-l+1), n_blocks, replace=TRUE)
      idxs <- unlist(lapply(starts, function(s) s:(s+l-1)))
      idxs <- idxs[1:Ti]; idxs <- pmin(idxs, Ti)
      df_b$x[rows] <- df_b$x[rows][idxs]   # shuffle x only -> breaks causality
    }
    dh_stat(df_b$y, df_b$x, df_b$id, df_b$time, P)$Z_tilde
  }
  Z_star <- unlist(mclapply(1:B, one_boot, mc.cores=cores))
  p_boot <- mean(abs(Z_star) >= abs(Z_obs), na.rm=TRUE)
  list(obs=obs, Z_star=Z_star, p_boot=p_boot)
}

cat("A.5 Dumitrescu-Hurlin (2012) with block bootstrap (B=1000, l=3)\n")
cat("H0: X does NOT homogeneously Granger-cause tarim_gsyh\n")
cat(sprintf("%-10s %10s %10s %10s %8s\n","X","W_bar","Z_tilde","p_asym","p_boot"))
for (vv in vars) {
  r <- block_bootstrap_pval(v[[target]], v[[vv]], v$iso3c, v$year, P=2, B=1000, l=3, cores=4)
  Z <- r$obs$Z_tilde
  p_asym <- 2*(1-pnorm(abs(Z)))
  cat(sprintf("%-10s %10.3f %10.3f %10.4f %8.4f\n", vv, r$obs$W_bar, Z, p_asym, r$p_boot))
  saveRDS(r, sprintf("A5_dh_%s.rds", vv))
}
