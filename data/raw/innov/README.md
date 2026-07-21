# Insumos raw de INNOV

`world_bank_wdi/innov_wdi_inputs_1980_2022.csv` y su archivo idéntico para
Stata contienen los insumos sin transformar del canal de innovación:

- `scientific_articles`: artículos científicos y técnicos (`IP.JRN.ARTC.SC`),
  numerador de la medida principal;
- `population_total`: población utilizada para expresar los artículos por
  millón de habitantes;
- `resident_patents`: solicitudes de patentes de residentes (`IP.PAT.RESD`),
  conservadas para robustez;
- `rd_expenditure_pct_gdp`: gasto en investigación y desarrollo, conservado
  como alternativa no prioritaria por su cobertura limitada.

Los archivos raw contienen solamente valores publicados por la fuente. Las
tasas por millón y `log(1 + x)` se calcularán posteriormente en
`data/processed/innov/`.

La serie principal cubre las 1.485 observaciones de la muestra DRES de 55 países
durante 1996-2022. `innov_raw_coverage_dres20.csv` documenta la cobertura de la
medida principal y sus alternativas.

El script reproducible es
[`scripts/data/innov/innov_wdi_data.R`](../../../scripts/data/innov/innov_wdi_data.R).
