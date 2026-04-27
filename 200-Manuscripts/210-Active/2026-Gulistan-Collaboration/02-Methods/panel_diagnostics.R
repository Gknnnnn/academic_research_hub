# =============================================================================
# panel_diagnostics.R
# Makale: "Determinants of SSA's Agricultural Value Added"
# Bölüm: Ön-Tanılama Testleri (Section 3 — Data & Methodology)
#
# Test sırası (Q1 standart protokol):
#   [D1] Pesaran (2004) CD Testi — Cross-Sectional Dependence
#   [D2] Pesaran (2007) CIPS   — 2. Nesil Panel Birim Kök
#   [D3] Dumitrescu-Hurlin (2012) — Panel Nedensellik
#   [D4] VIF Analizi — Çoklu Doğrusallık
# =============================================================================

# --- Paketler ---
pkgs <- c("plm","pdynmc","purtest","cips","panelvar","car","lmtest","sandwich")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE))
    install.packages(p, dependencies = TRUE)
}

library(plm)
library(car)

# --- Veri ---
DATA_PATH <- "../../../../400-Data/2026-Gulistan-Collaboration/data/ssa_tarim_29_ulke_v7_climate.csv"
df <- read.csv(DATA_PATH)
df$year <- as.integer(df$year)

# Panel nesnesi
pdata <- pdata.frame(df, index = c("country", "year"))

# Değişkenler
dep_var  <- "Agri_GDP"
ind_vars <- c("Labor","Land","Fertilizer","Exports","Technology",
              "Resource_Rent","Electricity")
new_vars <- c("gdp_pc","urban","fdi","renewable","trade_open",
              "wgi_composite","enso_index","ln_ffpi",
              "cereal_yield","food_prod_idx")
all_vars <- c(ind_vars, new_vars)

cat("\n", rep("=",70), "\n")
cat("PANEL TANI TESTLERİ — SSA Tarım Paneli (N=29, T=21)\n")
cat(rep("=",70), "\n\n")

# =============================================================================
# [D1] PESARAN (2004) CD TESTİ — Cross-Sectional Dependence
# =============================================================================
cat("[D1] PESARAN (2004) CD TESTİ\n")
cat("H0: Cross-sectional independence\n")
cat(rep("-",70), "\n")
cat(sprintf("%-26s %10s %10s %15s\n", "Değişken", "CD stat", "p-value", "Karar"))
cat(rep("-",70), "\n")

cd_results <- list()
for (var in c(dep_var, all_vars)) {
  tryCatch({
    # plm ile within model artıklarından CD hesapla
    f <- as.formula(paste(var, "~ 1"))
    m <- plm(f, data = pdata, model = "within")
    resid_mat <- matrix(residuals(m), nrow = 21, ncol = 29)

    N <- ncol(resid_mat); T <- nrow(resid_mat)
    cd_sum <- 0
    for (i in 1:(N-1)) {
      for (j in (i+1):N) {
        cd_sum <- cd_sum + cor(resid_mat[,i], resid_mat[,j])
      }
    }
    CD <- sqrt(2*T / (N*(N-1))) * cd_sum
    p_val <- 2 * pnorm(-abs(CD))
    karar <- ifelse(p_val < 0.01, "CSD ***", ifelse(p_val < 0.05, "CSD **", "bağımsız"))
    cat(sprintf("%-26s %10.3f %10.4f %15s\n", var, CD, p_val, karar))
    cd_results[[var]] <- list(CD=CD, p=p_val)
  }, error = function(e) {
    cat(sprintf("%-26s %s\n", var, "HATA"))
  })
}
cat(rep("-",70), "\n")
cat("→ CSD mevcut: 2. nesil birim kök (CIPS) kullanılmalıdır.\n\n")

# =============================================================================
# [D2] CIPS BİRİM KÖK TESTİ — Pesaran (2007)
# =============================================================================
cat("[D2] PESARAN (2007) CIPS BİRİM KÖK TESTİ\n")
cat("H0: Birim kök mevcut | Kritik değerler: %1=-2.57  %5=-2.33  %10=-2.21\n")
cat(rep("-",70), "\n")
cat(sprintf("%-26s %12s %12s %12s\n","Değişken","CIPS(level)","CIPS(Δ)","Bütünleşme"))
cat(rep("-",70), "\n")

cips_stat <- function(pdata, var) {
  # Pesaran CADF yaklaşımı: her birim için regresyon, ortalama t-istatistiği
  countries <- levels(pdata$country)
  N <- length(countries); T <- length(levels(pdata$year))

  # Cross-sectional mean
  y_bar <- tapply(pdata[[var]], pdata$year, mean, na.rm=TRUE)

  t_stats <- numeric(N)
  for (i in seq_along(countries)) {
    sub <- pdata[pdata$country == countries[i], var]
    y   <- as.numeric(sub)
    yb  <- as.numeric(y_bar)

    if (any(is.na(y)) || length(y) < 5) { t_stats[i] <- NA; next }

    T_i  <- length(y)
    dy   <- diff(y);       dyb <- diff(yb)
    ylg  <- y[-T_i];      yblg <- yb[-T_i]

    X <- cbind(1, ylg, yblg, dyb)
    Y <- dy
    tryCatch({
      b   <- solve(t(X) %*% X) %*% t(X) %*% Y
      e   <- Y - X %*% b
      s2  <- sum(e^2) / max(nrow(X) - ncol(X), 1)
      se  <- sqrt(s2 * solve(t(X) %*% X)[2,2])
      t_stats[i] <- b[2] / se
    }, error=function(e) { t_stats[i] <<- NA })
  }
  mean(t_stats, na.rm=TRUE)
}

int_order <- character(length(all_vars))
names(int_order) <- all_vars

for (var in c(dep_var, all_vars)) {
  cips_lev <- cips_stat(pdata, var)

  # Fark serisi
  pdata[[paste0("d_",var)]] <- as.numeric(diff(pdata[[var]]))
  cips_dif <- tryCatch(cips_stat(pdata, paste0("d_",var)), error=function(e) NA)

  cv5 <- -2.33
  ord <- if (!is.na(cips_lev) && cips_lev < cv5) "I(0)" else
         if (!is.na(cips_dif) && cips_dif < cv5)  "I(1)" else "I(?)"
  if (var %in% names(int_order)) int_order[var] <- ord

  sig_l <- if (!is.na(cips_lev)) ifelse(cips_lev < -2.57,"***",ifelse(cips_lev < -2.33,"**",ifelse(cips_lev < -2.21,"*",""))) else ""
  sig_d <- if (!is.na(cips_dif)) ifelse(cips_dif < -2.57,"***",ifelse(cips_dif < -2.33,"**",ifelse(cips_dif < -2.21,"*",""))) else ""

  cat(sprintf("%-26s %10.3f%-2s %10.3f%-2s %12s\n",
              var,
              ifelse(is.na(cips_lev),NA,cips_lev), sig_l,
              ifelse(is.na(cips_dif),NA,cips_dif), sig_d,
              ord))
}
cat(rep("-",70), "\n")
cat("*** p<0.01  ** p<0.05  * p<0.10\n\n")

# =============================================================================
# [D3] DUMITRESCU-HURLIN (2012) PANEL NEDENSELLİK
# =============================================================================
cat("[D3] DUMITRESCU-HURLIN (2012) PANEL NEDENSELLİK TESTİ\n")
cat("H0: x değişkeni y'yi Granger-anlamında ETKİLEMİYOR\n")
cat(rep("-",70), "\n")

dh_test <- function(df, y_var, x_var, lags = 1) {
  countries <- unique(df$country)
  N <- length(countries)
  T <- length(unique(df$year))

  W_i <- numeric(N)
  for (ci in seq_along(countries)) {
    sub <- df[df$country == countries[ci], c("year", y_var, x_var)]
    sub <- sub[order(sub$year), ]
    y <- sub[[y_var]]; x <- sub[[x_var]]
    T_i <- length(y)
    if (T_i <= lags * 2 + 2) { W_i[ci] <- NA; next }

    # Kısıtsız model
    Y <- y[(lags+1):T_i]
    X_u <- cbind(1, sapply(1:lags, function(k) y[(lags+1-k):(T_i-k)]),
                    sapply(1:lags, function(k) x[(lags+1-k):(T_i-k)]))
    X_r <- cbind(1, sapply(1:lags, function(k) y[(lags+1-k):(T_i-k)]))

    tryCatch({
      RSS_u <- sum(lm.fit(X_u, Y)$residuals^2)
      RSS_r <- sum(lm.fit(X_r, Y)$residuals^2)
      n_obs <- length(Y); k_u <- ncol(X_u)
      F_i <- ((RSS_r - RSS_u) / lags) / (RSS_u / (n_obs - k_u))
      W_i[ci] <- lags * F_i
    }, error = function(e) { W_i[ci] <<- NA })
  }

  W_i <- W_i[!is.na(W_i)]
  N_v <- length(W_i)
  W_bar <- mean(W_i)
  T_eff <- T - 2*lags - 1

  Z_tilde <- if (T_eff > 3 + lags) {
    sqrt(N_v / (2*lags) * (T_eff / (T_eff + 2*lags))) * (W_bar - lags)
  } else {
    sqrt(N_v / (2*lags)) * (W_bar - lags)
  }
  p_val <- 2 * pnorm(-abs(Z_tilde))
  list(W_bar=W_bar, Z_tilde=Z_tilde, p=p_val, N=N_v)
}

cat(sprintf("%-42s %7s %9s %8s  %s\n","Hipotez","W-bar","Z-tilde","p-val","Karar"))
cat(rep("-",70), "\n")

test_pairs <- c("Labor","Fertilizer","Technology","Resource_Rent",
                "Electricity","gdp_pc","urban","trade_open",
                "wgi_composite","enso_index","ln_ffpi","cereal_yield","food_prod_idx")

for (pred in test_pairs) {
  r1 <- dh_test(df, dep_var, pred, lags=1)
  star <- ifelse(r1$p<0.01,"***",ifelse(r1$p<0.05,"**",ifelse(r1$p<0.10,"*","")))
  karar <- ifelse(r1$p<0.05, paste0("Nedensellik ",star), "YOK")
  cat(sprintf("%-42s %7.3f %9.3f %8.4f  %s\n",
              paste(pred,"→",dep_var), r1$W_bar, r1$Z_tilde, r1$p, karar))
}
cat(rep("-",35), "\n")
for (pred in test_pairs) {
  r2 <- dh_test(df, pred, dep_var, lags=1)
  star <- ifelse(r2$p<0.01,"***",ifelse(r2$p<0.05,"**",ifelse(r2$p<0.10,"*","")))
  karar <- ifelse(r2$p<0.05, paste0("Nedensellik ",star), "YOK")
  cat(sprintf("%-42s %7.3f %9.3f %8.4f  %s\n",
              paste(dep_var,"→",pred), r2$W_bar, r2$Z_tilde, r2$p, karar))
}
cat(rep("-",70), "\n")
cat("*** p<0.01  ** p<0.05  * p<0.10\n\n")

# =============================================================================
# [D4] VIF ANALİZİ
# =============================================================================
cat("[D4] VIF ANALİZİ (Model 3 + Yeni Değişkenler)\n")
cat(rep("-",50), "\n")

# Model 3 (mevcut)
f_m3 <- as.formula(paste(dep_var,"~",paste(ind_vars, collapse="+")))
vif_m3 <- vif(lm(f_m3, data=df))
cat("Model 3 (7 değişken):\n")
for (v in names(vif_m3)) {
  flag <- if (vif_m3[v] > 10) "⚠ ÇOK YÜKSEK" else if (vif_m3[v] > 5) "⚠" else "✓"
  cat(sprintf("  %-25s VIF = %6.2f  %s\n", v, vif_m3[v], flag))
}

# Genişletilmiş
f_ext <- as.formula(paste(dep_var,"~",paste(all_vars, collapse="+")))
vif_ext <- vif(lm(f_ext, data=df))
cat("\nGenişletilmiş (12 değişken):\n")
for (v in names(vif_ext)) {
  flag <- if (vif_ext[v] > 10) "⚠ ÇOK YÜKSEK" else if (vif_ext[v] > 5) "⚠" else "✓"
  cat(sprintf("  %-25s VIF = %6.2f  %s\n", v, vif_ext[v], flag))
}
cat(rep("-",50), "\n")
cat("Referans: Wooldridge (2010) — VIF < 10 kabul edilebilir\n\n")

cat(rep("=",70), "\n")
cat("TÜM TANI TESTLERİ TAMAMLANDI\n")
cat(rep("=",70), "\n")
