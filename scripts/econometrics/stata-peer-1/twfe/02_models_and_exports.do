// *********************************************
// Universidad: Universidad de Buenos Aires
// Facultad: Facultad de Ciencias Económicas
// Escuela: Escuela de Negocios y Administración Pública
// Programa: Maestría en Economía Aplicada
//
// Tipo de trabajo: Trabajo Final de Maestría (TFM)
// Título: Rentas extractivas y transformación estructural externa en economías
//        dependientes de recursos naturales no renovables del subsuelo (1996--2021)
// Autor: Julián Alberto Delgadillo Marín
// Director: Martín Grandes
//
// Archivo: 02_models_and_exports.do (Parte 2 de 2 - Secciones 5 a 8)
// Ubicación: scripts/econometrics/stata-peer-1/
// Fecha: Segundo Cuatrimestre 2026
// *********************************************

// *********************************************
// Configuración Inicial e Insumos de Estimación
// *********************************************

* Limpiar la sesión y cerrar registros previos
version 17.0
clear all
cls
macro drop _all
capture log close _all

* Configurar parámetros de ejecución
set more off
set varabbrev off
set type double
set linesize 255
set seed 20260729
set sortseed 20260729

* Verificar e instalar dependencias adicionales de inferencia si no están presentes
foreach pkg in boottest ftools reghdfe estout {
    capture which `pkg'
    if _rc {
        capture ssc install `pkg'
    }
}

* Localizar dinámicamente la raíz del proyecto con fallback absoluto infalible
local rel_path "data/processed/00_master_panel/master_panel_country_year.dta"

* Validar la integridad de los datos
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
                // Ruta absoluta predeterminada del repositorio
                local abs_path "C:/Users/julla/GitHub/master-thesis-project-applied-econ/`rel_path'"
                capture confirm file "`abs_path'"
                if !_rc {
                    quietly cd "C:/Users/julla/GitHub/master-thesis-project-applied-econ"
                }
                else {
                    display as error "Error: No se pudo encontrar el panel maestro."
                    exit 601
                }
            }
        }
    }
}

* Definir variables globales para las rutas del repositorio
global PROJECT_ROOT "`c(pwd)'"
global OUTPUT_ROOT              "$PROJECT_ROOT/outputs/econometrics/stata-peer-1/twfe"
global OUTPUT_SAMPLE            "$OUTPUT_ROOT/01_sample"
global OUTPUT_DIAGNOSTICS       "$OUTPUT_ROOT/02_diagnostics"
global OUTPUT_ECI               "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX              "$OUTPUT_ROOT/04_divx"
global OUTPUT_STABILITY         "$OUTPUT_ROOT/05_stability"
global OUTPUT_RESOURCE_DISAGG   "$OUTPUT_ROOT/06_resource_disaggregation"
global OUTPUT_FINAL             "$OUTPUT_ROOT/07_final"
global OUTPUT_LOGS              "$OUTPUT_ROOT/logs"

* Abrir el registro de ejecución en el archivo log de la parte 2
log using "$OUTPUT_LOGS/02_models_and_exports.log", text replace name(model_log)

* Confirmar la presencia del dataset de estimación preparado en la Parte 1
capture confirm file "$OUTPUT_SAMPLE/master_panel_sample.dta"
if _rc {
    display as error "Error: No se encontró $OUTPUT_SAMPLE/master_panel_sample.dta"
    display as error "Ejecute primero 01_data_prep_and_diagnostics.do"
    exit 601
}

// *********************************************
// 5. Modelo Principal: ECI (TWFE) [Ecuación 9.17]
// *********************************************

* Cargar la base de datos de estimación y declarar la estructura de panel
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

* 5.1. Definir conjunto de regresores con notación factorial para interacción
global ECI_REGRESSORS c.rents##c.inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin

* 5.2. Estimar el Modelo 1 Principal: ECI TWFE con rentas logaritmo log(1+x) [Ecuación 9.17 Base]
xtreg eci $ECI_REGRESSORS i.year if sample_eci==1, fe vce(cluster country_id)

* Guardar estimaciones del Modelo 1 en memoria y archivo .ster
estimates store ECI_TWFE_MAIN
estimates save "$OUTPUT_ECI/eci_twfe_main.ster", replace

* Verificar que la muestra utilizada coincide con los casos completos
assert e(sample) == sample_eci

* 5.3. Exportar tabla CSV detallada de coeficientes e intervalos de confianza
tempname eci_coef_post
tempfile eci_coef_report

* Definir estructura del postfile de coeficientes ECI
postfile `eci_coef_post' ///
    int order str32 term str100 variable_label str32 channel ///
    double coefficient standard_error t_statistic p_value ci_lower ci_upper ///
    using "`eci_coef_report'", replace

* Ejecutar la siguiente instrucción del bloque
local eci_terms rents inst rents_x_inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin
local critical_t = invttail(e(df_r), 0.025)
local term_order = 0

* Iterar sobre regresores para extraer estadísticas de ECI
foreach term of local eci_terms {
    local ++term_order

    // Evaluar condición de control de flujo
    if "`term'" == "rents_x_inst" {
        local b = _b[c.rents#c.inst]
        local se = _se[c.rents#c.inst]
        local term_label "RENTS x INST"
    }
    else {
        local b = _b[`term']
        local se = _se[`term']
        local term_label : variable label `term'
        if `"`term_label'"' == "" local term_label "`term'"
    }

    // Ejecutar la siguiente instrucción del bloque
    local channel "Controles económicos"
    if inlist("`term'", "rents", "inst", "rents_x_inst") local channel "Institucional"
    if inlist("`term'", "log_oilpc", "log_gaspc", "log_coalpc") local channel "Abundancia de recursos"
    if inlist("`term'", "hhi", "pexp", "fexp") local channel "Estructura exportadora"
    if inlist("`term'", "vol", "rer") local channel "Condiciones macroeconómicas"
    if inlist("`term'", "humcap", "innov", "net") local channel "Capacidades productivas"

    // Ejecutar la siguiente instrucción del bloque
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local low = `b' - `critical_t' * `se'
    local high = `b' + `critical_t' * `se'

    // Ejecutar la siguiente instrucción del bloque
    post `eci_coef_post' (`term_order') ("`term'") (`"`term_label'"') (`"`channel'"') (`b') (`se') (`t') (`p') (`low') (`high')
}
postclose `eci_coef_post'

* Exportar tabla de coeficientes ECI a CSV
preserve
    use "`eci_coef_report'", clear
    sort order
    format coefficient standard_error t_statistic ci_lower ci_upper %12.6f
    format p_value %10.6f
    export delimited using "$OUTPUT_ECI/eci_twfe_coefficients.csv", replace
    list term coefficient standard_error p_value ci_lower ci_upper, noobs abbreviate(24)
restore

* 5.4. Exportar el resumen general del modelo en CSV
tempname eci_sum_post
tempfile eci_sum_report

* Definir estructura del postfile de resumen ECI
postfile `eci_sum_post' ///
    str24 model str12 dependent int obs countries clusters years ///
    double r2_within r2_between r2_overall f_stat df_m df_r p_val rmse sigma_u sigma_e rho ///
    using "`eci_sum_report'", replace

* Guardar métricas del modelo ECI en el postfile
post `eci_sum_post' ("ECI_TWFE_MAIN") ("eci") (e(N)) (e(N_g)) (e(N_clust)) (23) ///
    (e(r2_w)) (e(r2_b)) (e(r2_o)) (e(F)) (e(df_m)) (e(df_r)) (e(p)) (e(rmse)) (e(sigma_u)) (e(sigma_e)) (e(rho))
postclose `eci_sum_post'

* Exportar el resumen del modelo ECI a CSV
preserve
    use "`eci_sum_report'", clear
    format r2_within r2_between r2_overall f_stat p_val rmse sigma_u sigma_e rho %12.6f
    export delimited using "$OUTPUT_ECI/eci_twfe_model_summary.csv", replace
restore

* 5.5. Realizar pruebas de hipótesis conjuntas por canal teórico
tempname eci_tests_post
tempfile eci_tests_report

* Definir estructura del postfile de pruebas F en ECI
postfile `eci_tests_post' int order str40 test str100 null_hypothesis double f_stat df1 df2 p_val using "`eci_tests_report'", replace

* Test 1: Canal institucional
test rents inst c.rents#c.inst
post `eci_tests_post' (1) ("Canal institucional") ("RENTS, INST y RENTSxINST son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 2: Canal de abundancia
test log_oilpc log_gaspc log_coalpc
post `eci_tests_post' (2) ("Canal de abundancia") ("Petróleo, gas y carbón son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 3: Canal estructural
test hhi pexp fexp
post `eci_tests_post' (3) ("Canal estructural") ("HHI, PEXP y FEXP son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 4: Canal macroeconómico
test vol rer
post `eci_tests_post' (4) ("Canal macroeconómico") ("VOL y RER son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 5: Capacidades productivas
test humcap innov net
post `eci_tests_post' (5) ("Capacidades productivas") ("HUMCAP, INNOV y NET son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 6: Controles económicos
test log_gdppc govcons fin
post `eci_tests_post' (6) ("Controles económicos") ("log(GDPPC), GOVCONS y FIN son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 7: Efectos fijos por año
testparm i.year
post `eci_tests_post' (7) ("Efectos fijos por año") ("Todos los dummies de año son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 8: Igualdad entre recursos
test (log_oilpc = log_gaspc) (log_oilpc = log_coalpc)
post `eci_tests_post' (8) ("Igualdad entre recursos") ("Coeficientes de petróleo, gas y carbón son iguales") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque
postclose `eci_tests_post'

* Exportar resultados de las pruebas F de ECI a CSV
preserve
    use "`eci_tests_report'", clear
    sort order
    format f_stat p_val %12.6f
    export delimited using "$OUTPUT_ECI/eci_twfe_channel_tests.csv", replace
    list test null_hypothesis f_stat p_val, noobs abbreviate(24)
restore

* 5.6. Estimar el Modelo 2: ECI TWFE con rentas en niveles [Sensibilidad]
xtreg eci rents inst c.rents#c.inst oilpc gaspc coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin i.year if sample_eci==1, fe vce(cluster country_id)
estimates store ECI_TWFE_LEVELS
estat ic   // AIC y BIC

* 5.7. Estimar el Modelo 3: ECI TWFE con reghdfe (efectos fijos de alto nivel)
cap which reghdfe
if _rc == 0 {
    reghdfe eci rents inst c.rents#c.inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin if sample_eci==1, absorb(country_id year) vce(cluster country_id)
    estimates store ECI_REGHDFE
}

* Comparar los modelos ECI agregados en una tabla en la consola
esttab ECI_TWFE_MAIN ECI_TWFE_LEVELS, se compress

// *********************************************
// 6. Modelo Complementario: DIVX (TWFE) [Ecuación 9.58]
// *********************************************

* Cargar la base de datos de estimación
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

* 6.1. Definir regresores excluyendo strictly HHI (identidad DIVX = 1 - HHI)
global DIVX_REGRESSORS c.rents##c.inst log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin

* 6.2. Estimar el Modelo 1: DIVX TWFE excluyendo HHI [Ecuación 9.58 Base]
xtreg divx $DIVX_REGRESSORS i.year if sample_divx==1, fe vce(cluster country_id)

* Guardar estimaciones del Modelo 1 en memoria y archivo .ster
estimates store DIVX_TWFE_MAIN
estimates save "$OUTPUT_DIVX/divx_twfe_main.ster", replace

* 6.3. Exportar coeficientes del modelo DIVX en CSV
tempname divx_coef_post
tempfile divx_coef_report

* Definir estructura del postfile de coeficientes DIVX
postfile `divx_coef_post' ///
    int order str32 term str100 variable_label str32 channel ///
    double coefficient standard_error t_statistic p_value ci_lower ci_upper ///
    using "`divx_coef_report'", replace

* Ejecutar la siguiente instrucción del bloque
local divx_terms rents inst rents_x_inst log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin
local critical_t = invttail(e(df_r), 0.025)
local term_order = 0

* Iterar sobre regresores para extraer estadísticas de DIVX
foreach term of local divx_terms {
    local ++term_order

    // Evaluar condición de control de flujo
    if "`term'" == "rents_x_inst" {
        local b = _b[c.rents#c.inst]
        local se = _se[c.rents#c.inst]
        local term_label "RENTS x INST"
    }
    else {
        local b = _b[`term']
        local se = _se[`term']
        local term_label : variable label `term'
        if `"`term_label'"' == "" local term_label "`term'"
    }

    // Ejecutar la siguiente instrucción del bloque
    local channel "Controles económicos"
    if inlist("`term'", "rents", "inst", "rents_x_inst") local channel "Institucional"
    if inlist("`term'", "log_oilpc", "log_gaspc", "log_coalpc") local channel "Abundancia de recursos"
    if inlist("`term'", "pexp", "fexp") local channel "Estructura exportadora"
    if inlist("`term'", "vol", "rer") local channel "Condiciones macroeconómicas"
    if inlist("`term'", "humcap", "innov", "net") local channel "Capacidades productivas"

    // Ejecutar la siguiente instrucción del bloque
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local low = `b' - `critical_t' * `se'
    local high = `b' + `critical_t' * `se'

    // Ejecutar la siguiente instrucción del bloque
    post `divx_coef_post' (`term_order') ("`term'") (`"`term_label'"') (`"`channel'"') (`b') (`se') (`t') (`p') (`low') (`high')
}
postclose `divx_coef_post'

* Exportar tabla de coeficientes DIVX a CSV
preserve
    use "`divx_coef_report'", clear
    sort order
    format coefficient standard_error t_statistic ci_lower ci_upper %12.6f
    format p_value %10.6f
    export delimited using "$OUTPUT_DIVX/divx_twfe_coefficients.csv", replace
    list term coefficient standard_error p_value ci_lower ci_upper, noobs abbreviate(24)
restore

* 6.4. Exportar el resumen general del modelo DIVX en CSV
tempname divx_sum_post
tempfile divx_sum_report

* Definir estructura del postfile de resumen DIVX
postfile `divx_sum_post' ///
    str24 model str12 dependent int obs countries clusters years ///
    double r2_within r2_between r2_overall f_stat df_m df_r p_val rmse sigma_u sigma_e rho ///
    using "`divx_sum_report'", replace

* Guardar métricas del modelo DIVX en el postfile
post `divx_sum_post' ("DIVX_TWFE_MAIN") ("divx") (e(N)) (e(N_g)) (e(N_clust)) (23) ///
    (e(r2_w)) (e(r2_b)) (e(r2_o)) (e(F)) (e(df_m)) (e(df_r)) (e(p)) (e(rmse)) (e(sigma_u)) (e(sigma_e)) (e(rho))
postclose `divx_sum_post'

* Exportar el resumen del modelo DIVX a CSV
preserve
    use "`divx_sum_report'", clear
    format r2_within r2_between r2_overall f_stat p_val rmse sigma_u sigma_e rho %12.6f
    export delimited using "$OUTPUT_DIVX/divx_twfe_model_summary.csv", replace
restore

* 6.5. Realizar pruebas de hipótesis conjuntas por canal para DIVX
tempname divx_tests_post
tempfile divx_tests_report

* Definir estructura del postfile de pruebas F en DIVX
postfile `divx_tests_post' int order str40 test str100 null_hypothesis double f_stat df1 df2 p_val using "`divx_tests_report'", replace

* Test 1: Canal institucional
test rents inst c.rents#c.inst
post `divx_tests_post' (1) ("Canal institucional") ("RENTS, INST y RENTSxINST son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 2: Canal de abundancia
test log_oilpc log_gaspc log_coalpc
post `divx_tests_post' (2) ("Canal de abundancia") ("Petróleo, gas y carbón son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 3: Canal estructural
test pexp fexp
post `divx_tests_post' (3) ("Canal estructural") ("PEXP y FEXP son conjuntamente cero (HHI excluido)") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 4: Canal macroeconómico
test vol rer
post `divx_tests_post' (4) ("Canal macroeconómico") ("VOL y RER son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 5: Capacidades productivas
test humcap innov net
post `divx_tests_post' (5) ("Capacidades productivas") ("HUMCAP, INNOV y NET son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 6: Controles económicos
test log_gdppc govcons fin
post `divx_tests_post' (6) ("Controles económicos") ("log(GDPPC), GOVCONS y FIN son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 7: Efectos fijos por año
testparm i.year
post `divx_tests_post' (7) ("Efectos fijos por año") ("Todos los dummies de año son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 8: Igualdad entre recursos
test (log_oilpc = log_gaspc) (log_oilpc = log_coalpc)
post `divx_tests_post' (8) ("Igualdad entre recursos") ("Coeficientes de petróleo, gas y carbón son iguales") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque
postclose `divx_tests_post'

* Exportar resultados de las pruebas F de DIVX a CSV
preserve
    use "`divx_tests_report'", clear
    sort order
    format f_stat p_val %12.6f
    export delimited using "$OUTPUT_DIVX/divx_twfe_channel_tests.csv", replace
    list test null_hypothesis f_stat p_val, noobs abbreviate(24)
restore

* 6.6. Estimar Modelo 2 de DIVX con rentas en niveles [Sensibilidad]
xtreg divx rents inst c.rents#c.inst oilpc gaspc coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin i.year if sample_divx==1, fe vce(cluster country_id)
estimates store DIVX_TWFE_LEVELS
estat ic   // AIC y BIC

* 6.7. Estimar Modelo 3 de DIVX con reghdfe
cap which reghdfe
if _rc == 0 {
    reghdfe divx rents inst c.rents#c.inst log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin if sample_divx==1, absorb(country_id year) vce(cluster country_id)
    estimates store DIVX_REGHDFE
}

* Comparar los modelos DIVX en la consola
esttab DIVX_TWFE_MAIN DIVX_TWFE_LEVELS, se compress

// *********************************************
// 7. Estabilidad, Efectos Marginales y Desagregación
// *********************************************

* Cargar la base de datos de estimación
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

* 7.1. Calcular percentiles observados del índice INST en la muestra de estimación
quietly summarize inst if sample_eci == 1, detail
local p10 = r(p10)
local p25 = r(p25)
local p50 = r(p50)
local p75 = r(p75)
local p90 = r(p90)
local inst_vals "`p10' `p25' `p50' `p75' `p90'"
local inst_lbls "P10 P25 P50 P75 P90"

* 7.2. Calcular efectos marginales condicionales d(Y)/d(RENTS) según percentiles de INST
tempname margins_post
tempfile margins_report

* Definir estructura del postfile de efectos marginales
postfile `margins_post' ///
    str8 model str4 percentile double inst_val marginal_effect standard_error t_stat p_val ci_lower ci_upper str12 significance ///
    using "`margins_report'", replace

* --- Modelo ECI ---
quietly xtreg eci $ECI_REGRESSORS i.year if sample_eci == 1, fe vce(cluster country_id)
margins, dydx(rents) at(inst=(`inst_vals'))
matrix eci_m = r(table)

* Generar visualización gráfica
marginsplot, recast(line) recastci(rarea) plotopts(lcolor(navy) lwidth(medthick)) ciopts(color(navy%25) lcolor(navy%45)) ///
    yline(0, lcolor(gs8) lpattern(dash)) xlabel(`p10' "P10" `p25' "P25" `p50' "P50" `p75' "P75" `p90' "P90", labsize(small) angle(45)) ///
    ylabel(, labsize(small) angle(horizontal)) ///
    title("ECI: Asociación marginal estimada de RENTS según INST", size(medium)) ///
    ytitle("Asociación marginal d(ECI)/d(RENTS)") xtitle("Percentil de calidad institucional (INST)") ///
    name(eci_margins_plot, replace)
cap graph export "$OUTPUT_STABILITY/eci_rents_marginal_effect_by_inst.pdf", replace
cap graph export "$OUTPUT_STABILITY/eci_rents_marginal_effect_by_inst.png", width(2400) replace

* Guardar en postfile cada efecto marginal de ECI por percentil
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
quietly xtreg divx $DIVX_REGRESSORS i.year if sample_divx == 1, fe vce(cluster country_id)
margins, dydx(rents) at(inst=(`inst_vals'))
matrix divx_m = r(table)

* Generar visualización gráfica
marginsplot, recast(line) recastci(rarea) plotopts(lcolor(maroon) lwidth(medthick)) ciopts(color(maroon%25) lcolor(maroon%45)) ///
    yline(0, lcolor(gs8) lpattern(dash)) xlabel(`p10' "P10" `p25' "P25" `p50' "P50" `p75' "P75" `p90' "P90", labsize(small) angle(45)) ///
    ylabel(, labsize(small) angle(horizontal)) ///
    title("DIVX: Asociación marginal estimada de RENTS según INST", size(medium)) ///
    ytitle("Asociación marginal d(DIVX)/d(RENTS)") xtitle("Percentil de calidad institucional (INST)") ///
    name(divx_margins_plot, replace)
cap graph export "$OUTPUT_STABILITY/divx_rents_marginal_effect_by_inst.pdf", replace
cap graph export "$OUTPUT_STABILITY/divx_rents_marginal_effect_by_inst.png", width(2400) replace

* Guardar en postfile cada efecto marginal de DIVX por percentil
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

* Exportar los resultados consolidados de efectos marginales a CSV
preserve
    use "`margins_report'", clear
    sort model inst_val
    format inst_val marginal_effect standard_error t_stat p_val ci_lower ci_upper %12.6f
    export delimited using "$OUTPUT_STABILITY/rents_marginal_effects_by_inst.csv", replace
    list, sepby(model) noobs abbreviate(24)
restore

* 7.3. Síntesis de prueba de igualdad de coeficientes entre recursos (Petróleo, Gas y Carbón)
tempname res_post
tempfile res_report

* Definir la estructura del reporte de igualdad de coeficientes de recursos
postfile `res_post' str8 model str90 null_hypothesis double f_stat df1 df2 p_val str16 decision using "`res_report'", replace

* Probar igualdad de coeficientes de recursos en ECI
quietly xtreg eci $ECI_REGRESSORS i.year if sample_eci == 1, fe vce(cluster country_id)
test (log_oilpc = log_gaspc) (log_oilpc = log_coalpc)
local d_eci "No rechazar H0"
if r(p) < 0.05 local d_eci "Rechazar H0"
post `res_post' ("ECI") ("Coeficientes de petróleo, gas y carbón son iguales") (r(F)) (r(df)) (r(df_r)) (r(p)) ("`d_eci'")

* Probar igualdad de coeficientes de recursos en DIVX
quietly xtreg divx $DIVX_REGRESSORS i.year if sample_divx == 1, fe vce(cluster country_id)
test (log_oilpc = log_gaspc) (log_oilpc = log_coalpc)
local d_divx "No rechazar H0"
if r(p) < 0.05 local d_divx "Rechazar H0"
post `res_post' ("DIVX") ("Coeficientes de petróleo, gas y carbón son iguales") (r(F)) (r(df)) (r(df_r)) (r(p)) ("`d_divx'")

* Ejecutar la siguiente instrucción del bloque
postclose `res_post'

* Exportar el reporte de igualdad de coeficientes de recursos a CSV
preserve
    use "`res_report'", clear
    format f_stat p_val %12.6f
    export delimited using "$OUTPUT_STABILITY/resource_coefficient_equality.csv", replace
    list, noobs abbreviate(24)
restore

* 7.4. Reestimación omitiendo un país a la vez (Leave-One-Country-Out Jackknife across 49 Countries)
quietly levelsof country_id if sample_eci == 1, local(c_list)
tempname loo_post
tempfile loo_report

* Definir estructura del postfile de reestimaciones Jackknife
postfile `loo_post' str8 model double excluded_id str3 excluded_iso3 str24 term double base_b b se p obs countries using "`loo_report'", replace

* Obtener betas base de RENTS
quietly xtreg eci $ECI_REGRESSORS i.year if sample_eci == 1, fe vce(cluster country_id)
local base_eci_b = _b[rents]
quietly xtreg divx $DIVX_REGRESSORS i.year if sample_divx == 1, fe vce(cluster country_id)
local base_divx_b = _b[rents]

* Bucle Jackknife de sensibilidad omitiendo un país por iteración
foreach cid of local c_list {
    quietly levelsof country_iso3_code if country_id == `cid', local(c_iso3) clean

    // ECI
    quietly xtreg eci $ECI_REGRESSORS i.year if sample_eci == 1 & country_id != `cid', fe vce(cluster country_id)
    local p_val = 2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
    post `loo_post' ("ECI") (`cid') ("`c_iso3'") ("RENTS") (`base_eci_b') (_b[rents]) (_se[rents]) (`p_val') (e(N)) (e(N_g))

    // DIVX
    quietly xtreg divx $DIVX_REGRESSORS i.year if sample_divx == 1 & country_id != `cid', fe vce(cluster country_id)
    local p_val = 2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
    post `loo_post' ("DIVX") (`cid') ("`c_iso3'") ("RENTS") (`base_divx_b') (_b[rents]) (_se[rents]) (`p_val') (e(N)) (e(N_g))
}
postclose `loo_post'

* Exportar el resumen de sensibilidad del Jackknife a CSV
preserve
    use "`loo_report'", clear
    gen byte sign_change = (sign(b) != sign(base_b))
    gen byte sig_5 = (p < 0.05)
    export delimited using "$OUTPUT_STABILITY/leave_one_country_out.csv", replace

    * Ejecutar la siguiente instrucción del bloque
    collapse (count) reps=b (firstnm) base_b (min) min_b=b min_p=p (max) max_b=b max_p=p (sum) sign_changes=sign_change sig_5, by(model term)
    format base_b min_b max_b min_p max_p %12.6f
    export delimited using "$OUTPUT_STABILITY/leave_one_country_out_summary.csv", replace
    list, sepby(model) noobs abbreviate(24)
restore

* 7.5. Inferencia complementaria mediante Wild Cluster Bootstrap (boottest)
cap which boottest
if _rc == 0 {
    tempname boot_post
    tempfile boot_report

    // Definir estructura del postfile de inferencia bootstrap no paramétrica
    postfile `boot_post' str8 model str24 term double conv_b conv_p boot_p ci_low ci_high reps str12 weight using "`boot_report'", replace

    // ECI RENTS
    quietly xtreg eci $ECI_REGRESSORS i.year if sample_eci == 1, fe vce(cluster country_id)
    local cp = 2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
    boottest rents, cluster(country_id) reps(9999) seed(20260729) nograph
    matrix boot_ci = r(CI)
    post `boot_post' ("ECI") ("RENTS") (_b[rents]) (`cp') (r(p)) (el(boot_ci,1,1)) (el(boot_ci,1,2)) (r(reps)) ("`r(weighttype)'")

    // ECI Interaction
    boottest c.rents#c.inst, cluster(country_id) reps(9999) seed(20260730) nograph
    matrix boot_ci = r(CI)
    local cp = 2 * ttail(e(df_r), abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))
    post `boot_post' ("ECI") ("RENTS x INST") (_b[c.rents#c.inst]) (`cp') (r(p)) (el(boot_ci,1,1)) (el(boot_ci,1,2)) (r(reps)) ("`r(weighttype)'")

    // DIVX RENTS
    quietly xtreg divx $DIVX_REGRESSORS i.year if sample_divx == 1, fe vce(cluster country_id)
    local cp = 2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
    boottest rents, cluster(country_id) reps(9999) seed(20260731) nograph
    matrix boot_ci = r(CI)
    post `boot_post' ("DIVX") ("RENTS") (_b[rents]) (`cp') (r(p)) (el(boot_ci,1,1)) (el(boot_ci,1,2)) (r(reps)) ("`r(weighttype)'")

    // DIVX Interaction
    boottest c.rents#c.inst, cluster(country_id) reps(9999) seed(20260732) nograph
    matrix boot_ci = r(CI)
    local cp = 2 * ttail(e(df_r), abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))
    post `boot_post' ("DIVX") ("RENTS x INST") (_b[c.rents#c.inst]) (`cp') (r(p)) (el(boot_ci,1,1)) (el(boot_ci,1,2)) (r(reps)) ("`r(weighttype)'")

    // Ejecutar la siguiente instrucción del bloque
    postclose `boot_post'

    // Exportar el reporte Wild Cluster Bootstrap a CSV
    preserve
        use "`boot_report'", clear
        format conv_b conv_p boot_p ci_low ci_high %12.6f
        export delimited using "$OUTPUT_STABILITY/wild_cluster_bootstrap.csv", replace
        list, sepby(model) noobs abbreviate(24)
    restore
}

* Restaurar estimación base DIVX principal para exportación
estimates restore DIVX_TWFE_MAIN

// *********************************************
// 8. Exportación de Resultados y Conclusiones
// *********************************************

* Exportar las tablas formateadas finales a LaTeX y Texto
cap which esttab
if _rc == 0 {
    // Exportar Tabla Principal ECI vs DIVX
    esttab ECI_TWFE_MAIN DIVX_TWFE_MAIN using "$OUTPUT_FINAL/table_eci_divx_twfe.tex", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        title("Modelos Econométricos Principales: ECI (Eq. 9.17) y DIVX (Eq. 9.58)") ///
        mtitles("ECI (Complejidad)" "DIVX (Diversificación)") ///
        booktabs alignment(c) drop(*.year) ///
        stats(N N_g r2_o, labels("Observaciones" "Países" "R2 overall"))

    // Ejecutar la siguiente instrucción del bloque
    esttab ECI_TWFE_MAIN DIVX_TWFE_MAIN using "$OUTPUT_FINAL/table_eci_divx_twfe.txt", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        mtitles("ECI (Complejidad)" "DIVX (Diversificación)") ///
        drop(*.year) ///
        stats(N N_g r2_o, labels("Observaciones" "Países" "R2 overall"))

    // Exportar Tabla de Sensibilidad (Log Rentas vs. Rentas en Niveles)
    esttab ECI_TWFE_MAIN ECI_TWFE_LEVELS using "$OUTPUT_FINAL/table_eci_robustness.tex", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        title("Sensibilidad del Modelo Principal ECI (Log vs. Niveles)") ///
        mtitles("Log Rentas (Base)" "Rentas Niveles") ///
        booktabs alignment(c) drop(*.year) ///
        stats(N N_g r2_o, labels("Observaciones" "Países" "R2 overall"))
}
else {
    // Mostrar la tabla comparativa en consola si esttab no está instalado
    estimates table ECI_TWFE_MAIN DIVX_TWFE_MAIN, b(%8.3f) se(%8.3f) stats(N r2)
}

* Informar en consola la finalización exitosa de la Parte 2
display as result "---------------------------------------------------------"
display as result "Parte 2 (Secciones 5 a 8) completada con éxito en stata-peer-1."
display as result "Tablas LaTeX exportadas en: $OUTPUT_FINAL"
display as result "---------------------------------------------------------"

* Cerrar el archivo de registro de ejecución de la Parte 2
log close model_log
