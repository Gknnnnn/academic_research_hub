# Toda-Yamamoto Causality

Method family:

- time-series

Plain language:

- optimal VAR gecikmesine maksimum bütünleşme derecesi kadar ek gecikme ekleyerek Wald testi üzerinden nedensellik sınar

Equation:

```latex
Y_t = c + A_1 Y_{t-1} + \cdots + A_k Y_{t-k} + A_{k+1} Y_{t-k-1} + \cdots + A_{k+d_{max}} Y_{t-k-d_{max}} + \varepsilon_t
```

Wolfram Alpha query:

- expand vector autoregression lag structure

Linked method map:

- `100-Literature/150-Method-Maps/Toda-Yamamoto.md`
