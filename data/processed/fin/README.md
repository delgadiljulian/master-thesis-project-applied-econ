# FIN procesada

Esta carpeta contiene la medida de profundidad financiera:

```text
FIN = crédito doméstico al sector privado (% del PIB)
```

La fuente es el indicador `FS.AST.PRVT.GD.ZS` de los World Development
Indicators. FIN aproxima la profundidad del crédito privado; no constituye un
índice integral de acceso, eficiencia, estabilidad o calidad financiera.

La variable se conserva en la escala porcentual publicada. No se aplican
logaritmos, estandarización, interpolación, imputación ni recorte.

## Valores superiores a 100 %

El saldo de crédito privado puede superar el PIB generado durante un año, por
lo que los valores superiores a 100 % son económicamente admisibles. El panel
contiene 84 de estas observaciones. Se conservan todas sin winsorización; el
máximo es 157,28 % para Noruega en 2020.

## Cobertura validada

El período procesado es 1996-2021 y conserva la cuadrícula completa de 55
países y 26 años. FIN está disponible en 1.202 de las 1.430 observaciones
potenciales (84,06 %).

Veintiocho países tienen cobertura completa, 26 presentan cobertura parcial y
Nauru no tiene observaciones.

## Archivos

- `fin_data.csv` y `fin_data.dta`: panel procesado;
- `fin_country_year_diagnostics_1996_2021.csv`: valor publicado, indicador de
  valores superiores a 100 % y estado de disponibilidad por país-año;
- `fin_country_coverage_1996_2021.csv`: cobertura por país;
- `fin_year_coverage_1996_2021.csv`: cobertura anual;
- `fin_validation_summary.csv`: controles de identidad, dominio, llaves,
  valores superiores a 100 %, cobertura y equivalencia CSV–Stata.

El script reproducible es
[`scripts/data/processed/fin/fin_processed.R`](../../../scripts/data/processed/fin/fin_processed.R).
