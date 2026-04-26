# NEXT SESSION — Yeni Oturum Başlangıç Protokolü
_Güncellendi: 2026-04-12 (Token Optimization Protocol v2.0 — token-guard skill active)_

## Token-Optimized Session Startup Checklist

Every session must follow this sequence:

```
1. /clear                          ← H1: Clean context from previous task
2. Read CLAUDE.md                  ← Load project constitution
3. Read PROJECT.md (if exists)     ← H16: Load project-specific context
4. Read RESEARCH_STATE.md          ← Load current state
5. Define task in ONE sentence     ← H6: Specific, English prompt
6. /stats                          ← H3: Baseline token count
7. Start work (Sonnet default)     ← H15: Switch to Opus only if needed
8. /compact at 60-70% context      ← H10: Proactive compression
9. /cost at session end            ← H4: Log to PROGRESS.md
10. git commit                     ← H13: Checkpoint before next task
```

## Claude'a Talimat

Bu dosyayı okuyan Claude:
1. `RESEARCH_STATE.md` dosyasını oku
2. Kullanıcıya şu özeti sun:

---

**"Kaldığınız yerden devam ediyoruz. Son oturumda (12 Nisan 2026):**

- 18-Hack Token Optimization Protocol fully deployed (CLAUDE.md + skills + infrastructure)
- token-guard skill installed and active in Cowork
- research-manager skill updated with token protocol integration
- 38 PROJECT.md files created across 210-Active/ portfolio
- **Dr. Öğr. Üyesi başvurusu için 0-6 ay içinde ≥1 SSCI/SCI kabulü** gerekiyor

**Priority Queue (submission order):**
1. **Climate-Agriculture-Turkey-ARDL** → v05 complete, submit to JEM (Sonnet: cover letter + formatting)
2. **Scopus-MGK-MGO** → v3, HRPUB template adaptation (Sonnet: data curation)
3. **EKC_BRICST v0.4** → Pesaran CD → CIPS → CS-ARDL estimation (Opus: specification)

**Şimdi ne yapalım?**"

---

## Hızlı Başlangıç Seçenekleri

Kullanıcı doğrudan bir yön vermezse şunu sor:

> "ARDL makalesini JEM'e göndermek için son adımları mı tamamlayalım, yoksa başka bir çalışmadan mı devam edelim?"

## Kritik Dosya Yolları

```
~/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/
├── RESEARCH_STATE.md          ← Ana hafıza dosyası
├── PROGRESS.md                ← Oturum günlüğü
├── NEXT_SESSION.md            ← Bu dosya
└── 200-Manuscripts/
    └── 210-Active/
        ├── Climate-Agriculture-Turkey-ARDL/   ← P1 ACİL (v05 submit-ready)
        │   └── PROJECT.md ← token-efficient context
        ├── Scopus-MGK-MGO/                    ← P2 (HRPUB target)
        │   └── PROJECT.md
        ├── EKC_BRICST/                        ← P3 (CS-ARDL estimation)
        │   └── PROJECT.md
        └── [37 more active manuscripts with PROJECT.md]
```

## Kısa Komutlar

| Söylersen | Yapılacak |
|---|---|
| "ARDL'den devam" | ARDL v05 aç, cover letter finalize, JEM'e gönder |
| "Scopus'tan devam" | 2026-Scopus-MGK-MGO → HRPUB template uyarla |
| "EKC devam" | EKC_BRICST → Pesaran CD + CIPS + CS-ARDL pipeline |
| "UY'den devam" | 2026-UY-MGO-Makale checklist tamamla |
| "Konya'dan devam" | Konya Q1 revizyonuna başla |
| "Portföy durumu" | RESEARCH_STATE.md oku + güncel özet sun |
| "token check" | Token-guard skill tetikle, maliyet analizi |


## ⚠️ P2 DERGI DEĞİŞİKLİĞİ — UNUTMA
P2 makalesi (SCOPUS_MGK_MGO) → **HRPUB Environment and Ecology Research**
URL: https://www.hrpub.org/journals/jour_index.php?id=40
Template dosyası: `04-Manuscript/HRPUB_Manu_Template_V1.docx`
Sonraki adım: Manuscript'i HRPUB template'ine uyarla → portal'dan gönder
