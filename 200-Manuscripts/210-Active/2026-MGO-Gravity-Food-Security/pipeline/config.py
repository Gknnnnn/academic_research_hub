"""Path configuration for Gravity Food Security pipeline.

Mirrors OSE econ-project-templates conventions:
  SRC  — source R scripts (02-Methods/)
  BLD  — build artefacts (03-Results/)
  DOC  — manuscript (04-Manuscript/)
  ROOT — project root
"""

from pathlib import Path

ROOT: Path = Path(__file__).parent.parent.resolve()

SRC: Path = ROOT / "02-Methods"
BLD: Path = ROOT / "03-Results"
BLD_RDS: Path = BLD / "rds"
BLD_TABLES: Path = BLD / "tables"
BLD_FIGURES: Path = BLD / "figures"
DOC: Path = ROOT / "04-Manuscript"
