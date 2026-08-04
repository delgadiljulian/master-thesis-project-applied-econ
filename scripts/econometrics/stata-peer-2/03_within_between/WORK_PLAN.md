# Plan de trabajo — descomposición within-between de Mundlak

## 1. Función

Este módulo separa dos fuentes distintas de asociación:

- cambios de RENTS e INST dentro de cada país a lo largo del tiempo;
- diferencias persistentes en los niveles medios de RENTS e INST entre países.

Sustituye al antiguo plan IV/2SLS. Es una extensión descriptiva del análisis de
panel y no una estrategia de identificación causal.

## 2. Razón para incluirlo

Los diagnósticos muestran que una parte importante de la variación de ECI,
DIVX, RENTS e INST ocurre entre países. TWFE utiliza correctamente la variación
dentro de cada país, pero no cuantifica por separado la relación estructural
entre países.

Una especificación correlated random effects, basada en Mundlak, permite
mostrar ambos componentes sin adoptar el supuesto restrictivo de efectos
aleatorios simples no correlacionados con los regresores.

## 3. Descomposición

Para cada variable temporal X:

X_within(i,t) = X(i,t) - media_i(X)

X_between(i) = media_i(X)

La equivalencia técnica inicial utilizará P = RENTS × INST y descompondrá P en
su desviación respecto de la media del país y su media por país:

Y(i,t) = beta_W RENTS_within(i,t)
       + gamma_W INST_within(i,t)
       + delta_W P_within(i,t)
       + beta_B RENTS_between(i)
       + gamma_B INST_between(i)
       + delta_B P_between(i)
       + efectos de año
       + efecto aleatorio de país
       + error(i,t).

Después de verificar equivalencia con TWFE, la interpretación sustantiva de la
moderación utilizará la expansión completa de RENTS y INST:

- RENTS_within × INST_within;
- RENTS_within × INST_between;
- RENTS_between × INST_within;
- RENTS_between × INST_between.

Esta expansión evita atribuir a una única interacción diferencias que pueden
provenir de la moderación temporal dentro del país o del nivel institucional
estructural entre países. Los resultados se comunicarán mediante efectos
marginales, no mediante la lectura aislada de los cuatro coeficientes.

## 4. Interpretación

- beta_W: asociación entre un cambio de RENTS respecto del promedio histórico
  del país y el cambio de Y.
- beta_B: asociación entre el nivel medio de RENTS de un país y su nivel medio
  de Y frente a otros países.
- beta_W y beta_B pueden diferir sin que uno invalide al otro.

El componente within debe coincidir con TWFE cuando se usan la misma muestra,
variables y ponderación implícita. El componente between sigue expuesto a
confusión por características estructurales no observadas y se describe como
comparación, no como efecto.

## 5. Secuencia de modelos

### WB0 — equivalencia técnica

- Descomponer todos los regresores de la especificación focal.
- Estimar CRE con efectos de año y errores agrupados por país.
- Comparar exactamente los coeficientes within con M1 de TWFE.

Una diferencia no explicada por muestra o parametrización bloquea el módulo.

### WB1 — focal

- RENTS within y between.
- INST within y between.
- Interacción técnica descompuesta y expansión sustantiva de cuatro términos.
- Efectos de año.

### WB2 — bloques parsimoniosos

Añadir cada bloque de controles por separado, descomponiendo todas sus
variables en componentes within y between. No se mezclan regresores sin
descomponer con medias de otros regresores.

### WB3 — desagregación por recurso

Separar hidrocarburos y minería/carbón en componentes within y between. Se
estimará únicamente después de validar WB0–WB2.

## 6. Muestra y panel desbalanceado

Las medias por país se calculan exclusivamente sobre la muestra de estimación
congelada. Se registran:

- número de años que aporta cada país a cada media;
- primer y último año observado;
- países con ventanas cortas o discontinuas;
- cambios de composición entre especificaciones.

La estimación principal usa la misma muestra común que la comparación TWFE.
Como sensibilidad, se exigirá un mínimo predefinido de años por país. Ese
umbral se fija antes de revisar coeficientes.

## 7. Controles de dimensionalidad

La dimensión between efectiva es el número de países, no las 1.044
observaciones. Por ello:

- WB1 será la especificación sustantiva principal;
- WB2 incorporará un bloque por vez;
- no se estimará automáticamente una columna con todos los componentes within
  y between de los 17 regresores;
- se reportarán VIF y condición de la matriz para los componentes between;
- una estimación inestable se descarta en lugar de reducir controles por
  significancia.

## 8. Inferencia y pruebas

- errores estándar agrupados por país;
- wild cluster bootstrap para componentes focales;
- prueba beta_W = beta_B;
- prueba conjunta de medias de Mundlak;
- comparación beta_W con TWFE;
- leave-one-country-out de los componentes between;
- gráficos separados de asociaciones within y between;
- sensibilidad a ventanas de observación y países dominantes.

El rechazo de beta_W = beta_B indica que mezclar ambas fuentes de variación
sería engañoso; no establece causalidad.

## 9. Reglas de aceptación

El módulo se incorpora al TFM si:

1. WB0 reproduce los coeficientes within de TWFE;
2. las medias se construyen sobre una muestra transparente;
3. la dimensión between permite inferencia interpretable;
4. los resultados no dependen de uno o dos países;
5. las interacciones se interpretan mediante efectos marginales;
6. el texto separa explícitamente asociación within y between.

Si los componentes between son inestables, se reporta solo la equivalencia
within o se excluye el módulo completo.

## 10. Scripts previstos

1. `01_within_between_data.do`
2. `02_mundlak_models.do`
3. `03_equivalence_and_sensitivity.do`
4. `run_stata_peer_2.ps1`
5. `run_stata_peer_2.cmd`

## 11. Outputs previstos

Ruta:

`outputs/econometrics/stata-peer-2/03_within_between/`

- `00_design/within_between_variable_register.csv`;
- `01_sample/within_between_sample_summary.csv`;
- `02_diagnostics/mean_coverage_by_country.csv`;
- `02_diagnostics/between_collinearity.csv`;
- `03_equivalence/twfe_cre_equivalence.csv`;
- `04_eci/eci_within_between_coefficients.csv`;
- `05_divx/divx_within_between_coefficients.csv`;
- `06_heterogeneity/resource_within_between.csv`;
- `07_stability/between_leave_one_out.csv`;
- `08_final/within_between_acceptance_decision.csv`;
- `logs/`.

## 12. Controles de avance

1. **WB-A — muestra:** congelar y auditar las medias por país.
2. **WB-B — equivalencia:** reproducir TWFE dentro de CRE.
3. **WB-C — focal:** estimar WB1.
4. **WB-D — bloques:** ejecutar WB2 sin saturar la dimensión between.
5. **WB-E — heterogeneidad:** estimar WB3 si procede.
6. **WB-F — estabilidad:** bootstrap y exclusión de países.
7. **WB-G — TFM:** incorporar o excluir formalmente.

## 13. Estado

**Diseño aprobado; scripts y estimaciones pendientes.**

## 14. Referencia metodológica de partida

- [Mundlak](https://ideas.repec.org/a/ecm/emetrp/v46y1978i1p69-85.html):
  correlated random effects y separación entre variación temporal dentro de
  unidades y diferencias persistentes entre unidades.
