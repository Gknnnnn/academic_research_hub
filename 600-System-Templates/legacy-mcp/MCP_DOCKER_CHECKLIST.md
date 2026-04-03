# OrbStack Checklist

## Bir kere yap

- `brew install orbstack`
- `docker context ls`
- `docker context use orbstack`
- `docker info`
- `docker run --rm hello-world`

## research-nexus

- `docker build -f servers/research-nexus/Dockerfile -t research-nexus-mcp .`
- `docker run --rm -e WORKSPACE_ROOT=/workspace -v "<repo_abs_path>:/workspace" research-nexus-mcp python3 smoke_test.py`

## Compose

- `docker compose --profile orchestration up prefect-orchestrator`
- `docker compose run --rm prefect-orchestrator python3 orchestration/nexus_prefect_flow.py --project 2026-Scopus-MGK-MGO --dry-run`

## MCP Durumu

- `Docker MCP Toolkit is temporarily unsupported during OrbStack migration.`
- legacy config dosyalari aktif varsayilan degildir

## Basari Kontrolu

- aktif context `orbstack`
- build basarili
- smoke test basarili
- compose runtime/context kaynakli bozulmuyor
