# Insumo raw de GOVCONS

`world_bank_wdi/govcons_wdi_input_1980_2022.csv` y su archivo equivalente para
Stata contienen el gasto de consumo final del gobierno general como porcentaje
del PIB publicado por los World Development Indicators
(`NE.CON.GOVT.ZS`).

La variable se utilizará como control del tamaño relativo del consumo público.
No mide la capacidad fiscal, la presión tributaria, el balance presupuestario ni
la prociclicidad de la política fiscal. La serie se conserva en la escala
original de la fuente: la capa raw no aplica logaritmos, interpolaciones,
imputaciones ni recortes.

`world_bank_wdi/govcons_raw_coverage_summary_dres20.csv` resume la cobertura y
el rango para los 55 países de la muestra DRES durante 1996-2022.
`world_bank_wdi/govcons_raw_country_coverage_dres20.csv` identifica los años
faltantes y el rango observado de cada país.

La serie está disponible en 1.211 de las 1.485 celdas país-año (81,5 %).
Cuarenta y nueve países tienen al menos una observación y 40 presentan
cobertura completa. Antigua y Barbuda, Jamaica, Liberia, Nigeria, Nauru y
Trinidad y Tobago no tienen observaciones durante 1996-2022.

WDI publica 16 valores iguales a cero para Venezuela entre 1996 y 2011. El
archivo fuente original confirma que no fueron creados por el script. Se
conservan sin modificación en raw. En processed se marcan como faltantes porque
forman una secuencia incompatible con el dominio económico del indicador; no
se sustituyen ni imputan.

El archivo `world_bank_wdi/govcons.dta` se conserva como alias de compatibilidad
construido a partir de la misma serie WDI. No representa una definición
adicional de la variable.

El script reproducible es
[`scripts/data/raw/govcons/govcons_wdi_raw.R`](../../../scripts/data/raw/govcons/govcons_wdi_raw.R).

La construcción definitiva y sus diagnósticos están documentados en
[`data/processed/govcons/`](../../processed/govcons/).
