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
// Archivo: 08_twfe_resource_disaggregated_full.do (Versión Codex)
// Ubicación: scripts/econometrics/stata-peer-2/01_twfe_main/
// Contenido: Secciones 19 a 24 del análisis econométrico desagregado
// Extensión: Desagregación de RENTS entre Hidrocarburos y Minería
// Requisito operativo: ejecutar 01 y 04; 06 y 07 son modelos previos
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************


// *****************************************************************************
// INICIALIZACIÓN DEL ARCHIVO 08
// *****************************************************************************

// B.1. Limpiar la sesión y fijar el entorno reproducible

* Configurar versión de Stata 17.0, limpiar memoria y establecer semilla estandarizada.
version 17.0
* Limpiar la memoria de Stata borrando todas las variables cargadas.
clear all
* Limpiar la consola de comandos de Stata.
cls
* Eliminar todas las variables temporales y globales de la memoria.
macro drop _all
* Cerrar cualquier registro de texto (log) abierto previamente.
capture log close _all

* Ejecutar la siguiente instrucción del bloque.
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


// B.2. Localizar la raíz del proyecto

* Definir el panel maestro como marcador y las rutas alternativas del repositorio.
local project_marker "data/processed/00_master_panel/master_panel_country_year.dta"
local project_current "`c(pwd)'"
local project_windows "C:/Users/`c(username)'/GitHub/master-thesis-project-applied-econ"
local project_manual ""
global PROJECT_ROOT ""

* Buscar dinámicamente hasta 8 niveles superiores y validar la ubicación del proyecto.
local project_candidate "`project_current'"
forvalues search_level = 0/8 {
    if "$PROJECT_ROOT" == "" {
        * Verificar la existencia de un archivo antes de intentar cargarlo.
        capture confirm file "`project_candidate'/`project_marker'"
        if !_rc {
            quietly cd "`project_candidate'"
            global PROJECT_ROOT "`c(pwd)'"
        }
    }
    local project_candidate "`project_candidate'/.."
}

* Probar la ruta estándar de Windows si la búsqueda ascendente no encuentra el repositorio.
if "$PROJECT_ROOT" == "" {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "`project_windows'/`project_marker'"
    if !_rc {
        global PROJECT_ROOT "`project_windows'"
    }
}

* Probar la ruta manual únicamente cuando haya sido definida por el usuario.
if "$PROJECT_ROOT" == "" & "`project_manual'" != "" {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "`project_manual'/`project_marker'"
    if !_rc {
        global PROJECT_ROOT "`project_manual'"
    }
}

* Detener la ejecución si ninguna ruta candidata contiene el panel maestro.
if "$PROJECT_ROOT" == "" {
    display as error "No se pudo localizar la raíz del repositorio."
    display as error "Edite local project_manual en la inicialización."
    exit 601
}

* Fijar la raíz validada como directorio de trabajo para el resto del archivo.
quietly cd "$PROJECT_ROOT"
display as result "Raíz del proyecto localizada correctamente:"
pwd

* Cargar rutinas compartidas para los contratos esenciales de estimación.
do "scripts/econometrics/stata-peer-2/01_twfe_main/00_validation_helpers.do"


// B.3. Definir las entradas, salidas y el log del archivo 08

* Definir las rutas globales del proyecto para la versión stata-peer-2.
global OUTPUT_ROOT               "$PROJECT_ROOT/outputs/econometrics/stata-peer-2/01_twfe_main"
global OUTPUT_DESIGN             "$OUTPUT_ROOT/00_design"
global OUTPUT_SAMPLE             "$OUTPUT_ROOT/01_sample"
global OUTPUT_DIAGNOSTICS        "$OUTPUT_ROOT/02_diagnostics"
global OUTPUT_ECI                "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX               "$OUTPUT_ROOT/04_divx"
global OUTPUT_DISAGG             "$OUTPUT_ROOT/07_resource_disaggregation"
global OUTPUT_DISAGG_DESIGN      "$OUTPUT_DISAGG/00_design"
global OUTPUT_DISAGG_DIAGNOSTICS "$OUTPUT_DISAGG/01_diagnostics"
global OUTPUT_DISAGG_ECI         "$OUTPUT_DISAGG/02_eci"
global OUTPUT_DISAGG_DIVX        "$OUTPUT_DISAGG/03_divx"
global OUTPUT_DISAGG_STABILITY   "$OUTPUT_DISAGG/04_stability"
global OUTPUT_DISAGG_EXPORTS     "$OUTPUT_DISAGG/05_exports"
global OUTPUT_DISAGG_LOGS        "$OUTPUT_DISAGG/logs"
global ADO_PROJECT               "$OUTPUT_ROOT/ado"

* Crear la estructura de directorios requeridos si no existen.
capture mkdir "$PROJECT_ROOT/outputs"
capture mkdir "$PROJECT_ROOT/outputs/econometrics"
capture mkdir "$OUTPUT_ROOT"
capture mkdir "$OUTPUT_DISAGG"
capture mkdir "$OUTPUT_DISAGG_DESIGN"
capture mkdir "$OUTPUT_DISAGG_DIAGNOSTICS"
capture mkdir "$OUTPUT_DISAGG_LOGS"
capture mkdir "$ADO_PROJECT"
capture mkdir "$ADO_PROJECT/plus"

* Habilitar desde la inicialización las dependencias locales del proyecto.
adopath ++ "$ADO_PROJECT/plus"

* Iniciar el archivo de registro de ejecución para el script 08.
log using "$OUTPUT_DISAGG_LOGS/08_twfe_resource_disaggregated_full.log", text replace name(disaggregation_log)

* Verificar antes de los diagnósticos que las pruebas temporales estén disponibles.
foreach command in xttest3 xtserial xtcsd {
    capture which `command'
    if _rc {
        display as error "No se encontró `command'; instale la dependencia requerida antes de ejecutar el archivo 08."
        exit 199
    }
}


// B.4. Verificar los insumos producidos por los archivos 01 y 04

* Comprobar la presencia de la base analítica preparada y los resúmenes de estimación.
display as text "Dependencias externas de la inicialización y la sección 19: ninguna."

* Ejecutar la siguiente instrucción del bloque.
local estimation_file "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta"
* Verificar la existencia de un archivo antes de intentar cargarlo.
capture confirm file "`estimation_file'"
if _rc {
    display as error "No se encontró la base preparada para las estimaciones."
    display as error "Ejecute primero 01_data_preparation_diagnostics.do."
    exit 601
}

* Validar la integridad de los datos.
capture confirm file "$OUTPUT_ECI/eci_twfe_model_summary.csv"
if _rc {
    display as error "No se encontró el resumen del modelo ECI agregado."
    display as error "Ejecute primero 04_twfe_full.do."
    exit 601
}

* Validar la integridad de los datos.
capture confirm file "$OUTPUT_DIVX/divx_twfe_model_summary.csv"
if _rc {
    display as error "No se encontró el resumen del modelo DIVX agregado."
    display as error "Ejecute primero 04_twfe_full.do."
    exit 601
}

* Exigir el contrato común de muestra y el registro metodológico actualizado.
capture confirm file "$OUTPUT_SAMPLE/sample_contract.csv"
if _rc {
    display as error "No se encontró sample_contract.csv."
    display as error "Ejecute primero 01_data_preparation_diagnostics.do."
    exit 601
}

capture confirm file "$OUTPUT_DESIGN/econometric_decision_register.csv"
if _rc {
    display as error "No se encontró econometric_decision_register.csv."
    display as error "Ejecute primero 01_data_preparation_diagnostics.do."
    exit 601
}

* Recuperar las dimensiones y reglas de construcción de la muestra común.
import delimited using "$OUTPUT_SAMPLE/sample_contract.csv", ///
    clear varnames(1)
assert _N == 2
assert sample_observations[1] == sample_observations[2]
assert sample_countries[1] == sample_countries[2]
assert effective_years[1] == effective_years[2]
assert first_year[1] == first_year[2]
assert last_year[1] == last_year[2]
assert samples_identical == 1
assert no_imputation == 1
assert no_interpolation == 1

quietly summarize sample_observations, meanonly
local temporal_contract_n = r(min)
quietly summarize sample_countries, meanonly
local temporal_contract_countries = r(min)
quietly summarize effective_years, meanonly
local temporal_contract_years = r(min)
quietly summarize first_year, meanonly
local temporal_contract_first = r(min)
quietly summarize last_year, meanonly
local temporal_contract_last = r(min)
quietly summarize no_imputation, meanonly
local temporal_no_imputation = r(min)
quietly summarize no_interpolation, meanonly
local temporal_no_interpolation = r(min)

* Confirmar que las exclusiones temporales y el rol diagnóstico permanecen
* predefinidos antes de observar resultados de los componentes.
import delimited using ///
    "$OUTPUT_DESIGN/econometric_decision_register.csv", ///
    clear varnames(1)
assert _N == 18
isid decision_id
assert significance_selected == 0
quietly count if inlist(decision_id, "D14", "D15", "D16") & ///
    hierarchy == "EXCLUDED" & implementation_status == "EXCLUDED"
local temporal_exclusion_rows = r(N)
assert `temporal_exclusion_rows' == 3
quietly count if decision_id == "D18" & hierarchy == "MAIN" & ///
    implementation_status == "DIAGNOSTIC_ONLY"
local temporal_d18_rows = r(N)
assert `temporal_d18_rows' == 1
quietly count if decision_id == "D13" & hierarchy == "CONDITIONAL" & ///
    implementation_status == "IMPLEMENTED_WITH_JUSTIFICATION" & ///
    significance_selected == 0
local temporal_d13_rows = r(N)
assert `temporal_d13_rows' == 1
quietly count if significance_selected != 0
local temporal_sig_selection = r(N)
assert `temporal_sig_selection' == 0

* Cargar la base de estimación y declarar el panel de datos.
use "`estimation_file'", clear
* Comprobar que la combinación de identificadores de país y año sea única.
isid country_iso3_code year
* Declarar la estructura de panel definiendo la variable país y año.
xtset country_id year

* Validar la integridad de los datos.
confirm variable country_iso3_code country country_id year eci divx sample_eci sample_divx rents rents_oil_gas rents_mining inst ln1p_oilpc ln1p_gaspc ln1p_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin

* Informar que los insumos quedaron validados antes de iniciar la desagregación.
display as result "Inicialización del archivo 08 completada; comienza la sección 19."


// *****************************************************************************
// 19. Diseño Integrado de la Desagregación de RENTS
// *****************************************************************************

// 19.1. Confirmar las definiciones y la identidad contable

* Verificar que las tres variables numéricas de rentas estén presentes.
foreach var in rents rents_oil_gas rents_mining {
    capture confirm numeric variable `var'
    if _rc {
        display as error "La variable `var' debe ser numérica."
        exit 109
    }
}

* Validar el patrón de faltantes en las rentas desagregadas.
quietly count if missing(rents) != (missing(rents_oil_gas) | missing(rents_mining))
local missingness_mismatches = r(N)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `missingness_mismatches' == 0

* Verificar la identidad contable contruida: RENTS = RENTS_OIL_GAS + RENTS_MINING.
tempvar rents_decomposition_gap
generate double `rents_decomposition_gap' = abs(rents - rents_oil_gas - rents_mining) if !missing(rents, rents_oil_gas, rents_mining)

* Evaluar condición de control de flujo.
quietly count if !missing(`rents_decomposition_gap')
local identity_observations = r(N)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `identity_observations' > 0

* Ejecutar la siguiente instrucción del bloque.
quietly summarize `rents_decomposition_gap', meanonly
local identity_max_gap = r(max)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `identity_max_gap' <= 1e-10

* Validar el rango porcentual (0 a 100) para ambas rentas desagregadas.
foreach var in rents_oil_gas rents_mining {
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert inrange(`var', 0, 100) if !missing(`var')
}


// 19.2. Fijar la relación con los modelos agregados

* Mantener ECI_TWFE_MAIN y DIVX_TWFE_MAIN como especificaciones agregadas centrales.


// 19.3. Definir las interacciones institucionales

* Generar y verificar las variables de interacción explícitas con calidad institucional.
capture drop rents_oil_gas_x_inst rents_mining_x_inst

* Evaluar condición de control de flujo.
generate double rents_oil_gas_x_inst = rents_oil_gas * inst if !missing(rents_oil_gas, inst)
generate double rents_mining_x_inst  = rents_mining  * inst if !missing(rents_mining, inst)

* Ejecutar la siguiente instrucción del bloque.
label variable rents_oil_gas_x_inst "RENTS_OIL_GAS x INST"
label variable rents_mining_x_inst  "RENTS_MINING x INST"

* Validar la integridad de los datos.
assert missing(rents_oil_gas_x_inst) == (missing(rents_oil_gas) | missing(inst))
* Control de calidad automático que detiene el script si no se cumple la condición.
assert missing(rents_mining_x_inst)  == (missing(rents_mining)  | missing(inst))

* Evaluar condición de control de flujo.
assert abs(rents_oil_gas_x_inst - rents_oil_gas*inst) <= 1e-10 if !missing(rents_oil_gas_x_inst, rents_oil_gas, inst)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(rents_mining_x_inst  - rents_mining*inst)  <= 1e-10 if !missing(rents_mining_x_inst,  rents_mining,  inst)


// 19.4. Predefinir regresores y tratamiento de los controles per cápita

* Definir vectores globales de variables comunes y muestras analíticas completos.
global DISAGG_COMMON_VARS rents_oil_gas rents_mining inst ln1p_oilpc ln1p_gaspc ln1p_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin
global DISAGG_ECI_SAMPLE_VARS  eci  $DISAGG_COMMON_VARS hhi
global DISAGG_DIVX_SAMPLE_VARS divx $DISAGG_COMMON_VARS

* Definir los vectores de regresores principales con interacciones institucionales.
global DISAGG_COMMON_REGRESSORS c.rents_oil_gas##c.inst c.rents_mining##c.inst ln1p_oilpc ln1p_gaspc ln1p_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin
global DISAGG_ECI_REGRESSORS  $DISAGG_COMMON_REGRESSORS hhi
global DISAGG_DIVX_REGRESSORS $DISAGG_COMMON_REGRESSORS

* Definir los vectores alternativos para análisis de sensibilidad sin controles per cápita.
global DISAGG_COMMON_NO_PC c.rents_oil_gas##c.inst c.rents_mining##c.inst pexp fexp vol rer humcap innov net log_gdppc govcons fin
global DISAGG_ECI_NO_PC  $DISAGG_COMMON_NO_PC hhi
global DISAGG_DIVX_NO_PC $DISAGG_COMMON_NO_PC


// 19.5. Construir y validar las muestras comparables

* Identificar casos completos y generar marcas de muestra desagregada.
capture drop n_missing_eci_disagg n_missing_divx_disagg
capture drop sample_eci_disagg sample_divx_disagg

* Ejecutar la siguiente instrucción del bloque.
egen n_missing_eci_disagg = rowmiss($DISAGG_ECI_SAMPLE_VARS)
generate byte sample_eci_disagg = n_missing_eci_disagg == 0
label variable sample_eci_disagg "Muestra completa del modelo ECI desagregado"

* Ejecutar la siguiente instrucción del bloque.
egen n_missing_divx_disagg = rowmiss($DISAGG_DIVX_SAMPLE_VARS)
generate byte sample_divx_disagg = n_missing_divx_disagg == 0
label variable sample_divx_disagg "Muestra completa del modelo DIVX desagregado"

* Validar coincidencia 1:1 con las muestras de estimación agregadas.
quietly count if sample_eci_disagg != sample_eci
local eci_sample_mismatches = r(N)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `eci_sample_mismatches' == 0

* Evaluar condición de control de flujo.
quietly count if sample_divx_disagg != sample_divx
local divx_sample_mismatches = r(N)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `divx_sample_mismatches' == 0

* Recuperar dimensiones de la muestra ECI desagregada.
quietly count if sample_eci_disagg == 1
local eci_disagg_n = r(N)
quietly levelsof country_id if sample_eci_disagg == 1, local(eci_disagg_country_ids)
local eci_disagg_countries : word count `eci_disagg_country_ids'
quietly summarize year if sample_eci_disagg == 1, meanonly
local eci_disagg_first_year = r(min)
local eci_disagg_last_year  = r(max)

* Recuperar dimensiones de la muestra DIVX desagregada.
quietly count if sample_divx_disagg == 1
local divx_disagg_n = r(N)
quietly levelsof country_id if sample_divx_disagg == 1, local(divx_disagg_country_ids)
local divx_disagg_countries : word count `divx_disagg_country_ids'
quietly summarize year if sample_divx_disagg == 1, meanonly
local divx_disagg_first_year = r(min)
local divx_disagg_last_year  = r(max)

* Recuperar el tamaño de las muestras agregadas utilizadas como referencia.
quietly count if sample_eci == 1
local eci_aggregate_n = r(N)
* Contar silenciosamente cuántas observaciones cumplen una condición determinada.
quietly count if sample_divx == 1
local divx_aggregate_n = r(N)

* Confirmar de forma explícita que la extensión conserva el contrato común.
quietly count if sample_eci_disagg != sample_divx_disagg
local disagg_sample_mismatches = r(N)
assert `disagg_sample_mismatches' == 0

quietly levelsof year if sample_eci_disagg == 1, ///
    local(eci_disagg_year_values)
local eci_disagg_years : word count `eci_disagg_year_values'
quietly levelsof year if sample_divx_disagg == 1, ///
    local(divx_disagg_year_values)
local divx_disagg_years : word count `divx_disagg_year_values'

assert `eci_disagg_n' == `temporal_contract_n'
assert `divx_disagg_n' == `temporal_contract_n'
assert `eci_disagg_countries' == `temporal_contract_countries'
assert `divx_disagg_countries' == `temporal_contract_countries'
assert `eci_disagg_years' == `temporal_contract_years'
assert `divx_disagg_years' == `temporal_contract_years'
assert `eci_disagg_first_year' == `temporal_contract_first'
assert `divx_disagg_first_year' == `temporal_contract_first'
assert `eci_disagg_last_year' == `temporal_contract_last'
assert `divx_disagg_last_year' == `temporal_contract_last'

* Verificar programáticamente que HHI conserva su alcance exclusivo de ECI.
local temporal_hhi_in_eci = ///
    strpos(" $DISAGG_ECI_REGRESSORS ", " hhi ") > 0
local temporal_hhi_in_divx = ///
    strpos(" $DISAGG_DIVX_REGRESSORS ", " hhi ") > 0
assert `temporal_hhi_in_eci' == 1
assert `temporal_hhi_in_divx' == 0


// 19.6. Predefinir pruebas e interpretación

* Predefinir hipótesis de igualdad y percentiles de la distribución institucional.
global DISAGG_TEST_EQUAL_LEVELS "rents_oil_gas = rents_mining"
global DISAGG_TEST_EQUAL_INTERACTIONS "c.rents_oil_gas#c.inst = c.rents_mining#c.inst"
global DISAGG_INST_PERCENTILES "10 25 50 75 90"


// 19.7. Exportar la evidencia del diseño y cerrar el Control G

* Inicializar y guardar el reporte de decisiones del Control G.
tempname control_g_post
tempfile control_g_report

* Ejecutar la siguiente instrucción del bloque.
postfile `control_g_post' str36 decision str48 selection str244 rationale using "`control_g_report'", replace

* Ejecutar la siguiente instrucción del bloque.
post `control_g_post' ("analytical_role") ("complementary_extension") ("Los modelos agregados ECI_TWFE_MAIN y DIVX_TWFE_MAIN siguen siendo centrales.")
* Escribir una fila de resultados dentro del archivo temporal.
post `control_g_post' ("model_structure") ("joint_components") ("Ambos componentes entran juntos para evitar omitir la otra fuente de rentas y permitir pruebas de igualdad.")
* Escribir una fila de resultados dentro del archivo temporal.
post `control_g_post' ("institutional_interactions") ("both_simultaneous") ("Cada componente interactúa con INST dentro de la misma ecuación como descomposición de la interacción agregada.")
* Escribir una fila de resultados dentro del archivo temporal.
post `control_g_post' ("per_capita_controls_main") ("retain_all") ("Los controles per cápita representan abundancia real y preservan la comparabilidad con el modelo agregado.")
* Escribir una fila de resultados dentro del archivo temporal.
post `control_g_post' ("per_capita_sensitivity") ("exclude_all_together") ("La única sensibilidad predefinida retira conjuntamente OILPC, GASPC y COALPC transformados.")
* Escribir una fila de resultados dentro del archivo temporal.
post `control_g_post' ("samples") ("same_complete_cases") ("Las muestras desagregadas deben coincidir exactamente con las muestras agregadas aprobadas.")
* Escribir una fila de resultados dentro del archivo temporal.
post `control_g_post' ("inference") ("twfe_cluster_country") ("Se mantienen efectos fijos por país y año y errores estándar agrupados por país.")
* Escribir una fila de resultados dentro del archivo temporal.
post `control_g_post' ("interpretation") ("conditional_associations") ("Las diferencias entre componentes se interpretarán como asociaciones condicionadas y no como efectos causales.")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `control_g_post'

* Exportar las decisiones predefinidas que sustentan el Control G.
preserve
    use "`control_g_report'", clear
    export delimited using "$OUTPUT_DISAGG_DESIGN/control_g_design.csv", replace
restore

* Inicializar y guardar el reporte de validación contable y comparabilidad.
tempname validation_post
tempfile validation_report

* Ejecutar la siguiente instrucción del bloque.
postfile `validation_post' str40 check str24 unit double value str12 status using "`validation_report'", replace

* Ejecutar la siguiente instrucción del bloque.
post `validation_post' ("identity_complete_observations") ("observations") (`identity_observations') ("PASS")
* Escribir una fila de resultados dentro del archivo temporal.
post `validation_post' ("identity_max_absolute_gap") ("percentage_points") (`identity_max_gap') ("PASS")
* Escribir una fila de resultados dentro del archivo temporal.
post `validation_post' ("identity_missingness_mismatches") ("observations") (`missingness_mismatches') ("PASS")
* Escribir una fila de resultados dentro del archivo temporal.
post `validation_post' ("eci_aggregate_observations") ("observations") (`eci_aggregate_n') ("REFERENCE")
* Escribir una fila de resultados dentro del archivo temporal.
post `validation_post' ("eci_disaggregated_observations") ("observations") (`eci_disagg_n') ("PASS")
* Escribir una fila de resultados dentro del archivo temporal.
post `validation_post' ("eci_disaggregated_countries") ("countries") (`eci_disagg_countries') ("PASS")
* Escribir una fila de resultados dentro del archivo temporal.
post `validation_post' ("eci_sample_mismatches") ("observations") (`eci_sample_mismatches') ("PASS")
* Escribir una fila de resultados dentro del archivo temporal.
post `validation_post' ("divx_aggregate_observations") ("observations") (`divx_aggregate_n') ("REFERENCE")
* Escribir una fila de resultados dentro del archivo temporal.
post `validation_post' ("divx_disaggregated_observations") ("observations") (`divx_disagg_n') ("PASS")
* Escribir una fila de resultados dentro del archivo temporal.
post `validation_post' ("divx_disaggregated_countries") ("countries") (`divx_disagg_countries') ("PASS")
* Escribir una fila de resultados dentro del archivo temporal.
post `validation_post' ("divx_sample_mismatches") ("observations") (`divx_sample_mismatches') ("PASS")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `validation_post'

* Exportar las comprobaciones contables y de comparabilidad de las muestras.
preserve
    use "`validation_report'", clear
    format value %16.10g
    export delimited using "$OUTPUT_DISAGG_DESIGN/section19_validation.csv", replace
restore


// 19.8. Predefinir y exportar el contrato temporal de los componentes

* El contrato fija el alcance de los bloques 2 a 5 antes de ejecutar cualquier
* prueba temporal. Ninguna fila autoriza transformar o seleccionar el M3.
tempname temporal_design_post
tempfile temporal_design_report

postfile `temporal_design_post' ///
    str4 rule_id str40 design_area str80 source ///
    str100 required_setting ///
    str160 methodological_action str180 interpretation_limit ///
    byte passed ///
    using "`temporal_design_report'", replace

post `temporal_design_post' ///
    ("T01") ("COMPONENT_SCOPE") ///
    ("master_panel_estimation_sample.dta") ///
    ("rents_oil_gas; rents_mining") ///
    ("Evaluar temporalmente solo los dos componentes contables de RENTS.") ///
    ("RENTS x INST agregado y auxiliares manuales no son procesos autonomos.") ///
    (1)
post `temporal_design_post' ///
    ("T02") ("COMMON_SAMPLE") ("sample_contract.csv") ///
    ("N=1044; countries=49; effective_years=23; identical_samples=1") ///
    ("Usar exactamente la muestra comun de los modelos desagregados aprobados.") ///
    ("No recortar, balancear, imputar ni interpolar para habilitar una prueba.") ///
    ((`eci_disagg_n' == `temporal_contract_n') & ///
     (`divx_disagg_n' == `temporal_contract_n') & ///
     (`disagg_sample_mismatches' == 0))
post `temporal_design_post' ///
    ("T03") ("ACCOUNTING_IDENTITY") ("section19_validation.csv") ///
    ("RENTS = RENTS_OIL_GAS + RENTS_MINING; tolerance=1e-10") ///
    ("Detener la extension ante cualquier ruptura de la identidad contable.") ///
    ("La identidad define componentes; no identifica efectos causales.") ///
    ((`identity_max_gap' <= 1e-10) & (`missingness_mismatches' == 0))
post `temporal_design_post' ///
    ("T04") ("HHI_SCOPE") ("DISAGG_ECI_REGRESSORS; DISAGG_DIVX_REGRESSORS") ///
    ("HHI in ECI only; HHI absent from DIVX") ///
    ("Conservar HHI en ECI y excluirlo de toda ecuacion DIVX.") ///
    ("Incluir HHI en DIVX generaria una identidad mecanica.") ///
    ((`temporal_hhi_in_eci' == 1) & (`temporal_hhi_in_divx' == 0))
post `temporal_design_post' ///
    ("T05") ("NO_IMPUTATION") ("sample_contract.csv") ///
    ("no_imputation=1") ///
    ("Preservar los valores observados y los vacios del panel.") ///
    ("No completar series para mejorar artificialmente elegibilidad o potencia.") ///
    (`temporal_no_imputation' == 1)
post `temporal_design_post' ///
    ("T06") ("NO_INTERPOLATION") ("sample_contract.csv") ///
    ("no_interpolation=1") ///
    ("Mantener las brechas temporales reales de la muestra.") ///
    ("Las diferencias y rezagos deben respetar anos no consecutivos.") ///
    (`temporal_no_interpolation' == 1)
post `temporal_design_post' ///
    ("T07") ("UNIT_ROOT_SPECIFICATION") ("Peer1_audit; D18") ///
    ("Fisher-ADF; constant; lags=1; demeaned; level and first difference") ///
    ("Aplicar una sola especificacion predefinida a cada componente.") ///
    ("El rechazo no demuestra estacionariedad universal ni clasifica I(0) o I(1).") ///
    (1)
post `temporal_design_post' ///
    ("T08") ("DIAGNOSTIC_ROLE") ("econometric_decision_register.csv; D18") ///
    ("implementation_status=DIAGNOSTIC_ONLY") ///
    ("Usar persistencia y raices unitarias como contexto temporal.") ///
    ("No transformar, excluir ni seleccionar componentes automaticamente.") ///
    (`temporal_d18_rows' == 1)
post `temporal_design_post' ///
    ("T09") ("NO_SIGNIFICANCE_SELECTION") ///
    ("econometric_decision_register.csv") ///
    ("significance_selected=0") ///
    ("Predefinir todas las pruebas y conservar tambien resultados no significativos.") ///
    ("Los valores p no eligen especificaciones ni periodos.") ///
    (`temporal_sig_selection' == 0)
post `temporal_design_post' ///
    ("T10") ("EXCLUDED_METHODS") ///
    ("econometric_decision_register.csv; D14-D16") ///
    ("Exclude cointegration, ECM, VAR/VEC, Granger, LP and HP from script 08") ///
    ("No incorporar metodos sin vector, choque o sistema predefinido.") ///
    ("Las exclusiones no impiden un proyecto dinamico separado con otro diseno.") ///
    (`temporal_exclusion_rows' == 3)
post `temporal_design_post' ///
    ("T11") ("INFERENCE_GATE") ("future disaggregated_panel_error_tests.csv") ///
    ("No Driscoll-Kraay or PCSE before residual diagnostics") ///
    ("Evaluar primero heterocedasticidad, autocorrelacion y Pesaran CD.") ///
    ("Una alerta residual abriria una decision separada; no activa otro estimador.") ///
    (1)
post `temporal_design_post' ///
    ("T12") ("OUTPUT_ISOLATION") ("OUTPUT_DISAGG") ///
    ("Write only under 07_resource_disaggregation") ///
    ("Mantener los nuevos resultados dentro de la extension desagregada.") ///
    ("Los outputs agregados de 01 y 04 permanecen protegidos.") ///
    (1)

postclose `temporal_design_post'

preserve
    use "`temporal_design_report'", clear
    assert _N == 12
    isid rule_id
    assert !missing(design_area, source, required_setting)
    assert !missing(methodological_action, interpretation_limit)
    assert passed == 1
    sort rule_id
    export delimited using ///
        "$OUTPUT_DISAGG_DESIGN/component_temporal_design.csv", ///
        replace datafmt
    list rule_id design_area required_setting passed, ///
        noobs abbreviate(32)
restore

* Notificar el cierre del diseño sin estimar todavía coeficientes desagregados.
display as result "Control G aprobado antes de observar coeficientes."
display as result ///
    "Contrato temporal aprobado: 12 reglas predefinidas y validadas."
display as result "ECI desagregado: `eci_disagg_n' observaciones, `eci_disagg_countries' países, `eci_disagg_first_year'-`eci_disagg_last_year'."
display as result "DIVX desagregado: `divx_disagg_n' observaciones, `divx_disagg_countries' países, `divx_disagg_first_year'-`divx_disagg_last_year'."
display as result "Sección 19 completada: diseño registrado y muestras comparables validadas."


// *****************************************************************************
// 20. Preparación y Diagnósticos de los Componentes
// *****************************************************************************

// 20.1. Cargar la base analítica sin modificarla

* Confirmar la integridad de la estructura de panel de datos.
isid country_iso3_code year
* Declarar la estructura de panel definiendo la variable país y año.
xtset country_id year

* Comprobar el tamaño del panel y de las dos muestras analíticas.
quietly count
* Control de calidad automático que detiene el script si no se cumple la condición.
assert r(N) == 1430

* Evaluar condición de control de flujo.
quietly count if sample_eci_disagg == 1
* Control de calidad automático que detiene el script si no se cumple la condición.
assert r(N) == 1044

* Evaluar condición de control de flujo.
quietly count if sample_divx_disagg == 1
* Control de calidad automático que detiene el script si no se cumple la condición.
assert r(N) == 1044


// 20.2. Validar cobertura, dominios e identidad contable

* Perfilar cobertura y distribución estadística de los componentes.
tempname profile_post
tempfile profile_report

* Ejecutar la siguiente instrucción del bloque.
postfile `profile_post' str24 variable long grid_observations long available_grid long missing_grid double coverage_grid_percent int countries_available int first_year int last_year long sample_observations long sample_zeros double sample_zero_percent mean sd min p1 p5 p25 median p75 p95 p99 max skewness using "`profile_report'", replace

* Iterar sobre los elementos del conjunto.
foreach var in rents_oil_gas rents_mining {
    * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
    quietly count
    local grid_n = r(N)
    * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
    quietly count if !missing(`var')
    local available_n = r(N)
    local missing_n = `grid_n' - `available_n'
    local coverage = 100 * `available_n' / `grid_n'
    quietly levelsof country_id if !missing(`var'), local(available_ids)
    local available_countries : word count `available_ids'
    quietly summarize year if !missing(`var'), meanonly
    local first_year = r(min)
    local last_year = r(max)
    * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
    quietly count if sample_eci_disagg == 1
    local sample_n = r(N)
    * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
    quietly count if sample_eci_disagg == 1 & `var' == 0
    local zero_n = r(N)
    local zero_percent = 100 * `zero_n' / `sample_n'
    quietly summarize `var' if sample_eci_disagg == 1, detail
    * Escribir una fila de resultados dentro del archivo temporal.
    post `profile_post' ("`var'") (`grid_n') (`available_n') (`missing_n') (`coverage') (`available_countries') (`first_year') (`last_year') (`sample_n') (`zero_n') (`zero_percent') (r(mean)) (r(sd)) (r(min)) (r(p1)) (r(p5)) (r(p25)) (r(p50)) (r(p75)) (r(p95)) (r(p99)) (r(max)) (r(skewness))
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `profile_post'

* Exportar el perfil de cobertura y distribución de cada componente.
preserve
    use "`profile_report'", clear
    format coverage_grid_percent sample_zero_percent %9.2f
    format mean sd min p1 p5 p25 median p75 p95 p99 max skewness %12.6f
    export delimited using "$OUTPUT_DISAGG_DIAGNOSTICS/component_profile.csv", replace
restore


// 20.3. Evaluar variación temporal y colinealidad

* Descomponer variaciones Within y Between por componente.
tempname variation_post
tempfile variation_report

* Ejecutar la siguiente instrucción del bloque.
postfile `variation_post' str28 variable str12 role long observations int countries double average_periods mean sd_overall sd_between sd_within within_sd_ratio byte has_within_variation using "`variation_report'", replace

* Iterar sobre los elementos del conjunto.
foreach var in rents_oil_gas rents_mining rents_oil_gas_x_inst rents_mining_x_inst {
    local role "component"
    if strpos("`var'", "_x_inst") local role "interaction"
    quietly xtsum `var' if sample_eci_disagg == 1
    local within_ratio = r(sd_w) / r(sd)
    local within_available = r(sd_w) > 1e-10
    * Escribir una fila de resultados dentro del archivo temporal.
    post `variation_post' ("`var'") ("`role'") (r(N)) (r(n)) (r(Tbar)) (r(mean)) (r(sd)) (r(sd_b)) (r(sd_w)) (`within_ratio') (`within_available')
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `variation_post'

* Exportar la descomposición de variación Within y Between.
preserve
    use "`variation_report'", clear
    format average_periods mean sd_overall sd_between sd_within within_sd_ratio %12.6f
    sort role variable
    export delimited using "$OUTPUT_DISAGG_DIAGNOSTICS/component_panel_variation.csv", replace
restore


// 20.3.1. Inventariar la estructura temporal y la persistencia descriptiva

* Este inventario no prueba raíces unitarias ni autoriza transformar, excluir
* o sustituir componentes en las especificaciones desagregadas aprobadas.
assert sample_eci_disagg == sample_divx_disagg

tempname temporal_post
tempfile temporal_report

postfile `temporal_post' ///
    str24 variable ///
    str28 component_label ///
    str18 sample ///
    long source_observations ///
    long valid_lag_pairs ///
    long ar1_observations ///
    int countries ///
    double lag_pair_loss_percent ///
    int min_periods ///
    int max_periods ///
    double average_periods ///
    int calendar_year_count ///
    str244 calendar_years ///
    long total_internal_gaps ///
    str120 pooled_missing_years ///
    double ar1_coefficient ///
    double standard_error ///
    double t_statistic ///
    double p_value ///
    double ci_lower ///
    double ci_upper ///
    double cluster_df ///
    str24 persistence_label ///
    byte model_change_authorized ///
    str244 interpretation_limit ///
    using "`temporal_report'", replace

foreach var in rents_oil_gas rents_mining {
    local component_label "Petróleo y gas"
    if "`var'" == "rents_mining" {
        local component_label "Minería"
    }

    quietly count if sample_eci_disagg == 1 & !missing(`var')
    local source_n = r(N)

    quietly count if ///
        sample_eci_disagg == 1 & ///
        L.sample_eci_disagg == 1 & ///
        !missing(`var', L.`var')
    local lag_pairs = r(N)
    local pair_loss = 100 * (`source_n' - `lag_pairs') / `source_n'

    preserve
        keep if sample_eci_disagg == 1 & !missing(`var')
        sort country_id year
        by country_id: generate int periods_in_country = _N
        by country_id (year): generate int internal_gap = ///
            cond(_n == 1, 0, max(year - year[_n - 1] - 1, 0))

        quietly summarize internal_gap, meanonly
        local total_gaps = r(sum)
        quietly levelsof year, local(calendar_years)
        local year_count : word count `calendar_years'
        quietly summarize year, meanonly
        local first_calendar_year = r(min)
        local last_calendar_year = r(max)

        local pooled_missing ""
        forvalues calendar_year = ///
            `first_calendar_year'/`last_calendar_year' {
            quietly count if year == `calendar_year'
            if r(N) == 0 {
                local pooled_missing ///
                    "`pooled_missing' `calendar_year'"
            }
        }
        local pooled_missing = strtrim("`pooled_missing'")
        if "`pooled_missing'" == "" {
            local pooled_missing "Ninguno"
        }

        by country_id: generate byte country_first = _n == 1
        quietly count if country_first == 1
        local country_n = r(N)
        quietly summarize periods_in_country if country_first == 1, meanonly
        local min_periods = r(min)
        local max_periods = r(max)
        local average_periods = r(mean)
    restore

    quietly xtreg `var' L.`var' i.year if ///
        sample_eci_disagg == 1 & ///
        L.sample_eci_disagg == 1, ///
        fe vce(cluster country_id)
    local ar1_n = e(N)
    local ar1_b = _b[L.`var']
    local ar1_se = _se[L.`var']
    local ar1_t = `ar1_b' / `ar1_se'
    local ar1_df = e(df_r)
    local ar1_p = 2 * ttail(`ar1_df', abs(`ar1_t'))
    local ar1_crit = invttail(`ar1_df', 0.025)
    local ar1_lb = `ar1_b' - `ar1_crit' * `ar1_se'
    local ar1_ub = `ar1_b' + `ar1_crit' * `ar1_se'

    local persistence_label "Baja descriptiva"
    if abs(`ar1_b') >= 0.30 {
        local persistence_label "Moderada descriptiva"
    }
    if abs(`ar1_b') >= 0.70 {
        local persistence_label "Alta descriptiva"
    }

    post `temporal_post' ///
        ("`var'") ///
        ("`component_label'") ///
        ("ECI_DIVX_common") ///
        (`source_n') ///
        (`lag_pairs') ///
        (`ar1_n') ///
        (`country_n') ///
        (`pair_loss') ///
        (`min_periods') ///
        (`max_periods') ///
        (`average_periods') ///
        (`year_count') ///
        ("`calendar_years'") ///
        (`total_gaps') ///
        ("`pooled_missing'") ///
        (`ar1_b') ///
        (`ar1_se') ///
        (`ar1_t') ///
        (`ar1_p') ///
        (`ar1_lb') ///
        (`ar1_ub') ///
        (`ar1_df') ///
        ("`persistence_label'") ///
        (0) ///
        ("AR(1) descriptivo con FE de país y año y errores agrupados por país; no es prueba de raíz unitaria ni regla automática de modelación.")
}
postclose `temporal_post'

* Validar y exportar el contrato analítico del bloque 2.
preserve
    use "`temporal_report'", clear
    isid variable
    assert _N == 2
    assert inlist(variable, "rents_oil_gas", "rents_mining")
    assert source_observations == 1044
    assert countries == 49
    assert valid_lag_pairs < source_observations
    assert ar1_observations == valid_lag_pairs
    assert !missing( ///
        lag_pair_loss_percent, ///
        min_periods, ///
        max_periods, ///
        average_periods, ///
        calendar_year_count, ///
        total_internal_gaps, ///
        ar1_coefficient, ///
        standard_error, ///
        t_statistic, ///
        p_value, ///
        ci_lower, ///
        ci_upper, ///
        cluster_df)
    assert strpos(lower(variable), "hhi") == 0
    assert model_change_authorized == 0
    format lag_pair_loss_percent average_periods %9.2f
    format ar1_coefficient standard_error t_statistic ///
        p_value ci_lower ci_upper cluster_df %12.6f
    sort variable
    export delimited using ///
        "$OUTPUT_DISAGG_DIAGNOSTICS/component_temporal_inventory.csv", ///
        replace datafmt
restore

display as result ///
    "Bloque 2 validado: inventario temporal descriptivo de dos componentes."


// 20.3.2. Ejecutar Fisher-ADF predefinido para los dos componentes

* Fisher-ADF se usa solo como diagnóstico temporal complementario. El rechazo
* de la hipótesis nula conjunta no demuestra que todos los países sean
* estacionarios ni determina por sí solo un orden de integración común.
capture drop diagnostic_d_rents_oil_gas
capture drop diagnostic_d_rents_mining
generate double diagnostic_d_rents_oil_gas = ///
    D.rents_oil_gas if ///
    sample_eci_disagg == 1 & L.sample_eci_disagg == 1
generate double diagnostic_d_rents_mining = ///
    D.rents_mining if ///
    sample_eci_disagg == 1 & L.sample_eci_disagg == 1

tempname component_ur_post
tempfile component_ur_report

postfile `component_ur_post' ///
    str24 variable ///
    str28 component_label ///
    str18 sample ///
    str18 series_form ///
    str12 method ///
    str24 statistic_type ///
    str12 deterministics ///
    byte demeaned ///
    int lags ///
    long observations ///
    int countries ///
    double statistic ///
    double p_value ///
    byte reject_5pct ///
    str36 decision ///
    int return_code ///
    str48 null_hypothesis ///
    str64 alternative_hypothesis ///
    str20 diagnostic_role ///
    byte model_change_authorized ///
    str244 interpretation_limit ///
    using "`component_ur_report'", replace

foreach var in rents_oil_gas rents_mining {
    local component_label "Petróleo y gas"
    if "`var'" == "rents_mining" {
        local component_label "Minería"
    }

    foreach series_form in LEVEL FIRST_DIFFERENCE {
        local test_var "`var'"
        if "`series_form'" == "FIRST_DIFFERENCE" {
            local test_var "diagnostic_d_`var'"
        }

        capture quietly xtunitroot fisher `test_var' ///
            if sample_eci_disagg == 1, ///
            dfuller lags(1) demean
        local fisher_rc = _rc
        if `fisher_rc' != 0 {
            display as error ///
                "Fisher-ADF falló para `var' en `series_form'."
            exit `fisher_rc'
        }

        local fisher_n = r(N)
        local fisher_groups = r(N_g)
        local fisher_stat = r(P)
        local fisher_p = r(p_P)
        if missing(`fisher_stat', `fisher_p') {
            display as error ///
                "Fisher-ADF devolvió resultados vacíos para `var' en `series_form'."
            exit 498
        }

        local fisher_reject = `fisher_p' < 0.05
        local fisher_decision "DO_NOT_REJECT_UNIT_ROOT_NULL"
        if `fisher_reject' == 1 {
            local fisher_decision "REJECT_UNIT_ROOT_NULL"
        }

        post `component_ur_post' ///
            ("`var'") ///
            ("`component_label'") ///
            ("ECI_DIVX_common") ///
            ("`series_form'") ///
            ("FISHER_ADF") ///
            ("INVERSE_CHI_SQUARED_P") ///
            ("CONSTANT") ///
            (1) ///
            (1) ///
            (`fisher_n') ///
            (`fisher_groups') ///
            (`fisher_stat') ///
            (`fisher_p') ///
            (`fisher_reject') ///
            ("`fisher_decision'") ///
            (`fisher_rc') ///
            ("All panels contain unit roots") ///
            ("At least one panel is stationary") ///
            ("DIAGNOSTIC_ONLY") ///
            (0) ///
            ("El rechazo indica que no todos los paneles contienen raíz unitaria; no demuestra estacionariedad universal ni clasifica automáticamente I(0) o I(1).")
    }
}
postclose `component_ur_post'

* Validar y exportar la batería reducida comprometida para el bloque 3.
preserve
    use "`component_ur_report'", clear
    isid variable series_form
    assert _N == 4
    bysort variable: assert _N == 2
    assert inlist(variable, "rents_oil_gas", "rents_mining")
    assert inlist(series_form, "LEVEL", "FIRST_DIFFERENCE")
    assert method == "FISHER_ADF"
    assert statistic_type == "INVERSE_CHI_SQUARED_P"
    assert deterministics == "CONSTANT"
    assert demeaned == 1
    assert lags == 1
    assert observations == 1044 if series_form == "LEVEL"
    assert observations == 869 if series_form == "FIRST_DIFFERENCE"
    assert countries == 49
    assert return_code == 0
    assert !missing(statistic, p_value)
    assert inrange(p_value, 0, 1)
    assert reject_5pct == (p_value < 0.05)
    assert diagnostic_role == "DIAGNOSTIC_ONLY"
    assert model_change_authorized == 0
    assert strpos(lower(variable), "hhi") == 0
    format statistic p_value %14.10f
    sort variable series_form
    export delimited using ///
        "$OUTPUT_DISAGG_DIAGNOSTICS/panel_unit_root_components.csv", ///
        replace datafmt
restore

drop diagnostic_d_rents_oil_gas diagnostic_d_rents_mining

display as result ///
    "Bloque 3 validado: cuatro resultados Fisher-ADF diagnósticos."

* Exportar la matriz de correlaciones focales de regresores.
local focal_vars rents_oil_gas rents_mining inst rents_oil_gas_x_inst rents_mining_x_inst ln1p_oilpc ln1p_gaspc ln1p_coalpc
quietly correlate `focal_vars' if sample_eci_disagg == 1
matrix focal_correlations = r(C)

* Ejecutar la siguiente instrucción del bloque.
preserve
    clear
    svmat double focal_correlations, names(col)
    generate str28 variable = ""
    local row_number = 1
    foreach var of local focal_vars {
        replace variable = "`var'" in `row_number'
        local ++row_number
    }
    order variable
    export delimited using "$OUTPUT_DISAGG_DIAGNOSTICS/focal_correlation_matrix.csv", replace
restore

* Calcular VIF Within con regresores residualizados por país y año.
local regressors_eci rents_oil_gas rents_mining inst rents_oil_gas_x_inst rents_mining_x_inst ln1p_oilpc ln1p_gaspc ln1p_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin
local hhi_term "hhi"
local regressors_divx : list regressors_eci - hhi_term

* Iterar sobre los elementos del conjunto.
foreach var of local regressors_eci {
    capture drop within_`var'
    quietly regress `var' i.country_id i.year if sample_eci_disagg == 1
    predict double within_`var' if e(sample), residuals
}

* Ejecutar la siguiente instrucción del bloque.
tempname vif_post
tempfile vif_report

* Evaluar condición de control de flujo.
postfile `vif_post' str12 model str28 variable double auxiliary_r2 vif str12 assessment using "`vif_report'", replace

* Iterar sobre los elementos del conjunto.
foreach model in ECI DIVX {
    local regressors "`regressors_eci'"
    local sample_flag "sample_eci_disagg"
    if "`model'" == "DIVX" {
        local regressors "`regressors_divx'"
        local sample_flag "sample_divx_disagg"
    }
    foreach target of local regressors {
        local remaining : list regressors - target
        local within_remaining ""
        foreach var of local remaining {
            local within_remaining "`within_remaining' within_`var'"
        }
        quietly regress within_`target' `within_remaining' if `sample_flag' == 1
        local vif_value = .
        local vif_assessment "SINGULAR"
        if e(r2) < 0.999999999999 {
            local vif_value = 1 / (1 - e(r2))
            local vif_assessment "LOW"
            if `vif_value' >= 5 local vif_assessment "REVIEW"
            if `vif_value' >= 10 local vif_assessment "HIGH"
        }
        * Escribir una fila de resultados dentro del archivo temporal.
        post `vif_post' ("`model'") ("`target'") (e(r2)) (`vif_value') ("`vif_assessment'")
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `vif_post'

* Exportar los VIF ordenados por modelo y magnitud.
preserve
    use "`vif_report'", clear
    gsort model -vif
    format auxiliary_r2 vif %12.6f
    export delimited using "$OUTPUT_DISAGG_DIAGNOSTICS/within_vif_by_model.csv", replace
restore

* Eliminar las variables residuales creadas únicamente para el diagnóstico VIF.
foreach var of local regressors_eci {
    drop within_`var'
}


// 20.4. Diagnosticar la estructura residual de las ecuaciones desagregadas

* Crear indicadores anuales explícitos porque xtserial no admite i.year. Se
* omite el primer año observado como categoría de referencia.
quietly levelsof year if sample_eci_disagg == 1, ///
    local(disagg_error_years)
local disagg_error_base_year : word 1 of `disagg_error_years'
local disagg_error_year_dummies ""

foreach diagnostic_year of local disagg_error_years {
    if `diagnostic_year' != `disagg_error_base_year' {
        capture drop disagg_error_year_`diagnostic_year'
        generate byte disagg_error_year_`diagnostic_year' = ///
            year == `diagnostic_year'
        local disagg_error_year_dummies ///
            "`disagg_error_year_dummies' disagg_error_year_`diagnostic_year'"
    }
}

tempname disagg_error_post
tempfile disagg_error_report

postfile `disagg_error_post' ///
    str8 model ///
    str8 dependent ///
    str32 test ///
    str80 null_hypothesis ///
    double statistic ///
    double df1 ///
    double df2 ///
    double p_value ///
    long observations ///
    int countries ///
    int first_year ///
    int last_year ///
    byte includes_country_fe ///
    byte includes_year_fe ///
    byte hhi_included ///
    str20 decision ///
    int return_code ///
    str18 sample_rule ///
    str20 main_inference ///
    str20 alternative_status ///
    byte model_change_authorized ///
    str244 interpretation_limit ///
    using "`disagg_error_report'", replace

foreach model in ECI DIVX {
    local dependent "eci"
    local regressors "`regressors_eci'"
    local factor_regressors "$DISAGG_ECI_REGRESSORS"
    local sample_flag "sample_eci_disagg"
    local hhi_included = 1

    if "`model'" == "DIVX" {
        local dependent "divx"
        local regressors "`regressors_divx'"
        local factor_regressors "$DISAGG_DIVX_REGRESSORS"
        local sample_flag "sample_divx_disagg"
        local hhi_included = 0
    }

    quietly count if `sample_flag' == 1
    local disagg_diag_n = r(N)
    assert `disagg_diag_n' == 1044
    quietly levelsof country_id if `sample_flag' == 1, ///
        local(disagg_diag_country_ids)
    local disagg_diag_countries : word count `disagg_diag_country_ids'
    assert `disagg_diag_countries' == 49
    quietly summarize year if `sample_flag' == 1, meanonly
    local disagg_diag_first = r(min)
    local disagg_diag_last = r(max)

    * Wald modificado para heterocedasticidad entre países.
    quietly xtreg `dependent' `factor_regressors' i.year ///
        if `sample_flag' == 1, fe
    assert e(N) == `disagg_diag_n'
    assert e(sample) == `sample_flag'
    capture quietly xttest3
    local hetero_rc = _rc
    if `hetero_rc' != 0 {
        display as error ///
            "Modified Wald falló para el modelo desagregado `model'."
        exit `hetero_rc'
    }
    local hetero_stat = r(wald)
    local hetero_df = r(df)
    local hetero_p = r(p)
    if missing(`hetero_stat', `hetero_df', `hetero_p') {
        display as error ///
            "Modified Wald devolvió resultados vacíos para `model'."
        exit 498
    }
    local hetero_decision "DO NOT REJECT H0"
    if `hetero_p' < 0.05 local hetero_decision "REJECT H0"

    post `disagg_error_post' ///
        ("`model'") ("`dependent'") ("Modified Wald") ///
        ("Equal error variance across countries") ///
        (`hetero_stat') (`hetero_df') (.) (`hetero_p') ///
        (`disagg_diag_n') (`disagg_diag_countries') ///
        (`disagg_diag_first') (`disagg_diag_last') ///
        (1) (1) (`hhi_included') ///
        ("`hetero_decision'") (`hetero_rc') ///
        ("COMMON_COMPLETE") ("CLUSTER_COUNTRY") ///
        ("NOT_AUTHORIZED") (0) ///
        ("Diagnóstico de heterocedasticidad; la inferencia principal agrupada por país se mantiene por diseño.")

    * Wooldridge para autocorrelación serial de primer orden, conservando los
    * controles y los efectos anuales de la ecuación desagregada.
    capture quietly xtserial `dependent' `regressors' ///
        `disagg_error_year_dummies' ///
        if `sample_flag' == 1
    local serial_rc = _rc
    if `serial_rc' != 0 {
        display as error ///
            "Wooldridge AR(1) falló para el modelo desagregado `model'."
        exit `serial_rc'
    }
    local serial_stat = r(F)
    local serial_df1 = r(df)
    local serial_df2 = r(df_r)
    local serial_p = r(p)
    if missing(`serial_stat', `serial_df1', `serial_df2', `serial_p') {
        display as error ///
            "Wooldridge devolvió resultados vacíos para `model'."
        exit 498
    }
    local serial_decision "DO NOT REJECT H0"
    if `serial_p' < 0.05 local serial_decision "REJECT H0"

    post `disagg_error_post' ///
        ("`model'") ("`dependent'") ("Wooldridge AR(1)") ///
        ("No first-order serial correlation") ///
        (`serial_stat') (`serial_df1') (`serial_df2') (`serial_p') ///
        (`disagg_diag_n') (`disagg_diag_countries') ///
        (`disagg_diag_first') (`disagg_diag_last') ///
        (1) (1) (`hhi_included') ///
        ("`serial_decision'") (`serial_rc') ///
        ("COMMON_COMPLETE") ("CLUSTER_COUNTRY") ///
        ("NOT_AUTHORIZED") (0) ///
        ("Diagnóstico de correlación serial residual; no es un modelo AR(p) ni activa PCSE-AR(1).")

    * Pesaran CD sobre los residuos del TWFE con efectos de país y año.
    quietly xtreg `dependent' `factor_regressors' i.year ///
        if `sample_flag' == 1, fe
    assert e(N) == `disagg_diag_n'
    assert e(sample) == `sample_flag'
    capture quietly xtcsd, pesaran abs
    local cd_rc = _rc
    if `cd_rc' != 0 {
        display as error ///
            "Pesaran CD falló para el modelo desagregado `model'."
        exit `cd_rc'
    }
    local cd_stat = r(pesaran)
    local cd_p = 2 * normal(-abs(`cd_stat'))
    if missing(`cd_stat', `cd_p') {
        display as error ///
            "Pesaran CD devolvió resultados vacíos para `model'."
        exit 498
    }
    local cd_decision "DO NOT REJECT H0"
    if `cd_p' < 0.05 local cd_decision "REJECT H0"

    post `disagg_error_post' ///
        ("`model'") ("`dependent'") ("Pesaran CD") ///
        ("Cross-sectional independence of residuals") ///
        (`cd_stat') (.) (.) (`cd_p') ///
        (`disagg_diag_n') (`disagg_diag_countries') ///
        (`disagg_diag_first') (`disagg_diag_last') ///
        (1) (1) (`hhi_included') ///
        ("`cd_decision'") (`cd_rc') ///
        ("COMMON_COMPLETE") ("CLUSTER_COUNTRY") ///
        ("NOT_AUTHORIZED") (0) ///
        ("Una alerta de dependencia transversal exige revisión separada; no activa automáticamente Driscoll-Kraay, PCSE o CCE.")
}

drop `disagg_error_year_dummies'
postclose `disagg_error_post'

* Validar la completitud, la muestra y el alcance metodológico del bloque 4.
preserve
    use "`disagg_error_report'", clear
    isid model test
    assert _N == 6
    bysort model: assert _N == 3
    assert inlist(model, "ECI", "DIVX")
    assert inlist(test, ///
        "Modified Wald", ///
        "Wooldridge AR(1)", ///
        "Pesaran CD")
    assert observations == 1044
    assert countries == 49
    assert first_year == 1996
    assert last_year == 2021
    assert includes_country_fe == 1
    assert includes_year_fe == 1
    assert hhi_included == 1 if model == "ECI"
    assert hhi_included == 0 if model == "DIVX"
    assert return_code == 0
    assert !missing(statistic, p_value)
    assert inrange(p_value, 0, 1)
    assert decision == "REJECT H0" if p_value < 0.05
    assert decision == "DO NOT REJECT H0" if p_value >= 0.05
    assert main_inference == "CLUSTER_COUNTRY"
    assert alternative_status == "NOT_AUTHORIZED"
    assert model_change_authorized == 0
    format statistic df1 df2 p_value %12.6f
    sort model test
    export delimited using ///
        "$OUTPUT_DISAGG_DIAGNOSTICS/component_error_tests.csv", ///
        replace datafmt
restore

display as result ///
    "Bloque 4 validado: seis diagnósticos residuales desagregados."
display as result ///
    "No se activó Driscoll-Kraay, PCSE ni CCE."


// 20.5. Revisar distribuciones y observaciones influyentes

* Detectar observaciones influyentes (Leverage, Cook, Residuos).
tempfile influence_eci influence_divx
tempname influence_post
tempfile influence_summary

* Ejecutar la siguiente instrucción del bloque.
postfile `influence_post' str8 model long observations int parameters double leverage_cutoff cooks_cutoff long flagged_total flagged_leverage flagged_cooks flagged_residual double max_cooks max_abs_standardized_residual using "`influence_summary'", replace

* Iterar sobre los elementos del conjunto.
foreach model in ECI DIVX {
    local dependent "eci"
    local regressors "`regressors_eci'"
    local sample_flag "sample_eci_disagg"
    local influence_file "`influence_eci'"
    if "`model'" == "DIVX" {
        local dependent "divx"
        local regressors "`regressors_divx'"
        local sample_flag "sample_divx_disagg"
        local influence_file "`influence_divx'"
    }
    preserve
        quietly regress `dependent' `regressors' i.country_id i.year if `sample_flag' == 1
        local influence_n = e(N)
        local influence_k = e(df_m) + 1
        local leverage_threshold = 2 * `influence_k' / `influence_n'
        local cooks_threshold = 4 / `influence_n'

        // Evaluar condición de control de flujo.
        predict double leverage if e(sample), hat
        predict double cooks_distance if e(sample), cooksd
        predict double standardized_residual if e(sample), rstandard

        // Evaluar condición de control de flujo.
        generate byte flag_leverage = leverage > `leverage_threshold' if e(sample)
        generate byte flag_cooks = cooks_distance > `cooks_threshold' if e(sample)
        generate byte flag_residual = abs(standardized_residual) > 3 if e(sample)
        generate byte flag_any = flag_leverage | flag_cooks | flag_residual if e(sample)
        generate double abs_standardized_residual = abs(standardized_residual) if e(sample)

        // Evaluar condición de control de flujo.
        quietly count if flag_any == 1
        local flagged_total = r(N)
        * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
        quietly count if flag_leverage == 1
        local flagged_leverage = r(N)
        * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
        quietly count if flag_cooks == 1
        local flagged_cooks = r(N)
        * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
        quietly count if flag_residual == 1
        local flagged_residual = r(N)

        // Evaluar condición de control de flujo.
        quietly summarize cooks_distance if e(sample), meanonly
        local max_cooks = r(max)
        quietly summarize abs_standardized_residual if e(sample), meanonly
        local max_abs_residual = r(max)

        // Ejecutar la siguiente instrucción del bloque.
        post `influence_post' ("`model'") (`influence_n') (`influence_k') (`leverage_threshold') (`cooks_threshold') (`flagged_total') (`flagged_leverage') (`flagged_cooks') (`flagged_residual') (`max_cooks') (`max_abs_residual')

        // Evaluar condición de control de flujo.
        keep if flag_any == 1
        generate str8 model = "`model'"
        generate double dependent_value = `dependent'
        generate double leverage_cutoff = `leverage_threshold'
        generate double cooks_cutoff = `cooks_threshold'
        keep model country_iso3_code country country_id year dependent_value leverage leverage_cutoff cooks_distance cooks_cutoff standardized_residual flag_leverage flag_cooks flag_residual
        save "`influence_file'", replace
    restore
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `influence_post'

* Exportar el resumen de alertas de influencia por modelo.
preserve
    use "`influence_summary'", clear
    format leverage_cutoff cooks_cutoff max_cooks max_abs_standardized_residual %12.6f
    export delimited using "$OUTPUT_DISAGG_DIAGNOSTICS/influence_summary.csv", replace
restore

* Unir y exportar el detalle de las observaciones señaladas.
preserve
    use "`influence_eci'", clear
    append using "`influence_divx'"
    gsort model -cooks_distance
    format leverage leverage_cutoff cooks_distance cooks_cutoff standardized_residual %12.6f
    export delimited using "$OUTPUT_DISAGG_DIAGNOSTICS/influential_observations.csv", replace
restore

* Cerrar los diagnósticos sin excluir países ni observaciones.
display as result "Sección 20 completada: diagnósticos desagregados exportados."
display as result "No se eliminaron países ni observaciones."


// *****************************************************************************
// 21. Modelo Desagregado Integrado con ECI
// *****************************************************************************

// 21.1. Definir la muestra ECI comparable

* Habilitar dependencias y verificar cobertura de la muestra ECI desagregada.
capture mkdir "$OUTPUT_DISAGG_ECI"

* Iterar sobre los elementos del conjunto.
foreach command in reghdfe esttab {
    capture which `command'
    if _rc {
        display as error "No se encontró `command'; ejecute primero el archivo 04."
        exit 199
    }
}

* Evaluar condición de control de flujo.
quietly count if sample_eci_disagg == 1
local eci_expected_n = r(N)
quietly levelsof country_id if sample_eci_disagg == 1, local(eci_expected_ids)
local eci_expected_countries : word count `eci_expected_ids'
quietly levelsof year if sample_eci_disagg == 1, local(eci_expected_years)
local eci_expected_year_count : word count `eci_expected_years'
quietly summarize year if sample_eci_disagg == 1, meanonly
local eci_first_year = r(min)
local eci_last_year = r(max)

* Validar la integridad de los datos.
assert `eci_expected_n' == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `eci_expected_countries' == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `eci_expected_year_count' == 23
* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_eci_disagg == sample_eci

* Iterar sobre los elementos del conjunto.
foreach structural_wgi_gap in 1997 1999 2001 {
    * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
    quietly count if year == `structural_wgi_gap' & sample_eci_disagg == 1
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert r(N) == 0
}

* Informar la cobertura efectiva de la muestra ECI validada.
display as text "Muestra ECI desagregada: `eci_expected_n' observaciones, `eci_expected_countries' países y `eci_expected_year_count' años."


// 21.2. Estimar la especificación ECI aprobada

* Estimar modelo TWFE desagregado para ECI con errores agrupados por país.
local eci_disagg_terms rents_oil_gas rents_mining inst c.rents_oil_gas#c.inst c.rents_mining#c.inst ln1p_oilpc ln1p_gaspc ln1p_coalpc hhi pexp fexp vol rer humcap innov net log_gdppc govcons fin

* Evaluar condición de control de flujo.
xtreg eci $DISAGG_ECI_REGRESSORS i.year if sample_eci_disagg == 1, fe vce(cluster country_id)
capture estimates drop ECI_TWFE_DISAGG
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_TWFE_DISAGG
estimates save "$OUTPUT_DISAGG_ECI/eci_twfe_disaggregated.ster", replace

* Validar la integridad de los datos.
peer2_assert_estimation_contract, ///
    sample(sample_eci_disagg) observations(`eci_expected_n') ///
    countries(`eci_expected_countries') clusters(`eci_expected_countries')

* Recuperar métricas de ajuste del modelo.
local eci_n = e(N)
local eci_countries = e(N_g)
local eci_clusters = e(N_clust)
local eci_r2_within = e(r2_w)
local eci_r2_between = e(r2_b)
local eci_r2_overall = e(r2_o)
local eci_f = e(F)
local eci_df_model = e(df_m)
local eci_df_error = e(df_r)
local eci_model_p = e(p)
local eci_rmse = e(rmse)
local eci_sigma_u = e(sigma_u)
local eci_sigma_e = e(sigma_e)
local eci_rho = e(rho)

* Validar la integridad de los datos.
assert `eci_df_error' == `eci_clusters' - 1

* Exportar la tabla de coeficientes detallada.
tempname eci_coefficients_post
tempfile eci_coefficients_report

* Ejecutar la siguiente instrucción del bloque.
postfile `eci_coefficients_post' int order str32 term str100 variable_label str36 channel double coefficient standard_error t_statistic p_value ci_lower ci_upper using "`eci_coefficients_report'", replace

* Ejecutar la siguiente instrucción del bloque.
local eci_critical_t = invttail(`eci_df_error', 0.025)
local eci_term_order = 0

* Iterar sobre los elementos del conjunto.
foreach term of local eci_disagg_terms {
    local ++eci_term_order
    local term_label "`term'"
    if "`term'" == "c.rents_oil_gas#c.inst" {
        local term_label "RENTS_OIL_GAS x INST"
    }
    else if "`term'" == "c.rents_mining#c.inst" {
        local term_label "RENTS_MINING x INST"
    }
    else {
        local variable_label : variable label `term'
        if `"`variable_label'"' != "" {
            local term_label `"`variable_label'"'
        }
    }
    local channel "Controles económicos y financieros"
    if inlist("`term'", "rents_oil_gas", "rents_mining", "inst") {
        local channel "Institucional desagregado"
    }
    if inlist("`term'", "c.rents_oil_gas#c.inst", "c.rents_mining#c.inst") {
        local channel "Institucional desagregado"
    }
    else if inlist("`term'", "ln1p_oilpc", "ln1p_gaspc", "ln1p_coalpc") {
        local channel "Abundancia de recursos"
    }
    else if inlist("`term'", "hhi", "pexp", "fexp") {
        local channel "Estructura exportadora"
    }
    else if inlist("`term'", "vol", "rer") {
        local channel "Condiciones macroeconómicas"
    }
    else if inlist("`term'", "humcap", "innov", "net") {
        local channel "Capacidades productivas"
    }
    local coefficient = _b[`term']
    local standard_error = _se[`term']
    local t_statistic = `coefficient' / `standard_error'
    local p_value = 2 * ttail(`eci_df_error', abs(`t_statistic'))
    local ci_lower = `coefficient' - `eci_critical_t' * `standard_error'
    local ci_upper = `coefficient' + `eci_critical_t' * `standard_error'

    // Ejecutar la siguiente instrucción del bloque.
    scalar eci_disagg_xtreg_b_`eci_term_order' = `coefficient'
    scalar eci_disagg_xtreg_se_`eci_term_order' = `standard_error'

    // Ejecutar la siguiente instrucción del bloque.
    post `eci_coefficients_post' (`eci_term_order') ("`term'") (`"`term_label'"') ("`channel'") (`coefficient') (`standard_error') (`t_statistic') (`p_value') (`ci_lower') (`ci_upper')
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `eci_coefficients_post'

* Ejecutar la siguiente instrucción del bloque.
preserve
    use "`eci_coefficients_report'", clear
    sort order
    format coefficient standard_error t_statistic ci_lower ci_upper %16.10f
    format p_value %12.10f
    export delimited using "$OUTPUT_DISAGG_ECI/eci_disaggregated_coefficients.csv", replace
restore

* Exportar el resumen estadístico global del modelo ECI.
tempname eci_summary_post
tempfile eci_summary_report

* Ejecutar la siguiente instrucción del bloque.
postfile `eci_summary_post' str24 model str12 dependent_variable int observations countries clusters years first_year last_year double r2_within r2_between r2_overall f_statistic df_model df_error model_p_value rmse sigma_country sigma_idiosyncratic rho_country using "`eci_summary_report'", replace

* Ejecutar la siguiente instrucción del bloque.
post `eci_summary_post' ("ECI_TWFE_DISAGG") ("eci") (`eci_n') (`eci_countries') (`eci_clusters') (`eci_expected_year_count') (`eci_first_year') (`eci_last_year') (`eci_r2_within') (`eci_r2_between') (`eci_r2_overall') (`eci_f') (`eci_df_model') (`eci_df_error') (`eci_model_p') (`eci_rmse') (`eci_sigma_u') (`eci_sigma_e') (`eci_rho')
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `eci_summary_post'

* Ejecutar la siguiente instrucción del bloque.
preserve
    use "`eci_summary_report'", clear
    format r2_within r2_between r2_overall f_statistic model_p_value rmse sigma_country sigma_idiosyncratic rho_country %12.6f
    export delimited using "$OUTPUT_DISAGG_ECI/eci_disaggregated_model_summary.csv", replace
restore


// 21.3. Contrastar los componentes de RENTS

* Ejecutar las 7 pruebas de hipótesis predefinidas en el modelo ECI desagregado.
estimates restore ECI_TWFE_DISAGG
tempname eci_tests_post
tempfile eci_tests_report

* Ejecutar la siguiente instrucción del bloque.
postfile `eci_tests_post' int order str44 test str140 null_hypothesis double f_statistic df1 df2 p_value using "`eci_tests_report'", replace

* Ejecutar la siguiente instrucción del bloque.
test rents_oil_gas c.rents_oil_gas#c.inst
local eci_p_oil_gas_joint = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' (1) ("Hidrocarburos: efecto conjunto") ("RENTS_OIL_GAS y su interacción son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
test rents_mining c.rents_mining#c.inst
local eci_p_mining_joint = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' (2) ("Minería: efecto conjunto") ("RENTS_MINING y su interacción son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
test c.rents_oil_gas#c.inst c.rents_mining#c.inst
local eci_p_interactions_joint = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' (3) ("Interacciones conjuntas") ("Las dos interacciones institucionales son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
test rents_oil_gas = rents_mining
local eci_p_equal_levels = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' (4) ("Igualdad de coeficientes directos") ("Los coeficientes directos de ambos componentes son iguales") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
test c.rents_oil_gas#c.inst = c.rents_mining#c.inst
local eci_p_equal_interactions = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' (5) ("Igualdad de interacciones") ("Las interacciones institucionales de ambos componentes son iguales") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
test (rents_oil_gas = rents_mining) (c.rents_oil_gas#c.inst = c.rents_mining#c.inst)
local eci_p_aggregate_restriction = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' (6) ("Restricción del modelo agregado") ("Coeficientes directos e interacciones son iguales entre componentes") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
test rents_oil_gas rents_mining c.rents_oil_gas#c.inst c.rents_mining#c.inst
local eci_p_focal_joint = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' (7) ("Términos desagregados conjuntos") ("Los cuatro términos desagregados son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
postclose `eci_tests_post'

* Ejecutar la siguiente instrucción del bloque.
preserve
    use "`eci_tests_report'", clear
    sort order
    format f_statistic p_value %12.6f
    export delimited using "$OUTPUT_DISAGG_ECI/eci_disaggregated_tests.csv", replace
restore

* Verificar coeficientes mediante estimación alternativa con reghdfe.
reghdfe eci $DISAGG_ECI_REGRESSORS if sample_eci_disagg == 1, absorb(country_id year) vce(cluster country_id)
capture estimates drop ECI_REGHDFE_DISAGG_CHECK
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_REGHDFE_DISAGG_CHECK
estimates save "$OUTPUT_DISAGG_ECI/eci_reghdfe_disaggregated_check.ster", replace

* Validar la integridad de los datos.
assert e(N) == `eci_n'
local coefficient_tolerance = 1e-8
local max_coefficient_difference = 0

* Ejecutar la siguiente instrucción del bloque.
tempname eci_verification_post
tempfile eci_verification_report

* Ejecutar la siguiente instrucción del bloque.
postfile `eci_verification_post' int order str32 term double xtreg_coefficient reghdfe_coefficient absolute_coefficient_difference xtreg_standard_error reghdfe_standard_error absolute_se_difference byte coefficient_match using "`eci_verification_report'", replace

* Ejecutar la siguiente instrucción del bloque.
local eci_term_order = 0
foreach term of local eci_disagg_terms {
    local ++eci_term_order
    local xtreg_coefficient = scalar(eci_disagg_xtreg_b_`eci_term_order')
    local xtreg_standard_error = scalar(eci_disagg_xtreg_se_`eci_term_order')
    local reghdfe_coefficient = _b[`term']
    local reghdfe_standard_error = _se[`term']
    local coefficient_difference = abs(`xtreg_coefficient' - `reghdfe_coefficient')
    local se_difference = abs(`xtreg_standard_error' - `reghdfe_standard_error')
    local coefficient_match = `coefficient_difference' < `coefficient_tolerance'
    if `coefficient_difference' > `max_coefficient_difference' {
        local max_coefficient_difference = `coefficient_difference'
    }
    * Escribir una fila de resultados dentro del archivo temporal.
    post `eci_verification_post' (`eci_term_order') ("`term'") (`xtreg_coefficient') (`reghdfe_coefficient') (`coefficient_difference') (`xtreg_standard_error') (`reghdfe_standard_error') (`se_difference') (`coefficient_match')
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `eci_verification_post'

* Validar la integridad de los datos.
assert `max_coefficient_difference' < `coefficient_tolerance'

* Ejecutar la siguiente instrucción del bloque.
preserve
    use "`eci_verification_report'", clear
    sort order
    format xtreg_coefficient reghdfe_coefficient absolute_coefficient_difference xtreg_standard_error reghdfe_standard_error absolute_se_difference %16.10f
    export delimited using "$OUTPUT_DISAGG_ECI/eci_xtreg_reghdfe_verification.csv", replace
restore


// 21.4. Comparar con el modelo ECI agregado

* Cargar la estimación de referencia agregada y verificar consistencia de muestra.
capture confirm file "$OUTPUT_ECI/eci_twfe_main.ster"
if _rc {
    display as error "No se encontró el modelo ECI agregado guardado."
    exit 601
}

* Cargar el archivo de datos.
estimates use "$OUTPUT_ECI/eci_twfe_main.ster"
capture estimates drop ECI_TWFE_MAIN_REFERENCE
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_TWFE_MAIN_REFERENCE

* Validar la integridad de los datos.
assert e(N) == `eci_n'
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == `eci_countries'

* Ejecutar la siguiente instrucción del bloque.
local aggregate_r2_within = e(r2_w)
local aggregate_r2_between = e(r2_b)
local aggregate_r2_overall = e(r2_o)
local aggregate_f = e(F)
local aggregate_p = e(p)
local aggregate_rmse = e(rmse)
local aggregate_df_model = e(df_m)

* Exportar reporte comparativo del modelo ECI Agregado vs. Desagregado.
tempname model_comparison_post
tempfile model_comparison_report

* Ejecutar la siguiente instrucción del bloque.
postfile `model_comparison_post' str28 model str16 rent_structure int observations countries clusters double r2_within r2_between r2_overall f_statistic model_p_value rmse df_model using "`model_comparison_report'", replace

* Ejecutar la siguiente instrucción del bloque.
post `model_comparison_post' ("ECI_TWFE_MAIN") ("aggregate") (`eci_n') (`eci_countries') (`eci_clusters') (`aggregate_r2_within') (`aggregate_r2_between') (`aggregate_r2_overall') (`aggregate_f') (`aggregate_p') (`aggregate_rmse') (`aggregate_df_model')
* Escribir una fila de resultados dentro del archivo temporal.
post `model_comparison_post' ("ECI_TWFE_DISAGG") ("disaggregated") (`eci_n') (`eci_countries') (`eci_clusters') (`eci_r2_within') (`eci_r2_between') (`eci_r2_overall') (`eci_f') (`eci_model_p') (`eci_rmse') (`eci_df_model')
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `model_comparison_post'

* Ejecutar la siguiente instrucción del bloque.
preserve
    use "`model_comparison_report'", clear
    format r2_within r2_between r2_overall f_statistic model_p_value rmse %12.6f
    export delimited using "$OUTPUT_DISAGG_ECI/eci_aggregate_disaggregated_model_comparison.csv", replace
restore

* Exportar comparación de términos focales de rentas.
tempname focal_comparison_post
tempfile focal_comparison_report

* Ejecutar la siguiente instrucción del bloque.
postfile `focal_comparison_post' str28 model str24 component str32 term double coefficient standard_error t_statistic p_value ci_lower ci_upper using "`focal_comparison_report'", replace

* Iterar sobre los elementos del conjunto.
foreach specification in AGGREGATE DISAGGREGATED {
    local focal_terms "rents c.rents#c.inst"
    if "`specification'" == "AGGREGATE" {
        * Restaurar una estimación previa desde la memoria de Stata.
        estimates restore ECI_TWFE_MAIN_REFERENCE
    }
    else {
        * Restaurar una estimación previa desde la memoria de Stata.
        estimates restore ECI_TWFE_DISAGG
        local focal_terms rents_oil_gas rents_mining c.rents_oil_gas#c.inst c.rents_mining#c.inst
    }
    foreach term of local focal_terms {
        local component "aggregate"
        if strpos("`term'", "oil_gas") local component "oil_gas"
        if strpos("`term'", "mining") local component "mining"
        local coefficient = _b[`term']
        local standard_error = _se[`term']
        local t_statistic = `coefficient' / `standard_error'
        local p_value = 2 * ttail(`eci_df_error', abs(`t_statistic'))
        local ci_lower = `coefficient' - `eci_critical_t' * `standard_error'
        local ci_upper = `coefficient' + `eci_critical_t' * `standard_error'

        // Ejecutar la siguiente instrucción del bloque.
        post `focal_comparison_post' ("ECI_`specification'") ("`component'") ("`term'") (`coefficient') (`standard_error') (`t_statistic') (`p_value') (`ci_lower') (`ci_upper')
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `focal_comparison_post'

* Ejecutar la siguiente instrucción del bloque.
preserve
    use "`focal_comparison_report'", clear
    format coefficient standard_error t_statistic ci_lower ci_upper %16.10f
    format p_value %12.10f
    export delimited using "$OUTPUT_DISAGG_ECI/eci_aggregate_disaggregated_focal_comparison.csv", replace
restore

* Exportar tabla comparativa en formato LaTeX (.tex).
esttab ECI_TWFE_MAIN_REFERENCE ECI_TWFE_DISAGG using "$OUTPUT_DISAGG_ECI/eci_aggregate_disaggregated_table.tex", replace label booktabs b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) keep(rents rents_oil_gas rents_mining inst c.rents#c.inst c.rents_oil_gas#c.inst c.rents_mining#c.inst) order(rents rents_oil_gas rents_mining inst c.rents#c.inst c.rents_oil_gas#c.inst c.rents_mining#c.inst) coeflabels(rents "RENTS agregado" rents_oil_gas "RENTS petróleo + gas" rents_mining "RENTS minería + carbón" c.rents#c.inst "RENTS agregado x INST" c.rents_oil_gas#c.inst "RENTS petróleo + gas x INST" c.rents_mining#c.inst "RENTS minería + carbón x INST") stats(N N_g r2_w, fmt(0 0 4) labels("Observaciones" "Países" "R2 within")) addnotes("Efectos fijos por país y año." "Errores estándar agrupados por país." "La extensión no reemplaza el modelo agregado.")

* Restaurar la estimación oficial y notificar la aprobación del Control H.
estimates restore ECI_TWFE_DISAGG
display as result "Sección 11 completada: modelo ECI desagregado estimado y verificado."
display as result "Control H aprobado: resultados ECI revisados y comparación cerrada."
display as text "La restricción agregada obtuvo p = " %7.4f `eci_p_aggregate_restriction' "."


// *****************************************************************************
// 22. Modelo Desagregado Integrado con DIVX
// *****************************************************************************

// 22.1. Definir la muestra DIVX comparable

* Habilitar directorio y validar consistencia de la muestra DIVX desagregada.
capture mkdir "$OUTPUT_DISAGG_DIVX"

* Evaluar condición de control de flujo.
quietly count if sample_divx_disagg == 1
local divx_expected_n = r(N)
quietly levelsof country_id if sample_divx_disagg == 1, local(divx_expected_ids)
local divx_expected_countries : word count `divx_expected_ids'
quietly levelsof year if sample_divx_disagg == 1, local(divx_expected_years)
local divx_expected_year_count : word count `divx_expected_years'
quietly summarize year if sample_divx_disagg == 1, meanonly
local divx_first_year = r(min)
local divx_last_year = r(max)

* Validar la integridad de los datos.
assert `divx_expected_n' == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `divx_expected_countries' == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `divx_expected_year_count' == 23
* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_divx_disagg == sample_divx
* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_divx_disagg == sample_eci_disagg

* Iterar sobre los elementos del conjunto.
foreach structural_wgi_gap in 1997 1999 2001 {
    * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
    quietly count if year == `structural_wgi_gap' & sample_divx_disagg == 1
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert r(N) == 0
}

* Informar la cobertura efectiva de la muestra DIVX validada.
display as text "Muestra DIVX desagregada: `divx_expected_n' observaciones, `divx_expected_countries' países y `divx_expected_year_count' años."


// 22.2. Estimar la especificación DIVX aprobada

* Estimar modelo TWFE desagregado para DIVX (excluyendo HHI).
local divx_disagg_terms rents_oil_gas rents_mining inst c.rents_oil_gas#c.inst c.rents_mining#c.inst ln1p_oilpc ln1p_gaspc ln1p_coalpc pexp fexp vol rer humcap innov net log_gdppc govcons fin

* Evaluar condición de control de flujo.
xtreg divx $DISAGG_DIVX_REGRESSORS i.year if sample_divx_disagg == 1, fe vce(cluster country_id)
capture estimates drop DIVX_TWFE_DISAGG
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_TWFE_DISAGG
estimates save "$OUTPUT_DISAGG_DIVX/divx_twfe_disaggregated.ster", replace

* Validar la integridad de los datos.
peer2_assert_estimation_contract, ///
    sample(sample_divx_disagg) observations(`divx_expected_n') ///
    countries(`divx_expected_countries') clusters(`divx_expected_countries')

* Conservar métricas de ajuste para DIVX.
local divx_n = e(N)
local divx_countries = e(N_g)
local divx_clusters = e(N_clust)
local divx_r2_within = e(r2_w)
local divx_r2_between = e(r2_b)
local divx_r2_overall = e(r2_o)
local divx_f = e(F)
local divx_df_model = e(df_m)
local divx_df_error = e(df_r)
local divx_model_p = e(p)
local divx_rmse = e(rmse)
local divx_sigma_u = e(sigma_u)
local divx_sigma_e = e(sigma_e)
local divx_rho = e(rho)

* Validar la integridad de los datos.
assert `divx_df_error' == `divx_clusters' - 1

* Exportar tabla de coeficientes detallada de DIVX.
tempname divx_coefficients_post
tempfile divx_coefficients_report

* Ejecutar la siguiente instrucción del bloque.
postfile `divx_coefficients_post' int order str32 term str100 variable_label str36 channel double coefficient standard_error t_statistic p_value ci_lower ci_upper using "`divx_coefficients_report'", replace

* Ejecutar la siguiente instrucción del bloque.
local divx_critical_t = invttail(`divx_df_error', 0.025)
local divx_term_order = 0

* Iterar sobre los elementos del conjunto.
foreach term of local divx_disagg_terms {
    local ++divx_term_order
    local term_label "`term'"
    if "`term'" == "c.rents_oil_gas#c.inst" {
        local term_label "RENTS_OIL_GAS x INST"
    }
    else if "`term'" == "c.rents_mining#c.inst" {
        local term_label "RENTS_MINING x INST"
    }
    else {
        local variable_label : variable label `term'
        if `"`variable_label'"' != "" {
            local term_label `"`variable_label'"'
        }
    }
    local channel "Controles económicos y financieros"
    if inlist("`term'", "rents_oil_gas", "rents_mining", "inst") {
        local channel "Institucional desagregado"
    }
    if inlist("`term'", "c.rents_oil_gas#c.inst", "c.rents_mining#c.inst") {
        local channel "Institucional desagregado"
    }
    else if inlist("`term'", "ln1p_oilpc", "ln1p_gaspc", "ln1p_coalpc") {
        local channel "Abundancia de recursos"
    }
    else if inlist("`term'", "pexp", "fexp") {
        local channel "Estructura exportadora"
    }
    else if inlist("`term'", "vol", "rer") {
        local channel "Condiciones macroeconómicas"
    }
    else if inlist("`term'", "humcap", "innov", "net") {
        local channel "Capacidades productivas"
    }
    local coefficient = _b[`term']
    local standard_error = _se[`term']
    local t_statistic = `coefficient' / `standard_error'
    local p_value = 2 * ttail(`divx_df_error', abs(`t_statistic'))
    local ci_lower = `coefficient' - `divx_critical_t' * `standard_error'
    local ci_upper = `coefficient' + `divx_critical_t' * `standard_error'

    // Ejecutar la siguiente instrucción del bloque.
    scalar divx_disagg_xtreg_b_`divx_term_order' = `coefficient'
    scalar divx_disagg_xtreg_se_`divx_term_order' = `standard_error'

    // Ejecutar la siguiente instrucción del bloque.
    post `divx_coefficients_post' (`divx_term_order') ("`term'") (`"`term_label'"') ("`channel'") (`coefficient') (`standard_error') (`t_statistic') (`p_value') (`ci_lower') (`ci_upper')
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `divx_coefficients_post'

* Ejecutar la siguiente instrucción del bloque.
preserve
    use "`divx_coefficients_report'", clear
    sort order
    format coefficient standard_error t_statistic ci_lower ci_upper %16.10f
    format p_value %12.10f
    export delimited using "$OUTPUT_DISAGG_DIVX/divx_disaggregated_coefficients.csv", replace
restore

* Exportar resumen estadístico global del modelo DIVX.
tempname divx_summary_post
tempfile divx_summary_report

* Ejecutar la siguiente instrucción del bloque.
postfile `divx_summary_post' str24 model str12 dependent_variable int observations countries clusters years first_year last_year double r2_within r2_between r2_overall f_statistic df_model df_error model_p_value rmse sigma_country sigma_idiosyncratic rho_country using "`divx_summary_report'", replace

* Ejecutar la siguiente instrucción del bloque.
post `divx_summary_post' ("DIVX_TWFE_DISAGG") ("divx") (`divx_n') (`divx_countries') (`divx_clusters') (`divx_expected_year_count') (`divx_first_year') (`divx_last_year') (`divx_r2_within') (`divx_r2_between') (`divx_r2_overall') (`divx_f') (`divx_df_model') (`divx_df_error') (`divx_model_p') (`divx_rmse') (`divx_sigma_u') (`divx_sigma_e') (`divx_rho')
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `divx_summary_post'

* Ejecutar la siguiente instrucción del bloque.
preserve
    use "`divx_summary_report'", clear
    format r2_within r2_between r2_overall f_statistic rmse sigma_country sigma_idiosyncratic rho_country %12.6f
    format model_p_value %12.6e
    export delimited using "$OUTPUT_DISAGG_DIVX/divx_disaggregated_model_summary.csv", replace
restore


// 22.3. Contrastar los componentes de RENTS

* Ejecutar las 7 pruebas de hipótesis predefinidas para DIVX.
estimates restore DIVX_TWFE_DISAGG
tempname divx_tests_post
tempfile divx_tests_report

* Ejecutar la siguiente instrucción del bloque.
postfile `divx_tests_post' int order str44 test str140 null_hypothesis double f_statistic df1 df2 p_value using "`divx_tests_report'", replace

* Ejecutar la siguiente instrucción del bloque.
test rents_oil_gas c.rents_oil_gas#c.inst
local divx_p_oil_gas_joint = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' (1) ("Hidrocarburos: efecto conjunto") ("RENTS_OIL_GAS y su interacción son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
test rents_mining c.rents_mining#c.inst
local divx_p_mining_joint = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' (2) ("Minería: efecto conjunto") ("RENTS_MINING y su interacción son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
test c.rents_oil_gas#c.inst c.rents_mining#c.inst
local divx_p_interactions_joint = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' (3) ("Interacciones conjuntas") ("Las dos interacciones institucionales son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
test rents_oil_gas = rents_mining
local divx_p_equal_levels = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' (4) ("Igualdad de coeficientes directos") ("Los coeficientes directos de ambos componentes son iguales") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
test c.rents_oil_gas#c.inst = c.rents_mining#c.inst
local divx_p_equal_interactions = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' (5) ("Igualdad de interacciones") ("Las interacciones institucionales de ambos componentes son iguales") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
test (rents_oil_gas = rents_mining) (c.rents_oil_gas#c.inst = c.rents_mining#c.inst)
local divx_p_aggregate_restriction = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' (6) ("Restricción del modelo agregado") ("Coeficientes directos e interacciones son iguales entre componentes") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
test rents_oil_gas rents_mining c.rents_oil_gas#c.inst c.rents_mining#c.inst
local divx_p_focal_joint = r(p)
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' (7) ("Términos desagregados conjuntos") ("Los cuatro términos desagregados son conjuntamente cero") (r(F)) (r(df)) (r(df_r)) (r(p))

* Ejecutar la siguiente instrucción del bloque.
postclose `divx_tests_post'

* Ejecutar la siguiente instrucción del bloque.
preserve
    use "`divx_tests_report'", clear
    sort order
    format f_statistic p_value %12.6f
    export delimited using "$OUTPUT_DISAGG_DIVX/divx_disaggregated_tests.csv", replace
restore

* Verificar coeficientes mediante estimación alternativa con reghdfe.
reghdfe divx $DISAGG_DIVX_REGRESSORS if sample_divx_disagg == 1, absorb(country_id year) vce(cluster country_id)
capture estimates drop DIVX_REGHDFE_DISAGG_CHECK
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_REGHDFE_DISAGG_CHECK
estimates save "$OUTPUT_DISAGG_DIVX/divx_reghdfe_disaggregated_check.ster", replace

* Validar la integridad de los datos.
assert e(N) == `divx_n'
local divx_coefficient_tolerance = 1e-8
local divx_max_coefficient_difference = 0

* Ejecutar la siguiente instrucción del bloque.
tempname divx_verification_post
tempfile divx_verification_report

* Ejecutar la siguiente instrucción del bloque.
postfile `divx_verification_post' int order str32 term double xtreg_coefficient reghdfe_coefficient absolute_coefficient_difference xtreg_standard_error reghdfe_standard_error absolute_se_difference byte coefficient_match using "`divx_verification_report'", replace

* Ejecutar la siguiente instrucción del bloque.
local divx_term_order = 0
foreach term of local divx_disagg_terms {
    local ++divx_term_order
    local xtreg_coefficient = scalar(divx_disagg_xtreg_b_`divx_term_order')
    local xtreg_standard_error = scalar(divx_disagg_xtreg_se_`divx_term_order')
    local reghdfe_coefficient = _b[`term']
    local reghdfe_standard_error = _se[`term']
    local coefficient_difference = abs(`xtreg_coefficient' - `reghdfe_coefficient')
    local se_difference = abs(`xtreg_standard_error' - `reghdfe_standard_error')
    local coefficient_match = `coefficient_difference' < `divx_coefficient_tolerance'
    if `coefficient_difference' > `divx_max_coefficient_difference' {
        local divx_max_coefficient_difference = `coefficient_difference'
    }
    * Escribir una fila de resultados dentro del archivo temporal.
    post `divx_verification_post' (`divx_term_order') ("`term'") (`xtreg_coefficient') (`reghdfe_coefficient') (`coefficient_difference') (`xtreg_standard_error') (`reghdfe_standard_error') (`se_difference') (`coefficient_match')
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `divx_verification_post'

* Validar la integridad de los datos.
assert `divx_max_coefficient_difference' < `divx_coefficient_tolerance'

* Ejecutar la siguiente instrucción del bloque.
preserve
    use "`divx_verification_report'", clear
    sort order
    format xtreg_coefficient reghdfe_coefficient absolute_coefficient_difference xtreg_standard_error reghdfe_standard_error absolute_se_difference %16.10f
    export delimited using "$OUTPUT_DISAGG_DIVX/divx_xtreg_reghdfe_verification.csv", replace
restore


// 22.4. Comparar con el modelo DIVX agregado

* Cargar la estimación agregada de referencia para DIVX.
capture confirm file "$OUTPUT_DIVX/divx_twfe_main.ster"
if _rc {
    display as error "No se encontró el modelo DIVX agregado guardado."
    exit 601
}

* Cargar el archivo de datos.
estimates use "$OUTPUT_DIVX/divx_twfe_main.ster"
capture estimates drop DIVX_TWFE_MAIN_REFERENCE
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_TWFE_MAIN_REFERENCE

* Validar la integridad de los datos.
assert e(N) == `divx_n'
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == `divx_countries'

* Ejecutar la siguiente instrucción del bloque.
local divx_aggregate_r2_within = e(r2_w)
local divx_aggregate_r2_between = e(r2_b)
local divx_aggregate_r2_overall = e(r2_o)
local divx_aggregate_f = e(F)
local divx_aggregate_p = e(p)
local divx_aggregate_rmse = e(rmse)
local divx_aggregate_df_model = e(df_m)

* Exportar reporte comparativo de modelos DIVX.
tempname divx_model_comparison_post
tempfile divx_model_comparison_report

* Ejecutar la siguiente instrucción del bloque.
postfile `divx_model_comparison_post' str28 model str16 rent_structure int observations countries clusters double r2_within r2_between r2_overall f_statistic model_p_value rmse df_model using "`divx_model_comparison_report'", replace

* Ejecutar la siguiente instrucción del bloque.
post `divx_model_comparison_post' ("DIVX_TWFE_MAIN") ("aggregate") (`divx_n') (`divx_countries') (`divx_clusters') (`divx_aggregate_r2_within') (`divx_aggregate_r2_between') (`divx_aggregate_r2_overall') (`divx_aggregate_f') (`divx_aggregate_p') (`divx_aggregate_rmse') (`divx_aggregate_df_model')
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_model_comparison_post' ("DIVX_TWFE_DISAGG") ("disaggregated") (`divx_n') (`divx_countries') (`divx_clusters') (`divx_r2_within') (`divx_r2_between') (`divx_r2_overall') (`divx_f') (`divx_model_p') (`divx_rmse') (`divx_df_model')
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `divx_model_comparison_post'

* Ejecutar la siguiente instrucción del bloque.
preserve
    use "`divx_model_comparison_report'", clear
    format r2_within r2_between r2_overall f_statistic rmse %12.6f
    format model_p_value %12.6e
    export delimited using "$OUTPUT_DISAGG_DIVX/divx_aggregate_disaggregated_model_comparison.csv", replace
restore

* Exportar comparación de términos focales de DIVX.
tempname divx_focal_comparison_post
tempfile divx_focal_comparison_report

* Ejecutar la siguiente instrucción del bloque.
postfile `divx_focal_comparison_post' str28 model str24 component str32 term double coefficient standard_error t_statistic p_value ci_lower ci_upper using "`divx_focal_comparison_report'", replace

* Iterar sobre los elementos del conjunto.
foreach specification in AGGREGATE DISAGGREGATED {
    local focal_terms "rents c.rents#c.inst"
    if "`specification'" == "AGGREGATE" {
        * Restaurar una estimación previa desde la memoria de Stata.
        estimates restore DIVX_TWFE_MAIN_REFERENCE
    }
    else {
        * Restaurar una estimación previa desde la memoria de Stata.
        estimates restore DIVX_TWFE_DISAGG
        local focal_terms rents_oil_gas rents_mining c.rents_oil_gas#c.inst c.rents_mining#c.inst
    }
    foreach term of local focal_terms {
        local component "aggregate"
        if strpos("`term'", "oil_gas") local component "oil_gas"
        if strpos("`term'", "mining") local component "mining"
        local coefficient = _b[`term']
        local standard_error = _se[`term']
        local t_statistic = `coefficient' / `standard_error'
        local p_value = 2 * ttail(`divx_df_error', abs(`t_statistic'))
        local ci_lower = `coefficient' - `divx_critical_t' * `standard_error'
        local ci_upper = `coefficient' + `divx_critical_t' * `standard_error'

        // Ejecutar la siguiente instrucción del bloque.
        post `divx_focal_comparison_post' ("DIVX_`specification'") ("`component'") ("`term'") (`coefficient') (`standard_error') (`t_statistic') (`p_value') (`ci_lower') (`ci_upper')
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `divx_focal_comparison_post'

* Ejecutar la siguiente instrucción del bloque.
preserve
    use "`divx_focal_comparison_report'", clear
    format coefficient standard_error t_statistic ci_lower ci_upper %16.10f
    format p_value %12.10f
    export delimited using "$OUTPUT_DISAGG_DIVX/divx_aggregate_disaggregated_focal_comparison.csv", replace
restore

* Exportar tabla comparativa en formato LaTeX (.tex).
esttab DIVX_TWFE_MAIN_REFERENCE DIVX_TWFE_DISAGG using "$OUTPUT_DISAGG_DIVX/divx_aggregate_disaggregated_table.tex", replace label booktabs b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) keep(rents rents_oil_gas rents_mining inst c.rents#c.inst c.rents_oil_gas#c.inst c.rents_mining#c.inst) order(rents rents_oil_gas rents_mining inst c.rents#c.inst c.rents_oil_gas#c.inst c.rents_mining#c.inst) coeflabels(rents "RENTS agregado" rents_oil_gas "RENTS petróleo + gas" rents_mining "RENTS minería + carbón" c.rents#c.inst "RENTS agregado x INST" c.rents_oil_gas#c.inst "RENTS petróleo + gas x INST" c.rents_mining#c.inst "RENTS minería + carbón x INST") stats(N N_g r2_w, fmt(0 0 4) labels("Observaciones" "Países" "R2 within")) addnotes("Efectos fijos por país y año." "Errores estándar agrupados por país." "HHI se excluye porque DIVX = 1 - HHI." "La extensión no reemplaza el modelo agregado.")

* Restaurar la estimación oficial y notificar la aprobación del Control I.
estimates restore DIVX_TWFE_DISAGG
display as result "Sección 12 completada: modelo DIVX desagregado estimado y verificado."
display as result "Control I aprobado: resultados DIVX revisados y comparación cerrada."
display as text "La restricción agregada obtuvo p = " %7.4f `divx_p_aggregate_restriction' "."


// *****************************************************************************
// 23. Estabilidad y Efectos Marginales por Componente
// *****************************************************************************

// 23.1. Calcular efectos marginales según INST

* Preparar la carpeta, verificar boottest y obtener los percentiles comunes de INST.
capture mkdir "$OUTPUT_DISAGG_STABILITY"
capture which boottest
if _rc {
    display as error "No se encontró boottest; ejecute primero el archivo 04."
    exit 199
}
quietly summarize inst if sample_eci_disagg == 1, detail
local disagg_inst_p10 = r(p10)
local disagg_inst_p25 = r(p25)
local disagg_inst_p50 = r(p50)
local disagg_inst_p75 = r(p75)
local disagg_inst_p90 = r(p90)
local disagg_inst_values ///
    "`disagg_inst_p10' `disagg_inst_p25' `disagg_inst_p50' `disagg_inst_p75' `disagg_inst_p90'"
local disagg_inst_labels "P10 P25 P50 P75 P90"

* Crear el reporte consolidado de veinte efectos marginales por componente.
tempname disagg_margins_post
tempfile disagg_margins_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `disagg_margins_post' ///
    str8 model str12 component str32 term str4 percentile ///
    double inst_value marginal_effect standard_error ///
    t_statistic p_value ci_lower ci_upper ///
    str16 significance ///
    using "`disagg_margins_report'", replace

* Estimar cada modelo y evaluar ambos componentes en los cinco percentiles de INST.
foreach model in ECI DIVX {
    local dependent "eci"
    local regressors "$DISAGG_ECI_REGRESSORS"
    local sample_flag "sample_eci_disagg"
    local outcome_title "Complejidad económica"
    local color_oil_gas "navy"
    local color_mining "dkorange"
    if "`model'" == "DIVX" {
        local dependent "divx"
        local regressors "$DISAGG_DIVX_REGRESSORS"
        local sample_flag "sample_divx_disagg"
        local outcome_title "Diversificación exportadora"
        local color_oil_gas "maroon"
        local color_mining "purple"
    }

    // Estimar la especificación principal correspondiente al resultado.
    quietly xtreg `dependent' `regressors' i.year ///
        if `sample_flag' == 1, fe vce(cluster country_id)

    // Procesar por separado los componentes de hidrocarburos y minería.
    foreach component in oil_gas mining {
        local rent_term "rents_`component'"
        local component_title "Petróleo y gas"
        if "`component'" == "mining" {
            local component_title "Minería y carbón"
        }
        local graph_color "`color_`component''"
        local graph_name = lower("`model'_`component'_margins")
        local graph_file = lower("`model'_`component'_marginal_effect")

        // Calcular la asociación marginal en los cinco percentiles institucionales.
        margins, dydx(`rent_term') at(inst=(`disagg_inst_values'))
        matrix disagg_margin_table = r(table)

        // Graficar el perfil marginal con su intervalo de confianza.
        marginsplot, ///
            recast(line) recastci(rarea) ///
            plotopts(lcolor(`graph_color') lwidth(medthick)) ///
            ciopts(color(`graph_color'%25) lcolor(`graph_color'%45)) ///
            yline(0, lcolor(gs8) lpattern(dash)) ///
            xlabel( ///
                `disagg_inst_p10' "P10" ///
                `disagg_inst_p25' "P25" ///
                `disagg_inst_p50' "P50" ///
                `disagg_inst_p75' "P75" ///
                `disagg_inst_p90' "P90", ///
                labsize(small) angle(45)) ///
            ylabel(, labsize(small) angle(horizontal)) ///
            title("`outcome_title': `component_title' según INST", ///
                size(medium)) ///
            ytitle("Asociación marginal estimada") ///
            xtitle("Percentil de calidad institucional (INST)") ///
            name(`graph_name', replace)
        graph export ///
            "$OUTPUT_DISAGG_STABILITY/`graph_file'.pdf", replace
        graph export ///
            "$OUTPUT_DISAGG_STABILITY/`graph_file'.png", ///
            width(2400) replace

        // Registrar cada estimación marginal en el reporte consolidado.
        forvalues margin_column = 1/5 {
            local percentile : word `margin_column' of ///
                `disagg_inst_labels'
            local inst_value : word `margin_column' of ///
                `disagg_inst_values'
            local marginal_effect = ///
                el(disagg_margin_table, 1, `margin_column')
            local margin_se = ///
                el(disagg_margin_table, 2, `margin_column')
            local margin_t = ///
                el(disagg_margin_table, 3, `margin_column')
            local margin_p = ///
                el(disagg_margin_table, 4, `margin_column')
            local margin_low = ///
                el(disagg_margin_table, 5, `margin_column')
            local margin_high = ///
                el(disagg_margin_table, 6, `margin_column')
            local margin_significance "No"
            if `margin_p' < 0.10 local margin_significance "10%"
            if `margin_p' < 0.05 local margin_significance "5%"
            if `margin_p' < 0.01 local margin_significance "1%"
            * Escribir una fila de resultados dentro del archivo temporal.
            post `disagg_margins_post' ///
                ("`model'") ("`component'") ("`rent_term'") ///
                ("`percentile'") (`inst_value') ///
                (`marginal_effect') (`margin_se') (`margin_t') ///
                (`margin_p') (`margin_low') (`margin_high') ///
                ("`margin_significance'")
        }
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `disagg_margins_post'

* Exportar los efectos marginales sin seleccionar resultados por significancia.
preserve
    use "`disagg_margins_report'", clear
    sort model component inst_value
    format inst_value marginal_effect standard_error ///
        t_statistic p_value ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_DISAGG_STABILITY/component_marginal_effects_by_inst.csv", ///
        replace datafmt
restore

* Liberar objetos ya exportados antes de iniciar las reestimaciones masivas.
graph drop _all
capture estimates drop _all
matrix drop _all
mata: mata clear
mata: mata mlib index

* Recargar el panel y reconstruir las variables aprobadas para las sensibilidades.
clear
use "`estimation_file'", clear
* Comprobar que la combinación de identificadores de país y año sea única.
isid country_iso3_code year
* Declarar la estructura de panel definiendo la variable país y año.
xtset country_id year

* Eliminar auxiliares previos para que la reconstrucción sea idempotente.
foreach auxiliary_variable in ///
    rents_oil_gas_x_inst ///
    rents_mining_x_inst ///
    n_missing_eci_disagg ///
    sample_eci_disagg ///
    n_missing_divx_disagg ///
    sample_divx_disagg ///
    influential_eci_disagg ///
    influential_divx_disagg {
    capture drop `auxiliary_variable'
}

* Reconstruir interacciones y muestras con las definiciones aprobadas.
generate double rents_oil_gas_x_inst = ///
    rents_oil_gas * inst if !missing(rents_oil_gas, inst)
generate double rents_mining_x_inst = ///
    rents_mining * inst if !missing(rents_mining, inst)
egen n_missing_eci_disagg = rowmiss($DISAGG_ECI_SAMPLE_VARS)
generate byte sample_eci_disagg = n_missing_eci_disagg == 0
egen n_missing_divx_disagg = rowmiss($DISAGG_DIVX_SAMPLE_VARS)
generate byte sample_divx_disagg = n_missing_divx_disagg == 0
* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_eci_disagg == sample_eci
* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_divx_disagg == sample_divx


// 23.2. Evaluar estabilidad temporal alrededor de 2014

* El corte está preespecificado en D13 con base en World Bank (2015),
* Understanding the Plunge in Oil Prices: Sources and Implications. El año
* 2014 mezcla meses previos y posteriores a la caída del precio del petróleo;
* por ello esta sección es una sensibilidad y no identifica efectos causales.
assert `temporal_d13_rows' == 1
capture drop post2014
generate byte post2014 = year >= 2014
label variable post2014 "Año 2014 o posterior"
assert inlist(post2014, 0, 1)

* Documentar la cobertura previa y posterior dentro de la muestra común.
quietly levelsof country_iso3_code if sample_eci_disagg == 1, ///
    local(disagg_full_iso3) clean

quietly count if sample_eci_disagg == 1 & post2014 == 0
local disagg_pre_n = r(N)
quietly levelsof country_id if sample_eci_disagg == 1 & post2014 == 0, ///
    local(disagg_pre_country_ids)
local disagg_pre_countries : word count `disagg_pre_country_ids'
quietly levelsof year if sample_eci_disagg == 1 & post2014 == 0, ///
    local(disagg_pre_years)
local disagg_pre_effective_years : word count `disagg_pre_years'
quietly levelsof country_iso3_code ///
    if sample_eci_disagg == 1 & post2014 == 0, ///
    local(disagg_pre_iso3) clean
local disagg_pre_absent : list disagg_full_iso3 - disagg_pre_iso3

quietly count if sample_eci_disagg == 1 & post2014 == 1
local disagg_post_n = r(N)
quietly levelsof country_id if sample_eci_disagg == 1 & post2014 == 1, ///
    local(disagg_post_country_ids)
local disagg_post_countries : word count `disagg_post_country_ids'
quietly levelsof year if sample_eci_disagg == 1 & post2014 == 1, ///
    local(disagg_post_years)
local disagg_post_effective_years : word count `disagg_post_years'
quietly levelsof country_iso3_code ///
    if sample_eci_disagg == 1 & post2014 == 1, ///
    local(disagg_post_iso3) clean
local disagg_post_absent : list disagg_full_iso3 - disagg_post_iso3

assert `disagg_pre_n' + `disagg_post_n' == 1044
assert `disagg_pre_n' == 689
assert `disagg_post_n' == 355
assert `disagg_pre_countries' == 49
assert `disagg_post_countries' == 48
assert `disagg_pre_effective_years' == 15
assert `disagg_post_effective_years' == 8

tempname disagg_post2014_post
tempfile disagg_post2014_report

postfile `disagg_post2014_post' ///
    str8 model ///
    str12 component ///
    str18 term_type ///
    str36 base_term ///
    str56 change_term ///
    double pre_coefficient ///
    double pre_standard_error ///
    double pre_p_value ///
    double pre_ci_lower ///
    double pre_ci_upper ///
    double change_from_2014 ///
    double change_standard_error ///
    double change_p_value ///
    double change_ci_lower ///
    double change_ci_upper ///
    double post_coefficient ///
    double post_standard_error ///
    double post_p_value ///
    double post_ci_lower ///
    double post_ci_upper ///
    byte sign_stable ///
    double component_joint_f ///
    double component_joint_df1 ///
    double component_joint_df2 ///
    double component_joint_p ///
    double overall_joint_f ///
    double overall_joint_df1 ///
    double overall_joint_df2 ///
    double overall_joint_p ///
    long observations ///
    int countries ///
    long pre_observations ///
    int pre_countries ///
    int pre_effective_years ///
    long post_observations ///
    int post_countries ///
    int post_effective_years ///
    str24 post_absent_countries ///
    int cutoff_year ///
    byte country_fe ///
    byte year_fe ///
    byte hhi_included ///
    byte externally_prespecified ///
    byte significance_selected ///
    str16 hierarchy ///
    byte model_change_authorized ///
    str40 external_reference ///
    str244 interpretation_limit ///
    using "`disagg_post2014_report'", replace

foreach model in ECI DIVX {
    local dependent "eci"
    local regressors "$DISAGG_ECI_REGRESSORS"
    local sample_flag "sample_eci_disagg"
    local hhi_included = 1
    if "`model'" == "DIVX" {
        local dependent "divx"
        local regressors "$DISAGG_DIVX_REGRESSORS"
        local sample_flag "sample_divx_disagg"
        local hhi_included = 0
    }

    * La muestra completa conserva efectos de país y año. El cambio común de
    * la pendiente de INST se incluye para mantener la jerarquía del modelo.
    quietly xtreg `dependent' `regressors' ///
        i.post2014#c.rents_oil_gas ///
        i.post2014#c.rents_mining ///
        i.post2014#c.inst ///
        i.post2014#c.rents_oil_gas#c.inst ///
        i.post2014#c.rents_mining#c.inst ///
        i.year if `sample_flag' == 1, ///
        fe vce(cluster country_id)
    assert e(sample) == `sample_flag'
    assert e(N) == 1044
    assert e(N_g) == 49
    local disagg_regime_df = e(df_r)

    * Contrastes predefinidos por componente y para los cinco cambios focales.
    quietly test ///
        1.post2014#c.rents_oil_gas ///
        1.post2014#c.rents_oil_gas#c.inst
    local oil_joint_f = r(F)
    local oil_joint_df1 = r(df)
    local oil_joint_df2 = r(df_r)
    local oil_joint_p = r(p)

    quietly test ///
        1.post2014#c.rents_mining ///
        1.post2014#c.rents_mining#c.inst
    local mining_joint_f = r(F)
    local mining_joint_df1 = r(df)
    local mining_joint_df2 = r(df_r)
    local mining_joint_p = r(p)

    quietly test ///
        1.post2014#c.rents_oil_gas ///
        1.post2014#c.rents_mining ///
        1.post2014#c.inst ///
        1.post2014#c.rents_oil_gas#c.inst ///
        1.post2014#c.rents_mining#c.inst
    local overall_joint_f = r(F)
    local overall_joint_df1 = r(df)
    local overall_joint_df2 = r(df_r)
    local overall_joint_p = r(p)

    foreach component in oil_gas mining {
        local component_var "rents_`component'"
        local component_label "OIL_GAS"
        local component_f = `oil_joint_f'
        local component_df1 = `oil_joint_df1'
        local component_df2 = `oil_joint_df2'
        local component_p = `oil_joint_p'
        if "`component'" == "mining" {
            local component_label "MINING"
            local component_f = `mining_joint_f'
            local component_df1 = `mining_joint_df1'
            local component_df2 = `mining_joint_df2'
            local component_p = `mining_joint_p'
        }

        local base_terms ///
            "`component_var' c.`component_var'#c.inst"
        local change_terms ///
            "1.post2014#c.`component_var' 1.post2014#c.`component_var'#c.inst"
        local term_types "MAIN INST_INTERACTION"

        forvalues term_index = 1/2 {
            local base_term : word `term_index' of `base_terms'
            local change_term : word `term_index' of `change_terms'
            local term_type : word `term_index' of `term_types'

            local pre_b = _b[`base_term']
            local pre_se = _se[`base_term']
            local t_critical = invttail(`disagg_regime_df', 0.025)
            local pre_p = 2 * ttail( ///
                `disagg_regime_df', abs(`pre_b' / `pre_se'))
            local pre_lb = `pre_b' - `t_critical' * `pre_se'
            local pre_ub = `pre_b' + `t_critical' * `pre_se'

            local change_b = _b[`change_term']
            local change_se = _se[`change_term']
            local change_p = 2 * ttail( ///
                `disagg_regime_df', abs(`change_b' / `change_se'))
            local change_lb = `change_b' - `t_critical' * `change_se'
            local change_ub = `change_b' + `t_critical' * `change_se'

            quietly lincom `base_term' + `change_term'
            local post_b = r(estimate)
            local post_se = r(se)
            local post_p = r(p)
            local post_lb = r(lb)
            local post_ub = r(ub)
            local sign_stable = sign(`pre_b') == sign(`post_b')

            post `disagg_post2014_post' ///
                ("`model'") ("`component_label'") ("`term_type'") ///
                ("`base_term'") ("`change_term'") ///
                (`pre_b') (`pre_se') (`pre_p') (`pre_lb') (`pre_ub') ///
                (`change_b') (`change_se') (`change_p') ///
                (`change_lb') (`change_ub') ///
                (`post_b') (`post_se') (`post_p') (`post_lb') (`post_ub') ///
                (`sign_stable') ///
                (`component_f') (`component_df1') ///
                (`component_df2') (`component_p') ///
                (`overall_joint_f') (`overall_joint_df1') ///
                (`overall_joint_df2') (`overall_joint_p') ///
                (1044) (49) ///
                (`disagg_pre_n') (`disagg_pre_countries') ///
                (`disagg_pre_effective_years') ///
                (`disagg_post_n') (`disagg_post_countries') ///
                (`disagg_post_effective_years') ///
                ("`disagg_post_absent'") (2014) ///
                (1) (1) (`hhi_included') (1) (0) ///
                ("SENSITIVITY") (0) ///
                ("World Bank PRN 1 (2015)") ///
                ("Sensibilidad en muestra completa; 2014 es transición, los coeficientes no identifican efectos causales y la significancia no selecciona el modelo.")
        }
    }
}
postclose `disagg_post2014_post'

* Validar y exportar los ocho términos focales con pruebas conjuntas repetidas
* dentro de cada componente para conservar un único archivo autocontenido.
preserve
    use "`disagg_post2014_report'", clear
    isid model component term_type
    assert _N == 8
    bysort model component: assert _N == 2
    assert observations == 1044
    assert countries == 49
    assert pre_observations == 689
    assert pre_countries == 49
    assert pre_effective_years == 15
    assert post_observations == 355
    assert post_countries == 48
    assert post_effective_years == 8
    assert cutoff_year == 2014
    assert country_fe == 1
    assert year_fe == 1
    assert hhi_included == 1 if model == "ECI"
    assert hhi_included == 0 if model == "DIVX"
    assert externally_prespecified == 1
    assert significance_selected == 0
    assert hierarchy == "SENSITIVITY"
    assert model_change_authorized == 0
    assert inrange(pre_p_value, 0, 1)
    assert inrange(change_p_value, 0, 1)
    assert inrange(post_p_value, 0, 1)
    assert inrange(component_joint_p, 0, 1)
    assert inrange(overall_joint_p, 0, 1)
    assert inrange(pre_coefficient, pre_ci_lower, pre_ci_upper)
    assert inrange(change_from_2014, change_ci_lower, change_ci_upper)
    assert inrange(post_coefficient, post_ci_lower, post_ci_upper)
    format pre_coefficient pre_standard_error pre_p_value ///
        pre_ci_lower pre_ci_upper ///
        change_from_2014 change_standard_error change_p_value ///
        change_ci_lower change_ci_upper ///
        post_coefficient post_standard_error post_p_value ///
        post_ci_lower post_ci_upper ///
        component_joint_f component_joint_p ///
        overall_joint_f overall_joint_p %12.6f
    sort model component term_type
    export delimited using ///
        "$OUTPUT_DISAGG_STABILITY/post_2014_stability.csv", ///
        replace datafmt
restore

drop post2014

display as result ///
    "Bloque 5 validado: estabilidad post-2014 en muestra completa."
display as result ///
    "La sensibilidad no identifica una ruptura causal ni selecciona el modelo."


// 23.3. Evaluar sensibilidad a observaciones y países

* Convertir el inventario de alertas de la sección 20 en indicadores país-año.
capture confirm file ///
    "$OUTPUT_DISAGG_DIAGNOSTICS/influential_observations.csv"
if _rc {
    display as error ///
        "No se encontró influential_observations.csv; ejecute la sección 20."
    exit 601
}
tempfile disagg_influence_flags
preserve
    import delimited using ///
        "$OUTPUT_DISAGG_DIAGNOSTICS/influential_observations.csv", ///
        clear varnames(1)
    keep country_iso3_code year model
    duplicates drop
    generate byte influential = 1
    reshape wide influential, ///
        i(country_iso3_code year) j(model) string
    capture confirm variable influentialECI
    if _rc generate byte influentialECI = 0
    capture confirm variable influentialDIVX
    if _rc generate byte influentialDIVX = 0
    replace influentialECI = 0 if missing(influentialECI)
    replace influentialDIVX = 0 if missing(influentialDIVX)
    rename influentialECI influential_eci_disagg
    rename influentialDIVX influential_divx_disagg
    save "`disagg_influence_flags'", replace
restore

* Combinar las alertas con el panel y verificar los conteos aprobados.
merge m:1 country_iso3_code year using ///
    "`disagg_influence_flags'", keep(master match) nogen
replace influential_eci_disagg = 0 ///
    if missing(influential_eci_disagg)
replace influential_divx_disagg = 0 ///
    if missing(influential_divx_disagg)
* Contar silenciosamente cuántas observaciones cumplen una condición determinada.
quietly count if sample_eci_disagg == 1 & ///
    influential_eci_disagg == 1
local eci_influential_n = r(N)
* Contar silenciosamente cuántas observaciones cumplen una condición determinada.
quietly count if sample_divx_disagg == 1 & ///
    influential_divx_disagg == 1
local divx_influential_n = r(N)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `eci_influential_n' == 75
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `divx_influential_n' == 78

* Comparar los modelos base con la exclusión conjunta de observaciones alertadas.
local disagg_focal_terms ///
    rents_oil_gas rents_mining ///
    c.rents_oil_gas#c.inst c.rents_mining#c.inst
tempname disagg_influence_post
tempfile disagg_influence_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `disagg_influence_post' ///
    str8 model str20 specification str32 term ///
    double observations countries coefficient standard_error p_value ///
    using "`disagg_influence_report'", replace
foreach model in ECI DIVX {
    local dependent "eci"
    local regressors "$DISAGG_ECI_REGRESSORS"
    local sample_flag "sample_eci_disagg"
    local influence_flag "influential_eci_disagg"
    if "`model'" == "DIVX" {
        local dependent "divx"
        local regressors "$DISAGG_DIVX_REGRESSORS"
        local sample_flag "sample_divx_disagg"
        local influence_flag "influential_divx_disagg"
    }

    // Reestimar y registrar los cuatro términos de la especificación base.
    quietly reghdfe `dependent' `regressors' ///
        if `sample_flag' == 1, ///
        absorb(country_id year) vce(cluster country_id)
    foreach term of local disagg_focal_terms {
        local term_p = 2 * ttail(e(df_r), ///
            abs(_b[`term'] / _se[`term']))
        * Escribir una fila de resultados dentro del archivo temporal.
        post `disagg_influence_post' ///
            ("`model'") ("Base") ("`term'") ///
            (e(N)) (e(N_clust)) ///
            (_b[`term']) (_se[`term']) (`term_p')
    }

    // Reestimar y registrar el modelo sin observaciones alertadas.
    quietly reghdfe `dependent' `regressors' ///
        if `sample_flag' == 1 & `influence_flag' == 0, ///
        absorb(country_id year) vce(cluster country_id)
    foreach term of local disagg_focal_terms {
        local term_p = 2 * ttail(e(df_r), ///
            abs(_b[`term'] / _se[`term']))
        * Escribir una fila de resultados dentro del archivo temporal.
        post `disagg_influence_post' ///
            ("`model'") ("Excluye alertas") ("`term'") ///
            (e(N)) (e(N_clust)) ///
            (_b[`term']) (_se[`term']) (`term_p')
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `disagg_influence_post'

* Exportar la sensibilidad a observaciones potencialmente influyentes.
preserve
    use "`disagg_influence_report'", clear
    sort model term specification
    format observations countries %12.0f
    format coefficient standard_error p_value %16.10f
    export delimited using ///
        "$OUTPUT_DISAGG_STABILITY/influential_observation_sensitivity.csv", ///
        replace datafmt
restore

* Preparar el detalle de exclusión individual para los 49 países comunes.
quietly levelsof country_id if sample_eci_disagg == 1, ///
    local(disagg_country_ids)
local disagg_country_count : word count `disagg_country_ids'
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `disagg_country_count' == 49
tempname disagg_loo_post
tempfile disagg_loo_report disagg_loo_summary
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `disagg_loo_post' ///
    str8 model double excluded_country_id ///
    str3 excluded_country_iso3 str32 term ///
    double base_coefficient coefficient standard_error p_value ///
    observations countries ///
    using "`disagg_loo_report'", replace

* Reestimar ambos modelos omitiendo sucesivamente cada país y cada término focal.
foreach model in ECI DIVX {
    local dependent "eci"
    local regressors "$DISAGG_ECI_REGRESSORS"
    local sample_flag "sample_eci_disagg"
    local base_prefix "eci"
    if "`model'" == "DIVX" {
        local dependent "divx"
        local regressors "$DISAGG_DIVX_REGRESSORS"
        local sample_flag "sample_divx_disagg"
        local base_prefix "divx"
    }

    // Reestimar y conservar los coeficientes base antes de las exclusiones.
    quietly reghdfe `dependent' `regressors' ///
        if `sample_flag' == 1, ///
        absorb(country_id year) vce(cluster country_id)
    local focal_order = 0
    foreach term of local disagg_focal_terms {
        local ++focal_order
        scalar disagg_loo_base_`base_prefix'_`focal_order' = ///
            _b[`term']
    }

    // Excluir cada país y registrar los cuatro términos del modelo restante.
    foreach excluded_id of local disagg_country_ids {
        quietly levelsof country_iso3_code ///
            if country_id == `excluded_id', ///
            local(excluded_iso3) clean
        quietly reghdfe `dependent' `regressors' ///
            if `sample_flag' == 1 & country_id != `excluded_id', ///
            absorb(country_id year) vce(cluster country_id)
        local focal_order = 0
        foreach term of local disagg_focal_terms {
            local ++focal_order
            local term_p = 2 * ttail(e(df_r), ///
                abs(_b[`term'] / _se[`term']))
            local base_coefficient = ///
                scalar(disagg_loo_base_`base_prefix'_`focal_order')
            * Escribir una fila de resultados dentro del archivo temporal.
            post `disagg_loo_post' ///
                ("`model'") (`excluded_id') ("`excluded_iso3'") ///
                ("`term'") (`base_coefficient') ///
                (_b[`term']) (_se[`term']) (`term_p') ///
                (e(N)) (e(N_clust))
        }
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `disagg_loo_post'

* Exportar las 392 estimaciones de exclusión individual de países.
preserve
    use "`disagg_loo_report'", clear
    sort model term excluded_country_id
    format base_coefficient coefficient standard_error p_value %16.10f
    export delimited using ///
        "$OUTPUT_DISAGG_STABILITY/leave_one_country_out_detail.csv", ///
        replace datafmt
restore

* Resumir cambios de signo, rangos y frecuencia de significancia por término.
preserve
    use "`disagg_loo_report'", clear
    generate byte sign_change = ///
        sign(coefficient) != sign(base_coefficient)
    generate byte significant_5 = p_value < 0.05
    generate byte significant_10 = p_value < 0.10
    collapse ///
        (count) replications=coefficient ///
        (firstnm) base_coefficient ///
        (min) min_coefficient=coefficient min_p_value=p_value ///
        (max) max_coefficient=coefficient max_p_value=p_value ///
        (sum) sign_changes=sign_change ///
            significant_5 significant_10, ///
        by(model term)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert replications == 49
    format base_coefficient min_coefficient max_coefficient ///
        min_p_value max_p_value %16.10f
    save "`disagg_loo_summary'", replace
    export delimited using ///
        "$OUTPUT_DISAGG_STABILITY/leave_one_country_out_summary.csv", ///
        replace datafmt
restore


// 23.4. Aplicar inferencia alternativa

* Ejecutar wild cluster bootstrap para los ocho términos focales predefinidos.
tempname disagg_bootstrap_post
tempfile disagg_bootstrap_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `disagg_bootstrap_post' ///
    str8 model str32 term ///
    double conventional_coefficient conventional_p_value ///
    bootstrap_p_value ci_lower ci_upper replications ///
    str16 weight_type ///
    using "`disagg_bootstrap_report'", replace
local bootstrap_order = 0
foreach model in ECI DIVX {
    local dependent "eci"
    local regressors "$DISAGG_ECI_REGRESSORS"
    local sample_flag "sample_eci_disagg"
    if "`model'" == "DIVX" {
        local dependent "divx"
        local regressors "$DISAGG_DIVX_REGRESSORS"
        local sample_flag "sample_divx_disagg"
    }

    // Reestimar con xtreg porque boottest requiere un único efecto absorbido.
    quietly xtreg `dependent' `regressors' i.year ///
        if `sample_flag' == 1, ///
        fe vce(cluster country_id)

    // Aplicar el contraste bootstrap a cada término focal del modelo activo.
    foreach term of local disagg_focal_terms {
        local ++bootstrap_order
        local conventional_coefficient = _b[`term']
        local conventional_p = 2 * ttail(e(df_r), ///
            abs(_b[`term'] / _se[`term']))
        local bootstrap_seed = 20260729 + `bootstrap_order'
        quietly boottest `term', ///
            cluster(country_id) reps(9999) ///
            seed(`bootstrap_seed') nograph
        matrix disagg_bootstrap_ci = r(CI)
        local bootstrap_p = r(p)
        local bootstrap_reps = r(reps)
        local bootstrap_weight "`r(weighttype)'"
        * Control de calidad automático que detiene el script si no se cumple la condición.
        assert !missing(`bootstrap_p')
        * Control de calidad automático que detiene el script si no se cumple la condición.
        assert `bootstrap_reps' == 9999
        * Escribir una fila de resultados dentro del archivo temporal.
        post `disagg_bootstrap_post' ///
            ("`model'") ("`term'") ///
            (`conventional_coefficient') (`conventional_p') ///
            (`bootstrap_p') ///
            (el(disagg_bootstrap_ci, 1, 1)) ///
            (el(disagg_bootstrap_ci, 1, 2)) ///
            (`bootstrap_reps') ("`bootstrap_weight'")
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `disagg_bootstrap_post'

* Exportar la inferencia bootstrap sin sustituir los errores agrupados principales.
preserve
    use "`disagg_bootstrap_report'", clear
    sort model term
    format conventional_coefficient conventional_p_value ///
        bootstrap_p_value ci_lower ci_upper %16.10f
    export delimited using ///
        "$OUTPUT_DISAGG_STABILITY/wild_cluster_bootstrap.csv", ///
        replace datafmt
restore

// 23.5. Comparar estabilidad entre componentes

* Estimar la única sensibilidad predefinida sin controles per cápita.
tempname disagg_no_pc_post
tempfile disagg_no_pc_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `disagg_no_pc_post' ///
    str8 model str32 specification str32 term ///
    double observations countries coefficient standard_error p_value ///
    using "`disagg_no_pc_report'", replace
foreach model in ECI DIVX {
    local dependent "eci"
    local sample_flag "sample_eci_disagg"
    local no_pc_regressors "$DISAGG_ECI_NO_PC"
    local base_regressors "$DISAGG_ECI_REGRESSORS"
    if "`model'" == "DIVX" {
        local dependent "divx"
        local sample_flag "sample_divx_disagg"
        local no_pc_regressors "$DISAGG_DIVX_NO_PC"
        local base_regressors "$DISAGG_DIVX_REGRESSORS"
    }

    // Reestimar la especificación principal como referencia de la sensibilidad.
    quietly reghdfe `dependent' `base_regressors' ///
        if `sample_flag' == 1, ///
        absorb(country_id year) vce(cluster country_id)
    foreach term of local disagg_focal_terms {
        local term_p = 2 * ttail(e(df_r), ///
            abs(_b[`term'] / _se[`term']))
        * Escribir una fila de resultados dentro del archivo temporal.
        post `disagg_no_pc_post' ///
            ("`model'") ("Base") ("`term'") ///
            (e(N)) (e(N_g)) (_b[`term']) (_se[`term']) (`term_p')
    }

    // Reestimar sin los tres controles per cápita sobre la misma muestra.
    quietly reghdfe `dependent' `no_pc_regressors' ///
        if `sample_flag' == 1, ///
        absorb(country_id year) vce(cluster country_id)
    * Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
    assert e(N) == 1044
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert e(N_clust) == 49
    foreach term of local disagg_focal_terms {
        local term_p = 2 * ttail(e(df_r), ///
            abs(_b[`term'] / _se[`term']))
        * Escribir una fila de resultados dentro del archivo temporal.
        post `disagg_no_pc_post' ///
            ("`model'") ("Sin controles per cápita") ("`term'") ///
            (e(N)) (e(N_clust)) ///
            (_b[`term']) (_se[`term']) (`term_p')
    }
}
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `disagg_no_pc_post'

* Exportar la sensibilidad de especificación conservando la misma muestra.
preserve
    use "`disagg_no_pc_report'", clear
    sort model term specification
    format coefficient standard_error p_value %16.10f
    export delimited using ///
        "$OUTPUT_DISAGG_STABILITY/no_per_capita_controls_sensitivity.csv", ///
        replace datafmt
restore

* Preparar las fuentes necesarias para clasificar la estabilidad de cada término.
tempfile stability_base stability_influence stability_no_pc stability_bootstrap
preserve
    use "`disagg_influence_report'", clear
    keep if specification == "Base"
    keep model term coefficient p_value
    rename coefficient base_coefficient
    rename p_value base_p_value
    save "`stability_base'", replace
restore
preserve
    use "`disagg_influence_report'", clear
    keep if specification == "Excluye alertas"
    keep model term coefficient p_value
    rename coefficient influence_coefficient
    rename p_value influence_p_value
    save "`stability_influence'", replace
restore
preserve
    use "`disagg_no_pc_report'", clear
    keep if specification == "Sin controles per cápita"
    keep model term coefficient p_value
    rename coefficient no_pc_coefficient
    rename p_value no_pc_p_value
    save "`stability_no_pc'", replace
restore
preserve
    use "`disagg_bootstrap_report'", clear
    keep model term bootstrap_p_value ci_lower ci_upper
    rename ci_lower bootstrap_ci_lower
    rename ci_upper bootstrap_ci_upper
    save "`stability_bootstrap'", replace
restore

* Clasificar como complementaria la evidencia estable y respaldada por bootstrap.
preserve
    use "`stability_base'", clear
    merge 1:1 model term using "`stability_influence'", ///
        assert(match) nogen
    merge 1:1 model term using "`stability_no_pc'", ///
        assert(match) nogen
    merge 1:1 model term using "`disagg_loo_summary'", ///
        assert(match) nogen ///
        keepusing(min_coefficient max_coefficient sign_changes ///
            significant_5 significant_10)
    merge 1:1 model term using "`stability_bootstrap'", ///
        assert(match) nogen
    generate byte direction_stable = ///
        sign(base_coefficient) == sign(influence_coefficient) & ///
        sign(base_coefficient) == sign(no_pc_coefficient) & ///
        sign_changes == 0
    generate byte bootstrap_support = bootstrap_p_value < 0.10
    generate str18 evidence_class = "No concluyente"
    replace evidence_class = "Complementaria" ///
        if direction_stable == 1 & bootstrap_support == 1
    sort model term
    format base_coefficient base_p_value ///
        influence_coefficient influence_p_value ///
        no_pc_coefficient no_pc_p_value ///
        min_coefficient max_coefficient ///
        bootstrap_p_value bootstrap_ci_lower bootstrap_ci_upper %16.10f
    export delimited using ///
        "$OUTPUT_DISAGG_STABILITY/stability_classification.csv", ///
        replace datafmt
restore

* Cerrar la sección después de verificar todas las sensibilidades predefinidas.
display as result ///
    "Sección 13 completada: estabilidad y efectos marginales exportados."
display as text ///
    "Las sensibilidades no sustituyen los modelos desagregados principales."

// *****************************************************************************
// 24. Exportación y Cierre de la Desagregación Integrada
// *****************************************************************************

// 24.1. Exportar resultados numéricos

* Crear la carpeta exclusiva del paquete final de la desagregación.
capture mkdir "$OUTPUT_DISAGG_EXPORTS"

* Verificar que estén disponibles todas las fuentes requeridas para el cierre.
foreach required_file in ///
    "$OUTPUT_ECI/eci_twfe_coefficients.csv" ///
    "$OUTPUT_DIVX/divx_twfe_coefficients.csv" ///
    "$OUTPUT_ECI/eci_twfe_model_summary.csv" ///
    "$OUTPUT_DIVX/divx_twfe_model_summary.csv" ///
    "$OUTPUT_ECI/eci_twfe_main.ster" ///
    "$OUTPUT_DIVX/divx_twfe_main.ster" ///
    "$OUTPUT_DISAGG_ECI/eci_disaggregated_coefficients.csv" ///
    "$OUTPUT_DISAGG_DIVX/divx_disaggregated_coefficients.csv" ///
    "$OUTPUT_DISAGG_ECI/eci_disaggregated_model_summary.csv" ///
    "$OUTPUT_DISAGG_DIVX/divx_disaggregated_model_summary.csv" ///
    "$OUTPUT_DISAGG_ECI/eci_disaggregated_tests.csv" ///
    "$OUTPUT_DISAGG_DIVX/divx_disaggregated_tests.csv" ///
    "$OUTPUT_DISAGG_ECI/eci_twfe_disaggregated.ster" ///
    "$OUTPUT_DISAGG_DIVX/divx_twfe_disaggregated.ster" ///
    "$OUTPUT_DISAGG_STABILITY/component_marginal_effects_by_inst.csv" ///
    "$OUTPUT_DISAGG_STABILITY/stability_classification.csv" {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "`required_file'"
    if _rc {
        display as error "Falta un insumo requerido para la sección 24:"
        display as error "`required_file'"
        exit 601
    }
}

* Preparar los términos focales del modelo ECI agregado.
tempfile final_eci_aggregate final_eci_disaggregated
preserve
    import delimited using ///
        "$OUTPUT_ECI/eci_twfe_coefficients.csv", ///
        clear varnames(1)
    keep if inlist(term, "rents", "c.rents#c.inst")
    generate str8 model = "ECI"
    generate str14 specification = "Agregado"
    save "`final_eci_aggregate'", replace
restore

* Preparar los términos focales del modelo ECI desagregado.
preserve
    import delimited using ///
        "$OUTPUT_DISAGG_ECI/eci_disaggregated_coefficients.csv", ///
        clear varnames(1)
    keep if inlist(term, ///
        "rents_oil_gas", ///
        "rents_mining", ///
        "c.rents_oil_gas#c.inst", ///
        "c.rents_mining#c.inst")
    generate str8 model = "ECI"
    generate str14 specification = "Desagregado"
    save "`final_eci_disaggregated'", replace
restore

* Preparar los términos focales del modelo DIVX agregado.
tempfile final_divx_aggregate final_divx_disaggregated
preserve
    import delimited using ///
        "$OUTPUT_DIVX/divx_twfe_coefficients.csv", ///
        clear varnames(1)
    keep if inlist(term, "rents", "c.rents#c.inst")
    generate str8 model = "DIVX"
    generate str14 specification = "Agregado"
    save "`final_divx_aggregate'", replace
restore

* Preparar los términos focales del modelo DIVX desagregado.
preserve
    import delimited using ///
        "$OUTPUT_DISAGG_DIVX/divx_disaggregated_coefficients.csv", ///
        clear varnames(1)
    keep if inlist(term, ///
        "rents_oil_gas", ///
        "rents_mining", ///
        "c.rents_oil_gas#c.inst", ///
        "c.rents_mining#c.inst")
    generate str8 model = "DIVX"
    generate str14 specification = "Desagregado"
    save "`final_divx_disaggregated'", replace
restore

* Consolidar los doce coeficientes focales agregados y desagregados.
preserve
    use "`final_eci_aggregate'", clear
    append using ///
        "`final_eci_disaggregated'" ///
        "`final_divx_aggregate'" ///
        "`final_divx_disaggregated'"
    drop order
    generate byte model_order = cond(model == "ECI", 1, 2)
    generate byte specification_order = ///
        cond(specification == "Agregado", 1, 2)
    generate byte term_order = 5
    replace term_order = 1 if term == "rents"
    replace term_order = 2 if term == "rents_oil_gas"
    replace term_order = 3 if term == "rents_mining"
    replace term_order = 4 if term == "c.rents#c.inst"
    replace term_order = 5 if term == "c.rents_oil_gas#c.inst"
    replace term_order = 6 if term == "c.rents_mining#c.inst"
    order ///
        model specification term variable_label channel ///
        coefficient standard_error t_statistic p_value ci_lower ci_upper
    sort model_order specification_order term_order
    drop model_order specification_order term_order
    format ///
        coefficient standard_error t_statistic p_value ///
        ci_lower ci_upper %16.10f
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 12
    export delimited using ///
        "$OUTPUT_DISAGG_EXPORTS/final_focal_coefficients.csv", ///
        replace datafmt
restore

* Consolidar cobertura y ajuste de los cuatro modelos comparables.
tempfile final_eci_agg_sum final_eci_disagg_sum
tempfile final_divx_agg_sum final_divx_disagg_sum
preserve
    import delimited using ///
        "$OUTPUT_ECI/eci_twfe_model_summary.csv", ///
        clear varnames(1)
    generate str8 outcome = "ECI"
    generate str14 specification = "Agregado"
    save "`final_eci_agg_sum'", replace
restore

* Preparar el resumen del modelo ECI desagregado.
preserve
    import delimited using ///
        "$OUTPUT_DISAGG_ECI/eci_disaggregated_model_summary.csv", ///
        clear varnames(1)
    generate str8 outcome = "ECI"
    generate str14 specification = "Desagregado"
    save "`final_eci_disagg_sum'", replace
restore

* Preparar el resumen del modelo DIVX agregado.
preserve
    import delimited using ///
        "$OUTPUT_DIVX/divx_twfe_model_summary.csv", ///
        clear varnames(1)
    generate str8 outcome = "DIVX"
    generate str14 specification = "Agregado"
    save "`final_divx_agg_sum'", replace
restore

* Preparar el resumen del modelo DIVX desagregado.
preserve
    import delimited using ///
        "$OUTPUT_DISAGG_DIVX/divx_disaggregated_model_summary.csv", ///
        clear varnames(1)
    generate str8 outcome = "DIVX"
    generate str14 specification = "Desagregado"
    save "`final_divx_disagg_sum'", replace
restore

* Exportar la comparación conjunta de cobertura y ajuste.
preserve
    use "`final_eci_agg_sum'", clear
    append using ///
        "`final_eci_disagg_sum'" ///
        "`final_divx_agg_sum'" ///
        "`final_divx_disagg_sum'"
    generate byte outcome_order = cond(outcome == "ECI", 1, 2)
    generate byte specification_order = ///
        cond(specification == "Agregado", 1, 2)
    order outcome specification model dependent_variable
    sort outcome_order specification_order
    drop outcome_order specification_order
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 4
    export delimited using ///
        "$OUTPUT_DISAGG_EXPORTS/final_model_comparison.csv", ///
        replace datafmt
restore

* Consolidar las pruebas conjuntas de los modelos ECI y DIVX desagregados.
tempfile final_eci_tests final_divx_tests
preserve
    import delimited using ///
        "$OUTPUT_DISAGG_ECI/eci_disaggregated_tests.csv", ///
        clear varnames(1)
    generate str8 model = "ECI"
    save "`final_eci_tests'", replace
restore

* Preparar las pruebas conjuntas del modelo DIVX.
preserve
    import delimited using ///
        "$OUTPUT_DISAGG_DIVX/divx_disaggregated_tests.csv", ///
        clear varnames(1)
    generate str8 model = "DIVX"
    save "`final_divx_tests'", replace
restore

* Exportar las catorce pruebas conjuntas en una sola tabla.
preserve
    use "`final_eci_tests'", clear
    append using "`final_divx_tests'"
    generate byte model_order = cond(model == "ECI", 1, 2)
    order model order test null_hypothesis
    sort model_order order
    drop model_order
    format f_statistic p_value %16.10f
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 14
    export delimited using ///
        "$OUTPUT_DISAGG_EXPORTS/final_joint_tests.csv", ///
        replace datafmt
restore

* Copiar los efectos marginales al paquete final con orden homogéneo.
preserve
    import delimited using ///
        "$OUTPUT_DISAGG_STABILITY/component_marginal_effects_by_inst.csv", ///
        clear varnames(1)
    sort model component inst_value
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 20
    export delimited using ///
        "$OUTPUT_DISAGG_EXPORTS/final_component_marginal_effects.csv", ///
        replace datafmt
restore

* Copiar la clasificación de estabilidad al paquete final.
preserve
    import delimited using ///
        "$OUTPUT_DISAGG_STABILITY/stability_classification.csv", ///
        clear varnames(1)
    sort model term
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 8
    export delimited using ///
        "$OUTPUT_DISAGG_EXPORTS/final_stability_classification.csv", ///
        replace datafmt
restore


// 24.2. Crear tablas y figuras comparables

* Exigir esttab para producir las versiones LaTeX y texto de la tabla final.
capture which esttab
if _rc {
    display as error "La sección 24 requiere esttab para exportar la tabla final."
    exit 199
}

* Recuperar y almacenar los cuatro modelos previamente validados.
estimates use "$OUTPUT_ECI/eci_twfe_main.ster"
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_AGG_FINAL
* Cargar una estimación guardada previamente en disco.
estimates use "$OUTPUT_DISAGG_ECI/eci_twfe_disaggregated.ster"
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_DISAGG_FINAL
* Cargar una estimación guardada previamente en disco.
estimates use "$OUTPUT_DIVX/divx_twfe_main.ster"
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_AGG_FINAL
* Cargar una estimación guardada previamente en disco.
estimates use "$OUTPUT_DISAGG_DIVX/divx_twfe_disaggregated.ster"
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_DISAGG_FINAL

* Exportar la tabla comparativa principal en formato LaTeX.
esttab ///
    ECI_AGG_FINAL ECI_DISAGG_FINAL ///
    DIVX_AGG_FINAL DIVX_DISAGG_FINAL ///
    using "$OUTPUT_DISAGG_EXPORTS/table_eci_divx_aggregate_disaggregated.tex", ///
    replace booktabs label ///
    b(4) se(4) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles( ///
        "ECI agregado" ///
        "ECI desagregado" ///
        "DIVX agregado" ///
        "DIVX desagregado") ///
    keep( ///
        rents ///
        rents_oil_gas ///
        rents_mining ///
        c.rents#c.inst ///
        c.rents_oil_gas#c.inst ///
        c.rents_mining#c.inst) ///
    order( ///
        rents ///
        rents_oil_gas ///
        rents_mining ///
        c.rents#c.inst ///
        c.rents_oil_gas#c.inst ///
        c.rents_mining#c.inst) ///
    stats( ///
        N N_g r2_w rmse, ///
        fmt(0 0 4 4) ///
        labels( ///
            "Observaciones" ///
            "Países" ///
            "R2 within" ///
            "RMSE")) ///
    title( ///
        "RENTS agregado y desagregado: modelos de efectos fijos") ///
    addnotes( ///
        "Efectos fijos por país y año." ///
        "Errores estándar agrupados por país." ///
        "HHI se excluye del modelo DIVX porque DIVX = 1 - HHI." ///
        "La extensión no reemplaza los modelos agregados.")

* Exportar la misma tabla en texto plano para revisión directa.
esttab ///
    ECI_AGG_FINAL ECI_DISAGG_FINAL ///
    DIVX_AGG_FINAL DIVX_DISAGG_FINAL ///
    using "$OUTPUT_DISAGG_EXPORTS/table_eci_divx_aggregate_disaggregated.txt", ///
    replace label ///
    b(4) se(4) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles( ///
        "ECI agregado" ///
        "ECI desagregado" ///
        "DIVX agregado" ///
        "DIVX desagregado") ///
    keep( ///
        rents ///
        rents_oil_gas ///
        rents_mining ///
        c.rents#c.inst ///
        c.rents_oil_gas#c.inst ///
        c.rents_mining#c.inst) ///
    order( ///
        rents ///
        rents_oil_gas ///
        rents_mining ///
        c.rents#c.inst ///
        c.rents_oil_gas#c.inst ///
        c.rents_mining#c.inst) ///
    stats( ///
        N N_g r2_w rmse, ///
        fmt(0 0 4 4) ///
        labels( ///
            "Observaciones" ///
            "Países" ///
            "R2 within" ///
            "RMSE")) ///
    addnotes( ///
        "Efectos fijos por país y año." ///
        "Errores estándar agrupados por país." ///
        "HHI se excluye del modelo DIVX porque DIVX = 1 - HHI." ///
        "La extensión no reemplaza los modelos agregados.")

* Exportar una tabla suplementaria con todos los controles de los cuatro modelos.
esttab ///
    ECI_AGG_FINAL ECI_DISAGG_FINAL ///
    DIVX_AGG_FINAL DIVX_DISAGG_FINAL ///
    using "$OUTPUT_DISAGG_EXPORTS/table_eci_divx_full_models.tex", ///
    replace booktabs label ///
    b(4) se(4) ///
    noomitted nobaselevels ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles( ///
        "ECI agregado" ///
        "ECI desagregado" ///
        "DIVX agregado" ///
        "DIVX desagregado") ///
    drop(*.year _cons) ///
    order( ///
        rents ///
        rents_oil_gas ///
        rents_mining ///
        inst ///
        c.rents#c.inst ///
        c.rents_oil_gas#c.inst ///
        c.rents_mining#c.inst ///
        ln1p_oilpc ///
        ln1p_gaspc ///
        ln1p_coalpc ///
        hhi ///
        pexp ///
        fexp ///
        vol ///
        rer ///
        humcap ///
        innov ///
        net ///
        log_gdppc ///
        govcons ///
        fin) ///
    stats( ///
        N N_g r2_w rmse, ///
        fmt(0 0 4 4) ///
        labels( ///
            "Observaciones" ///
            "Países" ///
            "R2 within" ///
            "RMSE")) ///
    title( ///
        "Modelos completos de RENTS agregado y desagregado") ///
    addnotes( ///
        "Efectos fijos por país y año." ///
        "Errores estándar agrupados por país." ///
        "HHI se excluye del modelo DIVX porque DIVX = 1 - HHI." ///
        "La extensión no reemplaza los modelos agregados.")

* Exportar la tabla suplementaria completa en texto plano.
esttab ///
    ECI_AGG_FINAL ECI_DISAGG_FINAL ///
    DIVX_AGG_FINAL DIVX_DISAGG_FINAL ///
    using "$OUTPUT_DISAGG_EXPORTS/table_eci_divx_full_models.txt", ///
    replace label ///
    b(4) se(4) ///
    noomitted nobaselevels ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles( ///
        "ECI agregado" ///
        "ECI desagregado" ///
        "DIVX agregado" ///
        "DIVX desagregado") ///
    drop(*.year _cons) ///
    order( ///
        rents ///
        rents_oil_gas ///
        rents_mining ///
        inst ///
        c.rents#c.inst ///
        c.rents_oil_gas#c.inst ///
        c.rents_mining#c.inst ///
        ln1p_oilpc ///
        ln1p_gaspc ///
        ln1p_coalpc ///
        hhi ///
        pexp ///
        fexp ///
        vol ///
        rer ///
        humcap ///
        innov ///
        net ///
        log_gdppc ///
        govcons ///
        fin) ///
    stats( ///
        N N_g r2_w rmse, ///
        fmt(0 0 4 4) ///
        labels( ///
            "Observaciones" ///
            "Países" ///
            "R2 within" ///
            "RMSE")) ///
    addnotes( ///
        "Efectos fijos por país y año." ///
        "Errores estándar agrupados por país." ///
        "HHI se excluye del modelo DIVX porque DIVX = 1 - HHI." ///
        "La extensión no reemplaza los modelos agregados.")

* Confirmar que las ocho figuras revisadas permanezcan disponibles en PDF y PNG.
local final_figure_count = 0
foreach model in eci divx {
    foreach component in oil_gas mining {
        foreach extension in pdf png {
            * Verificar la existencia de un archivo antes de intentar cargarlo.
            capture confirm file ///
                "$OUTPUT_DISAGG_STABILITY/`model'_`component'_marginal_effect.`extension'"
            * Control de calidad automático que detiene el script si no se cumple la condición.
            assert _rc == 0
            local ++final_figure_count
        }
    }
}
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `final_figure_count' == 8


// 24.3. Crear el índice reproducible de outputs

* Integrar y volver a validar los cinco productos de la extensión temporal.
foreach temporal_file in ///
    "$OUTPUT_DISAGG_DESIGN/component_temporal_design.csv" ///
    "$OUTPUT_DISAGG_DIAGNOSTICS/component_temporal_inventory.csv" ///
    "$OUTPUT_DISAGG_DIAGNOSTICS/panel_unit_root_components.csv" ///
    "$OUTPUT_DISAGG_DIAGNOSTICS/component_error_tests.csv" ///
    "$OUTPUT_DISAGG_STABILITY/post_2014_stability.csv" {
    capture confirm file "`temporal_file'"
    if _rc {
        display as error ///
            "Falta un producto requerido para la integración temporal: `temporal_file'"
        exit 601
    }
}

preserve
    import delimited using ///
        "$OUTPUT_DISAGG_DESIGN/component_temporal_design.csv", ///
        clear varnames(1)
    isid rule_id
    assert _N == 12
    assert passed == 1
    local final_temporal_design_rows = _N
restore

preserve
    import delimited using ///
        "$OUTPUT_DISAGG_DIAGNOSTICS/component_temporal_inventory.csv", ///
        clear varnames(1)
    isid variable
    assert _N == 2
    assert source_observations == 1044
    assert countries == 49
    assert model_change_authorized == 0
    local final_temporal_inventory_rows = _N
restore

preserve
    import delimited using ///
        "$OUTPUT_DISAGG_DIAGNOSTICS/panel_unit_root_components.csv", ///
        clear varnames(1)
    isid variable series_form
    assert _N == 4
    assert return_code == 0
    assert model_change_authorized == 0
    local final_temporal_unitroot_rows = _N
restore

preserve
    import delimited using ///
        "$OUTPUT_DISAGG_DIAGNOSTICS/component_error_tests.csv", ///
        clear varnames(1)
    isid model test
    assert _N == 6
    assert return_code == 0
    assert alternative_status == "NOT_AUTHORIZED"
    assert model_change_authorized == 0
    local final_temporal_error_rows = _N
restore

preserve
    import delimited using ///
        "$OUTPUT_DISAGG_STABILITY/post_2014_stability.csv", ///
        clear varnames(1)
    isid model component term_type
    assert _N == 8
    assert externally_prespecified == 1
    assert significance_selected == 0
    assert model_change_authorized == 0
    local final_temporal_post2014_rows = _N
restore

local final_temporal_source_rows = ///
    `final_temporal_design_rows' + ///
    `final_temporal_inventory_rows' + ///
    `final_temporal_unitroot_rows' + ///
    `final_temporal_error_rows' + ///
    `final_temporal_post2014_rows'
assert `final_temporal_source_rows' == 32

tempname temporal_extension_post
tempfile temporal_extension_data

postfile `temporal_extension_post' ///
    byte order ///
    str8 block_id ///
    str60 artifact ///
    str120 relative_path ///
    int expected_rows ///
    int observed_rows ///
    byte passed ///
    str24 analytical_role ///
    byte model_change_authorized ///
    str244 interpretation_limit ///
    using "`temporal_extension_data'", replace

post `temporal_extension_post' ///
    (1) ("BLOCK_1") ("component_temporal_design.csv") ///
    ("00_design/component_temporal_design.csv") ///
    (12) (`final_temporal_design_rows') ///
    (`final_temporal_design_rows' == 12) ///
    ("DESIGN_CONTRACT") (0) ///
    ("Predefine alcance, muestra y exclusiones; no contiene estimaciones.")
post `temporal_extension_post' ///
    (2) ("BLOCK_2") ("component_temporal_inventory.csv") ///
    ("01_diagnostics/component_temporal_inventory.csv") ///
    (2) (`final_temporal_inventory_rows') ///
    (`final_temporal_inventory_rows' == 2) ///
    ("DIAGNOSTIC_ONLY") (0) ///
    ("La persistencia AR(1) es descriptiva y queda sujeta a revisión de Peer-1.")
post `temporal_extension_post' ///
    (3) ("BLOCK_3") ("panel_unit_root_components.csv") ///
    ("01_diagnostics/panel_unit_root_components.csv") ///
    (4) (`final_temporal_unitroot_rows') ///
    (`final_temporal_unitroot_rows' == 4) ///
    ("DIAGNOSTIC_ONLY") (0) ///
    ("Fisher-ADF no demuestra estacionariedad universal ni clasifica automáticamente I(0) o I(1).")
post `temporal_extension_post' ///
    (4) ("BLOCK_4") ("component_error_tests.csv") ///
    ("01_diagnostics/component_error_tests.csv") ///
    (6) (`final_temporal_error_rows') ///
    (`final_temporal_error_rows' == 6) ///
    ("INFERENCE_DIAGNOSTIC") (0) ///
    ("Los diagnósticos no activan automáticamente Driscoll-Kraay, PCSE o CCE.")
post `temporal_extension_post' ///
    (5) ("BLOCK_5") ("post_2014_stability.csv") ///
    ("04_stability/post_2014_stability.csv") ///
    (8) (`final_temporal_post2014_rows') ///
    (`final_temporal_post2014_rows' == 8) ///
    ("SENSITIVITY") (0) ///
    ("2014 es transición externa; la sensibilidad no identifica una ruptura causal.")

postclose `temporal_extension_post'

preserve
    use "`temporal_extension_data'", clear
    isid block_id
    assert _N == 5
    assert observed_rows == expected_rows
    assert passed == 1
    assert model_change_authorized == 0
    egen int integrated_source_rows = total(observed_rows)
    assert integrated_source_rows == 32
    drop integrated_source_rows
    sort order
    export delimited using ///
        "$OUTPUT_DISAGG_EXPORTS/temporal_extension_manifest.csv", ///
        replace datafmt
restore

* Registrar la configuración y las verificaciones centrales del paquete final.
tempname manifest_post
tempfile manifest_data
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `manifest_post' ///
    str40 package_id ///
    str40 script ///
    str12 stata_version ///
    str16 execution_date ///
    str16 execution_time ///
    str80 source_data ///
    double eci_observations ///
    double divx_observations ///
    double countries ///
    double first_year ///
    double last_year ///
    double focal_rows ///
    double joint_test_rows ///
    double marginal_effect_rows ///
    double stability_rows ///
    double temporal_extension_files ///
    double temporal_design_rows ///
    double temporal_inventory_rows ///
    double temporal_unit_root_rows ///
    double temporal_error_test_rows ///
    double temporal_post2014_rows ///
    double figure_files ///
    double final_export_files ///
    double indexed_files ///
    double bootstrap_replications ///
    str32 output_scope ///
    str24 control_status ///
    str28 temporal_control_status ///
    using "`manifest_data'", replace

* Escribir una fila única con el alcance reproducible de la ejecución.
post `manifest_post' ///
    ("resource_disaggregation_19_24") ///
    ("08_twfe_resource_disaggregated_full.do") ///
    ("`c(stata_version)'") ///
    ("`c(current_date)'") ///
    ("`c(current_time)'") ///
    ("01_sample/master_panel_estimation_sample.dta") ///
    (1044) ///
    (1044) ///
    (49) ///
    (1996) ///
    (2021) ///
    (12) ///
    (14) ///
    (20) ///
    (8) ///
    (5) ///
    (`final_temporal_design_rows') ///
    (`final_temporal_inventory_rows') ///
    (`final_temporal_unitroot_rows') ///
    (`final_temporal_error_rows') ///
    (`final_temporal_post2014_rows') ///
    (`final_figure_count') ///
    (12) ///
    (59) ///
    (9999) ///
    ("07_resource_disaggregation") ///
    ("Control J validado") ///
    ("Bloques 1-5 validados")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `manifest_post'

* Exportar el manifiesto de la extensión.
preserve
    use "`manifest_data'", clear
    export delimited using ///
        "$OUTPUT_DISAGG_EXPORTS/results_manifest.csv", ///
        replace datafmt
restore

* Construir un inventario dinámico de todos los archivos de la extensión.
tempname index_post
tempfile index_data
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `index_post' ///
    str24 section ///
    str100 filename ///
    str180 relative_path ///
    str12 format ///
    double data_rows ///
    str100 content ///
    using "`index_data'", replace

* Recorrer cada subcarpeta y contar las filas de los archivos CSV.
foreach output_section in ///
    00_design ///
    01_diagnostics ///
    02_eci ///
    03_divx ///
    04_stability ///
    05_exports ///
    logs {
    local section_path "$OUTPUT_DISAGG/`output_section'"
    local section_files : dir "`section_path'" files "*"
    local section_content "Resultados de la extensión"
    if "`output_section'" == "00_design" {
        local section_content "Diseño y validaciones previas"
    }
    if "`output_section'" == "01_diagnostics" {
        local section_content "Diagnósticos de componentes"
    }
    if "`output_section'" == "02_eci" {
        local section_content "Modelo ECI desagregado"
    }
    if "`output_section'" == "03_divx" {
        local section_content "Modelo DIVX desagregado"
    }
    if "`output_section'" == "04_stability" {
        local section_content "Estabilidad y efectos marginales"
    }
    if "`output_section'" == "05_exports" {
        local section_content "Paquete final consolidado"
    }
    if "`output_section'" == "logs" {
        local section_content "Registro de ejecución"
    }

    // Indexar los archivos encontrados sin modificar sus contenidos.
    foreach output_file of local section_files {
        if ///
            "`output_section'" == "05_exports" & ///
            "`output_file'" == "results_index.csv" {
            continue
        }
        local output_format = ///
            lower(substr( ///
                "`output_file'", ///
                strrpos("`output_file'", ".") + 1, ///
                .))
        local output_rows = .

        // Contar observaciones únicamente cuando el archivo sea una tabla CSV.
        if "`output_format'" == "csv" {
            preserve
                quietly import delimited using ///
                    "`section_path'/`output_file'", ///
                    clear varnames(1) stringcols(_all)
                * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
                quietly count
                local output_rows = r(N)
            restore
        }

        // Añadir la ruta relativa y sus metadatos al índice reproducible.
        post `index_post' ///
            ("`output_section'") ///
            ("`output_file'") ///
            ("`output_section'/`output_file'") ///
            ("`output_format'") ///
            (`output_rows') ///
            ("`section_content'")
    }
}

* Incluir el propio índice antes de cerrar el inventario.
post `index_post' ///
    ("05_exports") ///
    ("results_index.csv") ///
    ("05_exports/results_index.csv") ///
    ("csv") ///
    (.) ///
    ("Paquete final consolidado")
* Cerrar y guardar la tabla de resultados temporales en disco.
postclose `index_post'

* Exportar el índice ordenado y completar su propio número de filas.
preserve
    use "`index_data'", clear
    sort section filename
    * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
    quietly count
    replace data_rows = r(N) if relative_path == "05_exports/results_index.csv"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 59
    export delimited using ///
        "$OUTPUT_DISAGG_EXPORTS/results_index.csv", ///
        replace datafmt
restore


// 24.4. Ejecutar y cerrar el Control J

* Comprobar que los doce archivos finales estén presentes y no estén vacíos.
local final_export_count = 0
foreach final_file in ///
    final_focal_coefficients.csv ///
    final_model_comparison.csv ///
    final_joint_tests.csv ///
    final_component_marginal_effects.csv ///
    final_stability_classification.csv ///
    table_eci_divx_aggregate_disaggregated.tex ///
    table_eci_divx_aggregate_disaggregated.txt ///
    table_eci_divx_full_models.tex ///
    table_eci_divx_full_models.txt ///
    temporal_extension_manifest.csv ///
    results_manifest.csv ///
    results_index.csv {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "$OUTPUT_DISAGG_EXPORTS/`final_file'"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _rc == 0
    local ++final_export_count
}
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `final_export_count' == 12

* Verificar los conteos comprometidos en las seis tablas finales.
local final_tables ///
    final_focal_coefficients.csv ///
    final_model_comparison.csv ///
    final_joint_tests.csv ///
    final_component_marginal_effects.csv ///
    final_stability_classification.csv ///
    temporal_extension_manifest.csv
local expected_rows "12 4 14 20 8 5"
local final_table_count : word count `final_tables'
forvalues table_index = 1/`final_table_count' {
    local final_table : word `table_index' of `final_tables'
    local expected_row_count : word `table_index' of `expected_rows'
    preserve
        quietly import delimited using ///
            "$OUTPUT_DISAGG_EXPORTS/`final_table'", ///
            clear varnames(1)
        * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
        quietly count
        * Control de calidad automático que detiene el script si no se cumple la condición.
        assert r(N) == `expected_row_count'
    restore
}

* Confirmar que el manifiesto general integra los conteos temporales aprobados.
preserve
    import delimited using ///
        "$OUTPUT_DISAGG_EXPORTS/results_manifest.csv", ///
        clear varnames(1)
    assert _N == 1
    assert temporal_extension_files == 5
    assert temporal_design_rows == 12
    assert temporal_inventory_rows == 2
    assert temporal_unit_root_rows == 4
    assert temporal_error_test_rows == 6
    assert temporal_post2014_rows == 8
    assert final_export_files == 12
    assert indexed_files == 59
    assert temporal_control_status == "Bloques 1-5 validados"
restore

* Confirmar que el índice contiene los seis artefactos de integración temporal.
local temporal_index_paths ///
    "00_design/component_temporal_design.csv 01_diagnostics/component_temporal_inventory.csv 01_diagnostics/panel_unit_root_components.csv 01_diagnostics/component_error_tests.csv 04_stability/post_2014_stability.csv 05_exports/temporal_extension_manifest.csv"
local temporal_index_rows "12 2 4 6 8 5"
local temporal_index_count : word count `temporal_index_paths'

preserve
    import delimited using ///
        "$OUTPUT_DISAGG_EXPORTS/results_index.csv", ///
        clear varnames(1)
    assert _N == 59
    forvalues temporal_index_i = 1/`temporal_index_count' {
        local temporal_index_path : word `temporal_index_i' of ///
            `temporal_index_paths'
        local temporal_index_expected : word `temporal_index_i' of ///
            `temporal_index_rows'
        quietly count if ///
            relative_path == "`temporal_index_path'" & ///
            data_rows == `temporal_index_expected'
        assert r(N) == 1
    }
restore

* Notificar que el paquete interno superó todas las verificaciones del Control J.
display as result "Control J validado: paquete final completo y reproducible."
display as result ///
    "Bloque 6 validado: cinco bloques temporales integrados sin cambios del modelo."


// *****************************************************************************
// CIERRE DEL ARCHIVO 08.
// *****************************************************************************

* Informar el alcance ejecutado y cerrar el registro del archivo 08.
display as result "Sección 24 completada: exportaciones finales e índice generados."
display as result "Archivo 08 finalizado: secciones 19 a 24 completadas sin errores."
log close disaggregation_log
