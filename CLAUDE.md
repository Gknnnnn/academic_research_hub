# Research Context — Dr. M. Gökhan Özdemir
Kırıkkale University, Department of Economics Theory
Focus: econometrics, energy & environmental economics, climate, sustainable agriculture, migration–carbon–growth nexus, political economy of Eurasia/Turkey.

## Tone & Output Standards
- Q1 journal register (Energy Economics, Ecological Economics, JEM, EE&P).
- Always discuss: identification, endogeneity, OVB, heteroskedasticity, multicollinearity, robustness, economic significance, limitations.
- Equations & tables in LaTeX. References Zotero-ready (APA 7 / Chicago).
- Structure: Summary → Detailed Analysis → Econometric/Policy Implications → Robustness & Limitations → References.

## Preferred Methods (default toolkit)
- Panel: FE/RE, Hausman, Driscoll-Kraay, CS-ARDL, PMG-ECM, AMG, CCEMG, System-GMM (Blundell-Bond), Bias-corrected LSDV.
- Cross-section dependence & slope homogeneity: Pesaran CD, CDw+, Pesaran-Yamagata.
- Unit root: CIPS, CADF, IPS, LLC; Cointegration: Westerlund, Pedroni, Kao.
- Causality: Dumitrescu-Hurlin, Konya bootstrap, Toda-Yamamoto, Hatemi-J asymmetric.
- Time series: ARDL bounds, VAR/SVAR/VECM, ARIMA, Bai-Perron breaks.
- Identification: IV/2SLS, GMM, DiD, RDD, Bartik/shift-share, synthetic control.
- Inference: Webb wild cluster bootstrap (mandatory when N<30 clusters).
- Software: Stata (xtbreak, xtdcce2, xtwest), R (plm, lmtest, vars, urca, strucchange, fixest), Python (linearmodels, statsmodels, pandas).

## Active Projects (slot map — 2026-04-12)
40 active manuscripts in `210-Active/`. Each has a `PROJECT.md` for token-efficient context loading.
**Priority queue (submission-ready):**
1. **Climate-Agriculture-Turkey-ARDL** — v05 ready, JEM target. URGENT: birim notları + co-author sign-off → submit.
2. **Scopus-MGK-MGO** — v3 pre-submission fixes done. Target: HRPUB Environment and Ecology Research.
3. **EKC_BRICST v0.4** — N=9, CS-ARDL, Webb bootstrap mandatory. Estimation stage.
4. **CE-Cognitive-Econometrics** — EU-27, 5 models. Macro arm complete; M1/M2 awaiting GESIS.
5. **Food-Regime-Decoupling** — BACI+FAOSTAT+AgTFP. Missing: FBS/EDGAR-FOOD/Exiobase.
6. **Paper 6 v7** — GCAI×inflation, Bai-Perron breaks. Chainalysis data unverified.
**Full portfolio:** `960-Infrastructure/961-Dashboard/` or run `ls 200-Manuscripts/210-Active/*/PROJECT.md`

## Standing Rules
- **Webb wild cluster bootstrap** is mandatory whenever clusters < 30 (esp. BRICS-T, MINT, EU-27 subsamples).
- **MG/CS-ARDL standard errors** are inflated in small N — always report bootstrap CIs alongside.
- **Bai-Perron supF p-values** are χ²(q) approximations — cross-check with Stata `xtbreak` or R `strucchange` before any Q1 submission.
- **Pesaran CD + CIPS** are pre-conditions before any panel cointegration / CS-ARDL.
- **Zotero better-bibtex** key format: `authorYearTitle` lowercase.
- **No retirement doctrine** for portfolio papers — revive weakest first; bottom-5 currently: green-innovation, CE-CogEcon, UY-Sust-Nexus, AI-Green, ZRY-SO-UY.

## 🔴 ANAYASA — Akademik Dürüstlük Kuralları (2026-04-19)
**NO HALLUCINATION. NO GHOST CITATIONS. NO HYPOTHETICAL ANALYSES.**

1. **Yalnızca çalıştırılmış analizler yazılır.** Bir test, model veya robustness check makalede yer alacaksa kodun çalıştırılmış ve sonucun doğrulanmış olması zorunludur. "Önerilir / recommended / future work" ifadesi yalnızca future work bölümünde kullanılır — metodoloji, results veya discussion bölümlerinde değil.
2. **Yalnızca gerçek veriler kullanılır.** Her veri kaynağı indirilen, temizlenen ve doğrulanan ham veriye dayanmak zorundadır. Varsayımsal veya interpolate edilmiş veri açıkça etiketlenir.
3. **Yalnızca doğrulanmış sonuçlar raporlanır.** Her katsayı, p-değeri, test istatistiği ve güven aralığı çalıştırılan kodun çıktısıyla eşleşmek zorundadır. Hiçbir sayı el ile yazılmaz.
4. **Hiçbir ghost citation eklenmez.** Her referans: (a) gerçek bir yayın, (b) doğru DOI/dergi/yıl, (c) metindeki iddiayla içerik açısından uyumlu olmalıdır. DOI doğrulanmadan referans eklenmez.
5. **Pre-submission AUDIT zorunludur.** Her makalede göndermeden önce şu kontroller yapılır:
   - Tüm sayısal değerler kod çıktısıyla çapraz kontrol edildi mi?
   - Makalede iddia edilen her analiz gerçekten çalıştırıldı mı?
   - Tüm referanslar gerçek ve içerik açısından uyumlu mu?
   - "Recommended / future work" olarak etiketlenmemiş hiçbir hipotetik kalmadı mı?

**Bu kuralları ihlal eden her içerik gönderimden önce kaldırılır veya düzeltilir.**

6. **NO RETRACTED PAPER — GOLDEN RULE FOR ALL TIME.** Yayınlanmış makalelerde retraksiyon asla kabul edilemez. Bu kuralı korumak için: (a) her yayınlanmış makalede veri doğruluğu, yöntem şeffaflığı ve referans bütünlüğü periyodik olarak kontrol edilir; (b) scite/Retraction Watch üzerinden retraksiyon riski taraması yapılır; (c) gönderimden önce AUDIT zorunludur. Bir sorun tespit edilirse derhal editöre bildirim ve düzeltme/erratum tercih edilir — gizleme yasaktır.

## Erasmus+ Outreach
→ Archived to `960-Infrastructure/claude-md-archive.md`. **Every outgoing email requires explicit approval before send.**

## Data Sources (canonical)
- TurkStat, World Bank WDI, OECD.Stat, IEA, IRENA, FAOSTAT, BACI HS92 (CEPII), USDA AgTFP, EDGAR/EDGAR-FOOD, Eurobarometer (GESIS), Eurostat, Chainalysis Geography Report, Triple-A.
- WB API note: `EN.ATM.CO2E.PC` deprecated → use `EN.GHG.CO2.PC.CE.AR5`.

## Key Folder Conventions (v2.0)
Full listing → `960-Infrastructure/claude-md-archive.md`. Summary:
- `100-Inbox/` raw drops | `110-Literature/` Zotero | `120-Concepts/` theory
- `200-Manuscripts/` 210-Active → 240-Published pipeline | `290-Idea-Incubator/`
- `300-Output-Registry/` YÖK·A1-A4 + ÜAK + KKÜ cross-map
- `400-Data/` panels, codebooks | `400-Grants/` TÜBİTAK, BAP
- `600-Methods/` Stata/R/Python templates | `700-Results/` tables, figures
- `800-Teaching/` | `900-Admin/` | `950-Dossiers/` ÜAK + YÖK + KKÜ
- `960-Infrastructure/` automation, MCP, dashboard

## Zotero
5.907 refs | 405 collections | cleanup script: `600-Methods/zotero_cleanup.py`

## Workflow Rules (Claude Code Insights — 2026-04-09)
These rules were derived from 32 sessions of usage analysis and address the most frequent friction points.

### Render & Output
- **Always render Quarto/R documents after edits and fix any render errors before reporting completion.** Never declare a task done without a clean render. Validate R code chunks incrementally before running a full render to catch escape-character, package-reference, and chunk errors early.
- **For DOCX/PDF output, generate via `quarto render` directly — never paste content.** Pasting is not an acceptable substitute for rendering.
- **After any QMD edit, render to both PDF and DOCX, inspect the output, and report any warnings/errors before asking for review.**

### Manuscript Updates
- **When updating a manuscript, also regenerate all associated tables and figures, and update PROGRESS_COOKBOOK with a timestamp.** Do not wait for the user to point out that tables/figures were not regenerated.
- **Assume solo authorship unless explicitly told otherwise; never add co-authors without explicit confirmation.** (Incident: Bayrakdar incorrectly added as co-author.)

### Large Sweeps & Budget Management
- **Before starting any large portfolio sweep, list all files to be changed, estimate scope, and process them in priority order (render-blocking fixes first).** After completing each file, append its status to `PROGRESS_COOKBOOK.md` so the session can be resumed cleanly if usage limits are hit.
- **Front-load actual edits; minimize exploration overhead.** Extensive exploration before editing wastes session budget.

### Bibliography Hygiene
- **Before any bib edit, audit the `.bib` file: find unused entries, missing citations, and verify every DOI resolves via CrossRef. Report a summary table before making changes.** This standardises the zombie-citation and DOI-enrichment checks that previously ran ad hoc.

## Token Optimization Protocol (18-Hack Integration — 2026-04-12)
Source: Burhan Kocabıyık, "Claude Code Token Hackleri: 18 Yöntem" + session experience.

### TIER 1 — Easy Hacks (Session Discipline)

**H1 · /clear between tasks.** Every task switch (e.g., Stata debug → R panel analysis → LaTeX table) starts with `/clear`. Context accumulates multiplicatively; clearing resets the cost curve.

**H2 · Disable unused MCPs.** Each MCP injects tool schemas into every request. Keep only file-ops + shell active during analysis. Re-enable others (browser, Zotero, etc.) only when needed.

**H3 · /stats after every major operation.** Track token burn rate. If a single prompt consumed >50k tokens, simplify the next prompt or split the task.

**H4 · /cost at session boundaries.** Log session cost in PROGRESS.md to build a cost baseline per project type (e.g., "CS-ARDL estimation ~$0.40/session").

**H5 · /context at 60-70% fill.** When context window approaches saturation, run `/compact` proactively — do not wait for degradation.

**H6 · One-shot specific prompts.** Ambiguous prompts cause back-and-forth = wasted tokens.
- BAD: "Analyze my panel"
- GOOD: "Run Pesaran CD test on panel_oecd.csv, report test stat + p-value, interpret cross-section dependence"

**H7 · English prompts, Turkish output.** Turkish ≈ 1.8 tokens/word vs English ≈ 1.0. All .md files, CLAUDE.md, and instructions stay English. Request Turkish output explicitly: "Output the discussion section in Turkish."

**H8 · Minimal prompt syntax.** No courtesy padding. Direct imperative: "Estimate FE model with Driscoll-Kraay SE" not "Could you please kindly estimate a fixed effects model with robust standard errors for me?"

**H9 · One task = one session.** Literature review, code writing, table formatting, manuscript drafting → separate sessions. After each, `/clear` + git commit.

### TIER 2 — Medium Hacks (Context Management)

**H10 · /compact at 60-70% context fill.** Compresses conversation history while preserving critical information. Run proactively during long Stata/R debug sessions.

**H11 · Lean CLAUDE.md (this file).** This file is read on every request. Every unnecessary line costs tokens across all interactions. Rule: if a line hasn't been referenced in 30 days, archive it to `960-Infrastructure/claude-md-archive.md`.

**H12 · Plan mode for complex tasks.** Before multi-step analysis (e.g., full EKC pipeline), use plan mode: Claude plans without executing, user approves, then execution begins. Prevents costly misdirection.

**H13 · Git checkpoint strategy.** Commit after each pipeline stage: data-clean → EDA → unit-root → cointegration → estimation → robustness. On error, revert to checkpoint instead of re-running everything.

**H14 · Memory 2.0 (/memory).** Store persistent preferences (journal style, variable naming, LaTeX conventions) in Claude memory. Avoids re-specifying per session. Enable automemory for incremental learning.

### TIER 3 — Advanced Hacks (Model & Architecture)

**H15 · Hybrid model routing (Opus + Sonnet).**
- **Sonnet (default):** Data cleaning, table formatting, .bib editing, file operations, routine code fixes.
- **Opus (on-demand):** Identification strategy design, CS-ARDL specification, discussion/policy section writing, complex debugging, architectural decisions.
- Rule: Start every session in Sonnet. Switch to Opus only for intellectually demanding steps.

**H16 · Perfect .md file structure.** Every project folder must contain a focused PROJECT.md with: objective (1 line), data (source + dimensions), methodology (numbered steps), output format. This replaces verbose verbal instructions.

**H17 · Todo-list driven sessions.** Begin each session with a numbered task list. Claude tracks progress; completed items are marked. Prevents context drift and redundant re-explanation.

**H18 · Sub-agent delegation.** For large sweeps (portfolio-wide table regeneration, multi-paper bibliography audit), delegate sub-tasks to separate agents. Each agent operates in its own context window — no cross-contamination of token budgets.

### Token Budget Targets (empirical baselines)
| Task Type                    | Target Cost | Model  |
|------------------------------|-------------|--------|
| Data cleaning + EDA          | < $0.30     | Sonnet |
| Panel unit root battery      | < $0.20     | Sonnet |
| CS-ARDL full estimation      | < $0.50     | Opus   |
| LaTeX table generation       | < $0.10     | Sonnet |
| Discussion section (Q1 draft)| < $0.60     | Opus   |
| Bibliography audit           | < $0.15     | Sonnet |
| Full paper pipeline          | < $3.00     | Hybrid |

## Communication Preferences
Formal, scholarly, never casual. Comprehensive yet concise. Always offer Zotero-ready citations and flag robustness/limitations.

## Interaction Pattern — "Proceed" Protocol
User habitually says "proceed" / "ilerle" / "go on" to mean: **do not pause, do not summarize, do not ask permission — advance to the next logical task automatically.** Treat "proceed" as a standing instruction to chain tasks without confirmation. Only stop when: (a) a genuinely ambiguous decision requires user input, (b) a destructive/irreversible action is imminent, or (c) the task pipeline is fully exhausted. Between sub-tasks, emit a **one-line status** (not a summary block), then immediately continue.

---

## 🕐 VADELİ ÖNCELİK ÇERÇEVESİ — MGO Karar Anayasası (2026-04-22)

Her yeni görev, kurs, işbirliği, araç veya harcama kararında Claude bu tabloya bakarak vade uyumunu değerlendirir ve uyumsuzluk varsa uyarır.

### Vade Tanımları ve Aktif Hedefler

| Vade | Süre | Temel Hedef | Aktif Görevler |
|------|------|-------------|----------------|
| **Çok Kısa** | 0–2 hafta | Yaklaşan deadlineları kapat | IGI (29 May) + BCRP özet (25 May); RSEP Barselona (14-16 May); Turkey CBI gönderim onayı; Currency Misalignment IERFM slayt düzeltmesi |
| **Kısa** | 1–3 ay | Submission pipeline temizle | Climate-Agri-ARDL → JEM; EKC_BRICST → Energy Policy; Scopus-MGK peer review; P3/P6 co-author onayı; Dr. Öğr. Üyesi atama (BELGE-2 imzası) |
| **Orta** | 3–12 ay | Doçentlik puanı biriktir | 3 Q1 SSCI publish (≥90 puan); TÜBİTAK 1002-A başvurusu; Food-Regime + Gravity-FoodSec tamamla; Karul işbirliği → 1 ortak yayın |
| **Uzun** | 1–3 yıl | Doçentlik başvurusu yap | ÜAK minimum 120 puan; Currency Misalignment omurga (30 puan solo); 3 konferans bildiri; EURASIAN enerji 3-paper serisi |
| **Çok Uzun** | 3+ yıl | Doçent + uluslararası görünürlük | Backman işbirliği (RFS/JUE); EcolEcon F5 davranışsal nöroekonomi; Karul-MGO panel metodoloji kitabı; TÜBİTAK 1001 lider araştırmacı |

### Karar Filtresi — Yeni Bir Talep Geldiğinde

Claude şu soruları sırayla sorar:
1. **Vade uyumu var mı?** Görev hangi vadede değer üretiyor? Aktif hedefle örtüşüyor mu?
2. **Fırsat maliyeti nedir?** Bu göreve harcanan süre hangi aktif deadline'ı geciktirir?
3. **Katkı katsayısı nedir?** Direkt yayın/puan/atama katkısı var mı yoksa dolaylı mı?

### Vade Uyumu Değerlendirme Örnekleri

| Talep | Vade | Uyum | Karar |
|-------|------|------|-------|
| HPC/Parallel Computing kursu (C++, MPI) | Çok Uzun | ❌ Çok erken | Ertele — mevcut darboğaz computing değil |
| R `parallel` paketi öğren | Kısa | ✅ Uyumlu | Yap — Webb bootstrap'ı hızlandırır |
| Julia FixedEffectModels derin öğrenim | Orta | ⚠️ Koşullu | Sadece büyük panel gelirse |
| Zotero DOI enrichment tamamla | Çok Kısa | ✅ Kritik | Hemen — submission öncesi audit |
| EcolEcon F5 nöroekonomi paper yaz | Çok Uzun | ✅ Doğru vade | Doçentlik sonrasına sakla |
| TÜBİTAK 1001 başvurusu | Orta-Uzun | ✅ Zamanı geldi | 2026-2 döngüsünü hazırla |

### Proaktif Vade Uyarısı Kuralı
- Çok kısa vadeli deadline varken uzun vadeli iş yapılırsa → **UYAR.**
- Çok uzun vadeli bir şey önerilirse → vadesi gelip gelmediğini kontrol et, varken söyle.
- Vade belirsizse → "Bu hangi vadeye hizmet ediyor?" diye sor.

---

## 🔴 ANAYASA — AVRASYa SİYASİ İKTİSAT KAĞIT ÇERÇEVESI (2026-04-25)

> **Her Avrasya/jeoekonomi paper fikrinde, ANKASAM→Q1 dönüşümünde, BRI/AIIB/finans/iklim politika makalelerinde aktiftir.**

### 6 Teori Kümesi — Hangisi Ne Zaman

| Küme | Teori | Ne Zaman Kullan |
|------|-------|----------------|
| **G** | **Geoeconomics** (Clayton, Maggiori & Schreger 2026 *Econometrica*) | BRI/AIIB, Hürmüz, enerji koridorları, SWIFT, yaptırım |
| **H** | **Hegemonic Stability Theory** (Kindleberger 1973; Keohane 1984) | BRICS+, Washington Consensus, EAEU, Bretton Woods |
| **S** | **Structural Power** (Strange 1988 *States and Markets*) | Dolar hegemonyası, Basel IV, SWIFT, bilgi standartları |
| **I** | **Institutional Isomorphism** (DiMaggio & Powell 1983 ASR) | AIIB standartları, WB ko-finansman, EAEU kurumsal uyum |
| **F** | **Financial Fragmentation** (Cipriani et al. 2023 *JEP*) | Ödeme sistemleri, yaptırım mimarisi, Basel boşlukları |
| **D** | **BRI Debt Architecture** (Horn, Reinhart & Trebesch 2025 NBER) | BRI borç yeniden yapılanma, egemenlik kısıtı |

### Zorunlu Q1 Atıf Kuralı
Her Avrasya/jeoekonomi makalesi minimum şunları içermeli:
- **Clayton et al. (2026 Econometrica)** — geoeconomics çerçevesi (G)
- **Strange (1988)** — yapısal güç (S)
- **Cipriani et al. (2023 JEP DOI:10.1257/jep.37.1.31)** — finansal yaptırımlar (F)
- Konuya göre **I** veya **H** veya **D** kümesinden ≥1

### ANKASAM → Q1 Dönüşüm Protokolü
1. Hangi SB hangi teoriye dayanıyor? → Yukarıdaki haritaya bak
2. Bir test edilebilir hipotez oluştur (mekanizma = "coercive isomorphism drives AIIB-WB convergence")
3. Veri: AIIB project dataset (Wang 2025, public), TITR TEU, BIS cross-border claims, WB INRAIL data
4. 5-8 son 5 yıl SSCI atıf ekle
5. Anti-AI kelime taraması yap
6. Hedef dergi: *Review of International Political Economy* (SSCI Q1, best fit)

### ✅ SB02 DOI DÜZELTİLDİ (2026-04-25)
Eski hatalı atıf (hallucination): Della Posta DOI 10.1111/1758-5899.70001 ile "China's Global Financial Expansion: Revisionism or Adaptation?" başlığı — YANLIŞ.
Gerçek DOI = "The Discordant 'Debt Trap' and 'Secrecy' Narratives on BRI" (GP 16(2):348-356).
Düzeltilmiş atıf [v] — tüm EN/TR/RU versiyonlarda:
**Heldt, E.C., Schmidtke, H. & Serrano Oswald, O. (2025). "Multilateralism à la carte: how China navigates global economic institutions." *Review of International Political Economy*, 32(4): 899–921. DOI: 10.1080/09692290.2025.2495694**

### Tam referans listesi
→ `memory/reference_political_economy_theoretical_architecture.md`

---

## 🔴 ANAYASA — PANEL EKONOMETRİ PROMPT PROTOKOLÜ (2026-04-25)

> **Her panel analizi talebinde, her metodoloji sorusunda, her test seçim kararında aktiftir. Eksik bilgiyle yanlış test önerisi = metodolojik hata.**

### Metodolojik Evrim Hiyerarşisi (Karul Ekosistemi)

Her test nesil bilgisiyle birlikte okunmalıdır:

| Nesil | CSD | Heterojen | Faktör | Örnekler |
|-------|:---:|:---------:|:------:|----------|
| 1. Nesil | ❌ | ❌/✅ | ❌ | LLC, IPS, Pedroni, DH2012, FMOLS |
| 1.5 Nesil | ✅(boot) | ✅ | ❌ | Westerlund+bootstrap, Konya SUR |
| 2. Nesil | ✅ | ✅ | ✅ | CIPS, PANIC, PANICCA, NK2024, AMG, CCEMG |

**Kural:** CD testi anlamlıysa → 1. nesil test birincil OLAMAZ; yalnızca referans/karşılaştırma.

### Karar Ağacı — Test Öncelik Sırası

```
CD testi (Pesaran 2004) → p < 0.05?
  Evet → Birim kök: CIPS/PANIC (2. nesil) esas | LLC/IPS sadece referans
          Eşbütünleşme: Westerlund+bootstrap esas | Pedroni sadece referans
          Nedensellik: NK2024 PANIC-VAR esas | DH2012 sadece diagnostik
          Tahmin: AMG veya CCEMG | Driscoll-Kraay (SE düzeltmesi için ek)
  Hayır → IPS/Pedroni/DH2012 birincil olabilir
```

### MGO Panel Ekonometri Prompt Şablonu

Her panel analizi talebinde şu formatı kullan:

```
## BAĞLAM
Araştırma sorusu: [neyin neden üzerindeki etkisi — 1 cümle]
Hedef dergi: [örn. Energy Economics SSCI Q1]
Yazılım kısıtı: [GAUSS / R / Stata]

## VERİ MATRİSİ
N = [birim sayısı]  |  T = [dönem sayısı]  |  Dönem: [YYYY–YYYY]
Panel tipi: [dengeli / dengesiz]
Bağımlı: [değişken, birim, kaynak]
Ana açıklayıcı: [değişken, birim, kaynak]
Kontroller: [liste]
Dönüşüm: [ln / düzey / fark]

## ÖN TEST SONUÇLARI
CD: Z = [...], p = [...] → CSD [var/yok]
Delta (eğim homojenliği): [homojen/heterojen]
Birim kök (CIPS): [I(0)/I(1)/karışık]
Eşbütünleşme: [var/yok/belirsiz]

## HEDEF GÖREV (tek görev seç)
[ ] Birim kök testi seç ve uygula
[ ] Eşbütünleşme testi seç ve uygula
[ ] Nedensellik testi seç ve uygula
[ ] Uzun dönem tahmini yap
[ ] Sağlamlık seti tasarla
[ ] Metodoloji bölümünü yaz (dil: EN, hedef: [dergi])

## KISITLAR
- Karul testleri → GAUSS zorunlu; R replikasyonu YASAK
- Wikipedia yasak; doğrulanmamış DOI yasak
```

### Neden Bu Şablon Zorunlu?

| Eksik bilgi | Olası hata |
|-------------|-----------|
| N, T verilmemiş | Yanlış asimptotik uygulanır (T>N vs N>T) |
| CD sonucu yok | 1. nesil test önerilebilir → size bozulması |
| Yazılım kısıtı yok | R ile Karul testi önerilir → KARUL KURALI ihlali |
| Hedef dergi yok | Yetersiz rigor → hakem reddi |
| Tek görev belirsiz | Hem birim kök hem tahmin = token israfı |

### NK2024 Özel Kuralı
- NK2024 (PANIC-VAR) → GAUSS kodu `600-Methods/NK2024_GAUSS/` ✅
- R toolkit → sadece keşif/ön analiz; Q1 tablo değerleri GAUSS çıktısından
- PANICCA → robustness; PANIC → birincil
- Benchmark sırası: NK2024 → PANICCA → EK2011 → DH2012 → Konya

---

## 🔴 ANAYASA — TAM METODOLOJİ KARAR AĞAÇLARI (2026-04-25)

> **Her panel/zaman serisi metodoloji kararında, her makale tasarımında, her hakem revizyonunda aktiftir.**
> Tam küme detayları → `memory/reference_methodology_decision_trees.md`

### 3 Nesil Temel Kural (Her Testte Geçerli)

| Nesil | Testler | CSD Varsayımı | MGO Kuralı |
|-------|---------|--------------|-----------|
| **1. Nesil** | LLC, IPS, MW, Pedroni, DH2012, Hadri | CSD YOK | ❌ CSD varsa KULLANMA — sadece referans |
| **1.5 Nesil** | Westerlund+bootstrap, Westerlund-Edgerton | Kısmen | ⚠️ Bootstrap zorunlu; panel tabloya dahil et |
| **2. Nesil** | CIPS, CADF, PANIC, PANICCA, AMG, CCEMG, NK2024 | CSD VAR | ✅ Birincil — CSD sonrası varsayılan |

### Ana Karar Akışı (Her Makale İçin)

```
ADIM 1 — ÖN TESTLER (zorunlu sıra):
  Pesaran CD / CDw+ → [CSD var / yok]
  Pesaran-Yamagata Delta → [homojen / heterojen]

ADIM 2 — BİRİM KÖK:
  CSD yok          → LLC / IPS / MW
  CSD var + T>N    → CIPS / PANIC (PCA) ← TERCİH
  CSD var + T≈N    → CIPS / PANICCA (CSA)

ADIM 3 — EŞBÜTÜNLEŞMİ:
  CSD yok          → Pedroni / Kao (REFERANS OLARAK KABUL)
  CSD var          → Westerlund(2007)+bootstrap [BİRİNCİL]
                     Pedroni → sadece "karşılaştırma amaçlı"

ADIM 4 — TAHMİN:
  No CSD, homojen  → FMOLS / DOLS
  CSD, heterojen   → AMG / CCEMG [BİRİNCİL]
  CSD, dinamik     → CS-ARDL / MG-ECM (csdm 1.0.1 ✅)
                     → De Vos rank condition: estat ranktest ZORUNLU
  Endojenlik       → System-GMM (Blundell-Bond) / 2SLS-IV

ADIM 5 — NEDENSELLİK:
  CSD var          → NK2024 (PANIC-VAR+Holm) [BİRİNCİL] → GAUSS zorunlu
                     DH2012 → sadece "ön tanı" (1. nesil uyarısı ekle)
  CSD yok          → DH2012 / Konya bootstrap / Toda-Yamamoto

ADIM 6 — SAĞLAMLIK:
  N<30 küme        → Webb wild cluster bootstrap ZORUNLU
  Yapısal kırılma  → xtbreak (SJ 2025 ✅ Q1 cite edilebilir)
  Eğim homojenliği → De Vos (2024) rank condition
```

**12 küme (C1=Birim Kök…C12=DFM) + Q1 güncelleme protokolü + 2025-26 toolkit değişiklikleri → tam liste: `memory/reference_methodology_decision_trees.md`**

**Kural:** Yeni metodoloji makalesi geldiğinde `reference_methodology_decision_trees.md` güncellenir.

---

## 🔴 ANAYASA — ROUDANE EKOSİSTEMİ: EPİSTEMOLOJİK KARAR AĞAÇLARI (2026-04-25)

> **Her zaman serisi/NARDL/kantil/asimetrik analiz talebinde aktiftir. 39 kurulu Python paketi — tam rehber: `600-Methods/roudane_python_packages_reference.md`**

### Temel Epistemolojik İlke

Her Roudane paketi bir önceki yöntemin **bir kısıtını gevşeterek** doğar:

```
ADF → tarur (nonlinear ESTAR) → hybridnonlinur (Fourier smooth kırılma)
    → fwadf (wavelet ön-filtre) → qadf (kantil ρ(τ)) → boundedtest (sınırlı DGP)

Johansen → robcointeg (Student-t robust) → cointhatemij (çift kırılma)
         → fouriercoint (Fourier smooth CI) → vecmbreak (Group LASSO)

OLS → NARDL (asimetri) → QARDL (kantil) → wavenardl (frekans)
    → wqr.qq_regression (QQ çiftler) → qqkrls (nonlinear kernel QQ)
```

**6 küme (A=Birim Kök, B=Eşbütünleşme, C=NARDL, D=Kantil/Wavelet, E=Nedensellik, F=Panel) + Master karar akışı → tam rehber: `600-Methods/roudane_python_packages_reference.md`**

### Kritik Bug Listesi (Kullanmadan Önce Kontrol)

| Paket | Durum | Bypass |
|-------|-------|--------|
| `pycupfm` | ❌ LSDV bug | kullanılamaz |
| `pmct` | ❌ 0-dim bug | kullanılamaz |
| `pydcce.CDTest CDw` | ⚠️ broadcast | standart CD kullan |
| `qardl` gamma | ⚠️ slice hata | `res.gamma[int(i*k):int((i+1)*k)]` |
| `wqr.np_quantile_causality` | ⚠️ q=skalar çöküyor | `q` numpy array zorunlu |
| `selectbreakcoint` | ⚠️ `.fit()` yok | `.test(y, x)` |
| `nearkpss` | ⚠️ `mkpss` modül | `modified_kpss_test` doğrudan |
| `funitroot` | ⚠️ plotly yok | `pip3 install plotly` önce |

### Roudane ≠ GAUSS Kural Hatırlatması
- `hybridnonlinur.fourier_adf/kss` → Zaman serisi testi — **panel değil**
- Karul-Nazlıoğlu (2017) Fourier-LM panel → **GAUSS zorunlu**
- Roudane paketleri: tek seri ön-test + robustness → Q1 tablo değerleri GAUSS'tan
