suppressPackageStartupMessages({ library(neuralnet); library(parallel) })
setwd("/tmp/hbi_rds")
m <- readRDS("model_verisi.rds")
frm <- tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman

fit_one <- function(i, folds, data, hidden, thr, stp) {
  tr <- data[folds != i, ]; te <- data[folds == i, ]
  nn <- try(neuralnet(frm, data=tr, hidden=hidden, algorithm="rprop+",
                      linear.output=TRUE, stepmax=stp, threshold=thr), silent=TRUE)
  if (inherits(nn,"try-error") || is.null(nn$weights)) {
    # relax and retry
    nn <- neuralnet(frm, data=tr, hidden=hidden, algorithm="rprop+",
                    linear.output=TRUE, stepmax=stp*2, threshold=thr*5)
  }
  p <- as.numeric(predict(nn, te[,-1])); y <- te$tarim_gsyh
  c(r2=1-sum((y-p)^2)/sum((y-mean(y))^2), mae=mean(abs(y-p)), rmse=sqrt(mean((y-p)^2)))
}

run_cv <- function(k, data, hidden=c(7,5), thr=0.05, stp=1e5, seed=20260413, cores=4) {
  set.seed(seed)
  n <- nrow(data); folds <- sample(rep(1:k, length.out=n))
  res <- mclapply(1:k, fit_one, folds=folds, data=data, hidden=hidden, thr=thr, stp=stp, mc.cores=cores)
  do.call(rbind, res)
}

cat("A.1 k-Fold CV (6-7-5-1, Rprop+, thr=0.05, stepmax=1e5)\n")
for (k in c(5,10)) {
  t0 <- Sys.time()
  res <- run_cv(k, m)
  cat(sprintf("\n== k=%d (elapsed %.1fs) ==\n", k, as.numeric(difftime(Sys.time(),t0,units="secs"))))
  cat(sprintf("  R^2 : mean=%.4f sd=%.4f min=%.4f max=%.4f\n", mean(res[,"r2"]), sd(res[,"r2"]), min(res[,"r2"]), max(res[,"r2"])))
  cat(sprintf("  MAE : mean=%.4f sd=%.4f\n", mean(res[,"mae"]), sd(res[,"mae"])))
  cat(sprintf("  RMSE: mean=%.4f sd=%.4f\n", mean(res[,"rmse"]), sd(res[,"rmse"])))
  saveRDS(res, sprintf("A1_cv_k%d.rds", k))
}
