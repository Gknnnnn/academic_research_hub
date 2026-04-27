## ============================================================
## 2026-CE-Cognitive-Econometrics
## Script 01 — Bilişsel Önyargı Endeksi (CBI) inşası
## Author : Dr. M. Gökhan Özdemir
## Date   : 2026-04-08 (revize)
## Input  : 400-Data/raw/EB/{ZA7781,ZA7952,ZA8779,ZA8842}.dta
## Output : 400-Data/processed/CBI_country_year.{rds,csv}
##          600-Results/CE_pilot/pca_loadings.csv
##
## Mimari: Repeated cross-sections → ülke-yıl boyut ortalamaları → PCA
## Bireysel PCA mümkün değil (farklı dalgalarda farklı sorular, farklı kişiler)
## ============================================================

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(janitor)
  library(srvyr)
  library(psych)
})

set.seed(20260408)

RAW  <- "400-Data/raw/EB"
PROC <- "400-Data/processed"
RESU <- "600-Results/CE_pilot"
dir.create(PROC, showWarnings = FALSE, recursive = TRUE)
dir.create(RESU, showWarnings = FALSE, recursive = TRUE)

## ---- 1. Dalga tanımları ----
## Her dalga: hangi CBI boyutu, hangi q_kodu, yıl, skor yönü
## recode:
##   likert4_direct : (raw-1)/3 için raw∈1:4, DK(5)→NA; yüksek = yüksek önyargı
##   likert4_reverse: (4-raw)/3 için raw∈1:4, DK(5)→NA; 1=agree=yüksek önyargı → flip
##   binary_direct  : raw∈{0,1}; 1 = yüksek önyargı
##   binary_flip    : raw∈{0,1}; 0 = yüksek önyargı → 1-raw
##   yn_no_biased   : raw∈{1=Yes,2=No,3=DK}; No(2)=yüksek önyargı → recode 0/1/NA
##   fossil_recode  : qb11 özel; 1=fossil=1, 2=green=0, 3=both=0.5, 4=DK=NA

wave_items <- tribble(
  ~item, ~dim,              ~wave_id,  ~wave_year, ~q_code, ~recode,
  # Status Quo Bias
  "SQ1", "status_quo",     "ZA7781",  2021L,      "qb11",  "fossil_recode",
  "SQ2", "status_quo",     "ZA8842",  2024L,      "qb8",   "yn_no_biased",
  # Loss Aversion (disagree = cost-averse toward transition)
  "LA1", "loss_aversion",  "ZA7781",  2021L,      "qb4_3", "likert4_direct",
  "LA2", "loss_aversion",  "ZA7781",  2021L,      "qb4_6", "likert4_direct",
  # Bounded Cognition
  "BC1", "bounded_cogn",   "ZA7781",  2021L,      "qb3_5", "binary_flip",
  "BC2", "bounded_cogn",   "ZA7952",  2022L,      "qc3_2", "likert4_direct",
  # Present Bias
  "PB1", "present_bias",   "ZA7781",  2021L,      "qb5",   "yn_no_biased",
  "PB2", "present_bias",   "ZA7952",  2022L,      "qc3_5", "likert4_direct",
  # Optimism Bias (delegate = others will solve it)
  "OP1", "optimism",       "ZA7781",  2021L,      "qb3_1", "binary_direct",
  "OP2", "optimism",       "ZA8842",  2024L,      "qb6_2", "binary_flip"
)

## ---- 2. Dalga yükleme ----
wave_files <- c(
  ZA7781 = "ZA7781_v2.dta",
  ZA7952 = "ZA7952_v1-0-0.dta",
  ZA8779 = "ZA8779_v1-0-0.dta",  # CBI maddesi yok — yükleme atlanacak
  ZA8842 = "ZA8842_v1-0-0.dta"
)

needed_waves <- unique(wave_items$wave_id)

waves_raw <- map(needed_waves, function(wid) {
  fp <- file.path(RAW, wave_files[wid])
  if (!file.exists(fp)) { warning("Eksik dalga: ", wid); return(NULL) }
  cat("Yükleniyor:", wid, "\n")
  haven::read_dta(fp) |> janitor::clean_names()
}) |> set_names(needed_waves)

## ---- 3. Item'ı dalgadan çek ve ülke-düzeyinde ortala ----
recode_item <- function(raw_vec, recode_type) {
  x <- as.numeric(raw_vec)
  switch(recode_type,
    likert4_direct  = ifelse(x <= 4, (x - 1) / 3, NA_real_),
    likert4_reverse = ifelse(x <= 4, (4 - x) / 3, NA_real_),
    binary_direct   = ifelse(x %in% c(0, 1), x,       NA_real_),
    binary_flip     = ifelse(x %in% c(0, 1), 1 - x,   NA_real_),
    yn_no_biased    = case_when(x == 1 ~ 0, x == 2 ~ 1, TRUE ~ NA_real_),
    fossil_recode   = case_when(x == 1 ~ 1, x == 2 ~ 0,
                                x == 3 ~ 0.5, TRUE ~ NA_real_),
    stop("Bilinmeyen recode tipi: ", recode_type)
  )
}

extract_country_means <- function(row) {
  wid  <- row$wave_id
  df   <- waves_raw[[wid]]
  if (is.null(df)) return(tibble())

  qc <- row$q_code
  if (!qc %in% names(df)) {
    warning(sprintf("%-10s : %s bulunamadı", wid, qc))
    return(tibble())
  }

  # Ağırlık değişkeni (w1 öncelikli)
  wt_var <- names(df)[names(df) %in% c("w1","wex","weight")][1]
  wt <- if (!is.na(wt_var)) as.numeric(df[[wt_var]]) else rep(1, nrow(df))
  wt[is.na(wt) | wt <= 0] <- 1

  # Ülke (ISO iki harfli kod — isocntry öncelikli)
  cnt_var <- if ("isocntry" %in% names(df)) "isocntry" else
             if ("nation"   %in% names(df)) "nation"   else "country"
  cnt <- as.character(df[[cnt_var]])

  score <- recode_item(df[[qc]], row$recode)

  tibble(
    isocntry = cnt,
    score    = score,
    weight   = wt
  ) |>
    filter(!is.na(score), isocntry != "") |>
    # Almanya: DE-E / DE-W → DE olarak birleştir
    mutate(isocntry = if_else(startsWith(isocntry, "DE"), "DE", isocntry)) |>
    filter(nchar(isocntry) == 2) |>
    group_by(isocntry) |>
    summarise(
      item_mean = weighted.mean(score, weight, na.rm = TRUE),
      n_obs     = n(),
      .groups   = "drop"
    ) |>
    mutate(
      item      = row$item,
      dim       = row$dim,
      wave_id   = wid,
      wave_year = row$wave_year
    )
}

cat("\n--- Item çekme ---\n")
item_cy <- map_dfr(seq_len(nrow(wave_items)),
                   ~extract_country_means(wave_items[.x, ]))

cat("Toplam satır:", nrow(item_cy), "\n")
cat("Ülkeler:", n_distinct(item_cy$isocntry), "\n")
print(item_cy |> count(item, wave_year))

## ---- 4. Boyut ortalamaları (ülke-yıl) ----
dim_cy <- item_cy |>
  group_by(isocntry, wave_year, dim) |>
  summarise(dim_mean = mean(item_mean, na.rm = TRUE),
            n_items  = n(),
            .groups  = "drop")

## Geniş format: her boyut bir sütun
dim_wide <- dim_cy |>
  pivot_wider(names_from  = dim,
              values_from = c(dim_mean, n_items))

cat("\nBoyut-yıl özeti:\n")
print(dim_wide |> count(wave_year))

## ---- 5. PCA — ülke-yıl havuzu ----
dim_cols <- paste0("dim_mean_",
                   c("status_quo","loss_aversion","bounded_cogn",
                     "present_bias","optimism"))

pca_mat <- dim_wide |>
  select(all_of(intersect(dim_cols, names(dim_wide)))) |>
  as.matrix()

# Sadece tam vaka satırları
complete_rows <- complete.cases(pca_mat)
cat("PCA tam vaka sayısı:", sum(complete_rows), "/", nrow(pca_mat), "\n")

kmo_res   <- psych::KMO(pca_mat[complete_rows, ])
alpha_res <- psych::alpha(pca_mat[complete_rows, ], check.keys = TRUE)
pca_res   <- psych::principal(pca_mat[complete_rows, ], nfactors = 1,
                               rotate = "none", scores = TRUE)

cat("KMO overall:", round(kmo_res$MSA, 3), "\n")
cat("Cronbach alpha:", round(alpha_res$total$raw_alpha, 3), "\n")
cat("PC1 varyans payı:", round(pca_res$Vaccounted[2, 1] * 100, 1), "%\n")

loadings_tbl <- tibble(
  dim    = rownames(pca_res$loadings),
  pc1    = as.numeric(pca_res$loadings[, 1])
) |>
  mutate(weight_norm = pc1 / sum(abs(pc1)))

write.csv(loadings_tbl, file.path(RESU, "pca_loadings.csv"), row.names = FALSE)
cat("\nPC1 loadings:\n"); print(loadings_tbl)

## ---- 6. CBI skorunu ülke-yıl paneline ekle ----
cbi_scores <- rep(NA_real_, nrow(dim_wide))
cbi_scores[complete_rows] <- as.numeric(pca_res$scores[, 1])

# Equal-weight alternatif
cbi_eq <- rowMeans(pca_mat, na.rm = TRUE)

cbi_cy <- dim_wide |>
  mutate(
    CBI_pca = cbi_scores,
    CBI_eq  = cbi_eq,
    CBI_pca_z = as.numeric(scale(cbi_scores)),
    CBI_eq_z  = as.numeric(scale(cbi_eq))
  )

saveRDS(cbi_cy, file.path(PROC, "CBI_country_year.rds"))
write.csv(cbi_cy, file.path(PROC, "CBI_country_year.csv"), row.names = FALSE)

cat("\n=== CBI inşası tamamlandı ===\n")
cat("Ülke-yıl hücreleri :", nrow(cbi_cy), "\n")
cat("CBI_pca dolu hücre :", sum(!is.na(cbi_cy$CBI_pca)), "\n")
cat("Dalgalar           :", paste(sort(unique(cbi_cy$wave_year)), collapse=", "), "\n")

## ---- 7. Özet istatistikler ----
cat("\nCBI_pca özet:\n")
print(summary(cbi_cy$CBI_pca_z))
cat("\nÜlke-yıl tablosu:\n")
print(cbi_cy |> select(isocntry, wave_year, CBI_pca_z) |>
      arrange(wave_year, isocntry) |> head(30))
