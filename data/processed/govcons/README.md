# GOVCONS procesada

La única definición activa es:

```text
GOVCONS = gasto de consumo final del gobierno general (% del PIB)
```

La fuente activa es la base *National Accounts Main Aggregates* de la División
de Estadística de Naciones Unidas: serie 16, componente 3. WDI
(`NE.CON.GOVT.ZS`) se conserva exclusivamente como referencia de contraste y
no se mezcla con la serie activa.

## Validación de la sustitución

La serie de Naciones Unidas superó los umbrales definidos antes de activarla:

- 1.430 de 1.430 país-años disponibles para 55 países y 1996–2021;
- cero llaves duplicadas, faltantes, valores no positivos o infinitos;
- correlación de 0,9286 con WDI en las 1.152 observaciones comunes;
- diferencia absoluta media de 0,9840 puntos porcentuales;
- RMSE de 2,3888 puntos porcentuales.

La sustitución se realiza sobre la serie completa. No se rellenan solamente los
vacíos de WDI, porque eso produciría una variable híbrida con posibles quiebres
de fuente.

## Calidad metodológica

Los metadatos de Naciones Unidas se expanden a nivel país-año. En la serie
activa, 1.106 valores se clasifican como directos, 297 como derivados y 27 como
mixtos por superposición de métodos. Entre las 278 observaciones que WDI no
ofrecía, 128 son directas, 146 derivadas y cuatro mixtas.

Esta clasificación no altera los valores publicados. Permite documentar, por
ejemplo, que la serie de Nauru se deriva usando la participación del consumo
gubernamental de Kiribati, mientras que gran parte de la recuperación de
Venezuela procede de datos oficiales.

## Archivos

- `govcons_data.csv` y `govcons_data.dta`: panel activo basado únicamente en
  Naciones Unidas;
- `govcons_country_year_diagnostics_1996_2021.csv`: valores activos, referencia
  WDI, procedencia y métodos país-año;
- `govcons_un_wdi_comparison_1996_2021.csv`: comparación completa entre
  fuentes;
- `govcons_un_wdi_country_comparison_1996_2021.csv`: correlación y diferencias
  por país;
- `govcons_country_coverage_1996_2021.csv`: cobertura y calidad por país;
- `govcons_year_coverage_1996_2021.csv`: cobertura y calidad por año;
- `govcons_validation_summary.csv`: umbrales y resultados de validación.

El procesamiento se implementa en un único punto de entrada:
[`scripts/data/processed/govcons/govcons_processed.R`](../../../scripts/data/processed/govcons/govcons_processed.R).
