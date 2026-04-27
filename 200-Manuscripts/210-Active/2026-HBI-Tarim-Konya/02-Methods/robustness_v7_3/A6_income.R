suppressPackageStartupMessages({ library(neuralnet); library(parallel) })
setwd("/tmp/hbi_rds")
v <- readRDS("veri_tam_panel.rds")
m <- readRDS("model_verisi.rds")
ug <- readRDS("ulke_gruplari_listesi.rds")
# ug: tbl with country, iso3c, income, region, Gelir_Grubu
# model_verisi rows align with veri_tam_panel rows (both 2205)
stopifnot(nrow(m)==nrow(v))
m$iso3c <- v$iso3c
m$year  <- v$year
m <- merge(m, ug[,c("iso3c","Gelir_Grubu","income")], by="iso3c", all.x=TRUE)

cat("Income groups table:\n")
print(table(m$Gelir_Grubu))

frm <- tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman
grps <- sort(unique(m$Gelir_Grubu))

fit_one <- function(s, sub) {
  set.seed(s)
  idx <- sample(seq_len(nrow(sub)), floor(0.7*nrow(sub)))
  tr <- sub[idx,c("tarim_gsyh","emek","toprak","gubre","verim","ticaret","ekipman")]
  te <- sub[-idx,c("tarim_gsyh","emek","toprak","gubre","verim","ticaret","ekipman")]
  nn <- try(neuralnet(frm, data=tr, hidden=c(7,5), algorithm="rprop+", linear.output=TRUE, stepmax=1e5, threshold=0.05), silent=TRUE)
  if (inherits(nn,"try-error") || is.null(nn$weights)) return(c(r2=NA,mae=NA,rmse=NA))
  p <- as.numeric(predict(nn, te[,-1])); y <- te$tarim_gsyh
  c(r2=1-sum((y-p)^2)/sum((y-mean(y))^2), mae=mean(abs(y-p)), rmse=sqrt(mean((y-p)^2)))
}

cat(sprintf("\n%-25s %6s %8s %8s %8s\n","Income group","N","R2_mean","R2_sd","N_countries"))
for (g in grps) {
  sub <- m[m$Gelir_Grubu==g,]
  nc <- length(unique(sub$iso3c))
  seeds <- 1:10
  rr <- mclapply(seeds, fit_one, sub=sub, mc.cores=4)
  M <- do.call(rbind, rr); ok <- complete.cases(M)
  cat(sprintf("%-25s %6d %8.4f %8.4f %8d\n", g, nrow(sub), mean(M[ok,"r2"]), sd(M[ok,"r2"]), nc))
  saveRDS(M, sprintf("A6_%s.rds", gsub("[^A-Za-z0-9]","_",g)))
}
