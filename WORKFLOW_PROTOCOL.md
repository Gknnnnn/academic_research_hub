# Masterpiece Workflow Protocol (v1.0)
## Objective: Continuous Academic Article Production

### 1. The Stack
- **Orchestration**: n8n (Docker, Port 5679)
- **Knowledge Base**: Obsidian (OneDrive mounted at `/obsidian` in Docker)
- **Research Engine**: Antigravity / Claude Code (Multi-agent skills: `deep-research`, `academic-paper`, `academic-paper-reviewer`, `academic-pipeline`)
- **Data Sources**: Zotero API (Refs), WorldBank API (Macro indicators)

### 2. The Core Pipeline (10-Stage)
1. **INGESTION (n8n)**: 08:00 (Macro) & 20:00 (Zotero) sync to `/obsidian/400-Data` and `/800-Bibliography`.
2. **RESEARCH (Stage 1)**: `deep-research` (socratic/systematic mode). Integrate vault data + live web research.
3. **STYLE CALIBRATION**: Extract voice from existing `.qmd` files (e.g., `MGO_HBI_Tarim_Konya_v3.qmd`).
4. **WRITING (Stage 2)**: `academic-paper` (plan/full mode). Output: `.qmd` (Quarto).
5. **INTEGRITY (Stage 2.5/4.5)**: Mandatory `integrity_verification_agent`. 100% citation check. Zero hallucinations.
6. **REVIEW (Stage 3)**: 5-agent panel (EIC + 3 Reviewers + Devil's Advocate). Scoring: 0-100.
7. **REVISION**: Automated `revision-coach` roadmap based on feedback.
8. **FINALIZATION**: Pandoc/LaTeX -> Tectonic -> PDF.

### 3. Guidelines for the AI assistant (Token Efficiency)
- **Socratic Interaction**: Do not write the full paper in one go. Chapter-by-chapter convergence is mandatory.
- **Reference Integrity**: Never cite a source without DOI/WebSearch verification.
- **Data-Anchoring**: Always look for `.csv` files in `/obsidian/400-Data` before generating economic claims.
- **Consistency**: Maintain the "MGO" academic voice (formal, multi-layered, SDG-linked).
- **Format**: Use Quarto (`.qmd`) for all drafts to ensure reproducibility of R/Python code blocks.

### 4. Memory Persistence
- Save all research insights as `RESEARCH_STATE.md` in the project root.
- Maintain a `TASK.md` to track the current stage in the 10-stage pipeline.

---
*End of Protocol. This document is a mandatory context for all research-related sessions.*
