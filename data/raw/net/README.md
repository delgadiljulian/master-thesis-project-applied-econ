# Insumo raw de NET

`world_bank_wdi/net_wdi_input_1980_2022.csv` y su archivo equivalente para
Stata contienen el porcentaje de personas que utilizan internet publicado por
los World Development Indicators (`IT.NET.USER.ZS`).

La serie se conserva en su escala porcentual original. La capa raw no aplica
logaritmos, interpolaciones ni imputaciones, y los ceros publicados se
mantienen como valores válidos. La construcción definitiva de `NET` se realiza
en `data/processed/net/`.

`world_bank_wdi/net_raw_coverage_summary_dres20.csv` resume la cobertura para
los 55 países de la muestra DRES durante 1996-2022, mientras que
`world_bank_wdi/net_raw_country_coverage_dres20.csv` identifica los años
faltantes de cada país.

La serie está disponible en 1.431 de las 1.485 celdas país-año (96,4 %). Los
55 países tienen al menos una observación y 40 presentan cobertura completa.
Nauru es el caso más discontinuo, con 7 de 27 años observados. Los demás
faltantes son puntuales y aparecen tanto al comienzo como al final del período;
se conservan exactamente como los publica la fuente.

El script reproducible es
[`scripts/data/raw/net/net_wdi_raw.R`](../../../scripts/data/raw/net/net_wdi_raw.R).

La construcción definitiva y sus diagnósticos están documentados en
[`data/processed/net/`](../../processed/net/).
