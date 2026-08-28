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
// Archivo: 09_panel_specification_validation.do (Versión Codex - Peer-2)
// Contenido: Validación de la selección del estimador, tratamiento temporal e
//            inferencia complementaria del modelo completo M3.
// Propósito: Responder de manera reproducible a la revisión econométrica del
//            director antes de actualizar el TFM y solicitar el concepto
//            integral del profesor Julio Fabris.
// Requisito operativo: Ejecutar previamente 01_data_preparation_diagnostics.do
//                      y 04_twfe_full.do.
// Estado: Bloques 1 a 8 implementados y auditados.
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************


// =============================================================================
// GUÍA RÁPIDA DEL ARCHIVO 09
// =============================================================================
//
// Pregunta central:
// ¿El TWFE en niveles continúa siendo la especificación principal más
// defendible cuando se documentan de manera explícita la selección entre
// pooled, FE y RE, la persistencia temporal, una sensibilidad dinámica acotada
// y métodos alternativos de inferencia?
//
// Principios obligatorios:
// 1. M3 agregado sigue siendo el modelo sustantivo de referencia.
// 2. Todas las comparaciones utilizan la muestra congelada de 1.044
//    observaciones y 49 países, salvo pérdida mecánica documentada por rezagos
//    o primeras diferencias.
// 3. ECI es el resultado principal y DIVX el resultado complementario.
// 4. HHI nunca entra en la ecuación DIVX porque DIVX = 1 - HHI.
// 5. Los efectos de año se conservan en las comparaciones que requieran una
//    especificación temporal común.
// 6. La significancia no selecciona estimadores, controles, transformaciones
//    ni rezagos.
// 7. Los resultados se interpretan como asociaciones condicionales, no como
//    efectos causales.
// 8. GMM e IV/2SLS no se reactivan sin una identificación y unos instrumentos
//    defendibles.
// 9. Las salidas nuevas permanecen aisladas y no sobrescriben productos de los
//    archivos 01 a 08.
// =============================================================================


// *****************************************************************************
// 0. INICIALIZACIÓN Y LOCALIZACIÓN DEL PROYECTO
// *****************************************************************************

version 17.0
clear all
cls
macro drop _all
capture log close _all

set more off
set varabbrev off
set type double
set linesize 255
set seed 20260827
set sortseed 20260827


// 0.1. Localizar la raíz del repositorio

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
    display as error "Edite local project_manual en la inicialización."
    exit 601
}

quietly cd "$PROJECT_ROOT"
display as result "Raíz del proyecto localizada correctamente:"
pwd


// 0.2. Cargar las rutinas compartidas de validación

do "scripts/econometrics/stata-peer-2/01_twfe_main/00_validation_helpers.do"


// 0.3. Definir entradas y salidas exclusivas del archivo 09

global OUTPUT_ROOT ///
    "$PROJECT_ROOT/outputs/econometrics/stata-peer-2/01_twfe_main"
global OUTPUT_SAMPLE "$OUTPUT_ROOT/01_sample"
global OUTPUT_DIAGNOSTICS "$OUTPUT_ROOT/02_diagnostics"
global OUTPUT_ECI "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX "$OUTPUT_ROOT/04_divx"
global OUTPUT_VALIDATION ///
    "$OUTPUT_ROOT/14_panel_specification_validation"
global OUTPUT_VALIDATION_DESIGN "$OUTPUT_VALIDATION/00_design"
global OUTPUT_VALIDATION_SAMPLE "$OUTPUT_VALIDATION/01_sample"
global OUTPUT_VALIDATION_SELECTION "$OUTPUT_VALIDATION/02_estimator_selection"
global OUTPUT_VALIDATION_EFFECTS "$OUTPUT_VALIDATION/03_fixed_effects_tests"
global OUTPUT_VALIDATION_MUNDLAK "$OUTPUT_VALIDATION/04_mundlak_cre"
global OUTPUT_VALIDATION_STATIONARITY "$OUTPUT_VALIDATION/05_stationarity"
global OUTPUT_VALIDATION_DIFFERENCES "$OUTPUT_VALIDATION/06_first_differences"
global OUTPUT_VALIDATION_DYNAMIC "$OUTPUT_VALIDATION/07_dynamic_sensitivity"
global OUTPUT_VALIDATION_INFERENCE "$OUTPUT_VALIDATION/08_inference_sensitivity"
global OUTPUT_VALIDATION_FINAL "$OUTPUT_VALIDATION/09_final"
global OUTPUT_VALIDATION_LOGS "$OUTPUT_VALIDATION/logs"

foreach validation_directory in ///
    "$OUTPUT_VALIDATION" ///
    "$OUTPUT_VALIDATION_DESIGN" ///
    "$OUTPUT_VALIDATION_SAMPLE" ///
    "$OUTPUT_VALIDATION_SELECTION" ///
    "$OUTPUT_VALIDATION_EFFECTS" ///
    "$OUTPUT_VALIDATION_MUNDLAK" ///
    "$OUTPUT_VALIDATION_STATIONARITY" ///
    "$OUTPUT_VALIDATION_DIFFERENCES" ///
    "$OUTPUT_VALIDATION_DYNAMIC" ///
    "$OUTPUT_VALIDATION_INFERENCE" ///
    "$OUTPUT_VALIDATION_FINAL" ///
    "$OUTPUT_VALIDATION_LOGS" {
    capture mkdir "`validation_directory'"
}

log using ///
    "$OUTPUT_VALIDATION_LOGS/09_panel_specification_validation.log", ///
    text replace name(validation_log)


// *****************************************************************************
// 1. CONTRATO DE ENTRADAS Y MUESTRA CONGELADA
// *****************************************************************************

local validation_panel ///
    "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta"
local validation_contract "$OUTPUT_SAMPLE/sample_contract.csv"
local validation_unit_root_focal ///
    "$OUTPUT_DIAGNOSTICS/panel_unit_root_tests.csv"
local validation_unit_root_controls ///
    "$OUTPUT_DIAGNOSTICS/panel_unit_root_controls.csv"
local validation_eci_model "$OUTPUT_ECI/eci_twfe_main.ster"
local validation_divx_model "$OUTPUT_DIVX/divx_twfe_main.ster"

foreach validation_input in ///
    "`validation_panel'" ///
    "`validation_contract'" ///
    "`validation_unit_root_focal'" ///
    "`validation_unit_root_controls'" ///
    "`validation_eci_model'" ///
    "`validation_divx_model'" {
    capture confirm file "`validation_input'"
    if _rc {
        display as error "Falta una entrada obligatoria: `validation_input'"
        exit 601
    }
}

use "`validation_panel'", clear

isid country_id year

local validation_required_variables ///
    country_id country_iso3_code year ///
    sample_eci sample_divx ///
    eci divx rents inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin

foreach validation_variable of local validation_required_variables {
    capture confirm variable `validation_variable'
    if _rc {
        display as error ///
            "Falta la variable obligatoria `validation_variable'."
        exit 111
    }
}

assert sample_eci == sample_divx
assert inlist(sample_eci, 0, 1)

generate byte sample_validation = sample_eci == 1
label variable sample_validation ///
    "Muestra común congelada para validación de especificación"

quietly count if sample_validation == 1
local validation_expected_n = r(N)
assert `validation_expected_n' == 1044

quietly levelsof country_id if sample_validation == 1, ///
    local(validation_country_ids)
local validation_expected_countries : word count ///
    `validation_country_ids'
assert `validation_expected_countries' == 49

quietly levelsof year if sample_validation == 1, ///
    local(validation_years)
local validation_expected_years : word count `validation_years'
assert `validation_expected_years' == 23

quietly summarize year if sample_validation == 1, meanonly
assert r(min) == 1996
assert r(max) == 2021

xtset country_id year

display as result ///
    "Contrato validado: 1.044 observaciones, 49 países y 23 años efectivos."


// *****************************************************************************
// 2. ESPECIFICACIONES M3 QUE DEBEN PERMANECER INALTERADAS
// *****************************************************************************

global VALIDATION_ECI_REGRESSORS ///
    c.rents##c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin

global VALIDATION_DIVX_REGRESSORS ///
    c.rents##c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin

local validation_divx_hhi_position = ///
    strpos(" $VALIDATION_DIVX_REGRESSORS ", " hhi ")
assert `validation_divx_hhi_position' == 0

global VALIDATION_INFERENCE_MAIN "vce(cluster country_id)"


// *****************************************************************************
// 3. BLOQUE 1: COMPARACIÓN ENTRE POOLED, FE, TWFE Y RE
// *****************************************************************************

// Este bloque cambia únicamente la estructura del estimador. La muestra y los
// regresores M3 permanecen constantes dentro de cada resultado. Así, cualquier
// diferencia entre columnas no puede atribuirse a un cambio de observaciones o
// a la inclusión selectiva de controles.

tempfile validation_selection_summary
tempfile validation_selection_focal
tempname validation_summary_post
tempname validation_focal_post

postfile `validation_summary_post' ///
    int model_order ///
    str8 outcome ///
    str24 model_code ///
    str28 estimator ///
    byte country_fe ///
    byte year_fe ///
    byte random_effects ///
    long observations ///
    int countries ///
    int clusters ///
    int effective_years ///
    int first_year ///
    int last_year ///
    double r2 ///
    double r2_within ///
    double r2_between ///
    double r2_overall ///
    double residual_scale ///
    double model_statistic ///
    double model_p_value ///
    str8 statistic_type ///
    str32 inference ///
    str40 sample_rule ///
    using `validation_selection_summary', replace

postfile `validation_focal_post' ///
    int model_order ///
    str8 outcome ///
    str24 model_code ///
    str20 term ///
    str16 term_role ///
    double coefficient ///
    double standard_error ///
    double test_statistic ///
    double p_value ///
    double ci_lower ///
    double ci_upper ///
    str8 reference_distribution ///
    double degrees_freedom ///
    long observations ///
    int countries ///
    int clusters ///
    byte country_fe ///
    byte year_fe ///
    byte random_effects ///
    using `validation_selection_focal', replace

local validation_model_order = 0

foreach validation_outcome in eci divx {

    if "`validation_outcome'" == "eci" {
        local validation_regressors "$VALIDATION_ECI_REGRESSORS"
        local validation_outcome_label "ECI"
    }
    else {
        local validation_regressors "$VALIDATION_DIVX_REGRESSORS"
        local validation_outcome_label "DIVX"
    }

    forvalues validation_model = 1/5 {

        local ++validation_model_order
        local validation_country_fe = 0
        local validation_year_fe = 0
        local validation_random_effects = 0

        if `validation_model' == 1 {
            local validation_model_code "pooled"
            local validation_estimator "Pooled OLS"
            quietly regress `validation_outcome' ///
                `validation_regressors' ///
                if sample_validation == 1, ///
                $VALIDATION_INFERENCE_MAIN
        }
        else if `validation_model' == 2 {
            local validation_model_code "pooled_year_fe"
            local validation_estimator "Pooled OLS + year FE"
            local validation_year_fe = 1
            quietly regress `validation_outcome' ///
                `validation_regressors' i.year ///
                if sample_validation == 1, ///
                $VALIDATION_INFERENCE_MAIN
        }
        else if `validation_model' == 3 {
            local validation_model_code "country_fe"
            local validation_estimator "Country FE"
            local validation_country_fe = 1
            quietly xtreg `validation_outcome' ///
                `validation_regressors' ///
                if sample_validation == 1, ///
                fe $VALIDATION_INFERENCE_MAIN
        }
        else if `validation_model' == 4 {
            local validation_model_code "twfe"
            local validation_estimator "Country and year FE"
            local validation_country_fe = 1
            local validation_year_fe = 1
            quietly xtreg `validation_outcome' ///
                `validation_regressors' i.year ///
                if sample_validation == 1, ///
                fe $VALIDATION_INFERENCE_MAIN
        }
        else {
            local validation_model_code "re_year_fe"
            local validation_estimator "Random effects + year FE"
            local validation_year_fe = 1
            local validation_random_effects = 1
            quietly xtreg `validation_outcome' ///
                `validation_regressors' i.year ///
                if sample_validation == 1, ///
                re $VALIDATION_INFERENCE_MAIN
        }

        // El estimador no puede reducir la muestra común ni los clústeres.
        assert e(sample) == sample_validation
        assert e(N) == `validation_expected_n'

        quietly levelsof country_id if e(sample), ///
            local(validation_model_countries)
        local validation_model_country_count : word count ///
            `validation_model_countries'
        assert `validation_model_country_count' == ///
            `validation_expected_countries'

        quietly levelsof year if e(sample), ///
            local(validation_model_years)
        local validation_model_year_count : word count ///
            `validation_model_years'
        assert `validation_model_year_count' == `validation_expected_years'

        tempname validation_clusters validation_r2 validation_r2_w
        tempname validation_r2_b validation_r2_o validation_scale
        tempname validation_model_stat validation_model_p validation_df_r
        tempname validation_df_m

        scalar `validation_clusters' = .
        scalar `validation_r2' = .
        scalar `validation_r2_w' = .
        scalar `validation_r2_b' = .
        scalar `validation_r2_o' = .
        scalar `validation_scale' = .
        scalar `validation_model_stat' = .
        scalar `validation_model_p' = .
        scalar `validation_df_r' = .
        scalar `validation_df_m' = .

        capture scalar `validation_clusters' = e(N_clust)
        capture scalar `validation_r2' = e(r2)
        capture scalar `validation_r2_w' = e(r2_w)
        capture scalar `validation_r2_b' = e(r2_b)
        capture scalar `validation_r2_o' = e(r2_o)
        capture scalar `validation_scale' = e(rmse)
        if missing(`validation_scale') {
            capture scalar `validation_scale' = e(sigma_e)
        }
        capture scalar `validation_model_stat' = e(F)
        capture scalar `validation_model_p' = e(p)
        capture scalar `validation_df_r' = e(df_r)
        capture scalar `validation_df_m' = e(df_m)

        local validation_statistic_type "F"
        if missing(`validation_model_stat') {
            capture scalar `validation_model_stat' = e(chi2)
            local validation_statistic_type "chi2"
        }
        if missing(`validation_model_p') & ///
                "`validation_statistic_type'" == "F" & ///
                !missing(`validation_df_m') & !missing(`validation_df_r') {
            scalar `validation_model_p' = ///
                Ftail(`validation_df_m', `validation_df_r', ///
                    `validation_model_stat')
        }

        assert `validation_clusters' == `validation_expected_countries'

        local validation_estimate_name ///
            "`validation_outcome_label'_`validation_model_code'"
        estimates store `validation_estimate_name'
        estimates save ///
            "$OUTPUT_VALIDATION_SELECTION/`validation_estimate_name'.ster", ///
            replace

        post `validation_summary_post' ///
            (`validation_model_order') ///
            ("`validation_outcome_label'") ///
            ("`validation_model_code'") ///
            ("`validation_estimator'") ///
            (`validation_country_fe') ///
            (`validation_year_fe') ///
            (`validation_random_effects') ///
            (e(N)) ///
            (`validation_model_country_count') ///
            (`validation_clusters') ///
            (`validation_model_year_count') ///
            (1996) ///
            (2021) ///
            (`validation_r2') ///
            (`validation_r2_w') ///
            (`validation_r2_b') ///
            (`validation_r2_o') ///
            (`validation_scale') ///
            (`validation_model_stat') ///
            (`validation_model_p') ///
            ("`validation_statistic_type'") ///
            ("SE clustered by country") ///
            ("Common frozen M3 sample")

        foreach validation_term in rents inst c.rents#c.inst {

            tempname validation_b validation_se validation_test
            tempname validation_p validation_critical
            tempname validation_ci_lower validation_ci_upper

            scalar `validation_b' = _b[`validation_term']
            scalar `validation_se' = _se[`validation_term']
            scalar `validation_test' = ///
                `validation_b' / `validation_se'

            local validation_ref_dist "normal"
            scalar `validation_p' = ///
                2 * normal(-abs(`validation_test'))
            scalar `validation_critical' = invnormal(0.975)

            if !missing(`validation_df_r') {
                local validation_ref_dist "t"
                scalar `validation_p' = ///
                    2 * ttail(`validation_df_r', abs(`validation_test'))
                scalar `validation_critical' = ///
                    invttail(`validation_df_r', 0.025)
            }

            scalar `validation_ci_lower' = ///
                `validation_b' - `validation_critical' * `validation_se'
            scalar `validation_ci_upper' = ///
                `validation_b' + `validation_critical' * `validation_se'

            local validation_term_role "main_effect"
            if "`validation_term'" == "c.rents#c.inst" {
                local validation_term_role "interaction"
            }

            post `validation_focal_post' ///
                (`validation_model_order') ///
                ("`validation_outcome_label'") ///
                ("`validation_model_code'") ///
                ("`validation_term'") ///
                ("`validation_term_role'") ///
                (`validation_b') ///
                (`validation_se') ///
                (`validation_test') ///
                (`validation_p') ///
                (`validation_ci_lower') ///
                (`validation_ci_upper') ///
                ("`validation_ref_dist'") ///
                (`validation_df_r') ///
                (e(N)) ///
                (`validation_model_country_count') ///
                (`validation_clusters') ///
                (`validation_country_fe') ///
                (`validation_year_fe') ///
                (`validation_random_effects')
        }

        display as result ///
            "Bloque 1: `validation_outcome_label' - `validation_model_code' validado."
    }
}

postclose `validation_summary_post'
postclose `validation_focal_post'

preserve
    use `validation_selection_summary', clear
    sort model_order
    order model_order outcome model_code estimator ///
        country_fe year_fe random_effects ///
        observations countries clusters effective_years ///
        first_year last_year
    export delimited using ///
        "$OUTPUT_VALIDATION_SELECTION/estimator_selection_summary.csv", ///
        replace
restore

preserve
    use `validation_selection_focal', clear
    sort model_order term
    order model_order outcome model_code term term_role ///
        coefficient standard_error test_statistic p_value ///
        ci_lower ci_upper reference_distribution degrees_freedom ///
        observations countries clusters ///
        country_fe year_fe random_effects
    export delimited using ///
        "$OUTPUT_VALIDATION_SELECTION/estimator_selection_focal_coefficients.csv", ///
        replace
restore

display as result ///
    "Bloque 1 completo: 10 modelos y 30 coeficientes focales exportados."


// *****************************************************************************
// 4. BLOQUE 2: CONTRASTES DE EFECTOS DE PAÍS Y DE AÑO
// *****************************************************************************

// La prueba F clásica de efectos de país y la prueba LM requieren la matriz de
// varianzas convencional de sus estimadores. Se reportan como diagnósticos de
// especificación, no como inferencia principal sobre los coeficientes de M3.
// La prueba de efectos de año sí conserva errores agrupados por país.

tempfile validation_effects_tests
tempname validation_effects_post

postfile `validation_effects_post' ///
    int test_order ///
    str8 outcome ///
    str24 test_code ///
    str52 null_hypothesis ///
    str52 model_comparison ///
    str28 test_method ///
    str8 statistic_type ///
    double statistic ///
    double df_numerator ///
    double df_denominator ///
    double p_value ///
    byte reject_null_5pct ///
    str32 covariance_structure ///
    long observations ///
    int countries ///
    int effective_years ///
    str52 interpretation_scope ///
    using `validation_effects_tests', replace

local validation_test_order = 0

foreach validation_outcome in eci divx {

    if "`validation_outcome'" == "eci" {
        local validation_regressors "$VALIDATION_ECI_REGRESSORS"
        local validation_outcome_label "ECI"
    }
    else {
        local validation_regressors "$VALIDATION_DIVX_REGRESSORS"
        local validation_outcome_label "DIVX"
    }

    // 4.1. Efectos de país: F clásica de que todos los u_i son cero,
    //      condicionando por los mismos indicadores de año de TWFE.
    quietly xtreg `validation_outcome' ///
        `validation_regressors' i.year ///
        if sample_validation == 1, fe

    assert e(sample) == sample_validation
    assert e(N) == `validation_expected_n'
    assert e(N_g) == `validation_expected_countries'

    tempname validation_country_stat validation_country_df_n
    tempname validation_country_df_d validation_country_p

    scalar `validation_country_stat' = e(F_f)
    scalar `validation_country_df_n' = e(df_a)
    scalar `validation_country_df_d' = e(df_r)
    scalar `validation_country_p' = ///
        Ftail(`validation_country_df_n', `validation_country_df_d', ///
            `validation_country_stat')

    assert `validation_country_df_n' == ///
        `validation_expected_countries' - 1

    estimates store `validation_outcome_label'_country_fe_test
    estimates save ///
        "$OUTPUT_VALIDATION_EFFECTS/`validation_outcome_label'_country_fe_test.ster", ///
        replace

    local ++validation_test_order
    post `validation_effects_post' ///
        (`validation_test_order') ///
        ("`validation_outcome_label'") ///
        ("country_fe_joint") ///
        ("All country effects are jointly zero") ///
        ("Pooled with year FE vs country and year FE") ///
        ("Classical FE F test") ///
        ("F") ///
        (`validation_country_stat') ///
        (`validation_country_df_n') ///
        (`validation_country_df_d') ///
        (`validation_country_p') ///
        (`validation_country_p' < 0.05) ///
        ("Conventional") ///
        (e(N)) ///
        (e(N_g)) ///
        (`validation_expected_years') ///
        ("Diagnostic for time-invariant country heterogeneity")

    // 4.2. Efectos de año: Wald F agrupada por país dentro de FE de país.
    quietly xtreg `validation_outcome' ///
        `validation_regressors' i.year ///
        if sample_validation == 1, ///
        fe $VALIDATION_INFERENCE_MAIN

    assert e(sample) == sample_validation
    assert e(N) == `validation_expected_n'
    assert e(N_g) == `validation_expected_countries'
    assert e(N_clust) == `validation_expected_countries'

    estimates store `validation_outcome_label'_year_fe_test
    estimates save ///
        "$OUTPUT_VALIDATION_EFFECTS/`validation_outcome_label'_year_fe_test.ster", ///
        replace

    testparm i.year

    tempname validation_year_stat validation_year_df_n
    tempname validation_year_df_d validation_year_p

    scalar `validation_year_stat' = r(F)
    scalar `validation_year_df_n' = r(df)
    scalar `validation_year_df_d' = r(df_r)
    scalar `validation_year_p' = r(p)

    local ++validation_test_order
    post `validation_effects_post' ///
        (`validation_test_order') ///
        ("`validation_outcome_label'") ///
        ("year_fe_joint") ///
        ("All year indicators are jointly zero") ///
        ("Country FE vs country and year FE") ///
        ("Cluster-robust Wald test") ///
        ("F") ///
        (`validation_year_stat') ///
        (`validation_year_df_n') ///
        (`validation_year_df_d') ///
        (`validation_year_p') ///
        (`validation_year_p' < 0.05) ///
        ("SE clustered by country") ///
        (`validation_expected_n') ///
        (`validation_expected_countries') ///
        (`validation_expected_years') ///
        ("Diagnostic for common time shocks")

    // 4.3. Efectos aleatorios: LM clásica de var(u_i) = 0, con los mismos
    //      indicadores de año usados en la comparación del bloque 1.
    quietly xtreg `validation_outcome' ///
        `validation_regressors' i.year ///
        if sample_validation == 1, re

    assert e(sample) == sample_validation
    assert e(N) == `validation_expected_n'
    assert e(N_g) == `validation_expected_countries'

    estimates store `validation_outcome_label'_re_lm_test
    estimates save ///
        "$OUTPUT_VALIDATION_EFFECTS/`validation_outcome_label'_re_lm_test.ster", ///
        replace

    local validation_lm_n = e(N)
    local validation_lm_groups = e(N_g)
    quietly xttest0

    tempname validation_lm_stat validation_lm_p
    scalar `validation_lm_stat' = r(lm)
    scalar `validation_lm_p' = r(p)

    local ++validation_test_order
    post `validation_effects_post' ///
        (`validation_test_order') ///
        ("`validation_outcome_label'") ///
        ("re_lm_vs_pooled") ///
        ("Panel-level variance is zero") ///
        ("Pooled with year FE vs RE with year FE") ///
        ("Breusch-Pagan LM test") ///
        ("chibar2") ///
        (`validation_lm_stat') ///
        (1) ///
        (.) ///
        (`validation_lm_p') ///
        (`validation_lm_p' < 0.05) ///
        ("Conventional") ///
        (`validation_lm_n') ///
        (`validation_lm_groups') ///
        (`validation_expected_years') ///
        ("Diagnostic for nonzero panel-level variance")

    display as result ///
        "Bloque 2: tres contrastes para `validation_outcome_label' validados."
}

postclose `validation_effects_post'

preserve
    use `validation_effects_tests', clear
    sort test_order
    order test_order outcome test_code null_hypothesis ///
        model_comparison test_method statistic_type statistic ///
        df_numerator df_denominator p_value reject_null_5pct ///
        covariance_structure observations countries effective_years ///
        interpretation_scope
    export delimited using ///
        "$OUTPUT_VALIDATION_EFFECTS/fixed_effects_joint_tests.csv", ///
        replace
restore

display as result ///
    "Bloque 2 completo: seis pruebas de especificación exportadas."


// *****************************************************************************
// 5. BLOQUE 3: COMPARACIÓN FE--RE Y MUNDLAK/CRE
// *****************************************************************************

// Hausman se conserva como diagnóstico clásico bajo matriz convencional. La
// prueba Mundlak/CRE es el diagnóstico principal de este bloque porque permite
// contrastar con errores agrupados por país la independencia entre el efecto
// no observado del país y los regresores temporales de M3.

generate double validation_rents_inst = rents * inst
label variable validation_rents_inst "RENTS por INST para media Mundlak"

local validation_mean_sources_all ///
    rents inst validation_rents_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin

foreach validation_source of local validation_mean_sources_all {
    bysort country_id: egen double vm_`validation_source' = ///
        mean(cond(sample_validation == 1, `validation_source', .))
    assert !missing(vm_`validation_source') if sample_validation == 1
}

local validation_mean_variables_eci ///
    vm_rents vm_inst vm_validation_rents_inst ///
    vm_ln1p_oilpc vm_ln1p_gaspc vm_ln1p_coalpc ///
    vm_hhi vm_pexp vm_fexp ///
    vm_vol vm_rer ///
    vm_humcap vm_innov vm_net ///
    vm_log_gdppc vm_govcons vm_fin

local validation_mean_variables_divx ///
    vm_rents vm_inst vm_validation_rents_inst ///
    vm_ln1p_oilpc vm_ln1p_gaspc vm_ln1p_coalpc ///
    vm_pexp vm_fexp ///
    vm_vol vm_rer ///
    vm_humcap vm_innov vm_net ///
    vm_log_gdppc vm_govcons vm_fin

tempfile validation_hausman_diagnostics
tempfile validation_mundlak_focal
tempname validation_hausman_post
tempname validation_mundlak_post

postfile `validation_hausman_post' ///
    int test_order ///
    str8 outcome ///
    str24 test_code ///
    str60 null_hypothesis ///
    str36 estimator_comparison ///
    str32 covariance_structure ///
    str8 statistic_type ///
    double statistic ///
    double degrees_freedom ///
    double denominator_df ///
    double p_value ///
    byte reject_null_5pct ///
    int means_tested ///
    long observations ///
    int countries ///
    str20 execution_status ///
    byte valid_for_selection ///
    str64 interpretation_scope ///
    using `validation_hausman_diagnostics', replace

postfile `validation_mundlak_post' ///
    int model_order ///
    str8 outcome ///
    str20 model_code ///
    str20 term ///
    str16 term_role ///
    double coefficient ///
    double standard_error ///
    double test_statistic ///
    double p_value ///
    double ci_lower ///
    double ci_upper ///
    long observations ///
    int countries ///
    int clusters ///
    using `validation_mundlak_focal', replace

local validation_diagnostic_order = 0
local validation_mundlak_order = 0

foreach validation_outcome in eci divx {

    if "`validation_outcome'" == "eci" {
        local validation_regressors "$VALIDATION_ECI_REGRESSORS"
        local validation_mean_variables ///
            "`validation_mean_variables_eci'"
        local validation_outcome_label "ECI"
    }
    else {
        local validation_regressors "$VALIDATION_DIVX_REGRESSORS"
        local validation_mean_variables ///
            "`validation_mean_variables_divx'"
        local validation_outcome_label "DIVX"
    }

    local validation_means_count : word count ///
        `validation_mean_variables'

    // 5.1. Hausman clásico: mismas variables, años y muestra en FE y RE.
    quietly xtreg `validation_outcome' ///
        `validation_regressors' i.year ///
        if sample_validation == 1, fe
    assert e(sample) == sample_validation
    assert e(N) == `validation_expected_n'
    assert e(N_g) == `validation_expected_countries'
    estimates store `validation_outcome_label'_hausman_fe
    estimates save ///
        "$OUTPUT_VALIDATION_MUNDLAK/`validation_outcome_label'_hausman_fe.ster", ///
        replace

    quietly xtreg `validation_outcome' ///
        `validation_regressors' i.year ///
        if sample_validation == 1, re
    assert e(sample) == sample_validation
    assert e(N) == `validation_expected_n'
    assert e(N_g) == `validation_expected_countries'
    estimates store `validation_outcome_label'_hausman_re
    estimates save ///
        "$OUTPUT_VALIDATION_MUNDLAK/`validation_outcome_label'_hausman_re.ster", ///
        replace

    tempname validation_hausman_stat validation_hausman_df
    tempname validation_hausman_p
    scalar `validation_hausman_stat' = .
    scalar `validation_hausman_df' = .
    scalar `validation_hausman_p' = .
    local validation_hausman_status "ok"

    capture noisily hausman ///
        `validation_outcome_label'_hausman_fe ///
        `validation_outcome_label'_hausman_re, sigmamore
    local validation_hausman_rc = _rc

    if `validation_hausman_rc' == 0 {
        scalar `validation_hausman_stat' = r(chi2)
        scalar `validation_hausman_df' = r(df)
        scalar `validation_hausman_p' = r(p)
        // En la muestra congelada Stata devuelve el estadístico, pero advierte
        // que V_b - V_B no es positiva definida. Por ello no se usa para
        // seleccionar el estimador, aun cuando se conserva para transparencia.
        local validation_hausman_status "warning_non_pd"
    }
    else {
        local validation_hausman_status ///
            "failed_rc_`validation_hausman_rc'"
    }

    local ++validation_diagnostic_order
    post `validation_hausman_post' ///
        (`validation_diagnostic_order') ///
        ("`validation_outcome_label'") ///
        ("hausman_fe_vs_re") ///
        ("Coefficient differences between FE and RE are not systematic") ///
        ("Country-year FE vs RE with year FE") ///
        ("Conventional; sigmamore") ///
        ("chi2") ///
        (`validation_hausman_stat') ///
        (`validation_hausman_df') ///
        (.) ///
        (`validation_hausman_p') ///
        (`validation_hausman_p' < 0.05) ///
        (0) ///
        (`validation_expected_n') ///
        (`validation_expected_countries') ///
        ("`validation_hausman_status'") ///
        (0) ///
        ("Undefined under non-PD covariance difference; report with caveat")

    // 5.2. Mundlak/CRE: RE con las medias por país de todos los regresores
    //      temporales, incluida la media de la interacción observada.
    quietly xtreg `validation_outcome' ///
        `validation_regressors' i.year ///
        `validation_mean_variables' ///
        if sample_validation == 1, ///
        re $VALIDATION_INFERENCE_MAIN

    assert e(sample) == sample_validation
    assert e(N) == `validation_expected_n'
    assert e(N_g) == `validation_expected_countries'
    assert e(N_clust) == `validation_expected_countries'

    estimates store `validation_outcome_label'_mundlak_cre
    estimates save ///
        "$OUTPUT_VALIDATION_MUNDLAK/`validation_outcome_label'_mundlak_cre.ster", ///
        replace

    quietly testparm `validation_mean_variables'

    tempname validation_mundlak_stat validation_mundlak_df
    tempname validation_mundlak_df_d validation_mundlak_p
    scalar `validation_mundlak_stat' = .
    scalar `validation_mundlak_df' = r(df)
    scalar `validation_mundlak_df_d' = .
    scalar `validation_mundlak_p' = r(p)
    local validation_mundlak_stat_type "chi2"

    capture scalar `validation_mundlak_stat' = r(chi2)
    if missing(`validation_mundlak_stat') {
        scalar `validation_mundlak_stat' = r(F)
        scalar `validation_mundlak_df_d' = r(df_r)
        local validation_mundlak_stat_type "F"
    }

    local ++validation_diagnostic_order
    post `validation_hausman_post' ///
        (`validation_diagnostic_order') ///
        ("`validation_outcome_label'") ///
        ("mundlak_means_joint") ///
        ("All country means of time-varying regressors are jointly zero") ///
        ("RE with year FE vs Mundlak CRE") ///
        ("SE clustered by country") ///
        ("`validation_mundlak_stat_type'") ///
        (`validation_mundlak_stat') ///
        (`validation_mundlak_df') ///
        (`validation_mundlak_df_d') ///
        (`validation_mundlak_p') ///
        (`validation_mundlak_p' < 0.05) ///
        (`validation_means_count') ///
        (`validation_expected_n') ///
        (`validation_expected_countries') ///
        ("ok") ///
        (1) ///
        ("Direct diagnostic of RE orthogonality assumption")

    foreach validation_term in rents inst c.rents#c.inst {

        tempname validation_cre_b validation_cre_se
        tempname validation_cre_z validation_cre_p
        tempname validation_cre_ci_l validation_cre_ci_u

        scalar `validation_cre_b' = _b[`validation_term']
        scalar `validation_cre_se' = _se[`validation_term']
        scalar `validation_cre_z' = ///
            `validation_cre_b' / `validation_cre_se'
        scalar `validation_cre_p' = ///
            2 * normal(-abs(`validation_cre_z'))
        scalar `validation_cre_ci_l' = ///
            `validation_cre_b' - invnormal(0.975) * `validation_cre_se'
        scalar `validation_cre_ci_u' = ///
            `validation_cre_b' + invnormal(0.975) * `validation_cre_se'

        local validation_term_role "main_effect"
        if "`validation_term'" == "c.rents#c.inst" {
            local validation_term_role "interaction"
        }

        local ++validation_mundlak_order
        post `validation_mundlak_post' ///
            (`validation_mundlak_order') ///
            ("`validation_outcome_label'") ///
            ("mundlak_cre") ///
            ("`validation_term'") ///
            ("`validation_term_role'") ///
            (`validation_cre_b') ///
            (`validation_cre_se') ///
            (`validation_cre_z') ///
            (`validation_cre_p') ///
            (`validation_cre_ci_l') ///
            (`validation_cre_ci_u') ///
            (`validation_expected_n') ///
            (`validation_expected_countries') ///
            (`validation_expected_countries')
    }

    display as result ///
        "Bloque 3: Hausman y Mundlak/CRE para `validation_outcome_label' validados."
}

postclose `validation_hausman_post'
postclose `validation_mundlak_post'

preserve
    use `validation_hausman_diagnostics', clear
    sort test_order
    order test_order outcome test_code null_hypothesis ///
        estimator_comparison covariance_structure statistic_type ///
        statistic degrees_freedom denominator_df p_value ///
        reject_null_5pct means_tested observations countries ///
        execution_status valid_for_selection interpretation_scope
    export delimited using ///
        "$OUTPUT_VALIDATION_MUNDLAK/hausman_mundlak_diagnostics.csv", ///
        replace
restore

preserve
    use `validation_mundlak_focal', clear
    sort model_order
    order model_order outcome model_code term term_role ///
        coefficient standard_error test_statistic p_value ///
        ci_lower ci_upper observations countries clusters
    export delimited using ///
        "$OUTPUT_VALIDATION_MUNDLAK/mundlak_cre_focal_coefficients.csv", ///
        replace
restore

display as result ///
    "Bloque 3 completo: Hausman, Mundlak/CRE y seis coeficientes focales exportados."


// *****************************************************************************
// 6. BLOQUE 4: ESTACIONARIEDAD Y PRIMERAS DIFERENCIAS
// *****************************************************************************

// 6.1. Consolidar la evidencia Fisher--ADF existente sin repetir pruebas.

tempfile validation_stationarity_focal
tempfile validation_stat_controls

preserve
    import delimited using "`validation_unit_root_focal'", ///
        varnames(1) clear encoding(utf8)
    keep if method == "FISHER_ADF" & return_code == 0

    generate str20 model_scope = "BOTH"
    replace model_scope = "ECI" if variable == "eci"
    replace model_scope = "DIVX" if variable == "divx"
    generate str28 evidence_depth = "eight_predefined_variants"

    collapse ///
        (count) valid_tests=reject_5pct ///
        (sum) rejections=reject_5pct ///
        (min) minimum_p_value=p_value ///
        (max) maximum_p_value=p_value, ///
        by(variable model_scope series_form method evidence_depth)

    save `validation_stationarity_focal', replace
restore

preserve
    import delimited using "`validation_unit_root_controls'", ///
        varnames(1) clear encoding(utf8)
    keep if method == "FISHER_ADF" & return_code == 0
    generate str28 evidence_depth = "single_predefined_variant"

    collapse ///
        (count) valid_tests=reject_5pct ///
        (sum) rejections=reject_5pct ///
        (min) minimum_p_value=p_value ///
        (max) maximum_p_value=p_value, ///
        by(variable model_scope series_form method evidence_depth)

    save `validation_stat_controls', replace
restore

preserve
    use `validation_stationarity_focal', clear
    append using `validation_stat_controls'

    generate double rejection_share = rejections / valid_tests
    generate str24 evidence_summary = "mixed_rejection"
    replace evidence_summary = "no_rejection" if rejections == 0
    replace evidence_summary = "rejection_in_all_tests" ///
        if rejections == valid_tests

    generate byte model_change_authorized = 0
    generate str64 interpretation_limit = ///
        "Fisher rejection does not establish stationarity in every panel"
    replace interpretation_limit = ///
        "One predefined Fisher variant; signal is not an I(0)/I(1) class" ///
        if evidence_depth == "single_predefined_variant"

    isid variable series_form
    assert _N == 36
    sort variable series_form
    order variable model_scope series_form method evidence_depth ///
        valid_tests rejections rejection_share ///
        minimum_p_value maximum_p_value evidence_summary ///
        model_change_authorized interpretation_limit

    export delimited using ///
        "$OUTPUT_VALIDATION_STATIONARITY/stationarity_decision_matrix.csv", ///
        replace
restore

// 6.2. Construir la muestra apareada de primeras diferencias.
//      L.sample_validation exige que t y t-1 pertenezcan a la muestra M3 y que
//      sean años consecutivos según xtset; no se rellenan brechas internas.

generate byte sample_first_difference = ///
    sample_validation == 1 & L.sample_validation == 1
label variable sample_first_difference ///
    "Pares consecutivos derivados de la muestra M3"

local validation_fd_source_variables ///
    eci divx ///
    rents inst validation_rents_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin

foreach validation_source of local validation_fd_source_variables {
    generate double d_`validation_source' = D.`validation_source'
    assert !missing(d_`validation_source') ///
        if sample_first_difference == 1
}

quietly count if sample_first_difference == 1
local validation_fd_expected_n = r(N)
assert `validation_fd_expected_n' == 869

quietly levelsof country_id if sample_first_difference == 1, ///
    local(validation_fd_country_ids)
local validation_fd_countries : word count `validation_fd_country_ids'
assert `validation_fd_countries' == `validation_expected_countries'

quietly levelsof year if sample_first_difference == 1, ///
    local(validation_fd_year_values)
local validation_fd_years : word count `validation_fd_year_values'

quietly summarize year if sample_first_difference == 1, meanonly
local validation_fd_first_year = r(min)
local validation_fd_last_year = r(max)
local validation_fd_loss = ///
    `validation_expected_n' - `validation_fd_expected_n'

local validation_fd_eci_regressors ///
    d_rents d_inst d_validation_rents_inst ///
    d_ln1p_oilpc d_ln1p_gaspc d_ln1p_coalpc ///
    d_hhi d_pexp d_fexp ///
    d_vol d_rer ///
    d_humcap d_innov d_net ///
    d_log_gdppc d_govcons d_fin

local validation_fd_divx_regressors ///
    d_rents d_inst d_validation_rents_inst ///
    d_ln1p_oilpc d_ln1p_gaspc d_ln1p_coalpc ///
    d_pexp d_fexp ///
    d_vol d_rer ///
    d_humcap d_innov d_net ///
    d_log_gdppc d_govcons d_fin

tempfile validation_fd_summary
tempfile validation_fd_focal
tempname validation_fd_summary_post
tempname validation_fd_focal_post

postfile `validation_fd_summary_post' ///
    int model_order ///
    str8 outcome ///
    str28 model_code ///
    str52 transformation ///
    str40 interaction_treatment ///
    byte country_fe ///
    byte year_fe ///
    long level_observations ///
    long analysis_observations ///
    long observations_lost ///
    int countries ///
    int clusters ///
    int effective_years ///
    int first_year ///
    int last_year ///
    double r2 ///
    double model_statistic ///
    double model_p_value ///
    str28 inference ///
    str56 interpretation_scope ///
    using `validation_fd_summary', replace

postfile `validation_fd_focal_post' ///
    int model_order ///
    str8 outcome ///
    str28 model_code ///
    str28 term ///
    str20 levels_counterpart ///
    str16 term_role ///
    double coefficient ///
    double standard_error ///
    double test_statistic ///
    double p_value ///
    double ci_lower ///
    double ci_upper ///
    double degrees_freedom ///
    long observations ///
    int countries ///
    int clusters ///
    using `validation_fd_focal', replace

local validation_fd_model_order = 0

foreach validation_outcome in eci divx {

    if "`validation_outcome'" == "eci" {
        local validation_fd_regressors ///
            "`validation_fd_eci_regressors'"
        local validation_levels_regressors ///
            "$VALIDATION_ECI_REGRESSORS"
        local validation_outcome_label "ECI"
    }
    else {
        local validation_fd_regressors ///
            "`validation_fd_divx_regressors'"
        local validation_levels_regressors ///
            "$VALIDATION_DIVX_REGRESSORS"
        local validation_outcome_label "DIVX"
    }

    forvalues validation_fd_specification = 1/2 {

        local ++validation_fd_model_order

        if `validation_fd_specification' == 1 {
            local validation_fd_model_code "matched_sample_twfe"
            local validation_fd_estimate_suffix "matched_twfe"
            local validation_fd_transformation ///
                "Levels TWFE on the first-difference sample"
            local validation_fd_interaction ///
                "Observed RENTS x INST product in levels"
            local validation_fd_country_fe = 1
            local validation_fd_terms "rents inst c.rents#c.inst"
            local validation_fd_scope ///
                "Levels benchmark isolating the effect of sample loss"

            quietly xtreg `validation_outcome' ///
                `validation_levels_regressors' i.year ///
                if sample_first_difference == 1, ///
                fe $VALIDATION_INFERENCE_MAIN
        }
        else {
            local validation_fd_model_code "first_difference_year_fe"
            local validation_fd_estimate_suffix "fd_year"
            local validation_fd_transformation ///
                "First difference of the complete levels equation"
            local validation_fd_interaction ///
                "Delta of observed RENTS x INST product"
            local validation_fd_country_fe = 0
            local validation_fd_terms ///
                "d_rents d_inst d_validation_rents_inst"
            local validation_fd_scope ///
                "Short-run changes; not the same estimand as levels TWFE"

            quietly regress d_`validation_outcome' ///
                `validation_fd_regressors' i.year ///
                if sample_first_difference == 1, ///
                $VALIDATION_INFERENCE_MAIN
        }

        assert e(sample) == sample_first_difference
        assert e(N) == `validation_fd_expected_n'
        assert e(N_clust) == `validation_fd_countries'

        local validation_fd_estimate_name ///
            "`validation_outcome_label'_`validation_fd_estimate_suffix'"
        estimates store `validation_fd_estimate_name'
        estimates save ///
            "$OUTPUT_VALIDATION_DIFFERENCES/`validation_fd_estimate_name'.ster", ///
            replace

        tempname validation_fd_model_p validation_fd_r2
        scalar `validation_fd_model_p' = .
        scalar `validation_fd_r2' = .
        capture scalar `validation_fd_model_p' = e(p)
        if missing(`validation_fd_model_p') {
            scalar `validation_fd_model_p' = ///
                Ftail(e(df_m), e(df_r), e(F))
        }
        capture scalar `validation_fd_r2' = e(r2_w)
        if missing(`validation_fd_r2') {
            capture scalar `validation_fd_r2' = e(r2)
        }

        post `validation_fd_summary_post' ///
            (`validation_fd_model_order') ///
            ("`validation_outcome_label'") ///
            ("`validation_fd_model_code'") ///
            ("`validation_fd_transformation'") ///
            ("`validation_fd_interaction'") ///
            (`validation_fd_country_fe') ///
            (1) ///
            (`validation_expected_n') ///
            (`validation_fd_expected_n') ///
            (`validation_fd_loss') ///
            (`validation_fd_countries') ///
            (e(N_clust)) ///
            (`validation_fd_years') ///
            (`validation_fd_first_year') ///
            (`validation_fd_last_year') ///
            (`validation_fd_r2') ///
            (e(F)) ///
            (`validation_fd_model_p') ///
            ("SE clustered by country") ///
            ("`validation_fd_scope'")

        foreach validation_fd_term of local validation_fd_terms {

            tempname validation_fd_b validation_fd_se validation_fd_t
            tempname validation_fd_p validation_fd_critical
            tempname validation_fd_ci_l validation_fd_ci_u

            scalar `validation_fd_b' = _b[`validation_fd_term']
            scalar `validation_fd_se' = _se[`validation_fd_term']
            scalar `validation_fd_t' = ///
                `validation_fd_b' / `validation_fd_se'
            scalar `validation_fd_p' = ///
                2 * ttail(e(df_r), abs(`validation_fd_t'))
            scalar `validation_fd_critical' = ///
                invttail(e(df_r), 0.025)
            scalar `validation_fd_ci_l' = ///
                `validation_fd_b' - ///
                `validation_fd_critical' * `validation_fd_se'
            scalar `validation_fd_ci_u' = ///
                `validation_fd_b' + ///
                `validation_fd_critical' * `validation_fd_se'

            local validation_levels_counterpart ///
                "`validation_fd_term'"
            local validation_term_role "main_effect"
            if "`validation_fd_term'" == "d_rents" {
                local validation_levels_counterpart "rents"
            }
            if "`validation_fd_term'" == "d_inst" {
                local validation_levels_counterpart "inst"
            }
            if inlist("`validation_fd_term'", ///
                    "c.rents#c.inst", "d_validation_rents_inst") {
                local validation_levels_counterpart "c.rents#c.inst"
                local validation_term_role "interaction"
            }

            post `validation_fd_focal_post' ///
                (`validation_fd_model_order') ///
                ("`validation_outcome_label'") ///
                ("`validation_fd_model_code'") ///
                ("`validation_fd_term'") ///
                ("`validation_levels_counterpart'") ///
                ("`validation_term_role'") ///
                (`validation_fd_b') ///
                (`validation_fd_se') ///
                (`validation_fd_t') ///
                (`validation_fd_p') ///
                (`validation_fd_ci_l') ///
                (`validation_fd_ci_u') ///
                (e(df_r)) ///
                (e(N)) ///
                (`validation_fd_countries') ///
                (e(N_clust))
        }
    }

    display as result ///
        "Bloque 4: niveles apareados y FD para `validation_outcome_label' validados."
}

postclose `validation_fd_summary_post'
postclose `validation_fd_focal_post'

preserve
    use `validation_fd_summary', clear
    sort model_order
    order model_order outcome model_code transformation ///
        interaction_treatment country_fe year_fe ///
        level_observations analysis_observations observations_lost ///
        countries clusters effective_years first_year last_year ///
        r2 model_statistic model_p_value inference interpretation_scope
    export delimited using ///
        "$OUTPUT_VALIDATION_DIFFERENCES/matched_sample_first_differences.csv", ///
        replace
restore

preserve
    use `validation_fd_focal', clear
    sort model_order term
    order model_order outcome model_code term levels_counterpart term_role ///
        coefficient standard_error test_statistic p_value ///
        ci_lower ci_upper degrees_freedom ///
        observations countries clusters
    export delimited using ///
        "$OUTPUT_VALIDATION_DIFFERENCES/matched_sample_focal_coefficients.csv", ///
        replace

    keep if model_code == "first_difference_year_fe"
    export delimited using ///
        "$OUTPUT_VALIDATION_DIFFERENCES/first_difference_focal_coefficients.csv", ///
        replace
restore

display as result ///
    "Bloque 4 completo: estacionariedad consolidada y sensibilidad FD exportada."


// *****************************************************************************
// 7. BLOQUE 5: SENSIBILIDAD DINÁMICA ACOTADA
// *****************************************************************************

// Se añade únicamente L.y al M3 completo. El TWFE estático se reestima sobre
// la misma muestra dinámica para separar el efecto del rezago del efecto de la
// pérdida mecánica de observaciones. El modelo dinámico se interpreta como una
// sensibilidad asociativa y puede sufrir sesgo de Nickell; no activa GMM.

generate byte sample_dynamic = ///
    sample_validation == 1 & L.sample_validation == 1
label variable sample_dynamic ///
    "Muestra común para sensibilidad dinámica con L.y"

quietly count if sample_dynamic == 1
local validation_dynamic_expected_n = r(N)
assert `validation_dynamic_expected_n' == 869

quietly levelsof country_id if sample_dynamic == 1, ///
    local(validation_dynamic_country_ids)
local validation_dynamic_countries : word count ///
    `validation_dynamic_country_ids'
assert `validation_dynamic_countries' == `validation_expected_countries'

quietly levelsof year if sample_dynamic == 1, ///
    local(validation_dynamic_year_values)
local validation_dynamic_years : word count ///
    `validation_dynamic_year_values'

quietly summarize year if sample_dynamic == 1, meanonly
local validation_dynamic_first_year = r(min)
local validation_dynamic_last_year = r(max)
local validation_dynamic_loss = ///
    `validation_expected_n' - `validation_dynamic_expected_n'

tempfile validation_dynamic_summary
tempfile validation_dynamic_focal
tempname validation_dynamic_summary_post
tempname validation_dynamic_focal_post

postfile `validation_dynamic_summary_post' ///
    int model_order ///
    str8 outcome ///
    str24 model_code ///
    byte lagged_dependent ///
    byte country_fe ///
    byte year_fe ///
    long level_observations ///
    long analysis_observations ///
    long observations_lost ///
    int countries ///
    int clusters ///
    int effective_years ///
    int first_year ///
    int last_year ///
    double r2_within ///
    double lag_coefficient ///
    double lag_standard_error ///
    double lag_p_value ///
    double model_statistic ///
    double model_p_value ///
    str28 inference ///
    str52 interpretation_scope ///
    str64 dynamic_bias_warning ///
    using `validation_dynamic_summary', replace

postfile `validation_dynamic_focal_post' ///
    int model_order ///
    str8 outcome ///
    str24 model_code ///
    str20 term ///
    str20 term_role ///
    double coefficient ///
    double standard_error ///
    double test_statistic ///
    double p_value ///
    double ci_lower ///
    double ci_upper ///
    double degrees_freedom ///
    long observations ///
    int countries ///
    int clusters ///
    using `validation_dynamic_focal', replace

local validation_dynamic_order = 0

foreach validation_outcome in eci divx {

    if "`validation_outcome'" == "eci" {
        local validation_regressors "$VALIDATION_ECI_REGRESSORS"
        local validation_outcome_label "ECI"
    }
    else {
        local validation_regressors "$VALIDATION_DIVX_REGRESSORS"
        local validation_outcome_label "DIVX"
    }

    assert !missing(L.`validation_outcome') if sample_dynamic == 1

    forvalues validation_dyn_spec = 1/2 {

        local ++validation_dynamic_order

        if `validation_dyn_spec' == 1 {
            local validation_dynamic_code "matched_static_twfe"
            local validation_dynamic_lagged = 0
            local validation_dynamic_terms ///
                "rents inst c.rents#c.inst"
            local validation_dynamic_scope ///
                "Static TWFE benchmark on the dynamic estimation sample"
            local validation_dynamic_warning ///
                "Not applicable: no lagged dependent variable"

            quietly xtreg `validation_outcome' ///
                `validation_regressors' i.year ///
                if sample_dynamic == 1, ///
                fe $VALIDATION_INFERENCE_MAIN
        }
        else {
            local validation_dynamic_code "dynamic_fe_lag1"
            local validation_dynamic_lagged = 1
            local validation_dynamic_terms ///
                "L.`validation_outcome' rents inst c.rents#c.inst"
            local validation_dynamic_scope ///
                "Dynamic conditional association with one outcome lag"
            local validation_dynamic_warning ///
                "FE lag coefficient may have Nickell bias; no GMM correction"

            quietly xtreg `validation_outcome' ///
                L.`validation_outcome' ///
                `validation_regressors' i.year ///
                if sample_dynamic == 1, ///
                fe $VALIDATION_INFERENCE_MAIN
        }

        assert e(sample) == sample_dynamic
        assert e(N) == `validation_dynamic_expected_n'
        assert e(N_g) == `validation_dynamic_countries'
        assert e(N_clust) == `validation_dynamic_countries'

        local validation_dynamic_estimate ///
            "`validation_outcome_label'_dyn_`validation_dyn_spec'"
        estimates store `validation_dynamic_estimate'
        estimates save ///
            "$OUTPUT_VALIDATION_DYNAMIC/`validation_dynamic_estimate'.ster", ///
            replace

        tempname validation_dynamic_model_p
        tempname validation_lag_b validation_lag_se validation_lag_p
        scalar `validation_dynamic_model_p' = .
        scalar `validation_lag_b' = .
        scalar `validation_lag_se' = .
        scalar `validation_lag_p' = .

        capture scalar `validation_dynamic_model_p' = e(p)
        if missing(`validation_dynamic_model_p') {
            scalar `validation_dynamic_model_p' = ///
                Ftail(e(df_m), e(df_r), e(F))
        }

        if `validation_dynamic_lagged' == 1 {
            scalar `validation_lag_b' = _b[L.`validation_outcome']
            scalar `validation_lag_se' = _se[L.`validation_outcome']
            scalar `validation_lag_p' = ///
                2 * ttail(e(df_r), ///
                    abs(`validation_lag_b' / `validation_lag_se'))
        }

        post `validation_dynamic_summary_post' ///
            (`validation_dynamic_order') ///
            ("`validation_outcome_label'") ///
            ("`validation_dynamic_code'") ///
            (`validation_dynamic_lagged') ///
            (1) ///
            (1) ///
            (`validation_expected_n') ///
            (`validation_dynamic_expected_n') ///
            (`validation_dynamic_loss') ///
            (`validation_dynamic_countries') ///
            (e(N_clust)) ///
            (`validation_dynamic_years') ///
            (`validation_dynamic_first_year') ///
            (`validation_dynamic_last_year') ///
            (e(r2_w)) ///
            (`validation_lag_b') ///
            (`validation_lag_se') ///
            (`validation_lag_p') ///
            (e(F)) ///
            (`validation_dynamic_model_p') ///
            ("SE clustered by country") ///
            ("`validation_dynamic_scope'") ///
            ("`validation_dynamic_warning'")

        foreach validation_dynamic_term of local validation_dynamic_terms {

            tempname validation_dynamic_b validation_dynamic_se
            tempname validation_dynamic_t validation_dynamic_p
            tempname validation_dynamic_critical
            tempname validation_dynamic_ci_l validation_dynamic_ci_u

            scalar `validation_dynamic_b' = ///
                _b[`validation_dynamic_term']
            scalar `validation_dynamic_se' = ///
                _se[`validation_dynamic_term']
            scalar `validation_dynamic_t' = ///
                `validation_dynamic_b' / `validation_dynamic_se'
            scalar `validation_dynamic_p' = ///
                2 * ttail(e(df_r), abs(`validation_dynamic_t'))
            scalar `validation_dynamic_critical' = ///
                invttail(e(df_r), 0.025)
            scalar `validation_dynamic_ci_l' = ///
                `validation_dynamic_b' - ///
                `validation_dynamic_critical' * `validation_dynamic_se'
            scalar `validation_dynamic_ci_u' = ///
                `validation_dynamic_b' + ///
                `validation_dynamic_critical' * `validation_dynamic_se'

            local validation_dynamic_role "main_effect"
            if "`validation_dynamic_term'" == "c.rents#c.inst" {
                local validation_dynamic_role "interaction"
            }
            if "`validation_dynamic_term'" == ///
                    "L.`validation_outcome'" {
                local validation_dynamic_role "lagged_outcome"
            }

            post `validation_dynamic_focal_post' ///
                (`validation_dynamic_order') ///
                ("`validation_outcome_label'") ///
                ("`validation_dynamic_code'") ///
                ("`validation_dynamic_term'") ///
                ("`validation_dynamic_role'") ///
                (`validation_dynamic_b') ///
                (`validation_dynamic_se') ///
                (`validation_dynamic_t') ///
                (`validation_dynamic_p') ///
                (`validation_dynamic_ci_l') ///
                (`validation_dynamic_ci_u') ///
                (e(df_r)) ///
                (e(N)) ///
                (`validation_dynamic_countries') ///
                (e(N_clust))
        }
    }

    display as result ///
        "Bloque 5: estático apareado y dinámico para `validation_outcome_label' validados."
}

postclose `validation_dynamic_summary_post'
postclose `validation_dynamic_focal_post'

preserve
    use `validation_dynamic_summary', clear
    sort model_order
    order model_order outcome model_code lagged_dependent ///
        country_fe year_fe ///
        level_observations analysis_observations observations_lost ///
        countries clusters effective_years first_year last_year ///
        r2_within lag_coefficient lag_standard_error lag_p_value ///
        model_statistic model_p_value inference ///
        interpretation_scope dynamic_bias_warning
    export delimited using ///
        "$OUTPUT_VALIDATION_DYNAMIC/dynamic_sensitivity.csv", ///
        replace
restore

preserve
    use `validation_dynamic_focal', clear
    sort model_order term
    order model_order outcome model_code term term_role ///
        coefficient standard_error test_statistic p_value ///
        ci_lower ci_upper degrees_freedom ///
        observations countries clusters
    export delimited using ///
        "$OUTPUT_VALIDATION_DYNAMIC/dynamic_sensitivity_focal_coefficients.csv", ///
        replace
restore

display as result ///
    "Bloque 5 completo: cuatro modelos y catorce coeficientes exportados."


// *****************************************************************************
// 8. BLOQUE 6: SENSIBILIDAD DE INFERENCIA
// *****************************************************************************

// Cluster por país permanece como inferencia principal. El wild cluster
// bootstrap ya ejecutado por 04_twfe_full.do se reutiliza sin repetir 9.999
// réplicas. Driscoll--Kraay se estima una sola vez con lag(2), derivado de la
// regla Newey--West floor[4(T/100)^(2/9)] para T efectivo igual a 23.

local validation_error_tests ///
    "$OUTPUT_DIAGNOSTICS/panel_error_tests.csv"
local validation_wild_individual ///
    "$OUTPUT_ROOT/05_stability/wild_cluster_bootstrap.csv"
local validation_wild_joint ///
    "$OUTPUT_ROOT/05_stability/wild_cluster_bootstrap_joint_tests.csv"

foreach validation_inference_input in ///
    "`validation_error_tests'" ///
    "`validation_wild_individual'" ///
    "`validation_wild_joint'" {
    capture confirm file "`validation_inference_input'"
    if _rc {
        display as error ///
            "Falta una entrada de inferencia: `validation_inference_input'"
        exit 601
    }
}

capture which xtscc
if _rc {
    display as error ///
        "xtscc no está instalado; no se puede ejecutar Driscoll--Kraay."
    exit 199
}

// Validar el patrón de errores que motiva la jerarquía inferencial.
preserve
    import delimited using "`validation_error_tests'", ///
        varnames(1) clear encoding(utf8)
    assert _N == 6
    assert p_value < 0.05 if test == "Modified Wald"
    assert p_value < 0.05 if test == "Wooldridge AR(1)"
    assert p_value >= 0.05 if test == "Pesaran CD"
restore

local validation_dk_effective_t = `validation_expected_years'
local validation_dk_lag = ///
    floor(4 * (`validation_dk_effective_t' / 100)^(2 / 9))
assert `validation_dk_lag' == 2

tempfile validation_inference_generated
tempfile validation_joint_generated
tempname validation_inference_post
tempname validation_joint_post

postfile `validation_inference_post' ///
    int result_order ///
    str8 outcome ///
    str20 term ///
    str20 term_role ///
    str28 channel ///
    str24 inference_method ///
    double coefficient ///
    double standard_error ///
    double statistic ///
    double p_value ///
    double ci_lower ///
    double ci_upper ///
    str20 reference_distribution ///
    double degrees_freedom ///
    int lag_count ///
    long repetitions ///
    long observations ///
    int countries ///
    int effective_years ///
    byte serial_correlation_detected ///
    byte cross_section_dependence ///
    str16 hierarchy ///
    str80 applicability_note ///
    using `validation_inference_generated', replace

postfile `validation_joint_post' ///
    int result_order ///
    str8 outcome ///
    str40 hypothesis ///
    str24 inference_method ///
    str8 statistic_type ///
    double statistic ///
    double numerator_df ///
    double denominator_df ///
    double p_value ///
    int lag_count ///
    long repetitions ///
    long observations ///
    int countries ///
    str16 hierarchy ///
    str80 applicability_note ///
    using `validation_joint_generated', replace

local validation_inference_order = 0
local validation_joint_order = 0

foreach validation_outcome in eci divx {

    if "`validation_outcome'" == "eci" {
        local validation_regressors "$VALIDATION_ECI_REGRESSORS"
        local validation_inference_terms ///
            "rents inst c.rents#c.inst ln1p_oilpc ln1p_gaspc ln1p_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin"
        local validation_outcome_label "ECI"
    }
    else {
        local validation_regressors "$VALIDATION_DIVX_REGRESSORS"
        local validation_inference_terms ///
            "rents inst c.rents#c.inst ln1p_oilpc ln1p_gaspc ln1p_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin"
        local validation_outcome_label "DIVX"
    }

    // 8.1. Inferencia principal agrupada por país.
    quietly xtreg `validation_outcome' ///
        `validation_regressors' i.year ///
        if sample_validation == 1, ///
        fe $VALIDATION_INFERENCE_MAIN

    assert e(sample) == sample_validation
    assert e(N) == `validation_expected_n'
    assert e(N_g) == `validation_expected_countries'
    assert e(N_clust) == `validation_expected_countries'

    estimates store `validation_outcome_label'_inference_cluster
    estimates save ///
        "$OUTPUT_VALIDATION_INFERENCE/`validation_outcome_label'_inference_cluster.ster", ///
        replace

    tempname validation_cluster_rents validation_cluster_inst
    tempname validation_cluster_interaction
    scalar `validation_cluster_rents' = _b[rents]
    scalar `validation_cluster_inst' = _b[inst]
    scalar `validation_cluster_interaction' = _b[c.rents#c.inst]

    foreach validation_term of local validation_inference_terms {

        local validation_term_role "control"
        local validation_channel "economic_controls"
        if "`validation_term'" == "rents" {
            local validation_term_role "focal_exposure"
            local validation_channel "institutional_channel"
        }
        if "`validation_term'" == "inst" {
            local validation_term_role "focal_moderator"
            local validation_channel "institutional_channel"
        }
        if "`validation_term'" == "c.rents#c.inst" {
            local validation_term_role "focal_interaction"
            local validation_channel "institutional_channel"
        }
        if inlist("`validation_term'", ///
                "ln1p_oilpc", "ln1p_gaspc", "ln1p_coalpc") {
            local validation_channel "resource_composition"
        }
        if inlist("`validation_term'", "hhi", "pexp", "fexp") {
            local validation_channel "export_structure"
        }
        if inlist("`validation_term'", "vol", "rer") {
            local validation_channel "macroeconomic"
        }
        if inlist("`validation_term'", "humcap", "innov", "net") {
            local validation_channel "productive_capabilities"
        }

        tempname validation_inf_b validation_inf_se validation_inf_t
        tempname validation_inf_p validation_inf_critical
        tempname validation_inf_ci_l validation_inf_ci_u

        scalar `validation_inf_b' = _b[`validation_term']
        scalar `validation_inf_se' = _se[`validation_term']
        scalar `validation_inf_t' = ///
            `validation_inf_b' / `validation_inf_se'
        scalar `validation_inf_p' = ///
            2 * ttail(e(df_r), abs(`validation_inf_t'))
        scalar `validation_inf_critical' = invttail(e(df_r), 0.025)
        scalar `validation_inf_ci_l' = ///
            `validation_inf_b' - ///
            `validation_inf_critical' * `validation_inf_se'
        scalar `validation_inf_ci_u' = ///
            `validation_inf_b' + ///
            `validation_inf_critical' * `validation_inf_se'

        local ++validation_inference_order
        post `validation_inference_post' ///
            (`validation_inference_order') ///
            ("`validation_outcome_label'") ///
            ("`validation_term'") ///
            ("`validation_term_role'") ///
            ("`validation_channel'") ///
            ("country_cluster") ///
            (`validation_inf_b') ///
            (`validation_inf_se') ///
            (`validation_inf_t') ///
            (`validation_inf_p') ///
            (`validation_inf_ci_l') ///
            (`validation_inf_ci_u') ///
            ("t") ///
            (e(df_r)) ///
            (.) ///
            (.) ///
            (e(N)) ///
            (e(N_g)) ///
            (`validation_expected_years') ///
            (1) ///
            (0) ///
            ("MAIN") ///
            ("Handles arbitrary within-country dependence; main inference")
    }

    quietly test rents inst c.rents#c.inst
    local ++validation_joint_order
    post `validation_joint_post' ///
        (`validation_joint_order') ///
        ("`validation_outcome_label'") ///
        ("RENTS_INST_INTERACTION_JOINT_ZERO") ///
        ("country_cluster") ///
        ("F") ///
        (r(F)) ///
        (r(df)) ///
        (r(df_r)) ///
        (r(p)) ///
        (.) ///
        (.) ///
        (`validation_expected_n') ///
        (`validation_expected_countries') ///
        ("MAIN") ///
        ("Joint Wald test with country-clustered covariance")

    // 8.2. Driscoll--Kraay: mismos coeficientes FE, distinta covarianza.
    quietly xtscc `validation_outcome' ///
        `validation_regressors' i.year ///
        if sample_validation == 1, ///
        fe lag(`validation_dk_lag')

    assert e(sample) == sample_validation
    assert e(N) == `validation_expected_n'
    assert e(N_g) == `validation_expected_countries'
    assert e(lag) == `validation_dk_lag'
    assert abs(_b[rents] - `validation_cluster_rents') < 1e-8
    assert abs(_b[inst] - `validation_cluster_inst') < 1e-8
    assert abs(_b[c.rents#c.inst] - ///
        `validation_cluster_interaction') < 1e-8

    estimates store `validation_outcome_label'_inference_dk
    estimates save ///
        "$OUTPUT_VALIDATION_INFERENCE/`validation_outcome_label'_inference_dk.ster", ///
        replace

    foreach validation_term of local validation_inference_terms {

        local validation_term_role "control"
        local validation_channel "economic_controls"
        if "`validation_term'" == "rents" {
            local validation_term_role "focal_exposure"
            local validation_channel "institutional_channel"
        }
        if "`validation_term'" == "inst" {
            local validation_term_role "focal_moderator"
            local validation_channel "institutional_channel"
        }
        if "`validation_term'" == "c.rents#c.inst" {
            local validation_term_role "focal_interaction"
            local validation_channel "institutional_channel"
        }
        if inlist("`validation_term'", ///
                "ln1p_oilpc", "ln1p_gaspc", "ln1p_coalpc") {
            local validation_channel "resource_composition"
        }
        if inlist("`validation_term'", "hhi", "pexp", "fexp") {
            local validation_channel "export_structure"
        }
        if inlist("`validation_term'", "vol", "rer") {
            local validation_channel "macroeconomic"
        }
        if inlist("`validation_term'", "humcap", "innov", "net") {
            local validation_channel "productive_capabilities"
        }

        tempname validation_dk_b validation_dk_se validation_dk_t
        tempname validation_dk_p validation_dk_critical
        tempname validation_dk_ci_l validation_dk_ci_u

        scalar `validation_dk_b' = _b[`validation_term']
        scalar `validation_dk_se' = _se[`validation_term']
        scalar `validation_dk_t' = ///
            `validation_dk_b' / `validation_dk_se'
        scalar `validation_dk_p' = ///
            2 * ttail(e(df_r), abs(`validation_dk_t'))
        scalar `validation_dk_critical' = invttail(e(df_r), 0.025)
        scalar `validation_dk_ci_l' = ///
            `validation_dk_b' - ///
            `validation_dk_critical' * `validation_dk_se'
        scalar `validation_dk_ci_u' = ///
            `validation_dk_b' + ///
            `validation_dk_critical' * `validation_dk_se'

        local ++validation_inference_order
        post `validation_inference_post' ///
            (`validation_inference_order') ///
            ("`validation_outcome_label'") ///
            ("`validation_term'") ///
            ("`validation_term_role'") ///
            ("`validation_channel'") ///
            ("driscoll_kraay") ///
            (`validation_dk_b') ///
            (`validation_dk_se') ///
            (`validation_dk_t') ///
            (`validation_dk_p') ///
            (`validation_dk_ci_l') ///
            (`validation_dk_ci_u') ///
            ("t") ///
            (e(df_r)) ///
            (`validation_dk_lag') ///
            (.) ///
            (e(N)) ///
            (e(N_g)) ///
            (`validation_expected_years') ///
            (1) ///
            (0) ///
            ("SENSITIVITY") ///
            ("Large-T stress test; CD not detected and T=23 is modest")
    }

    quietly test rents inst c.rents#c.inst
    local ++validation_joint_order
    post `validation_joint_post' ///
        (`validation_joint_order') ///
        ("`validation_outcome_label'") ///
        ("RENTS_INST_INTERACTION_JOINT_ZERO") ///
        ("driscoll_kraay") ///
        ("F") ///
        (r(F)) ///
        (r(df)) ///
        (r(df_r)) ///
        (r(p)) ///
        (`validation_dk_lag') ///
        (.) ///
        (`validation_expected_n') ///
        (`validation_expected_countries') ///
        ("SENSITIVITY") ///
        ("DK joint test with lag selected by Newey-West rule")

    display as result ///
        "Bloque 6: cluster y DK para `validation_outcome_label' validados."
}

postclose `validation_inference_post'
postclose `validation_joint_post'

// 8.3. Incorporar las pruebas wild bootstrap ya verificadas por archivo 04.
preserve
    import delimited using "`validation_wild_individual'", ///
        varnames(1) clear encoding(utf8)
    assert _N == 6
    assert observations == `validation_expected_n'
    assert countries == `validation_expected_countries'
    assert repetitions == 9999

    rename model outcome
    recast str20 term
    replace term = "rents" if term == "RENTS"
    replace term = "inst" if term == "INST"
    replace term = "c.rents#c.inst" if term == "RENTS x INST"
    generate str20 term_role = "focal_exposure"
    replace term_role = "focal_moderator" if term == "inst"
    replace term_role = "focal_interaction" ///
        if term == "c.rents#c.inst"
    generate str28 channel = "institutional_channel"
    generate str24 inference_method = "wild_cluster_bootstrap"
    generate double standard_error = .
    rename statistic_value statistic
    rename bootstrap_p p_value
    generate str20 reference_distribution = "wild_bootstrap_t"
    generate double degrees_freedom = denominator_df
    generate int lag_count = .
    generate int effective_years = `validation_expected_years'
    generate byte serial_correlation_detected = 1
    generate byte cross_section_dependence = 0
    replace hierarchy = "SENSITIVITY"
    generate str80 applicability_note = ///
        "Finite-cluster sensitivity with 9999 Rademacher repetitions"
    generate int result_order = .

    keep result_order outcome term term_role channel inference_method ///
        coefficient standard_error statistic p_value ///
        ci_lower ci_upper reference_distribution degrees_freedom ///
        lag_count repetitions observations countries effective_years ///
        serial_correlation_detected cross_section_dependence ///
        hierarchy applicability_note

    tempfile validation_wild_standardized
    save `validation_wild_standardized', replace
restore

preserve
    use `validation_inference_generated', clear
    append using `validation_wild_standardized'
    sort outcome term inference_method
    replace result_order = _n
    assert _N == 72
    isid outcome term inference_method
    export delimited using ///
        "$OUTPUT_VALIDATION_INFERENCE/inference_sensitivity.csv", ///
        replace
restore

preserve
    import delimited using "`validation_wild_joint'", ///
        varnames(1) clear encoding(utf8)
    assert _N == 2
    assert observations == `validation_expected_n'
    assert countries == `validation_expected_countries'
    assert repetitions == 9999

    rename model outcome
    generate str24 inference_method = "wild_cluster_bootstrap"
    generate str8 statistic_type = "F"
    rename bootstrap_f statistic
    rename bootstrap_p p_value
    generate int lag_count = .
    replace hierarchy = "SENSITIVITY"
    generate str80 applicability_note = ///
        "Wild bootstrap joint test with 9999 Rademacher repetitions"
    generate int result_order = .

    keep result_order outcome hypothesis inference_method ///
        statistic_type statistic numerator_df denominator_df p_value ///
        lag_count repetitions observations countries ///
        hierarchy applicability_note

    tempfile validation_wild_joint_std
    save `validation_wild_joint_std', replace
restore

preserve
    use `validation_joint_generated', clear
    append using `validation_wild_joint_std'
    sort outcome inference_method
    replace result_order = _n
    assert _N == 6
    isid outcome inference_method
    export delimited using ///
        "$OUTPUT_VALIDATION_INFERENCE/inference_joint_tests.csv", ///
        replace
restore

display as result ///
    "Bloque 6 completo: cluster, wild bootstrap y DK exportados."


// *****************************************************************************
// 9. BLOQUE 7: REGISTRO INTEGRAL Y MATRIZ DE DECISIONES
// *****************************************************************************

// 9.1. Extraer todos los coeficientes sustantivos de las especificaciones.
//      Los indicadores de año permanecen en los modelos, pero se documentan
//      mediante su prueba conjunta y no como covariables sustantivas separadas.

local validation_levels_terms_eci ///
    "rents inst c.rents#c.inst ln1p_oilpc ln1p_gaspc ln1p_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin"
local validation_levels_terms_divx ///
    "rents inst c.rents#c.inst ln1p_oilpc ln1p_gaspc ln1p_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin"
local validation_fd_terms_eci ///
    "d_rents d_inst d_validation_rents_inst d_ln1p_oilpc d_ln1p_gaspc d_ln1p_coalpc d_hhi d_pexp d_fexp d_vol d_rer d_humcap d_innov d_net d_log_gdppc d_govcons d_fin"
local validation_fd_terms_divx ///
    "d_rents d_inst d_validation_rents_inst d_ln1p_oilpc d_ln1p_gaspc d_ln1p_coalpc d_pexp d_fexp d_vol d_rer d_humcap d_innov d_net d_log_gdppc d_govcons d_fin"

tempfile validation_coeff_registry
tempname validation_coeff_post

postfile `validation_coeff_post' ///
    int coefficient_order ///
    byte block_number ///
    str8 outcome ///
    str28 model_code ///
    str32 estimator ///
    str16 specification_role ///
    str24 transformation ///
    byte country_fe ///
    byte year_fe ///
    byte random_effects ///
    byte lagged_dependent ///
    str28 term ///
    str20 levels_counterpart ///
    str20 term_role ///
    str28 channel ///
    double coefficient ///
    double standard_error ///
    double test_statistic ///
    double p_value ///
    double ci_lower ///
    double ci_upper ///
    str8 reference_distribution ///
    double degrees_freedom ///
    long observations ///
    int countries ///
    str24 inference ///
    str32 sample_rule ///
    str120 estimates_file ///
    using `validation_coeff_registry', replace

local validation_coefficient_order = 0

foreach validation_outcome in eci divx {

    if "`validation_outcome'" == "eci" {
        local validation_outcome_label "ECI"
        local validation_levels_terms ///
            "`validation_levels_terms_eci'"
        local validation_fd_terms "`validation_fd_terms_eci'"
    }
    else {
        local validation_outcome_label "DIVX"
        local validation_levels_terms ///
            "`validation_levels_terms_divx'"
        local validation_fd_terms "`validation_fd_terms_divx'"
    }

    forvalues validation_registry_spec = 1/10 {

        local validation_block_number = 1
        local validation_country_fe = 0
        local validation_year_fe = 0
        local validation_random_effects = 0
        local validation_lagged_dependent = 0
        local validation_transformation "levels"
        local validation_spec_role "DIAGNOSTIC"
        local validation_estimator ""
        local validation_model_code ""
        local validation_model_file ""
        local validation_terms "`validation_levels_terms'"
        local validation_sample_rule "common_m3_1044"

        if `validation_registry_spec' == 1 {
            local validation_model_code "pooled"
            local validation_estimator "Pooled OLS"
            local validation_model_file ///
                "$OUTPUT_VALIDATION_SELECTION/`validation_outcome_label'_pooled.ster"
        }
        else if `validation_registry_spec' == 2 {
            local validation_model_code "pooled_year_fe"
            local validation_estimator "Pooled OLS with year FE"
            local validation_year_fe = 1
            local validation_model_file ///
                "$OUTPUT_VALIDATION_SELECTION/`validation_outcome_label'_pooled_year_fe.ster"
        }
        else if `validation_registry_spec' == 3 {
            local validation_model_code "country_fe"
            local validation_estimator "Country FE"
            local validation_country_fe = 1
            local validation_model_file ///
                "$OUTPUT_VALIDATION_SELECTION/`validation_outcome_label'_country_fe.ster"
        }
        else if `validation_registry_spec' == 4 {
            local validation_model_code "twfe_main"
            local validation_estimator "Country and year FE"
            local validation_country_fe = 1
            local validation_year_fe = 1
            local validation_spec_role "MAIN"
            local validation_model_file ///
                "$OUTPUT_VALIDATION_SELECTION/`validation_outcome_label'_twfe.ster"
        }
        else if `validation_registry_spec' == 5 {
            local validation_model_code "re_year_fe"
            local validation_estimator "Random effects with year FE"
            local validation_year_fe = 1
            local validation_random_effects = 1
            local validation_model_file ///
                "$OUTPUT_VALIDATION_SELECTION/`validation_outcome_label'_re_year_fe.ster"
        }
        else if `validation_registry_spec' == 6 {
            local validation_block_number = 3
            local validation_model_code "mundlak_cre"
            local validation_estimator "Mundlak correlated RE"
            local validation_year_fe = 1
            local validation_random_effects = 1
            local validation_spec_role "DIAGNOSTIC"
            local validation_model_file ///
                "$OUTPUT_VALIDATION_MUNDLAK/`validation_outcome_label'_mundlak_cre.ster"
        }
        else if `validation_registry_spec' == 7 {
            local validation_block_number = 4
            local validation_model_code "matched_sample_twfe"
            local validation_estimator "Country and year FE"
            local validation_country_fe = 1
            local validation_year_fe = 1
            local validation_spec_role "BENCHMARK"
            local validation_sample_rule "consecutive_pairs_869"
            local validation_model_file ///
                "$OUTPUT_VALIDATION_DIFFERENCES/`validation_outcome_label'_matched_twfe.ster"
        }
        else if `validation_registry_spec' == 8 {
            local validation_block_number = 4
            local validation_model_code "first_difference_year_fe"
            local validation_estimator "First-difference OLS"
            local validation_transformation "first_difference"
            local validation_year_fe = 1
            local validation_spec_role "SENSITIVITY"
            local validation_terms "`validation_fd_terms'"
            local validation_sample_rule "consecutive_pairs_869"
            local validation_model_file ///
                "$OUTPUT_VALIDATION_DIFFERENCES/`validation_outcome_label'_fd_year.ster"
        }
        else if `validation_registry_spec' == 9 {
            local validation_block_number = 5
            local validation_model_code "matched_static_twfe"
            local validation_estimator "Country and year FE"
            local validation_country_fe = 1
            local validation_year_fe = 1
            local validation_spec_role "BENCHMARK"
            local validation_sample_rule "dynamic_pairs_869"
            local validation_model_file ///
                "$OUTPUT_VALIDATION_DYNAMIC/`validation_outcome_label'_dyn_1.ster"
        }
        else {
            local validation_block_number = 5
            local validation_model_code "dynamic_fe_lag1"
            local validation_estimator "Dynamic country and year FE"
            local validation_country_fe = 1
            local validation_year_fe = 1
            local validation_lagged_dependent = 1
            local validation_spec_role "SENSITIVITY"
            local validation_sample_rule "dynamic_pairs_869"
            local validation_model_file ///
                "$OUTPUT_VALIDATION_DYNAMIC/`validation_outcome_label'_dyn_2.ster"
            local validation_terms ///
                "L.`validation_outcome' `validation_levels_terms'"
        }

        confirm file "`validation_model_file'"
        estimates use "`validation_model_file'"

        if `validation_registry_spec' <= 6 {
            assert e(N) == `validation_expected_n'
        }
        else {
            assert e(N) == `validation_dynamic_expected_n'
        }

        foreach validation_term of local validation_terms {

            local validation_base_term "`validation_term'"
            if substr("`validation_term'", 1, 2) == "d_" {
                local validation_base_term = ///
                    substr("`validation_term'", 3, ///
                    strlen("`validation_term'") - 2)
            }
            if "`validation_base_term'" == "validation_rents_inst" {
                local validation_base_term "c.rents#c.inst"
            }

            local validation_term_role "control"
            local validation_channel "economic_controls"
            if "`validation_base_term'" == "rents" {
                local validation_term_role "focal_exposure"
                local validation_channel "institutional_channel"
            }
            if "`validation_base_term'" == "inst" {
                local validation_term_role "focal_moderator"
                local validation_channel "institutional_channel"
            }
            if "`validation_base_term'" == "c.rents#c.inst" {
                local validation_term_role "focal_interaction"
                local validation_channel "institutional_channel"
            }
            if "`validation_base_term'" == "L.`validation_outcome'" {
                local validation_term_role "lagged_outcome"
                local validation_channel "dynamic_persistence"
            }
            if inlist("`validation_base_term'", ///
                    "ln1p_oilpc", "ln1p_gaspc", "ln1p_coalpc") {
                local validation_channel "resource_composition"
            }
            if inlist("`validation_base_term'", "hhi", "pexp", "fexp") {
                local validation_channel "export_structure"
            }
            if inlist("`validation_base_term'", "vol", "rer") {
                local validation_channel "macroeconomic"
            }
            if inlist("`validation_base_term'", ///
                    "humcap", "innov", "net") {
                local validation_channel "productive_capabilities"
            }

            tempname validation_reg_b validation_reg_se validation_reg_t
            tempname validation_reg_p validation_reg_critical
            tempname validation_reg_ci_l validation_reg_ci_u
            tempname validation_reg_df

            scalar `validation_reg_b' = _b[`validation_term']
            scalar `validation_reg_se' = _se[`validation_term']
            scalar `validation_reg_t' = ///
                `validation_reg_b' / `validation_reg_se'
            scalar `validation_reg_df' = .
            capture scalar `validation_reg_df' = e(df_r)

            local validation_reg_distribution "normal"
            scalar `validation_reg_p' = ///
                2 * normal(-abs(`validation_reg_t'))
            scalar `validation_reg_critical' = invnormal(0.975)
            if !missing(`validation_reg_df') {
                local validation_reg_distribution "t"
                scalar `validation_reg_p' = ///
                    2 * ttail(`validation_reg_df', abs(`validation_reg_t'))
                scalar `validation_reg_critical' = ///
                    invttail(`validation_reg_df', 0.025)
            }

            scalar `validation_reg_ci_l' = ///
                `validation_reg_b' - ///
                `validation_reg_critical' * `validation_reg_se'
            scalar `validation_reg_ci_u' = ///
                `validation_reg_b' + ///
                `validation_reg_critical' * `validation_reg_se'

            local ++validation_coefficient_order
            post `validation_coeff_post' ///
                (`validation_coefficient_order') ///
                (`validation_block_number') ///
                ("`validation_outcome_label'") ///
                ("`validation_model_code'") ///
                ("`validation_estimator'") ///
                ("`validation_spec_role'") ///
                ("`validation_transformation'") ///
                (`validation_country_fe') ///
                (`validation_year_fe') ///
                (`validation_random_effects') ///
                (`validation_lagged_dependent') ///
                ("`validation_term'") ///
                ("`validation_base_term'") ///
                ("`validation_term_role'") ///
                ("`validation_channel'") ///
                (`validation_reg_b') ///
                (`validation_reg_se') ///
                (`validation_reg_t') ///
                (`validation_reg_p') ///
                (`validation_reg_ci_l') ///
                (`validation_reg_ci_u') ///
                ("`validation_reg_distribution'") ///
                (`validation_reg_df') ///
                (e(N)) ///
                (`validation_expected_countries') ///
                ("SE clustered by country") ///
                ("`validation_sample_rule'") ///
                ("`validation_model_file'")
        }
    }
}

postclose `validation_coeff_post'

preserve
    use `validation_coeff_registry', clear
    sort coefficient_order
    assert _N == 332
    isid outcome model_code term
    export delimited using ///
        "$OUTPUT_VALIDATION_FINAL/all_substantive_coefficients.csv", ///
        replace

    bysort outcome model_code: generate int substantive_coefficients = _N
    bysort outcome model_code: keep if _n == 1
    isid outcome model_code
    assert _N == 20
    keep block_number outcome model_code estimator specification_role ///
        transformation country_fe year_fe random_effects lagged_dependent ///
        observations countries inference sample_rule ///
        substantive_coefficients estimates_file
    sort block_number outcome model_code
    export delimited using ///
        "$OUTPUT_VALIDATION_FINAL/specification_register.csv", ///
        replace
restore

// 9.2. Verificar los productos que alimentan la matriz de decisiones.
preserve
    import delimited using ///
        "$OUTPUT_VALIDATION_EFFECTS/fixed_effects_joint_tests.csv", ///
        varnames(1) clear encoding(utf8)
    assert _N == 6
    assert reject_null_5pct == 1
restore

preserve
    import delimited using ///
        "$OUTPUT_VALIDATION_MUNDLAK/hausman_mundlak_diagnostics.csv", ///
        varnames(1) clear encoding(utf8)
    assert reject_null_5pct == 1 if test_code == "mundlak_means_joint"
    assert valid_for_selection == 1 if test_code == "mundlak_means_joint"
    assert valid_for_selection == 0 if test_code == "hausman_fe_vs_re"
restore

preserve
    import delimited using ///
        "$OUTPUT_VALIDATION_STATIONARITY/stationarity_decision_matrix.csv", ///
        varnames(1) clear encoding(utf8)
    assert _N == 36
    assert model_change_authorized == 0
restore

preserve
    import delimited using ///
        "$OUTPUT_VALIDATION_DIFFERENCES/matched_sample_first_differences.csv", ///
        varnames(1) clear encoding(utf8)
    assert _N == 4
    assert analysis_observations == 869
restore

preserve
    import delimited using ///
        "$OUTPUT_VALIDATION_DYNAMIC/dynamic_sensitivity.csv", ///
        varnames(1) clear encoding(utf8)
    assert _N == 4
    assert lag_p_value < 0.05 if lagged_dependent == 1
restore

preserve
    import delimited using ///
        "$OUTPUT_VALIDATION_INFERENCE/inference_sensitivity.csv", ///
        varnames(1) clear encoding(utf8)
    assert _N == 72
    assert observations == `validation_expected_n'
restore

// 9.3. Registrar decisiones, jerarquía y acciones documentales.
tempfile validation_decision_matrix
tempname validation_decision_post

postfile `validation_decision_post' ///
    int decision_order ///
    str6 decision_id ///
    str28 domain ///
    str64 econometric_question ///
    str100 evidence_files ///
    str36 decision ///
    str16 hierarchy ///
    str100 tfm_action ///
    str36 target_sections ///
    using `validation_decision_matrix', replace

post `validation_decision_post' ///
    (1) ("D01") ("sample") ///
    ("Should estimator comparisons use a common sample?") ///
    ("sample_contract.csv; estimator_selection_summary.csv") ///
    ("KEEP_COMMON_M3_SAMPLE") ("MANDATORY") ///
    ("Report 1044 observations, 49 countries and identical ECI-DIVX sample") ///
    ("Methodology; results; appendix")

post `validation_decision_post' ///
    (2) ("D02") ("pooled_vs_panel") ///
    ("Can pooled OLS ignore country heterogeneity?") ///
    ("fixed_effects_joint_tests.csv") ///
    ("REJECT_POOLED_AS_MAIN") ("MAIN") ///
    ("Explain that country effects are jointly nonzero for both outcomes") ///
    ("Methodology; results")

post `validation_decision_post' ///
    (3) ("D03") ("time_effects") ///
    ("Are common year effects jointly relevant?") ///
    ("fixed_effects_joint_tests.csv") ///
    ("KEEP_YEAR_FIXED_EFFECTS") ("MAIN") ///
    ("Retain and report year FE in the preferred specification") ///
    ("Methodology; results")

post `validation_decision_post' ///
    (4) ("D04") ("fe_vs_re") ///
    ("Is the RE orthogonality assumption supported?") ///
    ("hausman_mundlak_diagnostics.csv") ///
    ("PREFER_FE_OVER_STANDARD_RE") ("MAIN") ///
    ("Base selection on clustered Mundlak test; flag classical Hausman caveat") ///
    ("Methodology; appendix")

post `validation_decision_post' ///
    (5) ("D05") ("main_estimator") ///
    ("Which panel estimator should remain primary?") ///
    ("estimator_selection_summary.csv; fixed_effects_joint_tests.csv; hausman_mundlak_diagnostics.csv") ///
    ("KEEP_LEVELS_TWFE_AS_MAIN") ("MAIN") ///
    ("Present country-year FE as preferred conditional-association model") ///
    ("Methodology; results")

post `validation_decision_post' ///
    (6) ("D06") ("stationarity") ///
    ("Does unit-root evidence require automatic differencing?") ///
    ("stationarity_decision_matrix.csv") ///
    ("NO_AUTOMATIC_MODEL_REPLACEMENT") ("DIAGNOSTIC") ///
    ("Report mixed level evidence and retain first differences as sensitivity") ///
    ("Methodology; limitations; appendix")

post `validation_decision_post' ///
    (7) ("D07") ("first_differences") ///
    ("Are focal findings stable in short-run changes?") ///
    ("matched_sample_first_differences.csv; matched_sample_focal_coefficients.csv") ///
    ("REPORT_TRANSFORMATION_SENSITIVITY") ("SENSITIVITY") ///
    ("Flag ECI interaction instability and stronger DIVX-RENTS evidence") ///
    ("Robustness; limitations")

post `validation_decision_post' ///
    (8) ("D08") ("dynamic_model") ///
    ("Do outcomes display conditional persistence?") ///
    ("dynamic_sensitivity.csv; dynamic_sensitivity_focal_coefficients.csv") ///
    ("REPORT_ONE_LAG_SENSITIVITY") ("SENSITIVITY") ///
    ("Report persistence and Nickell-bias caveat; do not promote dynamic FE") ///
    ("Robustness; limitations")

post `validation_decision_post' ///
    (9) ("D09") ("main_inference") ///
    ("Which covariance estimator should be primary?") ///
    ("panel_error_tests.csv; inference_sensitivity.csv") ///
    ("KEEP_COUNTRY_CLUSTER") ("MAIN") ///
    ("Use country-clustered SE for all main tables") ///
    ("Methodology; table notes")

post `validation_decision_post' ///
    (10) ("D10") ("wild_bootstrap") ///
    ("How should finite-cluster uncertainty be assessed?") ///
    ("wild_cluster_bootstrap.csv; inference_sensitivity.csv") ///
    ("KEEP_FOCAL_WILD_BOOTSTRAP") ("SENSITIVITY") ///
    ("Report 9999-repetition bootstrap only for predefined focal terms") ///
    ("Robustness; appendix")

post `validation_decision_post' ///
    (11) ("D11") ("driscoll_kraay") ///
    ("Should DK replace country clustering?") ///
    ("panel_error_tests.csv; inference_sensitivity.csv") ///
    ("KEEP_DK_AS_SECONDARY_ONLY") ("SENSITIVITY") ///
    ("Report lag(2), modest T and absence of detected cross-sectional dependence") ///
    ("Robustness; limitations")

post `validation_decision_post' ///
    (12) ("D12") ("pcse") ///
    ("Should PCSE be activated automatically?") ///
    ("panel_error_tests.csv; inference_joint_tests.csv") ///
    ("DO_NOT_ACTIVATE_PCSE") ("EXCLUDED") ///
    ("Do not add another covariance method without a distinct diagnostic need") ///
    ("Methodology")

post `validation_decision_post' ///
    (13) ("D13") ("causal_scope") ///
    ("Do these checks identify causal effects?") ///
    ("all_substantive_coefficients.csv; panel specification outputs") ///
    ("RETAIN_CONDITIONAL_ASSOCIATIONS") ("MANDATORY") ///
    ("Avoid causal language; no IV or GMM identification was introduced") ///
    ("Entire econometric chapter")

postclose `validation_decision_post'

preserve
    use `validation_decision_matrix', clear
    sort decision_order
    assert _N == 13
    isid decision_id
    export delimited using ///
        "$OUTPUT_VALIDATION_FINAL/panel_specification_decision.csv", ///
        replace
restore

display as result ///
    "Bloque 7 completo: 332 coeficientes, 20 modelos y 13 decisiones exportados."


// *****************************************************************************
// 10. BLOQUE 8: MANIFIESTO REPRODUCIBLE Y CONTRATO DE AUDITORÍA
// *****************************************************************************

// 10.1. Inventariar todos los productos analíticos de los bloques 1 a 7.
//       El manifiesto incluye sus propios metadatos para que la auditoría 99
//       pueda verificar existencia, número de filas y muestra esperada.

tempfile validation_results_manifest
tempname validation_manifest_post

postfile `validation_manifest_post' ///
    int artifact_order ///
    byte block_number ///
    str28 family ///
    str8 artifact_type ///
    str100 relative_path ///
    long expected_rows ///
    long expected_observations ///
    str16 hierarchy ///
    str120 purpose ///
    using `validation_results_manifest', replace

local validation_artifact_order = 0

// Modelos del bloque 1: cinco estimadores por resultado.
foreach validation_outcome_label in ECI DIVX {
    foreach validation_suffix in ///
            pooled pooled_year_fe country_fe twfe re_year_fe {
        local ++validation_artifact_order
        local validation_hierarchy "DIAGNOSTIC"
        if "`validation_suffix'" == "twfe" {
            local validation_hierarchy "MAIN"
        }
        post `validation_manifest_post' ///
            (`validation_artifact_order') (1) ///
            ("estimator_selection") ("STER") ///
            ("02_estimator_selection/`validation_outcome_label'_`validation_suffix'.ster") ///
            (.) (`validation_expected_n') ///
            ("`validation_hierarchy'") ///
            ("Stored estimator-selection model on the common M3 sample")
    }
}

// Modelos del bloque 2: pruebas de efectos de país, año y LM.
foreach validation_outcome_label in ECI DIVX {
    foreach validation_suffix in ///
            country_fe_test year_fe_test re_lm_test {
        local ++validation_artifact_order
        post `validation_manifest_post' ///
            (`validation_artifact_order') (2) ///
            ("fixed_effects_tests") ("STER") ///
            ("03_fixed_effects_tests/`validation_outcome_label'_`validation_suffix'.ster") ///
            (.) (`validation_expected_n') ("DIAGNOSTIC") ///
            ("Stored model underlying the panel-effects diagnostic")
    }
}

// Modelos del bloque 3: Hausman clásico y Mundlak/CRE.
foreach validation_outcome_label in ECI DIVX {
    foreach validation_suffix in ///
            hausman_fe hausman_re mundlak_cre {
        local ++validation_artifact_order
        post `validation_manifest_post' ///
            (`validation_artifact_order') (3) ///
            ("mundlak_cre") ("STER") ///
            ("04_mundlak_cre/`validation_outcome_label'_`validation_suffix'.ster") ///
            (.) (`validation_expected_n') ("DIAGNOSTIC") ///
            ("Stored model underlying the FE-versus-RE assessment")
    }
}

// Modelos del bloque 4: niveles emparejados y primeras diferencias.
foreach validation_outcome_label in ECI DIVX {
    foreach validation_suffix in matched_twfe fd_year {
        local ++validation_artifact_order
        local validation_hierarchy "BENCHMARK"
        if "`validation_suffix'" == "fd_year" {
            local validation_hierarchy "SENSITIVITY"
        }
        post `validation_manifest_post' ///
            (`validation_artifact_order') (4) ///
            ("first_differences") ("STER") ///
            ("06_first_differences/`validation_outcome_label'_`validation_suffix'.ster") ///
            (.) (`validation_dynamic_expected_n') ///
            ("`validation_hierarchy'") ///
            ("Stored matched-sample level or first-difference model")
    }
}

// Modelos del bloque 5: referencia estática y sensibilidad dinámica.
foreach validation_outcome_label in ECI DIVX {
    foreach validation_suffix in dyn_1 dyn_2 {
        local ++validation_artifact_order
        local validation_hierarchy "BENCHMARK"
        if "`validation_suffix'" == "dyn_2" {
            local validation_hierarchy "SENSITIVITY"
        }
        post `validation_manifest_post' ///
            (`validation_artifact_order') (5) ///
            ("dynamic_sensitivity") ("STER") ///
            ("07_dynamic_sensitivity/`validation_outcome_label'_`validation_suffix'.ster") ///
            (.) (`validation_dynamic_expected_n') ///
            ("`validation_hierarchy'") ///
            ("Stored static benchmark or one-lag dynamic model")
    }
}

// Modelos del bloque 6: inferencia principal y DK secundaria.
foreach validation_outcome_label in ECI DIVX {
    foreach validation_suffix in inference_cluster inference_dk {
        local ++validation_artifact_order
        local validation_hierarchy "MAIN"
        if "`validation_suffix'" == "inference_dk" {
            local validation_hierarchy "SENSITIVITY"
        }
        post `validation_manifest_post' ///
            (`validation_artifact_order') (6) ///
            ("inference_sensitivity") ("STER") ///
            ("08_inference_sensitivity/`validation_outcome_label'_`validation_suffix'.ster") ///
            (.) (`validation_expected_n') ///
            ("`validation_hierarchy'") ///
            ("Stored model for the approved inference hierarchy")
    }
}

// Archivos tabulares: rutas y filas esperadas forman el contrato de auditoría.
local validation_csv_paths ///
    "02_estimator_selection/estimator_selection_focal_coefficients.csv 02_estimator_selection/estimator_selection_summary.csv 03_fixed_effects_tests/fixed_effects_joint_tests.csv 04_mundlak_cre/hausman_mundlak_diagnostics.csv 04_mundlak_cre/mundlak_cre_focal_coefficients.csv 05_stationarity/stationarity_decision_matrix.csv 06_first_differences/first_difference_focal_coefficients.csv 06_first_differences/matched_sample_first_differences.csv 06_first_differences/matched_sample_focal_coefficients.csv 07_dynamic_sensitivity/dynamic_sensitivity_focal_coefficients.csv 07_dynamic_sensitivity/dynamic_sensitivity.csv 08_inference_sensitivity/inference_joint_tests.csv 08_inference_sensitivity/inference_sensitivity.csv 09_final/all_substantive_coefficients.csv 09_final/panel_specification_decision.csv 09_final/specification_register.csv 09_final/panel_specification_results_manifest.csv"
local validation_csv_expected_rows ///
    "30 10 6 4 6 36 6 4 12 14 4 6 72 332 13 20 51"
local validation_csv_blocks ///
    "1 1 2 3 3 4 4 4 4 5 5 6 6 7 7 7 8"
local validation_csv_families ///
    "estimator_selection estimator_selection fixed_effects_tests mundlak_cre mundlak_cre stationarity first_differences first_differences first_differences dynamic_sensitivity dynamic_sensitivity inference_sensitivity inference_sensitivity final_registry final_decisions final_registry reproducibility"
local validation_csv_hierarchies ///
    "DIAGNOSTIC DIAGNOSTIC DIAGNOSTIC DIAGNOSTIC DIAGNOSTIC DIAGNOSTIC SENSITIVITY SENSITIVITY SENSITIVITY SENSITIVITY SENSITIVITY SENSITIVITY SENSITIVITY MANDATORY MANDATORY MANDATORY MANDATORY"

local validation_csv_count : word count `validation_csv_paths'
assert `validation_csv_count' == 17

forvalues validation_csv_index = 1/`validation_csv_count' {
    local validation_csv_path : word ///
        `validation_csv_index' of `validation_csv_paths'
    local validation_csv_rows : word ///
        `validation_csv_index' of `validation_csv_expected_rows'
    local validation_csv_block : word ///
        `validation_csv_index' of `validation_csv_blocks'
    local validation_csv_family : word ///
        `validation_csv_index' of `validation_csv_families'
    local validation_csv_hierarchy : word ///
        `validation_csv_index' of `validation_csv_hierarchies'

    local ++validation_artifact_order
    post `validation_manifest_post' ///
        (`validation_artifact_order') (`validation_csv_block') ///
        ("`validation_csv_family'") ("CSV") ///
        ("`validation_csv_path'") (`validation_csv_rows') (.) ///
        ("`validation_csv_hierarchy'") ///
        ("Tabular result with an audited row-count contract")
}

postclose `validation_manifest_post'

preserve
    use `validation_results_manifest', clear
    sort artifact_order
    assert _N == 51
    isid artifact_order
    isid relative_path
    quietly count if artifact_type == "STER"
    assert r(N) == 34
    quietly count if artifact_type == "CSV"
    assert r(N) == 17
    export delimited using ///
        "$OUTPUT_VALIDATION_FINAL/panel_specification_results_manifest.csv", ///
        replace datafmt
restore

// 10.2. Confirmar que cada producto declarado existe después de la exportación.
preserve
    use `validation_results_manifest', clear
    sort artifact_order
    forvalues validation_manifest_row = 1/`=_N' {
        local validation_manifest_path = ///
            relative_path[`validation_manifest_row']
        capture confirm file ///
            "$OUTPUT_VALIDATION/`validation_manifest_path'"
        if _rc {
            display as error ///
                "Falta producto declarado: `validation_manifest_path'"
            exit 603
        }
    }
restore

display as result ///
    "Bloque 8 completo: 51 productos declarados y existentes."


// *****************************************************************************
// 11. CIERRE DEL ARCHIVO 09
// *****************************************************************************

display as result ///
    "Archivo 09: bloques 1 a 8 implementados y validados."

log close validation_log
