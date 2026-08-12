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
// Archivo: 08_twfe_resource_disaggregated_full.do (Versión Peer-1)
// Contenido: Modelo 3 Desagregado e Integrado — Hidrocarburos frente a Minería y Carbón simultáneamente
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

* Asegurar que el directorio de trabajo activo sea la raíz del repositorio.
quietly cd "C:/Users/julla/GitHub/master-thesis-project-applied-econ"

* Definir variables globales para las rutas del repositorio en Peer-1.
global PROJECT_ROOT "C:/Users/julla/GitHub/master-thesis-project-applied-econ"
global OUTPUT_ROOT   "$PROJECT_ROOT/outputs/econometrics/stata-peer-1/01_twfe_main"
global OUTPUT_SAMPLE "$OUTPUT_ROOT/01_sample"
global OUTPUT_DISAGG "$OUTPUT_ROOT/06_resource_disaggregation"
global OUTPUT_INTEG  "$OUTPUT_ROOT/12_resource_disaggregated_integrated"
global OUTPUT_FINAL  "$OUTPUT_ROOT/07_final"
global OUTPUT_LOGS   "$OUTPUT_ROOT/logs"

* Crear los directorios de salida utilizando shell mkdir para compatibilidad en Windows.
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\06_resource_disaggregation"
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\12_resource_disaggregated_integrated"
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\07_final"
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\logs"

capture log close _all
log using "$OUTPUT_LOGS/08_twfe_resource_disaggregated_full.log", text replace name(disagg_integ_log)

* Confirmar la presencia de la base de estimación congelada.
capture confirm file "$OUTPUT_SAMPLE/master_panel_sample.dta"
if _rc {
    display as error "Error: No se encontró $OUTPUT_SAMPLE/master_panel_sample.dta"
    exit 601
}


// *****************************************************************************
// 2. Carga de Muestra y Preparación de Variables Desagregadas
// *****************************************************************************

* Cargar la base analítica congelada de 1.044 observaciones y 49 países.
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

* Generar los términos de interacción específicos por componente extractivo.
capture gen rents_oil_gas_x_inst = rents_oil_gas * inst
capture gen rents_mining_x_inst = rents_mining * inst
label variable rents_oil_gas "Rentas de hidrocarburos (% PIB)"
label variable rents_oil_gas_x_inst "Rentas hidrocarburos x INST"
label variable rents_mining "Rentas de minería y carbón (% PIB)"
label variable rents_mining_x_inst "Rentas minería x INST"


// *****************************************************************************
// 3. Estimación del Modelo 3 Desagregado e Integrado — Complejidad Económica (ECI)
// *****************************************************************************

* Estimar el Modelo 3 Desagregado sobre Complejidad Económica (ECI).
reghdfe eci c.rents_oil_gas##c.inst c.rents_mining##c.inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin if sample_eci == 1, absorb(country_id year) vce(cluster country_id)

* Guardar estimación en memoria y en archivo .ster.
estimates store M3_DISAGG_ECI
local ster_path "$OUTPUT_INTEG/m3_disagg_eci.ster"
local ster_path = subinstr("`ster_path'", "/", "\", .)
estimates save "`ster_path'", replace

* Evaluar prueba de igualdad directa entre coeficientes de hidrocarburos y minería en ECI.
quietly test rents_oil_gas = rents_mining
local f_eq_eci = r(F)
local p_eq_eci = r(p)

* Evaluar prueba de igualdad entre términos de interacción en ECI.
quietly test c.rents_oil_gas#c.inst = c.rents_mining#c.inst
local f_inter_eci = r(F)
local p_inter_eci = r(p)

* Evaluar prueba de significancia conjunta del bloque desagregado completo en ECI.
quietly test rents_oil_gas rents_mining c.rents_oil_gas#c.inst c.rents_mining#c.inst
local f_joint_eci = r(F)
local p_joint_eci = r(p)


// *****************************************************************************
// 4. Estimación del Modelo 3 Desagregado e Integrado — Diversificación Exportadora (DIVX)
// *****************************************************************************

* Estimar el Modelo 3 Desagregado sobre Diversificación Exportadora (DIVX).
reghdfe divx c.rents_oil_gas##c.inst c.rents_mining##c.inst log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin if sample_divx == 1, absorb(country_id year) vce(cluster country_id)

* Guardar estimación en memoria y en archivo .ster.
estimates store M3_DISAGG_DIVX
local ster_path "$OUTPUT_INTEG/m3_disagg_divx.ster"
local ster_path = subinstr("`ster_path'", "/", "\", .)
estimates save "`ster_path'", replace

* Evaluar prueba de igualdad directa entre coeficientes de hidrocarburos y minería en DIVX.
quietly test rents_oil_gas = rents_mining
local f_eq_divx = r(F)
local p_eq_divx = r(p)

* Evaluar prueba de igualdad entre términos de interacción en DIVX.
quietly test c.rents_oil_gas#c.inst = c.rents_mining#c.inst
local f_inter_divx = r(F)
local p_inter_divx = r(p)

* Evaluar prueba de significancia conjunta del bloque desagregado completo en DIVX.
quietly test rents_oil_gas rents_mining c.rents_oil_gas#c.inst c.rents_mining#c.inst
local f_joint_divx = r(F)
local p_joint_divx = r(p)


// *****************************************************************************
// 5. Pruebas Formales de Igualdad y Reportes de Inferencia Desagregada
// *****************************************************************************

* Consolidar el reporte de pruebas de igualdad entre tipos de recursos a CSV.
tempname eq_post
tempfile eq_report
postfile `eq_post' str8 outcome str45 test_hypothesis double f_stat double p_val str16 decision using "`eq_report'", replace

local dec_eci "No rechazar H0"
if `p_eq_eci' < 0.05 local dec_eci "Rechazar H0"
post `eq_post' ("ECI") ("Igualdad coeficientes directos (oil_gas = mining)") (`f_eq_eci') (`p_eq_eci') ("`dec_eci'")

local dec_inter_eci "No rechazar H0"
if `p_inter_eci' < 0.05 local dec_inter_eci "Rechazar H0"
post `eq_post' ("ECI") ("Igualdad interacciones (oil_gas_x_inst = mining_x_inst)") (`f_inter_eci') (`p_inter_eci') ("`dec_inter_eci'")

local dec_joint_eci "No rechazar H0"
if `p_joint_eci' < 0.05 local dec_joint_eci "Rechazar H0"
post `eq_post' ("ECI") ("Significancia conjunta bloque desagregado") (`f_joint_eci') (`p_joint_eci') ("`dec_joint_eci'")

local dec_divx "No rechazar H0"
if `p_eq_divx' < 0.05 local dec_divx "Rechazar H0"
post `eq_post' ("DIVX") ("Igualdad coeficientes directos (oil_gas = mining)") (`f_eq_divx') (`p_eq_divx') ("`dec_divx'")

local dec_inter_divx "No rechazar H0"
if `p_inter_divx' < 0.05 local dec_inter_divx "Rechazar H0"
post `eq_post' ("DIVX") ("Igualdad interacciones (oil_gas_x_inst = mining_x_inst)") (`f_inter_divx') (`p_inter_divx') ("`dec_inter_divx'")

local dec_joint_divx "No rechazar H0"
if `p_joint_divx' < 0.05 local dec_joint_divx "Rechazar H0"
post `eq_post' ("DIVX") ("Significancia conjunta bloque desagregado") (`f_joint_divx') (`p_joint_divx') ("`dec_joint_divx'")

postclose `eq_post'

preserve
    use "`eq_report'", clear
    format f_stat p_val %12.4f
    export delimited using "$OUTPUT_INTEG/disaggregated_coefficient_equality.csv", replace
    export delimited using "$OUTPUT_DISAGG/disaggregated_coefficient_equality.csv", replace
    list, sepby(outcome) noobs abbreviate(35)
restore


// *****************************************************************************
// 6. Efectos Marginales Condicionales por Tipo de Recurso
// *****************************************************************************

* Obtener percentiles observados de la calidad institucional.
quietly summarize inst if sample_eci == 1, detail
local p10 = r(p10)
local p25 = r(p25)
local p50 = r(p50)
local p75 = r(p75)
local p90 = r(p90)
local inst_vals "`p10' `p25' `p50' `p75' `p90'"
local inst_lbls "P10 P25 P50 P75 P90"

* Calcular y exportar efectos marginales condicionales de hidrocarburos y minería en M3 Desagregado.
tempname disagg_me_post
tempfile disagg_me_report
postfile `disagg_me_post' str12 outcome str16 resource_type str4 percentile double inst_val double marginal_effect double standard_error double t_stat double p_val double ci_lower double ci_upper using "`disagg_me_report'", replace

* --- ECI Hidrocarburos ---
estimates restore M3_DISAGG_ECI
quietly margins, dydx(rents_oil_gas) at(inst=(`inst_vals'))
matrix M = r(table)
forvalues k = 1/5 {
    local pct : word `k' of `inst_lbls'
    local val : word `k' of `inst_vals'
    post `disagg_me_post' ("ECI") ("Hidrocarburos") ("`pct'") (`val') (el(M,1,`k')) (el(M,2,`k')) (el(M,3,`k')) (el(M,4,`k')) (el(M,5,`k')) (el(M,6,`k'))
}

* --- ECI Minería y Carbón ---
quietly margins, dydx(rents_mining) at(inst=(`inst_vals'))
matrix M = r(table)
forvalues k = 1/5 {
    local pct : word `k' of `inst_lbls'
    local val : word `k' of `inst_vals'
    post `disagg_me_post' ("ECI") ("Minería/Carbón") ("`pct'") (`val') (el(M,1,`k')) (el(M,2,`k')) (el(M,3,`k')) (el(M,4,`k')) (el(M,5,`k')) (el(M,6,`k'))
}

* --- DIVX Hidrocarburos ---
estimates restore M3_DISAGG_DIVX
quietly margins, dydx(rents_oil_gas) at(inst=(`inst_vals'))
matrix M = r(table)
forvalues k = 1/5 {
    local pct : word `k' of `inst_lbls'
    local val : word `k' of `inst_vals'
    post `disagg_me_post' ("DIVX") ("Hidrocarburos") ("`pct'") (`val') (el(M,1,`k')) (el(M,2,`k')) (el(M,3,`k')) (el(M,4,`k')) (el(M,5,`k')) (el(M,6,`k'))
}

* --- DIVX Minería y Carbón ---
quietly margins, dydx(rents_mining) at(inst=(`inst_vals'))
matrix M = r(table)
forvalues k = 1/5 {
    local pct : word `k' of `inst_lbls'
    local val : word `k' of `inst_vals'
    post `disagg_me_post' ("DIVX") ("Minería/Carbón") ("`pct'") (`val') (el(M,1,`k')) (el(M,2,`k')) (el(M,3,`k')) (el(M,4,`k')) (el(M,5,`k')) (el(M,6,`k'))
}
postclose `disagg_me_post'

preserve
    use "`disagg_me_report'", clear
    format inst_val marginal_effect standard_error t_stat p_val ci_lower ci_upper %12.4f
    export delimited using "$OUTPUT_INTEG/disaggregated_marginal_effects.csv", replace
    export delimited using "$OUTPUT_DISAGG/disaggregated_marginal_effects.csv", replace
    list, sepby(outcome resource_type) noobs abbreviate(20)
restore


// *****************************************************************************
// 7. Exportación de Tablas Formateadas en LaTeX
// *****************************************************************************

* Exportar la tabla econométrica final de modelos desagregados a LaTeX.
cap which esttab
if _rc == 0 {
    esttab M3_DISAGG_ECI M3_DISAGG_DIVX using "$OUTPUT_FINAL/table_resource_disaggregation_twfe.tex", replace ///
        b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
        stats(N N_g r2_within F p, labels("Observaciones" "Países" "R2 Within" "Estadístico F" "p-valor F") fmt(%9.0f %9.0f %9.4f %9.3f %9.4f)) ///
        mtitles("ECI (Complejidad)" "DIVX (Diversificación)") ///
        title("Modelo 3 Completo Desagregado: Hidrocarburos frente a Minería y Carbón") ///
        booktabs label alignment(c)
}

// *****************************************************************************
// 8. Diagnósticos de Series de Tiempo para Modelos Desagregados (Hidrocarburos vs. Minería)
// *****************************************************************************

local sb_disagg_eci_vars "rents_oil_gas inst rents_oil_gas_x_inst rents_mining rents_mining_x_inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin"
local sb_disagg_divx_vars "rents_oil_gas inst rents_oil_gas_x_inst rents_mining rents_mining_x_inst log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin"

// -----------------------------------------------------------------------------
// 8.1. Pruebas de Raíz Unitaria en Panel (Hidrocarburos y Minería)
// -----------------------------------------------------------------------------
tempname disagg_ur_post
tempfile disagg_ur_report
postfile `disagg_ur_post' str24 variable str16 spec double statistic double pvalue str24 conclusion using "`disagg_ur_report'", replace

foreach var in rents_oil_gas rents_mining {
    * Niveles con Drift
    capture quietly xtunitroot fisher `var', dfuller drift lags(1)
    if _rc == 0 {
        local stat = r(P)
        local pval = r(p_P)
        local conc "No Estacionaria (Raiz Unitaria)"
        if `pval' < 0.05 local conc "Estacionaria I(0)"
        post `disagg_ur_post' ("`var'") ("Niveles (Drift)") (`stat') (`pval') ("`conc'")
    }
    * Primeras Diferencias con Drift
    capture quietly xtunitroot fisher d.`var', dfuller drift lags(1)
    if _rc == 0 {
        local stat = r(P)
        local pval = r(p_P)
        local conc "I(1) Confirmado"
        if `pval' < 0.05 local conc "Estacionaria en d. (I(1))"
        post `disagg_ur_post' ("`var'") ("Diferencias (Drift)") (`stat') (`pval') ("`conc'")
    }
}
postclose `disagg_ur_post'

preserve
    use "`disagg_ur_report'", clear
    format statistic pvalue %12.4f
    export delimited using "$OUTPUT_INTEG/disagg_panel_unit_root_tests.csv", replace
    export delimited using "$OUTPUT_DISAGG/disagg_panel_unit_root_tests.csv", replace
restore


// -----------------------------------------------------------------------------
// 8.4. Quiebres Estructurales y Estabilidad Temporal (Superciclo Pre/Post 2014)
// -----------------------------------------------------------------------------
tempname disagg_sb_post
tempfile disagg_sb_report
postfile `disagg_sb_post' str12 model str24 period double beta_og double se_og double pval_og double beta_mn double se_mn double pval_mn using "`disagg_sb_report'", replace

* ECI Pre-2015 vs Post-2014
capture quietly reghdfe eci `sb_disagg_eci_vars' if sample_eci == 1 & year <= 2014, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - e(df_m)
    post `disagg_sb_post' ("ECI") ("Pre-2015 (1996-2014)") (_b[rents_oil_gas]) (_se[rents_oil_gas]) (2*ttail(`df', abs(_b[rents_oil_gas]/_se[rents_oil_gas]))) (_b[rents_mining]) (_se[rents_mining]) (2*ttail(`df', abs(_b[rents_mining]/_se[rents_mining])))
}
capture quietly reghdfe eci `sb_disagg_eci_vars' if sample_eci == 1 & year >= 2015, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - e(df_m)
    post `disagg_sb_post' ("ECI") ("Post-2014 (2015-2021)") (_b[rents_oil_gas]) (_se[rents_oil_gas]) (2*ttail(`df', abs(_b[rents_oil_gas]/_se[rents_oil_gas]))) (_b[rents_mining]) (_se[rents_mining]) (2*ttail(`df', abs(_b[rents_mining]/_se[rents_mining])))
}

* DIVX Pre-2015 vs Post-2014
capture quietly reghdfe divx `sb_disagg_divx_vars' if sample_divx == 1 & year <= 2014, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - e(df_m)
    post `disagg_sb_post' ("DIVX") ("Pre-2015 (1996-2014)") (_b[rents_oil_gas]) (_se[rents_oil_gas]) (2*ttail(`df', abs(_b[rents_oil_gas]/_se[rents_oil_gas]))) (_b[rents_mining]) (_se[rents_mining]) (2*ttail(`df', abs(_b[rents_mining]/_se[rents_mining])))
}
capture quietly reghdfe divx `sb_disagg_divx_vars' if sample_divx == 1 & year >= 2015, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - e(df_m)
    post `disagg_sb_post' ("DIVX") ("Post-2014 (2015-2021)") (_b[rents_oil_gas]) (_se[rents_oil_gas]) (2*ttail(`df', abs(_b[rents_oil_gas]/_se[rents_oil_gas]))) (_b[rents_mining]) (_se[rents_mining]) (2*ttail(`df', abs(_b[rents_mining]/_se[rents_mining])))
}
postclose `disagg_sb_post'

preserve
    use "`disagg_sb_report'", clear
    format beta_og se_og pval_og beta_mn se_mn pval_mn %12.4f
    export delimited using "$OUTPUT_INTEG/disagg_panel_structural_breaks.csv", replace
    export delimited using "$OUTPUT_DISAGG/disagg_panel_structural_breaks.csv", replace
restore


// -----------------------------------------------------------------------------
// 8.5. Autocorrelación AR(p) e Inferencia Comparativa Desagregada (Todas las variables)
// -----------------------------------------------------------------------------
tempname disagg_ar_post
tempfile disagg_ar_report
postfile `disagg_ar_post' str12 model str32 vce_type str24 variable double beta double se double pval using "`disagg_ar_report'", replace

* ECI Desagregado
capture quietly reghdfe eci `sb_disagg_eci_vars' if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - e(df_m)
    foreach var of local sb_disagg_eci_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * ttail(`df', abs(`b'/`se'))
            post `disagg_ar_post' ("ECI") ("Cluster-Robust (Pais)") ("`var'") (`b') (`se') (`p')
        }
    }
}
capture quietly xtscc eci `sb_disagg_eci_vars' i.year if sample_eci == 1, fe lag(2)
if _rc == 0 {
    local df = e(df_r)
    if missing("`df'") | "`df'" == "." local df = e(N) - 20
    foreach var of local sb_disagg_eci_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * ttail(`df', abs(`b'/`se'))
            post `disagg_ar_post' ("ECI") ("Driscoll-Kraay HAC (lag 2)") ("`var'") (`b') (`se') (`p')
        }
    }
}
capture quietly xtpcse eci `sb_disagg_eci_vars' i.country_id i.year if sample_eci == 1, correlation(ar1)
if _rc == 0 {
    foreach var of local sb_disagg_eci_vars {
        capture local b = _b[`var']
        capture local se = _se[`var']
        if _rc == 0 & !missing(`b') & !missing(`se') & `se' > 0 {
            local p = 2 * normal(-abs(`b'/`se'))
            post `disagg_ar_post' ("ECI") ("Panel PCSE (AR1)") ("`var'") (`b') (`se') (`p')
        }
    }
}
postclose `disagg_ar_post'

preserve
    use "`disagg_ar_report'", clear
    format beta se pval %12.4f
    export delimited using "$OUTPUT_INTEG/disagg_panel_autocorrelation_inference.csv", replace
    export delimited using "$OUTPUT_DISAGG/disagg_panel_autocorrelation_inference.csv", replace
restore



* Informar en consola la finalización exitosa del archivo 08.
display as result "---------------------------------------------------------"
display as result "Script 08: Modelos Desagregados TWFE completado con éxito."
display as result "Resultados exportados en: $OUTPUT_INTEG y $OUTPUT_DISAGG"
display as result "---------------------------------------------------------"

* Cerrar el registro de ejecución del archivo 08.
log close disagg_integ_log

