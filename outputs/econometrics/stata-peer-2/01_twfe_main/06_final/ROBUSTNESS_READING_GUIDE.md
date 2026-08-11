# Guía técnica para leer la robustez focal del M3

Generada por 04_twfe_full.do el 10 Aug 2026.

## Síntesis técnica

La evidencia no admite una etiqueta única de robusto o no robusto. La lectura debe separar estabilidad de signo y magnitud, inferencia, cambios de muestra, estabilidad temporal y efectos marginales.

La inferencia convencional y el wild cluster bootstrap coinciden en la clasificación al 5 % para 6 de 6 coeficientes y al 10 % para 6 de 6. Las tendencias lineales por país cambian el signo de RENTS x INST en 2 de 2 modelos. La exclusión por influencia registra 0 reversiones entre 4 coeficientes evaluados y leave-one-country-out registra 0.

Los efectos marginales de RENTS son negativos en 5 de 5 puntos observados de INST para ECI y en 5 de 5 para DIVX. Sus intervalos excluyen cero en 3 puntos para ECI y 4 para DIVX.

## La estabilidad comparable difiere entre términos

La columna de signos usa solo M3, tendencias, exclusión por influencia y leave-one-country-out. El cambio de 2014 se informa aparte porque corresponde a otro estimando.

| Modelo | Término | Coeficiente M3 | Signos comparables | Desvío máximo (%) | p bootstrap | p cambio 2014 | p cambio conjunto 2014 |
|---|---|---:|---:|---:|---:|---:|---:|
| ECI | RENTS | -0.009795 | 3/3 |     55.05 | 0.040104 | 0.918232 | 0.343224 |
| ECI | INST |  0.266705 | 1/1 |     92.34 | 0.090609 | 0.546615 | 0.343224 |
| ECI | RENTS x INST | -0.005199 | 2/3 |    111.31 | 0.209121 | 0.312612 | 0.343224 |
| DIVX | RENTS | -0.003536 | 3/3 |     26.64 | 0.020702 | 0.350120 | 0.058521 |
| DIVX | INST |  0.017472 | 1/1 |    159.77 | 0.576758 | 0.694424 | 0.058521 |
| DIVX | RENTS x INST |  0.000948 | 2/3 |    127.00 | 0.476648 | 0.018457 | 0.058521 |

El desvío porcentual puede ser grande cuando el coeficiente principal está próximo a cero. Por eso debe leerse junto con el rango de coeficientes y no como una puntuación de robustez.

## Efectos marginales dentro del soporte institucional

| Modelo | Rango observado de INST | Rango del efecto marginal | Puntos negativos | IC que excluyen cero |
|---|---:|---:|---:|---:|
| ECI | [  -1.239,    0.915] | [-0.014555, -0.003352] | 5/5 | 3/5 |
| DIVX | [  -1.239,    0.915] | [-0.004711, -0.002668] | 5/5 | 4/5 |

Estos efectos marginales combinan RENTS y RENTS x INST. No deben interpretarse como el coeficiente aislado de RENTS ni extrapolarse fuera de P10-P90 de INST.

## Alcance, muestra y definiciones

- Muestra principal: 1044 observaciones, 49 países y 23 años efectivos entre 1996 y 2021.
- M3, tendencias y bootstrap conservan la muestra común.
- La exclusión por influencia modifica el número de observaciones; leave-one-country-out usa 48 países en cada repetición.
- Los resultados son asociaciones condicionadas con efectos fijos por país y año, no efectos causales.

## Método de síntesis

La matriz compara signo, magnitud e incertidumbre solo cuando el estimando es comparable. El bootstrap se trata como inferencia alternativa sobre el mismo coeficiente; el corte de 2014 como cambio temporal; y los márgenes como derivadas evaluadas en valores observados de INST. Se usan tablas porque un gráfico común mezclaría escalas y estimandos diferentes.

## Limitaciones e incertidumbre

- INST no fue evaluada en la exclusión por influencia ni en leave-one-country-out; sus celdas permanecen vacías.
- Las pruebas individuales del corte de 2014 no sustituyen la prueba conjunta preespecificada.
- La coincidencia de significancia entre métodos no demuestra estabilidad de magnitud ni causalidad.
- No se seleccionó ninguna especificación según su valor p.

## Siguiente paso recomendado

Usar estas matrices como insumo para la comparación formal M1-M3 del archivo 05. La redacción debe distinguir resultados centrales, sensibilidades y cambios de estimando antes de incorporarse al TFM.

## Preguntas abiertas

1. ¿La estabilidad de RENTS e INST se conserva al comparar M1, M2 y M3 sobre la misma muestra?
2. ¿Las diferencias entre ECI y DIVX reflejan escala, precisión o canales estructurales distintos?
3. ¿Las extensiones por petróleo-gas y minería modifican la lectura del resultado agregado?
