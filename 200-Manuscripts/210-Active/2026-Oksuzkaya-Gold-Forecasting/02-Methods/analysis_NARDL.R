# ---
# Title: NARDL Asymmetric Currency Wars & Safe Havens on Gold
# Authors: Dr. Mehmet Öksüzkaya & Dr. Mehmet Gökhan Özdemir
# Concept: Capturing the non-linear, asymmetric impact of REER shocks and rival Safe Havens on XAU/USD
# ---

library(ardl)
library(tseries)
library(forecast)

# 1. Data Ingestion Placeholder
# data <- read.csv("gold_currency_wars_data.csv")
# Y: Gold Returns (XAU)
# X: US_REER (US Real Effective Exchange Rate), CN_REER (China REER)
# Controls: JPY_USD (Yen), CHF_USD (Franc), VIX, GPR (Geopolitical Risk), Crypto_Index

# 2. Variable Decomposition (Positive and Negative Shocks via REER)
# Example: Non-linear decomposition for US_REER
# data$US_REER_POS <- cumsum(ifelse(diff(data$US_REER) > 0, diff(data$US_REER), 0))
# data$US_REER_NEG <- cumsum(ifelse(diff(data$US_REER) < 0, diff(data$US_REER), 0))

# 3. NARDL Modeling
# nardl_model <- ardl(XAU ~ US_REER_POS + US_REER_NEG + CN_REER + JPY_USD + CHF_USD + VIX + GPR + Crypto_Index, data=data, max_p=4)
# Bounds Test for Asymmetric Cointegration
# bounds_test(nardl_model)

# 4. Extracting Residuals for Machine Learning
# Once the NARDL model captures the long/short-term asymmetric dynamics against rival Safe Havens, 
# there will be "unexplained variance" (residuals) during extreme crisis periods.
# residuals_nardl <- residuals(nardl_model)
# write.csv(residuals_nardl, "nardl_residuals_for_ML.csv")

message("NARDL baseline upgraded with REER, JPY, CHF, and Crypto variables. Awaiting data.")
