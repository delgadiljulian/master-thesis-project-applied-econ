# HUMCAP procesada

Esta carpeta contiene el índice de capital humano utilizado en el modelo:

```text
HUMCAP = hc
```

`hc` es el índice de capital humano publicado por Penn World Table 11.0. Se
conserva en sus niveles originales y combina años promedio de escolaridad con
retornos a la educación. Por tanto, HUMCAP no se interpreta como años de
escolaridad, porcentaje ni tasa.

PWT 11.0 es la única fuente de esta variable. No se aplican logaritmos,
estandarizaciones, interpolaciones ni imputaciones.

## Cobertura validada

El período procesado es 1996-2021 y conserva la cuadrícula completa de 55
países y 26 años. HUMCAP está disponible en 1.222 de las 1.430 observaciones
potenciales (85,45 %). Cuarenta y siete países tienen los 26 años completos.
Antigua y Barbuda, Guinea, Libia, Nauru, Omán, Papúa Nueva Guinea, Surinam y
Seychelles no tienen observaciones de `hc` y conservan sus 208 país-años como
faltantes.

No existen países con cobertura parcial dentro del período.

## Archivos

- `humcap_data.csv` y `humcap_data.dta`: panel procesado;
- `humcap_country_year_diagnostics_1996_2021.csv`: índice original, HUMCAP y
  estado de disponibilidad para cada país-año;
- `humcap_country_coverage_1996_2021.csv`: cobertura por país;
- `humcap_year_coverage_1996_2021.csv`: cobertura anual;
- `humcap_validation_summary.csv`: controles de identidad, dominio, llaves,
  cobertura y equivalencia entre CSV y Stata.

El script reproducible es
[`scripts/data/processed/humcap/humcap_processed.R`](../../../scripts/data/processed/humcap/humcap_processed.R).
