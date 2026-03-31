# Green Innovation ECM

Method family:

- panel-data / PMG

Plain language:

- models short-term deviations of export intensity from long-term green transformation equilibrium while allowing provinces to differ in short-run responses.

Equation:

```latex
\Delta ExportShare_{it} = \phi_i (ExportShare_{i,t-1} - \theta_1 GreenInvestment_{i,t-1} - \theta_2 StructuralRatio_{i,t-1}) + \sum_{j=1}^{p-1} \lambda_{ij} \Delta ExportShare_{i,t-j} + \sum_{j=0}^{q-1} \delta_{ij} \Delta GreenInvestment_{i,t-j} + \mu_i + \varepsilon_{it}
```

Symbol Dictionary:

- \(ExportShare_{it}\): ihracat yoğunluğu  
- \(GreenInvestment_{i,t-1}\): yeşil yatırım üçlemeleri  
- \(StructuralRatio_{i,t-1}\): yapısal dönüşüm oranı  
- \(i\): il/provanya  
- \(t\): zaman  

Variants:

- Log form: use ln(ExportShare) if heteroskedastic  
- Interaction: include \(GreenInvestment_{it} \times InstitutionalIndex_{it}\)  
- Nonlinear form: allow regime switching by sustainability threshold  

Estimation Notes:

- Use PMG estimator via `plm::pmg()` or `pmd` package  
- Pre-tests: unit root (ADF), cointegration (Pedroni)  
- Diagnostics: ECM coefficient significance, Hausman test

Wolfram Alpha query:

- solve `Δy = λ(y - θx) + ...` for long-run θ given ECM coefficient  

Reuse Notes:

- Project: `300-Projects/310-Active-Papers/green-innovation-structural`  
- Link back to `100-Literature/150-Method-Maps/Panel-ARDL-Green-Innovation.md`  
