suppressPackageStartupMessages({library(ARDL); library(readxl)})
raw <- read_excel('data/turkey_climate_agri_1970_2021.xlsx', sheet='Sayfa1')
names(raw) <- c('year','alan_raw','ava','co2_raw','tsso_raw','tsa','pr')
co2pc <- read.csv('/tmp/turkey_co2pc_wb.csv')
names(co2pc) <- c('year','co2pc'); co2pc$year <- as.integer(co2pc$year)
df <- merge(raw, co2pc, by='year'); df <- df[order(df$year),]
df$lnAVA  <- log(df$ava); df$lnPR <- log(df$pr); df$lnTSA <- log(df$tsa)
df$lnTSSO <- log(df$tsso_raw); df$lnALAN <- log(df$alan_raw/10); df$lnCO2 <- log(df$co2pc)
vts   <- ts(df[,c('lnAVA','lnPR','lnTSA','lnTSSO','lnALAN','lnCO2')], start=1970, freq=1)
vts80 <- window(vts, start=1980, end=2021)

m_r1 <- ardl(lnAVA ~ lnPR + lnTSA + lnTSSO + lnALAN, data=vts, order=c(4,0,1,0,2))
m_r2 <- ardl(lnAVA ~ lnPR + lnTSA + lnTSSO + lnCO2,  data=vts, order=c(4,0,1,0,2))
m_r3 <- ardl(lnAVA ~ lnPR + lnTSA + lnTSSO + lnALAN + lnCO2, data=vts80, order=c(4,0,1,0,2,0))

fmt_lr <- function(lr) {
  for (i in 2:nrow(lr)) {
    sig <- ifelse(lr$Pr[i]<0.01,'***',ifelse(lr$Pr[i]<0.05,'**',ifelse(lr$Pr[i]<0.10,'*','')))
    cat(sprintf('  %-10s %+7.4f%s SE=%6.4f t=%6.3f p=%.4f\n',
                lr$Term[i], lr$Estimate[i], sig, lr$Std.Error[i], lr$t.value[i], lr$Pr[i]))
  }
}
cat("R1:\n"); fmt_lr(multipliers(m_r1, type='lr', se=TRUE))
cat("R2:\n"); fmt_lr(multipliers(m_r2, type='lr', se=TRUE))
cat("R3:\n"); fmt_lr(multipliers(m_r3, type='lr', se=TRUE))

# ECTs
u1 <- uecm(m_r1); u2 <- uecm(m_r2); u3 <- uecm(m_r3)
cat("\nECTs:\n")
cat("R1:", round(coef(u1)['L(lnAVA, 1)'],4), " SE=",
    round(summary(u1)$coef['L(lnAVA, 1)','Std. Error'],4), "\n")
cat("R2:", round(coef(u2)['L(lnAVA, 1)'],4), " SE=",
    round(summary(u2)$coef['L(lnAVA, 1)','Std. Error'],4), "\n")
cat("R3:", round(coef(u3)['L(lnAVA, 1)'],4), " SE=",
    round(summary(u3)$coef['L(lnAVA, 1)','Std. Error'],4), "\n")
cat("F-stats: R1=", round(bounds_f_test(m_r1, case=3)$statistic,3),
    " R2=", round(bounds_f_test(m_r2, case=3)$statistic,3),
    " R3=", round(bounds_f_test(m_r3, case=3)$statistic,3), "\n")
