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
// Archivo: 07_twfe_mining_models.do (Versión Codex)
// Contenido: Extensión paralela de las secciones 15 a 18
// Extensión: Modelos 1 y 2 con RENTS_MINING exclusivamente
// Requisito operativo: ejecutar primero el archivo 01
// Estado: implementación completa de las secciones 15M a 18M
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************


// *****************************************************************************
// INICIALIZACIÓN DEL ARCHIVO 07
// *****************************************************************************

// D.1. Limpiar la sesión y fijar el entorno reproducible

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
set seed 20260804
* Definir la semilla de ordenamiento para garantizar la reproducibilidad de datos.
set sortseed 20260804


// D.2. Localizar la raíz del proyecto

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


// D.3. Definir entradas, salida única y log

global OUTPUT_ROOT ///
    "$PROJECT_ROOT/outputs/econometrics/stata-peer-2/01_twfe_main"
global OUTPUT_SAMPLE "$OUTPUT_ROOT/01_sample"
global OUTPUT_MIN "$OUTPUT_ROOT/11_mining_models"
global ADO_PROJECT "$OUTPUT_ROOT/ado"

capture mkdir "$PROJECT_ROOT/outputs"
capture mkdir "$PROJECT_ROOT/outputs/econometrics"
capture mkdir "$OUTPUT_ROOT"
capture mkdir "$OUTPUT_MIN"
capture mkdir "$ADO_PROJECT"
capture mkdir "$ADO_PROJECT/plus"

log using "$OUTPUT_MIN/07_twfe_mining_models.log", ///
    text replace name(mining_log)


// D.4. Verificar dependencias y archivos requeridos

adopath ++ "$ADO_PROJECT/plus"
net set ado "$ADO_PROJECT/plus"

capture which ftools
if _rc {
    ssc install ftools
}
capture which reghdfe
if _rc {
    ssc install reghdfe
}
capture which esttab
if _rc {
    ssc install estout
}
capture which boottest
if _rc {
    net install boottest, ///
        from("https://raw.githubusercontent.com/droodman/boottest/master") ///
        replace
}

foreach command in ftools reghdfe esttab boottest {
    capture which `command'
    if _rc {
        display as error "Stata no encuentra el comando: `command'"
        exit 199
    }
}

local estimation_file ///
    "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta"
* Verificar la existencia de un archivo antes de intentar cargarlo.
capture confirm file "`estimation_file'"
if _rc {
    display as error "No se encontró la base de estimación del archivo 01."
    exit 601
}

display as result ///
    "Inicialización completa; comienza la extensión RENTS_MINING."


// *****************************************************************************
// 15M. Diseño de los Modelos 1 y 2 con RENTS_MINING.
// *****************************************************************************

// 15M.1. Delimitar la pregunta de la extensión.

tempname design_post
tempfile design_register
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `design_post' ///
    str8 model str8 outcome str20 role str180 question ///
    str32 rent_measure str28 sample_rule str32 interpretation ///
    using "`design_register'", replace

foreach model in M1_MIN M2_MIN {
    * Escribir una fila de resultados dentro del archivo temporal.
    post `design_post' ///
        ("`model'") ("ECI") ("Principal") ///
        ("¿Cómo se asocian las rentas mineras con ECI?") ///
        ("Carbón más minerales, % PIB") ///
        ("Muestra común congelada") ("Asociación condicional")
    * Escribir una fila de resultados dentro del archivo temporal.
    post `design_post' ///
        ("`model'") ("DIVX") ("Complementario") ///
        ("¿Cómo se asocian las rentas mineras con DIVX?") ///
        ("Carbón más minerales, % PIB") ///
        ("Muestra común congelada") ("Asociación condicional")
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `design_post'

preserve
    use "`design_register'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 4
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert sample_rule == "Muestra común congelada"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert interpretation == "Asociación condicional"
    sort model outcome
    export delimited using ///
        "$OUTPUT_MIN/mining_design_register.csv", replace datafmt
restore


// 15M.2. Definir la variable focal.

use "`estimation_file'", clear
* Comprobar que la combinación de identificadores de país y año sea única.
isid country_iso3_code year

confirm variable ///
    country_iso3_code country country_id year ///
    eci hhi divx sample_eci sample_divx ///
    rents rents_oil_gas rents_mining inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin

foreach variable in ///
    country_id year eci hhi divx sample_eci sample_divx ///
    rents rents_oil_gas rents_mining inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin {
    confirm numeric variable `variable'
}

capture drop rents_mining_x_inst
generate double rents_mining_x_inst = rents_mining * inst ///
    if !missing(rents_mining, inst)
label variable rents_mining_x_inst "RENTS_MINING x INST"

* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(rents_mining_x_inst - rents_mining * inst) < 1e-10 ///
    if !missing(rents_mining_x_inst, rents_mining, inst)


// 15M.3. Validar cobertura, variación e identidad.

* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(rents - rents_oil_gas - rents_mining) < 1e-10 ///
    if !missing(rents, rents_oil_gas, rents_mining)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(divx - (1 - hhi)) < 1e-10 if !missing(divx, hhi)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert rents_mining >= 0 if !missing(rents_mining)

* Declarar la estructura de panel definiendo la variable país y año.
xtset country_id year


// 15M.4. Congelar la muestra comparable.

* Control de calidad automático que detiene el script si no se cumple la condición.
assert inlist(sample_eci, 0, 1)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert inlist(sample_divx, 0, 1)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_eci == sample_divx
generate byte sample_mining_common = sample_eci == 1 & sample_divx == 1
label variable sample_mining_common ///
    "Muestra común M1 y M2 con RENTS_MINING"

egen int mining_missing_union = rowmiss( ///
    eci hhi divx rents_mining inst rents_mining_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc pexp fexp ///
    vol rer humcap innov net log_gdppc govcons fin)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert mining_missing_union == 0 if sample_mining_common == 1

* Contar silenciosamente cuántas observaciones cumplen una condición determinada.
quietly count if sample_mining_common == 1
local mining_n = r(N)
quietly levelsof country_id if sample_mining_common == 1, ///
    local(mining_country_ids)
local mining_countries : word count `mining_country_ids'
quietly levelsof year if sample_mining_common == 1, ///
    local(mining_years)
local mining_year_count : word count `mining_years'
quietly summarize year if sample_mining_common == 1, meanonly
local mining_first_year = r(min)
local mining_last_year = r(max)

* Control de calidad automático que detiene el script si no se cumple la condición.
assert `mining_n' == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `mining_countries' == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `mining_year_count' == 23
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `mining_first_year' == 1996
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `mining_last_year' == 2021

bysort country_id: egen double mining_country_mean = ///
    mean(rents_mining) if sample_mining_common == 1
generate double mining_within_deviation = ///
    rents_mining - mining_country_mean if sample_mining_common == 1
quietly summarize mining_within_deviation if sample_mining_common == 1
* Control de calidad automático que detiene el script si no se cumple la condición.
assert r(sd) > 0
local mining_within_sd = r(sd)
drop mining_country_mean mining_within_deviation mining_missing_union


// 15M.5. Fijar estimación e inferencia comunes.

global MINING_INFERENCE "vce(cluster country_id)"
global MINING_INSTITUTIONAL c.rents_mining##c.inst

global MINING_M1_ABUNDANCE ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc
global MINING_M1_STRUCTURE_ECI hhi pexp fexp
global MINING_M1_STRUCTURE_DIVX pexp fexp
global MINING_M1_ECI_REGRESSORS ///
    $MINING_INSTITUTIONAL $MINING_M1_ABUNDANCE ///
    $MINING_M1_STRUCTURE_ECI log_gdppc
global MINING_M1_DIVX_REGRESSORS ///
    $MINING_INSTITUTIONAL $MINING_M1_ABUNDANCE ///
    $MINING_M1_STRUCTURE_DIVX log_gdppc

global MINING_M2_REGRESSORS ///
    $MINING_INSTITUTIONAL vol rer humcap innov net ///
    log_gdppc govcons fin

local mining_m1_eci_terms ///
    rents_mining inst c.rents_mining#c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp log_gdppc
local mining_m1_divx_terms ///
    rents_mining inst c.rents_mining#c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp log_gdppc
local mining_m2_terms ///
    rents_mining inst c.rents_mining#c.inst ///
    vol rer humcap innov net log_gdppc govcons fin


// 15M.6. Registrar el diseño antes de estimar.

tempname sample_post specification_post
tempfile sample_report specification_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `sample_post' ///
    str8 model str8 outcome long observations int countries ///
    int effective_years int first_year int last_year ///
    double mining_within_sd byte complete_union ///
    using "`sample_report'", replace

foreach model in M1_MIN M2_MIN {
    foreach outcome in ECI DIVX {
        * Escribir una fila de resultados dentro del archivo temporal.
        post `sample_post' ///
            ("`model'") ("`outcome'") ///
            (`mining_n') (`mining_countries') ///
            (`mining_year_count') ///
            (`mining_first_year') (`mining_last_year') ///
            (`mining_within_sd') (1)
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `sample_post'

preserve
    use "`sample_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 4
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert observations == 1044
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert countries == 49
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert complete_union == 1
    sort model outcome
    export delimited using ///
        "$OUTPUT_MIN/mining_sample_validation.csv", replace datafmt
restore

* Crear un archivo temporal para ir registrando resultados calculados.
postfile `specification_post' ///
    str8 model str8 outcome str244 regressors str32 hhi_rule ///
    using "`specification_report'", replace
* Escribir una fila de resultados dentro del archivo temporal.
post `specification_post' ///
    ("M1_MIN") ("ECI") ///
    ("RENTS_MINING, INST, interacción, OILPC, GASPC, " + ///
        "COALPC, HHI, PEXP, FEXP y log_GDPPC") ///
    ("Incluir HHI")
* Escribir una fila de resultados dentro del archivo temporal.
post `specification_post' ///
    ("M1_MIN") ("DIVX") ///
    ("RENTS_MINING, INST, interacción, OILPC, GASPC, " + ///
        "COALPC, PEXP, FEXP y log_GDPPC") ///
    ("Excluir HHI: DIVX=1-HHI")
* Escribir una fila de resultados dentro del archivo temporal.
post `specification_post' ///
    ("M2_MIN") ("ECI") ///
    ("RENTS_MINING, INST, interacción, VOL, RER, HUMCAP, " + ///
        "INNOV, NET, log_GDPPC, GOVCONS y FIN") ///
    ("No aplica")
* Escribir una fila de resultados dentro del archivo temporal.
post `specification_post' ///
    ("M2_MIN") ("DIVX") ///
    ("RENTS_MINING, INST, interacción, VOL, RER, HUMCAP, " + ///
        "INNOV, NET, log_GDPPC, GOVCONS y FIN") ///
    ("No aplica")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `specification_post'

preserve
    use "`specification_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 4
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    export delimited using ///
        "$OUTPUT_MIN/mining_specification_register.csv", ///
        replace datafmt
restore

display as result ///
    "Sección 15M completa: diseño y muestra RENTS_MINING validados."


// *****************************************************************************
// 16M. Modelo 1 con Rentas Mineras.
// *****************************************************************************

// 16M.1. Definir el canal institucional de M1.

tempname coefficient_post summary_post joint_post
tempfile coefficient_report summary_report joint_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `coefficient_post' ///
    str8 model str8 outcome int order str32 term ///
    double coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper using "`coefficient_report'", replace
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `summary_post' ///
    str8 model str8 outcome long observations int countries ///
    int clusters effective_years double r2_within r2_between ///
    r2_overall f_statistic model_p_value ///
    using "`summary_report'", replace
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `joint_post' ///
    str8 model str8 outcome int order str32 channel ///
    str100 null_hypothesis double f_statistic df1 df2 p_value ///
    using "`joint_report'", replace

* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(rents_mining_x_inst - rents_mining * inst) < 1e-10 ///
    if sample_mining_common == 1


// 16M.2. Incorporar abundancia y estructura exportadora.

foreach variable of global MINING_M1_ABUNDANCE {
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert `variable' >= 0 if sample_mining_common == 1
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert !missing(`variable') if sample_mining_common == 1
}
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(divx - (1 - hhi)) < 1e-10 ///
    if sample_mining_common == 1

* COALPC no representa toda la abundancia de minerales del subagregado.


// 16M.3. Estimar M1 para ECI.

xtreg eci $MINING_M1_ECI_REGRESSORS i.year ///
    if sample_mining_common == 1, fe $MINING_INFERENCE
capture estimates drop ECI_M1_MIN
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_M1_MIN
estimates save "$OUTPUT_MIN/mining_m1_eci.ster", replace

* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(sample) == sample_mining_common
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_clust) == 49

local critical_t = invttail(e(df_r), 0.025)
local order = 0
foreach term of local mining_m1_eci_terms {
    local ++order
    local b = _b[`term']
    local se = _se[`term']
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local lower = `b' - `critical_t' * `se'
    local upper = `b' + `critical_t' * `se'
    scalar mining_m1_eci_b_`order' = `b'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `coefficient_post' ///
        ("M1_MIN") ("ECI") (`order') ("`term'") ///
        (`b') (`se') (`t') (`p') (`lower') (`upper')
}
* Escribir una fila de resultados dentro del archivo temporal.
post `summary_post' ///
    ("M1_MIN") ("ECI") (e(N)) (e(N_g)) (e(N_clust)) ///
    (`mining_year_count') (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
    (e(F)) (e(p))

test rents_mining inst c.rents_mining#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_MIN") ("ECI") (1) ("Institucional") ///
    ("RENTS_MINING, INST e interacción son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test ln1p_oilpc ln1p_gaspc ln1p_coalpc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_MIN") ("ECI") (2) ("Abundancia") ///
    ("OILPC, GASPC y COALPC son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test hhi pexp fexp
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_MIN") ("ECI") (3) ("Estructura exportadora") ///
    ("HHI, PEXP y FEXP son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test log_gdppc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_MIN") ("ECI") (4) ("Nivel de desarrollo") ///
    ("log_GDPPC es igual a cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_MIN") ("ECI") (5) ("Efectos de año") ///
    ("Todos los indicadores de año son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))


// 16M.4. Estimar M1 para DIVX.

xtreg divx $MINING_M1_DIVX_REGRESSORS i.year ///
    if sample_mining_common == 1, fe $MINING_INFERENCE
capture estimates drop DIVX_M1_MIN
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_M1_MIN
estimates save "$OUTPUT_MIN/mining_m1_divx.ster", replace

* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(sample) == sample_mining_common
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_clust) == 49

local critical_t = invttail(e(df_r), 0.025)
local order = 0
foreach term of local mining_m1_divx_terms {
    local ++order
    local b = _b[`term']
    local se = _se[`term']
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local lower = `b' - `critical_t' * `se'
    local upper = `b' + `critical_t' * `se'
    scalar mining_m1_divx_b_`order' = `b'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `coefficient_post' ///
        ("M1_MIN") ("DIVX") (`order') ("`term'") ///
        (`b') (`se') (`t') (`p') (`lower') (`upper')
}
* Escribir una fila de resultados dentro del archivo temporal.
post `summary_post' ///
    ("M1_MIN") ("DIVX") (e(N)) (e(N_g)) (e(N_clust)) ///
    (`mining_year_count') (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
    (e(F)) (e(p))

test rents_mining inst c.rents_mining#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_MIN") ("DIVX") (1) ("Institucional") ///
    ("RENTS_MINING, INST e interacción son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test ln1p_oilpc ln1p_gaspc ln1p_coalpc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_MIN") ("DIVX") (2) ("Abundancia") ///
    ("OILPC, GASPC y COALPC son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test pexp fexp
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_MIN") ("DIVX") (3) ("Estructura exportadora") ///
    ("PEXP y FEXP son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test log_gdppc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_MIN") ("DIVX") (4) ("Nivel de desarrollo") ///
    ("log_GDPPC es igual a cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_MIN") ("DIVX") (5) ("Efectos de año") ///
    ("Todos los indicadores de año son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))


// 16M.5. Ejecutar pruebas conjuntas por canal.

* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `coefficient_post'
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `summary_post'
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `joint_post'

preserve
    use "`coefficient_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 19
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort model outcome order
    format coefficient standard_error t_statistic p_value ///
        ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_m1_coefficients.csv", replace datafmt
restore

preserve
    use "`summary_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 2
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert observations == 1044
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert countries == 49
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert clusters == 49
    sort outcome
    export delimited using ///
        "$OUTPUT_MIN/mining_m1_model_summary.csv", replace datafmt
restore

preserve
    use "`joint_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 10
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort outcome order
    format f_statistic p_value %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_m1_joint_tests.csv", replace datafmt
restore

display as result "Pruebas conjuntas de M1_MIN completadas."


// 16M.6. Calcular efectos marginales y bootstrap.

quietly summarize inst if sample_mining_common == 1, detail
local inst_p10 = r(p10)
local inst_p25 = r(p25)
local inst_p50 = r(p50)
local inst_p75 = r(p75)
local inst_p90 = r(p90)
local inst_values ///
    "`inst_p10' `inst_p25' `inst_p50' `inst_p75' `inst_p90'"
local inst_labels "P10 P25 P50 P75 P90"

tempname margins_post
tempfile margins_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `margins_post' ///
    str8 model str8 outcome int order str8 percentile ///
    double inst_value marginal_effect standard_error p_value ///
    ci_lower ci_upper using "`margins_report'", replace

local mining_estimates ECI_M1_MIN DIVX_M1_MIN
local mining_outcomes ECI DIVX
local mining_graphs mining_m1_eci mining_m1_divx

forvalues index = 1/2 {
    local estimate_name : word `index' of `mining_estimates'
    local outcome : word `index' of `mining_outcomes'
    local graph_name : word `index' of `mining_graphs'

    * Restaurar una estimación previa desde la memoria de Stata.
    estimates restore `estimate_name'
    margins, dydx(rents_mining) at(inst=(`inst_values'))
    matrix current_margins = r(table)

    forvalues column = 1/5 {
        local inst_value : word `column' of `inst_values'
        local percentile : word `column' of `inst_labels'
        * Escribir una fila de resultados dentro del archivo temporal.
        post `margins_post' ///
            ("M1_MIN") ("`outcome'") ///
            (`column') ("`percentile'") (`inst_value') ///
            (el(current_margins, 1, `column')) ///
            (el(current_margins, 2, `column')) ///
            (el(current_margins, 4, `column')) ///
            (el(current_margins, 5, `column')) ///
            (el(current_margins, 6, `column'))
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
        title("M1 - `outcome'", size(medsmall)) ///
        xtitle("Percentil de INST", size(small)) ///
        ytitle("Asociación marginal", size(small)) ///
        graphregion(color(white)) ///
        nodraw name(`graph_name', replace)
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `margins_post'

preserve
    use "`margins_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 10
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort outcome order
    format inst_value marginal_effect standard_error ///
        p_value ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_m1_marginal_effects.csv", ///
        replace datafmt
restore

graph combine mining_m1_eci mining_m1_divx, ///
    cols(2) graphregion(color(white)) ///
    title( ///
        "Asociación marginal de rentas mineras según INST", ///
        size(medsmall)) ///
    note( ///
        "Modelo 1; asociaciones condicionales con IC del 95 %", ///
        size(vsmall)) ///
    name(mining_m1_margins_combined, replace)
graph export "$OUTPUT_MIN/mining_m1_marginal_effects.png", ///
    width(3000) replace

tempname bootstrap_post
tempfile bootstrap_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `bootstrap_post' ///
    str8 model str8 outcome str28 term ///
    double coefficient conventional_p bootstrap_p ///
    ci_lower ci_upper repetitions str12 weight_type ///
    using "`bootstrap_report'", replace

forvalues index = 1/2 {
    local estimate_name : word `index' of `mining_estimates'
    local outcome : word `index' of `mining_outcomes'
    local seed_level = 20260820 + (2 * `index') - 1
    local seed_interaction = 20260820 + (2 * `index')

    * Restaurar una estimación previa desde la memoria de Stata.
    estimates restore `estimate_name'
    local level_p = 2 * ttail(e(df_r), ///
        abs(_b[rents_mining] / _se[rents_mining]))
    local interaction_p = 2 * ttail(e(df_r), ///
        abs(_b[c.rents_mining#c.inst] / ///
        _se[c.rents_mining#c.inst]))

    boottest rents_mining, cluster(country_id) reps(9999) ///
        seed(`seed_level') nograph
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert !missing(r(p))
    matrix level_ci = r(CI)
    * Escribir una fila de resultados dentro del archivo temporal.
    post `bootstrap_post' ///
        ("M1_MIN") ("`outcome'") ("RENTS_MINING") ///
        (_b[rents_mining]) (`level_p') (r(p)) ///
        (el(level_ci, 1, 1)) (el(level_ci, 1, 2)) ///
        (r(reps)) ("`r(weighttype)'")

    boottest c.rents_mining#c.inst, ///
        cluster(country_id) reps(9999) ///
        seed(`seed_interaction') nograph
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert !missing(r(p))
    matrix interaction_ci = r(CI)
    * Escribir una fila de resultados dentro del archivo temporal.
    post `bootstrap_post' ///
        ("M1_MIN") ("`outcome'") ///
        ("RENTS_MINING x INST") ///
        (_b[c.rents_mining#c.inst]) (`interaction_p') (r(p)) ///
        (el(interaction_ci, 1, 1)) ///
        (el(interaction_ci, 1, 2)) ///
        (r(reps)) ("`r(weighttype)'")
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `bootstrap_post'

preserve
    use "`bootstrap_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 4
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome term
    sort outcome term
    format coefficient conventional_p bootstrap_p ///
        ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_m1_wild_cluster_bootstrap.csv", ///
        replace datafmt
restore

display as result ///
    "Efectos marginales y bootstrap de M1_MIN completados."


// 16M.7. Verificar y almacenar M1.

tempname verification_post
tempfile verification_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `verification_post' ///
    str8 model str8 outcome int order str32 term ///
    double xtreg_coefficient reghdfe_coefficient ///
    absolute_difference byte coefficient_match ///
    using "`verification_report'", replace

local coefficient_tolerance = 1e-8
forvalues index = 1/2 {
    local outcome : word `index' of `mining_outcomes'
    if `index' == 1 {
        local dependent eci
        local regressors "$MINING_M1_ECI_REGRESSORS"
        local current_terms "`mining_m1_eci_terms'"
        local scalar_prefix "mining_m1_eci_b"
    }
    else {
        local dependent divx
        local regressors "$MINING_M1_DIVX_REGRESSORS"
        local current_terms "`mining_m1_divx_terms'"
        local scalar_prefix "mining_m1_divx_b"
    }

    * Estimar el modelo de regresión con efectos fijos de país y año y errores agrupados.
    reghdfe `dependent' `regressors' ///
        if sample_mining_common == 1, ///
        absorb(country_id year) $MINING_INFERENCE
    * Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
    assert e(N) == 1044

    local order = 0
    foreach term of local current_terms {
        local ++order
        local xtreg_b = scalar(`scalar_prefix'_`order')
        local hdfe_b = _b[`term']
        local difference = abs(`xtreg_b' - `hdfe_b')
        local match = `difference' < `coefficient_tolerance'
        * Control de calidad automático que detiene el script si no se cumple la condición.
        assert `match' == 1
        * Escribir una fila de resultados dentro del archivo temporal.
        post `verification_post' ///
            ("M1_MIN") ("`outcome'") ///
            (`order') ("`term'") ///
            (`xtreg_b') (`hdfe_b') (`difference') (`match')
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `verification_post'

preserve
    use "`verification_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 19
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert coefficient_match == 1
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort outcome order
    format xtreg_coefficient reghdfe_coefficient ///
        absolute_difference %16.10f
    export delimited using ///
        "$OUTPUT_MIN/mining_m1_xtreg_reghdfe_verification.csv", ///
        replace datafmt
restore

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab ECI_M1_MIN DIVX_M1_MIN ///
    using "$OUTPUT_MIN/mining_m1_results_table.tex", ///
    replace booktabs label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents_mining inst c.rents_mining#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp log_gdppc) ///
    order( ///
        rents_mining inst c.rents_mining#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp log_gdppc) ///
    coeflabels( ///
        rents_mining "RENTS_MINING" ///
        inst "INST" ///
        c.rents_mining#c.inst "RENTS_MINING x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        hhi "HHI" pexp "PEXP" fexp "FEXP" ///
        log_gdppc "log(GDPPC)") ///
    mtitles("ECI" "DIVX") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab ECI_M1_MIN DIVX_M1_MIN ///
    using "$OUTPUT_MIN/mining_m1_results_table.txt", ///
    replace label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents_mining inst c.rents_mining#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp log_gdppc) ///
    order( ///
        rents_mining inst c.rents_mining#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp log_gdppc) ///
    coeflabels( ///
        rents_mining "RENTS_MINING" ///
        inst "INST" ///
        c.rents_mining#c.inst "RENTS_MINING x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        hhi "HHI" pexp "PEXP" fexp "FEXP" ///
        log_gdppc "log(GDPPC)") ///
    mtitles("ECI" "DIVX") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))

tempname manifest_post
tempfile manifest_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `manifest_post' ///
    int order str28 family str80 file str140 purpose ///
    using "`manifest_report'", replace
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (1) ("Diseño") ("mining_design_register.csv") ///
    ("Pregunta y función de M1_MIN y M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (2) ("Muestra") ("mining_sample_validation.csv") ///
    ("Validación de 1.044 observaciones y 49 países.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (3) ("Diseño") ("mining_specification_register.csv") ///
    ("Regresores previstos y regla de HHI.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (4) ("Estimación") ("mining_m1_eci.ster") ///
    ("Estimación M1_MIN para ECI.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (5) ("Estimación") ("mining_m1_divx.ster") ///
    ("Estimación M1_MIN para DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (6) ("Resultados") ("mining_m1_coefficients.csv") ///
    ("Coeficientes e incertidumbre de M1_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (7) ("Resultados") ("mining_m1_model_summary.csv") ///
    ("Cobertura y ajuste within de M1_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (8) ("Inferencia") ("mining_m1_joint_tests.csv") ///
    ("Pruebas conjuntas por canal.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (9) ("Interpretación") ("mining_m1_marginal_effects.csv") ///
    ("Efectos marginales según percentiles de INST.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (10) ("Inferencia") ("mining_m1_wild_cluster_bootstrap.csv") ///
    ("Bootstrap de RENTS_MINING y su interacción.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (11) ("Verificación") ///
    ("mining_m1_xtreg_reghdfe_verification.csv") ///
    ("Equivalencia numérica entre xtreg y reghdfe.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (12) ("Tabla") ("mining_m1_results_table.tex") ///
    ("Tabla LaTeX del Modelo 1 minero.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (13) ("Tabla") ("mining_m1_results_table.txt") ///
    ("Tabla de texto del Modelo 1 minero.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (14) ("Figura") ("mining_m1_marginal_effects.png") ///
    ("Figura comparada para revisión visual.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (15) ("Documentación") ("mining_m1_results_manifest.csv") ///
    ("Inventario parcial hasta la sección 16M.")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `manifest_post'

preserve
    use "`manifest_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 15
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid order
    export delimited using ///
        "$OUTPUT_MIN/mining_m1_results_manifest.csv", replace datafmt
restore

local required_files ///
    mining_design_register.csv ///
    mining_sample_validation.csv ///
    mining_specification_register.csv ///
    mining_m1_eci.ster ///
    mining_m1_divx.ster ///
    mining_m1_coefficients.csv ///
    mining_m1_model_summary.csv ///
    mining_m1_joint_tests.csv ///
    mining_m1_marginal_effects.csv ///
    mining_m1_wild_cluster_bootstrap.csv ///
    mining_m1_xtreg_reghdfe_verification.csv ///
    mining_m1_results_table.tex ///
    mining_m1_results_table.txt ///
    mining_m1_marginal_effects.png ///
    mining_m1_results_manifest.csv

foreach required_file of local required_files {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "$OUTPUT_MIN/`required_file'"
    if _rc {
        display as error "Falta el producto: `required_file'"
        exit 603
    }
}

* Restaurar una estimación previa desde la memoria de Stata.
estimates restore DIVX_M1_MIN
display as result ///
    "Sección 16M completa: M1_MIN estimado y validado."


// *****************************************************************************
// 17M. Modelo 2 con Rentas Mineras.
// *****************************************************************************

// 17M.1. Definir el canal institucional de M2.

* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(rents_mining_x_inst - rents_mining * inst) < 1e-10 ///
    if sample_mining_common == 1


// 17M.2. Incorporar el canal macroeconómico.

* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(vol, rer) if sample_mining_common == 1


// 17M.3. Incorporar las capacidades productivas.

* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(humcap, innov, net) if sample_mining_common == 1


// 17M.4. Incorporar controles económicos, fiscales y financieros.

* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(log_gdppc, govcons, fin) ///
    if sample_mining_common == 1


// 17M.5. Estimar M2 para ECI y DIVX.

tempname m2_coefficient_post m2_summary_post m2_joint_post
tempfile m2_coefficient_report m2_summary_report m2_joint_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `m2_coefficient_post' ///
    str8 model str8 outcome int order str32 term ///
    double coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper using "`m2_coefficient_report'", replace
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `m2_summary_post' ///
    str8 model str8 outcome long observations int countries ///
    int clusters effective_years double r2_within r2_between ///
    r2_overall f_statistic model_p_value ///
    using "`m2_summary_report'", replace
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `m2_joint_post' ///
    str8 model str8 outcome int order str32 channel ///
    str100 null_hypothesis double f_statistic df1 df2 p_value ///
    using "`m2_joint_report'", replace

xtreg eci $MINING_M2_REGRESSORS i.year ///
    if sample_mining_common == 1, fe $MINING_INFERENCE
capture estimates drop ECI_M2_MIN
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_M2_MIN
estimates save "$OUTPUT_MIN/mining_m2_eci.ster", replace

* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(sample) == sample_mining_common
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_clust) == 49

local critical_t = invttail(e(df_r), 0.025)
local order = 0
foreach term of local mining_m2_terms {
    local ++order
    local b = _b[`term']
    local se = _se[`term']
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local lower = `b' - `critical_t' * `se'
    local upper = `b' + `critical_t' * `se'
    scalar mining_m2_eci_b_`order' = `b'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `m2_coefficient_post' ///
        ("M2_MIN") ("ECI") (`order') ("`term'") ///
        (`b') (`se') (`t') (`p') (`lower') (`upper')
}
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_summary_post' ///
    ("M2_MIN") ("ECI") (e(N)) (e(N_g)) (e(N_clust)) ///
    (`mining_year_count') (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
    (e(F)) (e(p))

test rents_mining inst c.rents_mining#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_joint_post' ///
    ("M2_MIN") ("ECI") (1) ("Institucional") ///
    ("RENTS_MINING, INST e interacción son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test vol rer
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_joint_post' ///
    ("M2_MIN") ("ECI") (2) ("Macroeconomía") ///
    ("VOL y RER son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test humcap innov net
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_joint_post' ///
    ("M2_MIN") ("ECI") (3) ("Capacidades productivas") ///
    ("HUMCAP, INNOV y NET son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test log_gdppc
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_joint_post' ///
    ("M2_MIN") ("ECI") (4) ("Nivel de desarrollo") ///
    ("log_GDPPC es igual a cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test govcons fin
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_joint_post' ///
    ("M2_MIN") ("ECI") (5) ("Fiscal y financiero") ///
    ("GOVCONS y FIN son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_joint_post' ///
    ("M2_MIN") ("ECI") (6) ("Efectos de año") ///
    ("Todos los indicadores de año son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

xtreg divx $MINING_M2_REGRESSORS i.year ///
    if sample_mining_common == 1, fe $MINING_INFERENCE
capture estimates drop DIVX_M2_MIN
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_M2_MIN
estimates save "$OUTPUT_MIN/mining_m2_divx.ster", replace

* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(sample) == sample_mining_common
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_clust) == 49

local critical_t = invttail(e(df_r), 0.025)
local order = 0
foreach term of local mining_m2_terms {
    local ++order
    local b = _b[`term']
    local se = _se[`term']
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local lower = `b' - `critical_t' * `se'
    local upper = `b' + `critical_t' * `se'
    scalar mining_m2_divx_b_`order' = `b'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `m2_coefficient_post' ///
        ("M2_MIN") ("DIVX") (`order') ("`term'") ///
        (`b') (`se') (`t') (`p') (`lower') (`upper')
}
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_summary_post' ///
    ("M2_MIN") ("DIVX") (e(N)) (e(N_g)) (e(N_clust)) ///
    (`mining_year_count') (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
    (e(F)) (e(p))

test rents_mining inst c.rents_mining#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_joint_post' ///
    ("M2_MIN") ("DIVX") (1) ("Institucional") ///
    ("RENTS_MINING, INST e interacción son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test vol rer
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_joint_post' ///
    ("M2_MIN") ("DIVX") (2) ("Macroeconomía") ///
    ("VOL y RER son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test humcap innov net
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_joint_post' ///
    ("M2_MIN") ("DIVX") (3) ("Capacidades productivas") ///
    ("HUMCAP, INNOV y NET son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test log_gdppc
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_joint_post' ///
    ("M2_MIN") ("DIVX") (4) ("Nivel de desarrollo") ///
    ("log_GDPPC es igual a cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test govcons fin
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_joint_post' ///
    ("M2_MIN") ("DIVX") (5) ("Fiscal y financiero") ///
    ("GOVCONS y FIN son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `m2_joint_post' ///
    ("M2_MIN") ("DIVX") (6) ("Efectos de año") ///
    ("Todos los indicadores de año son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))


// 17M.6. Ejecutar pruebas conjuntas por canal.

* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `m2_coefficient_post'
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `m2_summary_post'
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `m2_joint_post'

preserve
    use "`m2_coefficient_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 22
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort outcome order
    format coefficient standard_error t_statistic p_value ///
        ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_m2_coefficients.csv", replace datafmt
restore

preserve
    use "`m2_summary_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 2
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert observations == 1044
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert countries == 49
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert clusters == 49
    sort outcome
    export delimited using ///
        "$OUTPUT_MIN/mining_m2_model_summary.csv", replace datafmt
restore

preserve
    use "`m2_joint_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 12
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort outcome order
    format f_statistic p_value %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_m2_joint_tests.csv", replace datafmt
restore


// 17M.7. Calcular efectos marginales y bootstrap.

tempname m2_margins_post
tempfile m2_margins_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `m2_margins_post' ///
    str8 model str8 outcome int order str8 percentile ///
    double inst_value marginal_effect standard_error p_value ///
    ci_lower ci_upper using "`m2_margins_report'", replace

local mining_m2_estimates ECI_M2_MIN DIVX_M2_MIN
local mining_m2_outcomes ECI DIVX
local mining_m2_graphs mining_m2_eci mining_m2_divx

forvalues index = 1/2 {
    local estimate_name : word `index' of `mining_m2_estimates'
    local outcome : word `index' of `mining_m2_outcomes'
    local graph_name : word `index' of `mining_m2_graphs'

    * Restaurar una estimación previa desde la memoria de Stata.
    estimates restore `estimate_name'
    margins, dydx(rents_mining) at(inst=(`inst_values'))
    matrix current_margins = r(table)

    forvalues column = 1/5 {
        local inst_value : word `column' of `inst_values'
        local percentile : word `column' of `inst_labels'
        * Escribir una fila de resultados dentro del archivo temporal.
        post `m2_margins_post' ///
            ("M2_MIN") ("`outcome'") ///
            (`column') ("`percentile'") (`inst_value') ///
            (el(current_margins, 1, `column')) ///
            (el(current_margins, 2, `column')) ///
            (el(current_margins, 4, `column')) ///
            (el(current_margins, 5, `column')) ///
            (el(current_margins, 6, `column'))
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
        title("M2 - `outcome'", size(medsmall)) ///
        xtitle("Percentil de INST", size(small)) ///
        ytitle("Asociación marginal", size(small)) ///
        graphregion(color(white)) ///
        nodraw name(`graph_name', replace)
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `m2_margins_post'

preserve
    use "`m2_margins_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 10
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort outcome order
    format inst_value marginal_effect standard_error ///
        p_value ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_m2_marginal_effects.csv", ///
        replace datafmt
restore

graph combine mining_m2_eci mining_m2_divx, ///
    cols(2) graphregion(color(white)) ///
    title( ///
        "Asociación marginal de rentas mineras según INST", ///
        size(medsmall)) ///
    note( ///
        "Modelo 2; asociaciones condicionales con IC del 95 %", ///
        size(vsmall)) ///
    name(mining_m2_margins_combined, replace)
graph export "$OUTPUT_MIN/mining_m2_marginal_effects.png", ///
    width(3000) replace

tempname m2_bootstrap_post
tempfile m2_bootstrap_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `m2_bootstrap_post' ///
    str8 model str8 outcome str28 term ///
    double coefficient conventional_p bootstrap_p ///
    ci_lower ci_upper repetitions str12 weight_type ///
    using "`m2_bootstrap_report'", replace

forvalues index = 1/2 {
    local estimate_name : word `index' of `mining_m2_estimates'
    local outcome : word `index' of `mining_m2_outcomes'
    local seed_level = 20260830 + (2 * `index') - 1
    local seed_interaction = 20260830 + (2 * `index')

    * Restaurar una estimación previa desde la memoria de Stata.
    estimates restore `estimate_name'
    local level_p = 2 * ttail(e(df_r), ///
        abs(_b[rents_mining] / _se[rents_mining]))
    local interaction_p = 2 * ttail(e(df_r), ///
        abs(_b[c.rents_mining#c.inst] / ///
        _se[c.rents_mining#c.inst]))

    boottest rents_mining, cluster(country_id) reps(9999) ///
        seed(`seed_level') nograph
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert !missing(r(p))
    matrix level_ci = r(CI)
    * Escribir una fila de resultados dentro del archivo temporal.
    post `m2_bootstrap_post' ///
        ("M2_MIN") ("`outcome'") ("RENTS_MINING") ///
        (_b[rents_mining]) (`level_p') (r(p)) ///
        (el(level_ci, 1, 1)) (el(level_ci, 1, 2)) ///
        (r(reps)) ("`r(weighttype)'")

    boottest c.rents_mining#c.inst, ///
        cluster(country_id) reps(9999) ///
        seed(`seed_interaction') nograph
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert !missing(r(p))
    matrix interaction_ci = r(CI)
    * Escribir una fila de resultados dentro del archivo temporal.
    post `m2_bootstrap_post' ///
        ("M2_MIN") ("`outcome'") ///
        ("RENTS_MINING x INST") ///
        (_b[c.rents_mining#c.inst]) (`interaction_p') (r(p)) ///
        (el(interaction_ci, 1, 1)) ///
        (el(interaction_ci, 1, 2)) ///
        (r(reps)) ("`r(weighttype)'")
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `m2_bootstrap_post'

preserve
    use "`m2_bootstrap_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 4
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome term
    sort outcome term
    format coefficient conventional_p bootstrap_p ///
        ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_m2_wild_cluster_bootstrap.csv", ///
        replace datafmt
restore


// 17M.8. Verificar y almacenar M2.

tempname m2_verification_post
tempfile m2_verification_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `m2_verification_post' ///
    str8 model str8 outcome int order str32 term ///
    double xtreg_coefficient reghdfe_coefficient ///
    absolute_difference byte coefficient_match ///
    using "`m2_verification_report'", replace

forvalues index = 1/2 {
    local outcome : word `index' of `mining_m2_outcomes'
    if `index' == 1 {
        local dependent eci
        local scalar_prefix "mining_m2_eci_b"
    }
    else {
        local dependent divx
        local scalar_prefix "mining_m2_divx_b"
    }

    * Estimar el modelo de regresión con efectos fijos de país y año y errores agrupados.
    reghdfe `dependent' $MINING_M2_REGRESSORS ///
        if sample_mining_common == 1, ///
        absorb(country_id year) $MINING_INFERENCE
    * Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
    assert e(N) == 1044

    local order = 0
    foreach term of local mining_m2_terms {
        local ++order
        local xtreg_b = scalar(`scalar_prefix'_`order')
        local hdfe_b = _b[`term']
        local difference = abs(`xtreg_b' - `hdfe_b')
        local match = `difference' < `coefficient_tolerance'
        * Control de calidad automático que detiene el script si no se cumple la condición.
        assert `match' == 1
        * Escribir una fila de resultados dentro del archivo temporal.
        post `m2_verification_post' ///
            ("M2_MIN") ("`outcome'") ///
            (`order') ("`term'") ///
            (`xtreg_b') (`hdfe_b') (`difference') (`match')
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `m2_verification_post'

preserve
    use "`m2_verification_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 22
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert coefficient_match == 1
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort outcome order
    format xtreg_coefficient reghdfe_coefficient ///
        absolute_difference %16.10f
    export delimited using ///
        "$OUTPUT_MIN/mining_m2_xtreg_reghdfe_verification.csv", ///
        replace datafmt
restore

* Restaurar una estimación previa desde la memoria de Stata.
estimates restore DIVX_M2_MIN
display as result ///
    "Sección 17M completa: M2_MIN estimado y validado."


// *****************************************************************************
// 18M. Comparación y Exportación de los Modelos con RENTS_MINING.
// *****************************************************************************

// 18M.1. Comparar los coeficientes focales de M1 y M2.

tempname focal_post
tempfile focal_report mining_focal_data
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `focal_post' ///
    str4 model_family str8 outcome str16 resource_component ///
    int order str24 concept str32 term double coefficient ///
    standard_error p_value using "`focal_report'", replace

local mining_estimates_all ///
    ECI_M1_MIN DIVX_M1_MIN ECI_M2_MIN DIVX_M2_MIN
local mining_model_families M1 M1 M2 M2
local mining_outcomes_all ECI DIVX ECI DIVX
local mining_focal_terms ///
    rents_mining inst c.rents_mining#c.inst
local focal_concepts ///
    RENTS_MINING INST RENTS_MINING_x_INST

forvalues index = 1/4 {
    local estimate_name : word `index' of `mining_estimates_all'
    local model_family : word `index' of `mining_model_families'
    local outcome : word `index' of `mining_outcomes_all'
    * Restaurar una estimación previa desde la memoria de Stata.
    estimates restore `estimate_name'

    local order = 0
    foreach term of local mining_focal_terms {
        local ++order
        local concept : word `order' of `focal_concepts'
        local p = 2 * ttail(e(df_r), ///
            abs(_b[`term'] / _se[`term']))
        * Escribir una fila de resultados dentro del archivo temporal.
        post `focal_post' ///
            ("`model_family'") ("`outcome'") ///
            ("RENTS_MINING") (`order') ("`concept'") ///
            ("`term'") (_b[`term']) (_se[`term']) (`p')
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `focal_post'

preserve
    use "`focal_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 12
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model_family outcome resource_component order
    sort model_family outcome order
    format coefficient standard_error p_value %12.6f
    save "`mining_focal_data'", replace
    export delimited using ///
        "$OUTPUT_MIN/mining_model_comparison.csv", replace datafmt
restore

display as text ///
    "La comparación M1-M2 es descriptiva; no vota significancias."


// 18M.2. Contrastar con los modelos de RENTS totales.

global AGG_M1_ECI_REGRESSORS ///
    c.rents##c.inst ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp log_gdppc
global AGG_M1_DIVX_REGRESSORS ///
    c.rents##c.inst ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp log_gdppc
global AGG_M2_REGRESSORS ///
    c.rents##c.inst vol rer humcap innov net ///
    log_gdppc govcons fin

tempname aggregate_post
tempfile aggregate_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `aggregate_post' ///
    str4 model_family str8 outcome str16 specification ///
    int order str24 concept str32 term double coefficient ///
    standard_error p_value using "`aggregate_report'", replace

forvalues index = 1/4 {
    local mining_estimate : word `index' of `mining_estimates_all'
    local model_family : word `index' of `mining_model_families'
    local outcome : word `index' of `mining_outcomes_all'

    if `index' == 1 {
        local dependent eci
        local aggregate_regressors "$AGG_M1_ECI_REGRESSORS"
    }
    else if `index' == 2 {
        local dependent divx
        local aggregate_regressors "$AGG_M1_DIVX_REGRESSORS"
    }
    else if `index' == 3 {
        local dependent eci
        local aggregate_regressors "$AGG_M2_REGRESSORS"
    }
    else {
        local dependent divx
        local aggregate_regressors "$AGG_M2_REGRESSORS"
    }

    quietly xtreg `dependent' `aggregate_regressors' i.year ///
        if sample_mining_common == 1, fe $MINING_INFERENCE
    * Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
    assert e(N) == 1044
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert e(N_g) == 49

    local aggregate_terms rents inst c.rents#c.inst
    local aggregate_concepts RENTS INST RENTS_x_INST
    local order = 0
    foreach term of local aggregate_terms {
        local ++order
        local concept : word `order' of `aggregate_concepts'
        local p = 2 * ttail(e(df_r), ///
            abs(_b[`term'] / _se[`term']))
        * Escribir una fila de resultados dentro del archivo temporal.
        post `aggregate_post' ///
            ("`model_family'") ("`outcome'") ("RENTS total") ///
            (`order') ("`concept'") ("`term'") ///
            (_b[`term']) (_se[`term']) (`p')
    }

    * Restaurar una estimación previa desde la memoria de Stata.
    estimates restore `mining_estimate'
    local order = 0
    foreach term of local mining_focal_terms {
        local ++order
        local concept : word `order' of `aggregate_concepts'
        local p = 2 * ttail(e(df_r), ///
            abs(_b[`term'] / _se[`term']))
        * Escribir una fila de resultados dentro del archivo temporal.
        post `aggregate_post' ///
            ("`model_family'") ("`outcome'") ("RENTS_MINING") ///
            (`order') ("`concept'") ("`term'") ///
            (_b[`term']) (_se[`term']) (`p')
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `aggregate_post'

preserve
    use "`aggregate_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 24
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model_family outcome specification order
    sort model_family outcome order specification
    format coefficient standard_error p_value %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_aggregate_comparison.csv", ///
        replace datafmt
restore


// 18M.3. Contrastar con RENTS_OIL_GAS.

local oil_gas_coefficients ///
    "$OUTPUT_ROOT/10_oil_gas_models/og_coefficients.csv"
local oil_gas_summary ///
    "$OUTPUT_ROOT/10_oil_gas_models/og_model_summary.csv"
* Verificar la existencia de un archivo antes de intentar cargarlo.
capture confirm file "`oil_gas_coefficients'"
if _rc {
    display as error ///
        "Falta og_coefficients.csv; ejecute primero el archivo 06."
    exit 601
}
* Verificar la existencia de un archivo antes de intentar cargarlo.
capture confirm file "`oil_gas_summary'"
if _rc {
    display as error ///
        "Falta og_model_summary.csv; ejecute primero el archivo 06."
    exit 601
}

preserve
    import delimited using "`oil_gas_summary'", ///
        clear varnames(1) encoding(utf8)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 4
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert observations == 1044
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert countries == 49
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert clusters == 49
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
restore

tempfile oil_gas_focal_data
preserve
    import delimited using "`oil_gas_coefficients'", ///
        clear varnames(1) encoding(utf8)
    keep if inlist(term, ///
        "rents_oil_gas", "inst", ///
        "c.rents_oil_gas#c.inst")
    keep model outcome term coefficient standard_error p_value
    generate str4 model_family = substr(model, 1, 2)
    generate str16 resource_component = "RENTS_OIL_GAS"
    generate int order = .
    replace order = 1 if term == "rents_oil_gas"
    replace order = 2 if term == "inst"
    replace order = 3 if term == "c.rents_oil_gas#c.inst"
    generate str24 concept = ""
    replace concept = "RENTS_COMPONENT" if order == 1
    replace concept = "INST" if order == 2
    replace concept = "RENTS_COMPONENT_x_INST" if order == 3
    keep model_family outcome resource_component order concept ///
        term coefficient standard_error p_value
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 12
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model_family outcome resource_component order
    save "`oil_gas_focal_data'", replace
restore

preserve
    use "`mining_focal_data'", clear
    replace concept = "RENTS_COMPONENT" if order == 1
    replace concept = "RENTS_COMPONENT_x_INST" if order == 3
    append using "`oil_gas_focal_data'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 24
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model_family outcome resource_component order
    sort model_family outcome order resource_component
    format coefficient standard_error p_value %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_oil_gas_comparison.csv", ///
        replace datafmt
restore

display as text ///
    "La comparación sectorial es descriptiva y no prueba diferencias."


// 18M.4. Resumir pruebas conjuntas y efectos marginales.

preserve
    use "`coefficient_report'", clear
    append using "`m2_coefficient_report'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 41
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort model outcome order
    format coefficient standard_error t_statistic p_value ///
        ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_coefficients.csv", replace datafmt
restore

preserve
    use "`summary_report'", clear
    append using "`m2_summary_report'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 4
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert observations == 1044
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert countries == 49
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert clusters == 49
    sort model outcome
    export delimited using ///
        "$OUTPUT_MIN/mining_model_summary.csv", replace datafmt
restore

preserve
    use "`joint_report'", clear
    append using "`m2_joint_report'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 22
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort model outcome order
    format f_statistic p_value %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_joint_tests.csv", replace datafmt
restore

preserve
    use "`margins_report'", clear
    append using "`m2_margins_report'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 20
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort model outcome order
    format inst_value marginal_effect standard_error ///
        p_value ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_marginal_effects.csv", replace datafmt
restore

preserve
    use "`bootstrap_report'", clear
    append using "`m2_bootstrap_report'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 8
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome term
    sort model outcome term
    format coefficient conventional_p bootstrap_p ///
        ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_MIN/mining_wild_cluster_bootstrap.csv", ///
        replace datafmt
restore

preserve
    use "`verification_report'", clear
    append using "`m2_verification_report'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 41
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert coefficient_match == 1
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort model outcome order
    format xtreg_coefficient reghdfe_coefficient ///
        absolute_difference %16.10f
    export delimited using ///
        "$OUTPUT_MIN/mining_xtreg_reghdfe_verification.csv", ///
        replace datafmt
restore

graph combine ///
    mining_m1_eci mining_m1_divx ///
    mining_m2_eci mining_m2_divx, ///
    cols(2) graphregion(color(white)) ///
    title( ///
        "Asociación marginal de rentas mineras según INST", ///
        size(medsmall)) ///
    note( ///
        "Modelos 1 y 2; asociaciones condicionales con IC del 95 %", ///
        size(vsmall)) ///
    name(mining_margins_combined, replace)
graph export "$OUTPUT_MIN/mining_marginal_effects.png", ///
    width(3000) replace


// 18M.5. Crear las tablas comparativas.

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab ECI_M2_MIN DIVX_M2_MIN ///
    using "$OUTPUT_MIN/mining_m2_results_table.tex", ///
    replace booktabs label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents_mining inst c.rents_mining#c.inst ///
        vol rer humcap innov net log_gdppc govcons fin) ///
    order( ///
        rents_mining inst c.rents_mining#c.inst ///
        vol rer humcap innov net log_gdppc govcons fin) ///
    coeflabels( ///
        rents_mining "RENTS_MINING" ///
        inst "INST" ///
        c.rents_mining#c.inst "RENTS_MINING x INST" ///
        vol "VOL" rer "RER" humcap "HUMCAP" ///
        innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" govcons "GOVCONS" fin "FIN") ///
    mtitles("ECI" "DIVX") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab ECI_M2_MIN DIVX_M2_MIN ///
    using "$OUTPUT_MIN/mining_m2_results_table.txt", ///
    replace label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents_mining inst c.rents_mining#c.inst ///
        vol rer humcap innov net log_gdppc govcons fin) ///
    order( ///
        rents_mining inst c.rents_mining#c.inst ///
        vol rer humcap innov net log_gdppc govcons fin) ///
    coeflabels( ///
        rents_mining "RENTS_MINING" ///
        inst "INST" ///
        c.rents_mining#c.inst "RENTS_MINING x INST" ///
        vol "VOL" rer "RER" humcap "HUMCAP" ///
        innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" govcons "GOVCONS" fin "FIN") ///
    mtitles("ECI" "DIVX") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab ///
    ECI_M1_MIN DIVX_M1_MIN ECI_M2_MIN DIVX_M2_MIN ///
    using "$OUTPUT_MIN/mining_models_comparison_table.tex", ///
    replace booktabs label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents_mining inst c.rents_mining#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc hhi pexp fexp ///
        vol rer humcap innov net log_gdppc govcons fin) ///
    order( ///
        rents_mining inst c.rents_mining#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc hhi pexp fexp ///
        vol rer humcap innov net log_gdppc govcons fin) ///
    coeflabels( ///
        rents_mining "RENTS_MINING" ///
        inst "INST" ///
        c.rents_mining#c.inst "RENTS_MINING x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        hhi "HHI" pexp "PEXP" fexp "FEXP" ///
        vol "VOL" rer "RER" humcap "HUMCAP" ///
        innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" govcons "GOVCONS" fin "FIN") ///
    mtitles("M1 ECI" "M1 DIVX" "M2 ECI" "M2 DIVX") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab ///
    ECI_M1_MIN DIVX_M1_MIN ECI_M2_MIN DIVX_M2_MIN ///
    using "$OUTPUT_MIN/mining_models_comparison_table.txt", ///
    replace label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents_mining inst c.rents_mining#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc hhi pexp fexp ///
        vol rer humcap innov net log_gdppc govcons fin) ///
    order( ///
        rents_mining inst c.rents_mining#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc hhi pexp fexp ///
        vol rer humcap innov net log_gdppc govcons fin) ///
    coeflabels( ///
        rents_mining "RENTS_MINING" ///
        inst "INST" ///
        c.rents_mining#c.inst "RENTS_MINING x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        hhi "HHI" pexp "PEXP" fexp "FEXP" ///
        vol "VOL" rer "RER" humcap "HUMCAP" ///
        innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" govcons "GOVCONS" fin "FIN") ///
    mtitles("M1 ECI" "M1 DIVX" "M2 ECI" "M2 DIVX") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))


// 18M.6. Exportar las salidas en una carpeta plana.

display as result ///
    "Todas las salidas se guardaron directamente en 11_mining_models."


// 18M.7. Validar el paquete y cerrar el archivo.

tempname full_manifest_post
tempfile full_manifest_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `full_manifest_post' ///
    int order str28 family str80 file str140 purpose ///
    using "`full_manifest_report'", replace
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (1) ("Diseño") ("mining_design_register.csv") ///
    ("Pregunta y función de las cuatro ecuaciones.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (2) ("Muestra") ("mining_sample_validation.csv") ///
    ("Validación de 1.044 observaciones y 49 países.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (3) ("Diseño") ("mining_specification_register.csv") ///
    ("Regresores y regla de HHI por ecuación.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (4) ("Estimación") ("mining_m1_eci.ster") ///
    ("Estimación M1_MIN para ECI.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (5) ("Estimación") ("mining_m1_divx.ster") ///
    ("Estimación M1_MIN para DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (6) ("Estimación") ("mining_m2_eci.ster") ///
    ("Estimación M2_MIN para ECI.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (7) ("Estimación") ("mining_m2_divx.ster") ///
    ("Estimación M2_MIN para DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (8) ("Resultados") ("mining_m1_coefficients.csv") ///
    ("Coeficientes e incertidumbre de M1_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (9) ("Resultados") ("mining_m2_coefficients.csv") ///
    ("Coeficientes e incertidumbre de M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (10) ("Resultados") ("mining_coefficients.csv") ///
    ("Coeficientes de las cuatro ecuaciones.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (11) ("Resultados") ("mining_m1_model_summary.csv") ///
    ("Cobertura y ajuste within de M1_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (12) ("Resultados") ("mining_m2_model_summary.csv") ///
    ("Cobertura y ajuste within de M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (13) ("Resultados") ("mining_model_summary.csv") ///
    ("Resumen de las cuatro ecuaciones.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (14) ("Inferencia") ("mining_m1_joint_tests.csv") ///
    ("Pruebas conjuntas de M1_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (15) ("Inferencia") ("mining_m2_joint_tests.csv") ///
    ("Pruebas conjuntas de M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (16) ("Inferencia") ("mining_joint_tests.csv") ///
    ("Pruebas conjuntas de M1_MIN y M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (17) ("Comparación") ("mining_model_comparison.csv") ///
    ("Comparación focal entre M1_MIN y M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (18) ("Comparación") ("mining_aggregate_comparison.csv") ///
    ("Contraste con RENTS total en la misma muestra.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (19) ("Comparación") ("mining_oil_gas_comparison.csv") ///
    ("Contraste descriptivo con RENTS_OIL_GAS.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (20) ("Interpretación") ("mining_m1_marginal_effects.csv") ///
    ("Efectos marginales de M1_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (21) ("Interpretación") ("mining_m2_marginal_effects.csv") ///
    ("Efectos marginales de M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (22) ("Interpretación") ("mining_marginal_effects.csv") ///
    ("Efectos marginales de las cuatro ecuaciones.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (23) ("Inferencia") ("mining_m1_wild_cluster_bootstrap.csv") ///
    ("Bootstrap de M1_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (24) ("Inferencia") ("mining_m2_wild_cluster_bootstrap.csv") ///
    ("Bootstrap de M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (25) ("Inferencia") ("mining_wild_cluster_bootstrap.csv") ///
    ("Bootstrap de M1_MIN y M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (26) ("Verificación") ///
    ("mining_m1_xtreg_reghdfe_verification.csv") ///
    ("Equivalencia xtreg-reghdfe de M1_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (27) ("Verificación") ///
    ("mining_m2_xtreg_reghdfe_verification.csv") ///
    ("Equivalencia xtreg-reghdfe de M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (28) ("Verificación") ///
    ("mining_xtreg_reghdfe_verification.csv") ///
    ("Equivalencia de las cuatro ecuaciones.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (29) ("Tabla") ("mining_m1_results_table.tex") ///
    ("Tabla LaTeX del Modelo 1 minero.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (30) ("Tabla") ("mining_m1_results_table.txt") ///
    ("Tabla de texto del Modelo 1 minero.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (31) ("Tabla") ("mining_m2_results_table.tex") ///
    ("Tabla LaTeX del Modelo 2 minero.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (32) ("Tabla") ("mining_m2_results_table.txt") ///
    ("Tabla de texto del Modelo 2 minero.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (33) ("Tabla") ("mining_models_comparison_table.tex") ///
    ("Tabla LaTeX comparativa de M1_MIN y M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (34) ("Tabla") ("mining_models_comparison_table.txt") ///
    ("Tabla de texto comparativa de M1_MIN y M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (35) ("Figura") ("mining_m1_marginal_effects.png") ///
    ("Figura de efectos marginales de M1_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (36) ("Figura") ("mining_m2_marginal_effects.png") ///
    ("Figura de efectos marginales de M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (37) ("Figura") ("mining_marginal_effects.png") ///
    ("Figura comparativa de M1_MIN y M2_MIN.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (38) ("Documentación") ("mining_m1_results_manifest.csv") ///
    ("Inventario parcial hasta la sección 16M.")
* Escribir una fila de resultados dentro del archivo temporal.
post `full_manifest_post' ///
    (39) ("Documentación") ("mining_results_manifest.csv") ///
    ("Inventario reproducible de las secciones 15M a 18M.")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `full_manifest_post'

preserve
    use "`full_manifest_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 39
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid order
    export delimited using ///
        "$OUTPUT_MIN/mining_results_manifest.csv", replace datafmt
restore

local required_files_full ///
    mining_design_register.csv ///
    mining_sample_validation.csv ///
    mining_specification_register.csv ///
    mining_m1_eci.ster ///
    mining_m1_divx.ster ///
    mining_m2_eci.ster ///
    mining_m2_divx.ster ///
    mining_m1_coefficients.csv ///
    mining_m2_coefficients.csv ///
    mining_coefficients.csv ///
    mining_m1_model_summary.csv ///
    mining_m2_model_summary.csv ///
    mining_model_summary.csv ///
    mining_m1_joint_tests.csv ///
    mining_m2_joint_tests.csv ///
    mining_joint_tests.csv ///
    mining_model_comparison.csv ///
    mining_aggregate_comparison.csv ///
    mining_oil_gas_comparison.csv ///
    mining_m1_marginal_effects.csv ///
    mining_m2_marginal_effects.csv ///
    mining_marginal_effects.csv ///
    mining_m1_wild_cluster_bootstrap.csv ///
    mining_m2_wild_cluster_bootstrap.csv ///
    mining_wild_cluster_bootstrap.csv ///
    mining_m1_xtreg_reghdfe_verification.csv ///
    mining_m2_xtreg_reghdfe_verification.csv ///
    mining_xtreg_reghdfe_verification.csv ///
    mining_m1_results_table.tex ///
    mining_m1_results_table.txt ///
    mining_m2_results_table.tex ///
    mining_m2_results_table.txt ///
    mining_models_comparison_table.tex ///
    mining_models_comparison_table.txt ///
    mining_m1_marginal_effects.png ///
    mining_m2_marginal_effects.png ///
    mining_marginal_effects.png ///
    mining_m1_results_manifest.csv ///
    mining_results_manifest.csv

foreach required_file of local required_files_full {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "$OUTPUT_MIN/`required_file'"
    if _rc {
        display as error "Falta el producto: `required_file'"
        exit 603
    }
}

* Restaurar una estimación previa desde la memoria de Stata.
estimates restore DIVX_M2_MIN
display as result ///
    "Archivo 07 finalizado: secciones 15M a 18M sin errores."
display as text ///
    "Resultados asociativos; no constituyen efectos causales."
log close mining_log


// *****************************************************************************
// FIN DEL ARCHIVO 07.
// *****************************************************************************

* La ejecución termina después de validar todos los productos declarados.
