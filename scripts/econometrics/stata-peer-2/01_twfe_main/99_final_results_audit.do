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
// Archivo: 99_final_results_audit.do (Versión Codex - Peer-2)
// Contenido: Auditoría y Reconciliación de Entregables Finales
// Propósito: Verificar que todos los archivos de salida (CSV, JSON, gráficos de márgenes,
//            modelos .ster y resúmenes) hayan sido generados correctamente sin errores.
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************

// =============================================================================
// PROPÓSITO DEL ARCHIVO DE AUDITORÍA:
// - Este script no estima modelos econométricos ni altera la base de datos.
// - Realiza una inspección automatizada de integridad sobre la carpeta outputs/
//   comprobando que la muestra congelada (N=1044, G=49), los coeficientes y las marcas
//   de significancia estén 100% disponibles y reconciliados para la redacción de la tesis.
// =============================================================================

version 17.0
clear all
set more off
set varabbrev off
capture log close _all

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
    if !_rc global PROJECT_ROOT "`project_windows'"
}
if "$PROJECT_ROOT" == "" & "`project_manual'" != "" {
    capture confirm file "`project_manual'/`project_marker'"
    if !_rc global PROJECT_ROOT "`project_manual'"
}
if "$PROJECT_ROOT" == "" {
    display as error "No se pudo localizar la raíz del repositorio."
    exit 601
}

global OUTPUT_ROOT ///
    "$PROJECT_ROOT/outputs/econometrics/stata-peer-2/01_twfe_main"
global OUTPUT_ECI "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX "$OUTPUT_ROOT/04_divx"
global OUTPUT_STABILITY "$OUTPUT_ROOT/05_stability"
global OUTPUT_FINAL "$OUTPUT_ROOT/06_final"
global OUTPUT_DIAGNOSTICS "$OUTPUT_ROOT/02_diagnostics"
global OUTPUT_VALIDATION ///
    "$OUTPUT_ROOT/14_panel_specification_validation"
global OUTPUT_VALIDATION_SAMPLE "$OUTPUT_VALIDATION/01_sample"
global OUTPUT_VALIDATION_SELECTION ///
    "$OUTPUT_VALIDATION/02_estimator_selection"
global OUTPUT_VALIDATION_EFFECTS ///
    "$OUTPUT_VALIDATION/03_fixed_effects_tests"
global OUTPUT_VALIDATION_MUNDLAK "$OUTPUT_VALIDATION/04_mundlak_cre"
global OUTPUT_VALIDATION_STATIONARITY ///
    "$OUTPUT_VALIDATION/05_stationarity"
global OUTPUT_VALIDATION_DIFFERENCES ///
    "$OUTPUT_VALIDATION/06_first_differences"
global OUTPUT_VALIDATION_DYNAMIC ///
    "$OUTPUT_VALIDATION/07_dynamic_sensitivity"
global OUTPUT_VALIDATION_INFERENCE ///
    "$OUTPUT_VALIDATION/08_inference_sensitivity"
global OUTPUT_VALIDATION_FINAL "$OUTPUT_VALIDATION/09_final"
global OUTPUT_AUDIT_LOGS "$OUTPUT_ROOT/logs"

capture mkdir "$OUTPUT_AUDIT_LOGS"
log using "$OUTPUT_AUDIT_LOGS/99_final_results_audit.log", ///
    text replace name(final_audit_log)

foreach required_file in ///
    "$OUTPUT_ECI/eci_twfe_coefficients.csv" ///
    "$OUTPUT_DIVX/divx_twfe_coefficients.csv" ///
    "$OUTPUT_ECI/eci_twfe_model_summary.csv" ///
    "$OUTPUT_DIVX/divx_twfe_model_summary.csv" ///
    "$OUTPUT_STABILITY/wild_cluster_bootstrap.csv" ///
    "$OUTPUT_FINAL/final_model_coefficients.csv" ///
    "$OUTPUT_FINAL/final_model_summaries.csv" ///
    "$OUTPUT_FINAL/final_wild_cluster_bootstrap.csv" ///
    "$OUTPUT_DIAGNOSTICS/panel_error_tests.csv" ///
    "$OUTPUT_VALIDATION_FINAL/all_substantive_coefficients.csv" ///
    "$OUTPUT_VALIDATION_FINAL/specification_register.csv" ///
    "$OUTPUT_VALIDATION_FINAL/panel_specification_decision.csv" ///
    "$OUTPUT_VALIDATION_FINAL/panel_specification_results_manifest.csv" {
    capture confirm file "`required_file'"
    assert _rc == 0
}

tempname audit_post
tempfile audit_data final_data source_data
postfile `audit_post' str40 audit_item byte passed str244 note ///
    using "`audit_data'", replace

* 1. Coeficientes finales: deben reproducir exactamente las salidas ECI y DIVX.
import delimited using "$OUTPUT_FINAL/final_model_coefficients.csv", ///
    clear varnames(1)
keep model term coefficient standard_error t_statistic p_value ci_lower ci_upper
isid model term
foreach metric in coefficient standard_error t_statistic p_value ci_lower ci_upper {
    rename `metric' `metric'_final
}
save "`final_data'", replace

clear
tempfile eci_coefficients divx_coefficients
import delimited using "$OUTPUT_ECI/eci_twfe_coefficients.csv", ///
    clear varnames(1)
generate str4 model = "ECI"
save "`eci_coefficients'", replace
import delimited using "$OUTPUT_DIVX/divx_twfe_coefficients.csv", ///
    clear varnames(1)
generate str4 model = "DIVX"
append using "`eci_coefficients'"
keep model term coefficient standard_error t_statistic p_value ci_lower ci_upper
isid model term
foreach metric in coefficient standard_error t_statistic p_value ci_lower ci_upper {
    rename `metric' `metric'_source
}
merge 1:1 model term using "`final_data'"
assert _merge == 3
foreach metric in coefficient standard_error t_statistic p_value ci_lower ci_upper {
    assert abs(`metric'_source - `metric'_final) < 1e-12
}
assert _N == 33
post `audit_post' ("FINAL_COEFFICIENTS") (1) ///
    ("33 coeficientes finales coinciden con sus fuentes ECI y DIVX.")

* 2. Resúmenes: misma muestra, cobertura y medidas de ajuste del modelo fuente.
import delimited using "$OUTPUT_FINAL/final_model_summaries.csv", ///
    clear varnames(1)
keep model observations countries clusters years first_year last_year ///
    r2_within r2_between r2_overall f_statistic df_model df_error ///
    model_p_value rmse sigma_country sigma_idiosyncratic rho_country
isid model
foreach metric in observations countries clusters years first_year last_year ///
    r2_within r2_between r2_overall f_statistic df_model df_error ///
    model_p_value rmse sigma_country sigma_idiosyncratic rho_country {
    rename `metric' `metric'_final
}
save "`final_data'", replace

import delimited using "$OUTPUT_ECI/eci_twfe_model_summary.csv", ///
    clear varnames(1)
save "`eci_coefficients'", replace
import delimited using "$OUTPUT_DIVX/divx_twfe_model_summary.csv", ///
    clear varnames(1)
append using "`eci_coefficients'"
keep model observations countries clusters years first_year last_year ///
    r2_within r2_between r2_overall f_statistic df_model df_error ///
    model_p_value rmse sigma_country sigma_idiosyncratic rho_country
isid model
foreach metric in observations countries clusters years first_year last_year ///
    r2_within r2_between r2_overall f_statistic df_model df_error ///
    model_p_value rmse sigma_country sigma_idiosyncratic rho_country {
    rename `metric' `metric'_source
}
merge 1:1 model using "`final_data'"
assert _merge == 3
foreach metric in observations countries clusters years first_year last_year ///
    r2_within r2_between r2_overall f_statistic df_model df_error ///
    model_p_value rmse sigma_country sigma_idiosyncratic rho_country {
    assert abs(`metric'_source - `metric'_final) < 1e-12
}
assert observations_source == 1044
assert countries_source == 49
assert clusters_source == 49
post `audit_post' ("FINAL_MODEL_SUMMARIES") (1) ///
    ("Dos resúmenes finales conservan 1.044 observaciones y 49 países.")

* 3. La sensibilidad bootstrap copiada al paquete final debe ser idéntica.
import delimited using "$OUTPUT_FINAL/final_wild_cluster_bootstrap.csv", ///
    clear varnames(1)
keep model term coefficient conventional_p bootstrap_p ci_lower ci_upper ///
    statistic_type statistic_value numerator_df denominator_df repetitions ///
    seed observations countries weight_type significance_selected hierarchy
isid model term
foreach metric in coefficient conventional_p bootstrap_p ci_lower ci_upper ///
    statistic_value numerator_df denominator_df repetitions seed observations ///
    countries significance_selected {
    rename `metric' `metric'_final
}
foreach text_metric in statistic_type weight_type hierarchy {
    rename `text_metric' `text_metric'_final
}
save "`final_data'", replace

import delimited using "$OUTPUT_STABILITY/wild_cluster_bootstrap.csv", ///
    clear varnames(1)
keep model term coefficient conventional_p bootstrap_p ci_lower ci_upper ///
    statistic_type statistic_value numerator_df denominator_df repetitions ///
    seed observations countries weight_type significance_selected hierarchy
isid model term
foreach metric in coefficient conventional_p bootstrap_p ci_lower ci_upper ///
    statistic_value numerator_df denominator_df repetitions seed observations ///
    countries significance_selected {
    rename `metric' `metric'_source
}
foreach text_metric in statistic_type weight_type hierarchy {
    rename `text_metric' `text_metric'_source
}
merge 1:1 model term using "`final_data'"
assert _merge == 3
foreach metric in coefficient conventional_p bootstrap_p ci_lower ci_upper ///
    statistic_value numerator_df denominator_df repetitions seed observations ///
    countries significance_selected {
    assert abs(`metric'_source - `metric'_final) < 1e-12
}
foreach text_metric in statistic_type weight_type hierarchy {
    assert `text_metric'_source == `text_metric'_final
}
assert _N == 6
post `audit_post' ("FINAL_WILD_BOOTSTRAP") (1) ///
    ("Seis contrastes bootstrap finales coinciden con el archivo de estabilidad.")

* 4. La inferencia conserva la regla aprobada: CD no activa DK automáticamente.
import delimited using "$OUTPUT_DIAGNOSTICS/panel_error_tests.csv", ///
    clear varnames(1)
isid model test
quietly count if test == "Pesaran CD" & decision == "DO NOT REJECT H0"
assert r(N) == 2
quietly count if test == "Wooldridge AR(1)" & decision == "REJECT H0"
assert r(N) == 2
quietly count if test == "Modified Wald" & decision == "REJECT H0"
assert r(N) == 2
post `audit_post' ("INFERENCE_DECISION") (1) ///
    ("Cluster y wild se mantienen; DK queda como sensibilidad secundaria.")

* 5. El manifiesto declara 34 modelos, 17 CSV y verifica cada ruta y fila.
tempfile validation_manifest
import delimited using ///
    "$OUTPUT_VALIDATION_FINAL/panel_specification_results_manifest.csv", ///
    clear varnames(1)
assert _N == 51
isid artifact_order
isid relative_path
quietly count if artifact_type == "STER"
assert r(N) == 34
quietly count if artifact_type == "CSV"
assert r(N) == 17
save "`validation_manifest'", replace

forvalues validation_audit_row = 1/51 {
    use "`validation_manifest'", clear
    local validation_audit_path = ///
        relative_path[`validation_audit_row']
    local validation_audit_type = ///
        artifact_type[`validation_audit_row']
    local validation_audit_rows = ///
        expected_rows[`validation_audit_row']

    capture confirm file ///
        "$OUTPUT_VALIDATION/`validation_audit_path'"
    assert _rc == 0

    if "`validation_audit_type'" == "CSV" {
        import delimited using ///
            "$OUTPUT_VALIDATION/`validation_audit_path'", ///
            clear varnames(1)
        quietly count
        assert r(N) == `validation_audit_rows'
    }
}
post `audit_post' ("VALIDATION_MANIFEST") (1) ///
    ("51 productos existen; 34 modelos y 17 CSV cumplen el contrato.")

* 6. El registro conserva diez especificaciones por resultado y sus muestras.
import delimited using ///
    "$OUTPUT_VALIDATION_FINAL/specification_register.csv", ///
    clear varnames(1)
assert _N == 20
isid outcome model_code
bysort outcome: assert _N == 10
assert observations == 1044 if inlist(model_code, ///
    "pooled", "pooled_year_fe", "country_fe", "twfe_main", ///
    "re_year_fe", "mundlak_cre")
assert observations == 869 if inlist(model_code, ///
    "matched_sample_twfe", "first_difference_year_fe", ///
    "matched_static_twfe", "dynamic_fe_lag1")
assert countries == 49
post `audit_post' ("VALIDATION_SPECIFICATIONS") (1) ///
    ("20 modelos: diez por resultado, con muestras 1.044 o 869 documentadas.")

* 7. El registro integral reproduce los 33 coeficientes TWFE finales.
import delimited using ///
    "$OUTPUT_VALIDATION_FINAL/all_substantive_coefficients.csv", ///
    clear varnames(1)
assert _N == 332
isid outcome model_code term
assert !missing(coefficient, standard_error, p_value)
keep if model_code == "twfe_main"
assert _N == 33
rename outcome model
keep model term coefficient standard_error test_statistic p_value ///
    ci_lower ci_upper
rename test_statistic t_statistic
foreach metric in coefficient standard_error t_statistic p_value ///
        ci_lower ci_upper {
    rename `metric' `metric'_validation
}
save "`source_data'", replace

import delimited using "$OUTPUT_FINAL/final_model_coefficients.csv", ///
    clear varnames(1)
keep model term coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper
foreach metric in coefficient standard_error t_statistic p_value ///
        ci_lower ci_upper {
    rename `metric' `metric'_final
}
merge 1:1 model term using "`source_data'"
assert _merge == 3
foreach metric in coefficient standard_error t_statistic p_value ///
        ci_lower ci_upper {
    assert abs(`metric'_validation - `metric'_final) < 1e-6
}
post `audit_post' ("VALIDATION_COEFFICIENTS") (1) ///
    ("332 coeficientes completos; los 33 TWFE reproducen el paquete final.")

* 8. Las sensibilidades conservan sus muestras y reglas preespecificadas.
import delimited using ///
    "$OUTPUT_VALIDATION_STATIONARITY/stationarity_decision_matrix.csv", ///
    clear varnames(1)
assert _N == 36
assert model_change_authorized == 0

import delimited using ///
    "$OUTPUT_VALIDATION_DIFFERENCES/matched_sample_first_differences.csv", ///
    clear varnames(1)
assert _N == 4
assert analysis_observations == 869

import delimited using ///
    "$OUTPUT_VALIDATION_DYNAMIC/dynamic_sensitivity.csv", ///
    clear varnames(1)
assert _N == 4
assert analysis_observations == 869
assert lag_p_value < 0.05 if lagged_dependent == 1
post `audit_post' ("VALIDATION_TRANSFORMATIONS") (1) ///
    ("Estacionariedad, primeras diferencias y dinámica conservan su jerarquía.")

* 9. La inferencia completa cubre controles y reserva wild para términos focales.
import delimited using ///
    "$OUTPUT_VALIDATION_INFERENCE/inference_sensitivity.csv", ///
    clear varnames(1)
assert _N == 72
isid outcome inference_method term
quietly count if inference_method == "country_cluster"
assert r(N) == 33
quietly count if inference_method == "driscoll_kraay"
assert r(N) == 33
quietly count if inference_method == "wild_cluster_bootstrap"
assert r(N) == 6
assert observations == 1044

import delimited using ///
    "$OUTPUT_VALIDATION_INFERENCE/inference_joint_tests.csv", ///
    clear varnames(1)
assert _N == 6
isid outcome inference_method
post `audit_post' ("VALIDATION_INFERENCE") (1) ///
    ("72 coeficientes inferenciales y seis pruebas conjuntas están completos.")

* 10. La matriz final conserva las decisiones econométricas aprobadas.
import delimited using ///
    "$OUTPUT_VALIDATION_FINAL/panel_specification_decision.csv", ///
    clear varnames(1)
assert _N == 13
isid decision_id
assert decision == "KEEP_LEVELS_TWFE_AS_MAIN" if decision_id == "D05"
assert decision == "KEEP_COUNTRY_CLUSTER" if decision_id == "D09"
assert decision == "KEEP_DK_AS_SECONDARY_ONLY" if decision_id == "D11"
assert decision == "RETAIN_CONDITIONAL_ASSOCIATIONS" if decision_id == "D13"
assert hierarchy != ""
post `audit_post' ("VALIDATION_DECISIONS") (1) ///
    ("13 decisiones preservan TWFE, cluster principal y alcance no causal.")

postclose `audit_post'
use "`audit_data'", clear
isid audit_item
assert _N == 10
assert passed == 1
export delimited using "$OUTPUT_FINAL/final_results_audit.csv", ///
    replace datafmt
display as result "Auditoría final completada: 10 reconciliaciones aprobadas."
log close final_audit_log
