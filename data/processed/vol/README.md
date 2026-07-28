# VOL procesada

Esta carpeta contiene la volatilidad de los términos de intercambio de
commodities:

```text
g(t)   = 100 × [log(CTOT(t)) - log(CTOT(t-1))]
VOL(t) = desviación estándar de g(t-4), ..., g(t)
```

`CTOT` es el `Commodity Net Export Price Index` del FMI
(`CEMPI_CTOTNX_TT`) con ponderaciones fijas (`H_FW_IX`). VOL utiliza la
desviación estándar muestral de R y exige cinco variaciones anuales válidas,
equivalentes a seis niveles consecutivos del índice.

No se interpolan niveles ni variaciones y no se permiten ventanas parciales.
El período procesado es 1996-2021 y conserva los 55 países de la muestra fija
`DRES >= 20 %`.

## Cobertura validada

`VOL` está disponible en 1.403 de las 1.430 observaciones potenciales
(98,11 %). Cincuenta y cuatro países tienen datos y 53 presentan los 26 años
completos. Nauru no tiene serie CTOT y Rusia carece únicamente de VOL en 1996
porque no dispone del nivel de 1991 necesario para completar esa primera
ventana.

Los valores se expresan como desviaciones estándar de variaciones porcentuales
logarítmicas. La mediana es 9,86 y el máximo 42,59. No se recortan ni
estandarizan los valores calculados.

## Archivos

- `vol_data.csv` y `vol_data.dta`: panel procesado;
- `vol_country_year_diagnostics_1996_2021.csv`: nivel CTOT, variación anual,
  conteo de niveles y variaciones de cada ventana;
- `vol_country_coverage_1996_2021.csv`: cobertura por país;
- `vol_year_coverage_1996_2021.csv`: cobertura anual;
- `vol_validation_summary.csv`: controles de ventana, fórmula, rango, llaves y
  equivalencia entre CSV y Stata.

El script reproducible es
[`scripts/data/processed/vol/vol_processed.R`](../../../scripts/data/processed/vol/vol_processed.R).
