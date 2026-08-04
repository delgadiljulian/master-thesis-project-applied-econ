# Plan de trabajo — TWFE principal

## 1. Función

TWFE es el estimador principal de la tesis. Identifica asociaciones a partir de
la variación temporal dentro de cada país, absorbiendo características
permanentes de los países y shocks comunes de cada año.

Las estimaciones no se interpretan como efectos causales. El parámetro focal es
una asociación condicional dentro del país.

## 2. Resultados y variables focales

Se estiman dos ecuaciones:

1. ECI, resultado principal de sofisticación exportadora.
2. DIVX = 1 - HHI, resultado complementario de diversificación.

Variables focales:

- RENTS;
- INST;
- RENTS × INST.

La extensión sectorial sustituye RENTS por:

- RENTS_OIL_GAS;
- RENTS_MINING.

## 3. Muestra

- Universo fijo: 55 países y 1996–2021.
- Grilla maestra: 1.430 país-años.
- Muestra completa vigente: 1.044 observaciones, 49 países y un promedio de
  21,3 períodos por país.
- Panel desbalanceado por disponibilidad de regresores.
- Sin imputación ni interpolación.

Cada especificación exportará observaciones, países, años y pérdidas por
faltantes. Las comparaciones se presentarán tanto con la muestra disponible de
cada columna como sobre una muestra común.

## 4. Secuencia de modelos

### M0 — descriptivo

- Variación total, between y within.
- Cobertura por país, año y variable.
- Correlaciones y observaciones influyentes.

### M1 — focal

Y(i,t) = beta1 RENTS(i,t)
       + beta2 INST(i,t)
       + beta3 RENTS(i,t) × INST(i,t)
       + efecto país
       + efecto año
       + error(i,t).

Esta será la columna de referencia para la asociación total condicionada por
efectos fijos.

### M2 — bloques teóricos

Se parte de M1 y se añade un bloque por vez:

1. abundancia: OILPC, GASPC y COALPC;
2. estructura exportadora: HHI, PEXP y FEXP;
3. macroeconomía: VOL y RER;
4. capacidades: HUMCAP, INNOV y NET;
5. economía y finanzas: log(GDPPC), GOVCONS y FIN.

HHI no se incorpora cuando Y = DIVX.

### M3 — completa

Reúne todos los bloques. Corresponde a la especificación ya estimada y se
interpreta como una asociación directa altamente condicionada. No reemplaza M1
como referencia porque algunas covariables pueden ser canales posteriores a
las rentas.

### M4 — desagregada

Sustituye RENTS por rentas de hidrocarburos y de minería/carbón. Las
interacciones con INST se incorporan junto con todos sus términos
constitutivos. La igualdad entre componentes se contrasta formalmente.

## 5. Decisiones previas sobre controles

Antes de ampliar los scripts se creará una tabla con:

| Variable | Bloque | Papel propuesto | Riesgo de sobrecontrol |
|---|---|---|---|
| RENTS | Focal | Exposición | No aplica |
| INST | Institucional | Moderador | Puede responder a rentas |
| Abundancia física | Abundancia | Condición estructural | Bajo dentro del período |
| HHI, PEXP, FEXP | Estructura | Posible canal | Alto |
| VOL, RER | Macroeconomía | Posible canal | Medio/alto |
| HUMCAP, INNOV, NET | Capacidades | Posible canal | Medio/alto |
| PIB, GOVCONS, FIN | Controles | Confusor o canal | Debe justificarse |

Esta clasificación determina la interpretación de cada columna. No se
eliminan variables del modelo completo ya validado, pero tampoco se usa esa
columna como única evidencia.

## 6. Inferencia principal

- Efectos fijos por país y año.
- Errores estándar agrupados por país.
- Wild cluster bootstrap para RENTS, INST, interacción y términos sectoriales.
- Efectos marginales de RENTS en percentiles predefinidos de INST.
- Pruebas conjuntas para términos principales e interacciones.

La agrupación por país responde a heterocedasticidad y correlación serial
dentro de cada panel. El bootstrap atiende la cantidad moderada de 49
conglomerados.

## 7. Diagnósticos y sensibilidades

### Ya validados

- heterocedasticidad entre países;
- autocorrelación de primer orden;
- ausencia de evidencia residual de dependencia transversal;
- VIF sobre variación within;
- verificación xtreg frente a reghdfe;
- wild cluster bootstrap;
- leave-one-country-out;
- observaciones influyentes;
- transformaciones de abundancia;
- desagregación de rentas.

### Por añadir

1. Comparación completa de M1–M3 con muestras disponibles.
2. Comparación M1–M3 sobre muestra común.
3. Tabla de cambio del coeficiente focal entre bloques.
4. Tendencias lineales específicas por país como sensibilidad severa.
5. Driscoll–Kraay solo como contraste secundario.

No se eliminarán países o años por mejorar significancia. Toda exclusión debe
responder a una regla previamente documentada.

## 8. Scripts

### Existentes

1. `01_data_preparation_diagnostics.do`
2. `02_econometric_models.do`
3. `03_resource_disaggregation.do`
4. `run_stata_peer_2.ps1`
5. `run_stata_peer_2.cmd`

### Ampliación prevista

La secuencia M1–M3 debe incorporarse en `02_econometric_models.do` mediante una
sección nueva que preserve los nombres y archivos vigentes. Los resultados ya
validados no se sobrescriben hasta comparar coeficientes y muestras.

## 9. Outputs

Ruta única:

`outputs/econometrics/stata-peer-2/01_twfe_main/`

Además de las salidas existentes, se crearán:

- `00_design/control_role_classification.csv`;
- `03_eci/eci_nested_specifications.csv`;
- `04_divx/divx_nested_specifications.csv`;
- `05_stability/common_sample_comparison.csv`;
- `05_stability/country_trend_sensitivity.csv`;
- `05_stability/driscoll_kraay_sensitivity.csv`;
- `06_final/twfe_model_hierarchy_decision.csv`.

## 10. Controles de avance

1. **TWFE-A — muestra:** verificar las 1.044 observaciones actuales y las
   muestras de M1–M3.
2. **TWFE-B — controles:** cerrar la clasificación antes de estimar bloques.
3. **TWFE-C — modelos:** ejecutar M1–M3 para ECI y DIVX.
4. **TWFE-D — comparación común:** repetir en muestra común.
5. **TWFE-E — inferencia:** bootstrap y pruebas conjuntas.
6. **TWFE-F — heterogeneidad:** conservar y auditar M4.
7. **TWFE-G — TFM:** seleccionar tablas y actualizar el texto.

## 11. Estado

**Estimador principal aprobado.**

La especificación completa, la desagregación y sus pruebas de estabilidad ya
están implementadas. Falta incorporar la jerarquía M1–M3 para que el modelo
completo no sea la única referencia sustantiva.

