# ECI procesado

La carpeta `atlas/` contiene la única serie de ECI utilizada en la tesis. El
script procesado selecciona los 55 países fijados mediante `DRES >= 20 %` y el
período econométrico 1996–2021 a partir de la captura raw de la API oficial del
Atlas of Economic Complexity.

## Definición

`eci` es el Índice de Complejidad Económica publicado por el Harvard Growth Lab
en el campo `countryYear.eci`. El indicador combina la diversidad de la canasta
exportadora y la ubicuidad de los productos exportados. La consulta actual del
Atlas utiliza por defecto la clasificación HS92.

No se mezclan valores de la antigua tabla de rankings, OEC ni otras fuentes. No
se redondea, interpola, imputa o estandariza la serie.

## Cobertura

La salida contiene 1.430 observaciones: 55 países por 26 años. Todos los países
tienen ECI observado en cada año entre 1996 y 2021, sin llaves duplicadas ni
valores infinitos.

## Archivos

- `atlas/eci_data.csv` y `atlas/eci_data.dta`: panel procesado equivalente en
  CSV y Stata;
- `atlas/eci_country_coverage_1996_2021.csv`: cobertura por país;
- `atlas/eci_validation_summary.csv`: dimensiones, faltantes, duplicados y
  validaciones numéricas.

El script reproducible es
[`scripts/data/processed/eci/eci_atlas_processed.R`](../../../scripts/data/processed/eci/eci_atlas_processed.R).
