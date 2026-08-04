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
// Archivo: 03_twfe_capabilities_stability.do (Versión Codex)
// Contenido: Secciones 7 y 8 del análisis econométrico
// Requisito operativo: ejecutar primero el archivo 01
// Estado: implementación completa de las secciones 7 y 8
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************


// *****************************************************************************
// INICIALIZACIÓN DEL ARCHIVO 03
// *****************************************************************************

// A.1. Limpiar la sesión y fijar el entorno reproducible

* Este archivo puede ejecutarse en una sesión nueva después del archivo 01. La numeración econométrica continúa directamente en la sección 7.
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


// A.3. Definir las entradas, salidas y el log del Modelo 2

* Compartir la base analítica del archivo 01 sin sobrescribir sus resultados.
global OUTPUT_ROOT ///
    "$PROJECT_ROOT/outputs/econometrics/stata-peer-2/01_twfe_main"
global OUTPUT_SAMPLE "$OUTPUT_ROOT/01_sample"
global OUTPUT_M2 ///
    "$OUTPUT_ROOT/09_capabilities_stability"
global ADO_PROJECT "$OUTPUT_ROOT/ado"

* Crear una sola carpeta de M2 y conservar la biblioteca compartida.
capture mkdir "$PROJECT_ROOT/outputs"
capture mkdir "$PROJECT_ROOT/outputs/econometrics"
capture mkdir "$OUTPUT_ROOT"
capture mkdir "$OUTPUT_M2"
capture mkdir "$ADO_PROJECT"
capture mkdir "$ADO_PROJECT/plus"

* Abrir un registro exclusivo de M2 y reemplazar su ejecución anterior.
log using "$OUTPUT_M2/03_twfe_capabilities_stability.log", ///
    text replace name(m2_log)


// A.4. Verificar los paquetes de estimación y exportación

* Añadir la biblioteca local sin reemplazar otras rutas disponibles de Stata.
adopath ++ "$ADO_PROJECT/plus"
net set ado "$ADO_PROJECT/plus"

capture which ftools
if _rc {
    display as text "Instalando el paquete ftools desde SSC..."
    ssc install ftools
}

capture which reghdfe
if _rc {
    display as text "Instalando el paquete reghdfe desde SSC..."
    ssc install reghdfe
}

capture which esttab
if _rc {
    display as text "Instalando el paquete estout desde SSC..."
    ssc install estout
}

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

which ftools
which reghdfe
which esttab
which boottest
mata: mata mlib index


// A.5. Comprobar que el archivo 01 produjo la base analítica

local estimation_file ///
    "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta"

* Verificar la existencia de un archivo antes de intentar cargarlo.
capture confirm file "`estimation_file'"
if _rc {
    display as error "No se encontró la base preparada para las estimaciones."
    display as error "Ejecute primero 01_data_preparation_diagnostics.do."
    exit 601
}

display as result ///
    "Inicialización del archivo 03 completada; comienza la sección 7."


// *****************************************************************************
// 7. Diseño del Modelo 2: Capacidades y Estabilidad
// *****************************************************************************

// 7.1. Delimitar la pregunta y la función del modelo

* Registrar el diseño aprobado antes de consultar los resultados.
tempname design_post
tempfile design_register
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `design_post' ///
    str8 model str8 outcome str20 role str180 question ///
    str28 sample_rule str32 interpretation ///
    using "`design_register'", replace

* Escribir una fila de resultados dentro del archivo temporal.
post `design_post' ///
    ("M2") ("ECI") ("Principal") ///
    ("¿Qué condiciones institucionales, macroeconómicas, " + ///
        "productivas, fiscales y financieras acompañan " + ///
        "trayectorias más favorables?") ///
    ("Muestra común congelada") ("Asociación condicional")
* Escribir una fila de resultados dentro del archivo temporal.
post `design_post' ///
    ("M2") ("DIVX") ("Complementario") ///
    ("¿Qué condiciones institucionales, macroeconómicas, " + ///
        "productivas, fiscales y financieras acompañan " + ///
        "trayectorias más favorables?") ///
    ("Muestra común congelada") ("Asociación condicional")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `design_post'

preserve
    use "`design_register'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 2
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert model == "M2"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert sample_rule == "Muestra común congelada"
    export delimited using ///
        "$OUTPUT_M2/m2_design_register.csv", replace datafmt
restore

display as result "7.1. Diseño y función de M2 registrados sin errores."


// 7.2. Cargar y validar la muestra analítica común

* Abrir la copia derivada sin modificar el panel maestro ni otros modelos.
use "`estimation_file'", clear
* Comprobar que la combinación de identificadores de país y año sea única.
isid country_iso3_code year

* Verificar todos los campos requeridos por las dos ecuaciones de M2.
confirm variable ///
    country_iso3_code country country_id year ///
    eci divx sample_eci sample_divx ///
    rents inst rents_x_inst ///
    vol rer humcap innov net ///
    log_gdppc govcons fin

foreach variable in ///
    country_id year eci divx sample_eci sample_divx ///
    rents inst rents_x_inst ///
    vol rer humcap innov net ///
    log_gdppc govcons fin {
    confirm numeric variable `variable'
}

* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(rents_x_inst - rents * inst) < 1e-10 ///
    if !missing(rents_x_inst, rents, inst)
* Declarar la estructura de panel definiendo la variable país y año.
xtset country_id year

* Congelar la comparación con las banderas producidas por el modelo completo.
assert inlist(sample_eci, 0, 1)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert inlist(sample_divx, 0, 1)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_eci == sample_divx
generate byte sample_m2_common = sample_eci == 1 & sample_divx == 1
label variable sample_m2_common "Muestra común congelada de M1, M2 y M3"
* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_m2_common == sample_eci

* Confirmar completitud de todos los regresores de M2 en la muestra común.
egen int m2_missing_eci = rowmiss( ///
    eci rents inst rents_x_inst ///
    vol rer humcap innov net log_gdppc govcons fin)
egen int m2_missing_divx = rowmiss( ///
    divx rents inst rents_x_inst ///
    vol rer humcap innov net log_gdppc govcons fin)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert m2_missing_eci == 0 if sample_m2_common == 1
* Control de calidad automático que detiene el script si no se cumple la condición.
assert m2_missing_divx == 0 if sample_m2_common == 1

* Contar silenciosamente cuántas observaciones cumplen una condición determinada.
quietly count if sample_m2_common == 1
local m2_n = r(N)
quietly levelsof country_id if sample_m2_common == 1, ///
    local(m2_country_ids)
local m2_countries : word count `m2_country_ids'
quietly levelsof year if sample_m2_common == 1, local(m2_years)
local m2_year_count : word count `m2_years'
quietly summarize year if sample_m2_common == 1, meanonly
local m2_first_year = r(min)
local m2_last_year = r(max)

* Control de calidad automático que detiene el script si no se cumple la condición.
assert `m2_n' == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `m2_countries' == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `m2_year_count' == 23
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `m2_first_year' == 1996
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `m2_last_year' == 2021

foreach structural_wgi_gap in 1997 1999 2001 {
    * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
    quietly count if year == `structural_wgi_gap' & sample_m2_common == 1
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert r(N) == 0
}

* Exportar un resumen mínimo de la muestra común de las dos ecuaciones.
tempname sample_post
tempfile sample_validation
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `sample_post' ///
    str8 model str8 outcome long observations int countries ///
    int effective_years int first_year int last_year ///
    byte same_country_year_keys byte complete_m2_variables ///
    using "`sample_validation'", replace
* Escribir una fila de resultados dentro del archivo temporal.
post `sample_post' ///
    ("M2") ("ECI") (`m2_n') (`m2_countries') (`m2_year_count') ///
    (`m2_first_year') (`m2_last_year') (1) (1)
* Escribir una fila de resultados dentro del archivo temporal.
post `sample_post' ///
    ("M2") ("DIVX") (`m2_n') (`m2_countries') (`m2_year_count') ///
    (`m2_first_year') (`m2_last_year') (1) (1)
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `sample_post'

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
    assert same_country_year_keys == 1
    export delimited using ///
        "$OUTPUT_M2/m2_sample_validation.csv", replace datafmt
restore

drop m2_missing_eci m2_missing_divx
display as result ///
    "7.2. Muestra común validada: 1.044 observaciones y 49 países."


// 7.3. Definir el canal institucional compartido

* Mantener exactamente el mismo núcleo institucional utilizado por M1 y M3.
global M2_INSTITUTIONAL ///
    c.rents##c.inst

local m2_institutional_terms ///
    rents inst c.rents#c.inst
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(rents_x_inst - rents * inst) < 1e-10 ///
    if sample_m2_common == 1

display as result "7.3. Canal institucional definido sin errores."


// 7.4. Incorporar el canal macroeconómico

* Incorporar volatilidad y tipo de cambio real como un bloque conjunto.
global M2_MACROECONOMIC ///
    vol rer

* Ambos términos se evaluarán individual y conjuntamente dentro del país.
assert !missing(vol, rer) if sample_m2_common == 1

display as result "7.4. Canal macroeconómico definido sin errores."


// 7.5. Incorporar las capacidades productivas

* Incorporar capital humano, innovación y conectividad como un solo bloque.
global M2_CAPABILITIES ///
    humcap innov net

* Conservar el bloque aunque algún coeficiente aislado sea impreciso.
assert !missing(humcap, innov, net) if sample_m2_common == 1

display as result "7.5. Capacidades productivas definidas sin errores."


// 7.6. Incorporar los controles económicos, fiscales y financieros

* Incorporar desarrollo, consumo público y profundidad financiera.
global M2_CONTROLS ///
    log_gdppc govcons fin

* GOVCONS y FIN aproximarán condiciones fiscales y financieras complementarias.
assert !missing(log_gdppc, govcons, fin) if sample_m2_common == 1

display as result "7.6. Controles económicos y financieros definidos."


// 7.7. Fijar efectos, inferencia y salidas

* ECI y DIVX utilizan exactamente los mismos regresores dentro de M2.
global M2_REGRESSORS ///
    $M2_INSTITUTIONAL ///
    $M2_MACROECONOMIC ///
    $M2_CAPABILITIES ///
    $M2_CONTROLS

local m2_terms ///
    rents inst c.rents#c.inst ///
    vol rer humcap innov net ///
    log_gdppc govcons fin
global M2_INFERENCE "vce(cluster country_id)"

* Registrar la inclusión simétrica de los once términos en ambas ecuaciones.
tempname variable_post
tempfile variable_register
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `variable_post' ///
    int order str28 channel str24 variable ///
    str8 eci_included str8 divx_included ///
    using "`variable_register'", replace
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (1) ("Institucional") ("RENTS") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (2) ("Institucional") ("INST") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (3) ("Institucional") ("RENTS x INST") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (4) ("Macroeconomía") ("VOL") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (5) ("Macroeconomía") ("RER") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (6) ("Capacidades") ("HUMCAP") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (7) ("Capacidades") ("INNOV") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (8) ("Capacidades") ("NET") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (9) ("Desarrollo") ("log_GDPPC") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (10) ("Fiscal") ("GOVCONS") ("Sí") ("Sí")
* Escribir una fila de resultados dentro del archivo temporal.
post `variable_post' (11) ("Financiero") ("FIN") ("Sí") ("Sí")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `variable_post'

preserve
    use "`variable_register'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 11
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid order
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert eci_included == divx_included
    export delimited using ///
        "$OUTPUT_M2/m2_variable_register.csv", replace datafmt
restore

display as result "7.7. Especificaciones e inferencia de M2 fijadas."


// *****************************************************************************
// 8. Estimación del Modelo 2 con ECI y DIVX
// *****************************************************************************

// 8.1. Estimar la ecuación de capacidades con ECI

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
xtreg eci $M2_REGRESSORS i.year ///
    if sample_m2_common == 1, fe $M2_INFERENCE

capture estimates drop ECI_M2
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_M2
estimates save "$OUTPUT_M2/m2_eci.ster", replace

* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(sample) == sample_m2_common
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_clust) == 49

local eci_base_rents_b = _b[rents]
local eci_base_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local eci_base_interaction_b = _b[c.rents#c.inst]
local eci_base_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))

local eci_order = 0
local eci_critical_t = invttail(e(df_r), 0.025)
foreach term of local m2_terms {
    local ++eci_order
    local b = _b[`term']
    local se = _se[`term']
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local lower = `b' - `eci_critical_t' * `se'
    local upper = `b' + `eci_critical_t' * `se'
    scalar m2_eci_b_`eci_order' = `b'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `coefficient_post' ///
        ("M2") ("ECI") (`eci_order') ("`term'") ///
        (`b') (`se') (`t') (`p') (`lower') (`upper')
}

* Escribir una fila de resultados dentro del archivo temporal.
post `summary_post' ///
    ("M2") ("ECI") (e(N)) (e(N_g)) (e(N_clust)) ///
    (`m2_year_count') (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
    (e(F)) (e(p))

display as result "8.1. Modelo M2 para ECI estimado sin errores."


// 8.2. Estimar la ecuación de capacidades con DIVX

* Estimar DIVX con los mismos regresores y la misma muestra país-año.
xtreg divx $M2_REGRESSORS i.year ///
    if sample_m2_common == 1, fe $M2_INFERENCE

capture estimates drop DIVX_M2
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_M2
estimates save "$OUTPUT_M2/m2_divx.ster", replace

* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(sample) == sample_m2_common
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_clust) == 49

local divx_base_rents_b = _b[rents]
local divx_base_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local divx_base_interaction_b = _b[c.rents#c.inst]
local divx_base_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))

local divx_order = 0
local divx_critical_t = invttail(e(df_r), 0.025)
foreach term of local m2_terms {
    local ++divx_order
    local b = _b[`term']
    local se = _se[`term']
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local lower = `b' - `divx_critical_t' * `se'
    local upper = `b' + `divx_critical_t' * `se'
    scalar m2_divx_b_`divx_order' = `b'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `coefficient_post' ///
        ("M2") ("DIVX") (`divx_order') ("`term'") ///
        (`b') (`se') (`t') (`p') (`lower') (`upper')
}

* Escribir una fila de resultados dentro del archivo temporal.
post `summary_post' ///
    ("M2") ("DIVX") (e(N)) (e(N_g)) (e(N_clust)) ///
    (`m2_year_count') (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
    (e(F)) (e(p))

* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `coefficient_post'
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `summary_post'

preserve
    use "`coefficient_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 22
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid outcome order
    sort outcome order
    format coefficient standard_error t_statistic p_value ///
        ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_M2/m2_coefficients.csv", replace datafmt
restore

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
        "$OUTPUT_M2/m2_model_summary.csv", replace datafmt
restore

display as result "8.2. Modelo M2 para DIVX estimado sin errores."


// 8.3. Ejecutar pruebas conjuntas por canal

* Registrar seis pruebas sustantivas para cada resultado.
tempname joint_post
tempfile joint_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `joint_post' ///
    str8 model str8 outcome int order str32 channel ///
    str100 null_hypothesis double f_statistic df1 df2 p_value ///
    using "`joint_report'", replace

* Evaluar los bloques previstos en la ecuación ECI.
estimates restore ECI_M2
test rents inst c.rents#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2") ("ECI") (1) ("Institucional") ///
    ("RENTS, INST e interacción son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test vol rer
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2") ("ECI") (2) ("Macroeconomía") ///
    ("VOL y RER son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test humcap innov net
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2") ("ECI") (3) ("Capacidades productivas") ///
    ("HUMCAP, INNOV y NET son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test log_gdppc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2") ("ECI") (4) ("Nivel de desarrollo") ///
    ("log_GDPPC es igual a cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test govcons fin
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2") ("ECI") (5) ("Fiscal y financiero") ///
    ("GOVCONS y FIN son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2") ("ECI") (6) ("Efectos de año") ///
    ("Todos los indicadores de año son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Repetir exactamente las mismas pruebas en la ecuación DIVX.
estimates restore DIVX_M2
test rents inst c.rents#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2") ("DIVX") (1) ("Institucional") ///
    ("RENTS, INST e interacción son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test vol rer
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2") ("DIVX") (2) ("Macroeconomía") ///
    ("VOL y RER son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test humcap innov net
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2") ("DIVX") (3) ("Capacidades productivas") ///
    ("HUMCAP, INNOV y NET son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test log_gdppc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2") ("DIVX") (4) ("Nivel de desarrollo") ///
    ("log_GDPPC es igual a cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test govcons fin
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2") ("DIVX") (5) ("Fiscal y financiero") ///
    ("GOVCONS y FIN son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2") ("DIVX") (6) ("Efectos de año") ///
    ("Todos los indicadores de año son conjuntamente cero") ///
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
        "$OUTPUT_M2/m2_joint_tests.csv", replace datafmt
restore

display as result "8.3. Pruebas conjuntas de M2 completadas."


// 8.4. Interpretar la interacción RENTS por INST

* Definir percentiles institucionales observados en la muestra congelada.
quietly summarize inst if sample_m2_common == 1, detail
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
estimates restore ECI_M2
margins, dydx(rents) at(inst=(`inst_values'))
matrix eci_margins = r(table)
forvalues column = 1/5 {
    local inst_value : word `column' of `inst_values'
    local percentile : word `column' of `inst_labels'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `margins_post' ///
        ("M2") ("ECI") (`column') ("`percentile'") ///
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
    name(m2_eci_margins, replace)

* Calcular y graficar la asociación marginal de RENTS para DIVX.
estimates restore DIVX_M2
margins, dydx(rents) at(inst=(`inst_values'))
matrix divx_margins = r(table)
forvalues column = 1/5 {
    local inst_value : word `column' of `inst_values'
    local percentile : word `column' of `inst_labels'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `margins_post' ///
        ("M2") ("DIVX") (`column') ("`percentile'") ///
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
    name(m2_divx_margins, replace)

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
        "$OUTPUT_M2/m2_marginal_effects.csv", replace datafmt
restore

* Combinar ambos resultados sin imponer una escala vertical común.
graph combine m2_eci_margins m2_divx_margins, ///
    cols(2) graphregion(color(white)) ///
    title("Asociación marginal de RENTS según INST", size(medsmall)) ///
    note( ///
        "Modelo M2; asociaciones condicionales con IC del 95 %", ///
        size(vsmall)) ///
    name(m2_margins_combined, replace)
graph export "$OUTPUT_M2/m2_marginal_effects.pdf", replace
graph export "$OUTPUT_M2/m2_marginal_effects.png", ///
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

quietly xtreg eci $M2_REGRESSORS i.year ///
    if sample_m2_common == 1, fe $M2_INFERENCE
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(_b[rents] - `eci_base_rents_b') < 1e-10
boottest rents, cluster(country_id) reps(9999) ///
    seed(20260807) nograph
* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(r(p))
matrix eci_rents_ci = r(CI)
* Escribir una fila de resultados dentro del archivo temporal.
post `bootstrap_post' ///
    ("M2") ("ECI") ("RENTS") ///
    (_b[rents]) (`eci_base_rents_p') (r(p)) ///
    (el(eci_rents_ci, 1, 1)) (el(eci_rents_ci, 1, 2)) ///
    (r(reps)) ("`r(weighttype)'")

boottest c.rents#c.inst, cluster(country_id) reps(9999) ///
    seed(20260808) nograph
* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(r(p))
matrix eci_interaction_ci = r(CI)
* Escribir una fila de resultados dentro del archivo temporal.
post `bootstrap_post' ///
    ("M2") ("ECI") ("RENTS x INST") ///
    (_b[c.rents#c.inst]) (`eci_base_interaction_p') (r(p)) ///
    (el(eci_interaction_ci, 1, 1)) ///
    (el(eci_interaction_ci, 1, 2)) ///
    (r(reps)) ("`r(weighttype)'")

quietly xtreg divx $M2_REGRESSORS i.year ///
    if sample_m2_common == 1, fe $M2_INFERENCE
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(_b[rents] - `divx_base_rents_b') < 1e-10
boottest rents, cluster(country_id) reps(9999) ///
    seed(20260809) nograph
* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(r(p))
matrix divx_rents_ci = r(CI)
* Escribir una fila de resultados dentro del archivo temporal.
post `bootstrap_post' ///
    ("M2") ("DIVX") ("RENTS") ///
    (_b[rents]) (`divx_base_rents_p') (r(p)) ///
    (el(divx_rents_ci, 1, 1)) (el(divx_rents_ci, 1, 2)) ///
    (r(reps)) ("`r(weighttype)'")

boottest c.rents#c.inst, cluster(country_id) reps(9999) ///
    seed(20260810) nograph
* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(r(p))
matrix divx_interaction_ci = r(CI)
* Escribir una fila de resultados dentro del archivo temporal.
post `bootstrap_post' ///
    ("M2") ("DIVX") ("RENTS x INST") ///
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
        "$OUTPUT_M2/m2_wild_cluster_bootstrap.csv", ///
        replace datafmt
restore

display as result "8.4. Efectos marginales y bootstrap completados."


// 8.5. Verificar y exportar el Modelo 2

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
reghdfe eci $M2_REGRESSORS ///
    if sample_m2_common == 1, ///
    absorb(country_id year) $M2_INFERENCE
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
local eci_order = 0
foreach term of local m2_terms {
    local ++eci_order
    local xtreg_b = scalar(m2_eci_b_`eci_order')
    local hdfe_b = _b[`term']
    local difference = abs(`xtreg_b' - `hdfe_b')
    local match = `difference' < `coefficient_tolerance'
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert `match' == 1
    * Escribir una fila de resultados dentro del archivo temporal.
    post `verification_post' ///
        ("M2") ("ECI") (`eci_order') ("`term'") ///
        (`xtreg_b') (`hdfe_b') (`difference') (`match')
}

* Estimar el modelo de regresión con efectos fijos de país y año y errores agrupados.
reghdfe divx $M2_REGRESSORS ///
    if sample_m2_common == 1, ///
    absorb(country_id year) $M2_INFERENCE
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
local divx_order = 0
foreach term of local m2_terms {
    local ++divx_order
    local xtreg_b = scalar(m2_divx_b_`divx_order')
    local hdfe_b = _b[`term']
    local difference = abs(`xtreg_b' - `hdfe_b')
    local match = `difference' < `coefficient_tolerance'
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert `match' == 1
    * Escribir una fila de resultados dentro del archivo temporal.
    post `verification_post' ///
        ("M2") ("DIVX") (`divx_order') ("`term'") ///
        (`xtreg_b') (`hdfe_b') (`difference') (`match')
}

* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `verification_post'

preserve
    use "`verification_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 22
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert coefficient_match == 1
    sort outcome order
    format xtreg_coefficient reghdfe_coefficient ///
        absolute_difference %16.10f
    export delimited using ///
        "$OUTPUT_M2/m2_xtreg_reghdfe_verification.csv", ///
        replace datafmt
restore

* Crear una tabla compacta de las dos ecuaciones del Modelo 2.
esttab ECI_M2 DIVX_M2 using "$OUTPUT_M2/m2_results_table.tex", ///
    replace booktabs label se nonotes ///
    b(4) se(4) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents inst c.rents#c.inst ///
        vol rer humcap innov net ///
        log_gdppc govcons fin) ///
    order( ///
        rents inst c.rents#c.inst ///
        vol rer humcap innov net ///
        log_gdppc govcons fin) ///
    coeflabels( ///
        rents "RENTS" ///
        inst "INST" ///
        c.rents#c.inst "RENTS x INST" ///
        vol "VOL" rer "RER" ///
        humcap "HUMCAP" innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" ///
        govcons "GOVCONS" fin "FIN") ///
    mtitles("ECI" "DIVX") ///
    stats(N N_g r2_w, ///
        fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within")) ///
    addnotes( ///
        "Errores estándar agrupados por país entre paréntesis." ///
        "Efectos fijos por país y año en ambas ecuaciones." ///
        "Resultados asociativos; no constituyen efectos causales." ///
        "* p<0.10, ** p<0.05, *** p<0.01")

* Crear además una versión legible sin requerir un compilador LaTeX.
esttab ECI_M2 DIVX_M2 using "$OUTPUT_M2/m2_results_table.txt", ///
    replace label se nonotes ///
    b(4) se(4) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents inst c.rents#c.inst ///
        vol rer humcap innov net ///
        log_gdppc govcons fin) ///
    order( ///
        rents inst c.rents#c.inst ///
        vol rer humcap innov net ///
        log_gdppc govcons fin) ///
    coeflabels( ///
        rents "RENTS" ///
        inst "INST" ///
        c.rents#c.inst "RENTS x INST" ///
        vol "VOL" rer "RER" ///
        humcap "HUMCAP" innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" ///
        govcons "GOVCONS" fin "FIN") ///
    mtitles("ECI" "DIVX") ///
    stats(N N_g r2_w, ///
        fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within")) ///
    addnotes( ///
        "Errores estándar agrupados por país entre paréntesis." ///
        "Efectos fijos por país y año en ambas ecuaciones." ///
        "Resultados asociativos; no constituyen efectos causales." ///
        "* p<0.10, ** p<0.05, *** p<0.01")

* Registrar los productos finales sin crear subcarpetas innecesarias.
tempname manifest_post
tempfile manifest_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `manifest_post' ///
    int order str32 family str80 file str140 purpose ///
    using "`manifest_report'", replace
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (1) ("Diseño") ("m2_design_register.csv") ///
    ("Pregunta, resultados y regla común de estimación.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (2) ("Diseño") ("m2_variable_register.csv") ///
    ("Variables y canales incluidos en ECI y DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (3) ("Muestra") ("m2_sample_validation.csv") ///
    ("Validación de 1.044 observaciones y 49 países.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (4) ("Estimación") ("m2_eci.ster") ///
    ("Estimación principal M2 para ECI.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (5) ("Estimación") ("m2_divx.ster") ///
    ("Estimación complementaria M2 para DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (6) ("Resultados") ("m2_coefficients.csv") ///
    ("Coeficientes, errores e intervalos de las dos ecuaciones.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (7) ("Resultados") ("m2_model_summary.csv") ///
    ("Cobertura y ajuste within de ECI y DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (8) ("Inferencia") ("m2_joint_tests.csv") ///
    ("Pruebas conjuntas por canal sustantivo.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (9) ("Inferencia") ("m2_wild_cluster_bootstrap.csv") ///
    ("Bootstrap para RENTS y RENTS x INST.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (10) ("Interpretación") ("m2_marginal_effects.csv") ///
    ("Asociación marginal de RENTS según percentiles de INST.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (11) ("Verificación") ("m2_xtreg_reghdfe_verification.csv") ///
    ("Equivalencia numérica entre xtreg y reghdfe.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (12) ("Tabla") ("m2_results_table.tex") ///
    ("Tabla LaTeX compacta del Modelo 2.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (13) ("Tabla") ("m2_results_table.txt") ///
    ("Tabla de texto compacta del Modelo 2.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (14) ("Figura") ("m2_marginal_effects.pdf") ///
    ("Figura comparada apta para LaTeX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (15) ("Figura") ("m2_marginal_effects.png") ///
    ("Figura comparada para inspección visual.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (16) ("Documentación") ("m2_results_manifest.csv") ///
    ("Inventario reproducible de productos de M2.")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `manifest_post'

preserve
    use "`manifest_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 16
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid order
    export delimited using ///
        "$OUTPUT_M2/m2_results_manifest.csv", replace datafmt
restore

* Comprobar que todos los archivos declarados fueron creados.
local required_files ///
    m2_design_register.csv ///
    m2_variable_register.csv ///
    m2_sample_validation.csv ///
    m2_eci.ster ///
    m2_divx.ster ///
    m2_coefficients.csv ///
    m2_model_summary.csv ///
    m2_joint_tests.csv ///
    m2_wild_cluster_bootstrap.csv ///
    m2_marginal_effects.csv ///
    m2_xtreg_reghdfe_verification.csv ///
    m2_results_table.tex ///
    m2_results_table.txt ///
    m2_marginal_effects.pdf ///
    m2_marginal_effects.png ///
    m2_results_manifest.csv

foreach required_file of local required_files {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "$OUTPUT_M2/`required_file'"
    if _rc {
        display as error "Falta el producto de M2: `required_file'"
        exit 603
    }
}

* Cerrar el archivo con el resultado complementario nuevamente activo.
estimates restore DIVX_M2
display as result ///
    "Archivo 03 finalizado: secciones 7 y 8 completadas sin errores."
display as text ///
    "Los resultados describen asociaciones condicionales, no causales."
log close m2_log
