* *********************************************
* Universidad: Universidad de Buenos Aires
* Facultad: Facultad de Ciencias Económicas
* Escuela: Escuela de Negocios y Administración Pública
* Programa: Maestría en Economía Aplicada
*
* Tipo de trabajo: Trabajo Final de Maestría (TFM)
* Título: Rentas extractivas y transformación estructural externa en economías
*        dependientes de recursos naturales no renovables del subsuelo (1996--2021)
* Autor: Julián Alberto Delgadillo Marín
* Director: Martín Grandes
*
* Archivo: 03_resource_disaggregation.do (Parte 3 de 3 - Secciones 9 a 14)
* Ubicación: scripts/econometrics/stata-peer-1/
* Contenido: Análisis econométrico desagregado (Hidrocarburos vs. Minería + Carbón)
* Requisitos: Completar archivos 01 y 02 antes de ejecutar esta extensión
* Fecha: Segundo Cuatrimestre 2026
* *********************************************

* *********************************************
* INICIALIZACIÓN DEL ARCHIVO 03
* *********************************************

* 0.1. Establecer la versión de Stata 17.0 y limpiar la memoria activa del sistema
version 17.0
clear all
cls
macro drop _all
capture log close _all

* 0.2. Fijar configuraciones globales de ejecución, semillas reproducibles y precisión numérica
set more off
set varabbrev off
set type double
set linesize 255
set seed 20260729
set sortseed 20260729

* 0.3. Comprobar e instalar paquetes de Stata requeridos si no están previamente instalados
foreach pkg in boottest ftools reghdfe estout xttest3 {
    capture which `pkg'
    if _rc {
        capture ssc install `pkg'
    }
}

* 0.4. Algoritmo de localización dinámica de la raíz del proyecto con soporte multi-nivel
local rel_path "data/processed/00_master_panel/master_panel_country_year.dta"

* Validar la integridad de los datos
capture confirm file "`rel_path'"
if !_rc {
    // Stata ya se encuentra posicionado en el directorio raíz del repositorio
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
                // Definir ruta absoluta estandarizada como mecanismo de seguridad final
                local abs_path "C:/Users/julla/GitHub/master-thesis-project-applied-econ/`rel_path'"
                capture confirm file "`abs_path'"
                if !_rc {
                    quietly cd "C:/Users/julla/GitHub/master-thesis-project-applied-econ"
                }
                else {
                    display as error "Error crítico: No se pudo localizar la base de datos maestra."
                    exit 601
                }
            }
        }
    }
}

* 0.5. Definición de globales del sistema para las rutas de salida de stata-peer-1
global PROJECT_ROOT "`c(pwd)'"
global OUTPUT_ROOT               "$PROJECT_ROOT/outputs/econometrics/stata-peer-1"
global OUTPUT_SAMPLE             "$OUTPUT_ROOT/01_sample"
global OUTPUT_DIAGNOSTICS        "$OUTPUT_ROOT/02_diagnostics"
global OUTPUT_ECI                "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX               "$OUTPUT_ROOT/04_divx"
global OUTPUT_FINAL              "$OUTPUT_ROOT/06_final"
global OUTPUT_DISAGG             "$OUTPUT_ROOT/07_resource_disaggregation"
global OUTPUT_DISAGG_DESIGN      "$OUTPUT_DISAGG/00_design"
global OUTPUT_DISAGG_DIAGNOSTICS "$OUTPUT_DISAGG/02_diagnostics"
global OUTPUT_DISAGG_ECI         "$OUTPUT_DISAGG/03_eci"
global OUTPUT_DISAGG_DIVX        "$OUTPUT_DISAGG/04_divx"
global OUTPUT_DISAGG_STABILITY   "$OUTPUT_DISAGG/05_stability"
global OUTPUT_DISAGG_FINAL       "$OUTPUT_DISAGG/06_final"
global OUTPUT_DISAGG_LOGS        "$OUTPUT_DISAGG/logs"

// Crear la estructura de carpetas exclusiva para la desagregación de recursos
capture mkdir "$OUTPUT_ROOT"
capture mkdir "$OUTPUT_DISAGG"
capture mkdir "$OUTPUT_DISAGG_DESIGN"
capture mkdir "$OUTPUT_DISAGG_DIAGNOSTICS"
capture mkdir "$OUTPUT_DISAGG_ECI"
capture mkdir "$OUTPUT_DISAGG_DIVX"
capture mkdir "$OUTPUT_DISAGG_STABILITY"
capture mkdir "$OUTPUT_DISAGG_FINAL"
capture mkdir "$OUTPUT_DISAGG_LOGS"

* 0.6. Iniciar el registro de log exclusivo para la Parte 3 (Secciones 9 a 14) en la carpeta de desagregación
log using "$OUTPUT_DISAGG_LOGS/03_resource_disaggregation.log", text replace name(disagg_log)

* 0.7. Verificar que el dataset procesado por el script 01 y resúmenes del script 02 estén disponibles
capture confirm file "$OUTPUT_SAMPLE/master_panel_sample.dta"
if _rc {
    display as error "Error: No se encontró la base analítica en $OUTPUT_SAMPLE/master_panel_sample.dta"
    display as error "Debe ejecutar primero el script 01_data_prep_and_diagnostics.do"
    exit 601
}

* Validar la integridad de los datos
capture confirm file "$OUTPUT_ECI/eci_twfe_model_summary.csv"
if _rc {
    display as error "Error: No se encontró el resumen ECI agregado en $OUTPUT_ECI/eci_twfe_model_summary.csv"
    display as error "Debe ejecutar primero el script 02_models_and_exports.do"
    exit 601
}

* Validar la integridad de los datos
capture confirm file "$OUTPUT_DIVX/divx_twfe_model_summary.csv"
if _rc {
    display as error "Error: No se encontró el resumen DIVX agregado en $OUTPUT_DIVX/divx_twfe_model_summary.csv"
    display as error "Debe ejecutar primero el script 02_models_and_exports.do"
    exit 601
}

* 0.8. Cargar el dataset analítico maestro y declarar la estructura de panel de datos
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

// *********************************************
// 9. Diseño de la Desagregación de RENTS
// *********************************************

* 9.1. Comprobar la presencia de las dos variables desagregadas numéricas en el panel analítico:
* - Componente 1: RENTS_OIL_GAS (Rentas de petróleo + gas natural en % del PIB)
* - Componente 2: RENTS_MINING (Rentas de minerales + metales + carbón en % del PIB)
foreach var in rents rents_oil_gas rents_mining {
    capture confirm numeric variable `var'
    if _rc {
        display as error "Error: La variable `var' debe ser numérica."
        exit 109
    }
}

* 9.2. Validar coincidencia de valores faltantes (missingness pattern match)
quietly count if missing(rents) != (missing(rents_oil_gas) | missing(rents_mining))
assert r(N) == 0

* 9.3. Verificar empíricamente la identidad contable contruida: RENTS = RENTS_OIL_GAS + RENTS_MINING (máxima brecha <= 1e-10)
tempvar rents_gap
generate double `rents_gap' = abs(rents - rents_oil_gas - rents_mining) if !missing(rents, rents_oil_gas, rents_mining)
quietly summarize `rents_gap', meanonly
assert r(max) <= 1e-10

* 9.4. Verificar los límites de dominio porcentual (0 a 100) para las rentas desagregadas
foreach var in rents_oil_gas rents_mining {
    assert inrange(`var', 0, 100) if !missing(`var')
}

* 9.5. Generar y etiquetar explícitamente los términos de interacción con calidad institucional (INST)
capture drop rents_oil_gas_x_inst rents_mining_x_inst
generate double rents_oil_gas_x_inst = rents_oil_gas * inst if !missing(rents_oil_gas, inst)
generate double rents_mining_x_inst  = rents_mining  * inst if !missing(rents_mining, inst)
label variable rents_oil_gas_x_inst "RENTS_OIL_GAS x INST"
label variable rents_mining_x_inst  "RENTS_MINING x INST"

* 9.6. Definir vectores globales de regresores principales (especificación base)
global ECI_DISAGG_REGRESSORS  c.rents_oil_gas##c.inst c.rents_mining##c.inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin
global DIVX_DISAGG_REGRESSORS c.rents_oil_gas##c.inst c.rents_mining##c.inst log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin

* 9.7. Definir vectores globales de regresores alternativos para análisis de sensibilidad (sin controles per cápita log_oilpc, log_gaspc, log_coalpc)
global ECI_DISAGG_NO_PC  c.rents_oil_gas##c.inst c.rents_mining##c.inst hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin
global DIVX_DISAGG_NO_PC c.rents_oil_gas##c.inst c.rents_mining##c.inst pexp fexp vol rer humcap innov net log_gdppc govcons fin

* 9.8. Notificar la finalización exitosa de la Sección 9 en la consola de Stata
display as result "Sección 9 completada: Diseño de la desagregación validado, identidades contables verificadas y variables de interacción generadas."

// *********************************************
// 10. Preparación y Diagnósticos de los Componentes
// *********************************************

* 10.1. Verificar la restricción de no negatividad de las rentas desagregadas
assert rents_oil_gas >= 0 if !missing(rents_oil_gas)
assert rents_mining  >= 0 if !missing(rents_mining)

* 10.2. Inicializar el postfile de memoria para almacenar el perfil estadístico completo de componentes
tempname profile_post
tempfile profile_report

* Definir la estructura de columnas y tipos de datos del reporte de perfil
postfile `profile_post' str24 variable long grid_observations long available_grid long missing_grid double coverage_grid_percent int countries_available int first_year int last_year long sample_observations long sample_zeros double sample_zero_percent mean sd min p1 p5 p25 median p75 p95 p99 max skewness using "`profile_report'", replace

* Iterar sobre cada componente para calcular métricas descriptivas, cobertura y asimetría
foreach var in rents_oil_gas rents_mining {
    quietly count
    local grid_n = r(N)
    quietly count if !missing(`var')
    local available_n = r(N)
    local missing_n = `grid_n' - `available_n'
    local coverage = 100 * `available_n' / `grid_n'
    quietly levelsof country_id if !missing(`var'), local(available_ids)
    local available_countries : word count `available_ids'
    quietly summarize year if !missing(`var'), meanonly
    local first_year = r(min)
    local last_year = r(max)
    quietly count if sample_eci == 1
    local sample_n = r(N)
    quietly count if sample_eci == 1 & `var' == 0
    local zero_n = r(N)
    local zero_percent = 100 * `zero_n' / `sample_n'
    quietly summarize `var' if sample_eci == 1, detail
    post `profile_post' ("`var'") (`grid_n') (`available_n') (`missing_n') (`coverage') (`available_countries') (`first_year') (`last_year') (`sample_n') (`zero_n') (`zero_percent') (r(mean)) (r(sd)) (r(min)) (r(p1)) (r(p5)) (r(p25)) (r(p50)) (r(p75)) (r(p95)) (r(p99)) (r(max)) (r(skewness))
}
postclose `profile_post'

* Exportar el reporte de perfil estadístico de componentes a un archivo CSV formateado
preserve
    use "`profile_report'", clear
    format coverage_grid_percent sample_zero_percent %9.2f
    format mean sd min p1 p5 p25 median p75 p95 p99 max skewness %12.6f
    export delimited using "$OUTPUT_DISAGG_DIAGNOSTICS/component_profile.csv", replace
restore

* 10.3. Estructurar postfile para descomposición de varianza Within/Between (xtsum) de componentes
tempname disagg_var_post
tempfile disagg_var_report

* Definir la estructura de variables del postfile de variación panel
postfile `disagg_var_post' str24 variable long observations int countries double average_periods mean double sd_overall sd_between sd_within within_sd_ratio using "`disagg_var_report'", replace

* Iterar sobre las variables de rentas e interacciones para calcular indicadores panel
foreach var in rents_oil_gas rents_mining rents_oil_gas_x_inst rents_mining_x_inst {
    quietly xtsum `var' if sample_eci == 1
    local within_ratio = r(sd_w) / r(sd)
    post `disagg_var_post' ("`var'") (r(N)) (r(n)) (r(Tbar)) (r(mean)) (r(sd)) (r(sd_b)) (r(sd_w)) (`within_ratio')
}
postclose `disagg_var_post'

* Exportar el reporte de descomposición de varianza de los componentes a formato CSV
preserve
    use "`disagg_var_report'", clear
    format average_periods mean sd_overall sd_between sd_within within_sd_ratio %12.4f
    export delimited using "$OUTPUT_DISAGG_DIAGNOSTICS/disaggregated_panel_variation.csv", replace
restore

* 10.4. Exportar la matriz de correlaciones focales entre rentas desagregadas, interacciones y controles per cápita
local focal_vars rents_oil_gas rents_mining inst rents_oil_gas_x_inst rents_mining_x_inst log_oilpc log_gaspc log_coalpc
quietly correlate `focal_vars' if sample_eci == 1
matrix focal_correlations = r(C)

* Convertir la matriz de correlaciones a dataset y exportarla a CSV
preserve
    clear
    svmat double focal_correlations, names(col)
    generate str28 variable = ""
    local row_number = 1
    foreach var of local focal_vars {
        replace variable = "`var'" in `row_number'
        local ++row_number
    }
    order variable
    export delimited using "$OUTPUT_DISAGG_DIAGNOSTICS/focal_correlation_matrix.csv", replace
restore

* 10.5. Estructurar postfile para evaluar colinealidad Within (VIF) del modelo desagregado
tempname vif_disagg_post
tempfile vif_disagg_report

* Definir la estructura de variables para el reporte VIF Within
postfile `vif_disagg_post' str8 model str24 variable double vif str12 assessment using "`vif_disagg_report'", replace

* Definir lista de regresores desagregados para la transformación de residuos Within
local disagg_regressors_eci "rents_oil_gas rents_mining inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin"

* Obtener los residuos de la proyección sobre efectos fijos de país y año para cada regresor
foreach var of local disagg_regressors_eci {
    capture drop within_`var'
    quietly regress `var' i.country_id i.year if sample_eci == 1
    predict double within_`var' if e(sample), residuals
}

* Estimar regresiones auxiliares de residuos para obtener el VIF Within por regresor
foreach target of local disagg_regressors_eci {
    local remaining : list disagg_regressors_eci - target
    local within_remaining ""
    foreach var of local remaining {
        local within_remaining "`within_remaining' within_`var'"
    }
    quietly regress within_`target' `within_remaining' if sample_eci == 1
    local vif_value = 1 / (1 - e(r2))
    local vif_assessment "LOW"
    if `vif_value' >= 5  local vif_assessment "REVIEW"
    if `vif_value' >= 10 local vif_assessment "HIGH"
    post `vif_disagg_post' ("ECI_DISAGG") ("`target'") (`vif_value') ("`vif_assessment'")
}
postclose `vif_disagg_post'

* Exportar los resultados de VIF Within desagregado a un archivo CSV
preserve
    use "`vif_disagg_report'", clear
    gsort -vif
    format vif %12.4f
    export delimited using "$OUTPUT_DISAGG_DIAGNOSTICS/vif_disaggregated_models.csv", replace
restore

* Limpiar variables temporales de residuos Within creadas en memoria
foreach var of local disagg_regressors_eci {
    capture drop within_`var'
}

* 10.6. Diagnóstico de observaciones influyentes en modelos desagregados (Cook's distance, leverage y residuos studentizados)
tempname influence_post
tempfile influence_report

* Definir la estructura de variables del reporte de observaciones influyentes
postfile `influence_post' str8 model long total_obs int params double leverage_cutoff cooks_cutoff long flagged_total flagged_leverage flagged_cooks flagged_residual double max_cooks max_abs_rstudent using "`influence_report'", replace

* Evaluar métricas de apalancamiento e influencia por modelo desagregado
foreach model in ECI DIVX {
    local dep "eci"
    local sample_cond "sample_eci == 1"
    local regs "$ECI_DISAGG_REGRESSORS"
    if "`model'" == "DIVX" {
        local dep "divx"
        local sample_cond "sample_divx == 1"
        local regs "$DIVX_DISAGG_REGRESSORS"
    }
    quietly regress `dep' `regs' i.country_id i.year if `sample_cond'
    quietly count if e(sample)
    local n_obs = r(N)
    local n_par = e(df_m) + 1
    local lev_cut = 2 * `n_par' / `n_obs'
    local cook_cut = 4 / `n_obs'
    tempvar lev cook rstud
    quietly predict double `lev' if e(sample), hat
    quietly predict double `cook' if e(sample), cooksd
    quietly predict double `rstud' if e(sample), rstudent
    quietly count if e(sample) & (`lev' > `lev_cut' | `cook' > `cook_cut' | abs(`rstud') > 3)
    local f_tot = r(N)
    quietly count if e(sample) & `lev' > `lev_cut'
    local f_lev = r(N)
    quietly count if e(sample) & `cook' > `cook_cut'
    local f_cook = r(N)
    quietly count if e(sample) & abs(`rstud') > 3
    local f_res = r(N)
    quietly summarize `cook' if e(sample), meanonly
    local max_c = r(max)
    tempvar abs_rstud
    quietly gen double `abs_rstud' = abs(`rstud') if e(sample)
    quietly summarize `abs_rstud' if e(sample), meanonly
    local max_r = r(max)
    post `influence_post' ("`model'") (`n_obs') (`n_par') (`lev_cut') (`cook_cut') (`f_tot') (`f_lev') (`f_cook') (`f_res') (`max_c') (`max_r')
}
postclose `influence_post'

* Exportar el reporte de diagnóstico de observaciones influyentes a CSV
preserve
    use "`influence_report'", clear
    format leverage_cutoff cooks_cutoff max_cooks max_abs_rstudent %12.6f
    export delimited using "$OUTPUT_DISAGG_DIAGNOSTICS/influential_observations_disaggregated.csv", replace
restore

* 10.7. Notificar la finalización exitosa de los diagnósticos de componentes
display as result "Sección 10 completada: Perfil de componentes, correlaciones focales, VIF e influencias exportados a $OUTPUT_DISAGG_DIAGNOSTICS."

// *********************************************
// 11. Modelos Desagregados con ECI
// *********************************************

* 11.1. Estimar el Modelo Principal ECI TWFE con rentas desagregadas de Hidrocarburos y Minería
xtreg eci $ECI_DISAGG_REGRESSORS i.year if sample_eci==1, fe vce(cluster country_id)
estimates store ECI_TWFE_DISAGG
estimates save "$OUTPUT_DISAGG_ECI/eci_twfe_disagg.ster", replace

* 11.2. Inicializar postfile para registrar coeficientes, canales analíticos e intervalos del modelo ECI desagregado
tempname eci_disagg_coef_post
tempfile eci_disagg_coef_report

* Definir la estructura del reporte de coeficientes de ECI
postfile `eci_disagg_coef_post' int order str32 term str100 variable_label str36 channel double coefficient standard_error t_statistic p_value ci_lower ci_upper using "`eci_disagg_coef_report'", replace

* Extraer métricas estadísticas y asignar canal analítico a cada coeficiente estimado en ECI
local eci_disagg_terms rents_oil_gas rents_mining inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin
local critical_t = invttail(e(df_r), 0.025)
local term_order = 0

* Iterar sobre cada término de ECI para extraer coeficientes, errores e intervalos
foreach term of local eci_disagg_terms {
    local ++term_order
    local b = _b[`term']
    local se = _se[`term']
    local term_label : variable label `term'
    if `"`term_label'"' == "" local term_label "`term'"

    // Ejecutar la siguiente instrucción del bloque
    local channel "Controles económicos y financieros"
    if inlist("`term'", "rents_oil_gas", "rents_mining", "inst") local channel "Institucional desagregado"
    if inlist("`term'", "log_oilpc", "log_gaspc", "log_coalpc") local channel "Abundancia de recursos"
    if inlist("`term'", "hhi", "pexp", "fexp") local channel "Estructura exportadora"
    if inlist("`term'", "vol", "rer") local channel "Condiciones macroeconómicas"
    if inlist("`term'", "humcap", "innov", "net") local channel "Capacidades productivas"

    // Ejecutar la siguiente instrucción del bloque
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local low = `b' - `critical_t' * `se'
    local high = `b' + `critical_t' * `se'
    post `eci_disagg_coef_post' (`term_order') ("`term'") (`"`term_label'"') ("`channel'") (`b') (`se') (`t') (`p') (`low') (`high')
}
postclose `eci_disagg_coef_post'

* Exportar la tabla detallada de coeficientes de ECI desagregado en CSV
preserve
    use "`eci_disagg_coef_report'", clear
    sort order
    format coefficient standard_error t_statistic ci_lower ci_upper %12.6f
    format p_value %10.6f
    export delimited using "$OUTPUT_DISAGG_ECI/eci_disaggregated_coefficients.csv", replace
restore

* 11.3. Inicializar postfile para métricas globales de bondad de ajuste del modelo ECI desagregado
tempname eci_disagg_sum_post
tempfile eci_disagg_sum_report

* Definir la estructura del reporte del resumen ECI
postfile `eci_disagg_sum_post' str24 model str12 dependent int obs countries clusters double r2_within r2_between r2_overall f_stat p_val rmse sigma_u sigma_e rho using "`eci_disagg_sum_report'", replace

* Guardar métricas del modelo ECI desagregado en el postfile
post `eci_disagg_sum_post' ("ECI_TWFE_DISAGG") ("eci") (e(N)) (e(N_g)) (e(N_clust)) (e(r2_w)) (e(r2_b)) (e(r2_o)) (e(F)) (e(p)) (e(rmse)) (e(sigma_u)) (e(sigma_e)) (e(rho))
postclose `eci_disagg_sum_post'

* Exportar resumen del modelo ECI desagregado a CSV
preserve
    use "`eci_disagg_sum_report'", clear
    format r2_within r2_between r2_overall f_stat p_val rmse sigma_u sigma_e rho %12.6f
    export delimited using "$OUTPUT_DISAGG_ECI/eci_disaggregated_model_summary.csv", replace
restore

* 11.4. Inicializar postfile para la suite completa de 7 pruebas de hipótesis en ECI desagregado
tempname eci_disagg_tests_post
tempfile eci_disagg_tests_report

* Definir la estructura de variables del reporte de hipótesis F
postfile `eci_disagg_tests_post' int order str50 test str140 null_hypothesis double f_stat df1 df2 p_val using "`eci_disagg_tests_report'", replace

* Test 1: Hidrocarburos efecto conjunto (RENTS_OIL_GAS y su interacción)
test rents_oil_gas c.rents_oil_gas#c.inst
post `eci_disagg_tests_post' (1) ("Hidrocarburos: efecto conjunto") ("RENTS_OIL_GAS y su interacción son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 2: Minería efecto conjunto (RENTS_MINING y su interacción)
test rents_mining c.rents_mining#c.inst
post `eci_disagg_tests_post' (2) ("Minería: efecto conjunto") ("RENTS_MINING y su interacción son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 3: Interacciones conjuntas (ambas interacciones institucionales son cero)
test c.rents_oil_gas#c.inst c.rents_mining#c.inst
post `eci_disagg_tests_post' (3) ("Interacciones conjuntas") ("Las dos interacciones institucionales son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 4: Igualdad de coeficientes directos (H0: beta_oil_gas = beta_mining)
test rents_oil_gas = rents_mining
post `eci_disagg_tests_post' (4) ("Igualdad de coeficientes directos") ("Los coeficientes directos de ambos componentes son iguales") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 5: Igualdad de términos de interacción (H0: beta_oil_gas_x_inst = beta_mining_x_inst)
test c.rents_oil_gas#c.inst = c.rents_mining#c.inst
post `eci_disagg_tests_post' (5) ("Igualdad de interacciones") ("Las interacciones institucionales de ambos componentes son iguales") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 6: Restricción del modelo agregado (igualdad simultánea de directos e interacciones)
test (rents_oil_gas = rents_mining) (c.rents_oil_gas#c.inst = c.rents_mining#c.inst)
post `eci_disagg_tests_post' (6) ("Restricción del modelo agregado") ("Coeficientes directos e interacciones son iguales entre componentes") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 7: Términos desagregados conjuntos (significancia conjunta de los 4 términos)
test rents_oil_gas rents_mining c.rents_oil_gas#c.inst c.rents_mining#c.inst
post `eci_disagg_tests_post' (7) ("Términos desagregados conjuntos") ("Los cuatro términos desagregados son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque
postclose `eci_disagg_tests_post'

* Exportar los resultados de la suite de pruebas de hipótesis a CSV
preserve
    use "`eci_disagg_tests_report'", clear
    sort order
    format f_stat p_val %12.6f
    export delimited using "$OUTPUT_DISAGG_ECI/eci_disaggregated_channel_tests.csv", replace
restore

* 11.5. Verificación numérica de precisión estimando el mismo modelo con reghdfe
reghdfe eci $ECI_DISAGG_REGRESSORS if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
estimates store ECI_REGHDFE_DISAGG_CHECK

* Ejecutar la siguiente instrucción del bloque
tempname eci_verif_post
tempfile eci_verif_report

* Definir la estructura del reporte de verificación xtreg vs reghdfe
postfile `eci_verif_post' int order str32 term double xtreg_b reghdfe_b diff_b xtreg_se reghdfe_se diff_se byte match using "`eci_verif_report'", replace

* Iterar sobre los términos para contrastar la coincidencia exacta de coeficientes
local term_order = 0
foreach term of local eci_disagg_terms {
    local ++term_order
    estimates restore ECI_TWFE_DISAGG
    local xb = _b[`term']
    local xse = _se[`term']
    estimates restore ECI_REGHDFE_DISAGG_CHECK
    local hb = _b[`term']
    local hse = _se[`term']
    local db = abs(`xb' - `hb')
    local dse = abs(`xse' - `hse')
    local m = (`db' < 1e-8)
    post `eci_verif_post' (`term_order') ("`term'") (`xb') (`hb') (`db') (`xse') (`hse') (`dse') (`m')
}
postclose `eci_verif_post'

* Exportar reporte de verificación numérica ECI a CSV
preserve
    use "`eci_verif_report'", clear
    sort order
    format xtreg_b reghdfe_b diff_b xtreg_se reghdfe_se diff_se %16.10f
    export delimited using "$OUTPUT_DISAGG_ECI/eci_xtreg_reghdfe_verification.csv", replace
restore

* Restaurar la estimación oficial ECI TWFE desagregada y notificar el cierre de la Sección 11
estimates restore ECI_TWFE_DISAGG
display as result "Sección 11 completada: Estimación ECI Disagregada, pruebas de hipótesis y verificación con reghdfe guardadas."

// *********************************************
// 12. Modelos Desagregados con DIVX
// *********************************************

* 12.1. Estimar el Modelo Principal DIVX TWFE con rentas desagregadas (excluyendo HHI)
xtreg divx $DIVX_DISAGG_REGRESSORS i.year if sample_divx==1, fe vce(cluster country_id)
estimates store DIVX_TWFE_DISAGG
estimates save "$OUTPUT_DISAGG_DIVX/divx_twfe_disagg.ster", replace

* 12.2. Inicializar postfile para registrar coeficientes e intervalos del modelo DIVX desagregado
tempname divx_disagg_coef_post
tempfile divx_disagg_coef_report

* Definir la estructura del reporte de coeficientes DIVX
postfile `divx_disagg_coef_post' int order str32 term str100 variable_label str36 channel double coefficient standard_error t_statistic p_value ci_lower ci_upper using "`divx_disagg_coef_report'", replace

* Extraer métricas estadísticas y asignar canal analítico a cada coeficiente estimado en DIVX
local divx_disagg_terms rents_oil_gas rents_mining inst log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin
local critical_t = invttail(e(df_r), 0.025)
local term_order = 0

* Iterar sobre cada término de DIVX para extraer coeficientes, errores e intervalos
foreach term of local divx_disagg_terms {
    local ++term_order
    local b = _b[`term']
    local se = _se[`term']
    local term_label : variable label `term'
    if `"`term_label'"' == "" local term_label "`term'"

    // Ejecutar la siguiente instrucción del bloque
    local channel "Controles económicos y financieros"
    if inlist("`term'", "rents_oil_gas", "rents_mining", "inst") local channel "Institucional desagregado"
    if inlist("`term'", "log_oilpc", "log_gaspc", "log_coalpc") local channel "Abundancia de recursos"
    if inlist("`term'", "pexp", "fexp") local channel "Estructura exportadora"
    if inlist("`term'", "vol", "rer") local channel "Condiciones macroeconómicas"
    if inlist("`term'", "humcap", "innov", "net") local channel "Capacidades productivas"

    // Ejecutar la siguiente instrucción del bloque
    local t = `b' / `se'
    local p = 2 * ttail(e(df_r), abs(`t'))
    local low = `b' - `critical_t' * `se'
    local high = `b' + `critical_t' * `se'
    post `divx_disagg_coef_post' (`term_order') ("`term'") (`"`term_label'"') ("`channel'") (`b') (`se') (`t') (`p') (`low') (`high')
}
postclose `divx_disagg_coef_post'

* Exportar la tabla detallada de coeficientes de DIVX desagregado en CSV
preserve
    use "`divx_disagg_coef_report'", clear
    sort order
    format coefficient standard_error t_statistic ci_lower ci_upper %12.6f
    format p_value %10.6f
    export delimited using "$OUTPUT_DISAGG_DIVX/divx_disaggregated_coefficients.csv", replace
restore

* 12.3. Inicializar postfile para métricas globales de bondad de ajuste del modelo DIVX desagregado
tempname divx_disagg_sum_post
tempfile divx_disagg_sum_report

* Definir estructura del reporte de resumen DIVX
postfile `divx_disagg_sum_post' str24 model str12 dependent int obs countries clusters double r2_within r2_between r2_overall f_stat p_val rmse sigma_u sigma_e rho using "`divx_disagg_sum_report'", replace

* Guardar métricas del modelo DIVX desagregado en el postfile
post `divx_disagg_sum_post' ("DIVX_TWFE_DISAGG") ("divx") (e(N)) (e(N_g)) (e(N_clust)) (e(r2_w)) (e(r2_b)) (e(r2_o)) (e(F)) (e(p)) (e(rmse)) (e(sigma_u)) (e(sigma_e)) (e(rho))
postclose `divx_disagg_sum_post'

* Exportar resumen del modelo DIVX desagregado a CSV
preserve
    use "`divx_disagg_sum_report'", clear
    format r2_within r2_between r2_overall f_stat p_val rmse sigma_u sigma_e rho %12.6f
    export delimited using "$OUTPUT_DISAGG_DIVX/divx_disaggregated_model_summary.csv", replace
restore

* 12.4. Inicializar postfile para la suite completa de 7 pruebas de hipótesis en DIVX desagregado
tempname divx_disagg_tests_post
tempfile divx_disagg_tests_report

* Definir la estructura de variables del reporte de pruebas en DIVX
postfile `divx_disagg_tests_post' int order str50 test str140 null_hypothesis double f_stat df1 df2 p_val using "`divx_disagg_tests_report'", replace

* Test 1: Hidrocarburos efecto conjunto
test rents_oil_gas c.rents_oil_gas#c.inst
post `divx_disagg_tests_post' (1) ("Hidrocarburos: efecto conjunto") ("RENTS_OIL_GAS y su interacción son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 2: Minería efecto conjunto
test rents_mining c.rents_mining#c.inst
post `divx_disagg_tests_post' (2) ("Minería: efecto conjunto") ("RENTS_MINING y su interacción son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 3: Interacciones conjuntas
test c.rents_oil_gas#c.inst c.rents_mining#c.inst
post `divx_disagg_tests_post' (3) ("Interacciones conjuntas") ("Las dos interacciones institucionales son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 4: Igualdad de coeficientes directos
test rents_oil_gas = rents_mining
post `divx_disagg_tests_post' (4) ("Igualdad de coeficientes directos") ("Los coeficientes directos de ambos componentes son iguales") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 5: Igualdad de interacciones
test c.rents_oil_gas#c.inst = c.rents_mining#c.inst
post `divx_disagg_tests_post' (5) ("Igualdad de interacciones") ("Las interacciones institucionales de ambos componentes son iguales") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 6: Restricción del modelo agregado
test (rents_oil_gas = rents_mining) (c.rents_oil_gas#c.inst = c.rents_mining#c.inst)
post `divx_disagg_tests_post' (6) ("Restricción del modelo agregado") ("Coeficientes directos e interacciones son iguales entre componentes") (r(F)) (r(df)) (r(df_r)) (r(p))

* Test 7: Términos desagregados conjuntos
test rents_oil_gas rents_mining c.rents_oil_gas#c.inst c.rents_mining#c.inst
post `divx_disagg_tests_post' (7) ("Términos desagregados conjuntos") ("Los cuatro términos desagregados son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque
postclose `divx_disagg_tests_post'

* Exportar resultados de las pruebas de hipótesis del modelo DIVX desagregado a CSV
preserve
    use "`divx_disagg_tests_report'", clear
    sort order
    format f_stat p_val %12.6f
    export delimited using "$OUTPUT_DISAGG_DIVX/divx_disaggregated_channel_tests.csv", replace
restore

* 12.5. Verificación numérica de precisión estimando el mismo modelo DIVX con reghdfe
reghdfe divx $DIVX_DISAGG_REGRESSORS if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
estimates store DIVX_REGHDFE_DISAGG_CHECK

* Ejecutar la siguiente instrucción del bloque
tempname divx_verif_post
tempfile divx_verif_report

* Definir la estructura del reporte de verificación DIVX
postfile `divx_verif_post' int order str32 term double xtreg_b reghdfe_b diff_b xtreg_se reghdfe_se diff_se byte match using "`divx_verif_report'", replace

* Iterar sobre los términos para verificar coincidencia numérica
local term_order = 0
foreach term of local divx_disagg_terms {
    local ++term_order
    estimates restore DIVX_TWFE_DISAGG
    local xb = _b[`term']
    local xse = _se[`term']
    estimates restore DIVX_REGHDFE_DISAGG_CHECK
    local hb = _b[`term']
    local hse = _se[`term']
    local db = abs(`xb' - `hb')
    local dse = abs(`xse' - `hse')
    local m = (`db' < 1e-8)
    post `divx_verif_post' (`term_order') ("`term'") (`xb') (`hb') (`db') (`xse') (`hse') (`dse') (`m')
}
postclose `divx_verif_post'

* Exportar reporte de verificación DIVX a CSV
preserve
    use "`divx_verif_report'", clear
    sort order
    format xtreg_b reghdfe_b diff_b xtreg_se reghdfe_se diff_se %16.10f
    export delimited using "$OUTPUT_DISAGG_DIVX/divx_xtreg_reghdfe_verification.csv", replace
restore

* Restaurar estimación DIVX oficial y notificar la finalización exitosa de la Sección 12
estimates restore DIVX_TWFE_DISAGG
display as result "Sección 12 completada: Estimación DIVX Disagregada y verificación con reghdfe guardadas."

// *********************************************
// 13. Estabilidad y Efectos Marginales por Componente
// *********************************************

* 13.1. Obtener los percentiles observados de la distribución del índice de calidad institucional (INST)
quietly summarize inst if sample_eci == 1, detail
local p10 = r(p10)
local p25 = r(p25)
local p50 = r(p50)
local p75 = r(p75)
local p90 = r(p90)
local inst_vals "`p10' `p25' `p50' `p75' `p90'"
local inst_lbls "P10 P25 P50 P75 P90"

* 13.2. Inicializar postfile para almacenar los efectos marginales condicionales por componente
tempname disagg_margins_post
tempfile disagg_margins_report

* Definir la estructura de columnas para el reporte de efectos marginales
postfile `disagg_margins_post' str8 model str16 component str4 percentile double inst_val marginal_effect standard_error t_stat p_val ci_lower ci_upper str12 significance using "`disagg_margins_report'", replace

* 13.3. Re-estimar el modelo ECI desagregado para garantizar que la memoria contenga los resultados activos
quietly xtreg eci $ECI_DISAGG_REGRESSORS i.year if sample_eci == 1, fe vce(cluster country_id)

* 13.4. Calcular efectos marginales d(ECI)/d(rents_oil_gas) evaluados en percentiles de INST
margins, dydx(rents_oil_gas) at(inst=(`inst_vals'))
matrix m_og = r(table)

* 13.5. Graficar el perfil de efectos marginales de Hidrocarburos sobre ECI con etiquetas inclinadas a 45°
marginsplot, recast(line) recastci(rarea) plotopts(lcolor(navy) lwidth(medthick)) ciopts(color(navy%25) lcolor(navy%45)) ///
    yline(0, lcolor(gs8) lpattern(dash)) xlabel(`p10' "P10" `p25' "P25" `p50' "P50" `p75' "P75" `p90' "P90", labsize(small) angle(45)) ///
    ylabel(, labsize(small) angle(horizontal)) ///
    title("ECI: Asociación marginal estimada de Rentas de Hidrocarburos según INST", size(medium)) ///
    ytitle("Asociación marginal d(ECI)/d(RENTS_OIL_GAS)") xtitle("Percentil de calidad institucional (INST)") ///
    name(eci_og_margins, replace)
cap graph export "$OUTPUT_DISAGG_STABILITY/eci_rents_oil_gas_marginal_effect.pdf", replace
cap graph export "$OUTPUT_DISAGG_STABILITY/eci_rents_oil_gas_marginal_effect.png", width(2400) replace

* 13.6. Guardar en postfile cada efecto marginal de Hidrocarburos sobre ECI por percentil
forvalues col = 1/5 {
    local pct : word `col' of `inst_lbls'
    local val : word `col' of `inst_vals'
    local eff = el(m_og, 1, `col')
    local se  = el(m_og, 2, `col')
    local t   = el(m_og, 3, `col')
    local p   = el(m_og, 4, `col')
    local low = el(m_og, 5, `col')
    local high = el(m_og, 6, `col')
    local sig "No"
    if `p' < 0.10 local sig "10%"
    if `p' < 0.05 local sig "5%"
    if `p' < 0.01 local sig "1%"
    post `disagg_margins_post' ("ECI") ("rents_oil_gas") ("`pct'") (`val') (`eff') (`se') (`t') (`p') (`low') (`high') ("`sig'")
}

* 13.7. Calcular efectos marginales d(ECI)/d(rents_mining) evaluados en percentiles de INST
margins, dydx(rents_mining) at(inst=(`inst_vals'))
matrix m_min = r(table)

* 13.8. Graficar el perfil de efectos marginales de Minería sobre ECI con etiquetas inclinadas a 45°
marginsplot, recast(line) recastci(rarea) plotopts(lcolor(dkorange) lwidth(medthick)) ciopts(color(dkorange%25) lcolor(dkorange%45)) ///
    yline(0, lcolor(gs8) lpattern(dash)) xlabel(`p10' "P10" `p25' "P25" `p50' "P50" `p75' "P75" `p90' "P90", labsize(small) angle(45)) ///
    ylabel(, labsize(small) angle(horizontal)) ///
    title("ECI: Asociación marginal estimada de Rentas Mineras según INST", size(medium)) ///
    ytitle("Asociación marginal d(ECI)/d(RENTS_MINING)") xtitle("Percentil de calidad institucional (INST)") ///
    name(eci_min_margins, replace)
cap graph export "$OUTPUT_DISAGG_STABILITY/eci_rents_mining_marginal_effect.pdf", replace
cap graph export "$OUTPUT_DISAGG_STABILITY/eci_rents_mining_marginal_effect.png", width(2400) replace

* 13.9. Guardar en postfile cada efecto marginal de Minería sobre ECI por percentil
forvalues col = 1/5 {
    local pct : word `col' of `inst_lbls'
    local val : word `col' of `inst_vals'
    local eff = el(m_min, 1, `col')
    local se  = el(m_min, 2, `col')
    local t   = el(m_min, 3, `col')
    local p   = el(m_min, 4, `col')
    local low = el(m_min, 5, `col')
    local high = el(m_min, 6, `col')
    local sig "No"
    if `p' < 0.10 local sig "10%"
    if `p' < 0.05 local sig "5%"
    if `p' < 0.01 local sig "1%"
    post `disagg_margins_post' ("ECI") ("rents_mining") ("`pct'") (`val') (`eff') (`se') (`t') (`p') (`low') (`high') ("`sig'")
}

* 13.10. Re-estimar el modelo DIVX desagregado para análisis de efectos marginales
quietly xtreg divx $DIVX_DISAGG_REGRESSORS i.year if sample_divx == 1, fe vce(cluster country_id)

* 13.11. Calcular efectos marginales d(DIVX)/d(rents_oil_gas) evaluados en percentiles de INST
margins, dydx(rents_oil_gas) at(inst=(`inst_vals'))
matrix m_og_d = r(table)

* 13.12. Graficar el perfil de efectos marginales de Hidrocarburos sobre DIVX con etiquetas inclinadas a 45°
marginsplot, recast(line) recastci(rarea) plotopts(lcolor(maroon) lwidth(medthick)) ciopts(color(maroon%25) lcolor(maroon%45)) ///
    yline(0, lcolor(gs8) lpattern(dash)) xlabel(`p10' "P10" `p25' "P25" `p50' "P50" `p75' "P75" `p90' "P90", labsize(small) angle(45)) ///
    ylabel(, labsize(small) angle(horizontal)) ///
    title("DIVX: Asociación marginal estimada de Rentas de Hidrocarburos según INST", size(medium)) ///
    ytitle("Asociación marginal d(DIVX)/d(RENTS_OIL_GAS)") xtitle("Percentil de calidad institucional (INST)") ///
    name(divx_og_margins, replace)
cap graph export "$OUTPUT_DISAGG_STABILITY/divx_rents_oil_gas_marginal_effect.pdf", replace
cap graph export "$OUTPUT_DISAGG_STABILITY/divx_rents_oil_gas_marginal_effect.png", width(2400) replace

* 13.13. Guardar en postfile cada efecto marginal de Hidrocarburos sobre DIVX por percentil
forvalues col = 1/5 {
    local pct : word `col' of `inst_lbls'
    local val : word `col' of `inst_vals'
    local eff = el(m_og_d, 1, `col')
    local se  = el(m_og_d, 2, `col')
    local t   = el(m_og_d, 3, `col')
    local p   = el(m_og_d, 4, `col')
    local low = el(m_og_d, 5, `col')
    local high = el(m_og_d, 6, `col')
    local sig "No"
    if `p' < 0.10 local sig "10%"
    if `p' < 0.05 local sig "5%"
    if `p' < 0.01 local sig "1%"
    post `disagg_margins_post' ("DIVX") ("rents_oil_gas") ("`pct'") (`val') (`eff') (`se') (`t') (`p') (`low') (`high') ("`sig'")
}

* 13.14. Calcular efectos marginales d(DIVX)/d(rents_mining) evaluados en percentiles de INST
margins, dydx(rents_mining) at(inst=(`inst_vals'))
matrix m_min_d = r(table)

* 13.15. Graficar el perfil de efectos marginales de Minería sobre DIVX con etiquetas inclinadas a 45°
marginsplot, recast(line) recastci(rarea) plotopts(lcolor(purple) lwidth(medthick)) ciopts(color(purple%25) lcolor(purple%45)) ///
    yline(0, lcolor(gs8) lpattern(dash)) xlabel(`p10' "P10" `p25' "P25" `p50' "P50" `p75' "P75" `p90' "P90", labsize(small) angle(45)) ///
    ylabel(, labsize(small) angle(horizontal)) ///
    title("DIVX: Asociación marginal estimada de Rentas Mineras según INST", size(medium)) ///
    ytitle("Asociación marginal d(DIVX)/d(RENTS_MINING)") xtitle("Percentil de calidad institucional (INST)") ///
    name(divx_min_margins, replace)
cap graph export "$OUTPUT_DISAGG_STABILITY/divx_rents_mining_marginal_effect.pdf", replace
cap graph export "$OUTPUT_DISAGG_STABILITY/divx_rents_mining_marginal_effect.png", width(2400) replace

* 13.16. Guardar en postfile cada efecto marginal de Minería sobre DIVX por percentil
forvalues col = 1/5 {
    local pct : word `col' of `inst_lbls'
    local val : word `col' of `inst_vals'
    local eff = el(m_min_d, 1, `col')
    local se  = el(m_min_d, 2, `col')
    local t   = el(m_min_d, 3, `col')
    local p   = el(m_min_d, 4, `col')
    local low = el(m_min_d, 5, `col')
    local high = el(m_min_d, 6, `col')
    local sig "No"
    if `p' < 0.10 local sig "10%"
    if `p' < 0.05 local sig "5%"
    if `p' < 0.01 local sig "1%"
    post `disagg_margins_post' ("DIVX") ("rents_mining") ("`pct'") (`val') (`eff') (`se') (`t') (`p') (`low') (`high') ("`sig'")
}
postclose `disagg_margins_post'

* 13.17. Exportar los resultados consolidados de efectos marginales por componente a CSV
preserve
    use "`disagg_margins_report'", clear
    sort model component inst_val
    format inst_val marginal_effect standard_error t_stat p_val ci_lower ci_upper %12.6f
    export delimited using "$OUTPUT_DISAGG_STABILITY/component_marginal_effects_by_inst.csv", replace
    export delimited using "$OUTPUT_DISAGG_STABILITY/disaggregated_marginal_effects_by_inst.csv", replace
restore

* 13.18. Sensibilidad a Observaciones Potencialmente Influyentes (Excluyendo Alertas de Sección 10)
capture confirm file "$OUTPUT_DIAGNOSTICS/influential_observations.csv"
if _rc == 0 {
    tempfile disagg_influence_flags
    preserve
        import delimited using "$OUTPUT_DIAGNOSTICS/influential_observations.csv", clear varnames(1)
        keep country_iso3_code year model
        duplicates drop
        gen byte influential = 1
        reshape wide influential, i(country_iso3_code year) j(model) string
        capture confirm variable influentialECI
        if _rc gen byte influentialECI = 0
        capture confirm variable influentialDIVX
        if _rc gen byte influentialDIVX = 0
        replace influentialECI = 0 if missing(influentialECI)
        replace influentialDIVX = 0 if missing(influentialDIVX)
        rename influentialECI influential_eci_disagg
        rename influentialDIVX influential_divx_disagg
        save "`disagg_influence_flags'", replace
    restore

    // Ejecutar la siguiente instrucción del bloque
    preserve
        use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
        merge m:1 country_iso3_code year using "`disagg_influence_flags'", keep(master match) nogen
        replace influential_eci_disagg = 0 if missing(influential_eci_disagg)
        replace influential_divx_disagg = 0 if missing(influential_divx_disagg)

        // Ejecutar la siguiente instrucción del bloque
        local disagg_focal_terms rents_oil_gas rents_mining c.rents_oil_gas#c.inst c.rents_mining#c.inst
        tempname disagg_influence_post
        tempfile disagg_influence_report
        postfile `disagg_influence_post' str8 model str20 specification str32 term double observations countries coefficient standard_error p_value using "`disagg_influence_report'", replace

        // Ejecutar la siguiente instrucción del bloque
        foreach model in ECI DIVX {
            local dependent "eci"
            local regressors "$ECI_DISAGG_REGRESSORS"
            local sample_flag "sample_eci"
            local influence_flag "influential_eci_disagg"
            if "`model'" == "DIVX" {
                local dependent "divx"
                local regressors "$DIVX_DISAGG_REGRESSORS"
                local sample_flag "sample_divx"
                local influence_flag "influential_divx_disagg"
            }

            // Evaluar condición de control de flujo
            quietly reghdfe `dependent' `regressors' if `sample_flag' == 1, absorb(country_id year) vce(cluster country_id)
            foreach term of local disagg_focal_terms {
                local term_p = 2 * ttail(e(df_r), abs(_b[`term'] / _se[`term']))
                post `disagg_influence_post' ("`model'") ("Base") ("`term'") (e(N)) (e(N_clust)) (_b[`term']) (_se[`term']) (`term_p')
            }

            // Evaluar condición de control de flujo
            quietly reghdfe `dependent' `regressors' if `sample_flag' == 1 & `influence_flag' == 0, absorb(country_id year) vce(cluster country_id)
            foreach term of local disagg_focal_terms {
                local term_p = 2 * ttail(e(df_r), abs(_b[`term'] / _se[`term']))
                post `disagg_influence_post' ("`model'") ("Excluye alertas") ("`term'") (e(N)) (e(N_clust)) (_b[`term']) (_se[`term']) (`term_p')
            }
        }
        postclose `disagg_influence_post'

        // Ejecutar la siguiente instrucción del bloque
        use "`disagg_influence_report'", clear
        sort model term specification
        format observations countries %12.0f
        format coefficient standard_error p_value %16.10f
        export delimited using "$OUTPUT_DISAGG_STABILITY/influential_observation_sensitivity.csv", replace
    restore
}

* 13.19. Sensibilidad sin Controles Recursos Per Cápita (Log OilPC, GasPC, CoalPC)
global ECI_DISAGG_NO_PC c.rents_oil_gas##c.inst c.rents_mining##c.inst hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin
global DIVX_DISAGG_NO_PC c.rents_oil_gas##c.inst c.rents_mining##c.inst pexp fexp vol rer humcap innov net log_gdppc govcons fin

* Ejecutar la siguiente instrucción del bloque
tempname disagg_no_pc_post
tempfile disagg_no_pc_report
postfile `disagg_no_pc_post' str8 model str32 specification str32 term double observations countries coefficient standard_error p_value using "`disagg_no_pc_report'", replace

* Ejecutar la siguiente instrucción del bloque
local disagg_focal_terms rents_oil_gas rents_mining c.rents_oil_gas#c.inst c.rents_mining#c.inst

* Ejecutar la siguiente instrucción del bloque
foreach model in ECI DIVX {
    local dependent "eci"
    local sample_flag "sample_eci"
    local no_pc_regressors "$ECI_DISAGG_NO_PC"
    local base_regressors "$ECI_DISAGG_REGRESSORS"
    if "`model'" == "DIVX" {
        local dependent "divx"
        local sample_flag "sample_divx"
        local no_pc_regressors "$DIVX_DISAGG_NO_PC"
        local base_regressors "$DIVX_DISAGG_REGRESSORS"
    }

    // Evaluar condición de control de flujo
    quietly reghdfe `dependent' `base_regressors' if `sample_flag' == 1, absorb(country_id year) vce(cluster country_id)
    foreach term of local disagg_focal_terms {
        local term_p = 2 * ttail(e(df_r), abs(_b[`term'] / _se[`term']))
        post `disagg_no_pc_post' ("`model'") ("Base") ("`term'") (e(N)) (e(N_g)) (_b[`term']) (_se[`term']) (`term_p')
    }

    // Evaluar condición de control de flujo
    quietly reghdfe `dependent' `no_pc_regressors' if `sample_flag' == 1, absorb(country_id year) vce(cluster country_id)
    foreach term of local disagg_focal_terms {
        local term_p = 2 * ttail(e(df_r), abs(_b[`term'] / _se[`term']))
        post `disagg_no_pc_post' ("`model'") ("Sin controles per cápita") ("`term'") (e(N)) (e(N_g)) (_b[`term']) (_se[`term']) (`term_p')
    }
}
postclose `disagg_no_pc_post'

* Ejecutar la siguiente instrucción del bloque
preserve
    use "`disagg_no_pc_report'", clear
    sort model term specification
    format coefficient standard_error p_value %16.10f
    export delimited using "$OUTPUT_DISAGG_STABILITY/no_per_capita_controls_sensitivity.csv", replace
restore

* 13.20. Inicializar el análisis de sensibilidad Jackknife omitiendo un país a la vez para los 4 términos focales
quietly levelsof country_id if sample_eci == 1, local(c_list)
tempname disagg_loo_post
tempfile disagg_loo_report

* Ejecutar la siguiente instrucción del bloque
postfile `disagg_loo_post' str8 model double excluded_country_id str3 excluded_country_iso3 str32 term double base_coefficient coefficient standard_error p_value observations countries using "`disagg_loo_report'", replace

* Ejecutar la siguiente instrucción del bloque
foreach model in ECI DIVX {
    local dependent "eci"
    local regressors "$ECI_DISAGG_REGRESSORS"
    local sample_flag "sample_eci"
    local base_prefix "eci"
    if "`model'" == "DIVX" {
        local dependent "divx"
        local regressors "$DIVX_DISAGG_REGRESSORS"
        local sample_flag "sample_divx"
        local base_prefix "divx"
    }

    // Evaluar condición de control de flujo
    quietly reghdfe `dependent' `regressors' if `sample_flag' == 1, absorb(country_id year) vce(cluster country_id)
    local focal_order = 0
    foreach term of local disagg_focal_terms {
        local ++focal_order
        scalar disagg_loo_base_`base_prefix'_`focal_order' = _b[`term']
    }

    // Ejecutar la siguiente instrucción del bloque
    foreach cid of local c_list {
        quietly levelsof country_iso3_code if country_id == `cid', local(c_iso3) clean
        quietly reghdfe `dependent' `regressors' if `sample_flag' == 1 & country_id != `cid', absorb(country_id year) vce(cluster country_id)
        local focal_order = 0
        foreach term of local disagg_focal_terms {
            local ++focal_order
            local term_p = 2 * ttail(e(df_r), abs(_b[`term'] / _se[`term']))
            local base_b = scalar(disagg_loo_base_`base_prefix'_`focal_order')
            post `disagg_loo_post' ("`model'") (`cid') ("`c_iso3'") ("`term'") (`base_b') (_b[`term']) (_se[`term']) (`term_p') (e(N)) (e(N_clust))
        }
    }
}
postclose `disagg_loo_post'

* Ejecutar la siguiente instrucción del bloque
preserve
    use "`disagg_loo_report'", clear
    sort model term excluded_country_id
    format base_coefficient coefficient standard_error p_value %16.10f
    export delimited using "$OUTPUT_DISAGG_STABILITY/leave_one_country_out_detail.csv", replace

    * Ejecutar la siguiente instrucción del bloque
    gen byte sign_change = (sign(coefficient) != sign(base_coefficient))
    gen byte significant_5 = (p_value < 0.05)
    gen byte significant_10 = (p_value < 0.10)
    collapse (count) replications=coefficient (firstnm) base_coefficient (min) min_coefficient=coefficient min_p_value=p_value (max) max_coefficient=coefficient max_p_value=p_value (sum) sign_changes=sign_change significant_5 significant_10, by(model term)
    format base_coefficient min_coefficient max_coefficient min_p_value max_p_value %16.10f
    export delimited using "$OUTPUT_DISAGG_STABILITY/leave_one_country_out_summary.csv", replace
    export delimited using "$OUTPUT_DISAGG_STABILITY/disaggregated_leave_one_country_out_summary.csv", replace
restore

* 13.21. Ejecutar inferencia no paramétrica mediante Wild Cluster Bootstrap (boottest - 9,999 reps) para los 4 términos focales
cap which boottest
if _rc == 0 {
    tempname disagg_boot_post
    tempfile disagg_boot_report

    // Ejecutar la siguiente instrucción del bloque
    postfile `disagg_boot_post' str8 model str32 term double conventional_coefficient conventional_p_value bootstrap_p_value ci_lower ci_upper replications str16 weight_type using "`disagg_boot_report'", replace

    // Ejecutar la siguiente instrucción del bloque
    local bootstrap_order = 0
    foreach model in ECI DIVX {
        local dependent "eci"
        local regressors "$ECI_DISAGG_REGRESSORS"
        local sample_flag "sample_eci"
        if "`model'" == "DIVX" {
            local dependent "divx"
            local regressors "$DIVX_DISAGG_REGRESSORS"
            local sample_flag "sample_divx"
        }

        // Evaluar condición de control de flujo
        quietly xtreg `dependent' `regressors' i.year if `sample_flag' == 1, fe vce(cluster country_id)

        // Ejecutar la siguiente instrucción del bloque
        foreach term of local disagg_focal_terms {
            local ++bootstrap_order
            local conventional_coefficient = _b[`term']
            local conventional_p = 2 * ttail(e(df_r), abs(_b[`term'] / _se[`term']))
            local bootstrap_seed = 20260729 + `bootstrap_order'
            quietly boottest `term', cluster(country_id) reps(9999) seed(`bootstrap_seed') nograph
            matrix disagg_bootstrap_ci = r(CI)
            local bootstrap_p = r(p)
            local bootstrap_reps = r(reps)
            local bootstrap_weight "`r(weighttype)'"
            post `disagg_boot_post' ("`model'") ("`term'") (`conventional_coefficient') (`conventional_p') (`bootstrap_p') (el(disagg_bootstrap_ci, 1, 1)) (el(disagg_bootstrap_ci, 1, 2)) (`bootstrap_reps') ("`bootstrap_weight'")
        }
    }
    postclose `disagg_boot_post'

    // Ejecutar la siguiente instrucción del bloque
    preserve
        use "`disagg_boot_report'", clear
        sort model term
        format conventional_coefficient conventional_p_value bootstrap_p_value ci_lower ci_upper %16.10f
        export delimited using "$OUTPUT_DISAGG_STABILITY/wild_cluster_bootstrap.csv", replace
        export delimited using "$OUTPUT_DISAGG_STABILITY/disaggregated_wild_cluster_bootstrap.csv", replace
    restore
}

* 13.22. Matriz de Clasificación Final de Estabilidad del Respaldo Empírico
capture confirm file "$OUTPUT_DISAGG_STABILITY/influential_observation_sensitivity.csv"
if _rc == 0 {
    tempfile stability_base stability_influence stability_no_pc stability_bootstrap stability_loo
    preserve
        use "`disagg_influence_report'", clear
        keep if specification == "Base"
        keep model term coefficient p_value
        rename coefficient base_coefficient
        rename p_value base_p_value
        save "`stability_base'", replace
    restore
    preserve
        use "`disagg_influence_report'", clear
        keep if specification == "Excluye alertas"
        keep model term coefficient p_value
        rename coefficient influence_coefficient
        rename p_value influence_p_value
        save "`stability_influence'", replace
    restore
    preserve
        use "`disagg_no_pc_report'", clear
        keep if specification == "Sin controles per cápita"
        keep model term coefficient p_value
        rename coefficient no_pc_coefficient
        rename p_value no_pc_p_value
        save "`stability_no_pc'", replace
    restore
    preserve
        use "`disagg_boot_report'", clear
        keep model term bootstrap_p_value ci_lower ci_upper
        rename ci_lower bootstrap_ci_lower
        rename ci_upper bootstrap_ci_upper
        save "`stability_bootstrap'", replace
    restore
    preserve
        import delimited using "$OUTPUT_DISAGG_STABILITY/leave_one_country_out_summary.csv", clear
        keep model term min_coefficient max_coefficient sign_changes significant_5 significant_10
        save "`stability_loo'", replace
    restore

    // Ejecutar la siguiente instrucción del bloque
    preserve
        use "`stability_base'", clear
        merge 1:1 model term using "`stability_influence'", assert(match) nogen
        merge 1:1 model term using "`stability_no_pc'", assert(match) nogen
        merge 1:1 model term using "`stability_loo'", assert(match) nogen
        merge 1:1 model term using "`stability_bootstrap'", assert(match) nogen
        gen byte direction_stable = (sign(base_coefficient) == sign(influence_coefficient) & sign(base_coefficient) == sign(no_pc_coefficient) & sign_changes == 0)
        gen byte bootstrap_support = (bootstrap_p_value < 0.10)
        gen str18 evidence_class = "No concluyente"
        replace evidence_class = "Complementaria" if direction_stable == 1 & bootstrap_support == 1
        sort model term
        format base_coefficient base_p_value influence_coefficient influence_p_value no_pc_coefficient no_pc_p_value min_coefficient max_coefficient bootstrap_p_value bootstrap_ci_lower bootstrap_ci_upper %16.10f
        export delimited using "$OUTPUT_DISAGG_STABILITY/stability_classification.csv", replace
    restore
}

* 13.23. Notificar la finalización exitosa de la Sección 13
display as result "Sección 13 completada: Efectos marginales, sensibilidades e inferencia bootstrap por componente exportadas."

// *********************************************
// 14. Exportación y Cierre de la Desagregación
// *********************************************

* 14.1. Exportar tablas comparativas formateadas a LaTeX y Texto usando esttab
cap which esttab
if _rc == 0 {
    * Cargar las estimaciones agregadas previas guardadas en archivos .ster
    capture estimates use "$OUTPUT_ECI/eci_twfe_main.ster"
    estimates store ECI_MAIN_SAVED

    * Cargar el archivo de datos
    capture estimates use "$OUTPUT_DIVX/divx_twfe_main.ster"
    estimates store DIVX_MAIN_SAVED

    * Exportar la Tabla Comparativa Final a formato LaTeX (.tex) en la carpeta 06_final
    esttab ECI_MAIN_SAVED ECI_TWFE_DISAGG DIVX_MAIN_SAVED DIVX_TWFE_DISAGG using "$OUTPUT_DISAGG_FINAL/table_eci_divx_disaggregated.tex", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        title("Modelos Econométricos Desagregados: Hidrocarburos vs. Minería + Carbón") ///
        mtitles("ECI (Agregado)" "ECI (Desagregado)" "DIVX (Agregado)" "DIVX (Desagregado)") ///
        booktabs alignment(c) drop(*.year) ///
        stats(N N_g r2_o, labels("Observaciones" "Países" "R2 overall"))

    * Exportar la misma Tabla Comparativa a formato Texto (.txt) para consulta directa
    esttab ECI_MAIN_SAVED ECI_TWFE_DISAGG DIVX_MAIN_SAVED DIVX_TWFE_DISAGG using "$OUTPUT_DISAGG_FINAL/table_eci_divx_disaggregated.txt", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        mtitles("ECI (Agregado)" "ECI (Desagregado)" "DIVX (Agregado)" "DIVX (Desagregado)") ///
        drop(*.year) ///
        stats(N N_g r2_o, labels("Observaciones" "Países" "R2 overall"))
}

* 14.2. Informar en la consola de Stata la finalización exitosa del Script 03
display as result "---------------------------------------------------------"
display as result "Parte 3 (Secciones 9 a 14) completada con éxito total en stata-peer-1."
display as result "Tablas LaTeX desagregadas guardadas en: $OUTPUT_DISAGG_FINAL"
display as result "---------------------------------------------------------"

* 14.3. Cerrar el archivo de registro de ejecución de la Parte 3
log close disagg_log
