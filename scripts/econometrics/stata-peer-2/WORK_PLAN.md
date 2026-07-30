# Plan de trabajo econométrico en Stata — implementación candidata Codex

## 1. Objetivo

Implementar de forma reproducible en **Stata 17 MP** las dos ecuaciones
econométricas definidas en el capítulo metodológico de la tesis y su extensión
por tipo de renta:

1. **Modelo principal:** `ECI` como variable dependiente.
2. **Modelo complementario:** `DIVX = 1 - HHI` como variable dependiente,
   excluyendo `HHI` de los regresores.
3. **Extensión desagregada:** distinguir `RENTS_OIL_GAS` —petróleo y gas— de
   `RENTS_MINING` —carbón, minerales y metales— en ambos modelos.

Las estimaciones se interpretarán como asociaciones condicionales dentro de un
diseño observacional. No se presentarán como efectos causales.

## 2. Principios y límites

- Utilizar exclusivamente el panel maestro cerrado:
  `data/processed/00_master_panel/master_panel_country_year.dta`.
- Tratar el panel maestro como insumo de solo lectura.
- No modificar datos `raw`, datos procesados ni el constructor del panel.
- No imputar ni interpolar observaciones faltantes.
- No crear proxies, interacciones, submuestras o modelos no previstos.
- Mantener `RENTS × INST` como única interacción de la etapa agregada.
- No incorporar las interacciones de los componentes desagregados hasta cerrar
  expresamente el Control G.
- Estimar efectos fijos por país y por año.
- Excluir `HHI` únicamente del modelo `DIVX`.
- Desarrollar y validar el análisis sección por sección.
- No incorporar resultados al TFM antes de su revisión conjunta.

## 3. Ubicación de la implementación

Esta candidatura utiliza tres archivos de análisis consecutivos:

```text
scripts/econometrics/stata-peer-2/
  01_data_preparation_diagnostics.do
  02_econometric_models.do
  03_resource_disaggregation.do
  WORK_PLAN.md
```

El archivo `01_data_preparation_diagnostics.do` contiene las secciones 1 a 4:
configuración, validación del panel, preparación de muestras y diagnósticos. El
archivo `02_econometric_models.do` contiene las secciones 5 a 8: modelos ECI y
DIVX, estabilidad, efectos marginales y exportación final. El archivo
`03_resource_disaggregation.do` continúa con las secciones 9 a 14 y estará
dedicado exclusivamente a distinguir las rentas de hidrocarburos de las rentas
de carbón, minerales y metales.

La división evita que un único `.do` se vuelva difícil de revisar. No altera la
secuencia metodológica. El archivo 03 conservará los modelos agregados como
referencia y no los sustituirá.

## 4. Reproducibilidad y dependencias

Los archivos pueden ejecutarse desde cualquier directorio de trabajo de Stata,
respetando este orden:

```stata
do "C:/Users/usuario/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-2/01_data_preparation_diagnostics.do"
do "C:/Users/usuario/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-2/02_econometric_models.do"
do "C:/Users/usuario/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-2/03_resource_disaggregation.do"
```

Para ejecutarlos desde PowerShell se utilizará el ejecutor incluido:

```powershell
.\scripts\econometrics\stata-peer-2\run_stata_peer_2.cmd -Stage all
```

Este ejecutor guarda el registro automático del modo batch únicamente en
`outputs/econometrics/stata-peer-2/logs/batch/`. Los logs analíticos de los
archivos 01 y 02 permanecen en `outputs/econometrics/stata-peer-2/logs/`; el
del archivo 03 se guarda dentro de
`07_resource_disaggregation/logs/`. Ninguna ejecución desde terminal debe
crear archivos `.log` en la raíz ni en la carpeta de los scripts.

El ejecutor fue validado con las etapas 01 y 02 el 29 de julio de 2026. Ambas
terminaron correctamente y sus registros batch quedaron en la ruta prevista.
La etapa 03 ya forma parte del ejecutor porque contiene una inicialización y
las secciones 9 a 11 operativas. Se validó de forma aislada mediante
`-Stage 03`; `-Stage all` respeta el orden 01, 02 y 03.

Cada archivo localiza la raíz del proyecto en este orden:

1. el directorio de trabajo actual de Stata y hasta cinco directorios padre;
2. `C:/Users/<usuario>/GitHub/master-thesis-project-applied-econ`;
3. la ruta opcional definida en `project_manual`.

Después de localizar el panel maestro, cada archivo cambia automáticamente a la
raíz del repositorio. El archivo 02 verifica además que el archivo 01 haya
producido `master_panel_estimation_sample.dta`. Todas las rutas internas se
construyen desde la raíz. La configuración:

- fija la sintaxis en Stata 17;
- limpia la sesión antes de cada ejecución;
- desactiva abreviaciones de variables;
- fija semillas reproducibles;
- crea las carpetas de resultados;
- abre un registro separado para cada archivo;
- instala únicamente las dependencias ausentes;
- registra las versiones de las dependencias utilizadas.

Dependencias externas del archivo 01:

- `xtserial`, para la prueba de autocorrelación de Wooldridge;
- `xttest3`, para la prueba de Wald modificada de heterocedasticidad;
- `xtcsd`, para la prueba de dependencia transversal de Pesaran.

Dependencias externas del archivo 02:

- `ftools`;
- `reghdfe`;
- `estout`, mediante el comando `esttab`.

La inicialización y las secciones 9 y 10 del archivo 03 utilizan únicamente
comandos oficiales de Stata. La sección 11 reutiliza `reghdfe` y `esttab`,
instalados y verificados por el archivo 02; no instala paquetes adicionales.

No se añadirá otro paquete hasta que una sección implementada lo requiera de
forma efectiva.

## 5. Secciones de los archivos econométricos

### Sección 1. Configuración

**Objetivo**

Preparar un entorno reproducible antes de leer los datos.

**Tareas**

- Definir Stata 17 y limpiar la sesión.
- Verificar dependencias.
- Localizar la raíz desde el directorio actual o sus directorios padre.
- Definir macros globales de insumos y salidas.
- Crear la estructura de resultados.
- Abrir el log principal.

**Estado:** implementada y validada.

### Sección 2. Carga y validación del panel

**Objetivo**

Detener la ejecución si el panel no coincide con el insumo metodológico
esperado.

**Tareas**

- Cargar el `.dta` sin sobrescribirlo.
- Verificar las variables y sus tipos.
- Comprobar la llave país-año.
- Crear `country_id` y declarar el panel.
- Validar 55 países, 26 años y 1.430 observaciones.
- Verificar dominios e identidades contables.
- Comprobar `DIVX = 1 - HHI`.
- Comprobar `RENTS = RENTS_OIL_GAS + RENTS_MINING`.
- Comprobar `RENTS_X_INST = RENTS × INST`.

**Estado:** implementada y validada.

### Sección 3. Preparación de variables y muestras

**Objetivo**

Construir las muestras analíticas sin alterar el panel maestro.

**Tareas**

- Se examinaron los niveles, ceros y la asimetría de `OILPC`, `GASPC` y
  `COALPC`.
- Se compararon los niveles con `ln(1+x)`.
- Se adoptó `ln(1+x)` porque conserva los ceros y reduce la asimetría de las
  tres variables.
- Se construyeron por separado las muestras completas de los modelos `ECI` y
  `DIVX`.
- Se documentaron observaciones, países y años incluidos y excluidos.
- Las bases y tablas derivadas se guardaron únicamente en `01_sample`.
- No se imputaron ni interpolaron valores faltantes.

**Resultado validado en Stata:** 1.044 observaciones completas, 386
observaciones excluidas y 49 países con al menos una observación en cada
ecuación. Las muestras `ECI` y `DIVX` coinciden con la disponibilidad actual
del panel. Los años 1997, 1999 y 2001 no contienen casos completos debido a
los vacíos estructurales de `INST`.

**Estado:** implementada y validada técnicamente; pendiente de aprobación
conjunta en el Control B.

### Sección 4. Diagnósticos

**Objetivo**

Comprobar que la especificación pueda estimarse y definir la inferencia final
antes de observar los resultados principales.

**Tareas**

- Calcular estadísticos generales, *between* y *within*.
- Revisar distribuciones, ceros y valores extremos.
- Examinar correlaciones y colinealidad.
- Verificar variación temporal efectiva de los regresores.
- Evaluar heterocedasticidad y autocorrelación.
- Evaluar dependencia transversal.
- Identificar observaciones o países potencialmente influyentes.
- Registrar alertas sin excluir observaciones automáticamente.

**Resultados**

- Las variables de ambos modelos presentan variación temporal dentro de los
  países; ninguna quedó sin variación *within*.
- Los VIF calculados sobre la variación residualizada por país y año son
  inferiores a 2 en ambos modelos.
- La prueba de Wald modificada rechaza homocedasticidad en ECI y DIVX.
- La prueba de Wooldridge rechaza ausencia de autocorrelación de primer orden
  en ECI y DIVX.
- La prueba CD de Pesaran no rechaza independencia transversal en ninguno de
  los dos modelos.
- Se registraron 70 alertas de observaciones influyentes para ECI y 75 para
  DIVX. Son casos para revisión; no se eliminó ninguna observación.

**Estado:** implementada, validada técnicamente y aprobada en el Control C.

### Sección 5. Modelo principal con ECI

**Objetivo**

Estimar la ecuación principal con efectos fijos por país y año.

**Estrategia definida por los diagnósticos**

- Estimación transparente mediante `xtreg`, efectos fijos e indicadores de año.
- Errores estándar agrupados por país como inferencia principal.
- Verificación numérica mediante `reghdfe`.
- Interacción estimada mediante `c.rents##c.inst`.
- Pruebas conjuntas por canales y entre recursos extractivos.
- Comprobación estricta de que `xtreg` y `reghdfe` utilizan la misma muestra y
  producen los mismos coeficientes sustantivos.
- Exportación separada de coeficientes, resumen del modelo, pruebas conjuntas y
  reporte de equivalencia numérica.

La agrupación por país responde a la heterocedasticidad y la autocorrelación
detectadas. Como la prueba CD de Pesaran no encontró evidencia de dependencia
transversal residual, los errores Driscoll–Kraay no se adoptan como inferencia
principal; podrán incorporarse posteriormente como sensibilidad si resulta
metodológicamente útil.

**Salidas previstas**

- `eci_twfe_main.ster`;
- `eci_reghdfe_check.ster`;
- `eci_twfe_coefficients.csv`;
- `eci_twfe_model_summary.csv`;
- `eci_twfe_joint_tests.csv`;
- `eci_xtreg_reghdfe_verification.csv`;
- `eci_twfe_main.tex`.

**Resultados**

- El modelo utiliza 1.044 observaciones, 49 países y 23 años efectivos.
- El ajuste dentro de los países es `R2 within = 0,1523`.
- `RENTS` presenta un coeficiente negativo en `INST = 0` (`p = 0,0233`).
- `INST` presenta un coeficiente positivo en `RENTS = 0` (`p = 0,0570`).
- La interacción `RENTS × INST` es negativa, pero no estadísticamente distinta
  de cero (`p = 0,1388`). Su interpretación definitiva requiere los efectos
  marginales de la sección 7.
- El canal estructural es conjuntamente significativo (`p = 0,0007`); `HHI`,
  `PEXP` y `FEXP` presentan coeficientes negativos.
- Los canales institucional, de abundancia, macroeconómico, de capacidades y de
  controles no son conjuntamente significativos al 5 %.
- No se rechaza la igualdad entre los coeficientes de petróleo, gas y carbón
  (`p = 0,7680`).
- Los efectos fijos por año son conjuntamente significativos (`p = 0,0001`).
- `xtreg` y `reghdfe` producen exactamente los mismos 17 coeficientes y errores
  estándar; ninguna observación singleton fue eliminada.

**Estado:** implementada, validada técnicamente en Stata y aprobada mediante
revisión *peer-to-peer* en el Control D.

### Sección 6. Modelo complementario con DIVX

**Objetivo**

Estimar la misma estructura con `DIVX` como variable dependiente.

**Reglas**

- Mantener las transformaciones y la inferencia aprobadas para `ECI`.
- Mantener los mismos efectos fijos.
- Excluir únicamente `HHI`.
- Conservar `PEXP` y `FEXP`.
- No interpretar diferencias entre ecuaciones como evidencia causal.

**Salidas**

- `divx_twfe_main.ster`;
- `divx_reghdfe_check.ster`;
- `divx_twfe_coefficients.csv`;
- `divx_twfe_model_summary.csv`;
- `divx_twfe_joint_tests.csv`;
- `divx_xtreg_reghdfe_verification.csv`;
- `divx_twfe_main.tex`.

**Resultados**

- La estimación utiliza 1.044 observaciones, 49 países y 23 años efectivos,
  exactamente igual que la muestra completa definida para `DIVX`.
- El modelo es conjuntamente significativo y presenta un `R² within` de
  0,3119.
- `RENTS` presenta una asociación negativa con `DIVX` en `INST = 0`
  (`β = -0,003536`; `p = 0,0089`).
- La interacción `RENTS × INST` no es estadísticamente significativa
  (`p = 0,4274`).
- `PEXP` y `HUMCAP` presentan asociaciones positivas significativas; `NET` y
  `log(GDPPC)` presentan asociaciones negativas significativas.
- `GOVCONS` presenta significancia al 10 %. Las demás variables individuales
  no rechazan la hipótesis nula al 10 %.
- Los canales institucional, estructural, de capacidades productivas y de
  controles económicos y financieros son conjuntamente significativos. Los
  canales de abundancia y macroeconómico no lo son.
- Los efectos fijos por año son conjuntamente significativos
  (`p = 0,000045`).
- `HHI` quedó excluido de la ecuación y se verificó únicamente la identidad
  `DIVX = 1 - HHI`.
- `xtreg` y `reghdfe` producen exactamente los mismos 16 coeficientes y errores
  estándar; ninguna observación singleton fue eliminada.

**Estado:** implementada y validada técnicamente en Stata; pendiente de revisión
sustantiva en el Control E.

### Sección 7. Estabilidad y efectos marginales

**Objetivo**

Interpretar la interacción institucional y comprobar que los resultados no
dependan de errores o decisiones no documentadas.

**Tareas**

- Calcular el efecto marginal de `RENTS` para valores sustantivos de `INST`.
- Exportar intervalos de confianza y una figura de efectos marginales.
- Interpretar la prueba ya estimada de igualdad entre `OILPC`, `GASPC` y
  `COALPC`.
- Comparar la especificación principal `ln(1+x)` con `OILPC`, `GASPC` y
  `COALPC` en niveles per cápita, sin cambiar la definición agregada de `RENTS`.
- Revisar observaciones o países influyentes detectados previamente.
- Evaluar una prueba *wild cluster bootstrap* para `RENTS` y
  `RENTS × INST`, dado que la inferencia principal utiliza 49 conglomerados.
- Registrar cualquier sensibilidad sin sustituir silenciosamente el modelo
  predefinido.

**Resultados**

- En el modelo ECI, la asociación marginal estimada de `RENTS` se vuelve más
  negativa a medida que aumenta `INST`: pasa de `-0,0034` en P10
  (`p = 0,448`) a `-0,0146` en P90 (`p = 0,021`). El efecto puntual es
  estadísticamente distinto de cero desde la mediana institucional.
- En el modelo DIVX, la asociación marginal estimada de `RENTS` permanece
  negativa, pero se atenúa al aumentar `INST`: pasa de `-0,0047` en P10
  (`p < 0,001`) a `-0,0027` en P90 (`p = 0,214`). El intervalo de confianza
  incluye cero únicamente en P90.
- Estos perfiles marginales no constituyen evidencia suficiente de moderación:
  el coeficiente de `RENTS × INST` no es estadísticamente significativo en ECI
  ni en DIVX, tanto con inferencia agrupada convencional como con *wild cluster
  bootstrap*.
- No se rechaza la igualdad conjunta de los coeficientes de las rentas
  petroleras, gasíferas y carboníferas en ECI (`p = 0,768`) ni en DIVX
  (`p = 0,333`).
- Al sustituir únicamente `ln(1 + OILPC)`, `ln(1 + GASPC)` y
  `ln(1 + COALPC)` por sus niveles per cápita, `RENTS` conserva signo negativo:
  en ECI pasa de `-0,0098` (`p = 0,023`) a `-0,0067` (`p = 0,068`), y en DIVX
  pasa de `-0,0035` (`p = 0,009`) a `-0,0041` (`p = 0,017`).
- La interacción `RENTS × INST` continúa sin significancia estadística en la
  alternativa per cápita de ECI (`p = 0,466`) y DIVX (`p = 0,782`).
- El coeficiente de `GASPC` en niveles cambia de signo y resulta significativo
  en ECI (`p < 0,001`), mientras que su versión `ln(1+x)` no es significativa.
  Esto muestra sensibilidad de los componentes individuales a la forma
  funcional y respalda mantener `ln(1+x)` como especificación principal.
- Al excluir todas las observaciones señaladas como potencialmente influyentes,
  `RENTS` conserva signo negativo y significancia al 5 % en ambos modelos. La
  interacción institucional permanece no significativa.
- En el ejercicio de excluir un país por vez, `RENTS` conserva signo negativo
  en las 49 reestimaciones de cada modelo. Es significativo al 5 % en las 49
  estimaciones DIVX y en 46 de las 49 estimaciones ECI; en ECI es significativo
  al 10 % en las 49.
- La interacción no cambia de signo al excluir países individualmente y nunca
  es significativa al 5 %. En ECI alcanza el 10 % en 4 de 49 reestimaciones;
  en DIVX no alcanza el 10 % en ninguna.
- El *wild cluster bootstrap* con 9.999 repeticiones confirma la asociación
  negativa de `RENTS` en ECI (`p = 0,040`) y DIVX (`p = 0,021`), mientras que
  no respalda la interacción institucional en ECI (`p = 0,209`) ni DIVX
  (`p = 0,477`).
- Las pruebas de sensibilidad no sustituyen los modelos principales
  `ECI_TWFE_MAIN` y `DIVX_TWFE_MAIN`; sirven para evaluar la estabilidad de sus
  asociaciones estimadas.

**Estado:** implementada y validada técnicamente en Stata. Las figuras
individuales y la comparación ECI–DIVX fueron regeneradas con percentiles
legibles y bandas de confianza visibles. La sensibilidad de forma funcional
conservó la muestra de 1.044 observaciones y 49 países.

### Sección 8. Exportación de resultados

**Objetivo**

Crear un paquete reproducible listo para revisión, pero todavía separado del
TFM.

**Tareas**

- Exportar cobertura y composición de las muestras.
- Exportar descriptivos y diagnósticos.
- Exportar resultados `ECI` y `DIVX`.
- Exportar pruebas conjuntas y efectos marginales.
- Generar tablas mediante `esttab`.
- Exportar figuras en formatos aptos para LaTeX.
- Crear un índice que relacione cada resultado con su sección de origen.
- Cerrar el log.
- Ejecutar nuevamente los archivos 01 y 02, en ese orden, desde sesiones
  limpias.

**Implementación**

- La tabla econométrica principal reúne `ECI_TWFE_MAIN` y `DIVX_TWFE_MAIN` en
  formatos LaTeX y texto, con errores estándar agrupados por país, efectos
  fijos de país y año y una advertencia explícita contra interpretaciones
  causales.
- Los coeficientes, resúmenes de los modelos y pruebas conjuntas se consolidan
  en tres archivos CSV comunes sin reemplazar sus fuentes originales.
- La matriz de evidencia clasifica los resultados como centrales,
  complementarios, no concluyentes o controles.
- Las seis familias de estabilidad se copian al paquete final: efectos
  marginales, exclusión de observaciones alertadas, exclusión individual de
  países, *wild cluster bootstrap*, igualdad entre recursos y sensibilidad a
  la transformación de los controles per cápita.
- La sensibilidad de forma funcional se exporta también como tabla comparativa
  en formatos LaTeX y texto; no se presenta como desagregación sectorial.
- Las figuras ECI y DIVX se combinan en formatos PDF y PNG, manteniendo escalas
  verticales independientes.
- `RESULTS_INDEX.md` documenta el alcance agregado, los archivos y las reglas
  de interpretación; `results_manifest.csv` funciona como inventario legible
  por máquina.
- El cierre comprueba la muestra de los modelos, la existencia de los insumos,
  el número de filas de las consolidaciones y la creación de cada archivo
  anunciado.
- La futura desagregación hidrocarburos–minería queda expresamente fuera de
  este archivo.

**Estado:** implementada y validada técnicamente mediante una ejecución de
Stata desde la terminal el 29 de julio de 2026. Los archivos 01 y 02 cerraron
sin errores desde sesiones limpias y desde la carpeta anidada de los scripts.
El archivo 02 creó las 18 salidas finales previstas —17 inventariadas más el
propio manifiesto— y validó 33 filas de coeficientes y 16 pruebas conjuntas.

### Sección 9. Diseño de la desagregación de RENTS

**Objetivo**

Definir antes de estimar cómo se distinguirán las rentas de hidrocarburos de
las rentas de carbón, minerales y metales.

**Decisiones cerradas en el Control G**

- Los dos componentes entrarán conjuntamente dentro de la misma ecuación:
  `RENTS_OIL_GAS` y `RENTS_MINING`.
- Ambos componentes reemplazarán a `RENTS` únicamente en la extensión. Los
  modelos agregados `ECI_TWFE_MAIN` y `DIVX_TWFE_MAIN` continúan siendo los
  modelos centrales del TFM.
- Se incluirán simultáneamente `RENTS_OIL_GAS × INST` y
  `RENTS_MINING × INST`. Esta decisión descompone la interacción agregada y no
  autoriza otras interacciones.
- No se estimarán modelos separados con un solo componente, porque omitirían la
  otra fuente de rentas extractivas y no permitirían probar directamente la
  restricción sectorial del modelo agregado.
- `ln1p_oilpc`, `ln1p_gaspc` y `ln1p_coalpc` permanecen en la especificación
  principal: miden abundancia real por habitante, mientras los componentes de
  `RENTS` miden intensidad como porcentaje del PIB.
- Se predefine una única sensibilidad que excluye conjuntamente los tres
  controles per cápita. No se excluirán por separado ni según los resultados.
- Las muestras desagregadas deben coincidir exactamente con las muestras
  agregadas de casos completos.
- Se predefinen pruebas de significancia conjunta por componente, igualdad de
  coeficientes directos, igualdad de interacciones e igualdad conjunta de ambos
  pares. Los efectos marginales se evaluarán en P10, P25, P50, P75 y P90 de
  `INST`.
- La inferencia conservará efectos fijos por país y año y errores estándar
  agrupados por país. Los resultados se interpretarán como asociaciones
  condicionadas, no como efectos causales sectoriales.

**Implementación**

- La inicialización localiza la raíz, comprueba la base del archivo 01 y los
  resúmenes agregados ECI y DIVX del archivo 02.
- Las salidas de esta etapa se escriben exclusivamente en
  `07_resource_disaggregation/00_design/` y su log en
  `07_resource_disaggregation/logs/`.
- `control_g_design.csv` conserva las decisiones metodológicas.
- `section9_validation.csv` conserva la identidad contable y la comparación de
  muestras.
- La sección 9 utiliza únicamente comandos oficiales de Stata y no instala
  paquetes.

**Estado:** implementada y validada mediante una ejecución independiente de
Stata el 29 de julio de 2026. La identidad contable se comprobó en 1.352
observaciones, con una discrepancia máxima de
`9,384680533 × 10^-14` puntos porcentuales y cero incompatibilidades en el
patrón de faltantes. Las muestras ECI y DIVX desagregadas conservaron,
cada una, 1.044 observaciones y 49 países, con cero diferencias frente a sus
muestras agregadas. No se estimaron coeficientes.

### Sección 10. Preparación y diagnósticos de los componentes

**Objetivo**

Comprobar que los componentes pueden utilizarse en una especificación de panel
sin alterar la base ni ocultar problemas de cobertura o colinealidad.

**Tareas**

- Cargar la base analítica como insumo de solo lectura.
- Verificar dominios, valores faltantes e identidad contable.
- Documentar observaciones, países, años, ceros y valores extremos.
- Calcular variación *overall*, *between* y *within*.
- Examinar correlaciones y colinealidad con las interacciones y los controles
  per cápita relacionados.
- Registrar observaciones potencialmente influyentes sin eliminarlas
  automáticamente.

**Outputs**

- `component_profile.csv`: cobertura, ceros y distribución de ambos
  componentes.
- `component_panel_variation.csv`: variación *overall*, *between* y *within*
  de los componentes y sus interacciones.
- `focal_correlation_matrix.csv`: correlaciones con `INST` y los controles per
  cápita.
- `within_vif_by_model.csv`: VIF residualizado por país y año para ECI y DIVX,
  incluidas las interacciones.
- `influence_summary.csv`: umbrales y conteos de alertas por modelo.
- `influential_observations.csv`: detalle país-año para las sensibilidades
  posteriores.

**Resultados del diagnóstico**

- `rents_oil_gas` tiene 95,45 % de cobertura en la grilla y
  `rents_mining`, 96,78 %; ambas conservan 1.044 observaciones en la muestra
  analítica.
- Los dos componentes y sus interacciones presentan variación *within*
  positiva. La razón *within/overall* es 0,334 para hidrocarburos y 0,626 para
  minería.
- Las correlaciones en niveles alcanzan 0,783 entre `rents_oil_gas` y
  `ln1p_oilpc`, y 0,788 entre `ln1p_oilpc` y `ln1p_gaspc`. Sin embargo, el VIF
  *within* máximo es 2,040 en ECI y 1,966 en DIVX, por debajo del umbral de
  revisión de 5.
- Se alertaron 75 observaciones ECI y 78 DIVX mediante apalancamiento, distancia
  de Cook o residuo estandarizado. Estas alertas no modifican la muestra
  principal y alimentarán las sensibilidades de la sección 13.

**Estado:** implementada y validada mediante Stata el 29 de julio de 2026.
Los seis archivos fueron creados, no se detectó colinealidad *within* alta y no
se eliminaron países ni observaciones.

### Sección 11. Modelos desagregados con ECI

**Objetivo**

Estimar la asociación condicionada de cada tipo de renta con la complejidad
económica y compararla con `ECI_TWFE_MAIN`.

**Tareas**

- Construir y documentar la muestra ECI comparable.
- Estimar efectos fijos por país y año con errores agrupados por país.
- Probar la significancia individual y conjunta de ambos componentes.
- Contrastar la igualdad de los coeficientes de hidrocarburos y minería.
- Evaluar las interacciones institucionales aprobadas.
- Comparar signos, magnitudes, incertidumbre, cobertura y ajuste con el modelo
  agregado.

**Outputs**

- `eci_disaggregated_coefficients.csv`: 19 términos, incluidas las dos
  interacciones institucionales.
- `eci_disaggregated_model_summary.csv`: cobertura, ajuste e inferencia.
- `eci_disaggregated_tests.csv`: siete pruebas predefinidas.
- `eci_xtreg_reghdfe_verification.csv`: equivalencia término por término.
- `eci_aggregate_disaggregated_model_comparison.csv`: comparación homogénea de
  muestra y ajuste.
- `eci_aggregate_disaggregated_focal_comparison.csv`: comparación de los
  términos de rentas.
- `eci_aggregate_disaggregated_table.tex`: tabla provisional de revisión.
- Dos archivos `.ster` conservan las estimaciones `xtreg` y `reghdfe`.

**Resultados**

- La muestra permanece en 1.044 observaciones, 49 países y 23 años efectivos.
- El coeficiente directo de hidrocarburos es `-0,007254` (`p = 0,212`); su
  efecto conjunto con la interacción no es estadísticamente detectable
  (`p = 0,291`).
- El coeficiente directo de minería es `-0,013597` (`p = 0,0011`); su efecto
  conjunto con la interacción es estadísticamente detectable (`p = 0,0024`).
- Las dos interacciones no son conjuntamente significativas (`p = 0,340`).
- No se rechaza la igualdad de coeficientes directos (`p = 0,325`), la igualdad
  de interacciones (`p = 0,522`) ni la restricción conjunta implícita en el
  modelo agregado (`p = 0,332`).
- Los cuatro términos desagregados son conjuntamente significativos
  (`p = 0,0057`).
- El R² *within* pasa de 0,1523 en el modelo agregado a 0,1566 en el
  desagregado, mientras el RMSE cambia de 0,26343 a 0,26302.
- `xtreg` y `reghdfe` reproducen exactamente los 19 coeficientes. Los
  coeficientes comunes con el peer independiente difieren en menos de
  `4,3 × 10^-11`.

**Lectura:** la minería presenta una asociación negativa más precisa, pero las
pruebas formales no demuestran que su coeficiente o su interacción difieran de
los correspondientes a hidrocarburos. La evidencia es complementaria y no
justifica reemplazar `ECI_TWFE_MAIN`.

**Estado:** implementada, validada y aprobada en el Control H el 29 de julio de
2026. No se excluyeron observaciones y no se emplea lenguaje causal.

### Sección 12. Modelos desagregados con DIVX

**Objetivo**

Repetir la desagregación para diversificación exportadora manteniendo la
comparabilidad con `DIVX_TWFE_MAIN`.

**Tareas**

- Construir y documentar la muestra DIVX comparable.
- Excluir HHI porque `DIVX = 1 - HHI`.
- Estimar efectos fijos por país y año con errores agrupados por país.
- Repetir las pruebas individuales, conjuntas, de igualdad y de interacción.
- Comparar resultados con el modelo DIVX agregado.
- Distinguir diversificación horizontal de transformación productiva profunda.

**Outputs**

- `divx_disaggregated_coefficients.csv`: 18 términos, incluidas las dos
  interacciones institucionales y sin HHI.
- `divx_disaggregated_model_summary.csv`: cobertura, ajuste e inferencia.
- `divx_disaggregated_tests.csv`: siete pruebas predefinidas.
- `divx_xtreg_reghdfe_verification.csv`: equivalencia término por término.
- `divx_aggregate_disaggregated_model_comparison.csv`: comparación homogénea de
  muestra y ajuste.
- `divx_aggregate_disaggregated_focal_comparison.csv`: comparación de los
  términos de rentas.
- `divx_aggregate_disaggregated_table.tex`: tabla provisional de revisión.
- Dos archivos `.ster` conservan las estimaciones `xtreg` y `reghdfe`.

**Resultados**

- La muestra permanece en 1.044 observaciones, 49 países y 23 años efectivos.
- El coeficiente directo de hidrocarburos es `-0,004849` (`p = 0,0010`) y su
  efecto conjunto con la interacción es estadísticamente detectable
  (`p = 0,00018`).
- El coeficiente directo de minería es `-0,001413` (`p = 0,459`) y su efecto
  conjunto con la interacción no es estadísticamente detectable
  (`p = 0,749`).
- Las dos interacciones no son conjuntamente significativas (`p = 0,599`).
- No se rechaza por separado la igualdad de coeficientes directos (`p = 0,108`)
  ni la igualdad de interacciones (`p = 0,419`), pero sí se rechaza la
  restricción conjunta del modelo agregado (`p = 0,0184`).
- Los cuatro términos desagregados son conjuntamente significativos
  (`p = 0,0013`).
- El R² *within* pasa de 0,3119 en el modelo agregado a 0,3270 en el
  desagregado, mientras el RMSE cambia de 0,07164 a 0,07092.
- `xtreg` y `reghdfe` reproducen exactamente los 18 coeficientes. Los
  coeficientes comunes con el peer independiente difieren en menos de
  `4,9 × 10^-11`.

**Lectura:** las rentas de petróleo y gas presentan una asociación negativa más
precisa con la diversificación horizontal. Minería no muestra la misma
precisión y las interacciones institucionales no son detectables. La
desagregación rechaza conjuntamente la estructura agregada, por lo que aporta
información complementaria relevante, pero no sustituye la interpretación más
amplia de transformación productiva del modelo ECI.

**Estado:** implementada, validada y aprobada en el Control I el 29 de julio de
2026. HHI fue excluido por identidad, no se modificó la muestra y no se emplea
lenguaje causal.

### Sección 13. Estabilidad y efectos marginales por componente

**Objetivo**

Determinar si las diferencias entre hidrocarburos y minería se mantienen bajo
las mismas exigencias de estabilidad aplicadas a los modelos agregados.

**Tareas**

- Calcular efectos marginales de cada componente para valores sustantivos de
  `INST`.
- Reestimar excluyendo observaciones previamente alertadas.
- Ejecutar exclusiones de un país por vez.
- Aplicar *wild cluster bootstrap* cuando corresponda.
- Implementar únicamente sensibilidades predefinidas.
- Clasificar la evidencia como central, complementaria o no concluyente.

**Outputs**

- `component_marginal_effects_by_inst.csv`: 20 efectos marginales para los
  percentiles 10, 25, 50, 75 y 90 de `INST`.
- Ocho figuras, cuatro en PDF y cuatro en PNG, para hidrocarburos y minería en
  los modelos ECI y DIVX.
- `influential_observation_sensitivity.csv`: 16 comparaciones antes y después
  de excluir las observaciones alertadas.
- `leave_one_country_out_detail.csv`: 392 reestimaciones, correspondientes a
  49 países, dos modelos y cuatro términos focales.
- `leave_one_country_out_summary.csv`: ocho resúmenes de estabilidad.
- `wild_cluster_bootstrap.csv`: ocho pruebas con 9.999 réplicas y pesos
  Rademacher.
- `no_per_capita_controls_sensitivity.csv`: 16 comparaciones sobre la misma
  muestra, sin los controles de recursos per cápita.
- `stability_classification.csv`: clasificación predefinida de los ocho
  términos focales.

**Resultados**

- La asociación marginal de minería con ECI es negativa y estadísticamente
  detectable en los cinco percentiles de `INST`; varía entre `-0,010961` en
  P10 y `-0,015544` en P90.
- La asociación marginal de hidrocarburos con DIVX es negativa y detectable
  entre P10 y P75; en P90 es `-0,003742` (`p = 0,091`).
- Los efectos marginales de hidrocarburos sobre ECI y de minería sobre DIVX no
  son estadísticamente detectables en ninguno de los cinco percentiles.
- La exclusión de 75 alertas en ECI y 78 en DIVX preserva el signo de siete de
  los ocho términos. La interacción minería–instituciones del modelo ECI
  cambia de signo y algunos términos inicialmente imprecisos se vuelven
  detectables, por lo que esas variaciones se reportan como sensibilidad y no
  como resultados centrales.
- Las exclusiones de un país por vez preservan siempre el signo y la
  significancia al 5 % de minería en ECI y de hidrocarburos en DIVX. Los otros
  términos presentan menor estabilidad inferencial.
- El *wild cluster bootstrap* confirma minería en ECI (`p = 0,0235`) e
  hidrocarburos en DIVX (`p = 0,0029`); los otros seis términos no son
  detectables.
- La sensibilidad sin controles de recursos per cápita mantiene los signos y
  las conclusiones principales.
- La regla predefinida clasifica como evidencia complementaria únicamente
  minería en ECI e hidrocarburos en DIVX. Los seis términos restantes quedan
  como evidencia no concluyente.
- Los 20 efectos marginales coinciden con el peer independiente hasta el
  redondeo de exportación. Los cuatro resúmenes directos de exclusión de un
  país coinciden en signos, conteos y coeficientes, con diferencias inferiores
  a `3 × 10^-10`. Las pequeñas diferencias del bootstrap corresponden a
  semillas Monte Carlo distintas y no alteran ninguna conclusión.

**Lectura:** la evidencia de estabilidad refuerza de manera complementaria dos
patrones: minería en el modelo ECI e hidrocarburos en el modelo DIVX. No
respalda una interpretación central o causal de los demás componentes ni de
las interacciones institucionales.

**Estado:** implementada y validada el 29 de julio de 2026. Se ejecutaron
únicamente sensibilidades predefinidas, las cuatro figuras fueron revisadas
visualmente y el cierre permanece sujeto al Control J de la sección 14.

### Sección 14. Exportación y cierre de la desagregación

**Objetivo**

Crear un paquete reproducible y separado de las salidas agregadas.

**Tareas**

- Exportar coeficientes, incertidumbre, cobertura y pruebas conjuntas.
- Crear tablas comparables entre RENTS agregado, hidrocarburos y minería.
- Exportar figuras de efectos marginales en PDF y PNG.
- Crear un índice y un manifiesto de resultados.
- Ejecutar el archivo 03 desde una sesión limpia.
- Confirmar que no se sobrescribieron outputs de las secciones 1 a 8.
- Contrastar resultados entre pares antes de incorporarlos al TFM.

**Outputs**

- `final_focal_coefficients.csv`: doce coeficientes directos e interacciones
  comparables entre RENTS agregado, hidrocarburos y minería.
- `final_model_comparison.csv`: cobertura y ajuste de los cuatro modelos.
- `final_joint_tests.csv`: catorce pruebas conjuntas de ECI y DIVX
  desagregados.
- `final_component_marginal_effects.csv`: veinte efectos marginales por
  percentil de `INST`.
- `final_stability_classification.csv`: clasificación de los ocho términos
  focales.
- `table_eci_divx_aggregate_disaggregated.tex` y
  `table_eci_divx_aggregate_disaggregated.txt`: tabla comparativa focal.
- `table_eci_divx_full_models.tex` y `table_eci_divx_full_models.txt`: tabla
  suplementaria con todos los controles, incorporada después del contraste con
  Antigravity.
- `results_manifest.csv`: configuración, cobertura y verificaciones de la
  ejecución.
- `results_index.csv`: inventario dinámico de los 53 archivos producidos por
  las secciones 9 a 14.

**Resultados**

- El paquete final contiene once archivos en `05_exports/` y conserva las ocho
  figuras de efectos marginales en `04_stability/`.
- El índice registra 2 archivos de diseño, 6 de diagnóstico, 9 de ECI, 9 de
  DIVX, 15 de estabilidad, 11 exportaciones finales y el log de ejecución.
- Los doce coeficientes focales, sus errores estándar y sus valores p preservan
  los resultados validados en las secciones 11 y 12.
- La tabla final reproduce las mismas conclusiones y valores redondeados que la
  tabla de Antigravity. En los términos desagregados comunes, las diferencias
  de coeficientes permanecen por debajo de `3,1 × 10^-11`; las diferencias de
  los coeficientes agregados responden únicamente a la exportación a seis
  decimales y son inferiores a `4,7 × 10^-7`.
- La tabla completa de Antigravity se incorporó como salida suplementaria. Se
  conservaron sus notas sobre efectos fijos, agrupación por país, exclusión de
  HHI y carácter complementario de la extensión, y se eliminaron de la salida
  los niveles base y términos omitidos.
- El índice excluye su versión previa durante cada reconstrucción y añade una
  sola entrada propia, por lo que puede regenerarse sin duplicados.
- El archivo 03 se ejecutó desde una sesión limpia en Stata 17 y escribió el
  marcador de cierre de las secciones 9 a 14.
- El ejecutor comparó las huellas SHA-256 antes y después de la etapa 03 y
  confirmó que ningún output de las secciones 1 a 8 fue modificado.

**Lectura:** el paquete final separa completamente la extensión desagregada de
los resultados agregados, conserva la trazabilidad de cada salida y deja listas
las tablas necesarias para decidir su incorporación al TFM.

**Estado:** implementada, validada y aprobada en el Control J el 29 de julio de
2026. El archivo 03 quedó terminado.

## 6. Estructura exclusiva de salidas

Todas las salidas de esta implementación se escribirán únicamente bajo:

```text
outputs/econometrics/stata-peer-2/
  00_design/
  01_sample/
  02_diagnostics/
  03_eci/
  04_divx/
  05_stability/
  06_final/
  logs/
  07_resource_disaggregation/
    00_design/
    01_diagnostics/
    02_eci/
    03_divx/
    04_stability/
    05_exports/
    logs/
```

La estructura interna de `07_resource_disaggregation/` se utiliza completa con
las secciones 9 a 14: `00_design/`, `01_diagnostics/`, `02_eci/`, `03_divx/`,
`04_stability/`, `05_exports/` y `logs/`.
La extensión no escribirá dentro de `03_eci/`, `04_divx/`, `05_stability/` ni
`06_final/`, porque esas carpetas pertenecen a los modelos agregados.

Ninguna sección escribirá directamente en:

- `data/raw`;
- `data/processed`;
- `outputs/econometrics/stata-peer-1`;
- las carpetas generales situadas directamente en `outputs/econometrics`.

Los archivos temporales de Stata utilizarán `tempfile` y no se mezclarán con
los resultados finales.

## 7. Decisiones que deben cerrarse antes del modelo ECI

1. **Cerrada técnicamente:** utilizar `ln(1+OILPC)`, `ln(1+GASPC)` y
   `ln(1+COALPC)`; pendiente de ratificación en el Control B.
2. **Cerrada y aprobada:** usar errores estándar agrupados por país como
   inferencia principal.
3. **Cerrada y ejecutada:** presentar los efectos marginales en P10, P25, P50,
   P75 y P90 de `INST`.
4. **Cerrada y ejecutada:** probar la igualdad entre hidrocarburos y minería,
   tanto para los efectos directos como para las interacciones.
5. **Cerrada técnicamente:** revisar apalancamiento mayor que `2k/N`, distancia
   de Cook mayor que `4/N` o residuo estandarizado mayor que 3 en valor
   absoluto, sin exclusiones automáticas.

Estas decisiones se documentarán en `00_design` antes de estimar los
coeficientes principales.

## 8. Puntos de control

1. **Control A — configuración y panel:** validar secciones 1 y 2.
2. **Control B — muestra:** aprobar transformaciones, cobertura y exclusiones.
3. **Control C — diagnósticos:** aprobado; inferencia agrupada por país.
4. **Control D — ECI:** aprobado mediante revisión *peer-to-peer*; la
   interpretación de los efectos marginales se completará en la sección 7.
5. **Control E — estabilidad conjunta:** aprobado; comparar ECI y DIVX, sus
   efectos marginales y sensibilidades sin lenguaje causal y mantener la
   desagregación de recursos como una extensión posterior.
6. **Control F — cierre:** aprobado el 29 de julio de 2026. Los archivos 01 y
   02 se ejecutaron en orden desde sesiones limpias, localizaron la raíz desde
   la carpeta anidada y regeneraron sin errores las muestras, diagnósticos,
   modelos, sensibilidades y salidas finales.
7. **Control G — diseño de la desagregación:** aprobado antes de observar
   coeficientes. Se fijaron la estructura conjunta, las dos interacciones con
   `INST`, el tratamiento de los controles per cápita, las muestras comparables
   y las pruebas predefinidas.
8. **Control H — ECI desagregado:** aprobado el 29 de julio de 2026. La
   estimación conserva la muestra, supera la verificación `xtreg`–`reghdfe`,
   coincide con el peer independiente y no rechaza la restricción conjunta del
   modelo agregado.
9. **Control I — DIVX desagregado:** aprobado el 29 de julio de 2026. La
   estimación conserva la muestra, excluye HHI por identidad, supera la
   verificación `xtreg`–`reghdfe`, coincide con el peer independiente y rechaza
   la restricción conjunta del modelo agregado.
10. **Control J — cierre de la extensión:** aprobado el 29 de julio de 2026.
    Las sensibilidades y figuras fueron validadas, el paquete final contiene
    manifiesto e índice, la ejecución limpia preservó por SHA-256 los outputs
    de las secciones 1 a 8 y el contraste peer-to-peer mantuvo las conclusiones.

No se avanzará automáticamente de un control al siguiente sin revisar el
resultado de la etapa anterior.
