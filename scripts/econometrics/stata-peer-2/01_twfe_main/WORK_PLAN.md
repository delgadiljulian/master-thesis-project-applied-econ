# Plan de trabajo — TWFE con RENTS totales

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

## 8. Arquitectura definitiva de scripts

Se conservan los ocho archivos existentes. Su jerarquía metodológica queda
definida de la siguiente manera.

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

6. `06_twfe_oil_gas_models.do`: replica M1 y M2 sustituyendo RENTS totales por
   RENTS_OIL_GAS.
7. `07_twfe_mining_models.do`: replica M1 y M2 sustituyendo RENTS totales por
   RENTS_MINING.

Estas extensiones permiten examinar heterogeneidad por componente extractivo.
No reemplazan los modelos agregados ni forman parte del núcleo principal.

### 8.3. Contraste desagregado formal: archivo 08

8. `08_twfe_resource_disaggregated_full.do`: incorpora conjuntamente
   RENTS_OIL_GAS y RENTS_MINING, con sus interacciones institucionales, como
   contraste desagregado formal del resultado agregado.

El archivo 08 no constituye un modelo principal adicional. Su función es
contrastar si la agregación de las rentas oculta diferencias entre componentes,
preservando sin cambios los resultados generados por los archivos 01 a 07.

## 9. Estado de implementación

- Los archivos 01 a 08 están implementados.
- M1, M2 y M3 utilizan la misma muestra congelada de 1.044 observaciones y 49
  países.
- La comparación M1--M3 del archivo 05 está programada y validada.
- Las extensiones de petróleo y gas y de minería están programadas en archivos
  separados.
- El contraste desagregado integrado se mantiene aislado en el archivo 08.
- Los resultados de cada archivo se almacenan en rutas separadas para evitar
  sobrescrituras.

## 10. Ejecutor

`run_stata_peer_2.ps1` admite ejecuciones individuales y grupos metodológicos:

- `-Stage core`: ejecuta 01, 02, 03, 04 y 05. Es la opción predeterminada.
- `-Stage extensions`: ejecuta 06 y 07, en ese orden.
- `-Stage formal`: ejecuta únicamente 08.
- `-Stage all`: ejecuta 01 a 08 en orden.
- `-Stage 01` a `-Stage 08`: ejecuta un archivo específico.

Las extensiones requieren que los resultados del núcleo estén disponibles. El
contraste formal requiere, como mínimo, los resultados vigentes de 01 y 04; se
recomienda ejecutarlo después del núcleo completo.

Ejemplo desde la raíz del proyecto:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  ".\scripts\econometrics\stata-peer-2\01_twfe_main\run_stata_peer_2.ps1" `
  -Stage core
```

## 11. Cierre antes de nuevas especificaciones

No se agregarán nuevos modelos ni archivos econométricos hasta completar estas
dos tareas:

1. cerrar la lectura comparativa de M1, M2 y M3, distinguiendo los resultados
   robustos de los sensibles a la especificación;
2. redactar los resultados del núcleo, las extensiones y el contraste formal.

Esta pausa evita ampliar el espacio de especificaciones antes de consolidar la
evidencia ya producida. La ausencia de significancia individual no será un
criterio para eliminar controles aprobados.

## 12. Límite documental actual

En esta fase no se modificará el TFM. La redacción de resultados se preparará y
revisará primero como insumo separado; su incorporación a los capítulos de la
tesis requerirá una instrucción posterior y explícita.

## 13. Punto de reinicio

1. Ejecutar `-Stage core` si se necesita regenerar la comparación principal.
2. Revisar conjuntamente las tablas de M1, M2 y M3 producidas por el archivo
   05.
3. Redactar la síntesis comparativa, sin modificar todavía el TFM.
4. Revisar luego 06, 07 y 08 como evidencia complementaria.
5. No diseñar nuevas especificaciones antes de cerrar esa redacción.
