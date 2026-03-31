# Primary Economics Research Hub - Base Econometrics Loader
# Dr. Özdemir - Standard Library for Q1-level Research

# List of essential econometric packages
packages <- c(
  "plm",          # Linear Panel Models
  "fixest",       # High-dimensional Fixed Effects (Fastest)
  "vars",         # Vector Autoregression
  "urca",         # Unit Root and Cointegration Tests
  "modelsummary", # Professional Table Exports (LaTeX/HTML/Docx)
  "ggplot2",      # Premium Data Visualization
  "dplyr",        # Data Tidying
  "tidyr",        # Data Tidying
  "sandwich",     # Robust Standard Errors
  "lmtest"        # Inference Testing
)

# Function to check and install missing packages
load_packages <- function(pkgs) {
  new_pkgs <- pkgs[!(pkgs %in% installed.packages()[, "Package"])]
  if (length(new_pkgs)) {
    message(f"Installing missing packages: {paste(new_pkgs, collapse = ', ')}")
    install.packages(new_pkgs, repos = "https://cloud.r-project.org")
  }
  for (pkg in pkgs) {
    library(pkg, character.only = TRUE)
  }
  message("All econometric libraries loaded successfully.")
}

load_packages(packages)

# Set global theme for graphics (Premium Aesthetics - Theme Minimal)
library(ggplot2)
theme_set(theme_minimal(base_size = 12))

message("--- Research Ecosystem: Econometric Environment Ready ---")
