# OILPC, GASPC y COALPC procesadas

Esta carpeta contiene tres medidas de rentas extractivas reales por habitante:

```text
OILPC  = (renta petrolera como % del PIB / 100) × PIB real / población
GASPC  = (renta de gas como % del PIB / 100) × PIB real / población
COALPC = (renta del carbón como % del PIB / 100) × PIB real / población
```

Los insumos proceden exclusivamente de World Development Indicators. El PIB
real corresponde a `NY.GDP.MKTP.KD`, la población a `SP.POP.TOTL` y las tres
participaciones de renta a sus respectivos indicadores WDI.

## Regla de construcción

Cada variable se calcula únicamente cuando su participación de renta, el PIB
real y la población están observados en el mismo país-año. No se imputan
componentes, no se aplican logaritmos y los ceros publicados se conservan como
valores válidos.

Las tres medidas quedan expresadas en dólares constantes por habitante. El
período procesado es 1996-2021 y la cuadrícula conserva los 55 países de la
muestra fija `DRES >= 20 %`.

## Cobertura validada

La cuadrícula contiene 1.430 observaciones potenciales:

- `OILPC`: 1.397 país-años (97,69 %), los 55 países tienen datos y 49 están
  completos;
- `GASPC`: 1.365 país-años (95,45 %), 54 países tienen datos y 46 están
  completos; Sierra Leona no tiene observaciones;
- `COALPC`: 1.384 país-años (96,78 %), 54 países tienen datos y 48 están
  completos; Nauru no tiene observaciones.

Las distribuciones son asimétricas, especialmente para petróleo y gas. Los
valores máximos se conservan sin recortes porque reflejan economías con rentas
elevadas por habitante. Cualquier transformación o tratamiento de valores
influyentes deberá decidirse de manera explícita en la etapa econométrica.

## Archivos

- `oilpc_gaspc_coalpc_data.csv` y `.dta`: panel procesado;
- `oilpc_gaspc_coalpc_country_coverage_1996_2021.csv`: cobertura por país;
- `oilpc_gaspc_coalpc_year_coverage_1996_2021.csv`: cobertura anual;
- `oilpc_gaspc_coalpc_validation_summary.csv`: validación de dimensiones,
  fórmulas, rangos, llaves y equivalencia entre CSV y Stata.

El script reproducible es
[`scripts/data/processed/oilpc_gaspc_coalpc/oilpc_gaspc_coalpc_processed.R`](../../../scripts/data/processed/oilpc_gaspc_coalpc/oilpc_gaspc_coalpc_processed.R).
