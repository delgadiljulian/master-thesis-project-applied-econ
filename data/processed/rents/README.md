# RENTS procesada

Esta carpeta contiene la variable agregada de rentas extractivas del subsuelo y
dos desagregaciones sectoriales:

```text
RENTS             = petróleo + gas natural + carbón + minerales
RENTS_OIL_GAS     = petróleo + gas natural
RENTS_MINING      = carbón + minerales
RENTS             = RENTS_OIL_GAS + RENTS_MINING
```

Los cuatro componentes proceden de WDI y están expresados como porcentaje del
PIB. Se excluyen las rentas forestales y el indicador agregado de rentas
naturales totales.

## Regla de construcción

Cada medida se calcula únicamente cuando todos sus componentes están observados
en el mismo país-año. `RENTS` requiere los cuatro componentes;
`RENTS_OIL_GAS`, petróleo y gas; y `RENTS_MINING`, carbón y minerales. Los
faltantes nunca se sustituyen por cero y los ceros publicados por WDI se
conservan como valores válidos.

La especificación principal utiliza `RENTS`. Las dos medidas sectoriales quedan
disponibles para sustituirla en análisis desagregados. No deben incluirse
simultáneamente `RENTS`, `RENTS_OIL_GAS` y `RENTS_MINING`, porque la primera es
la suma exacta de las otras dos.

El período procesado es 1996-2021 y la cuadrícula conserva los 55 países
seleccionados mediante `DRES >= 20 %`.

## Archivos

- `rents_data.csv` y `rents_data.dta`: panel procesado con identificación,
  año, `rents`, `rents_oil_gas` y `rents_mining`;
- `rents_country_coverage_1996_2021.csv`: cobertura y faltantes por país;
- `rents_year_coverage_1996_2021.csv`: cobertura disponible en cada año;
- `rents_validation_summary.csv`: controles de dimensiones, fórmula, rangos,
  llaves y equivalencia entre CSV y Stata.

## Cobertura validada

La cuadrícula contiene 1.430 observaciones potenciales:

- `RENTS`: 1.352 país-años (94,55 %), 53 países con datos y 45 completos;
- `RENTS_OIL_GAS`: 1.365 país-años (95,45 %), 54 países con datos y 46
  completos; Sierra Leona no tiene observaciones;
- `RENTS_MINING`: 1.384 país-años (96,78 %), 54 países con datos y 48
  completos; Nauru no tiene observaciones.

Las diferencias de cobertura se deben a que cada subagregado requiere solo sus
dos componentes. La identidad entre el total y los subagregados se valida en
todas las filas donde están disponibles los cuatro componentes.

El script reproducible es
[`scripts/data/processed/rents/rents_processed.R`](../../../scripts/data/processed/rents/rents_processed.R).
