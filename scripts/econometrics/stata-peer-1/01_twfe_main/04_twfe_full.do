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
// Archivo: 04_twfe_full.do (Versión Peer-1)
// Contenido: Modelo 3 (M3) — Especificación TWFE completa integrando todos los canales
// Ubicación: scripts/econometrics/stata-peer-1/01_twfe_main/
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************


// *****************************************************************************
// 1. Inicialización del Entorno y Rutas de Trabajo
// *****************************************************************************

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

* Configurar parámetros generales de ejecución, semillas y precisión numérica.
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

* Desactivar pop-ups gráficos automáticos en la interfaz de Stata.
set graphics off

* Verificar e instalar dependencias de inferencia si no están presentes.
foreach pkg in boottest ftools reghdfe estout {
    capture which `pkg'
    if _rc {
        capture ssc install `pkg'
    }
}

* Localizar la raíz del proyecto con ruta relativa e infalible.
local rel_path "data/processed/00_master_panel/master_panel_country_year.dta"
capture confirm file "`rel_path'"
if !_rc {
    // Stata ya se encuentra en la raíz del proyecto
}
else {
    capture confirm file "../../../`rel_path'"
    if !_rc {
        quietly cd "../../.."
    }
    else {
        capture confirm file "../../`rel_path'"
        if !_rc {
            quietly cd "../.."
        }
        else {
            capture confirm file "../`rel_path'"
            if !_rc {
                quietly cd ".."
            }
            else {
                quietly cd "C:/Users/julla/GitHub/master-thesis-project-applied-econ"
            }
        }
    }
}

* Definir variables globales para las rutas del repositorio en Peer-1.
global PROJECT_ROOT "`c(pwd)'"
global OUTPUT_ROOT              "$PROJECT_ROOT/outputs/econometrics/stata-peer-1/01_twfe_main"
global OUTPUT_SAMPLE            "$OUTPUT_ROOT/01_sample"
global OUTPUT_DIAGNOSTICS       "$OUTPUT_ROOT/02_diagnostics"
global OUTPUT_ECI               "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX              "$OUTPUT_ROOT/04_divx"
global OUTPUT_STABILITY         "$OUTPUT_ROOT/05_stability"
global OUTPUT_RESOURCE_DISAGG   "$OUTPUT_ROOT/06_resource_disaggregation"
global OUTPUT_FINAL             "$OUTPUT_ROOT/07_final"
global OUTPUT_LOGS              "$OUTPUT_ROOT/logs"

* Crear los directorios de salida utilizando shell mkdir para compatibilidad en Windows.
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\02_diagnostics"
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\03_eci"
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\04_divx"
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\05_stability"
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\07_final"
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\logs"

* Abrir el registro de ejecución del Modelo 3 Completo.
log using "$OUTPUT_LOGS/04_twfe_full.log", text replace name(full_model_log)

* Confirmar la presencia de la base de estimación congelada.
capture confirm file "$OUTPUT_SAMPLE/master_panel_sample.dta"
if _rc {
    display as error "Error: No se encontró $OUTPUT_SAMPLE/master_panel_sample.dta"
    exit 601
}


// *****************************************************************************
// 1.1. Diagnóstico de Raíz Unitaria y Estacionariedad en Panel
// *****************************************************************************

* Cargar la base de estimación congelada y declarar la estructura de panel.
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

* Definir la lista completa de todas las variables del modelo a evaluar en niveles y en primeras diferencias.
local pur_vars eci divx rents inst rents_x_inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin

tempname pur_post
tempfile pur_report
postfile `pur_post' str24 variable str16 specification str16 test_name double statistic double p_value str24 conclusion using "`pur_report'", replace

foreach var of local pur_vars {
    // --- 1. EVALUACIÓN EN NIVELES (H0: Raíz Unitaria / No Estacionario) ---
    capture xtunitroot fisher `var' if !missing(`var'), dfuller lags(1) demean
    if _rc == 0 {
        local stat = r(P)
        local pval = r(p_P)
        local conc = "No estacionario I(1)"
        if `pval' < 0.05 local conc = "Estacionario I(0)"
        post `pur_post' ("`var'") ("Nivel") ("Fisher-ADF (P)") (`stat') (`pval') ("`conc'")
    }
    else {
        post `pur_post' ("`var'") ("Nivel") ("Fisher-ADF (P)") (.) (.) ("No calculado / Faltantes")
    }

    // --- 2. EVALUACIÓN EN PRIMERAS DIFERENCIAS (H0: Raíz Unitaria / No Estacionario) ---
    capture xtunitroot fisher d.`var' if !missing(`var'), dfuller lags(1) demean
    if _rc == 0 {
        local stat = r(P)
        local pval = r(p_P)
        local conc = "No estacionario I(2)+"
        if `pval' < 0.05 local conc = "Estacionario I(1)"
        post `pur_post' ("`var'") ("Primera Dif.") ("Fisher-ADF (P)") (`stat') (`pval') ("`conc'")
    }
    else {
        post `pur_post' ("`var'") ("Primera Dif.") ("Fisher-ADF (P)") (.) (.) ("No calculado / Faltantes")
    }
}
postclose `pur_post'

preserve
    use "`pur_report'", clear
    format statistic %12.4f
    format p_value %10.4f
    export delimited using "$OUTPUT_DIAGNOSTICS/panel_unit_root_tests.csv", replace
    display as result "----------------------------------------------------------------------"
    display as result "Sección 1.1: Pruebas de Raíz Unitaria en Panel (Levin-Lin-Chu e Im-Pesaran-Shin)"
    display as result "----------------------------------------------------------------------"
    list variable specification test_name statistic p_value conclusion, sepby(variable) noobs abbreviate(24)
restore


// *****************************************************************************
// 1.2. Pruebas de Cointegración en Panel (Pedroni, Kao, Westerlund)
// *****************************************************************************

* Cargar la base de estimación congelada y declarar la estructura de panel.
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

* Definir vectores clave del sistema econométrico para evaluar cointegración de largo plazo.
local eci_coint_vars rents inst log_gdppc humcap fin
local divx_coint_vars rents inst log_gdppc humcap fin

tempname coint_post
tempfile coint_report
postfile `coint_post' str12 model str16 test_name str24 statistic_name double statistic double p_value str36 conclusion using "`coint_report'", replace

// --- A. EVALUACIÓN DE COINTEGRACIÓN PARA MODELO ECI ---
// 1. Pruebas de Pedroni (xtcointtest pedroni)
capture xtcointtest pedroni eci `eci_coint_vars' if !missing(eci, rents, inst, log_gdppc, humcap, fin), demean
if _rc == 0 {
    matrix st = r(stat)
    matrix pv = r(p)
    local stat = st[1, 1]
    local pval = pv[1, 1]
    local conc = "No Cointegrado"
    if `pval' < 0.05 local conc = "Existe Cointegracion de Largo Plazo"
    post `coint_post' ("ECI") ("Pedroni") ("Modified PP t") (`stat') (`pval') ("`conc'")
    
    local stat_adf = st[3, 1]
    local pval_adf = pv[3, 1]
    local conc_adf = "No Cointegrado"
    if `pval_adf' < 0.05 local conc_adf = "Existe Cointegracion de Largo Plazo"
    post `coint_post' ("ECI") ("Pedroni") ("ADF t") (`stat_adf') (`pval_adf') ("`conc_adf'")
}

// 2. Prueba de Kao (xtcointtest kao)
capture xtcointtest kao eci `eci_coint_vars' if !missing(eci, rents, inst, log_gdppc, humcap, fin)
if _rc == 0 {
    matrix st = r(stat)
    matrix pv = r(p)
    local stat = st[1, 1]
    local pval = pv[1, 1]
    local conc = "No Cointegrado"
    if `pval' < 0.05 local conc = "Existe Cointegracion de Largo Plazo"
    post `coint_post' ("ECI") ("Kao") ("Modified Dickey-Fuller t") (`stat') (`pval') ("`conc'")
}

// 3. Prueba de Westerlund (xtcointtest westerlund)
capture xtcointtest westerlund eci `eci_coint_vars' if !missing(eci, rents, inst, log_gdppc, humcap, fin), demean
if _rc == 0 {
    matrix st = r(stat)
    matrix pv = r(p)
    local stat = st[1, 1]
    local pval = pv[1, 1]
    local conc = "No Cointegrado"
    if `pval' < 0.05 local conc = "Existe Cointegracion de Largo Plazo"
    post `coint_post' ("ECI") ("Westerlund") ("Variance ratio") (`stat') (`pval') ("`conc'")
}


// --- B. EVALUACIÓN DE COINTEGRACIÓN PARA MODELO DIVX ---
// 1. Pruebas de Pedroni (xtcointtest pedroni)
capture xtcointtest pedroni divx `divx_coint_vars' if !missing(divx, rents, inst, log_gdppc, humcap, fin), demean
if _rc == 0 {
    matrix st = r(stat)
    matrix pv = r(p)
    local stat = st[1, 1]
    local pval = pv[1, 1]
    local conc = "No Cointegrado"
    if `pval' < 0.05 local conc = "Existe Cointegracion de Largo Plazo"
    post `coint_post' ("DIVX") ("Pedroni") ("Modified PP t") (`stat') (`pval') ("`conc'")
    
    local stat_adf = st[3, 1]
    local pval_adf = pv[3, 1]
    local conc_adf = "No Cointegrado"
    if `pval_adf' < 0.05 local conc_adf = "Existe Cointegracion de Largo Plazo"
    post `coint_post' ("DIVX") ("Pedroni") ("ADF t") (`stat_adf') (`pval_adf') ("`conc_adf'")
}

// 2. Prueba de Kao (xtcointtest kao)
capture xtcointtest kao divx `divx_coint_vars' if !missing(divx, rents, inst, log_gdppc, humcap, fin)
if _rc == 0 {
    matrix st = r(stat)
    matrix pv = r(p)
    local stat = st[1, 1]
    local pval = pv[1, 1]
    local conc = "No Cointegrado"
    if `pval' < 0.05 local conc = "Existe Cointegracion de Largo Plazo"
    post `coint_post' ("DIVX") ("Kao") ("Modified Dickey-Fuller t") (`stat') (`pval') ("`conc'")
}

// 3. Prueba de Westerlund (xtcointtest westerlund)
capture xtcointtest westerlund divx `divx_coint_vars' if !missing(divx, rents, inst, log_gdppc, humcap, fin), demean
if _rc == 0 {
    matrix st = r(stat)
    matrix pv = r(p)
    local stat = st[1, 1]
    local pval = pv[1, 1]
    local conc = "No Cointegrado"
    if `pval' < 0.05 local conc = "Existe Cointegracion de Largo Plazo"
    post `coint_post' ("DIVX") ("Westerlund") ("Variance ratio") (`stat') (`pval') ("`conc'")
}

postclose `coint_post'

preserve
    use "`coint_report'", clear
    format statistic %12.4f
    format p_value %10.4f
    export delimited using "$OUTPUT_DIAGNOSTICS/panel_cointegration_tests.csv", replace
    display as result "----------------------------------------------------------------------"
    display as result "Sección 1.2: Pruebas de Cointegración en Panel (Pedroni, Kao, Westerlund)"
    display as result "----------------------------------------------------------------------"
    list model test_name statistic_name statistic p_value conclusion, sepby(model) noobs abbreviate(24)
restore


// *****************************************************************************
// 1.3. Proyecciones Locales en Panel (Jordà 2005, Horizontes h=0..5 para TODAS las variables)
// *****************************************************************************

* Cargar la base de estimación congelada y declarar la estructura de panel.
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

* Definir conjunto completo de regresores y horizontes de proyección h = 0 .. 5 años.
local lp_eci_vars rents inst rents_x_inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin
local lp_divx_vars rents inst rents_x_inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin
local horizons 0 1 2 3 4 5

tempname lp_post
tempfile lp_report
postfile `lp_post' str12 model str24 variable int horizon double beta double se double t_stat double p_val double ci_low double ci_high using "`lp_report'", replace

// --- A. PROYECCIONES LOCALES PARA COMPLEJIDAD ECONÓMICA (ECI) ---
foreach h of local horizons {
    local depvar "eci"
    if `h' > 0 local depvar "f`h'.eci"
    
    capture quietly reghdfe `depvar' `lp_eci_vars' if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
    if _rc == 0 {
        foreach var of local lp_eci_vars {
            capture local b = _b[`var']
            capture local se = _se[`var']
            if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
                local t = `b' / `se'
                local p = 2 * ttail(e(df_r), abs(`t'))
                local low = `b' - invttail(e(df_r), 0.025) * `se'
                local high = `b' + invttail(e(df_r), 0.025) * `se'
                post `lp_post' ("ECI") ("`var'") (`h') (`b') (`se') (`t') (`p') (`low') (`high')
            }
            else {
                post `lp_post' ("ECI") ("`var'") (`h') (.) (.) (.) (.) (.) (.)
            }
        }
    }
}

// --- B. PROYECCIONES LOCALES PARA DIVERSIFICACIÓN EXPORTADORA (DIVX) ---
foreach h of local horizons {
    local depvar "divx"
    if `h' > 0 local depvar "f`h'.divx"
    
    capture quietly reghdfe `depvar' `lp_divx_vars' if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
    if _rc == 0 {
        foreach var of local lp_divx_vars {
            capture local b = _b[`var']
            capture local se = _se[`var']
            if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
                local t = `b' / `se'
                local p = 2 * ttail(e(df_r), abs(`t'))
                local low = `b' - invttail(e(df_r), 0.025) * `se'
                local high = `b' + invttail(e(df_r), 0.025) * `se'
                post `lp_post' ("DIVX") ("`var'") (`h') (`b') (`se') (`t') (`p') (`low') (`high')
            }
            else {
                post `lp_post' ("DIVX") ("`var'") (`h') (.) (.) (.) (.) (.) (.)
            }
        }
    }
}

postclose `lp_post'

preserve
    use "`lp_report'", clear
    format beta se t_stat p_val ci_low ci_high %12.4f
    export delimited using "$OUTPUT_DIAGNOSTICS/panel_local_projections.csv", replace
    display as result "----------------------------------------------------------------------"
    display as result "Sección 1.3: Proyecciones Locales en Panel (Jordà 2005, Todas las variables h=0..5)"
    display as result "----------------------------------------------------------------------"
    list model variable horizon beta se p_val ci_low ci_high, sepby(variable) noobs abbreviate(24)
restore


// *****************************************************************************
// 1.4. Quiebres Estructurales y Estabilidad Temporal (Pre vs Post 2014)
// *****************************************************************************

* Cargar la base de estimación congelada y declarar la estructura de panel.
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

* Crear indicador de régimen Post-Superciclo de Commodities (2015-2021) vs Auge (1996-2014)
gen byte post_2014 = (year >= 2015) if !missing(year)
label var post_2014 "Régimen Post-Superciclo (2015-2021)"

local sb_eci_vars rents inst rents_x_inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin
local sb_divx_vars rents inst rents_x_inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin

tempname sb_post
tempfile sb_report
postfile `sb_post' str12 model str28 regime double beta_rents double se_rents double pval_rents double beta_inst double se_inst double pval_inst double beta_interaction double se_interaction double pval_interaction using "`sb_report'", replace

// --- A. EVALUACIÓN DE QUIEBRE ESTRUCTURAL PARA COMPLEJIDAD ECONÓMICA (ECI) ---
* 1. Muestra Completa (1996-2021)
capture quietly reghdfe eci `sb_eci_vars' if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    post `sb_post' ("ECI") ("Muestra Completa") (_b[rents]) (_se[rents]) (2*ttail(e(df_r), abs(_b[rents]/_se[rents]))) (_b[inst]) (_se[inst]) (2*ttail(e(df_r), abs(_b[inst]/_se[inst]))) (_b[rents_x_inst]) (_se[rents_x_inst]) (2*ttail(e(df_r), abs(_b[rents_x_inst]/_se[rents_x_inst])))
}

* 2. Submuestra Pre-2015 (Auge 1996-2014)
capture quietly reghdfe eci `sb_eci_vars' if sample_eci == 1 & post_2014 == 0, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    post `sb_post' ("ECI") ("Pre-2015 (Auge)") (_b[rents]) (_se[rents]) (2*ttail(e(df_r), abs(_b[rents]/_se[rents]))) (_b[inst]) (_se[inst]) (2*ttail(e(df_r), abs(_b[inst]/_se[inst]))) (_b[rents_x_inst]) (_se[rents_x_inst]) (2*ttail(e(df_r), abs(_b[rents_x_inst]/_se[rents_x_inst])))
}

* 3. Submuestra Post-2014 (Caida 2015-2021)
capture quietly reghdfe eci `sb_eci_vars' if sample_eci == 1 & post_2014 == 1, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    post `sb_post' ("ECI") ("Post-2014 (Caida)") (_b[rents]) (_se[rents]) (2*ttail(e(df_r), abs(_b[rents]/_se[rents]))) (_b[inst]) (_se[inst]) (2*ttail(e(df_r), abs(_b[inst]/_se[inst]))) (_b[rents_x_inst]) (_se[rents_x_inst]) (2*ttail(e(df_r), abs(_b[rents_x_inst]/_se[rents_x_inst])))
}


// --- B. EVALUACIÓN DE QUIEBRE ESTRUCTURAL PARA DIVERSIFICACIÓN EXPORTADORA (DIVX) ---
* 1. Muestra Completa (1996-2021)
capture quietly reghdfe divx `sb_divx_vars' if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    post `sb_post' ("DIVX") ("Muestra Completa") (_b[rents]) (_se[rents]) (2*ttail(e(df_r), abs(_b[rents]/_se[rents]))) (_b[inst]) (_se[inst]) (2*ttail(e(df_r), abs(_b[inst]/_se[inst]))) (_b[rents_x_inst]) (_se[rents_x_inst]) (2*ttail(e(df_r), abs(_b[rents_x_inst]/_se[rents_x_inst])))
}

* 2. Submuestra Pre-2015 (Auge 1996-2014)
capture quietly reghdfe divx `sb_divx_vars' if sample_divx == 1 & post_2014 == 0, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    post `sb_post' ("DIVX") ("Pre-2015 (Auge)") (_b[rents]) (_se[rents]) (2*ttail(e(df_r), abs(_b[rents]/_se[rents]))) (_b[inst]) (_se[inst]) (2*ttail(e(df_r), abs(_b[inst]/_se[inst]))) (_b[rents_x_inst]) (_se[rents_x_inst]) (2*ttail(e(df_r), abs(_b[rents_x_inst]/_se[rents_x_inst])))
}

* 3. Submuestra Post-2014 (Caida 2015-2021)
capture quietly reghdfe divx `sb_divx_vars' if sample_divx == 1 & post_2014 == 1, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    post `sb_post' ("DIVX") ("Post-2014 (Caida)") (_b[rents]) (_se[rents]) (2*ttail(e(df_r), abs(_b[rents]/_se[rents]))) (_b[inst]) (_se[inst]) (2*ttail(e(df_r), abs(_b[inst]/_se[inst]))) (_b[rents_x_inst]) (_se[rents_x_inst]) (2*ttail(e(df_r), abs(_b[rents_x_inst]/_se[rents_x_inst])))
}

postclose `sb_post'

preserve
    use "`sb_report'", clear
    format beta_rents se_rents pval_rents beta_inst se_inst pval_inst beta_interaction se_interaction pval_interaction %12.4f
    export delimited using "$OUTPUT_DIAGNOSTICS/panel_structural_break_tests.csv", replace
    display as result "----------------------------------------------------------------------"
    display as result "Sección 1.4: Quiebres Estructurales y Estabilidad Temporal (Pre vs Post 2014)"
    display as result "----------------------------------------------------------------------"
    list model regime beta_rents pval_rents beta_inst pval_inst beta_interaction pval_interaction, sepby(model) noobs abbreviate(28)
restore


// *****************************************************************************
// 1.5. Autocorrelación de Orden Superior AR(p) e Inferencia Comparativa (Todas las variables)
// *****************************************************************************

* Cargar la base de datos de estimación y declarar la estructura de panel.
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

tempname ar_post
tempfile ar_report
postfile `ar_post' str12 model str32 vce_type str24 variable double beta double se double pval using "`ar_report'", replace

// --- A. EVALUACIÓN DE INFERENCIA COMPARATIVA EN MODELO ECI (18 VARIABLES) ---
* 1. Baseline Cluster por País (vce cluster country_id)
capture quietly reghdfe eci `sb_eci_vars' if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - e(df_m)
    foreach var of local sb_eci_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * ttail(`df', abs(`b'/`se'))
            post `ar_post' ("ECI") ("Cluster-Robust (Pais)") ("`var'") (`b') (`se') (`p')
        }
    }
}

* 2. Errores Estándar Driscoll-Kraay (HAC espacial/temporal)
capture quietly xtscc eci `sb_eci_vars' i.year if sample_eci == 1, fe lag(2)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - 20
    foreach var of local sb_eci_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * ttail(`df', abs(`b'/`se'))
            post `ar_post' ("ECI") ("Driscoll-Kraay HAC (lag 2)") ("`var'") (`b') (`se') (`p')
        }
    }
}

* 3. Errores Estándar Corregidos por Autocorrelación Panel (PCSE AR1)
capture quietly xtpcse eci `sb_eci_vars' i.country_id i.year if sample_eci == 1, correlation(ar1)
if _rc == 0 {
    foreach var of local sb_eci_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * normal(-abs(`b'/`se'))
            post `ar_post' ("ECI") ("Panel PCSE (AR1)") ("`var'") (`b') (`se') (`p')
        }
    }
}


// --- B. EVALUACIÓN DE INFERENCIA COMPARATIVA EN MODELO DIVX (18 VARIABLES) ---
* 1. Baseline Cluster por País (vce cluster country_id)
capture quietly reghdfe divx `sb_divx_vars' if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - e(df_m)
    foreach var of local sb_divx_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * ttail(`df', abs(`b'/`se'))
            post `ar_post' ("DIVX") ("Cluster-Robust (Pais)") ("`var'") (`b') (`se') (`p')
        }
    }
}

* 2. Errores Estándar Driscoll-Kraay (HAC espacial/temporal)
capture quietly xtscc divx `sb_divx_vars' i.year if sample_divx == 1, fe lag(2)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - 20
    foreach var of local sb_divx_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * ttail(`df', abs(`b'/`se'))
            post `ar_post' ("DIVX") ("Driscoll-Kraay HAC (lag 2)") ("`var'") (`b') (`se') (`p')
        }
    }
}

* 3. Errores Estándar Corregidos por Autocorrelación Panel (PCSE AR1)
capture quietly xtpcse divx `sb_divx_vars' i.country_id i.year if sample_divx == 1, correlation(ar1)
if _rc == 0 {
    foreach var of local sb_divx_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * normal(-abs(`b'/`se'))
            post `ar_post' ("DIVX") ("Panel PCSE (AR1)") ("`var'") (`b') (`se') (`p')
        }
    }
}

postclose `ar_post'

preserve
    use "`ar_report'", clear
    format beta se pval %12.4f
    export delimited using "$OUTPUT_DIAGNOSTICS/panel_autocorrelation_inference.csv", replace
    display as result "----------------------------------------------------------------------"
    display as result "Sección 1.5: Autocorrelación AR(p) e Inferencia Comparativa (Todas las 18 variables)"
    display as result "----------------------------------------------------------------------"
    list model vce_type variable beta se pval, sepby(vce_type) noobs abbreviate(32)
restore


// *****************************************************************************
// 1.6. Filtros de Series de Tiempo (Ciclo vs. Tendencia - Filtro Hodrick-Prescott para TODAS las variables)
// *****************************************************************************

* Cargar la base de datos de estimación congelada y declarar la estructura de panel.
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

* Aplicar Filtro Hodrick-Prescott (lambda = 6.25 para datos anuales según Ravn & Uhlig 2002)
capture tsfilter hp eci_cycle = eci, trend(eci_trend) smooth(6.25)
capture tsfilter hp divx_cycle = divx, trend(divx_trend) smooth(6.25)

tempname hp_post
tempfile hp_report
postfile `hp_post' str12 model str24 component str24 variable double beta double se double pval using "`hp_report'", replace

// --- A. MODELO ECI: TENDENCIA ESTRUCTURAL VS CICLO DE CORTO PLAZO (18 VARIABLES) ---
* 1. Serie Original en Niveles (ECI Total)
capture quietly reghdfe eci `sb_eci_vars' if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - e(df_m)
    foreach var of local sb_eci_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * ttail(`df', abs(`b'/`se'))
            post `hp_post' ("ECI") ("Serie Original (Total)") ("`var'") (`b') (`se') (`p')
        }
    }
}

* 2. Tendencia Estructural de Largo Plazo (ECI Trend)
capture quietly reghdfe eci_trend `sb_eci_vars' if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - e(df_m)
    foreach var of local sb_eci_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * ttail(`df', abs(`b'/`se'))
            post `hp_post' ("ECI") ("Tendencia Largo Plazo") ("`var'") (`b') (`se') (`p')
        }
    }
}

* 3. Componente Cíclico de Corto Plazo (ECI Cycle)
capture quietly reghdfe eci_cycle `sb_eci_vars' if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - e(df_m)
    foreach var of local sb_eci_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * ttail(`df', abs(`b'/`se'))
            post `hp_post' ("ECI") ("Ciclo Corto Plazo") ("`var'") (`b') (`se') (`p')
        }
    }
}


// --- B. MODELO DIVX: TENDENCIA ESTRUCTURAL VS CICLO DE CORTO PLAZO (18 VARIABLES) ---
* 1. Serie Original en Niveles (DIVX Total)
capture quietly reghdfe divx `sb_divx_vars' if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - e(df_m)
    foreach var of local sb_divx_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * ttail(`df', abs(`b'/`se'))
            post `hp_post' ("DIVX") ("Serie Original (Total)") ("`var'") (`b') (`se') (`p')
        }
    }
}

* 2. Tendencia Estructural de Largo Plazo (DIVX Trend)
capture quietly reghdfe divx_trend `sb_divx_vars' if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - e(df_m)
    foreach var of local sb_divx_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * ttail(`df', abs(`b'/`se'))
            post `hp_post' ("DIVX") ("Tendencia Largo Plazo") ("`var'") (`b') (`se') (`p')
        }
    }
}

* 3. Componente Cíclico de Corto Plazo (DIVX Cycle)
capture quietly reghdfe divx_cycle `sb_divx_vars' if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - e(df_m)
    foreach var of local sb_divx_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * ttail(`df', abs(`b'/`se'))
            post `hp_post' ("DIVX") ("Ciclo Corto Plazo") ("`var'") (`b') (`se') (`p')
        }
    }
}

postclose `hp_post'

preserve
    use "`hp_report'", clear
    format beta se pval %12.4f
    export delimited using "$OUTPUT_DIAGNOSTICS/panel_hp_filter_decomposition.csv", replace
    display as result "----------------------------------------------------------------------"
    display as result "Sección 1.6: Descomposición de Series de Tiempo (Filtro HP: Ciclo vs. Tendencia - Todas las 18 variables)"
    display as result "----------------------------------------------------------------------"
    list model component variable beta se pval, sepby(component) noobs abbreviate(28)
restore


// *****************************************************************************
// 2. Modelo 3 Completo (M3) — Complejidad Económica (ECI)
// *****************************************************************************

* Cargar la base de datos de estimación y declarar la estructura de panel.
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

* Definir conjunto completo de regresores para el modelo ECI.
global ECI_REGRESSORS rents inst rents_x_inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin

* Estimar el Modelo 3 Completo (M3) de ECI con efectos fijos de país y año.
reghdfe eci $ECI_REGRESSORS if sample_eci == 1, absorb(country_id year) vce(cluster country_id)

* Guardar estimaciones en memoria y en archivo .ster.
estimates store ECI_TWFE_MAIN
estimates save "$OUTPUT_ECI/eci_twfe_main.ster", replace

* Verificar que la muestra utilizada coincide con los 1.044 casos congelados.
quietly count if e(sample)
assert r(N) == 1044

* Exportar tabla CSV detallada de coeficientes e intervalos de confianza.
tempname eci_coef_post
tempfile eci_coef_report
postfile `eci_coef_post' int order str32 term str100 variable_label str32 channel double coefficient standard_error t_statistic p_value ci_lower ci_upper using "`eci_coef_report'", replace

local eci_terms rents inst rents_x_inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin
local critical_t = invttail(e(df_r), 0.025)
local term_order = 0

foreach term of local eci_terms {
    local ++term_order
    local b = _b[`term']
    local se = _se[`term']
    local term_label : variable label `term'
    if `"`term_label'"' == "" local term_label "`term'"

    local channel "Controles económicos"
    if inlist("`term'", "rents", "inst", "rents_x_inst") local channel "Institucional"
    if inlist("`term'", "log_oilpc", "log_gaspc", "log_coalpc") local channel "Abundancia de recursos"
    if inlist("`term'", "hhi", "pexp", "fexp") local channel "Estructura exportadora"
    if inlist("`term'", "vol", "rer") local channel "Condiciones macroeconómicas"
    if inlist("`term'", "humcap", "innov", "net") local channel "Capacidades productivas"

    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local low = `b' - `critical_t' * `se'
    local high = `b' + `critical_t' * `se'

    post `eci_coef_post' (`term_order') ("`term'") (`"`term_label'"') (`"`channel'"') (`b') (`se') (`t') (`p') (`low') (`high')
}
postclose `eci_coef_post'

preserve
    use "`eci_coef_report'", clear
    sort order
    format coefficient standard_error t_statistic ci_lower ci_upper %12.6f
    format p_value %10.6f
    export delimited using "$OUTPUT_ECI/eci_twfe_coefficients.csv", replace
    list term coefficient standard_error p_value ci_lower ci_upper, noobs abbreviate(24)
restore

* Exportar el resumen general del modelo ECI en CSV.
tempname eci_sum_post
tempfile eci_sum_report
postfile `eci_sum_post' str24 model str12 dependent int obs countries clusters years double r2_within r2_between r2_overall f_stat df_m df_r p_val rmse sigma_u sigma_e rho using "`eci_sum_report'", replace

post `eci_sum_post' ("ECI_TWFE_MAIN") ("eci") (e(N)) (e(N_g)) (e(N_clust)) (23) (e(r2_within)) (.) (.) (e(F)) (e(df_m)) (e(df_r)) (e(p)) (e(rmse)) (.) (.) (.)
postclose `eci_sum_post'

preserve
    use "`eci_sum_report'", clear
    format r2_within f_stat p_val rmse %12.6f
    export delimited using "$OUTPUT_ECI/eci_twfe_model_summary.csv", replace
restore

* Realizar pruebas de hipótesis conjuntas por canal teórico para ECI.
tempname eci_tests_post
tempfile eci_tests_report
postfile `eci_tests_post' int order str40 test str100 null_hypothesis double f_stat df1 df2 p_val using "`eci_tests_report'", replace

test rents inst rents_x_inst
post `eci_tests_post' (1) ("Canal institucional") ("RENTS, INST y RENTSxINST son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

test log_oilpc log_gaspc log_coalpc
post `eci_tests_post' (2) ("Canal de abundancia") ("Petróleo, gas y carbón son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

test hhi pexp fexp
post `eci_tests_post' (3) ("Canal estructural") ("HHI, PEXP y FEXP son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

test vol rer
post `eci_tests_post' (4) ("Canal macroeconómico") ("VOL y RER son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

test humcap innov net
post `eci_tests_post' (5) ("Capacidades productivas") ("HUMCAP, INNOV y NET son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

test log_gdppc govcons fin
post `eci_tests_post' (6) ("Controles económicos") ("log(GDPPC), GOVCONS y FIN son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

test (log_oilpc = log_gaspc) (log_oilpc = log_coalpc)
post `eci_tests_post' (7) ("Igualdad entre recursos") ("Coeficientes de petróleo, gas y carbón son iguales") (r(F)) (r(df)) (r(df_r)) (r(p))

postclose `eci_tests_post'

preserve
    use "`eci_tests_report'", clear
    sort order
    format f_stat p_val %12.6f
    export delimited using "$OUTPUT_ECI/eci_twfe_channel_tests.csv", replace
    list test null_hypothesis f_stat p_val, noobs abbreviate(24)
restore


// *****************************************************************************
// 3. Modelo 3 Completo (M3) — Diversificación Exportadora (DIVX)
// *****************************************************************************

* Cargar la base de datos de estimación.
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

* Definir regresores excluyendo HHI para evitar identidad contable (DIVX = 1 - HHI).
global DIVX_REGRESSORS rents inst rents_x_inst log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin

* Estimar el Modelo 3 Completo (M3) de DIVX con efectos fijos de país y año.
reghdfe divx $DIVX_REGRESSORS if sample_divx == 1, absorb(country_id year) vce(cluster country_id)

* Guardar estimaciones en memoria y en archivo .ster.
estimates store DIVX_TWFE_MAIN
estimates save "$OUTPUT_DIVX/divx_twfe_main.ster", replace

* Exportar coeficientes del modelo DIVX a CSV.
tempname divx_coef_post
tempfile divx_coef_report
postfile `divx_coef_post' int order str32 term str100 variable_label str32 channel double coefficient standard_error t_statistic p_value ci_lower ci_upper using "`divx_coef_report'", replace

local divx_terms rents inst rents_x_inst log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin
local critical_t = invttail(e(df_r), 0.025)
local term_order = 0

foreach term of local divx_terms {
    local ++term_order
    local b = _b[`term']
    local se = _se[`term']
    local term_label : variable label `term'
    if `"`term_label'"' == "" local term_label "`term'"

    local channel "Controles económicos"
    if inlist("`term'", "rents", "inst", "rents_x_inst") local channel "Institucional"
    if inlist("`term'", "log_oilpc", "log_gaspc", "log_coalpc") local channel "Abundancia de recursos"
    if inlist("`term'", "pexp", "fexp") local channel "Estructura exportadora"
    if inlist("`term'", "vol", "rer") local channel "Condiciones macroeconómicas"
    if inlist("`term'", "humcap", "innov", "net") local channel "Capacidades productivas"

    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local low = `b' - `critical_t' * `se'
    local high = `b' + `critical_t' * `se'

    post `divx_coef_post' (`term_order') ("`term'") (`"`term_label'"') (`"`channel'"') (`b') (`se') (`t') (`p') (`low') (`high')
}
postclose `divx_coef_post'

preserve
    use "`divx_coef_report'", clear
    sort order
    format coefficient standard_error t_statistic ci_lower ci_upper %12.6f
    format p_value %10.6f
    export delimited using "$OUTPUT_DIVX/divx_twfe_coefficients.csv", replace
    list term coefficient standard_error p_value ci_lower ci_upper, noobs abbreviate(24)
restore

* Exportar el resumen general del modelo DIVX en CSV.
tempname divx_sum_post
tempfile divx_sum_report
postfile `divx_sum_post' str24 model str12 dependent int obs countries clusters years double r2_within r2_between r2_overall f_stat df_m df_r p_val rmse sigma_u sigma_e rho using "`divx_sum_report'", replace

post `divx_sum_post' ("DIVX_TWFE_MAIN") ("divx") (e(N)) (e(N_g)) (e(N_clust)) (23) (e(r2_within)) (.) (.) (e(F)) (e(df_m)) (e(df_r)) (e(p)) (e(rmse)) (.) (.) (.)
postclose `divx_sum_post'

preserve
    use "`divx_sum_report'", clear
    format r2_within f_stat p_val rmse %12.6f
    export delimited using "$OUTPUT_DIVX/divx_twfe_model_summary.csv", replace
restore

* Realizar pruebas de hipótesis conjuntas por canal para DIVX.
tempname divx_tests_post
tempfile divx_tests_report
postfile `divx_tests_post' int order str40 test str100 null_hypothesis double f_stat df1 df2 p_val using "`divx_tests_report'", replace

test rents inst rents_x_inst
post `divx_tests_post' (1) ("Canal institucional") ("RENTS, INST y RENTSxINST son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

test log_oilpc log_gaspc log_coalpc
post `divx_tests_post' (2) ("Canal de abundancia") ("Petróleo, gas y carbón son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

test pexp fexp
post `divx_tests_post' (3) ("Canal estructural") ("PEXP y FEXP son conjuntamente cero (HHI excluido)") (r(F)) (r(df)) (r(df_r)) (r(p))

test vol rer
post `divx_tests_post' (4) ("Canal macroeconómico") ("VOL y RER son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

test humcap innov net
post `divx_tests_post' (5) ("Capacidades productivas") ("HUMCAP, INNOV y NET son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

test log_gdppc govcons fin
post `divx_tests_post' (6) ("Controles económicos") ("log(GDPPC), GOVCONS y FIN son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

test (log_oilpc = log_gaspc) (log_oilpc = log_coalpc)
post `divx_tests_post' (7) ("Igualdad entre recursos") ("Coeficientes de petróleo, gas y carbón son iguales") (r(F)) (r(df)) (r(df_r)) (r(p))

postclose `divx_tests_post'

preserve
    use "`divx_tests_report'", clear
    sort order
    format f_stat p_val %12.6f
    export delimited using "$OUTPUT_DIVX/divx_twfe_channel_tests.csv", replace
    list test null_hypothesis f_stat p_val, noobs abbreviate(24)
restore


// *****************************************************************************
// 4. Estabilidad, Efectos Marginales y Sensibilidad
// *****************************************************************************

* Cargar la base de datos de estimación.
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

* Obtener percentiles observados de INST.
quietly summarize inst if sample_eci == 1, detail
local p10 = r(p10)
local p25 = r(p25)
local p50 = r(p50)
local p75 = r(p75)
local p90 = r(p90)
local inst_vals "`p10' `p25' `p50' `p75' `p90'"
local inst_lbls "P10 P25 P50 P75 P90"

* Calcular efectos marginales condicionales d(Y)/d(RENTS) según percentiles de INST.
tempname margins_post
tempfile margins_report
postfile `margins_post' str8 model str4 percentile double inst_val double marginal_effect double standard_error double t_stat double p_val double ci_lower double ci_upper str12 significance using "`margins_report'", replace

* --- Modelo ECI ---
quietly reghdfe eci $ECI_REGRESSORS if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
margins, dydx(rents) at(inst=(`inst_vals'))
matrix eci_m = r(table)

marginsplot, recast(line) recastci(rarea) plotopts(lcolor(navy) lwidth(medthick)) ciopts(color(navy%25) lcolor(navy%45)) ///
    yline(0, lcolor(gs8) lpattern(dash)) xlabel(`p10' "P10" `p25' "P25" `p50' "P50" `p75' "P75" `p90' "P90", labsize(small) angle(45)) ///
    ylabel(, labsize(small) angle(horizontal)) ///
    title("ECI (M3): Asociación marginal estimada de RENTS según INST", size(medium)) ///
    ytitle("Asociación marginal d(ECI)/d(RENTS)") xtitle("Percentil de calidad institucional (INST)") ///
    name(eci_m3_margins_plot, replace) nodraw
cap graph export "$OUTPUT_STABILITY/eci_rents_marginal_effect_by_inst.png", width(2400) replace

forvalues col = 1/5 {
    local pct : word `col' of `inst_lbls'
    local val : word `col' of `inst_vals'
    local eff = el(eci_m, 1, `col')
    local se  = el(eci_m, 2, `col')
    local t   = el(eci_m, 3, `col')
    local p   = el(eci_m, 4, `col')
    local low = el(eci_m, 5, `col')
    local high = el(eci_m, 6, `col')
    local sig "No"
    if `p' < 0.10 local sig "10%"
    if `p' < 0.05 local sig "5%"
    if `p' < 0.01 local sig "1%"
    post `margins_post' ("ECI") ("`pct'") (`val') (`eff') (`se') (`t') (`p') (`low') (`high') ("`sig'")
}

* --- Modelo DIVX ---
quietly reghdfe divx $DIVX_REGRESSORS if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
margins, dydx(rents) at(inst=(`inst_vals'))
matrix divx_m = r(table)

marginsplot, recast(line) recastci(rarea) plotopts(lcolor(maroon) lwidth(medthick)) ciopts(color(maroon%25) lcolor(maroon%45)) ///
    yline(0, lcolor(gs8) lpattern(dash)) xlabel(`p10' "P10" `p25' "P25" `p50' "P50" `p75' "P75" `p90' "P90", labsize(small) angle(45)) ///
    ylabel(, labsize(small) angle(horizontal)) ///
    title("DIVX (M3): Asociación marginal estimada de RENTS según INST", size(medium)) ///
    ytitle("Asociación marginal d(DIVX)/d(RENTS)") xtitle("Percentil de calidad institucional (INST)") ///
    name(divx_m3_margins_plot, replace) nodraw
cap graph export "$OUTPUT_STABILITY/divx_rents_marginal_effect_by_inst.png", width(2400) replace

forvalues col = 1/5 {
    local pct : word `col' of `inst_lbls'
    local val : word `col' of `inst_vals'
    local eff = el(divx_m, 1, `col')
    local se  = el(divx_m, 2, `col')
    local t   = el(divx_m, 3, `col')
    local p   = el(divx_m, 4, `col')
    local low = el(divx_m, 5, `col')
    local high = el(divx_m, 6, `col')
    local sig "No"
    if `p' < 0.10 local sig "10%"
    if `p' < 0.05 local sig "5%"
    if `p' < 0.01 local sig "1%"
    post `margins_post' ("DIVX") ("`pct'") (`val') (`eff') (`se') (`t') (`p') (`low') (`high') ("`sig'")
}
postclose `margins_post'

preserve
    use "`margins_report'", clear
    sort model inst_val
    format inst_val marginal_effect standard_error t_stat p_val ci_lower ci_upper %12.6f
    export delimited using "$OUTPUT_STABILITY/rents_marginal_effects_by_inst.csv", replace
    list, sepby(model) noobs abbreviate(24)
restore

* Reestimación Leave-One-Country-Out Jackknife omitiendo un país a la vez.
quietly levelsof country_id if sample_eci == 1, local(c_list)
tempname loo_post
tempfile loo_report
postfile `loo_post' str8 model double excluded_id str3 excluded_iso3 str24 term double base_b b se p obs countries using "`loo_report'", replace

quietly reghdfe eci $ECI_REGRESSORS if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
local base_eci_b = _b[rents]
quietly reghdfe divx $DIVX_REGRESSORS if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
local base_divx_b = _b[rents]

foreach cid of local c_list {
    quietly levelsof country_iso3_code if country_id == `cid', local(c_iso3) clean

    quietly reghdfe eci $ECI_REGRESSORS if sample_eci == 1 & country_id != `cid', absorb(country_id year) vce(cluster country_id)
    local p_val = 2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
    post `loo_post' ("ECI") (`cid') ("`c_iso3'") ("RENTS") (`base_eci_b') (_b[rents]) (_se[rents]) (`p_val') (e(N)) (e(N_g))

    quietly reghdfe divx $DIVX_REGRESSORS if sample_divx == 1 & country_id != `cid', absorb(country_id year) vce(cluster country_id)
    local p_val = 2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
    post `loo_post' ("DIVX") (`cid') ("`c_iso3'") ("RENTS") (`base_divx_b') (_b[rents]) (_se[rents]) (`p_val') (e(N)) (e(N_g))
}
postclose `loo_post'

preserve
    use "`loo_report'", clear
    gen byte sign_change = (sign(b) != sign(base_b))
    gen byte sig_5 = (p < 0.05)
    export delimited using "$OUTPUT_STABILITY/leave_one_country_out.csv", replace

    collapse (count) reps=b (firstnm) base_b (min) min_b=b min_p=p (max) max_b=b max_p=p (sum) sign_changes=sign_change sig_5, by(model term)
    format base_b min_b max_b min_p max_p %12.6f
    export delimited using "$OUTPUT_STABILITY/leave_one_country_out_summary.csv", replace
    list, sepby(model) noobs abbreviate(24)
restore

* Inferencia complementaria mediante Wild Cluster Bootstrap.
cap which boottest
if _rc == 0 {
    tempname boot_post
    tempfile boot_report
    postfile `boot_post' str8 model str24 term double conv_b conv_p boot_p ci_low ci_high reps str12 weight using "`boot_report'", replace

    quietly reghdfe eci $ECI_REGRESSORS if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
    local cp = 2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
    boottest rents, cluster(country_id) reps(9999) seed(20260729) nograph
    matrix boot_ci = r(CI)
    post `boot_post' ("ECI") ("RENTS") (_b[rents]) (`cp') (r(p)) (el(boot_ci,1,1)) (el(boot_ci,1,2)) (r(reps)) ("`r(weighttype)'")

    boottest rents_x_inst, cluster(country_id) reps(9999) seed(20260730) nograph
    matrix boot_ci = r(CI)
    local cp = 2 * ttail(e(df_r), abs(_b[rents_x_inst] / _se[rents_x_inst]))
    post `boot_post' ("ECI") ("RENTS x INST") (_b[rents_x_inst]) (`cp') (r(p)) (el(boot_ci,1,1)) (el(boot_ci,1,2)) (r(reps)) ("`r(weighttype)'")

    quietly reghdfe divx $DIVX_REGRESSORS if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
    local cp = 2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
    boottest rents, cluster(country_id) reps(9999) seed(20260731) nograph
    matrix boot_ci = r(CI)
    post `boot_post' ("DIVX") ("RENTS") (_b[rents]) (`cp') (r(p)) (el(boot_ci,1,1)) (el(boot_ci,1,2)) (r(reps)) ("`r(weighttype)'")

    boottest rents_x_inst, cluster(country_id) reps(9999) seed(20260732) nograph
    matrix boot_ci = r(CI)
    local cp = 2 * ttail(e(df_r), abs(_b[rents_x_inst] / _se[rents_x_inst]))
    post `boot_post' ("DIVX") ("RENTS x INST") (_b[rents_x_inst]) (`cp') (r(p)) (el(boot_ci,1,1)) (el(boot_ci,1,2)) (r(reps)) ("`r(weighttype)'")

    postclose `boot_post'

    preserve
        use "`boot_report'", clear
        format conv_b conv_p boot_p ci_low ci_high %12.6f
        export delimited using "$OUTPUT_STABILITY/wild_cluster_bootstrap.csv", replace
        list, sepby(model) noobs abbreviate(24)
    restore
}


// *****************************************************************************
// 5. Exportación de Resultados y Tablas Formateadas
// *****************************************************************************

* Exportar las tablas formateadas principales a LaTeX.
cap which esttab
if _rc == 0 {
    esttab ECI_TWFE_MAIN DIVX_TWFE_MAIN using "$OUTPUT_FINAL/table_eci_divx_twfe.tex", replace ///
        b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
        stats(N N_g r2_within F p, labels("Observaciones" "Países" "R2 Within" "Estadístico F" "p-valor F") fmt(%9.0f %9.0f %9.4f %9.3f %9.4f)) ///
        mtitles("ECI (Complejidad)" "DIVX (Diversificación)") ///
        title("Modelo 3 Completo (M3): Estimación TWFE ECI vs DIVX") ///
        booktabs label alignment(c)
}

* Informar en consola la finalización exitosa del Modelo 3 Completo.
display as result "---------------------------------------------------------"
display as result "Parte 2 (Secciones 5 a 8) completada con éxito en stata-peer-1."
display as result "Tablas LaTeX exportadas en: $OUTPUT_FINAL"
display as result "---------------------------------------------------------"

* Cerrar el archivo de registro de ejecución de la Parte 2.
log close full_model_log
