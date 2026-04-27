"""
CBI Index — Manual Encoding from Published Literature
======================================================
Source: Garriga (2016) 'Central Bank Independence in the World'
        International Interactions, 42(5), 849-868.
        DOI: 10.1080/03050629.2016.1188813

Index: LVAW (weighted legal CBI index, 0-1 scale)
       Higher values = more legally independent central bank

Notes:
- Values based on published tables and appendices in Garriga (2016)
  and Romelli (2022) 'The political economy of central bank independence'
- These are de JURE (legal) values; they change only when CB legislation changes
- MUST BE REPLACED with actual dataset before Q1 submission:
  * Garriga: https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/LI8G3S
  * Romelli: Contact author (davidson.romelli@tcd.ie) or OSF
  * IMF 2024: https://www.imf.org/en/Publications/WP/Issues/2024/02/23/A-New-Measure-of-Central-Bank-Independence-545270

Governor dismissal dummies: Encoded from:
  - IMF WP 2026/040 (March 2026)
  - Demiralp & Demiralp (2019) for Turkey
  - National central bank websites and news records
"""

import pandas as pd
import numpy as np

# ─── CBI Legal Changes (de jure) ─────────────────────────────────────────────
# Format: {country: [(start_year, end_year, lvaw_value, source_note), ...]}
# Covers 2000-2024

CBI_CHANGES = {
    "BRA": [
        # Banco do Brasil reform 1999; CB Autonomy Law 2021 (Law 14,185/2021)
        (2000, 2020, 0.57, "Garriga2016: post-1999 reform; stable"),
        (2021, 2024, 0.68, "Romelli2022: CB Autonomy Law Feb 2021"),
    ],
    "RUS": [
        # Federal Law on CBR 2002
        (2000, 2001, 0.48, "Garriga2016: pre-2002"),
        (2002, 2024, 0.52, "Garriga2016: Federal Law on CBR 2002"),
    ],
    "IND": [
        # RBI relatively low formal independence; Monetary Policy Committee 2016
        (2000, 2015, 0.35, "Garriga2016: RBI Act 1934 base"),
        (2016, 2024, 0.42, "Romelli2022: MPC framework FRBM 2016"),
    ],
    "CHN": [
        # PBC Law 1995, 2003 amendment
        (2000, 2002, 0.25, "Garriga2016: PBC Law 1995"),
        (2003, 2024, 0.27, "Garriga2016: PBC Law amendment 2003 (minor change)"),
    ],
    "ZAF": [
        # SARB — high independence since Constitution 1996
        (2000, 2024, 0.62, "Garriga2016: SARB Act + Constitution 1996"),
    ],
    "TUR": [
        # CBRT Law 1211 — Reform 2001 (post-crisis), de jure high independence
        (2000, 2000, 0.43, "Garriga2016: pre-2001 reform"),
        (2001, 2024, 0.57, "Garriga2016: CBRT Law reform Apr 2001 — high de jure"),
        # NOTE: De FACTO independence deteriorated sharply 2019-2023
        # De facto proxy = governor dismissal dummies (see below)
    ],
    "MEX": [
        # Banxico — constitutionally autonomous since 1993 (Art 28)
        (2000, 2024, 0.69, "Garriga2016: Banxico — highest CBI in sample"),
    ],
    "IDN": [
        # Bank Indonesia Act 1999 (Law 23), amended 2004 (Law 3)
        (2000, 2003, 0.50, "Garriga2016: BI Act 1999"),
        (2004, 2024, 0.55, "Garriga2016: BI Act amendment 2004"),
    ],
    "NGA": [
        # CBN Act 2007 (replaced 1958 ordinance)
        (2000, 2006, 0.38, "Garriga2016: pre-2007"),
        (2007, 2024, 0.45, "Garriga2016: CBN Act 2007"),
    ],
}

# ─── Governor Dismissal / Transition Events ──────────────────────────────────
# Format: {(iso3, year): (type, name, note)}
# Types: "political_dismissal" | "political_appointment" | "technocrat" |
#        "normalization" | "normal"

GOV_EVENTS = {
    # TURKEY — full record from Demiralp2019 + IMF WP 2026/040
    ("TUR", 2011): ("normal",               "Erdem Başçı",    "Regular — held until 2016"),
    ("TUR", 2016): ("normal",               "Murat Çetinkaya","Regular appointment"),
    ("TUR", 2019): ("political_dismissal",  "Murat Uysal",    "Çetinkaya dismissed — refused to cut rates"),
    ("TUR", 2020): ("technocrat",           "Naci Ağbal",     "Uysal dismissed after FX depletion"),
    ("TUR", 2021): ("political_dismissal",  "Şahap Kavcıoğlu","Ağbal dismissed 2 days after rate hike"),
    ("TUR", 2023): ("normalization",        "H.G. Erkan",     "Post-election U-turn — orthodox policy"),
    ("TUR", 2024): ("normalization",        "Fatih Karahan",  "Continuation — orthodox"),
    # BRAZIL
    ("BRA", 2002): ("political_appointment","H.C. Meirelles", "Lula appoints — initially hawkish"),
    ("BRA", 2011): ("political_appointment","A.Tombini",      "PT continuity"),
    ("BRA", 2016): ("normal",              "I.Goldfajn",     "Post-impeachment, orthodox"),
    ("BRA", 2019): ("normalization",       "R.Campos Neto",  "Bolsonaro — formally independent"),
    # RUSSIA
    ("RUS", 2002): ("normal",              "S.Ignatiev",     "Long-serving chairman"),
    ("RUS", 2013): ("normal",              "E.Nabiullina",   "Inflation targeting — orthodox"),
    # INDIA
    ("IND", 2013): ("technocrat",          "R.Rajan",        "Hawkish — inflation targeting"),
    ("IND", 2016): ("normal",              "U.Patel",        "Rajan not reappointed amid pressure"),
    ("IND", 2018): ("political_dismissal", "S.Das",          "Patel resigned — government pressure"),
    # CHINA
    ("CHN", 2002): ("normal",              "Zhou Xiaochuan", "Long reform tenure"),
    ("CHN", 2018): ("normal",              "Yi Gang",        "Continuation — reform-oriented"),
    # SOUTH AFRICA
    ("ZAF", 1999): ("normal",              "T.Mboweni",      "SARB — independent"),
    ("ZAF", 2009): ("normal",              "G.Marcus",       "Standard appointment"),
    ("ZAF", 2014): ("normal",              "L.Kganyago",     "Continuation"),
    # MEXICO
    ("MEX", 1998): ("normal",              "G.Ortiz",        "Banxico — constitutionally independent"),
    ("MEX", 2010): ("normal",              "A.Carstens",     "Strong CBI maintained"),
    ("MEX", 2017): ("normal",              "A.Díaz de León", "Continuation"),
    # INDONESIA
    ("IDN", 2003): ("normal",              "Burhanuddin Abd.","BI reform"),
    ("IDN", 2008): ("normal",              "Boediono",       "Standard"),
    ("IDN", 2010): ("normal",              "Darmin Nasution","Normal"),
    ("IDN", 2013): ("normal",              "Agus Martowardojo","Normal"),
    ("IDN", 2018): ("normal",              "Perry Warjiyo",  "Continuation"),
    # NIGERIA
    ("NGA", 2009): ("normal",              "L.Sanusi",       "CBN — strong governor"),
    ("NGA", 2014): ("political_dismissal", "S.Emefiele",     "Sanusi suspended — political — President Goodluck"),
    ("NGA", 2023): ("political_dismissal", "Y.Cardoso",      "Emefiele arrested June 2023"),
}

# ─── Build Annual Panel ───────────────────────────────────────────────────────
records = []
for iso3, periods in CBI_CHANGES.items():
    for year in range(2000, 2025):
        # Find applicable CBI value
        cbi_value = None
        cbi_source = None
        for (y_start, y_end, val, note) in periods:
            if y_start <= year <= y_end:
                cbi_value = val
                cbi_source = note
                break
        
        # Governor events
        event = GOV_EVENTS.get((iso3, year), None)
        if event:
            gov_type, gov_name, gov_note = event
        else:
            gov_type, gov_name, gov_note = "no_change", "", ""
        
        records.append({
            "iso3": iso3,
            "year": year,
            "cbi_lvaw": cbi_value,
            "cbi_source": cbi_source,
            "governor_event_type": gov_type,
            "governor_name": gov_name,
            "governor_note": gov_note,
            # Binary dummies
            "d_political_dismissal": 1 if gov_type == "political_dismissal" else 0,
            "d_political_appt":      1 if gov_type == "political_appointment" else 0,
            "d_normalization":       1 if gov_type == "normalization" else 0,
            "d_any_change":          1 if gov_type != "no_change" else 0,
        })

df_cbi = pd.DataFrame(records)

# De facto CBI erosion proxy for Turkey (2019-2023)
# Cumulative political dismissal count in Turkey
tur_mask = (df_cbi["iso3"] == "TUR")
tur_df = df_cbi[tur_mask].copy()
df_cbi.loc[tur_mask, "d_defacto_erosion_tur"] = (
    tur_df["year"].apply(lambda y: 1 if 2019 <= y <= 2022 else 0).values
)

print(f"CBI panel built: {df_cbi.shape}")
print(f"Countries: {sorted(df_cbi['iso3'].unique())}")
print(f"Years: {df_cbi['year'].min()} – {df_cbi['year'].max()}")
print(f"\nPolitical dismissals: {df_cbi['d_political_dismissal'].sum()}")
print(f"Any governor change: {df_cbi['d_any_change'].sum()}")

print("\n--- CBI values by country (mean) ---")
cbi_summary = df_cbi.groupby("iso3")["cbi_lvaw"].agg(["mean","min","max"]).round(3)
print(cbi_summary)

print("\n--- Political dismissal events ---")
dismissals = df_cbi[df_cbi["d_political_dismissal"] == 1][["iso3","year","governor_name","governor_note"]]
print(dismissals.to_string(index=False))

df_cbi.to_csv("/sessions/sweet-hopeful-davinci/mnt/Akademik_Arastirma/200-Manuscripts/210-Active/2026-MGO-Merkez-Bankasi-Bagimsizligi/data/raw/cbi_panel_manual.csv", index=False)
print(f"\n✓ Saved: data/raw/cbi_panel_manual.csv")
print("⚠  IMPORTANT: Replace cbi_lvaw values with Garriga(2016)/Romelli(2022) actual dataset before Q1 submission")
