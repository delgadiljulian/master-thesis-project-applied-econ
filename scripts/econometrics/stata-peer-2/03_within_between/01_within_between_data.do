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
// Archivo: 01_within_between_data.do (Versión Codex)
// Contenido: Secciones 1 a 7 — muestra congelada, medias nacionales y
//            componentes within-between
// Continuación: 02_mundlak_models.do
// Insumo principal: data/processed/00_master_panel/
//                   master_panel_country_year.dta
// Fecha: Segundo Cuatrimestre 2026
//
// ESTADO: ESQUELETO DOCUMENTADO. No contiene código ejecutable.
// *****************************************************************************


// *****************************************************************************
// PROPÓSITO, ALCANCE Y CONTRATO DEL ARCHIVO 01
// *****************************************************************************

* Este archivo preparará el tercer módulo econométrico. Su función será separar,
* para cada regresor incluido, la variación temporal dentro de los países y las
* diferencias persistentes entre países mediante la formulación correlated
* random effects asociada a Mundlak.

* Para una variable X:
*   - X_within(i,t)  = X(i,t) - media_i(X);
*   - X_between(i)   = media_i(X).

* Las medias se calcularán exclusivamente sobre una muestra de estimación
* congelada. No podrán calcularse sobre todas las observaciones disponibles y
* después aplicarse a una submuestra, porque eso rompería la comparación exacta
* con TWFE y alteraría el significado de los componentes.

* Este módulo sustituye el antiguo plan IV/2SLS, pero no ofrece identificación
* instrumental. La dimensión within será comparable con TWFE; la dimensión
* between seguirá expuesta a heterogeneidad estructural no observada y deberá
* interpretarse como comparación descriptiva entre países.

* Este archivo no estimará modelos, no modificará el panel maestro y no mezclará
* controles sin descomponer con medias de otros regresores.

* Entradas previstas:
*   - panel maestro país-año;
*   - definiciones y transformaciones del TWFE principal;
*   - muestra completa común de referencia para ECI y DIVX;
*   - bloques de controles aprobados en el plan de trabajo.

* Salidas previstas:
*   - 00_design/within_between_variable_register.csv;
*   - 01_sample/within_between_sample_summary.csv;
*   - 02_diagnostics/mean_coverage_by_country.csv;
*   - 01_sample/within_between_panel.dta;
*   - logs/01_within_between_data.log.

* Dependencia posterior: los archivos 02 y 03 utilizarán exclusivamente la base
* derivada de este archivo y no recalcularán medias nacionales por su cuenta.


// *****************************************************************************
// 1. Configuración reproducible del entorno
// *****************************************************************************

// 1.1. Limpiar la sesión y fijar Stata

* TODO: fijar versión de Stata, semilla y opciones generales.

* La configuración seguirá 01_twfe_main: Stata 17, precisión double, ejecución
* sin pausas, abreviaciones desactivadas y semillas comunes.


// 1.2. Localizar la raíz del repositorio

* TODO: localizar la raíz del proyecto.

* La búsqueda utilizará el panel maestro como marcador, ascenderá hasta ocho
* niveles y conservará alternativas automática de Windows y manual.


// 1.3. Definir entradas, outputs y log

* TODO: definir rutas de datos, scripts, outputs y logs.

* Las salidas se limitarán a
* outputs/econometrics/stata-peer-2/03_within_between. No se sobrescribirá ningún
* resultado de 01_twfe_main o 02_temporal_fe.


// 1.4. Verificar comandos requeridos

* TODO: enumerar y validar los comandos usados para preparar el panel.

* La creación de componentes deberá usar operaciones transparentes y auditables.
* Cualquier dependencia externa futura se justificará e instalará localmente.


// *****************************************************************************
// 2. Carga y validación del panel maestro
// *****************************************************************************

// 2.1. Integridad de la grilla país-año

* TODO: cargar master_panel_country_year.dta.
* TODO: comprobar llave país-año, cobertura y dimensiones.

* Se verificarán unicidad, países, años, observaciones, balance de la grilla y
* correspondencia entre ISO3, nombre del país e identificador numérico.


// 2.2. Variables, transformaciones e identidades

* TODO: validar variables e identidades requeridas.

* El archivo comprobará ECI, DIVX, RENTS, INST, RENTS × INST, componentes de
* renta y todos los controles candidatos de WB2. Las transformaciones per cápita
* deberán coincidir exactamente con las usadas en TWFE.

* HHI no se incorporará a modelos de DIVX porque DIVX = 1 - HHI.


// 2.3. Declaración del panel

* TODO: declarar la estructura de panel.

* El panel podrá estar desbalanceado en la muestra efectiva. La auditoría
* distinguirá años en la grilla de años válidos usados para calcular cada media.


// *****************************************************************************
// 3. Definición y auditoría de la muestra congelada
// *****************************************************************************

// 3.1. Reproducción de la muestra TWFE

* TODO: reproducir la muestra común del TWFE principal.
* TODO: verificar que ECI y DIVX usan la misma muestra cuando corresponda.

* La muestra principal deberá reconciliarse observación por observación con las
* banderas del TWFE. No bastará con que coincidan N y número de países.


// 3.2. Ventanas nacionales de observación

* TODO: registrar años efectivos por país, primer año, último año y vacíos.

* Para cada país se reportarán observaciones, primer y último año, amplitud de
* ventana, años faltantes internos y proporción efectiva de cobertura.


// 3.3. Umbral de sensibilidad

* TODO: fijar el umbral de años para la sensibilidad de ventana mínima.

* El umbral se congelará antes de revisar coeficientes. La muestra principal no
* excluirá países por duración salvo que el diseño así lo requiera; la restricción
* se reservará para la sensibilidad del archivo 03.


// *****************************************************************************
// 4. Descomposición técnica de Mundlak
// *****************************************************************************

// 4.1. Medias nacionales sobre la muestra congelada

* TODO: calcular medias por país exclusivamente sobre la muestra congelada.

* Las medias deberán permanecer constantes dentro del país y estar ausentes para
* países que no pertenezcan a la muestra. Se verificará que la media ponderada de
* cada componente within sea numéricamente cero dentro de cada país.


// 4.2. Componentes focales

* TODO: crear componentes within y between de RENTS e INST.

* RENTS_within medirá desviaciones respecto del promedio histórico observado del
* país; RENTS_between representará dicho promedio. La misma regla se aplicará a
* INST y a todos los regresores temporales.


// 4.3. Interacción técnica equivalente a TWFE

* TODO: descomponer técnicamente RENTS × INST.

* Para WB0 se descompondrá primero el producto observado P = RENTS × INST en P_w
* y P_b. Esta parametrización permitirá verificar que los coeficientes within
* coinciden con el TWFE focal sobre la misma muestra.


// 4.4. Controles para WB2

* TODO: descomponer cada control antes de incorporarlo a WB2.

* Los bloques se prepararán por separado: abundancia de recursos, estructura
* productiva, macroeconomía, capacidades y condiciones económico-financieras.
* No se construirá automáticamente un modelo saturado con todos los componentes.


// *****************************************************************************
// 5. Expansión sustantiva de la moderación RENTS × INST
// *****************************************************************************

// 5.1. Moderación dentro de los países

* TODO: construir RENTS_within × INST_within.

* Este término representa si cambios institucionales respecto del promedio del
* propio país modifican la asociación de cambios de RENTS con el resultado.


// 5.2. Moderación within por instituciones estructurales

* TODO: construir RENTS_within × INST_between.

* Este término permite que la asociación temporal de RENTS difiera entre países
* con distintos niveles institucionales medios.


// 5.3. Cruce entre exposición estructural y cambio institucional

* TODO: construir RENTS_between × INST_within.


// 5.4. Diferencias estructurales entre países

* TODO: construir RENTS_between × INST_between.

* La expansión de cuatro términos no se interpretará mediante coeficientes
* aislados. El archivo 02 deberá traducirla a efectos marginales sustantivos.


// *****************************************************************************
// 6. Preparación de componentes por tipo de recurso para WB3
// *****************************************************************************

// 6.1. Hidrocarburos y minería/carbón

* TODO: preparar hidrocarburos y minería/carbón para WB3.


// 6.2. Interacciones por recurso

* TODO: construir y descomponer sus interacciones con INST.

* La suma de los componentes de renta deberá reconciliarse con RENTS antes y
* después de la descomposición, dentro de la tolerancia numérica definida.


// *****************************************************************************
// 7. Auditoría, exportación y traspaso
// *****************************************************************************

// 7.1. Registro de variables

* TODO: exportar el registro de variables within-between.

* El registro documentará variable fuente, etiqueta, bloque, transformación,
* componente within, componente between, muestra y uso previsto en WB0--WB3.


// 7.2. Muestra y cobertura de medias

* TODO: exportar el resumen de muestra y cobertura de medias por país.


// 7.3. Base derivada

* TODO: guardar el panel derivado para los archivos 02 y 03.

* within_between_panel.dta conservará la llave país-año, banderas de muestra,
* conteos de años por país, componentes técnicos, expansión sustantiva y
* componentes por recurso.


// 7.4. Controles de cierre

* TODO: escribir el marcador de finalización en el log.

* El archivo se considerará completo únicamente si las medias son constantes por
* país, los componentes within tienen media cero, la muestra coincide con TWFE,
* las identidades se preservan y la base derivada abre en una sesión nueva.

* Marcador futuro de cierre:
* "Archivo Mundlak 01 finalizado: muestra y componentes validados."
