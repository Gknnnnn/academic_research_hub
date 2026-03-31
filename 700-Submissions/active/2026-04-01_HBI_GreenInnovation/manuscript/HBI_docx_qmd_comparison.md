# HBI DOCX vs QMD Comparison

## Files Compared

- DOCX: `/Users/mehmetgokhanozdemir/Documents/HBI_MGO_Makale_Konya/MGO_HBI_Tarim_Konya_v3.docx`
- QMD: `/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/700-Submissions/active/2026-04-01_HBI_GreenInnovation/manuscript/MGO_HBI_Tarim_Konya_v3.qmd`

## High-Level Result

These are clearly the same manuscript family.

- Same Turkish title
- Same English title
- Same authors and affiliations
- Same abstract / keyword structure
- Same section flow: `GIRIS` -> `LITERATUR OZETI` -> `MATERYAL VE YONTEM` -> findings/results -> `SONUC` -> `KAYNAKCA`

## Main Difference

The QMD file is the stronger production format.

- It contains executable code chunks, dynamic statistics, and rendering logic.
- It is better for reproducibility and future revision.
- It is already integrated into the `700-Submissions` project workflow.

The DOCX file is the stronger legacy reading source.

- It is easier to skim as a continuous narrative.
- It preserves an earlier full-text prose version outside the project workflow.

## Section-by-Section Recommendation

- Title and author block: keep QMD
- Turkish abstract: keep QMD, but compare wording against DOCX if needed
- English abstract: review carefully; the DOCX extraction shows a broken `R^2` expression, so QMD is safer
- Introduction: compare both versions manually; likely merge for style polish
- Literature review: compare both versions manually; likely merge for flow and citation phrasing
- Methods: keep QMD as the master version because it contains runnable code structure
- Results / findings: keep QMD as the master version
- Conclusion: compare both versions manually and keep the clearer prose
- References: keep QMD workflow, but verify formatting at render stage

## Working Decision

Use the QMD file as the master manuscript.

Use the DOCX file only as:

- a prose comparison source
- a recovery source for cleaner wording
- a backup reference for sections that read better in Word form

## Next Editing Move

The next useful step is not to rewrite everything.

Instead:

1. Open DOCX and QMD side by side.
2. Review only these sections first: `GIRIS`, `LITERATUR OZETI`, `SONUC`.
3. Copy only the cleaner prose from DOCX into QMD.
4. Leave all code-backed methods and results in QMD.
