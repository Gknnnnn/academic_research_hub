# Data Preview

Obsidian içinde CSV görüntülemek için `CSV Table` veya `Dataview` eklentisi kullan. Aşağıdaki `Dataview` bloğu, `400-Data/420-WorldBank/turkiye_makro_data.csv` içinden beş satır sunar.

```dataview
table year, gdp_usd, co2_kt, elec_kwh_pc, urban_pct
from "400-Data/420-WorldBank"
limit 5
```

Bu notu açtığında eklenti tabloyu otomatik render eder; eklentiyi eklemediysen `Community plugins` → `Browse` → "Dataview" veya "CSV Table" yükle ve etkinleştir. 

Ek olarak, CSV’yi doğrudan açmak istersen yol:

`[[400-Data/420-WorldBank/turkiye_makro_data.csv]]`

Son veri kalite raporu: `[[900-Dashboard/data_quality_log.md#turkiye_makro_data.csv]]`
