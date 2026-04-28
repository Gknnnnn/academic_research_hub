"""Data management tasks — BACI merge + panel clean.

DAG:
  [raw BACI CSVs] → 01_data_merge.R   → panel_hs6.rds
  panel_hs6.rds   → 02_panel_clean.R  → panel_clean.rds
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import pytask

from config import BLD_RDS, SRC


@pytask.mark.r(script=SRC / "01_data_merge.R")
def task_data_merge(
    script: Path = SRC / "01_data_merge.R",
    produces: Path = BLD_RDS / "panel_hs6.rds",
) -> None:
    """Merge BACI HS-6 bilateral trade with CEPII gravity variables.

    Input:  raw/ BACI CSVs + CEPII GeoDist + WDI GDP + DESTA FTA
    Output: panel_hs6.rds — 565,890 dyad-sector-year (2005-2020)

    Note: panel_hs6.rds is 165MB. If OneDrive sync is stale,
    run this task to regenerate from raw data.
    """


@pytask.mark.r(script=SRC / "02_panel_clean.R")
def task_panel_clean(
    script: Path = SRC / "02_panel_clean.R",
    depends_on: Path = BLD_RDS / "panel_hs6.rds",
    produces: Path = BLD_RDS / "panel_clean.rds",
) -> None:
    """Clean panel: winsorise, create perishability dummy, log-transform.

    Perishability classification: HS chapters 01-24 (fresh/processed food).
    Produces binary `perishable` flag used in all PPML models.
    """
