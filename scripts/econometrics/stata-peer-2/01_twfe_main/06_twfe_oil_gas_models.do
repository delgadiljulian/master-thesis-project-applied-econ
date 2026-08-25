// *****************************************************************************
// Universidad: Universidad de Buenos Aires
// Facultad: Facultad de Ciencias Económicas
// Escuela: Escuela de Negocios y Administración Pública
// Programa: Maestría en Economía Aplicada
//
// Tipo de trabajo: Trabajo Final de Maestría (TFM)
// Título: Rentas extractivas y transformación estructural externa en economías
//         dependientes de recursos naturales no renovables del subsuelo (1996--2021)
// Autor: Julián Alberto Delgadillo Marín
// Director: Martín Grandes
//
// Archivo: 06_twfe_oil_gas_models.do (Versión Codex - Peer-2)
// Contenido: Sub-especificación de Hidrocarburos (Petróleo y Gas Natural)
// Propósito: Desagregar las rentas totales (RENTS) para aislar el impacto específico
//            de RENTS_OIL_GAS (% PIB) y su interacción institucional sobre ECI y DIVX.
// Requisito operativo: Ejecutar previamente 01_data_preparation_diagnostics.do
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************

// =============================================================================
// GUÍA RÁPIDA DE COMPRENSIÓN ECONOMÉTRICA (HIDROCARBUROS):
// - ¿Por qué desagregar petróleo y gas? Las rentas petroleras suelen presentar una intensidad
//   de capital y concentración de enclaves superiores a los minerales sólidos.
// - Ecuación de estimación: Y_it = f(RENTS_OIL_GAS_it, INST_it, RENTS_OIL_GAS_it × INST_it, X_it)
//   empleando la sintaxis factorial nativa c.rents_oil_gas##c.inst.
// =============================================================================

// *****************************************************************************
// INICIALIZACIÓN DEL ARCHIVO 06
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
set seed 20260803
* Definir la semilla de ordenamiento para garantizar la reproducibilidad de datos.
set sortseed 20260803


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
global OUTPUT_OG "$OUTPUT_ROOT/10_oil_gas_models"
global OUTPUT_OG_M3 "$OUTPUT_OG/03_m3_full"
global ADO_PROJECT "$OUTPUT_ROOT/ado"

capture mkdir "$PROJECT_ROOT/outputs"
capture mkdir "$PROJECT_ROOT/outputs/econometrics"
capture mkdir "$OUTPUT_ROOT"
capture mkdir "$OUTPUT_OG"
capture mkdir "$OUTPUT_OG_M3"
capture mkdir "$ADO_PROJECT"
capture mkdir "$ADO_PROJECT/plus"

log using "$OUTPUT_OG/06_twfe_oil_gas_models.log", ///
    text replace name(og_log)


// C.4. Verificar dependencias y archivos requeridos

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
    "Inicialización completa; comienza la extensión RENTS_OIL_GAS."


// *****************************************************************************
// 15. Diseño de los Modelos 1, 2 y 3 con RENTS_OIL_GAS
// *****************************************************************************

// 15.1. Delimitar la pregunta de la extensión

tempname design_post
tempfile design_register
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `design_post' ///
    str8 model str8 outcome str20 role str180 question ///
    str32 rent_measure str28 sample_rule str32 interpretation ///
    using "`design_register'", replace

foreach model in M1_OG M2_OG M3_OG {
    * Escribir una fila de resultados dentro del archivo temporal.
    post `design_post' ///
        ("`model'") ("ECI") ("Principal") ///
        ("¿Cómo se asocian las rentas de petróleo y gas con ECI?") ///
        ("Petróleo más gas, % PIB") ///
        ("Muestra común congelada") ("Asociación condicional")
    * Escribir una fila de resultados dentro del archivo temporal.
    post `design_post' ///
        ("`model'") ("DIVX") ("Complementario") ///
        ("¿Cómo se asocian las rentas de petróleo y gas con DIVX?") ///
        ("Petróleo más gas, % PIB") ///
        ("Muestra común congelada") ("Asociación condicional")
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `design_post'

preserve
    use "`design_register'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 6
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert sample_rule == "Muestra común congelada"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert interpretation == "Asociación condicional"
    sort model outcome
    export delimited using ///
        "$OUTPUT_OG/og_design_register.csv", replace datafmt
restore


// 15.2. Definir la variable focal

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

capture drop rents_oil_gas_x_inst
generate double rents_oil_gas_x_inst = rents_oil_gas * inst ///
    if !missing(rents_oil_gas, inst)
label variable rents_oil_gas_x_inst "RENTS_OIL_GAS x INST"

* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(rents_oil_gas_x_inst - rents_oil_gas * inst) < 1e-10 ///
    if !missing(rents_oil_gas_x_inst, rents_oil_gas, inst)


// 15.3. Validar cobertura, variación e identidad

* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(rents - rents_oil_gas - rents_mining) < 1e-10 ///
    if !missing(rents, rents_oil_gas, rents_mining)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(divx - (1 - hhi)) < 1e-10 if !missing(divx, hhi)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert rents_oil_gas >= 0 if !missing(rents_oil_gas)

* Declarar la estructura de panel definiendo la variable país y año.
xtset country_id year


// 15.4. Congelar la muestra comparable

* Control de calidad automático que detiene el script si no se cumple la condición.
assert inlist(sample_eci, 0, 1)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert inlist(sample_divx, 0, 1)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_eci == sample_divx
generate byte sample_og_common = sample_eci == 1 & sample_divx == 1
label variable sample_og_common ///
    "Muestra común M1 y M2 con RENTS_OIL_GAS"

egen int og_missing_union = rowmiss( ///
    eci hhi divx rents_oil_gas inst rents_oil_gas_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc pexp fexp ///
    vol rer humcap innov net log_gdppc govcons fin)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert og_missing_union == 0 if sample_og_common == 1

* Contar silenciosamente cuántas observaciones cumplen una condición determinada.
quietly count if sample_og_common == 1
local og_n = r(N)
quietly levelsof country_id if sample_og_common == 1, ///
    local(og_country_ids)
local og_countries : word count `og_country_ids'
quietly levelsof year if sample_og_common == 1, local(og_years)
local og_year_count : word count `og_years'
quietly summarize year if sample_og_common == 1, meanonly
local og_first_year = r(min)
local og_last_year = r(max)

* Control de calidad automático que detiene el script si no se cumple la condición.
assert `og_n' == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `og_countries' == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `og_year_count' == 23
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `og_first_year' == 1996
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `og_last_year' == 2021

bysort country_id: egen double og_country_mean = ///
    mean(rents_oil_gas) if sample_og_common == 1
generate double og_within_deviation = ///
    rents_oil_gas - og_country_mean if sample_og_common == 1
quietly summarize og_within_deviation if sample_og_common == 1
* Control de calidad automático que detiene el script si no se cumple la condición.
assert r(sd) > 0
local og_within_sd = r(sd)
drop og_country_mean og_within_deviation og_missing_union


// 15.5. Fijar estimación e inferencia comunes

global OG_INFERENCE "vce(cluster country_id)"
global OG_INSTITUTIONAL c.rents_oil_gas##c.inst

global OG_M1_ABUNDANCE ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc
global OG_M1_STRUCTURE_ECI hhi pexp fexp
global OG_M1_STRUCTURE_DIVX pexp fexp
global OG_M1_ECI_REGRESSORS ///
    $OG_INSTITUTIONAL $OG_M1_ABUNDANCE ///
    $OG_M1_STRUCTURE_ECI log_gdppc
global OG_M1_DIVX_REGRESSORS ///
    $OG_INSTITUTIONAL $OG_M1_ABUNDANCE ///
    $OG_M1_STRUCTURE_DIVX log_gdppc

global OG_M2_REGRESSORS ///
    $OG_INSTITUTIONAL vol rer humcap innov net ///
    log_gdppc govcons fin

global OG_M3_ECI_REGRESSORS ///
    $OG_INSTITUTIONAL $OG_M1_ABUNDANCE ///
    $OG_M1_STRUCTURE_ECI vol rer humcap innov net ///
    log_gdppc govcons fin
global OG_M3_DIVX_REGRESSORS ///
    $OG_INSTITUTIONAL $OG_M1_ABUNDANCE ///
    $OG_M1_STRUCTURE_DIVX vol rer humcap innov net ///
    log_gdppc govcons fin

local og_m1_eci_terms ///
    rents_oil_gas inst c.rents_oil_gas#c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp log_gdppc
local og_m1_divx_terms ///
    rents_oil_gas inst c.rents_oil_gas#c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp log_gdppc
local og_m2_terms ///
    rents_oil_gas inst c.rents_oil_gas#c.inst ///
    vol rer humcap innov net log_gdppc govcons fin
local og_m3_eci_terms ///
    rents_oil_gas inst c.rents_oil_gas#c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin
local og_m3_divx_terms ///
    rents_oil_gas inst c.rents_oil_gas#c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin


// 15.6. Registrar el diseño antes de estimar

tempname sample_post specification_post
tempfile sample_report specification_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `sample_post' ///
    str8 model str8 outcome long observations int countries ///
    int effective_years int first_year int last_year ///
    double oil_gas_within_sd byte complete_union ///
    using "`sample_report'", replace

foreach model in M1_OG M2_OG M3_OG {
    foreach outcome in ECI DIVX {
        * Escribir una fila de resultados dentro del archivo temporal.
        post `sample_post' ///
            ("`model'") ("`outcome'") (`og_n') (`og_countries') ///
            (`og_year_count') (`og_first_year') (`og_last_year') ///
            (`og_within_sd') (1)
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `sample_post'

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
    assert complete_union == 1
    sort model outcome
    export delimited using ///
        "$OUTPUT_OG/og_sample_validation.csv", replace datafmt
restore

* Crear un archivo temporal para ir registrando resultados calculados.
postfile `specification_post' ///
    str8 model str8 outcome str244 regressors str32 hhi_rule ///
    using "`specification_report'", replace
* Escribir una fila de resultados dentro del archivo temporal.
post `specification_post' ///
    ("M1_OG") ("ECI") ///
    ("RENTS_OIL_GAS, INST, interacción, OILPC, GASPC, " + ///
        "COALPC, HHI, PEXP, FEXP y log_GDPPC") ///
    ("Incluir HHI")
* Escribir una fila de resultados dentro del archivo temporal.
post `specification_post' ///
    ("M1_OG") ("DIVX") ///
    ("RENTS_OIL_GAS, INST, interacción, OILPC, GASPC, " + ///
        "COALPC, PEXP, FEXP y log_GDPPC") ///
    ("Excluir HHI: DIVX=1-HHI")
* Escribir una fila de resultados dentro del archivo temporal.
post `specification_post' ///
    ("M2_OG") ("ECI") ///
    ("RENTS_OIL_GAS, INST, interacción, VOL, RER, HUMCAP, " + ///
        "INNOV, NET, log_GDPPC, GOVCONS y FIN") ///
    ("No aplica")
* Escribir una fila de resultados dentro del archivo temporal.
post `specification_post' ///
    ("M2_OG") ("DIVX") ///
    ("RENTS_OIL_GAS, INST, interacción, VOL, RER, HUMCAP, " + ///
        "INNOV, NET, log_GDPPC, GOVCONS y FIN") ///
    ("No aplica")
* Escribir las dos ecuaciones completas preespecificadas de M3_OG.
post `specification_post' ///
    ("M3_OG") ("ECI") ///
    ("RENTS_OIL_GAS, INST, interacción y todos los canales de M3, incluido HHI") ///
    ("Incluir HHI")
post `specification_post' ///
    ("M3_OG") ("DIVX") ///
    ("RENTS_OIL_GAS, INST, interacción y todos los canales de M3, sin HHI") ///
    ("Excluir HHI: DIVX=1-HHI")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `specification_post'

preserve
    use "`specification_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 6
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome
    export delimited using ///
        "$OUTPUT_OG/og_specification_register.csv", replace datafmt
restore

display as result ///
    "Sección 15 completa: diseño y muestra RENTS_OIL_GAS validados."


// *****************************************************************************
// 16. Modelo 1 con Rentas de Petróleo y Gas
// *****************************************************************************

// 16.1. Definir el canal institucional de M1

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
assert abs(rents_oil_gas_x_inst - rents_oil_gas * inst) < 1e-10 ///
    if sample_og_common == 1


// 16.2. Incorporar abundancia y estructura exportadora

foreach variable of global OG_M1_ABUNDANCE {
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert `variable' >= 0 if sample_og_common == 1
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert !missing(`variable') if sample_og_common == 1
}
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(divx - (1 - hhi)) < 1e-10 if sample_og_common == 1


// 16.3. Estimar M1 para ECI

xtreg eci $OG_M1_ECI_REGRESSORS i.year ///
    if sample_og_common == 1, fe $OG_INFERENCE
capture estimates drop ECI_M1_OG
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_M1_OG
estimates save "$OUTPUT_OG/og_m1_eci.ster", replace

* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(sample) == sample_og_common
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_clust) == 49

local critical_t = invttail(e(df_r), 0.025)
local order = 0
foreach term of local og_m1_eci_terms {
    local ++order
    local b = _b[`term']
    local se = _se[`term']
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local lower = `b' - `critical_t' * `se'
    local upper = `b' + `critical_t' * `se'
    scalar og_m1_eci_b_`order' = `b'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `coefficient_post' ///
        ("M1_OG") ("ECI") (`order') ("`term'") ///
        (`b') (`se') (`t') (`p') (`lower') (`upper')
}
* Escribir una fila de resultados dentro del archivo temporal.
post `summary_post' ///
    ("M1_OG") ("ECI") (e(N)) (e(N_g)) (e(N_clust)) ///
    (`og_year_count') (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
    (e(F)) (e(p))

test rents_oil_gas inst c.rents_oil_gas#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_OG") ("ECI") (1) ("Institucional") ///
    ("RENTS_OIL_GAS, INST e interacción son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test ln1p_oilpc ln1p_gaspc ln1p_coalpc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_OG") ("ECI") (2) ("Abundancia") ///
    ("OILPC, GASPC y COALPC son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test hhi pexp fexp
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_OG") ("ECI") (3) ("Estructura exportadora") ///
    ("HHI, PEXP y FEXP son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test log_gdppc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_OG") ("ECI") (4) ("Nivel de desarrollo") ///
    ("log_GDPPC es igual a cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_OG") ("ECI") (5) ("Efectos de año") ///
    ("Todos los indicadores de año son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))


// 16.4. Estimar M1 para DIVX

xtreg divx $OG_M1_DIVX_REGRESSORS i.year ///
    if sample_og_common == 1, fe $OG_INFERENCE
capture estimates drop DIVX_M1_OG
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_M1_OG
estimates save "$OUTPUT_OG/og_m1_divx.ster", replace

* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(sample) == sample_og_common
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_clust) == 49

local critical_t = invttail(e(df_r), 0.025)
local order = 0
foreach term of local og_m1_divx_terms {
    local ++order
    local b = _b[`term']
    local se = _se[`term']
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local lower = `b' - `critical_t' * `se'
    local upper = `b' + `critical_t' * `se'
    scalar og_m1_divx_b_`order' = `b'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `coefficient_post' ///
        ("M1_OG") ("DIVX") (`order') ("`term'") ///
        (`b') (`se') (`t') (`p') (`lower') (`upper')
}
* Escribir una fila de resultados dentro del archivo temporal.
post `summary_post' ///
    ("M1_OG") ("DIVX") (e(N)) (e(N_g)) (e(N_clust)) ///
    (`og_year_count') (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
    (e(F)) (e(p))

test rents_oil_gas inst c.rents_oil_gas#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_OG") ("DIVX") (1) ("Institucional") ///
    ("RENTS_OIL_GAS, INST e interacción son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test ln1p_oilpc ln1p_gaspc ln1p_coalpc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_OG") ("DIVX") (2) ("Abundancia") ///
    ("OILPC, GASPC y COALPC son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test pexp fexp
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_OG") ("DIVX") (3) ("Estructura exportadora") ///
    ("PEXP y FEXP son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test log_gdppc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_OG") ("DIVX") (4) ("Nivel de desarrollo") ///
    ("log_GDPPC es igual a cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M1_OG") ("DIVX") (5) ("Efectos de año") ///
    ("Todos los indicadores de año son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))


// 16.5. Ejecutar pruebas conjuntas por canal

display as result ///
    "Pruebas conjuntas de M1_OG registradas para ECI y DIVX."


// 16.6. Calcular efectos marginales y bootstrap

* Los efectos marginales y el bootstrap se ejecutarán conjuntamente en 18.3.


// 16.7. Verificar y almacenar M1

* Restaurar una estimación previa desde la memoria de Stata.
estimates restore DIVX_M1_OG
display as result "Sección 16 completa: M1_OG estimado y almacenado."


// *****************************************************************************
// 17. Modelo 2 con Rentas de Petróleo y Gas
// *****************************************************************************

// 17.1. Definir el canal institucional de M2

* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(rents_oil_gas_x_inst - rents_oil_gas * inst) < 1e-10 ///
    if sample_og_common == 1


// 17.2. Incorporar el canal macroeconómico

* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(vol, rer) if sample_og_common == 1


// 17.3. Incorporar las capacidades productivas

* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(humcap, innov, net) if sample_og_common == 1


// 17.4. Incorporar controles económicos, fiscales y financieros

* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(log_gdppc, govcons, fin) if sample_og_common == 1


// 17.5. Estimar M2 para ECI y DIVX

xtreg eci $OG_M2_REGRESSORS i.year ///
    if sample_og_common == 1, fe $OG_INFERENCE
capture estimates drop ECI_M2_OG
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_M2_OG
estimates save "$OUTPUT_OG/og_m2_eci.ster", replace

* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(sample) == sample_og_common
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_clust) == 49

local critical_t = invttail(e(df_r), 0.025)
local order = 0
foreach term of local og_m2_terms {
    local ++order
    local b = _b[`term']
    local se = _se[`term']
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local lower = `b' - `critical_t' * `se'
    local upper = `b' + `critical_t' * `se'
    scalar og_m2_eci_b_`order' = `b'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `coefficient_post' ///
        ("M2_OG") ("ECI") (`order') ("`term'") ///
        (`b') (`se') (`t') (`p') (`lower') (`upper')
}
* Escribir una fila de resultados dentro del archivo temporal.
post `summary_post' ///
    ("M2_OG") ("ECI") (e(N)) (e(N_g)) (e(N_clust)) ///
    (`og_year_count') (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
    (e(F)) (e(p))

test rents_oil_gas inst c.rents_oil_gas#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2_OG") ("ECI") (1) ("Institucional") ///
    ("RENTS_OIL_GAS, INST e interacción son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test vol rer
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2_OG") ("ECI") (2) ("Macroeconomía") ///
    ("VOL y RER son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test humcap innov net
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2_OG") ("ECI") (3) ("Capacidades productivas") ///
    ("HUMCAP, INNOV y NET son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test log_gdppc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2_OG") ("ECI") (4) ("Nivel de desarrollo") ///
    ("log_GDPPC es igual a cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test govcons fin
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2_OG") ("ECI") (5) ("Fiscal y financiero") ///
    ("GOVCONS y FIN son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2_OG") ("ECI") (6) ("Efectos de año") ///
    ("Todos los indicadores de año son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

xtreg divx $OG_M2_REGRESSORS i.year ///
    if sample_og_common == 1, fe $OG_INFERENCE
capture estimates drop DIVX_M2_OG
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_M2_OG
estimates save "$OUTPUT_OG/og_m2_divx.ster", replace

* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(sample) == sample_og_common
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_clust) == 49

local critical_t = invttail(e(df_r), 0.025)
local order = 0
foreach term of local og_m2_terms {
    local ++order
    local b = _b[`term']
    local se = _se[`term']
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local lower = `b' - `critical_t' * `se'
    local upper = `b' + `critical_t' * `se'
    scalar og_m2_divx_b_`order' = `b'
    * Escribir una fila de resultados dentro del archivo temporal.
    post `coefficient_post' ///
        ("M2_OG") ("DIVX") (`order') ("`term'") ///
        (`b') (`se') (`t') (`p') (`lower') (`upper')
}
* Escribir una fila de resultados dentro del archivo temporal.
post `summary_post' ///
    ("M2_OG") ("DIVX") (e(N)) (e(N_g)) (e(N_clust)) ///
    (`og_year_count') (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
    (e(F)) (e(p))

test rents_oil_gas inst c.rents_oil_gas#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2_OG") ("DIVX") (1) ("Institucional") ///
    ("RENTS_OIL_GAS, INST e interacción son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test vol rer
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2_OG") ("DIVX") (2) ("Macroeconomía") ///
    ("VOL y RER son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test humcap innov net
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2_OG") ("DIVX") (3) ("Capacidades productivas") ///
    ("HUMCAP, INNOV y NET son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test log_gdppc
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2_OG") ("DIVX") (4) ("Nivel de desarrollo") ///
    ("log_GDPPC es igual a cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
test govcons fin
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2_OG") ("DIVX") (5) ("Fiscal y financiero") ///
    ("GOVCONS y FIN son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `joint_post' ///
    ("M2_OG") ("DIVX") (6) ("Efectos de año") ///
    ("Todos los indicadores de año son cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))


// 17.6. Ejecutar pruebas conjuntas por canal

* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `coefficient_post'
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `summary_post'
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `joint_post'

preserve
    use "`coefficient_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 41
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort model outcome order
    format coefficient standard_error t_statistic p_value ///
        ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_OG/og_coefficients.csv", replace datafmt
restore

preserve
    use "`summary_report'", clear
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
        "$OUTPUT_OG/og_model_summary.csv", replace datafmt
restore

preserve
    use "`joint_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 22
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort model outcome order
    format f_statistic p_value %12.6f
    export delimited using ///
        "$OUTPUT_OG/og_joint_tests.csv", replace datafmt
restore


// 17.7. Calcular efectos marginales y bootstrap

* Los cuatro modelos se evaluarán conjuntamente en la subsección 18.3.


// 17.8. Verificar y almacenar M2

* Restaurar una estimación previa desde la memoria de Stata.
estimates restore DIVX_M2_OG
display as result "Sección 17 completa: M2_OG estimado y almacenado."


// *****************************************************************************
// 18. Modelo 3 Completo con Rentas de Petróleo y Gas
// *****************************************************************************

// 18.1. Estimar las ecuaciones completas de ECI y DIVX

tempname og_m3_coefficient_post og_m3_summary_post ///
    og_m3_joint_post og_m3_verification_post og_m3_manifest_post
tempfile og_m3_coefficient_report og_m3_summary_report ///
    og_m3_joint_report og_m3_verification_report og_m3_manifest_report

postfile `og_m3_coefficient_post' ///
    str8 model str8 outcome int order str32 term ///
    double coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper using "`og_m3_coefficient_report'", replace
postfile `og_m3_summary_post' ///
    str8 model str8 outcome long observations int countries clusters ///
    effective_years double r2_within r2_between r2_overall ///
    f_statistic model_p_value using "`og_m3_summary_report'", replace
postfile `og_m3_joint_post' ///
    str8 model str8 outcome int order str32 channel ///
    str120 null_hypothesis double f_statistic df1 df2 p_value ///
    using "`og_m3_joint_report'", replace

forvalues index = 1/2 {
    if `index' == 1 {
        local dependent eci
        local outcome ECI
        local regressors "$OG_M3_ECI_REGRESSORS"
        local current_terms "`og_m3_eci_terms'"
        local stored_estimate ECI_M3_OG
        local ster_file og_m3_eci.ster
        local scalar_prefix og_m3_eci_b
        local structure_terms hhi pexp fexp
        local structure_null "HHI, PEXP y FEXP son conjuntamente cero"
    }
    else {
        local dependent divx
        local outcome DIVX
        local regressors "$OG_M3_DIVX_REGRESSORS"
        local current_terms "`og_m3_divx_terms'"
        local stored_estimate DIVX_M3_OG
        local ster_file og_m3_divx.ster
        local scalar_prefix og_m3_divx_b
        local structure_terms pexp fexp
        local structure_null "PEXP y FEXP son conjuntamente cero"
    }

    xtreg `dependent' `regressors' i.year ///
        if sample_og_common == 1, fe $OG_INFERENCE
    capture estimates drop `stored_estimate'
    estimates store `stored_estimate'
    estimates save "$OUTPUT_OG_M3/`ster_file'", replace

    assert e(sample) == sample_og_common
    assert e(N) == 1044
    assert e(N_g) == 49
    assert e(N_clust) == 49
    assert e(df_r) == e(N_clust) - 1

    local critical_t = invttail(e(df_r), 0.025)
    local order = 0
    foreach term of local current_terms {
        local ++order
        local b = _b[`term']
        local se = _se[`term']
        local t = `b' / `se'
        local p = 2 * ttail(e(df_r), abs(`t'))
        local lower = `b' - `critical_t' * `se'
        local upper = `b' + `critical_t' * `se'
        scalar `scalar_prefix'_`order' = `b'
        post `og_m3_coefficient_post' ///
            ("M3_OG") ("`outcome'") (`order') ("`term'") ///
            (`b') (`se') (`t') (`p') (`lower') (`upper')
    }

    post `og_m3_summary_post' ///
        ("M3_OG") ("`outcome'") (e(N)) (e(N_g)) (e(N_clust)) ///
        (`og_year_count') (e(r2_w)) (e(r2_b)) (e(r2_o)) ///
        (e(F)) (e(p))

    test rents_oil_gas inst c.rents_oil_gas#c.inst
    post `og_m3_joint_post' ///
        ("M3_OG") ("`outcome'") (1) ("Institucional") ///
        ("RENTS_OIL_GAS, INST e interacción son cero") ///
        (r(F)) (r(df)) (r(df_r)) (r(p))
    test ln1p_oilpc ln1p_gaspc ln1p_coalpc
    post `og_m3_joint_post' ///
        ("M3_OG") ("`outcome'") (2) ("Abundancia") ///
        ("OILPC, GASPC y COALPC son conjuntamente cero") ///
        (r(F)) (r(df)) (r(df_r)) (r(p))
    test `structure_terms'
    post `og_m3_joint_post' ///
        ("M3_OG") ("`outcome'") (3) ("Estructura exportadora") ///
        ("`structure_null'") ///
        (r(F)) (r(df)) (r(df_r)) (r(p))
    test vol rer
    post `og_m3_joint_post' ///
        ("M3_OG") ("`outcome'") (4) ("Macroeconomía") ///
        ("VOL y RER son conjuntamente cero") ///
        (r(F)) (r(df)) (r(df_r)) (r(p))
    test humcap innov net
    post `og_m3_joint_post' ///
        ("M3_OG") ("`outcome'") (5) ("Capacidades productivas") ///
        ("HUMCAP, INNOV y NET son conjuntamente cero") ///
        (r(F)) (r(df)) (r(df_r)) (r(p))
    test log_gdppc govcons fin
    post `og_m3_joint_post' ///
        ("M3_OG") ("`outcome'") (6) ("Controles económicos") ///
        ("log_GDPPC, GOVCONS y FIN son conjuntamente cero") ///
        (r(F)) (r(df)) (r(df_r)) (r(p))
}

postclose `og_m3_coefficient_post'
postclose `og_m3_summary_post'
postclose `og_m3_joint_post'

preserve
    use "`og_m3_coefficient_report'", clear
    assert _N == 33
    isid model outcome order
    sort outcome order
    format coefficient standard_error t_statistic p_value ///
        ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_OG_M3/og_m3_coefficients.csv", replace datafmt
restore

preserve
    use "`og_m3_summary_report'", clear
    assert _N == 2
    isid model outcome
    assert observations == 1044
    assert countries == 49
    assert clusters == 49
    sort outcome
    export delimited using ///
        "$OUTPUT_OG_M3/og_m3_model_summary.csv", replace datafmt
restore

preserve
    use "`og_m3_joint_report'", clear
    assert _N == 12
    isid model outcome order
    sort outcome order
    format f_statistic p_value %12.6f
    export delimited using ///
        "$OUTPUT_OG_M3/og_m3_joint_tests.csv", replace datafmt
restore


// 18.2. Verificar equivalencia entre xtreg y reghdfe

postfile `og_m3_verification_post' ///
    str8 model str8 outcome int order str32 term ///
    double xtreg_coefficient reghdfe_coefficient ///
    absolute_difference byte coefficient_match ///
    using "`og_m3_verification_report'", replace

local coefficient_tolerance = 1e-8
forvalues index = 1/2 {
    if `index' == 1 {
        local dependent eci
        local outcome ECI
        local regressors "$OG_M3_ECI_REGRESSORS"
        local current_terms "`og_m3_eci_terms'"
        local scalar_prefix og_m3_eci_b
    }
    else {
        local dependent divx
        local outcome DIVX
        local regressors "$OG_M3_DIVX_REGRESSORS"
        local current_terms "`og_m3_divx_terms'"
        local scalar_prefix og_m3_divx_b
    }

    reghdfe `dependent' `regressors' ///
        if sample_og_common == 1, ///
        absorb(country_id year) $OG_INFERENCE
    assert e(N) == 1044

    local order = 0
    foreach term of local current_terms {
        local ++order
        local xtreg_b = scalar(`scalar_prefix'_`order')
        local hdfe_b = _b[`term']
        local difference = abs(`xtreg_b' - `hdfe_b')
        local match = `difference' < `coefficient_tolerance'
        assert `match' == 1
        post `og_m3_verification_post' ///
            ("M3_OG") ("`outcome'") (`order') ("`term'") ///
            (`xtreg_b') (`hdfe_b') (`difference') (`match')
    }
}
postclose `og_m3_verification_post'

preserve
    use "`og_m3_verification_report'", clear
    assert _N == 33
    assert coefficient_match == 1
    isid model outcome order
    sort outcome order
    format xtreg_coefficient reghdfe_coefficient ///
        absolute_difference %16.10f
    export delimited using ///
        "$OUTPUT_OG_M3/og_m3_xtreg_reghdfe_verification.csv", ///
        replace datafmt
restore


// 18.3. Exportar la tabla completa y el manifiesto de M3_OG

esttab ECI_M3_OG DIVX_M3_OG ///
    using "$OUTPUT_OG_M3/og_m3_results_table.tex", ///
    replace booktabs label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(`og_m3_eci_terms') order(`og_m3_eci_terms') ///
    coeflabels( ///
        rents_oil_gas "RENTS_OIL_GAS" ///
        inst "INST" ///
        c.rents_oil_gas#c.inst "RENTS_OIL_GAS x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        hhi "HHI" pexp "PEXP" fexp "FEXP" ///
        vol "VOL" rer "RER" humcap "HUMCAP" ///
        innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" govcons "GOVCONS" fin "FIN") ///
    mtitles("ECI" "DIVX") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))

esttab ECI_M3_OG DIVX_M3_OG ///
    using "$OUTPUT_OG_M3/og_m3_results_table.txt", ///
    replace label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(`og_m3_eci_terms') order(`og_m3_eci_terms') ///
    coeflabels( ///
        rents_oil_gas "RENTS_OIL_GAS" ///
        inst "INST" ///
        c.rents_oil_gas#c.inst "RENTS_OIL_GAS x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        hhi "HHI" pexp "PEXP" fexp "FEXP" ///
        vol "VOL" rer "RER" humcap "HUMCAP" ///
        innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" govcons "GOVCONS" fin "FIN") ///
    mtitles("ECI" "DIVX") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))

postfile `og_m3_manifest_post' ///
    int order str28 family str80 file str140 purpose ///
    using "`og_m3_manifest_report'", replace
post `og_m3_manifest_post' ///
    (1) ("Estimación") ("og_m3_eci.ster") ("M3_OG para ECI.")
post `og_m3_manifest_post' ///
    (2) ("Estimación") ("og_m3_divx.ster") ("M3_OG para DIVX.")
post `og_m3_manifest_post' ///
    (3) ("Resultados") ("og_m3_coefficients.csv") ///
    ("Coeficientes e incertidumbre de las dos ecuaciones completas.")
post `og_m3_manifest_post' ///
    (4) ("Resultados") ("og_m3_model_summary.csv") ///
    ("Cobertura y ajuste de M3_OG.")
post `og_m3_manifest_post' ///
    (5) ("Inferencia") ("og_m3_joint_tests.csv") ///
    ("Pruebas conjuntas de los seis bloques teóricos.")
post `og_m3_manifest_post' ///
    (6) ("Verificación") ("og_m3_xtreg_reghdfe_verification.csv") ///
    ("Equivalencia numérica entre xtreg y reghdfe.")
post `og_m3_manifest_post' ///
    (7) ("Tabla") ("og_m3_results_table.tex") ///
    ("Tabla LaTeX completa de M3_OG.")
post `og_m3_manifest_post' ///
    (8) ("Tabla") ("og_m3_results_table.txt") ///
    ("Tabla de texto completa de M3_OG.")
post `og_m3_manifest_post' ///
    (9) ("Documentación") ("og_m3_results_manifest.csv") ///
    ("Inventario reproducible de M3_OG.")
postclose `og_m3_manifest_post'

preserve
    use "`og_m3_manifest_report'", clear
    assert _N == 9
    isid order
    export delimited using ///
        "$OUTPUT_OG_M3/og_m3_results_manifest.csv", replace datafmt
restore

display as result ///
    "Sección 18 completa: M3_OG estimado, verificado y exportado."


// *****************************************************************************
// 19. Comparación y Exportación de los Modelos con RENTS_OIL_GAS
// *****************************************************************************

// 19.1. Comparar los coeficientes focales de M1 y M2

global AGG_M1_ECI_REGRESSORS ///
    c.rents##c.inst ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp log_gdppc
global AGG_M1_DIVX_REGRESSORS ///
    c.rents##c.inst ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp log_gdppc
global AGG_M2_REGRESSORS ///
    c.rents##c.inst vol rer humcap innov net ///
    log_gdppc govcons fin

tempname comparison_post
tempfile comparison_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `comparison_post' ///
    str4 model_family str8 outcome str18 specification ///
    int order str24 concept str32 term double coefficient ///
    standard_error p_value using "`comparison_report'", replace

local og_estimates ///
    ECI_M1_OG DIVX_M1_OG ECI_M2_OG DIVX_M2_OG
local model_families M1 M1 M2 M2
local outcomes ECI DIVX ECI DIVX

forvalues index = 1/4 {
    local og_estimate : word `index' of `og_estimates'
    local model_family : word `index' of `model_families'
    local outcome : word `index' of `outcomes'

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
        if sample_og_common == 1, fe $OG_INFERENCE
    * Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
    assert e(N) == 1044

    local aggregate_terms ///
        rents inst c.rents#c.inst
    local concepts ///
        RENTS INST RENTS_x_INST
    local order = 0
    foreach term of local aggregate_terms {
        local ++order
        local concept : word `order' of `concepts'
        local p = 2 * ttail(e(df_r), abs(_b[`term'] / _se[`term']))
        * Escribir una fila de resultados dentro del archivo temporal.
        post `comparison_post' ///
            ("`model_family'") ("`outcome'") ("RENTS total") ///
            (`order') ("`concept'") ("`term'") ///
            (_b[`term']) (_se[`term']) (`p')
    }

    * Restaurar una estimación previa desde la memoria de Stata.
    estimates restore `og_estimate'
    local oil_gas_terms ///
        rents_oil_gas inst c.rents_oil_gas#c.inst
    local order = 0
    foreach term of local oil_gas_terms {
        local ++order
        local concept : word `order' of `concepts'
        local p = 2 * ttail(e(df_r), abs(_b[`term'] / _se[`term']))
        * Escribir una fila de resultados dentro del archivo temporal.
        post `comparison_post' ///
            ("`model_family'") ("`outcome'") ("RENTS_OIL_GAS") ///
            (`order') ("`concept'") ("`term'") ///
            (_b[`term']) (_se[`term']) (`p')
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `comparison_post'

preserve
    use "`comparison_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 24
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model_family outcome specification order
    sort model_family outcome order specification
    format coefficient standard_error p_value %12.6f
    export delimited using ///
        "$OUTPUT_OG/og_aggregate_comparison.csv", replace datafmt
restore


// 19.2. Contrastar con los modelos equivalentes de RENTS totales

display as result ///
    "Comparación RENTS total y RENTS_OIL_GAS completada en la misma muestra."


// 19.3. Resumir pruebas conjuntas y efectos marginales

quietly summarize inst if sample_og_common == 1, detail
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

local graph_names og_m1_eci og_m1_divx og_m2_eci og_m2_divx
forvalues index = 1/4 {
    local estimate_name : word `index' of `og_estimates'
    local model_family : word `index' of `model_families'
    local outcome : word `index' of `outcomes'
    local model_label "`model_family'_OG"

    * Restaurar una estimación previa desde la memoria de Stata.
    estimates restore `estimate_name'
    margins, dydx(rents_oil_gas) at(inst=(`inst_values'))
    matrix current_margins = r(table)

    forvalues column = 1/5 {
        local inst_value : word `column' of `inst_values'
        local percentile : word `column' of `inst_labels'
        * Escribir una fila de resultados dentro del archivo temporal.
        post `margins_post' ///
            ("`model_label'") ("`outcome'") ///
            (`column') ("`percentile'") (`inst_value') ///
            (el(current_margins, 1, `column')) ///
            (el(current_margins, 2, `column')) ///
            (el(current_margins, 4, `column')) ///
            (el(current_margins, 5, `column')) ///
            (el(current_margins, 6, `column'))
    }

    local graph_name : word `index' of `graph_names'
    marginsplot, ///
        recast(line) recastci(rarea) ///
        yline(0, lpattern(dash) lcolor(gs8)) ///
        xlabel( ///
            `inst_p10' "P10" ///
            `inst_p25' "P25" ///
            `inst_p50' "P50" ///
            `inst_p75' "P75" ///
            `inst_p90' "P90", labsize(small)) ///
        title("`model_family' - `outcome'", size(medsmall)) ///
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
    assert _N == 20
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome order
    sort model outcome order
    format inst_value marginal_effect standard_error ///
        p_value ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_OG/og_marginal_effects.csv", replace datafmt
restore

graph combine og_m1_eci og_m1_divx og_m2_eci og_m2_divx, ///
    cols(2) graphregion(color(white)) ///
    title( ///
        "Asociación marginal de rentas de petróleo y gas según INST", ///
        size(medsmall)) ///
    note( ///
        "Modelos 1 y 2; asociaciones condicionales con IC del 95 %", ///
        size(vsmall)) ///
    name(og_margins_combined, replace)
graph export "$OUTPUT_OG/og_marginal_effects.png", ///
    width(3000) replace

tempname bootstrap_post
tempfile bootstrap_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `bootstrap_post' ///
    str8 model str8 outcome str28 term ///
    double coefficient conventional_p bootstrap_p ///
    ci_lower ci_upper repetitions str12 weight_type ///
    using "`bootstrap_report'", replace

forvalues index = 1/4 {
    local estimate_name : word `index' of `og_estimates'
    local model_family : word `index' of `model_families'
    local outcome : word `index' of `outcomes'
    local model_label "`model_family'_OG"
    local seed_level = 20260810 + (2 * `index') - 1
    local seed_interaction = 20260810 + (2 * `index')

    * Restaurar una estimación previa desde la memoria de Stata.
    estimates restore `estimate_name'
    local level_p = 2 * ttail(e(df_r), ///
        abs(_b[rents_oil_gas] / _se[rents_oil_gas]))
    local interaction_p = 2 * ttail(e(df_r), ///
        abs(_b[c.rents_oil_gas#c.inst] / ///
        _se[c.rents_oil_gas#c.inst]))

    boottest rents_oil_gas, cluster(country_id) reps(9999) ///
        seed(`seed_level') nograph
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert !missing(r(p))
    matrix level_ci = r(CI)
    * Escribir una fila de resultados dentro del archivo temporal.
    post `bootstrap_post' ///
        ("`model_label'") ("`outcome'") ("RENTS_OIL_GAS") ///
        (_b[rents_oil_gas]) (`level_p') (r(p)) ///
        (el(level_ci, 1, 1)) (el(level_ci, 1, 2)) ///
        (r(reps)) ("`r(weighttype)'")

    boottest c.rents_oil_gas#c.inst, ///
        cluster(country_id) reps(9999) ///
        seed(`seed_interaction') nograph
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert !missing(r(p))
    matrix interaction_ci = r(CI)
    * Escribir una fila de resultados dentro del archivo temporal.
    post `bootstrap_post' ///
        ("`model_label'") ("`outcome'") ///
        ("RENTS_OIL_GAS x INST") ///
        (_b[c.rents_oil_gas#c.inst]) (`interaction_p') (r(p)) ///
        (el(interaction_ci, 1, 1)) ///
        (el(interaction_ci, 1, 2)) ///
        (r(reps)) ("`r(weighttype)'")
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `bootstrap_post'

preserve
    use "`bootstrap_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 8
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid model outcome term
    sort model outcome term
    format coefficient conventional_p bootstrap_p ///
        ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_OG/og_wild_cluster_bootstrap.csv", replace datafmt
restore

display as result ///
    "Efectos marginales y wild cluster bootstrap completados."


// 19.4. Crear las tablas comparativas

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab ECI_M1_OG DIVX_M1_OG ///
    using "$OUTPUT_OG/og_m1_results_table.tex", ///
    replace booktabs label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents_oil_gas inst c.rents_oil_gas#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp log_gdppc) ///
    order( ///
        rents_oil_gas inst c.rents_oil_gas#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp log_gdppc) ///
    coeflabels( ///
        rents_oil_gas "RENTS_OIL_GAS" ///
        inst "INST" ///
        c.rents_oil_gas#c.inst "RENTS_OIL_GAS x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        hhi "HHI" pexp "PEXP" fexp "FEXP" ///
        log_gdppc "log(GDPPC)") ///
    mtitles("ECI" "DIVX") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab ECI_M1_OG DIVX_M1_OG ///
    using "$OUTPUT_OG/og_m1_results_table.txt", ///
    replace label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents_oil_gas inst c.rents_oil_gas#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp log_gdppc) ///
    order( ///
        rents_oil_gas inst c.rents_oil_gas#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp log_gdppc) ///
    coeflabels( ///
        rents_oil_gas "RENTS_OIL_GAS" ///
        inst "INST" ///
        c.rents_oil_gas#c.inst "RENTS_OIL_GAS x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        hhi "HHI" pexp "PEXP" fexp "FEXP" ///
        log_gdppc "log(GDPPC)") ///
    mtitles("ECI" "DIVX") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab ECI_M2_OG DIVX_M2_OG ///
    using "$OUTPUT_OG/og_m2_results_table.tex", ///
    replace booktabs label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents_oil_gas inst c.rents_oil_gas#c.inst ///
        vol rer humcap innov net log_gdppc govcons fin) ///
    order( ///
        rents_oil_gas inst c.rents_oil_gas#c.inst ///
        vol rer humcap innov net log_gdppc govcons fin) ///
    coeflabels( ///
        rents_oil_gas "RENTS_OIL_GAS" ///
        inst "INST" ///
        c.rents_oil_gas#c.inst "RENTS_OIL_GAS x INST" ///
        vol "VOL" rer "RER" humcap "HUMCAP" ///
        innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" govcons "GOVCONS" fin "FIN") ///
    mtitles("ECI" "DIVX") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))

* Exportar los coeficientes y estadísticas del modelo a tablas de LaTeX.
esttab ECI_M2_OG DIVX_M2_OG ///
    using "$OUTPUT_OG/og_m2_results_table.txt", ///
    replace label se nonotes noomitted nobaselevels ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    keep( ///
        rents_oil_gas inst c.rents_oil_gas#c.inst ///
        vol rer humcap innov net log_gdppc govcons fin) ///
    order( ///
        rents_oil_gas inst c.rents_oil_gas#c.inst ///
        vol rer humcap innov net log_gdppc govcons fin) ///
    coeflabels( ///
        rents_oil_gas "RENTS_OIL_GAS" ///
        inst "INST" ///
        c.rents_oil_gas#c.inst "RENTS_OIL_GAS x INST" ///
        vol "VOL" rer "RER" humcap "HUMCAP" ///
        innov "INNOV" net "NET" ///
        log_gdppc "log(GDPPC)" govcons "GOVCONS" fin "FIN") ///
    mtitles("ECI" "DIVX") ///
    stats(N N_g r2_w, fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within"))


// 19.5. Exportar las salidas en una carpeta plana

tempname verification_post
tempfile verification_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `verification_post' ///
    str8 model str8 outcome int order str32 term ///
    double xtreg_coefficient reghdfe_coefficient ///
    absolute_difference byte coefficient_match ///
    using "`verification_report'", replace

local coefficient_tolerance = 1e-8
forvalues index = 1/4 {
    local model_family : word `index' of `model_families'
    local outcome : word `index' of `outcomes'
    local model_label "`model_family'_OG"

    if `index' == 1 {
        local dependent eci
        local regressors "$OG_M1_ECI_REGRESSORS"
        local current_terms "`og_m1_eci_terms'"
        local scalar_prefix "og_m1_eci_b"
    }
    else if `index' == 2 {
        local dependent divx
        local regressors "$OG_M1_DIVX_REGRESSORS"
        local current_terms "`og_m1_divx_terms'"
        local scalar_prefix "og_m1_divx_b"
    }
    else if `index' == 3 {
        local dependent eci
        local regressors "$OG_M2_REGRESSORS"
        local current_terms "`og_m2_terms'"
        local scalar_prefix "og_m2_eci_b"
    }
    else {
        local dependent divx
        local regressors "$OG_M2_REGRESSORS"
        local current_terms "`og_m2_terms'"
        local scalar_prefix "og_m2_divx_b"
    }

    * Estimar el modelo de regresión con efectos fijos de país y año y errores agrupados.
    reghdfe `dependent' `regressors' ///
        if sample_og_common == 1, ///
        absorb(country_id year) $OG_INFERENCE
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
            ("`model_label'") ("`outcome'") ///
            (`order') ("`term'") ///
            (`xtreg_b') (`hdfe_b') (`difference') (`match')
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `verification_post'

preserve
    use "`verification_report'", clear
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
        "$OUTPUT_OG/og_xtreg_reghdfe_verification.csv", ///
        replace datafmt
restore


// 19.6. Validar el paquete y cerrar el archivo

tempname manifest_post
tempfile manifest_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `manifest_post' ///
    int order str28 family str80 file str140 purpose ///
    using "`manifest_report'", replace
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (1) ("Diseño") ("og_design_register.csv") ///
    ("Pregunta y función de las seis ecuaciones.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (2) ("Muestra") ("og_sample_validation.csv") ///
    ("Validación de 1.044 observaciones y 49 países.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (3) ("Diseño") ("og_specification_register.csv") ///
    ("Regresores y regla de HHI por ecuación.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (4) ("Estimación") ("og_m1_eci.ster") ///
    ("Estimación M1_OG para ECI.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (5) ("Estimación") ("og_m1_divx.ster") ///
    ("Estimación M1_OG para DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (6) ("Estimación") ("og_m2_eci.ster") ///
    ("Estimación M2_OG para ECI.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (7) ("Estimación") ("og_m2_divx.ster") ///
    ("Estimación M2_OG para DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (8) ("Resultados") ("og_coefficients.csv") ///
    ("Coeficientes e incertidumbre de las cuatro ecuaciones.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (9) ("Resultados") ("og_model_summary.csv") ///
    ("Cobertura y ajuste within de M1_OG y M2_OG.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (10) ("Inferencia") ("og_joint_tests.csv") ///
    ("Pruebas conjuntas por canal.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (11) ("Comparación") ("og_aggregate_comparison.csv") ///
    ("Comparación focal con RENTS total en la misma muestra.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (12) ("Interpretación") ("og_marginal_effects.csv") ///
    ("Efectos marginales según percentiles de INST.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (13) ("Inferencia") ("og_wild_cluster_bootstrap.csv") ///
    ("Bootstrap para RENTS_OIL_GAS y su interacción.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (14) ("Verificación") ("og_xtreg_reghdfe_verification.csv") ///
    ("Equivalencia numérica entre xtreg y reghdfe.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (15) ("Tabla") ("og_m1_results_table.tex") ///
    ("Tabla LaTeX del Modelo 1.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (16) ("Tabla") ("og_m1_results_table.txt") ///
    ("Tabla de texto del Modelo 1.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (17) ("Tabla") ("og_m2_results_table.tex") ///
    ("Tabla LaTeX del Modelo 2.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (18) ("Tabla") ("og_m2_results_table.txt") ///
    ("Tabla de texto del Modelo 2.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (19) ("Figura") ("og_marginal_effects.png") ///
    ("Figura comparada para revisión visual.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (20) ("Documentación") ("og_results_manifest.csv") ///
    ("Inventario reproducible de productos.")
post `manifest_post' ///
    (21) ("Estimación") ("03_m3_full/og_m3_eci.ster") ///
    ("Estimación M3_OG para ECI.")
post `manifest_post' ///
    (22) ("Estimación") ("03_m3_full/og_m3_divx.ster") ///
    ("Estimación M3_OG para DIVX.")
post `manifest_post' ///
    (23) ("Resultados") ("03_m3_full/og_m3_coefficients.csv") ///
    ("Coeficientes completos de M3_OG.")
post `manifest_post' ///
    (24) ("Resultados") ("03_m3_full/og_m3_model_summary.csv") ///
    ("Cobertura y ajuste de M3_OG.")
post `manifest_post' ///
    (25) ("Inferencia") ("03_m3_full/og_m3_joint_tests.csv") ///
    ("Pruebas conjuntas de M3_OG.")
post `manifest_post' ///
    (26) ("Verificación") ///
    ("03_m3_full/og_m3_xtreg_reghdfe_verification.csv") ///
    ("Equivalencia xtreg-reghdfe de M3_OG.")
post `manifest_post' ///
    (27) ("Tabla") ("03_m3_full/og_m3_results_table.tex") ///
    ("Tabla LaTeX completa de M3_OG.")
post `manifest_post' ///
    (28) ("Tabla") ("03_m3_full/og_m3_results_table.txt") ///
    ("Tabla de texto completa de M3_OG.")
post `manifest_post' ///
    (29) ("Documentación") ///
    ("03_m3_full/og_m3_results_manifest.csv") ///
    ("Inventario específico de M3_OG.")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `manifest_post'

preserve
    use "`manifest_report'", clear
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 29
    * Comprobar que la combinación de identificadores de país y año sea única.
    isid order
    export delimited using ///
        "$OUTPUT_OG/og_results_manifest.csv", replace datafmt
restore

local required_files ///
    og_design_register.csv ///
    og_sample_validation.csv ///
    og_specification_register.csv ///
    og_m1_eci.ster ///
    og_m1_divx.ster ///
    og_m2_eci.ster ///
    og_m2_divx.ster ///
    og_coefficients.csv ///
    og_model_summary.csv ///
    og_joint_tests.csv ///
    og_aggregate_comparison.csv ///
    og_marginal_effects.csv ///
    og_wild_cluster_bootstrap.csv ///
    og_xtreg_reghdfe_verification.csv ///
    og_m1_results_table.tex ///
    og_m1_results_table.txt ///
    og_m2_results_table.tex ///
    og_m2_results_table.txt ///
    og_marginal_effects.png ///
    03_m3_full/og_m3_eci.ster ///
    03_m3_full/og_m3_divx.ster ///
    03_m3_full/og_m3_coefficients.csv ///
    03_m3_full/og_m3_model_summary.csv ///
    03_m3_full/og_m3_joint_tests.csv ///
    03_m3_full/og_m3_xtreg_reghdfe_verification.csv ///
    03_m3_full/og_m3_results_table.tex ///
    03_m3_full/og_m3_results_table.txt ///
    03_m3_full/og_m3_results_manifest.csv ///
    og_results_manifest.csv

foreach required_file of local required_files {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "$OUTPUT_OG/`required_file'"
    if _rc {
        display as error "Falta el producto: `required_file'"
        exit 603
    }
}

* Restaurar una estimación previa desde la memoria de Stata.
estimates restore DIVX_M3_OG
display as result ///
    "Archivo 06 finalizado: secciones 15 a 19 sin errores."
display as text ///
    "Resultados asociativos; no constituyen efectos causales."
log close og_log


// *****************************************************************************
// FIN DEL ARCHIVO 06.
// *****************************************************************************

* La ejecución termina después de validar todos los productos declarados.
