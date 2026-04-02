#!/usr/bin/env python3
import argparse
import csv
import json
import os
import re
import shlex
import sys
import time
import subprocess
import httpx
import logging
import itertools
from datetime import datetime
from pathlib import Path
from typing import Any
import config
from stage_payloads import (
    build_stage_08_payload,
    build_pipeline_manifest,
)
from autonomous_watchtower import run_watchtower_for_project
from evolution_engine import run_evolution
sys.path.append(str(config.SYSTEM_DIR))
import admin_prompts

# Configuration
logger = config.setup_logging("antigravity")

# Paths (Dynamic Portability)
RESULTS_PATH = config.METHODS_DIR / "530-Econometric-Analysis" / "510-JEL-Q56-GreenGrowth" / "results"
DATA_VAULT_PATH = config.DATA_DIR
SPARRING_OUTPUT_DIR = RESULTS_PATH / "stage-04_5-socratic-lab"
META_OUTPUT_DIR = RESULTS_PATH / "stage-07-self-evolving-meta-logic"
MANIFEST_OUTPUT_DIR = RESULTS_PATH / "pipeline-run-manifests"
SKILL_LIBRARY_DIR = config.SYSTEM_DIR / "skill-library"
ANALYST_AGENT_PATH = config.METHODS_DIR / "analyst_agent.py"
MAX_AUDITED_FILES = 25
CSV_PREVIEW_ROWS = 3

CLAIM_ALIASES = {
    "gdp": ["gdp", "gross domestic product", "income"],
    "co2": ["co2", "carbon", "emission"],
    "electricity": ["electricity", "power", "energy use"],
    "urbanization": ["urban", "urbanization", "urban population"],
    "trade": ["trade", "openness", "export", "import"],
    "renewable": ["renewable", "clean energy"],
}

META_AUDIT_RULES = [
    {
        "name": "identification_guard",
        "triggers": ["identification", "causal", "descriptive", "inferential warrant"],
        "layer": "Force explicit identification language and downgrade causal claims unless defended.",
    },
    {
        "name": "endogeneity_watch",
        "triggers": ["endogeneity", "reverse causality", "simultaneity", "omitted"],
        "layer": "Require endogeneity paragraph plus estimator-specific diagnostics before final drafting.",
    },
    {
        "name": "robustness_battery",
        "triggers": ["robustness", "sensitivity", "subsample", "lag", "structural break"],
        "layer": "Add robustness checklist covering alternative specifications, windows, and post-shock periods.",
    },
    {
        "name": "measurement_audit",
        "triggers": ["measurement", "proxy", "operationalization"],
        "layer": "Compare alternative proxy definitions and log why the selected measure is defensible.",
    },
    {
        "name": "evidence_traceability",
        "triggers": ["red flag", "unsupported", "traceable", "audited csv"],
        "layer": "Block unsupported statistics unless linked to an audited data artifact.",
    },
]

class Spinner:
    def __init__(self, message="Working..."):
        self.spinner = itertools.cycle(['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'])
        self.message = message
        self.running = False

    def spin(self):
        sys.stdout.write(f"\r{next(self.spinner)} {self.message}")
        sys.stdout.flush()

def print_header():
    print("\n" + "="*60)
    print("🚀  ANTIGRAVITY: THE ULTIMATE RESEARCH ORCHESTRATOR")
    print("="*60 + "\n")

def parse_args():
    parser = argparse.ArgumentParser(description="Antigravity research orchestrator")
    subparsers = parser.add_subparsers(dest="command")

    econ = subparsers.add_parser("econometrics", help="Run the self-correcting econometric engine")
    econ.add_argument("--project-dir")
    econ.add_argument("--data")
    econ.add_argument("--dependent")
    econ.add_argument("--main-regressor")
    econ.add_argument("--controls", nargs="*", default=[])
    econ.add_argument("--extra-terms", nargs="*", default=[])
    econ.add_argument("--entity-id", default="country")
    econ.add_argument("--time-id", default="year")
    econ.add_argument("--manuscript-figures-dir")
    econ.add_argument("--output-dir")
    econ.add_argument("--appendix-dir")
    econ.add_argument("--candidate-lags", nargs="*", type=int, default=[0, 1, 2])
    econ.add_argument("--max-control-combinations", type=int, default=50)
    econ.add_argument("--outlier-zscore", type=float, default=3.0)
    econ.add_argument(
        "--functional-forms",
        nargs="*",
        default=["level", "log_level", "level_log", "log_log"],
    )
    econ.add_argument("--instruments", nargs="*", default=[])
    econ.add_argument("--config-json")
    return parser.parse_args()


def build_engine_command(args) -> list[str]:
    if args.config_json:
        payload = json.loads(Path(args.config_json).read_text(encoding="utf-8"))
        config_values = {
            "project_dir": payload["project_dir"],
            "data": payload["data_path"],
            "dependent": payload["dependent"],
            "main_regressor": payload["main_regressor"],
            "controls": payload.get("controls", []),
            "extra_terms": payload.get("extra_terms", []),
            "entity_id": payload.get("entity_id", "country"),
            "time_id": payload.get("time_id", "year"),
            "manuscript_figures_dir": payload.get("manuscript_figures_dir"),
            "output_dir": payload.get("output_dir"),
            "appendix_dir": payload.get("appendix_dir"),
            "candidate_lags": payload.get("candidate_lags", [0, 1, 2]),
            "max_control_combinations": payload.get("max_control_combinations", 50),
            "outlier_zscore": payload.get("outlier_zscore", 3.0),
            "functional_forms": payload.get(
                "functional_forms", ["level", "log_level", "level_log", "log_log"]
            ),
            "instruments": payload.get("instruments", []),
        }
    else:
        config_values = {
            "project_dir": args.project_dir,
            "data": args.data,
            "dependent": args.dependent,
            "main_regressor": args.main_regressor,
            "controls": args.controls,
            "extra_terms": args.extra_terms,
            "entity_id": args.entity_id,
            "time_id": args.time_id,
            "manuscript_figures_dir": args.manuscript_figures_dir,
            "output_dir": args.output_dir,
            "appendix_dir": args.appendix_dir,
            "candidate_lags": args.candidate_lags,
            "max_control_combinations": args.max_control_combinations,
            "outlier_zscore": args.outlier_zscore,
            "functional_forms": args.functional_forms,
            "instruments": args.instruments,
        }

    required = ["project_dir", "data", "dependent", "main_regressor"]
    missing = [key for key in required if not config_values.get(key)]
    if missing:
        raise SystemExit(f"Missing required econometrics arguments: {', '.join(missing)}")

    cmd = [
        sys.executable,
        str(ANALYST_AGENT_PATH),
        "--project-dir",
        str(config_values["project_dir"]),
        "--data",
        str(config_values["data"]),
        "--dependent",
        str(config_values["dependent"]),
        "--main-regressor",
        str(config_values["main_regressor"]),
        "--entity-id",
        str(config_values["entity_id"]),
        "--time-id",
        str(config_values["time_id"]),
        "--max-control-combinations",
        str(config_values["max_control_combinations"]),
        "--outlier-zscore",
        str(config_values["outlier_zscore"]),
    ]

    if config_values["controls"]:
        cmd.extend(["--controls", *map(str, config_values["controls"])])
    if config_values["extra_terms"]:
        cmd.extend(["--extra-terms", *map(str, config_values["extra_terms"])])
    if config_values["candidate_lags"]:
        cmd.extend(["--candidate-lags", *map(str, config_values["candidate_lags"])])
    if config_values["functional_forms"]:
        cmd.extend(["--functional-forms", *map(str, config_values["functional_forms"])])
    if config_values["instruments"]:
        cmd.extend(["--instruments", *map(str, config_values["instruments"])])
    if config_values["manuscript_figures_dir"]:
        cmd.extend(["--manuscript-figures-dir", str(config_values["manuscript_figures_dir"])])
    if config_values["output_dir"]:
        cmd.extend(["--output-dir", str(config_values["output_dir"])])
    if config_values["appendix_dir"]:
        cmd.extend(["--appendix-dir", str(config_values["appendix_dir"])])
    return cmd


def run_econometric_engine(args):
    print_header()
    print("📊 Launching Self-Correcting Econometric Engine...")
    cmd = build_engine_command(args)
    print(f"🧪 Command: {' '.join(shlex.quote(part) for part in cmd)}")
    completed = subprocess.run(cmd, check=False, text=True, capture_output=True)
    if completed.stdout:
        print(completed.stdout)
    if completed.returncode != 0:
        if completed.stderr:
            print(completed.stderr)
        raise SystemExit(completed.returncode)
    print("✅ Econometric engine completed.")

def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")

def ensure_stage_dirs():
    RESULTS_PATH.mkdir(parents=True, exist_ok=True)
    SPARRING_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    META_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    SKILL_LIBRARY_DIR.mkdir(parents=True, exist_ok=True)


def write_pipeline_manifest(
    summary_path: Path,
    *,
    socratic_report: dict[str, Any] | None = None,
    meta_report: dict[str, Any] | None = None,
    integrity_result: dict[str, Any] | None = None,
    evolution_report: dict[str, Any] | None = None,
) -> dict[str, str]:
    ensure_stage_dirs()
    project_context = resolve_linked_project_context(summary_path, socratic_report)
    manifest = build_pipeline_manifest(
        socratic_report=socratic_report,
        meta_report=meta_report,
        integrity_result=integrity_result,
        evolution_report=evolution_report,
    )
    timestamp = datetime.now().strftime("%Y%m%dT%H%M%S")
    slug = slugify(summary_path.stem)
    manifest_dict = {
        "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "summary_path": str(summary_path),
        "project_name": project_context["project_name"],
        "project_root": project_context["project_root"],
        "manifest": manifest.model_dump(by_alias=True),
    }
    json_path = MANIFEST_OUTPUT_DIR / f"pipeline-manifest-{slug}-{timestamp}.json"
    md_path = MANIFEST_OUTPUT_DIR / f"pipeline-manifest-{slug}-{timestamp}.md"
    json_path.write_text(json.dumps(manifest_dict, indent=2, ensure_ascii=False), encoding="utf-8")

    md_lines = [
        "# Pipeline Run Manifest",
        "",
        f"- Generated: {manifest_dict['generated_at']}",
        f"- Summary: `{manifest_dict['summary_path']}`",
        f"- Project: `{manifest_dict['project_name']}`",
        f"- Project root: `{manifest_dict['project_root']}`",
        "",
        "## Included Stages",
    ]
    for stage_name in ["stage_04_5", "stage_07", "stage_08", "stage_11"]:
        stage_payload = manifest_dict["manifest"].get(stage_name)
        status = "included" if stage_payload else "not included"
        md_lines.append(f"- `{stage_name}`: {status}")
    md_lines.extend(["", "## Manifest JSON", "```json", json.dumps(manifest_dict["manifest"], indent=2, ensure_ascii=False), "```"])
    md_path.write_text("\n".join(md_lines) + "\n", encoding="utf-8")
    return {"json": str(json_path), "markdown": str(md_path)}

def load_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")

def discover_csv_files(limit: int = MAX_AUDITED_FILES) -> list[Path]:
    files = sorted(DATA_VAULT_PATH.rglob("*.csv"))
    preferred = [p for p in files if "data_clean" in str(p).lower() or "panel" in p.name.lower()]
    ranked = preferred + [p for p in files if p not in preferred]
    return ranked[:limit]

def parse_numeric_claims(summary_path: Path) -> list[dict[str, Any]]:
    claims = []
    text = load_text(summary_path)
    current_section = ""
    for line in text.splitlines():
        if line.startswith("## "):
            current_section = line.strip()
            continue
        match = re.match(r"-\s+([^:]+):\s+(.+)$", line.strip())
        if not match:
            continue
        label = match.group(1).strip()
        value_text = match.group(2).strip()
        if current_section == "## Top Matched Documents":
            continue
        if "score=" in value_text.lower():
            continue
        numeric_match = re.search(r"-?\d+(?:\.\d+)?", value_text.replace(",", ""))
        if not numeric_match:
            continue
        claims.append(
            {
                "label": label,
                "value": float(numeric_match.group(0)),
                "raw_value": value_text,
                "topic_key": infer_topic_key(label),
            }
        )
    return claims

def infer_topic_key(label: str) -> str:
    lowered = label.lower()
    for topic_key, aliases in CLAIM_ALIASES.items():
        if any(alias in lowered for alias in aliases):
            return topic_key
    return slugify(label)

def safe_float(value: str) -> float | None:
    try:
        cleaned = value.replace(",", "").strip()
        if cleaned == "":
            return None
        return float(cleaned)
    except (TypeError, ValueError):
        return None

def sniff_numeric_columns(csv_path: Path) -> list[dict[str, Any]]:
    columns = []
    try:
        with csv_path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            if not reader.fieldnames:
                return columns
            samples: dict[str, list[float]] = {field: [] for field in reader.fieldnames}
            preview_rows = []
            for row_index, row in enumerate(reader):
                if row_index < CSV_PREVIEW_ROWS:
                    preview_rows.append(row)
                for field, value in row.items():
                    numeric = safe_float(value or "")
                    if numeric is not None and len(samples[field]) < 100:
                        samples[field].append(numeric)
                if row_index >= 250:
                    break

            for field, values in samples.items():
                if not values:
                    continue
                lowered = field.lower()
                columns.append(
                    {
                        "column": field,
                        "topic_key": infer_topic_key(lowered),
                        "min": min(values),
                        "max": max(values),
                        "sample_size": len(values),
                        "preview": preview_rows[:CSV_PREVIEW_ROWS],
                    }
                )
    except Exception as exc:
        logger.warning("Failed to inspect CSV %s: %s", csv_path, exc)
    return columns

def build_data_audit(summary_path: Path) -> dict[str, Any]:
    claims = parse_numeric_claims(summary_path)
    csv_files = discover_csv_files()
    catalog = []
    for csv_path in csv_files:
        column_profiles = sniff_numeric_columns(csv_path)
        if column_profiles:
            catalog.append({"path": str(csv_path), "columns": column_profiles})

    findings = []
    for claim in claims:
        matches = []
        for dataset in catalog:
            for profile in dataset["columns"]:
                if profile["topic_key"] == claim["topic_key"]:
                    matches.append(
                        {
                            "path": dataset["path"],
                            "column": profile["column"],
                            "min": profile["min"],
                            "max": profile["max"],
                            "sample_size": profile["sample_size"],
                        }
                    )

        if not matches:
            findings.append(
                {
                    "claim": claim["label"],
                    "status": "warning",
                    "severity": "medium",
                    "message": "No matching CSV column found in the audited vault slice.",
                    "evidence": [],
                }
            )
            continue

        supported = any(match["min"] <= claim["value"] <= match["max"] for match in matches)
        findings.append(
            {
                "claim": claim["label"],
                "status": "supported" if supported else "red_flag",
                "severity": "low" if supported else "high",
                "message": (
                    "Claim falls inside the observed range of at least one matching CSV column."
                    if supported
                    else "Claim sits outside the observed range of the audited CSV columns."
                ),
                "evidence": matches[:5],
            }
        )

    red_flags = [finding for finding in findings if finding["status"] == "red_flag"]
    return {
        "audited_files": len(catalog),
        "claims_checked": len(claims),
        "red_flag_count": len(red_flags),
        "findings": findings,
        "catalog_sample": catalog[:5],
    }

def build_cynical_peer_review(summary_path: Path, data_audit: dict[str, Any]) -> dict[str, Any]:
    summary_text = load_text(summary_path)
    numeric_claims = parse_numeric_claims(summary_path)
    latest_year = next((claim["value"] for claim in numeric_claims if claim["label"].lower() == "latest year"), None)
    red_flag_count = data_audit["red_flag_count"]

    attacks = [
        {
            "severity": "critical",
            "title": "Identification gap",
            "body": "The draft currently reads like a descriptive summary, not a defended empirical design. A reviewer will ask what causal or inferential warrant justifies moving from correlations to policy claims."
        },
        {
            "severity": "high",
            "title": "Endogeneity risk",
            "body": "Key macro variables in Q56 work often move together. Unless the design addresses simultaneity, reverse causality, or omitted transition dynamics, the strongest claims will look fragile."
        },
        {
            "severity": "high",
            "title": "Robustness burden",
            "body": "A Q1 reviewer will ask for sensitivity checks across alternative model forms, subsamples, lag structures, and post-shock periods before accepting the headline interpretation."
        },
    ]
    if latest_year is not None:
        attacks.append(
            {
                "severity": "medium",
                "title": "Temporal instability",
                "body": f"The latest summary point appears to anchor on {int(latest_year)}. Reviewers may argue that post-2020 structural breaks make pre-break regularities unreliable unless explicitly modeled."
            }
        )
    if red_flag_count:
        attacks.append(
            {
                "severity": "critical",
                "title": "Evidence mismatch",
                "body": f"The data auditor raised {red_flag_count} red flag(s). Any unsupported descriptive statistic will immediately weaken trust in the rest of the manuscript."
            }
        )

    weaknesses = []
    if "medium-confidence matches" in summary_text.lower():
        weaknesses.append("Literature grounding still looks noisy; medium-confidence matches need manual pruning before they are used as support.")
    weaknesses.append("The empirical summary does not yet articulate boundary conditions, alternative mechanisms, or where the claim should fail.")
    weaknesses.append("No defense is visible yet for measurement error, country heterogeneity, or publication-bias-sensitive framing.")

    return {
        "agent": "cynical_peer_reviewer",
        "attacks": attacks,
        "weakness_map": weaknesses,
    }

def build_synthesis_mediator(summary_path: Path, peer_review: dict[str, Any], data_audit: dict[str, Any]) -> dict[str, Any]:
    priority_items = []
    for attack in peer_review["attacks"]:
        if attack["severity"] in {"critical", "high"}:
            priority_items.append(attack["title"])
    for finding in data_audit["findings"]:
        if finding["status"] == "red_flag":
            priority_items.append(f"Verify statistic: {finding['claim']}")

    instruction = (
        "Write the Stage 05 discussion and limitations sections so that they answer the priority attacks directly. "
        "Every strong claim must be paired with a mechanism, a limitation, and a robustness sentence."
    )
    if data_audit["red_flag_count"]:
        instruction += " Remove or soften any numerical statement that is not traceable to an audited CSV range."

    return {
        "agent": "synthesis_mediator",
        "priority_repairs": priority_items[:8],
        "stage_05_instruction": instruction,
        "recommended_sections": [
            "Identification and inferential scope",
            "Why alternative explanations remain plausible",
            "Data quality, measurement, and audited statistics",
            "Robustness and post-shock sensitivity",
        ],
    }

def build_agent_transcript(peer_review: dict[str, Any], data_audit: dict[str, Any], mediator: dict[str, Any]) -> list[dict[str, Any]]:
    transcript = []
    for attack in peer_review["attacks"]:
        transcript.append(
            {
                "from": "cynical_peer_reviewer",
                "to": "synthesis_mediator",
                "message_type": "critique",
                "severity": attack["severity"],
                "content": f"{attack['title']}: {attack['body']}",
            }
        )
    for finding in data_audit["findings"]:
        transcript.append(
            {
                "from": "data_auditor",
                "to": "synthesis_mediator",
                "message_type": "audit",
                "severity": finding["severity"],
                "content": f"{finding['claim']}: {finding['message']}",
            }
        )
    transcript.append(
        {
            "from": "synthesis_mediator",
            "to": "stage_05_drafting",
            "message_type": "instruction",
            "severity": "high",
            "content": mediator["stage_05_instruction"],
        }
    )
    return transcript

def render_markdown_report(report: dict[str, Any]) -> str:
    lines = [
        "## Adversarial Multi-Agent Socratic Lab Report",
        f"**Generated:** {report['generated_at']}",
        f"**Summary Input:** `{report['summary_path']}`",
        "",
        "### Stage 04.5 Weakness Map",
        f"- Red flags: {report['data_auditor']['red_flag_count']}",
        f"- Audited CSV files: {report['data_auditor']['audited_files']}",
        f"- Numeric claims checked: {report['data_auditor']['claims_checked']}",
        "",
        "### Cynical Peer Reviewer",
    ]
    for attack in report["cynical_peer_reviewer"]["attacks"]:
        lines.append(f"- **{attack['severity'].upper()} | {attack['title']}**: {attack['body']}")

    lines.extend(["", "### Data Auditor"])
    for finding in report["data_auditor"]["findings"]:
        lines.append(f"- **{finding['status'].upper()} | {finding['claim']}**: {finding['message']}")

    lines.extend(["", "### Synthesis Mediator", f"- **Stage 05 Command:** {report['synthesis_mediator']['stage_05_instruction']}", "", "### Priority Repairs"])
    for item in report["synthesis_mediator"]["priority_repairs"]:
        lines.append(f"- {item}")
    return "\n".join(lines) + "\n"

def infer_project_context(summary_path: Path) -> dict[str, Any]:
    project_dir = next((parent for parent in summary_path.parents if parent.name == "03-Results"), None)
    if project_dir:
        root = project_dir.parent
    else:
        root = summary_path.parent
        if root.name == "results" and root.parent != root:
            root = root.parent
    manuscript_dir = root / "04-Manuscript"
    admin_dir = root / "01-Admin"
    return {
        "project_root": str(root),
        "project_name": root.name,
        "manuscript_dir": str(manuscript_dir),
        "admin_dir": str(admin_dir),
    }


def resolve_linked_project_context(
    summary_path: Path,
    socratic_report: dict[str, Any] | None = None,
) -> dict[str, Any]:
    base = infer_project_context(summary_path)
    if socratic_report:
        candidate_names = []
        for finding in socratic_report.get("data_auditor", {}).get("findings", []):
            evidence = finding.get("evidence")
            evidence_items = evidence if isinstance(evidence, list) else [evidence]
            for item in evidence_items:
                if not isinstance(item, dict):
                    continue
                path_value = item.get("path")
                if not path_value:
                    continue
                match = re.search(r"/400-Data/([^/]+)/", str(path_value))
                if match:
                    candidate_names.append(match.group(1))
        for name in candidate_names:
            linked_root = config.PROJECTS_DIR / "310-Active-Papers" / name
            if linked_root.exists():
                return {
                    "project_root": str(linked_root),
                    "project_name": linked_root.name,
                    "manuscript_dir": str(linked_root / "04-Manuscript"),
                    "admin_dir": str(linked_root / "01-Admin"),
                    "methods_root": base["project_root"],
                }
    return {**base, "methods_root": base["project_root"]}

def collect_active_audit_layers(peer_review: dict[str, Any], data_audit: dict[str, Any]) -> list[dict[str, str]]:
    joined_text = " ".join(
        [attack["title"] + " " + attack["body"] for attack in peer_review["attacks"]]
        + [finding["message"] for finding in data_audit["findings"]]
    ).lower()
    selected = []
    for rule in META_AUDIT_RULES:
        if any(trigger in joined_text for trigger in rule["triggers"]):
            selected.append({"name": rule["name"], "layer": rule["layer"]})
    if data_audit["red_flag_count"] and not any(item["name"] == "evidence_traceability" for item in selected):
        selected.append(
            {
                "name": "evidence_traceability",
                "layer": "Block unsupported statistics unless linked to an audited data artifact.",
            }
        )
    return selected

def extract_reusable_skill_assets(project_root: Path) -> list[str]:
    methods_dir = project_root / "02-Methods"
    if not methods_dir.exists():
        return []
    reusable = []
    for path in sorted(methods_dir.iterdir()):
        if path.is_file() and path.suffix in {".py", ".R", ".qmd", ".sh"}:
            reusable.append(str(path))
    return reusable[:12]

def build_watchtower_brief(summary_path: Path, project_context: dict[str, Any]) -> dict[str, Any]:
    summary_text = load_text(summary_path).lower()
    trend_signals = []
    candidate_trends = [
        ("green transition", ["green growth", "green transition", "sustainab"]),
        ("digitalization", ["digital", "digit", "technology"]),
        ("ai impact", ["ai", "artificial intelligence", "machine learning"]),
        ("energy security", ["energy", "electricity", "renewable"]),
        ("climate policy", ["climate", "carbon", "ecological", "emission"]),
    ]
    for label, patterns in candidate_trends:
        score = sum(1 for pattern in patterns if pattern in summary_text)
        if score:
            trend_signals.append({"theme": label, "score": score})
    trend_signals.sort(key=lambda item: item["score"], reverse=True)

    hypotheses = []
    for signal in trend_signals[:3]:
        if signal["theme"] == "ai impact":
            hypotheses.append("Test whether AI adoption or digital capability moderates the core environmental or productivity relationship.")
        elif signal["theme"] == "green transition":
            hypotheses.append("Frame the contribution against green-transition heterogeneity rather than average treatment language.")
        elif signal["theme"] == "energy security":
            hypotheses.append("Add an energy-security or energy-intensity channel test to strengthen mechanism credibility.")
        elif signal["theme"] == "climate policy":
            hypotheses.append("Link the findings to ecological constraint and climate-policy timing to sharpen 'why now'.")
        elif signal["theme"] == "digitalization":
            hypotheses.append("Probe digitalization as either a moderator or a sample-splitting dimension for next-cycle work.")

    return {
        "project": project_context["project_name"],
        "signals": trend_signals[:5],
        "next_hypotheses": hypotheses[:4],
        "monitoring_prompt": (
            "Track new literature, desk-reject risks, and adjacent mechanisms that could reposition this manuscript "
            "or seed the next paper in the same family."
        ),
    }

def build_meta_directive(summary_path: Path, peer_review: dict[str, Any], data_audit: dict[str, Any]) -> dict[str, Any]:
    active_layers = collect_active_audit_layers(peer_review, data_audit)
    priority_failures = []
    priority_failures.extend(attack["title"] for attack in peer_review["attacks"] if attack["severity"] in {"critical", "high"})
    priority_failures.extend(finding["claim"] for finding in data_audit["findings"] if finding["status"] == "red_flag")
    return {
        "stage": "07",
        "objective": "Convert critique into persistent workflow upgrades for the next manuscript cycle.",
        "source_summary": str(summary_path),
        "priority_failures": priority_failures[:8],
        "active_audit_layers": active_layers,
        "meta_prompt_patch": (
            "Before drafting final prose, state the identification claim, list two alternative explanations, "
            "name the strongest robustness check, and remove any statistic that cannot be traced to audited data."
        ),
        "promotion_rule": (
            "Any repeated critique observed across two projects must be promoted from note-level advice to a mandatory audit layer."
        ),
    }

def render_meta_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Stage 07 Self-Evolving Research & Meta-Logic",
        "",
        f"- Generated: {report['generated_at']}",
        f"- Project: `{report['project']['project_name']}`",
        f"- Source summary: `{report['meta_directive']['source_summary']}`",
        "",
        "## Evolution Log",
    ]
    for item in report["meta_directive"]["priority_failures"]:
        lines.append(f"- {item}")

    lines.extend(["", "## Activated Audit Layers"])
    for layer in report["meta_directive"]["active_audit_layers"]:
        lines.append(f"- `{layer['name']}`: {layer['layer']}")

    lines.extend(["", "## Watchtower Signals"])
    for signal in report["watchtower"]["signals"]:
        lines.append(f"- {signal['theme']}: score={signal['score']}")

    lines.extend(["", "## Next Hypotheses"])
    for item in report["watchtower"]["next_hypotheses"]:
        lines.append(f"- {item}")

    lines.extend(["", "## Reusable Skill Assets"])
    if report["skill_library"]["reusable_assets"]:
        for asset in report["skill_library"]["reusable_assets"]:
            lines.append(f"- `{asset}`")
    else:
        lines.append("- No reusable method assets detected.")

    lines.extend(
        [
            "",
            "## Meta Prompt Patch",
            report["meta_directive"]["meta_prompt_patch"],
            "",
            "## Promotion Rule",
            report["meta_directive"]["promotion_rule"],
        ]
    )
    return "\n".join(lines) + "\n"

def render_submission_strategy(report: dict[str, Any]) -> str:
    lines = [
        "# Submission Strategy",
        "",
        f"- Project: `{report['project']['project_name']}`",
        f"- Generated: `{report['generated_at']}`",
        "",
        "## Editor-Facing Risk Map",
    ]
    for item in report["meta_directive"]["priority_failures"]:
        lines.append(f"- {item}")

    lines.extend(["", "## Mandatory Audit Layers Before Submission"])
    for layer in report["meta_directive"]["active_audit_layers"]:
        lines.append(f"- `{layer['name']}`: {layer['layer']}")

    lines.extend(["", "## Why Now"])
    if report["watchtower"]["next_hypotheses"]:
        for item in report["watchtower"]["next_hypotheses"][:3]:
            lines.append(f"- {item}")
    else:
        lines.append("- Reconfirm the manuscript's timing against the latest field debate before submission.")

    lines.extend(
        [
            "",
            "## Cover Letter Guidance",
            f"- Emphasize journal fit through the manuscript's strongest mechanism and scope match.",
            f"- State the contribution cautiously: {report['meta_directive']['meta_prompt_patch']}",
            "",
            "## Reviewer Suggestion Guardrails",
            "- Prefer recent, method-relevant authors outside the authors' institutions and frequent coauthor network.",
            "- Exclude any reviewer candidate with visible institutional overlap or direct collaboration risk.",
        ]
    )
    return "\n".join(lines) + "\n"

def update_project_memory(report: dict[str, Any]) -> dict[str, str]:
    admin_dir = Path(report["project"]["admin_dir"])
    admin_dir.mkdir(parents=True, exist_ok=True)
    project_state_path = admin_dir / "PROJECT_STATE.md"
    research_state_path = admin_dir / "RESEARCH_STATE.md"
    task_path = admin_dir / "TASK.md"
    submission_strategy_path = admin_dir / "submission_strategy.md"

    summary_lines = [
        "## Stage 07 Meta-Learning",
        f"- Generated: {report['generated_at']}",
        f"- Priority failures: {', '.join(report['meta_directive']['priority_failures'][:5]) or 'None'}",
        f"- Audit layers: {', '.join(layer['name'] for layer in report['meta_directive']['active_audit_layers']) or 'None'}",
        f"- Meta report: `{report['artifacts']['markdown']}`",
        "",
    ]
    summary_block = "\n".join(summary_lines)

    existing_project_state = project_state_path.read_text(encoding="utf-8") if project_state_path.exists() else "# PROJECT STATE\n\n"
    if "## Stage 07 Meta-Learning" not in existing_project_state:
        existing_project_state = existing_project_state.rstrip() + "\n\n" + summary_block
    else:
        existing_project_state = re.sub(
            r"## Stage 07 Meta-Learning[\s\S]*?(?=\n## |\Z)",
            summary_block.rstrip(),
            existing_project_state,
        )
    project_state_path.write_text(existing_project_state.rstrip() + "\n", encoding="utf-8")

    research_state_lines = [
        "# RESEARCH STATE",
        "",
        f"- Project: {report['project']['project_name']}",
        "- Last completed step: Stage 07 Self-Evolving Research & Meta-Logic",
        f"- Next step: Apply audit layers in submission-facing prose and reviewer strategy.",
        f"- Risks: {', '.join(report['meta_directive']['priority_failures'][:4]) or 'None'}",
        f"- Source summary: {report['meta_directive']['source_summary']}",
        f"- Meta artifact: {report['artifacts']['markdown']}",
    ]
    research_state_path.write_text("\n".join(research_state_lines) + "\n", encoding="utf-8")

    task_lines = [
        "# TASK",
        "",
        "- Current stage: Stage 09 submission strategy hardening",
        "- Immediate action: fold Stage 07 audit layers into cover letter, journal fit, and final manuscript claims.",
        f"- Active strategy note: `{submission_strategy_path}`",
    ]
    task_path.write_text("\n".join(task_lines) + "\n", encoding="utf-8")
    submission_strategy_path.write_text(render_submission_strategy(report), encoding="utf-8")

    return {
        "project_state": str(project_state_path),
        "research_state": str(research_state_path),
        "task": str(task_path),
        "submission_strategy": str(submission_strategy_path),
    }

def run_stage_07_meta_logic(summary_path: Path, socratic_report: dict[str, Any]) -> dict[str, Any]:
    ensure_stage_dirs()
    project_context = infer_project_context(summary_path)
    peer_review = socratic_report["cynical_peer_reviewer"]
    data_audit = socratic_report["data_auditor"]
    meta_directive = build_meta_directive(summary_path, peer_review, data_audit)
    watchtower = build_watchtower_brief(summary_path, project_context)
    skill_library = {
        "project": project_context["project_name"],
        "reusable_assets": extract_reusable_skill_assets(Path(project_context["project_root"])),
    }
    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    report = {
        "stage": "07",
        "generated_at": generated_at,
        "project": project_context,
        "meta_directive": meta_directive,
        "watchtower": watchtower,
        "skill_library": skill_library,
    }
    timestamp = datetime.now().strftime("%Y%m%dT%H%M%S")
    slug = slugify(project_context["project_name"])
    json_path = META_OUTPUT_DIR / f"meta-logic-{slug}-{timestamp}.json"
    md_path = META_OUTPUT_DIR / f"meta-logic-{slug}-{timestamp}.md"
    skill_path = SKILL_LIBRARY_DIR / f"{slug}-latest.json"
    json_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    md_path.write_text(render_meta_markdown(report), encoding="utf-8")
    skill_path.write_text(json.dumps(skill_library, indent=2, ensure_ascii=False), encoding="utf-8")
    report["artifacts"] = {"json": str(json_path), "markdown": str(md_path), "skill_library": str(skill_path)}
    report["memory_updates"] = update_project_memory(report)
    return report

def run_socratic_lab(summary_path: Path) -> dict[str, Any]:
    ensure_stage_dirs()
    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    data_audit = build_data_audit(summary_path)
    peer_review = build_cynical_peer_review(summary_path, data_audit)
    mediator = build_synthesis_mediator(summary_path, peer_review, data_audit)
    transcript = build_agent_transcript(peer_review, data_audit, mediator)
    report = {
        "stage": "04.5",
        "generated_at": generated_at,
        "summary_path": str(summary_path),
        "data_vault_root": str(DATA_VAULT_PATH),
        "cynical_peer_reviewer": peer_review,
        "data_auditor": data_audit,
        "synthesis_mediator": mediator,
        "agent_transcript": transcript,
    }

    timestamp = datetime.now().strftime("%Y%m%dT%H%M%S")
    base_name = f"socratic-lab-{timestamp}"
    json_path = SPARRING_OUTPUT_DIR / f"{base_name}.json"
    md_path = SPARRING_OUTPUT_DIR / f"{base_name}.md"
    json_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    md_path.write_text(render_markdown_report(report), encoding="utf-8")
    report["artifacts"] = {"json": str(json_path), "markdown": str(md_path)}
    return report


def run_integrity_check(project_hint: str | None = None) -> dict[str, str | int]:
    report_dir = config.EXPORTS_DIR / "integrity_reports"
    report_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%dT%H%M%S")
    json_path = report_dir / f"integrity-{timestamp}.json"
    md_path = report_dir / f"integrity-{timestamp}.md"

    command = [
        sys.executable,
        str(config.PROJECT_ROOT / "nexus_integrity_guard.py"),
        "--check-claims",
        "--semantic-check",
        "--output",
        str(json_path),
        "--markdown",
        str(md_path),
    ]
    if project_hint:
        command.extend(["--project", project_hint])

    result = subprocess.run(command, capture_output=True, text=True, check=False)
    return {
        "returncode": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
        "json": str(json_path),
        "markdown": str(md_path),
    }


def build_grounded_evidence_cache(project_hint: str | None = None) -> dict[str, str | int]:
    command = [
        sys.executable,
        str(config.DASHBOARD_DIR / "build_grounded_evidence.py"),
    ]
    if project_hint:
        command.extend(["--project", project_hint])
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    return {
        "returncode": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
    }

async def trigger_n8n_workflow(wf_id, name):
    print(f"📡 Triggering n8n Workflow: {name} (ID: {wf_id})...")
    url = f"{config.N8N_URL}/api/v1/workflows/{wf_id}/run"
    headers = {"X-N8N-API-KEY": os.getenv("N8N_API_KEY")}
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(url, headers=headers, timeout=30.0)
            if response.status_code in [200, 201]:
                print(f"✅ {name} initiated successfully.")
                return True
            else:
                print(f"❌ Error triggering {name}: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            print(f"❌ Connection Error (n8n): {str(e)}")
            return False

def check_files():
    """Checks if new files have been created in the last 10 minutes."""
    if not RESULTS_PATH.exists():
        return False
        
    files = list(RESULTS_PATH.glob("empirical-summary-*.md"))
    csv_files = list(RESULTS_PATH.glob("*.csv")) # Some workflows might output csv here
    
    if not files:
        return False
        
    latest_file = max(files, key=os.path.getmtime)
    mtime = os.path.getmtime(latest_file)
    # Check if updated in the last 10 mins
    if time.time() - mtime < 600:
        return latest_file
    return False

async def trigger_stage_05_synthesis(
    socratic_report: dict[str, Any] | None = None,
    meta_report: dict[str, Any] | None = None,
    evolution_report: dict[str, Any] | None = None,
):
    print("\n🧠 Handing over to DeepSeek-R1 for Scientific Synthesis...")
    payload = {}
    manifest = build_pipeline_manifest(
        socratic_report=socratic_report,
        meta_report=meta_report,
        evolution_report=evolution_report,
    )
    if any([manifest.stage_04_5, manifest.stage_07, manifest.stage_11]):
        payload["manifest"] = manifest.model_dump(by_alias=True)
    
    # Codice Style & Persona Injection (Wave 2)
    payload["meta_prompt_patch"] = admin_prompts.get_drafting_prompt_extension()

    async with httpx.AsyncClient() as client:
        try:
            if payload:
                response = await client.post(f"{config.CORE_API_URL}/report/generate", json=payload, timeout=180.0)
                if response.status_code >= 400:
                    logger.warning("Stage 05 payload rejected (%s). Retrying without payload.", response.status_code)
                    response = await client.post(f"{config.CORE_API_URL}/report/generate", timeout=180.0)
            else:
                response = await client.post(f"{config.CORE_API_URL}/report/generate", timeout=180.0)

            if response.status_code == 200:
                data = response.json()
                manuscript_path = data.get("file")
                print("\n" + "🏆" * 20)
                print("MANUSCRIPT DRAFT GENERATED!")
                print(f"File: {manuscript_path}")
                print(f"Tone: English / Q1 Standard")
                if socratic_report:
                    print(f"Stage 04.5 Report: {socratic_report['artifacts']['json']}")
                print("🏆" * 20 + "\n")
                return manuscript_path
            else:
                print(f"❌ AI Synthesis Failed: {response.text}")
                return None
        except Exception as e:
            print(f"❌ Connection Error (AI Engine): {str(e)}")
            return None

async def run_stylometry_guard(filepath: str):
    """Stage 05.5: Audit the draft and auto-correct if linguistic markers are poor."""
    if not filepath or not os.path.exists(filepath):
        return

    print(f"📝 Running Stage 05.5 Stylometry Guard on {os.path.basename(filepath)}...")
    
    # We call the corrector script which internally runs the audit loop
    cmd = [sys.executable, str(config.PROJECT_ROOT / "stylometry_corrector.py"), filepath]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    
    if result.returncode == 0:
        print("✅ Stylometry Guard: Quality threshold met or correction applied.")
    else:
        print("⚠️ Stylometry Guard encountered an issue during correction.")
        if result.stdout: print(result.stdout)
        if result.stderr: print(result.stderr)

async def run_pipeline():
    print_header()
    ensure_stage_dirs()
    
    # 1. Trigger n8n Data Pipeline
    n8n_data_wf = os.getenv("N8N_WORKFLOW_ID_DATA", "1")
    if not await trigger_n8n_workflow(n8n_data_wf, "Data Extraction"):
        return

    # 2. Trigger Zotero & Obsidian Logic
    n8n_zotero_wf = os.getenv("N8N_WORKFLOW_ID_ZOTERO", "2")
    if not await trigger_n8n_workflow(n8n_zotero_wf, "Zotero-Obsidian Sync"):
        return

    # 3. Polling Verification Loop
    print(f"\n🔍 Monitoring Workspace: {RESULTS_PATH.name}")
    timeout = time.time() + 300  # 5 minutes
    interval = 10
    spinner = Spinner("Waiting for n8n to generate empirical results...")

    found_file = None
    while time.time() < timeout:
        found_file = check_files()
        if found_file:
            print(f"\n✨ SUCCESS: New results detected! -> {found_file.name}")
            break
        
        spinner.spin()
        time.sleep(interval)
    
    if not found_file:
        print(f"\n⌛ TIMEOUT: n8n took too long to produce results. Check n8n logs at {config.N8N_URL}")
        return

    # 4. Stage 04.5 Adversarial Multi-Agent Socratic Lab
    print("\n🧪 Running Stage 04.5: Adversarial Multi-Agent Socratic Lab...")
    socratic_report = run_socratic_lab(found_file)
    print(f"✅ Socratic Lab JSON report: {socratic_report['artifacts']['json']}")
    print(f"✅ Socratic Lab markdown report: {socratic_report['artifacts']['markdown']}")

    # 5. Stage 07 Self-Evolving Research & Meta-Logic
    print("\n🧬 Running Stage 07: Self-Evolving Research & Meta-Logic...")
    meta_report = run_stage_07_meta_logic(found_file, socratic_report)
    print(f"✅ Meta-logic JSON report: {meta_report['artifacts']['json']}")
    print(f"✅ Meta-logic markdown report: {meta_report['artifacts']['markdown']}")
    print(f"✅ Skill library snapshot: {meta_report['artifacts']['skill_library']}")

    # 5.5. Stage 11 Evolutionary Log & Meta-Learning
    print("\n🧠 Running Stage 11: Evolutionary Log & Meta-Learning...")
    evolution_report = run_evolution(found_file, socratic_report, meta_report)
    print(f"✅ Evolution JSON report: {evolution_report['artifacts']['json']}")
    print(f"✅ Evolution markdown report: {evolution_report['artifacts']['markdown']}")
    print(f"✅ Meta skills registry: {evolution_report['artifacts']['meta_skills']}")
    print(f"✅ Dynamic prompt context: {evolution_report['artifacts']['prompt_context']}")

    # 5.6. Stage 10 Autonomous Watchtower
    print("\n🛰️ Running Stage 10: Autonomous Watchtower...")
    watchtower_report = run_watchtower_for_project(Path(meta_report["project"]["project_root"]))
    print(f"✅ Watchtower JSON report: {watchtower_report['artifacts']['json']}")
    print(f"✅ Watchtower markdown report: {watchtower_report['artifacts']['markdown']}")
    print(f"✅ Project watchtower memory: {watchtower_report['memory_updates']['watchtower_memory']}")
    print(f"✅ Global literature radar: {watchtower_report['global_radar']}")

    # 6. Trigger AI Synthesis with Stage 04.5 context
    manuscript_file = await trigger_stage_05_synthesis(socratic_report, meta_report, evolution_report)

    # 6.5. Run Stylometry Guard for linguistic quality
    if manuscript_file:
        await run_stylometry_guard(manuscript_file)

    # 7. Build grounded evidence cache from local PDFs
    print("\n📚 Building grounded evidence cache from project PDFs...")
    evidence = build_grounded_evidence_cache()
    if evidence["returncode"] == 0:
        print("✅ Grounded evidence cache refreshed.")
    else:
        print("⚠️ Grounded evidence cache is partial; some cited sources could not be matched to PDFs.")
        if evidence["stdout"]:
            print(evidence["stdout"])
        elif evidence["stderr"]:
            print(evidence["stderr"])

    # 8. Run citation grounding / integrity pass
    print("\n🛡️ Running Stage 08: Grounding & Semantic Citation Integrity...")
    integrity = run_integrity_check()
    integrity_payload = build_stage_08_payload(integrity)
    if integrity["returncode"] == 0:
        print("✅ Integrity pass completed without blocking issues.")
    else:
        print("⚠️ Integrity pass surfaced citation items for review.")
        if integrity["stdout"]:
            print(integrity["stdout"])
        elif integrity["stderr"]:
            print(integrity["stderr"])
    print(f"✅ Integrity JSON report: {integrity['json']}")
    print(f"✅ Integrity markdown report: {integrity['markdown']}")
    print(f"✅ Integrity payload ready: {integrity_payload.artifacts.json_path}")

    manifest_artifacts = write_pipeline_manifest(
        found_file,
        socratic_report=socratic_report,
        meta_report=meta_report,
        integrity_result=integrity,
        evolution_report=evolution_report,
    )
    print(f"✅ Pipeline manifest JSON: {manifest_artifacts['json']}")
    print(f"✅ Pipeline manifest markdown: {manifest_artifacts['markdown']}")

if __name__ == "__main__":
    import asyncio
    cli_args = parse_args()
    if cli_args.command == "econometrics":
        run_econometric_engine(cli_args)
        raise SystemExit(0)
    try:
        asyncio.run(run_pipeline())
    except KeyboardInterrupt:
        print("\n🛑 Pipeline stopped by user.")
