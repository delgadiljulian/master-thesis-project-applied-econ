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
// Archivo: 02_lagged_and_cumulative_models.do (Versión Codex)
// Contenido: Secciones 7 a 13 — especificaciones T0--T3, inferencia y
//            efectos acumulados
// Requisito: ejecutar primero 01_temporal_data_and_samples.do
// Continuación: 03_leads_changes_and_sensitivity.do
// Fecha: Segundo Cuatrimestre 2026
//
// ESTADO: COMPLETO. Secciones 7 a 13 implementadas y validadas.
// *****************************************************************************


// *****************************************************************************
// PROPÓSITO, ALCANCE Y CONTRATO ECONOMÉTRICO DEL ARCHIVO 02
// *****************************************************************************
//
// 1. OBJETIVO DEL ANÁLISIS DE REZAGOS Y EFECTOS ACUMULADOS:
//    Este archivo estima las especificaciones de exposición temporal (T0--T3) para
//    evaluar si la relación entre rentas extractivas (RENTS) y complejidad/diversificación
//    opera de forma contemporánea, con rezago de transmisión, o acumulada.
//
// 2. MODELO DE REZAGOS DISTRIBUIDOS (DLM):
//    Se evalúa la estructura de rezagos distribuidos:
//    Y_it = alpha_i + delta_t + sum_{k=0}^2 beta_{k,1} RENTS_i,t-k + sum_{k=0}^2 beta_{k,2} (RENTS × INST)_i,t-k + X_it' gamma + epsilon_it
//    
//    - Efecto Acumulado de Largo Plazo (Long-Run Multiplier): Phi = sum_{k=0}^2 beta_{k,1}
//    - Prueba de Hipótesis Conjunta de Suma de Rezagos: H0: Phi = 0 (vía test / lincom)
//
// 3. PREGUNTAS CLAVE DE AUDITORÍA EMPÍRICA:
//    1. ¿La asociación RENTS-ECI/DIVX ocurre en el mismo año t o requiere t-1 / t-2?
//    2. ¿El promedio móvil trienal (bar(X)_i,t-2..t) suaviza mejor la volatilidad de precios?
//    3. ¿Los rezagos 0, 1 y 2 presentan colinealidad excesiva (evaluado con VIF panel)?
//    4. ¿La suma acumulada de los efectos es estadísticamente significativa bajo wild bootstrap?
//
// 4. ENTRADA Y SALIDAS:
//    - Entrada: 01_sample/temporal_panel.dta (validado previamente por el archivo 01)
//    - Salidas: 02_diagnostics/lag_correlation_and_vif.csv
//               03_eci/eci_temporal_coefficients.csv
//               04_divx/divx_temporal_coefficients.csv
//               05_cumulative/cumulative_effect_tests.csv
//               logs/02_lagged_and_cumulative_models.log
// *****************************************************************************


// *****************************************************************************
// 7. Inicialización reproducible del archivo 02
// *****************************************************************************

// 7.1. Limpiar la sesión y fijar el entorno

* El archivo puede comenzar en una sesión nueva de Stata.
* Repite la configuración general, pero no reconstruye los datos temporales.

* Limpiar la sesión y fijar exactamente el entorno usado por el archivo 01.
version 17.0
clear all
cls
macro drop _all
capture log close _all

set more off
set varabbrev off
set type double
set linesize 255
set seed 20260729
set sortseed 20260729

* Usar el panel maestro como marcador estable de la raíz del repositorio.
local project_marker ///
    "data/processed/00_master_panel/master_panel_country_year.dta"
local project_current "`c(pwd)'"
local project_windows ///
    "C:/Users/`c(username)'/GitHub/master-thesis-project-applied-econ"
local project_manual ""
global PROJECT_ROOT ""

* Buscar desde el directorio actual y hasta ocho niveles superiores.
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

* Probar la ubicación habitual de Windows si la búsqueda ascendente falla.
if "$PROJECT_ROOT" == "" {
    capture confirm file "`project_windows'/`project_marker'"
    if !_rc {
        global PROJECT_ROOT "`project_windows'"
    }
}

* Permitir una ruta manual para otros equipos.
if "$PROJECT_ROOT" == "" & "`project_manual'" != "" {
    capture confirm file "`project_manual'/`project_marker'"
    if !_rc {
        global PROJECT_ROOT "`project_manual'"
    }
}

* Detener el archivo si no se logra identificar la raíz.
if "$PROJECT_ROOT" == "" {
    display as error "No se pudo localizar la raíz del repositorio."
    display as error "Directorio inicial: `c(pwd)'"
    display as error "Edite project_manual en la sección 7.1."
    exit 601
}

quietly cd "$PROJECT_ROOT"
display as result "Raíz del proyecto localizada correctamente:"
pwd


// 7.2. Definir entradas, outputs y log

* Las estimaciones se guardan únicamente dentro del módulo temporal.
* Ningún resultado del módulo TWFE principal puede sobrescribirse.

* Centralizar las rutas del módulo temporal y sus productos.
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
global TEMPORAL_SPECIFICATIONS ///
    "$OUTPUT_DESIGN/temporal_specification_register.csv"
global TEMPORAL_SAMPLE_SUMMARY ///
    "$OUTPUT_SAMPLE/temporal_sample_summary.csv"
global TEMPORAL_LOSS_SUMMARY ///
    "$OUTPUT_SAMPLE/temporal_sample_loss_summary.csv"
global TEMPORAL_BY_COUNTRY ///
    "$OUTPUT_SAMPLE/temporal_sample_by_country.csv"
global TEMPORAL_BY_YEAR ///
    "$OUTPUT_SAMPLE/temporal_sample_by_year.csv"

* Crear únicamente las carpetas utilizadas por este archivo y sus extensiones.
capture mkdir "$OUTPUT_ROOT"
capture mkdir "$OUTPUT_DIAGNOSTICS"
capture mkdir "$OUTPUT_ECI"
capture mkdir "$OUTPUT_DIVX"
capture mkdir "$OUTPUT_CUMULATIVE"
capture mkdir "$OUTPUT_LOGS"
capture mkdir "$ADO_PROJECT"
capture mkdir "$ADO_PROJECT/plus"

* Abrir un log independiente del archivo de preparación temporal.
log using "$OUTPUT_LOGS/02_lagged_and_cumulative_models.log", ///
    text replace name(temporal_models_log)

display as text "7. Inicialización reproducible del archivo 02"
display as result "Stata:    versión 17.0"
display as result "Proyecto: $PROJECT_ROOT"
display as result "Entrada:  $TEMPORAL_PANEL"
display as result "Salidas:  $OUTPUT_ROOT"
display as result "Inicio:   `c(current_date)' `c(current_time)'"


// 7.3. Comprobar dependencias econométricas

* El archivo distingue herramientas incluidas en Stata de paquetes externos.
* Todo paquete externo debe guardarse y validarse dentro del proyecto.

* Añadir las bibliotecas del módulo temporal y del TWFE principal.
* Estas adiciones no reemplazan las rutas habituales de Stata.
adopath ++ "$ADO_PROJECT/plus"
capture confirm file "$ADO_TWFE"
adopath ++ "$ADO_TWFE"

* Las secciones 7 y 8 solo requieren comandos nativos de Stata 17.
local required_native_commands ///
    isid levelsof xtset xtdescribe regress xtreg

foreach command of local required_native_commands {
    capture which `command'
    if _rc {
        display as error "Stata no encuentra el comando requerido: `command'"
        exit 199
    }
}

* Registrar si boottest ya está disponible, sin instalarlo ni bloquear todavía.
* Su disponibilidad será obligatoria únicamente al programar la sección 12.
capture which boottest
if _rc {
    local boottest_status "Pendiente para la sección 12"
}
else {
    local boottest_status "Disponible"
}

display as result "Comandos nativos de las secciones 7 y 8 verificados."
display as result "Estado de boottest: `boottest_status'"


// *****************************************************************************
// 8. Verificación del insumo congelado
// *****************************************************************************

// 8.1. Confirmar el producto del archivo 01

* Detener la ejecución si falta la base temporal o su llave no es única.
* Detenerla también si faltan variables o cambian los tamaños de muestra.

* Comprobar países, grupos, años y períodos efectivos de cada muestra.
* Un modelo ejecutable no es informativo si su cobertura es insuficiente.

display as text "8. Verificación del insumo congelado"

* Confirmar todos los productos que permiten auditar la base temporal.
local required_inputs ///
    00_design/temporal_specification_register.csv ///
    01_sample/temporal_sample_summary.csv ///
    01_sample/temporal_sample_loss_summary.csv ///
    01_sample/temporal_sample_by_country.csv ///
    01_sample/temporal_sample_by_year.csv ///
    01_sample/temporal_panel.dta

foreach relative_input of local required_inputs {
    capture confirm file "$OUTPUT_ROOT/`relative_input'"
    if _rc {
        display as error "Falta un producto obligatorio del archivo 01:"
        display as error "$OUTPUT_ROOT/`relative_input'"
        display as error "Ejecute primero 01_temporal_data_and_samples.do."
        exit 601
    }
}

* Cargar exclusivamente la base derivada; no volver al panel maestro.
use "$TEMPORAL_PANEL", clear

* Confirmar la procedencia registrada dentro del archivo .dta.
local temporal_module : char _dta[temporal_module]
local temporal_stage : char _dta[temporal_stage]
assert "`temporal_module'" == "02_temporal_fe"
assert "`temporal_stage'" == "Secciones 1 a 6 completas"

* Verificar grano, dimensiones y estructura del panel congelado.
isid country_iso3_code year
quietly count
local panel_observations = r(N)
assert `panel_observations' == 1430

quietly levelsof country_id, local(panel_country_ids)
local panel_countries : word count `panel_country_ids'
assert `panel_countries' == 55

quietly summarize year, meanonly
local panel_first_year = r(min)
local panel_last_year = r(max)
assert `panel_first_year' == 1996
assert `panel_last_year' == 2021

xtset country_id year
xtdescribe

* Confirmar identificadores, resultados, términos temporales y banderas.
confirm variable ///
    country_iso3_code country country_id year eci divx ///
    rents inst rents_x_inst ///
    continuity_l1 continuity_l2 continuity_f1 ///
    t0_rents t0_inst t0_rents_x_inst ///
    t1_rents t1_inst t1_rents_x_inst ///
    t2_ma3_rents t2_ma3_inst t2_ma3_rents_x_inst ///
    t3_rents_l0 t3_rents_l1 t3_rents_l2 ///
    t3_inst_l0 t3_inst_l1 t3_inst_l2 ///
    t3_rents_x_inst_l0 t3_rents_x_inst_l1 ///
    t3_rents_x_inst_l2 t4_rents_f1 ///
    t5_d_eci t5_d_divx t5_d_rents t5_d_inst ///
    sample_t0_eci sample_t1_eci sample_t2_eci sample_t3_eci ///
    sample_t3_expanded_eci sample_t4_eci sample_t5_eci ///
    sample_t0_divx sample_t1_divx sample_t2_divx sample_t3_divx ///
    sample_t3_expanded_divx sample_t4_divx sample_t5_divx ///
    sample_common_t0_t3_eci sample_common_t0_t3_divx

* Reproducir las identidades temporales centrales directamente desde la base.
assert continuity_l1 == (year > `panel_first_year')
assert continuity_l2 == (year > `panel_first_year' + 1)
assert continuity_f1 == (year < `panel_last_year')

assert t1_rents == L1.rents ///
    if continuity_l1 == 1 & !missing(t1_rents, L1.rents)
assert t1_inst == L1.inst ///
    if continuity_l1 == 1 & !missing(t1_inst, L1.inst)
assert abs(t1_rents_x_inst - t1_rents*t1_inst) <= 1e-10 ///
    if !missing(t1_rents_x_inst, t1_rents, t1_inst)

assert abs(t2_ma3_rents - ///
    (t3_rents_l0 + t3_rents_l1 + t3_rents_l2)/3) <= 1e-10 ///
    if !missing(t2_ma3_rents, t3_rents_l0, t3_rents_l1, t3_rents_l2)
assert abs(t2_ma3_inst - ///
    (t3_inst_l0 + t3_inst_l1 + t3_inst_l2)/3) <= 1e-10 ///
    if !missing(t2_ma3_inst, t3_inst_l0, t3_inst_l1, t3_inst_l2)
assert abs(t2_ma3_rents_x_inst - ///
    (t3_rents_x_inst_l0 + t3_rents_x_inst_l1 + ///
        t3_rents_x_inst_l2)/3) <= 1e-10 ///
    if !missing(t2_ma3_rents_x_inst, ///
        t3_rents_x_inst_l0, t3_rents_x_inst_l1, ///
        t3_rents_x_inst_l2)

assert t4_rents_f1 == F1.rents ///
    if continuity_f1 == 1 & !missing(t4_rents_f1, F1.rents)
assert abs(t5_d_eci - (eci - L1.eci)) <= 1e-10 ///
    if !missing(t5_d_eci, eci, L1.eci)
assert abs(t5_d_divx - (divx - L1.divx)) <= 1e-10 ///
    if !missing(t5_d_divx, divx, L1.divx)

* Definir el inventario de muestras que debe coincidir con los reportes.
local report_models ///
    t0 t1 t2 t3 t3_expanded t4 t5 common_t0_t3

foreach outcome in eci divx {
    foreach model of local report_models {
        if "`model'" == "t3_expanded" {
            local sample_variable "sample_t3_expanded_`outcome'"
        }
        else if "`model'" == "common_t0_t3" {
            local sample_variable "sample_common_t0_t3_`outcome'"
        }
        else {
            local sample_variable "sample_`model'_`outcome'"
        }

        assert inlist(`sample_variable', 0, 1)
        quietly count if `sample_variable' == 1
        scalar actual_n_`outcome'_`model' = r(N)

        quietly levelsof country_id if `sample_variable' == 1, ///
            local(model_country_ids)
        local model_countries : word count `model_country_ids'
        scalar actual_g_`outcome'_`model' = `model_countries'

        quietly levelsof year if `sample_variable' == 1, ///
            local(model_year_values)
        local model_years : word count `model_year_values'
        scalar actual_t_`outcome'_`model' = `model_years'
    }
}

* Confirmar la relación predefinida entre T2, T3 ampliado y la muestra común.
foreach outcome in eci divx {
    assert sample_t2_`outcome' == sample_t3_expanded_`outcome'
    assert sample_t2_`outcome' <= sample_t3_`outcome'
    assert sample_common_t0_t3_`outcome' == sample_t2_`outcome'
}

* ECI y DIVX deben conservar coberturas idénticas en el panel vigente.
foreach model in t0 t1 t2 t3 t3_expanded t4 t5 {
    assert sample_`model'_eci == sample_`model'_divx
}
assert sample_common_t0_t3_eci == sample_common_t0_t3_divx

* Reabrir el resumen general y reconciliar cada observación, país y año.
preserve
    import delimited using "$TEMPORAL_SAMPLE_SUMMARY", ///
        clear varnames(1)
    isid outcome model
    assert _N == 16

    foreach outcome in eci divx {
        foreach model of local report_models {
            quietly count if outcome == "`outcome'" & model == "`model'"
            assert r(N) == 1
            quietly summarize observations ///
                if outcome == "`outcome'" & model == "`model'", meanonly
            assert r(min) == scalar(actual_n_`outcome'_`model')
            quietly summarize countries ///
                if outcome == "`outcome'" & model == "`model'", meanonly
            assert r(min) == scalar(actual_g_`outcome'_`model')
            quietly summarize calendar_years ///
                if outcome == "`outcome'" & model == "`model'", meanonly
            assert r(min) == scalar(actual_t_`outcome'_`model')
        }
    }
restore

* Verificar que las pérdidas se reconcilien con las muestras guardadas.
preserve
    import delimited using "$TEMPORAL_LOSS_SUMMARY", ///
        clear varnames(1)
    isid outcome model
    assert _N == 12
    assert boundary_loss + focal_missing_loss + ///
        outcome_missing_loss == total_excluded
    assert retained_observations + total_excluded == grid_observations

    foreach outcome in eci divx {
        foreach model in t0 t1 t2 t3 t4 t5 {
            quietly summarize retained_observations ///
                if outcome == "`outcome'" & model == "`model'", meanonly
            assert r(min) == scalar(actual_n_`outcome'_`model')
        }
    }
restore

* Reconciliar cobertura por país con los totales de cada muestra.
preserve
    import delimited using "$TEMPORAL_BY_COUNTRY", ///
        clear varnames(1)
    isid outcome model country_id
    assert _N == 880
    collapse (sum) sample_observations, by(outcome model)

    foreach outcome in eci divx {
        foreach model of local report_models {
            quietly summarize sample_observations ///
                if outcome == "`outcome'" & model == "`model'", meanonly
            assert r(min) == scalar(actual_n_`outcome'_`model')
        }
    }
restore

* Reconciliar cobertura por año con los mismos totales.
preserve
    import delimited using "$TEMPORAL_BY_YEAR", clear varnames(1)
    isid outcome model year
    assert _N == 416
    collapse (sum) observations, by(outcome model)

    foreach outcome in eci divx {
        foreach model of local report_models {
            quietly summarize observations ///
                if outcome == "`outcome'" & model == "`model'", meanonly
            assert r(min) == scalar(actual_n_`outcome'_`model')
        }
    }
restore

* Verificar que el diseño congelado contenga T0--T5 y T3X una sola vez.
preserve
    import delimited using "$TEMPORAL_SPECIFICATIONS", ///
        clear varnames(1)
    isid model
    assert _N == 7
    foreach registered_model in T0 T1 T2 T3 T3X T4 T5 {
        quietly count if model == "`registered_model'"
        assert r(N) == 1
    }
restore

* Aplicar mínimos de información antes de permitir diagnósticos o estimaciones.
foreach outcome in eci divx {
    foreach model in t0 t1 t2 t3 common_t0_t3 {
        assert scalar(actual_g_`outcome'_`model') >= 40
        assert scalar(actual_t_`outcome'_`model') >= 10
    }
}

* Mostrar la cobertura que alimentará los diagnósticos y modelos posteriores.
foreach outcome in eci divx {
    foreach model in t0 t1 t2 t3 common_t0_t3 {
        local ready_n = scalar(actual_n_`outcome'_`model')
        local ready_g = scalar(actual_g_`outcome'_`model')
        local ready_t = scalar(actual_t_`outcome'_`model')
        display as result ///
            "Listo `outcome' `model': N=`ready_n'; países=`ready_g'; " ///
            "años efectivos=`ready_t'"
    }
}

display as result "Secciones 7 y 8 completadas sin errores."
display as result ///
    "Panel temporal, muestras y reportes reconciliados completamente."
display as result "Siguiente bloque pendiente: sección 9."
display as result "TEMPORAL_02_SECTIONS_7_8_OK"


// *****************************************************************************
// 9. Diagnósticos previos de los rezagos distribuidos
// *****************************************************************************

// 9.1. Correlaciones temporales

* Las correlaciones usan únicamente las observaciones completas de T3.
* Así se comparan los tres valores de RENTS sobre una misma muestra.

display as text "9. Diagnósticos previos de los rezagos distribuidos"

* Congelar los umbrales antes de calcular cualquier diagnóstico.
scalar VIF_THRESHOLD = 10
scalar CORRELATION_ALERT_THRESHOLD = 0.90

* Crear un reporte conjunto para correlaciones, VIF y decisión sobre T3X.
tempname temporal_diagnostic_post
tempfile temporal_diagnostic_report

postfile `temporal_diagnostic_post' ///
    int order str20 diagnostic str24 specification str32 variable ///
    str32 comparison double value threshold ///
    str32 assessment int observations countries ///
    using "`temporal_diagnostic_report'", replace

* Calcular una única matriz sobre la muestra efectiva completa de T3.
quietly correlate ///
    t3_rents_l0 t3_rents_l1 t3_rents_l2 ///
    if sample_t3_eci == 1
matrix T3_RENTS_CORRELATION = r(C)

local diagnostic_order = 0
local correlation_pairs ///
    "1 2 t3_rents_l0 t3_rents_l1" ///
    "1 3 t3_rents_l0 t3_rents_l2" ///
    "2 3 t3_rents_l1 t3_rents_l2"

* Postear manualmente los tres pares para conservar nombres transparentes.
local ++diagnostic_order
local corr_l0_l1 = T3_RENTS_CORRELATION[1,2]
local corr_assessment = cond(abs(`corr_l0_l1') >= ///
    scalar(CORRELATION_ALERT_THRESHOLD), "Alerta alta", "Aceptable")
post `temporal_diagnostic_post' ///
    (`diagnostic_order') ("correlation") ("T3 básico") ///
    ("t3_rents_l0") ("t3_rents_l1") (`corr_l0_l1') ///
    (scalar(CORRELATION_ALERT_THRESHOLD)) ("`corr_assessment'") ///
    (scalar(actual_n_eci_t3)) (scalar(actual_g_eci_t3))

local ++diagnostic_order
local corr_l0_l2 = T3_RENTS_CORRELATION[1,3]
local corr_assessment = cond(abs(`corr_l0_l2') >= ///
    scalar(CORRELATION_ALERT_THRESHOLD), "Alerta alta", "Aceptable")
post `temporal_diagnostic_post' ///
    (`diagnostic_order') ("correlation") ("T3 básico") ///
    ("t3_rents_l0") ("t3_rents_l2") (`corr_l0_l2') ///
    (scalar(CORRELATION_ALERT_THRESHOLD)) ("`corr_assessment'") ///
    (scalar(actual_n_eci_t3)) (scalar(actual_g_eci_t3))

local ++diagnostic_order
local corr_l1_l2 = T3_RENTS_CORRELATION[2,3]
local corr_assessment = cond(abs(`corr_l1_l2') >= ///
    scalar(CORRELATION_ALERT_THRESHOLD), "Alerta alta", "Aceptable")
post `temporal_diagnostic_post' ///
    (`diagnostic_order') ("correlation") ("T3 básico") ///
    ("t3_rents_l1") ("t3_rents_l2") (`corr_l1_l2') ///
    (scalar(CORRELATION_ALERT_THRESHOLD)) ("`corr_assessment'") ///
    (scalar(actual_n_eci_t3)) (scalar(actual_g_eci_t3))


// 9.2. Inflación de varianza y condición informativa

* La colinealidad indica si los efectos rezagados pueden separarse.
* Si no pueden separarse, solo se interpreta la suma de los efectos de RENTS.
* Las interacciones rezagadas no se interpretan cuando incumplen este criterio.

* Calcular VIF auxiliares de T3 básico condicionando por efectos de país y año.
local t3_base_variables ///
    t3_rents_l0 t3_rents_l1 t3_rents_l2 t3_inst_l0

scalar T3_BASE_MAX_VIF = 0
foreach target_variable of local t3_base_variables {
    local current_target "`target_variable'"
    local other_variables : ///
        list t3_base_variables - current_target

    quietly regress `target_variable' `other_variables' ///
        i.country_id i.year if sample_t3_eci == 1
    local auxiliary_r2 = e(r2)
    local temporal_vif = 1/(1 - `auxiliary_r2')
    if `temporal_vif' > scalar(T3_BASE_MAX_VIF) {
        scalar T3_BASE_MAX_VIF = `temporal_vif'
    }

    local vif_assessment = cond(`temporal_vif' > scalar(VIF_THRESHOLD), ///
        "Supera umbral", "Aceptable")
    local ++diagnostic_order
    post `temporal_diagnostic_post' ///
        (`diagnostic_order') ("vif") ("T3 básico") ///
        ("`target_variable'") ("Otros términos y FE") ///
        (`temporal_vif') (scalar(VIF_THRESHOLD)) ///
        ("`vif_assessment'") ///
        (scalar(actual_n_eci_t3)) (scalar(actual_g_eci_t3))
}

* Congelar la regla de interpretación de los coeficientes individuales de T3.
scalar T3_BASE_VIF_PASS = ///
    scalar(T3_BASE_MAX_VIF) <= scalar(VIF_THRESHOLD)
local t3_base_decision = cond(scalar(T3_BASE_VIF_PASS) == 1, ///
    "Interpretación individual", "Solo suma y prueba conjunta")
local ++diagnostic_order
post `temporal_diagnostic_post' ///
    (`diagnostic_order') ("decision") ("T3 básico") ///
    ("max_vif") ("Regla ex ante") (scalar(T3_BASE_MAX_VIF)) ///
    (scalar(VIF_THRESHOLD)) ("`t3_base_decision'") ///
    (scalar(actual_n_eci_t3)) (scalar(actual_g_eci_t3))

* Evaluar por separado los nueve términos de la expansión distribuida T3X.
local t3_expanded_variables ///
    t3_rents_l0 t3_rents_l1 t3_rents_l2 ///
    t3_inst_l0 t3_inst_l1 t3_inst_l2 ///
    t3_rents_x_inst_l0 t3_rents_x_inst_l1 t3_rents_x_inst_l2

scalar T3X_MAX_VIF = 0
scalar T3X_VIF_VALID = 1

foreach target_variable of local t3_expanded_variables {
    local current_target "`target_variable'"
    local other_variables : ///
        list t3_expanded_variables - current_target

    capture quietly regress `target_variable' `other_variables' ///
        i.country_id i.year if sample_t3_expanded_eci == 1

    if _rc | e(r2) >= 0.999999999 {
        local temporal_vif = .
        local vif_assessment "No identificable"
        scalar T3X_VIF_VALID = 0
    }
    else {
        local auxiliary_r2 = e(r2)
        local temporal_vif = 1/(1 - `auxiliary_r2')
        local vif_assessment = cond(`temporal_vif' > ///
            scalar(VIF_THRESHOLD), "Supera umbral", "Aceptable")
        if `temporal_vif' > scalar(T3X_MAX_VIF) {
            scalar T3X_MAX_VIF = `temporal_vif'
        }
    }

    local ++diagnostic_order
    post `temporal_diagnostic_post' ///
        (`diagnostic_order') ("vif") ("T3X ampliado") ///
        ("`target_variable'") ("Otros términos y FE") ///
        (`temporal_vif') (scalar(VIF_THRESHOLD)) ///
        ("`vif_assessment'") ///
        (scalar(actual_n_eci_t3_expanded)) ///
        (scalar(actual_g_eci_t3_expanded))
}

* T3X solo se habilita si todos sus VIF pueden calcularse.
* El mayor VIF tampoco puede superar el límite predefinido de 10.
scalar T3X_VIF_PASS = ///
    scalar(T3X_VIF_VALID) == 1 & ///
    scalar(T3X_MAX_VIF) <= scalar(VIF_THRESHOLD)

local t3x_decision = cond(scalar(T3X_VIF_PASS) == 1, ///
    "Habilitada", "No habilitada")
local ++diagnostic_order
post `temporal_diagnostic_post' ///
    (`diagnostic_order') ("decision") ("T3X ampliado") ///
    ("max_vif") ("Regla ex ante") (scalar(T3X_MAX_VIF)) ///
    (scalar(VIF_THRESHOLD)) ("`t3x_decision'") ///
    (scalar(actual_n_eci_t3_expanded)) ///
    (scalar(actual_g_eci_t3_expanded))

postclose `temporal_diagnostic_post'

preserve
    use "`temporal_diagnostic_report'", clear
    isid order
    assert _N == 18
    sort order
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/lag_correlation_and_vif.csv", ///
        replace datafmt
restore

display as result ///
    "Correlaciones RENTS: L0-L1=`corr_l0_l1'; " ///
    "L0-L2=`corr_l0_l2'; L1-L2=`corr_l1_l2'."
display as result "VIF máximo T3 básico: " scalar(T3_BASE_MAX_VIF)
display as result "Decisión T3 básico:   `t3_base_decision'"
display as result "VIF máximo T3X:       " scalar(T3X_MAX_VIF)
display as result "Decisión T3X:         `t3x_decision'"
display as result "Sección 9 completada sin errores."


// *****************************************************************************
// 10. Secuencia temporal para ECI
// *****************************************************************************

// 10.1. T0 — referencia contemporánea

* T0 relaciona ECI con RENTS, INST y su interacción del mismo año.
* Los efectos fijos controlan diferencias de país y choques comunes de año.
* Esta estimación funciona como referencia interna del módulo.

display as text "10. Secuencia temporal para ECI"

* Estimar T0 en su muestra propia con interacción contemporánea factorial.
quietly xtreg eci c.t0_rents##c.t0_inst i.year ///
    if sample_t0_eci == 1, fe vce(cluster country_id)
estimates store ECI_T0_OWN

tempvar used_t0_own
generate byte `used_t0_own' = e(sample)
assert `used_t0_own' == sample_t0_eci
assert e(N) == scalar(actual_n_eci_t0)
assert e(N_g) == scalar(actual_g_eci_t0)
assert _se[t0_rents] > 0 & _se[t0_rents] < .
assert _se[t0_inst] > 0 & _se[t0_inst] < .
assert _se[c.t0_rents#c.t0_inst] > 0 & ///
    _se[c.t0_rents#c.t0_inst] < .

scalar ECI_T0_OWN_B_RENTS = _b[t0_rents]
scalar ECI_T0_OWN_B_INST = _b[t0_inst]
scalar ECI_T0_OWN_B_INTERACTION = _b[c.t0_rents#c.t0_inst]


// 10.2. T1 — exposición rezagada un año

* T1 usa información del año anterior y establece precedencia temporal.
* Solo pierde el primer año disponible de cada trayectoria nacional.

* Estimar T1 con los tres términos pertenecientes al mismo año t-1.
quietly xtreg eci c.t1_rents##c.t1_inst i.year ///
    if sample_t1_eci == 1, fe vce(cluster country_id)
estimates store ECI_T1_OWN

tempvar used_t1_own
generate byte `used_t1_own' = e(sample)
assert `used_t1_own' == sample_t1_eci
assert e(N) == scalar(actual_n_eci_t1)
assert e(N_g) == scalar(actual_g_eci_t1)
assert _se[t1_rents] > 0 & _se[t1_rents] < .
assert _se[t1_inst] > 0 & _se[t1_inst] < .
assert _se[c.t1_rents#c.t1_inst] > 0 & ///
    _se[c.t1_rents#c.t1_inst] < .

scalar ECI_T1_OWN_B_RENTS = _b[t1_rents]
scalar ECI_T1_OWN_B_INST = _b[t1_inst]
scalar ECI_T1_OWN_B_INTERACTION = _b[c.t1_rents#c.t1_inst]


// 10.3. T2 — exposición acumulada reciente

* T2 utiliza los promedios retrospectivos construidos en el archivo 01.
* El modelo no recalcula promedios ni admite ventanas incompletas.

* La interacción T2 es la media de los productos calculados cada año.
* El producto de las medias representa una variable diferente y no se utiliza.
quietly xtreg eci ///
    t2_ma3_rents t2_ma3_inst t2_ma3_rents_x_inst i.year ///
    if sample_t2_eci == 1, fe vce(cluster country_id)
estimates store ECI_T2_OWN

tempvar used_t2_own
generate byte `used_t2_own' = e(sample)
assert `used_t2_own' == sample_t2_eci
assert e(N) == scalar(actual_n_eci_t2)
assert e(N_g) == scalar(actual_g_eci_t2)
assert _se[t2_ma3_rents] > 0 & _se[t2_ma3_rents] < .
assert _se[t2_ma3_inst] > 0 & _se[t2_ma3_inst] < .
assert _se[t2_ma3_rents_x_inst] > 0 & ///
    _se[t2_ma3_rents_x_inst] < .

scalar ECI_T2_OWN_B_RENTS = _b[t2_ma3_rents]
scalar ECI_T2_OWN_B_INST = _b[t2_ma3_inst]
scalar ECI_T2_OWN_B_INTERACTION = _b[t2_ma3_rents_x_inst]


// 10.4. T3 — rezagos distribuidos 0--2

* T3 conserva los coeficientes de cada año para calcular el efecto acumulado.
* Su interpretación depende de la suma, la prueba conjunta y la colinealidad.

* Estimar la versión básica predefinida de T3.
quietly xtreg eci ///
    t3_rents_l0 t3_rents_l1 t3_rents_l2 t3_inst_l0 i.year ///
    if sample_t3_eci == 1, fe vce(cluster country_id)
estimates store ECI_T3_OWN

tempvar used_t3_own
generate byte `used_t3_own' = e(sample)
assert `used_t3_own' == sample_t3_eci
assert e(N) == scalar(actual_n_eci_t3)
assert e(N_g) == scalar(actual_g_eci_t3)
foreach term in t3_rents_l0 t3_rents_l1 t3_rents_l2 t3_inst_l0 {
    assert _se[`term'] > 0 & _se[`term'] < .
}

scalar ECI_T3_OWN_B_L0 = _b[t3_rents_l0]
scalar ECI_T3_OWN_B_L1 = _b[t3_rents_l1]
scalar ECI_T3_OWN_B_L2 = _b[t3_rents_l2]
scalar ECI_T3_OWN_B_INST = _b[t3_inst_l0]
scalar ECI_T3_INDIVIDUAL_INTERPRETATION = scalar(T3_BASE_VIF_PASS)

* Estimar T3X solo cuando la regla VIF de la sección 9 lo habilite.
scalar ECI_T3X_ESTIMATED = 0
if scalar(T3X_VIF_PASS) == 1 {
    quietly xtreg eci `t3_expanded_variables' i.year ///
        if sample_t3_expanded_eci == 1, ///
        fe vce(cluster country_id)
    estimates store ECI_T3X_OWN
    assert e(N) == scalar(actual_n_eci_t3_expanded)
    assert e(N_g) == scalar(actual_g_eci_t3_expanded)
    scalar ECI_T3X_ESTIMATED = 1
}


// 10.5. Comparabilidad de muestras

* Cada modelo se estima con su muestra propia y con una muestra común.
* Esto separa el cambio temporal del cambio en la composición de la muestra.

* T0 sobre la intersección común T0--T3.
quietly xtreg eci c.t0_rents##c.t0_inst i.year ///
    if sample_common_t0_t3_eci == 1, fe vce(cluster country_id)
estimates store ECI_T0_COMMON
assert e(N) == scalar(actual_n_eci_common_t0_t3)
assert e(N_g) == scalar(actual_g_eci_common_t0_t3)
scalar ECI_T0_COMMON_B_RENTS = _b[t0_rents]

* T1 sobre la misma intersección.
quietly xtreg eci c.t1_rents##c.t1_inst i.year ///
    if sample_common_t0_t3_eci == 1, fe vce(cluster country_id)
estimates store ECI_T1_COMMON
assert e(N) == scalar(actual_n_eci_common_t0_t3)
assert e(N_g) == scalar(actual_g_eci_common_t0_t3)
scalar ECI_T1_COMMON_B_RENTS = _b[t1_rents]

* Estimar T2 sobre la intersección, igual a su muestra propia actual.
quietly xtreg eci ///
    t2_ma3_rents t2_ma3_inst t2_ma3_rents_x_inst i.year ///
    if sample_common_t0_t3_eci == 1, fe vce(cluster country_id)
estimates store ECI_T2_COMMON
assert e(N) == scalar(actual_n_eci_common_t0_t3)
assert e(N_g) == scalar(actual_g_eci_common_t0_t3)
scalar ECI_T2_COMMON_B_RENTS = _b[t2_ma3_rents]

* T3 básico sobre la misma intersección.
quietly xtreg eci ///
    t3_rents_l0 t3_rents_l1 t3_rents_l2 t3_inst_l0 i.year ///
    if sample_common_t0_t3_eci == 1, fe vce(cluster country_id)
estimates store ECI_T3_COMMON
assert e(N) == scalar(actual_n_eci_common_t0_t3)
assert e(N_g) == scalar(actual_g_eci_common_t0_t3)
scalar ECI_T3_COMMON_B_L0 = _b[t3_rents_l0]
scalar ECI_T3_COMMON_B_L1 = _b[t3_rents_l1]
scalar ECI_T3_COMMON_B_L2 = _b[t3_rents_l2]

* Confirmar que T2 propia y común son idénticas por definición de muestra.
assert abs(scalar(ECI_T2_OWN_B_RENTS) - ///
    scalar(ECI_T2_COMMON_B_RENTS)) <= 1e-12

* Conservar los modelos ECI que utilizarán las secciones 12 y 13.
estimates dir

display as result ///
    "ECI T0 propia: b(RENTS)=" scalar(ECI_T0_OWN_B_RENTS)
display as result ///
    "ECI T1 propia: b(RENTS t-1)=" scalar(ECI_T1_OWN_B_RENTS)
display as result ///
    "ECI T2 propia: b(media RENTS)=" scalar(ECI_T2_OWN_B_RENTS)
display as result ///
    "ECI T3 propia (solo diagnóstico): b(L0)=" ///
    scalar(ECI_T3_OWN_B_L0) ///
    "; b(L1)=" scalar(ECI_T3_OWN_B_L1) ///
    "; b(L2)=" scalar(ECI_T3_OWN_B_L2)
display as result "Uso permitido de T3: `t3_base_decision'"
display as result "Sección 10 completada sin errores."
display as result "Siguiente bloque pendiente: sección 11."
display as result "TEMPORAL_02_SECTIONS_9_10_OK"


// *****************************************************************************
// 11. Secuencia temporal para DIVX
// *****************************************************************************

// 11.1. T0 — referencia contemporánea

quietly xtreg divx c.t0_rents##c.t0_inst i.year ///
    if sample_t0_divx == 1, fe vce(cluster country_id)
estimates store DIVX_T0_OWN

assert e(N) == scalar(actual_n_divx_t0)
assert e(N_g) == scalar(actual_g_divx_t0)
assert e(df_r) == e(N_clust) - 1

scalar DIVX_T0_OWN_B_RENTS = _b[t0_rents]
scalar DIVX_T0_OWN_B_INST = _b[t0_inst]
scalar DIVX_T0_OWN_B_INTERACTION = _b[c.t0_rents#c.t0_inst]

foreach term in t0_rents t0_inst c.t0_rents#c.t0_inst {
    assert !missing(_b[`term'])
    assert !missing(_se[`term'])
    assert _se[`term'] > 0
}

* DIVX conserva la definición empleada por el módulo principal.
* HHI no puede ser un control porque DIVX se calcula como uno menos HHI.


// 11.2. T1 — exposición rezagada un año

* Estimar DIVX con los términos focales observados un año antes.

quietly xtreg divx c.t1_rents##c.t1_inst i.year ///
    if sample_t1_divx == 1, fe vce(cluster country_id)
estimates store DIVX_T1_OWN

assert e(N) == scalar(actual_n_divx_t1)
assert e(N_g) == scalar(actual_g_divx_t1)
assert e(df_r) == e(N_clust) - 1

scalar DIVX_T1_OWN_B_RENTS = _b[t1_rents]
scalar DIVX_T1_OWN_B_INST = _b[t1_inst]
scalar DIVX_T1_OWN_B_INTERACTION = _b[c.t1_rents#c.t1_inst]

foreach term in t1_rents t1_inst c.t1_rents#c.t1_inst {
    assert !missing(_b[`term'])
    assert !missing(_se[`term'])
    assert _se[`term'] > 0
}


// 11.3. T2 — exposición acumulada reciente

* Estimar DIVX con promedios retrospectivos de tres años completos.

quietly xtreg divx t2_ma3_rents t2_ma3_inst t2_ma3_rents_x_inst i.year ///
    if sample_t2_divx == 1, fe vce(cluster country_id)
estimates store DIVX_T2_OWN

assert e(N) == scalar(actual_n_divx_t2)
assert e(N_g) == scalar(actual_g_divx_t2)
assert e(df_r) == e(N_clust) - 1

scalar DIVX_T2_OWN_B_RENTS = _b[t2_ma3_rents]
scalar DIVX_T2_OWN_B_INST = _b[t2_ma3_inst]
scalar DIVX_T2_OWN_B_INTERACTION = _b[t2_ma3_rents_x_inst]

foreach term in t2_ma3_rents t2_ma3_inst t2_ma3_rents_x_inst {
    assert !missing(_b[`term'])
    assert !missing(_se[`term'])
    assert _se[`term'] > 0
}


// 11.4. T3 — rezagos distribuidos 0--2

* Distribuir la relación de RENTS entre el año actual y dos rezagos.

quietly xtreg divx t3_rents_l0 t3_rents_l1 t3_rents_l2 ///
    t3_inst_l0 i.year if sample_t3_divx == 1, ///
    fe vce(cluster country_id)
estimates store DIVX_T3_OWN

assert e(N) == scalar(actual_n_divx_t3)
assert e(N_g) == scalar(actual_g_divx_t3)
assert e(df_r) == e(N_clust) - 1

scalar DIVX_T3_OWN_B_L0 = _b[t3_rents_l0]
scalar DIVX_T3_OWN_B_L1 = _b[t3_rents_l1]
scalar DIVX_T3_OWN_B_L2 = _b[t3_rents_l2]
scalar DIVX_T3_OWN_B_INST = _b[t3_inst_l0]
scalar DIVX_T3_INDIV_INTERPRETATION = scalar(T3_BASE_VIF_PASS)

foreach term in t3_rents_l0 t3_rents_l1 t3_rents_l2 t3_inst_l0 {
    assert !missing(_b[`term'])
    assert !missing(_se[`term'])
    assert _se[`term'] > 0
}

* La versión expandida T3X solo se estima si superó el umbral predefinido.
scalar DIVX_T3X_ESTIMATED = 0
if scalar(T3X_VIF_PASS) == 1 {
    quietly xtreg divx `t3_expanded_variables' i.year ///
        if sample_t3_expanded_divx == 1, fe vce(cluster country_id)
    estimates store DIVX_T3X_OWN
    assert e(N) == scalar(actual_n_divx_t3_expanded)
    assert e(N_g) == scalar(actual_g_divx_t3_expanded)
    scalar DIVX_T3X_ESTIMATED = 1
}
else {
    display as text "T3X DIVX no se estima: `t3x_decision'"
}


// 11.5. Comparabilidad de muestras

* Repetir T0--T3 sobre una muestra común para comparar horizontes.

quietly xtreg divx c.t0_rents##c.t0_inst i.year ///
    if sample_common_t0_t3_divx == 1, fe vce(cluster country_id)
estimates store DIVX_T0_COMMON
assert e(N) == scalar(actual_n_divx_common_t0_t3)
assert e(N_g) == scalar(actual_g_divx_common_t0_t3)
scalar DIVX_T0_COMMON_B_RENTS = _b[t0_rents]

quietly xtreg divx c.t1_rents##c.t1_inst i.year ///
    if sample_common_t0_t3_divx == 1, fe vce(cluster country_id)
estimates store DIVX_T1_COMMON
assert e(N) == scalar(actual_n_divx_common_t0_t3)
assert e(N_g) == scalar(actual_g_divx_common_t0_t3)
scalar DIVX_T1_COMMON_B_RENTS = _b[t1_rents]

quietly xtreg divx t2_ma3_rents t2_ma3_inst t2_ma3_rents_x_inst i.year ///
    if sample_common_t0_t3_divx == 1, fe vce(cluster country_id)
estimates store DIVX_T2_COMMON
assert e(N) == scalar(actual_n_divx_common_t0_t3)
assert e(N_g) == scalar(actual_g_divx_common_t0_t3)
scalar DIVX_T2_COMMON_B_RENTS = _b[t2_ma3_rents]

quietly xtreg divx t3_rents_l0 t3_rents_l1 t3_rents_l2 ///
    t3_inst_l0 i.year if sample_common_t0_t3_divx == 1, ///
    fe vce(cluster country_id)
estimates store DIVX_T3_COMMON
assert e(N) == scalar(actual_n_divx_common_t0_t3)
assert e(N_g) == scalar(actual_g_divx_common_t0_t3)
scalar DIVX_T3_COMMON_B_L0 = _b[t3_rents_l0]
scalar DIVX_T3_COMMON_B_L1 = _b[t3_rents_l1]
scalar DIVX_T3_COMMON_B_L2 = _b[t3_rents_l2]

* T2 propia y común coinciden porque ambas banderas definen la misma muestra.
assert abs(scalar(DIVX_T2_OWN_B_RENTS) - ///
    scalar(DIVX_T2_COMMON_B_RENTS)) <= 1e-12

* Las tablas de ECI y DIVX deben conservar la misma estructura de columnas.
* Esto facilita comparar muestras, signos, escalas e incertidumbre.

estimates dir
display as result ///
    "DIVX T0 propia: b(RENTS)=" scalar(DIVX_T0_OWN_B_RENTS)
display as result ///
    "DIVX T1 propia: b(RENTS t-1)=" scalar(DIVX_T1_OWN_B_RENTS)
display as result ///
    "DIVX T2 propia: b(media RENTS)=" scalar(DIVX_T2_OWN_B_RENTS)
display as result ///
    "DIVX T3 propia (solo diagnóstico): b(L0)=" ///
    scalar(DIVX_T3_OWN_B_L0) ///
    "; b(L1)=" scalar(DIVX_T3_OWN_B_L1) ///
    "; b(L2)=" scalar(DIVX_T3_OWN_B_L2)
display as result "Uso permitido de T3: `t3_base_decision'"
display as result "Sección 11 completada sin errores."


// *****************************************************************************
// 12. Efectos acumulados, pruebas e inferencia
// *****************************************************************************

// 12.1. Suma de rezagos

* Calcular el efecto acumulado sumando los tres coeficientes de RENTS.

tempname cumulative_handle
tempfile cumulative_results

postfile `cumulative_handle' ///
    int order str8 outcome str8 sample_type str20 model ///
    str12 test_type str100 null_hypothesis ///
    double estimate standard_error t_statistic f_statistic ///
    df1 df2 p_value ci_lower ci_upper observations countries ///
    str60 interpretation ///
    using `cumulative_results', replace

local cumulative_order = 0

foreach outcome in eci divx {
    local outcome_upper = upper("`outcome'")

    foreach sample_type in own common {
        local sample_upper = upper("`sample_type'")
        local estimate_name "`outcome_upper'_T3_`sample_upper'"

        quietly estimates restore `estimate_name'
        local model_n = e(N)
        local model_g = e(N_g)

        quietly lincom t3_rents_l0 + t3_rents_l1 + t3_rents_l2
        local sum_estimate = r(estimate)
        local sum_se = r(se)
        local sum_t = r(t)
        local sum_df = r(df)
        local sum_p = r(p)
        local sum_lb = r(lb)
        local sum_ub = r(ub)

        assert abs(`sum_estimate' - ///
            (_b[t3_rents_l0] + _b[t3_rents_l1] + ///
            _b[t3_rents_l2])) <= 1e-12
        assert `sum_se' > 0
        assert inrange(`sum_p', 0, 1)
        assert `sum_lb' < `sum_ub'

        scalar T3_SUM_`outcome'_`sample_type' = `sum_estimate'
        scalar T3_SUM_P_`outcome'_`sample_type' = `sum_p'

        local ++cumulative_order
        post `cumulative_handle' (`cumulative_order') ///
            ("`outcome_upper'") ("`sample_type'") ("`estimate_name'") ///
            ("sum") ("b(L0) + b(L1) + b(L2) = 0") ///
            (`sum_estimate') (`sum_se') (`sum_t') (.) ///
            (1) (`sum_df') (`sum_p') (`sum_lb') (`sum_ub') ///
            (`model_n') (`model_g') ///
            ("Interpretar suma; no rezagos individuales")

        * La prueba conjunta se ejecuta inmediatamente sobre el mismo modelo.
        quietly test t3_rents_l0 t3_rents_l1 t3_rents_l2
        local joint_f = r(F)
        local joint_df1 = r(df)
        local joint_df2 = r(df_r)
        local joint_p = r(p)

        assert `joint_df1' == 3
        assert `joint_df2' == `model_g' - 1
        assert inrange(`joint_p', 0, 1)

        scalar T3_JOINT_P_`outcome'_`sample_type' = `joint_p'

        local ++cumulative_order
        post `cumulative_handle' (`cumulative_order') ///
            ("`outcome_upper'") ("`sample_type'") ("`estimate_name'") ///
            ("joint") ("b(L0) = b(L1) = b(L2) = 0") ///
            (.) (.) (.) (`joint_f') ///
            (`joint_df1') (`joint_df2') (`joint_p') (.) (.) ///
            (`model_n') (`model_g') ///
            ("Prueba conjunta; no rezagos individuales")
    }
}

postclose `cumulative_handle'

preserve
    use `cumulative_results', clear
    sort order
    assert _N == 8
    isid outcome sample_type test_type
    assert inlist(outcome, "ECI", "DIVX")
    assert inlist(sample_type, "own", "common")
    assert inlist(test_type, "sum", "joint")
    assert observations > 0 & countries > 0
    export delimited using ///
        "$OUTPUT_CUMULATIVE/cumulative_effect_tests.csv", replace
restore

* La suma usa la matriz completa para calcular error e intervalo de confianza.


// 12.2. Pruebas conjuntas

* Cada prueba conjunta se calcula sobre el mismo modelo utilizado por la suma.
* Esto impide cambiar accidentalmente el resultado o la muestra.
assert scalar(T3_JOINT_P_eci_own) >= 0 & ///
    scalar(T3_JOINT_P_eci_own) <= 1
assert scalar(T3_JOINT_P_divx_own) >= 0 & ///
    scalar(T3_JOINT_P_divx_own) <= 1
assert scalar(T3_JOINT_P_eci_common) >= 0 & ///
    scalar(T3_JOINT_P_eci_common) <= 1
assert scalar(T3_JOINT_P_divx_common) >= 0 & ///
    scalar(T3_JOINT_P_divx_common) <= 1

* La prueba de suma evalúa si el efecto acumulado es igual a cero.
* La prueba conjunta evalúa si los tres coeficientes son iguales a cero.


// 12.3. Inferencia agrupada y wild bootstrap

* La inferencia convencional permite dependencia dentro de cada país.
* El bootstrap se aplica a términos focales de T1, T2 y a la suma de T3.
* Cada contraste conserva la muestra propia del horizonte correspondiente.

* boottest calcula valores p robustos ante el número limitado de países.
capture which boottest
if _rc {
    display as error ///
        "No se encontró boottest; no puede completarse la sección 12.3."
    exit 499
}

mata: mata mlib index

capture drop t3_rents_mean_for_sum t3_rents_d1_for_sum ///
    t3_rents_d2_for_sum
generate double t3_rents_mean_for_sum = ///
    (t3_rents_l0 + t3_rents_l1 + t3_rents_l2) / 3 ///
    if !missing(t3_rents_l0, t3_rents_l1, t3_rents_l2)
generate double t3_rents_d1_for_sum = t3_rents_l1 - t3_rents_l0 ///
    if !missing(t3_rents_l0, t3_rents_l1)
generate double t3_rents_d2_for_sum = t3_rents_l2 - t3_rents_l0 ///
    if !missing(t3_rents_l0, t3_rents_l2)

label variable t3_rents_mean_for_sum ///
    "Media L0-L2; coeficiente equivale a suma de rezagos"
label variable t3_rents_d1_for_sum "Diferencia RENTS L1-L0"
label variable t3_rents_d2_for_sum "Diferencia RENTS L2-L0"

tempname bootstrap_handle bootstrap_ci
tempfile bootstrap_results

postfile `bootstrap_handle' ///
    int order str8 outcome str8 sample_type str12 model ///
    str40 term str60 hypothesis ///
    double coefficient conventional_p bootstrap_p ///
    ci_lower ci_upper observations countries repetitions ///
    long seed ///
    str20 weight_type ///
    using `bootstrap_results', replace

local bootstrap_order = 0
local bootstrap_repetitions = 9999

foreach outcome in eci divx {
    local outcome_upper = upper("`outcome'")

    foreach horizon in t1 t2 {
        local horizon_upper = upper("`horizon'")
        local estimate_name "`outcome_upper'_`horizon_upper'_OWN"
        quietly estimates restore `estimate_name'

        if "`horizon'" == "t1" {
            local focal_terms ///
                "t1_rents c.t1_rents#c.t1_inst"
        }
        else {
            local focal_terms ///
                "t2_ma3_rents t2_ma3_rents_x_inst"
        }

        foreach term of local focal_terms {
            local coefficient = _b[`term']
            local conventional_p = 2 * ttail(e(df_r), ///
                abs(_b[`term'] / _se[`term']))
            local model_n = e(N)
            local model_g = e(N_g)
            local bootstrap_seed = 2608000 + `bootstrap_order' + 1

            quietly boottest `term', cluster(country_id) ///
                reps(`bootstrap_repetitions') ///
                seed(`bootstrap_seed') nograph

            matrix `bootstrap_ci' = r(CI)
            local bootstrap_p = r(p)
            local bootstrap_reps = r(reps)
            local bootstrap_weight "`r(weighttype)'"
            local bootstrap_lb = `bootstrap_ci'[1, 1]
            local bootstrap_ub = `bootstrap_ci'[1, 2]

            assert inrange(`conventional_p', 0, 1)
            assert inrange(`bootstrap_p', 0, 1)
            assert `bootstrap_reps' == `bootstrap_repetitions'
            assert `bootstrap_lb' < `bootstrap_ub'

            local ++bootstrap_order
            post `bootstrap_handle' (`bootstrap_order') ///
                ("`outcome_upper'") ("own") ("`horizon_upper'") ///
                ("`term'") ("`term' = 0") ///
                (`coefficient') (`conventional_p') (`bootstrap_p') ///
                (`bootstrap_lb') (`bootstrap_ub') ///
                (`model_n') (`model_g') (`bootstrap_reps') ///
                (`bootstrap_seed') ("`bootstrap_weight'")
        }
    }

    * La media reparametrizada permite contrastar directamente la suma de T3.
    quietly xtreg `outcome' t3_rents_mean_for_sum ///
        t3_rents_d1_for_sum t3_rents_d2_for_sum t3_inst_l0 i.year ///
        if sample_t3_`outcome' == 1, fe vce(cluster country_id)

    assert e(N) == scalar(actual_n_`outcome'_t3)
    assert e(N_g) == scalar(actual_g_`outcome'_t3)
    assert abs(_b[t3_rents_mean_for_sum] - ///
        scalar(T3_SUM_`outcome'_own)) <= 1e-10

    local coefficient = _b[t3_rents_mean_for_sum]
    local conventional_p = 2 * ttail(e(df_r), ///
        abs(_b[t3_rents_mean_for_sum] / ///
        _se[t3_rents_mean_for_sum]))
    local model_n = e(N)
    local model_g = e(N_g)
    local bootstrap_seed = 2608000 + `bootstrap_order' + 1

    quietly boottest t3_rents_mean_for_sum, cluster(country_id) ///
        reps(`bootstrap_repetitions') seed(`bootstrap_seed') nograph

    matrix `bootstrap_ci' = r(CI)
    local bootstrap_p = r(p)
    local bootstrap_reps = r(reps)
    local bootstrap_weight "`r(weighttype)'"
    local bootstrap_lb = `bootstrap_ci'[1, 1]
    local bootstrap_ub = `bootstrap_ci'[1, 2]

    assert abs(`conventional_p' - ///
        scalar(T3_SUM_P_`outcome'_own)) <= 1e-10
    assert inrange(`bootstrap_p', 0, 1)
    assert `bootstrap_reps' == `bootstrap_repetitions'
    assert `bootstrap_lb' < `bootstrap_ub'

    local ++bootstrap_order
    post `bootstrap_handle' (`bootstrap_order') ///
        ("`outcome_upper'") ("own") ("T3") ///
        ("sum_rents_l0_l2") ("b(L0)+b(L1)+b(L2) = 0") ///
        (`coefficient') (`conventional_p') (`bootstrap_p') ///
        (`bootstrap_lb') (`bootstrap_ub') ///
        (`model_n') (`model_g') (`bootstrap_reps') ///
        (`bootstrap_seed') ("`bootstrap_weight'")
}

postclose `bootstrap_handle'

preserve
    use `bootstrap_results', clear
    sort order
    assert _N == 10
    isid outcome model term
    isid seed
    assert sample_type == "own"
    assert observations > 0 & countries > 0
    assert repetitions == `bootstrap_repetitions'
    assert seed == 2608000 + order
    assert inrange(conventional_p, 0, 1)
    assert inrange(bootstrap_p, 0, 1)
    export delimited using ///
        "$OUTPUT_CUMULATIVE/temporal_wild_cluster_bootstrap.csv", replace
restore

* Documentar el número de países y las repeticiones de cada bootstrap.
* Presentar sus valores p junto con la inferencia agrupada convencional.
* Estos resultados no modifican la regla previa de selección de modelos.

display as result ///
    "ECI T3 suma propia: " scalar(T3_SUM_eci_own) ///
    "; p agrupado=" scalar(T3_SUM_P_eci_own) ///
    "; p conjunta=" scalar(T3_JOINT_P_eci_own)
display as result ///
    "DIVX T3 suma propia: " scalar(T3_SUM_divx_own) ///
    "; p agrupado=" scalar(T3_SUM_P_divx_own) ///
    "; p conjunta=" scalar(T3_JOINT_P_divx_own)
display as result ///
    "Wild cluster bootstrap: 10 contrastes, 9,999 repeticiones cada uno."
display as result "Sección 12 completada sin errores."
display as result "Continuación automática: sección 13."
display as result "TEMPORAL_02_SECTIONS_11_12_OK"


// *****************************************************************************
// 13. Exportación, validación y traspaso al archivo 03
// *****************************************************************************

display as text "13. Exportación, validación y traspaso al archivo 03"

capture mkdir "$OUTPUT_FINAL"


// 13.1. Exportar coeficientes focales de ECI y DIVX

* Reunir los coeficientes comparables de ambos resultados en una tabla.

tempname coefficients_handle
tempfile coefficients_results

postfile `coefficients_handle' ///
    int order str8 outcome str20 model str4 horizon str8 sample_type ///
    str40 term str24 term_role ///
    double coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper observations countries clusters ///
    effective_years first_year last_year ///
    byte country_fe year_fe clustered_by_country ///
    str60 interpretation ///
    using `coefficients_results', replace

local coefficient_order = 0

foreach outcome in eci divx {
    local outcome_upper = upper("`outcome'")

    foreach horizon in t0 t1 t2 t3 {
        local horizon_upper = upper("`horizon'")

        if "`horizon'" == "t0" {
            local model_terms ///
                "t0_rents t0_inst c.t0_rents#c.t0_inst"
        }
        else if "`horizon'" == "t1" {
            local model_terms ///
                "t1_rents t1_inst c.t1_rents#c.t1_inst"
        }
        else if "`horizon'" == "t2" {
            local model_terms ///
                "t2_ma3_rents t2_ma3_inst t2_ma3_rents_x_inst"
        }
        else {
            local model_terms ///
                "t3_rents_l0 t3_rents_l1 t3_rents_l2 t3_inst_l0"
        }

        foreach sample_type in own common {
            local sample_upper = upper("`sample_type'")
            local estimate_name ///
                "`outcome_upper'_`horizon_upper'_`sample_upper'"

            if "`sample_type'" == "own" {
                local sample_key "`horizon'"
                local sample_variable "sample_`horizon'_`outcome'"
            }
            else {
                local sample_key "common_t0_t3"
                local sample_variable ///
                    "sample_common_t0_t3_`outcome'"
            }

            quietly estimates restore `estimate_name'

            assert e(N) == scalar(actual_n_`outcome'_`sample_key')
            assert e(N_g) == scalar(actual_g_`outcome'_`sample_key')
            assert e(N_clust) == e(N_g)
            assert e(df_r) == e(N_clust) - 1

            local model_n = e(N)
            local model_g = e(N_g)
            local model_clusters = e(N_clust)
            local model_t = scalar(actual_t_`outcome'_`sample_key')

            quietly summarize year if `sample_variable' == 1, meanonly
            local model_first_year = r(min)
            local model_last_year = r(max)
            assert r(N) == `model_n'

            quietly levelsof year if `sample_variable' == 1, ///
                local(model_year_values_export)
            local counted_model_years : word count ///
                `model_year_values_export'
            assert `model_t' == `counted_model_years'

            foreach term of local model_terms {
                local term_role ""

                if inlist("`term'", "t0_rents", "t1_rents", ///
                    "t2_ma3_rents") {
                    local term_role "rents"
                }
                else if inlist("`term'", "t0_inst", "t1_inst", ///
                    "t2_ma3_inst", "t3_inst_l0") {
                    local term_role "institutions"
                }
                else if inlist("`term'", ///
                    "c.t0_rents#c.t0_inst", ///
                    "c.t1_rents#c.t1_inst", ///
                    "t2_ma3_rents_x_inst") {
                    local term_role "interaction"
                }
                else if "`term'" == "t3_rents_l0" {
                    local term_role "rents_lag_0"
                }
                else if "`term'" == "t3_rents_l1" {
                    local term_role "rents_lag_1"
                }
                else if "`term'" == "t3_rents_l2" {
                    local term_role "rents_lag_2"
                }

                assert "`term_role'" != ""
                assert !missing(_b[`term'])
                assert !missing(_se[`term']) & _se[`term'] > 0

                local coefficient = _b[`term']
                local standard_error = _se[`term']
                local t_statistic = `coefficient' / `standard_error'
                local p_value = 2 * ttail(e(df_r), abs(`t_statistic'))
                local critical_t = invttail(e(df_r), 0.025)
                local ci_lower = `coefficient' - ///
                    `critical_t' * `standard_error'
                local ci_upper = `coefficient' + ///
                    `critical_t' * `standard_error'

                assert inrange(`p_value', 0, 1)
                assert `ci_lower' < `ci_upper'

                local interpretation = cond("`horizon'" == "t3", ///
                    "No individual; usar suma y prueba conjunta", ///
                    "Coeficiente focal del horizonte")

                local ++coefficient_order
                post `coefficients_handle' (`coefficient_order') ///
                    ("`outcome_upper'") ("`estimate_name'") ///
                    ("`horizon_upper'") ("`sample_type'") ///
                    ("`term'") ("`term_role'") ///
                    (`coefficient') (`standard_error') ///
                    (`t_statistic') (`p_value') ///
                    (`ci_lower') (`ci_upper') ///
                    (`model_n') (`model_g') (`model_clusters') ///
                    (`model_t') (`model_first_year') (`model_last_year') ///
                    (1) (1) (1) ("`interpretation'")
            }
        }
    }
}

postclose `coefficients_handle'

preserve
    use `coefficients_results', clear
    sort order

    assert _N == 52
    isid outcome model term
    assert countries == clusters
    assert country_fe == 1 & year_fe == 1
    assert clustered_by_country == 1
    assert inlist(outcome, "ECI", "DIVX")
    assert inlist(horizon, "T0", "T1", "T2", "T3")
    assert inlist(sample_type, "own", "common")
    assert inrange(p_value, 0, 1)
    assert ci_lower < ci_upper

    bysort outcome: assert _N == 26
    bysort outcome horizon sample_type: assert _N == ///
        cond(horizon == "T3", 4, 3)

    export delimited using ///
        "$OUTPUT_FINAL/temporal_model_coefficients.csv", replace
restore

preserve
    use `coefficients_results', clear
    keep if outcome == "ECI"
    assert _N == 26
    export delimited using ///
        "$OUTPUT_ECI/eci_temporal_coefficients.csv", replace
restore

preserve
    use `coefficients_results', clear
    keep if outcome == "DIVX"
    assert _N == 26
    export delimited using ///
        "$OUTPUT_DIVX/divx_temporal_coefficients.csv", replace
restore


// 13.2. Reconciliar pruebas acumuladas, bootstrap y diagnósticos

* Reabrir los resultados previos y comprobar que coincidan con las estimaciones.

local required_inference_outputs ///
    02_diagnostics/lag_correlation_and_vif.csv ///
    05_cumulative/cumulative_effect_tests.csv ///
    05_cumulative/temporal_wild_cluster_bootstrap.csv

foreach relative_output of local required_inference_outputs {
    capture confirm file "$OUTPUT_ROOT/`relative_output'"
    if _rc {
        display as error "Falta un output obligatorio de inferencia:"
        display as error "$OUTPUT_ROOT/`relative_output'"
        exit 601
    }
}

preserve
    import delimited using ///
        "$OUTPUT_DIAGNOSTICS/lag_correlation_and_vif.csv", ///
        clear varnames(1)
    assert _N == 18
    isid order
    quietly count if diagnostic == "decision"
    assert r(N) == 2
    quietly count if diagnostic == "decision" & ///
        assessment == "No habilitada"
    assert r(N) == 1
    quietly count if diagnostic == "decision" & ///
        assessment == "Solo suma y prueba conjunta"
    assert r(N) == 1
restore

preserve
    import delimited using ///
        "$OUTPUT_CUMULATIVE/cumulative_effect_tests.csv", ///
        clear varnames(1)
    assert _N == 8
    isid outcome sample_type test_type
    assert inrange(p_value, 0, 1)

    quietly summarize estimate if outcome == "ECI" & ///
        sample_type == "own" & test_type == "sum", meanonly
    assert r(N) == 1
    assert abs(r(mean) - scalar(T3_SUM_eci_own)) <= 1e-12

    quietly summarize estimate if outcome == "DIVX" & ///
        sample_type == "own" & test_type == "sum", meanonly
    assert r(N) == 1
    assert abs(r(mean) - scalar(T3_SUM_divx_own)) <= 1e-12

    quietly summarize p_value if outcome == "ECI" & ///
        sample_type == "own" & test_type == "joint", meanonly
    assert r(N) == 1
    assert abs(r(mean) - scalar(T3_JOINT_P_eci_own)) <= 1e-7

    quietly summarize p_value if outcome == "DIVX" & ///
        sample_type == "own" & test_type == "joint", meanonly
    assert r(N) == 1
    assert abs(r(mean) - scalar(T3_JOINT_P_divx_own)) <= 1e-7
restore

preserve
    import delimited using ///
        "$OUTPUT_CUMULATIVE/temporal_wild_cluster_bootstrap.csv", ///
        clear varnames(1)
    assert _N == 10
    isid outcome model term
    assert sample_type == "own"
    assert repetitions == 9999
    assert countries == 53
    isid seed
    assert seed == 2608000 + order
    assert inrange(conventional_p, 0, 1)
    assert inrange(bootstrap_p, 0, 1)
    assert ci_lower < ci_upper
restore


// 13.3. Guardar estimaciones y construir el traspaso al archivo 03

* Guardar los modelos T1 y T2 que el archivo 03 necesita volver a utilizar.

foreach outcome in eci divx {
    local outcome_upper = upper("`outcome'")
    local outcome_directory = cond("`outcome'" == "eci", ///
        "$OUTPUT_ECI", "$OUTPUT_DIVX")

    foreach horizon in t1 t2 {
        local horizon_upper = upper("`horizon'")
        local estimate_name ///
            "`outcome_upper'_`horizon_upper'_OWN"

        quietly estimates restore `estimate_name'
        estimates save ///
            "`outcome_directory'/`outcome'_`horizon'_own.ster", replace

        capture confirm file ///
            "`outcome_directory'/`outcome'_`horizon'_own.ster"
        assert _rc == 0
    }
}

preserve
    import delimited using ///
        "$OUTPUT_CUMULATIVE/temporal_wild_cluster_bootstrap.csv", ///
        clear varnames(1)
    keep if inlist(model, "T1", "T2")
    assert _N == 8
    isid outcome model term

    generate str20 estimate_name = outcome + "_" + model + "_OWN"
    generate str100 ster_relative_path = ""
    replace ster_relative_path = ///
        "03_eci/eci_" + lower(model) + "_own.ster" ///
        if outcome == "ECI"
    replace ster_relative_path = ///
        "04_divx/divx_" + lower(model) + "_own.ster" ///
        if outcome == "DIVX"
    generate byte ready_for_file03 = 1
    generate str60 handoff_role = ///
        "Referencia temporal para placebo y sensibilidad"

    assert ster_relative_path != ""
    assert ready_for_file03 == 1
    isid seed
    assert seed == 2608000 + order
    sort outcome model term
    order outcome model term estimate_name ster_relative_path ///
        coefficient conventional_p bootstrap_p observations countries ///
        repetitions ready_for_file03 handoff_role

    export delimited using ///
        "$OUTPUT_FINAL/02_models_handoff.csv", replace
restore


// 13.4. Crear manifiesto y ejecutar controles finales de aceptación

* Crear un inventario que confirme la existencia de cada producto obligatorio.

tempname manifest_handle
tempfile manifest_results

postfile `manifest_handle' ///
    int order str20 stage str18 artifact_type ///
    str100 relative_path double expected_rows ///
    str80 role str12 status ///
    using `manifest_results', replace

post `manifest_handle' (1) ("diagnostics") ("csv") ///
    ("02_diagnostics/lag_correlation_and_vif.csv") (18) ///
    ("Diagnóstico ex ante de T3 y T3X") ("validated")
post `manifest_handle' (2) ("coefficients") ("csv") ///
    ("03_eci/eci_temporal_coefficients.csv") (26) ///
    ("Coeficientes temporales de ECI") ("validated")
post `manifest_handle' (3) ("coefficients") ("csv") ///
    ("04_divx/divx_temporal_coefficients.csv") (26) ///
    ("Coeficientes temporales de DIVX") ("validated")
post `manifest_handle' (4) ("inference") ("csv") ///
    ("05_cumulative/cumulative_effect_tests.csv") (8) ///
    ("Sumas y pruebas conjuntas de T3") ("validated")
post `manifest_handle' (5) ("inference") ("csv") ///
    ("05_cumulative/temporal_wild_cluster_bootstrap.csv") (10) ///
    ("Bootstrap focal de T1, T2 y suma T3") ("validated")
post `manifest_handle' (6) ("final") ("csv") ///
    ("09_final/temporal_model_coefficients.csv") (52) ///
    ("Tabla combinada de coeficientes") ("validated")
post `manifest_handle' (7) ("handoff") ("csv") ///
    ("09_final/02_models_handoff.csv") (8) ///
    ("Índice de traspaso al archivo 03") ("validated")
post `manifest_handle' (8) ("handoff") ("ster") ///
    ("03_eci/eci_t1_own.ster") (.) ///
    ("Estimación ECI T1 para archivo 03") ("validated")
post `manifest_handle' (9) ("handoff") ("ster") ///
    ("03_eci/eci_t2_own.ster") (.) ///
    ("Estimación ECI T2 para archivo 03") ("validated")
post `manifest_handle' (10) ("handoff") ("ster") ///
    ("04_divx/divx_t1_own.ster") (.) ///
    ("Estimación DIVX T1 para archivo 03") ("validated")
post `manifest_handle' (11) ("handoff") ("ster") ///
    ("04_divx/divx_t2_own.ster") (.) ///
    ("Estimación DIVX T2 para archivo 03") ("validated")

postclose `manifest_handle'

preserve
    use `manifest_results', clear
    assert _N == 11
    isid order
    assert status == "validated"

    forvalues row = 1/`=_N' {
        local artifact_path = relative_path[`row']
        capture confirm file "$OUTPUT_ROOT/`artifact_path'"
        assert _rc == 0
    }

    export delimited using ///
        "$OUTPUT_FINAL/02_results_manifest.csv", replace
restore

local required_final_outputs ///
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

foreach relative_output of local required_final_outputs {
    capture confirm file "$OUTPUT_ROOT/`relative_output'"
    if _rc {
        display as error "Falta un producto final obligatorio:"
        display as error "$OUTPUT_ROOT/`relative_output'"
        exit 601
    }
}

* Cada tabla identifica modelo, muestra, término, incertidumbre y cobertura.

* El cierre exige que T0--T3 coincidan con sus muestras guardadas.
* También exige sumas reproducibles y decisiones T3 basadas en diagnósticos.

display as result ///
    "Coeficientes exportados: 52 filas (26 ECI y 26 DIVX)."
display as result ///
    "Traspaso al archivo 03: 8 contrastes y 4 estimaciones .ster."
display as result ///
    "Manifiesto validado: 11 productos obligatorios del archivo 02."
display as result ///
    "Archivo temporal 02 finalizado: modelos T0--T3 e inferencia validados."
display as result "TEMPORAL_02_SECTION_13_OK"

log close temporal_models_log
