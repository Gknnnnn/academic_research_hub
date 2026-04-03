# OrbStack Runtime Setup

Bu depo icin birincil runtime artik OrbStack'tir.

## Durum

`Docker MCP Toolkit is temporarily unsupported during OrbStack migration.`

## Kurulum

```bash
brew install orbstack
docker context ls
docker context use orbstack
docker info
docker run --rm hello-world
```

## research-nexus Dogrulamasi

```bash
docker build -f servers/research-nexus/Dockerfile -t research-nexus-mcp .
docker run --rm -e WORKSPACE_ROOT=/workspace -v "<repo_abs_path>:/workspace" research-nexus-mcp python3 smoke_test.py
```

## Sonraki Adim

```bash
docker compose --profile orchestration up prefect-orchestrator
docker compose run --rm prefect-orchestrator python3 orchestration/nexus_prefect_flow.py --project 2026-Scopus-MGK-MGO --dry-run
```

## Not

- aktif context `orbstack` olmadan ilerleme
- Docker Desktop sadece rollback icin tutulur
- MCP config dosyalari legacy durumdadir
