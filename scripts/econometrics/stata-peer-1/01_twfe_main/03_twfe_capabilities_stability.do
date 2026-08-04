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
// Archivo: 03_twfe_capabilities_stability.do (Versión Peer-1)
// Contenido: Modelo 2 (M2) — Capacidades productivas, estabilidad macroeconómica y controles
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
set seed 20260729
* Definir la semilla de ordenamiento para garantizar la reproducibilidad de datos.
set sortseed 20260729

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

* Definir variables globales de rutas para la implementación Peer-1.
global PROJECT_ROOT        "`c(pwd)'"
global OUTPUT_ROOT         "$PROJECT_ROOT/outputs/econometrics/stata-peer-1/01_twfe_main"
global OUTPUT_SAMPLE       "$OUTPUT_ROOT/01_sample"
global OUTPUT_M2           "$OUTPUT_ROOT/09_capabilities_stability"
global OUTPUT_ECI          "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX         "$OUTPUT_ROOT/04_divx"
global OUTPUT_LOGS         "$OUTPUT_ROOT/logs"

* Crear los directorios de salida utilizando shell mkdir para compatibilidad en Windows.
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\09_capabilities_stability"
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\03_eci"
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\04_divx"
capture shell mkdir "$PROJECT_ROOT\outputs\econometrics\stata-peer-1\01_twfe_main\logs"

* Abrir el registro de ejecución de la Parte 3 (Modelo 2).
log using "$OUTPUT_LOGS/03_twfe_capabilities_stability.log", text replace name(m2_log)


// *****************************************************************************
// 2. Carga y Verificación de la Muestra Congelada
// *****************************************************************************

* Cargar la base analítica preparada previamente en el archivo 01.
use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear

* Declarar la estructura de datos de panel definiendo la variable país y año.
xtset country_id year

* Validar que la muestra analítica tenga exactamente 1.044 observaciones y 49 países.
quietly count if sample_eci == 1
assert r(N) == 1044
quietly levelsof country_id if sample_eci == 1, local(c_list)
assert `: word count `c_list'' == 49


// *****************************************************************************
// 3. Estimación del Modelo 2 (M2) — Complejidad Económica (ECI)
// *****************************************************************************

* Estimar la regresión TWFE de ECI sobre el bloque de capacidades productivas, estabilidad y controles.
reghdfe eci rents inst rents_x_inst vol rer humcap innov net log_gdppc govcons fin if sample_eci == 1, absorb(country_id year) vce(cluster country_id)

* Guardar el modelo estimado en la memoria interna de Stata.
estimates store M2_ECI

* Guardar el objeto de estimación en disco para reproducibilidad futura.
estimates save "$OUTPUT_M2/m2_eci.ster", replace
estimates save "$OUTPUT_ECI/m2_eci.ster", replace

* Evaluar la significancia conjunta del bloque de estabilidad macroeconómica.
quietly test vol rer
local f_stab_eci = r(F)
local p_stab_eci = r(p)

* Evaluar la significancia conjunta del bloque de capacidades productivas.
quietly test humcap innov net
local f_cap_eci = r(F)
local p_cap_eci = r(p)

* Evaluar la significancia conjunta del bloque fiscal y financiero.
quietly test govcons fin
local f_fisc_eci = r(F)
local p_fisc_eci = r(p)

* Evaluar la significancia conjunta del mecanismo institucional de rentas.
quietly test rents rents_x_inst
local f_rents_eci = r(F)
local p_rents_eci = r(p)

* Obtener los percentiles de calidad institucional en la muestra de estimación.
quietly summarize inst if sample_eci == 1, detail
local inst_p10 = r(p10)
local inst_p25 = r(p25)
local inst_p50 = r(p50)
local inst_p75 = r(p75)
local inst_p90 = r(p90)

* Estimar los efectos marginales de RENTS a diferentes niveles de calidad institucional.
margins if sample_eci == 1, dydx(rents) at(inst=(`inst_p10' `inst_p25' `inst_p50' `inst_p75' `inst_p90'))

* Crear tabla borrador temporal para exportar los efectos marginales de ECI en M2.
tempname me_post_eci
tempfile me_file_eci
postfile `me_post_eci' str12 outcome str12 inst_level double inst_val double dydx_rents double std_err double t_stat double p_val double ci_low double ci_high using "`me_file_eci'", replace

matrix M_eci = r(table)
local at_names "P10 P25 P50 P75 P90"
local at_vals  "`inst_p10' `inst_p25' `inst_p50' `inst_p75' `inst_p90'"

forvalues k = 1/5 {
    local lvl : word `k' of `at_names'
    local val : word `k' of `at_vals'
    local b   = M_eci[1, `k']
    local se  = M_eci[2, `k']
    local t   = M_eci[3, `k']
    local p   = M_eci[4, `k']
    local low = M_eci[5, `k']
    local high= M_eci[6, `k']
    post `me_post_eci' ("ECI") ("`lvl'") (`val') (`b') (`se') (`t') (`p') (`low') (`high')
}
postclose `me_post_eci'


// *****************************************************************************
// 4. Estimación del Modelo 2 (M2) — Diversificación Exportadora (DIVX)
// *****************************************************************************

* Estimar la regresión TWFE de DIVX sobre el bloque de capacidades productivas, estabilidad y controles.
reghdfe divx rents inst rents_x_inst vol rer humcap innov net log_gdppc govcons fin if sample_divx == 1, absorb(country_id year) vce(cluster country_id)

* Guardar el modelo estimado en la memoria interna de Stata.
estimates store M2_DIVX

* Guardar el objeto de estimación en disco para reproducibilidad futura.
estimates save "$OUTPUT_M2/m2_divx.ster", replace
estimates save "$OUTPUT_DIVX/m2_divx.ster", replace

* Evaluar la significancia conjunta del bloque de estabilidad macroeconómica.
quietly test vol rer
local f_stab_divx = r(F)
local p_stab_divx = r(p)

* Evaluar la significancia conjunta del bloque de capacidades productivas.
quietly test humcap innov net
local f_cap_divx = r(F)
local p_cap_divx = r(p)

* Evaluar la significancia conjunta del bloque fiscal y financiero.
quietly test govcons fin
local f_fisc_divx = r(F)
local p_fisc_divx = r(p)

* Evaluar la significancia conjunta del mecanismo institucional de rentas.
quietly test rents rents_x_inst
local f_rents_divx = r(F)
local p_rents_divx = r(p)

* Estimar los efectos marginales de RENTS a diferentes niveles de calidad institucional.
margins if sample_divx == 1, dydx(rents) at(inst=(`inst_p10' `inst_p25' `inst_p50' `inst_p75' `inst_p90'))

* Crear tabla borrador temporal para exportar los efectos marginales de DIVX en M2.
tempname me_post_divx
tempfile me_file_divx
postfile `me_post_divx' str12 outcome str12 inst_level double inst_val double dydx_rents double std_err double t_stat double p_val double ci_low double ci_high using "`me_file_divx'", replace

matrix M_divx = r(table)

forvalues k = 1/5 {
    local lvl : word `k' of `at_names'
    local val : word `k' of `at_vals'
    local b   = M_divx[1, `k']
    local se  = M_divx[2, `k']
    local t   = M_divx[3, `k']
    local p   = M_divx[4, `k']
    local low = M_divx[5, `k']
    local high= M_divx[6, `k']
    post `me_post_divx' ("DIVX") ("`lvl'") (`val') (`b') (`se') (`t') (`p') (`low') (`high')
}
postclose `me_post_divx'


// *****************************************************************************
// 5. Exportación de Resultados y Tablas Formateadas
// *****************************************************************************

* Consolidar y exportar la tabla de efectos marginales de RENTS en M2 a CSV.
preserve
    use "`me_file_eci'", clear
    append using "`me_file_divx'"
    format inst_val dydx_rents std_err t_stat p_val ci_low ci_high %12.4f
    export delimited using "$OUTPUT_M2/m2_marginal_effects_rents.csv", replace
    list, sepby(outcome) noobs abbreviate(20)
restore

* Crear y exportar la tabla resumen de pruebas F de significancia conjunta de M2 a CSV.
tempname ftest_post
tempfile ftest_report
postfile `ftest_post' str8 outcome str36 block double f_stat double p_val using "`ftest_report'", replace

post `ftest_post' ("ECI")  ("Estabilidad macroeconómica (VOL, RER)") (`f_stab_eci') (`p_stab_eci')
post `ftest_post' ("ECI")  ("Capacidades productivas (HUMCAP, INNOV, NET)") (`f_cap_eci')  (`p_cap_eci')
post `ftest_post' ("ECI")  ("Fiscal y financiero (GOVCONS, FIN)") (`f_fisc_eci') (`p_fisc_eci')
post `ftest_post' ("ECI")  ("Mecanismo de rentas (RENTS + RENTSxINST)") (`f_rents_eci') (`p_rents_eci')

post `ftest_post' ("DIVX") ("Estabilidad macroeconómica (VOL, RER)") (`f_stab_divx') (`p_stab_divx')
post `ftest_post' ("DIVX") ("Capacidades productivas (HUMCAP, INNOV, NET)") (`f_cap_divx')  (`p_cap_divx')
post `ftest_post' ("DIVX") ("Fiscal y financiero (GOVCONS, FIN)") (`f_fisc_divx') (`p_fisc_divx')
post `ftest_post' ("DIVX") ("Mecanismo de rentas (RENTS + RENTSxINST)") (`f_rents_divx') (`p_rents_divx')
postclose `ftest_post'

preserve
    use "`ftest_report'", clear
    format f_stat p_val %12.4f
    export delimited using "$OUTPUT_M2/m2_joint_tests.csv", replace
    list, sepby(outcome) noobs abbreviate(36)
restore

* Exportar la tabla comparativa de regresiones M2 (ECI vs DIVX) en formato LaTeX y texto.
esttab M2_ECI M2_DIVX using "$OUTPUT_M2/m2_main_table.tex", replace ///
    b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N N_g r2_within F p, labels("Observaciones" "Países" "R2 Within" "Estadístico F" "p-valor F") fmt(%9.0f %9.0f %9.4f %9.3f %9.4f)) ///
    mtitles("ECI" "DIVX") title("Modelo 2 (M2): Capacidades Productivas y Estabilidad Macroeconómica") ///
    booktabs label alignment(c)

* Informar en consola el cierre exitoso del archivo 03.
display as result "---------------------------------------------------------"
display as result "Archivo 03 finalizado: modelo 2 completado sin errores."
display as result "Resultados guardados en: $OUTPUT_M2"
display as result "---------------------------------------------------------"

* Cerrar el registro de ejecución de la Parte 3.
log close m2_log
