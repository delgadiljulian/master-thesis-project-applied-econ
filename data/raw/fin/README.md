# Insumo raw de FIN

`world_bank_wdi/fin_wdi_input_1980_2022.csv` y su archivo equivalente para
Stata contienen el crédito doméstico al sector privado como porcentaje del PIB
publicado por los World Development Indicators (`FS.AST.PRVT.GD.ZS`).
[La ficha oficial de metadatos](https://databank.worldbank.org/metadataglossary/world-development-indicators/series/FS.AST.PRVT.GD.ZS)
define el indicador como recursos financieros provistos al sector privado por
corporaciones financieras.

La variable se interpreta como una proxy de profundidad financiera o
profundidad del crédito privado. No constituye un índice integral de desarrollo
financiero: no mide directamente acceso, eficiencia, estabilidad ni calidad de
la cartera. Para algunos países, la definición de la fuente puede incluir
crédito a empresas públicas.

La serie se conserva en su escala original. La capa raw no aplica logaritmos,
interpolaciones, imputaciones ni truncamientos. Los valores superiores a 100
son admisibles porque el saldo de crédito puede superar el PIB anual.

`world_bank_wdi/fin_raw_coverage_summary_dres20.csv` resume la cobertura y el
rango para los 55 países de la muestra DRES durante 1996-2022.
`world_bank_wdi/fin_raw_country_coverage_dres20.csv` identifica los años
faltantes y el rango observado de cada país.

La serie está disponible en 1.244 de las 1.485 celdas país-año (83,8 %).
Cincuenta y cuatro países tienen al menos una observación, 28 presentan
cobertura completa y Nauru no tiene datos. La cobertura se reduce hacia el
final del período: 42 países tienen dato en 2022. Los 89 valores superiores a
100 % se conservan como valores publicados; el máximo de la muestra es 157,3 %
para Noruega en 2020.

El script reproducible es
[`scripts/data/raw/fin/fin_wdi_raw.R`](../../../scripts/data/raw/fin/fin_wdi_raw.R).

La construcción definitiva y sus diagnósticos están documentados en
[`data/processed/fin/`](../../processed/fin/).
