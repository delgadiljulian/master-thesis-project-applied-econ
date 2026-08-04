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
// Archivo: 01_data_prep_and_diagnostics.do (Parte 1 de 2 - Secciones 1 a 4)
// Ubicación: scripts/econometrics/stata-peer-1/
// Fecha: Segundo Cuatrimestre 2026
// *********************************************

// *********************************************
// 1. Configuración del Entorno y Rutas de Trabajo
// *********************************************

* Limpiar el entorno de trabajo y cerrar sesiones o registros previos
version 17.0
* Limpiar la memoria de Stata borrando todas las variables cargadas.
clear all
* Limpiar la consola de comandos de Stata.
cls
* Eliminar todas las variables temporales y globales de la memoria.
macro drop _all
* Cerrar cualquier registro de texto (log) abierto previamente.
capture log close _all

* Configurar parámetros generales de ejecución, semillas y precisión numérica
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

* Verificar e instalar dependencias externas necesarias desde SSC
foreach pkg in ftools reghdfe estout xtscc xttest3 xtcsd {
    capture which `pkg'
    if _rc {
        capture ssc install `pkg'
    }
}

* Comprobar e instalar paquete de autocorrelación serial xtserial si falta
capture which xtserial
if _rc {
    capture net install st0039, from("https://www.stata-journal.com/software/sj3-2")
}

* Localizar dinámicamente la raíz del proyecto con fallback absoluto infalible
local rel_path "data/processed/00_master_panel/master_panel_country_year.dta"

* Validar la integridad de los datos
capture confirm file "`rel_path'"
if !_rc {
    // Stata ya se encuentra en la raíz del proyecto
}
else {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "../../../`rel_path'"
    if !_rc {
        quietly cd "../../.."
    }
    else {
        * Verificar la existencia de un archivo antes de intentar cargarlo.
        capture confirm file "../../`rel_path'"
        if !_rc {
            quietly cd "../.."
        }
        else {
            * Verificar la existencia de un archivo antes de intentar cargarlo.
            capture confirm file "../`rel_path'"
            if !_rc {
                quietly cd ".."
            }
            else {
                // Ruta absoluta predeterminada del repositorio
                local abs_path "C:/Users/julla/GitHub/master-thesis-project-applied-econ/`rel_path'"
                * Verificar la existencia de un archivo antes de intentar cargarlo.
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
global DATA_MASTER   "$PROJECT_ROOT/data/processed/00_master_panel"
global PANEL_FILE    "$DATA_MASTER/master_panel_country_year.dta"

* Definir y establecer la estructura de carpetas de resultados para stata-peer-1
global OUTPUT_ROOT              "$PROJECT_ROOT/outputs/econometrics/stata-peer-1/01_twfe_main"
global OUTPUT_DESIGN            "$OUTPUT_ROOT/00_design"
global OUTPUT_SAMPLE            "$OUTPUT_ROOT/01_sample"
global OUTPUT_DIAGNOSTICS       "$OUTPUT_ROOT/02_diagnostics"
global OUTPUT_ECI               "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX              "$OUTPUT_ROOT/04_divx"
global OUTPUT_STABILITY         "$OUTPUT_ROOT/05_stability"
global OUTPUT_RESOURCE_DISAGG   "$OUTPUT_ROOT/06_resource_disaggregation"
global OUTPUT_FINAL             "$OUTPUT_ROOT/07_final"
global OUTPUT_LOGS              "$OUTPUT_ROOT/logs"

* Crear los directorios de salida en el sistema
capture mkdir "$PROJECT_ROOT/outputs"
capture mkdir "$PROJECT_ROOT/outputs/econometrics"
capture mkdir "$OUTPUT_ROOT"
capture mkdir "$OUTPUT_DESIGN"
capture mkdir "$OUTPUT_SAMPLE"
capture mkdir "$OUTPUT_DIAGNOSTICS"
capture mkdir "$OUTPUT_ECI"
capture mkdir "$OUTPUT_DIVX"
capture mkdir "$OUTPUT_STABILITY"
capture mkdir "$OUTPUT_RESOURCE_DISAGG"
capture mkdir "$OUTPUT_FINAL"
capture mkdir "$OUTPUT_LOGS"

* Abrir el registro de ejecución en el archivo log de la parte 1
log using "$OUTPUT_LOGS/01_data_prep_and_diagnostics.log", text replace name(prep_log)

// *********************************************
// 2. Carga y Validación del Panel Maestro
// *********************************************

* Cargar la base de datos maestra
use "$PANEL_FILE", clear

* Estandarizar nombres de variables a minúsculas
rename *, lower

* Etiquetar variables de la base de datos para presentación en tablas
label var eci                  "Complejidad económica (ECI)"
label var divx                 "Diversificación exportadora (DIVX = 1 - HHI)"
label var rents                "Rentas extractivas del subsuelo (% PIB)"
label var inst                 "Calidad institucional (INST)"
label var rents_x_inst         "RENTS x INST"
label var oilpc                "Renta petrolera per cápita (USD/hab)"
label var gaspc                "Renta gasífera per cápita (USD/hab)"
label var coalpc               "Renta carbonífera per cápita (USD/hab)"
label var hhi                  "Concentración exportadora (HHI)"
label var pexp                 "Exp. primarias no energéticas (% exp. merc.)"
label var fexp                 "Exp. combustibles (% exp. merc.)"
label var vol                  "Volatilidad términos de intercambio (VOL)"
label var rer                  "Tipo de cambio real (log pl_gdpo)"
label var humcap               "Capital humano (Índice retornos)"
label var innov                "Innovación (log 1 + art. científ./millón hab)"
label var net                  "Conectividad digital (% pob. internet)"
label var log_gdppc            "Nivel de desarrollo (log PIB pc PPA)"
label var govcons              "Consumo del gobierno (% PIB)"
label var fin                  "Profundidad financiera (Crédito bancario % PIB)"

* Crear el identificador numérico del país para la estructura de panel
capture confirm new variable country_id
if !_rc {
    encode country_iso3_code, generate(country_id)
    label var country_id "Identificador numérico de país"
}

* Mover la variable country_id a la tercera columna del dataset
capture confirm variable country
if !_rc {
    order country_id, after(country)
}
else {
    order country_id, after(country_iso3_code)
}

* Establecer la estructura de datos de panel
xtset country_id year

* Verificar dimensiones exactas y unicidad de la llave país-año
assert !missing(country_iso3_code) & !missing(year)
assert strlen(country_iso3_code) == 3
* Contar silenciosamente cuántas observaciones cumplen una condición determinada.
quietly count
assert r(N) == 1430
quietly levelsof country_id, local(c_check)
assert `: word count `c_check'' == 55

* Verificar la identidad contable DIVX = 1 - HHI
assert abs(divx - (1 - hhi)) <= 1e-6 if !missing(divx, hhi)

// *********************************************
// 3. Preparación de Datos y Muestras Analíticas
// *********************************************

* 3.1. Evaluar asimetría y aplicar transformaciones logarítmicas log(1 + x)
tempname transform_post
tempfile transformation_report

* Definir estructura del postfile de transformaciones logarítmicas
postfile `transform_post' str12 variable long observations long zeros double zero_percent double skewness_level skewness_ln1p using "`transformation_report'", replace

* Iterar sobre las variables per cápita para aplicar transformaciones log(1+x)
foreach var in oilpc gaspc coalpc {
    * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
    quietly count if !missing(`var')
    local n_nonmissing = r(N)

    // Evaluar condición de control de flujo
    quietly count if `var' == 0
    local n_zeros = r(N)
    local zero_percent = 100 * `n_zeros' / `n_nonmissing'

    // Ejecutar la siguiente instrucción del bloque
    quietly summarize `var', detail
    local skewness_level = r(skewness)

    // Ejecutar la siguiente instrucción del bloque
    capture drop log_`var'
    gen double log_`var' = log(1 + `var') if !missing(`var')
    local var_upper = upper("`var'")
    label var log_`var' "log(1 + `var_upper')"

    // Ejecutar la siguiente instrucción del bloque
    quietly summarize log_`var', detail
    local skewness_ln1p = r(skewness)

    // Ejecutar la siguiente instrucción del bloque
    post `transform_post' ("`var'") (`n_nonmissing') (`n_zeros') (`zero_percent') (`skewness_level') (`skewness_ln1p')
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `transform_post'

* Exportar la tabla comparativa de transformaciones logarítmicas a CSV
preserve
    use "`transformation_report'", clear
    replace zero_percent = round(zero_percent, 0.01)
    replace skewness_level = round(skewness_level, 0.001)
    replace skewness_ln1p = round(skewness_ln1p, 0.001)
    format zero_percent %9.2f
    format skewness_level skewness_ln1p %9.3f
    sort variable
    export delimited using "$OUTPUT_DESIGN/resource_transformation_comparison.csv", replace
    list, noobs abbreviate(20)
restore

* Crear la variable de interacción explícita
capture drop log_rents_x_inst
gen double log_rents_x_inst = rents * inst
label var log_rents_x_inst "RENTS x INST"

* Definir los conjuntos de variables para cada modelo
global MODEL_COMMON rents inst rents_x_inst log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin
global MODEL_ECI    eci  $MODEL_COMMON hhi
global MODEL_DIVX   divx $MODEL_COMMON

* Definir banderas para la muestra analítica completa de ECI (Complete Case Analysis)
egen n_missing_eci = rowmiss($MODEL_ECI)
gen byte sample_eci = (n_missing_eci == 0)
label var sample_eci "Flag muestra modelo ECI (con HHI)"

* Definir banderas para la muestra analítica completa de DIVX (Complete Case Analysis)
egen n_missing_divx = rowmiss($MODEL_DIVX)
gen byte sample_divx = (n_missing_divx == 0)
label var sample_divx "Flag muestra modelo DIVX (sin HHI)"

* Generar e exportar informe de cobertura de muestra por país a CSV
preserve
    collapse (sum) obs_eci=sample_eci obs_divx=sample_divx, by(country_iso3_code country country_id)
    gen int exc_eci = 26 - obs_eci
    gen int exc_divx = 26 - obs_divx
    order country_iso3_code country country_id obs_eci exc_eci obs_divx exc_divx
    sort country_iso3_code
    export delimited using "$OUTPUT_SAMPLE/sample_coverage_by_country.csv", replace
restore

* Guardar la base de datos procesada de estimación
save "$OUTPUT_SAMPLE/master_panel_sample.dta", replace

// *********************************************
// 4. Estadísticas Descriptivas y Diagnósticos Avanzados
// *********************************************

* 4.1. Cargar y verificar la base preparada para el análisis
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
* Declarar la estructura de panel definiendo la variable país y año.
xtset country_id year

* Definir vector global de variables para diagnóstico
global DIAGNOSTIC_VARS eci divx rents inst rents_x_inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin

* 4.2. Generar y exportar estadísticas descriptivas (Panel Completo vs Muestra Estimación)
tempname descriptive_post
tempfile descriptive_report

* Definir estructura del postfile de estadísticas descriptivas
postfile `descriptive_post' ///
    str16 analysis_sample str24 variable ///
    long observations long zeros double zero_percent ///
    double mean sd min p25 median p75 max ///
    using "`descriptive_report'", replace

* Iterar sobre muestras y variables para calcular descriptivos
foreach analysis_sample in PANEL_COMPLETE ESTIMATION {
    foreach var of global DIAGNOSTIC_VARS {
        local restriction "!missing(`var')"
        if "`analysis_sample'" == "ESTIMATION" {
            local restriction "sample_eci == 1 & !missing(`var')"
        }

        // Evaluar condición de control de flujo
        quietly count if `restriction'
        local n_available = r(N)

        // Evaluar condición de control de flujo
        quietly count if `restriction' & `var' == 0
        local n_zeros = r(N)
        local zero_share = 100 * `n_zeros' / `n_available'

        // Evaluar condición de control de flujo
        quietly summarize `var' if `restriction', detail
        post `descriptive_post' ///
            ("`analysis_sample'") ("`var'") ///
            (`n_available') (`n_zeros') (`zero_share') ///
            (r(mean)) (r(sd)) (r(min)) (r(p25)) ///
            (r(p50)) (r(p75)) (r(max))
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `descriptive_post'

* Exportar el reporte de estadísticas descriptivas a CSV
preserve
    use "`descriptive_report'", clear
    replace zero_percent = round(zero_percent, 0.01)
    format zero_percent %9.2f
    format mean sd min p25 median p75 max %12.4f
    sort analysis_sample variable
    export delimited using "$OUTPUT_DIAGNOSTICS/descriptive_statistics.csv", replace
    list, sepby(analysis_sample) noobs abbreviate(20)
restore

* 4.3. Descomposición de Varianza de Panel (Overall, Between y Within)
tempname variation_post
tempfile variation_report

* Definir estructura del postfile de descomposición de varianza panel
postfile `variation_post' ///
    str24 variable long observations int countries ///
    double average_periods mean ///
    double sd_overall sd_between sd_within within_sd_ratio ///
    using "`variation_report'", replace

* Iterar sobre variables para descomponer varianzas con xtsum
foreach var of global DIAGNOSTIC_VARS {
    quietly xtsum `var' if sample_eci == 1
    local within_ratio = r(sd_w) / r(sd)
    post `variation_post' ///
        ("`var'") (r(N)) (r(n)) (r(Tbar)) (r(mean)) ///
        (r(sd)) (r(sd_b)) (r(sd_w)) (`within_ratio')
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `variation_post'

* Exportar reporte de descomposición de varianza a CSV
preserve
    use "`variation_report'", clear
    format average_periods mean sd_overall sd_between sd_within within_sd_ratio %12.4f
    sort variable
    export delimited using "$OUTPUT_DIAGNOSTICS/panel_variation.csv", replace
    list, noobs abbreviate(24)
restore

* 4.4. Matriz de Correlaciones para la especificación ECI
quietly correlate $MODEL_ECI if sample_eci == 1
matrix correlation_eci = r(C)

* Convertir la matriz de correlaciones de ECI a dataset y exportarla a CSV
preserve
    clear
    svmat double correlation_eci, names(col)
    gen str24 variable = ""
    local row_number = 1
    foreach var of global MODEL_ECI {
        replace variable = "`var'" in `row_number'
        local ++row_number
    }
    order variable
    export delimited using "$OUTPUT_DIAGNOSTICS/correlation_matrix_eci.csv", replace
restore

* Calcular matriz de correlaciones para la especificación DIVX
quietly correlate $MODEL_DIVX if sample_divx == 1
matrix correlation_divx = r(C)

* Convertir la matriz de correlaciones de DIVX a dataset y exportarla a CSV
preserve
    clear
    svmat double correlation_divx, names(col)
    gen str24 variable = ""
    local row_number = 1
    foreach var of global MODEL_DIVX {
        replace variable = "`var'" in `row_number'
        local ++row_number
    }
    order variable
    export delimited using "$OUTPUT_DIAGNOSTICS/correlation_matrix_divx.csv", replace
restore

* 4.5. Colinealidad Within (Residualización por Efectos Fijos de País y Año + VIF)
tempname vif_post
tempfile vif_report

* Definir estructura del postfile VIF
postfile `vif_post' ///
    str8 model str24 variable double vif str12 assessment ///
    using "`vif_report'", replace

* Definir lista de regresores para el modelo ECI
local regressors_eci "$MODEL_COMMON hhi"

* Obtener residuos Within para los regresores de ECI
foreach var of local regressors_eci {
    capture drop within_`var'
    quietly regress `var' i.country_id i.year if sample_eci == 1
    predict double within_`var' if e(sample), residuals
}

* Estimar regresiones auxiliares de VIF Within para ECI
foreach target of local regressors_eci {
    local remaining : list regressors_eci - target
    local within_remaining ""
    foreach var of local remaining {
        local within_remaining "`within_remaining' within_`var'"
    }
    quietly regress within_`target' `within_remaining' if sample_eci == 1
    local vif_value = 1 / (1 - e(r2))
    local vif_assessment "LOW"
    if `vif_value' >= 5  local vif_assessment "REVIEW"
    if `vif_value' >= 10 local vif_assessment "HIGH"
    post `vif_post' ("ECI") ("`target'") (`vif_value') ("`vif_assessment'")
}

* Definir lista de regresores para el modelo DIVX
local regressors_divx "$MODEL_COMMON"

* Estimar regresiones auxiliares de VIF Within para DIVX
foreach target of local regressors_divx {
    local remaining : list regressors_divx - target
    local within_remaining ""
    foreach var of local remaining {
        local within_remaining "`within_remaining' within_`var'"
    }
    quietly regress within_`target' `within_remaining' if sample_divx == 1
    local vif_value = 1 / (1 - e(r2))
    local vif_assessment "LOW"
    if `vif_value' >= 5  local vif_assessment "REVIEW"
    if `vif_value' >= 10 local vif_assessment "HIGH"
    post `vif_post' ("DIVX") ("`target'") (`vif_value') ("`vif_assessment'")
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `vif_post'

* Exportar tabla resumen VIF por modelo a CSV
preserve
    use "`vif_report'", clear
    gsort model -vif
    format vif %12.4f
    export delimited using "$OUTPUT_DIAGNOSTICS/vif_by_model.csv", replace
    list, sepby(model) noobs abbreviate(24)
restore

* Limpiar variables temporales de residuos Within creadas en memoria
foreach var of local regressors_eci {
    capture drop within_`var'
}

* 4.6. Pruebas de Especificación de la Estructura de Errores (Heterocedasticidad, Autocorrelación y Dependencia Transversal)
tempname tests_post
tempfile tests_report

* Definir estructura del postfile de pruebas de errores de panel
postfile `tests_post' str8 model str32 test str80 null_hypothesis double statistic df1 df2 p_value str20 decision using "`tests_report'", replace

* Ejecutar diagnósticos estadísticos de errores por modelo
foreach model in ECI DIVX {
    local dependent "eci"
    local regressors "$MODEL_COMMON hhi"
    local sample_flag "sample_eci"

    // Evaluar condición de control de flujo
    if "`model'" == "DIVX" {
        local dependent "divx"
        local regressors "$MODEL_COMMON"
        local sample_flag "sample_divx"
    }

    // Evaluar condición de control de flujo
    quietly xtreg `dependent' `regressors' i.year if `sample_flag' == 1, fe
    cap xttest3
    if _rc == 0 {
        local hetero_stat = r(wald)
        local hetero_df   = r(df)
        local hetero_p    = r(p)
        local hetero_decision "DO NOT REJECT H0"
        if `hetero_p' < 0.05 local hetero_decision "REJECT H0"
        post `tests_post' ("`model'") ("Modified Wald") ("Equal error variance across countries") (`hetero_stat') (`hetero_df') (.) (`hetero_p') ("`hetero_decision'")
    }

    // Evaluar condición de control de flujo
    cap xtserial `dependent' `regressors' if `sample_flag' == 1
    if _rc == 0 {
        local serial_stat = r(F)
        local serial_df1  = r(df)
        local serial_df2  = r(df_r)
        local serial_p    = r(p)
        local serial_decision "DO NOT REJECT H0"
        if `serial_p' < 0.05 local serial_decision "REJECT H0"
        post `tests_post' ("`model'") ("Wooldridge AR(1)") ("No first-order serial correlation") (`serial_stat') (`serial_df1') (`serial_df2') (`serial_p') ("`serial_decision'")
    }

    // Evaluar condición de control de flujo
    quietly xtreg `dependent' `regressors' i.year if `sample_flag' == 1, fe
    cap xtcsd, pesaran abs
    if _rc == 0 {
        local cd_stat = r(pesaran)
        local cd_p = 2 * normal(-abs(`cd_stat'))
        local cd_decision "DO NOT REJECT H0"
        if `cd_p' < 0.05 local cd_decision "REJECT H0"
        post `tests_post' ("`model'") ("Pesaran CD") ("Cross-sectional independence of residuals") (`cd_stat') (.) (.) (`cd_p') ("`cd_decision'")
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `tests_post'

* Exportar resultados de las pruebas de errores a CSV
preserve
    use "`tests_report'", clear
    format statistic p_value %12.6f
    sort model test
    export delimited using "$OUTPUT_DIAGNOSTICS/panel_error_tests.csv", replace
    list, sepby(model) noobs abbreviate(24)
restore

* 4.7. Identificación de Observaciones Influyentes (Leverage, Cook's Distance y Residuos Estandarizados)
tempfile influence_eci influence_divx

* Calcular métricas de influencia y apalancamiento para el modelo ECI
preserve
    quietly regress eci $MODEL_COMMON hhi i.country_id i.year if sample_eci == 1
    local influence_n = e(N)
    local influence_k = e(df_m) + 1
    local leverage_threshold = 2 * `influence_k' / `influence_n'
    local cooks_threshold = 4 / `influence_n'

    * Evaluar condición de control de flujo
    predict double leverage if e(sample), hat
    predict double cooks_distance if e(sample), cooksd
    predict double standardized_residual if e(sample), rstandard

    * Evaluar condición de control de flujo
    generate byte flag_leverage = leverage > `leverage_threshold' if e(sample)
    generate byte flag_cooks = cooks_distance > `cooks_threshold' if e(sample)
    generate byte flag_residual = abs(standardized_residual) > 3 if e(sample)

    * Evaluar condición de control de flujo
    keep if e(sample) & (flag_leverage == 1 | flag_cooks == 1 | flag_residual == 1)

    * Ejecutar la siguiente instrucción del bloque
    generate str8 model = "ECI"
    generate double dependent_value = eci
    generate double leverage_cutoff = `leverage_threshold'
    generate double cooks_cutoff = `cooks_threshold'

    * Ejecutar la siguiente instrucción del bloque
    keep model country_iso3_code country country_id year dependent_value leverage leverage_cutoff cooks_distance cooks_cutoff standardized_residual flag_leverage flag_cooks flag_residual
    save "`influence_eci'", replace
restore

* Calcular métricas de influencia y apalancamiento para el modelo DIVX
preserve
    quietly regress divx $MODEL_COMMON i.country_id i.year if sample_divx == 1
    local influence_n = e(N)
    local influence_k = e(df_m) + 1
    local leverage_threshold = 2 * `influence_k' / `influence_n'
    local cooks_threshold = 4 / `influence_n'

    * Evaluar condición de control de flujo
    predict double leverage if e(sample), hat
    predict double cooks_distance if e(sample), cooksd
    predict double standardized_residual if e(sample), rstandard

    * Evaluar condición de control de flujo
    generate byte flag_leverage = leverage > `leverage_threshold' if e(sample)
    generate byte flag_cooks = cooks_distance > `cooks_threshold' if e(sample)
    generate byte flag_residual = abs(standardized_residual) > 3 if e(sample)

    * Evaluar condición de control de flujo
    keep if e(sample) & (flag_leverage == 1 | flag_cooks == 1 | flag_residual == 1)

    * Ejecutar la siguiente instrucción del bloque
    generate str8 model = "DIVX"
    generate double dependent_value = divx
    generate double leverage_cutoff = `leverage_threshold'
    generate double cooks_cutoff = `cooks_threshold'

    * Ejecutar la siguiente instrucción del bloque
    keep model country_iso3_code country country_id year dependent_value leverage leverage_cutoff cooks_distance cooks_cutoff standardized_residual flag_leverage flag_cooks flag_residual
    save "`influence_divx'", replace
restore

* Consolidar y exportar alertas de observaciones influyentes a CSV
preserve
    use "`influence_eci'", clear
    append using "`influence_divx'"
    gsort model -cooks_distance
    format leverage leverage_cutoff cooks_distance cooks_cutoff standardized_residual %12.6f
    export delimited using "$OUTPUT_DIAGNOSTICS/influential_observations.csv", replace
    list, sepby(model) noobs abbreviate(20)
restore

* Informar en consola la finalización exitosa de la Parte 1
display as result "---------------------------------------------------------"
display as result "Parte 1 (Secciones 1 a 4) completada con éxito en stata-peer-1."
display as result "Base guardada en: $OUTPUT_SAMPLE/master_panel_sample.dta"
display as result "---------------------------------------------------------"

* Cerrar el archivo de registro de ejecución de la Parte 1
log close prep_log
