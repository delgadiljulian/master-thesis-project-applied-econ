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
// Archivo: 03_resource_disaggregation.do (Parte 3 - Secciones 9 a 14: GMM Desagregado)
// Ubicación: scripts/econometrics/stata-peer-1/gmm/
// Fecha: Segundo Cuatrimestre 2026
// *********************************************

// *********************************************
// 0. Configuración del Entorno y Rutas de Trabajo (GMM Desagregado)
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

global PROJECT_ROOT              "`c(pwd)'"
global OUTPUT_ROOT               "$PROJECT_ROOT/outputs/econometrics/stata-peer-1/gmm"
global OUTPUT_SAMPLE             "$OUTPUT_ROOT/01_sample"
global OUTPUT_DISAGG             "$OUTPUT_ROOT/06_resource_disaggregation"
global OUTPUT_DISAGG_DESIGN      "$OUTPUT_DISAGG/00_design"
global OUTPUT_DISAGG_DIAGNOSTICS "$OUTPUT_DISAGG/02_diagnostics"
global OUTPUT_DISAGG_ECI         "$OUTPUT_DISAGG/03_eci"
global OUTPUT_DISAGG_DIVX        "$OUTPUT_DISAGG/04_divx"
global OUTPUT_DISAGG_STABILITY   "$OUTPUT_DISAGG/05_stability"
global OUTPUT_DISAGG_FINAL       "$OUTPUT_DISAGG/07_final"
global OUTPUT_DISAGG_LOGS        "$OUTPUT_ROOT/logs"

capture mkdir "$OUTPUT_ROOT"
capture mkdir "$OUTPUT_DISAGG"
capture mkdir "$OUTPUT_DISAGG_DESIGN"
capture mkdir "$OUTPUT_DISAGG_DIAGNOSTICS"
capture mkdir "$OUTPUT_DISAGG_ECI"
capture mkdir "$OUTPUT_DISAGG_DIVX"
capture mkdir "$OUTPUT_DISAGG_STABILITY"
capture mkdir "$OUTPUT_DISAGG_FINAL"
capture mkdir "$OUTPUT_DISAGG_LOGS"

log using "$OUTPUT_DISAGG_LOGS/03_resource_disaggregation.log", text replace name(disagg_log)

* Desplegar encabezado de la Parte 3 de GMM
display as result "=========================================================="
display as result "  GMM PARTE 3: Desagregación por Tipo de Recurso (Eq. 9.38)"
display as result "=========================================================="

* Verificar existencia de la muestra procesada de GMM
capture confirm file "$OUTPUT_SAMPLE/master_panel_gmm_sample.dta"
if _rc {
    display as error "Error: No se encontró $OUTPUT_SAMPLE/master_panel_gmm_sample.dta"
    display as error "Debe ejecutar primero 01_data_prep_and_diagnostics.do"
    exit 601
}

* Cargar panel preparado de GMM para la estimación desagregada
use "$OUTPUT_SAMPLE/master_panel_gmm_sample.dta", clear
xtset country_id year

// *********************************************
// 9. Diseño de la Desagregación de RENTS en GMM
// *********************************************

* 9.1. Comprobar presencia de variables desagregadas en el panel
foreach var in rents rents_oil_gas rents_mining {
    capture confirm numeric variable `var'
    if _rc {
        display as error "Error: La variable `var' debe ser numérica."
        exit 109
    }
}

* 9.2. Verificar identidad contable: RENTS = RENTS_OIL_GAS + RENTS_MINING
tempvar rents_gap
generate double `rents_gap' = abs(rents - rents_oil_gas - rents_mining) if !missing(rents, rents_oil_gas, rents_mining)
quietly summarize `rents_gap', meanonly
assert r(max) <= 1e-10

* 9.3. Generar y etiquetar interacciones desagregadas con calidad institucional (INST)
capture drop rents_oil_gas_x_inst rents_mining_x_inst
generate double rents_oil_gas_x_inst = rents_oil_gas * inst if !missing(rents_oil_gas, inst)
generate double rents_mining_x_inst  = rents_mining  * inst if !missing(rents_mining, inst)
label variable rents_oil_gas_x_inst "RENTS_OIL_GAS x INST"
label variable rents_mining_x_inst  "RENTS_MINING x INST"

* Generar dummies de año para controlar efectos fijos de tiempo
quietly tabulate year, generate(year_dummy_)

* Definir vector global de controles macroeconómicos y estructurales
global CONTROLS_COMMON log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin

// *********************************************
// 10. Preparación y Diagnósticos de los Componentes Desagregados
// *********************************************

* Definir estructura postfile para descriptivas de componentes desagregados
tempname desc_disagg_post
tempfile desc_disagg_report

postfile `desc_disagg_post' str24 variable long observations double mean double sd double min double p50 double max using "`desc_disagg_report'", replace

foreach var in rents_oil_gas rents_mining rents_oil_gas_x_inst rents_mining_x_inst {
    quietly summarize `var' if sample_gmm_eci == 1, detail
    post `desc_disagg_post' ("`var'") (r(N)) (r(mean)) (r(sd)) (r(min)) (r(p50)) (r(max))
}
postclose `desc_disagg_post'

preserve
    use "`desc_disagg_report'", clear
    format mean sd min p50 max %12.4f
    export delimited using "$OUTPUT_DISAGG_DIAGNOSTICS/descriptive_statistics_disagg_gmm.csv", replace
restore

// *********************************************
// 11. Modelos GMM Dinámicos Desagregados con ECI
// *********************************************

* 11.1. Benchmark Desagregado ECI (Sin Interacciones)
display as text "Estimando ECI System GMM Desagregado Benchmark..."
xtabond2 eci L.eci rents_oil_gas rents_mining inst year_dummy_*, ///
    gmmstyle(L.eci, laglimits(2 4)) ///
    ivstyle(rents_oil_gas rents_mining inst year_dummy_*) ///
    twostep robust small
estimates store ECI_DISAGG_GMM_BENCH
estimates save "$OUTPUT_DISAGG_ECI/eci_disagg_gmm_bench.ster", replace

* 11.2. Interacción Desagregada ECI
display as text "Estimando ECI System GMM Desagregado con Interacciones..."
xtabond2 eci L.eci rents_oil_gas rents_mining inst rents_oil_gas_x_inst rents_mining_x_inst year_dummy_*, ///
    gmmstyle(L.eci, laglimits(2 4)) ///
    ivstyle(rents_oil_gas rents_mining inst rents_oil_gas_x_inst rents_mining_x_inst year_dummy_*) ///
    twostep robust small
estimates store ECI_DISAGG_GMM_INT
estimates save "$OUTPUT_DISAGG_ECI/eci_disagg_gmm_int.ster", replace

* 11.3. Modelo Completo Desagregado ECI
display as text "Estimando ECI System GMM Desagregado Completo..."
xtabond2 eci L.eci rents_oil_gas rents_mining inst rents_oil_gas_x_inst rents_mining_x_inst hhi $CONTROLS_COMMON year_dummy_*, ///
    gmmstyle(L.eci, laglimits(2 3)) ///
    ivstyle(rents_oil_gas rents_mining inst rents_oil_gas_x_inst rents_mining_x_inst hhi $CONTROLS_COMMON year_dummy_*) ///
    twostep robust small
estimates store ECI_DISAGG_GMM_FULL
estimates save "$OUTPUT_DISAGG_ECI/eci_disagg_gmm_full.ster", replace

* Exportar coeficientes de ECI Desagregado a CSV
preserve
    clear
    tempname eci_disagg_coeff_post
    tempfile eci_disagg_coeff_report
    postfile `eci_disagg_coeff_post' str24 model str32 variable double b double se double t_stat double p_val using "`eci_disagg_coeff_report'", replace

    foreach m in ECI_DISAGG_GMM_BENCH ECI_DISAGG_GMM_INT ECI_DISAGG_GMM_FULL {
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
                post `eci_disagg_coeff_post' ("`m'") ("`var'") (`coef') (`se') (`t') (`p')
            }
            local ++i
        }
    }
    postclose `eci_disagg_coeff_post'

    use "`eci_disagg_coeff_report'", clear
    format b se t_stat p_val %12.4f
    export delimited using "$OUTPUT_DISAGG_ECI/eci_disagg_gmm_coefficients.csv", replace
restore

// *********************************************
// 12. Modelos GMM Dinámicos Desagregados con DIVX
// *********************************************

* 12.1. Benchmark Desagregado DIVX
display as text "Estimando DIVX System GMM Desagregado Benchmark..."
xtabond2 divx L.divx rents_oil_gas rents_mining inst year_dummy_*, ///
    gmmstyle(L.divx, laglimits(2 4)) ///
    ivstyle(rents_oil_gas rents_mining inst year_dummy_*) ///
    twostep robust small
estimates store DIVX_DISAGG_GMM_BENCH
estimates save "$OUTPUT_DISAGG_DIVX/divx_disagg_gmm_bench.ster", replace

* 12.2. Interacción Desagregada DIVX
display as text "Estimando DIVX System GMM Desagregado con Interacciones..."
xtabond2 divx L.divx rents_oil_gas rents_mining inst rents_oil_gas_x_inst rents_mining_x_inst year_dummy_*, ///
    gmmstyle(L.divx, laglimits(2 4)) ///
    ivstyle(rents_oil_gas rents_mining inst rents_oil_gas_x_inst rents_mining_x_inst year_dummy_*) ///
    twostep robust small
estimates store DIVX_DISAGG_GMM_INT
estimates save "$OUTPUT_DISAGG_DIVX/divx_disagg_gmm_int.ster", replace

* 12.3. Modelo Completo Desagregado DIVX
display as text "Estimando DIVX System GMM Desagregado Completo..."
xtabond2 divx L.divx rents_oil_gas rents_mining inst rents_oil_gas_x_inst rents_mining_x_inst $CONTROLS_COMMON year_dummy_*, ///
    gmmstyle(L.divx, laglimits(2 3)) ///
    ivstyle(rents_oil_gas rents_mining inst rents_oil_gas_x_inst rents_mining_x_inst $CONTROLS_COMMON year_dummy_*) ///
    twostep robust small
estimates store DIVX_DISAGG_GMM_FULL
estimates save "$OUTPUT_DISAGG_DIVX/divx_disagg_gmm_full.ster", replace

* Exportar coeficientes de DIVX Desagregado a CSV
preserve
    clear
    tempname divx_disagg_coeff_post
    tempfile divx_disagg_coeff_report
    postfile `divx_disagg_coeff_post' str24 model str32 variable double b double se double t_stat double p_val using "`divx_disagg_coeff_report'", replace

    foreach m in DIVX_DISAGG_GMM_BENCH DIVX_DISAGG_GMM_INT DIVX_DISAGG_GMM_FULL {
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
                post `divx_disagg_coeff_post' ("`m'") ("`var'") (`coef') (`se') (`t') (`p')
            }
            local ++i
        }
    }
    postclose `divx_disagg_coeff_post'

    use "`divx_disagg_coeff_report'", clear
    format b se t_stat p_val %12.4f
    export delimited using "$OUTPUT_DISAGG_DIVX/divx_disagg_gmm_coefficients.csv", replace
restore

// *********************************************
// 13. Estabilidad, Diagnósticos de Instrumentos y Efectos Marginales
// *********************************************

* Definir estructura postfile para diagnósticos de especificación desagregada
tempname disagg_diag_post
tempfile disagg_diag_report

postfile `disagg_diag_post' str24 model long obs int countries int instruments ///
    double ar1_stat double ar1_p double ar2_stat double ar2_p ///
    double sargan_stat double sargan_p double hansen_stat double hansen_p ///
    double eq_test_stat double eq_test_p ///
    using "`disagg_diag_report'", replace

foreach m in ECI_DISAGG_GMM_BENCH ECI_DISAGG_GMM_INT ECI_DISAGG_GMM_FULL DIVX_DISAGG_GMM_BENCH DIVX_DISAGG_GMM_INT DIVX_DISAGG_GMM_FULL {
    estimates restore `m'
    
    * Prueba de igualdad de efectos entre hidrocarburos y minería
    quietly test rents_oil_gas = rents_mining
    local eq_stat = cond(!missing(r(F)), r(F), cond(!missing(r(chi2)), r(chi2), .))
    local eq_p    = r(p)

    local k_inst     = e(j)
    local ar1_val    = e(ar1)
    local ar1_pval   = e(ar1p)
    local ar2_val    = e(ar2)
    local ar2_pval   = e(ar2p)
    local sargan_val = e(sargan)
    local sargan_pval= e(sarganp)
    local hansen_val = e(hansen)
    local hansen_pval= e(hansenp)

    post `disagg_diag_post' ("`m'") (e(N)) (e(N_g)) (`k_inst') ///
        (`ar1_val') (`ar1_pval') (`ar2_val') (`ar2_pval') ///
        (`sargan_val') (`sargan_pval') (`hansen_val') (`hansen_pval') ///
        (`eq_stat') (`eq_p')
}
postclose `disagg_diag_post'

preserve
    use "`disagg_diag_report'", clear
    format ar1_stat ar1_p ar2_stat ar2_p sargan_stat sargan_p hansen_stat hansen_p eq_test_stat eq_test_p %12.4f
    export delimited using "$OUTPUT_DISAGG_STABILITY/gmm_disagg_specification_tests.csv", replace
    display as text "--- RESUMEN PRUEBAS DE ESPECIFICACIÓN Y EQUIVALENCIA DE RECURSOS (GMM DESAGREGADO) ---"
    list, noobs abbreviate(20)
restore

// *********************************************
// 14. Exportación y Cierre de la Desagregación GMM (Tablas LaTeX y Texto)
// *********************************************

* Verificar e instalar paquete esttab para exportación de modelos desagregados
capture which esttab
if _rc == 0 {
    * 14.1. Tabla Principal GMM Desagregado para Complejidad Económica (ECI)
    esttab ECI_DISAGG_GMM_BENCH ECI_DISAGG_GMM_INT ECI_DISAGG_GMM_FULL using "$OUTPUT_DISAGG_FINAL/table_eci_disagg_gmm.tex", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        title("Modelos System GMM Desagregados por Tipo de Recurso: Complejidad Económica (ECI)") ///
        mtitles("Benchmark" "Interacción" "Controles Completos") ///
        booktabs alignment(c) drop(year_dummy_*) ///
        stats(N N_g j ar1 ar1p ar2 ar2p hansen hansenp, ///
              labels("Observaciones" "Países" "Instrumentos" "AR(1) Stat" "AR(1) p-val" "AR(2) Stat" "AR(2) p-val" "Hansen J Stat" "Hansen p-val"))

    esttab ECI_DISAGG_GMM_BENCH ECI_DISAGG_GMM_INT ECI_DISAGG_GMM_FULL using "$OUTPUT_DISAGG_FINAL/table_eci_disagg_gmm.txt", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        mtitles("Benchmark" "Interacción" "Controles Completos") ///
        drop(year_dummy_*) ///
        stats(N N_g j ar1 ar1p ar2 ar2p hansen hansenp, ///
              labels("Observaciones" "Países" "Instrumentos" "AR(1) Stat" "AR(1) p-val" "AR(2) Stat" "AR(2) p-val" "Hansen J Stat" "Hansen p-val"))

    * 14.2. Tabla Principal GMM Desagregado para Diversificación (DIVX)
    esttab DIVX_DISAGG_GMM_BENCH DIVX_DISAGG_GMM_INT DIVX_DISAGG_GMM_FULL using "$OUTPUT_DISAGG_FINAL/table_divx_disagg_gmm.tex", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        title("Modelos System GMM Desagregados por Tipo de Recurso: Diversificación Exportadora (DIVX)") ///
        mtitles("Benchmark" "Interacción" "Controles Completos") ///
        booktabs alignment(c) drop(year_dummy_*) ///
        stats(N N_g j ar1 ar1p ar2 ar2p hansen hansenp, ///
              labels("Observaciones" "Países" "Instrumentos" "AR(1) Stat" "AR(1) p-val" "AR(2) Stat" "AR(2) p-val" "Hansen J Stat" "Hansen p-val"))

    esttab DIVX_DISAGG_GMM_BENCH DIVX_DISAGG_GMM_INT DIVX_DISAGG_GMM_FULL using "$OUTPUT_DISAGG_FINAL/table_divx_disagg_gmm.txt", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        mtitles("Benchmark" "Interacción" "Controles Completos") ///
        drop(year_dummy_*) ///
        stats(N N_g j ar1 ar1p ar2 ar2p hansen hansenp, ///
              labels("Observaciones" "Países" "Instrumentos" "AR(1) Stat" "AR(1) p-val" "AR(2) Stat" "AR(2) p-val" "Hansen J Stat" "Hansen p-val"))

    * 14.3. Tabla Comparativa ECI vs DIVX Desagregados (Modelos Completos)
    esttab ECI_DISAGG_GMM_FULL DIVX_DISAGG_GMM_FULL using "$OUTPUT_DISAGG_FINAL/table_eci_divx_disagg_gmm.tex", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        title("Modelos System GMM Desagregados Comparativos: ECI y DIVX") ///
        mtitles("ECI (Complejidad)" "DIVX (Diversificación)") ///
        booktabs alignment(c) drop(year_dummy_*) ///
        stats(N N_g j ar1 ar1p ar2 ar2p hansen hansenp, ///
              labels("Observaciones" "Países" "Instrumentos" "AR(1) Stat" "AR(1) p-val" "AR(2) Stat" "AR(2) p-val" "Hansen J Stat" "Hansen p-val"))

    esttab ECI_DISAGG_GMM_FULL DIVX_DISAGG_GMM_FULL using "$OUTPUT_DISAGG_FINAL/table_eci_divx_disagg_gmm.txt", replace ///
        label b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
        mtitles("ECI (Complejidad)" "DIVX (Diversificación)") ///
        drop(year_dummy_*) ///
        stats(N N_g j ar1 ar1p ar2 ar2p hansen hansenp, ///
              labels("Observaciones" "Países" "Instrumentos" "AR(1) Stat" "AR(1) p-val" "AR(2) Stat" "AR(2) p-val" "Hansen J Stat" "Hansen p-val"))
}

* Confirmar finalización de la Parte 3 de GMM
display as result "=========================================================="
display as result "  Parte 3 (Secciones 9 a 14) completada con éxito."
display as result "=========================================================="
log close disagg_log
