# FIN procesada

Esta carpeta contiene la medida de profundidad financiera:

```text
FIN = crédito doméstico al sector privado otorgado por bancos (% del PIB)
```

La fuente activa es el indicador `FD.AST.PRVT.GD.ZS` de los World Development
Indicators. FIN aproxima la profundidad del crédito bancario privado; no
constituye un índice integral de acceso, eficiencia, estabilidad o calidad
financiera.

La variable se conserva en la escala porcentual publicada. No se aplican
logaritmos, estandarización, interpolación, imputación ni recorte.

## Valores superiores a 100 %

El saldo de crédito privado puede superar el PIB generado durante un año, por
lo que los valores superiores a 100 % son económicamente admisibles. El panel
contiene 42 de estas observaciones. Se conservan todas sin winsorización; el
máximo es 142,10 % para Australia en 2016.

## Cobertura validada

El período procesado es 1996-2021 y conserva la cuadrícula completa de 55
países y 26 años. FIN está disponible en 1.328 de las 1.430 observaciones
potenciales (92,87 %).

Cuarenta países tienen cobertura completa, 14 presentan cobertura parcial y
Nauru no tiene observaciones.

## Contraste con la definición amplia

La serie anterior `FS.AST.PRVT.GD.ZS`, que incluye corporaciones financieras
más amplias, se conserva únicamente como referencia y nunca se mezcla con la
serie bancaria. La definición activa recupera 126 observaciones, no pierde
ninguna celda observada en la serie amplia y eleva la cobertura desde 84,06 %
hasta 92,87 %.

En las 1.202 observaciones comunes, la correlación es 0,9594 y la diferencia
absoluta media es 2,39 puntos porcentuales. Las mayores discrepancias se
concentran en Sudáfrica, Chile y Noruega; por ello, los diagnósticos conservan
ambas series y sus diferencias país-año.

## Archivos

- `fin_data.csv` y `fin_data.dta`: panel procesado;
- `fin_country_year_diagnostics_1996_2021.csv`: serie activa, referencia,
  diferencias y estado de disponibilidad por país-año;
- `fin_banks_broad_comparison_1996_2021.csv`: contraste país-año;
- `fin_banks_broad_country_comparison_1996_2021.csv`: contraste por país;
- `fin_country_coverage_1996_2021.csv`: cobertura por país;
- `fin_year_coverage_1996_2021.csv`: cobertura anual;
- `fin_validation_summary.csv`: controles de identidad, dominio, llaves,
  valores superiores a 100 %, cobertura y equivalencia CSV–Stata.

El procesamiento se implementa en un único punto de entrada:
[`fin_processed.R`](../../../scripts/data/processed/fin/fin_processed.R).
