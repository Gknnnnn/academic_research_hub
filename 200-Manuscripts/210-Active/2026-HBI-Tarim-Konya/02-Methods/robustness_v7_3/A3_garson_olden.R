suppressPackageStartupMessages({ library(neuralnet); library(NeuralNetTools) })
setwd("/tmp/hbi_rds")
m <- readRDS("model_verisi.rds")
frm <- tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman

set.seed(20260413)
# 2-hidden-layer (baseline) for Olden (signed)
nn2 <- neuralnet(frm, data=m, hidden=c(7,5), algorithm="rprop+", linear.output=TRUE, stepmax=1e5, threshold=0.05)
o <- olden(nn2, bar_plot=FALSE)

# 1-hidden-layer (12 neurons, matching total 7+5) for Garson (unsigned)
set.seed(20260413)
nn1 <- neuralnet(frm, data=m, hidden=12, algorithm="rprop+", linear.output=TRUE, stepmax=1e5, threshold=0.05)
g <- garson(nn1, bar_plot=FALSE)

df <- data.frame(
  variable     = rownames(g),
  garson_pct   = g$rel_imp,                       # 0-100 (%)
  olden_signed = o$importance,                    # signed
  olden_abs_pct= abs(o$importance)/sum(abs(o$importance))*100
)
df$rank_garson <- rank(-df$garson_pct)
df$rank_olden  <- rank(-df$olden_abs_pct)

cat("A.3 Garson (single-layer 6-12-1) vs Olden (two-layer 6-7-5-1) Importance\n\n")
print(df, row.names=FALSE, digits=3)

rho <- suppressWarnings(cor(df$rank_garson, df$rank_olden, method="spearman"))
tau <- suppressWarnings(cor(df$rank_garson, df$rank_olden, method="kendall"))
cat(sprintf("\nRank concordance  Spearman rho = %.4f\n", rho))
cat(sprintf("Rank concordance  Kendall tau  = %.4f\n", tau))

saveRDS(df, "A3_garson_olden.rds")
