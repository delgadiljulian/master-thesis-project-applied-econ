# HUMCAP procesada

La variable activa se construye íntegramente con los años promedio de
escolaridad de adultos de 25 años o más publicados por el PNUD. Para mantener
la interpretación económica del índice utilizado anteriormente, se aplica la
función de retornos educativos de PWT:

```text
phi(s) = 0.134*s                              si s <= 4
phi(s) = 0.134*4 + 0.101*(s - 4)             si 4 < s <= 8
phi(s) = 0.134*4 + 0.101*4 + 0.068*(s - 8)   si s > 8
HUMCAP = exp(phi(s))
```

HUMCAP es una proxy de capacidades productivas acumuladas; no se interpreta
como años de escolaridad, porcentaje ni tasa. No se aplican interpolaciones,
imputaciones, estandarizaciones ni mezclas de fuentes.

## Cobertura validada

El período procesado es 1996--2021 y conserva la cuadrícula completa de 55
países y 26 años. HUMCAP está disponible en 1.403 de las 1.430 observaciones
potenciales (98,11 %). Cuarenta y nueve países tienen los 26 años completos y
seis tienen cobertura parcial; ningún país carece por completo de información.

Frente a la antigua definición `hc` de PWT 11.0, la serie activa recupera 184
celdas y pierde tres, para una ganancia neta de 181 observaciones. En las 1.219
observaciones comunes, la correlación en niveles es 0,9307, la correlación
dentro de los países es 0,8879 y la correlación mediana por país es 0,9735. La
correlación de las variaciones anuales es menor (0,5253), por lo que los
resultados que dependan de cambios de corto plazo deben interpretarse con
cautela. El error absoluto medio equivale a 0,77 años de escolaridad.

## Archivos

- `humcap_data.csv` y `humcap_data.dta`: panel procesado activo;
- `humcap_country_year_diagnostics_1996_2021.csv`: años de escolaridad, función
  de retornos, HUMCAP y estado de disponibilidad;
- `humcap_country_coverage_1996_2021.csv`: cobertura por país;
- `humcap_year_coverage_1996_2021.csv`: cobertura anual;
- `humcap_undp_pwt_comparison_1996_2021.csv`: comparación país-año con PWT;
- `humcap_undp_pwt_country_comparison_1996_2021.csv`: diagnóstico comparado por
  país;
- `humcap_validation_summary.csv`: controles de cobertura, concordancia,
  identidad, dominio, llaves y equivalencia entre CSV y Stata.

El script activo es
[`scripts/data/processed/humcap/humcap_undp_processed.R`](../../../scripts/data/processed/humcap/humcap_undp_processed.R).
El nombre histórico `humcap_processed.R` se conserva como envoltorio de
compatibilidad y ejecuta la misma construcción.
