# MCP Landing Page

Bu klasor, bu depodaki guncel MCP kurulumunu ve kullanimini tek yerde toplar.

Ana giriş noktası: [MCP Guide](../MCP.md)

## Hızlı Başlangıç

1. [MCP Guide](../MCP.md)
2. [MCP First-Run Checklist](./MCP_FIRST_RUN_CHECKLIST.md)
3. Legacy sorunlari icin [MCP Troubleshooting](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/600-System-Templates/legacy-mcp/MCP_TROUBLESHOOTING.md)

## Profil Tasarımı

1. [MCP Profile Recommendations](./MCP_PROFILE_RECOMMENDATIONS.md)
2. [MCP Server Selection](./MCP_SERVER_SELECTION.md)
3. [MCP Shortlist](./MCP_SHORTLIST.md)
4. [MCP Tool Policy](./MCP_TOOL_POLICY.md)
5. [MCP Research Playbook](./MCP_RESEARCH_PLAYBOOK.md)
6. [MCP Profile Matrix](./MCP_PROFILE_MATRIX.md)

## İstemci Şablonları

1. [.vscode/mcp.json](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/.vscode/mcp.json)
2. [.vscode/mcp.economic-research.json](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/.vscode/mcp.economic-research.json)
3. [.vscode/mcp.paper-writing.json](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/.vscode/mcp.paper-writing.json)
4. [Claude Desktop şablonu](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/600-System-Templates/legacy-mcp/claude_desktop_mcp.json)
5. [.vscode/settings.json](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/.vscode/settings.json)
6. [MCP server.yaml şablonu](./MCP_SERVER_TEMPLATE.yaml)

## Legacy Arsiv

- [legacy-mcp](/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/600-System-Templates/legacy-mcp)
- bu klasor eski Docker, OrbStack ve Claude Desktop MCP notlarini tutar

## Onerilen Varsayilan

- profil: `economic-research`
- yetki: salt okunur başlangıç
- yazma: yalnızca görev bazlı
- ağ erişimi: yalnızca gerektiğinde

## Kullanım Sırası

1. önce kurulum notunu oku
2. sonra profil önerilerini seç
3. ardından yetki politikasına bak
4. en son ilk çalıştırma kontrolünü yap
5. sorun varsa troubleshooting aç
