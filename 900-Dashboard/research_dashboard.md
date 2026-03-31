# Research Automation Dashboard

Tüm otomasyon katmanları ve mevcut proje stokları bu sayfada takip edin. Her bölüm en güncel dosyaya işaret eder.

## Pipeline Status

- **JEL classification** – çıktı klasörü: `100-Literature/135-JEL-Indexes/`; gece otomasyonu varsa burada üretilen indeksler izlenir.
- **Brainstorm → Incubator → Promotion** – `200-Concepts/240-Brainstorming-Lab`, `300-Projects/340-Idea-Incubator`, `300-Projects/310-Active-Papers`; promotion mantığı bu klasör akışı üzerinden takip edilir.  
- **Empirical analysis** – analiz çıktıları `500-Methods/530-Econometric-Analysis/.../results/empirical-summary-*.md` veya proje bazlı `700-Submissions/active/.../output/` altında toplanır.  
- **Submission workflow** – `700-Submissions/` active folder per paper, template in `_templates/analysis_workflow_template.md`.

## Live Projects

- `green-innovation-structural` (Green Innovation Structural Transformation):  
  - Paper note: `100-Literature/140-Paper-Notes/2026-03-31-Green-Innovation-Structural-Transformation.md`  
  - Method map: `100-Literature/150-Method-Maps/Panel-ARDL-Green-Innovation.md`  
  - Equation: `500-Methods/540-Equation-Library/panel-data/Green-Innovation-ECM.md`  
  - Submission folder: `700-Submissions/active/2026-03-30_AER_GreenGrowth/` with `code/run.sh`, clean/analysis scripts, `output/regression_summary.md`, `timeline.md`, `manuscript/`, `submission/`, `reviews/`, `revision/`.

## Latest Automation Runs

- Brainstorm capture sample: `200-Concepts/240-Brainstorming-Lab/2026-03-30-green-growth-and-structural-transformation.md`  
- Promotions log: aktifse proje klasörlerindeki `timeline.md` ve ilgili incubator notları üzerinden izlenir.  
- AI handoff/context: `900-Dashboard/notebooklm_export.md`

## Next Updates

1. Tweak `700-Submissions` project outputs (figures, manuscript) and mark timeline steps.  
2. Keep adding AI brainstorming sessions and flag promising ones with `promotion_ready: true`.  
3. JEL tag writeback veya benzeri otomasyonları yalnızca bu vault içinde izlenebilir bir config/dokümantasyonla aktive et.  

Bu dosya her gün güncellenebilir; yeni proje eklendikçe ilgili satırları çoğaltın. Shared dashboard olarak DeepSeek/Claude oturumlarında bu dosyayı açmak bağlamı korur. 
