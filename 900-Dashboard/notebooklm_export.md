# NotebookLM Export

## System Summary (HTML)

<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="utf-8">
  <title>Research Ops Summary</title>
  <style>
    body { font-family: system-ui, Arial, sans-serif; background:#111; color:#f4f4f4; padding:2rem; }
    h1 { color:#7ed321; }
    section { border:1px solid #2f2f2f; padding:1rem; margin-bottom:1rem; border-radius:0.5rem; background:#171717; }
    ul { margin:0; padding-left:1.2rem; }
    .bar { height:0.6rem; background:#4a90e2; border-radius:0.3rem; margin-top:0.6rem; }
    .bar span { display:block; height:100%; background:#50e3c2; border-radius:inherit; }
  </style>
</head>
<body>
  <h1>Research Automation Overview</h1>
  <section>
    <h2>AI Token / Usage Summary</h2>
    <p>Burada Claude, Gemini, Codex ve Grok gibi hesapların token tüketimleri gösterilir (manuel güncelleme):</p>
    <ul>
      <li>Claude (Deep Research) — ???/250K token</li>
      <li>Gemini (Idea exploration) — ???/200K token</li>
      <li>Codex (Automation) — ???/300K token</li>
      <li>Grok (Brainstorm) — ???/150K token</li>
    </ul>
    <div class="bar"><span style="width:45%"></span></div>
  </section>
  <section>
    <h2>Pipeline Status</h2>
    <ul>
      <li>JEL sync: automated nightly 03:00 (scripts/jel-system).</li>
      <li>Brainstorm workflow: daily n8n job + DeepSeek handoff.</li>
      <li>Idea promotion: `roc-idea-promotion` @18:00 weekdays.</li>
    </ul>
  </section>
  <section>
    <h2>Project Snapshot</h2>
    <ul>
      <li>Active paper: Green Innovation Structural Transformation (`300-Projects/310-Active-Papers/...`).</li>
      <li>Data quality log: `900-Dashboard/data_quality_log.md` showing NA counts.</li>
      <li>Submission templates: `700-Submissions/_templates/analysis_workflow_template.md`.</li>
    </ul>
  </section>
  <p>Status tarih damgası: <strong><span id="timestamp"></span></strong></p>
  <script>
    document.getElementById("timestamp").textContent = new Date().toLocaleString("tr-TR");
  </script>
</body>
</html>


## Data Preview

# Data Preview

Obsidian içinde CSV görüntülemek için `CSV Table` veya `Dataview` eklentisi kullan. Aşağıdaki `Dataview` bloğu, `400-Data/420-WorldBank/turkiye_makro_data.csv` içinden beş satır sunar.

```dataview
table year, gdp_usd, co2_kt, elec_kwh_pc, urban_pct
from "400-Data/420-WorldBank"
limit 5
```

Bu notu açtığında eklenti tabloyu otomatik render eder; eklentiyi eklemediysen `Community plugins` → `Browse` → "Dataview" veya "CSV Table" yükle ve etkinleştir. 

Ek olarak, CSV’yi doğrudan açmak istersen yol:

`[[400-Data/420-WorldBank/turkiye_makro_data.csv]]`

Son veri kalite raporu: `[[900-Dashboard/data_quality_log.md#turkiye_makro_data.csv]]`


## DeepSeek Handoff Reference

# DeepSeek Handoff

## Objective

Review the current Research Ops / Obsidian / Zotero architecture and propose improvements, especially around:

- AI-assisted brainstorming
- literature note generation
- methodology extraction
- equation reconstruction
- safe automation

Do not redesign from scratch. Build on the current real state.

## Environment

- macOS
- Research ops root:
  `/Users/mehmetgokhanozdemir/research-ops`
- Obsidian vault:
  `/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma`
- n8n UI:
  `http://localhost:5679`

## Running Stack

- `roc-n8n`
- `roc-postgres`
- `roc-chromadb`

## Verified Working Parts

### Macro pipeline

- World Bank data flow works
- Output path:
  `/400-Data/420-WorldBank`

### Zotero export pipeline

- Zotero API integration works
- Bibliography exports are written into:
  `/800-Bibliography`

### JEL MVP

Root:

- `/Users/mehmetgokhanozdemir/research-ops/jel-system`

Current behavior:

- reads the full Zotero library
- classifies items with deterministic JEL rules
- generates:
  - `100-Literature/135-JEL-Indexes/master-jel-index.md`
  - `100-Literature/135-JEL-Indexes/review-queue.md`
  - `by-collection`
  - `by-family`
  - `by-code`
  - `documents-inventory`
  - `documents-matches`

Current scale:

- 2176 Zotero top-level items processed
- 4129 research-relevant files inventoried from `1. Documents`
- 660 document-to-Zotero fuzzy matches

### Empirical analysis workflow

- Workflow file:
  `/Users/mehmetgokhanozdemir/research-ops/n8n-workflows/04-empirical-analysis-orchestrator.json`
- Workflow id in n8n:
  `roc-empirical-analysis`
- Current purpose:
  builds an empirical markdown summary for a JEL stream

## Current Vault Architecture

There are two layers intentionally preserved:

### 1. Legacy mental-model folders

- `01_Literature_Review`
- `02_Theoretical_Framework`
- `03_Data_Raw`
- `04_Data_Cleaned`
- `05_Econometric_Models`
- `06_Results_Tables`
- `07_Manuscript_Drafts`
- `08_Zotero_Sync`
- `09_Python_Scripts`
- `10_R_Scripts`
- `11_Notes_Obsidian`
- `12_Graphics_Outputs`
- `13_Conference_Papers`
- `14_Journal_Submissions`
- `15_Archive`
- `16_Admin_Docs`
- `99_Exports`

These are now preserved mainly as reference and orientation layers.

### 2. Active ROC production folders

- `000-Inbox`
- `100-Literature`
- `200-Concepts`
- `300-Projects`
- `400-Data`
- `500-Methods`
- `600-Templates`
- `700-Analysis-Output`
- `800-Bibliography`
- `900-Dashboard`

## New Literature Intelligence Layer

Recently added:

- `100-Literature/140-Paper-Notes`
- `100-Literature/150-Method-Maps`
- `500-Methods/540-Equation-Library`

Templates added:

- `600-Templates/Paper-Reading-Template.md`
- `600-Templates/Method-Map-Template.md`
- `600-Templates/Equation-Library-Template.md`
- `600-Templates/Brainstorming-Session-Template.md`

Protocol files:

- `research-ops/LITERATURE_INTELLIGENCE_PROTOCOL.md`
- `vault/DUAL_WORKSPACE_PROTOCOL.md`
- `vault/VAULT_MIGRATION_GUIDE.md`

Starter method files:

- `ARDL.md`
- `PMG.md`
- `Toda-Yamamoto.md`
- `ANN.md`

Starter equation files:

- `ARDL-ECM.md`
- `PMG-Panel-ARDL.md`
- `Toda-Yamamoto-Causality.md`
- `ANN-FeedForward.md`

## New Brainstorming Layer

Added for AI-assisted idea development:

- `200-Concepts/240-Brainstorming-Lab`
- `300-Projects/340-Idea-Incubator`

Goal:

- allow free AI brainstorming without polluting production project folders
- promote only matured ideas into active paper folders

## New Automation Added

### Brainstorm capture script

- `/Users/mehmetgokhanozdemir/research-ops/scripts/run_brainstorm_capture.py`

Purpose:

- create structured brainstorming notes in Obsidian
- optionally write directly into the incubator layer

### Brainstorming n8n workflow file

- `/Users/mehmetgokhanozdemir/research-ops/n8n-workflows/05-brainstorming-session-generator.json`

Purpose:

- generate a daily or manual brainstorming note in:
  `200-Concepts/240-Brainstorming-Lab`

### Idea promotion automation

- `/Users/mehmetgokhanozdemir/research-ops/scripts/promote_incubator_ideas.py`
- `/Users/mehmetgokhanozdemir/research-ops/n8n-workflows/06-idea-promotion-runner.json`

Purpose:

- detect incubator notes flagged `promotion_ready: true` and move them into `300-Projects/310-Active-Papers/<slug>`
- create `project_overview.md` and log promoted ideas in `research-ops/promoted_projects.json`
- run weekdays at 18:00 (or manually) to keep active project pipeline filled

## Important Design Principles

- Do not collapse the system into one folder tree.
- Preserve legacy folders as cognitive navigation aids.
- Preserve ROC folders as production infrastructure.
- Use Zotero as bibliographic source of truth.
- Use Obsidian as research workspace and enriched mirror.
- Do not propose unsafe full bidirectional filesystem sync between Zotero DB and OneDrive.
- Focus on controlled metadata, note generation, methodology extraction, and equation reconstruction.
- Track data quality: each cleaning run logs the dataset, row counts before/after, and missing columns into `900-Dashboard/data_quality_log.md`.

## Submission Folder Guidelines

- Active submissions live under `700-Submissions/active/<slug>/` with `data/`, `code/`, `output/`, `manuscript/`, `submission/`, `reviews/`, `revision/`, plus `timeline.md`.  
- Data should be symlinked back to `400-Data/` to avoid duplication.  
- `code/run.sh` orchestrates cleaning (`01_clean_data.py`) and analysis (`02_analysis.py`) for the sample Green Growth project; adapt similar scripts per submission.  
- `project_overview.md` and `Idea Promotion Runner` keep active submissions in sync with the AI idea pipeline.  

## What Is Still Missing

1. Automated paper-note generation from Zotero items or PDFs
2. Automated methodology extraction into `150-Method-Maps`
3. Automated equation extraction / reconstruction pipeline
4. Better AI collaboration patterns for sustained long-horizon brainstorming

## What I Want From You

Please review this real system state and propose:

1. The best automation design for:
   - brainstorming capture
   - paper-note generation
   - methodology extraction
   - equation reconstruction
2. How to use AI continuously for idea development without creating chaos
3. What should be manual vs automated
4. How to move an idea from:
   - Brainstorming Lab
   - Idea Incubator
   - Active Paper
5. What the next 3 highest-value implementation steps should be

Please be concrete and build on the actual paths and files above.
### NotebookLM / Presentation / Data Alerts

- `/Users/mehmetgokhanozdemir/research-ops/scripts/build_notebooklm_export.py` + `n8n-workflows/07-notebooklm-exporter.json` – HTML/Dataview özetini Markdown’a çevirip NotebookLM’e gönder.  
- `/Users/mehmetgokhanozdemir/research-ops/scripts/generate_presentation_notes.py` + `n8n-workflows/08-presentation-generator.json` – regression summary’ı Sunum notlarına dönüştürüyor (weekly).  
- `/Users/mehmetgokhanozdemir/research-ops/scripts/check_data_quality.py` + `n8n-workflows/09-data-quality-alert.json` – `900-Dashboard/data_quality_log.md` son girişini `data_quality_alert.md`’e yazıyor; günlük 12:00 kontrolü.  
