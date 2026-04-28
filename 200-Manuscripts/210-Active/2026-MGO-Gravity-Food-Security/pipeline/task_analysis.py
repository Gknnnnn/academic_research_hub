"""Main analysis tasks — PPML baseline + FTA interaction.

DAG:
  panel_clean.rds → 04_ppml_main.R    → ppml_main_results.rds
                  → 11b_fta_interaction.R → fta_interaction.rds
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import pytask

from config import BLD_RDS, BLD_TABLES, SRC

PANEL_CLEAN = BLD_RDS / "panel_clean.rds"


@pytask.mark.r(script=SRC / "02_baseline_ppml.R")
def task_baseline_ppml(
    script: Path = SRC / "02_baseline_ppml.R",
    depends_on: Path = PANEL_CLEAN,
    produces: Path = BLD_RDS / "ppml_baseline.rds",
) -> None:
    """Baseline PPML: ln_distance + ln_gdp_exp + ln_gdp_imp + FTA.

    Estimator: fixest::fepois, exporter-year + importer-year FEs.
    Cluster-robust SE at pair_id level.
    Key result: β(ln_dist) ≈ -0.75 (stable across perishable/durable).
    """


@pytask.mark.r(script=SRC / "04_ppml_main.R")
def task_ppml_main(
    script: Path = SRC / "04_ppml_main.R",
    depends_on: Path = PANEL_CLEAN,
    produces: Path = BLD_RDS / "ppml_main.rds",
) -> None:
    """Main PPML: perishability × FTA interaction (Table 2 in paper).

    Key result: FTA × perishable = +0.7337***, FTA × durable = +0.3800***
    Asymmetry Δ = +0.366 (p = 5.2e-06) — main finding.
    """


@pytask.mark.r(script=SRC / "11b_fta_interaction.R")
def task_fta_interaction(
    script: Path = SRC / "11b_fta_interaction.R",
    depends_on: Path = BLD_RDS / "ppml_main.rds",
    produces: Path = BLD_TABLES / "fta_interaction_wald.csv",
) -> None:
    """Wald test for FTA asymmetry: H0: β(FTA×P) = β(FTA×D).

    Result: Δ = 0.366, z = -4.56, p < 10⁻⁵ — confirms asymmetry.
    """


@pytask.mark.r(script=SRC / "03_sectoral_split.R")
def task_sectoral(
    script: Path = SRC / "03_sectoral_split.R",
    depends_on: Path = PANEL_CLEAN,
    produces: Path = BLD_TABLES / "sectoral_results.csv",
) -> None:
    """Sectoral PPML — perishable vs durable by HS-2 chapter groups."""
