# OSF Preregistration Templates — MGO
_Created: 2026-04-26 | Purpose: timestamped priority for unpublished research ideas_

**OSF URL:** https://osf.io/register  
**Login:** ORCID 0000-0002-6756-7285  
**Registration type:** OSF Preregistration (standard)  
**Embargo:** YES — set to maximum (4 years = until 2030-04-26) → extend or release early when paper submits

---

## PREREGISTRATION 1 — PE01: AIIB Institutional Isomorphism

**Title:**
```
Coercive Isomorphism or Strategic Adaptation? AIIB Institutional Convergence with 
World Bank Safeguard Standards: A Comparative Project-Level Analysis
```

**Research questions:**
```
1. Do AIIB infrastructure projects exhibit systematic convergence with World Bank 
   environmental and social safeguard standards (coercive isomorphism), or do they 
   maintain distinct "Chinese" governance patterns?
2. Does co-financing with MDBs accelerate isomorphic convergence?
3. Is convergence heterogeneous across project type (transport, energy, urban)?
```

**Hypotheses:**
```
H1: AIIB projects co-financed with World Bank will show higher environmental safeguard 
    compliance scores than AIIB-solo projects (coercive isomorphism).
H2: AIIB compliance scores have increased over time (2016–2024), reflecting normative 
    isomorphism via hiring of Western-trained staff.
H3: The convergence rate is higher for projects in OECD-member borrower countries 
    than non-OECD borrowers (mimetic isomorphism driven by reputational pressure).
```

**Data sources:**
```
- AIIB project database (public): aiib.org/en/projects/list/
- World Bank projects database: projects.worldbank.org
- AIIB Environmental and Social Framework (2016, 2021 revisions)
- Wang (2025) AIIB project dataset (public replication data)
- BIS cross-border claims (for financial integration controls)
```

**Methodology:**
```
- Matching estimator: Propensity Score Matching (AIIB-solo vs. AIIB-WB co-finance)
- DiD: Pre-post AIIB policy reform (2021 ESF revision)
- Dependent variable: Safeguard compliance index (constructed from project documents)
- Robustness: Entropy balancing; synthetic control (small N)
```

**Theoretical framework:**
```
DiMaggio & Powell (1983) institutional isomorphism:
- Coercive: MDB co-financing imposes WB standards on AIIB
- Normative: Staff professionalization → internalized standards
- Mimetic: Reputational mimicry in OECD-linked projects
```

**Target journal:** Review of International Political Economy (RIPE, SSCI Q1, IF 5.2)  
**Estimated submission:** 2026-11  
**Embargo end:** Release when submitted to RIPE

---

## PREREGISTRATION 2 — PE02: Basel IV Access Risk Gap

**Title:**
```
Regulatory Asymmetry and Financial Exclusion: How Basel IV Capital Requirements 
Create a Systematic Access-Risk Gap for Developing Economy Borrowers
```

**Research questions:**
```
1. Does Basel IV's standardized approach (SA) generate systematically higher 
   risk weights for sovereign and corporate exposures from developing economies 
   compared to OECD economies, conditional on actual default rates?
2. Does the capital requirement differential translate into measurable credit 
   rationing for developing-country borrowers in international syndicated lending?
3. Is the access-risk gap amplified for economies outside major credit rating coverage?
```

**Hypotheses:**
```
H1: Basel IV SA risk weights for developing-economy sovereigns exceed those implied 
    by historical default rates (regulatory overpricing).
H2: Syndicated loan spreads for developing-economy borrowers increased more than 
    OECD-borrower spreads following Basel IV adoption announcements (2017–2023).
H3: The overpricing is largest for countries with no ECAI rating (unrated sovereign exposure).
```

**Data sources:**
```
- BIS Consolidated Banking Statistics (CBS): stats.bis.org
- Dealogic Syndicated Loans database (access via library or co-author)
- IMF Sovereign default database (Beers & Maier, 2023)
- Basel Committee supervisory data (BCBS QIS)
- ECAI rating coverage: Moody's, S&P, Fitch sovereign ratings
```

**Methodology:**
```
- Regression discontinuity: rating threshold crossings (BBB-/Baa3)
- Event study: Basel IV announcement dates (BCBS 2017, 2023 final rules)
- Panel IV: ECAI coverage as instrument for effective risk weight
- Sample: 80+ countries, 2010–2024
```

**Theoretical framework:**
```
Strange (1988) structural power: Basel standards as exercise of structural power 
by financial incumbents. Cipriani et al. (2023 JEP) financial fragmentation mechanism.
```

**Target journal:** Review of International Political Economy (RIPE, SSCI Q1)  
**Estimated submission:** 2027-01  
**Embargo end:** Release when submitted to RIPE

---

## OSF Registration Steps

```
1. Go to osf.io → Log in → "+ New" → "Registration"
2. Click "New registration" on relevant project (or create new project first)
3. Select registration type: "OSF Preregistration"
4. Fill in: Title, Research questions, Hypotheses, Data, Analysis plan
5. IMPORTANT: Select "Embargo" → set to 4 years (2030-04-26)
6. Submit registration
7. Copy registration DOI → save in PROJECT.md
8. To release early: osf.io → Registrations → End embargo
```

**Embargo strategy:**
- PE01 AIIB: Release embargo when RIPE submission confirmed (expected Oct–Nov 2026)
- PE02 Basel IV: Release embargo when RIPE submission confirmed (expected Dec 2026–Jan 2027)
- This gives full priority protection while you collect data and write the paper

---

## Quick Reference: CC License by Output Type

| Output | License | Where to deposit |
|--------|---------|-----------------|
| Working paper / preprint | CC BY 4.0 | Zenodo + SSRN/EconStor |
| Research ideas (pre-writing) | OSF embargo (no license yet) | OSF preregistration |
| Data sets | CC BY 4.0 or CC0 | Zenodo (separate deposit) |
| R/Python code | MIT License | GitHub (already set up) |
| Policy analysis (ANKASAM) | CC BY-NC-ND 4.0 | Zenodo or own website |
| Unpublished drafts | CC BY-NC-ND 4.0 + embargo | OSF private |
