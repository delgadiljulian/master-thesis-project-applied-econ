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

foreach required_file in ///
    "$OUTPUT_ECI/eci_twfe_coefficients.csv" ///
    "$OUTPUT_DIVX/divx_twfe_coefficients.csv" ///
    "$OUTPUT_ECI/eci_twfe_model_summary.csv" ///
    "$OUTPUT_DIVX/divx_twfe_model_summary.csv" ///
    "$OUTPUT_STABILITY/wild_cluster_bootstrap.csv" ///
    "$OUTPUT_FINAL/final_model_coefficients.csv" ///
    "$OUTPUT_FINAL/final_model_summaries.csv" ///
    "$OUTPUT_FINAL/final_wild_cluster_bootstrap.csv" ///
    "$OUTPUT_DIAGNOSTICS/panel_error_tests.csv" {
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
generate str4 model_key = "ECI"
rename model source_model
rename model_key model
save "`eci_coefficients'", replace
import delimited using "$OUTPUT_DIVX/divx_twfe_model_summary.csv", ///
    clear varnames(1)
generate str4 model_key = "DIVX"
rename model source_model
rename model_key model
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
    ("Cluster por país y wild bootstrap se mantienen; Pesaran CD no activa DK.")

postclose `audit_post'
use "`audit_data'", clear
isid audit_item
assert _N == 4
assert passed == 1
export delimited using "$OUTPUT_FINAL/final_results_audit.csv", ///
    replace datafmt
display as result "Auditoría final completada: 4 reconciliaciones aprobadas."
