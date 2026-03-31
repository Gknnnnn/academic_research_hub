# PMG Panel ARDL

Method family:

- panel-data

Plain language:

- panel birimlerde kısa dönem katsayılarını heterojen, uzun dönem katsayılarını homojen kabul eden dinamik model

Equation:

```latex
\Delta y_{it} = \phi_i \left(y_{i,t-1} - \theta x_{i,t-1}\right) + \sum_{j=1}^{p-1} \lambda_{ij} \Delta y_{i,t-j} + \sum_{j=0}^{q-1} \delta_{ij} \Delta x_{i,t-j} + \mu_i + \varepsilon_{it}
```

Wolfram Alpha query:

- rearrange panel error correction model

Linked method map:

- `100-Literature/150-Method-Maps/PMG.md`
