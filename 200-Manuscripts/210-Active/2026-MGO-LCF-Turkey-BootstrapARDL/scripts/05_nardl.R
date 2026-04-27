# ============================================================
# 05_nardl.R
# LCF Turkey Bootstrap ARDL — Asymmetric NARDL Estimation
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-26
# ============================================================
# Method: NARDL (Shin, Yu & Greenwood-Nimmo 2014, Festschrift)
# Asymmetric decomposition of lnGDP into positive/negative partial sums
# Tests: Wald long-run asymmetry + Wald short-run asymmetry
# ============================================================

library(tidyverse)
library(ARDL)       # nardl support via ardl() with pos/neg vars
library(dynlm)      # alternative
library(lmtest)     # waldtest

# ============================================================
# LOAD DATA
# ============================================================
panel_file <- list.files("data", pattern = "turkey_lcf_panel_", full.names = TRUE) |>
  sort() |> tail(1)
panel <- read_csv(panel_file, show_col_types = FALSE)

df <- panel |>
  select(year, lnLCF, lnGDP, lnGDP2, lnREN, lnTrade) |>
  drop_na() |>
  arrange(year)

cat("NARDL sample:", min(df$year), "–", max(df$year), "| T =", nrow(df), "\n\n")

# ============================================================
# 1. PARTIAL SUM DECOMPOSITION OF lnGDP
# ============================================================
cat("=== PARTIAL SUM DECOMPOSITION ===\n")
cat("Decomposing lnGDP into positive (GDP+) and negative (GDP-) partial sums\n")
cat("Following Shin, Yu & Greenwood-Nimmo (2014)\n\n")

d_lnGDP <- c(NA, diff(df$lnGDP))  # first difference

# Positive partial sum: cumulative sum of positive changes
pos_changes <- ifelse(d_lnGDP > 0, d_lnGDP, 0)
neg_changes <- ifelse(d_lnGDP < 0, d_lnGDP, 0)

df$GDP_pos <- cumsum(replace_na(pos_changes, 0))  # y+ = Σ max(Δy, 0)
df$GDP_neg <- cumsum(replace_na(neg_changes, 0))  # y- = Σ min(Δy, 0)

cat("GDP_pos range:", round(range(df$GDP_pos), 3), "\n")
cat("GDP_neg range:", round(range(df$GDP_neg), 3), "\n")
cat("Check: lnGDP ≈ GDP_pos + GDP_neg + lnGDP[1]?",
    round(cor(df$lnGDP, df$GDP_pos + df$GDP_neg), 4), "(should be ~1)\n\n")

# ============================================================
# 2. NARDL ESTIMATION VIA UECM
# ============================================================
cat("=== NARDL UNRESTRICTED ECM ===\n")
cat("lnLCF ~ GDP_pos + GDP_neg + lnGDP2 + lnREN + lnTrade\n\n")

# Build NARDL manually via OLS UECM (Shin et al. equation 6)
# UECM: ΔlnLCF = α + ρ*lnLCF(-1) + θ+*GDP_pos(-1) + θ-*GDP_neg(-1)
#                  + γ1*lnGDP2(-1) + γ2*lnREN(-1) + γ3*lnTrade(-1)
#                  + Σδ_j*ΔlnLCF(-j) + Σφ+_j*ΔGDP_pos(-j)
#                  + Σφ-_j*ΔGDP_neg(-j) + ... + ε

n_lags <- 1  # optimal lag (from ARDL selection in script 04)

df_ts <- df |>
  mutate(
    d_lnLCF   = c(NA, diff(lnLCF)),
    d_GDP_pos = c(NA, diff(GDP_pos)),
    d_GDP_neg = c(NA, diff(GDP_neg)),
    d_lnGDP2  = c(NA, diff(lnGDP2)),
    d_lnREN   = c(NA, diff(lnREN)),
    d_lnTrade = c(NA, diff(lnTrade)),
    # Lags
    lnLCF_L1    = lag(lnLCF, 1),
    GDP_pos_L1  = lag(GDP_pos, 1),
    GDP_neg_L1  = lag(GDP_neg, 1),
    lnGDP2_L1   = lag(lnGDP2, 1),
    lnREN_L1    = lag(lnREN, 1),
    lnTrade_L1  = lag(lnTrade, 1),
    d_lnLCF_L1  = lag(d_lnLCF, 1),
    d_GDP_pos_L1 = lag(d_GDP_pos, 1),
    d_GDP_neg_L1 = lag(d_GDP_neg, 1)
  ) |>
  drop_na()

nardl_uecm <- lm(
  d_lnLCF ~ lnLCF_L1 + GDP_pos_L1 + GDP_neg_L1 + lnGDP2_L1 + lnREN_L1 + lnTrade_L1 +
             d_lnLCF_L1 + d_GDP_pos_L1 + d_GDP_neg_L1 + d_lnGDP2 + d_lnREN + d_lnTrade,
  data = df_ts
)

cat("NARDL UECM Results:\n")
print(summary(nardl_uecm))

# ============================================================
# 3. LONG-RUN ASYMMETRIC COEFFICIENTS
# ============================================================
cat("\n=== LONG-RUN NARDL COEFFICIENTS ===\n")

coefs <- coef(nardl_uecm)
rho   <- coefs["lnLCF_L1"]  # ECT coefficient (ρ)

# Long-run coefficients: L+ = -θ+/ρ,  L- = -θ-/ρ
L_pos <- -coefs["GDP_pos_L1"] / rho  # long-run effect of GDP increase
L_neg <- -coefs["GDP_neg_L1"] / rho  # long-run effect of GDP decrease

cat("ECT (ρ):", round(rho, 4), "\n")
cat("Long-run L+ (GDP increase → LCF):", round(L_pos, 4), "\n")
cat("Long-run L- (GDP decrease → LCF):", round(L_neg, 4), "\n")
cat("Asymmetry ratio L+/L-:", round(L_pos / L_neg, 3), "\n\n")

# ============================================================
# 4. WALD TESTS FOR LONG-RUN AND SHORT-RUN ASYMMETRY
# ============================================================
cat("=== ASYMMETRY WALD TESTS ===\n")

# Long-run asymmetry: H0: θ+ = θ- (i.e., L+ = L-)
lr_wald <- linearHypothesis(nardl_uecm,
                             "GDP_pos_L1 = GDP_neg_L1",
                             test = "F")
cat("Long-run asymmetry Wald F:", round(lr_wald$F[2], 4),
    "| p:", round(lr_wald$`Pr(>F)`[2], 4), "\n")
cat("Decision:",
    ifelse(lr_wald$`Pr(>F)`[2] < 0.05,
           "REJECT H0 → Long-run asymmetry confirmed ✅",
           "Cannot reject H0 → Symmetric long-run ❌"), "\n\n")

# Short-run asymmetry: H0: φ+ = φ-
sr_wald <- linearHypothesis(nardl_uecm,
                             "d_GDP_pos_L1 = d_GDP_neg_L1",
                             test = "F")
cat("Short-run asymmetry Wald F:", round(sr_wald$F[2], 4),
    "| p:", round(sr_wald$`Pr(>F)`[2], 4), "\n")
cat("Decision:",
    ifelse(sr_wald$`Pr(>F)`[2] < 0.05,
           "REJECT H0 → Short-run asymmetry confirmed ✅",
           "Cannot reject H0 → Symmetric short-run ❌"), "\n")

# ============================================================
# 5. ASYMMETRIC DYNAMIC MULTIPLIER PLOT
# ============================================================
cat("\n=== ASYMMETRIC DYNAMIC MULTIPLIERS ===\n")
cat("Computing h-step ahead multipliers for GDP+ and GDP-\n")

h_max <- 20

# Extract short-run coefficients
phi_pos <- sum(coefs[grepl("d_GDP_pos", names(coefs))])
phi_neg <- sum(coefs[grepl("d_GDP_neg", names(coefs))])

# Build multiplier sequences (simplified single-lag version)
psi <- rho + 1
m_pos <- numeric(h_max)
m_neg <- numeric(h_max)
m_pos[1] <- coefs["d_GDP_pos_L1"]
m_neg[1] <- coefs["d_GDP_neg_L1"]

for (h in 2:h_max) {
  m_pos[h] <- psi * m_pos[h-1]
  m_neg[h] <- psi * m_neg[h-1]
}

multipliers_df <- tibble(
  h      = 1:h_max,
  m_pos  = cumsum(m_pos),
  m_neg  = cumsum(m_neg),
  diff   = cumsum(m_pos) - cumsum(m_neg)
)

# Save and plot
write_csv(multipliers_df,
          paste0("data/nardl_multipliers_", format(Sys.Date(), "%Y%m%d"), ".csv"))

p_mult <- ggplot(multipliers_df) +
  geom_line(aes(h, m_pos, color = "GDP+ (income growth)"),  linewidth = 1.1) +
  geom_line(aes(h, m_neg, color = "GDP- (income decline)"), linewidth = 1.1, linetype = "dashed") +
  geom_hline(yintercept = 0, linetype = "dotted") +
  scale_color_manual(values = c("steelblue", "tomato")) +
  labs(
    title = "Asymmetric Dynamic Multipliers: Income Growth vs. Decline → LCF",
    x = "Horizon (years)", y = "Cumulative multiplier",
    color = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave("figures/fig_nardl_multipliers.png", p_mult,
       width = 8, height = 5, dpi = 300)
cat("✅ Multiplier plot saved: figures/fig_nardl_multipliers.png\n")

cat("\n=== 05_nardl.R COMPLETE ===\n")
cat("Next step: Run 06_fmols_ccr.R for long-run robustness.\n")
