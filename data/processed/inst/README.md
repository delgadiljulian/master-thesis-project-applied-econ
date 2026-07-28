# INST procesada

Esta carpeta contiene el índice de calidad institucional utilizado por la
tesis:

```text
INST = (control de la corrupción + Estado de derecho
        + efectividad gubernamental) / 3
```

Los tres componentes son los estimadores de Worldwide Governance Indicators
en su escala original aproximada de -2,5 a 2,5. Como están publicados en una
escala común, no se estandarizan nuevamente antes de calcular el promedio.
Valores mayores de `INST` representan mejor calidad institucional.

## Regla de construcción

`INST` se calcula únicamente cuando los tres componentes están observados en el
mismo país-año. No se permiten promedios parciales, interpolaciones ni
imputaciones.

WGI no publicó observaciones para 1997, 1999 ni 2001. Estos 165 vacíos
país-año son estructurales y permanecen explícitamente faltantes. No
representan errores de descarga.

El período procesado es 1996-2021 y la cuadrícula conserva los 55 países de la
muestra fija `DRES >= 20 %`.

## Cobertura validada

La cuadrícula contiene 1.430 observaciones potenciales. `INST` está disponible
en 1.257 país-años (87,90 %). Los tres años no publicados explican 165 de los
173 faltantes.

Dentro de los 1.265 país-años que pertenecen a años publicados, la cobertura es
de 99,37 %. Los ocho faltantes restantes corresponden a Nauru en 1996, 1998,
2000 y 2002-2006, porque control de la corrupción y efectividad gubernamental no
están disponibles. Los 55 países tienen al menos una observación y 54 tienen
cobertura completa en los 23 años publicados.

## Archivos

- `inst_data.csv` y `inst_data.dta`: panel procesado con identificación, año e
  `inst`;
- `inst_country_coverage_1996_2021.csv`: cobertura y faltantes por país;
- `inst_year_coverage_1996_2021.csv`: cobertura anual y señalización de los
  años no publicados;
- `inst_validation_summary.csv`: controles de dimensiones, fórmula, rango,
  llaves y equivalencia entre CSV y Stata.

El script reproducible es
[`scripts/data/processed/inst/inst_processed.R`](../../../scripts/data/processed/inst/inst_processed.R).
