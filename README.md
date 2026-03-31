# Primary Economics Research Hub

Welcome to the central repository for primary economics research. This workspace is strictly organized into 16 active folders to streamline the research pipeline—from initial literature review to econometric modeling, manuscript drafting, and journal submission.

## Directory Structure

*   **/01_Literature_Review**: For active literature search notes, synthesized bibliographies, and relevant reading materials.
*   **/02_Theoretical_Framework**: Notes and derivations for economic and econometric theories underpinning the research.
*   **/03_Data_Raw**: Original, untouched datasets from external sources (e.g., World Bank, OECD, regional statistical agencies).
*   **/04_Data_Cleaned**: Processed and tidied datasets ready for econometric analysis.
*   **/05_Econometric_Models**: Estimation codes, modeling scripts (R/Python), and cross-validation routines.
*   **/06_Results_Tables**: Final exported tables, model summaries, and statistical test results.
*   **/07_Manuscript_Drafts**: Active workspace for drafting papers, usually in Quarto (.qmd), RMarkdown, or LaTeX.
*   **/08_Zotero_Sync**: Scripts and exported `.bib` libraries acting as the bridge to the main Zotero reference manager.
*   **/09_Python_Scripts**: Utility scripts (e.g., data scraping, string parsing, document indexing, API wrappers).
*   **/10_R_Scripts**: Core analytical R scripts, especially for panel data or advanced econometric pipelines.
*   **/11_Notes_Obsidian**: Main Obsidian vault connection containing structured knowledge bases, meeting notes, and daily logs.
*   **/12_Graphics_Outputs**: Generated charts, maps, and figures (in PDF, PNG, or SVG formats).
*   **/13_Conference_Papers**: Submissions, presentations, and posters intended for academic conferences.
*   **/14_Journal_Submissions**: Finalized packages ready for peer-reviewed journal submission (includes cover letters and reviewer responses).
*   **/15_Archive**: Old project versions, deprecated datasets, and inactive research branches.
*   **/16_Admin_Docs**: Administrative documentation, grant proposals, ethical clearances, and budgeting.

> [!NOTE]
> Background knowledge literature from `OneDrive/1. Documents` is deliberately kept out of this active tree to maintain focus. Instead, it is indexed in `/11_Notes_Obsidian/Background_Documents_Index.md`.

## Zotero Integration
Use the scripts in `08_Zotero_Sync` to pull latest citations from Zotero (Group/User ID: **7714813**).

## Maintenance & Clean-up
Refer to `/09_Python_Scripts` for tools to automatically resolve and uniformly rename incoming loose PDFs.

## Quick Start for Daily Use

If you are using this system as an economist rather than as a developer, the simplest workflow is:

1. Start from `900-Dashboard` to see the current pipeline status, active projects, and recent updates.
2. When reading a paper, save your structured note under `100-Literature`.
3. When exploring a new idea, start in `200-Concepts/240-Brainstorming-Lab`.
4. When an idea becomes serious, move it into `300-Projects`.
5. Keep data in `400-Data`, methods in `500-Methods`, and outputs in `700-Analysis-Output` or `700-Submissions`.

## Practical Rule

Do not treat every idea as a confirmed result.

- Use `Working Hypotheses` for ideas, expectations, and early interpretations.
- Use `Verified Findings` only after literature, data, and empirical checks are completed.

## Folder Guide

- `100-Literature`: paper notes, Zotero collections, JEL-based literature organization
- `200-Concepts`: brainstorming, idea generation, method comparison
- `300-Projects`: active paper ideas and project-level organization
- `400-Data`: datasets and update logs
- `500-Methods`: equations, econometric methods, analysis structure
- `600-Templates`: ready-to-use templates for notes and analysis
- `700-Submissions`: paper-by-paper production folders
- `800-Bibliography`: bibliography outputs
- `900-Dashboard`: the best place to start each day
