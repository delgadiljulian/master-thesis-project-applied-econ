# Insumos raw de RER

`pwt/rer_pwt11_input_1950_2023.csv` y su archivo equivalente para Stata
contienen `pl_gdpo`, el nivel de precios del producto de PWT 11.0 (`PPP/XR`).
Esta es la única serie activa para `RER`.

Los archivos raw preservan los niveles publicados. `log(pl_gdpo)` se calcula
exclusivamente en `data/processed/rer/`, no dentro de la capa raw.

La fuente PWT completa se almacena una sola vez en `data/raw/pwt/pwt110.dta`
porque también suministra el capital humano. La serie tiene cobertura
completa para 52 de los 55 países durante 1996-2022; Libia, Nauru y Papúa Nueva
Guinea no aparecen en PWT. `pwt/rer_pwt_raw_coverage_summary_dres20.csv` y
`pwt/rer_pwt_raw_country_coverage_dres20.csv` documentan la cobertura.

El script reproducible es
[`scripts/data/raw/rer/rer_pwt_raw.py`](../../../scripts/data/raw/rer/rer_pwt_raw.py).

La construcción definitiva y sus diagnósticos están documentados en
[`data/processed/rer/`](../../processed/rer/).
