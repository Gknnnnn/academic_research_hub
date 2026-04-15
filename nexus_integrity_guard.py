import re
import os
import sys
from pathlib import Path
import config

# Configuration
logger = config.setup_logging("integrity_guard")

def extract_citations_from_qmd(file_path):
    """Extracts CiteKeys from a Quarto file using regex."""
    cite_pattern = re.compile(r'@([a-zA-Z0-9_]{3,})') # Matches @Key, [@Key], etc.
    citations = set()
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            # Remove code blocks and comments to avoid false positives
            content = re.sub(r'```.*?```', '', content, flags=re.DOTALL)
            content = re.sub(r'<!--.*?-->', '', content, flags=re.DOTALL)
            
            matches = cite_pattern.findall(content)
            for m in matches:
                # Exclude some common non-citation @ usages if needed
                if not m.isdigit():
                    citations.add(m)
    except Exception as e:
        logger.error(f"Error reading QMD: {e}")
        
    return citations

def extract_keys_from_bib(bib_path):
    """Extracts all BibTeX keys from a .bib file."""
    # Matches @type{Key,
    key_pattern = re.compile(r'@[a-zA-Z]+\{([a-zA-Z0-9_]{3,}),')
    keys = set()
    
    try:
        with open(bib_path, 'r', encoding='utf-8') as f:
            content = f.read()
            matches = key_pattern.findall(content)
            for m in matches:
                keys.add(m)
    except Exception as e:
        logger.error(f"Error reading BIB: {e}")
        
    return keys

def audit_manuscript(qmd_relative_path):
    """Performs the full integrity audit."""
    qmd_path = config.PROJECT_ROOT / qmd_relative_path
    bib_path = config.LITERATURE_DIR / "180-Bibliography" / "references.bib"
    
    if not qmd_path.exists():
        return {"status": "error", "message": f"File not found: {qmd_path}"}
    
    if not bib_path.exists():
        return {"status": "error", "message": f"Bibliography not found: {bib_path}"}
    
    text_citations = extract_citations_from_qmd(qmd_path)
    bib_keys = extract_keys_from_bib(bib_path)
    
    ghost_citations = text_citations - bib_keys
    zombie_citations = bib_keys - text_citations
    
    results = {
        "manuscript": str(qmd_path.name),
        "total_in_text": len(text_citations),
        "total_in_bib": len(bib_keys),
        "ghost_citations": list(ghost_citations), # In text but missing from Bib
        "zombie_citations": list(zombie_citations), # In Bib but unused
        "status": "pass" if not ghost_citations else "fail"
    }
    
    return results


def scan_project(project_hint=None, check_claims=False):
    """Compatibility wrapper for server.py's integrity endpoint."""
    if project_hint:
        project_path = Path(project_hint)
        if project_path.suffix == ".qmd":
            target = project_hint
        else:
            manuscript_dir = config.PROJECTS_DIR / "310-Active-Papers" / project_hint / "04-Manuscript"
            matches = sorted(manuscript_dir.glob("*.qmd"))
            if not matches:
                return {"status": "error", "message": f"No manuscript found for project: {project_hint}"}
            target = str(matches[0].relative_to(config.PROJECT_ROOT))
    else:
        candidates = sorted(
            (config.PROJECTS_DIR / "310-Active-Papers").glob("*/04-Manuscript/*.qmd"),
            key=lambda path: path.stat().st_mtime,
            reverse=True,
        )
        if not candidates:
            return {"status": "error", "message": "No manuscript files found under active projects."}
        target = str(candidates[0].relative_to(config.PROJECT_ROOT))

    result = audit_manuscript(target)
    if check_claims:
        result["claim_check_mode"] = "basic"
    result["project_hint"] = project_hint
    return result

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python nexus_integrity_guard.py [relative_path_to_qmd]")
        sys.exit(1)
        
    target = sys.argv[1]
    report = audit_manuscript(target)
    
    print("\n" + "="*40)
    print(f"🔍 NEXUS INTEGRITY REPORT: {report['manuscript']}")
    print("="*40)
    print(f"✅ Citations in text: {report['total_in_text']}")
    print(f"📚 Keys in bibliography: {report['total_in_bib']}")
    
    if report['ghost_citations']:
        print(f"\n❌ GHOST CITATIONS (Found in text, missing from Bib):")
        for c in report['ghost_citations']:
            print(f"   - @{c}")
    else:
        print("\n✅ No ghost citations found.")
        
    if report['zombie_citations']:
        # Only show a few zombies to stay concise
        print(f"\n🧟 ZOMBIE CITATIONS ({len(report['zombie_citations'])} items in Bib but unused):")
        for c in sorted(report['zombie_citations'])[:5]:
            print(f"   - @{c}")
        if len(report['zombie_citations']) > 5:
            print(f"   ... and {len(report['zombie_citations']) - 5} more.")
    
    print("="*40)
    print(f"RESULT: {report['status'].upper()}")
    print("="*40)
