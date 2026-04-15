# MCP Guide

Bu belge, bu depodaki guncel MCP kullanimini tek yerde toplar.

## Guncel durum

Aktif yaklasim Docker tabanli gateway degil, dogrudan istemci konfigurasyonudur.

Guncel ana profil:
- `economic-research`

Ikinci profil:
- `paper-writing`

Aktif MCP sunuculari:
- `research_nexus`
- `fetch`
- `filesystem`
- `time`

## Hizli baslangic

1. [config.toml](/Users/mehmetgokhanozdemir/.codex/config.toml) icinde MCP sunucularinin tanimli oldugunu kontrol et.
2. VS Code icin [.vscode/mcp.json](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/.vscode/mcp.json) dosyasini kullan.
3. Arastirma agirlikli oturumlar icin [.vscode/mcp.economic-research.json](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/.vscode/mcp.economic-research.json) profilini referans al.
4. Yazi ve revizyon agirlikli oturumlar icin [.vscode/mcp.paper-writing.json](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/.vscode/mcp.paper-writing.json) profilini referans al.
5. Istemciyi yeniden baslat ve ilk calistirma kontrolunu uygula.

## Server rolleri

### `research_nexus`

Ana arastirma omurgasidir.

Kullanim:
- aktif proje ozeti
- submission state tarama
- gate report okuma
- JEL ve Zotero odakli literatur snapshot

### `fetch`

Dis web kaynaklarini okumak icin kullanilir.

Kullanim:
- acik web dokumantasyonu
- metod ve veri sayfalari
- URL tabanli icerik ozeti

### `filesystem`

Depo icindeki dosyalari kontrollu okumak icin kullanilir.

Kullanim:
- markdown notlari
- config dosyalari
- submission klasorleri

### `time`

Deadline ve timezone netlestirme icin kullanilir.

Kullanim:
- Europe/Istanbul bazli tarih netlestirme
- konferans ve resubmission zamani kontrolu

## Profil secimi

- literatur, veri, yontem ve konu kesfi icin: `economic-research`
- draft, revizyon ve submission kontrolu icin: `paper-writing`

Ayrintili profil matrisi:
- [MCP Profile Matrix](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/600-System-Templates/MCP_PROFILE_MATRIX.md)

## Ilk calistirma kontrolu

- [MCP First-Run Checklist](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/600-System-Templates/MCP_FIRST_RUN_CHECKLIST.md)

Kontrol et:
- `uvx` calisiyor mu
- `npx` calisiyor mu
- `research_nexus` yolu dogru mu
- istemci yeni config ile yeniden baslatildi mi

## Onerilen belge zinciri

1. [MCP Landing Page](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/600-System-Templates/MCP_LANDING_PAGE.md)
2. [MCP Profile Recommendations](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/600-System-Templates/MCP_PROFILE_RECOMMENDATIONS.md)
3. [MCP Research Playbook](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/600-System-Templates/MCP_RESEARCH_PLAYBOOK.md)
4. [MCP Profile Matrix](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/600-System-Templates/MCP_PROFILE_MATRIX.md)

## Legacy not

Docker ve Claude Desktop tabanli eski dosyalar arşivlenmistir; aktif varsayilan degildir:
- [claude_desktop_mcp.json](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/600-System-Templates/legacy-mcp/claude_desktop_mcp.json)
- [claude_desktop_mcp_research_nexus.json](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/600-System-Templates/legacy-mcp/claude_desktop_mcp_research_nexus.json)
