# Insumos raw de RENTS

`world_bank_wdi/rents_wdi_inputs_1980_2022.csv` y su archivo equivalente para
Stata contienen los cuatro componentes sin transformar de las rentas
extractivas:

- rentas petroleras (`NY.GDP.PETR.RT.ZS`);
- rentas de gas natural (`NY.GDP.NGAS.RT.ZS`);
- rentas del carbón (`NY.GDP.COAL.RT.ZS`);
- rentas minerales (`NY.GDP.MINR.RT.ZS`).

La capa raw no suma estos componentes ni imputa valores faltantes. En
`data/processed/rents/` se construyen la suma total `RENTS`, el subagregado
`RENTS_OIL_GAS` de petróleo y gas, y el subagregado `RENTS_MINING` de carbón y
minerales. Cada medida exige que todos sus propios componentes estén
observados.

El indicador de rentas naturales totales (`NY.GDP.TOTL.RT.ZS`) no se utiliza
porque incluye rentas forestales y no coincide con la definición extractiva de
la tesis. Los cuatro componentes WDI están publicados hasta 2021; la ausencia
de 2022 se conserva como faltante de la fuente.

`rents_raw_coverage_dres20.csv` documenta la cobertura individual y conjunta
para los 55 países de la muestra DRES durante 1996-2022. El script reproducible
es
[`scripts/data/raw/rents/rents_wdi_raw.R`](../../../scripts/data/raw/rents/rents_wdi_raw.R).

La construcción de la variable definitiva corresponde a
[`scripts/data/processed/rents/rents_processed.R`](../../../scripts/data/processed/rents/rents_processed.R).
