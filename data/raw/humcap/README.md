# Insumos raw de HUMCAP

## Fuente: Penn World Table 11.0

`pwt/humcap_pwt11_input_1950_2023.csv` y su archivo equivalente para Stata
contienen el índice de capital humano `hc` publicado por Penn World Table 11.0.
El índice combina información sobre años promedio de escolaridad con retornos a
la educación. Por tanto, `HUMCAP` no debe interpretarse como años de escolaridad
ni como una tasa o porcentaje.

La fuente original se almacena una sola vez en `data/raw/pwt/pwt110.dta`. El
extracto específico conserva únicamente código de país, nombre, año y `hc`, sin
interpolaciones, imputaciones ni transformaciones.

`pwt/humcap_pwt_raw_coverage_summary_dres20.csv` resume la cobertura para los 55
países de la muestra DRES durante 1996-2022 y
`pwt/humcap_pwt_raw_country_coverage_dres20.csv` documenta cada país.

La serie está disponible en 1.269 de las 1.485 celdas país-año
(85,5 %). Cuarenta y siete países tienen cobertura completa. Antigua y Barbuda,
Guinea, Libia, Nauru, Omán, Papua Nueva Guinea, Surinam y Seychelles no tienen
observaciones de `hc` durante el período principal. Esta es la única definición
activa de `HUMCAP` en el proyecto.

`pwt/humcap_pwt.dta` es un alias de compatibilidad construido con la misma
serie de PWT 11.0. No representa una fuente ni una definición adicional.

El script reproducible es
[`scripts/data/raw/humcap/humcap_pwt_raw.py`](../../../scripts/data/raw/humcap/humcap_pwt_raw.py).

La construcción definitiva en niveles y sus diagnósticos están documentados en
[`data/processed/humcap/`](../../processed/humcap/).
