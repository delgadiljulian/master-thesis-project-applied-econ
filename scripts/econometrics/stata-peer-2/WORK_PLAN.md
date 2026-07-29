# Plan de trabajo econométrico en Stata — implementación candidata Codex

## 1. Objetivo

Implementar de forma reproducible en **Stata 17 MP** las dos ecuaciones
econométricas definidas en el capítulo metodológico de la tesis:

1. **Modelo principal:** `ECI` como variable dependiente.
2. **Modelo complementario:** `DIVX = 1 - HHI` como variable dependiente,
   excluyendo `HHI` de los regresores.

Las estimaciones se interpretarán como asociaciones condicionales dentro de un
diseño observacional. No se presentarán como efectos causales.

## 2. Principios y límites

- Utilizar exclusivamente el panel maestro cerrado:
  `data/processed/00_master_panel/master_panel_country_year.dta`.
- Tratar el panel maestro como insumo de solo lectura.
- No modificar datos `raw`, datos procesados ni el constructor del panel.
- No imputar ni interpolar observaciones faltantes.
- No crear proxies, interacciones, submuestras o modelos no previstos.
- Mantener únicamente la interacción `RENTS × INST`.
- Estimar efectos fijos por país y por año.
- Excluir `HHI` únicamente del modelo `DIVX`.
- Desarrollar y validar el análisis sección por sección.
- No incorporar resultados al TFM antes de su revisión conjunta.

## 3. Ubicación de la implementación

Esta candidatura utiliza dos archivos de análisis consecutivos:

```text
scripts/econometrics/stata-peer-2/
  01_data_preparation_diagnostics.do
  02_econometric_models.do
  WORK_PLAN.md
```

El archivo `01_data_preparation_diagnostics.do` contiene las secciones 1 a 4:
configuración, validación del panel, preparación de muestras y diagnósticos. El
archivo `02_econometric_models.do` contiene las secciones 5 a 8: modelos ECI y
DIVX, estabilidad, efectos marginales y exportación final.

La división evita que un único `.do` se vuelva difícil de revisar. No altera la
secuencia metodológica ni duplica estimaciones.

## 4. Reproducibilidad y dependencias

Los archivos pueden ejecutarse desde cualquier directorio de trabajo de Stata,
respetando este orden:

```stata
do "C:/Users/usuario/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-2/01_data_preparation_diagnostics.do"
do "C:/Users/usuario/GitHub/master-thesis-project-applied-econ/scripts/econometrics/stata-peer-2/02_econometric_models.do"
```

Para ejecutarlos desde PowerShell se utilizará el ejecutor incluido:

```powershell
.\scripts\econometrics\stata-peer-2\run_stata_peer_2.cmd -Stage all
```

Este ejecutor guarda el registro automático del modo batch únicamente en
`outputs/econometrics/stata-peer-2/logs/batch/`. Los logs analíticos creados por
los `.do` permanecen en `outputs/econometrics/stata-peer-2/logs/`; por tanto,
ninguna ejecución desde terminal debe crear archivos `.log` en la raíz ni en la
carpeta de los scripts.

El ejecutor fue validado con las etapas 01 y 02 el 29 de julio de 2026. Ambas
terminaron correctamente y sus registros batch quedaron en la ruta prevista.

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
```

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
3. Valores de `INST` para presentar los efectos marginales.
4. Prueba de igualdad entre los coeficientes de los tres recursos.
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

No se avanzará automáticamente de un control al siguiente sin revisar el
resultado de la etapa anterior.
