# LOG_GDPPC procesada

Esta carpeta contiene el control del nivel de desarrollo económico:

```text
LOG_GDPPC = log(PIB per cápita en PPA constante)
```

El nivel proviene del indicador `NY.GDP.PCAP.PP.KD` de los World Development
Indicators y está expresado en dólares internacionales constantes ajustados
por paridad de poder adquisitivo. `log` representa el logaritmo natural.

El nivel se mantiene únicamente como insumo y diagnóstico. La variable que
entra al modelo es `LOG_GDPPC`.

## Cobertura validada

El período procesado es 1996-2021 y conserva la cuadrícula completa de 55
países y 26 años. LOG_GDPPC está disponible en 1.378 de las 1.430
observaciones potenciales (96,36 %).

Cincuenta y tres países tienen los 26 años completos. Venezuela y Yemen no
tienen observaciones de `NY.GDP.PCAP.PP.KD` durante el período y conservan sus
52 país-años como faltantes. No existen países con cobertura parcial.

No se emplea el indicador en dólares constantes sin PPA, ni se interpola o
imputa ningún valor.

## Archivos

- `log_gdppc_data.csv` y `log_gdppc_data.dta`: panel procesado;
- `log_gdppc_country_year_diagnostics_1996_2021.csv`: nivel de GDPPC,
  LOG_GDPPC y estado de disponibilidad para cada país-año;
- `log_gdppc_country_coverage_1996_2021.csv`: cobertura por país;
- `log_gdppc_year_coverage_1996_2021.csv`: cobertura anual;
- `log_gdppc_validation_summary.csv`: controles de fórmula, dominio, llaves,
  cobertura y equivalencia entre CSV y Stata.

El script reproducible es
[`scripts/data/processed/gdppc/log_gdppc_processed.R`](../../../scripts/data/processed/gdppc/log_gdppc_processed.R).
