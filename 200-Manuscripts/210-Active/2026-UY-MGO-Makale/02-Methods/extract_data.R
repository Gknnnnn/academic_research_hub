library(WDI)
library(dplyr)
library(tidyr)

gostergeler <- c(
  ihracat = "NE.EXP.GNFS.KD",
  reer = "PX.REX.REER",
  gsyh = "NY.GDP.MKTP.KD",
  hukuk = "RL.EST",
  regulasyon = "RQ.EST"
)

cat("Fetching country data...\n")
yeni_veri <- WDI(
  indicator = gostergeler,
  start = 2000,
  end = 2022,
  extra = TRUE
)

cat("Fetching World GDP data...\n")
dunya_veri <- WDI(
  country = "WLD",
  indicator = c(world_gsyh = "NY.GDP.MKTP.KD"),
  start = 2000,
  end = 2022,
  extra = FALSE
)

# Merge
dunya_gsyh <- dunya_veri %>%
  select(year, world_gsyh) %>%
  mutate(ln_world_gsyh = log(world_gsyh))

analiz_verisi_full <- yeni_veri %>%
  filter(region != "Aggregates") %>%
  drop_na(hukuk, reer, ihracat, gsyh, income) %>%
  left_join(dunya_gsyh, by = "year") %>%
  mutate(
    ln_ihracat = log(ihracat),
    ln_reer = log(reer),
    ln_gsyh = log(gsyh)
  )

gelismekte_olan_veri <- analiz_verisi_full %>%
  filter(income != "High income")

# Check if we have standard columns
cat("Columns in analiz_verisi_full:", paste(names(analiz_verisi_full), collapse=", "), "\n")
cat("Rows in gelismekte_olan_veri:", nrow(gelismekte_olan_veri), "\n")
cat("Sample ln_world_gsyh:", head(analiz_verisi_full$ln_world_gsyh, 2), "\n")

write.csv(analiz_verisi_full, "data/analiz_verisi_full.csv", row.names = FALSE)
write.csv(gelismekte_olan_veri, "data/gelismekte_olan_veri.csv", row.names = FALSE)
cat("Done.\n")
