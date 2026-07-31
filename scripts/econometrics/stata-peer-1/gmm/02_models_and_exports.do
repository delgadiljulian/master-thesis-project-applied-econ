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
// Archivo: 02_models_and_exports.do (Parte 2 - Secciones 5 a 8: GMM Dinámico)
// Ubicación: scripts/econometrics/stata-peer-1/gmm/
// Fecha: Segundo Cuatrimestre 2026
// *********************************************

// *********************************************
// 1. Configuración del Entorno y Rutas de Trabajo (GMM)
// *********************************************

version 17.0
clear all
cls
macro drop _all
capture log close _all

set more off
set varabbrev off
set type double
set linesize 255
set seed 20260731
set sortseed 20260731

foreach pkg in ftools reghdfe estout xtabond2 {
    capture which `pkg'
    if _rc {
        capture ssc install `pkg', replace
    }
}

* Garantizar que la función Mata de xtabond2 esté cargada y compilada en la memoria de Stata
capture do "`c(sysdir_plus)'x/xtabond2.mata"
capture mata: mata mlib index

local rel_path "data/processed/00_master_panel/master_panel_country_year.dta"
capture confirm file "`rel_path'"
if !_rc {
    // Ok
}
else {
    capture confirm file "../../../../`rel_path'"
    if !_rc {
        quietly cd "../../../.."
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
                quietly cd "C:/Users/julla/GitHub/master-thesis-project-applied-econ"
            }
        }
    }
}

global PROJECT_ROOT "`c(pwd)'"
global OUTPUT_ROOT              "$PROJECT_ROOT/outputs/econometrics/stata-peer-1/gmm"
global OUTPUT_SAMPLE            "$OUTPUT_ROOT/01_sample"
global OUTPUT_DIAGNOSTICS       "$OUTPUT_ROOT/02_diagnostics"
global OUTPUT_ECI               "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX              "$OUTPUT_ROOT/04_divx"
global OUTPUT_STABILITY         "$OUTPUT_ROOT/05_stability"
global OUTPUT_RESOURCE_DISAGG   "$OUTPUT_ROOT/06_resource_disaggregation"
global OUTPUT_FINAL             "$OUTPUT_ROOT/07_final"
global OUTPUT_LOGS              "$OUTPUT_ROOT/logs"

log using "$OUTPUT_LOGS/02_models_and_exports.log", text replace name(model_log)

* Desplegar encabezado de la Parte 2 de GMM
display as result "=========================================================="
display as result "  GMM PARTE 2: Estimación de Modelos Dinámicos y Exportación"
display as result "=========================================================="

* Verificar existencia de la muestra procesada de GMM
capture confirm file "$OUTPUT_SAMPLE/master_panel_gmm_sample.dta"
if _rc {
    display as error "Error: No se encontró $OUTPUT_SAMPLE/master_panel_gmm_sample.dta"
    display as error "Ejecute primero 01_data_prep_and_diagnostics.do en gmm"
    exit 601
}

// *********************************************
// 5. Modelo Principal de GMM Dinámico: Complejidad Económica (ECI)
// *********************************************

use "$OUTPUT_SAMPLE/master_panel_gmm_sample.dta", clear
xtset country_id year

* Cargar explícitamente la función Mata de xtabond2 en la sesión activa
capture do "`c(sysdir_plus)'x/xtabond2.mata"
capture mata: mata mlib index

* Generar dummies de año para controlar efectos fijos de tiempo
quietly tabulate year, generate(year_dummy_)

* Define vectores de variables
global CONTROLS_COMMON log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin

* 5.1. Modelo (1): GMM Benchmark (Sin Interacción)
display as text "Estimando ECI System GMM Benchmark..."
xtabond2 eci L.eci rents inst year_dummy_*, ///
    gmmstyle(L.eci, laglimits(2 4)) ///
    ivstyle(rents inst year_dummy_*) ///
    twostep robust small
estimates store ECI_GMM_BENCH
estimates save "$OUTPUT_ECI/eci_gmm_bench.ster", replace

* 5.2. Modelo (2): GMM con Término de Interacción (RENTS x INST)
display as text "Estimando ECI System GMM con Interacción..."
xtabond2 eci L.eci rents inst rents_x_inst year_dummy_*, ///
    gmmstyle(L.eci, laglimits(2 4)) ///
    ivstyle(rents inst rents_x_inst year_dummy_*) ///
    twostep robust small
estimates store ECI_GMM_INT
estimates save "$OUTPUT_ECI/eci_gmm_int.ster", replace

* 5.3. Modelo (3): GMM Completo con Controles Estructurales (Modelo Principal ECI)
display as text "Estimando ECI System GMM Completo..."
xtabond2 eci L.eci rents inst rents_x_inst hhi $CONTROLS_COMMON year_dummy_*, ///
    gmmstyle(L.eci, laglimits(2 3)) ///
    ivstyle(rents inst rents_x_inst hhi $CONTROLS_COMMON year_dummy_*) ///
    twostep robust small
estimates store ECI_GMM_FULL
estimates save "$OUTPUT_ECI/eci_gmm_full.ster", replace

* Exportar matriz de coeficientes y errores estándar de ECI a CSV
preserve
    clear
    tempname eci_coeff_post
    tempfile eci_coeff_report
    postfile `eci_coeff_post' str16 model str32 variable double b double se double t_stat double p_val using "`eci_coeff_report'", replace

    foreach m in ECI_GMM_BENCH ECI_GMM_INT ECI_GMM_FULL {
        estimates restore `m'
        matrix B = e(b)
        matrix V = e(V)
        local colnames : colnames B
        local i = 1
        foreach var of local colnames {
            if "`var'" != "_cons" & !regexm("`var'", "year_dummy_") {
                local coef = B[1, `i']
                local se = sqrt(V[`i', `i'])
                local t = `coef' / `se'
                local p = 2 * ttail(e(df_r), abs(`t'))
                post `eci_coeff_post' ("`m'") ("`var'") (`coef') (`se') (`t') (`p')
            }
            local ++i
        }
    }
    postclose `eci_coeff_post'

    use "`eci_coeff_report'", clear
    format b se t_stat p_val %12.4f
    export delimited using "$OUTPUT_ECI/eci_gmm_coefficients.csv", replace
restore

* 5.4. Pruebas de hipótesis conjuntas por canal teórico para ECI (Figura 9.2)
estimates restore ECI_GMM_FULL
tempname eci_tests_post
tempfile eci_tests_report

postfile `eci_tests_post' int order str40 channel str100 null_hypothesis double stat_val double df double df_r double p_val using "`eci_tests_report'", replace

* 1. Canal institucional
test rents inst rents_x_inst
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `eci_tests_post' (1) ("Canal institucional") ("RENTS, INST y RENTSxINST son conjuntamente cero") (`stat') (r(df)) (`dfr') (r(p))

* 2. Canal de abundancia
test log_oilpc log_gaspc log_coalpc
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `eci_tests_post' (2) ("Canal de abundancia") ("OILPC, GASPC y COALPC son conjuntamente cero") (`stat') (r(df)) (`dfr') (r(p))

* 3. Canal estructural
test hhi pexp fexp
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `eci_tests_post' (3) ("Canal estructural") ("HHI, PEXP y FEXP son conjuntamente cero") (`stat') (r(df)) (`dfr') (r(p))

* 4. Canal macroeconómico
test vol rer
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `eci_tests_post' (4) ("Canal macroeconómico") ("VOL y RER son conjuntamente cero") (`stat') (r(df)) (`dfr') (r(p))

* 5. Capacidades productivas
test humcap innov net
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `eci_tests_post' (5) ("Capacidades productivas") ("HUMCAP, INNOV y NET son conjuntamente cero") (`stat') (r(df)) (`dfr') (r(p))

* 6. Control de desarrollo
test log_gdppc
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `eci_tests_post' (6) ("Control de desarrollo") ("log(GDPPC) es cero") (`stat') (r(df)) (`dfr') (r(p))

* 7. Controles fiscales y financieros
test govcons fin
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `eci_tests_post' (7) ("Controles fiscales y financieros") ("GOVCONS y FIN son conjuntamente cero") (`stat') (r(df)) (`dfr') (r(p))

postclose `eci_tests_post'

preserve
    use "`eci_tests_report'", clear
    sort order
    format stat_val p_val %12.4f
    export delimited using "$OUTPUT_ECI/eci_gmm_channel_tests.csv", replace
restore

// *********************************************
// 6. Modelo Complementario de GMM Dinámico: Diversificación (DIVX)
// *********************************************

* Cargar panel preparado de GMM para estimación de DIVX
use "$OUTPUT_SAMPLE/master_panel_gmm_sample.dta", clear
xtset country_id year
quietly tabulate year, generate(year_dummy_)

* 6.1. Modelo (1): GMM DIVX Benchmark
display as text "Estimando DIVX System GMM Benchmark..."
xtabond2 divx L.divx rents inst year_dummy_*, ///
    gmmstyle(L.divx, laglimits(2 4)) ///
    ivstyle(rents inst year_dummy_*) ///
    twostep robust small
estimates store DIVX_GMM_BENCH
estimates save "$OUTPUT_DIVX/divx_gmm_bench.ster", replace

* 6.2. Modelo (2): GMM DIVX con Interacción
display as text "Estimando DIVX System GMM con Interacción..."
xtabond2 divx L.divx rents inst rents_x_inst year_dummy_*, ///
    gmmstyle(L.divx, laglimits(2 4)) ///
    ivstyle(rents inst rents_x_inst year_dummy_*) ///
    twostep robust small
estimates store DIVX_GMM_INT
estimates save "$OUTPUT_DIVX/divx_gmm_int.ster", replace

* 6.3. Modelo (3): GMM DIVX Completo
display as text "Estimando DIVX System GMM Completo..."
xtabond2 divx L.divx rents inst rents_x_inst $CONTROLS_COMMON year_dummy_*, ///
    gmmstyle(L.divx, laglimits(2 3)) ///
    ivstyle(rents inst rents_x_inst $CONTROLS_COMMON year_dummy_*) ///
    twostep robust small
estimates store DIVX_GMM_FULL
estimates save "$OUTPUT_DIVX/divx_gmm_full.ster", replace

* Exportar matriz de coeficientes de DIVX a CSV
preserve
    clear
    tempname divx_coeff_post
    tempfile divx_coeff_report
    postfile `divx_coeff_post' str16 model str32 variable double b double se double t_stat double p_val using "`divx_coeff_report'", replace

    foreach m in DIVX_GMM_BENCH DIVX_GMM_INT DIVX_GMM_FULL {
        estimates restore `m'
        matrix B = e(b)
        matrix V = e(V)
        local colnames : colnames B
        local i = 1
        foreach var of local colnames {
            if "`var'" != "_cons" & !regexm("`var'", "year_dummy_") {
                local coef = B[1, `i']
                local se = sqrt(V[`i', `i'])
                local t = `coef' / `se'
                local p = 2 * ttail(e(df_r), abs(`t'))
                post `divx_coeff_post' ("`m'") ("`var'") (`coef') (`se') (`t') (`p')
            }
            local ++i
        }
    }
    postclose `divx_coeff_post'

    use "`divx_coeff_report'", clear
    format b se t_stat p_val %12.4f
    export delimited using "$OUTPUT_DIVX/divx_gmm_coefficients.csv", replace
restore

* 6.4. Pruebas de hipótesis conjuntas por canal teórico para DIVX (Figura 9.2)
estimates restore DIVX_GMM_FULL
tempname divx_tests_post
tempfile divx_tests_report

postfile `divx_tests_post' int order str40 channel str100 null_hypothesis double stat_val double df double df_r double p_val using "`divx_tests_report'", replace

* 1. Canal institucional
test rents inst rents_x_inst
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `divx_tests_post' (1) ("Canal institucional") ("RENTS, INST y RENTSxINST son conjuntamente cero") (`stat') (r(df)) (`dfr') (r(p))

* 2. Canal de abundancia
test log_oilpc log_gaspc log_coalpc
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `divx_tests_post' (2) ("Canal de abundancia") ("OILPC, GASPC y COALPC son conjuntamente cero") (`stat') (r(df)) (`dfr') (r(p))

* 3. Canal estructural
test pexp fexp
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `divx_tests_post' (3) ("Canal estructural") ("PEXP y FEXP son conjuntamente cero") (`stat') (r(df)) (`dfr') (r(p))

* 4. Canal macroeconómico
test vol rer
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `divx_tests_post' (4) ("Canal macroeconómico") ("VOL y RER son conjuntamente cero") (`stat') (r(df)) (`dfr') (r(p))

* 5. Capacidades productivas
test humcap innov net
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `divx_tests_post' (5) ("Capacidades productivas") ("HUMCAP, INNOV y NET son conjuntamente cero") (`stat') (r(df)) (`dfr') (r(p))

* 6. Control de desarrollo
test log_gdppc
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `divx_tests_post' (6) ("Control de desarrollo") ("log(GDPPC) es cero") (`stat') (r(df)) (`dfr') (r(p))

* 7. Controles fiscales y financieros
test govcons fin
local stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
local dfr = cond(!missing(r(df_r)), r(df_r), .)
post `divx_tests_post' (7) ("Controles fiscales y financieros") ("GOVCONS y FIN son conjuntamente cero") (`stat') (r(df)) (`dfr') (r(p))

postclose `divx_tests_post'

preserve
    use "`divx_tests_report'", clear
    sort order
    format stat_val p_val %12.4f
    export delimited using "$OUTPUT_DIVX/divx_gmm_channel_tests.csv", replace
restore

// *********************************************
// 7. Diagnósticos de Especificación (Sargan/Hansen y AR1/AR2)
// *********************************************

* Definir estructura postfile para diagnósticos de especificación
tempname diag_post
tempfile diag_report

postfile `diag_post' str20 model long obs int countries int instruments ///
    double ar1_stat double ar1_p double ar2_stat double ar2_p ///
    double sargan_stat double sargan_p double hansen_stat double hansen_p ///
    using "`diag_report'", replace

foreach m in ECI_GMM_BENCH ECI_GMM_INT ECI_GMM_FULL DIVX_GMM_BENCH DIVX_GMM_INT DIVX_GMM_FULL {
    estimates restore `m'
    local k_inst     = e(j)
    local ar1_val    = e(ar1)
    local ar1_pval   = e(ar1p)
    local ar2_val    = e(ar2)
    local ar2_pval   = e(ar2p)
    local sargan_val = e(sargan)
    local sargan_pval= e(sarganp)
    local hansen_val = e(hansen)
    local hansen_pval= e(hansenp)

    post `diag_post' ("`m'") (e(N)) (e(N_g)) (`k_inst') ///
        (`ar1_val') (`ar1_pval') (`ar2_val') (`ar2_pval') ///
        (`sargan_val') (`sargan_pval') (`hansen_val') (`hansen_pval')
}
postclose `diag_post'

preserve
    use "`diag_report'", clear
    format ar1_stat ar1_p ar2_stat ar2_p sargan_stat sargan_p hansen_stat hansen_p %12.4f
    export delimited using "$OUTPUT_STABILITY/gmm_specification_tests.csv", replace
    display as text "--- RESUMEN DIAGNÓSTICOS ESPECIFICACIÓN GMM (Sargan / Hansen / AR1 / AR2) ---"
    list, noobs abbreviate(20)
restore

// *********************************************
// 8. Exportación de Resultados y Tablas Principales a LaTeX y Texto
// *********************************************

* Verificar e instalar paquete esttab para exportación a LaTeX
capture which esttab
if _rc == 0 {
    * 8.1. Tabla Principal GMM para Complejidad Económica (ECI)
    esttab ECI_GMM_BENCH ECI_GMM_INT ECI_GMM_FULL using "$OUTPUT_FINAL/table_eci_gmm.tex", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        title("Modelos System GMM Dinámicos: Complejidad Económica (ECI)") ///
        mtitles("Benchmark" "Interacción" "Controles Completos") ///
        booktabs alignment(c) drop(year_dummy_*) ///
        stats(N N_g j ar1 ar1p ar2 ar2p hansen hansenp, ///
              labels("Observaciones" "Países" "Instrumentos" "AR(1) Stat" "AR(1) p-val" "AR(2) Stat" "AR(2) p-val" "Hansen J Stat" "Hansen p-val"))

    esttab ECI_GMM_BENCH ECI_GMM_INT ECI_GMM_FULL using "$OUTPUT_FINAL/table_eci_gmm.txt", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        mtitles("Benchmark" "Interacción" "Controles Completos") ///
        drop(year_dummy_*) ///
        stats(N N_g j ar1 ar1p ar2 ar2p hansen hansenp, ///
              labels("Observaciones" "Países" "Instrumentos" "AR(1) Stat" "AR(1) p-val" "AR(2) Stat" "AR(2) p-val" "Hansen J Stat" "Hansen p-val"))

    * 8.2. Tabla Principal GMM para Diversificación (DIVX)
    esttab DIVX_GMM_BENCH DIVX_GMM_INT DIVX_GMM_FULL using "$OUTPUT_FINAL/table_divx_gmm.tex", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        title("Modelos System GMM Dinámicos: Diversificación Exportadora (DIVX)") ///
        mtitles("Benchmark" "Interacción" "Controles Completos") ///
        booktabs alignment(c) drop(year_dummy_*) ///
        stats(N N_g j ar1 ar1p ar2 ar2p hansen hansenp, ///
              labels("Observaciones" "Países" "Instrumentos" "AR(1) Stat" "AR(1) p-val" "AR(2) Stat" "AR(2) p-val" "Hansen J Stat" "Hansen p-val"))

    esttab DIVX_GMM_BENCH DIVX_GMM_INT DIVX_GMM_FULL using "$OUTPUT_FINAL/table_divx_gmm.txt", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        mtitles("Benchmark" "Interacción" "Controles Completos") ///
        drop(year_dummy_*) ///
        stats(N N_g j ar1 ar1p ar2 ar2p hansen hansenp, ///
              labels("Observaciones" "Países" "Instrumentos" "AR(1) Stat" "AR(1) p-val" "AR(2) Stat" "AR(2) p-val" "Hansen J Stat" "Hansen p-val"))

    * 8.3. Tabla Comparativa ECI vs DIVX (Modelos Principales GMM)
    esttab ECI_GMM_FULL DIVX_GMM_FULL using "$OUTPUT_FINAL/table_eci_divx_gmm.tex", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        title("Modelos System GMM Comparativos: ECI y DIVX") ///
        mtitles("ECI (Complejidad)" "DIVX (Diversificación)") ///
        booktabs alignment(c) drop(year_dummy_*) ///
        stats(N N_g j ar1 ar1p ar2 ar2p hansen hansenp, ///
              labels("Observaciones" "Países" "Instrumentos" "AR(1) Stat" "AR(1) p-val" "AR(2) Stat" "AR(2) p-val" "Hansen J Stat" "Hansen p-val"))

    esttab ECI_GMM_FULL DIVX_GMM_FULL using "$OUTPUT_FINAL/table_eci_divx_gmm.txt", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        mtitles("ECI (Complejidad)" "DIVX (Diversificación)") ///
        drop(year_dummy_*) ///
        stats(N N_g j ar1 ar1p ar2 ar2p hansen hansenp, ///
              labels("Observaciones" "Países" "Instrumentos" "AR(1) Stat" "AR(1) p-val" "AR(2) Stat" "AR(2) p-val" "Hansen J Stat" "Hansen p-val"))
}

* Confirmar finalización de la Parte 2 de GMM
display as result "=========================================================="
display as result "  Parte 2 (Secciones 5 a 8) completada con éxito."
display as result "=========================================================="
log close model_log
