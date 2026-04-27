"""
Pre-submission audit script — UY-MGO-Makale (MAKÜ SOBED)
Kontrol: Tablo yıldız tutarlılığı, zombie citation, örneklem ifadesi
Düzeltme: Unicode yıldız desteği eklendi (U+2217 ★)
"""

import re
import sys
import zipfile
from pathlib import Path

# ── Ayarlar ──────────────────────────────────────────────────────────────────
DOCX_PATH = Path(__file__).parent.parent / "04-Manuscript" / "UY_MGO_Makale_TR_FINAL.docx"
SIGNIFICANCE_LEVELS = {
    "***": 0.01,
    "**":  0.05,
    "*":   0.10,
}
# Unicode yıldız karşılıkları (U+2217 ASTERISK OPERATOR)
UNICODE_STARS = {
    "\u2217\u2217\u2217": "***",
    "\u2217\u2217":       "**",
    "\u2217":             "*",
}

# ── Yardımcı ─────────────────────────────────────────────────────────────────
def normalise_stars(text: str) -> str:
    """Unicode yıldızları ASCII'ye çevirir."""
    for u, a in UNICODE_STARS.items():
        text = text.replace(u, a)
    return text


def extract_docx_text(path: Path) -> str:
    """DOCX → düz metin."""
    with zipfile.ZipFile(path) as z:
        xml = z.read("word/document.xml").decode("utf-8", errors="ignore")
    text = re.sub(r"<[^>]+>", " ", xml)
    text = re.sub(r"\s+", " ", text)
    return normalise_stars(text)


# ── Kontrol 1: Yıldız tutarlılığı ────────────────────────────────────────────
def check_star_consistency(text: str) -> list[str]:
    """
    Yıldız sonrası p-değeri parantezi bulunan kalıpları tarar.
    Örnek: 0.129*** (p=0.24)  →  TUTARSIZ
    """
    pattern = re.compile(
        r"([-+]?\d+\.?\d*)"       # katsayı
        r"(\*{1,3})"               # yıldızlar (ASCII, unicode normalise edildi)
        r"\s*\(([^)]+)\)",         # parantez içi (SE veya p-değeri)
        re.UNICODE,
    )
    issues = []
    for m in pattern.finditer(text):
        coef, stars, paren = m.group(1), m.group(2), m.group(3)
        # p-değeri parantezde mi?
        p_match = re.search(r"p\s*=\s*(0?\.\d+)", paren)
        if p_match:
            p_val = float(p_match.group(1))
            threshold = SIGNIFICANCE_LEVELS[stars]
            if p_val >= threshold:
                issues.append(
                    f"TUTARSIZ YILDIZ: {coef}{stars} ama p={p_val:.3f} "
                    f"(eşik {threshold}) — '{m.group(0)[:60]}'"
                )
    return issues


# ── Kontrol 2: Örneklem ifadesi ──────────────────────────────────────────────
SAMPLE_PATTERNS = [
    (r"\b39\s+[üu]lke\b",         "39 ülke — özette 37 yazılmalı (etkin N)"),
    (r"\b37\s+[üu]lke\b",         "37 ülke — EK-1 dipnotu gerekli (Çin+Zambiya not)"),
    (r"N\s*=\s*39\b",              "N=39 — N=37 (etkin) ile değiştirilmeli"),
]

def check_sample_size(text: str) -> list[str]:
    issues = []
    for pat, msg in SAMPLE_PATTERNS:
        if re.search(pat, text, re.IGNORECASE):
            issues.append(f"ÖRNEKLEM: {msg}")
    return issues


# ── Kontrol 3: Zombie citation tarama ────────────────────────────────────────
def check_zombie_citations(text: str) -> list[str]:
    """
    Metin-içi atıf formatı: (Yazar, Yıl) veya Yazar (Yıl)
    Kaynakça bölümünde bulunan yazar-yıl çiftleri ile karşılaştırır.
    """
    # Metin-içi atıf kalıpları
    inline_pattern = re.compile(
        r"([A-ZÇĞİÖŞÜa-zçğışöüâîû][a-zçğışöüâîû]+(?:\s+vd\.?)?)"
        r"\s*[,\s]\s*((?:19|20)\d{2}[a-z]?)",
        re.UNICODE,
    )
    inline_refs = set()
    for m in inline_pattern.finditer(text):
        inline_refs.add((m.group(1).strip(), m.group(2).strip()))

    # Kaynakça bölümü tespiti (son büyük bölüm)
    ref_section_match = re.search(
        r"KAYNAKÇA|Kaynakça|REFERENCES|References", text
    )
    ref_text = text[ref_section_match.start():] if ref_section_match else ""

    bib_pattern = re.compile(
        r"([A-ZÇĞİÖŞÜ][a-zçğışöüâîûA-Z\-\.]+(?:,?\s+[A-Z]\.)*)"
        r"\s*\(?(?:19|20)(\d{2})[a-z]?\)?",
        re.UNICODE,
    )
    bib_years = set()
    for m in bib_pattern.finditer(ref_text):
        bib_years.add(f"20{m.group(2)}" if int(m.group(2)) < 50 else f"19{m.group(2)}")

    issues = []
    if not ref_text:
        issues.append("KAYNAKÇA: Kaynakça bölümü tespit edilemedi — manuel kontrol gerekli")
    else:
        issues.append(
            f"BİLGİ: {len(inline_refs)} metin-içi atıf, "
            f"{len(bib_years)} kaynakça yılı tespit edildi — "
            "tam çapraz kontrol için Zotero kullanınız."
        )
    return issues


# ── Ana akış ─────────────────────────────────────────────────────────────────
def main():
    if not DOCX_PATH.exists():
        print(f"HATA: DOCX bulunamadı → {DOCX_PATH}")
        sys.exit(1)

    print(f"Denetleniyor: {DOCX_PATH.name}\n{'─'*60}")
    text = extract_docx_text(DOCX_PATH)

    all_issues = []

    # Kontrol 1
    star_issues = check_star_consistency(text)
    all_issues.extend(star_issues)
    print(f"[1] Yıldız tutarlılığı: {len(star_issues)} sorun")
    for i in star_issues:
        print(f"    ⚠  {i}")

    # Kontrol 2
    sample_issues = check_sample_size(text)
    all_issues.extend(sample_issues)
    print(f"\n[2] Örneklem ifadesi: {len(sample_issues)} tespit")
    for i in sample_issues:
        print(f"    ⚠  {i}")

    # Kontrol 3
    zombie_issues = check_zombie_citations(text)
    all_issues.extend(zombie_issues)
    print(f"\n[3] Zombie citation: {len(zombie_issues)} tespit")
    for i in zombie_issues:
        print(f"    ℹ  {i}")

    print(f"\n{'─'*60}")
    if all_issues:
        print(f"TOPLAM {len(all_issues)} tespit — gönderimden önce gözden geçirin.")
    else:
        print("✅ Denetim temiz — gönderime hazır.")


if __name__ == "__main__":
    main()
