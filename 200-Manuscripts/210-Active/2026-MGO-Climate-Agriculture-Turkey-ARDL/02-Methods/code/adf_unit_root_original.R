veri1 <- read_excel(file.choose())
names(veri1)
library(readxl)



# Y??l s??tunu hari?? di??erlerini ts'e d??n????t??r
veri_ts <- ts(veri1[ , -1],    # Y??l s??tununu ????kar??yoruz
              start = 1970,    # ilk g??zlem
              end   = 2021,    # son g??zlem
              frequency = 1)   # y??ll??k

# t??m s??tunlara log uygula
veri_ts_ln <- log(veri_ts)

veri_ts_ln

# Her seriyi ayr?? grafik olarak ??izelim
for (i in 1:ncol(veri_ts_ln)) {
  plot(veri_ts_ln[, i],
       main = paste("", colnames(veri_ts_ln)[i]),
       xlab = "Zaman",
       ylab = paste("l", colnames(veri_ts_ln)[i], "", sep=""),
       col = "blue")
}


library(urca)

# her de??i??ken i??in sabit+trendli ADF testi (lag=4 ??rnek)
for (var in colnames(veri_ts_ln)) {
  cat("\n====", var, "====\n")
  adf_result <- ur.df(veri_ts_ln[, var], type = "trend", lags = 4)
  print(summary(adf_result))
}

for (var in colnames(veri_ts_ln)) {
  cat("\n====", var, "====\n")
  adf_result <- ur.df(veri_ts_ln[, var], type = "drift", lags = 4)
  print(summary(adf_result))
}


# Gerekli paket
if (!requireNamespace("urca", quietly = TRUE)) install.packages("urca")
library(urca)

## === 1) Birinci fark?? al ===
# veri_ts_ln: 1970???2021, ??ok de??i??kenli ts (ln al??nm????) varsay??m??yla
d1_ts <- diff(veri_ts_ln)          # birinci fark
# Kolon adlar?? yerinde dursun (baz?? durumlarda kaybolabilir, garanti edelim)
colnames(d1_ts) <- colnames(veri_ts_ln)

## === 2) Parametreler ===
adf_type <- "drift"   # sabit+trendli (??nceki tercihine uygun)
lags     <- 4         # y??ll??k veri i??in makul; istersen de??i??tir

## === 3) T??m de??i??kenler i??in ADF (trendli) ve tablo ??retimi ===
adf_rows <- lapply(colnames(d1_ts), function(v) {
  x <- d1_ts[, v]
  fit <- ur.df(x, type = adf_type, lags = lags)
  
  # test istatisti??i ve kritik de??erleri ??ek
  # trendli modelde tau3 ve phi2/phi3 d??ner
  tau_stat <- as.numeric(fit@teststat["tau3"])
  cvals    <- fit@cval["tau3", c("1pct","5pct","10pct")]
  
  karar_5  <- ifelse(tau_stat < cvals["5pct"], "Dura??an (H0 reddedildi)", "Dura??an de??il")
  
  data.frame(
    Degisken = v,
    tau3     = round(tau_stat, 3),
    cval_1   = as.character(cvals["1pct"]),
    cval_5   = as.character(cvals["5pct"]),
    cval_10  = as.character(cvals["10pct"]),
    Gecikme  = lags,
    Model    = "Sabit",
    Karar_5  = karar_5,
    stringsAsFactors = FALSE
  )
})

adf_table <- do.call(rbind, adf_rows)

## === 4) Sonu??lar?? g??ster ===
print(adf_table, row.names = FALSE)

## (??stersen ayr??nt??l?? ??zetleri de g??rmek i??in a??a????y?? a??abilirsin)
for (v in colnames(d1_ts)) {
cat("\n====", v, "====\n")
print(summary(ur.df(d1_ts[, v], type = adf_type, lags = lags))) }

