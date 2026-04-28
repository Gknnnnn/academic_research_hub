# Gravity Food Security — pytask Pipeline

Adapted from [OpenSourceEconomics/econ-project-templates](https://github.com/OpenSourceEconomics/econ-project-templates).

## Quick Start

```bash
# From pipeline/ directory:
pytask .

# Or from project root:
pytask pipeline/
```

Single command rebuilds: data → analysis → robustness → figures → DOCX.

## DAG Overview

```
raw BACI CSVs
    └─ 01_data_merge.R ──► panel_hs6.rds (165MB)
                               └─ 02_panel_clean.R ──► panel_clean.rds
                                       ├─ 02_baseline_ppml.R ──► ppml_baseline.rds
                                       ├─ 04_ppml_main.R ──► ppml_main.rds
                                       │       └─ 11b_fta_interaction.R ──► fta_interaction_wald.csv
                                       ├─ 12_robustness_distance_timeseries.R ──► yearly_distance_coef.pdf (Fig 1)
                                       └─ [07-15 robustness scripts] ──► rob_*.csv
                                               │
                                     gravity_food_security_v01.qmd
                                               └─ quarto render ──► gravity_food_security_v01.docx
```

## OneDrive Stub Warning

`panel_hs6.rds` (165MB) may appear as an OneDrive cloud stub.
If `task_data_merge` fails with "connection timed out", force-download via:
```bash
# In macOS Finder: right-click panel_hs6.rds → "Always keep on this device"
# Or trigger via Python:
import subprocess; subprocess.run(["open", "path/to/panel_hs6.rds"])
```
Fallback: use `task_figure1_placeholder` which reconstructs Figure 1 from
reported summary statistics (β range −0.72 to −0.79, trend p=0.266).

## Tasks

| Task | Script | Output |
|------|--------|--------|
| `task_data_merge` | `01_data_merge.R` | `panel_hs6.rds` |
| `task_panel_clean` | `02_panel_clean.R` | `panel_clean.rds` |
| `task_baseline_ppml` | `02_baseline_ppml.R` | `ppml_baseline.rds` |
| `task_ppml_main` | `04_ppml_main.R` | `ppml_main.rds` |
| `task_fta_interaction` | `11b_fta_interaction.R` | `fta_interaction_wald.csv` |
| `task_figure1` | `12_robustness_distance_timeseries.R` | `yearly_distance_coef.pdf` |
| `task_figure1_placeholder` | `12b_fig1_placeholder.R` | `yearly_distance_coef_placeholder.pdf` |
| `task_robustness_*` (7×) | `07-15_robustness_*.R` | `rob_*.csv` |
| `task_compile_paper` | quarto render | `gravity_food_security_v01.docx` |
| `task_compile_paper_anon` | quarto render | `gravity_food_security_v01_anon.docx` |

## Replication Standard

This pipeline meets AEA/Food Policy replication standards:
- All inputs explicitly declared as `depends_on`
- All outputs declared as `produces`
- Deterministic order enforced by DAG
- `raw/` never modified — all transformations in `bld/`
