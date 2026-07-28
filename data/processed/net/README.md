# NET procesada

Esta carpeta contiene la medida de conectividad digital:

```text
NET = personas que utilizan internet (% de la población)
```

La fuente es el indicador `IT.NET.USER.ZS` de los World Development
Indicators. NET se conserva en su escala porcentual original de 0 a 100 y
aproxima la difusión tecnológica y el acceso a información productiva.

No se aplican logaritmos, estandarizaciones, interpolaciones ni imputaciones.
Los tres ceros publicados —Gabón, Omán y Siria en 1996— se conservan como
valores válidos.

## Cobertura validada

El período procesado es 1996-2021 y conserva la cuadrícula completa de 55
países y 26 años. NET está disponible en 1.379 de las 1.430 observaciones
potenciales (96,43 %).

Cuarenta países tienen los 26 años completos y 15 presentan faltantes. Todos
los países tienen al menos una observación. Nauru es el caso más discontinuo,
con 6 años disponibles y 20 faltantes. Los demás vacíos se conservan según la
publicación de WDI y se detallan en el diagnóstico por país.

## Archivos

- `net_data.csv` y `net_data.dta`: panel procesado;
- `net_country_year_diagnostics_1996_2021.csv`: valor publicado, NET y estado
  de disponibilidad para cada país-año;
- `net_country_coverage_1996_2021.csv`: cobertura y años faltantes por país;
- `net_year_coverage_1996_2021.csv`: cobertura anual;
- `net_validation_summary.csv`: controles de identidad, rango, llaves,
  cobertura y equivalencia entre CSV y Stata.

El script reproducible es
[`scripts/data/processed/net/net_processed.R`](../../../scripts/data/processed/net/net_processed.R).
