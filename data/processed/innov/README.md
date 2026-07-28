# INNOV procesada

Esta carpeta contiene la medida de capacidades científico-tecnológicas:

```text
artículos por millón = artículos científicos y técnicos / población × 1.000.000
INNOV = log(1 + artículos por millón)
```

El numerador corresponde al indicador `IP.JRN.ARTC.SC` de los World
Development Indicators y la población a `SP.POP.TOTL`. La transformación
logarítmica reduce la asimetría y `log(1 + x)` permite conservar observaciones
con cero artículos.

INNOV aproxima la producción de conocimiento científico y las capacidades
tecnológicas; no mide directamente patentes ni innovación comercial. Esta es
la única definición utilizada en el proyecto.

## Cobertura validada

El período procesado es 1996-2021 y contiene las 1.430 observaciones potenciales
de los 55 países y 26 años. Tanto los artículos como la población están
disponibles en todas las celdas, por lo que INNOV tiene cobertura del 100 %.

Existen 15 país-años con cero artículos publicados. Se conservan como valores
válidos y generan `INNOV = 0`. No se interpola ni imputa ningún insumo.

## Archivos

- `innov_data.csv` y `innov_data.dta`: panel procesado;
- `innov_country_year_diagnostics_1996_2021.csv`: insumos, tasa por millón,
  INNOV y estado de disponibilidad para cada país-año;
- `innov_country_coverage_1996_2021.csv`: cobertura y ceros por país;
- `innov_year_coverage_1996_2021.csv`: cobertura y ceros por año;
- `innov_validation_summary.csv`: controles de fórmula, dominio, llaves,
  cobertura y equivalencia entre CSV y Stata.

El script reproducible es
[`scripts/data/processed/innov/innov_processed.R`](../../../scripts/data/processed/innov/innov_processed.R).
