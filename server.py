import os
import asyncio
import logging
import subprocess
import glob
import json
import re
import httpx
import importlib.util
import importlib.machinery
import sys
from datetime import datetime
from pathlib import Path
from dataclasses import dataclass
from typing import Callable, Optional
import uvicorn
from fastapi import FastAPI, Body, File, UploadFile, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from anthropic import AsyncAnthropic
from openai import AsyncOpenAI
from dotenv import load_dotenv

import config
from dspy_style_optimizer import optimize_manuscript_file, optimize_style, restore_manuscript_backup
from nexus_integrity_guard import scan_project
from nexus_pack import package_submission
from orchestration.nexus_prefect_flow import run_project_autopilot
from stage_payloads import PipelineManifest, ReportGenerateRequest, Stage045Payload, Stage07Payload, Stage11Payload


def ensure_lightrag_compat() -> None:
    """Patch broken LightRAG package layouts that split utils into a package."""
    spec = importlib.machinery.PathFinder.find_spec("lightrag")
    if not spec or not spec.submodule_search_locations:
        return

    package_root = Path(next(iter(spec.submodule_search_locations)))
    utils_pkg = package_root / "utils" / "__init__.py"
    utils_legacy = package_root / "utils.py"

    if not utils_pkg.exists() or not utils_legacy.exists():
        return

    package_module = sys.modules.get("lightrag")
    if package_module is None:
        package_spec = importlib.util.spec_from_loader("lightrag", loader=None)
        package_module = importlib.util.module_from_spec(package_spec)
        package_module.__path__ = [str(package_root)]
        sys.modules["lightrag"] = package_module

    utils_module = sys.modules.get("lightrag.utils")
    if utils_module is None:
        utils_spec = importlib.util.spec_from_file_location(
            "lightrag.utils",
            utils_pkg,
            submodule_search_locations=[str(utils_pkg.parent)],
        )
        if utils_spec and utils_spec.loader:
            utils_module = importlib.util.module_from_spec(utils_spec)
            sys.modules["lightrag.utils"] = utils_module
            utils_spec.loader.exec_module(utils_module)

    legacy_spec = importlib.util.spec_from_file_location("lightrag_legacy_utils", utils_legacy)
    if not legacy_spec or not legacy_spec.loader or utils_module is None:
        return

    legacy_module = importlib.util.module_from_spec(legacy_spec)
    sys.modules["lightrag_legacy_utils"] = legacy_module
    legacy_spec.loader.exec_module(legacy_module)

    if not hasattr(utils_module, "get_env_value") and hasattr(legacy_module, "get_env_value"):
        setattr(utils_module, "get_env_value", legacy_module.get_env_value)
        exported = list(getattr(utils_module, "__all__", []))
        if "get_env_value" not in exported:
            exported.append("get_env_value")
            utils_module.__all__ = exported


ensure_lightrag_compat()

from lightrag import LightRAG, QueryParam

# Configuration
logger = config.setup_logging("akademik_karargah")

# --- Dynamic Base Directory (Portability) ---
BASE_DIR = config.PROJECT_ROOT
WORKING_DIR = BASE_DIR / "lightrag_db"
logger.info(f"System Base: {BASE_DIR}")

@dataclass
class ModelFunc:
    func: Callable
    async def __call__(self, *args, **kwargs):
        return await self.func(*args, **kwargs)

@dataclass
class EmbeddingFunc:
    func: Callable
    embedding_dim: int = 1536
    async def __call__(self, *args, **kwargs):
        return await self.func(*args, **kwargs)


def format_stage_04_5_context(stage_data: Stage045Payload | None) -> str:
    if not stage_data:
        return ""

    lines = ["### STAGE 04.5 SOCRATIC LAB CONTEXT"]
    instruction = stage_data.stage_05_instruction
    if instruction:
        lines.append(f"- Stage 05 instruction: {instruction}")

    red_flag_count = stage_data.red_flag_count
    if red_flag_count is not None:
        lines.append(f"- Data auditor red flags: {red_flag_count}")

    priority_repairs = stage_data.priority_repairs
    if priority_repairs:
        lines.append("- Priority repairs:")
        for item in priority_repairs[:10]:
            lines.append(f"  - {item}")

    artifact_json = stage_data.artifacts.json_path
    if artifact_json:
        lines.append(f"- Sparring report JSON: {artifact_json}")

    return "\n".join(lines)


def format_stage_07_context(stage_data: Stage07Payload | None) -> str:
    if not stage_data:
        return ""

    lines = ["### STAGE 07 META-LOGIC CONTEXT"]
    if stage_data.project:
        lines.append(f"- Project context: {stage_data.project}")

    if stage_data.meta_prompt_patch:
        lines.append(f"- Meta prompt patch: {stage_data.meta_prompt_patch}")

    if stage_data.priority_failures:
        lines.append("- Persistent failure modes:")
        for item in stage_data.priority_failures[:6]:
            lines.append(f"  - {item}")

    if stage_data.active_audit_layers:
        lines.append("- Mandatory audit layers:")
        for layer in stage_data.active_audit_layers[:5]:
            lines.append(f"  - {layer.name}: {layer.layer}")

    if stage_data.next_hypotheses:
        lines.append("- Watchtower next hypotheses:")
        for item in stage_data.next_hypotheses[:3]:
            lines.append(f"  - {item}")

    if stage_data.signals:
        rendered = ", ".join(f"{signal.theme}({signal.score})" for signal in stage_data.signals[:4])
        lines.append(f"- Trend signals: {rendered}")

    return "\n".join(lines)


def format_stage_11_context(stage_data: Stage11Payload | None) -> str:
    if not stage_data:
        return ""

    lines = ["### STAGE 11 DYNAMIC META PROMPT"]
    if stage_data.project_type:
        lines.append(f"- Project type: {stage_data.project_type}")
    if stage_data.risk_gaps:
        lines.append(f"- Active risk gaps: {', '.join(stage_data.risk_gaps)}")
    if stage_data.selected_injections:
        lines.append("- Selected prompt injections:")
        for item in stage_data.selected_injections[:5]:
            lines.append(f"  - [{item.skill_key}] {item.instruction}")
    if stage_data.reviewer_checklist:
        lines.append("- Reviewer-derived checklist:")
        for item in stage_data.reviewer_checklist[:6]:
            lines.append(f"  - {item}")
    if stage_data.style_patterns:
        lines.append("- Reusable style patterns:")
        for item in stage_data.style_patterns[:3]:
            lines.append(f"  - {item}")
    if stage_data.prompt_text:
        lines.append("")
        lines.append(stage_data.prompt_text.strip())
    return "\n".join(lines)


def read_text_if_exists(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="ignore")


def slugify(value: str) -> str:
    lowered = value.lower()
    cleaned = "".join(char if char.isalnum() else "-" for char in lowered)
    return "-".join(part for part in cleaned.split("-") if part)


def parse_evolution_timestamp(path: Path) -> str:
    match = re.search(r"(\d{8}T\d{6})", path.name)
    return match.group(1) if match else ""


def load_evolution_metadata(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def load_manifest_metadata(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def load_pipeline_manifest(summary_path: Path) -> tuple[PipelineManifest | None, dict]:
    manifest_path = find_best_pipeline_manifest(summary_path)
    if not manifest_path:
        return None, {}
    payload = load_manifest_metadata(manifest_path)
    manifest_data = payload.get("manifest")
    if not manifest_data:
        return None, payload
    try:
        return PipelineManifest.model_validate(manifest_data), payload
    except Exception:
        return None, payload


def find_latest_manifest_payload() -> dict:
    manifest_dirs = config.METHODS_DIR.glob("530-Econometric-Analysis/*/results/pipeline-run-manifests")
    best: tuple[float, dict] | None = None
    for manifest_dir in manifest_dirs:
        for path in manifest_dir.glob("*.json"):
            payload = load_manifest_metadata(path)
            mtime = os.path.getmtime(path)
            enriched = {**payload, "manifest_path": str(path)}
            if best is None or mtime > best[0]:
                best = (mtime, enriched)
    return best[1] if best else {}


def resolve_project_hint(project_hint: str | None = None) -> tuple[str | None, dict]:
    if project_hint:
        return project_hint, {}
    payload = find_latest_manifest_payload()
    return payload.get("project_name"), payload


def update_manifest_lifecycle(
    manifest_path: str | Path | None,
    *,
    report_artifact: str | None = None,
    watchtower_artifact: str | None = None,
    package_artifact: str | None = None,
    orchestration_run: dict | None = None,
) -> dict:
    if not manifest_path:
        return {}
    path = Path(manifest_path)
    if not path.exists():
        return {}
    payload = load_manifest_metadata(path)
    lifecycle = payload.get("lifecycle", {}) or {}
    updated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lifecycle["updated_at"] = updated_at
    if report_artifact:
        lifecycle["report_artifact"] = report_artifact
    if watchtower_artifact:
        lifecycle["watchtower_artifact"] = watchtower_artifact
    if package_artifact:
        lifecycle["package_artifact"] = package_artifact
    if orchestration_run:
        lifecycle["orchestration_run"] = orchestration_run
    payload["lifecycle"] = lifecycle
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    return lifecycle


def find_best_pipeline_manifest(summary_path: Path) -> Path | None:
    manifest_dirs = config.METHODS_DIR.glob("530-Econometric-Analysis/*/results/pipeline-run-manifests")
    summary_str = str(summary_path)
    best_match: tuple[int, float, Path] | None = None
    for manifest_dir in manifest_dirs:
        for path in manifest_dir.glob("*.json"):
            payload = load_manifest_metadata(path)
            manifest_summary = str(payload.get("summary_path", ""))
            score = 0
            if manifest_summary == summary_str:
                score += 10
            elif manifest_summary and (manifest_summary in summary_str or summary_str in manifest_summary):
                score += 6
            if score <= 0:
                continue
            candidate = (score, os.path.getmtime(path), path)
            if best_match is None or candidate > best_match:
                best_match = candidate
    return best_match[2] if best_match else None


def infer_project_root_from_summary(summary_path: Path) -> Path | None:
    manifest_path = find_best_pipeline_manifest(summary_path)
    if manifest_path:
        payload = load_manifest_metadata(manifest_path)
        project_root = payload.get("project_root")
        if project_root:
            return Path(project_root)

    parts = summary_path.resolve().parts
    if "300-Projects" in parts:
        idx = parts.index("300-Projects")
        if len(parts) > idx + 2:
            return Path(*parts[: idx + 3])

    evolution_path = find_best_dynamic_prompt_context(summary_path)
    if evolution_path:
        timestamp = parse_evolution_timestamp(evolution_path)
        if timestamp:
            prompt_dir = config.RESULTS_DIR / "stage-11-evolution"
            pattern = f"evolution-*-{timestamp}.json"
            for candidate in prompt_dir.glob(pattern):
                payload = load_evolution_metadata(candidate)
                project_root = payload.get("project_snapshot", {}).get("project_root")
                if project_root:
                    return Path(project_root)
    return None


def find_project_watchtower(summary_path: Path) -> Path | None:
    project_root = infer_project_root_from_summary(summary_path)
    if not project_root:
        return None
    candidate = project_root / "01-Admin" / "WATCHTOWER.md"
    return candidate if candidate.exists() else None


def find_best_dynamic_prompt_context(summary_path: Path) -> Path | None:
    prompt_dir = config.RESULTS_DIR / "stage-11-evolution"
    evolution_files = sorted(prompt_dir.glob("evolution-*.json"), key=os.path.getmtime, reverse=True)
    summary_str = str(summary_path)
    summary_slug = slugify(summary_path.stem)
    best_match: tuple[int, float, Path] | None = None

    for evolution_path in evolution_files:
        payload = load_evolution_metadata(evolution_path)
        source_summary = str(payload.get("source_summary", ""))
        project_snapshot = payload.get("project_snapshot", {}) or {}
        project_name = str(project_snapshot.get("project_name", ""))

        score = 0
        if source_summary == summary_str:
            score += 10
        elif source_summary and (source_summary in summary_str or summary_str in source_summary):
            score += 7
        if project_name and slugify(project_name) == summary_slug:
            score += 5
        elif project_name and slugify(project_name) in summary_slug:
            score += 3

        if score <= 0:
            continue

        timestamp = parse_evolution_timestamp(evolution_path)
        prompt_path = prompt_dir / f"prompt-context-{slugify(project_name or summary_path.stem)}-{timestamp}.md"
        if not prompt_path.exists():
            continue

        candidate = (score, os.path.getmtime(prompt_path), prompt_path)
        if best_match is None or candidate > best_match:
            best_match = candidate

    if best_match:
        return best_match[2]

    candidates = sorted(prompt_dir.glob("prompt-context-*.md"), key=os.path.getmtime)
    return candidates[-1] if candidates else None


def build_meta_prompt_context_block(summary_path: Path) -> str:
    sections = []

    dynamic_prompt_path = find_best_dynamic_prompt_context(summary_path)
    if dynamic_prompt_path:
        sections.append("### STAGE 11 DYNAMIC META PROMPT")
        sections.append(read_text_if_exists(dynamic_prompt_path).strip())

    watchtower_path = find_project_watchtower(summary_path)
    if watchtower_path:
        sections.append("### WATCHTOWER LEADS")
        sections.append(read_text_if_exists(watchtower_path).strip())

    style_injection_path = config.PROJECT_ROOT / "600-System-Templates" / "style_injection_mgo.md"
    style_profile_path = config.PROJECT_ROOT / "600-System-Templates" / "style_profile_mgo.yaml"

    style_injection = read_text_if_exists(style_injection_path).strip()
    if style_injection:
        sections.append("### MGO STYLE INJECTION")
        sections.append(style_injection)

    style_profile = read_text_if_exists(style_profile_path).strip()
    if style_profile:
        sections.append("### MGO STYLE PROFILE")
        sections.append(style_profile)

    if not sections:
        return ""
    return "\n\n".join(sections)

app = FastAPI(title="Akademik Karargah AI Motoru")

# CORS middleware for Port 8010 frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API clients
use_litellm_proxy = config.USE_LITELLM_PROXY
anthropic_client = AsyncAnthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))
openai_client = AsyncOpenAI(api_key=os.environ.get("OPENAI_API_KEY"))
proxy_client = AsyncOpenAI(
    api_key=os.environ.get("LITELLM_MASTER_KEY", os.environ.get("OPENAI_API_KEY", "not-needed")),
    base_url=f"{config.LITELLM_URL.rstrip('/')}/v1",
)

async def llm_call(prompt, system_prompt=None, history_messages=[], **kwargs):
    messages = history_messages + [{"role": "user", "content": prompt}]
    if use_litellm_proxy:
        payload = []
        if system_prompt:
            payload.append({"role": "system", "content": system_prompt})
        payload.extend(messages)
        response = await proxy_client.chat.completions.create(
            model=config.LITELLM_CHAT_MODEL,
            messages=payload,
            max_tokens=kwargs.get("max_tokens", 4096),
            temperature=kwargs.get("temperature", 0.2),
        )
        return response.choices[0].message.content or ""

    response = await anthropic_client.messages.create(
        model="claude-3-5-sonnet-20240620",
        max_tokens=kwargs.get("max_tokens", 4096),
        system=system_prompt if system_prompt else "",
        messages=messages
    )
    return response.content[0].text

OLLAMA_API_URL = f"{config.OLLAMA_URL}/api/generate"

async def llm_call_ollama(prompt, system_prompt=None):
    if use_litellm_proxy:
        payload = []
        if system_prompt:
            payload.append({"role": "system", "content": system_prompt})
        payload.append({"role": "user", "content": prompt})
        try:
            response = await proxy_client.chat.completions.create(
                model=config.LITELLM_LOCAL_MODEL,
                messages=payload,
                max_tokens=4096,
                temperature=0.7,
            )
            return response.choices[0].message.content or ""
        except Exception as e:
            logger.error("LiteLLM local model error: %s", e)
            return f"Error calling LiteLLM local model: {str(e)}"

    payload = {
        "model": "deepseek-r1:7b",
        "prompt": f"{system_prompt}\n\n{prompt}" if system_prompt else prompt,
        "stream": False,
        "options": {
            "temperature": 0.7,
            "num_predict": 4096
        }
    }
    async with httpx.AsyncClient(timeout=120.0) as client:
        try:
            response = await client.post(OLLAMA_API_URL, json=payload)
            response.raise_for_status()
            return response.json().get("response", "")
        except Exception as e:
            logger.error(f"Ollama Error: {str(e)}")
            return f"Error calling Ollama: {str(e)}"

async def embed_call(texts: list[str]) -> list[list[float]]:
    if use_litellm_proxy:
        response = await proxy_client.embeddings.create(
            model=config.LITELLM_EMBED_MODEL,
            input=texts,
        )
        return [item.embedding for item in response.data]

    response = await openai_client.embeddings.create(
        model="text-embedding-3-small",
        input=texts
    )
    return [item.embedding for item in response.data]

# RAG Motoru
working_dir = str(WORKING_DIR)
if not os.path.exists(working_dir):
    os.makedirs(working_dir)

rag: LightRAG | None = None


def get_rag() -> LightRAG:
    global rag
    if rag is None:
        rag = LightRAG(
            working_dir=working_dir,
            llm_model_func=ModelFunc(func=llm_call),
            embedding_func=EmbeddingFunc(func=embed_call, embedding_dim=1536),
        )
    return rag


def list_pipeline_manifests(limit: int = 20) -> list[dict]:
    manifest_dirs = sorted(config.METHODS_DIR.glob("530-Econometric-Analysis/*/results/pipeline-run-manifests"))
    items = []
    for manifest_dir in manifest_dirs:
        for path in manifest_dir.glob("*.json"):
            try:
                payload = json.loads(path.read_text(encoding="utf-8"))
            except Exception:
                continue
            manifest = payload.get("manifest", {}) or {}
            lifecycle = payload.get("lifecycle", {}) or {}
            included_stages = [name for name, value in manifest.items() if value]
            items.append(
                {
                    "generated_at": payload.get("generated_at"),
                    "project_name": payload.get("project_name"),
                    "project_root": payload.get("project_root"),
                    "summary_path": payload.get("summary_path"),
                    "manifest_path": str(path),
                    "manifest_markdown_path": str(path.with_suffix(".md")),
                    "included_stages": included_stages,
                    "lifecycle": lifecycle,
                }
            )
    items.sort(key=lambda item: item.get("generated_at") or "", reverse=True)
    return items[:limit]

# --- Endpoints ---

@app.get("/")
async def read_index():
    index_path = config.DASHBOARD_DIR / "910-Dashboard" / "research_ops_ui_v1_clone" / "public" / "index.html"
    return FileResponse(str(index_path))

@app.get("/api/projects")
async def get_projects():
    try:
        path = config.DASHBOARD_DIR / "env" / "Academic_Silsile_v1.json"
        if not path.exists():
            return {"active_projects": {}, "pipeline_status": {}}
        with open(path, 'r') as f:
            data = json.load(f)
        return data
    except Exception as e:
        logger.error(f"Error reading projects: {e}")
        return {"status": "error", "message": str(e)}


@app.get("/api/manifests")
async def get_manifests(limit: int = 20):
    try:
        safe_limit = max(1, min(limit, 100))
        manifests = list_pipeline_manifests(safe_limit)
        return {"status": "success", "count": len(manifests), "items": manifests}
    except Exception as e:
        logger.error(f"Manifest listing error: {e}")
        return {"status": "error", "message": str(e)}

@app.post("/query")
async def query_endpoint(data: dict = Body(...)):
    try:
        query_text = data.get("query", "")
        mode = data.get("mode", "hybrid")
        logger.info(f"Sorgu işleniyor ({mode}): {query_text}")
        
        # Correctly await the async query
        response = await get_rag().query(query_text, param=QueryParam(mode=mode))
        return {"response": response}
    except Exception as e:
        logger.error(f"Hata: {str(e)}")
        return {"status": "error", "message": str(e)}

@app.post("/index_text")
async def index_text(data: dict = Body(...)):
    try:
        text = data.get("text", "")
        metadata = data.get("metadata", {})
        if not text:
            raise HTTPException(status_code=400, detail="Text content is required")
        
        # Ensure metadata is prepended for richer indexing
        full_content = f"METADATA: {json.dumps(metadata)}\n\nCONTENT: {text}"
        
        # Correctly await the async insert if supported, else run in thread
        await get_rag().insert(full_content)
        return {"status": "success", "length": len(text)}
    except Exception as e:
        logger.error(f"Indexing error: {str(e)}")
        return {"status": "error", "message": str(e)}

@app.post("/index_pdf")
async def index_pdf(file: UploadFile = File(...)):
    try:
        content = await file.read()
        text_content = content.decode('utf-8', errors='ignore')
        await get_rag().insert(text_content)
        return {"status": "success", "filename": file.filename}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/report/generate")
async def generate_report(data: ReportGenerateRequest = Body(default_factory=ReportGenerateRequest)):
    try:
        # 1. Find latest empirical summary
        search_pattern = str(config.METHODS_DIR / "530-Econometric-Analysis" / "*" / "results" / "empirical-summary-*.md")
        files = glob.glob(search_pattern)
        if not files:
            raise HTTPException(status_code=404, detail="No empirical summary found")
        
        latest_summary_file = max(files, key=os.path.getmtime)
        with open(latest_summary_file, 'r') as f:
            summary_content = f.read()
        summary_path = Path(latest_summary_file)
        canonical_manifest, manifest_metadata = load_pipeline_manifest(summary_path)

        # 2. Get RAG context for deeper synthesis
        # We query RAG for the core themes identified in the summary
        rag_context = await get_rag().query(
            "Synthesize the core theoretical and empirical themes relevant to this study's Green Innovation and Green Growth focus in Turkey.",
            param=QueryParam(mode="hybrid")
        )

        manifest = data.manifest or canonical_manifest
        stage_04_5 = data.stage_04_5 or (manifest.stage_04_5 if manifest else None)
        stage_07 = data.stage_07 or (manifest.stage_07 if manifest else None)
        stage_11 = data.stage_11 or (manifest.stage_11 if manifest else None)
        socratic_context = format_stage_04_5_context(stage_04_5)
        meta_logic_context = format_stage_07_context(stage_07)
        meta_prompt_context = format_stage_11_context(stage_11) or build_meta_prompt_context_block(summary_path)

        # 3. Construct System Prompt for DeepSeek-R1 (English Academic)
        system_prompt = """You are a Senior Econometrician and Q1 Journal Editor. 
Your task is to synthesize a FULL SCIENTIFIC REPORT based on provided empirical results and literature context.
LANGUAGE: English.
TONE: Academic, rigorous, and professional.
STRUCTURE:
1. Abstract (Max 250 words)
2. Introduction (Context, Significance)
3. Methodology & Results Synthesis (Summarize findings from data)
4. Discussion and Limitations
5. Policy Implications
6. Future Research Directions
Rules:
- Do not overstate causal claims when the design is descriptive or associative.
- Explicitly address endogeneity, robustness, data-quality, and alternative-explanation concerns when they are provided.
- If the Socratic Lab reports unsupported statistics, soften or omit those claims.
- Apply any Stage 07 audit layers as mandatory drafting constraints when they are provided.
- Apply the MGO style rules and dynamic meta-learning prompt injections when they are provided.
Include reasoning (think tags if supported) and focus on the 'Green Innovation - CO2 Link' specifically for Turkey."""

        prompt = f"""### EMPIRICAL SUMMARY DATA:
{summary_content}

### RELEVANT LITERATURE CONTEXT:
{rag_context}

{socratic_context}

{meta_logic_context}

{meta_prompt_context}

Please generate the Full Scientific Report now."""

        # 4. Call Ollama (DeepSeek-R1)
        report_text = await llm_call_ollama(prompt, system_prompt=system_prompt)

        # 5. Save to Manuscript Drafts
        output_dir = config.PROJECT_ROOT / "07_Manuscript_Drafts"
        output_dir.mkdir(exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M")
        output_file = output_dir / f"Full_Report_Ollama_{timestamp}.md"
        
        with open(output_file, 'w') as f:
            f.write(report_text)

        manifest_path = str(find_best_pipeline_manifest(summary_path)) if manifest else None
        watchtower_path = find_project_watchtower(summary_path)
        update_manifest_lifecycle(
            manifest_path,
            report_artifact=str(output_file),
            watchtower_artifact=str(watchtower_path) if watchtower_path else None,
        )

        return {
            "status": "success", 
            "file": output_file,
            "summary_used": os.path.basename(latest_summary_file),
            "manifest_used": bool(manifest),
            "manifest_path": manifest_path,
            "stage_04_5_used": bool(stage_04_5),
            "stage_07_used": bool(stage_07),
            "stage_11_used": bool(stage_11),
            "dynamic_meta_prompt_used": bool(meta_prompt_context.strip()),
        }
    except Exception as e:
        logger.error(f"Report Generation Error: {str(e)}")
        return {"status": "error", "message": str(e)}


@app.post("/api/integrity/scan")
async def integrity_scan(data: dict = Body({})):
    try:
        project = data.get("project")
        check_claims = bool(data.get("check_claims", False))
        result = await asyncio.to_thread(scan_project, project, check_claims)
        return result
    except Exception as e:
        logger.error(f"Integrity scan error: {e}")
        return {"status": "error", "message": str(e)}


@app.post("/api/package/generate")
async def generate_submission_package(data: dict = Body({})):
    try:
        project, manifest_payload = resolve_project_hint(data.get("project"))
        if not project:
            raise HTTPException(status_code=400, detail="Project is required")
        result = await asyncio.to_thread(package_submission, project)
        update_manifest_lifecycle(
            manifest_payload.get("manifest_path"),
            package_artifact=result.get("package_dir"),
        )
        return {"status": "success", "manifest_path": manifest_payload.get("manifest_path"), **result}
    except Exception as e:
        logger.error(f"Packaging error: {e}")
        return {"status": "error", "message": str(e)}


@app.post("/api/orchestration/run")
async def run_orchestration(data: dict = Body(...)):
    try:
        project, manifest_payload = resolve_project_hint(data.get("project"))
        if not project:
            raise HTTPException(status_code=400, detail="Project is required")
        trigger_ingestion = bool(data.get("trigger_ingestion", False))
        build_package = bool(data.get("build_package", False))
        dry_run = bool(data.get("dry_run", False))
        result = await asyncio.to_thread(
            run_project_autopilot,
            project,
            trigger_ingestion,
            build_package,
            dry_run,
        )
        update_manifest_lifecycle(
            manifest_payload.get("manifest_path"),
            orchestration_run=result,
            package_artifact=result.get("package", {}).get("package_dir") if isinstance(result.get("package"), dict) else None,
        )
        return {"status": "success", "manifest_path": manifest_payload.get("manifest_path"), "result": result}
    except Exception as e:
        logger.error(f"Orchestration error: {e}")
        return {"status": "error", "message": str(e)}

@app.post("/analyze/peer_review")
async def analyze_peer_review(data: dict = Body(...)):
    try:
        content = data.get("content", "")
        if not content:
            raise HTTPException(status_code=400, detail="Content is required")
        
        system_prompt = """You are a Senior Editor at a Top-Tier Q1 Economics Journal (e.g., Energy Economics). 
Your tone is extremely rigorous, slightly adversarial, and scientifically pedantic.
Focus on:
1. Identification Strategy (Is there endogeneity? Is the IV valid?)
2. Methodological Rigor (Are the assumptions for GMM/ARDL met?)
3. Contribution (Is this just 'another country study' or is there a real gap?)
4. Data Quality (Are the sources and frequency appropriate?)
Be constructive but 'brutally honest' about what would cause an immediate Desk Reject."""
        
        response = await llm_call(content, system_prompt=system_prompt)
        return {"response": response}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/api/ai/humanize")
async def ai_humanize(data: dict = Body(...)):
    try:
        text = data.get("text", "")
        if not text:
            raise HTTPException(status_code=400, detail="Text is required")

        result = await optimize_style(
            text,
            llm_callable=llm_call,
            objective="humanize_academic_prose",
        )
        return {"response": result.optimized_text, "metadata": result.as_dict()}
    except Exception as e:
        logger.error(f"Humanize error: {e}")
        return {"status": "error", "message": str(e)}

@app.post("/api/dspy/optimize-style")
async def dspy_optimize_style(data: dict = Body(...)):
    try:
        text = data.get("text", "")
        objective = data.get("objective", "reduce_ai_scent")
        if not text:
            raise HTTPException(status_code=400, detail="Text is required")

        result = await optimize_style(
            text,
            llm_callable=llm_call,
            objective=objective,
        )
        return {"status": "success", **result.as_dict()}
    except Exception as e:
        logger.error(f"DSPy optimize-style error: {e}")
        return {"status": "error", "message": str(e)}


@app.post("/api/dspy/optimize-manuscript")
async def dspy_optimize_manuscript(data: dict = Body(...)):
    try:
        filepath = data.get("filepath", "")
        objective = data.get("objective", "reduce_ai_scent")
        write = bool(data.get("write", False))
        max_blocks = int(data.get("max_blocks", 6))
        if not filepath:
            raise HTTPException(status_code=400, detail="Filepath is required")

        result = await optimize_manuscript_file(
            filepath,
            llm_callable=llm_call,
            objective=objective,
            write=write,
            max_blocks=max_blocks,
        )
        return {"status": "success", **result.as_dict()}
    except Exception as e:
        logger.error(f"DSPy optimize-manuscript error: {e}")
        return {"status": "error", "message": str(e)}


@app.post("/api/dspy/restore-manuscript")
async def dspy_restore_manuscript(data: dict = Body(...)):
    try:
        filepath = data.get("filepath", "")
        if not filepath:
            raise HTTPException(status_code=400, detail="Filepath is required")
        result = restore_manuscript_backup(filepath)
        if not result.restored:
            return {"status": "error", "message": "No .bak backup found for this manuscript.", **result.as_dict()}
        return {"status": "success", **result.as_dict()}
    except Exception as e:
        logger.error(f"DSPy restore-manuscript error: {e}")
        return {"status": "error", "message": str(e)}

@app.post("/analyze/stylometry/correct")
async def stylometry_correct(data: dict = Body(...)):
    try:
        path = data.get("filepath", "")
        if not path:
            raise HTTPException(status_code=400, detail="Filepath is required")
        
        # Security: Join with BASE_DIR for local isolation
        full_path = str(BASE_DIR / path)
        if not os.path.exists(full_path):
            raise HTTPException(status_code=404, detail=f"File not found: {path}")

        # Run script using the dedicated venv
        process = subprocess.Popen(["./venv/bin/python", "stylometry_corrector.py", full_path], 
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return {"status": "started", "pid": process.pid, "file": os.path.basename(full_path)}
    except Exception as e:
        logger.error(f"Stylometry correction error: {e}")
        return {"status": "error", "message": str(e)}

@app.post("/api/integrity/scan")
async def integrity_scan(data: dict = Body(...)):
    try:
        path = data.get("filepath", "")
        if not path:
            raise HTTPException(status_code=400, detail="Filepath is required")
        
        # Run the integrity guard script
        import subprocess
        process = subprocess.run(["./venv/bin/python", "nexus_integrity_guard.py", path], 
                                capture_output=True, text=True)
        return {"report": process.stdout, "status": "done"}
    except Exception as e:
        logger.error(f"Integrity scan error: {e}")
        return {"status": "error", "message": str(e)}

@app.post("/api/package/generate")
async def package_generate(data: dict = Body(...)):
    try:
        project = data.get("project", "")
        journal = data.get("journal", "Elsevier")
        if not project:
            raise HTTPException(status_code=400, detail="Project name is required")
        
        import subprocess
        process = subprocess.run(["./venv/bin/python", "nexus_pack.py", project, journal], 
                                capture_output=True, text=True)
        return {"output": process.stdout, "status": "done"}
    except Exception as e:
        logger.error(f"Package generation error: {e}")
        return {"status": "error", "message": str(e)}

@app.post("/analyze/model_architect")
async def analyze_model_architect(data: dict = Body(...)):
    try:
        query = data.get("query", "")
        # ...
        metadata = data.get("metadata", {}) # Column names, types, etc.
        
        system_prompt = """You are an Expert Econometrician and R Developer. 
Your task is to take a research question and dataset metadata, then propose a production-ready R identification strategy and code.
Use modern packages: 'fixest' for fixed effects, 'plm' for panel data, 'vars' for VAR/VECM.
Structure your response as:
1. Recommended Identification Strategy
2. R Code Block (commented)
3. Interpretation Guide (what to look for in the results)
Highlight potential robustness tests (e.g., Dumitrescu-Hurlin for causality)."""
        
        prompt = f"Research Question: {query}\n\nDataset Metadata: {json.dumps(metadata)}"
        response = await llm_call(prompt, system_prompt=system_prompt)
        return {"response": response}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.get("/system/graph")
async def get_system_graph():
    try:
        # Attempt to find LightRAG graph files
        # LightRAG stores entities in vdb_entities.json or similar
        # For this version, we will check graph_chunk_entity_relation.graphml if it exists
        graph_path = os.path.join(working_dir, "graph_chunk_entity_relation.graphml")
        
        # If no graph exists yet, return empty
        if not os.path.exists(graph_path):
            return {"nodes": [], "links": []}
            
        # Simplified parser for presentation (in a real scenario, use networkx)
        # For now, let's return a small dummy to test D3 until indexing happens
        return {
            "nodes": [
                {"id": "ECI", "group": 1},
                {"id": "Green Growth", "group": 1},
                {"id": "Turkey", "group": 2},
                {"id": "Panel GMM", "group": 3}
            ],
            "links": [
                {"source": "ECI", "target": "Green Growth", "value": 1},
                {"source": "Green Growth", "target": "Turkey", "value": 1},
                {"source": "Panel GMM", "target": "ECI", "value": 1}
            ]
        }
    except Exception as e:
        logger.error(f"Graph API Error: {e}")
        return {"nodes": [], "links": []}

@app.get("/api/literature_radar")
async def get_literature_radar():
    try:
        import pandas as pd
        path = config.PROJECT_ROOT / "scripts" / "research_pipeline" / "scopus_results_classified_partial.csv"
        
        if not os.path.exists(path) or os.path.getsize(path) == 0:
            # Fallback if no partial results yet or empty file
            return {"top_papers": []}
            
        df = pd.read_csv(path)
        if df.empty:
            return {"top_papers": []}
            
        # Get last 5 classified papers
        recent = df.tail(5).to_dict('records')
        
        # Map to UI format
        formatted = []
        for r in recent:
            formatted.append({
                "title": r.get('title', 'Unknown'),
                "jel": r.get('jel_category', 'Unclassified'),
                "quality": "high_priority" if "Econometrics" in str(r.get('jel_category')) else "promising",
                "journal": r.get('publicationName', 'Scopus'),
                "sjr": r.get('sjr', '-'),
                "snip": r.get('snip', '-')
            })
        return {"top_papers": formatted}
    except Exception as e:
        logger.error(f"Radar API Error: {e}")
        return {"top_papers": [], "error": str(e)}

@app.post("/analyze/run_r_code")
async def run_r_code(data: dict = Body(...)):
    try:
        code = data.get("code", "")
        if not code:
            raise HTTPException(status_code=400, detail="R code is required")
        
        # Security: Clean the code for simple injections (basic)
        # For a local researcher, we trust the code but it's good practice.
        # Save to temp file
        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".R", mode="w", delete=False) as f:
            f.write(code)
            temp_path = f.name
            
        try:
            # Run using Rscript
            result = subprocess.run(["/usr/local/bin/Rscript", temp_path], capture_output=True, text=True, timeout=30)
            output = result.stdout
            if result.stderr:
                output += "\n--- ERRORS/WARNINGS ---\n" + result.stderr
            return {"output": output}
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.get("/system/status")
async def system_status():
    # Check Ollama status
    ollama_online = False
    # Basic health check
    return {
        "status": "online",
        "apis": {
            "litellm_proxy": "enabled" if use_litellm_proxy else "disabled",
            "anthropic": "ok" if os.environ.get("ANTHROPIC_API_KEY") else "missing",
            "openai": "ok" if os.environ.get("OPENAI_API_KEY") else "missing",
            "ollama": config.OLLAMA_URL,
        },
        "models": {
            "chat": config.LITELLM_CHAT_MODEL if use_litellm_proxy else "claude-3-5-sonnet-20240620",
            "embedding": config.LITELLM_EMBED_MODEL if use_litellm_proxy else "text-embedding-3-small",
            "local": config.LITELLM_LOCAL_MODEL if use_litellm_proxy else "deepseek-r1:7b",
        },
        "rag": {
            "working_dir": working_dir,
            "indexed_files": len(os.listdir(working_dir)) if os.path.exists(working_dir) else 0
        }
    }

@app.get("/api/scholar_skills")
async def get_scholar_skills():
    return {
        "feynman": {
            "system_prompt": "You are Richard Feynman. Explain complex concepts to a 5-year-old child using simple analogies and zero jargon.",
            "mode": "hybrid"
        },
        "socrates": {
            "system_prompt": "You are Socrates. Do not give answers. Ask 3 critical, probing questions that expose contradictions in the user's logic.",
            "mode": "hybrid"
        },
        "gamification": {
            "system_prompt": "You are a Game Master. Analyze the researcher's output and reward 'Scholar XP' or 'Badges'. Provide a level-up notification.",
            "mode": "simple"
        }
    }

@app.post("/automation/{task}")
async def run_automation(task: str, data: dict = Body({})):
    scripts = {
        "zotero_sync": "900-Dashboard/zotero_to_lightrag_v2.py",
        "pdf_cleanup": "900-Dashboard/pdf_cleanup.py",
        "onedrive_sync": "900-Dashboard/force_onedrive_sync.py",
        "pop_sync": "900-Dashboard/pop_manager.py",
        "obsidian_questions": "900-Dashboard/obsidian_manager.py",
        "journal_switch": "switch_journal.py"
    }
    
    if task not in scripts:
        raise HTTPException(status_code=404, detail="Task not found")
    
    script_path = scripts[task]
    try:
        # For journal_switch, we pass the journal name as an argument
        args = ["./venv/bin/python", script_path]
        if task == "journal_switch":
            journal = data.get("journal", "elsevier")
            args.append(journal)
            
        process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return {"status": "started", "task": task, "pid": process.pid}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# Static files for UI
static_path = str(config.DASHBOARD_DIR / "910-Dashboard" / "research_ops_ui_v1_clone" / "public")
if os.path.exists(static_path):
    # This will serve files directly under / if not matched by other routes
    app.mount("/", StaticFiles(directory=static_path, html=True), name="static")

if __name__ == "__main__":
    # Use 0.0.0.0 to listen on all IPv4 interfaces for Mac compatibility
    uvicorn.run(app, host="0.0.0.0", port=8000)
