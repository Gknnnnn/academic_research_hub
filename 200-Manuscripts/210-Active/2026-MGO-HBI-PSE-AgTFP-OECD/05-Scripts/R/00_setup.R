# 00_setup.R — Package installation & global settings
# PSE × AgTFP OECD Panel | MGO × HBI | 2026-04-20

options(scipen = 999, digits = 4)

pkgs <- c(
  # Panel data & inference
  "plm", "lmtest", "sandwich", "clubSandwich",
  # Second-generation panel tests (xtdcce2 equivalent in R)
  "pdynmc", "pwt10",
  # Unit root & cointegration
  "urca", "CADFtest",
  # CS-ARDL / AMG / CCEMG (Eberhardt toolkit)
  "ARDL", "dyn", "dynlm",
  # Dumitrescu-Hurlin causality
  "plm",
  # Webb wild cluster bootstrap
  "fwildclusterboot",
  # Data wrangling
  "tidyverse", "data.table",
  # Tables
  "stargazer", "xtable", "knitr", "kableExtra",
  # Visualization
  "ggplot2", "patchwork"
)

# Install missing packages
new_pkgs <- pkgs[!pkgs %in% installed.packages()[,"Package"]]
if (length(new_pkgs) > 0) {
  message("Installing: ", paste(new_pkgs, collapse=", "))
  install.packages(new_pkgs, repos = "https://cloud.r-project.org")
}

# xtdcce2 / CD / CIPS not natively in CRAN; use Stata-equivalent via:
# R package 'pdynmc' for system-GMM
# For CIPS: use CADFtest or manual CIPS implementation below

# Paths — CLI-safe
script_args <- commandArgs(trailingOnly = FALSE)
file_arg    <- grep("--file=", script_args, value = TRUE)
if (length(file_arg) > 0) {
  SCRIPT_DIR <- normalizePath(dirname(sub("--file=", "", file_arg)))
} else {
  SCRIPT_DIR <- normalizePath(".")
}
BASE <- normalizePath(file.path(SCRIPT_DIR, "../.."))
DATA  <- file.path(BASE, "06-Data", "clean", "panel_master.csv")
TBLS  <- file.path(BASE, "03-Results", "tables")
FIGS  <- file.path(BASE, "03-Results", "figures")
dir.create(TBLS, recursive=TRUE, showWarnings=FALSE)
dir.create(FIGS, recursive=TRUE, showWarnings=FALSE)

cat("Setup complete. Data path:", DATA, "\n")
