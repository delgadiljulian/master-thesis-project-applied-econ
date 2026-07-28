# PEXP y FEXP procesadas

Esta carpeta contiene dos participaciones de especialización exportadora:

```text
PEXP = 100 × exportaciones SITC 0, 1, 2, 4 y división 68
             / exportaciones de mercancías

FEXP = 100 × exportaciones SITC 3
             / exportaciones de mercancías
```

El numerador incluye exclusivamente mercancías clasificadas en las secciones
SITC Rev. 2 0, 1, 2 y 4, más la división 68, para `PEXP`; y la sección 3 para
`FEXP`. Los dos numeradores son mutuamente excluyentes. El denominador común
incluye todas las mercancías SITC de cuatro dígitos y el residuo `XXXX`;
excluye servicios financieros, TIC, transporte, viajes y servicios no
especificados.

Las correcciones comerciales negativas se conservan en raw y se reemplazan por
cero únicamente para las agregaciones, siguiendo la misma regla aplicada en
DRES y HHI. Ambas variables quedan expresadas en porcentaje, con rango de 0 a
100.

El período procesado es 1996-2021 y conserva los 55 países de la muestra fija
`DRES >= 20 %`.

## Cobertura validada

`PEXP` y `FEXP` están disponibles en las 1.430 observaciones de la cuadrícula:
los 55 países tienen cobertura completa durante 1996-2021. El catálogo contiene
244 productos PEXP y 21 productos FEXP, sin superposición. El denominador
reconstruido coincide exactamente con el utilizado por HHI.

El residuo `XXXX` representa más del 10 % de las mercancías en 165 país-años y
alcanza un máximo de 61,23 %. Se mantiene en el denominador conforme a la
definición aprobada, pero el diagnóstico queda disponible para interpretar
esos casos con cautela.

## Archivos

- `pexp_fexp_data.csv` y `pexp_fexp_data.dta`: panel conjunto;
- `pexp_fexp_country_year_diagnostics_1996_2021.csv`: numeradores, denominador,
  servicios excluidos, `XXXX` y correcciones negativas;
- `pexp_fexp_country_coverage_1996_2021.csv`: cobertura por país;
- `pexp_fexp_year_coverage_1996_2021.csv`: cobertura anual;
- `pexp_fexp_validation_summary.csv`: controles de clasificación, fórmulas,
  rangos, llaves y equivalencia entre CSV y Stata.

El script reproducible es
[`scripts/data/processed/pexp_fexp/pexp_fexp_processed.R`](../../../scripts/data/processed/pexp_fexp/pexp_fexp_processed.R).
