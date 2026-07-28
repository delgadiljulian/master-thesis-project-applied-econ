# GOVCONS procesada

Esta carpeta contiene el control de consumo gubernamental:

```text
GOVCONS = gasto de consumo final del gobierno general (% del PIB)
```

La fuente es el indicador `NE.CON.GOVT.ZS` de los World Development
Indicators. GOVCONS controla por el tamaño relativo del consumo público; no
mide presión tributaria, capacidad fiscal, balance presupuestario ni
prociclicidad fiscal.

La variable se conserva en la escala porcentual publicada, sin logaritmos,
estandarización, interpolación, imputación ni fuente alternativa.

## Tratamiento de los ceros de Venezuela

El archivo oficial de WDI publica 16 ceros consecutivos para Venezuela entre
1996 y 2011. Estos valores continúan una secuencia iniciada en 1991, después de
una serie positiva cercana a 8-14 % del PIB, y luego son seguidos por
observaciones faltantes. Un consumo final del gobierno exactamente nulo durante
ese período no es económicamente plausible.

Por esta razón, los 16 ceros se conservan intactos en raw, pero en processed se
marcan como faltantes mediante `source_zero_flagged_missing`. No se reemplazan
por valores estimados ni por otra fuente.

## Cobertura validada

El período procesado es 1996-2021 y conserva la cuadrícula completa de 55
países y 26 años. Después del control de calidad, GOVCONS está disponible en
1.152 de las 1.430 observaciones potenciales (80,56 %).

Cuarenta países tienen cobertura completa, ocho presentan cobertura parcial y
siete no tienen observaciones utilizables: Antigua y Barbuda, Jamaica,
Liberia, Nigeria, Nauru, Trinidad y Tobago y Venezuela.

## Archivos

- `govcons_data.csv` y `govcons_data.dta`: panel procesado;
- `govcons_country_year_diagnostics_1996_2021.csv`: valor raw, GOVCONS y
  clasificación de disponibilidad para cada país-año;
- `govcons_country_coverage_1996_2021.csv`: cobertura por país;
- `govcons_year_coverage_1996_2021.csv`: cobertura anual;
- `govcons_validation_summary.csv`: controles de ceros, dominio, llaves,
  cobertura y equivalencia entre CSV y Stata.

El script reproducible es
[`scripts/data/processed/govcons/govcons_processed.R`](../../../scripts/data/processed/govcons/govcons_processed.R).
