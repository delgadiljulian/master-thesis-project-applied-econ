# Insumo raw de LOG_GDPPC

`world_bank_wdi/gdppc_ppp_constant_wdi_input_1980_2022.csv` y su archivo
equivalente para Stata contienen el PIB per cápita en términos de paridad de
poder adquisitivo y dólares internacionales constantes
(`NY.GDP.PCAP.PP.KD`).

La capa raw conserva el nivel positivo publicado por los World Development
Indicators. No calcula el logaritmo, no interpola y no imputa valores
faltantes. `LOG_GDPPC` se construye exclusivamente en `data/processed/gdppc/`.

El indicador anterior `NY.GDP.PCAP.KD` no se utiliza como insumo oficial
porque está expresado en dólares constantes sin ajuste por PPA. Los antiguos
archivos que además aplicaban el logaritmo dentro de raw fueron retirados del
flujo.

`world_bank_wdi/gdppc_raw_coverage_summary_dres20.csv` resume la cobertura para
los 55 países de la muestra DRES durante 1996-2022, mientras que
`world_bank_wdi/gdppc_raw_country_coverage_dres20.csv` identifica los años
faltantes por país.

La serie cubre 1.431 de las 1.485 celdas país-año (96,4 %). Los 53 países con
datos presentan series completas; Venezuela y Yemen no tienen observaciones
del indicador durante 1996-2022. Estas ausencias se conservan sin sustitución.

El script reproducible es
[`scripts/data/raw/gdppc/gdppc_wdi_raw.R`](../../../scripts/data/raw/gdppc/gdppc_wdi_raw.R).

La construcción definitiva y sus diagnósticos están documentados en
[`data/processed/gdppc/`](../../processed/gdppc/).
