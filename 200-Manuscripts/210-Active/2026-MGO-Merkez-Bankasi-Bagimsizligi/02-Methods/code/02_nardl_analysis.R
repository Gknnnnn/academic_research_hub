# ============================================================================
# Merkez Bankası Bağımsızlığı — NARDL + Bai-Perron Analiz Scripti
# ============================================================================
# M. Gökhan Özdemir | Kırıkkale University
# Oluşturma: 2026-04-09
#
# Model: NARDL (Nonlinear ARDL — Shin et al. 2014)
# Araştırma sorusu: TCMB'nin fiili bağımsızlık kaybı (2019–2023)
#   enflasyon beklentileri üzerinde asimetrik etki yarattı mı?
#
# GEREKLİ PAKETLER:
#   install.packages(c("ARDL", "nardl", "urca", "strucchange",
#                      "tseries", "lmtest", "sandwich", "ggplot2",
#                      "dynlm", "vars", "tsDyn"))
# ============================================================================

# ── 0. Ortam ─────────────────────────────────────────────────────────────────
rm(list = ls())
options(scipen = 999, digits = 4)
set.seed(42)

# Paket yükleme
pkgs <- c("ARDL", "nardl", "urca", "strucchange", "tseries",
          "lmtest", "sandwich", "ggplot2", "dplyr", "zoo",
          "dynlm", "vars", "readr", "lubridate")
invisible(lapply(pkgs, function(p) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  library(p, character.only = TRUE)
}))

# ── 1. Veri Yükleme ──────────────────────────────────────────────────────────
cat("=== [1] Veri yükleniyor ===\n")

df <- read_csv("../data/raw/tcmb_monthly_2005_2025.csv",
               col_types = cols(date = col_date())) |>
  arrange(date) |>
  filter(!is.na(inf_exp_12m), !is.na(policy_rate), !is.na(cpi_annual))

# Zaman serisi objesi
ts_start <- c(year(min(df$date)), month(min(df$date)))
ts_end   <- c(year(max(df$date)), month(max(df$date)))

# Temel değişkenler (aylık, 2005M1–2025M3)
inf_exp  <- ts(df$inf_exp_12m,  start = ts_start, frequency = 12)  # Bağımlı: 12ay enf. beklentisi
policy   <- ts(df$policy_rate,  start = ts_start, frequency = 12)  # Politika faizi
cpi      <- ts(df$cpi_annual,   start = ts_start, frequency = 12)  # Gerçekleşen enflasyon
usd_try  <- ts(log(df$usd_try), start = ts_start, frequency = 12)  # Log kur
m2_gr    <- ts(df$m2,           start = ts_start, frequency = 12)  # Para arzı

cat("  Dönem:", format(min(df$date)), "—", format(max(df$date)),
    "| Gözlem:", nrow(df), "\n")

# ── 2. Birim Kök Testleri ─────────────────────────────────────────────────────
cat("\n=== [2] Birim Kök Testleri ===\n")

# 2a. ADF-GLS (Elliott, Rothenberg, Stock 1996)
run_adf_gls <- function(x, name) {
  cat(sprintf("%-20s", name))
  # ur.ers = ADF-GLS
  test_level <- ur.ers(x, type = "DF-GLS", model = "trend", lag.max = 12)
  test_diff  <- ur.ers(diff(x), type = "DF-GLS", model = "constant", lag.max = 12)
  cat("Level:", round(test_level@teststat, 3),
      "| 5%cv:", test_level@cval[2],
      "| Diff:", round(test_diff@teststat, 3), "\n")
}

cat("Variable             Level stat | 5%cv  | 1st Diff\n")
cat(strrep("-", 55), "\n")
run_adf_gls(inf_exp, "inf_exp_12m")
run_adf_gls(policy,  "policy_rate")
run_adf_gls(cpi,     "cpi_annual")
run_adf_gls(usd_try, "log_usd_try")

# 2b. Zivot-Andrews (tek yapısal kırılma — 2021 bölgesi için)
cat("\n--- Zivot-Andrews (tek kırılma) ---\n")
za_inf <- ur.za(inf_exp, model = "both", lag = 12)
cat("inf_exp_12m: Kırılma tarihi =",
    format(time(inf_exp)[which.min(za_inf@teststat)]), "\n")
cat("Zivot-Andrews t-stat:", round(min(za_inf@teststat), 3),
    "| 5% kritik: -4.80\n")

# ── 3. ARDL Bounds Testi (ARDL — Pesaran et al. 2001) ────────────────────────
cat("\n=== [3] ARDL Bounds Testi ===\n")

# BIC/AIC ile optimal gecikme seçimi
ardl_mod <- ardl(inf_exp ~ policy + cpi + usd_try,
                 data = df, order = c(12, 12, 12, 12),
                 selection = "BIC")

bounds_res <- bounds_f_test(ardl_mod, case = 3)
cat("F-istatistiği:", round(bounds_res$statistic, 3), "\n")
cat("I(0) 5% üst sınır:", bounds_res$tab[2, 2], "\n")
cat("I(1) 5% üst sınır:", bounds_res$tab[2, 4], "\n")
cat("Eşbütünleşme:", ifelse(bounds_res$statistic > bounds_res$tab[2, 4],
                            "EVET (I(1) üstü)", "HAYIR"), "\n")

# ── 4. NARDL (Nonlinear ARDL — Shin et al. 2014) ─────────────────────────────
cat("\n=== [4] NARDL Asimetrik Eşbütünleşme ===\n")
# Ana hipotez: CBI kaybı (politika faizi ↓) enflasyon beklentileri üzerinde
# asimetrik etki yaratır — aşağı yönlü faiz şoku ≠ yukarı yönlü faiz şoku

# policy pozitif/negatif ayrıştırması
df <- df |>
  mutate(
    d_policy     = c(NA, diff(policy_rate)),
    policy_pos   = cumsum(ifelse(is.na(d_policy), 0, pmax(d_policy, 0))),  # ↑ faiz
    policy_neg   = cumsum(ifelse(is.na(d_policy), 0, pmin(d_policy, 0))),  # ↓ faiz (bağımsızlık kaybı)
    d_cpi        = c(NA, diff(cpi_annual)),
    cpi_pos      = cumsum(ifelse(is.na(d_cpi), 0, pmax(d_cpi, 0))),
    cpi_neg      = cumsum(ifelse(is.na(d_cpi), 0, pmin(d_cpi, 0)))
  )

# NARDL modeli
nardl_mod <- nardl(
  inf_exp_12m ~ policy_pos + policy_neg + cpi_annual + usd_try,
  data = df,
  p    = 3,    # optimal gecikme — BIC ile ayarlanacak
  q    = c(3, 3, 3, 3),
  ic   = "BIC",
  se   = "white"  # White heteroskedasticity-consistent SE
)
summary(nardl_mod)

# Asimetri testi: H0: β⁺_policy = β⁻_policy (uzun dönem)
cat("\n--- Uzun Dönem Asimetri Testi (Wald) ---\n")
# Wald testi: θ⁺ = θ⁻
cat("Null: Politika faizi artışı = düşüşü (simetrik etki)\n")
# nardl paketi içinde asimetri testi
print(nardl_mod$asymmetry)

# ── 5. Bai-Perron Çoklu Yapısal Kırılma ─────────────────────────────────────
cat("\n=== [5] Bai-Perron Çoklu Yapısal Kırılma ===\n")
# Beklenen kırılmalar: 2019-07 (Uysal), 2021-03 (Kavacioglu), 2023-06 (Erkan)

inf_ts <- ts(df$inf_exp_12m, start = ts_start, frequency = 12)

# strucchange ile supF testi
bp_test <- breakpoints(inf_ts ~ 1, h = 0.15, breaks = 5)  # min %15 segment
cat("Optimal kırılma sayısı:", bp_test$breakpoints |> length(), "\n")
cat("BIC-seçilen kırılmalar:\n")
summary(bp_test)

# Kırılma tarihleri
break_dates <- time(inf_ts)[bp_test$breakpoints]
cat("Kırılma tarihleri:", paste(round(break_dates, 2), collapse = ", "), "\n")

# ⚠️ NOT (CLAUDE.md uyarısı):
# Bai-Perron supF p-değerleri χ²(q) yaklaşımıdır.
# Q1 gönderim öncesi Stata xtbreak ile çapraz kontrol yapılmalıdır.
cat("\n⚠️  supF p-değerleri χ²(q) yaklaşımı — Stata xtbreak ile doğrulayın\n")

# Görselleştirme
plot(bp_test, main = "Bai-Perron: Enflasyon Beklentileri Yapısal Kırılmalar",
     ylab = "12 Aylık Enflasyon Beklentisi (%)")
abline(v = c(2019.5, 2021.25, 2023.5), col = "red", lty = 2)
legend("topleft", legend = c("Gerçekleşen kırılma", "TCMB başkan değişimi"),
       col = c("black", "red"), lty = c(1, 2))

# ── 6. Tanısal Testler ───────────────────────────────────────────────────────
cat("\n=== [6] Tanısal Testler ===\n")

# CUSUM istikrar testi
cat("CUSUM testi (istikrar):\n")
cusum_test <- efp(inf_exp_12m ~ policy_rate + cpi_annual + usd_try,
                  data = df, type = "OLS-CUSUM")
plot(cusum_test, main = "CUSUM — Model İstikrarı")
print(sctest(cusum_test))

# Breusch-Godfrey otokorelasyon
cat("\nBreusch-Godfrey (otokorelasyon, lag=12):\n")
print(bgtest(nardl_mod$model, order = 12))

# Breusch-Pagan heteroskedastisite
cat("Breusch-Pagan (heteroskedastisite):\n")
print(bptest(nardl_mod$model))

# ── 7. Dinamik Çoğaltanlar ──────────────────────────────────────────────────
cat("\n=== [7] Dinamik Çoğaltanlar (Dynamic Multipliers) ===\n")
# 24 dönem (2 yıl) ufku
mult <- multipliers(nardl_mod, type = "asymmetric", ci = 0.95, n.ahead = 24)
plot(mult, main = "Asimetrik Dinamik Çoğaltanlar: Politika Faizi → Enflasyon Beklentisi",
     ylab = "Kümülatif Etki (%p)",
     xlab = "Ay")

# ── 8. Robustness: TVP-VAR ───────────────────────────────────────────────────
cat("\n=== [8] Robustness: VAR ===\n")
var_data <- df[, c("inf_exp_12m", "policy_rate", "cpi_annual", "usd_try")] |>
  na.omit()

var_select <- VARselect(var_data, lag.max = 12, type = "const")
cat("Optimal VAR gecikmesi (AIC):", var_select$selection["AIC(n)"], "\n")

var_mod <- VAR(var_data, p = var_select$selection["AIC(n)"],
               type = "const")
# Causality test: politika faizi → enflasyon beklentisi
cat("Granger nedensellik (policy_rate → inf_exp_12m):\n")
print(causality(var_mod, cause = "policy_rate")$Granger)

# ── 9. Sonuçları Kaydet ──────────────────────────────────────────────────────
cat("\n=== [9] Çıktılar kaydediliyor ===\n")
out_path <- "../data/processed/"
dir.create(out_path, showWarnings = FALSE, recursive = TRUE)

# NARDL uzun dönem katsayıları
write.csv(coef(nardl_mod), file.path(out_path, "nardl_coef.csv"))
cat("✓ NARDL katsayıları:", file.path(out_path, "nardl_coef.csv"), "\n")

cat("\n✅ Analiz tamamlandı.\n")
cat("Sonraki adım: 03_tables_figures.R (tablo ve şekil üretimi)\n")

# ============================================================================
# TABLOLAR İÇİN REFERANS ŞABLONU (LaTeX)
# ============================================================================
# \begin{table}[ht]
# \centering
# \caption{NARDL Long-Run Asymmetric Estimates}
# \label{tab:nardl_lr}
# \begin{tabular}{lcccc}
# \hline
# Variable & Coeff. & Std.Err & t-stat & p-value \\
# \hline
# $\theta^+$ (policy rate increase) & & & & \\
# $\theta^-$ (policy rate decrease) & & & & \\
# CPI (actual inflation) & & & & \\
# $\ln$(USD/TRY) & & & & \\
# \hline
# Wald test ($\theta^+=\theta^-$) & \multicolumn{4}{c}{F = [val], p = [val]} \\
# \hline
# \end{tabular}
# \end{table}
