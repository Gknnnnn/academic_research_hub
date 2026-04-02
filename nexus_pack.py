import os
import sys
import shutil
import json
from pathlib import Path
from datetime import datetime
import re
import config

# Configuration
logger = config.setup_logging("submission_packager")
PROJECTS_ROOT = config.PROJECTS_DIR / "310-Active-Papers"
SUBMISSIONS_ROOT = config.PROJECT_ROOT / "900-Submissions"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def read_project_name(state_path: Path) -> str:
    text = read_text(state_path)
    match = re.search(r"^##\s+Project\s*$\n([^\n]+)", text, re.MULTILINE)
    return match.group(1).strip() if match else ""


def find_project(project_hint: str | None = None) -> Path:
    candidates = [p for p in PROJECTS_ROOT.rglob("*") if p.is_dir()]
    if project_hint:
        direct = PROJECTS_ROOT / project_hint
        if direct.exists():
            return direct

        hint = project_hint.lower()
        for project_dir in candidates:
            state_path = project_dir / "01-Admin" / "PROJECT_STATE.md"
            if state_path.exists():
                project_name = read_project_name(state_path).lower()
                if hint == project_name or hint in project_name or hint in project_dir.name.lower():
                    return project_dir

        matches = [p for p in candidates if hint in p.name.lower()]
        if matches:
            return sorted(matches)[0]

        raise FileNotFoundError(f"Project not found: {project_hint}")

    state_candidates = []
    for project_dir in candidates:
        state_path = project_dir / "01-Admin" / "PROJECT_STATE.md"
        if state_path.exists():
            state_candidates.append((state_path.stat().st_mtime, project_dir))
    if not state_candidates:
        raise FileNotFoundError("No project state files found.")
    return sorted(state_candidates, reverse=True)[0][1]

# Generic Cover Letter Template
COVER_LETTER_TEMPLATE = """# [FORMAL COVER LETTER]

**To:** The Editor-in-Chief  
**Journal:** {journal}  
**Date:** {date}

**Subject:** Submission of Manuscript for Peer Review

Dear Editor,

We are pleased to submit our original research article titled **"{title}"** for your review.

This research investigates {objective}. Our findings suggest that {key_finding}. We introduce the **"{concept}"** framework, which provides {contribution}.

**Key highlights of our research include:**
1.  **Methodological Rigor**: {methods}
2.  **Originality**: This manuscript is original and not under consideration elsewhere.
3.  **Transparency**: We have provided a full **Replication Manifest** to support the transparency of our findings.

Thank you for your consideration.

Sincerely,

**Gökhan Özdemir** (Corresponding Author)
{contact_info}
"""

def create_submission_package(project_name, journal="Elsevier"):
    """Creates a standardized submission package in 900-Submissions."""
    project_dir = config.PROJECTS_DIR / project_name
    if not project_dir.exists():
        try:
            project_dir = find_project(project_name)
        except FileNotFoundError:
            logger.error(f"Project directory not found: {project_name}")
            return {"status": "error", "message": f"Project {project_name} not found."}
    
    # Setup Output
    timestamp = datetime.now().strftime("%Y-%m-%d")
    out_dir = SUBMISSIONS_ROOT / f"{timestamp}-{project_name}-Submission"
    out_dir.mkdir(parents=True, exist_ok=True)
    
    # 1. Generate Cover Letter
    # (In a real system, we'd pull this from a project_metadata.json)
    metadata = {
        "journal": journal.capitalize(),
        "date": datetime.now().strftime("%B %d, %Y"),
        "title": f"Nexus Research: {project_name.replace('-', ' ')}",
        "objective": "the intersection of structural change and sustainable development",
        "key_finding": "agricultural structural transformation follows a non-linear stabilization path",
        "concept": "Structural Floor",
        "contribution": "a vital insight for long-term planning",
        "methods": "Econometric panel analysis and ANN modeling",
        "contact_info": "m.gokhan.ozdemir@nexus.edu"
    }
    
    cl_path = out_dir / f"Cover_Letter_{metadata['journal']}.md"
    with open(cl_path, "w", encoding="utf-8") as f:
        f.write(COVER_LETTER_TEMPLATE.format(**metadata))
        
    # 2. Gather Manuscript
    # (Assuming user has rendered it in 600-Results or 300-Projects)
    # Search for PDF in the project folder
    pdf_files = list(project_dir.rglob("*.pdf"))
    if pdf_files:
        latest_pdf = sorted(pdf_files, key=os.path.getmtime, reverse=True)[0]
        shutil.copy2(latest_pdf, out_dir / f"Manuscript_{project_name}.pdf")
        logger.info(f"Copied manuscript: {latest_pdf.name}")
    else:
        logger.warning("No PDF manuscript found. Package created without it.")

    # 3. Copy strategy and memory artifacts when available
    strategy_assets = [
        project_dir / "01-Admin" / "submission_strategy.md",
        project_dir / "01-Admin" / "RESEARCH_STATE.md",
        project_dir / "01-Admin" / "TASK.md",
    ]
    for asset in strategy_assets:
        if asset.exists():
            shutil.copy2(asset, out_dir / asset.name)

    # 4. Create replication manifest
    manifest_path = out_dir / "Replicability_Manifest.md"
    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write(f"# Replicability Manifest: {project_name}\n\n")
        f.write("## Data Sources\n- World Bank Open Data\n- FAOSTAT\n\n")
        f.write("## Methods\n- Multi-Layer Perceptron (R/Python)\n- Panel Fixed Effects\n\n")
        f.write(f"Generated by MGO Research Nexus on {timestamp}")

    # 5. Record package metadata
    metadata_path = out_dir / "package_metadata.json"
    metadata_payload = {
        "project": project_name,
        "journal": journal,
        "created_at": timestamp,
        "artifacts": [f.name for f in out_dir.iterdir()],
    }
    metadata_path.write_text(json.dumps(metadata_payload, indent=2), encoding="utf-8")
        
    return {
        "status": "success",
        "package_dir": str(out_dir),
        "journal": journal,
        "files_included": sorted([f.name for f in out_dir.iterdir()])
    }


def package_submission(project_name, journal="Elsevier"):
    """Compatibility wrapper for server.py packaging endpoint."""
    return create_submission_package(project_name, journal)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python nexus_pack.py [project_name] [journal]")
        sys.exit(1)
        
    proj = sys.argv[1]
    jrnl = sys.argv[2] if len(sys.argv) > 2 else "Elsevier"
    
    res = create_submission_package(proj, jrnl)
    if res["status"] == "success":
        print(f"\n✅ SUBMISSION PACKAGE CREATED!")
        print(f"📁 Path: {res['package_dir']}")
        print(f"📖 Journal: {res['journal']}")
        print(f"📄 Files: {', '.join(res['files_included'])}")
    else:
        print(f"❌ Error: {res['message']}")
