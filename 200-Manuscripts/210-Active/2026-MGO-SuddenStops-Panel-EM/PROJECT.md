# PROJECT: Sudden Stops in Capital Flows — Panel Econometrics

**Status:** Idea/Design Phase  
**Created:** 2026-04-28  
**Author:** Res. Asst. Dr. M. Gökhan Özdemir  
**ORCID:** 0000-0002-6756-7285

---

## 1. Research Question (1 line)

What global and domestic determinants drive the probability of sudden stops in gross capital inflows, and do macroprudential policies and exchange rate regimes modify this risk in a heterogeneous panel of emerging and developing economies?

---

## 2. Motivation & Research Gap

**What is known:**
- Calvo (1998) established the sudden stop concept; Calvo, Izquierdo & Mejia (2004) provided the first panel probit evidence using 32 countries.
- Forbes & Warnock (2012) standardized episode identification using quarterly gross flow data (±1 SD / ±2 SD rule over rolling 5-year windows).
- Eichengreen & Gupta (2016 WB WP 7639) updated to post-2002 data with probit/logit/cloglog.
- Du & Pu (2025, IJFE 30:352-368) use two-way FE panel logit on 71 EMEs 1998Q1-2022Q4.
- Business Perspectives (2025): Panel probit, 64 countries, 1980-2024; VIX +1pt → +0.39pp SS probability.

**Critical gap (MGO novelty):**
1. **Cross-sectional dependence (CSD) not addressed** in existing panel probit work — all papers use standard clustered SE without testing for global factor contamination. With financial globalization, CSD is near-certain in capital flow panels.
2. **Eurasian/CIS economies excluded** from most samples (Brazil, Chile, Korea, Poland dominate).
3. **Asymmetric push-pull decomposition**: sudden stops may respond differently to VIX rises vs. falls (NARDL logic) — untested in any panel setting.
4. **Macroprudential × credit interaction** only tested in one paper (Business Perspectives 2025); not explored for Eurasian or transition economies.
5. **Sudden stops → CA adjustment speed**: how fast does the current account correct after an episode? (Connects to MGO's CA-NARDL expertise.)

---

## 3. Proposed Methodology

### 3.1 Episode Identification
Follow **Forbes & Warnock (2012)** quarterly gross flow methodology:
- Episode = year-on-year change in gross inflows ≥ 1 SD below rolling 5-year mean AND ≥ 1 quarter at ≥ 2 SD below mean.
- Binary dependent variable: `SS_it ∈ {0, 1}`

### 3.2 Baseline Estimation: Panel Probit / Logit
```
Pr(SS_it = 1) = Φ(α + β_G G_t + β_D D_it + β_M MPP_it + γ_i + ε_it)
```
Where:
- `G_t` = global push factors: VIX, US FFR, global growth, global uncertainty (GPR)
- `D_it` = domestic pull factors: CAD/GDP, credit growth, reserves/GDP, REER misalignment, institutional quality
- `MPP_it` = macroprudential tightening index (IMF iMaPP database)
- `γ_i` = country FE (or random effects if Hausman permits)

**SE correction:** Driscoll-Kraay or Pesaran-type CSD-robust SE.

### 3.3 Pre-estimation Tests
| Test | Tool | Purpose |
|------|------|---------|
| Pesaran CD | `plm::pcdtest` (R) | CSD detection |
| Pesaran-Yamagata Δ | `pdynmc` / manual | Slope homogeneity |
| CIPS / CADF | `CADFtest` (R) | Unit root in regressors |
| VIF + Condition number | base R | Multicollinearity |

### 3.4 Heterogeneity Analysis
- Advanced vs. Emerging: structural break in baseline probability (Wald test on group dummy).
- Eurasian subsample (15–20 countries): separate panel probit.
- Exchange rate regime interaction: fixed vs. float (Ilzetzki-Reinhart-Rogoff classification).

### 3.5 Push-Pull Decomposition (NOVELTY)
Decompose SS probability into:
- **Global push** component: variance explained by `G_t` alone
- **Domestic pull** component: residual after partialling out global factors
- Method: Variance decomposition from panel probit margins (AME).

### 3.6 Robustness
- Alternative episode definitions: net vs. gross flows; Calvo-Izquierdo 2-SD threshold.
- Complementary log-log (cloglog) model for rare-events correction.
- Weighted logit (king-Zeng rare events logit).
- Remove GFC (2008-09) and COVID (2020) periods.
- Webb wild cluster bootstrap for N_cluster < 30.

---

## 4. Data Matrix

| Variable | Source | Frequency | Coverage |
|----------|--------|-----------|----------|
| Gross capital inflows (total, FDI, portfolio, other) | IMF BOP/IFS | Quarterly | 1990–2024 |
| VIX | CBOE via FRED | Quarterly | 1990–2024 |
| US Federal Funds Rate | FRED | Quarterly | 1990–2024 |
| GDP growth | WB WDI | Quarterly | 1990–2024 |
| Current account / GDP | WB WDI | Quarterly | 1990–2024 |
| Domestic credit / GDP | WB GFDD | Quarterly | 1990–2024 |
| FX reserves / GDP | WB WDI | Quarterly | 1990–2024 |
| REER | BIS / IFS | Quarterly | 1990–2024 |
| Institutional quality (ICRG/WGI) | WB WGI | Annual | 1996–2024 |
| Macroprudential policy index | IMF iMaPP | Quarterly | 2000–2024 |
| Exchange rate regime | Ilzetzki-RR | Annual | 1990–2021 |
| GPR index | Caldara-Iacoviello (FRED) | Monthly → quarterly | 1985–2024 |

**Target N:** 60–90 countries (advanced + emerging + Eurasian transition)  
**Target T:** 1995Q1–2024Q4 (unbalanced panel)

---

## 5. Expected Contribution & Novelty

1. **First CSD-aware sudden stop panel** — addresses global factor contamination ignored in all existing probit work.
2. **Eurasian representation** — CIS/transition economies in dedicated subsample.
3. **Macroprudential × credit interaction** tested with panel margins at specific quantiles of credit growth.
4. **Push-pull variance decomposition** at average marginal effects level.
5. **Connects to MGO's CA adjustment research** — SS → CA speed-of-adjustment mechanism (extension section).

---

## 6. Target Journals (A-B-C Plan)

| Plan | Journal | IF | SSCI | ÜAK | Fee | Notes |
|------|---------|----|----|-----|-----|-------|
| **A** | *Journal of International Money and Finance* (JIMF) | 4.2 | Q2 | 20pt | $250 non-refundable ⚠️ | Strong fit; FW2012 published here |
| **A-alt** | *International Review of Economics & Finance* (IREF) | 4.8 | Q2 | 20pt | $0 | Emter (2023) published here; excellent fit |
| **B** | *Journal of Policy Modeling* (JPM) | 5.2 | Q2 | 20pt | $0 | Policy relevance; no fee |
| **C** | *Emerging Markets Finance & Trade* (EMFT) | 3.4 | Q2 | 20pt | $0 | Eurasian angle; fast |

**Recommendation:** Start with IREF (no fee, Emter 2023 precedent, IF=4.8, Q2). Avoid JIMF unless paper is exceptional (non-refundable fee).

---

## 7. Closest 10 Papers (Citation Network)

| # | Authors | Year | Journal | Key Contribution | Confidence |
|---|---------|------|---------|-----------------|------------|
| 1 | Calvo, G.A. | 1998 | *Journal of Applied Economics* 1(1):35-54 | Concept definition; self-fulfilling stop mechanism | 0.95 [web] |
| 2 | Calvo, Izquierdo & Mejia | 2004 | NBER WP 10520 | Panel probit; DLD × openness nonlinear interaction | 0.95 [web] |
| 3 | Forbes & Warnock | 2012 | *JIntEcon* 88(2):235-251 | Episode identification methodology; push factors dominant | 0.98 [DOI ✅] |
| 4 | Edwards, S. | 2004 | *AER* 94(2):59-64 | Financial openness → smaller output loss | 0.90 [web] |
| 5 | Eichengreen & Gupta | 2016 | World Bank WP 7639 | Updated probit/logit/cloglog post-2002 | 0.85 [web] |
| 6 | Emter, L. | 2023 | *Int Rev Econ Finance* 84:711-731 | Leverage cycles + growth shocks; 98 countries 1990-2017 | 0.85 [web] |
| 7 | Du & Pu | 2025 | *Int J Finance & Econ* 30(1):352-368 | 2-way FE panel logit; 71 EMEs; US uncertainty → SS ↑ | 0.85 [web] |
| 8 | Wang, Lu & Song | 2025 | *J Int Fin Markets* 99 | SS → bank systemic risk; MPP mitigates; 43 nations | 0.85 [web] |
| 9 | [Business Perspectives] | 2025 | *Invest Manag Fin Innov* | Panel probit 64 ctry 1980-2024; MPP × credit interaction | 0.80 [web] |
| 10 | Çukurova/JEI | 2025 | *J Econ Integration* 40(1):119-143 | 13 EMEs cloglog + SVAR; DOI:10.11130/jei.2024038 | 0.85 [web] |

**DOI STATUS (update as verified):**
- Forbes & Warnock (2012): DOI `10.1016/j.jinteco.2012.03.006` ✅ VERIFIED 2026-04-28 (ScienceDirect + REPEC)
- Emter (2023): IREF 84(C):711-731 published ✅ | DOI [NOT FOUND in search — manual check: doi.org/10.1016/j.iref.2023.XXX]
- Du & Pu (2025): DOI `10.1002/ijfe.2914` [UNVERIFIED — manual check required]
- Wang et al. (2025): JIFMIM vol.99 2025 [DOI NOT FOUND — search journal directly]
- Business Perspectives (2025): [DOI NOT FOUND — search businessperspectives.org]
- JEI (2025): DOI `10.11130/jei.2024038` [source: AVESİS — plausible but verify via doi.org]

---

## 8. JEL Codes
F32 (Current account adjustment; short-term capital movements)  
F41 (Open economy macroeconomics)  
F38 (International financial policy)  
G15 (International financial markets)  
E44 (Financial markets and the macroeconomy)

---

## 9. Timeline

| Milestone | Target |
|-----------|--------|
| Literature review + data collection | 2026-07 |
| Episode identification (Forbes-Warnock code in R) | 2026-08 |
| Baseline panel probit + CSD tests | 2026-09 |
| Robustness battery | 2026-10 |
| First draft (QMD) | 2026-11 |
| Sparring + peer review | 2026-12 |
| Submission (IREF) | 2027-01 |

---

## 10. Connections to MGO Portfolio

- **FinStress-CA-NARDL-Turkey** → SS is the external trigger; CA adjustment speed = extension.
- **Currency Misalignment-CA** → REER misalignment is a key SS determinant in this paper.
- **GPR-Export-Diversification** → GPR index is a push factor; shared data infrastructure.
- **Chronic Inflation Trilemma** → Trilemma indexes (Aizenman-Chinn-Ito) as control variables.
- **Global Panel Data Infrastructure** → 261-var panel already built; BOP data needed.

---

## 11. DAMOKLES Check

- [x] Title: NOT "The Impact of X on Y" — declarative title planned: "Global Uncertainty, Domestic Credit, and Sudden Stops: Panel Evidence from Emerging Economies"
- [x] MGO expertise: panel econometrics + external balance = genuine contribution
- [x] Solo authorship (default)
- [x] Method from research question, not template
- [x] Not MDPI
