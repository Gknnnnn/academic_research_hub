# ============================================================
# KG-MGO / Automation-LaborShare: ECI Computation from BACI
# Script 07 — Economic Complexity Index (ECI) for 14 Eurasian
# Date   : 2026-04-25 | Author: MGO
# Source : BACI HS92 V202601 (CEPII)
# Package: economiccomplexity (CRAN)
# Output : data/oec_eci_country_year.csv
# NOTE   : Large BACI files (>250MB) must be locally cached.
#          Files not cached on OneDrive are skipped gracefully.
# ============================================================

suppressPackageStartupMessages({
  library(data.table)
  library(economiccomplexity)
  library(dplyr)
  library(arrow)          # streaming CSV read — no mmap, handles OneDrive files
})

# ---- 0. Paths ----
BACI_DIR  <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/1. Documents/BACI_HS92_V202601"
OUT_FILE  <- "data/oec_eci_country_year.csv"
YEARS     <- 2000:2022

# ---- 1. Eurasian country BACI codes ----
eurasian_codes <- c(
  ARM = 51, AZE = 31, BLR = 112, GEO = 268, KAZ = 398,
  KGZ = 417, MDA = 498, MNG = 496, RUS = 643, TJK = 762,
  TUR = 792, TKM = 795, UKR = 804, UZB = 860
)

code_map <- data.frame(iso3     = names(eurasian_codes),
                       iso3_baci = as.integer(eurasian_codes))

# ---- 2. Main loop: compute ECI per year ----
eci_list   <- vector("list", length(YEARS))
skipped    <- character(0)

for (yr in YEARS) {
  idx <- which(YEARS == yr)
  cat(sprintf("[%d/%d] BACI year %d ...\n", idx, length(YEARS), yr))

  f <- file.path(BACI_DIR, sprintf("BACI_HS92_Y%d_V202601.csv", yr))
  if (!file.exists(f)) {
    cat("  ⚠️  File not found, skipping\n")
    skipped <- c(skipped, as.character(yr)); next
  }

  # arrow::read_csv_arrow: streaming read, no mmap — works with OneDrive files
  dt <- tryCatch({
    raw <- read_csv_arrow(f, col_select = c("i", "k", "v"),
                          schema = schema(i = int32(), k = utf8(), v = float64(),
                                          t = int32(), j = int32(), q = float64()),
                          read_options = CsvReadOptions$create(skip_rows_after_names = 0))
    as.data.table(raw)
  }, error = function(e) {
    cat(sprintf("  ⚠️  Read error: %s\n", conditionMessage(e)))
    skipped <<- c(skipped, as.character(yr))
    NULL
  })
  if (is.null(dt)) next

  dt <- dt[, .(export_val = sum(v, na.rm = TRUE)), by = .(i, k)]

  # Convert to wide matrix (countries × products)
  mat_wide <- dcast(dt, i ~ k, value.var = "export_val", fill = 0)
  row_ids  <- mat_wide$i
  mat      <- as.matrix(mat_wide[, -1])
  rownames(mat) <- as.character(row_ids)
  mat <- mat[rowSums(mat) > 0, colSums(mat) > 0]

  # Compute RCA (Balassa 1965) and ECI (Hidalgo & Hausman 2009)
  rca     <- balassa_index(mat, discrete = FALSE)
  eci_raw <- complexity_measures(rca)

  eci_vec <- eci_raw$complexity_index_country
  eci_df  <- data.frame(
    iso3_baci = as.integer(names(eci_vec)),
    eci       = as.numeric(eci_vec),
    year      = yr
  )

  eci_df <- merge(eci_df, code_map, by = "iso3_baci", all.x = FALSE)
  eci_list[[idx]] <- eci_df
  cat(sprintf("  ✅  %d Eurasian obs\n", nrow(eci_df)))
}

# ---- 3. Stack and save (whatever was computed) ----
valid <- Filter(Negate(is.null), eci_list)
if (length(valid) == 0) {
  cat("\n❌ No years computed — all BACI files unavailable locally.\n")
  cat("   → Run OneDrive sync, then re-run this script.\n")
  quit(status = 1)
}

eci_panel <- rbindlist(valid, use.names = TRUE, fill = TRUE)
setnames(eci_panel, "iso3", "country_iso3")
eci_panel[, eci_std := scale(eci), by = year]
setorder(eci_panel, country_iso3, year)
fwrite(eci_panel, OUT_FILE)

cat("\n=== ECI Panel Saved ===\n")
cat("File    :", OUT_FILE, "\n")
cat("Rows    :", nrow(eci_panel), "\n")
cat("Countries:", length(unique(eci_panel$country_iso3)), "\n")
cat("Years computed:", paste(sort(unique(eci_panel$year)), collapse = ", "), "\n")
if (length(skipped) > 0)
  cat("⚠️  Skipped (not cached):", paste(skipped, collapse = ", "), "\n")
cat("\n")

print(eci_panel[country_iso3 %in% c("TUR","RUS","KAZ") & year %in% unique(eci_panel$year)[1:3],
                .(country_iso3, year, eci, eci_std)])
