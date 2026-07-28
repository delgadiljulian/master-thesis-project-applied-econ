# Insumos raw de OILPC, GASPC y COALPC

`world_bank_wdi/oilpc_gaspc_coalpc_wdi_inputs_1980_2022.csv` y su archivo
equivalente para Stata contienen los cinco insumos sin transformar requeridos
para construir posteriormente las tres medidas de rentas por habitante:

- rentas petroleras como porcentaje del PIB (`NY.GDP.PETR.RT.ZS`);
- rentas de gas natural como porcentaje del PIB (`NY.GDP.NGAS.RT.ZS`);
- rentas del carbón como porcentaje del PIB (`NY.GDP.COAL.RT.ZS`);
- PIB en dólares constantes (`NY.GDP.MKTP.KD`);
- población total (`SP.POP.TOTL`).

La capa raw no calcula `OILPC`, `GASPC` ni `COALPC`, y tampoco aplica
logaritmos, deflactores adicionales o imputaciones. En la capa processed, cada
participación porcentual se combina con el PIB real y se divide por la
población para obtener una medida por habitante. Los ceros publicados por WDI
se conservan como valores válidos y no se confunden con datos faltantes.

Las series de rentas WDI están publicadas hasta 2021; su ausencia en 2022 se
conserva como faltante de la fuente. El archivo
`world_bank_wdi/oilpc_gaspc_coalpc_raw_coverage_dres20.csv` documenta la
cobertura de cada insumo y de las tres combinaciones requeridas para los 55
países de la muestra DRES durante 1996-2022.

La cobertura conjunta de cada futura variable es:

- `OILPC`: 1.397 de 1.485 celdas (94,1 %), con datos para los 55 países;
- `GASPC`: 1.365 celdas (91,9 %), sin observaciones de gas para Sierra Leona;
- `COALPC`: 1.384 celdas (93,2 %), sin observaciones de carbón para Nauru.

Los cinco insumos aparecen conjuntamente en 1.352 celdas (91,0 %) y 53 países.
Hasta 2021, 49 países tienen insumos completos para `OILPC`, 46 para `GASPC` y
48 para `COALPC`. La población está completa para toda la muestra; el PIB real
solo falta para Yemen entre 2019 y 2022.

WDI es la única fuente activa para estas tres variables.

El script reproducible es
[`scripts/data/raw/oilpc_gaspc_coalpc/oilpc_gaspc_coalpc_wdi_raw.R`](../../../scripts/data/raw/oilpc_gaspc_coalpc/oilpc_gaspc_coalpc_wdi_raw.R).

La construcción definitiva se realiza mediante
[`scripts/data/processed/oilpc_gaspc_coalpc/oilpc_gaspc_coalpc_processed.R`](../../../scripts/data/processed/oilpc_gaspc_coalpc/oilpc_gaspc_coalpc_processed.R).
