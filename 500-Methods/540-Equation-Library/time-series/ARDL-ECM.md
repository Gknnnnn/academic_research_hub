# ARDL-ECM

Method family:

- time-series

Plain language:

- bağımlı değişkenin kısa dönem değişimini, gecikmeli fark terimleri ve uzun dönem denge sapması üzerinden açıklar

Equation:

```latex
\Delta y_t = \alpha + \sum_{i=1}^{p} \beta_i \Delta y_{t-i} + \sum_{j=0}^{q} \gamma_j \Delta x_{t-j} + \lambda \left(y_{t-1} - \theta x_{t-1}\right) + \varepsilon_t
```

Wolfram Alpha query:

- solve error correction form for long-run equilibrium

Linked method map:

- `100-Literature/150-Method-Maps/ARDL.md`
