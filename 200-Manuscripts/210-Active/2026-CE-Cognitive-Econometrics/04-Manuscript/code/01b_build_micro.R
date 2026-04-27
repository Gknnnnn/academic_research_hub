## ============================================================
## Script 01b — Bireysel mikro veri seti inşası
## Author : Dr. M. Gökhan Özdemir | 2026-04-08
## Input  : 400-Data/raw/EB/ZA7781_v2.dta (EB 95.1, 2021, N=26,669)
## Output : 400-Data/processed/CBI_micro.rds + CBI_micro.csv
## ============================================================
## Değişken haritası (ZA7781):
##  CE_Action  = qb6_14 (waste reduction/separation) OR qb6_15 (less disposables)
##  CBI items (bireysel, her biri 0-1):
##    SQ: qb11  (status-quo bias — fossil=1, green=0, binary_flip: green=1=not biased)
##    LA1: qb4_3 (cost perception: Likert4 direct — agree=high loss aversion)
##    LA2: qb4_6 (public finance support: Likert4 direct)
##    BC:  qb3_5 (personal responsibility: binary_flip — 1=delegates=biased)
##    PB:  qb5   (personal action: binary_direct — No=present_bias=1)
##    OP:  qb3_1 (national govt responsible → optimism-delegation)
##  Demographics:
##    age      = d11 (exact), edu_age = d8 (school-leaving age)
##    female   = d10 (1=Man→0, 2=Woman→1, 3=NonBin→NA)
##    urban    = d25 (1=rural, 2=small, 3=large)
##    polit_lr = d1  (1-10 left-right)
##    country  = isocntry
##    weight   = w1
## ============================================================

suppressPackageStartupMessages({
  library(haven); library(dplyr); library(psych)
})
set.seed(20260408)

PROJ <- "."  # run from project root
RAW  <- file.path(PROJ, "400-Data/raw/EB")
PROC <- file.path(PROJ, "400-Data/processed")
RESU <- file.path(PROJ, "600-Results/CE_pilot")

## ---- 1. Yükle ----
cat("ZA7781 yükleniyor...\n")
za <- haven::read_dta(file.path(RAW, "ZA7781_v2.dta")) |>
  janitor::clean_names()
cat("N_raw =", nrow(za), "  K =", ncol(za), "\n")

## ---- 2. Yeniden kodlama yardımcıları ----
lk4_direct  <- function(x) { x <- as.numeric(x); ifelse(x<=4, (x-1)/3, NA_real_) }
lk4_reverse <- function(x) { x <- as.numeric(x); ifelse(x<=4, (4-x)/3, NA_real_) }
bin_direct  <- function(x) { x <- as.numeric(x); ifelse(x%in%c(0,1), x,    NA_real_) }
bin_flip    <- function(x) { x <- as.numeric(x); ifelse(x%in%c(0,1), 1-x,  NA_real_) }
yn_no_bias  <- function(x) { x <- as.numeric(x); case_when(x==1~0,x==2~1,TRUE~NA_real_) }
fossil_rc   <- function(x) { x <- as.numeric(x); case_when(x==1~1,x==2~0,x==3~0.5,TRUE~NA_real_) }

## ---- 3. CBI bireysel skorlar ----
micro <- za |>
  transmute(
    id       = row_number(),
    country  = as.character(isocntry),
    wave_yr  = 2021L,
    weight   = ifelse(is.na(w1)|w1<=0, 1, as.numeric(w1)),
    # CBI boyutları
    SQ       = fossil_rc(qb11),
    LA1      = lk4_direct(qb4_3),
    LA2      = lk4_direct(qb4_6),
    BC       = bin_flip(qb3_5),     # 0=accepts personal resp (not biased), 1=delegates (biased)
    PB       = yn_no_bias(qb5),     # 0=takes action, 1=no personal action (present-biased)
    OP       = bin_direct(qb3_1),   # 1=thinks govt responsible (delegates, optimistic)
    # CE davranışı (bağımlı değişken)
    ce_waste  = as.integer(as.numeric(qb6_14) == 1),  # reduce/separate waste
    ce_disp   = as.integer(as.numeric(qb6_15) == 1),  # less disposable items
    CE_Action = as.integer(ce_waste == 1 | ce_disp == 1),
    # Demografik
    age      = ifelse(as.numeric(d11)>=15 & as.numeric(d11)<=97, as.numeric(d11), NA_real_),
    edu_age  = ifelse(as.numeric(d8)>=2   & as.numeric(d8)<=80,  as.numeric(d8),  NA_real_),
    female   = case_when(as.numeric(d10)==1~0L, as.numeric(d10)==2~1L, TRUE~NA_integer_),
    urban    = as.integer(as.numeric(d25)),
    polit_lr = ifelse(as.numeric(d1)>=1 & as.numeric(d1)<=10, as.numeric(d1), NA_real_)
  ) |>
  # Almanya DE-E / DE-W → DE
  mutate(country = ifelse(startsWith(country,"DE"), "DE", country)) |>
  filter(nchar(country)==2, country!="")

cat("N_micro (temizlendi):", nrow(micro), "\n")

## ---- 4. Bireysel PCA ile CBI_pca_z ----
cbi_mat <- micro |>
  select(SQ, LA1, LA2, BC, PB, OP) |>
  as.matrix()

complete_i <- complete.cases(cbi_mat)
cat("PCA tam vaka:", sum(complete_i), "/", nrow(cbi_mat), "\n")

# PCA
pca_res <- psych::principal(cbi_mat[complete_i, ], nfactors=1, rotate="none")
cat("PC1 varyans payı:", round(pca_res$Vaccounted[2,1]*100, 1), "%\n")
loadings_df <- data.frame(dim=rownames(pca_res$loadings),
                          pc1=as.numeric(pca_res$loadings[,1]))
print(loadings_df)

# Equal weight
cbi_eq <- rowMeans(cbi_mat, na.rm=TRUE)

# Skor atama
cbi_pca <- rep(NA_real_, nrow(micro))
cbi_pca[complete_i] <- as.numeric(pca_res$scores[,1])

micro <- micro |>
  mutate(
    CBI_pca   = cbi_pca,
    CBI_eq    = cbi_eq,
    CBI_pca_z = as.numeric(scale(cbi_pca)),
    CBI_eq_z  = as.numeric(scale(cbi_eq))
  )

## ---- 5. Özet ----
cat("\nCE_Action dağılımı:\n")
print(table(micro$CE_Action, useNA="always"))
cat("\nCBI_pca_z özet:\n")
print(summary(micro$CBI_pca_z))
cat("\nÜlke sayısı:", n_distinct(micro$country), "\n")
cat("CBI tam vaka:", sum(!is.na(micro$CBI_pca_z)), "\n")

## ---- 6. Kayıt ----
saveRDS(micro, file.path(PROC, "CBI_micro.rds"))
write.csv(micro, file.path(PROC, "CBI_micro.csv"), row.names=FALSE)
write.csv(loadings_df, file.path(RESU, "pca_loadings_micro.csv"), row.names=FALSE)
cat("\n=== CBI_micro.rds kaydedildi ===\n")
cat("N =", nrow(micro), "| ülke =", n_distinct(micro$country),
    "| wave =", unique(micro$wave_yr), "\n")
