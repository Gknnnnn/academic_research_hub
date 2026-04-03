# OrbStack Troubleshooting

## Runtime baslamiyor

- `docker context ls`
- `docker context use orbstack`
- `docker info`
- OrbStack uygulamasinin acik oldugunu dogrula

## Build fail oluyor

- aktif context'in `orbstack` oldugunu dogrula
- `docker build -f servers/research-nexus/Dockerfile -t research-nexus-mcp .` komutunu tekrar dene
- hata Docker Hub veya ag kaynakliysa yeniden dene

## Container smoke test fail oluyor

- mount yolunun dogru oldugunu kontrol et
- `WORKSPACE_ROOT=/workspace` kullandigini dogrula
- `servers/research-nexus/smoke_test.py` ile yerel dogrulama yap

## Compose fail oluyor

- `docker info` ile runtime sagligini tekrar kontrol et
- env veya dependency eksikligini ayir
- runtime/context kaynakli hata ile uygulama eksikligini karistirma

## MCP neden yok

- `Docker MCP Toolkit is temporarily unsupported during OrbStack migration.`
- legacy MCP config dosyalari sadece referans icin tutulur

## Rollback

```bash
docker context use desktop-linux
```
