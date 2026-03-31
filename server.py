import os
import asyncio
import logging
import subprocess
import glob
import json
import httpx
from datetime import datetime
from pathlib import Path
from dataclasses import dataclass
from typing import Callable, Optional
from lightrag import LightRAG, QueryParam
import uvicorn
from fastapi import FastAPI, Body, File, UploadFile, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from anthropic import AsyncAnthropic
from openai import AsyncOpenAI
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("akademik_karargah")

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

app = FastAPI(title="Akademik Karargah AI Motoru")

# API İstemcileri
anthropic_client = AsyncAnthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))
openai_client = AsyncOpenAI(api_key=os.environ.get("OPENAI_API_KEY"))

async def llm_call(prompt, system_prompt=None, history_messages=[], **kwargs):
    messages = history_messages + [{"role": "user", "content": prompt}]
    response = await anthropic_client.messages.create(
        model="claude-3-5-sonnet-20240620",
        max_tokens=4096,
        system=system_prompt if system_prompt else "",
        messages=messages
    )
    return response.content[0].text

OLLAMA_API_URL = "http://localhost:11434/api/generate"

async def llm_call_ollama(prompt, system_prompt=None):
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
    response = await openai_client.embeddings.create(
        model="text-embedding-3-small",
        input=texts
    )
    return [item.embedding for item in response.data]

# RAG Motoru
working_dir = "./lightrag_db"
if not os.path.exists(working_dir):
    os.makedirs(working_dir)

rag = LightRAG(
    working_dir=working_dir,
    llm_model_func=ModelFunc(func=llm_call),
    embedding_func=EmbeddingFunc(func=embed_call, embedding_dim=1536)
)

# --- Endpoints ---

@app.get("/")
async def read_index():
    return FileResponse('dashboard/index.html')

@app.post("/query")
async def query_endpoint(data: dict = Body(...)):
    try:
        query_text = data.get("query", "")
        mode = data.get("mode", "hybrid")
        logger.info(f"Sorgu işleniyor ({mode}): {query_text}")
        response = await rag.query(query_text, param=QueryParam(mode=mode))
        return {"response": response}
    except Exception as e:
        logger.error(f"Hata: {str(e)}")
        return {"status": "error", "message": str(e)}

@app.post("/index_pdf")
async def index_pdf(file: UploadFile = File(...)):
    try:
        content = await file.read()
        # LightRAG handles text ingestion. For PDF, we'd normally extract text first.
        # For simplicity in this bridge, we assume text or use a basic extractor if needed.
        text_content = content.decode('utf-8', errors='ignore')
        rag.insert(text_content)
        return {"status": "success", "filename": file.filename}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/report/generate")
async def generate_report():
    try:
        # 1. Find latest empirical summary
        search_path = "500-Methods/530-Econometric-Analysis/*/results/empirical-summary-*.md"
        files = glob.glob(search_path)
        if not files:
            raise HTTPException(status_code=404, detail="No empirical summary found")
        
        latest_summary_file = max(files, key=os.path.getmtime)
        with open(latest_summary_file, 'r') as f:
            summary_content = f.read()

        # 2. Get RAG context for deeper synthesis
        # We query RAG for the core themes identified in the summary
        rag_context = await rag.query(
            "Synthesize the core theoretical and empirical themes relevant to this study's Green Innovation and Green Growth focus in Turkey.",
            param=QueryParam(mode="hybrid")
        )

        # 3. Construct System Prompt for DeepSeek-R1 (English Academic)
        system_prompt = """You are a Senior Econometrician and Q1 Journal Editor. 
Your task is to synthesize a FULL SCIENTIFIC REPORT based on provided empirical results and literature context.
LANGUAGE: English.
TONE: Academic, rigorous, and professional.
STRUCTURE:
1. Abstract (Max 250 words)
2. Introduction (Context, Significance)
3. Methodology & Results Synthesis (Summarize findings from data)
4. Policy Implications
5. Future Research Directions
Include reasoning (think tags if supported) and focus on the 'Green Innovation - CO2 Link' specifically for Turkey."""

        prompt = f"""### EMPIRICAL SUMMARY DATA:
{summary_content}

### RELEVANT LITERATURE CONTEXT:
{rag_context}

Please generate the Full Scientific Report now."""

        # 4. Call Ollama (DeepSeek-R1)
        report_text = await llm_call_ollama(prompt, system_prompt=system_prompt)

        # 5. Save to Manuscript Drafts
        output_dir = "07_Manuscript_Drafts"
        os.makedirs(output_dir, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M")
        output_file = os.path.join(output_dir, f"Full_Report_Ollama_{timestamp}.md")
        
        with open(output_file, 'w') as f:
            f.write(report_text)

        return {
            "status": "success", 
            "file": output_file,
            "summary_used": os.path.basename(latest_summary_file)
        }
    except Exception as e:
        logger.error(f"Report Generation Error: {str(e)}")
        return {"status": "error", "message": str(e)}

@app.get("/system/status")
async def system_status():
    # Check Ollama status
    ollama_online = False
    try:
        async with httpx.AsyncClient(timeout=1.0) as client:
            res = await client.get("http://localhost:11434/api/tags")
            ollama_online = res.status_code == 200
    except:
        pass

    return {
        "status": "online",
        "apis": {
            "anthropic": "ok" if os.environ.get("ANTHROPIC_API_KEY") else "missing",
            "openai": "ok" if os.environ.get("OPENAI_API_KEY") else "missing",
            "ollama_local": "online" if ollama_online else "offline"
        },
        "rag": {
            "working_dir": working_dir,
            "indexed_files": len(os.listdir(working_dir)) if os.path.exists(working_dir) else 0
        }
    }

@app.post("/automation/{task}")
async def run_automation(task: str):
    scripts = {
        "zotero_sync": "scripts/zotero_to_lightrag.py",
        "pdf_cleanup": "09_Python_Scripts/pdf_cleanup.py",
        "onedrive_sync": "09_Python_Scripts/force_onedrive_sync.py"
    }
    
    if task not in scripts:
        raise HTTPException(status_code=404, detail="Task not found")
    
    script_path = scripts[task]
    try:
        # Run script in the background
        process = subprocess.Popen(["./venv/bin/python", script_path], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return {"status": "started", "task": task, "pid": process.pid}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# Static files for CSS/JS
if os.path.exists("dashboard"):
    app.mount("/static", StaticFiles(directory="dashboard"), name="static")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
