# Plan de trabajo — efectos fijos y orden temporal

## 0. Estado respecto del TFM vigente

Este paquete está implementado como evidencia temporal asociativa separada. No
forma parte de los resultados centrales del TFM ni es una robustez directamente
comparable con `01_twfe_main`: sus muestras propias difieren de la muestra
congelada de 1.044 observaciones y 49 países. Su incorporación al manuscrito
exigiría autorización específica y una reconciliación previa de muestra y
especificación.

No contiene cointegración, ECM, VAR/VEC, Granger, proyecciones locales, filtro
HP ni análisis de shocks; tampoco identifica relaciones causales.

## 1. Función

Este módulo examina si la relación entre rentas extractivas y transformación
estructural es contemporánea, rezagada o acumulada. Sustituye al antiguo plan
System GMM.

No instrumenta variables, no incluye la variable dependiente rezagada y no
afirma causalidad. Su propósito es verificar el orden temporal y la estabilidad
de la asociación TWFE.

## 2. Justificación

ECI y DIVX cambian gradualmente, mientras las rentas pueden responder con mayor
rapidez al ciclo de precios. Una especificación exclusivamente contemporánea
puede omitir efectos demorados o mezclar ajustes que ocurren en distintos
horizontes.

El panel efectivo ofrece unos 21 años por país, suficiente para estudiar
rezagos cortos sin recurrir a una matriz extensa de instrumentos.

## 3. Principios

- Rezagos fijados antes de observar resultados.
- Horizonte corto, acorde con 1996–2021.
- Modelos focales parsimoniosos antes de añadir controles.
- Misma definición de ECI, DIVX, RENTS e INST que en TWFE.
- Efectos fijos de país y año.
- Errores agrupados por país y wild cluster bootstrap.
- Comparación sobre una muestra común.
- Ningún rezago se selecciona por su p-valor.

## 4. Secuencia de modelos

### T0 — referencia contemporánea

Réplica focal conceptual de M1 del módulo principal; no sustituye la
jerarquía completa de modelos contemporáneos:

Y(i,t) = RENTS(i,t) + INST(i,t) + RENTS(i,t) × INST(i,t)
       + efectos de país y año + error(i,t).

### T1 — exposición rezagada un año

Utiliza RENTS, INST y su interacción observados en t-1. Este será el modelo
temporal principal porque establece precedencia sin reducir excesivamente la
muestra.

### T2 — exposición acumulada de tres años

Utiliza el promedio móvil retrospectivo t, t-1 y t-2 de cada término focal. La
construcción exige tres observaciones consecutivas y no cruza vacíos del panel.

Este modelo resume exposición reciente y evita interpretar por separado
coeficientes de rezagos altamente correlacionados.

### T3 — rezagos distribuidos 0–2

Incluye RENTS en t, t-1 y t-2 y reporta:

- cada coeficiente;
- suma acumulada;
- prueba conjunta de los tres términos.

La interacción se estudiará primero en T1 y T2. Solo se ampliará a los tres
rezagos en T3 si el VIF temporal y la matriz de varianzas siguen siendo
informativos.

### T4 — adelanto placebo

Añade RENTS en t+1 a una especificación focal predefinida. Una asociación con
el adelanto es una alerta compatible con anticipación, persistencia o
causalidad inversa; no constituye por sí sola una prueba de invalidez o
exogeneidad.

### T5 — cambios anuales

Como sensibilidad se estimará:

delta Y(i,t) = beta delta RENTS(i,t)
             + gamma delta INST(i,t)
             + delta año
             + error(i,t).

Este modelo estudia cambios de corto plazo. Se interpretará con cautela porque
la diferenciación puede amplificar error de medición.

## 5. Tratamiento de controles

La secuencia temporal se estima primero con los términos focales. Después se
añaden únicamente bloques cuya temporalidad pueda justificarse.

- No se controlará simultáneamente por una variable contemporánea cuando sea
  un posible resultado del cambio previo en RENTS.
- Los controles rezagados deben construirse con la misma regla temporal.
- El modelo completo de TWFE no se trasladará automáticamente.
- HHI nunca entra en la ecuación DIVX.

## 6. Muestras

Se crearán indicadores separados:

- muestra T0;
- muestra T1 con un rezago válido;
- muestra T2/T3 con tres años consecutivos;
- muestra común T0–T3.

Para cada muestra se reportarán observaciones, países, años inicial/final,
pérdidas por rezago y países excluidos. Los huecos no se rellenan ni se tratan
como años consecutivos.

## 7. Diagnósticos

- correlación entre RENTS y sus rezagos;
- VIF temporal para T3;
- prueba conjunta y suma de rezagos;
- antecedente de autocorrelación residual documentado por el TWFE principal;
- wild cluster bootstrap de términos focales y suma acumulada;
- leave-one-country-out para T1 y T2;
- comparación de signos y magnitudes con T0, la réplica focal de M1;
- sensibilidad a tendencias lineales específicas por país.

## 8. Reglas de aceptación

El módulo se incorpora al TFM si:

1. conserva una cantidad suficiente de países y períodos;
2. la construcción de rezagos respeta la continuidad temporal;
3. la inferencia no depende de un único país;
4. T3 no presenta colinealidad que vuelva ininterpretables los rezagos;
5. la narrativa distingue asociación contemporánea, rezagada y acumulada;
6. los adelantos se presentan como falsificación informativa, no como prueba
   causal definitiva.

Si T3 falla por colinealidad, se conservan T1 y T2. No se cambia el horizonte
para obtener significancia.

## 9. Scripts previstos

1. `01_temporal_data_and_samples.do`
2. `02_lagged_and_cumulative_models.do`
3. `03_leads_changes_and_sensitivity.do`
4. `run_stata_peer_2.ps1`
5. `run_stata_peer_2.cmd`

## 10. Outputs previstos

Ruta:

`outputs/econometrics/stata-peer-2/02_temporal_fe/`

- `00_design/temporal_specification_register.csv`;
- `01_sample/temporal_sample_summary.csv`;
- `02_diagnostics/lag_correlation_and_vif.csv`;
- `03_eci/eci_temporal_coefficients.csv`;
- `03_eci/eci_t1_own.ster` y `eci_t2_own.ster`;
- `04_divx/divx_temporal_coefficients.csv`;
- `04_divx/divx_t1_own.ster` y `divx_t2_own.ster`;
- `05_cumulative/cumulative_effect_tests.csv`;
- `05_cumulative/temporal_wild_cluster_bootstrap.csv`;
- `06_placebo/lead_placebo_tests.csv`;
- `07_changes/first_difference_results.csv`;
- `08_stability/temporal_leave_one_out.csv`;
- `08_stability/temporal_leave_one_out_summary.csv`;
- `08_stability/country_trend_sensitivity.csv`;
- `08_stability/eci_t1_country_trends.ster` y
  `eci_t2_country_trends.ster`;
- `08_stability/divx_t1_country_trends.ster` y
  `divx_t2_country_trends.ster`;
- `09_final/temporal_model_coefficients.csv`;
- `09_final/02_models_handoff.csv`;
- `09_final/02_results_manifest.csv`;
- `09_final/temporal_acceptance_decision.csv`;
- `09_final/temporal_results_manifest.csv`;
- `logs/`.

## 11. Controles de avance

1. **TEMP-A — diseño:** congelar T0–T5.
2. **TEMP-B — rezagos:** validar continuidad y muestras.
3. **TEMP-C — modelos:** estimar ECI y DIVX.
4. **TEMP-D — inferencia:** bootstrap, sumas y pruebas conjuntas.
5. **TEMP-E — estabilidad:** placebo, cambios y exclusión de países.
6. **TEMP-F — TFM:** incorporar o excluir formalmente.

## 12. Estado

**Diseño aprobado. Los archivos `01_temporal_data_and_samples.do` y
`02_lagged_and_cumulative_models.do` están completos y validados en Stata 17.
Los diagnósticos descartan T3X y restringen T3 básico a su suma y prueba
conjunta por colinealidad. La inferencia conserva errores agrupados por país y
añade 10 contrastes wild cluster bootstrap con 9.999 repeticiones. La sección
13 exporta 52 coeficientes, valida 11 productos y deja cuatro estimaciones
guardadas para el archivo 03. La sección 14 también está implementada y valida
de manera independiente el panel, las muestras, el manifiesto, los ocho
contrastes de traspaso y las cuatro estimaciones guardadas. La sección 15 estima
el adelanto placebo T4 sobre una muestra común para el bloque base y el modelo
aumentado; no detecta alerta estadística en ECI ni en DIVX con los umbrales
predefinidos. La sección 16 estima T5 en primeras diferencias con efectos de
año e inferencia agrupada por país; los cambios de RENTS presentan una
asociación negativa con los cambios de ECI y DIVX, interpretada exclusivamente
como evidencia de corto plazo. La sección 17 completa 212 estimaciones
leave-one-country-out: los cuatro coeficientes de RENTS conservan el signo en
las 53 exclusiones; los cambios de signo se limitan a las interacciones no
significativas de DIVX. La sección 18 estima T1 y T2 con 52 tendencias lineales
nacionales identificadas en cada modelo, manteniendo sin cambios las muestras
de 53 países. Ninguno de los ocho términos focales cambia de signo; cuatro
cambian su clasificación al 5 % y cuatro se desplazan más de un error estándar
del modelo base, por lo que esta prueba se conserva como sensibilidad y no como
reemplazo automático de la especificación principal. La sección 19 reconcilia
las reglas TEMP-A--TEMP-F y exporta una matriz de siete diseños sin seleccionar
por significancia: T1 queda como resultado temporal principal; T2 y T5 como
sensibilidades; T3 solo mediante suma y prueba conjunta en el apéndice; T4 como
diagnóstico de falsificación; T3X se excluye por colinealidad; y T0 permanece
como referencia sin duplicar el TWFE. La decisión global es incorporar el
módulo temporal con cautelas explícitas y lenguaje asociativo. La sección 20
completa el cierre mediante un manifiesto integral que reabre y reconcilia 33
productos previos: 20 tablas CSV, el panel temporal de 1.430 observaciones y 12
estimaciones guardadas. El
manifiesto final también fue reabierto y validado, y la decisión metodológica
conserva a T1 como especificación temporal principal sin seleccionar horizontes
por significancia. Los tres archivos `.do` y las secciones 1 a 20 del módulo
temporal están completos y validados en Stata 17.**
