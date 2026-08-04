// *****************************************************************************
// Universidad: Universidad de Buenos Aires
// Facultad: Facultad de Ciencias Económicas
// Escuela: Escuela de Negocios y Administración Pública
// Programa: Maestría en Economía Aplicada
//
// Tipo de trabajo: Trabajo Final de Maestría (TFM)
// Título: Rentas extractivas y transformación estructural externa en economías
//         dependientes de recursos naturales no renovables del subsuelo
//         (1996--2021)
// Autor: Julián Alberto Delgadillo Marín
// Director: Martín Grandes
//
// Módulo: 03_within_between — Descomposición de Mundlak
// Archivo: 02_mundlak_models.do (Versión Codex)
// Contenido: Secciones 8 a 14 — WB0, WB1, WB2, equivalencia TWFE--CRE e
//            inferencia
// Requisito: ejecutar primero 01_within_between_data.do
// Continuación: 03_equivalence_and_sensitivity.do
// Fecha: Segundo Cuatrimestre 2026
//
// ESTADO: ESQUELETO DOCUMENTADO. No contiene código ejecutable.
// *****************************************************************************


// *****************************************************************************
// PROPÓSITO, ALCANCE Y CONTRATO DEL ARCHIVO 02
// *****************************************************************************

* Este archivo realizará la estimación principal del módulo within-between. La
* primera obligación será demostrar la equivalencia técnica entre los
* coeficientes within de un modelo correlated random effects y los coeficientes
* del TWFE focal, manteniendo idénticas variables, muestra y efectos de año.

* Solo después de aprobar WB0 se estimará WB1, que separa la moderación temporal
* y estructural mediante cuatro interacciones. WB2 añadirá bloques de controles
* de forma parsimoniosa para respetar que la dimensión between efectiva es el
* número de países y no el total de observaciones país-año.

* Preguntas que deberá responder:
*   1. ¿los componentes within reproducen exactamente el TWFE focal?;
*   2. ¿la asociación de cambios de RENTS difiere de la comparación entre países?;
*   3. ¿el nivel institucional medio modera la asociación temporal de RENTS?;
*   4. ¿los resultados sobreviven a bloques de controles descompuestos?;
*   5. ¿los componentes between son suficientemente precisos e informativos?

* Los resultados between no se presentarán como efectos causales. La inclusión
* de medias de Mundlak relaja la independencia entre regresores y heterogeneidad
* nacional, pero no elimina confusores estructurales no observados.

* Entrada exclusiva prevista:
*   - 01_sample/within_between_panel.dta, producido por el archivo 01.

* Salidas previstas:
*   - 02_diagnostics/between_collinearity.csv;
*   - 03_equivalence/twfe_cre_equivalence.csv;
*   - 04_eci/eci_within_between_coefficients.csv;
*   - 05_divx/divx_within_between_coefficients.csv;
*   - tablas de efectos marginales y pruebas de Mundlak;
*   - modelos .ster requeridos por el archivo 03;
*   - logs/02_mundlak_models.log.


// *****************************************************************************
// 8. Inicialización reproducible del archivo 02
// *****************************************************************************

// 8.1. Entorno, raíz y rutas

* TODO: configurar Stata y localizar la raíz del proyecto.
* TODO: definir rutas de entrada, outputs y logs.

* El archivo deberá ejecutarse en una sesión nueva y usar exclusivamente las
* carpetas del módulo 03_within_between.


// 8.2. Verificar el insumo congelado

* TODO: cargar y validar el panel within-between congelado.

* Se comprobarán llave país-año, muestra, constancia de medias, media cero de los
* componentes within y existencia de todas las variables necesarias para WB0--WB2.


// 8.3. Dependencias de estimación y exportación

* TODO: verificar los estimadores, pruebas y comandos de exportación requeridos.

* Cualquier paquete externo se instalará en la biblioteca ado local. El archivo
* deberá detenerse si una función crítica no está disponible.


// *****************************************************************************
// 9. Diagnósticos de dimensionalidad between
// *****************************************************************************

// 9.1. Inflación de varianza

* TODO: calcular VIF de los componentes between.

* Los VIF se calcularán sobre la muestra efectiva y se presentarán por bloque,
* evitando mezclar especificaciones que nunca se estimarán juntas.


// 9.2. Condición de la matriz

* TODO: evaluar la condición de la matriz de regresores between.


// 9.3. Regla de estimabilidad

* TODO: documentar bloques que no sean estimables de forma informativa.

* Un bloque podrá descartarse por colinealidad, falta de variación o relación
* desfavorable entre parámetros between y países. No se reducirán variables
* dentro de un bloque porque una de ellas resulte no significativa.


// *****************************************************************************
// 10. WB0 — equivalencia técnica TWFE--CRE
// *****************************************************************************

// 10.1. Referencia TWFE focal

* TODO: reestimar el modelo focal TWFE sobre la muestra congelada.

* Se estimarán ECI y DIVX con RENTS, INST y el producto observado, efectos fijos
* de país y año y errores agrupados por país.


// 10.2. CRE con interacción técnica descompuesta

* TODO: estimar el CRE con componentes técnicos within y between.

* El CRE incluirá RENTS_w, INST_w, P_w, RENTS_b, INST_b y P_b, además de efectos
* de año. La comparación se centrará en los tres coeficientes within.


// 10.3. Equivalencia para ECI y DIVX

* TODO: comparar coeficientes within para ECI.
* TODO: comparar coeficientes within para DIVX.

* La tabla de equivalencia registrará coeficiente TWFE, coeficiente CRE within,
* errores estándar, diferencia absoluta, tolerancia y estado de la comprobación.


// 10.4. Regla de bloqueo

* TODO: bloquear el módulo si la equivalencia no se explica por parametrización.

* No se avanzará a una interpretación sustantiva si las diferencias provienen de
* muestras, ponderaciones o variables incompatibles. Cualquier discrepancia debe
* diagnosticarse y corregirse, no tolerarse por conveniencia.


// *****************************************************************************
// 11. WB1 — modelo focal sustantivo
// *****************************************************************************

// 11.1. Expansión de cuatro interacciones

* TODO: estimar la expansión completa de la interacción para ECI.
* TODO: estimar la expansión completa de la interacción para DIVX.

* WB1 incluirá los efectos principales within y between de RENTS e INST y los
* cruces R_w×I_w, R_w×I_b, R_b×I_w y R_b×I_b, junto con efectos de año.


// 11.2. Efectos marginales

* TODO: calcular efectos marginales within y between interpretables.

* Los efectos de RENTS se evaluarán en valores institucionales sustantivos y
* predefinidos, con intervalos de confianza derivados de la matriz completa.


// 11.3. Diferencia entre fuentes de variación

* TODO: probar igualdad entre asociaciones within y between.

* El rechazo de igualdad indicará que mezclar cambios nacionales y diferencias
* entre países oculta heterogeneidad. No implicará que uno de los coeficientes
* sea causal o que el otro sea inválido.


// *****************************************************************************
// 12. WB2 — bloques parsimoniosos de controles
// *****************************************************************************

// 12.1. Abundancia y composición de recursos

* TODO: añadir por separado el bloque de abundancia de recursos.


// 12.2. Estructura productiva

* TODO: añadir por separado el bloque de estructura productiva.


// 12.3. Condiciones macroeconómicas

* TODO: añadir por separado el bloque macroeconómico.


// 12.4. Capacidades productivas e institucionales

* TODO: añadir por separado el bloque de capacidades.


// 12.5. Condiciones económicas y financieras

* TODO: añadir por separado el bloque económico-financiero.


// 12.6. Restricción definicional de DIVX

* TODO: excluir HHI de toda ecuación cuya dependiente sea DIVX.

* Cada bloque entrará con sus componentes within y between. Se registrarán N,
* países, parámetros, coeficientes focales y pruebas conjuntas de sus medias.


// *****************************************************************************
// 13. Inferencia, pruebas de Mundlak y comparación
// *****************************************************************************

// 13.1. Inferencia agrupada por país

* TODO: utilizar errores estándar agrupados por país.


// 13.2. Wild cluster bootstrap

* TODO: ejecutar wild cluster bootstrap para componentes focales.

* Se documentarán número de clusters, repeticiones, semilla y términos probados.
* El bootstrap será sensibilidad y no criterio para seleccionar especificaciones.


// 13.3. Prueba conjunta de componentes between

* TODO: probar conjuntamente las medias de Mundlak.

* La prueba permitirá evaluar si un modelo de efectos aleatorios simples que
* omitiera las medias sería compatible con los datos, sin convertirla en una
* prueba suficiente de ausencia de endogeneidad.


// *****************************************************************************
// 14. Exportación, validación y traspaso al archivo 03
// *****************************************************************************

* TODO: exportar equivalencia TWFE–CRE.
* TODO: exportar coeficientes y efectos marginales de ECI y DIVX.
* TODO: exportar diagnósticos between y pruebas conjuntas.
* TODO: guardar estimaciones requeridas por el archivo 03.
* TODO: escribir el marcador de finalización en el log.

* Cada salida identificará resultado, modelo WB0--WB2, bloque, componente,
* término, coeficiente, error, estadístico, valor p, intervalo, N, países y años.

* El archivo solo se considerará completo si WB0 aprueba la equivalencia, WB1
* puede interpretarse mediante efectos marginales y los bloques WB2 respetan la
* dimensionalidad between.

* Marcador futuro de cierre:
* "Archivo Mundlak 02 finalizado: WB0--WB2 e inferencia validados."
