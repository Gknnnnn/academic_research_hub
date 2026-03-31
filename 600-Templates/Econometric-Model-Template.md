---
type: econometric-specification
status: draft
date-created: {{date:YYYY-MM-DD}}
---
# {{model-name}}
## Specification
$$CO_{2,it} = \alpha_i + \beta_1 Y_{it} + \beta_2 Y_{it}^2 + \epsilon_{it}$$
## R Implementation
```r
library(plm)
# model_fe <- plm(data, model="within")
