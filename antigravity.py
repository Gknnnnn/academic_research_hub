#!/usr/bin/env python3
import os
import sys
import time
import httpx
import logging
import itertools
from datetime import datetime
from dotenv import load_dotenv
from pathlib import Path

# Configuration
load_dotenv()

N8N_BASE_URL = os.getenv("N8N_BASE_URL", "http://localhost:5679")
N8N_API_KEY = os.getenv("N8N_API_KEY")
N8N_DATA_WF = os.getenv("N8N_WORKFLOW_ID_DATA", "1")
N8N_ZOTERO_WF = os.getenv("N8N_WORKFLOW_ID_ZOTERO", "2")
ACADEMIC_ENGINE_URL = os.getenv("ACADEMIC_ENGINE_URL", "http://localhost:8000")

# Path to poll (Verified exists on host)
RESULTS_PATH = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/500-Methods/530-Econometric-Analysis/510-JEL-Q56-GreenGrowth/results")

# Setup Logging
logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("antigravity")

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

async def trigger_n8n_workflow(wf_id, name):
    print(f"📡 Triggering n8n Workflow: {name} (ID: {wf_id})...")
    url = f"{N8N_BASE_URL}/api/v1/workflows/{wf_id}/run"
    headers = {"X-N8N-API-KEY": N8N_API_KEY}
    
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

async def run_pipeline():
    print_header()
    
    # 1. Trigger n8n Data Pipeline
    if not await trigger_n8n_workflow(N8N_DATA_WF, "Data Extraction"):
        return

    # 2. Trigger Zotero & Obsidian Logic
    if not await trigger_n8n_workflow(N8N_ZOTERO_WF, "Zotero-Obsidian Sync"):
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
        print("\n⌛ TIMEOUT: n8n took too long to produce results. Check n8n logs at http://localhost:5679")
        return

    # 4. Trigger AI Synthesis
    print("\n🧠 Handing over to DeepSeek-R1 for Scientific Synthesis...")
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(f"{ACADEMIC_ENGINE_URL}/report/generate", timeout=180.0)
            if response.status_code == 200:
                data = response.json()
                print("\n" + "🏆" * 20)
                print("MANUSCRIPT DRAFT GENERATED!")
                print(f"File: {data.get('file')}")
                print(f"Tone: English / Q1 Standard")
                print("🏆" * 20 + "\n")
            else:
                print(f"❌ AI Synthesis Failed: {response.text}")
        except Exception as e:
            print(f"❌ Connection Error (AI Engine): {str(e)}")

if __name__ == "__main__":
    import asyncio
    try:
        asyncio.run(run_pipeline())
    except KeyboardInterrupt:
        print("\n🛑 Pipeline stopped by user.")
