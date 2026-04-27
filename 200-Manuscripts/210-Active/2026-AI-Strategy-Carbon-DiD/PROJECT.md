# AI Strategy & Carbon — Staggered DiD
## Objective
Identify causal effect of national AI strategy adoption on CO2 emissions and renewable energy.
## Data
40 countries, 2005-2023; staggered treatment timing (2017-2021); N=125, T=19.
## Methodology
1. Staggered TWFE + Callaway-Sant'Anna CS-ATT
2. Event study parameterization (e=-2 to +4)
3. Goodman-Bacon decomposition (COVID-19 bias control)
## Output
Q1 (policy causal effects); 12-page PDF clean render; full R replication scripts.
## Status
Stage 6: v0.2 complete; v0.3 in progress.

## Responsible AI Framing (literature/contribution — eklenecek)
- Strubell et al. (2019) "Energy and Policy Considerations for Deep Learning in NLP" — AI'ın enerji tüketimi; ICML 2019. DOI: 10.18653/v1/P19-1355
- Rebound effect: AI verimlilik kazancı → Jevons paradoxu (DATAMACLEA paper'da işlendi; cross-cite)
- Fairness + auditability: ulusal AI strateji governance → policy bölümüne ekle
- Framing: "AI adoption reduces emissions" iddiası → **causal identification** olmadan yazma; DiD = causal design, bu avantajı vurgula
