# Insumos raw de INNOV

`world_bank_wdi/innov_wdi_input_1980_2022.csv` y su archivo equivalente para
Stata contienen los insumos sin transformar del canal de innovación:

- `scientific_articles`: artículos científicos y técnicos (`IP.JRN.ARTC.SC`),
  numerador de la medida;
- `population_total`: población utilizada para expresar los artículos por
  millón de habitantes.

Los archivos raw contienen solamente valores publicados por la fuente. Las
tasas por millón y `log(1 + x)` se calculan exclusivamente en
`data/processed/innov/`.

Esta es la única definición activa de `INNOV`. Sus insumos cubren las 1.485
observaciones de la muestra DRES de 55 países durante 1996-2022.
`innov_raw_coverage_summary_dres20.csv` e
`innov_raw_country_coverage_dres20.csv` documentan la cobertura.

El script reproducible es
[`scripts/data/raw/innov/innov_wdi_raw.py`](../../../scripts/data/raw/innov/innov_wdi_raw.py).

La construcción definitiva y sus diagnósticos están documentados en
[`data/processed/innov/`](../../processed/innov/).
