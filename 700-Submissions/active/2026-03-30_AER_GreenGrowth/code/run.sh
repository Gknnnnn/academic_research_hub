#!/usr/bin/env bash
set -euo pipefail
"$(dirname "$0")/01_clean_data.py"
"$(dirname "$0")/02_analysis.py"
