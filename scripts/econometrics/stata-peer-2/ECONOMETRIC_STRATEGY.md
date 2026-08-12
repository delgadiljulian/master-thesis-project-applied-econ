# Estrategia econométrica revisada del panel

## 1. Decisión metodológica

La tesis no utilizará tres estimadores por obligación. La estrategia se ajusta
a la pregunta de investigación, al carácter observacional del diseño y a la
estructura efectiva del panel:

| Jerarquía | Módulo | Función | Interpretación |
|---|---|---|---|
| Principal | TWFE jerarquizado | Asociaciones dentro de cada país | Evidencia central |
| Auxiliar, no integrado al TFM vigente | FE temporal | Orden temporal de la exposición en muestras propias | Asociación separada; no sustituye ni robustece directamente el TWFE |

System GMM e IV/2SLS se retiran del plan operativo. Tampoco se adoptan como
estimadores principales CCE, PCSE, panel ARDL o efectos aleatorios simples.

## 2. Por qué se retiran GMM e IV

### System GMM

System GMM responde principalmente a paneles dinámicos cortos y anchos con una
variable dependiente rezagada y ausencia de buenos instrumentos externos. Ese
no es el diseño central de esta tesis:

- la muestra efectiva actual tiene 49 países y un promedio de 21,3 años;
- la pregunta sustantiva no exige un modelo con variable dependiente rezagada;
- el objetivo declarado es estimar asociaciones condicionales, no parámetros
  causales dinámicos;
- la implementación anterior produjo más instrumentos que países y pruebas de
  Hansen poco informativas;
- clasificar casi todos los regresores como exógenos no resuelve la
  endogeneidad de RENTS ni de la interacción.

Por estas razones, reducir instrumentos no basta para justificar GMM. Se
retira del TFM y se conserva únicamente como antecedente descartado.

### IV/2SLS

La base actual no contiene un instrumento externo defendible. Los rezagos de
RENTS, INST, VOL o sus interacciones no satisfacen automáticamente la
restricción de exclusión. Un instrumento basado en precios internacionales y
exposición histórica requeriría datos nuevos y enfrentaría una ruta directa
plausible hacia ECI y DIVX mediante exportaciones, tipo de cambio e inversión.

Sin una fuente externa, una primera etapa fuerte y una exclusión convincente,
IV produciría una apariencia causal que el diseño no puede sostener. Se retira
del plan en vez de mantenerlo como promesa metodológica.

## 3. Qué pregunta responde cada módulo

### 3.1. TWFE jerarquizado

Pregunta: cuando cambian las rentas extractivas dentro de un mismo país, ¿cómo
cambian ECI y DIVX, una vez absorbidas las diferencias permanentes entre países
y los shocks comunes de cada año?

Estimando principal:

- asociación dentro del país entre RENTS y cada resultado;
- moderación de esa asociación por INST;
- aporte de los canales extractivos, productivos y macroeconómicos.

### 3.2. FE temporal (paquete auxiliar separado)

Pregunta: ¿la asociación aparece contemporáneamente, con rezago o al considerar
una exposición acumulada reciente?

Este módulo utiliza valores rezagados y promedios móviles de RENTS e INST,
además de una prueba con adelantos. No incluye una variable dependiente
rezagada ni pretende corregir endogeneidad mediante instrumentos internos.
Sus muestras no coinciden con la muestra congelada del núcleo; por ello no se
presenta en el TFM vigente como una robustez directa ni como evidencia central.

## 4. Secuencia principal de especificaciones

Para ECI y DIVX se utilizarán tres especificaciones con RENTS totales:

1. **Estructura extractiva y exportadora:** canal institucional, abundancia
   física, estructura exportadora y log(GDPPC).
2. **Capacidades y estabilidad:** canal institucional, macroeconomía,
   capacidades productivas y controles económicos, fiscales y financieros.
3. **Completa:** todos los canales anteriores en el TWFE original.

Los dos primeros modelos responden preguntas temáticas paralelas. El tercero
permite observar qué asociaciones permanecen al considerar todos los canales.
La reducción de un coeficiente entre modelos no demuestra mediación.

## 5. Reglas comunes

- Panel base: 55 países, 1996–2021 y 1.430 llaves país-año.
- Muestra completa vigente: 1.044 observaciones y 49 países para las dos
  ecuaciones completas; cada nueva columna debe volver a documentar su muestra.
- Sin imputación ni interpolación.
- ECI es el resultado principal y DIVX el complementario.
- HHI se excluye siempre del modelo DIVX porque DIVX = 1 - HHI.
- Toda interacción conserva sus términos constitutivos.
- Los modelos se comparan en su muestra disponible y en una muestra común.
- Los bloques se fijan antes de observar coeficientes.
- No se seleccionan rezagos, controles o transformaciones por significancia.
- Todos los resultados se describen como asociaciones.

## 6. Inferencia y diagnósticos

Los diagnósticos vigentes muestran heterocedasticidad y correlación serial,
pero no evidencia residual de dependencia transversal después de los efectos
de año. Por ello:

- inferencia principal: errores estándar agrupados por país;
- control por 49 conglomerados: wild cluster bootstrap;
- estabilidad: exclusión sucesiva de países y revisión de observaciones
  influyentes;
- Driscoll–Kraay: solo se reconsiderará si futuros diagnósticos detectan
  dependencia transversal residual sustantiva;
- tendencias lineales específicas por país: sensibilidad exigente, no columna
  base;
- CCE: solo se reconsiderará si nuevos diagnósticos detectan dependencia
  transversal sustantiva.

## 7. Arquitectura de carpetas

```text
scripts/econometrics/stata-peer-2/
  ECONOMETRIC_STRATEGY.md
  01_twfe_main/
    WORK_PLAN.md
    01_data_preparation_diagnostics.do
    02_twfe_extractive_export_structure.do
    03_twfe_capabilities_stability.do
    04_twfe_full.do
    05_twfe_model_comparison.do
    06_twfe_oil_gas_models.do
    07_twfe_mining_models.do
    08_twfe_resource_disaggregated_full.do
    run_stata_peer_2.ps1
    run_stata_peer_2.cmd
  02_temporal_fe/
    README.md  # sensibilidades asociativas separadas; no LP, VAR/VEC ni ECM
    WORK_PLAN.md
    01_temporal_data_and_samples.do
    02_lagged_and_cumulative_models.do
    03_leads_changes_and_sensitivity.do
```

Las salidas replican exactamente estos dos nombres dentro de
`outputs/econometrics/stata-peer-2/`.

## 8. Estado y siguiente fase

1. El núcleo TWFE 01--05 está implementado y validado sobre la muestra común.
2. Las extensiones 06 y 07 están implementadas para petróleo y gas y minería.
3. El archivo 08 se conserva como contraste desagregado formal.
4. El módulo temporal está completo como paquete auxiliar, pero no se integra
   al TFM vigente ni se interpreta como robustez directamente comparable con
   la muestra TWFE congelada.
5. No se agregarán especificaciones antes de cerrar la comparación y redactar
   los resultados disponibles, sin votar resultados por significancia.

## 9. Criterio final para el TFM

El TFM debe sostener sus conclusiones en TWFE. El paquete temporal permanece
separado hasta que exista una decisión expresa y una reconciliación de muestra;
en ningún caso convierte el estudio en causal. No se incorporarán estimadores
adicionales por obligación ni se reemplazará el núcleo por GMM o IV.

## 10. Referencias metodológicas de partida

- [Roodman](https://doi.org/10.1111/j.1468-0084.2008.00542.x), sobre
  los riesgos de proliferación de instrumentos y la adecuación de GMM a
  paneles cortos y anchos.
- [Driscoll y Kraay](https://direct.mit.edu/rest/article/80/4/549/57586/Consistent-Covariance-Matrix-Estimation-with), sobre inferencia robusta frente
  a dependencia temporal y transversal cuando la dimensión temporal es
  suficientemente informativa.
