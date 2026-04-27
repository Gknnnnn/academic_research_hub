# ============================================================
# AI Strategy Carbon DiD — Data Pull (v0.1)
# Author: M. Gökhan Özdemir | 2026-04-09
# Sources: OWID CO2 data + OWID Energy data + OECD AI Policy Observatory
# ============================================================
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
})

OUT <- here::here("400-Data")  # run from project root
if (!dir.exists(file.path(OUT, "processed"))) dir.create(file.path(OUT, "processed"), recursive = TRUE)
if (!dir.exists(file.path(OUT, "raw")))       dir.create(file.path(OUT, "raw"),       recursive = TRUE)

# ── 1. AI Strategy adoption dates (OECD AI Policy Observatory) ───────────────
# Source: https://oecd.ai/en/dashboards/policy-instruments
# Hand-compiled 2026-04-09; verified against OECD country dashboards
ai_adoption <- tribble(
  ~iso_code, ~adopt_year,
  "AUT", 2021, "BEL", 2019, "BGR", 2020, "CAN", 2017,
  "CHL", 2021, "HRV", 2021, "CZE", 2019, "DNK", 2019,
  "EST", 2019, "FIN", 2017, "FRA", 2018, "DEU", 2018,
  "GRC", 2021, "HUN", 2020, "IND", 2018, "IRL", 2021,
  "ISR", 2021, "ITA", 2019, "JPN", 2019, "KOR", 2019,
  "LVA", 2020, "LTU", 2019, "LUX", 2019, "MLT", 2019,
  "MEX", 2018, "NLD", 2019, "NZL", 2019, "NOR", 2020,
  "POL", 2021, "PRT", 2019, "ROU", 2019, "SGP", 2019,
  "SVK", 2021, "SVN", 2021, "ESP", 2019, "SWE", 2018,
  "CHE", 2019, "TUR", 2021, "GBR", 2017, "USA", 2019
)

write_csv(ai_adoption, file.path(OUT, "raw/ai_adoption_dates.csv"))

# ── 2. OWID CO2 data ──────────────────────────────────────────────────────────
owid_co2 <- read_csv(
  "https://raw.githubusercontent.com/owid/co2-data/master/owid-co2-data.csv",
  show_col_types = FALSE
)

# ── 3. OWID Energy data (for renewable share) ─────────────────────────────────
owid_energy <- read_csv(
  "https://raw.githubusercontent.com/owid/energy-data/master/owid-energy-data.csv",
  show_col_types = FALSE
) %>%
  select(iso_code, year, renewables_share_energy)

# ── 4. Merge and construct panel ──────────────────────────────────────────────
co2_sel <- owid_co2 %>%
  filter(year >= 2000, year <= 2023) %>%
  filter(!is.na(iso_code), iso_code != "", !grepl("^OWID", iso_code)) %>%
  select(iso_code, country, year, co2_per_capita, gdp, population)

panel_raw <- co2_sel %>%
  left_join(owid_energy, by = c("iso_code", "year")) %>%
  left_join(ai_adoption, by = "iso_code")

# Filter to HI/UMI: GDP per capita > 4000 USD (2019) or treated
gdp_threshold <- panel_raw %>%
  filter(year == 2019, !is.na(gdp), !is.na(population)) %>%
  mutate(gdppc_2019 = gdp / population) %>%
  filter(gdppc_2019 > 4000) %>%
  pull(iso_code)

panel <- panel_raw %>%
  filter(iso_code %in% gdp_threshold | !is.na(adopt_year)) %>%
  filter(year >= 2005) %>%
  mutate(
    treated    = !is.na(adopt_year),
    post       = as.integer(treated & year >= adopt_year),
    event_time = ifelse(treated, year - adopt_year, NA_integer_),
    ln_co2pc   = log(pmax(co2_per_capita, 0.001)),
    ln_gdppc   = log(pmax(gdp / pmax(population, 1), 1)),
    # For CS did package: g = adoption year; 0 = never-treated (numeric)
    g          = ifelse(is.na(adopt_year), 0, as.numeric(adopt_year)),
    cid        = as.integer(factor(iso_code)),
    rel_time   = case_when(
      !treated         ~ NA_integer_,
      event_time <= -6 ~ -6L,
      event_time >= 5  ~ 5L,
      TRUE             ~ as.integer(event_time)
    )
  ) %>%
  group_by(iso_code) %>%
  filter(n() >= 10) %>%
  ungroup()

write_csv(panel, file.path(OUT, "processed/ai_strategy_panel.csv"))
saveRDS(panel,   file.path(OUT, "processed/ai_strategy_panel.rds"))

message("Panel saved: ", nrow(panel), " obs | ",
        length(unique(panel$iso_code)), " countries | treated=",
        sum(!duplicated(panel$iso_code[panel$treated])))
