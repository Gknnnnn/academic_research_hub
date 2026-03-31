# Panel ARDL – Green Innovation Application

## Method Identity

- Method name: Panel ARDL (PMG)
- JEL link: Q56 / O13
- Typical use case: hybrid panel with short-run heterogeneity and long-run homogeneity in green growth studies

## When To Use

- Cross-sectional units (provinces/sectors) with up to 20 years of annual data  
- Research questions about structural transformation driven by policy shocks

## Core Assumptions

- Each cross-section shares long-run slope (PMG constraint)  
- Short-run coefficients lag-dependent  
- Variables are I(0)/I(1), no I(2)

## Required Inputs

- Panel: provincial GDP, export shares, green energy expenditures  
- Stationarity checks (ADF)  
- Bounds testing for ARDL lag selection

## Canonical Equation

- Reference: `500-Methods/540-Equation-Library/panel-data/PMG-Panel-ARDL.md`

## Common Diagnostics

- Pedroni, Westerlund cointegration tests  
- Hausman test between MG and PMG  
- Error correction term significance

## Typical Output Interpretation

- Negative ECM coefficient → return to long-run equilibrium  
- Short-run coefficients capture immediate policy impact  
- Long-run slope reflects green innovation elasticity

## Strengths

- Balances heterogeneity and efficiency  
- Handles dynamic responses to policy  
- Provides clear short vs long path

## Weaknesses

- Requires panel cointegration  
- Sensitive to lag selection

## Papers Using This Method

- `Green Innovation Structural Transformation` (current project)

## My Use Cases

- Use this note to anchor the project overview in `300-Projects/310-Active-Papers/green-innovation-structural`  
- Link to `500-Methods/540-Equation-Library/panel-data/PMG-Panel-ARDL.md`

## Next Steps

- Fill the template in `600-Templates/Method-Map-Template.md` with explicit lag orders, variables, and diagnostics  
- Tie the ECM coefficient expectation to policy variables in the project overview  
