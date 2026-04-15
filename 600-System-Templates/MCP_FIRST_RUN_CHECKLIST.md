# MCP First-Run Checklist

## Hazırlık

- `uvx` çalışıyor mu
- `npx` çalışıyor mu
- `economic-research` veya `paper-writing` profili seçildi mi
- `research_nexus` yolu doğru mu

## VS Code

- `.vscode/mcp.json` dosyası var mı
- gerekirse `.vscode/mcp.economic-research.json` veya `.vscode/mcp.paper-writing.json` dosyası seçildi mi
- VS Code yeniden başlatıldı mı

## Claude Desktop

- Codex config içindeki MCP sunucuları güncel mi
- `uvx` ve `npx` komutları istemci tarafından erişilebilir mi
- istemci bağlantı kuruyor mu

## Doğrulama

- dosya listesi beklenen klasörü gösteriyor mu
- `fetch` dış web içeriğini çekebiliyor mu
- `time` Europe/Istanbul ile doğru sonuç veriyor mu
- salt okunur alanlar gerçekten yazıma kapalı mı
- ihtiyaç yoksa yazma yetkisi verilmemiş mi
- gizli anahtarlar görünmüyor mu

## Sorun olursa

- önce profil adını kontrol et
- sonra `uvx` veya `npx` komutlarını elle çalıştırıp hata mesajını oku
- en son MCP sunucu yolunu ve config dosyasını kontrol et
