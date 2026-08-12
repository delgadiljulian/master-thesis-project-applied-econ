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
// Módulo: 02_temporal_fe — Efectos fijos y orden temporal
// Archivo: 03_leads_changes_and_sensitivity.do (Versión Codex)
// Contenido: Secciones 14 a 20 — T4, T5, estabilidad por país y decisión
//            metodológica
// Requisitos: completar los archivos temporales 01 y 02
// Fecha: Segundo Cuatrimestre 2026
//
// ESTADO: COMPLETO. Secciones 14 a 20 implementadas y validadas.
// *****************************************************************************


// *****************************************************************************
// PROPÓSITO, ALCANCE Y CONTRATO ECONOMÉTRICO DEL ARCHIVO 03
// *****************************************************************************
//
// 1. OBJETIVO DE FALSIFICACIÓN Y SENSIBILIDAD:
//    Este archivo somete las especificaciones temporales preferidas (T1/T2) a cuatro
//    pruebas econométricas de sensibilidad y falsificación:
//
// 2. MODALIDADES DE DIAGNÓSTICO:
//    - T4 (Placebo / Adelanto t+1): Y_it = alpha_i + delta_t + beta_lead RENTS_i,t+1 + X_it' gamma + epsilon_it
//      * Criterio placebo: H0: beta_lead = 0. Un beta_lead != 0 sugiere causalidad inversa o anticipación.
//    - T5 (Primeras Diferencias - FD): Delta Y_it = delta_t + gamma_1 Delta RENTS_it + Delta X_it' gamma + u_it
//      * Remueve heterogeneidad inobservable invariante en el tiempo mediante diferenciación directa.
//    - Leave-One-Country-Out (LOO): Re-estimación iterativa (G-1) para descartar sensibilidad a un país dominante.
//    - Tendencias Específicas por País (Country-Specific Linear Trends):
//      Y_it = alpha_i + lambda_i × t + delta_t + beta_1 RENTS_it + ... + epsilon_it
//      * Controla por trayectorias seculares no observadas diferenciadas por nación.
//
// 3. MATRIZ DE DECISIÓN Y MANIFIESTO FINAL:
//    Consolida las decisiones de aceptación/rechazo en 09_final/temporal_acceptance_decision.csv
//    y compila el manifiesto reproducible de resultados del módulo temporal.
//
// 4. ENTRADAS Y SALIDAS:
//    - Entradas: 01_sample/temporal_panel.dta y modelos .ster generados por el archivo 02.
//    - Salidas:  06_placebo/lead_placebo_tests.csv
//               07_changes/first_difference_results.csv
//               08_stability/temporal_leave_one_out.csv
//               08_stability/country_trend_sensitivity.csv
//               09_final/temporal_acceptance_decision.csv
//               09_final/temporal_results_manifest.csv
//               logs/03_leads_changes_and_sensitivity.log
// *****************************************************************************


// *****************************************************************************
// 14. Inicialización y verificación de dependencias
// *****************************************************************************

// 14.1. Entorno, raíz y rutas

* El archivo puede comenzar en una sesión nueva de Stata.
* Las estimaciones necesarias se leen del disco y no de la memoria anterior.

version 17.0
clear all
cls
macro drop _all
capture log close _all

set more off
set varabbrev off
set type double
set linesize 255
set seed 20260803
set sortseed 20260803

* Usar el panel maestro para identificar automáticamente la raíz del proyecto.
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
        capture confirm file "`project_candidate'/`project_marker'"
        if !_rc {
            quietly cd "`project_candidate'"
            global PROJECT_ROOT "`c(pwd)'"
        }
    }
    local project_candidate "`project_candidate'/.."
}

if "$PROJECT_ROOT" == "" {
    capture confirm file "`project_windows'/`project_marker'"
    if !_rc {
        global PROJECT_ROOT "`project_windows'"
    }
}

if "$PROJECT_ROOT" == "" & "`project_manual'" != "" {
    capture confirm file "`project_manual'/`project_marker'"
    if !_rc {
        global PROJECT_ROOT "`project_manual'"
    }
}

if "$PROJECT_ROOT" == "" {
    display as error "No se pudo localizar la raíz del repositorio."
    display as error "Directorio inicial: `c(pwd)'"
    display as error "Edite project_manual en la sección 14.1."
    exit 601
}

quietly cd "$PROJECT_ROOT"

* Centralizar todas las rutas del módulo temporal.
global SCRIPT_ROOT ///
    "$PROJECT_ROOT/scripts/econometrics/stata-peer-2/02_temporal_fe"
global OUTPUT_ROOT ///
    "$PROJECT_ROOT/outputs/econometrics/stata-peer-2/02_temporal_fe"
global OUTPUT_DESIGN      "$OUTPUT_ROOT/00_design"
global OUTPUT_SAMPLE      "$OUTPUT_ROOT/01_sample"
global OUTPUT_DIAGNOSTICS "$OUTPUT_ROOT/02_diagnostics"
global OUTPUT_ECI         "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX        "$OUTPUT_ROOT/04_divx"
global OUTPUT_CUMULATIVE  "$OUTPUT_ROOT/05_cumulative"
global OUTPUT_PLACEBO     "$OUTPUT_ROOT/06_placebo"
global OUTPUT_CHANGES     "$OUTPUT_ROOT/07_changes"
global OUTPUT_STABILITY   "$OUTPUT_ROOT/08_stability"
global OUTPUT_FINAL       "$OUTPUT_ROOT/09_final"
global OUTPUT_LOGS        "$OUTPUT_ROOT/logs"
global ADO_PROJECT        "$OUTPUT_ROOT/ado"
global ADO_TWFE ///
    "$PROJECT_ROOT/outputs/econometrics/stata-peer-2/01_twfe_main/ado/plus"

global TEMPORAL_PANEL ///
    "$OUTPUT_SAMPLE/temporal_panel.dta"
global TEMPORAL_SAMPLE_SUMMARY ///
    "$OUTPUT_SAMPLE/temporal_sample_summary.csv"
global TEMPORAL_HANDOFF ///
    "$OUTPUT_FINAL/02_models_handoff.csv"
global TEMPORAL_MANIFEST ///
    "$OUTPUT_FINAL/02_results_manifest.csv"

* Crear únicamente las carpetas de salida utilizadas por el archivo 03.
capture mkdir "$OUTPUT_PLACEBO"
capture mkdir "$OUTPUT_CHANGES"
capture mkdir "$OUTPUT_STABILITY"
capture mkdir "$OUTPUT_FINAL"
capture mkdir "$OUTPUT_LOGS"

log using "$OUTPUT_LOGS/03_leads_changes_and_sensitivity.log", ///
    text replace name(temporal_sensitivity_log)

display as text "14. Inicialización y verificación de dependencias"
display as result "Stata:    versión 17.0"
display as result "Proyecto: $PROJECT_ROOT"
display as result "Entrada:  $TEMPORAL_PANEL"
display as result "Salidas:  $OUTPUT_ROOT"
display as result "Inicio:   `c(current_date)' `c(current_time)'"

* Verificar las herramientas incluidas en Stata y el paquete boottest.
* No instalar paquetes mientras se ejecuta el análisis.
adopath ++ "$ADO_PROJECT/plus"
adopath ++ "$ADO_TWFE"

local required_native_commands ///
    isid levelsof xtset xtdescribe regress xtreg test lincom estimates

foreach command of local required_native_commands {
    capture which `command'
    if _rc {
        display as error "Stata no encuentra el comando requerido: `command'"
        exit 199
    }
}

capture which boottest
if _rc {
    display as error ///
        "No se encontró boottest en las bibliotecas ado del proyecto."
    exit 199
}

mata: mata mlib index

display as result ///
    "Entorno, rutas y dependencias de la sección 14.1 verificados."


// 14.2. Verificar productos de los archivos 01 y 02

* Confirmar el inventario mínimo requerido antes de cargar datos.
local required_previous_outputs ///
    00_design/temporal_specification_register.csv ///
    01_sample/temporal_panel.dta ///
    01_sample/temporal_sample_summary.csv ///
    01_sample/temporal_sample_loss_summary.csv ///
    02_diagnostics/lag_correlation_and_vif.csv ///
    03_eci/eci_temporal_coefficients.csv ///
    03_eci/eci_t1_own.ster ///
    03_eci/eci_t2_own.ster ///
    04_divx/divx_temporal_coefficients.csv ///
    04_divx/divx_t1_own.ster ///
    04_divx/divx_t2_own.ster ///
    05_cumulative/cumulative_effect_tests.csv ///
    05_cumulative/temporal_wild_cluster_bootstrap.csv ///
    09_final/temporal_model_coefficients.csv ///
    09_final/02_models_handoff.csv ///
    09_final/02_results_manifest.csv

foreach relative_input of local required_previous_outputs {
    capture confirm file "$OUTPUT_ROOT/`relative_input'"
    if _rc {
        display as error "Falta un producto obligatorio de los archivos 01 o 02:"
        display as error "$OUTPUT_ROOT/`relative_input'"
        display as error ///
            "Ejecute primero 01_temporal_data_and_samples.do y el archivo 02."
        exit 601
    }
}

* Cargar exclusivamente el panel temporal congelado.
use "$TEMPORAL_PANEL", clear

local temporal_module : char _dta[temporal_module]
local temporal_stage : char _dta[temporal_stage]
assert "`temporal_module'" == "02_temporal_fe"
assert "`temporal_stage'" == "Secciones 1 a 6 completas"

isid country_iso3_code year
quietly count
assert r(N) == 1430

quietly levelsof country_id, local(panel_country_ids)
local panel_countries : word count `panel_country_ids'
assert `panel_countries' == 55

quietly summarize year, meanonly
assert r(min) == 1996
assert r(max) == 2021

xtset country_id year
assert r(panelvar) == "country_id"
assert r(timevar) == "year"

confirm variable ///
    country_iso3_code country country_id year eci divx rents inst ///
    rents_x_inst continuity_l1 continuity_l2 continuity_f1 ///
    t1_rents t1_inst t1_rents_x_inst ///
    t2_ma3_rents t2_ma3_inst t2_ma3_rents_x_inst ///
    t4_rents_f1 t5_d_eci t5_d_divx t5_d_rents t5_d_inst ///
    sample_t1_eci sample_t2_eci sample_t4_eci sample_t5_eci ///
    sample_t1_divx sample_t2_divx sample_t4_divx sample_t5_divx

* Recalcular las identidades que sostienen las pruebas T4 y T5.
assert continuity_l1 == (year > 1996)
assert continuity_l2 == (year > 1997)
assert continuity_f1 == (year < 2021)

assert t4_rents_f1 == F1.rents ///
    if continuity_f1 == 1 & !missing(t4_rents_f1, F1.rents)
assert abs(t5_d_eci - (eci - L1.eci)) <= 1e-10 ///
    if !missing(t5_d_eci, eci, L1.eci)
assert abs(t5_d_divx - (divx - L1.divx)) <= 1e-10 ///
    if !missing(t5_d_divx, divx, L1.divx)
assert abs(t5_d_rents - (rents - L1.rents)) <= 1e-10 ///
    if !missing(t5_d_rents, rents, L1.rents)
assert abs(t5_d_inst - (inst - L1.inst)) <= 1e-10 ///
    if !missing(t5_d_inst, inst, L1.inst)

* ECI y DIVX deben compartir las mismas observaciones en cada diseño temporal.
foreach model in t1 t2 t4 t5 {
    assert sample_`model'_eci == sample_`model'_divx
}

* Recontar muestras, países y años efectivos directamente desde el panel.
foreach outcome in eci divx {
    foreach model in t1 t2 t4 t5 {
        local sample_variable "sample_`model'_`outcome'"
        assert inlist(`sample_variable', 0, 1)

        quietly count if `sample_variable' == 1
        scalar CHECK_N_`outcome'_`model' = r(N)

        quietly levelsof country_id if `sample_variable' == 1, ///
            local(check_country_ids)
        local check_countries : word count `check_country_ids'
        scalar CHECK_G_`outcome'_`model' = `check_countries'

        quietly levelsof year if `sample_variable' == 1, ///
            local(check_year_values)
        local check_years : word count `check_year_values'
        scalar CHECK_T_`outcome'_`model' = `check_years'

        quietly summarize year if `sample_variable' == 1, meanonly
        scalar CHECK_FIRST_`outcome'_`model' = r(min)
        scalar CHECK_LAST_`outcome'_`model' = r(max)

        assert scalar(CHECK_N_`outcome'_`model') > 0
        assert scalar(CHECK_G_`outcome'_`model') >= 50
        assert scalar(CHECK_T_`outcome'_`model') >= 18
    }
}

* Reconciliar los conteos con el reporte producido por el archivo 01.
preserve
    import delimited using "$TEMPORAL_SAMPLE_SUMMARY", ///
        clear varnames(1)
    assert _N == 16
    isid outcome model

    foreach outcome in eci divx {
        foreach model in t1 t2 t4 t5 {
            quietly summarize observations if outcome == "`outcome'" & ///
                model == "`model'", meanonly
            assert r(N) == 1
            assert r(mean) == scalar(CHECK_N_`outcome'_`model')

            quietly summarize countries if outcome == "`outcome'" & ///
                model == "`model'", meanonly
            assert r(N) == 1
            assert r(mean) == scalar(CHECK_G_`outcome'_`model')

            quietly summarize calendar_years if outcome == "`outcome'" & ///
                model == "`model'", meanonly
            assert r(N) == 1
            assert r(mean) == scalar(CHECK_T_`outcome'_`model')

            quietly summarize first_year if outcome == "`outcome'" & ///
                model == "`model'", meanonly
            assert r(N) == 1
            assert r(mean) == scalar(CHECK_FIRST_`outcome'_`model')

            quietly summarize last_year if outcome == "`outcome'" & ///
                model == "`model'", meanonly
            assert r(N) == 1
            assert r(mean) == scalar(CHECK_LAST_`outcome'_`model')
        }
    }
restore

* Validar estructura y existencia de cada producto enumerado por el manifiesto.
preserve
    import delimited using "$TEMPORAL_MANIFEST", clear varnames(1)
    assert _N == 11
    isid order
    assert status == "validated"

    forvalues row = 1/`=_N' {
        local manifest_path = relative_path[`row']
        capture confirm file "$OUTPUT_ROOT/`manifest_path'"
        assert _rc == 0
    }
restore

* Verificar los tamaños y llaves de las tablas producidas por el archivo 02.
preserve
    import delimited using ///
        "$OUTPUT_FINAL/temporal_model_coefficients.csv", ///
        clear varnames(1)
    assert _N == 52
    isid outcome model term
    bysort outcome: assert _N == 26
    assert inrange(p_value, 0, 1)
restore

preserve
    import delimited using ///
        "$OUTPUT_CUMULATIVE/cumulative_effect_tests.csv", ///
        clear varnames(1)
    assert _N == 8
    isid outcome sample_type test_type
    assert inrange(p_value, 0, 1)
restore

preserve
    import delimited using ///
        "$OUTPUT_CUMULATIVE/temporal_wild_cluster_bootstrap.csv", ///
        clear varnames(1)
    assert _N == 10
    isid outcome model term
    assert repetitions == 9999
    assert countries == 53
    isid seed
    assert seed == 2608000 + order
    assert inrange(bootstrap_p, 0, 1)
restore

* Extraer de la tabla de traspaso los valores que servirán como referencias.
preserve
    import delimited using "$TEMPORAL_HANDOFF", clear varnames(1)
    assert _N == 8
    isid outcome model term
    assert ready_for_file03 == 1
    assert sample_type == "own"
    assert repetitions == 9999
    assert countries == 53
    isid seed
    assert seed == 2608000 + order
    assert inrange(conventional_p, 0, 1)
    assert inrange(bootstrap_p, 0, 1)

    foreach outcome in eci divx {
        local outcome_upper = upper("`outcome'")

        foreach model in t1 t2 {
            local model_upper = upper("`model'")

            if "`model'" == "t1" {
                local rents_term "t1_rents"
                local interaction_term "c.t1_rents#c.t1_inst"
            }
            else {
                local rents_term "t2_ma3_rents"
                local interaction_term "t2_ma3_rents_x_inst"
            }

            quietly summarize observations if ///
                outcome == "`outcome_upper'" & model == "`model_upper'", ///
                meanonly
            assert r(N) == 2
            assert r(min) == r(max)
            scalar REF_N_`outcome'_`model' = r(mean)

            quietly summarize countries if ///
                outcome == "`outcome_upper'" & model == "`model_upper'", ///
                meanonly
            assert r(N) == 2
            assert r(min) == r(max)
            scalar REF_G_`outcome'_`model' = r(mean)

            foreach role in rents interaction {
                local reference_term "``role'_term'"

                quietly summarize coefficient if ///
                    outcome == "`outcome_upper'" & ///
                    model == "`model_upper'" & ///
                    term == "`reference_term'", meanonly
                assert r(N) == 1
                scalar REF_B_`outcome'_`model'_`role' = r(mean)

                quietly summarize conventional_p if ///
                    outcome == "`outcome_upper'" & ///
                    model == "`model_upper'" & ///
                    term == "`reference_term'", meanonly
                assert r(N) == 1
                scalar REF_PC_`outcome'_`model'_`role' = r(mean)

                quietly summarize bootstrap_p if ///
                    outcome == "`outcome_upper'" & ///
                    model == "`model_upper'" & ///
                    term == "`reference_term'", meanonly
                assert r(N) == 1
                scalar REF_PB_`outcome'_`model'_`role' = r(mean)
            }
        }
    }
restore

* Reabrir cada modelo guardado y compararlo con la tabla de traspaso.
* Los coeficientes deben coincidir prácticamente a precisión de máquina.
* Los valores p admiten únicamente el redondeo producido al exportar el CSV.
foreach outcome in eci divx {
    local outcome_upper = upper("`outcome'")
    local outcome_directory = cond("`outcome'" == "eci", ///
        "$OUTPUT_ECI", "$OUTPUT_DIVX")

    foreach model in t1 t2 {
        local model_upper = upper("`model'")
        local ster_file ///
            "`outcome_directory'/`outcome'_`model'_own.ster"

        estimates use "`ster_file'"

        assert "`e(cmd)'" == "xtreg"
        assert "`e(depvar)'" == "`outcome'"
        assert "`e(vce)'" == "cluster"
        assert "`e(clustvar)'" == "country_id"
        assert e(N) == scalar(REF_N_`outcome'_`model')
        assert e(N_g) == scalar(REF_G_`outcome'_`model')
        assert e(N_clust) == e(N_g)
        assert e(df_r) == e(N_clust) - 1

        if "`model'" == "t1" {
            local rents_term "t1_rents"
            local interaction_term "c.t1_rents#c.t1_inst"
        }
        else {
            local rents_term "t2_ma3_rents"
            local interaction_term "t2_ma3_rents_x_inst"
        }

        foreach role in rents interaction {
            local reference_term "``role'_term'"
            assert abs(_b[`reference_term'] - ///
                scalar(REF_B_`outcome'_`model'_`role')) <= 1e-12
            assert _se[`reference_term'] > 0 & ///
                !missing(_se[`reference_term'])

            local conventional_p = 2 * ttail(e(df_r), ///
                abs(_b[`reference_term'] / _se[`reference_term']))
            assert abs(`conventional_p' - ///
                scalar(REF_PC_`outcome'_`model'_`role')) <= 1e-7
        }
    }
}

estimates clear

* Recargar el panel para que la sección 15 reciba un estado limpio y conocido.
use "$TEMPORAL_PANEL", clear
isid country_iso3_code year
xtset country_id year

assert scalar(CHECK_N_eci_t1) == 1148
assert scalar(CHECK_N_eci_t2) == 933
assert scalar(CHECK_N_eci_t4) == 1142
assert scalar(CHECK_N_eci_t5) == 987
assert scalar(CHECK_G_eci_t1) == 53
assert scalar(CHECK_G_eci_t2) == 53
assert scalar(CHECK_G_eci_t4) == 53
assert scalar(CHECK_G_eci_t5) == 53

* Detener la ejecución si faltan datos, muestras o modelos previos.

display as result ///
    "Muestras verificadas: T1=1,148; T2=933; T4=1,142; T5=987."
display as result ///
    "Referencias verificadas: 8 contrastes y 4 estimaciones .ster."
display as result ///
    "Sección 14 completada: dependencias y traspaso reconciliados."
display as result "Siguiente bloque pendiente: sección 15."
display as result "TEMPORAL_03_SECTION_14_OK"


// *****************************************************************************
// 15. T4 — adelanto placebo
// *****************************************************************************

// 15.1. Especificación para ECI

* Estimar primero T0 sobre la misma muestra disponible para T4.
* Añadir después únicamente el valor de RENTS observado en el año siguiente.

quietly xtreg eci c.t0_rents##c.t0_inst i.year ///
    if sample_t4_eci == 1, fe vce(cluster country_id)
estimates store ECI_T4_BASE

tempvar used_eci_t4_base
generate byte `used_eci_t4_base' = e(sample)
assert `used_eci_t4_base' == sample_t4_eci
assert e(N) == scalar(CHECK_N_eci_t4)
assert e(N_g) == scalar(CHECK_G_eci_t4)
assert e(N_clust) == e(N_g)
assert e(df_r) == e(N_clust) - 1

scalar ECI_T4_BASE_B_RENTS = _b[t0_rents]
scalar ECI_T4_BASE_B_INST = _b[t0_inst]
scalar ECI_T4_BASE_B_INTERACTION = ///
    _b[c.t0_rents#c.t0_inst]

quietly xtreg eci c.t0_rents##c.t0_inst t4_rents_f1 i.year ///
    if sample_t4_eci == 1, fe vce(cluster country_id)
estimates store ECI_T4_PLACEBO

tempvar used_eci_t4_placebo
generate byte `used_eci_t4_placebo' = e(sample)
assert `used_eci_t4_placebo' == sample_t4_eci
assert e(N) == scalar(CHECK_N_eci_t4)
assert e(N_g) == scalar(CHECK_G_eci_t4)
assert e(N_clust) == e(N_g)
assert e(df_r) == e(N_clust) - 1

foreach term in t0_rents t0_inst c.t0_rents#c.t0_inst t4_rents_f1 {
    assert !missing(_b[`term'])
    assert !missing(_se[`term']) & _se[`term'] > 0
}

scalar ECI_T4_B_RENTS = _b[t0_rents]
scalar ECI_T4_B_INST = _b[t0_inst]
scalar ECI_T4_B_INTERACTION = _b[c.t0_rents#c.t0_inst]
scalar ECI_T4_B_LEAD = _b[t4_rents_f1]
scalar ECI_T4_SE_LEAD = _se[t4_rents_f1]
scalar ECI_T4_P_LEAD = 2 * ttail(e(df_r), ///
    abs(_b[t4_rents_f1] / _se[t4_rents_f1]))

quietly test t4_rents_f1
assert r(df) == 1
assert abs(r(p) - scalar(ECI_T4_P_LEAD)) <= 1e-12

estimates save "$OUTPUT_PLACEBO/eci_t4_placebo.ster", replace
capture confirm file "$OUTPUT_PLACEBO/eci_t4_placebo.ster"
assert _rc == 0


// 15.2. Especificación para DIVX

* Repetir la prueba placebo para DIVX con la misma muestra y controles.

quietly xtreg divx c.t0_rents##c.t0_inst i.year ///
    if sample_t4_divx == 1, fe vce(cluster country_id)
estimates store DIVX_T4_BASE

tempvar used_divx_t4_base
generate byte `used_divx_t4_base' = e(sample)
assert `used_divx_t4_base' == sample_t4_divx
assert e(N) == scalar(CHECK_N_divx_t4)
assert e(N_g) == scalar(CHECK_G_divx_t4)
assert e(N_clust) == e(N_g)
assert e(df_r) == e(N_clust) - 1

scalar DIVX_T4_BASE_B_RENTS = _b[t0_rents]
scalar DIVX_T4_BASE_B_INST = _b[t0_inst]
scalar DIVX_T4_BASE_B_INTERACTION = ///
    _b[c.t0_rents#c.t0_inst]

quietly xtreg divx c.t0_rents##c.t0_inst t4_rents_f1 i.year ///
    if sample_t4_divx == 1, fe vce(cluster country_id)
estimates store DIVX_T4_PLACEBO

tempvar used_divx_t4_placebo
generate byte `used_divx_t4_placebo' = e(sample)
assert `used_divx_t4_placebo' == sample_t4_divx
assert e(N) == scalar(CHECK_N_divx_t4)
assert e(N_g) == scalar(CHECK_G_divx_t4)
assert e(N_clust) == e(N_g)
assert e(df_r) == e(N_clust) - 1

foreach term in t0_rents t0_inst c.t0_rents#c.t0_inst t4_rents_f1 {
    assert !missing(_b[`term'])
    assert !missing(_se[`term']) & _se[`term'] > 0
}

scalar DIVX_T4_B_RENTS = _b[t0_rents]
scalar DIVX_T4_B_INST = _b[t0_inst]
scalar DIVX_T4_B_INTERACTION = _b[c.t0_rents#c.t0_inst]
scalar DIVX_T4_B_LEAD = _b[t4_rents_f1]
scalar DIVX_T4_SE_LEAD = _se[t4_rents_f1]
scalar DIVX_T4_P_LEAD = 2 * ttail(e(df_r), ///
    abs(_b[t4_rents_f1] / _se[t4_rents_f1]))

quietly test t4_rents_f1
assert r(df) == 1
assert abs(r(p) - scalar(DIVX_T4_P_LEAD)) <= 1e-12

estimates save "$OUTPUT_PLACEBO/divx_t4_placebo.ster", replace
capture confirm file "$OUTPUT_PLACEBO/divx_t4_placebo.ster"
assert _rc == 0


// 15.3. Registro e interpretación de la señal placebo

* Los umbrales clasifican la señal, pero no seleccionan ni eliminan modelos.
scalar PLACEBO_ALERT_THRESHOLD = 0.05
scalar PLACEBO_WEAK_THRESHOLD = 0.10

tempname placebo_handle
tempfile placebo_results

postfile `placebo_handle' ///
    int order str8 outcome str20 model str16 specification ///
    str40 term str24 term_role ///
    double coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper coefficient_change_vs_base ///
    observations countries clusters effective_years first_year last_year ///
    byte is_future_lead alert_code ///
    str40 signal_assessment str110 interpretation ///
    using `placebo_results', replace

local placebo_order = 0

foreach outcome in eci divx {
    local outcome_upper = upper("`outcome'")

    quietly levelsof year if sample_t4_`outcome' == 1, ///
        local(placebo_year_values)
    local placebo_years : word count `placebo_year_values'
    quietly summarize year if sample_t4_`outcome' == 1, meanonly
    local placebo_first_year = r(min)
    local placebo_last_year = r(max)

    assert `placebo_years' == scalar(CHECK_T_`outcome'_t4)
    assert `placebo_first_year' == ///
        scalar(CHECK_FIRST_`outcome'_t4)
    assert `placebo_last_year' == ///
        scalar(CHECK_LAST_`outcome'_t4)

    foreach specification in base placebo {
        local specification_upper = upper("`specification'")
        local estimate_name ///
            "`outcome_upper'_T4_`specification_upper'"

        quietly estimates restore `estimate_name'
        assert e(N) == scalar(CHECK_N_`outcome'_t4)
        assert e(N_g) == scalar(CHECK_G_`outcome'_t4)

        if "`specification'" == "base" {
            local model_terms ///
                "t0_rents t0_inst c.t0_rents#c.t0_inst"
            local specification_label "T0 on T4 sample"
        }
        else {
            local model_terms ///
                "t0_rents t0_inst c.t0_rents#c.t0_inst t4_rents_f1"
            local specification_label "T4 augmented"
        }

        foreach term of local model_terms {
            local term_role ""
            local is_future_lead = 0
            local alert_code = -1
            local signal_assessment "Contexto contemporáneo"
            local interpretation ///
                "Coeficiente del bloque T0 estimado sobre la muestra T4"
            local coefficient_change = .

            if "`term'" == "t0_rents" {
                local term_role "contemporary_rents"
            }
            else if "`term'" == "t0_inst" {
                local term_role "contemporary_inst"
            }
            else if "`term'" == "c.t0_rents#c.t0_inst" {
                local term_role "contemporary_interaction"
            }
            else if "`term'" == "t4_rents_f1" {
                local term_role "future_rents_lead"
                local is_future_lead = 1
                local interpretation ///
                    "Alerta informativa; no demuestra causalidad inversa ni invalidez"
            }

            assert "`term_role'" != ""

            local coefficient = _b[`term']
            local standard_error = _se[`term']
            local t_statistic = `coefficient' / `standard_error'
            local p_value = 2 * ttail(e(df_r), abs(`t_statistic'))
            local critical_t = invttail(e(df_r), 0.025)
            local ci_lower = `coefficient' - ///
                `critical_t' * `standard_error'
            local ci_upper = `coefficient' + ///
                `critical_t' * `standard_error'

            if "`specification'" == "placebo" & ///
                "`term'" != "t4_rents_f1" {
                if "`term'" == "t0_rents" {
                    local coefficient_change = `coefficient' - ///
                        scalar(`outcome_upper'_T4_BASE_B_RENTS)
                }
                else if "`term'" == "t0_inst" {
                    local coefficient_change = `coefficient' - ///
                        scalar(`outcome_upper'_T4_BASE_B_INST)
                }
                else {
                    local coefficient_change = `coefficient' - ///
                        scalar(`outcome_upper'_T4_BASE_B_INTERACTION)
                }
            }

            if "`term'" == "t4_rents_f1" {
                if `p_value' < scalar(PLACEBO_ALERT_THRESHOLD) {
                    local alert_code = 2
                    local signal_assessment "Alerta estadística al 5%"
                }
                else if `p_value' < scalar(PLACEBO_WEAK_THRESHOLD) {
                    local alert_code = 1
                    local signal_assessment "Señal débil al 10%"
                }
                else {
                    local alert_code = 0
                    local signal_assessment "Sin alerta estadística"
                }
            }

            assert inrange(`p_value', 0, 1)
            assert `ci_lower' < `ci_upper'

            local ++placebo_order
            post `placebo_handle' (`placebo_order') ///
                ("`outcome_upper'") ("`estimate_name'") ///
                ("`specification_label'") ///
                ("`term'") ("`term_role'") ///
                (`coefficient') (`standard_error') ///
                (`t_statistic') (`p_value') (`ci_lower') (`ci_upper') ///
                (`coefficient_change') (e(N)) (e(N_g)) (e(N_clust)) ///
                (`placebo_years') (`placebo_first_year') ///
                (`placebo_last_year') (`is_future_lead') (`alert_code') ///
                ("`signal_assessment'") ("`interpretation'")
        }
    }
}

postclose `placebo_handle'

preserve
    use `placebo_results', clear
    sort order

    assert _N == 14
    isid outcome model term
    assert inlist(outcome, "ECI", "DIVX")
    assert inlist(specification, "T0 on T4 sample", "T4 augmented")
    assert observations == 1142
    assert countries == 53
    assert clusters == countries
    assert effective_years == 22
    assert first_year == 1996
    assert last_year == 2020
    assert inrange(p_value, 0, 1)
    assert ci_lower < ci_upper

    quietly count if is_future_lead == 1
    assert r(N) == 2
    assert inlist(alert_code, -1, 0, 1, 2)
    assert alert_code == -1 if is_future_lead == 0
    assert inlist(alert_code, 0, 1, 2) if is_future_lead == 1

    export delimited using ///
        "$OUTPUT_PLACEBO/lead_placebo_tests.csv", replace
restore

capture confirm file "$OUTPUT_PLACEBO/lead_placebo_tests.csv"
assert _rc == 0
capture confirm file "$OUTPUT_PLACEBO/eci_t4_placebo.ster"
assert _rc == 0
capture confirm file "$OUTPUT_PLACEBO/divx_t4_placebo.ster"
assert _rc == 0

* La tabla separa los términos contemporáneos del adelanto usado como placebo.
* También informa cobertura para evitar comparaciones incompatibles.

display as result ///
    "ECI T4: b(RENTS t+1)=" scalar(ECI_T4_B_LEAD) ///
    "; p agrupado=" scalar(ECI_T4_P_LEAD)
display as result ///
    "DIVX T4: b(RENTS t+1)=" scalar(DIVX_T4_B_LEAD) ///
    "; p agrupado=" scalar(DIVX_T4_P_LEAD)
display as result ///
    "Interpretación T4: alerta informativa, no prueba causal definitiva."
display as result "Sección 15 completada sin errores."
display as result "Siguiente bloque pendiente: sección 16."
display as result "TEMPORAL_03_SECTION_15_OK"


// *****************************************************************************
// 16. T5 — cambios anuales
// *****************************************************************************

// 16.1. Modelo de cambios para ECI

* La primera diferencia elimina características nacionales constantes.
* La regresión de cambios conserva efectos comunes para cada año.
* No añade otra vez efectos de país ni interacciones no predefinidas.

quietly regress t5_d_eci t5_d_rents t5_d_inst i.year ///
    if sample_t5_eci == 1, vce(cluster country_id)
estimates store ECI_T5_FD

tempvar used_eci_t5
generate byte `used_eci_t5' = e(sample)
assert `used_eci_t5' == sample_t5_eci
assert e(N) == scalar(CHECK_N_eci_t5)
assert e(N_clust) == scalar(CHECK_G_eci_t5)
assert e(df_r) == e(N_clust) - 1

foreach term in t5_d_rents t5_d_inst {
    assert !missing(_b[`term'])
    assert !missing(_se[`term']) & _se[`term'] > 0
}

scalar ECI_T5_B_D_RENTS = _b[t5_d_rents]
scalar ECI_T5_SE_D_RENTS = _se[t5_d_rents]
scalar ECI_T5_P_D_RENTS = 2 * ttail(e(df_r), ///
    abs(_b[t5_d_rents] / _se[t5_d_rents]))
scalar ECI_T5_B_D_INST = _b[t5_d_inst]
scalar ECI_T5_SE_D_INST = _se[t5_d_inst]
scalar ECI_T5_P_D_INST = 2 * ttail(e(df_r), ///
    abs(_b[t5_d_inst] / _se[t5_d_inst]))

quietly test t5_d_rents t5_d_inst
scalar ECI_T5_JOINT_F = r(F)
scalar ECI_T5_JOINT_P = r(p)
assert r(df) == 2
assert r(df_r) == scalar(CHECK_G_eci_t5) - 1
assert inrange(scalar(ECI_T5_JOINT_P), 0, 1)

estimates save "$OUTPUT_CHANGES/eci_t5_first_difference.ster", replace
capture confirm file "$OUTPUT_CHANGES/eci_t5_first_difference.ster"
assert _rc == 0


// 16.2. Modelo de cambios para DIVX

* Repetir para DIVX la misma regresión de cambios anuales utilizada para ECI.

quietly regress t5_d_divx t5_d_rents t5_d_inst i.year ///
    if sample_t5_divx == 1, vce(cluster country_id)
estimates store DIVX_T5_FD

tempvar used_divx_t5
generate byte `used_divx_t5' = e(sample)
assert `used_divx_t5' == sample_t5_divx
assert e(N) == scalar(CHECK_N_divx_t5)
assert e(N_clust) == scalar(CHECK_G_divx_t5)
assert e(df_r) == e(N_clust) - 1

foreach term in t5_d_rents t5_d_inst {
    assert !missing(_b[`term'])
    assert !missing(_se[`term']) & _se[`term'] > 0
}

scalar DIVX_T5_B_D_RENTS = _b[t5_d_rents]
scalar DIVX_T5_SE_D_RENTS = _se[t5_d_rents]
scalar DIVX_T5_P_D_RENTS = 2 * ttail(e(df_r), ///
    abs(_b[t5_d_rents] / _se[t5_d_rents]))
scalar DIVX_T5_B_D_INST = _b[t5_d_inst]
scalar DIVX_T5_SE_D_INST = _se[t5_d_inst]
scalar DIVX_T5_P_D_INST = 2 * ttail(e(df_r), ///
    abs(_b[t5_d_inst] / _se[t5_d_inst]))

quietly test t5_d_rents t5_d_inst
scalar DIVX_T5_JOINT_F = r(F)
scalar DIVX_T5_JOINT_P = r(p)
assert r(df) == 2
assert r(df_r) == scalar(CHECK_G_divx_t5) - 1
assert inrange(scalar(DIVX_T5_JOINT_P), 0, 1)

estimates save "$OUTPUT_CHANGES/divx_t5_first_difference.ster", replace
capture confirm file "$OUTPUT_CHANGES/divx_t5_first_difference.ster"
assert _rc == 0


// 16.3. Inferencia e interpretación

* Calcular la cobertura con la misma bandera utilizada por cada estimación.
* Repetir los conteos evita asumir que ECI y DIVX siempre comparten muestra.

foreach outcome in eci divx {
    tempvar t5_periods t5_tag

    bysort country_id: egen double `t5_periods' = ///
        total(sample_t5_`outcome')
    egen byte `t5_tag' = tag(country_id)

    quietly summarize `t5_periods' ///
        if `t5_tag' == 1 & `t5_periods' > 0, ///
        meanonly
    assert r(N) == scalar(CHECK_G_`outcome'_t5)
    scalar T5_AVG_PERIODS_`outcome' = r(mean)
    scalar T5_MIN_PERIODS_`outcome' = r(min)
    scalar T5_MAX_PERIODS_`outcome' = r(max)

    quietly count if sample_t0_`outcome' == 1
    scalar T5_T0_N_`outcome' = r(N)
    scalar T5_LOSS_PANEL_`outcome' = ///
        1430 - scalar(CHECK_N_`outcome'_t5)
    scalar T5_LOSS_T0_`outcome' = ///
        scalar(T5_T0_N_`outcome') - scalar(CHECK_N_`outcome'_t5)
    scalar T5_LOSS_PANEL_PCT_`outcome' = ///
        100 * scalar(T5_LOSS_PANEL_`outcome') / 1430
    scalar T5_LOSS_T0_PCT_`outcome' = ///
        100 * scalar(T5_LOSS_T0_`outcome') / ///
        scalar(T5_T0_N_`outcome')
}

assert scalar(T5_AVG_PERIODS_eci) == scalar(T5_AVG_PERIODS_divx)
assert scalar(T5_MIN_PERIODS_eci) == 12
assert scalar(T5_MAX_PERIODS_eci) == 19
assert scalar(T5_LOSS_PANEL_eci) == 443
assert scalar(T5_LOSS_T0_eci) == 210

tempname changes_handle
tempfile changes_results

postfile `changes_handle' ///
    int order str8 outcome str16 model str12 test_type ///
    str40 term str32 term_role ///
    double coefficient standard_error t_statistic f_statistic ///
    df1 df2 p_value ci_lower ci_upper ///
    observations countries clusters effective_years first_year last_year ///
    average_periods_per_country minimum_periods_per_country ///
    maximum_periods_per_country observations_lost_vs_panel ///
    observations_lost_vs_t0 loss_percent_vs_panel loss_percent_vs_t0 ///
    byte year_fe clustered_by_country ///
    str110 interpretation ///
    using `changes_results', replace

local changes_order = 0

foreach outcome in eci divx {
    local outcome_upper = upper("`outcome'")
    local estimate_name "`outcome_upper'_T5_FD"

    quietly estimates restore `estimate_name'
    assert e(N) == scalar(CHECK_N_`outcome'_t5)
    assert e(N_clust) == scalar(CHECK_G_`outcome'_t5)

    local model_n = e(N)
    local model_g = e(N_clust)
    local model_df = e(df_r)
    local model_t = scalar(CHECK_T_`outcome'_t5)
    local model_first = scalar(CHECK_FIRST_`outcome'_t5)
    local model_last = scalar(CHECK_LAST_`outcome'_t5)
    local average_periods = scalar(T5_AVG_PERIODS_`outcome')
    local minimum_periods = scalar(T5_MIN_PERIODS_`outcome')
    local maximum_periods = scalar(T5_MAX_PERIODS_`outcome')
    local loss_panel = scalar(T5_LOSS_PANEL_`outcome')
    local loss_t0 = scalar(T5_LOSS_T0_`outcome')
    local loss_panel_pct = scalar(T5_LOSS_PANEL_PCT_`outcome')
    local loss_t0_pct = scalar(T5_LOSS_T0_PCT_`outcome')

    foreach term in t5_d_rents t5_d_inst {
        if "`term'" == "t5_d_rents" {
            local term_role "annual_change_rents"
            local interpretation ///
                "Asociación entre cambio anual de RENTS y cambio anual del resultado"
        }
        else {
            local term_role "annual_change_institutions"
            local interpretation ///
                "Asociación entre cambio anual institucional y cambio anual del resultado"
        }

        local coefficient = _b[`term']
        local standard_error = _se[`term']
        local t_statistic = `coefficient' / `standard_error'
        local p_value = 2 * ttail(`model_df', abs(`t_statistic'))
        local critical_t = invttail(`model_df', 0.025)
        local ci_lower = `coefficient' - ///
            `critical_t' * `standard_error'
        local ci_upper = `coefficient' + ///
            `critical_t' * `standard_error'

        assert inrange(`p_value', 0, 1)
        assert `ci_lower' < `ci_upper'

        local ++changes_order
        post `changes_handle' (`changes_order') ///
            ("`outcome_upper'") ("`estimate_name'") ///
            ("coefficient") ("`term'") ("`term_role'") ///
            (`coefficient') (`standard_error') (`t_statistic') (.) ///
            (1) (`model_df') (`p_value') (`ci_lower') (`ci_upper') ///
            (`model_n') (`model_g') (`model_g') (`model_t') ///
            (`model_first') (`model_last') (`average_periods') ///
            (`minimum_periods') (`maximum_periods') (`loss_panel') ///
            (`loss_t0') (`loss_panel_pct') (`loss_t0_pct') ///
            (1) (1) ("`interpretation'")
    }

    quietly test t5_d_rents t5_d_inst
    local joint_f = r(F)
    local joint_df1 = r(df)
    local joint_df2 = r(df_r)
    local joint_p = r(p)

    assert `joint_df1' == 2
    assert `joint_df2' == `model_g' - 1
    assert inrange(`joint_p', 0, 1)

    local ++changes_order
    post `changes_handle' (`changes_order') ///
        ("`outcome_upper'") ("`estimate_name'") ///
        ("joint") ("t5_d_rents+t5_d_inst") ///
        ("joint_changes") (.) (.) (.) (`joint_f') ///
        (`joint_df1') (`joint_df2') (`joint_p') (.) (.) ///
        (`model_n') (`model_g') (`model_g') (`model_t') ///
        (`model_first') (`model_last') (`average_periods') ///
        (`minimum_periods') (`maximum_periods') (`loss_panel') ///
        (`loss_t0') (`loss_panel_pct') (`loss_t0_pct') ///
        (1) (1) ///
        ("Prueba conjunta de los cambios anuales en RENTS e instituciones")
}

postclose `changes_handle'

preserve
    use `changes_results', clear
    sort order

    assert _N == 6
    isid outcome test_type term
    assert inlist(outcome, "ECI", "DIVX")
    assert inlist(test_type, "coefficient", "joint")
    assert observations == 987
    assert countries == 53
    assert clusters == countries
    assert effective_years == 19
    assert first_year == 2003
    assert last_year == 2021
    assert minimum_periods_per_country == 12
    assert maximum_periods_per_country == 19
    assert observations_lost_vs_panel == 443
    assert observations_lost_vs_t0 == 210
    assert year_fe == 1
    assert clustered_by_country == 1
    assert inrange(p_value, 0, 1)

    quietly count if test_type == "coefficient"
    assert r(N) == 4
    quietly count if test_type == "joint"
    assert r(N) == 2
    quietly count if term_role == "annual_change_rents"
    assert r(N) == 2
    quietly count if term_role == "annual_change_institutions"
    assert r(N) == 2
    quietly count if term_role == "joint_changes"
    assert r(N) == 2

    export delimited using ///
        "$OUTPUT_CHANGES/first_difference_results.csv", replace
restore

capture confirm file "$OUTPUT_CHANGES/first_difference_results.csv"
assert _rc == 0
capture confirm file "$OUTPUT_CHANGES/eci_t5_first_difference.ster"
assert _rc == 0
capture confirm file "$OUTPUT_CHANGES/divx_t5_first_difference.ster"
assert _rc == 0

* Reportar cuántos cambios válidos aporta cada país y la pérdida de muestra.
* T5 describe asociaciones entre cambios anuales, no efectos de largo plazo.

display as result ///
    "ECI T5: b(delta RENTS)=" scalar(ECI_T5_B_D_RENTS) ///
    "; p=" scalar(ECI_T5_P_D_RENTS) ///
    "; p conjunta=" scalar(ECI_T5_JOINT_P)
display as result ///
    "DIVX T5: b(delta RENTS)=" scalar(DIVX_T5_B_D_RENTS) ///
    "; p=" scalar(DIVX_T5_P_D_RENTS) ///
    "; p conjunta=" scalar(DIVX_T5_JOINT_P)
display as result ///
    "Cobertura T5: 987 observaciones, 53 países y 12--19 cambios por país."
display as result ///
    "Interpretación T5: asociaciones de corto plazo, no efectos de largo plazo."
display as result "Sección 16 completada sin errores."
display as result "Siguiente bloque pendiente: sección 17."
display as result "TEMPORAL_03_SECTION_16_OK"


// *****************************************************************************
// 17. Estabilidad leave-one-country-out
// *****************************************************************************

// 17.1. Exclusión individual en T1

* Reestimar T1 excluyendo un país distinto en cada repetición.
* Registrar RENTS y la interacción porque son los términos focales de T1.
* Cada repetición agrupa la inferencia por los 52 países restantes.

tempname loo_handle
tempfile loo_results

postfile `loo_handle' ///
    long order str8 outcome str4 model str40 term str16 term_role ///
    int omitted_country_id str3 omitted_country_code ///
    str60 omitted_country_name int omitted_observations ///
    double coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper reference_coefficient reference_standard_error ///
    reference_p_cluster reference_p_bootstrap ///
    absolute_coefficient_difference relative_absolute_difference ///
    deviation_in_reference_se ///
    byte sign_match significant_5 reference_significant_5 ///
    observations reference_observations countries clusters ///
    using `loo_results', replace

local loo_order = 0

foreach outcome in eci divx {
    local outcome_upper = upper("`outcome'")
    local sample_variable "sample_t1_`outcome'"
    local rents_term "t1_rents"
    local interaction_term "c.t1_rents#c.t1_inst"

    quietly xtreg `outcome' c.t1_rents##c.t1_inst i.year ///
        if `sample_variable' == 1, fe vce(cluster country_id)

    assert e(N) == scalar(REF_N_`outcome'_t1)
    assert e(N_g) == scalar(REF_G_`outcome'_t1)
    assert e(N_clust) == e(N_g)
    local reference_n = e(N)
    local reference_g = e(N_g)
    local reference_df = e(df_r)

    foreach role in rents interaction {
        local focal_term "``role'_term'"
        local reference_b_`role' = _b[`focal_term']
        local reference_se_`role' = _se[`focal_term']
        local reference_p_`role' = 2 * ttail(`reference_df', ///
            abs(_b[`focal_term'] / _se[`focal_term']))

        assert abs(`reference_b_`role'' - ///
            scalar(REF_B_`outcome'_t1_`role')) <= 1e-12
        assert abs(`reference_p_`role'' - ///
            scalar(REF_PC_`outcome'_t1_`role')) <= 1e-7
    }

    quietly levelsof country_id if `sample_variable' == 1, ///
        local(loo_t1_country_ids)
    local loo_t1_country_count : word count `loo_t1_country_ids'
    assert `loo_t1_country_count' == `reference_g'

    foreach omitted_id of local loo_t1_country_ids {
        quietly levelsof country_iso3_code if country_id == `omitted_id', ///
            local(omitted_code) clean
        quietly levelsof country if country_id == `omitted_id', ///
            local(omitted_name) clean
        quietly count if `sample_variable' == 1 & ///
            country_id == `omitted_id'
        local omitted_n = r(N)
        assert `omitted_n' > 0

        quietly xtreg `outcome' c.t1_rents##c.t1_inst i.year ///
            if `sample_variable' == 1 & country_id != `omitted_id', ///
            fe vce(cluster country_id)

        assert e(N) == `reference_n' - `omitted_n'
        assert e(N_g) == `reference_g' - 1
        assert e(N_clust) == e(N_g)
        assert e(df_r) == e(N_clust) - 1

        local loo_n = e(N)
        local loo_g = e(N_g)
        local loo_df = e(df_r)

        foreach role in rents interaction {
            local focal_term "``role'_term'"
            local reference_b = `reference_b_`role''
            local reference_se = `reference_se_`role''
            local reference_p = `reference_p_`role''
            local reference_pb = scalar(REF_PB_`outcome'_t1_`role')

            local coefficient = _b[`focal_term']
            local standard_error = _se[`focal_term']
            local t_statistic = `coefficient' / `standard_error'
            local p_value = 2 * ttail(`loo_df', abs(`t_statistic'))
            local critical_t = invttail(`loo_df', 0.025)
            local ci_lower = `coefficient' - ///
                `critical_t' * `standard_error'
            local ci_upper = `coefficient' + ///
                `critical_t' * `standard_error'
            local absolute_difference = ///
                abs(`coefficient' - `reference_b')
            local relative_difference = cond(abs(`reference_b') > 1e-12, ///
                `absolute_difference' / abs(`reference_b'), .)
            local standardized_difference = ///
                `absolute_difference' / `reference_se'
            local sign_match = ///
                sign(`coefficient') == sign(`reference_b')
            local significant_5 = `p_value' < 0.05
            local reference_significant_5 = `reference_p' < 0.05

            assert inrange(`p_value', 0, 1)
            assert `ci_lower' < `ci_upper'
            assert `absolute_difference' >= 0
            assert `standardized_difference' >= 0

            local ++loo_order
            post `loo_handle' (`loo_order') ("`outcome_upper'") ///
                ("T1") ("`focal_term'") ("`role'") ///
                (`omitted_id') ("`omitted_code'") ("`omitted_name'") ///
                (`omitted_n') (`coefficient') (`standard_error') ///
                (`t_statistic') (`p_value') (`ci_lower') (`ci_upper') ///
                (`reference_b') (`reference_se') (`reference_p') ///
                (`reference_pb') (`absolute_difference') ///
                (`relative_difference') (`standardized_difference') ///
                (`sign_match') (`significant_5') ///
                (`reference_significant_5') (`loo_n') (`reference_n') ///
                (`loo_g') (`loo_g')
        }
    }
}


// 17.2. Exclusión individual en T2

* Reestimar T2 excluyendo un país distinto en cada repetición.
* La interacción sigue siendo la media de los productos calculados cada año.
* Nunca se reemplaza por el producto de las medias durante esta prueba.

foreach outcome in eci divx {
    local outcome_upper = upper("`outcome'")
    local sample_variable "sample_t2_`outcome'"
    local rents_term "t2_ma3_rents"
    local interaction_term "t2_ma3_rents_x_inst"

    quietly xtreg `outcome' ///
        t2_ma3_rents t2_ma3_inst t2_ma3_rents_x_inst i.year ///
        if `sample_variable' == 1, fe vce(cluster country_id)

    assert e(N) == scalar(REF_N_`outcome'_t2)
    assert e(N_g) == scalar(REF_G_`outcome'_t2)
    assert e(N_clust) == e(N_g)
    local reference_n = e(N)
    local reference_g = e(N_g)
    local reference_df = e(df_r)

    foreach role in rents interaction {
        local focal_term "``role'_term'"
        local reference_b_`role' = _b[`focal_term']
        local reference_se_`role' = _se[`focal_term']
        local reference_p_`role' = 2 * ttail(`reference_df', ///
            abs(_b[`focal_term'] / _se[`focal_term']))

        assert abs(`reference_b_`role'' - ///
            scalar(REF_B_`outcome'_t2_`role')) <= 1e-12
        assert abs(`reference_p_`role'' - ///
            scalar(REF_PC_`outcome'_t2_`role')) <= 1e-7
    }

    quietly levelsof country_id if `sample_variable' == 1, ///
        local(loo_t2_country_ids)
    local loo_t2_country_count : word count `loo_t2_country_ids'
    assert `loo_t2_country_count' == `reference_g'

    foreach omitted_id of local loo_t2_country_ids {
        quietly levelsof country_iso3_code if country_id == `omitted_id', ///
            local(omitted_code) clean
        quietly levelsof country if country_id == `omitted_id', ///
            local(omitted_name) clean
        quietly count if `sample_variable' == 1 & ///
            country_id == `omitted_id'
        local omitted_n = r(N)
        assert `omitted_n' > 0

        quietly xtreg `outcome' ///
            t2_ma3_rents t2_ma3_inst t2_ma3_rents_x_inst i.year ///
            if `sample_variable' == 1 & country_id != `omitted_id', ///
            fe vce(cluster country_id)

        assert e(N) == `reference_n' - `omitted_n'
        assert e(N_g) == `reference_g' - 1
        assert e(N_clust) == e(N_g)
        assert e(df_r) == e(N_clust) - 1

        local loo_n = e(N)
        local loo_g = e(N_g)
        local loo_df = e(df_r)

        foreach role in rents interaction {
            local focal_term "``role'_term'"
            local reference_b = `reference_b_`role''
            local reference_se = `reference_se_`role''
            local reference_p = `reference_p_`role''
            local reference_pb = scalar(REF_PB_`outcome'_t2_`role')

            local coefficient = _b[`focal_term']
            local standard_error = _se[`focal_term']
            local t_statistic = `coefficient' / `standard_error'
            local p_value = 2 * ttail(`loo_df', abs(`t_statistic'))
            local critical_t = invttail(`loo_df', 0.025)
            local ci_lower = `coefficient' - ///
                `critical_t' * `standard_error'
            local ci_upper = `coefficient' + ///
                `critical_t' * `standard_error'
            local absolute_difference = ///
                abs(`coefficient' - `reference_b')
            local relative_difference = cond(abs(`reference_b') > 1e-12, ///
                `absolute_difference' / abs(`reference_b'), .)
            local standardized_difference = ///
                `absolute_difference' / `reference_se'
            local sign_match = ///
                sign(`coefficient') == sign(`reference_b')
            local significant_5 = `p_value' < 0.05
            local reference_significant_5 = `reference_p' < 0.05

            assert inrange(`p_value', 0, 1)
            assert `ci_lower' < `ci_upper'
            assert `absolute_difference' >= 0
            assert `standardized_difference' >= 0

            local ++loo_order
            post `loo_handle' (`loo_order') ("`outcome_upper'") ///
                ("T2") ("`focal_term'") ("`role'") ///
                (`omitted_id') ("`omitted_code'") ("`omitted_name'") ///
                (`omitted_n') (`coefficient') (`standard_error') ///
                (`t_statistic') (`p_value') (`ci_lower') (`ci_upper') ///
                (`reference_b') (`reference_se') (`reference_p') ///
                (`reference_pb') (`absolute_difference') ///
                (`relative_difference') (`standardized_difference') ///
                (`sign_match') (`significant_5') ///
                (`reference_significant_5') (`loo_n') (`reference_n') ///
                (`loo_g') (`loo_g')
        }
    }
}

postclose `loo_handle'

preserve
    use `loo_results', clear
    sort order

    assert _N == 424
    isid outcome model term omitted_country_id
    assert inlist(outcome, "ECI", "DIVX")
    assert inlist(model, "T1", "T2")
    assert inlist(term_role, "rents", "interaction")
    bysort outcome model term: assert _N == 53
    assert countries == 52
    assert clusters == countries
    assert observations == reference_observations - omitted_observations
    assert inrange(p_value, 0, 1)
    assert inrange(reference_p_cluster, 0, 1)
    assert inrange(reference_p_bootstrap, 0, 1)
    assert absolute_coefficient_difference >= 0
    assert deviation_in_reference_se >= 0
    assert inlist(sign_match, 0, 1)
    assert inlist(significant_5, 0, 1)
    assert inlist(reference_significant_5, 0, 1)

    export delimited using ///
        "$OUTPUT_STABILITY/temporal_leave_one_out.csv", replace
restore


// 17.3. Resumen de influencia

* Resumir cuánto cambia cada término cuando se excluye un país a la vez.

tempname loo_summary_handle
tempfile loo_summary_results

postfile `loo_summary_handle' ///
    int order str8 outcome str4 model str40 term str16 term_role ///
    double reference_coefficient reference_standard_error ///
    reference_p_cluster reference_p_bootstrap ///
    iterations minimum_coefficient mean_coefficient maximum_coefficient ///
    minimum_p_value maximum_p_value sign_change_count ///
    significant_5_count significance_change_count ///
    maximum_absolute_difference max_deviation_reference_se ///
    minimum_observations maximum_observations ///
    str3 most_influential_country_code ///
    str60 most_influential_country_name ///
    str70 stability_assessment ///
    using `loo_summary_results', replace

local loo_summary_order = 0

foreach outcome in ECI DIVX {
    foreach model in T1 T2 {
        foreach role in rents interaction {
            preserve
                use `loo_results', clear
                keep if outcome == "`outcome'" & model == "`model'" & ///
                    term_role == "`role'"
                assert _N == 53

                local summary_term = term[1]
                local reference_b = reference_coefficient[1]
                local reference_se = reference_standard_error[1]
                local reference_p = reference_p_cluster[1]
                local reference_pb = reference_p_bootstrap[1]

                quietly summarize coefficient, meanonly
                local minimum_b = r(min)
                local mean_b = r(mean)
                local maximum_b = r(max)

                quietly summarize p_value, meanonly
                local minimum_p = r(min)
                local maximum_p = r(max)

                quietly count if sign_match == 0
                local sign_changes = r(N)
                quietly count if significant_5 == 1
                local significant_count = r(N)
                quietly count if significant_5 != reference_significant_5
                local significance_changes = r(N)

                quietly summarize absolute_coefficient_difference, meanonly
                local maximum_abs_difference = r(max)
                quietly summarize deviation_in_reference_se, meanonly
                local maximum_standardized_difference = r(max)
                quietly summarize observations, meanonly
                local minimum_n = r(min)
                local maximum_n = r(max)

                gsort -absolute_coefficient_difference ///
                    omitted_country_code
                local influential_code = omitted_country_code[1]
                local influential_name = omitted_country_name[1]

                if `sign_changes' > 0 {
                    local stability_assessment ///
                        "Inestable: al menos una exclusión cambia el signo"
                }
                else if `maximum_standardized_difference' > 1 {
                    local stability_assessment ///
                        "Signo estable; revisar influencia sobre magnitud"
                }
                else if `significance_changes' > 0 {
                    local stability_assessment ///
                        "Signo estable; precisión sensible a algunas exclusiones"
                }
                else {
                    local stability_assessment ///
                        "Signo y clasificación inferencial estables"
                }
            restore

            local ++loo_summary_order
            post `loo_summary_handle' (`loo_summary_order') ///
                ("`outcome'") ("`model'") ("`summary_term'") ///
                ("`role'") (`reference_b') (`reference_se') ///
                (`reference_p') (`reference_pb') (53) ///
                (`minimum_b') (`mean_b') (`maximum_b') ///
                (`minimum_p') (`maximum_p') (`sign_changes') ///
                (`significant_count') (`significance_changes') ///
                (`maximum_abs_difference') ///
                (`maximum_standardized_difference') ///
                (`minimum_n') (`maximum_n') ///
                ("`influential_code'") ("`influential_name'") ///
                ("`stability_assessment'")
        }
    }
}

postclose `loo_summary_handle'

preserve
    use `loo_summary_results', clear
    sort order

    assert _N == 8
    isid outcome model term
    assert iterations == 53
    assert minimum_coefficient <= mean_coefficient
    assert mean_coefficient <= maximum_coefficient
    assert inrange(minimum_p_value, 0, 1)
    assert inrange(maximum_p_value, 0, 1)
    assert minimum_p_value <= maximum_p_value
    assert inrange(sign_change_count, 0, 53)
    assert inrange(significant_5_count, 0, 53)
    assert inrange(significance_change_count, 0, 53)
    assert maximum_absolute_difference >= 0
    assert max_deviation_reference_se >= 0

    quietly count if sign_change_count > 0
    scalar LOO_GROUPS_WITH_SIGN_CHANGES = r(N)
    quietly count if significance_change_count > 0
    scalar LOO_GROUPS_WITH_P_CHANGES = r(N)

    export delimited using ///
        "$OUTPUT_STABILITY/temporal_leave_one_out_summary.csv", replace
restore

* Registrar país omitido, coeficiente, incertidumbre y cobertura de cada modelo.
* El resumen muestra rangos, cambios de signo y desviaciones frente al modelo.

capture confirm file "$OUTPUT_STABILITY/temporal_leave_one_out.csv"
assert _rc == 0
capture confirm file ///
    "$OUTPUT_STABILITY/temporal_leave_one_out_summary.csv"
assert _rc == 0

* Restablecer el panel y su declaración antes de continuar con la sección 18.
use "$TEMPORAL_PANEL", clear
isid country_iso3_code year
xtset country_id year

display as result ///
    "Leave-one-country-out: 212 modelos y 424 coeficientes registrados."
display as result ///
    "Grupos con cambio de signo: " scalar(LOO_GROUPS_WITH_SIGN_CHANGES) ///
    " de 8."
display as result ///
    "Grupos con cambios de clasificación al 5%: " ///
    scalar(LOO_GROUPS_WITH_P_CHANGES) " de 8."
display as result "Sección 17 completada sin errores."
display as result "Siguiente bloque pendiente: sección 18."
display as result "TEMPORAL_03_SECTION_17_OK"


// *****************************************************************************
// 18. Sensibilidad a tendencias lineales específicas por país
// *****************************************************************************

// 18.1. T1 con tendencias nacionales

* Medir el tiempo desde 1996 mejora la estabilidad numérica de la estimación.
* Cada país recibe una trayectoria lineal propia a lo largo del período.
* Una pendiente es redundante y quedan 52 parámetros adicionales identificados.

capture drop country_linear_trend
generate double country_linear_trend = year - 1996
assert country_linear_trend >= 0 & country_linear_trend <= 25

tempname trend_handle
tempfile trend_results

postfile `trend_handle' ///
    int order str8 outcome str4 model str40 term str16 term_role ///
    double baseline_coefficient baseline_standard_error baseline_p_value ///
    trend_coefficient trend_standard_error trend_p_value ///
    coefficient_difference absolute_coefficient_difference ///
    relative_absolute_difference deviation_in_baseline_se ///
    standard_error_ratio ///
    byte sign_match baseline_significant_5 trend_significant_5 ///
    observations countries clusters effective_years ///
    baseline_model_df trend_model_df added_model_df cluster_residual_df ///
    baseline_within_r2 trend_within_r2 ///
    str80 sensitivity_assessment ///
    using `trend_results', replace

local trend_order = 0

foreach outcome in eci divx {
    local outcome_upper = upper("`outcome'")
    local sample_variable "sample_t1_`outcome'"
    local rents_term "t1_rents"
    local interaction_term "c.t1_rents#c.t1_inst"

    quietly xtreg `outcome' c.t1_rents##c.t1_inst i.year ///
        if `sample_variable' == 1, fe vce(cluster country_id)

    assert e(N) == scalar(REF_N_`outcome'_t1)
    assert e(N_g) == scalar(REF_G_`outcome'_t1)
    local baseline_n = e(N)
    local baseline_g = e(N_g)
    local baseline_df_m = e(df_m)
    local baseline_df_r = e(df_r)
    local baseline_r2 = e(r2_w)

    foreach role in rents interaction {
        local focal_term "``role'_term'"
        local baseline_b_`role' = _b[`focal_term']
        local baseline_se_`role' = _se[`focal_term']
        local baseline_p_`role' = 2 * ttail(`baseline_df_r', ///
            abs(_b[`focal_term'] / _se[`focal_term']))

        assert abs(`baseline_b_`role'' - ///
            scalar(REF_B_`outcome'_t1_`role')) <= 1e-12
        assert abs(`baseline_p_`role'' - ///
            scalar(REF_PC_`outcome'_t1_`role')) <= 1e-7
    }

    quietly xtreg `outcome' c.t1_rents##c.t1_inst i.year ///
        i.country_id#c.country_linear_trend ///
        if `sample_variable' == 1, fe vce(cluster country_id)
    estimates store `outcome_upper'_T1_TRENDS

    tempvar used_t1_trends
    generate byte `used_t1_trends' = e(sample)
    assert `used_t1_trends' == `sample_variable'
    assert e(N) == `baseline_n'
    assert e(N_g) == `baseline_g'
    assert e(N_clust) == e(N_g)
    assert e(df_r) == e(N_clust) - 1

    local trend_df_m = e(df_m)
    local trend_df_r = e(df_r)
    local trend_r2 = e(r2_w)

    * Contar pendientes identifica cuántas tendencias utiliza el modelo.
    local added_df = 0
    local coefficient_names : colnames e(b)
    foreach coefficient of local coefficient_names {
        if strpos("`coefficient'", "#c.country_linear_trend") > 0 {
            quietly _ms_parse_parts `coefficient'
            if r(omit) == 0 local ++added_df
        }
    }
    assert `added_df' == `baseline_g' - 1

    estimates save ///
        "$OUTPUT_STABILITY/`outcome'_t1_country_trends.ster", replace

    foreach role in rents interaction {
        local focal_term "``role'_term'"
        local baseline_b = `baseline_b_`role''
        local baseline_se = `baseline_se_`role''
        local baseline_p = `baseline_p_`role''
        local trend_b = _b[`focal_term']
        local trend_se = _se[`focal_term']
        local trend_p = 2 * ttail(`trend_df_r', ///
            abs(`trend_b' / `trend_se'))
        local coefficient_difference = `trend_b' - `baseline_b'
        local absolute_difference = abs(`coefficient_difference')
        local relative_difference = cond(abs(`baseline_b') > 1e-12, ///
            `absolute_difference' / abs(`baseline_b'), .)
        local standardized_difference = ///
            `absolute_difference' / `baseline_se'
        local se_ratio = `trend_se' / `baseline_se'
        local sign_match = sign(`trend_b') == sign(`baseline_b')
        local baseline_significant = `baseline_p' < 0.05
        local trend_significant = `trend_p' < 0.05

        if `sign_match' == 0 {
            local sensitivity_assessment ///
                "Cambio de signo al incorporar tendencias nacionales"
        }
        else if `standardized_difference' > 1 {
            local sensitivity_assessment ///
                "Signo estable; magnitud sensible a tendencias nacionales"
        }
        else if `baseline_significant' != `trend_significant' {
            local sensitivity_assessment ///
                "Signo y magnitud estables; cambia la precisión inferencial"
        }
        else {
            local sensitivity_assessment ///
                "Signo, magnitud y clasificación inferencial estables"
        }

        assert `trend_se' > 0 & !missing(`trend_se')
        assert inrange(`trend_p', 0, 1)
        assert `absolute_difference' >= 0
        assert `standardized_difference' >= 0
        assert `se_ratio' > 0

        local ++trend_order
        post `trend_handle' (`trend_order') ("`outcome_upper'") ///
            ("T1") ("`focal_term'") ("`role'") ///
            (`baseline_b') (`baseline_se') (`baseline_p') ///
            (`trend_b') (`trend_se') (`trend_p') ///
            (`coefficient_difference') (`absolute_difference') ///
            (`relative_difference') (`standardized_difference') ///
            (`se_ratio') (`sign_match') (`baseline_significant') ///
            (`trend_significant') (`baseline_n') (`baseline_g') ///
            (`baseline_g') (scalar(CHECK_T_`outcome'_t1)) ///
            (`baseline_df_m') (`trend_df_m') (`added_df') ///
            (`trend_df_r') (`baseline_r2') (`trend_r2') ///
            ("`sensitivity_assessment'")
    }
}


// 18.2. T2 con tendencias nacionales

* Repetir T2 permitiendo que cada país tenga su propia trayectoria lineal.

foreach outcome in eci divx {
    local outcome_upper = upper("`outcome'")
    local sample_variable "sample_t2_`outcome'"
    local rents_term "t2_ma3_rents"
    local interaction_term "t2_ma3_rents_x_inst"

    quietly xtreg `outcome' ///
        t2_ma3_rents t2_ma3_inst t2_ma3_rents_x_inst i.year ///
        if `sample_variable' == 1, fe vce(cluster country_id)

    assert e(N) == scalar(REF_N_`outcome'_t2)
    assert e(N_g) == scalar(REF_G_`outcome'_t2)
    local baseline_n = e(N)
    local baseline_g = e(N_g)
    local baseline_df_m = e(df_m)
    local baseline_df_r = e(df_r)
    local baseline_r2 = e(r2_w)

    foreach role in rents interaction {
        local focal_term "``role'_term'"
        local baseline_b_`role' = _b[`focal_term']
        local baseline_se_`role' = _se[`focal_term']
        local baseline_p_`role' = 2 * ttail(`baseline_df_r', ///
            abs(_b[`focal_term'] / _se[`focal_term']))

        assert abs(`baseline_b_`role'' - ///
            scalar(REF_B_`outcome'_t2_`role')) <= 1e-12
        assert abs(`baseline_p_`role'' - ///
            scalar(REF_PC_`outcome'_t2_`role')) <= 1e-7
    }

    quietly xtreg `outcome' ///
        t2_ma3_rents t2_ma3_inst t2_ma3_rents_x_inst i.year ///
        i.country_id#c.country_linear_trend ///
        if `sample_variable' == 1, fe vce(cluster country_id)
    estimates store `outcome_upper'_T2_TRENDS

    tempvar used_t2_trends
    generate byte `used_t2_trends' = e(sample)
    assert `used_t2_trends' == `sample_variable'
    assert e(N) == `baseline_n'
    assert e(N_g) == `baseline_g'
    assert e(N_clust) == e(N_g)
    assert e(df_r) == e(N_clust) - 1

    local trend_df_m = e(df_m)
    local trend_df_r = e(df_r)
    local trend_r2 = e(r2_w)

    local added_df = 0
    local coefficient_names : colnames e(b)
    foreach coefficient of local coefficient_names {
        if strpos("`coefficient'", "#c.country_linear_trend") > 0 {
            quietly _ms_parse_parts `coefficient'
            if r(omit) == 0 local ++added_df
        }
    }
    assert `added_df' == `baseline_g' - 1

    estimates save ///
        "$OUTPUT_STABILITY/`outcome'_t2_country_trends.ster", replace

    foreach role in rents interaction {
        local focal_term "``role'_term'"
        local baseline_b = `baseline_b_`role''
        local baseline_se = `baseline_se_`role''
        local baseline_p = `baseline_p_`role''
        local trend_b = _b[`focal_term']
        local trend_se = _se[`focal_term']
        local trend_p = 2 * ttail(`trend_df_r', ///
            abs(`trend_b' / `trend_se'))
        local coefficient_difference = `trend_b' - `baseline_b'
        local absolute_difference = abs(`coefficient_difference')
        local relative_difference = cond(abs(`baseline_b') > 1e-12, ///
            `absolute_difference' / abs(`baseline_b'), .)
        local standardized_difference = ///
            `absolute_difference' / `baseline_se'
        local se_ratio = `trend_se' / `baseline_se'
        local sign_match = sign(`trend_b') == sign(`baseline_b')
        local baseline_significant = `baseline_p' < 0.05
        local trend_significant = `trend_p' < 0.05

        if `sign_match' == 0 {
            local sensitivity_assessment ///
                "Cambio de signo al incorporar tendencias nacionales"
        }
        else if `standardized_difference' > 1 {
            local sensitivity_assessment ///
                "Signo estable; magnitud sensible a tendencias nacionales"
        }
        else if `baseline_significant' != `trend_significant' {
            local sensitivity_assessment ///
                "Signo y magnitud estables; cambia la precisión inferencial"
        }
        else {
            local sensitivity_assessment ///
                "Signo, magnitud y clasificación inferencial estables"
        }

        assert `trend_se' > 0 & !missing(`trend_se')
        assert inrange(`trend_p', 0, 1)
        assert `absolute_difference' >= 0
        assert `standardized_difference' >= 0
        assert `se_ratio' > 0

        local ++trend_order
        post `trend_handle' (`trend_order') ("`outcome_upper'") ///
            ("T2") ("`focal_term'") ("`role'") ///
            (`baseline_b') (`baseline_se') (`baseline_p') ///
            (`trend_b') (`trend_se') (`trend_p') ///
            (`coefficient_difference') (`absolute_difference') ///
            (`relative_difference') (`standardized_difference') ///
            (`se_ratio') (`sign_match') (`baseline_significant') ///
            (`trend_significant') (`baseline_n') (`baseline_g') ///
            (`baseline_g') (scalar(CHECK_T_`outcome'_t2)) ///
            (`baseline_df_m') (`trend_df_m') (`added_df') ///
            (`trend_df_r') (`baseline_r2') (`trend_r2') ///
            ("`sensitivity_assessment'")
    }
}

postclose `trend_handle'


// 18.3. Comparación con el diseño principal

* Comparar los resultados con los modelos sin tendencias propias.

preserve
    use `trend_results', clear
    sort order

    assert _N == 8
    isid outcome model term
    assert inlist(outcome, "ECI", "DIVX")
    assert inlist(model, "T1", "T2")
    assert inlist(term_role, "rents", "interaction")
    assert observations == cond(model == "T1", 1148, 933)
    assert countries == 53
    assert clusters == countries
    assert effective_years == cond(model == "T1", 22, 18)
    assert added_model_df == countries - 1
    assert cluster_residual_df == clusters - 1
    assert inrange(baseline_p_value, 0, 1)
    assert inrange(trend_p_value, 0, 1)
    assert absolute_coefficient_difference >= 0
    assert deviation_in_baseline_se >= 0
    assert standard_error_ratio > 0
    assert inlist(sign_match, 0, 1)
    assert inlist(baseline_significant_5, 0, 1)
    assert inlist(trend_significant_5, 0, 1)

    quietly count if sign_match == 0
    scalar TREND_GROUPS_WITH_SIGN_CHANGES = r(N)
    quietly count if baseline_significant_5 != trend_significant_5
    scalar TREND_GROUPS_WITH_P_CHANGES = r(N)
    quietly count if deviation_in_baseline_se > 1
    scalar TREND_LARGE_B_CHANGES = r(N)

    export delimited using ///
        "$OUTPUT_STABILITY/country_trend_sensitivity.csv", replace
restore

* Esta prueba absorbe trayectorias lineales diferentes para cada país.
* Se distinguen cambios de precisión, signo y magnitud de los coeficientes.
* También se informa cuántos parámetros adicionales requiere el modelo.

local required_trend_outputs ///
    country_trend_sensitivity.csv ///
    eci_t1_country_trends.ster ///
    eci_t2_country_trends.ster ///
    divx_t1_country_trends.ster ///
    divx_t2_country_trends.ster

foreach trend_output of local required_trend_outputs {
    capture confirm file "$OUTPUT_STABILITY/`trend_output'"
    assert _rc == 0
}

use "$TEMPORAL_PANEL", clear
isid country_iso3_code year
xtset country_id year

display as result ///
    "Tendencias nacionales: 4 modelos y 8 términos focales comparados."
display as result ///
    "Cambios de signo: " scalar(TREND_GROUPS_WITH_SIGN_CHANGES) ///
    "; cambios de clasificación al 5%: " ///
    scalar(TREND_GROUPS_WITH_P_CHANGES) "."
display as result ///
    "Cambios de magnitud superiores a 1 EE base: " ///
    scalar(TREND_LARGE_B_CHANGES) "."
display as result ///
    "Costo por modelo: 52 parámetros de tendencia adicionales."
display as result "Sección 18 completada sin errores."
display as result "Siguiente bloque pendiente: sección 19."
display as result "TEMPORAL_03_SECTION_18_OK"


// *****************************************************************************
// 19. Matriz de decisión metodológica TEMP-A--TEMP-F
// *****************************************************************************

// 19.1. Reconciliación de las reglas TEMP-A--TEMP-E

* La significancia no se utiliza para seleccionar el modelo preferido.
* Los valores p se documentan después de validar diseño, muestra y estabilidad.

* TEMP-A: el registro ex ante contiene T0--T5 y la variante condicional T3X.
preserve
    import delimited using ///
        "$OUTPUT_DESIGN/temporal_specification_register.csv", ///
        clear varnames(1)
    assert _N == 7
    isid model
    assert inlist(model, "T0", "T1", "T2", "T3", "T3X", "T4", "T5")

    quietly count if implementation_status == "Congelado"
    assert r(N) == 6
    quietly count if model == "T3X" & ///
        implementation_status == "Condicional a diagnóstico"
    assert r(N) == 1
    scalar DEC_TEMP_A_PASS = 1
restore

* TEMP-B comprueba que las muestras mantengan países y años suficientes.
* Los tamaños también deben coincidir entre ECI y DIVX.
preserve
    import delimited using "$TEMPORAL_SAMPLE_SUMMARY", ///
        clear varnames(1)
    assert _N == 16
    isid outcome model

    foreach candidate in t0 t1 t2 t3 t3_expanded t4 t5 {
        quietly summarize observations if model == "`candidate'", meanonly
        assert r(N) == 2
        assert r(min) == r(max)
        scalar DEC_N_`candidate' = r(mean)

        quietly summarize countries if model == "`candidate'", meanonly
        assert r(N) == 2
        assert r(min) == r(max)
        scalar DEC_G_`candidate' = r(mean)

        quietly summarize calendar_years if model == "`candidate'", meanonly
        assert r(N) == 2
        assert r(min) == r(max)
        scalar DEC_T_`candidate' = r(mean)

        assert scalar(DEC_G_`candidate') == 53
        assert scalar(DEC_T_`candidate') >= 18
    }

    assert scalar(DEC_N_t0) == 1197
    assert scalar(DEC_N_t1) == 1148
    assert scalar(DEC_N_t2) == 933
    assert scalar(DEC_N_t3) == 1140
    assert scalar(DEC_N_t3_expanded) == 933
    assert scalar(DEC_N_t4) == 1142
    assert scalar(DEC_N_t5) == 987
    scalar DEC_TEMP_B_PASS = 1
restore

* TEMP-C limita T3 a la suma y a la prueba conjunta por su VIF elevado.
* T3X tampoco se habilita y esta decisión no depende de los valores p.
preserve
    import delimited using ///
        "$OUTPUT_DIAGNOSTICS/lag_correlation_and_vif.csv", ///
        clear varnames(1)
    assert _N == 18
    isid order

    quietly summarize value if diagnostic == "decision" & ///
        specification == "T3 básico", meanonly
    assert r(N) == 1
    scalar DEC_T3_MAX_VIF = r(mean)

    quietly summarize threshold if diagnostic == "decision" & ///
        specification == "T3 básico", meanonly
    assert r(N) == 1
    scalar DEC_VIF_THRESHOLD = r(mean)

    quietly summarize value if diagnostic == "decision" & ///
        specification == "T3X ampliado", meanonly
    assert r(N) == 1
    scalar DEC_T3X_MAX_VIF = r(mean)

    assert scalar(DEC_T3_MAX_VIF) > scalar(DEC_VIF_THRESHOLD)
    assert scalar(DEC_T3X_MAX_VIF) > scalar(DEC_VIF_THRESHOLD)
    assert scalar(DEC_T3X_MAX_VIF) > scalar(DEC_T3_MAX_VIF)
    scalar DEC_TEMP_C_CORE_PASS = 1
restore

* TEMP-D verifica inferencia agrupada, bootstrap y efectos acumulados.
* Los valores p se documentan, pero no se usan para escoger horizontes.
preserve
    import delimited using ///
        "$OUTPUT_CUMULATIVE/temporal_wild_cluster_bootstrap.csv", ///
        clear varnames(1)
    assert _N == 10
    isid outcome model term
    assert repetitions == 9999
    assert countries == 53
    assert inrange(bootstrap_p, 0, 1)

    foreach outcome in ECI DIVX {
        foreach model in T1 T2 {
            quietly summarize bootstrap_p if outcome == "`outcome'" & ///
                model == "`model'" & strpos(term, "rents") > 0 & ///
                strpos(term, "inst") == 0, meanonly
            assert r(N) == 1
            scalar DEC_P_`outcome'_`model' = r(mean)
        }

        quietly summarize bootstrap_p if outcome == "`outcome'" & ///
            model == "T3", meanonly
        assert r(N) == 1
        scalar DEC_P_`outcome'_T3 = r(mean)
    }
restore

preserve
    import delimited using ///
        "$OUTPUT_CUMULATIVE/cumulative_effect_tests.csv", ///
        clear varnames(1)
    assert _N == 8
    isid outcome sample_type test_type
    assert inrange(p_value, 0, 1)
    quietly count if sample_type == "own" & test_type == "sum"
    assert r(N) == 2
    quietly count if sample_type == "own" & test_type == "joint"
    assert r(N) == 2
    scalar DEC_TEMP_D_PASS = 1
restore

* TEMP-E reúne placebo, diferencias, exclusiones y tendencias nacionales.
* La estabilidad del signo se evalúa por separado de la precisión.
preserve
    import delimited using ///
        "$OUTPUT_PLACEBO/lead_placebo_tests.csv", ///
        clear varnames(1)
    assert _N == 14
    isid outcome model term
    quietly count if is_future_lead == 1
    assert r(N) == 2
    quietly count if is_future_lead == 1 & alert_code != 0
    assert r(N) == 0

    foreach outcome in ECI DIVX {
        quietly summarize p_value if outcome == "`outcome'" & ///
            is_future_lead == 1, meanonly
        assert r(N) == 1
        scalar DEC_P_`outcome'_T4 = r(mean)
    }
    scalar DEC_PLACEBO_ALERTS = 0
restore

preserve
    import delimited using ///
        "$OUTPUT_CHANGES/first_difference_results.csv", ///
        clear varnames(1)
    assert _N == 6
    isid outcome test_type term
    quietly count if term_role == "annual_change_rents"
    assert r(N) == 2
    assert coefficient < 0 if term_role == "annual_change_rents"

    foreach outcome in ECI DIVX {
        quietly summarize p_value if outcome == "`outcome'" & ///
            term_role == "annual_change_rents", meanonly
        assert r(N) == 1
        scalar DEC_P_`outcome'_T5 = r(mean)
    }
restore

preserve
    import delimited using ///
        "$OUTPUT_STABILITY/temporal_leave_one_out_summary.csv", ///
        clear varnames(1)
    assert _N == 8
    isid outcome model term
    assert iterations == 53

    quietly count if term_role == "rents" & sign_change_count > 0
    assert r(N) == 0
    quietly count if term_role == "interaction" & sign_change_count > 0
    scalar DEC_LOO_INTERACTION_SIGN_GROUPS = r(N)
    assert scalar(DEC_LOO_INTERACTION_SIGN_GROUPS) == 2
restore

preserve
    import delimited using ///
        "$OUTPUT_STABILITY/country_trend_sensitivity.csv", ///
        clear varnames(1)
    assert _N == 8
    isid outcome model term

    quietly count if sign_match == 0
    scalar DEC_TREND_SIGN_CHANGES = r(N)
    assert scalar(DEC_TREND_SIGN_CHANGES) == 0

    quietly count if baseline_significant_5 != trend_significant_5
    scalar DEC_TREND_P_CHANGES = r(N)
    assert scalar(DEC_TREND_P_CHANGES) == 4

    quietly count if deviation_in_baseline_se > 1
    scalar DEC_TREND_LARGE_CHANGES = r(N)
    assert scalar(DEC_TREND_LARGE_CHANGES) == 4
    scalar DEC_TEMP_E_CAVEAT = 1
restore


// 19.2. Decisión por diseño temporal

* TEMP-F asigna a cada diseño un papel específico dentro del TFM.
* Los papeles posibles son principal, sensibilidad, diagnóstico o apéndice.

tempname decision_handle
tempfile decision_results

postfile `decision_handle' ///
    int order str8 model str50 analytical_role ///
    double observations countries effective_years max_vif ///
    eci_key_p divx_key_p ///
    str24 temp_a_design str24 temp_b_sample ///
    str24 temp_c_estimability str24 temp_d_inference ///
    str28 temp_e_stability str36 temp_f_tfm_role ///
    str28 decision_code str100 main_limitation ///
    str180 evidence_artifacts str48 selection_rule ///
    using `decision_results', replace

post `decision_handle' ///
    (1) ("T0") ("Referencia contemporánea del módulo temporal") ///
    (scalar(DEC_N_t0)) (scalar(DEC_G_t0)) (scalar(DEC_T_t0)) ///
    (.) (.) (.) ///
    ("Cumple") ("Cumple") ("Cumple") ("Inferencia agrupada") ///
    ("No aplica") ("Referencia; no duplicar TWFE") ///
    ("reference_only") ///
    ("No constituye un método temporal adicional") ///
    ("registro ex ante; coeficientes T0; muestra propia y común") ///
    ("Reglas ex ante; nunca p-valor")

post `decision_handle' ///
    (2) ("T1") ("Precedencia temporal de un año") ///
    (scalar(DEC_N_t1)) (scalar(DEC_G_t1)) (scalar(DEC_T_t1)) ///
    (.) (scalar(DEC_P_ECI_T1)) (scalar(DEC_P_DIVX_T1)) ///
    ("Cumple") ("Cumple") ("Cumple") ("Cluster y wild bootstrap") ///
    ("Cumple con cautelas") ("Resultado temporal principal") ///
    ("principal_temporal") ///
    ("Interacciones sensibles en ECI o nulas en DIVX") ///
    ("bootstrap; placebo; leave-one-out; tendencias nacionales") ///
    ("Reglas ex ante; nunca p-valor")

post `decision_handle' ///
    (3) ("T2") ("Exposición acumulada retrospectiva de tres años") ///
    (scalar(DEC_N_t2)) (scalar(DEC_G_t2)) (scalar(DEC_T_t2)) ///
    (.) (scalar(DEC_P_ECI_T2)) (scalar(DEC_P_DIVX_T2)) ///
    ("Cumple") ("Cumple") ("Cumple") ("Cluster y wild bootstrap") ///
    ("Cumple con cautelas") ("Sensibilidad temporal acumulada") ///
    ("sensitivity_accumulated") ///
    ("Menor muestra y sensibilidad a tendencias nacionales") ///
    ("bootstrap; muestra común; leave-one-out; tendencias nacionales") ///
    ("Reglas ex ante; nunca p-valor")

post `decision_handle' ///
    (4) ("T3") ("Efecto acumulado de rezagos distribuidos 0--2") ///
    (scalar(DEC_N_t3)) (scalar(DEC_G_t3)) (scalar(DEC_T_t3)) ///
    (scalar(DEC_T3_MAX_VIF)) ///
    (scalar(DEC_P_ECI_T3)) (scalar(DEC_P_DIVX_T3)) ///
    ("Cumple") ("Cumple") ("Cumple restringido") ///
    ("Suma, conjunta y bootstrap") ("No evaluado con LOO") ///
    ("Apéndice: solo suma y conjunta") ("appendix_cumulative") ///
    ("VIF alto impide interpretar rezagos individuales") ///
    ("diagnóstico VIF; suma acumulada; prueba conjunta; bootstrap") ///
    ("Reglas ex ante; nunca p-valor")

post `decision_handle' ///
    (5) ("T3X") ("Moderación distribuida ampliada") ///
    (scalar(DEC_N_t3_expanded)) (scalar(DEC_G_t3_expanded)) ///
    (scalar(DEC_T_t3_expanded)) (scalar(DEC_T3X_MAX_VIF)) ///
    (.) (.) ///
    ("Cumple condicional") ("Cumple") ("No cumple") ("No aplica") ///
    ("No aplica") ("Excluir con justificación") ("excluded_collinearity") ///
    ("VIF máximo excede ampliamente el umbral predefinido") ///
    ("diagnóstico T3X; modelo no estimado por regla ex ante") ///
    ("Reglas ex ante; nunca p-valor")

post `decision_handle' ///
    (6) ("T4") ("Falsificación mediante adelanto de RENTS") ///
    (scalar(DEC_N_t4)) (scalar(DEC_G_t4)) (scalar(DEC_T_t4)) ///
    (.) (scalar(DEC_P_ECI_T4)) (scalar(DEC_P_DIVX_T4)) ///
    ("Cumple") ("Cumple") ("Cumple") ("Inferencia agrupada") ///
    ("Sin alerta estadística") ("Diagnóstico de falsificación") ///
    ("diagnostic_placebo") ///
    ("Un adelanto no demuestra exogeneidad ni causalidad") ///
    ("placebo t+1 sobre muestra común con bloque contemporáneo") ///
    ("Reglas ex ante; nunca p-valor")

post `decision_handle' ///
    (7) ("T5") ("Cambios anuales de corto plazo") ///
    (scalar(DEC_N_t5)) (scalar(DEC_G_t5)) (scalar(DEC_T_t5)) ///
    (.) (scalar(DEC_P_ECI_T5)) (scalar(DEC_P_DIVX_T5)) ///
    ("Cumple") ("Cumple") ("Cumple") ("Inferencia agrupada") ///
    ("Coherente con cautelas") ("Sensibilidad de corto plazo") ///
    ("sensitivity_short_run") ///
    ("La diferenciación puede amplificar error de medición") ///
    ("primeras diferencias; efectos de año; errores agrupados") ///
    ("Reglas ex ante; nunca p-valor")

postclose `decision_handle'


// 19.3. Validación y exportación de la matriz

* Verificar que cada modelo tenga decisión, limitación y evidencia documentadas.

preserve
    use `decision_results', clear
    sort order

    assert _N == 7
    isid order
    isid model
    assert inlist(model, "T0", "T1", "T2", "T3", "T3X", "T4", "T5")
    assert observations > 0
    assert countries == 53
    assert effective_years >= 18
    assert selection_rule == "Reglas ex ante; nunca p-valor"
    assert temp_a_design != ""
    assert temp_b_sample != ""
    assert temp_c_estimability != ""
    assert temp_d_inference != ""
    assert temp_e_stability != ""
    assert temp_f_tfm_role != ""
    assert decision_code != ""
    assert main_limitation != ""
    assert evidence_artifacts != ""

    quietly summarize max_vif if model == "T3", meanonly
    assert r(N) == 1
    assert abs(r(mean) - scalar(DEC_T3_MAX_VIF)) <= 1e-6
    quietly summarize max_vif if model == "T3X", meanonly
    assert r(N) == 1
    assert abs(r(mean) - scalar(DEC_T3X_MAX_VIF)) <= 1e-4
    assert missing(max_vif) if !inlist(model, "T3", "T3X")
    assert inrange(eci_key_p, 0, 1) if !inlist(model, "T0", "T3X")
    assert inrange(divx_key_p, 0, 1) if !inlist(model, "T0", "T3X")

    quietly count if decision_code == "principal_temporal"
    assert r(N) == 1
    quietly count if decision_code == "excluded_collinearity"
    assert r(N) == 1
    quietly count if strpos(decision_code, "sensitivity") == 1
    assert r(N) == 2
    quietly count if model == "T3" & ///
        temp_c_estimability == "Cumple restringido"
    assert r(N) == 1
    quietly count if model == "T3X" & temp_c_estimability == "No cumple"
    assert r(N) == 1

    export delimited using ///
        "$OUTPUT_FINAL/temporal_acceptance_decision.csv", replace
restore

capture confirm file "$OUTPUT_FINAL/temporal_acceptance_decision.csv"
assert _rc == 0

preserve
    import delimited using ///
        "$OUTPUT_FINAL/temporal_acceptance_decision.csv", ///
        clear varnames(1)
    assert _N == 7
    isid model
    quietly count if decision_code == "principal_temporal"
    assert r(N) == 1
    quietly count if decision_code == "excluded_collinearity"
    assert r(N) == 1
restore

scalar DEC_TEMP_F_INCLUDE_CAVEATS = ///
    scalar(DEC_TEMP_A_PASS) * scalar(DEC_TEMP_B_PASS) * ///
    scalar(DEC_TEMP_C_CORE_PASS) * scalar(DEC_TEMP_D_PASS) * ///
    scalar(DEC_TEMP_E_CAVEAT)
assert scalar(DEC_TEMP_F_INCLUDE_CAVEATS) == 1

use "$TEMPORAL_PANEL", clear
isid country_iso3_code year
xtset country_id year

display as result ///
    "TEMP-A--TEMP-D: diseño, muestras, estimabilidad e inferencia validados."
display as result ///
    "TEMP-E: estable en signo para RENTS; tendencias exigen cautelas."
display as result ///
    "TEMP-F: incorporar el módulo temporal con jerarquía y cautelas explícitas."
display as result ///
    "Decisión: T1 principal; T2 y T5 sensibilidades; T3 apéndice; T4 diagnóstico; T3X excluido."
display as result "Sección 19 completada sin errores."
display as result "Siguiente bloque pendiente: sección 20."
display as result "TEMPORAL_03_SECTION_19_OK"


// *****************************************************************************
// 20. Exportación, manifiesto y cierre del módulo temporal
// *****************************************************************************

// 20.1. Construcción del manifiesto integral

* El manifiesto reúne los productos analíticos creados por los tres archivos.
* No incluye los registros de ejecución ni se incluye a sí mismo.

tempname final_manifest_handle
tempfile final_manifest_results

postfile `final_manifest_handle' ///
    int order str4 source_file str20 stage str8 artifact_type ///
    str100 relative_path double expected_records actual_records ///
    str20 record_unit str100 tfm_role str28 inclusion_role ///
    str12 status ///
    using `final_manifest_results', replace

* Productos del archivo 01: diseño, muestras y panel derivado.
post `final_manifest_handle' ///
    (1) ("01") ("design") ("csv") ///
    ("00_design/temporal_specification_register.csv") (7) (.) ("rows") ///
    ("Registro ex ante de T0--T5 y T3X") ("Metodología") ("pending")
post `final_manifest_handle' ///
    (2) ("01") ("sample") ("dta") ///
    ("01_sample/temporal_panel.dta") (1430) (.) ("data rows") ///
    ("Panel temporal derivado y reproducible") ("Reproducibilidad") ("pending")
post `final_manifest_handle' ///
    (3) ("01") ("sample") ("csv") ///
    ("01_sample/temporal_sample_summary.csv") (16) (.) ("rows") ///
    ("Resumen de muestras por resultado y diseño") ("Metodología") ("pending")
post `final_manifest_handle' ///
    (4) ("01") ("sample") ("csv") ///
    ("01_sample/temporal_sample_loss_summary.csv") (12) (.) ("rows") ///
    ("Descomposición de pérdidas por temporalidad") ("Apéndice") ("pending")
post `final_manifest_handle' ///
    (5) ("01") ("sample") ("csv") ///
    ("01_sample/temporal_sample_by_country.csv") (880) (.) ("rows") ///
    ("Cobertura temporal por país") ("Apéndice") ("pending")
post `final_manifest_handle' ///
    (6) ("01") ("sample") ("csv") ///
    ("01_sample/temporal_sample_by_year.csv") (416) (.) ("rows") ///
    ("Cobertura temporal por año") ("Apéndice") ("pending")
post `final_manifest_handle' ///
    (7) ("01") ("audit") ("csv") ///
    ("09_final/temporal_output_manifest.csv") (6) (.) ("rows") ///
    ("Manifiesto de datos y muestras") ("Auditoría") ("pending")

* Productos del archivo 02: modelos, inferencia y traspaso.
post `final_manifest_handle' ///
    (8) ("02") ("diagnostics") ("csv") ///
    ("02_diagnostics/lag_correlation_and_vif.csv") (18) (.) ("rows") ///
    ("Diagnóstico ex ante de T3 y T3X") ("Diagnóstico") ("pending")
post `final_manifest_handle' ///
    (9) ("02") ("coefficients") ("csv") ///
    ("03_eci/eci_temporal_coefficients.csv") (26) (.) ("rows") ///
    ("Coeficientes temporales de ECI") ("Resultados") ("pending")
post `final_manifest_handle' ///
    (10) ("02") ("models") ("ster") ///
    ("03_eci/eci_t1_own.ster") (1148) (.) ("model observations") ///
    ("Estimación reproducible ECI T1") ("Reproducibilidad") ("pending")
post `final_manifest_handle' ///
    (11) ("02") ("models") ("ster") ///
    ("03_eci/eci_t2_own.ster") (933) (.) ("model observations") ///
    ("Estimación reproducible ECI T2") ("Reproducibilidad") ("pending")
post `final_manifest_handle' ///
    (12) ("02") ("coefficients") ("csv") ///
    ("04_divx/divx_temporal_coefficients.csv") (26) (.) ("rows") ///
    ("Coeficientes temporales de DIVX") ("Resultados") ("pending")
post `final_manifest_handle' ///
    (13) ("02") ("models") ("ster") ///
    ("04_divx/divx_t1_own.ster") (1148) (.) ("model observations") ///
    ("Estimación reproducible DIVX T1") ("Reproducibilidad") ("pending")
post `final_manifest_handle' ///
    (14) ("02") ("models") ("ster") ///
    ("04_divx/divx_t2_own.ster") (933) (.) ("model observations") ///
    ("Estimación reproducible DIVX T2") ("Reproducibilidad") ("pending")
post `final_manifest_handle' ///
    (15) ("02") ("inference") ("csv") ///
    ("05_cumulative/cumulative_effect_tests.csv") (8) (.) ("rows") ///
    ("Sumas y pruebas conjuntas de T3") ("Apéndice") ("pending")
post `final_manifest_handle' ///
    (16) ("02") ("inference") ("csv") ///
    ("05_cumulative/temporal_wild_cluster_bootstrap.csv") (10) (.) ("rows") ///
    ("Inferencia bootstrap de T1, T2 y suma T3") ("Resultados") ("pending")
post `final_manifest_handle' ///
    (17) ("02") ("final") ("csv") ///
    ("09_final/temporal_model_coefficients.csv") (52) (.) ("rows") ///
    ("Tabla combinada de coeficientes T0--T3") ("Resultados") ("pending")
post `final_manifest_handle' ///
    (18) ("02") ("handoff") ("csv") ///
    ("09_final/02_models_handoff.csv") (8) (.) ("rows") ///
    ("Traspaso reproducible al archivo 03") ("Auditoría") ("pending")
post `final_manifest_handle' ///
    (19) ("02") ("audit") ("csv") ///
    ("09_final/02_results_manifest.csv") (11) (.) ("rows") ///
    ("Manifiesto de modelos e inferencia") ("Auditoría") ("pending")

* Productos del archivo 03: falsificación, cambios, estabilidad y decisión.
post `final_manifest_handle' ///
    (20) ("03") ("placebo") ("csv") ///
    ("06_placebo/lead_placebo_tests.csv") (14) (.) ("rows") ///
    ("Adelanto placebo T4") ("Diagnóstico") ("pending")
post `final_manifest_handle' ///
    (21) ("03") ("placebo") ("ster") ///
    ("06_placebo/eci_t4_placebo.ster") (1142) (.) ///
    ("model observations") ("Estimación reproducible ECI T4") ///
    ("Reproducibilidad") ("pending")
post `final_manifest_handle' ///
    (22) ("03") ("placebo") ("ster") ///
    ("06_placebo/divx_t4_placebo.ster") (1142) (.) ///
    ("model observations") ("Estimación reproducible DIVX T4") ///
    ("Reproducibilidad") ("pending")
post `final_manifest_handle' ///
    (23) ("03") ("changes") ("csv") ///
    ("07_changes/first_difference_results.csv") (6) (.) ("rows") ///
    ("Primeras diferencias T5") ("Sensibilidad") ("pending")
post `final_manifest_handle' ///
    (24) ("03") ("changes") ("ster") ///
    ("07_changes/eci_t5_first_difference.ster") (987) (.) ///
    ("model observations") ("Estimación reproducible ECI T5") ///
    ("Reproducibilidad") ("pending")
post `final_manifest_handle' ///
    (25) ("03") ("changes") ("ster") ///
    ("07_changes/divx_t5_first_difference.ster") (987) (.) ///
    ("model observations") ("Estimación reproducible DIVX T5") ///
    ("Reproducibilidad") ("pending")
post `final_manifest_handle' ///
    (26) ("03") ("stability") ("csv") ///
    ("08_stability/temporal_leave_one_out.csv") (424) (.) ("rows") ///
    ("Detalle leave-one-country-out de T1 y T2") ("Sensibilidad") ("pending")
post `final_manifest_handle' ///
    (27) ("03") ("stability") ("csv") ///
    ("08_stability/temporal_leave_one_out_summary.csv") (8) (.) ("rows") ///
    ("Resumen leave-one-country-out") ("Sensibilidad") ("pending")
post `final_manifest_handle' ///
    (28) ("03") ("stability") ("csv") ///
    ("08_stability/country_trend_sensitivity.csv") (8) (.) ("rows") ///
    ("Tendencias lineales específicas por país") ("Sensibilidad") ("pending")
post `final_manifest_handle' ///
    (29) ("03") ("stability") ("ster") ///
    ("08_stability/eci_t1_country_trends.ster") (1148) (.) ///
    ("model observations") ("Estimación ECI T1 con tendencias") ///
    ("Reproducibilidad") ("pending")
post `final_manifest_handle' ///
    (30) ("03") ("stability") ("ster") ///
    ("08_stability/eci_t2_country_trends.ster") (933) (.) ///
    ("model observations") ("Estimación ECI T2 con tendencias") ///
    ("Reproducibilidad") ("pending")
post `final_manifest_handle' ///
    (31) ("03") ("stability") ("ster") ///
    ("08_stability/divx_t1_country_trends.ster") (1148) (.) ///
    ("model observations") ("Estimación DIVX T1 con tendencias") ///
    ("Reproducibilidad") ("pending")
post `final_manifest_handle' ///
    (32) ("03") ("stability") ("ster") ///
    ("08_stability/divx_t2_country_trends.ster") (933) (.) ///
    ("model observations") ("Estimación DIVX T2 con tendencias") ///
    ("Reproducibilidad") ("pending")
post `final_manifest_handle' ///
    (33) ("03") ("decision") ("csv") ///
    ("09_final/temporal_acceptance_decision.csv") (7) (.) ("rows") ///
    ("Jerarquía metodológica TEMP-A--TEMP-F") ("Metodología") ("pending")

postclose `final_manifest_handle'


// 20.2. Verificación individual de los productos

* Abrir cada producto y comparar su contenido con el inventario esperado.

use `final_manifest_results', clear
sort order

assert _N == 33
isid order
isid relative_path
assert inlist(source_file, "01", "02", "03")
assert inlist(artifact_type, "csv", "dta", "ster")
assert expected_records > 0
assert actual_records == .
assert status == "pending"

quietly count if artifact_type == "csv"
assert r(N) == 20
quietly count if artifact_type == "dta"
assert r(N) == 1
quietly count if artifact_type == "ster"
assert r(N) == 12
quietly count if source_file == "01"
assert r(N) == 7
quietly count if source_file == "02"
assert r(N) == 12
quietly count if source_file == "03"
assert r(N) == 14

forvalues row = 1/`=_N' {
    local artifact_path = relative_path[`row']
    local artifact_kind = artifact_type[`row']
    local expected_count = expected_records[`row']

    capture confirm file "$OUTPUT_ROOT/`artifact_path'"
    if _rc {
        display as error "Falta un producto del manifiesto final:"
        display as error "$OUTPUT_ROOT/`artifact_path'"
        exit 601
    }

    if "`artifact_kind'" == "csv" {
        preserve
            import delimited using "$OUTPUT_ROOT/`artifact_path'", ///
                clear varnames(1)
            quietly count
            local actual_count = r(N)
        restore
    }
    else if "`artifact_kind'" == "dta" {
        preserve
            use "$OUTPUT_ROOT/`artifact_path'", clear
            isid country_iso3_code year
            quietly count
            local actual_count = r(N)
            quietly levelsof country_id, local(manifest_country_ids)
            local manifest_countries : word count `manifest_country_ids'
            assert `manifest_countries' == 55
            quietly summarize year, meanonly
            assert r(min) == 1996
            assert r(max) == 2021
        restore
    }
    else if "`artifact_kind'" == "ster" {
        quietly estimates use "$OUTPUT_ROOT/`artifact_path'"
        local expected_depvar = cond(strpos("`artifact_path'", "/eci_") > 0, ///
            "eci", "divx")
        if strpos("`artifact_path'", "_t5_first_difference") > 0 {
            local expected_depvar = "t5_d_`expected_depvar'"
        }
        assert "`e(depvar)'" == "`expected_depvar'"

        if strpos("`artifact_path'", "_t5_first_difference") > 0 {
            assert "`e(cmd)'" == "regress"
        }
        else {
            assert "`e(cmd)'" == "xtreg"
        }

        assert "`e(vce)'" == "cluster"
        assert e(N_clust) == 53

        local stored_terms : colnames e(b)
        if strpos("`artifact_path'", "_t1_") > 0 {
            assert strpos(" `stored_terms' ", " t1_rents ") > 0
        }
        if strpos("`artifact_path'", "_t2_") > 0 {
            assert strpos(" `stored_terms' ", " t2_ma3_rents ") > 0
        }
        if strpos("`artifact_path'", "_t4_") > 0 {
            assert strpos(" `stored_terms' ", " t4_rents_f1 ") > 0
        }
        if strpos("`artifact_path'", "_t5_") > 0 {
            assert strpos(" `stored_terms' ", " t5_d_rents ") > 0
        }
        if strpos("`artifact_path'", "country_trends") > 0 {
            assert strpos("`stored_terms'", "country_linear_trend") > 0
        }

        local actual_count = e(N)
    }

    assert `actual_count' == `expected_count'
    replace actual_records = `actual_count' in `row'
    replace status = "validated" in `row'
}

assert actual_records == expected_records
assert status == "validated"
assert tfm_role != ""
assert inclusion_role != ""
assert record_unit != ""

generate str11 validation_date = "`c(current_date)'"
generate str8 validation_time = "`c(current_time)'"
order order source_file stage artifact_type relative_path ///
    expected_records actual_records record_unit tfm_role ///
    inclusion_role status validation_date validation_time

export delimited using ///
    "$OUTPUT_FINAL/temporal_results_manifest.csv", replace


// 20.3. Reapertura, decisión y cierre definitivo

* Reabrir los resultados finales antes de declarar completo el módulo temporal.

capture confirm file "$OUTPUT_FINAL/temporal_results_manifest.csv"
assert _rc == 0

preserve
    import delimited using ///
        "$OUTPUT_FINAL/temporal_results_manifest.csv", ///
        clear varnames(1)
    assert _N == 33
    isid order
    isid relative_path
    assert actual_records == expected_records
    assert status == "validated"
    quietly count if inclusion_role == "Resultados"
    assert r(N) == 4
    quietly count if inclusion_role == "Sensibilidad"
    assert r(N) == 4
    quietly count if inclusion_role == "Diagnóstico"
    assert r(N) == 2
restore

preserve
    import delimited using ///
        "$OUTPUT_FINAL/temporal_acceptance_decision.csv", ///
        clear varnames(1)
    assert _N == 7
    isid model
    quietly count if decision_code == "principal_temporal" & model == "T1"
    assert r(N) == 1
    quietly count if decision_code == "excluded_collinearity" & model == "T3X"
    assert r(N) == 1
    quietly count if selection_rule != "Reglas ex ante; nunca p-valor"
    assert r(N) == 0
restore

use "$TEMPORAL_PANEL", clear
isid country_iso3_code year
assert _N == 1430
quietly levelsof country_id, local(final_country_ids)
local final_countries : word count `final_country_ids'
assert `final_countries' == 55
quietly summarize year, meanonly
assert r(min) == 1996
assert r(max) == 2021
xtset country_id year

display as result ///
    "Manifiesto integral validado: 33 productos previos y 1 manifiesto final."
display as result ///
    "Cobertura: 20 CSV, 1 panel DTA y 12 estimaciones STER."
display as result ///
    "Decisión final: incorporar el módulo temporal con cautelas explícitas."
display as result ///
    "Archivo temporal 03 finalizado: sensibilidades y decisión validadas."
display as result ///
    "Módulo 02_temporal_fe completo: secciones 1 a 20 validadas."
display as result "TEMPORAL_03_SECTION_20_OK"
display as result "TEMPORAL_03_COMPLETED_OK"
display as result "TEMPORAL_MODULE_COMPLETED_OK"
display as result "Fin: `c(current_date)' `c(current_time)'"

log close temporal_sensitivity_log
