# Plan de trabajo — TWFE con RENTS totales y extensiones por componente

## 1. Función

TWFE es el estimador principal de la tesis. Utiliza la variación temporal dentro
de cada país y absorbe características permanentes y choques comunes por año.
Los resultados se interpretarán como asociaciones condicionales, no causales.

## 2. Resultados dependientes

Cada modelo se estimará con dos resultados:

1. ECI, medida principal de sofisticación exportadora.
2. DIVX = 1 - HHI, medida complementaria de diversificación exportadora.

HHI podrá entrar como regresor cuando la dependiente sea ECI. HHI se excluirá
cuando la dependiente sea DIVX para evitar una identidad mecánica.

## 3. Muestra e inferencia comunes

- Muestra congelada: 1.044 observaciones y 49 países.
- Período general: 1996–2021, con 23 años observados en la muestra completa.
- Misma muestra país-año para M1, M2 y M3.
- Efectos fijos por país y por año.
- Errores estándar agrupados por país.
- Wild cluster bootstrap como sensibilidad inferencial.
- Sin imputación, interpolación o selección según significancia.

La muestra común garantiza que los cambios entre modelos provengan de los
canales incluidos y no de diferencias en disponibilidad de datos.

## 4. Modelo 1 — Estructura extractiva y exportadora

Variables:

- RENTS;
- INST;
- RENTS × INST;
- OILPC, GASPC y COALPC con las transformaciones aprobadas;
- HHI, únicamente cuando la dependiente sea ECI;
- PEXP y FEXP;
- log_GDPPC.

Pregunta:

> ¿La asociación entre las rentas extractivas y la transformación estructural
> permanece después de distinguir la abundancia física de recursos y la
> estructura exportadora?

Este modelo separa rentas obtenidas, abundancia física y especialización
exportadora, tres dimensiones relacionadas pero conceptualmente diferentes.

## 5. Modelo 2 — Capacidades y estabilidad

Variables:

- RENTS;
- INST;
- RENTS × INST;
- VOL y RER;
- HUMCAP, INNOV y NET;
- log_GDPPC;
- GOVCONS y FIN.

Pregunta:

> ¿Qué condiciones institucionales, macroeconómicas, productivas, fiscales y
> financieras están asociadas con trayectorias más favorables, una vez
> controlada la dependencia de las rentas?

Este modelo concentra los factores potencialmente relacionados con estabilidad,
capacidades de absorción y condiciones fiscales y financieras.

## 6. Modelo 3 — TWFE completo original

M3 reúne simultáneamente todos los canales de M1 y M2:

- RENTS, INST y RENTS × INST;
- OILPC, GASPC y COALPC;
- HHI solo para ECI, además de PEXP y FEXP;
- VOL y RER;
- HUMCAP, INNOV y NET;
- log_GDPPC, GOVCONS y FIN.

M3 corresponde al TWFE original ya implementado. No constituye un cuarto
modelo y no se reemplazará por una nueva especificación.

## 7. Lógica comparativa

M1 y M2 son modelos temáticos paralelos. Ninguno es una versión preliminar del
otro. M3 funciona como contraste completo al reunir ambos conjuntos de canales.

La comparación estudiará:

1. estabilidad de RENTS, INST y RENTS × INST;
2. efectos marginales de RENTS en niveles observados de INST;
3. significancia conjunta de cada canal;
4. cambios de magnitud e incertidumbre entre M1, M2 y M3;
5. ajuste within y comportamiento de ECI frente a DIVX.

No se realizará una votación de resultados entre modelos.

## 8. Arquitectura operativa de scripts

El flujo reproducible comprende los archivos `01` a `09` y la auditoría `99`.
El archivo auxiliar `00_validation_helpers.do` centraliza controles repetidos,
pero no constituye una etapa independiente de estimación.

### 8.1. Núcleo principal: archivos 01 a 05

1. `01_data_preparation_diagnostics.do`: preparación, muestra y diagnósticos.
2. `02_twfe_extractive_export_structure.do`: M1 para ECI y DIVX, secciones 5
   y 6.
3. `03_twfe_capabilities_stability.do`: M2 para ECI y DIVX, secciones 7 y 8.
4. `04_twfe_full.do`: M3 completo para ECI y DIVX, secciones 9 a 12.
5. `05_twfe_model_comparison.do`: comparación formal M1--M3, secciones 13 y
   14.

Estos cinco archivos constituyen el análisis TWFE principal. M1 y M2 son
especificaciones temáticas paralelas; M3 es el modelo completo, y el archivo 05
evalúa su estabilidad y comparabilidad sobre la muestra común.

### 8.2. Extensiones: archivos 06 y 07

6. `06_twfe_oil_gas_models.do`: conserva M1 y M2 y añadirá una variante
   completa M3_OG, sustituyendo RENTS totales por RENTS_OIL_GAS.
7. `07_twfe_mining_models.do`: conserva M1 y M2 y añadirá una variante
   completa M3_MIN, sustituyendo RENTS totales por RENTS_MINING.

Estas extensiones permiten examinar heterogeneidad por componente extractivo.
No reemplazan el M3 agregado. M3_OG y M3_MIN se estimarán como especificaciones
alternativas completas, con los mismos canales, muestra e inferencia de M3.

### 8.3. Contraste desagregado formal: archivo 08

8. `08_twfe_resource_disaggregated_full.do`: incorpora conjuntamente
   RENTS_OIL_GAS y RENTS_MINING, con sus interacciones institucionales, como
   contraste desagregado formal del resultado agregado.

El archivo 08 no constituye un modelo principal adicional. Su función es
contrastar si la agregación de las rentas oculta diferencias entre componentes,
preservando sin cambios los resultados generados por los archivos 01 a 07.

### 8.4. Comparación documental de las variantes M3

`compare_m3_variants.ps1` no estima modelos. Lee las salidas validadas de
M3_AGG, M3_OG, M3_MIN y M3_SIM y genera una comparación reproducible de
coeficientes, canales comunes, términos de rentas, ajuste y pruebas conjuntas en
`13_m3_component_comparison`.

### 8.5. Validación de especificación y auditoría final

9. `09_panel_specification_validation.do` compara pooled OLS, FE y RE;
   documenta efectos de país y año, Mundlak/CRE, estacionariedad, primeras
   diferencias, persistencia dinámica e inferencia alternativa. TWFE en niveles
   permanece como especificación principal y las extensiones conservan una
   jerarquía explícitamente secundaria.
99. `99_final_results_audit.do` no estima modelos. Reconciliará los productos
    finales y los resultados del archivo 09 mediante diez controles de
    integridad, muestra, coeficientes, transformaciones, inferencia y decisiones.

Los archivos 09 y 99 deben ejecutarse en ese orden después de disponer de los
productos vigentes de 01 y 04. No modifican el TFM.

## 9. Estado de implementación

- Los archivos 01 a 09 y la auditoría 99 están implementados.
- M1, M2 y M3 utilizan la misma muestra congelada de 1.044 observaciones y 49
  países.
- La comparación M1--M3 del archivo 05 está programada y validada.
- Las extensiones M1 y M2 de petróleo y gas y de minería están programadas en
  archivos separados.
- Las variantes completas M3_OG y M3_MIN quedaron preespecificadas y
  autorizadas el 24 de agosto de 2026. Fueron programadas, ejecutadas y
  validadas en los archivos 06 y 07 sobre 1.044 observaciones y 49 países.
- Cada variante produjo 17 coeficientes para ECI, 16 para DIVX y 12 pruebas
  conjuntas; la verificación `xtreg`--`reghdfe` arrojó diferencia máxima cero.
- Las nueve salidas de cada variante se encuentran aisladas en
  `10_oil_gas_models/03_m3_full` y `11_mining_models/03_m3_full`.
- La comparación de los cuatro M3 fue generada y validada en
  `13_m3_component_comparison`: 136 coeficientes, 29 filas de canales comunes,
  20 términos de rentas, ocho resúmenes de modelo y 54 pruebas conjuntas.
- El contraste desagregado integrado se mantiene aislado en el archivo 08.
- El archivo 09 valida 20 especificaciones, 332 coeficientes sustantivos y 13
  decisiones econométricas; su manifiesto declara 51 productos.
- La auditoría 99 aprueba diez reconciliaciones y verifica el archivo 09 sin
  reestimar ni redefinir el modelo principal.
- Los resultados de cada archivo se almacenan en rutas separadas para evitar
  sobrescrituras.

## 10. Ejecutor

`run_stata_peer_2.ps1` admite ejecuciones individuales y grupos metodológicos:

- `-Stage core`: ejecuta 01, 02, 03, 04 y 05. Es la opción predeterminada.
- `-Stage extensions`: ejecuta 06 y 07, en ese orden.
- `-Stage formal`: ejecuta únicamente 08.
- `-Stage review`: ejecuta 09 y luego 99.
- `-Stage all`: ejecuta 01 a 09 y finalmente 99.
- `-Stage 01` a `-Stage 09` y `-Stage 99`: ejecuta un archivo específico.

Las extensiones requieren que los resultados del núcleo estén disponibles. El
contraste formal requiere, como mínimo, los resultados vigentes de 01 y 04; se
recomienda ejecutarlo después del núcleo completo.

Ejemplo desde la raíz del proyecto:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  ".\scripts\econometrics\stata-peer-2\01_twfe_main\run_stata_peer_2.ps1" `
  -Stage core
```

## 11. Límite para nuevas especificaciones

La pausa anterior se levanta exclusivamente para implementar M3_OG y M3_MIN,
preespecificados antes de observar sus coeficientes completos. No se autorizan
otros modelos, transformaciones ni selecciones de controles. La ausencia de
significancia individual no será un criterio para eliminar variables.

## 12. Límite documental actual

En esta fase no se modificará el TFM. La redacción de resultados se preparará y
revisará primero como insumo separado; su incorporación a los capítulos de la
tesis requerirá una instrucción posterior y explícita.

## 13. Punto de reinicio

1. Ejecutar `-Stage review` para reproducir 09 y 99 sobre los productos
   vigentes.
2. Revisar la matriz de 13 decisiones y los coeficientes completos antes de
   actualizar la metodología, los resultados y las limitaciones del TFM.
3. Modificar el TFM únicamente bajo instrucción explícita.
4. Posponer la refactorización extensa de los scripts hasta cerrar la
   actualización econométrica del manuscrito.

## 14. Preespecificación de M3 por componente

### 14.1. Reglas comunes

- Resultados: ECI y DIVX.
- Muestra exigida: 1.044 observaciones, 49 países y 23 años efectivos dentro de
  1996--2021.
- Estimador: efectos fijos por país con indicadores de año.
- Inferencia principal: errores estándar agrupados por país.
- HHI entra únicamente en la ecuación ECI porque DIVX = 1 - HHI.
- Todos los términos se reportan, independientemente de su significancia.
- Los coeficientes se interpretan como asociaciones condicionales, no causales.

### 14.2. M3_OG

M3_OG sustituye `c.rents##c.inst` por
`c.rents_oil_gas##c.inst` y mantiene sin cambios:

- `ln1p_oilpc ln1p_gaspc ln1p_coalpc`;
- `hhi pexp fexp` para ECI y `pexp fexp` para DIVX;
- `vol rer`;
- `humcap innov net`;
- `log_gdppc govcons fin`.

RENTS totales y RENTS_MINING no entran como regresores en esta variante.

### 14.3. M3_MIN

M3_MIN sustituye `c.rents##c.inst` por
`c.rents_mining##c.inst` y conserva exactamente los mismos controles y reglas
de M3_OG. RENTS totales y RENTS_OIL_GAS no entran como regresores en esta
variante.

### 14.4. Pruebas y salidas mínimas

Cada resultado deberá incluir pruebas conjuntas para los bloques institucional,
abundancia per cápita, estructura exportadora, estabilidad macroeconómica,
capacidades productivas y controles económicos y financieros. Los scripts
deberán exportar, como mínimo, coeficientes completos, resumen del modelo,
pruebas conjuntas, equivalencia `xtreg`--`reghdfe` y una tabla LaTeX/TXT con
columnas ECI y DIVX.

La ejecución validada conserva estos productos en subcarpetas `03_m3_full`
propias de cada componente, sin mezclar las salidas nuevas con los productos
históricos de M1 y M2.

El archivo 08 conserva una función distinta: estima ambos componentes
simultáneamente y permite interpretar cada uno manteniendo constante el otro.
No sustituye las dos variantes alternativas preespecificadas aquí.
