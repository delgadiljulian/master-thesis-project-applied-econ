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
// Archivo: 01_data_prep_and_diagnostics.do (Parte 1 - Secciones 1 a 4: GMM Dinámico)
// Ubicación: scripts/econometrics/stata-peer-1/gmm/
// Fecha: Segundo Cuatrimestre 2026
// *********************************************

// *********************************************
// 1. Configuración del Entorno y Rutas de Trabajo (GMM Dinámico)
// *********************************************

* Limpiar el entorno de trabajo y cerrar sesiones o registros previos
version 17.0
clear all
cls
macro drop _all
capture log close _all

* Configurar parámetros generales de ejecución, semillas y precisión numérica
set more off
set varabbrev off
set type double
set linesize 255
set seed 20260731
set sortseed 20260731

* Verificar e instalar dependencias externas necesarias desde SSC
foreach pkg in ftools reghdfe estout xtscc xttest3 xtcsd xtabond2 {
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
global DATA_MASTER   "$PROJECT_ROOT/data/processed/00_master_panel"
global PANEL_FILE    "$DATA_MASTER/master_panel_country_year.dta"

* Definir y establecer la estructura de carpetas de resultados para stata-peer-1/gmm
global OUTPUT_ROOT              "$PROJECT_ROOT/outputs/econometrics/stata-peer-1/gmm"
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

* Abrir el registro de ejecución en el archivo log de la parte 1 de GMM
log using "$OUTPUT_LOGS/01_gmm_data_prep_and_diagnostics.log", text replace name(gmm_prep_log)

* Desplegar encabezado de la Parte 1 de GMM
display as result "=========================================================="
display as result "  GMM PARTE 1: Configuración, Datos y Diagnósticos Iniciales"
display as result "=========================================================="

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
quietly count
assert r(N) == 1430
quietly levelsof country_id, local(c_check)
assert `: word count `c_check'' == 55

* Verificar la identidad contable DIVX = 1 - HHI
assert abs(divx - (1 - hhi)) <= 1e-6 if !missing(divx, hhi)

// *********************************************
// 3. Preparación de Muestra Analítica y Rezagos Dinámicos
// *********************************************

* 3.1. Evaluar asimetría y aplicar transformaciones logarítmicas log(1 + x)
tempname transform_post
tempfile transformation_report

postfile `transform_post' str12 variable long observations long zeros double zero_percent double skewness_level skewness_ln1p using "`transformation_report'", replace

foreach var in oilpc gaspc coalpc {
    quietly count if !missing(`var')
    local n_nonmissing = r(N)

    quietly count if `var' == 0
    local n_zeros = r(N)
    local zero_percent = 100 * `n_zeros' / `n_nonmissing'

    quietly summarize `var', detail
    local skewness_level = r(skewness)

    capture drop log_`var'
    gen double log_`var' = log(1 + `var') if !missing(`var')
    local var_upper = upper("`var'")
    label var log_`var' "log(1 + `var_upper')"

    quietly summarize log_`var', detail
    local skewness_ln1p = r(skewness)

    post `transform_post' ("`var'") (`n_nonmissing') (`n_zeros') (`zero_percent') (`skewness_level') (`skewness_ln1p')
}
postclose `transform_post'

* Exportar reporte de transformación de variables a CSV
preserve
    use "`transformation_report'", clear
    replace zero_percent = round(zero_percent, 0.01)
    replace skewness_level = round(skewness_level, 0.001)
    replace skewness_ln1p = round(skewness_ln1p, 0.001)
    format zero_percent %9.2f
    format skewness_level skewness_ln1p %9.3f
    sort variable
    export delimited using "$OUTPUT_DESIGN/resource_transformation_comparison_gmm.csv", replace
restore

* 3.2. Crear la variable de interacción explícita
capture drop rents_x_inst
gen double rents_x_inst = rents * inst if !missing(rents, inst)
label var rents_x_inst "RENTS x INST"

* 3.3. Construir variables dinámicas (rezagos e instrumentación para System GMM)
capture drop L_eci L_divx L_rents L_inst L_rents_x_inst
gen double L_eci            = L.eci
gen double L_divx           = L.divx
gen double L_rents          = L.rents
gen double L_inst           = L.inst
gen double L_rents_x_inst   = L.rents_x_inst

label var L_eci          "ECI (t-1)"
label var L_divx         "DIVX (t-1)"
label var L_rents        "RENTS (t-1)"
label var L_inst         "INST (t-1)"
label var L_rents_x_inst "RENTS x INST (t-1)"

* Generar primeras diferencias para diagnósticos de autocorrelación en GMM
capture drop D_eci D_divx D_rents
gen double D_eci   = D.eci
gen double D_divx  = D.divx
gen double D_rents = D.rents

label var D_eci   "D.ECI (primera diferencia)"
label var D_divx  "D.DIVX (primera diferencia)"
label var D_rents "D.RENTS (primera diferencia)"

* Definir los conjuntos de variables para cada modelo dinámico GMM
global MODEL_GMM_COMMON L_eci rents inst rents_x_inst log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin
global MODEL_GMM_ECI    eci  $MODEL_GMM_COMMON hhi
global MODEL_GMM_DIVX   divx L_divx rents inst rents_x_inst log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin

* Definir banderas para la muestra analítica completa de GMM ECI
egen n_missing_gmm_eci = rowmiss($MODEL_GMM_ECI)
gen byte sample_gmm_eci = (n_missing_gmm_eci == 0)
label var sample_gmm_eci "Flag muestra modelo GMM ECI"

* Definir banderas para la muestra analítica completa de GMM DIVX
egen n_missing_gmm_divx = rowmiss($MODEL_GMM_DIVX)
gen byte sample_gmm_divx = (n_missing_gmm_divx == 0)
label var sample_gmm_divx "Flag muestra modelo GMM DIVX"

* Generar y exportar informe de cobertura de muestra GMM por país a CSV
preserve
    collapse (sum) obs_gmm_eci=sample_gmm_eci obs_gmm_divx=sample_gmm_divx, by(country_iso3_code country country_id)
    gen int exc_gmm_eci = 25 - obs_gmm_eci
    gen int exc_gmm_divx = 25 - obs_gmm_divx
    order country_iso3_code country country_id obs_gmm_eci exc_gmm_eci obs_gmm_divx exc_gmm_divx
    sort country_iso3_code
    export delimited using "$OUTPUT_SAMPLE/sample_coverage_by_country_gmm.csv", replace
restore

* Guardar la base de datos procesada de estimación GMM
save "$OUTPUT_SAMPLE/master_panel_gmm_sample.dta", replace
display as result "Base de datos GMM guardada en: $OUTPUT_SAMPLE/master_panel_gmm_sample.dta"

// *********************************************
// 4. Estadísticas Descriptivas y Diagnósticos del Panel Dinámico (GMM)
// *********************************************

* 4.1. Cargar y verificar la base preparada para el análisis GMM
use "$OUTPUT_SAMPLE/master_panel_gmm_sample.dta", clear
xtset country_id year

* Definir vector de variables centrales para diagnóstico dinámico GMM
global GMM_DIAGNOSTIC_VARS eci L_eci divx L_divx rents inst rents_x_inst log_gdppc humcap fin

* 4.2. Estadísticas Descriptivas Sintéticas del Panel Dinámico (Resumidas y Relevantes)
tempname desc_gmm_post
tempfile desc_gmm_report

postfile `desc_gmm_post' ///
    str24 variable long observations double mean double sd ///
    double min double p50 double max ///
    using "`desc_gmm_report'", replace

foreach var of global GMM_DIAGNOSTIC_VARS {
    quietly summarize `var' if sample_gmm_eci == 1, detail
    post `desc_gmm_post' ("`var'") (r(N)) (r(mean)) (r(sd)) (r(min)) (r(p50)) (r(max))
}
postclose `desc_gmm_post'

* Guardar y exportar tabla de estadísticas descriptivas de GMM a CSV
preserve
    use "`desc_gmm_report'", clear
    format mean sd min p50 max %12.4f
    sort variable
    export delimited using "$OUTPUT_DIAGNOSTICS/descriptive_statistics_gmm.csv", replace
    display as text "--- RESUMEN DESCRIPTIVO MUESTRA GMM ---"
    list, noobs abbreviate(20)
restore

* 4.3. Descomposición de Varianza de Panel Dinámico (Within vs Between)
tempname var_gmm_post
tempfile var_gmm_report

postfile `var_gmm_post' ///
    str24 variable long observations int countries double mean ///
    double sd_overall double sd_between double sd_within double within_sd_ratio ///
    using "`var_gmm_report'", replace

foreach var of global GMM_DIAGNOSTIC_VARS {
    quietly xtsum `var' if sample_gmm_eci == 1
    local ratio = r(sd_w) / r(sd)
    post `var_gmm_post' ("`var'") (r(N)) (r(n)) (r(mean)) (r(sd)) (r(sd_b)) (r(sd_w)) (`ratio')
}
postclose `var_gmm_post'

* Guardar y exportar descomposición de varianza de panel a CSV
preserve
    use "`var_gmm_report'", clear
    format mean sd_overall sd_between sd_within within_sd_ratio %12.4f
    sort variable
    export delimited using "$OUTPUT_DIAGNOSTICS/panel_variation_gmm.csv", replace
restore

* 4.4. Correlación de Variables Dinámicas y Rezagos de Instrumentación
quietly correlate eci L_eci rents inst rents_x_inst log_gdppc humcap fin if sample_gmm_eci == 1
matrix corr_gmm = r(C)

* Exportar matriz de correlación de variables dinámicas a CSV
preserve
    clear
    svmat double corr_gmm, names(col)
    gen str24 variable = ""
    local row = 1
    foreach var in eci L_eci rents inst rents_x_inst log_gdppc humcap fin {
        replace variable = "`var'" in `row'
        local ++row
    }
    order variable
    export delimited using "$OUTPUT_DIAGNOSTICS/correlation_matrix_gmm.csv", replace
restore

* 4.5. Pruebas de Estacionariedad y Autocorrelación Serial para GMM
tempname gmm_tests_post
tempfile gmm_tests_report

postfile `gmm_tests_post' str32 test_name str24 target_variable double stat_val double p_val str40 conclusion using "`gmm_tests_report'", replace

* Prueba de autocorrelación de Wooldridge (xtserial) para ECI y DIVX
capture xtserial eci rents inst log_gdppc
if !_rc {
    post `gmm_tests_post' ("Wooldridge_AR1_Test") ("eci") (r(F)) (r(p)) ("Rechaza H0: Hay autocorrelación de primer orden")
}

* Prueba de autocorrelación de Wooldridge para DIVX
capture xtserial divx rents inst log_gdppc
if !_rc {
    post `gmm_tests_post' ("Wooldridge_AR1_Test") ("divx") (r(F)) (r(p)) ("Rechaza H0: Hay autocorrelación de primer orden")
}

* Prueba de Raíz Unitaria de Panel Fisher (Choi 2001) para ECI
capture xtunitroot fisher eci if sample_gmm_eci == 1, dfuller lags(1)
if !_rc {
    post `gmm_tests_post' ("Fisher_UnitRoot_P_Test") ("eci") (r(p)) (r(p_p)) ("Estacionariedad en niveles")
}

postclose `gmm_tests_post'

* Exportar diagnóstico dinámico de panel GMM a CSV
preserve
    use "`gmm_tests_report'", clear
    format stat_val p_val %9.4f
    export delimited using "$OUTPUT_DIAGNOSTICS/gmm_dynamic_diagnostics.csv", replace
    list, noobs abbreviate(24)
restore

* Confirmar finalización de la Parte 1 de GMM
display as result "=========================================================="
display as result "  Parte 1 (GMM Data Prep & Diagnostics) completada con éxito."
display as result "=========================================================="
log close gmm_prep_log
