suppressPackageStartupMessages({ library(neuralnet); library(parallel) })
setwd("/tmp/hbi_rds")
m <- readRDS("model_verisi.rds")
frm <- tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman

# Architectures: base 6-7-5-1 vs 4 alternatives
archs <- list(
  "6-7-5-1 (baz)" = c(7,5),
  "6-5-3-1"       = c(5,3),
  "6-8-4-1"       = c(8,4),
  "6-10-5-1"      = c(10,5),
  "6-6-6-1"       = c(6,6)
)

fit_seed <- function(s, hidden, tr, te, thr, stp) {
  set.seed(s)
  nn <- try(neuralnet(frm, data=tr, hidden=hidden, algorithm="rprop+",
                      linear.output=TRUE, stepmax=stp, threshold=thr), silent=TRUE)
  if (inherits(nn,"try-error") || is.null(nn$weights)) return(c(r2=NA,mae=NA,rmse=NA))
  p <- as.numeric(predict(nn, te[,-1])); y <- te$tarim_gsyh
  c(r2=1-sum((y-p)^2)/sum((y-mean(y))^2), mae=mean(abs(y-p)), rmse=sqrt(mean((y-p)^2)))
}

# Fixed 70/30 split (as in original paper)
set.seed(20260413)
idx <- sample(seq_len(nrow(m)), size=floor(0.7*nrow(m)))
tr <- m[idx,]; te <- m[-idx,]
seeds <- 1:20  # 20 seeds per architecture for robustness

cat("A.2 Architecture Sensitivity (20 seeds each, 70/30 split)\n")
cat(sprintf("%-18s %8s %8s %8s %8s %8s\n","Arch","R2_mean","R2_sd","MAE_mean","RMSE_mean","N_ok"))
results <- list()
for (nm in names(archs)) {
  h <- archs[[nm]]
  rr <- mclapply(seeds, fit_seed, hidden=h, tr=tr, te=te, thr=0.05, stp=1e5, mc.cores=4)
  M <- do.call(rbind, rr)
  ok <- complete.cases(M)
  results[[nm]] <- M
  cat(sprintf("%-18s %8.4f %8.4f %8.4f %8.4f %8d\n", nm,
              mean(M[ok,"r2"]), sd(M[ok,"r2"]), mean(M[ok,"mae"]), mean(M[ok,"rmse"]), sum(ok)))
}
saveRDS(results, "A2_archs.rds")
