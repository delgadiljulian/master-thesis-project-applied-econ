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
// Archivo: 03_equivalence_and_sensitivity.do (Versión Codex)
// Contenido: Secciones 15 a 21 — WB3, estabilidad, ventanas de observación y
//            decisión metodológica
// Requisitos: completar y aprobar los archivos Mundlak 01 y 02
// Fecha: Segundo Cuatrimestre 2026
//
// ESTADO: ESQUELETO DOCUMENTADO. No contiene código ejecutable.
// *****************************************************************************


// *****************************************************************************
// PROPÓSITO, ALCANCE Y CONTRATO DEL ARCHIVO 03
// *****************************************************************************

* Este archivo evaluará si la descomposición within-between es suficientemente
* estable para incorporarse al TFM. Ampliará WB1 por tipo de recurso únicamente
* si WB0 y WB1 fueron aprobados, y someterá los componentes focales a exclusión
* de países, ventanas mínimas e inferencia bootstrap.

* La estabilidad de los componentes between merece especial atención porque su
* dimensión efectiva es el número de países. Un coeficiente estimado con muchas
* observaciones país-año puede seguir siendo frágil si depende de uno o dos países.

* Este archivo no cambiará la muestra, controles o umbrales después de observar
* resultados. Si WB3 es demasiado dimensional o inestable, el módulo podrá
* conservar WB0/WB1 y excluir la desagregación con una justificación explícita.

* Entradas previstas:
*   - 01_sample/within_between_panel.dta;
*   - prueba de equivalencia WB0;
*   - estimaciones WB1 y diagnósticos WB2 del archivo 02.

* Salidas previstas:
*   - 06_heterogeneity/resource_within_between.csv;
*   - 07_stability/between_leave_one_out.csv;
*   - 07_stability/minimum_window_sensitivity.csv;
*   - 07_stability/within_between_bootstrap.csv;
*   - 08_final/within_between_acceptance_decision.csv;
*   - logs/03_equivalence_and_sensitivity.log.


// *****************************************************************************
// 15. Inicialización y verificación de condiciones de entrada
// *****************************************************************************

// 15.1. Entorno, raíz y rutas

* TODO: configurar Stata y localizar la raíz del proyecto.
* TODO: definir rutas de entrada, outputs y logs.


// 15.2. Verificar datos y resultados previos

* TODO: cargar y validar el panel within-between congelado.
* TODO: verificar que WB0 fue aprobado antes de continuar.

* La ejecución se detendrá si la equivalencia TWFE--CRE no fue aprobada, si la
* base derivada cambió o si faltan las estimaciones WB1 que sirven de referencia.


// *****************************************************************************
// 16. WB3 — desagregación por tipo de recurso
// *****************************************************************************

// 16.1. Componentes de hidrocarburos

* TODO: estimar componentes de hidrocarburos para ECI y DIVX.


// 16.2. Componentes de minería/carbón

* TODO: estimar componentes de minería/carbón para ECI y DIVX.


// 16.3. Moderación institucional por recurso

* TODO: calcular efectos marginales condicionados por INST.


// 16.4. Comparación con RENTS agregada

* TODO: exportar comparaciones agregadas y desagregadas.

* WB3 respetará las identidades contables y comparará resultados sobre una
* muestra común. No se atribuirán diferencias a tipos de recurso si provienen de
* cambios de cobertura.


// *****************************************************************************
// 17. Estabilidad leave-one-country-out
// *****************************************************************************

// 17.1. Esquema de exclusión

* TODO: excluir un país por vez en WB1.


// 17.2. Componentes within

* TODO: registrar estabilidad de los componentes within.


// 17.3. Componentes between

* TODO: registrar estabilidad de los componentes between.


// 17.4. Resumen de influencia nacional

* TODO: identificar dependencia de uno o dos países sin excluirlos ad hoc.

* Por iteración se guardarán país omitido, N, clusters, coeficientes, errores,
* valores p y diferencias frente al modelo completo. El resumen distinguirá
* inestabilidad de signo, magnitud y precisión.


// *****************************************************************************
// 18. Sensibilidad a la ventana nacional de observación
// *****************************************************************************

// 18.1. Aplicar el umbral predefinido

* TODO: exigir el mínimo predefinido de años por país.


// 18.2. Cambio de composición y coeficientes

* TODO: comparar composición de muestra y coeficientes.


// 18.3. Trayectorias cortas o discontinuas

* TODO: revisar países con ventanas cortas o discontinuas.

* La sensibilidad recalculará las medias dentro de la muestra restringida; no
* reutilizará medias de la muestra principal cuando cambie el conjunto de años.


// *****************************************************************************
// 19. Estabilidad inferencial y contraste within--between
// *****************************************************************************

// 19.1. Wild cluster bootstrap

* TODO: resumir wild cluster bootstrap de componentes focales.


// 19.2. Signos, magnitudes e intervalos between

* TODO: evaluar signos, magnitudes e intervalos de los términos between.


// 19.3. Igualdad de asociaciones

* TODO: contrastar beta_within = beta_between.

* La interpretación separará evidencia de diferencia estadística, magnitud
* económica y estabilidad a exclusiones. Ningún criterio aislado decidirá la
* inclusión del módulo.


// *****************************************************************************
// 20. Matriz de decisión metodológica WB-A--WB-G
// *****************************************************************************

* TODO: verificar las reglas WB-A a WB-G.
* TODO: decidir si se incorpora WB1, WB2, WB3 o solo WB0.
* TODO: documentar exclusiones por inestabilidad o dimensionalidad.
* TODO: mantener una interpretación asociativa y no causal.

* La matriz registrará por componente:
*   - coincidencia de muestra con TWFE;
*   - equivalencia WB0;
*   - número efectivo de países;
*   - colinealidad between;
*   - estabilidad leave-one-country-out;
*   - sensibilidad a ventanas mínimas;
*   - disponibilidad de efectos marginales interpretables;
*   - lenguaje permitido para el TFM.

* Decisiones posibles: incorporar WB1 como extensión principal; incorporar WB2
* o WB3 solo como sensibilidad; reportar únicamente la equivalencia WB0; o
* excluir el módulo completo con una explicación reproducible.


// *****************************************************************************
// 21. Exportación, manifiesto y cierre del módulo Mundlak
// *****************************************************************************

* TODO: exportar heterogeneidad, estabilidad y sensibilidad.
* TODO: exportar la decisión de aceptación del módulo Mundlak.
* TODO: escribir el marcador de finalización en el log.

* El manifiesto final identificará todos los archivos producidos y cuáles pueden
* utilizarse en el cuerpo del TFM, en anexos o únicamente como auditoría interna.
* Este archivo no editará el documento de tesis automáticamente.

* Marcador futuro de cierre:
* "Archivo Mundlak 03 finalizado: WB3, estabilidad y decisión validadas."
