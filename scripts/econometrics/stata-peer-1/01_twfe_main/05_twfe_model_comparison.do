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
// Archivo: 05_twfe_model_comparison.do (Versión Peer-1)
// Contenido: Comparación formal de los modelos M1, M2 y M3 sobre muestra congelada
// Ubicación: scripts/econometrics/stata-peer-1/01_twfe_main/
// Fecha: Segundo Cuatrimestre 2026
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
set seed 20260729
set sortseed 20260729

// *****************************************************************************
// 1. Localización del Proyecto y Configuración de Directorios
// *****************************************************************************

local rel_path "data/processed/00_master_panel/master_panel_country_year.dta"
capture confirm file "`rel_path'"
if !_rc {
    // Stata ya está en la raíz
}
else {
    capture confirm file "../../../`rel_path'"
    if !_rc quietly cd "../../.."
    else {
        capture confirm file "../../`rel_path'"
        if !_rc quietly cd "../.."
        else {
            capture confirm file "../`rel_path'"
            if !_rc quietly cd ".."
            else {
                quietly cd "C:/Users/julla/GitHub/master-thesis-project-applied-econ"
            }
        }
    }
}

global PROJECT_ROOT "`c(pwd)'"
global OUTPUT_ROOT   "$PROJECT_ROOT/outputs/econometrics/stata-peer-1/01_twfe_main"
global OUTPUT_SAMPLE "$OUTPUT_ROOT/01_sample"
global OUTPUT_ECI    "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX   "$OUTPUT_ROOT/04_divx"
global OUTPUT_FINAL  "$OUTPUT_ROOT/07_final"
global OUTPUT_LOGS   "$OUTPUT_ROOT/logs"

capture mkdir "$OUTPUT_FINAL"
capture mkdir "$OUTPUT_LOGS"

log using "$OUTPUT_LOGS/05_twfe_model_comparison.log", text replace name(comp_log)

// *****************************************************************************
// 2. Carga de Muestra y Estimación de Modelos M1, M2, M3
// *****************************************************************************

use "$OUTPUT_SAMPLE/master_panel_sample.dta", clear
xtset country_id year

tempname comp_post
tempfile comp_report
postfile `comp_post' str8 outcome str8 model double rents_b double rents_se double rents_p double inter_b double inter_se double inter_p double r2_within double rmse int obs int countries using "`comp_report'", replace

// --- ECI ---

* M1 ECI
reghdfe eci c.rents##c.inst log_oilpc log_gaspc log_coalpc hhi pexp fexp log_gdppc if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
post `comp_post' ("ECI") ("M1") (_b[rents]) (_se[rents]) (2*ttail(e(df_r), abs(_b[rents]/_se[rents]))) (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) (2*ttail(e(df_r), abs(_b[c.rents#c.inst]/_se[c.rents#c.inst]))) (e(r2_within)) (e(rmse)) (e(N)) (e(N_g))

* M2 ECI
reghdfe eci c.rents##c.inst vol rer humcap innov net log_gdppc govcons fin if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
post `comp_post' ("ECI") ("M2") (_b[rents]) (_se[rents]) (2*ttail(e(df_r), abs(_b[rents]/_se[rents]))) (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) (2*ttail(e(df_r), abs(_b[c.rents#c.inst]/_se[c.rents#c.inst]))) (e(r2_within)) (e(rmse)) (e(N)) (e(N_g))

* M3 ECI
reghdfe eci c.rents##c.inst log_oilpc log_gaspc log_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin if sample_eci == 1, absorb(country_id year) vce(cluster country_id)
post `comp_post' ("ECI") ("M3") (_b[rents]) (_se[rents]) (2*ttail(e(df_r), abs(_b[rents]/_se[rents]))) (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) (2*ttail(e(df_r), abs(_b[c.rents#c.inst]/_se[c.rents#c.inst]))) (e(r2_within)) (e(rmse)) (e(N)) (e(N_g))

// --- DIVX ---

* M1 DIVX
reghdfe divx c.rents##c.inst log_oilpc log_gaspc log_coalpc pexp fexp log_gdppc if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
post `comp_post' ("DIVX") ("M1") (_b[rents]) (_se[rents]) (2*ttail(e(df_r), abs(_b[rents]/_se[rents]))) (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) (2*ttail(e(df_r), abs(_b[c.rents#c.inst]/_se[c.rents#c.inst]))) (e(r2_within)) (e(rmse)) (e(N)) (e(N_g))

* M2 DIVX
reghdfe divx c.rents##c.inst vol rer humcap innov net log_gdppc govcons fin if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
post `comp_post' ("DIVX") ("M2") (_b[rents]) (_se[rents]) (2*ttail(e(df_r), abs(_b[rents]/_se[rents]))) (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) (2*ttail(e(df_r), abs(_b[c.rents#c.inst]/_se[c.rents#c.inst]))) (e(r2_within)) (e(rmse)) (e(N)) (e(N_g))

* M3 DIVX
reghdfe divx c.rents##c.inst log_oilpc log_gaspc log_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin if sample_divx == 1, absorb(country_id year) vce(cluster country_id)
post `comp_post' ("DIVX") ("M3") (_b[rents]) (_se[rents]) (2*ttail(e(df_r), abs(_b[rents]/_se[rents]))) (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) (2*ttail(e(df_r), abs(_b[c.rents#c.inst]/_se[c.rents#c.inst]))) (e(r2_within)) (e(rmse)) (e(N)) (e(N_g))

postclose `comp_post'

// *****************************************************************************
// 3. Exportación y Visualización de la Comparación de Modelos
// *****************************************************************************

use "`comp_report'", clear
format rents_b rents_se inter_b inter_se r2_within rmse %12.6f
format rents_p inter_p %10.4f

export delimited using "$OUTPUT_FINAL/model_comparison_m1_m2_m3.csv", replace

display _newline(2)
display "=========================================================================================="
display "                  TABLA COMPARATIVA DE MODELOS TWFE (M1, M2, M3)                          "
display "=========================================================================================="
list outcome model rents_b rents_se rents_p inter_b inter_se inter_p r2_within, noobs abbreviate(20)
display "=========================================================================================="

display "Archivo 05 finalizado sin errores."

log close comp_log
