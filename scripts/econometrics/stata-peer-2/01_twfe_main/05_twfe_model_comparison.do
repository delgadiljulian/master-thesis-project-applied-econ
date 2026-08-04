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
// Archivo: 05_twfe_model_comparison.do (Versión Codex)
// Contenido: Secciones 13 y 14 del análisis econométrico
// Requisito operativo: ejecutar previamente los archivos 01 a 04
// Estado: implementación completa de las secciones 13 y 14
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************


// *****************************************************************************
// INICIALIZACIÓN DEL ARCHIVO 05
// *****************************************************************************

// C.1. Limpiar la sesión y fijar el entorno reproducible

* Fijar la versión 17 de Stata para garantizar la compatibilidad del script.
version 17.0
* Limpiar la memoria de Stata borrando todas las variables cargadas.
clear all
* Limpiar la consola de comandos de Stata.
cls
* Eliminar todas las variables temporales y globales de la memoria.
macro drop _all
* Cerrar cualquier registro de texto (log) abierto previamente.
capture log close _all

* Desactivar las pausas de pantalla para una ejecución continua.
set more off
* Evitar que Stata abrevie nombres de variables automáticamente.
set varabbrev off
* Usar precisión doble para evitar errores de redondeo numérico.
set type double
* Ajustar el ancho de consola a 255 caracteres para ver tablas completas.
set linesize 255
* Definir la semilla pseudoaleatoria para hacer 100% reproducibles las simulaciones.
set seed 20260805
* Definir la semilla de ordenamiento para garantizar la reproducibilidad de datos.
set sortseed 20260805


// C.2. Localizar la raíz del proyecto

local project_marker ///
    "data/processed/00_master_panel/master_panel_country_year.dta"
local project_current "`c(pwd)'"
local project_windows ///
    "C:/Users/`c(username)'/GitHub/master-thesis-project-applied-econ"
local project_manual ""
global PROJECT_ROOT ""

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

if "$PROJECT_ROOT" == "" {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "`project_windows'/`project_marker'"
    if !_rc {
        global PROJECT_ROOT "`project_windows'"
    }
}

if "$PROJECT_ROOT" == "" & "`project_manual'" != "" {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "`project_manual'/`project_marker'"
    if !_rc {
        global PROJECT_ROOT "`project_manual'"
    }
}

if "$PROJECT_ROOT" == "" {
    display as error "No se pudo localizar la raíz del repositorio."
    display as error "Edite local project_manual en la inicialización."
    exit 601
}

quietly cd "$PROJECT_ROOT"
display as result "Raíz del proyecto localizada correctamente:"
pwd


// C.3. Definir entradas, salida única y log

global OUTPUT_ROOT ///
    "$PROJECT_ROOT/outputs/econometrics/stata-peer-2/01_twfe_main"
global OUTPUT_SAMPLE "$OUTPUT_ROOT/01_sample"
global OUTPUT_M1 "$OUTPUT_ROOT/08_extractive_export_structure"
global OUTPUT_M2 "$OUTPUT_ROOT/09_capabilities_stability"
global OUTPUT_ECI "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX "$OUTPUT_ROOT/04_divx"
global OUTPUT_STABILITY "$OUTPUT_ROOT/05_stability"
global OUTPUT_FINAL "$OUTPUT_ROOT/06_final"
global OUTPUT_COMPARE "$OUTPUT_ROOT/12_model_comparison"
global ADO_PROJECT "$OUTPUT_ROOT/ado"

capture mkdir "$PROJECT_ROOT/outputs"
capture mkdir "$PROJECT_ROOT/outputs/econometrics"
capture mkdir "$OUTPUT_ROOT"
capture mkdir "$OUTPUT_COMPARE"
capture mkdir "$ADO_PROJECT"
capture mkdir "$ADO_PROJECT/plus"

log using "$OUTPUT_COMPARE/05_twfe_model_comparison.log", ///
    text replace name(comparison_log)


// C.4. Verificar dependencias y productos requeridos

adopath ++ "$ADO_PROJECT/plus"
net set ado "$ADO_PROJECT/plus"

capture which esttab
if _rc {
    ssc install estout
}
capture which esttab
if _rc {
    display as error "Stata no encuentra el comando esttab."
    exit 199
}

local estimation_file ///
    "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta"
* Verificar la existencia de un archivo antes de intentar cargarlo.
capture confirm file "`estimation_file'"
if _rc {
    display as error ///
        "No se encontró la base de estimación del archivo 01."
    exit 601
}

display as result ///
    "Inicialización completa; comienza la comparación M1-M2-M3."


// *****************************************************************************
// 13. Comparación de los Tres Modelos TWFE con RENTS Totales
// *****************************************************************************

// 13.1. Verificar las estimaciones almacenadas

* Cargar una estimación guardada previamente en disco.
estimates use "$OUTPUT_M1/m1_eci.ster"
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_M1
* Cargar una estimación guardada previamente en disco.
estimates use "$OUTPUT_M1/m1_divx.ster"
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_M1

* Cargar una estimación guardada previamente en disco.
estimates use "$OUTPUT_M2/m2_eci.ster"
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_M2
* Cargar una estimación guardada previamente en disco.
estimates use "$OUTPUT_M2/m2_divx.ster"
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_M2

* Cargar una estimación guardada previamente en disco.
estimates use "$OUTPUT_ECI/eci_twfe_main.ster"
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_M3
* Cargar una estimación guardada previamente en disco.
estimates use "$OUTPUT_DIVX/divx_twfe_main.ster"
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_M3

local comparison_estimates ///
    ECI_M1 DIVX_M1 ECI_M2 DIVX_M2 ECI_M3 DIVX_M3
local comparison_models M1 M1 M2 M2 M3 M3
local comparison_outcomes ECI DIVX ECI DIVX ECI DIVX
local comparison_model_orders 1 1 2 2 3 3

foreach estimate_name of local comparison_estimates {
    * Restaurar una estimación previa desde la memoria de Stata.
    estimates restore `estimate_name'
    * Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
    assert e(N) == 1044
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert e(N_g) == 49
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert e(N_clust) == 49
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert e(df_r) == 48
}

display as result ///
    "13.1. Las seis estimaciones fueron recuperadas sin reestimar."


// 13.2. Confirmar la igualdad de las muestras principales

use "`estimation_file'", clear
* Comprobar que la combinación de identificadores de país y año sea única.
isid country_iso3_code year

confirm variable ///
    country_iso3_code country_id year sample_eci sample_divx ///
    eci divx hhi rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin

* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_eci == sample_divx
* Control de calidad automático que detiene el script si no se cumple la condición.
assert inlist(sample_eci, 0, 1)

egen int comparison_missing_union = rowmiss( ///
    eci divx hhi rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert comparison_missing_union == 0 if sample_eci == 1

* Contar silenciosamente cuántas observaciones cumplen una condición determinada.
quietly count if sample_eci == 1
local comparison_n = r(N)
quietly levelsof country_id if sample_eci == 1, ///
    local(comparison_country_ids)
local comparison_countries : word count `comparison_country_ids'
quietly levelsof year if sample_eci == 1, ///
    local(comparison_years)
local comparison_year_count : word count `comparison_years'
quietly summarize year if sample_eci == 1, meanonly
local comparison_first_year = r(min)
local comparison_last_year = r(max)

* Control de calidad automático que detiene el script si no se cumple la condición.
assert `comparison_n' == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `comparison_countries' == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `comparison_year_count' == 23
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `comparison_first_year' == 1996
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `comparison_last_year' == 2021

drop comparison_missing_union

tempname sample_post fit_post
tempfile sample_report fit_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `sample_post' ///
    str2 model str8 outcome int model_order ///
    long observations int countries clusters effective_years ///
    first_year last_year byte same_country_year_keys ///
    using "`sample_report'", replace
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `fit_post' ///
    str2 model str8 outcome int model_order ///
    long observations int countries clusters ///
    double r2_within r2_between r2_overall ///
    f_statistic model_p_value df_error ///
    using "`fit_report'", replace

forvalues index = 1/6 {
    local estimate_name : word `index' of `comparison_estimates'
    local model : word `index' of `comparison_models'
    local outcome : word `index' of `comparison_outcomes'
    local model_order : word `index' of `comparison_model_orders'

    * Restaurar una estimación previa desde la memoria de Stata.
    estimates restore `estimate_name'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `sample_post' ///
        ("`model'") ("`outcome'") (`model_order') ///
        (e(N)) (e(N_g)) (e(N_clust)) ///
        (`comparison_year_count') ///
        (`comparison_first_year') (`comparison_last_year') (1)
    * Escribir una fila de resultados dentro del archivo temporal.
    post `fit_post' ///
        ("`model'") ("`outcome'") (`model_order') ///
        (e(N)) (e(N_g)) (e(N_clust)) ///
        (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
        (e(F)) (e(p)) (e(df_r))
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `sample_post'
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `fit_post'

preserve
    use "`sample_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 6
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert observations == 1044
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert countries == 49
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert clusters == 49
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert effective_years == 23
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert same_country_year_keys == 1
    sort outcome model_order
    export delimited using ///
        "$OUTPUT_COMPARE/twfe_comparison_sample_validation.csv", ///
        replace datafmt
restore

preserve
    use "`fit_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 6
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert observations == 1044
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert countries == 49
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert clusters == 49
    sort outcome model_order
    export delimited using ///
        "$OUTPUT_COMPARE/twfe_model_fit_comparison.csv", ///
        replace datafmt
restore

display as result ///
    "13.2. La muestra común fue validada para las seis ecuaciones."


// 13.3. Comparar los coeficientes focales

tempname focal_post
tempfile focal_report focal_base focal_final
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `focal_post' ///
    str2 model str8 outcome int model_order term_order ///
    str20 concept str32 term ///
    double coefficient standard_error t_statistic conventional_p ///
    ci_lower ci_upper using "`focal_report'", replace

local focal_terms rents inst c.rents#c.inst
local focal_concepts RENTS INST RENTS_x_INST

forvalues index = 1/6 {
    local estimate_name : word `index' of `comparison_estimates'
    local model : word `index' of `comparison_models'
    local outcome : word `index' of `comparison_outcomes'
    local model_order : word `index' of `comparison_model_orders'

    * Restaurar una estimación previa desde la memoria de Stata.
    estimates restore `estimate_name'
    local critical_t = invttail(e(df_r), 0.025)
    local term_order = 0
    foreach term of local focal_terms {
        local ++term_order
        local concept : word `term_order' of `focal_concepts'
        local b = _b[`term']
        local se = _se[`term']
        local t = `b' / `se'
        local p = 2 * ttail(e(df_r), abs(`t'))
        local lower = `b' - `critical_t' * `se'
        local upper = `b' + `critical_t' * `se'
        * Escribir una fila de resultados dentro del archivo temporal.
        post `focal_post' ///
            ("`model'") ("`outcome'") ///
            (`model_order') (`term_order') ///
            ("`concept'") ("`term'") ///
            (`b') (`se') (`t') (`p') (`lower') (`upper')
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `focal_post'

preserve
    use "`focal_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 18
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome term_order
    sort outcome term_order model_order
    save "`focal_base'", replace
restore

tempfile bootstrap_m1 bootstrap_m12 bootstrap_full bootstrap_merge
preserve
    import delimited using ///
        "$OUTPUT_M1/m1_wild_cluster_bootstrap.csv", ///
        clear varnames(1) encoding(utf8)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 4
    save "`bootstrap_m1'", replace
restore

preserve
    import delimited using ///
        "$OUTPUT_M2/m2_wild_cluster_bootstrap.csv", ///
        clear varnames(1) encoding(utf8)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 4
    append using "`bootstrap_m1'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 8
    save "`bootstrap_m12'", replace
restore

preserve
    import delimited using ///
        "$OUTPUT_STABILITY/wild_cluster_bootstrap.csv", ///
        clear varnames(1) encoding(utf8)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 4
    rename model outcome
    generate str2 model = "M3"
    append using "`bootstrap_m12'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 12
    generate int term_order = .
    replace term_order = 1 if term == "RENTS"
    replace term_order = 3 if term == "RENTS x INST"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert inlist(term_order, 1, 3)
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome term_order
    sort outcome term_order model
    save "`bootstrap_full'", replace
    export delimited using ///
        "$OUTPUT_COMPARE/twfe_wild_cluster_bootstrap.csv", ///
        replace datafmt

    keep model outcome term_order bootstrap_p ///
        ci_lower ci_upper repetitions weight_type
    rename ci_lower bootstrap_ci_lower
    rename ci_upper bootstrap_ci_upper
    save "`bootstrap_merge'", replace
restore

preserve
    use "`focal_base'", clear
    merge 1:1 model outcome term_order using "`bootstrap_merge'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _merge == 1 if term_order == 2
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _merge == 3 if inlist(term_order, 1, 3)
    drop _merge
    sort outcome term_order model_order
    format coefficient standard_error t_statistic ///
        conventional_p ci_lower ci_upper bootstrap_p ///
        bootstrap_ci_lower bootstrap_ci_upper %12.6f
    save "`focal_final'", replace
    export delimited using ///
        "$OUTPUT_COMPARE/twfe_focal_coefficients.csv", ///
        replace datafmt
restore

display as text ///
    "Los coeficientes se comparan sin votar resultados por significancia."


// 13.4. Comparar el aporte conjunto de los canales

tempfile joint_m1 joint_m12
preserve
    import delimited using "$OUTPUT_M1/m1_joint_tests.csv", ///
        clear varnames(1) encoding(utf8)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 12
    save "`joint_m1'", replace
restore

preserve
    import delimited using "$OUTPUT_M2/m2_joint_tests.csv", ///
        clear varnames(1) encoding(utf8)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 12
    append using "`joint_m1'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 24
    save "`joint_m12'", replace
restore

preserve
    import delimited using "$OUTPUT_FINAL/final_joint_tests.csv", ///
        clear varnames(1) encoding(utf8)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 16
    rename model outcome
    generate str2 model = "M3"
    rename test channel
    append using "`joint_m12'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 40
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort outcome model order
    format f_statistic p_value %12.6f
    export delimited using ///
        "$OUTPUT_COMPARE/twfe_joint_tests_comparison.csv", ///
        replace datafmt
restore

tempname channel_post
tempfile channel_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `channel_post' ///
    str2 model int model_order str32 channel byte included ///
    str100 interpretation using "`channel_report'", replace

* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M1") (1) ("Institucional") (1) ("Núcleo compartido")
* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M1") (1) ("Abundancia") (1) ("Canal temático")
* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M1") (1) ("Estructura exportadora") (1) ("Canal temático")
* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M1") (1) ("Macroeconomía") (0) ("Fuera de M1")
* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M1") (1) ("Capacidades productivas") (0) ("Fuera de M1")
* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M1") (1) ("Nivel de desarrollo") (1) ("Control compartido")
* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M1") (1) ("Fiscal y financiero") (0) ("Fuera de M1")

* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M2") (2) ("Institucional") (1) ("Núcleo compartido")
* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M2") (2) ("Abundancia") (0) ("Fuera de M2")
* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M2") (2) ("Estructura exportadora") (0) ("Fuera de M2")
* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M2") (2) ("Macroeconomía") (1) ("Canal temático")
* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M2") (2) ("Capacidades productivas") (1) ("Canal temático")
* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M2") (2) ("Nivel de desarrollo") (1) ("Control compartido")
* Escribir una fila de resultados dentro del archivo temporal.
post `channel_post' ///
    ("M2") (2) ("Fiscal y financiero") (1) ("Canal temático")

foreach channel in ///
    "Institucional" ///
    "Abundancia" ///
    "Estructura exportadora" ///
    "Macroeconomía" ///
    "Capacidades productivas" ///
    "Nivel de desarrollo" ///
    "Fiscal y financiero" {
    * Escribir una fila de resultados dentro del archivo temporal.
    post `channel_post' ///
        ("M3") (3) ("`channel'") (1) ("TWFE completo")
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `channel_post'

preserve
    use "`channel_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 21
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model channel
    sort model_order channel
    export delimited using ///
        "$OUTPUT_COMPARE/twfe_channel_inclusion.csv", replace datafmt
restore


// 13.5. Distinguir modelos temáticos y modelo completo

tempname design_post
tempfile design_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `design_post' ///
    str2 model int model_order str8 outcome str32 model_name ///
    str20 role str180 question str80 hhi_rule ///
    using "`design_report'", replace

foreach outcome in ECI DIVX {
    local hhi_m1 "Incluir HHI"
    local hhi_m2 "No aplica"
    local hhi_m3 "Incluir HHI"
    if "`outcome'" == "DIVX" {
        local hhi_m1 "Excluir HHI: DIVX=1-HHI"
        local hhi_m3 "Excluir HHI: DIVX=1-HHI"
    }
    * Escribir una fila de resultados dentro del archivo temporal.
    post `design_post' ///
        ("M1") (1) ("`outcome'") ///
        ("Estructura extractiva") ("Temático") ///
        ("Distinguir rentas, abundancia y estructura exportadora") ///
        ("`hhi_m1'")
    * Escribir una fila de resultados dentro del archivo temporal.
    post `design_post' ///
        ("M2") (2) ("`outcome'") ///
        ("Capacidades y estabilidad") ("Temático") ///
        ("Evaluar estabilidad, capacidades y condiciones fiscales") ///
        ("`hhi_m2'")
    * Escribir una fila de resultados dentro del archivo temporal.
    post `design_post' ///
        ("M3") (3) ("`outcome'") ///
        ("TWFE completo") ("Contraste") ///
        ("Reunir simultáneamente todos los canales de M1 y M2") ///
        ("`hhi_m3'")
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `design_post'

preserve
    use "`design_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 6
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    sort outcome model_order
    export delimited using ///
        "$OUTPUT_COMPARE/twfe_model_design_register.csv", ///
        replace datafmt
restore

display as result ///
    "Sección 13 completa: M1 y M2 son paralelos; M3 es contraste."


// *****************************************************************************
// 14. Exportación de la Comparación TWFE
// *****************************************************************************

// 14.1. Crear la tabla M1 a M3 para ECI

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab ECI_M1 ECI_M2 ECI_M3 ///
    using "$OUTPUT_COMPARE/table_twfe_models_eci.tex", ///
    replace booktabs label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp vol rer humcap innov net ///
        log_gdppc govcons fin) ///
    order( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp vol rer humcap innov net ///
        log_gdppc govcons fin) ///
    coeflabels( ///
        rents "RENTS" inst "INST" ///
        c.rents#c.inst "RENTS x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        hhi "HHI" pexp "PEXP" fexp "FEXP" ///
        vol "VOL" rer "RER" humcap "HUMCAP" ///
        innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" ///
        govcons "GOVCONS" fin "FIN") ///
    mtitles("M1 Estructura" "M2 Capacidades" "M3 Completo") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within")) ///
    addnotes( ///
        "Efectos fijos por país y año." ///
        "Errores estándar agrupados por país entre paréntesis." ///
        "Resultados asociativos; no constituyen efectos causales.")

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab ECI_M1 ECI_M2 ECI_M3 ///
    using "$OUTPUT_COMPARE/table_twfe_models_eci.txt", ///
    replace label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp vol rer humcap innov net ///
        log_gdppc govcons fin) ///
    order( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp vol rer humcap innov net ///
        log_gdppc govcons fin) ///
    coeflabels( ///
        rents "RENTS" inst "INST" ///
        c.rents#c.inst "RENTS x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        hhi "HHI" pexp "PEXP" fexp "FEXP" ///
        vol "VOL" rer "RER" humcap "HUMCAP" ///
        innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" ///
        govcons "GOVCONS" fin "FIN") ///
    mtitles("M1 Estructura" "M2 Capacidades" "M3 Completo") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))


// 14.2. Crear la tabla M1 a M3 para DIVX

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab DIVX_M1 DIVX_M2 DIVX_M3 ///
    using "$OUTPUT_COMPARE/table_twfe_models_divx.tex", ///
    replace booktabs label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        pexp fexp vol rer humcap innov net ///
        log_gdppc govcons fin) ///
    order( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        pexp fexp vol rer humcap innov net ///
        log_gdppc govcons fin) ///
    coeflabels( ///
        rents "RENTS" inst "INST" ///
        c.rents#c.inst "RENTS x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        pexp "PEXP" fexp "FEXP" ///
        vol "VOL" rer "RER" humcap "HUMCAP" ///
        innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" ///
        govcons "GOVCONS" fin "FIN") ///
    mtitles("M1 Estructura" "M2 Capacidades" "M3 Completo") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within")) ///
    addnotes( ///
        "HHI excluido porque DIVX = 1 - HHI." ///
        "Efectos fijos por país y año." ///
        "Errores estándar agrupados por país entre paréntesis." ///
        "Resultados asociativos; no constituyen efectos causales.")

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab DIVX_M1 DIVX_M2 DIVX_M3 ///
    using "$OUTPUT_COMPARE/table_twfe_models_divx.txt", ///
    replace label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        pexp fexp vol rer humcap innov net ///
        log_gdppc govcons fin) ///
    order( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        pexp fexp vol rer humcap innov net ///
        log_gdppc govcons fin) ///
    coeflabels( ///
        rents "RENTS" inst "INST" ///
        c.rents#c.inst "RENTS x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        pexp "PEXP" fexp "FEXP" ///
        vol "VOL" rer "RER" humcap "HUMCAP" ///
        innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" ///
        govcons "GOVCONS" fin "FIN") ///
    mtitles("M1 Estructura" "M2 Capacidades" "M3 Completo") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))


// 14.3. Documentar estabilidad y diferencias entre modelos

preserve
    use "`focal_final'", clear
    keep outcome term_order concept term model ///
        coefficient standard_error conventional_p bootstrap_p
    rename coefficient b
    rename standard_error se
    rename conventional_p p
    rename bootstrap_p boot_p
    reshape wide b se p boot_p, ///
        i(outcome term_order concept term) j(model) string
    generate byte sign_consistent = ///
        sign(bM1) == sign(bM2) & sign(bM2) == sign(bM3)
    egen double coefficient_min = rowmin(bM1 bM2 bM3)
    egen double coefficient_max = rowmax(bM1 bM2 bM3)
    generate double coefficient_range = ///
        coefficient_max - coefficient_min
    order outcome term_order concept term sign_consistent ///
        bM1 bM2 bM3 seM1 seM2 seM3 pM1 pM2 pM3 ///
        boot_pM1 boot_pM2 boot_pM3 coefficient_range
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 6
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid outcome term_order
    sort outcome term_order
    format b* se* p* boot_p* coefficient_* %12.6f
    export delimited using ///
        "$OUTPUT_COMPARE/twfe_focal_stability.csv", ///
        replace datafmt
restore

tempfile margins_m1 margins_m12
preserve
    import delimited using "$OUTPUT_M1/m1_marginal_effects.csv", ///
        clear varnames(1) encoding(utf8)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 10
    save "`margins_m1'", replace
restore

preserve
    import delimited using "$OUTPUT_M2/m2_marginal_effects.csv", ///
        clear varnames(1) encoding(utf8)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 10
    append using "`margins_m1'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 20
    save "`margins_m12'", replace
restore

preserve
    import delimited using ///
        "$OUTPUT_FINAL/final_rents_marginal_effects_by_inst.csv", ///
        clear varnames(1) encoding(utf8)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 10
    rename model outcome
    rename institutional_percentile percentile
    generate str2 model = "M3"
    generate int order = .
    replace order = 1 if percentile == "P10"
    replace order = 2 if percentile == "P25"
    replace order = 3 if percentile == "P50"
    replace order = 4 if percentile == "P75"
    replace order = 5 if percentile == "P90"
    keep model outcome order percentile inst_value ///
        marginal_effect standard_error p_value ci_lower ci_upper
    append using "`margins_m12'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 30
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    bysort outcome percentile: egen double inst_min = min(inst_value)
    bysort outcome percentile: egen double inst_max = max(inst_value)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert abs(inst_max - inst_min) < 1e-6
    drop inst_min inst_max
    sort outcome order model
    format inst_value marginal_effect standard_error ///
        p_value ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_COMPARE/twfe_marginal_effects_comparison.csv", ///
        replace datafmt
restore

preserve
    use "`focal_final'", clear
    keep if inlist(term_order, 1, 3)
    label define comparison_model_axis ///
        1 "M1" 2 "M2" 3 "M3"
    label values model_order comparison_model_axis
    replace concept = "RENTS x INST" if term_order == 3
    twoway ///
        (rcap ci_lower ci_upper model_order, lcolor(navy)) ///
        (scatter coefficient model_order, ///
            mcolor(navy) msymbol(circle)), ///
        yline(0, lpattern(dash) lcolor(gs8)) ///
        xlabel(1 "M1" 2 "M2" 3 "M3", labsize(small)) ///
        ylabel(, format(%7.3f) angle(horizontal) labsize(vsmall)) ///
        xtitle("Modelo TWFE", size(small)) ///
        ytitle("Coeficiente e IC del 95 %", size(small)) ///
        legend(off) ///
        graphregion(color(white)) ///
        by(outcome concept, cols(2) yrescale legend(off) ///
            title("Estabilidad de los coeficientes focales", ///
                size(medsmall)) ///
            note( ///
                "Misma muestra; IC convencionales agrupados por país", ///
                size(vsmall)))
    graph export ///
        "$OUTPUT_COMPARE/twfe_focal_coefficients.png", ///
        width(3000) replace
restore

display as result ///
    "14.3. Estabilidad, bootstrap y efectos marginales consolidados."


// 14.4. Validar el paquete comparativo final

tempname manifest_post
tempfile manifest_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `manifest_post' ///
    int order str28 family str80 file str140 purpose ///
    using "`manifest_report'", replace
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (1) ("Diseño") ("twfe_model_design_register.csv") ///
    ("Función comparativa de M1, M2 y M3.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (2) ("Muestra") ("twfe_comparison_sample_validation.csv") ///
    ("Igualdad de muestra en las seis ecuaciones.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (3) ("Ajuste") ("twfe_model_fit_comparison.csv") ///
    ("R-cuadrado within y ajuste de M1, M2 y M3.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (4) ("Diseño") ("twfe_channel_inclusion.csv") ///
    ("Matriz de inclusión de canales por modelo.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (5) ("Resultados") ("twfe_focal_coefficients.csv") ///
    ("RENTS, INST e interacción con inferencia.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (6) ("Estabilidad") ("twfe_focal_stability.csv") ///
    ("Cambios focales entre M1, M2 y M3.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (7) ("Inferencia") ("twfe_joint_tests_comparison.csv") ///
    ("Pruebas conjuntas por canal.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (8) ("Inferencia") ("twfe_wild_cluster_bootstrap.csv") ///
    ("Bootstrap de RENTS e interacción.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (9) ("Interpretación") ///
    ("twfe_marginal_effects_comparison.csv") ///
    ("Efectos marginales de RENTS según INST.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (10) ("Tabla") ("table_twfe_models_eci.tex") ///
    ("Tabla LaTeX M1-M3 para ECI.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (11) ("Tabla") ("table_twfe_models_eci.txt") ///
    ("Tabla de texto M1-M3 para ECI.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (12) ("Tabla") ("table_twfe_models_divx.tex") ///
    ("Tabla LaTeX M1-M3 para DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (13) ("Tabla") ("table_twfe_models_divx.txt") ///
    ("Tabla de texto M1-M3 para DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (14) ("Figura") ("twfe_focal_coefficients.png") ///
    ("Figura comparativa con intervalos del 95 %.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (15) ("Documentación") ("twfe_comparison_manifest.csv") ///
    ("Inventario reproducible de productos.")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `manifest_post'

preserve
    use "`manifest_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 15
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid order
    export delimited using ///
        "$OUTPUT_COMPARE/twfe_comparison_manifest.csv", ///
        replace datafmt
restore

local required_outputs ///
    twfe_model_design_register.csv ///
    twfe_comparison_sample_validation.csv ///
    twfe_model_fit_comparison.csv ///
    twfe_channel_inclusion.csv ///
    twfe_focal_coefficients.csv ///
    twfe_focal_stability.csv ///
    twfe_joint_tests_comparison.csv ///
    twfe_wild_cluster_bootstrap.csv ///
    twfe_marginal_effects_comparison.csv ///
    table_twfe_models_eci.tex ///
    table_twfe_models_eci.txt ///
    table_twfe_models_divx.tex ///
    table_twfe_models_divx.txt ///
    twfe_focal_coefficients.png ///
    twfe_comparison_manifest.csv

foreach required_output of local required_outputs {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "$OUTPUT_COMPARE/`required_output'"
    if _rc {
        display as error "Falta el producto: `required_output'"
        exit 603
    }
}

* Restaurar una estimación previa desde la memoria de Stata.
estimates restore DIVX_M3
display as result ///
    "Archivo 05 finalizado: secciones 13 y 14 sin errores."
display as text ///
    "M1 y M2 son temáticos paralelos; M3 es el contraste completo."
display as text ///
    "Resultados asociativos; no constituyen efectos causales."
log close comparison_log


// *****************************************************************************
// FIN DEL ARCHIVO 05.
// *****************************************************************************

* La ejecución termina después de validar todos los productos declarados.
