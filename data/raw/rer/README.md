# Insumos raw de RER

`pwt_wdi/rer_inputs_1980_2022.csv` y su archivo idéntico para Stata contienen:

- `pl_gdpo`: nivel de precios del producto de PWT 11.0 (`PPP/XR`), seleccionado
  como insumo principal del tipo de cambio real;
- `reer_index`: índice de tipo de cambio real efectivo WDI/FMI
  (`PX.REX.REER`), conservado para robustez.

Los archivos raw preservan los niveles publicados. `log(pl_gdpo)` se calculará
posteriormente en `data/processed/rer/`, no dentro de la capa raw.

La fuente PWT completa se almacena una sola vez en `data/raw/pwt/pwt110.dta`
porque también suministra el capital humano. La serie principal tiene cobertura
completa para 52 de los 55 países durante 1996-2022; Libia, Nauru y Papúa Nueva
Guinea no aparecen en PWT. `rer_raw_coverage_dres20.csv` documenta la cobertura
de ambas alternativas.

El script reproducible es
[`scripts/data/rer/rer_pwt_wdi_data.R`](../../../scripts/data/rer/rer_pwt_wdi_data.R).
