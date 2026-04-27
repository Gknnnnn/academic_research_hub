"""
Panel Codebook + Summary Statistics — MGO Research Portfolio
Date: 2026-04-27

Outputs:
  codebook_panel_20260427.csv        — variable-level metadata (261 vars)
  summary_stats_{group}_20260427.csv — descriptive stats per group
  missingness_report_20260427.csv    — coverage by var × group
  project_panel_map_20260427.md      — which active projects use which panel vars
"""

import pandas as pd, numpy as np, os, glob
from datetime import date

TODAY = date.today().strftime("%Y%m%d")
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

GROUPS = {
    "CIVETS":      ["COL","IDN","VNM","EGY","TUR","ZAF"],
    "BRICST_MINT": ["BRA","RUS","IND","CHN","ZAF","TUR","MEX","IDN","NGA"],
    "EU27":        ["AUT","BEL","BGR","HRV","CYP","CZE","DNK","EST","FIN","FRA","DEU",
                    "GRC","HUN","IRL","ITA","LVA","LTU","LUX","MLT","NLD","POL","PRT",
                    "ROU","SVK","SVN","ESP","SWE"],
    "EURASIAN":    ["AZE","ARM","BLR","GEO","KAZ","KGZ","MDA","RUS","TJK","TKM","UKR","UZB","TUR"],
    "OECD35":      ["AUS","AUT","BEL","CAN","CHL","CZE","DNK","EST","FIN","FRA","DEU",
                    "GRC","HUN","ISL","IRL","ISR","ITA","JPN","KOR","LVA","LTU","LUX",
                    "MEX","NLD","NZL","NOR","POL","PRT","SVK","SVN","ESP","SWE","CHE","TUR","GBR","USA"],
}

# ─── Codebook metadata ───────────────────────────────────────────────────────
# For each variable: source, units, coverage_note, citation_key

CODEBOOK = {
    # WDI Core
    "gdp_pc_ppp_2017":        ("WB WDI","NY.GDP.PCAP.PP.KD","constant 2017 international $","1990-2024","WorldBank_WDI_2024"),
    "gdp_growth":             ("WB WDI","NY.GDP.MKTP.KD.ZG","% annual","1990-2024","WorldBank_WDI_2024"),
    "inflation_cpi":          ("WB WDI","FP.CPI.TOTL.ZG","% annual","1990-2024","WorldBank_WDI_2024"),
    "trade_gdp":              ("WB WDI","NE.TRD.GNFS.ZS","% of GDP","1990-2024","WorldBank_WDI_2024"),
    "fdi_gdp":                ("WB WDI","BX.KLT.DINV.WD.GD.ZS","net inflows % GDP","1990-2024","WorldBank_WDI_2024"),
    "gov_exp_gdp":            ("WB WDI","NE.CON.GOVT.ZS","% GDP","1990-2024","WorldBank_WDI_2024"),
    "population":             ("WB WDI","SP.POP.TOTL","persons","1990-2024","WorldBank_WDI_2024"),
    "urbanization":           ("WB WDI","SP.URB.TOTL.IN.ZS","% total population","1990-2024","WorldBank_WDI_2024"),
    "co2_pc_ar5":             ("WB WDI","EN.GHG.CO2.PC.CE.AR5","t CO2 per capita (AR5)","1990-2022","WorldBank_WDI_2024"),
    "ghg_total_kt":           ("WB WDI","EN.ATM.GHGT.KT.CE","kt CO2-eq","1990-2022","WorldBank_WDI_2024"),
    "ren_energy_share":       ("WB WDI","EG.FEC.RNEW.ZS","% of total final energy","1990-2021","WorldBank_WDI_2024"),
    "energy_use_pc":          ("WB WDI","EG.USE.PCAP.KG.OE","kg oil eq per capita","1990-2015","WorldBank_WDI_2024"),
    "elec_access":            ("WB WDI","EG.ELC.ACCS.ZS","% population","1990-2022","WorldBank_WDI_2024"),
    "unemp_rate":             ("WB WDI","SL.UEM.TOTL.ZS","% labour force (ILO modelled)","1990-2024","WorldBank_WDI_2024"),
    "unemp_rate_natl":        ("WB WDI","SL.UEM.TOTL.NE.ZS","% labour force (national est.)","1990-2024","WorldBank_WDI_2024"),
    "lfpr":                   ("WB WDI","SL.TLF.CACT.ZS","% population 15+","1990-2024","WorldBank_WDI_2024"),
    "educ_exp_gdp":           ("WB WDI","SE.XPD.TOTL.GD.ZS","% GDP","1990-2022","WorldBank_WDI_2024"),
    "agr_va_gdp":             ("WB WDI","NV.AGR.TOTL.ZS","% GDP","1990-2024","WorldBank_WDI_2024"),
    "food_prod_idx":          ("WB WDI","AG.PRD.FOOD.XD","index 2014-16=100","1990-2022","WorldBank_WDI_2024"),
    "arable_land_pc":         ("WB WDI","AG.LND.ARBL.HA.PC","ha per capita","1990-2021","WorldBank_WDI_2024"),
    "agri_land_pct":          ("WB WDI","AG.LND.AGRI.ZS","% land area","1990-2021","WorldBank_WDI_2024"),
    "undernourishment":       ("WB WDI","SN.ITK.DEFC.ZS","% population","1990-2022","WorldBank_WDI_2024"),
    "cereal_yield":           ("WB WDI","AG.YLD.CREL.KG","kg per ha","1990-2022","WorldBank_WDI_2024"),
    "dom_credit_gdp":         ("WB WDI","FS.AST.DOMS.GD.ZS","% GDP","1990-2024","WorldBank_WDI_2024"),
    "internet_users":         ("WB WDI","IT.NET.USER.ZS","% population","1990-2023","WorldBank_WDI_2024"),
    "tax_revenue_gdp":        ("WB WDI","GC.TAX.TOTL.GD.ZS","% GDP","1990-2023","WorldBank_WDI_2024"),
    # WDI Additional
    "life_expectancy":        ("WB WDI","SP.DYN.LE00.IN","years at birth","1990-2022","WorldBank_WDI_2024"),
    "child_mortality":        ("WB WDI","SH.DYN.MORT","per 1000 live births","1990-2022","WorldBank_WDI_2024"),
    "health_exp_gdp":         ("WB WDI","SH.XPD.CHEX.GD.ZS","% GDP (current)","2000-2021","WorldBank_WDI_2024"),
    "current_account_gdp":    ("WB WDI","BN.CAB.XOKA.GD.ZS","% GDP","1990-2023","WorldBank_WDI_2024"),
    "govt_debt_gdp":          ("WB WDI","GC.DOD.TOTL.GD.ZS","central govt % GDP","1990-2023","WorldBank_WDI_2024"),
    "rnd_exp_gdp":            ("WB WDI","GB.XPD.RSDV.GD.ZS","% GDP","1996-2022","WorldBank_WDI_2024"),
    "gini_index":             ("WB WDI","SI.POV.GINI","0-100","1990-2022","WorldBank_WDI_2024"),
    "hitech_exports_pct":     ("WB WDI","TX.VAL.TECH.MF.ZS","% of manufactured exports","1990-2022","WorldBank_WDI_2024"),
    "pm25_exposure":          ("WB WDI","EN.ATM.PM25.MC.M3","micrograms/m³","1990-2019","WorldBank_WDI_2024"),
    "broadband_subs":         ("WB WDI","IT.NET.BBND.P2","per 100 people","2000-2022","WorldBank_WDI_2024"),
    # WGI
    "wgi_control_corruption": ("WB WGI","CC.EST","estimate −2.5 to +2.5","1996-2023","Kaufmann_Kraay_2024"),
    "wgi_gov_effectiveness":  ("WB WGI","GE.EST","estimate −2.5 to +2.5","1996-2023","Kaufmann_Kraay_2024"),
    "wgi_political_stability":("WB WGI","PV.EST","estimate −2.5 to +2.5","1996-2023","Kaufmann_Kraay_2024"),
    "wgi_rule_of_law":        ("WB WGI","RL.EST","estimate −2.5 to +2.5","1996-2023","Kaufmann_Kraay_2024"),
    "wgi_reg_quality":        ("WB WGI","RQ.EST","estimate −2.5 to +2.5","1996-2023","Kaufmann_Kraay_2024"),
    "wgi_voice_accountability":("WB WGI","VA.EST","estimate −2.5 to +2.5","1996-2023","Kaufmann_Kraay_2024"),
    # HCI
    "hci_overall":            ("WB HCI","HD.HCI.OVRL","index 0-1","2010-2020","WorldBank_HCI_2020"),
    "hci_harmonized_learning":("WB HCI","HD.HCI.HLOS","harmonized learning outcomes","2010-2020","WorldBank_HCI_2020"),
    "hci_u5_survival":        ("WB HCI","HD.HCI.SURV","probability of survival to age 5","2010-2020","WorldBank_HCI_2020"),
    "hci_expected_years_schl":("WB HCI","HD.HCI.EYRS","years","2010-2020","WorldBank_HCI_2020"),
    # OWID CO2
    "owid_co2_mt":            ("OWID CO2","co2","Mt CO2","1990-2022","Ritchie_Rosado_Roser_2024"),
    "owid_co2_pc":            ("OWID CO2","co2_per_capita","t CO2 per capita","1990-2022","Ritchie_Rosado_Roser_2024"),
    "owid_consump_co2":       ("OWID CO2","consumption_co2","Mt CO2 (consumption-based)","1990-2022","Ritchie_Rosado_Roser_2024"),
    "owid_ghg_pc":            ("OWID CO2","ghg_per_capita","t CO2-eq per capita","1990-2022","Ritchie_Rosado_Roser_2024"),
    "owid_ch4_pc":            ("OWID CO2","methane_per_capita","t CO2-eq per capita","1990-2022","Ritchie_Rosado_Roser_2024"),
    "owid_n2o_pc":            ("OWID CO2","nitrous_oxide_per_capita","t CO2-eq per capita","1990-2022","Ritchie_Rosado_Roser_2024"),
    "owid_coal_co2":          ("OWID CO2","coal_co2","Mt CO2","1990-2022","Ritchie_Rosado_Roser_2024"),
    "owid_oil_co2":           ("OWID CO2","oil_co2","Mt CO2","1990-2022","Ritchie_Rosado_Roser_2024"),
    "owid_gas_co2":           ("OWID CO2","gas_co2","Mt CO2","1990-2022","Ritchie_Rosado_Roser_2024"),
    "owid_cement_co2":        ("OWID CO2","cement_co2","Mt CO2","1990-2022","Ritchie_Rosado_Roser_2024"),
    # OWID Energy
    "owid_energy_twh":        ("OWID Energy","primary_energy_consumption","TWh","1990-2022","OurWorldInData_Energy_2024"),
    "owid_energy_pc":         ("OWID Energy","energy_per_capita","kWh per capita","1990-2022","OurWorldInData_Energy_2024"),
    "owid_ren_share":         ("OWID Energy","renewables_share_energy","% primary energy","1990-2022","OurWorldInData_Energy_2024"),
    "owid_fossil_share":      ("OWID Energy","fossil_share_energy","% primary energy","1990-2022","OurWorldInData_Energy_2024"),
    "owid_solar_share":       ("OWID Energy","solar_share_energy","% primary energy","1990-2022","OurWorldInData_Energy_2024"),
    "owid_wind_share":        ("OWID Energy","wind_share_energy","% primary energy","1990-2022","OurWorldInData_Energy_2024"),
    "owid_nuclear_share":     ("OWID Energy","nuclear_share_energy","% primary energy","1990-2022","OurWorldInData_Energy_2024"),
    "owid_carbon_intensity":  ("OWID Energy","carbon_intensity_elec","gCO2/kWh","1990-2022","OurWorldInData_Energy_2024"),
    # PWT
    "pwt_rgdpe":              ("PWT 10.01","rgdpe","million 2017 USD (expenditure-side)","1950-2019","Feenstra_Inklaar_Timmer_2015"),
    "pwt_rgdpo":              ("PWT 10.01","rgdpo","million 2017 USD (output-side)","1950-2019","Feenstra_Inklaar_Timmer_2015"),
    "pwt_pop":                ("PWT 10.01","pop","million persons","1950-2019","Feenstra_Inklaar_Timmer_2015"),
    "pwt_emp":                ("PWT 10.01","emp","million persons engaged","1950-2019","Feenstra_Inklaar_Timmer_2015"),
    "pwt_avh":                ("PWT 10.01","avh","average annual hours worked per worker","1950-2019","Feenstra_Inklaar_Timmer_2015"),
    "pwt_hc":                 ("PWT 10.01","hc","human capital index (Barro-Lee/Mincerian)","1950-2019","Feenstra_Inklaar_Timmer_2015"),
    "pwt_ck":                 ("PWT 10.01","ck","capital services (index, 2017=1)","1950-2019","Feenstra_Inklaar_Timmer_2015"),
    "pwt_ctfp":               ("PWT 10.01","ctfp","TFP at current PPPs (index, USA=1)","1950-2019","Feenstra_Inklaar_Timmer_2015"),
    "pwt_cwtfp":              ("PWT 10.01","cwtfp","welfare-relevant TFP (index, USA=1)","1950-2019","Feenstra_Inklaar_Timmer_2015"),
    "pwt_labsh":              ("PWT 10.01","labsh","labour share of GDP","1950-2019","Feenstra_Inklaar_Timmer_2015"),
    "pwt_delta":              ("PWT 10.01","delta","capital depreciation rate","1950-2019","Feenstra_Inklaar_Timmer_2015"),
    "pwt_xr":                 ("PWT 10.01","xr","exchange rate (LCU/USD)","1950-2019","Feenstra_Inklaar_Timmer_2015"),
    "pwt_pl_gdpo":            ("PWT 10.01","pl_gdpo","price level of output-side GDP","1950-2019","Feenstra_Inklaar_Timmer_2015"),
    # IMF WEO
    "imf_gdp_growth":         ("IMF WEO","NGDP_RPCH","% annual real GDP growth","1990-2024","IMF_WEO_2024"),
    "imf_inflation":          ("IMF WEO","PCPIPCH","% CPI change","1990-2024","IMF_WEO_2024"),
    "imf_ca_gdp":             ("IMF WEO","BCA_NGDPD","current account % GDP","1990-2024","IMF_WEO_2024"),
    "imf_fiscal_balance":     ("IMF WEO","GGXCNL_NGDP","net lending/borrowing % GDP","1990-2024","IMF_WEO_2024"),
    "imf_ppp_gdp_pc":         ("IMF WEO","PPPPC","GDP per capita PPP (current intl $)","1990-2024","IMF_WEO_2024"),
    "imf_govt_debt_gdp":      ("IMF WEO","GGXWDG_NGDP","gross govt debt % GDP","1990-2024","IMF_WEO_2024"),
    "imf_unemp_rate":         ("IMF WEO","LUR","unemployment rate %","1990-2024","IMF_WEO_2024"),
    # GPR
    "gpr":                    ("GPR","GPR","global geopolitical risk index (Caldara-Iacoviello)","1985-2024","Caldara_Iacoviello_2022"),
    "gprt":                   ("GPR","GPRT","geopolitical threats index","1985-2024","Caldara_Iacoviello_2022"),
    "gpra":                   ("GPR","GPRA","geopolitical acts index","1985-2024","Caldara_Iacoviello_2022"),
    "gprh":                   ("GPR","GPRH","historical GPR index","1985-2024","Caldara_Iacoviello_2022"),
    # FRED
    "fred_wti_usd":           ("FRED","DCOILWTICO","WTI crude oil price (USD/bbl)","1986-2024","FRED_StLouisFed"),
    "fred_brent_usd":         ("FRED","DCOILBRENTEU","Brent crude oil price (USD/bbl)","1987-2024","FRED_StLouisFed"),
    "fred_energy_price_idx":  ("FRED","PNRGINDEXM","energy commodity price index","1990-2024","FRED_StLouisFed"),
    "fred_gold_usd":          ("FRED","GOLDAMGBD228NLBM","gold price (USD/troy oz)","1968-2024","FRED_StLouisFed"),
    "fred_us_ffr":            ("FRED","FEDFUNDS","US federal funds rate %","1954-2024","FRED_StLouisFed"),
    "fred_us_10yr":           ("FRED","GS10","10-year US Treasury yield %","1953-2024","FRED_StLouisFed"),
    "fred_eurusd":            ("FRED","DEXUSEU","USD per EUR","1999-2024","FRED_StLouisFed"),
    "fred_global_epu":        ("FRED","GEPUCURRENT","Global Economic Policy Uncertainty (Baker et al.)","1997-2024","Baker_Bloom_Davis_2016"),
    "fred_us_epu":            ("FRED","USEPUINDXD","US Economic Policy Uncertainty","1985-2024","Baker_Bloom_Davis_2016"),
    "fred_us_cpi":            ("FRED","CPIAUCSL","US CPI (1982-84=100)","1947-2024","FRED_StLouisFed"),
    # FAOSTAT
    "fao_meat_prod_mt":       ("FAOSTAT","Meat, Total / Production","1000 tonnes","1990-2022","FAO_FAOSTAT_2024"),
    "fao_milk_prod_mt":       ("FAOSTAT","Milk, Total / Production","1000 tonnes","1990-2022","FAO_FAOSTAT_2024"),
    "fao_rice_prod_mt":       ("FAOSTAT","Rice / Production","1000 tonnes","1990-2022","FAO_FAOSTAT_2024"),
    "fao_wheat_prod_mt":      ("FAOSTAT","Wheat / Production","1000 tonnes","1990-2022","FAO_FAOSTAT_2024"),
    "fao_roots_prod_mt":      ("FAOSTAT","Roots and Tubers, Total / Production","1000 tonnes","1990-2022","FAO_FAOSTAT_2024"),
    "fao_sugarcane_prod_mt":  ("FAOSTAT","Sugar cane / Production","1000 tonnes","1990-2022","FAO_FAOSTAT_2024"),
    # ILO
    "ilo_unemp_rate":         ("ILO ILOSTAT","UNE_DEAP_SEX_AGE_RT_A","unemployment rate % (ILO modelled)","1990-2024","ILO_ILOSTAT_2024"),
    "ilo_lfpr":               ("ILO ILOSTAT","EAP_DWAP_SEX_AGE_RT_A","labour force participation rate % (15+)","1990-2024","ILO_ILOSTAT_2024"),
    "ilo_emp_pop_ratio":      ("ILO ILOSTAT","EMP_DWAP_SEX_AGE_RT_A","employment-to-population ratio % (15+)","1990-2024","ILO_ILOSTAT_2024"),
    "ilo_avg_hours_worked":   ("ILO ILOSTAT","HOW_TEMP_SEX_AGE_ECO_NB_A","mean weekly hours worked (total economy)","1990-2023","ILO_ILOSTAT_2024"),
}

print("Building codebook...")
# Load one panel to get full col list
df_sample = pd.read_csv("panel_oecd35_20260427.csv", nrows=2)
all_cols = [c for c in df_sample.columns if c not in ["iso3","year","source"]]

codebook_rows = []
for col in all_cols:
    if col in CODEBOOK:
        src, orig_code, units, coverage, cite = CODEBOOK[col]
    elif col.startswith("gpr_"):
        country = col.replace("gpr_","").upper()
        src, orig_code, units, coverage, cite = (
            "GPR", f"GPR_{country}", f"country-specific GPR ({country})",
            "1985-2024", "Caldara_Iacoviello_2022"
        )
    elif col.startswith("fred_"):
        src, orig_code, units, coverage, cite = "FRED", col, "see FRED", "var", "FRED_StLouisFed"
    elif col.startswith("owid_"):
        src, orig_code, units, coverage, cite = "OWID", col, "see OWID", "1990-2022", "Ritchie_Rosado_Roser_2024"
    elif col.startswith("pwt_"):
        src, orig_code, units, coverage, cite = "PWT 10.01", col, "see PWT codebook", "1950-2019", "Feenstra_Inklaar_Timmer_2015"
    elif col.startswith("imf_"):
        src, orig_code, units, coverage, cite = "IMF WEO", col, "see IMF WEO", "1990-2024", "IMF_WEO_2024"
    elif col.startswith("fao_"):
        src, orig_code, units, coverage, cite = "FAOSTAT", col, "1000 tonnes", "1990-2022", "FAO_FAOSTAT_2024"
    elif col.startswith("ilo_"):
        src, orig_code, units, coverage, cite = "ILO ILOSTAT", col, "see ILO", "1990-2024", "ILO_ILOSTAT_2024"
    elif col.startswith("wgi_"):
        src, orig_code, units, coverage, cite = "WB WGI", col, "estimate -2.5 to +2.5", "1996-2023", "Kaufmann_Kraay_2024"
    elif col.startswith("hci_"):
        src, orig_code, units, coverage, cite = "WB HCI", col, "see HCI codebook", "2010-2020", "WorldBank_HCI_2020"
    else:
        src, orig_code, units, coverage, cite = "WB WDI", col, "see WDI codebook", "1990-2024", "WorldBank_WDI_2024"

    codebook_rows.append({
        "variable": col,
        "source": src,
        "original_code": orig_code,
        "units": units,
        "coverage_years": coverage,
        "citation_key": cite,
    })

df_codebook = pd.DataFrame(codebook_rows)
codebook_path = os.path.join(OUT_DIR, f"codebook_panel_20260427.csv")
df_codebook.to_csv(codebook_path, index=False)
print(f"✅ Codebook: {len(df_codebook)} variables → {codebook_path}")

# ─── Summary statistics per group ────────────────────────────────────────────
print("\nBuilding summary statistics...")

# Key variables for stats (skip GPR country-specific — too many)
STAT_VARS = [c for c in all_cols if not c.startswith("gpr_") and not c.startswith("fred_")]

for grp_name in GROUPS:
    panel_path = sorted(glob.glob(f"panel_{grp_name.lower()}_*.csv"))
    if not panel_path:
        continue
    df = pd.read_csv(panel_path[-1])
    stat_cols = [c for c in STAT_VARS if c in df.columns]

    stats = df[stat_cols].describe(percentiles=[.25,.50,.75]).T
    stats.index.name = "variable"
    stats = stats.reset_index()
    # Add source info
    stats = pd.merge(stats, df_codebook[["variable","source","units","coverage_years"]],
                     on="variable", how="left")
    # Add missingness — align by variable name
    miss_series = df[stat_cols].isna().mean() * 100
    miss_series.index.name = "variable"
    miss_df = miss_series.reset_index().rename(columns={0: "pct_missing"})
    stats = pd.merge(stats, miss_df, on="variable", how="left")
    stats["pct_missing"] = stats["pct_missing"].round(1)

    out_path = os.path.join(OUT_DIR, f"summary_stats_{grp_name.lower()}_20260427.csv")
    stats.to_csv(out_path, index=False)
    print(f"  ✅ {grp_name}: {len(stats)} vars → {out_path}")

# ─── Missingness report ───────────────────────────────────────────────────────
print("\nBuilding missingness report...")
miss_rows = []
for grp_name in GROUPS:
    panel_path = sorted(glob.glob(f"panel_{grp_name.lower()}_*.csv"))
    if not panel_path:
        continue
    df = pd.read_csv(panel_path[-1])
    for col in STAT_VARS:
        if col not in df.columns:
            miss_rows.append({"group": grp_name, "variable": col, "pct_available": 0.0,
                              "n_obs": 0, "n_total": len(df)})
        else:
            n_avail = df[col].notna().sum()
            miss_rows.append({
                "group": grp_name,
                "variable": col,
                "pct_available": round(n_avail/len(df)*100, 1),
                "n_obs": n_avail,
                "n_total": len(df)
            })

df_miss = pd.DataFrame(miss_rows)
df_miss_wide = df_miss.pivot(index="variable", columns="group", values="pct_available").reset_index()
df_miss_wide = pd.merge(df_miss_wide, df_codebook[["variable","source"]], on="variable", how="left")
df_miss_wide = df_miss_wide.sort_values(["source","variable"])
miss_path = os.path.join(OUT_DIR, f"missingness_report_20260427.csv")
df_miss_wide.to_csv(miss_path, index=False)
print(f"✅ Missingness report → {miss_path}")

# ─── Project-Panel Map ────────────────────────────────────────────────────────
print("\nBuilding project-panel map...")

PROJECT_MAP = {
    "EKC_BRICST (Energy Policy)": {
        "panel": "BRICST_MINT",
        "dep_var": "co2_pc_ar5",
        "key_vars": ["gdp_pc_ppp_2017", "gdp_growth", "ren_energy_share", "trade_gdp",
                     "owid_co2_pc", "owid_energy_twh", "owid_ren_share"],
        "note": "v39 ready; cross-check owid_co2_pc vs co2_pc_ar5 (AR5 basis)"
    },
    "PSE_AgTFP_OECD (Food Policy)": {
        "panel": "OECD35",
        "dep_var": "agr_va_gdp",
        "key_vars": ["food_prod_idx", "cereal_yield", "fao_wheat_prod_mt", "fao_meat_prod_mt",
                     "gpr", "fred_wti_usd", "wgi_political_stability"],
        "note": "v06 ready; use FAOSTAT + WDI food vars"
    },
    "Climate_Agri_Turkey_ARDL (JEM)": {
        "panel": "CIVETS",
        "dep_var": "agr_va_gdp",
        "key_vars": ["cereal_yield", "food_prod_idx", "fao_wheat_prod_mt", "co2_pc_ar5",
                     "ren_energy_share", "gdp_pc_ppp_2017"],
        "note": "v17 ready; TUR ISO subset; use co2_pc_ar5 not deprecated EN.ATM.CO2E.PC"
    },
    "GPR_Export_Diversification_Eurasian": {
        "panel": "EURASIAN",
        "dep_var": "trade_gdp",
        "key_vars": ["gpr", "gpr_tur", "gpr_rus", "wgi_political_stability",
                     "gdp_pc_ppp_2017", "fred_energy_price_idx"],
        "note": "null result paper; GPR country cols available for 34 countries"
    },
    "CIVETS_Unemployment": {
        "panel": "CIVETS",
        "dep_var": "ilo_unemp_rate",
        "key_vars": ["gdp_growth", "inflation_cpi", "trade_gdp", "gdp_pc_ppp_2017",
                     "ilo_lfpr", "ilo_emp_pop_ratio", "wgi_gov_effectiveness"],
        "note": "Use ILO not WDI unemployment for consistency (ILO modelled estimate)"
    },
    "Automation_LaborShare_Eurasian": {
        "panel": "EURASIAN",
        "dep_var": "pwt_labsh",
        "key_vars": ["pwt_ctfp", "pwt_hc", "gdp_pc_ppp_2017", "ilo_lfpr",
                     "internet_users", "hitech_exports_pct", "wgi_rule_of_law"],
        "note": "PWT labour share + TFP + ILO LFPR combination"
    },
    "MonPol_Asymmetry_Türkiye": {
        "panel": "CIVETS",
        "dep_var": "inflation_cpi",
        "key_vars": ["imf_inflation", "imf_gdp_growth", "fred_us_ffr", "fred_eurusd",
                     "fred_brent_usd", "gdp_pc_ppp_2017", "dom_credit_gdp"],
        "note": "TUR only; use IMF + FRED for monetary context"
    },
    "CE_Cognitive_Econometrics_EU27": {
        "panel": "EU27",
        "dep_var": "gdp_pc_ppp_2017",
        "key_vars": ["rnd_exp_gdp", "hitech_exports_pct", "educ_exp_gdp", "hci_overall",
                     "internet_users", "broadband_subs", "wgi_gov_effectiveness",
                     "pwt_ctfp", "pwt_labsh"],
        "note": "5 models; DML-PLR needs good instruments; consider pwt_hc as IV"
    },
    "Food_Regime_Decoupling (JCP)": {
        "panel": "OECD35",
        "dep_var": "co2_pc_ar5",
        "key_vars": ["food_prod_idx", "fao_meat_prod_mt", "fao_wheat_prod_mt",
                     "owid_co2_mt", "agr_va_gdp", "gdp_pc_ppp_2017", "trade_gdp"],
        "note": "v02 ready; FAOSTAT + OWID CO2 + WDI agri vars now available"
    },
    "Chokepoints_Maritime (TRE)": {
        "panel": "OECD35",
        "dep_var": "trade_gdp",
        "key_vars": ["gpr", "gprt", "fred_brent_usd", "fred_energy_price_idx",
                     "fdi_gdp", "current_account_gdp", "imf_ca_gdp"],
        "note": "v08 ready; GPR threats index (gprt) = key chokepoint proxy"
    },
    "SSA_ML_Food_Security": {
        "panel": "BRICST_MINT",
        "dep_var": "undernourishment",
        "key_vars": ["food_prod_idx", "cereal_yield", "fao_wheat_prod_mt", "fao_meat_prod_mt",
                     "gdp_pc_ppp_2017", "wgi_political_stability", "ilo_unemp_rate",
                     "fred_food_comm_idx"],
        "note": "v06 BFJ ready; use FAOSTAT + WDI food security vars"
    },
    "Stagflation_ML (IJF)": {
        "panel": "OECD35",
        "dep_var": "inflation_cpi",
        "key_vars": ["gdp_growth", "unemp_rate", "fred_us_ffr", "fred_global_epu",
                     "fred_energy_price_idx", "gpr", "imf_inflation"],
        "note": "RF+SHAP; EPU + GPR + energy price as key features"
    },
}

# Check variable availability for each project
map_rows = []
for proj_name, info in PROJECT_MAP.items():
    grp = info["panel"]
    panel_path = sorted(glob.glob(f"panel_{grp.lower()}_*.csv"))
    if not panel_path:
        continue
    df_p = pd.read_csv(panel_path[-1])
    avail = []
    missing_vars = []
    for v in info["key_vars"]:
        if v in df_p.columns:
            cov = df_p[v].notna().mean() * 100
            avail.append(f"{v} ({cov:.0f}%)")
        else:
            missing_vars.append(v)

    map_rows.append({
        "project": proj_name,
        "panel": grp,
        "dep_var": info["dep_var"],
        "dep_var_available": "✅" if info["dep_var"] in df_p.columns else "❌",
        "key_vars_available": len(avail),
        "key_vars_total": len(info["key_vars"]),
        "missing_vars": ", ".join(missing_vars) if missing_vars else "none",
        "note": info["note"],
    })

df_map = pd.DataFrame(map_rows)
map_path = os.path.join(OUT_DIR, f"project_panel_map_20260427.csv")
df_map.to_csv(map_path, index=False)

# Print summary
print("\n" + "="*70)
print("PROJECT-PANEL VARIABLE AVAILABILITY")
print("="*70)
for _, row in df_map.iterrows():
    status = "✅" if row["missing_vars"] == "none" else "⚠️"
    print(f"{status} {row['project'][:45]:<45} | {row['panel']:<12} | "
          f"{row['key_vars_available']}/{row['key_vars_total']} vars | "
          f"DV: {row['dep_var_available']}")
    if row["missing_vars"] != "none":
        print(f"   Missing: {row['missing_vars']}")

# Final summary
print("\n" + "="*60)
print("BUILD COMPLETE")
print("="*60)
for grp in GROUPS:
    panel_path = sorted(glob.glob(f"panel_{grp.lower()}_*.csv"))
    if panel_path:
        df = pd.read_csv(panel_path[-1])
        print(f"  {grp:<12}: {len(df)} rows × {len(df.columns)} cols | "
              f"{df.iloc[:,2:].notna().mean().mean()*100:.1f}% complete")
print(f"\nOutputs:")
print(f"  {codebook_path}")
print(f"  summary_stats_{{group}}_20260427.csv  (5 files)")
print(f"  {miss_path}")
print(f"  {map_path}")
