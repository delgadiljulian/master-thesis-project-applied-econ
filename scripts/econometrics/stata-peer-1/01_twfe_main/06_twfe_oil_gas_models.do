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
// Archivo: 06_twfe_oil_gas_models.do (Versión Peer-1)
// Contenido: Extensión TWFE — Modelos de rentas específicas de hidrocarburos (petróleo y gas natural)
// Ubicación: scripts/econometrics/stata-peer-1/01_twfe_main/
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************


// *****************************************************************************
// 1. Inicialización del Entorno y Rutas de Trabajo
// *****************************************************************************

* Fijar la versión 17 de Stata para garantizar la compatibilidad del script.
version 17.0
* Limpiar la memoria de Stata borrando todas las variables cargadas.
clear all
* Limpiar la consola de comandos de Stata.
cls
* Eliminar todas las variables temporales y globales de la memoria.
macro drop _all
* Cerrar cualquier registro de texto (log) abierto previamente.
capture log close _all

* Configurar parámetros generales de ejecución, semillas y precisión numérica.
set more off
* Evitar que Stata abrevie nombres de variables automáticamente.
set varabbrev off
* Usar precisión doble para evitar errores de redondeo numérico.
set type double
* Ajustar el ancho de consola a 255 caracteres para ver tablas completas.
set linesize 255
* Definir la semilla pseudoaleatoria para hacer 100% reproducibles las simulaciones.
set seed 20260803
* Definir la semilla de ordenamiento para garantizar la reproducibilidad de datos.
set sortseed 20260803

* Localizar la raíz del proyecto con ruta relativa e infalible.
local rel_path "data/processed/00_master_panel/master_panel_country_year.dta"
capture confirm file "`rel_path'"
if !_rc {
    // Stata ya se encuentra en la raíz del proyecto
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
                quietly cd "C:/Users/julla/GitHub/master-thesis-project-applied-econ"
            }
        }
    }
}

* Asegurar que el directorio de trabajo activo sea la raíz del repositorio.
quietly cd "C:/Users/julla/GitHub/master-thesis-project-applied-econ"

* Definir variables globales para las rutas del repositorio en Peer-1.
global PROJECT_ROOT "C:/Users/julla/GitHub/master-thesis-project-applied-econ"
global OUTPUT_ROOT  "$PROJECT_ROOT/outputs/econometrics/stata-peer-1/01_twfe_main"
global OUTPUT_SAMPLE "$OUTPUT_ROOT/01_sample"
global OUTPUT_OG    "$OUTPUT_ROOT/10_oil_gas_models"
global OUTPUT_LOGS  "$OUTPUT_ROOT/logs"

* Crear los directorios de salida utilizando shell mkdir para compatibilidad en Windows.
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\10_oil_gas_models"
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\logs"

* Abrir el registro de ejecución de los modelos de hidrocarburos.
log using "$OUTPUT_LOGS/06_twfe_oil_gas_models.log", text replace name(og_log)

* Confirmar la presencia de la base de estimación congelada.
capture confirm file "$OUTPUT_SAMPLE/master_panel_sample.dta"
if _rc {
    display as error "Error: No se encontró $OUTPUT_SAMPLE/master_panel_sample.dta"
    exit 601
}


// *****************************************************************************
// 2. Carga de Muestra y Preparación de Variables de Hidrocarburos
// *****************************************************************************

* Cargar la base analítica congelada de 1.044 observaciones y 49 países.
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

* Generar el término de interacción entre rentas de hidrocarburos y calidad institucional si no existe.
capture gen rents_oil_gas_x_inst = rents_oil_gas * inst
label variable rents_oil_gas "Rentas de hidrocarburos (% PIB)"
label variable rents_oil_gas_x_inst "Rentas hidrocarburos x INST"


// *****************************************************************************
// 3. Estimaciones del Modelo 1 (M1) — Especificación de Hidrocarburos
// *****************************************************************************

* 3.1. Estimar M1 Hidrocarburos sobre Complejidad Económica (ECI)
reghdfe eci c.rents_oil_gas##c.inst log_oilpc log_gaspc log_coalpc hhi pexp fexp log_gdppc if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
estimates store M1_OG_ECI
local ster_path "$OUTPUT_OG/m1_og_eci.ster"
local ster_path = subinstr("`ster_path'", "/", "\", .)
estimates save "`ster_path'", replace

* 3.2. Estimar M1 Hidrocarburos sobre Diversificación Exportadora (DIVX)
reghdfe divx c.rents_oil_gas##c.inst log_oilpc log_gaspc log_coalpc pexp fexp log_gdppc if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
estimates store M1_OG_DIVX
local ster_path "$OUTPUT_OG/m1_og_divx.ster"
local ster_path = subinstr("`ster_path'", "/", "\", .)
estimates save "`ster_path'", replace


// *****************************************************************************
// 4. Estimaciones del Modelo 2 (M2) — Especificación de Hidrocarburos
// *****************************************************************************

* 4.1. Estimar M2 Hidrocarburos sobre Complejidad Económica (ECI)
reghdfe eci c.rents_oil_gas##c.inst vol rer humcap innov net log_gdppc govcons fin if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
estimates store M2_OG_ECI
local ster_path "$OUTPUT_OG/m2_og_eci.ster"
local ster_path = subinstr("`ster_path'", "/", "\", .)
estimates save "`ster_path'", replace

* 4.2. Estimar M2 Hidrocarburos sobre Diversificación Exportadora (DIVX)
reghdfe divx c.rents_oil_gas##c.inst vol rer humcap innov net log_gdppc govcons fin if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
estimates store M2_OG_DIVX
local ster_path "$OUTPUT_OG/m2_og_divx.ster"
local ster_path = subinstr("`ster_path'", "/", "\", .)
estimates save "`ster_path'", replace


// *****************************************************************************
// 5. Efectos Marginales Condicionales de Rentas de Hidrocarburos por INST
// *****************************************************************************

* Obtener percentiles observados de la calidad institucional.
quietly summarize inst if sample_eci == 1, detail
local p10 = r(p10)
local p25 = r(p25)
local p50 = r(p50)
local p75 = r(p75)
local p90 = r(p90)
local inst_vals "`p10' `p25' `p50' `p75' `p90'"
local inst_lbls "P10 P25 P50 P75 P90"

* Calcular efectos marginales de rents_oil_gas en M1 y M2 para ECI y DIVX.
tempname og_me_post
tempfile og_me_report
postfile `og_me_post' str12 model str12 outcome str4 percentile double inst_val double marginal_effect double standard_error double t_stat double p_val double ci_lower double ci_upper using "`og_me_report'", replace

* M1 ECI
estimates restore M1_OG_ECI
quietly margins, dydx(rents_oil_gas) at(inst=(`inst_vals'))
matrix M = r(table)
forvalues k = 1/5 {
    local pct : word `k' of `inst_lbls'
    local val : word `k' of `inst_vals'
    post `og_me_post' ("M1_OG") ("ECI") ("`pct'") (`val') (el(M,1,`k')) (el(M,2,`k')) (el(M,3,`k')) (el(M,4,`k')) (el(M,5,`k')) (el(M,6,`k'))
}

* M1 DIVX
estimates restore M1_OG_DIVX
quietly margins, dydx(rents_oil_gas) at(inst=(`inst_vals'))
matrix M = r(table)
forvalues k = 1/5 {
    local pct : word `k' of `inst_lbls'
    local val : word `k' of `inst_vals'
    post `og_me_post' ("M1_OG") ("DIVX") ("`pct'") (`val') (el(M,1,`k')) (el(M,2,`k')) (el(M,3,`k')) (el(M,4,`k')) (el(M,5,`k')) (el(M,6,`k'))
}

* M2 ECI
estimates restore M2_OG_ECI
quietly margins, dydx(rents_oil_gas) at(inst=(`inst_vals'))
matrix M = r(table)
forvalues k = 1/5 {
    local pct : word `k' of `inst_lbls'
    local val : word `k' of `inst_vals'
    post `og_me_post' ("M2_OG") ("ECI") ("`pct'") (`val') (el(M,1,`k')) (el(M,2,`k')) (el(M,3,`k')) (el(M,4,`k')) (el(M,5,`k')) (el(M,6,`k'))
}

* M2 DIVX
estimates restore M2_OG_DIVX
quietly margins, dydx(rents_oil_gas) at(inst=(`inst_vals'))
matrix M = r(table)
forvalues k = 1/5 {
    local pct : word `k' of `inst_lbls'
    local val : word `k' of `inst_vals'
    post `og_me_post' ("M2_OG") ("DIVX") ("`pct'") (`val') (el(M,1,`k')) (el(M,2,`k')) (el(M,3,`k')) (el(M,4,`k')) (el(M,5,`k')) (el(M,6,`k'))
}
postclose `og_me_post'

preserve
    use "`og_me_report'", clear
    format inst_val marginal_effect standard_error t_stat p_val ci_lower ci_upper %12.4f
    export delimited using "$OUTPUT_OG/og_marginal_effects_rents.csv", replace
    list, sepby(model outcome) noobs abbreviate(20)
restore


// *****************************************************************************
// 6. Pruebas de Hipótesis Conjuntas para Modelos de Hidrocarburos
// *****************************************************************************

* Evaluar la significancia conjunta del mecanismo institucional de hidrocarburos.
tempname og_test_post
tempfile og_test_report
postfile `og_test_post' str12 model str12 outcome str40 test_name double f_stat double p_val using "`og_test_report'", replace

* M1 ECI
estimates restore M1_OG_ECI
quietly test rents_oil_gas c.rents_oil_gas#c.inst
post `og_test_post' ("M1_OG") ("ECI") ("Mecanismo Hidrocarburos (rents + inter)") (r(F)) (r(p))

* M1 DIVX
estimates restore M1_OG_DIVX
quietly test rents_oil_gas c.rents_oil_gas#c.inst
post `og_test_post' ("M1_OG") ("DIVX") ("Mecanismo Hidrocarburos (rents + inter)") (r(F)) (r(p))

* M2 ECI
estimates restore M2_OG_ECI
quietly test rents_oil_gas c.rents_oil_gas#c.inst
post `og_test_post' ("M2_OG") ("ECI") ("Mecanismo Hidrocarburos (rents + inter)") (r(F)) (r(p))

* M2 DIVX
estimates restore M2_OG_DIVX
quietly test rents_oil_gas c.rents_oil_gas#c.inst
post `og_test_post' ("M2_OG") ("DIVX") ("Mecanismo Hidrocarburos (rents + inter)") (r(F)) (r(p))

postclose `og_test_post'

preserve
    use "`og_test_report'", clear
    format f_stat p_val %12.4f
    export delimited using "$OUTPUT_OG/og_joint_tests.csv", replace
    list, sepby(model) noobs abbreviate(30)
restore


// *****************************************************************************
// 7. Exportación de Tablas Formateadas en LaTeX
// *****************************************************************************

* Exportar la tabla comparativa de modelos de hidrocarburos a LaTeX.
cap which esttab
if _rc == 0 {
    esttab M1_OG_ECI M1_OG_DIVX M2_OG_ECI M2_OG_DIVX using "$OUTPUT_OG/og_models_table.tex", replace ///
        b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
        stats(N N_g r2_within F p, labels("Observaciones" "Países" "R2 Within" "Estadístico F" "p-valor F") fmt(%9.0f %9.0f %9.4f %9.3f %9.4f)) ///
        mtitles("M1 ECI" "M1 DIVX" "M2 ECI" "M2 DIVX") ///
        title("Modelos TWFE de Rentas de Hidrocarburos (Petróleo y Gas Natural)") ///
        booktabs label alignment(c)
}

* Informar en consola la finalización exitosa del script 06.
display as result "---------------------------------------------------------"
display as result "Archivo 06 finalizado: modelos de hidrocarburos completados sin errores."
display as result "Resultados guardados en: $OUTPUT_OG"
display as result "---------------------------------------------------------"

* Cerrar el archivo de registro de ejecución del script 06.
log close og_log
