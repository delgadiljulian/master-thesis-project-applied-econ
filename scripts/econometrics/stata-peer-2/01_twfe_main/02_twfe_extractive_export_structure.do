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
// Archivo: 02_twfe_extractive_export_structure.do (Versión Codex)
// Contenido: Secciones 5 y 6 del análisis econométrico
// Requisito operativo: ejecutar primero el archivo 01
// Estado: implementación completa de las secciones 5 y 6
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************


// *****************************************************************************
// INICIALIZACIÓN DEL ARCHIVO 02
// *****************************************************************************

// A.1. Limpiar la sesión y fijar el entorno reproducible

* Este archivo puede ejecutarse en una sesión nueva después del archivo 01. La numeración econométrica continúa directamente en la sección 5.
version 17.0
* Limpiar la memoria de Stata borrando todas las variables cargadas.
clear all
* Limpiar la consola de comandos de Stata.
cls
* Eliminar todas las variables temporales y globales de la memoria.
macro drop _all
* Cerrar cualquier registro de texto (log) abierto previamente.
capture log close _all

* Fijar precisión, presentación y semillas para obtener resultados repetibles.
set more off
* Evitar que Stata abrevie nombres de variables automáticamente.
set varabbrev off
* Usar precisión doble para evitar errores de redondeo numérico.
set type double
* Ajustar el ancho de consola a 255 caracteres para ver tablas completas.
set linesize 255
* Definir la semilla pseudoaleatoria para hacer 100% reproducibles las simulaciones.
set seed 20260729
* Definir la semilla de ordenamiento para garantizar la reproducibilidad de datos.
set sortseed 20260729


// A.2. Localizar la raíz del proyecto

* Utilizar el panel maestro como marcador estable de la raíz del repositorio.
local project_marker ///
    "data/processed/00_master_panel/master_panel_country_year.dta"

* Examinar el directorio actual, la ruta usual de Windows y una ruta manual.
local project_current "`c(pwd)'"
local project_windows ///
    "C:/Users/`c(username)'/GitHub/master-thesis-project-applied-econ"
local project_manual ""
global PROJECT_ROOT ""

* Buscar el marcador desde el directorio actual y hasta ocho niveles arriba.
local project_candidate "`project_current'"
forvalues search_level = 0/8 {
    if "$PROJECT_ROOT" == "" {
        * Verificar la existencia de un archivo antes de intentar cargarlo.
        capture confirm file "`project_candidate'/`project_marker'"
        if !_rc {
            quietly cd "`project_candidate'"
            global PROJECT_ROOT "`c(pwd)'"
        }
    }
    local project_candidate "`project_candidate'/.."
}

* Probar la ubicación habitual de Windows si la búsqueda anterior falló.
if "$PROJECT_ROOT" == "" {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "`project_windows'/`project_marker'"
    if !_rc {
        global PROJECT_ROOT "`project_windows'"
    }
}

* Probar finalmente la ruta manual cuando haya sido diligenciada.
if "$PROJECT_ROOT" == "" & "`project_manual'" != "" {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "`project_manual'/`project_marker'"
    if !_rc {
        global PROJECT_ROOT "`project_manual'"
    }
}

* Detener la ejecución si ninguna ubicación contiene el repositorio.
if "$PROJECT_ROOT" == "" {
    display as error "No se pudo localizar la raíz del repositorio."
    display as error "Edite local project_manual en la inicialización."
    exit 601
}

* Trabajar desde la raíz identificada y mostrarla para facilitar la revisión.
quietly cd "$PROJECT_ROOT"
display as result "Raíz del proyecto localizada correctamente:"
pwd


// A.3. Definir las entradas, salidas y el log del Modelo 1

* Compartir la base analítica del archivo 01 sin sobrescribir sus resultados.
global OUTPUT_ROOT ///
    "$PROJECT_ROOT/outputs/econometrics/stata-peer-2/01_twfe_main"
global OUTPUT_SAMPLE "$OUTPUT_ROOT/01_sample"
global OUTPUT_M1 ///
    "$OUTPUT_ROOT/08_extractive_export_structure"
global ADO_PROJECT         "$OUTPUT_ROOT/ado"

* Crear únicamente las carpetas propias de M1 y la biblioteca compartida.
capture mkdir "$PROJECT_ROOT/outputs"
capture mkdir "$PROJECT_ROOT/outputs/econometrics"
capture mkdir "$OUTPUT_ROOT"
capture mkdir "$OUTPUT_M1"
capture mkdir "$ADO_PROJECT"
capture mkdir "$ADO_PROJECT/plus"

* Abrir un registro exclusivo de M1 y reemplazar solo su ejecución anterior.
log using "$OUTPUT_M1/02_twfe_extractive_export_structure_full.log", ///
    text replace name(m1_log)


// A.4. Verificar los paquetes previstos para la estimación posterior

* Añadir la biblioteca local sin reemplazar otras rutas disponibles de Stata.
adopath ++ "$ADO_PROJECT/plus"
net set ado "$ADO_PROJECT/plus"

* Instalar ftools si la dependencia de reghdfe todavía no está disponible.
capture which ftools
if _rc {
    display as text "Instalando el paquete ftools desde SSC..."
    ssc install ftools
}

* Instalar reghdfe para verificar después los efectos fijos absorbidos.
capture which reghdfe
if _rc {
    display as text "Instalando el paquete reghdfe desde SSC..."
    ssc install reghdfe
}

* Instalar estout para que esttab exporte las tablas econométricas.
capture which esttab
if _rc {
    display as text "Instalando el paquete estout desde SSC..."
    ssc install estout
}

* Instalar boottest para la sensibilidad wild cluster bootstrap posterior.
capture which boottest
if _rc {
    display as text "Instalando boottest desde su repositorio oficial..."
    net install boottest, ///
        from("https://raw.githubusercontent.com/droodman/boottest/master") ///
        replace
}

* Detener la ejecución si alguna dependencia sigue sin estar disponible.
foreach command in ftools reghdfe esttab boottest {
    capture which `command'
    if _rc {
        display as error "Stata no encuentra el comando requerido: `command'"
        exit 199
    }
}

* Registrar las versiones utilizadas sin instalar o actualizar paquetes.
which ftools
which reghdfe
which esttab
which boottest
mata: mata mlib index


// A.5. Comprobar que el archivo 01 produjo la base analítica

* Guardar la ruta de la copia preparada que alimenta los tres modelos TWFE.
local estimation_file ///
    "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta"

* Detener el archivo si la preparación común todavía no está disponible.
capture confirm file "`estimation_file'"
if _rc {
    display as error "No se encontró la base preparada para las estimaciones."
    display as error "Ejecute primero 01_data_preparation_diagnostics.do."
    exit 601
}

display as result ///
    "Inicialización del archivo 02 completada; comienza la sección 5."


// *****************************************************************************
// 5. Diseño del Modelo 1: Estructura Extractiva y Exportadora
// *****************************************************************************

// 5.1. Delimitar la pregunta y la función del modelo

* Registrar el diseño aprobado antes de estimar o consultar resultados.
tempname design_post
tempfile design_register

* Definir las columnas que documentan la función de cada ecuación de M1.
postfile `design_post' ///
    str8 model str8 outcome str20 role str180 question ///
    str32 hhi_rule str28 sample_rule str32 interpretation ///
    using "`design_register'", replace

* ECI es el resultado principal y admite HHI como dimensión estructural.
post `design_post' ///
    ("M1") ("ECI") ("Principal") ///
    ("¿Permanece la asociación de RENTS al distinguir abundancia física y estructura exportadora?") ///
    ("Incluir HHI") ("Muestra común congelada") ///
    ("Asociación condicional")

* DIVX es complementario y excluye HHI por su identidad contable exacta.
post `design_post' ///
    ("M1") ("DIVX") ("Complementario") ///
    ("¿Permanece la asociación de RENTS al distinguir abundancia física y estructura exportadora?") ///
    ("Excluir HHI: DIVX=1-HHI") ("Muestra común congelada") ///
    ("Asociación condicional")

* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `design_post'

* Validar el registro antes de exportarlo como decisión metodológica de M1.
preserve
    use "`design_register'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 2
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert model == "M1"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert inlist(outcome, "ECI", "DIVX")
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert sample_rule == "Muestra común congelada"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert interpretation == "Asociación condicional"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert hhi_rule == "Incluir HHI" if outcome == "ECI"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert hhi_rule == "Excluir HHI: DIVX=1-HHI" if outcome == "DIVX"
    sort outcome
    export delimited using ///
        "$OUTPUT_M1/m1_design_register.csv", replace datafmt
restore

display as result "5.1. Diseño y función de M1 registrados sin errores."


// 5.2. Cargar y validar la muestra analítica común

* Abrir la copia derivada; el panel maestro y los resultados de M3 no cambian.
use "`estimation_file'", clear

* Confirmar que cada combinación de país y año identifica una sola fila.
isid country_iso3_code year

* Verificar las variables necesarias para delimitar M1 y su muestra común.
confirm variable ///
    country_iso3_code country country_id year ///
    eci divx hhi sample_eci sample_divx ///
    rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp log_gdppc

* Confirmar que los campos econométricos tienen almacenamiento numérico.
foreach variable in ///
    country_id year eci divx hhi sample_eci sample_divx ///
    rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp log_gdppc {
    confirm numeric variable `variable'
}

* Revalidar las identidades que podrían afectar las dos ecuaciones de M1.
assert abs(divx - (1 - hhi)) < 1e-10 if !missing(divx, hhi)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(rents_x_inst - rents * inst) < 1e-10 ///
    if !missing(rents_x_inst, rents, inst)

* Declarar las dimensiones para detectar duplicados o problemas temporales.
xtset country_id year

* Las banderas provienen del modelo completo y congelan la comparación M1-M3.
assert inlist(sample_eci, 0, 1)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert inlist(sample_divx, 0, 1)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_eci == sample_divx
generate byte sample_m1_common = sample_eci == 1 & sample_divx == 1
label variable sample_m1_common "Muestra común congelada de M1, M2 y M3"
* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_m1_common == sample_eci

* Comprobar que los regresores de M1 están completos dentro de esta muestra.
egen int m1_missing_eci = rowmiss( ///
    eci rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp log_gdppc)
egen int m1_missing_divx = rowmiss( ///
    divx rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp log_gdppc)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert m1_missing_eci == 0 if sample_m1_common == 1
* Control de calidad automático que detiene el script si no se cumple la condición.
assert m1_missing_divx == 0 if sample_m1_common == 1

* Contar observaciones, países, años efectivos y extremos temporales.
quietly count if sample_m1_common == 1
local m1_n = r(N)
quietly levelsof country_id if sample_m1_common == 1, ///
    local(m1_country_ids)
local m1_countries : word count `m1_country_ids'
quietly levelsof year if sample_m1_common == 1, local(m1_years)
local m1_year_count : word count `m1_years'
quietly summarize year if sample_m1_common == 1, meanonly
local m1_first_year = r(min)
local m1_last_year = r(max)

* Aplicar los conteos aprobados sin ampliar la muestra de los modelos reducidos.
assert `m1_n' == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `m1_countries' == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `m1_year_count' == 23
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `m1_first_year' == 1996
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `m1_last_year' == 2021

* Confirmar los tres vacíos estructurales de WGI sin imputarlos ni rellenarlos.
foreach structural_wgi_gap in 1997 1999 2001 {
    * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
    quietly count if year == `structural_wgi_gap' & sample_m1_common == 1
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert r(N) == 0
}

* Construir un resumen verificable para ECI y DIVX sobre las mismas llaves.
tempname sample_post
tempfile sample_validation
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `sample_post' ///
    str8 model str8 outcome long observations int countries ///
    int effective_years int first_year int last_year ///
    byte same_country_year_keys byte complete_m1_variables ///
    using "`sample_validation'", replace

* Escribir una fila de resultados dentro del archivo temporal.
post `sample_post' ///
    ("M1") ("ECI") (`m1_n') (`m1_countries') (`m1_year_count') ///
    (`m1_first_year') (`m1_last_year') (1) (1)
* Escribir una fila de resultados dentro del archivo temporal.
post `sample_post' ///
    ("M1") ("DIVX") (`m1_n') (`m1_countries') (`m1_year_count') ///
    (`m1_first_year') (`m1_last_year') (1) (1)
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `sample_post'

* Reabrir el resumen y comprobar su contenido antes de exportarlo.
preserve
    use "`sample_validation'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 2
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert observations == 1044
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert countries == 49
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert effective_years == 23
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert first_year == 1996
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert last_year == 2021
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert same_country_year_keys == 1
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert complete_m1_variables == 1
    sort outcome
    export delimited using ///
        "$OUTPUT_M1/m1_sample_validation.csv", replace datafmt
restore

* Retirar auxiliares; la bandera común queda disponible para la subsección 5.3.
drop m1_missing_eci m1_missing_divx

display as result ///
    "5.2. Muestra común validada: 1.044 observaciones y 49 países."
display as result "ECI y DIVX usan exactamente las mismas llaves país-año."
display as result ///
    "Archivo 02: inicialización y subsecciones 5.1 y 5.2 completadas."


// 5.3. Definir el canal institucional compartido

* Utilizar notación factorial para incluir RENTS, INST y su interacción.
global M1_INSTITUTIONAL ///
    c.rents##c.inst

* Conservar los nombres utilizados en pruebas, tablas y verificaciones.
local m1_institutional_terms ///
    rents inst c.rents#c.inst

* Confirmar que la interacción almacenada coincide con el producto observado.
assert abs(rents_x_inst - rents * inst) < 1e-10 ///
    if sample_m1_common == 1

display as result "5.3. Canal institucional definido sin errores."


// 5.4. Incorporar el canal de abundancia física

* Utilizar las transformaciones ln(1+x) aprobadas en el archivo 01.
global M1_ABUNDANCE ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc

* Estas variables separarán abundancia física de rentas captadas.
foreach variable of global M1_ABUNDANCE {
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert `variable' >= 0 if sample_m1_common == 1
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert !missing(`variable') if sample_m1_common == 1
}

display as result "5.4. Canal de abundancia definido sin errores."


// 5.5. Incorporar el canal de estructura exportadora

* ECI admite HHI junto con las participaciones primarias y de combustibles.
global M1_STRUCTURE_ECI ///
    hhi pexp fexp

* DIVX excluye HHI porque ambas variables mantienen una identidad exacta.
global M1_STRUCTURE_DIVX ///
    pexp fexp

* Revalidar la identidad que impide utilizar HHI en la ecuación DIVX.
assert abs(divx - (1 - hhi)) < 1e-10 ///
    if sample_m1_common == 1

display as result "5.5. Canal de estructura exportadora definido."


// 5.6. Incorporar el control por nivel de desarrollo

* Incorporar el logaritmo del PIB per cápita en las dos ecuaciones.
global M1_DEVELOPMENT ///
    log_gdppc

* Su coeficiente no se interpretará como un efecto causal del desarrollo.
assert !missing(log_gdppc) if sample_m1_common == 1

display as result "5.6. Control por nivel de desarrollo definido."


// 5.7. Fijar efectos, inferencia y salidas

* Reunir los regresores de ECI respetando el orden conceptual aprobado.
global M1_ECI_REGRESSORS ///
    $M1_INSTITUTIONAL ///
    $M1_ABUNDANCE ///
    $M1_STRUCTURE_ECI ///
    $M1_DEVELOPMENT

* Reunir los regresores DIVX sin introducir HHI de manera mecánica.
global M1_DIVX_REGRESSORS ///
    $M1_INSTITUTIONAL ///
    $M1_ABUNDANCE ///
    $M1_STRUCTURE_DIVX ///
    $M1_DEVELOPMENT

* Definir los términos sustantivos que se exportarán en cada ecuación.
local m1_eci_terms ///
    rents inst c.rents#c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp log_gdppc
local m1_divx_terms ///
    rents inst c.rents#c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp log_gdppc

* Aplicar efectos fijos de país y año con agrupamiento por país.
global M1_INFERENCE "vce(cluster country_id)"

* Confirmar que HHI aparezca únicamente en la ecuación ECI.
assert strpos(" $M1_ECI_REGRESSORS ", " hhi ") > 0
* Control de calidad automático que detiene el script si no se cumple la condición.
assert strpos(" $M1_DIVX_REGRESSORS ", " hhi ") == 0

* Registrar cada bloque para que la especificación sea auditable.
tempname variable_post
tempfile variable_register
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `variable_post' ///
    int order str24 channel str24 variable ///
    str8 eci_included str8 divx_included ///
    using "`variable_register'", replace
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (1) ("Institucional") ("RENTS") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (2) ("Institucional") ("INST") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (3) ("Institucional") ("RENTS x INST") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (4) ("Abundancia") ("ln1p_OILPC") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (5) ("Abundancia") ("ln1p_GASPC") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (6) ("Abundancia") ("ln1p_COALPC") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (7) ("Estructura") ("HHI") ("Sí") ("No")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (8) ("Estructura") ("PEXP") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (9) ("Estructura") ("FEXP") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (10) ("Desarrollo") ("log_GDPPC") ("Sí") ("Sí")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `variable_post'

preserve
    use "`variable_register'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 10
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid order
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert divx_included == "No" if variable == "HHI"
    export delimited using ///
        "$OUTPUT_M1/m1_variable_register.csv", replace datafmt
restore

display as result "5.7. Especificaciones e inferencia de M1 fijadas."


// *****************************************************************************
// 6. Estimación del Modelo 1 con ECI y DIVX
// *****************************************************************************

// 6.1. Estimar la ecuación de estructura extractiva con ECI

* Preparar reportes comunes para coeficientes y resúmenes de ambos resultados.
tempname coefficient_post summary_post
tempfile coefficient_report summary_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `coefficient_post' ///
    str8 model str8 outcome int order str32 term ///
    double coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper using "`coefficient_report'", replace
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `summary_post' ///
    str8 model str8 outcome long observations int countries ///
    int clusters int effective_years ///
    double r2_within r2_between r2_overall f_statistic model_p ///
    using "`summary_report'", replace

* Estimar ECI con efectos fijos de país y año sobre la muestra congelada.
xtreg eci $M1_ECI_REGRESSORS i.year ///
    if sample_m1_common == 1, fe $M1_INFERENCE

capture estimates drop ECI_M1
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_M1
estimates save "$OUTPUT_M1/m1_eci.ster", replace

* Verificar que la estimación conserve toda la muestra común aprobada.
assert e(sample) == sample_m1_common
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_clust) == 49

* Conservar resultados focales para bootstrap y comparaciones posteriores.
local eci_base_rents_b = _b[rents]
local eci_base_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local eci_base_interaction_b = _b[c.rents#c.inst]
local eci_base_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))

* Exportar cada término sustantivo con inferencia agrupada por país.
local eci_order = 0
local eci_critical_t = invttail(e(df_r), 0.025)
foreach term of local m1_eci_terms {
    local ++eci_order
    local b = _b[`term']
    local se = _se[`term']
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local lower = `b' - `eci_critical_t' * `se'
    local upper = `b' + `eci_critical_t' * `se'
    scalar m1_eci_b_`eci_order' = `b'
    scalar m1_eci_se_`eci_order' = `se'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `coefficient_post' ///
        ("M1") ("ECI") (`eci_order') ("`term'") ///
        (`b') (`se') (`t') (`p') (`lower') (`upper')
}

* Escribir una fila de resultados dentro del archivo temporal.
post `summary_post' ///
    ("M1") ("ECI") (e(N)) (e(N_g)) (e(N_clust)) ///
    (`m1_year_count') (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
    (e(F)) (e(p))

display as result "6.1. Modelo M1 para ECI estimado sin errores."


// 6.2. Estimar la ecuación de estructura extractiva con DIVX

* Estimar DIVX con la misma muestra y excluir únicamente HHI.
xtreg divx $M1_DIVX_REGRESSORS i.year ///
    if sample_m1_common == 1, fe $M1_INFERENCE

capture estimates drop DIVX_M1
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_M1
estimates save "$OUTPUT_M1/m1_divx.ster", replace

* Confirmar igualdad exacta de observaciones y países con el modelo ECI.
assert e(sample) == sample_m1_common
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_clust) == 49

* Conservar resultados focales para la inferencia bootstrap posterior.
local divx_base_rents_b = _b[rents]
local divx_base_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local divx_base_interaction_b = _b[c.rents#c.inst]
local divx_base_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))

* Añadir los términos DIVX al reporte común de coeficientes.
local divx_order = 0
local divx_critical_t = invttail(e(df_r), 0.025)
foreach term of local m1_divx_terms {
    local ++divx_order
    local b = _b[`term']
    local se = _se[`term']
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local lower = `b' - `divx_critical_t' * `se'
    local upper = `b' + `divx_critical_t' * `se'
    scalar m1_divx_b_`divx_order' = `b'
    scalar m1_divx_se_`divx_order' = `se'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `coefficient_post' ///
        ("M1") ("DIVX") (`divx_order') ("`term'") ///
        (`b') (`se') (`t') (`p') (`lower') (`upper')
}

* Escribir una fila de resultados dentro del archivo temporal.
post `summary_post' ///
    ("M1") ("DIVX") (e(N)) (e(N_g)) (e(N_clust)) ///
    (`m1_year_count') (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
    (e(F)) (e(p))

* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `coefficient_post'
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `summary_post'

* Exportar los coeficientes de las dos ecuaciones en un único archivo.
preserve
    use "`coefficient_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 19
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid outcome order
    sort outcome order
    format coefficient standard_error t_statistic p_value ///
        ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_M1/m1_coefficients.csv", replace datafmt
restore

* Exportar cobertura y ajuste para facilitar la comparación con M2 y M3.
preserve
    use "`summary_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 2
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid outcome
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert observations == 1044
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert countries == 49
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert clusters == 49
    export delimited using ///
        "$OUTPUT_M1/m1_model_summary.csv", replace datafmt
restore

display as result "6.2. Modelo M1 para DIVX estimado sin errores."


// 6.3. Ejecutar pruebas conjuntas por canal

* Registrar las pruebas de los canales sin decidir por coeficientes aislados.
tempname joint_post
tempfile joint_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `joint_post' ///
    str8 model str8 outcome int order str32 channel ///
    str100 null_hypothesis double f_statistic df1 df2 p_value ///
    using "`joint_report'", replace

* Evaluar los canales y restricciones de la ecuación ECI.
estimates restore ECI_M1
test rents inst c.rents#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1") ("ECI") (1) ("Institucional") ///
    ("RENTS, INST e interacción son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test ln1p_oilpc ln1p_gaspc ln1p_coalpc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1") ("ECI") (2) ("Abundancia") ///
    ("Petróleo, gas y carbón son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test hhi pexp fexp
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1") ("ECI") (3) ("Estructura exportadora") ///
    ("HHI, PEXP y FEXP son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test log_gdppc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1") ("ECI") (4) ("Nivel de desarrollo") ///
    ("log_GDPPC es igual a cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1") ("ECI") (5) ("Efectos de año") ///
    ("Todos los indicadores de año son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test (ln1p_oilpc = ln1p_gaspc) ///
     (ln1p_oilpc = ln1p_coalpc)
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1") ("ECI") (6) ("Igualdad entre recursos") ///
    ("Petróleo, gas y carbón tienen el mismo coeficiente") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Repetir las pruebas para DIVX sin introducir HHI.
estimates restore DIVX_M1
test rents inst c.rents#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1") ("DIVX") (1) ("Institucional") ///
    ("RENTS, INST e interacción son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test ln1p_oilpc ln1p_gaspc ln1p_coalpc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1") ("DIVX") (2) ("Abundancia") ///
    ("Petróleo, gas y carbón son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test pexp fexp
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1") ("DIVX") (3) ("Estructura exportadora") ///
    ("PEXP y FEXP son conjuntamente cero; HHI está excluido") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test log_gdppc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1") ("DIVX") (4) ("Nivel de desarrollo") ///
    ("log_GDPPC es igual a cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1") ("DIVX") (5) ("Efectos de año") ///
    ("Todos los indicadores de año son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test (ln1p_oilpc = ln1p_gaspc) ///
     (ln1p_oilpc = ln1p_coalpc)
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1") ("DIVX") (6) ("Igualdad entre recursos") ///
    ("Petróleo, gas y carbón tienen el mismo coeficiente") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `joint_post'

preserve
    use "`joint_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 12
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid outcome order
    sort outcome order
    format f_statistic p_value %12.6f
    export delimited using ///
        "$OUTPUT_M1/m1_joint_tests.csv", replace datafmt
restore

display as result "6.3. Pruebas conjuntas de M1 completadas."


// 6.4. Interpretar la interacción RENTS por INST

* Definir percentiles institucionales observados en la muestra congelada.
quietly summarize inst if sample_m1_common == 1, detail
local inst_p10 = r(p10)
local inst_p25 = r(p25)
local inst_p50 = r(p50)
local inst_p75 = r(p75)
local inst_p90 = r(p90)
local inst_values ///
    "`inst_p10' `inst_p25' `inst_p50' `inst_p75' `inst_p90'"
local inst_labels "P10 P25 P50 P75 P90"

* Preparar un reporte común de efectos marginales para ECI y DIVX.
tempname margins_post
tempfile margins_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `margins_post' ///
    str8 model str8 outcome int order str8 percentile ///
    double inst_value marginal_effect standard_error p_value ///
    ci_lower ci_upper using "`margins_report'", replace

* Calcular y graficar la asociación marginal de RENTS para ECI.
estimates restore ECI_M1
margins, dydx(rents) at(inst=(`inst_values'))
matrix eci_margins = r(table)
forvalues column = 1/5 {
    local inst_value : word `column' of `inst_values'
    local percentile : word `column' of `inst_labels'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `margins_post' ///
        ("M1") ("ECI") (`column') ("`percentile'") ///
        (`inst_value') ///
        (el(eci_margins, 1, `column')) ///
        (el(eci_margins, 2, `column')) ///
        (el(eci_margins, 4, `column')) ///
        (el(eci_margins, 5, `column')) ///
        (el(eci_margins, 6, `column'))
}
marginsplot, ///
    recast(line) recastci(rarea) ///
    yline(0, lpattern(dash) lcolor(gs8)) ///
    xlabel( ///
        `inst_p10' "P10" ///
        `inst_p25' "P25" ///
        `inst_p50' "P50" ///
        `inst_p75' "P75" ///
        `inst_p90' "P90", labsize(small)) ///
    title("ECI", size(medsmall)) ///
    xtitle("Percentil de calidad institucional", size(small)) ///
    ytitle("Asociación marginal de RENTS", size(small)) ///
    graphregion(color(white)) ///
    name(m1_eci_margins, replace)

* Calcular y graficar la asociación marginal de RENTS para DIVX.
estimates restore DIVX_M1
margins, dydx(rents) at(inst=(`inst_values'))
matrix divx_margins = r(table)
forvalues column = 1/5 {
    local inst_value : word `column' of `inst_values'
    local percentile : word `column' of `inst_labels'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `margins_post' ///
        ("M1") ("DIVX") (`column') ("`percentile'") ///
        (`inst_value') ///
        (el(divx_margins, 1, `column')) ///
        (el(divx_margins, 2, `column')) ///
        (el(divx_margins, 4, `column')) ///
        (el(divx_margins, 5, `column')) ///
        (el(divx_margins, 6, `column'))
}
marginsplot, ///
    recast(line) recastci(rarea) ///
    yline(0, lpattern(dash) lcolor(gs8)) ///
    xlabel( ///
        `inst_p10' "P10" ///
        `inst_p25' "P25" ///
        `inst_p50' "P50" ///
        `inst_p75' "P75" ///
        `inst_p90' "P90", labsize(small)) ///
    title("DIVX", size(medsmall)) ///
    xtitle("Percentil de calidad institucional", size(small)) ///
    ytitle("Asociación marginal de RENTS", size(small)) ///
    graphregion(color(white)) ///
    name(m1_divx_margins, replace)

* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `margins_post'

preserve
    use "`margins_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 10
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid outcome order
    sort outcome order
    format inst_value marginal_effect standard_error ///
        p_value ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_M1/m1_marginal_effects.csv", replace datafmt
restore

* Combinar ambos resultados sin imponer una escala vertical común.
graph combine m1_eci_margins m1_divx_margins, ///
    cols(2) graphregion(color(white)) ///
    title("Asociación marginal de RENTS según INST", size(medsmall)) ///
    note( ///
        "Modelo M1; asociaciones condicionales con IC del 95 %", ///
        size(vsmall)) ///
    name(m1_margins_combined, replace)
graph export "$OUTPUT_M1/m1_marginal_effects.pdf", replace
graph export "$OUTPUT_M1/m1_marginal_effects.png", ///
    width(3000) replace

* Aplicar bootstrap a RENTS y a la interacción en ambas ecuaciones.
tempname bootstrap_post
tempfile bootstrap_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `bootstrap_post' ///
    str8 model str8 outcome str24 term ///
    double coefficient conventional_p bootstrap_p ///
    ci_lower ci_upper repetitions str12 weight_type ///
    using "`bootstrap_report'", replace

quietly xtreg eci $M1_ECI_REGRESSORS i.year ///
    if sample_m1_common == 1, fe $M1_INFERENCE
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(_b[rents] - `eci_base_rents_b') < 1e-10
boottest rents, cluster(country_id) reps(9999) ///
    seed(20260803) nograph
* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(r(p))
matrix eci_rents_ci = r(CI)
* Escribir una fila de resultados dentro del archivo temporal.
post `bootstrap_post' ///
    ("M1") ("ECI") ("RENTS") ///
    (_b[rents]) (`eci_base_rents_p') (r(p)) ///
    (el(eci_rents_ci, 1, 1)) (el(eci_rents_ci, 1, 2)) ///
    (r(reps)) ("`r(weighttype)'")

boottest c.rents#c.inst, cluster(country_id) reps(9999) ///
    seed(20260804) nograph
* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(r(p))
matrix eci_interaction_ci = r(CI)
* Escribir una fila de resultados dentro del archivo temporal.
post `bootstrap_post' ///
    ("M1") ("ECI") ("RENTS x INST") ///
    (_b[c.rents#c.inst]) (`eci_base_interaction_p') (r(p)) ///
    (el(eci_interaction_ci, 1, 1)) ///
    (el(eci_interaction_ci, 1, 2)) ///
    (r(reps)) ("`r(weighttype)'")

quietly xtreg divx $M1_DIVX_REGRESSORS i.year ///
    if sample_m1_common == 1, fe $M1_INFERENCE
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(_b[rents] - `divx_base_rents_b') < 1e-10
boottest rents, cluster(country_id) reps(9999) ///
    seed(20260805) nograph
* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(r(p))
matrix divx_rents_ci = r(CI)
* Escribir una fila de resultados dentro del archivo temporal.
post `bootstrap_post' ///
    ("M1") ("DIVX") ("RENTS") ///
    (_b[rents]) (`divx_base_rents_p') (r(p)) ///
    (el(divx_rents_ci, 1, 1)) (el(divx_rents_ci, 1, 2)) ///
    (r(reps)) ("`r(weighttype)'")

boottest c.rents#c.inst, cluster(country_id) reps(9999) ///
    seed(20260806) nograph
* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(r(p))
matrix divx_interaction_ci = r(CI)
* Escribir una fila de resultados dentro del archivo temporal.
post `bootstrap_post' ///
    ("M1") ("DIVX") ("RENTS x INST") ///
    (_b[c.rents#c.inst]) (`divx_base_interaction_p') (r(p)) ///
    (el(divx_interaction_ci, 1, 1)) ///
    (el(divx_interaction_ci, 1, 2)) ///
    (r(reps)) ("`r(weighttype)'")

* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `bootstrap_post'

preserve
    use "`bootstrap_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 4
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid outcome term
    sort outcome term
    format coefficient conventional_p bootstrap_p ///
        ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_M1/m1_wild_cluster_bootstrap.csv", ///
        replace datafmt
restore

display as result "6.4. Efectos marginales y bootstrap completados."


// 6.5. Verificar y exportar el Modelo 1

* Comparar los coeficientes de xtreg con efectos fijos absorbidos.
tempname verification_post
tempfile verification_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `verification_post' ///
    str8 model str8 outcome int order str32 term ///
    double xtreg_coefficient reghdfe_coefficient ///
    absolute_difference byte coefficient_match ///
    using "`verification_report'", replace

local coefficient_tolerance = 1e-8
* Estimar el modelo de regresión con efectos fijos de país y año y errores agrupados.
reghdfe eci $M1_ECI_REGRESSORS ///
    if sample_m1_common == 1, ///
    absorb(country_id year) $M1_INFERENCE
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
local eci_order = 0
foreach term of local m1_eci_terms {
    local ++eci_order
    local xtreg_b = scalar(m1_eci_b_`eci_order')
    local hdfe_b = _b[`term']
    local difference = abs(`xtreg_b' - `hdfe_b')
    local match = `difference' < `coefficient_tolerance'
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert `match' == 1
    * Escribir una fila de resultados dentro del archivo temporal.
    post `verification_post' ///
        ("M1") ("ECI") (`eci_order') ("`term'") ///
        (`xtreg_b') (`hdfe_b') (`difference') (`match')
}

* Estimar el modelo de regresión con efectos fijos de país y año y errores agrupados.
reghdfe divx $M1_DIVX_REGRESSORS ///
    if sample_m1_common == 1, ///
    absorb(country_id year) $M1_INFERENCE
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
local divx_order = 0
foreach term of local m1_divx_terms {
    local ++divx_order
    local xtreg_b = scalar(m1_divx_b_`divx_order')
    local hdfe_b = _b[`term']
    local difference = abs(`xtreg_b' - `hdfe_b')
    local match = `difference' < `coefficient_tolerance'
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert `match' == 1
    * Escribir una fila de resultados dentro del archivo temporal.
    post `verification_post' ///
        ("M1") ("DIVX") (`divx_order') ("`term'") ///
        (`xtreg_b') (`hdfe_b') (`difference') (`match')
}

* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `verification_post'

preserve
    use "`verification_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 19
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert coefficient_match == 1
    sort outcome order
    format xtreg_coefficient reghdfe_coefficient ///
        absolute_difference %16.10f
    export delimited using ///
        "$OUTPUT_M1/m1_xtreg_reghdfe_verification.csv", ///
        replace datafmt
restore

* Crear una tabla compacta de las dos ecuaciones del Modelo 1.
esttab ECI_M1 DIVX_M1 using "$OUTPUT_M1/m1_results_table.tex", ///
    replace booktabs label se ///
    b(4) se(4) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp log_gdppc) ///
    order( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp log_gdppc) ///
    mtitles("ECI" "DIVX") ///
    stats(N N_g r2_w, ///
        labels("Observaciones" "Países" "R2 within")) ///
    addnotes( ///
        "Efectos fijos por país y año.", ///
        "Errores estándar agrupados por país.", ///
        "HHI se excluye de DIVX porque DIVX = 1 - HHI.")

* Registrar los productos finales sin crear subcarpetas innecesarias.
tempname manifest_post
tempfile manifest_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `manifest_post' ///
    int order str32 family str80 file str140 purpose ///
    using "`manifest_report'", replace
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (1) ("Diseño") ("m1_design_register.csv") ///
    ("Pregunta, resultados y regla de exclusión de HHI.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (2) ("Diseño") ("m1_variable_register.csv") ///
    ("Variables y canales incluidos en ECI y DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (3) ("Muestra") ("m1_sample_validation.csv") ///
    ("Validación de 1.044 observaciones y 49 países.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (4) ("Estimación") ("m1_eci.ster") ///
    ("Estimación principal M1 para ECI.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (5) ("Estimación") ("m1_divx.ster") ///
    ("Estimación complementaria M1 para DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (6) ("Resultados") ("m1_coefficients.csv") ///
    ("Coeficientes, errores e intervalos de las dos ecuaciones.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (7) ("Resultados") ("m1_model_summary.csv") ///
    ("Cobertura y ajuste within de ECI y DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (8) ("Inferencia") ("m1_joint_tests.csv") ///
    ("Pruebas conjuntas por canal y restricciones.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (9) ("Inferencia") ("m1_wild_cluster_bootstrap.csv") ///
    ("Bootstrap para RENTS y RENTS x INST.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (10) ("Interpretación") ("m1_marginal_effects.csv") ///
    ("Asociación marginal de RENTS según percentiles de INST.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (11) ("Verificación") ("m1_xtreg_reghdfe_verification.csv") ///
    ("Equivalencia numérica entre xtreg y reghdfe.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (12) ("Tabla") ("m1_results_table.tex") ///
    ("Tabla LaTeX compacta del Modelo 1.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (13) ("Figura") ("m1_marginal_effects.pdf") ///
    ("Figura comparada apta para LaTeX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (14) ("Figura") ("m1_marginal_effects.png") ///
    ("Figura comparada para inspección visual.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (15) ("Documentación") ("m1_results_manifest.csv") ///
    ("Inventario reproducible de productos de M1.")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `manifest_post'

preserve
    use "`manifest_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 15
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid order
    export delimited using ///
        "$OUTPUT_M1/m1_results_manifest.csv", replace datafmt
restore

* Comprobar que todos los archivos declarados fueron creados.
local required_files ///
    m1_design_register.csv ///
    m1_variable_register.csv ///
    m1_sample_validation.csv ///
    m1_eci.ster ///
    m1_divx.ster ///
    m1_coefficients.csv ///
    m1_model_summary.csv ///
    m1_joint_tests.csv ///
    m1_wild_cluster_bootstrap.csv ///
    m1_marginal_effects.csv ///
    m1_xtreg_reghdfe_verification.csv ///
    m1_results_table.tex ///
    m1_marginal_effects.pdf ///
    m1_marginal_effects.png ///
    m1_results_manifest.csv

foreach required_file of local required_files {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "$OUTPUT_M1/`required_file'"
    if _rc {
        display as error "Falta el producto de M1: `required_file'"
        exit 603
    }
}

* Cerrar el archivo con el resultado complementario nuevamente activo.
estimates restore DIVX_M1
display as result ///
    "Archivo 02 finalizado: secciones 5 y 6 completadas sin errores."
display as text ///
    "Los resultados describen asociaciones condicionales, no causales."
log close m1_log
