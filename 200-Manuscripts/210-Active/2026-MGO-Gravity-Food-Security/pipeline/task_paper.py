"""Paper compilation task — quarto render → DOCX.

DAG (final node):
  gravity_food_security_v01.qmd
  + yearly_distance_coef.pdf   (Figure 1)
  + references.bib
  → gravity_food_security_v01.docx  (Food Policy submission)
  → gravity_food_security_v01_anon.docx  (blind copy)
"""

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import pytask

from config import BLD_FIGURES, DOC, ROOT


@pytask.task(id="paper-docx")
def task_compile_paper(
    qmd: Path = DOC / "gravity_food_security_v01.qmd",
    bib: Path = DOC / "references.bib",
    figure1: Path = BLD_FIGURES / "yearly_distance_coef.pdf",
    produces: Path = DOC / "gravity_food_security_v01.docx",
) -> None:
    """Render manuscript QMD → DOCX via quarto.

    Requires: quarto CLI on PATH.
    Output: gravity_food_security_v01.docx — Food Policy format.
    """
    subprocess.run(
        ["quarto", "render", str(qmd), "--to", "docx"],
        check=True,
        cwd=DOC,
    )


@pytask.task(id="paper-anon")
def task_compile_paper_anon(
    qmd: Path = DOC / "gravity_food_security_v01_anon.qmd",
    bib: Path = DOC / "references.bib",
    figure1: Path = BLD_FIGURES / "yearly_distance_coef.pdf",
    produces: Path = DOC / "gravity_food_security_v01_anon.docx",
) -> None:
    """Render anonymous/blinded manuscript → DOCX for blind review."""
    subprocess.run(
        ["quarto", "render", str(qmd), "--to", "docx"],
        check=True,
        cwd=DOC,
    )
