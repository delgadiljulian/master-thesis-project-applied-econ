# RER procesada

Esta carpeta contiene el tipo de cambio real utilizado en el modelo:

```text
RER = log(pl_gdpo)
```

`pl_gdpo` es el nivel de precios del producto relativo a Estados Unidos
publicado por Penn World Table 11.0. Se utiliza el logaritmo natural. Un aumento
de RER representa una apreciación real, es decir, un mayor nivel de precios del
producto respecto de Estados Unidos.

PWT 11.0 es la única fuente de esta variable. No se combinan medidas
alternativas, no se interpola y no se imputan los países ausentes.

## Cobertura validada

El período procesado es 1996-2021 y conserva la cuadrícula completa de 55
países y 26 años. RER está disponible en 1.352 de las 1.430 observaciones
potenciales (94,55 %). Cincuenta y dos países tienen los 26 años completos.
Libia, Nauru y Papúa Nueva Guinea no tienen observaciones en PWT y conservan
sus 78 país-años como faltantes.

## Archivos

- `rer_data.csv` y `rer_data.dta`: panel procesado;
- `rer_country_year_diagnostics_1996_2021.csv`: nivel `pl_gdpo`, RER y estado
  de disponibilidad para cada país-año;
- `rer_country_coverage_1996_2021.csv`: cobertura por país;
- `rer_year_coverage_1996_2021.csv`: cobertura anual;
- `rer_validation_summary.csv`: controles de fórmula, dominio, llaves,
  cobertura y equivalencia entre CSV y Stata.

El script reproducible es
[`scripts/data/processed/rer/rer_processed.R`](../../../scripts/data/processed/rer/rer_processed.R).
