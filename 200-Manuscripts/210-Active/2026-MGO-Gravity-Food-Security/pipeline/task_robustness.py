"""Robustness tasks — scripts 07-15.

All depend on panel_clean.rds. Run after main analysis.
Each produces a CSV/RDS that feeds into paper tables (Table A1-A5).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import pytask

from config import BLD_RDS, BLD_TABLES, SRC

PANEL_CLEAN = BLD_RDS / "panel_clean.rds"
PPML_MAIN = BLD_RDS / "ppml_main.rds"

_robustness_tasks = [
    # (script, produces, description)
    ("13_robustness_fta_leadlag.R",
     "rob_fta_leadlag.csv",
     "BYZ lead-lag: FTA endogeneity test (F=1.45, p=0.234)"),
    ("12_robustness_distance_timeseries.R",
     "rob_distance_timeseries.rds",
     "Year-by-year β(ln_dist) → Figure 1 (trend p=0.266 NS)"),
    ("07_robustness_heckman.R",
     "rob_heckman.csv",
     "Heckman selection correction for zero trade flows"),
    ("08_robustness_covid.R",
     "rob_covid.csv",
     "COVID robustness: exclude 2020"),
    ("09_robustness_subsample_hs.R",
     "rob_subsample_hs.csv",
     "HS-4 subsample robustness"),
    ("10_robustness_alternative_estimators.R",
     "rob_alt_estimators.csv",
     "OLS/NB/Gamma alternative estimators"),
    ("05_landlocked_pandemic.R",
     "rob_landlocked.csv",
     "Landlocked + pandemic heterogeneity"),
]

for script_name, produces_name, desc in _robustness_tasks:

    @pytask.task(id=script_name.replace(".R", ""))
    @pytask.mark.r(script=SRC / script_name)
    def task_robustness(
        script: Path = SRC / script_name,
        depends_on: Path = PANEL_CLEAN,
        produces: Path = BLD_TABLES / produces_name,
    ) -> None:
        pass

    task_robustness.__doc__ = desc
