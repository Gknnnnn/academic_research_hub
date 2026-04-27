# =============================================================================
# IGI Global — Eurasian Energy Chapter
# Script 02: IMF WEO Fiscal Balance Data
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-22
# Variable: General government net lending/borrowing (% GDP) = GGXCNL_NGDP
# =============================================================================

# Install if needed:
# install.packages("imfr")

library(imfr)
library(dplyr)
library(tidyr)

# -----------------------------------------------------------------------------
# 1. COUNTRY ISO codes (ISO2 for IMF API)
# -----------------------------------------------------------------------------
eurasian_iso2 <- c(
  "AM",  # Armenia
  "AZ",  # Azerbaijan
  "BY",  # Belarus
  "GE",  # Georgia
  "KZ",  # Kazakhstan
  "KG",  # Kyrgyzstan
  "MD",  # Moldova
  "MN",  # Mongolia
  "RU",  # Russia
  "TJ",  # Tajikistan
  "TM",  # Turkmenistan
  "TR",  # Türkiye
  "UA",  # Ukraine
  "UZ"   # Uzbekistan
)

# Mapping ISO2 → ISO3 for merge
iso_map <- data.frame(
  iso2 = eurasian_iso2,
  iso3c = c("ARM","AZE","BLR","GEO","KAZ","KGZ","MDA","MNG",
            "RUS","TJK","TKM","TUR","UKR","UZB")
)

# -----------------------------------------------------------------------------
# 2. DOWNLOAD VIA imfr
# -----------------------------------------------------------------------------
cat("Downloading IMF WEO fiscal balance data...\n")

# WEO database ID in IMF API
# Indicator: GGXCNL_NGDP = General government net lending/borrowing (% GDP)

tryCatch({
  # Check available databases
  # dbs <- imf_databases()

  # WEO data via imfr
  weo_raw <- imf_dataset(
    database_id = "WEO",
    indicator   = "GGXCNL_NGDP",
    country     = eurasian_iso2,
    start       = 2000,
    end         = 2022
  )

  cat("WEO raw dimensions:", nrow(weo_raw), "x", ncol(weo_raw), "\n")
  print(head(weo_raw))

  # Clean
  fiscal_weo <- weo_raw %>%
    rename(iso2 = ref_area, year = time_period, fiscal_weo = obs_value) %>%
    mutate(year = as.integer(year),
           fiscal_weo = as.numeric(fiscal_weo)) %>%
    left_join(iso_map, by = "iso2") %>%
    select(iso3c, year, fiscal_weo) %>%
    filter(!is.na(iso3c))

  cat("\nFiscal WEO dimensions:", nrow(fiscal_weo), "\n")
  cat("Missing fiscal_weo:", sum(is.na(fiscal_weo$fiscal_weo)), "\n")

}, error = function(e) {
  cat("imfr method failed:", e$message, "\n")
  cat("Trying direct WEO bulk download...\n")

  # Fallback: Direct WEO download from IMF website
  # WEO April 2023 bulk data
  weo_url <- "https://www.imf.org/en/Publications/WEO/weo-database/2023/April/download-entire-database"
  cat("Manual download required from:", weo_url, "\n")
  cat("Indicator code: GGXCNL_NGDP\n")
})

# -----------------------------------------------------------------------------
# 3. ALTERNATIVE: Use WDI fiscal proxy
# -----------------------------------------------------------------------------
cat("\n--- WDI Fallback: Central Government Balance ---\n")

library(WDI)

# GC.BAL.CASH.GD.ZS = Cash surplus/deficit (% GDP) — central gov only
# GC.NLD.TOTL.GD.ZS = Net lending (+) / net borrowing (–) (% GDP)
fiscal_wdi <- WDI(
  country   = c("ARM","AZE","BLR","GEO","KAZ","KGZ","MDA","MNG",
                "RUS","TJK","TKM","TUR","UKR","UZB"),
  indicator = c(
    fiscal_cash = "GC.BAL.CASH.GD.ZS",
    fiscal_net  = "GC.NLD.TOTL.GD.ZS"
  ),
  start = 2000,
  end   = 2022,
  extra = FALSE
)

fiscal_clean <- fiscal_wdi %>%
  select(iso3c, year, fiscal_cash, fiscal_net) %>%
  arrange(iso3c, year)

cat("WDI fiscal variables:\n")
miss_fiscal <- fiscal_clean %>%
  summarise(
    fiscal_cash_missing = round(sum(is.na(fiscal_cash)) / n() * 100, 1),
    fiscal_net_missing  = round(sum(is.na(fiscal_net))  / n() * 100, 1)
  )
print(miss_fiscal)

cat("\nCountry-level fiscal_cash availability:\n")
fiscal_clean %>%
  group_by(iso3c) %>%
  summarise(
    n_obs    = sum(!is.na(fiscal_cash)),
    mean_val = round(mean(fiscal_cash, na.rm=TRUE), 2)
  ) %>%
  print(n=14)

# -----------------------------------------------------------------------------
# 4. MERGE WITH MAIN PANEL
# -----------------------------------------------------------------------------
panel <- read.csv("panel_eurasian_energy_20260422.csv")

panel_v2 <- panel %>%
  left_join(fiscal_clean, by = c("iso3c", "year"))

cat("\nPanel v2 — fiscal variables added\n")
cat("fiscal_cash non-NA:", sum(!is.na(panel_v2$fiscal_cash)), "\n")
cat("fiscal_net non-NA:", sum(!is.na(panel_v2$fiscal_net)), "\n")

# -----------------------------------------------------------------------------
# 5. M6: FE — energy_dep → fiscal balance
# -----------------------------------------------------------------------------
library(fixest)

m6_fiscal <- tryCatch(
  feols(fiscal_cash ~ energy_dep + ln_gdppc + trade + inflation | iso3c + year,
        data = panel_v2, panel.id = ~iso3c + year, vcov = "DK"),
  error = function(e) { cat("M6 failed:", e$message, "\n"); NULL }
)

if (!is.null(m6_fiscal)) {
  cat("\n--- M6 DK: energy_dep → Fiscal Balance (cash) ---\n")
  print(summary(m6_fiscal))
}

# -----------------------------------------------------------------------------
# 6. SAVE
# -----------------------------------------------------------------------------
write.csv(panel_v2, "panel_eurasian_energy_v2_20260422.csv", row.names = FALSE)
cat("\nPanel v2 saved: panel_eurasian_energy_v2_20260422.csv\n")
cat("=== FISCAL SCRIPT COMPLETE ===\n")
