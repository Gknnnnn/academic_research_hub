"""Figure generation tasks.

DAG:
  rob_distance_timeseries.rds → 12_robustness_distance_timeseries.R
                              → yearly_distance_coef.pdf  (Figure 1)

  panel_clean.rds → 16_network_centrality_sdm.R
                 → network_centrality_food.csv + top10_food_hubs.csv
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import pytask

from config import BLD_FIGURES, BLD_RDS, BLD_TABLES, SRC

TIMESERIES_RDS = BLD_TABLES / "rob_distance_timeseries.rds"
PANEL_CLEAN = BLD_RDS / "panel_clean.rds"


@pytask.mark.r(script=SRC / "12_robustness_distance_timeseries.R")
def task_figure1(
    script: Path = SRC / "12_robustness_distance_timeseries.R",
    depends_on: Path = PANEL_CLEAN,
    produces: Path = BLD_FIGURES / "yearly_distance_coef.pdf",
) -> None:
    """Figure 1: year-by-year β(ln_dist) with 95% CI and OLS trend.

    Requires panel_clean.rds (165MB — must be locally available).
    Fallback: run 12b_fig1_placeholder.R for placeholder from summary stats.
    Output: PDF 6.5×4.0in, DPI=300, ggplot2 theme_minimal.
    """


@pytask.mark.r(script=SRC / "12b_fig1_placeholder.R")
def task_figure1_placeholder(
    script: Path = SRC / "12b_fig1_placeholder.R",
    produces: Path = BLD_FIGURES / "yearly_distance_coef_placeholder.pdf",
) -> None:
    """Figure 1 PLACEHOLDER from reported summary statistics.

    Use when panel_clean.rds is unavailable (OneDrive stub).
    β values hardcoded from RESULTS_REVISION_NOTE_2026-04-07.md.
    Replace with task_figure1 output once panel_hs6.rds syncs.
    """


@pytask.mark.r(script=SRC / "16_network_centrality_sdm.R")
def task_network_figure(
    script: Path = SRC / "16_network_centrality_sdm.R",
    depends_on: Path = PANEL_CLEAN,
    produces: dict = {
        "centrality": BLD_TABLES / "network_centrality_food.csv",
        "hubs": BLD_TABLES / "top10_food_hubs.csv",
    },
) -> None:
    """Network centrality + spatial dependence model.

    Identifies top-10 food trade hubs by betweenness centrality.
    """
