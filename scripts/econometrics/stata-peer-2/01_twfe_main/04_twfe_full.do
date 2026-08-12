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
// Archivo: 04_twfe_full.do (Versión Codex - Peer-2)
// Contenido: Modelo 3 Completo (M3 Integrado) — Estimación Principal, Efectos Marginales e Inferencia
// Propósito: Integrar todos los canales teóricos (Institucional, Abundancia, Estructura,
//            Estabilidad Macroeconómica y Capacidades) en la ecuación de referencia del TFM.
// Requisito operativo: Ejecutar previamente 01_data_preparation_diagnostics.do
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************

// =============================================================================
// GUÍA RÁPIDA DE COMPRENSIÓN ECONOMÉTRICA (MODELO 3 INTEGRADO):
// - ¿Por qué es el modelo central? M3 condensa los 33 coeficientes de la especificación
//   completa, permitiendo aislar el efecto directo de RENTS sobre ECI y DIVX manteniendo
//   constantes todos los demás canales de transmisión.
// - ¿Cómo se validan los efectos marginales? Mediante margins, dydx(rents) at(inst=(...)),
//   generando las pendientes condicionales y gráficos de interacción por percentil de INST.
// - Inferencia robusta: Combina errores estándar agrupados por país (cluster country_id) con
//   Wild Cluster Bootstrap (boottest) a 9.999 repeticiones para descartar sesgos por número de clusters.
// =============================================================================

// *****************************************************************************
// INICIALIZACIÓN DEL ARCHIVO 04
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


// A.2. Localizar la raíz del proyecto

* Utilizar el panel maestro como marcador estable de la raíz del repositorio.
local project_marker ///
    "data/processed/00_master_panel/master_panel_country_year.dta"

* Examinar primero el directorio actual y hasta ocho niveles superiores. Después se probará la ubicación habitual de Windows; project_manual queda disponible para otros equipos.
local project_current "`c(pwd)'"
local project_windows ///
    "C:/Users/`c(username)'/GitHub/master-thesis-project-applied-econ"
local project_manual ""
global PROJECT_ROOT ""

* Buscar el marcador desde el directorio actual y ascendiendo como máximo ocho niveles. Esto permite ejecutarlo desde su carpeta o desde logs/batch sin depender de una ruta absoluta.
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

* Probar la ubicación habitual de Windows si la búsqueda ascendente falló.
if "$PROJECT_ROOT" == "" {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "`project_windows'/`project_marker'"
    if !_rc {
        global PROJECT_ROOT "`project_windows'"
    }
}

* Probar finalmente la ruta manual cuando haya sido diligenciada.
if "$PROJECT_ROOT" == "" & "`project_manual'" != "" {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "`project_manual'/`project_marker'"
    if !_rc {
        global PROJECT_ROOT "`project_manual'"
    }
}

* Detener la ejecución si ninguna de las ubicaciones contiene el proyecto.
if "$PROJECT_ROOT" == "" {
    display as error "No se pudo localizar la raíz del repositorio."
    display as error "Edite local project_manual en la inicialización."
    exit 601
}

* Cambiar a la raíz identificada y mostrarla en pantalla para que el usuario pueda verificar desde dónde se ejecutará el resto del análisis.
quietly cd "$PROJECT_ROOT"
display as result "Raíz del proyecto localizada correctamente:"
pwd

* Cargar rutinas compartidas para los contratos esenciales de estimación.
do "scripts/econometrics/stata-peer-2/01_twfe_main/00_validation_helpers.do"


// A.3. Definir las entradas, salidas y el log del archivo 04

* Centralizar las rutas de todas las salidas econométricas. Cada macro global identifica una carpeta específica y evita repetir rutas absolutas más abajo.
global OUTPUT_ROOT ///
    "$PROJECT_ROOT/outputs/econometrics/stata-peer-2/01_twfe_main"
global OUTPUT_DESIGN      "$OUTPUT_ROOT/00_design"
global OUTPUT_SAMPLE      "$OUTPUT_ROOT/01_sample"
global OUTPUT_DIAGNOSTICS "$OUTPUT_ROOT/02_diagnostics"
global OUTPUT_ECI         "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX        "$OUTPUT_ROOT/04_divx"
global OUTPUT_STABILITY   "$OUTPUT_ROOT/05_stability"
global OUTPUT_FINAL       "$OUTPUT_ROOT/06_final"
global OUTPUT_LOGS        "$OUTPUT_ROOT/logs"
global ADO_PROJECT        "$OUTPUT_ROOT/ado"

* Crear la estructura de carpetas necesaria. capture permite repetir el archivo sin detenerse cuando alguna carpeta ya existe.
capture mkdir "$PROJECT_ROOT/outputs"
capture mkdir "$PROJECT_ROOT/outputs/econometrics"
capture mkdir "$OUTPUT_ROOT"
capture mkdir "$OUTPUT_ECI"
capture mkdir "$OUTPUT_DIVX"
capture mkdir "$OUTPUT_STABILITY"
capture mkdir "$OUTPUT_FINAL"
capture mkdir "$OUTPUT_LOGS"
capture mkdir "$ADO_PROJECT"
capture mkdir "$ADO_PROJECT/plus"

* Abrir un registro de texto exclusivo para las secciones 9 a 12. replace garantiza que el log corresponda únicamente a la ejecución más reciente.
log using "$OUTPUT_LOGS/04_twfe_full.log", ///
    text replace name(models_log)


// A.4. Verificar e instalar los paquetes de estimación y exportación

* Añadir una biblioteca de paquetes exclusiva de stata-peer-2 sin reemplazar las rutas donde ya están instalados ftools, reghdfe y esttab.
adopath ++ "$ADO_PROJECT/plus"

* Indicar que las nuevas instalaciones deben escribirse en la biblioteca local, no en la carpeta personal del usuario.
net set ado "$ADO_PROJECT/plus"

* Confirmar que la biblioteca local y las rutas existentes forman parte de la búsqueda de comandos ado.
adopath

* ftools es la dependencia utilizada por reghdfe.
capture which ftools
if _rc {
    display as text "Instalando el paquete ftools desde SSC..."
    ssc install ftools
}

* reghdfe verifica el modelo con efectos fijos absorbidos.
capture which reghdfe
if _rc {
    display as text "Instalando el paquete reghdfe desde SSC..."
    ssc install reghdfe
}

* estout proporciona esttab para exportar las tablas LaTeX.
capture which esttab
if _rc {
    display as text "Instalando el paquete estout desde SSC..."
    ssc install estout
}

* boottest permite contrastar los términos centrales mediante wild cluster bootstrap. Esta inferencia se utilizará únicamente como sensibilidad.
capture which boottest
if _rc {
    display as text ///
        "Instalando boottest desde su repositorio oficial HTTPS..."
    net install boottest, ///
        from("https://raw.githubusercontent.com/droodman/boottest/master") ///
        replace
}

* Detener la ejecución si algún comando externo sigue sin estar disponible.
foreach command in ftools reghdfe esttab boottest {
    capture which `command'
    if _rc {
        display as error "Stata no encuentra el comando requerido: `command'"
        exit 199
    }
}

* Registrar las versiones de los comandos externos utilizados.
which ftools
which reghdfe
which esttab
which boottest

* Actualizar el índice de bibliotecas Mata después de añadir la ruta local. boottest guarda sus funciones compiladas dentro de lboottest.mlib.
mata: mata mlib index


// A.5. Comprobar que el archivo 01 produjo la base analítica

* Guardar en una macro local la ruta de la base derivada que alimenta los dos modelos econométricos.
local estimation_file ///
    "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta"

* Detener la ejecución con una instrucción clara si todavía no se ha ejecutado el archivo 01 o si su base analítica no está disponible.
capture confirm file "`estimation_file'"
if _rc {
    display as error "No se encontró la base preparada para las estimaciones."
    display as error "Ejecute primero:"
    display as error ///
        "01_data_preparation_diagnostics.do"
    exit 601
}

* Verificar los contratos y diagnósticos que documentan la procedencia de la
* muestra, la estrategia econométrica y las alertas de influencia.
capture confirm file "$OUTPUT_SAMPLE/sample_contract.csv"
if _rc {
    display as error "No se encontró sample_contract.csv; ejecute el archivo 01."
    exit 601
}

capture confirm file "$OUTPUT_DESIGN/econometric_decision_register.csv"
if _rc {
    display as error ///
        "No se encontró econometric_decision_register.csv; ejecute el archivo 01."
    exit 601
}

capture confirm file "$OUTPUT_DIAGNOSTICS/panel_error_tests.csv"
if _rc {
    display as error ///
        "No se encontró panel_error_tests.csv; ejecute el archivo 01."
    exit 601
}

capture confirm file "$OUTPUT_DIAGNOSTICS/temporal_control_inventory.csv"
if _rc {
    display as error ///
        "No se encontró temporal_control_inventory.csv; ejecute el archivo 01."
    exit 601
}

capture confirm file "$OUTPUT_DIAGNOSTICS/panel_unit_root_controls.csv"
if _rc {
    display as error ///
        "No se encontró panel_unit_root_controls.csv; ejecute el archivo 01."
    exit 601
}

capture confirm file "$OUTPUT_DIAGNOSTICS/influential_observations.csv"
if _rc {
    display as error ///
        "No se encontró influential_observations.csv; ejecute el archivo 01."
    exit 601
}

* Leer el contrato de muestra y conservar sus valores como referencia para las
* validaciones posteriores de ECI, DIVX y las sensibilidades.
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
assert key_definition == "country_iso3_code + year"
assert sample_rule == "COMPLETE_CASES"

quietly summarize sample_observations, meanonly
local contract_sample_n = r(min)
quietly summarize sample_countries, meanonly
local contract_sample_countries = r(min)
quietly summarize effective_years, meanonly
local contract_effective_years = r(min)
quietly summarize first_year, meanonly
local contract_first_year = r(min)
quietly summarize last_year, meanonly
local contract_last_year = r(min)
local contract_rows = _N

* Leer el registro de decisiones y verificar únicamente las decisiones que
* constituyen condiciones de entrada del M3. Las sensibilidades implementadas
* o condicionales se validan sin alterar la jerarquía del modelo principal.
import delimited using ///
    "$OUTPUT_DESIGN/econometric_decision_register.csv", ///
    clear varnames(1)
assert _N == 18
isid decision_id
assert significance_selected == 0
local decision_register_rows = _N

local required_active_decisions D01 D02 D03 D06 D17
local required_active_count = 0
foreach required_decision of local required_active_decisions {
    quietly count if decision_id == "`required_decision'" & ///
        hierarchy == "MAIN" & implementation_status == "ACTIVE"
    assert r(N) == 1
    local required_active_count = `required_active_count' + r(N)
}

quietly count if decision_id == "D04" & hierarchy == "SENSITIVITY" & ///
    implementation_status == "IMPLEMENTED"
assert r(N) == 1
local decision_d04_implemented = r(N)

quietly count if decision_id == "D07" & hierarchy == "SENSITIVITY" & ///
    implementation_status == "IMPLEMENTED"
assert r(N) == 1
local decision_d07_implemented = r(N)

quietly count if decision_id == "D08" & hierarchy == "SENSITIVITY" & ///
    implementation_status == "IMPLEMENTED"
assert r(N) == 1
local decision_d08_implemented = r(N)

quietly count if decision_id == "D12" & hierarchy == "SENSITIVITY" & ///
    implementation_status == "IMPLEMENTED"
assert r(N) == 1
local decision_d12_implemented = r(N)

quietly count if decision_id == "D13" & hierarchy == "CONDITIONAL" & ///
    implementation_status == "IMPLEMENTED_WITH_JUSTIFICATION"
assert r(N) == 1
local decision_d13_implemented = r(N)

quietly count if decision_id == "D18" & hierarchy == "MAIN" & ///
    implementation_status == "DIAGNOSTIC_ONLY"
assert r(N) == 1
local decision_d18_documented = r(N)

* Confirmar que el reporte de errores corresponde a las mismas dimensiones y
* que todas las pruebas incorporan efectos de año.
import delimited using "$OUTPUT_DIAGNOSTICS/panel_error_tests.csv", ///
    clear varnames(1)
assert _N == 6
assert observations == `contract_sample_n'
assert countries == `contract_sample_countries'
assert includes_year_fe == 1
local error_test_rows = _N
quietly count if includes_year_fe == 1
local error_tests_with_year_fe = r(N)

* Validar el inventario temporal de controles que documenta la persistencia y
* cobertura del M3 sin autorizar cambios de especificación.
import delimited using ///
    "$OUTPUT_DIAGNOSTICS/temporal_control_inventory.csv", ///
    clear varnames(1)
assert _N == 14
isid variable
assert source_observations == `contract_sample_n'
assert countries == `contract_sample_countries'
assert model_change_authorized == 0
quietly count if variable == "hhi" & model_scope == "ECI_ONLY"
local ctrl_hhi_scope_rows = r(N)
assert `ctrl_hhi_scope_rows' == 1
quietly count if variable != "hhi" & model_scope == "BOTH"
assert r(N) == 13
local ctrl_inventory_rows = _N

* Confirmar que la batería reducida contiene exactamente dos formas por control,
* una única especificación predefinida y resultados numéricos completos.
import delimited using ///
    "$OUTPUT_DIAGNOSTICS/panel_unit_root_controls.csv", ///
    clear varnames(1)
assert _N == 28
isid variable series_form
bysort variable: assert _N == 2
assert method == "FISHER_ADF"
assert deterministics == "CONSTANT"
assert demeaned == 1
assert lags == 1
assert return_code == 0
assert !missing(statistic, p_value)
assert model_change_authorized == 0
local ctrl_unitroot_rows = _N
quietly count if model_change_authorized == 1
local ctrl_authorized_changes = r(N)

* Calcular nuevamente las dimensiones directamente desde la base que será
* utilizada por las estimaciones y compararlas con el contrato del archivo 01.
use "`estimation_file'", clear
isid country_iso3_code year
assert sample_eci == sample_divx

quietly count if sample_eci == 1
local observed_sample_n = r(N)
quietly levelsof country_id if sample_eci == 1, ///
    local(observed_sample_country_ids)
local observed_sample_countries : word count `observed_sample_country_ids'
quietly levelsof year if sample_eci == 1, local(observed_sample_years)
local observed_effective_years : word count `observed_sample_years'
quietly summarize year if sample_eci == 1, meanonly
local observed_first_year = r(min)
local observed_last_year = r(max)

assert `observed_sample_n' == `contract_sample_n'
assert `observed_sample_countries' == `contract_sample_countries'
assert `observed_effective_years' == `contract_effective_years'
assert `observed_first_year' == `contract_first_year'
assert `observed_last_year' == `contract_last_year'

* Exportar un reporte de trazabilidad con cada condición verificada antes de
* comenzar la estimación del M3.
tempname input_contract_post
tempfile input_contract_report

postfile `input_contract_post' ///
    str4 validation_id str40 validation_item ///
    str72 source str48 expected str48 observed ///
    byte passed str120 failure_action ///
    using "`input_contract_report'", replace

post `input_contract_post' ///
    ("V01") ("ESTIMATION_DATASET_EXISTS") ///
    ("master_panel_estimation_sample.dta") ///
    ("EXISTS") ("EXISTS") (1) ///
    ("Ejecutar nuevamente el archivo 01.")
post `input_contract_post' ///
    ("V02") ("SAMPLE_CONTRACT_ROWS") ("sample_contract.csv") ///
    ("2") ("`contract_rows'") (`contract_rows' == 2) ///
    ("Regenerar el contrato de muestra con el archivo 01.")
post `input_contract_post' ///
    ("V03") ("COMMON_SAMPLE_OBSERVATIONS") ///
    ("sample_contract.csv; estimation dataset") ///
    ("`contract_sample_n'") ("`observed_sample_n'") ///
    (`observed_sample_n' == `contract_sample_n') ///
    ("Detener la estimación y revisar las banderas de muestra.")
post `input_contract_post' ///
    ("V04") ("COMMON_SAMPLE_COUNTRIES") ///
    ("sample_contract.csv; estimation dataset") ///
    ("`contract_sample_countries'") ("`observed_sample_countries'") ///
    (`observed_sample_countries' == `contract_sample_countries') ///
    ("Detener la estimación y revisar la cobertura por país.")
post `input_contract_post' ///
    ("V05") ("EFFECTIVE_YEARS") ///
    ("sample_contract.csv; estimation dataset") ///
    ("`contract_effective_years'") ("`observed_effective_years'") ///
    (`observed_effective_years' == `contract_effective_years') ///
    ("Detener la estimación y revisar la cobertura temporal.")
post `input_contract_post' ///
    ("V06") ("SAMPLE_FLAGS_IDENTICAL") ///
    ("sample_contract.csv; estimation dataset") ///
    ("1") ("1") (1) ///
    ("Detener la estimación si ECI y DIVX usan filas diferentes.")
post `input_contract_post' ///
    ("V07") ("NO_IMPUTATION") ("sample_contract.csv") ///
    ("1") ("1") (1) ///
    ("Regenerar la base sin imputación.")
post `input_contract_post' ///
    ("V08") ("NO_INTERPOLATION") ("sample_contract.csv") ///
    ("1") ("1") (1) ///
    ("Regenerar la base sin interpolación.")
post `input_contract_post' ///
    ("V09") ("KEY_DEFINITION") ("sample_contract.csv") ///
    ("country_iso3_code + year") ("country_iso3_code + year") (1) ///
    ("Restablecer la llave país-año validada.")
post `input_contract_post' ///
    ("V10") ("DECISION_REGISTER_ROWS") ///
    ("econometric_decision_register.csv") ///
    ("18") ("`decision_register_rows'") ///
    (`decision_register_rows' == 18) ///
    ("Regenerar el registro de decisiones con el archivo 01.")
post `input_contract_post' ///
    ("V11") ("SIGNIFICANCE_SELECTION") ///
    ("econometric_decision_register.csv") ///
    ("0") ("0") (1) ///
    ("Eliminar cualquier selección de especificación por significancia.")
post `input_contract_post' ///
    ("V12") ("REQUIRED_ACTIVE_DECISIONS") ///
    ("econometric_decision_register.csv") ///
    ("5") ("`required_active_count'") ///
    (`required_active_count' == 5) ///
    ("Restablecer D01, D02, D03, D06 y D17 como decisiones activas.")
post `input_contract_post' ///
    ("V13") ("D08_TRENDS_STATUS") ///
    ("econometric_decision_register.csv") ///
    ("IMPLEMENTED") ("IMPLEMENTED") ///
    (`decision_d08_implemented' == 1) ///
    ("No ejecutar tendencias si D08 no está implementada como sensibilidad.")
post `input_contract_post' ///
    ("V14") ("D13_2014_STATUS") ///
    ("econometric_decision_register.csv") ///
    ("IMPLEMENTED_WITH_JUSTIFICATION") ///
    ("IMPLEMENTED_WITH_JUSTIFICATION") ///
    (`decision_d13_implemented' == 1) ///
    ("No ejecutar la prueba de 2014 sin justificación externa documentada.")
post `input_contract_post' ///
    ("V15") ("ERROR_TEST_ROWS") ("panel_error_tests.csv") ///
    ("6") ("`error_test_rows'") (`error_test_rows' == 6) ///
    ("Regenerar los diagnósticos de errores con el archivo 01.")
post `input_contract_post' ///
    ("V16") ("ERROR_TESTS_WITH_YEAR_FE") ///
    ("panel_error_tests.csv") ///
    ("6") ("`error_tests_with_year_fe'") ///
    (`error_tests_with_year_fe' == 6) ///
    ("Regenerar las pruebas usando efectos de año.")
post `input_contract_post' ///
    ("V17") ("INFLUENCE_INVENTORY_EXISTS") ///
    ("influential_observations.csv") ///
    ("EXISTS") ("EXISTS") (1) ///
    ("Regenerar el inventario de influencia con el archivo 01.")
post `input_contract_post' ///
    ("V18") ("D04_BOOTSTRAP_STATUS") ///
    ("econometric_decision_register.csv") ///
    ("IMPLEMENTED") ("IMPLEMENTED") ///
    (`decision_d04_implemented' == 1) ///
    ("No presentar el bootstrap si D04 no está implementada.")
post `input_contract_post' ///
    ("V19") ("D07_MARGINAL_EFFECT_STATUS") ///
    ("econometric_decision_register.csv") ///
    ("IMPLEMENTED") ("IMPLEMENTED") ///
    (`decision_d07_implemented' == 1) ///
    ("No presentar márgenes fuera del soporte institucional observado.")
post `input_contract_post' ///
    ("V20") ("D12_INFLUENCE_STATUS") ///
    ("econometric_decision_register.csv") ///
    ("IMPLEMENTED") ("IMPLEMENTED") ///
    (`decision_d12_implemented' == 1) ///
    ("No presentar influencia sin exclusión diagnóstica y leave-one-out.")
post `input_contract_post' ///
    ("V21") ("D18_CONTROL_TEMPORAL_STATUS") ///
    ("econometric_decision_register.csv") ///
    ("DIAGNOSTIC_ONLY") ("DIAGNOSTIC_ONLY") ///
    (`decision_d18_documented' == 1) ///
    ("Regenerar el registro y el inventario temporal mediante el archivo 01.")
post `input_contract_post' ///
    ("V22") ("CONTROL_TEMPORAL_INVENTORY_ROWS") ///
    ("temporal_control_inventory.csv") ///
    ("14") ("`ctrl_inventory_rows'") ///
    (`ctrl_inventory_rows' == 14) ///
    ("Detener M3 si falta algún control en el inventario temporal.")
post `input_contract_post' ///
    ("V23") ("CONTROL_UNIT_ROOT_ROWS") ///
    ("panel_unit_root_controls.csv") ///
    ("28") ("`ctrl_unitroot_rows'") ///
    (`ctrl_unitroot_rows' == 28) ///
    ("Regenerar las pruebas predefinidas de los catorce controles.")
post `input_contract_post' ///
    ("V24") ("CONTROL_DIAGNOSTIC_MODEL_CHANGES") ///
    ("temporal_control_inventory.csv; panel_unit_root_controls.csv") ///
    ("0") ("`ctrl_authorized_changes'") ///
    (`ctrl_authorized_changes' == 0) ///
    ("No seleccionar ni transformar controles mediante significancia diagnóstica.")

postclose `input_contract_post'

use "`input_contract_report'", clear
assert _N == 24
isid validation_id
assert passed == 1
sort validation_id
export delimited using ///
    "$OUTPUT_DESIGN/m3_input_contract_validation.csv", ///
    replace datafmt
list validation_id validation_item expected observed passed, ///
    noobs abbreviate(32)
clear

* Informar que todas las comprobaciones de inicialización fueron superadas y que el archivo puede comenzar la estimación del modelo principal.
display as result ///
    "Inicialización del archivo 04 completada; comienza la sección 9."


// *****************************************************************************
// 9. Modelo TWFE Completo: ECI [Ecuación 9.17]
// *****************************************************************************


// 9.1. Cargar y verificar la muestra del modelo principal

* Abrir la base derivada en la sección 3. El panel maestro original permanece intacto; todas las estimaciones utilizan exclusivamente esta copia analítica.
use "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta", clear

* Confirmar que la base conserva una sola observación por país y año.
isid country_iso3_code year

* Confirmar que las variables necesarias para el modelo siguen disponibles.
confirm variable ///
    eci sample_eci sample_divx country_id year ///
    rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin

* Verificar nuevamente que la interacción almacenada corresponde exactamente al producto entre las rentas extractivas y la calidad institucional.
assert abs(rents_x_inst - rents * inst) < 1e-10 ///
    if !missing(rents_x_inst, rents, inst)

* Confirmar que la bandera ECI coincide fila por fila con el contrato común.
assert sample_eci == sample_divx

* Declarar el identificador del país y el año como dimensiones del panel.
xtset country_id year

* Contar las observaciones y los países que deben entrar en la estimación. Estos valores se compararán después con la muestra utilizada por xtreg.
quietly count if sample_eci == 1
local eci_expected_n = r(N)

* Identificar los países presentes en la muestra y contar cuántos paneles individuales aportan al modelo ECI.
quietly levelsof country_id if sample_eci == 1, ///
    local(eci_expected_country_ids)
local eci_expected_countries : word count `eci_expected_country_ids'

* Identificar los años efectivos de estimación y contar los periodos con al menos una observación completa.
quietly levelsof year if sample_eci == 1, local(eci_expected_years)
local eci_expected_year_count : word count `eci_expected_years'

* Recuperar los extremos temporales para documentar el intervalo cubierto por la muestra analítica.
quietly summarize year if sample_eci == 1, meanonly
local eci_first_year = r(min)
local eci_last_year  = r(max)

* Comparar la muestra ECI calculada en memoria con el contrato del archivo 01.
assert `eci_expected_n' == `contract_sample_n'
assert `eci_expected_countries' == `contract_sample_countries'
assert `eci_expected_year_count' == `contract_effective_years'
assert `eci_first_year' == `contract_first_year'
assert `eci_last_year' == `contract_last_year'

* Los WGI no publicaron los componentes de INST en 1997, 1999 y 2001. Por ello la muestra de casos completos contiene 23 años efectivos dentro del intervalo 1996-2021. Se conservan los vacíos: no se imputan ni interpolan.
foreach structural_wgi_gap in 1997 1999 2001 {
    * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
    quietly count if year == `structural_wgi_gap' & sample_eci == 1
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert r(N) == 0
}

* Mostrar en pantalla la cobertura que deberá reproducir la estimación.
display as text ///
    "Muestra esperada para ECI: `eci_expected_n' observaciones, " ///
    "`eci_expected_countries' países y `eci_expected_year_count' años."
display as text ///
    "Años WGI sin casos completos: 1997, 1999 y 2001."


// 9.2. Definir la ecuación ECI y la estrategia de inferencia

* Escribir la interacción con notación factorial. El operador ## incorpora RENTS, INST y RENTS x INST y permitirá calcular efectos marginales en la sección 7 sin reconstruir manualmente el modelo.
global ECI_REGRESSORS ///
    c.rents##c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin

* Definir los 17 términos sustantivos que se reportarán. Los indicadores de año también forman parte de la estimación, pero no se mostrarán como coeficientes individuales en las tablas principales.
local eci_terms ///
    rents inst c.rents#c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin

* Inferencia principal: errores agrupados por país ante heterocedasticidad y
* autocorrelación. Los efectos de año absorben shocks comunes; Pesaran CD no
* activa automáticamente Driscoll--Kraay. Véase INFERENCE_RULE.md.
global INFERENCE_MAIN "vce(cluster country_id)"


// 9.3. Estimar el modelo principal mediante xtreg

* Estimar la ecuación completa de la metodología: - fe absorbe los efectos fijos por país; - i.year incorpora los efectos fijos por año; - vce(cluster country_id) permite dependencia arbitraria dentro de cada país.
xtreg eci $ECI_REGRESSORS i.year if sample_eci == 1, ///
    fe $INFERENCE_MAIN

* Eliminar una copia previa con el mismo nombre para que la sección pueda ejecutarse nuevamente durante la revisión interactiva.
capture estimates drop ECI_TWFE_MAIN

* Guardar la estimación principal en la memoria de Stata.
estimates store ECI_TWFE_MAIN

* Guardar también una copia permanente para recuperarla sin reestimar.
estimates save "$OUTPUT_ECI/eci_twfe_main.ster", replace

* Comprobar que xtreg utilizó todos y únicamente los casos completos definidos en la sección 3. Cualquier diferencia detiene inmediatamente el archivo.
peer2_assert_estimation_contract, ///
    sample(sample_eci) observations(`eci_expected_n') ///
    countries(`eci_expected_countries') clusters(`eci_expected_countries')

* Guardar los principales resultados globales antes de ejecutar pruebas o abrir archivos temporales de resultados.
local eci_n          = e(N)
local eci_countries  = e(N_g)
local eci_clusters   = e(N_clust)
local eci_r2_within  = e(r2_w)
local eci_r2_between = e(r2_b)
local eci_r2_overall = e(r2_o)
local eci_f          = e(F)
local eci_df_model   = e(df_m)
local eci_df_error   = e(df_r)
local eci_model_p    = e(p)
local eci_rmse       = e(rmse)
local eci_sigma_u    = e(sigma_u)
local eci_sigma_e    = e(sigma_e)
local eci_rho        = e(rho)

* Con errores agrupados por país, Stata utiliza G-1 grados de libertad para la inferencia, donde G es el número de países que actúan como conglomerados.
assert `eci_df_error' == `eci_clusters' - 1

* Mostrar el tamaño de la estimación y su principal medida de ajuste within.
display as result ///
    "Modelo ECI estimado con `eci_n' observaciones y `eci_countries' países."
display as result ///
    "R-cuadrado within: " %9.4f `eci_r2_within'


// 9.4. Exportar los coeficientes y la incertidumbre del modelo

* Crear un reporte largo con una fila por término sustantivo. Este formato facilita revisar coeficientes, errores estándar, valores p e intervalos.
tempname eci_coefficients_post
tempfile eci_coefficients_report

* Definir la estructura del archivo temporal que recibirá una fila por coeficiente sustantivo del modelo.
postfile `eci_coefficients_post' ///
    int order ///
    str32 term ///
    str100 variable_label ///
    str32 channel ///
    double coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper ///
    using "`eci_coefficients_report'", replace

* Utilizar la distribución t con grados de libertad determinados por los conglomerados de país para construir intervalos de confianza del 95 %.
local eci_critical_t = invttail(`eci_df_error', 0.025)
local eci_term_order = 0

* Recorrer los términos en el orden de presentación definido para la tabla.
foreach term of local eci_terms {
    local ++eci_term_order

    // Recuperar el nombre descriptivo de cada variable.
    if "`term'" == "c.rents#c.inst" {
        local term_label "Interacción entre rentas y calidad institucional"
    }
    else {
        local term_label : variable label `term'
        if `"`term_label'"' == "" {
            local term_label "`term'"
        }
    }

    // Asignar cada coeficiente al canal teórico definido en la metodología.
    local channel "Controles económicos y financieros"

    // Reemplazar la categoría predeterminada cuando el término pertenece a uno de los canales sustantivos de la especificación.
    if inlist("`term'", "rents", "inst", "c.rents#c.inst") {
        local channel "Institucional"
    }
    else if inlist("`term'", ///
        "ln1p_oilpc", "ln1p_gaspc", "ln1p_coalpc") {
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

    // Calcular manualmente las medidas de inferencia para conservarlas en CSV.
    local coefficient    = _b[`term']
    local standard_error = _se[`term']
    local t_statistic    = `coefficient' / `standard_error'
    local p_value = 2 * ttail(`eci_df_error', abs(`t_statistic'))
    local ci_lower = ///
        `coefficient' - `eci_critical_t' * `standard_error'
    local ci_upper = ///
        `coefficient' + `eci_critical_t' * `standard_error'

    // Guardar coeficiente y error estándar para compararlos luego con reghdfe.
    scalar eci_xtreg_b_`eci_term_order'  = `coefficient'
    scalar eci_xtreg_se_`eci_term_order' = `standard_error'

    // Añadir al archivo temporal todos los resultados calculados para el término que se encuentra activo en esta iteración.
    post `eci_coefficients_post' ///
        (`eci_term_order') ///
        ("`term'") ///
        (`"`term_label'"') ///
        (`"`channel'"') ///
        (`coefficient') ///
        (`standard_error') ///
        (`t_statistic') ///
        (`p_value') ///
        (`ci_lower') ///
        (`ci_upper')
}

* Cerrar el archivo temporal para asegurar que todas las filas queden escritas.
postclose `eci_coefficients_post'

* Abrir temporalmente el reporte, aplicar formatos y exportarlo.
preserve
    use "`eci_coefficients_report'", clear
    sort order
    format coefficient standard_error t_statistic ///
        ci_lower ci_upper %12.6f
    format p_value %10.6f

    * Exportar el reporte de coeficientes en un formato abierto y reproducible.
    export delimited using ///
        "$OUTPUT_ECI/eci_twfe_coefficients.csv", replace datafmt

    * Mostrar los coeficientes en la ventana de resultados para facilitar la revisión cuando el archivo se ejecute de forma interactiva.
    list term coefficient standard_error p_value ci_lower ci_upper, ///
        noobs abbreviate(24)
restore


// 9.5. Exportar el resumen general de la estimación

* Crear una tabla de una fila con tamaño de muestra, cobertura, ajuste y componentes de la varianza del modelo de efectos fijos.
tempname eci_summary_post
tempfile eci_summary_report

* Definir las columnas del resumen de cobertura, ajuste e inferencia.
postfile `eci_summary_post' ///
    str24 model ///
    str12 dependent_variable ///
    int observations countries clusters years first_year last_year ///
    double r2_within r2_between r2_overall ///
    f_statistic df_model df_error model_p_value rmse ///
    sigma_country sigma_idiosyncratic rho_country ///
    using "`eci_summary_report'", replace

* Escribir una única fila con los resultados generales del modelo ECI.
post `eci_summary_post' ///
    ("ECI_TWFE_MAIN") ///
    ("eci") ///
    (`eci_n') ///
    (`eci_countries') ///
    (`eci_clusters') ///
    (`eci_expected_year_count') ///
    (`eci_first_year') ///
    (`eci_last_year') ///
    (`eci_r2_within') ///
    (`eci_r2_between') ///
    (`eci_r2_overall') ///
    (`eci_f') ///
    (`eci_df_model') ///
    (`eci_df_error') ///
    (`eci_model_p') ///
    (`eci_rmse') ///
    (`eci_sigma_u') ///
    (`eci_sigma_e') ///
    (`eci_rho')

* Cerrar el archivo temporal antes de abrirlo para su exportación.
postclose `eci_summary_post'

* Abrir temporalmente el resumen, aplicar formatos y conservar intacta la base analítica que permanece en memoria.
preserve
    use "`eci_summary_report'", clear
    format r2_within r2_between r2_overall ///
        f_statistic model_p_value rmse ///
        sigma_country sigma_idiosyncratic rho_country %12.6f

    * Exportar el resumen general del modelo en formato CSV.
    export delimited using ///
        "$OUTPUT_ECI/eci_twfe_model_summary.csv", replace datafmt
    list, noobs abbreviate(24)
restore


// 9.6. Realizar las pruebas conjuntas previstas por canal

* Recuperar la estimación principal antes de ejecutar las pruebas.
estimates restore ECI_TWFE_MAIN

* Preparar un reporte común para todas las hipótesis conjuntas.
tempname eci_tests_post
tempfile eci_tests_report

* Definir la estructura común para registrar las ocho pruebas conjuntas.
postfile `eci_tests_post' ///
    int order ///
    str40 test ///
    str100 null_hypothesis ///
    double f_statistic df1 df2 p_value ///
    using "`eci_tests_report'", replace

* Prueba 1: los tres términos del canal institucional son conjuntamente cero.
test rents inst c.rents#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' ///
    (1) ///
    ("Canal institucional") ///
    ("RENTS, INST y RENTS x INST son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 2: los coeficientes de petróleo, gas y carbón son conjuntamente cero.
test ln1p_oilpc ln1p_gaspc ln1p_coalpc
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' ///
    (2) ///
    ("Canal de abundancia") ///
    ("Petróleo, gas y carbón son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 3: concentración y especialización exportadora son conjuntamente cero.
test hhi pexp fexp
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' ///
    (3) ///
    ("Canal estructural") ///
    ("HHI, PEXP y FEXP son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 4: volatilidad y tipo de cambio real son conjuntamente cero.
test vol rer
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' ///
    (4) ///
    ("Canal macroeconómico") ///
    ("VOL y RER son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 5: capital humano, innovación y conectividad son conjuntamente cero.
test humcap innov net
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' ///
    (5) ///
    ("Capacidades productivas") ///
    ("HUMCAP, INNOV y NET son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 6: los tres controles económicos y financieros son conjuntamente cero.
test log_gdppc govcons fin
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' ///
    (6) ///
    ("Controles económicos y financieros") ///
    ("log(GDPPC), GOVCONS y FIN son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 7: verificar la relevancia conjunta de los efectos temporales.
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' ///
    (7) ///
    ("Efectos fijos por año") ///
    ("Todos los indicadores de año son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 8: evaluar si petróleo, gas y carbón tienen el mismo coeficiente. Esta prueba no impone que los efectos sean cero, sino que sean iguales.
test (ln1p_oilpc = ln1p_gaspc) ///
     (ln1p_oilpc = ln1p_coalpc)
* Escribir una fila de resultados dentro del archivo temporal.
post `eci_tests_post' ///
    (8) ///
    ("Igualdad entre recursos") ///
    ("Los coeficientes de petróleo, gas y carbón son iguales") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Cerrar el archivo temporal que reúne las pruebas de hipótesis.
postclose `eci_tests_post'

* Exportar y mostrar las pruebas conjuntas.
preserve
    use "`eci_tests_report'", clear
    sort order
    format f_statistic p_value %12.6f

    * Exportar todas las pruebas conjuntas en un único archivo CSV.
    export delimited using ///
        "$OUTPUT_ECI/eci_twfe_joint_tests.csv", replace datafmt
    list, noobs abbreviate(28)
restore


// 9.7. Verificar los coeficientes mediante reghdfe

* Estimar exactamente la misma ecuación absorbiendo directamente los efectos fijos por país y año. Esta no es una especificación adicional: funciona como una comprobación numérica independiente del modelo principal.
reghdfe eci $ECI_REGRESSORS if sample_eci == 1, ///
    absorb(country_id year) $INFERENCE_MAIN

* Eliminar una copia previa con el mismo nombre si se repite esta sección.
capture estimates drop ECI_REGHDFE_CHECK

* Guardar la estimación de comprobación sin reemplazar el resultado principal.
estimates store ECI_REGHDFE_CHECK
estimates save "$OUTPUT_ECI/eci_reghdfe_check.ster", replace

* Verificar que reghdfe conservó la misma muestra utilizada por xtreg.
assert e(N) == `eci_n'

* Guardar el tamaño de la comprobación, el número de singletons y la tolerancia numérica que se utilizará para comparar ambos comandos.
local eci_hdfe_n          = e(N)
local eci_hdfe_singletons = e(num_singletons)
local coefficient_tolerance = 1e-8
local max_coefficient_difference = 0

* Preparar un reporte término por término de la equivalencia numérica.
tempname eci_verification_post
tempfile eci_verification_report

* Definir las columnas del reporte de equivalencia término por término.
postfile `eci_verification_post' ///
    int order ///
    str32 term ///
    double xtreg_coefficient reghdfe_coefficient ///
    absolute_coefficient_difference ///
    xtreg_standard_error reghdfe_standard_error ///
    absolute_se_difference ///
    byte coefficient_match ///
    using "`eci_verification_report'", replace

* Reiniciar el contador para que el orden coincida con el reporte de coeficientes producido anteriormente.
local eci_term_order = 0

* Recorrer los términos sustantivos y comparar las dos implementaciones.
foreach term of local eci_terms {
    local ++eci_term_order

    // Comparar coeficientes y registrar también cualquier diferencia entre los errores estándar producidos por los dos comandos.
    local xtreg_coefficient  = scalar(eci_xtreg_b_`eci_term_order')
    local reghdfe_coefficient = _b[`term']
    local coefficient_difference = abs( ///
        `xtreg_coefficient' - `reghdfe_coefficient')

    // Recuperar y comparar también los errores estándar agrupados por país.
    local xtreg_standard_error = ///
        scalar(eci_xtreg_se_`eci_term_order')
    local reghdfe_standard_error = _se[`term']
    local se_difference = abs( ///
        `xtreg_standard_error' - `reghdfe_standard_error')

    // Crear una bandera que indique si el coeficiente cumple la tolerancia.
    local coefficient_match = ///
        `coefficient_difference' < `coefficient_tolerance'

    // Conservar la mayor diferencia observada para la validación final.
    if `coefficient_difference' > `max_coefficient_difference' {
        local max_coefficient_difference = `coefficient_difference'
    }

    // Escribir en el reporte las dos estimaciones y sus diferencias absolutas.
    post `eci_verification_post' ///
        (`eci_term_order') ///
        ("`term'") ///
        (`xtreg_coefficient') ///
        (`reghdfe_coefficient') ///
        (`coefficient_difference') ///
        (`xtreg_standard_error') ///
        (`reghdfe_standard_error') ///
        (`se_difference') ///
        (`coefficient_match')
}

* Cerrar el archivo temporal de verificación antes de utilizarlo.
postclose `eci_verification_post'

* Detener el archivo si algún coeficiente difiere por encima de la tolerancia.
assert `max_coefficient_difference' < `coefficient_tolerance'

* Exportar el reporte detallado de verificación.
preserve
    use "`eci_verification_report'", clear
    sort order
    format xtreg_coefficient reghdfe_coefficient ///
        absolute_coefficient_difference ///
        xtreg_standard_error reghdfe_standard_error ///
        absolute_se_difference %16.10f

    * Exportar el detalle de equivalencia entre xtreg y reghdfe.
    export delimited using ///
        "$OUTPUT_ECI/eci_xtreg_reghdfe_verification.csv", ///
        replace datafmt
    list term absolute_coefficient_difference ///
        absolute_se_difference coefficient_match, ///
        noobs abbreviate(28)
restore

* Mostrar las dos comprobaciones principales de la verificación numérica.
display as result ///
    "Máxima diferencia de coeficientes entre xtreg y reghdfe: " ///
    %16.10f `max_coefficient_difference'
display as result ///
    "Observaciones singleton eliminadas por reghdfe: `eci_hdfe_singletons'"


// 9.8. Crear una tabla LaTeX provisional para revisión

* Recuperar el modelo xtreg porque constituye la estimación principal del TFM.
estimates restore ECI_TWFE_MAIN

* Exportar una tabla provisional con los coeficientes sustantivos. La sección 8 se encargará posteriormente del formato final y de integrar ECI con DIVX.
esttab ECI_TWFE_MAIN using "$OUTPUT_ECI/eci_twfe_main.tex", ///
    replace ///
    label ///
    booktabs ///
    b(4) se(4) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    keep(`eci_terms') ///
    order(`eci_terms') ///
    coeflabels(c.rents#c.inst "RENTS x INST") ///
    stats(N N_g r2_w r2_b r2_o, ///
        fmt(0 0 4 4 4) ///
        labels("Observaciones" "Países" ///
            "R2 within" "R2 between" "R2 overall")) ///
    title("Modelo principal ECI con efectos fijos por país y año") ///
    addnotes( ///
        "Efectos fijos por país: sí." ///
        "Efectos fijos por año: sí." ///
        "Errores estándar agrupados por país." ///
        "Los indicadores de año no se muestran.")

* Informar que la sección terminó y cuál estimación queda activa en memoria.
display as result "Sección 5 completada: modelo principal ECI estimado."
display as result ///
    "La estimación activa es ECI_TWFE_MAIN y no se excluyeron observaciones."


// *****************************************************************************
// 10. Modelo TWFE Completo: DIVX [Ecuación 9.58]
// *****************************************************************************


// 10.1. Cargar y verificar la muestra del modelo complementario

* Abrir nuevamente la base analítica completa. Este paso evita que una transformación temporal de la sección 9 pueda afectar el modelo DIVX.
use "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta", clear

* Confirmar que cada fila continúa identificada de manera única por país y año.
isid country_iso3_code year

* Verificar que están disponibles DIVX, su bandera de muestra y todos los regresores previstos. HHI se conserva únicamente para validar la identidad DIVX = 1 - HHI; no se incorporará en la ecuación econométrica.
confirm variable ///
    divx hhi sample_eci sample_divx country_id year ///
    rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin

* Confirmar que la variable dependiente complementaria sigue correspondiendo exactamente al inverso del índice de concentración exportadora.
assert abs(divx - (1 - hhi)) < 1e-10 if !missing(divx, hhi)

* Confirmar también la identidad de la interacción institucional.
assert abs(rents_x_inst - rents * inst) < 1e-10 ///
    if !missing(rents_x_inst, rents, inst)

* Confirmar que DIVX utiliza exactamente las mismas filas previstas para ECI.
assert sample_divx == sample_eci

* Declarar nuevamente la estructura país-año del panel.
xtset country_id year

* Contar las observaciones que deben ingresar en el modelo DIVX.
quietly count if sample_divx == 1
local divx_expected_n = r(N)

* Identificar los países presentes y contar cuántos paneles individuales aportan observaciones al modelo complementario.
quietly levelsof country_id if sample_divx == 1, ///
    local(divx_expected_country_ids)
local divx_expected_countries : word count `divx_expected_country_ids'

* Identificar los años efectivos y contar los periodos representados en la muestra completa del modelo DIVX.
quietly levelsof year if sample_divx == 1, local(divx_expected_years)
local divx_expected_year_count : word count `divx_expected_years'

* Recuperar el primer y el último año para documentar la cobertura temporal.
quietly summarize year if sample_divx == 1, meanonly
local divx_first_year = r(min)
local divx_last_year  = r(max)

* Comparar la muestra DIVX calculada en memoria con el contrato del archivo 01.
assert `divx_expected_n' == `contract_sample_n'
assert `divx_expected_countries' == `contract_sample_countries'
assert `divx_expected_year_count' == `contract_effective_years'
assert `divx_first_year' == `contract_first_year'
assert `divx_last_year' == `contract_last_year'

* Verificar que los vacíos estructurales de WGI permanecen fuera de la muestra.
foreach structural_wgi_gap in 1997 1999 2001 {
    * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
    quietly count if year == `structural_wgi_gap' & sample_divx == 1
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert r(N) == 0
}

* Mostrar en pantalla la cobertura que deberá conservar la estimación DIVX.
display as text ///
    "Muestra esperada para DIVX: `divx_expected_n' observaciones, " ///
    "`divx_expected_countries' países y `divx_expected_year_count' años."
display as text ///
    "Años WGI sin casos completos: 1997, 1999 y 2001."


// 10.2. Definir la ecuación DIVX y excluir HHI

* Mantener la misma especificación aprobada para ECI, excepto HHI. Incluir HHI sería una identidad mecánica porque DIVX se construye como 1 - HHI.
global DIVX_REGRESSORS ///
    c.rents##c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin

* Definir los 16 términos sustantivos que se exportarán. Los indicadores de año permanecen en la estimación, pero no se muestran individualmente.
local divx_terms ///
    rents inst c.rents#c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin

* Buscar el nombre HHI dentro de la lista de regresores para impedir que una edición futura introduzca accidentalmente esta identidad en la ecuación.
local divx_hhi_position = strpos(" $DIVX_REGRESSORS ", " hhi ")

* Detener la ejecución si la búsqueda anterior encuentra HHI.
assert `divx_hhi_position' == 0

* Conservar la inferencia principal: errores agrupados por país para responder
* a heterocedasticidad y autocorrelación; no sustituirla automáticamente por DK.
global INFERENCE_MAIN "vce(cluster country_id)"


// 10.3. Estimar el modelo complementario mediante xtreg

* Estimar DIVX con efectos fijos por país, indicadores de año y errores agrupados por país. La estructura es idéntica a ECI salvo por la exclusión de HHI y el cambio de variable dependiente.
xtreg divx $DIVX_REGRESSORS i.year if sample_divx == 1, ///
    fe $INFERENCE_MAIN

* Eliminar de la memoria una estimación anterior con el mismo nombre para que esta sección pueda ejecutarse nuevamente durante la revisión.
capture estimates drop DIVX_TWFE_MAIN

* Guardar la estimación principal en la memoria activa de Stata.
estimates store DIVX_TWFE_MAIN

* Guardar una copia permanente que pueda recuperarse sin volver a estimar.
estimates save "$OUTPUT_DIVX/divx_twfe_main.ster", replace

* Comprobar que la estimación utilizó todos y únicamente los casos previstos.
peer2_assert_estimation_contract, ///
    sample(sample_divx) observations(`divx_expected_n') ///
    countries(`divx_expected_countries') clusters(`divx_expected_countries')

* Guardar las medidas generales antes de ejecutar pruebas adicionales.
local divx_n          = e(N)
local divx_countries  = e(N_g)
local divx_clusters   = e(N_clust)
local divx_r2_within  = e(r2_w)
local divx_r2_between = e(r2_b)
local divx_r2_overall = e(r2_o)
local divx_f          = e(F)
local divx_df_model   = e(df_m)
local divx_df_error   = e(df_r)
local divx_model_p    = e(p)
local divx_rmse       = e(rmse)
local divx_sigma_u    = e(sigma_u)
local divx_sigma_e    = e(sigma_e)
local divx_rho        = e(rho)

* Verificar que Stata utiliza G - 1 grados de libertad al agrupar por país.
assert `divx_df_error' == `divx_clusters' - 1

* Mostrar el tamaño de la estimación y su principal medida de ajuste within.
display as result ///
    "Modelo DIVX estimado con `divx_n' observaciones y `divx_countries' países."
display as result ///
    "R-cuadrado within: " %9.4f `divx_r2_within'


// 10.4. Exportar los coeficientes y la incertidumbre del modelo

* Reservar un nombre y una ubicación temporal para el reporte de coeficientes.
tempname divx_coefficients_post
tempfile divx_coefficients_report

* Definir la estructura del archivo temporal que recibirá una fila por coeficiente sustantivo.
postfile `divx_coefficients_post' ///
    int order ///
    str32 term ///
    str100 variable_label ///
    str32 channel ///
    double coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper ///
    using "`divx_coefficients_report'", replace

* Calcular el valor crítico t correspondiente a 49 conglomerados y reiniciar el contador que define el orden de presentación.
local divx_critical_t = invttail(`divx_df_error', 0.025)
local divx_term_order = 0

* Recorrer los términos en el mismo orden utilizado en las tablas finales.
foreach term of local divx_terms {
    local ++divx_term_order

    // Recuperar una etiqueta legible para cada término.
    if "`term'" == "c.rents#c.inst" {
        local term_label "Interacción entre rentas y calidad institucional"
    }
    else {
        local term_label : variable label `term'
        if `"`term_label'"' == "" {
            local term_label "`term'"
        }
    }

    // Asignar inicialmente el término al grupo general de controles.
    local channel "Controles económicos y financieros"

    // Reemplazar la categoría predeterminada cuando el término pertenece a uno de los canales sustantivos del modelo.
    if inlist("`term'", "rents", "inst", "c.rents#c.inst") {
        local channel "Institucional"
    }
    else if inlist("`term'", ///
        "ln1p_oilpc", "ln1p_gaspc", "ln1p_coalpc") {
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

    // Calcular coeficiente, error estándar, estadístico t y valor p.
    local coefficient    = _b[`term']
    local standard_error = _se[`term']
    local t_statistic    = `coefficient' / `standard_error'
    local p_value = 2 * ttail(`divx_df_error', abs(`t_statistic'))

    // Construir los límites inferior y superior del intervalo de confianza.
    local ci_lower = ///
        `coefficient' - `divx_critical_t' * `standard_error'
    local ci_upper = ///
        `coefficient' + `divx_critical_t' * `standard_error'

    // Conservar los resultados de xtreg para compararlos después con reghdfe.
    scalar divx_xtreg_b_`divx_term_order'  = `coefficient'
    scalar divx_xtreg_se_`divx_term_order' = `standard_error'

    // Añadir al archivo temporal los resultados calculados para este término.
    post `divx_coefficients_post' ///
        (`divx_term_order') ///
        ("`term'") ///
        (`"`term_label'"') ///
        (`"`channel'"') ///
        (`coefficient') ///
        (`standard_error') ///
        (`t_statistic') ///
        (`p_value') ///
        (`ci_lower') ///
        (`ci_upper')
}

* Cerrar el archivo temporal para asegurar que todas las filas queden escritas.
postclose `divx_coefficients_post'

* Abrir temporalmente el reporte sin perder la base analítica activa.
preserve

    * Cargar el reporte de coeficientes y ordenar sus filas.
    use "`divx_coefficients_report'", clear
    sort order

    * Aplicar formatos homogéneos a coeficientes, intervalos y valores p.
    format coefficient standard_error t_statistic ///
        ci_lower ci_upper %12.6f
    format p_value %10.6f

    * Exportar el reporte de coeficientes en formato CSV.
    export delimited using ///
        "$OUTPUT_DIVX/divx_twfe_coefficients.csv", replace datafmt

    * Mostrar en pantalla los resultados sustantivos para facilitar su revisión.
    list term coefficient standard_error p_value ci_lower ci_upper, ///
        noobs abbreviate(24)

* Recuperar la base analítica después de cerrar la exportación.
restore


// 10.5. Exportar el resumen general de la estimación

* Reservar un nombre y una ubicación temporal para el resumen del modelo.
tempname divx_summary_post
tempfile divx_summary_report

* Definir las columnas del resumen de cobertura, ajuste e inferencia.
postfile `divx_summary_post' ///
    str24 model ///
    str12 dependent_variable ///
    int observations countries clusters years first_year last_year ///
    double r2_within r2_between r2_overall ///
    f_statistic df_model df_error model_p_value rmse ///
    sigma_country sigma_idiosyncratic rho_country ///
    using "`divx_summary_report'", replace

* Escribir una única fila con los resultados generales del modelo DIVX.
post `divx_summary_post' ///
    ("DIVX_TWFE_MAIN") ///
    ("divx") ///
    (`divx_n') ///
    (`divx_countries') ///
    (`divx_clusters') ///
    (`divx_expected_year_count') ///
    (`divx_first_year') ///
    (`divx_last_year') ///
    (`divx_r2_within') ///
    (`divx_r2_between') ///
    (`divx_r2_overall') ///
    (`divx_f') ///
    (`divx_df_model') ///
    (`divx_df_error') ///
    (`divx_model_p') ///
    (`divx_rmse') ///
    (`divx_sigma_u') ///
    (`divx_sigma_e') ///
    (`divx_rho')

* Cerrar el archivo temporal antes de abrirlo para su exportación.
postclose `divx_summary_post'

* Abrir temporalmente el resumen sin reemplazar la base analítica en memoria.
preserve

    * Cargar la fila de resumen y aplicar formatos numéricos homogéneos.
    use "`divx_summary_report'", clear
    format r2_within r2_between r2_overall ///
        f_statistic model_p_value rmse ///
        sigma_country sigma_idiosyncratic rho_country %12.6f

    * Exportar el resumen general del modelo en formato CSV.
    export delimited using ///
        "$OUTPUT_DIVX/divx_twfe_model_summary.csv", replace datafmt

    * Mostrar el resumen exportado para facilitar la revisión interactiva.
    list, noobs abbreviate(24)

* Recuperar la base analítica después de exportar el resumen.
restore


// 10.6. Realizar las pruebas conjuntas previstas por canal

* Recuperar la estimación principal antes de ejecutar las pruebas.
estimates restore DIVX_TWFE_MAIN

* Reservar un nombre y una ubicación temporal para las pruebas conjuntas.
tempname divx_tests_post
tempfile divx_tests_report

* Definir la estructura común para registrar las ocho pruebas.
postfile `divx_tests_post' ///
    int order ///
    str40 test ///
    str100 null_hypothesis ///
    double f_statistic df1 df2 p_value ///
    using "`divx_tests_report'", replace

* Prueba 1: los términos del canal institucional son conjuntamente cero.
test rents inst c.rents#c.inst
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' ///
    (1) ///
    ("Canal institucional") ///
    ("RENTS, INST y RENTS x INST son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 2: petróleo, gas y carbón son conjuntamente cero.
test ln1p_oilpc ln1p_gaspc ln1p_coalpc
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' ///
    (2) ///
    ("Canal de abundancia") ///
    ("Petróleo, gas y carbón son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 3: PEXP y FEXP son conjuntamente cero. HHI queda expresamente fuera porque constituye la transformación inversa de la variable dependiente.
test pexp fexp
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' ///
    (3) ///
    ("Canal estructural") ///
    ("PEXP y FEXP son conjuntamente cero; HHI está excluido") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 4: volatilidad y tipo de cambio real son conjuntamente cero.
test vol rer
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' ///
    (4) ///
    ("Canal macroeconómico") ///
    ("VOL y RER son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 5: capital humano, innovación y conectividad son conjuntamente cero.
test humcap innov net
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' ///
    (5) ///
    ("Capacidades productivas") ///
    ("HUMCAP, INNOV y NET son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 6: los controles económicos y financieros son conjuntamente cero.
test log_gdppc govcons fin
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' ///
    (6) ///
    ("Controles económicos y financieros") ///
    ("log(GDPPC), GOVCONS y FIN son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 7: los indicadores de año son conjuntamente cero.
testparm i.year
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' ///
    (7) ///
    ("Efectos fijos por año") ///
    ("Todos los indicadores de año son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 8: petróleo, gas y carbón tienen el mismo coeficiente.
test (ln1p_oilpc = ln1p_gaspc) ///
     (ln1p_oilpc = ln1p_coalpc)
* Escribir una fila de resultados dentro del archivo temporal.
post `divx_tests_post' ///
    (8) ///
    ("Igualdad entre recursos") ///
    ("Los coeficientes de petróleo, gas y carbón son iguales") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Cerrar el archivo temporal que reúne las pruebas de hipótesis.
postclose `divx_tests_post'

* Abrir temporalmente el reporte de pruebas y conservar la base analítica.
preserve

    * Cargar, ordenar y formatear las ocho pruebas conjuntas.
    use "`divx_tests_report'", clear
    sort order
    format f_statistic p_value %12.6f

    * Exportar todas las pruebas conjuntas en un único archivo CSV.
    export delimited using ///
        "$OUTPUT_DIVX/divx_twfe_joint_tests.csv", replace datafmt

    * Mostrar las pruebas exportadas para facilitar su revisión.
    list, noobs abbreviate(28)

* Recuperar la base analítica después de la exportación.
restore


// 10.7. Verificar los coeficientes mediante reghdfe

* Reestimar exactamente la misma ecuación absorbiendo los efectos fijos por país y año. Esta es una comprobación numérica, no un modelo alternativo.
reghdfe divx $DIVX_REGRESSORS if sample_divx == 1, ///
    absorb(country_id year) $INFERENCE_MAIN

* Eliminar de la memoria una comprobación anterior con el mismo nombre.
capture estimates drop DIVX_REGHDFE_CHECK

* Guardar la estimación de comprobación en la memoria activa.
estimates store DIVX_REGHDFE_CHECK

* Guardar una copia permanente de la comprobación con efectos absorbidos.
estimates save "$OUTPUT_DIVX/divx_reghdfe_check.ster", replace

* Confirmar que reghdfe conservó la muestra completa del modelo DIVX.
assert e(N) == `divx_n'

* Guardar el tamaño, los singletons y la tolerancia de comparación.
local divx_hdfe_n          = e(N)
local divx_hdfe_singletons = e(num_singletons)
local divx_coefficient_tolerance = 1e-8
local divx_max_coefficient_difference = 0

* Reservar un nombre y una ubicación temporal para verificar la equivalencia.
tempname divx_verification_post
tempfile divx_verification_report

* Definir las columnas del reporte de equivalencia término por término.
postfile `divx_verification_post' ///
    int order ///
    str32 term ///
    double xtreg_coefficient reghdfe_coefficient ///
    absolute_coefficient_difference ///
    xtreg_standard_error reghdfe_standard_error ///
    absolute_se_difference ///
    byte coefficient_match ///
    using "`divx_verification_report'", replace

* Reiniciar el contador para conservar el orden del reporte de coeficientes.
local divx_term_order = 0

* Recorrer los términos sustantivos y comparar las dos implementaciones.
foreach term of local divx_terms {
    local ++divx_term_order

    // Recuperar los coeficientes de xtreg y reghdfe.
    local xtreg_coefficient = ///
        scalar(divx_xtreg_b_`divx_term_order')
    local reghdfe_coefficient = _b[`term']

    // Calcular la diferencia absoluta entre los dos coeficientes.
    local coefficient_difference = abs( ///
        `xtreg_coefficient' - `reghdfe_coefficient')

    // Recuperar los errores estándar agrupados producidos por ambos comandos.
    local xtreg_standard_error = ///
        scalar(divx_xtreg_se_`divx_term_order')
    local reghdfe_standard_error = _se[`term']

    // Calcular la diferencia absoluta entre los dos errores estándar.
    local se_difference = abs( ///
        `xtreg_standard_error' - `reghdfe_standard_error')

    // Crear una bandera que indique si el coeficiente cumple la tolerancia.
    local coefficient_match = ///
        `coefficient_difference' < `divx_coefficient_tolerance'

    // Conservar la mayor diferencia observada para la validación final.
    if `coefficient_difference' > `divx_max_coefficient_difference' {
        local divx_max_coefficient_difference = `coefficient_difference'
    }

    // Escribir en el reporte las dos estimaciones y sus diferencias absolutas.
    post `divx_verification_post' ///
        (`divx_term_order') ///
        ("`term'") ///
        (`xtreg_coefficient') ///
        (`reghdfe_coefficient') ///
        (`coefficient_difference') ///
        (`xtreg_standard_error') ///
        (`reghdfe_standard_error') ///
        (`se_difference') ///
        (`coefficient_match')
}

* Cerrar el archivo temporal de verificación antes de utilizarlo.
postclose `divx_verification_post'

* Detener el archivo si algún coeficiente no coincide dentro de la tolerancia.
assert `divx_max_coefficient_difference' < ///
    `divx_coefficient_tolerance'

* Abrir temporalmente el reporte de verificación y conservar la base analítica.
preserve

    * Cargar, ordenar y formatear las diferencias término por término.
    use "`divx_verification_report'", clear
    sort order
    format xtreg_coefficient reghdfe_coefficient ///
        absolute_coefficient_difference ///
        xtreg_standard_error reghdfe_standard_error ///
        absolute_se_difference %16.10f

    * Exportar el detalle de equivalencia entre xtreg y reghdfe.
    export delimited using ///
        "$OUTPUT_DIVX/divx_xtreg_reghdfe_verification.csv", ///
        replace datafmt

    * Mostrar las diferencias para que puedan revisarse en la consola.
    list term absolute_coefficient_difference ///
        absolute_se_difference coefficient_match, ///
        noobs abbreviate(28)

* Recuperar la base analítica después de exportar la verificación.
restore

* Mostrar la diferencia máxima y el número de singletons descartados.
display as result ///
    "Máxima diferencia de coeficientes entre xtreg y reghdfe: " ///
    %16.10f `divx_max_coefficient_difference'
display as result ///
    "Observaciones singleton eliminadas por reghdfe: `divx_hdfe_singletons'"


// 10.8. Crear una tabla LaTeX provisional para revisión

* Recuperar el modelo xtreg porque constituye la estimación complementaria que se comparará con ECI en el Control E.
estimates restore DIVX_TWFE_MAIN

* Exportar una tabla provisional. La sección 8 integrará posteriormente los dos modelos dentro de una presentación común.
esttab DIVX_TWFE_MAIN using "$OUTPUT_DIVX/divx_twfe_main.tex", ///
    replace ///
    label ///
    booktabs ///
    b(4) se(4) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    keep(`divx_terms') ///
    order(`divx_terms') ///
    coeflabels(c.rents#c.inst "RENTS x INST") ///
    stats(N N_g r2_w r2_b r2_o, ///
        fmt(0 0 4 4 4) ///
        labels("Observaciones" "Países" ///
            "R2 within" "R2 between" "R2 overall")) ///
    title("Modelo complementario DIVX con efectos fijos por país y año") ///
    addnotes( ///
        "Efectos fijos por país: sí." ///
        "Efectos fijos por año: sí." ///
        "Errores estándar agrupados por país." ///
        "HHI se excluye porque DIVX = 1 - HHI." ///
        "Los indicadores de año no se muestran.")

* Informar que la sección terminó y cuál estimación queda activa en memoria.
display as result ///
    "Sección 6 completada: modelo complementario DIVX estimado."
display as result ///
    "La estimación activa es DIVX_TWFE_MAIN y HHI fue excluido."


// *****************************************************************************
// 11. Estabilidad y Efectos Marginales del Modelo Completo
// *****************************************************************************


// 11.1. Recuperar la base analítica y definir valores observados de INST

* Abrir nuevamente la base derivada para que todas las sensibilidades partan de la misma información utilizada por los modelos principales.
use "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta", clear

* Confirmar que la llave país-año continúa identificando cada observación.
isid country_iso3_code year

* Verificar las variables que se utilizarán para efectos marginales, exclusiones y reestimaciones de estabilidad.
confirm variable ///
    eci divx sample_eci sample_divx ///
    country_iso3_code country_id year ///
    rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin

* Confirmar que ECI y DIVX utilizan exactamente las mismas observaciones. Esta igualdad permite comparar las sensibilidades sin cambios de composición.
assert sample_eci == sample_divx

* Declarar nuevamente las dimensiones del panel antes de reestimar modelos.
xtset country_id year

* Calcular percentiles de INST dentro de la muestra común. Se emplean P10, P25, P50, P75 y P90 para evitar que casos extremos determinen toda la figura.
quietly summarize inst if sample_eci == 1, detail
local inst_p10 = r(p10)
local inst_p25 = r(p25)
local inst_p50 = r(p50)
local inst_p75 = r(p75)
local inst_p90 = r(p90)
local inst_min = r(min)
local inst_max = r(max)

* Reunir los cinco valores y sus nombres en macros que se reutilizarán para ambos modelos y para la exportación del reporte.
local inst_values ///
    "`inst_p10' `inst_p25' `inst_p50' `inst_p75' `inst_p90'"
local inst_labels "P10 P25 P50 P75 P90"

* Mostrar el rango completo y los puntos seleccionados para que el usuario pueda verificar qué niveles institucionales alimentan los márgenes.
display as text ///
    "Rango observado de INST: " %9.4f `inst_min' " a " %9.4f `inst_max'
display as text ///
    "Valores de referencia: `inst_values'"

* Recuperar los coeficientes centrales ECI almacenados. La marca e(sample) ya no es válida después de use, pero los coeficientes y la matriz de varianzas sí.
estimates restore ECI_TWFE_MAIN
local eci_base_rents_b = _b[rents]
local eci_base_rents_se = _se[rents]
local eci_base_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local eci_base_interaction_b = _b[c.rents#c.inst]
local eci_base_interaction_se = _se[c.rents#c.inst]
local eci_base_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))

* Recuperar de la misma forma las referencias centrales del modelo DIVX.
estimates restore DIVX_TWFE_MAIN
local divx_base_rents_b = _b[rents]
local divx_base_rents_se = _se[rents]
local divx_base_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local divx_base_interaction_b = _b[c.rents#c.inst]
local divx_base_interaction_se = _se[c.rents#c.inst]
local divx_base_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))


// 11.2. Calcular los efectos marginales de RENTS según INST

* Crear un archivo temporal común para guardar efectos, errores estándar, valores p e intervalos de confianza de ECI y DIVX.
tempname margins_post
tempfile margins_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `margins_post' ///
    str8 model ///
    str4 institutional_percentile ///
    double inst_value marginal_effect standard_error ///
    t_statistic p_value ci_lower ci_upper ///
    str12 significance ///
    using "`margins_report'", replace

* Reestimar silenciosamente el modelo ECI aprobado. La recarga de la base invalida la marca interna e(sample) de una estimación restaurada y margins necesita reconstruirla sobre los mismos 1.044 casos.
quietly xtreg eci $ECI_REGRESSORS i.year if sample_eci == 1, ///
    fe $INFERENCE_MAIN

* Confirmar que la reestimación utilizada por margins reproduce el coeficiente RENTS del modelo principal y conserva su muestra completa.
assert abs(_b[rents] - `eci_base_rents_b') < 1e-10
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == `eci_expected_n'
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == `eci_expected_countries'

* Calcular d(ECI)/d(RENTS) en los cinco percentiles institucionales. Con una interacción lineal, cada margen combina el coeficiente de RENTS con el de RENTS x INST y conserva su incertidumbre conjunta.
margins, dydx(rents) at(inst=(`inst_values'))

* Conservar la tabla completa devuelta por margins antes de construir la figura o ejecutar cualquier otro comando.
matrix eci_margins_table = r(table)

* Graficar la asociación marginal estimada y su intervalo de confianza del 95 %. La línea horizontal en cero permite identificar dónde cambia el signo.
marginsplot, ///
    recast(line) ///
    recastci(rarea) ///
    plotopts(lcolor(navy) lwidth(medthick)) ///
    ciopts(color(navy%25) lcolor(navy%45) lwidth(vthin)) ///
    yline(0, lcolor(gs8) lpattern(dash)) ///
    xlabel( ///
        `inst_p10' "P10" ///
        `inst_p25' "P25" ///
        `inst_p50' "P50" ///
        `inst_p75' "P75" ///
        `inst_p90' "P90", ///
        labsize(small)) ///
    ylabel(, labsize(small) angle(horizontal)) ///
    title( ///
        "ECI: asociación marginal de RENTS según INST", ///
        size(medsmall)) ///
    subtitle( ///
        "TWFE; intervalos de confianza del 95 %", ///
        size(small)) ///
    ytitle("d(ECI) / d(RENTS)", size(small)) ///
    xtitle("Percentil de calidad institucional (INST)", size(small)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    xsize(8) ///
    ysize(5) ///
    name(eci_rents_margins, replace)

* Exportar la figura ECI en PDF para LaTeX y en PNG para revisión rápida.
graph export ///
    "$OUTPUT_STABILITY/eci_rents_marginal_effect_by_inst.pdf", ///
    replace
graph export ///
    "$OUTPUT_STABILITY/eci_rents_marginal_effect_by_inst.png", ///
    width(2400) replace

* Recorrer las cinco columnas de la tabla de margins y registrar cada resultado con el percentil institucional correspondiente.
forvalues column = 1/5 {
    local percentile : word `column' of `inst_labels'
    local inst_value : word `column' of `inst_values'
    local effect = el(eci_margins_table, 1, `column')
    local se     = el(eci_margins_table, 2, `column')
    local tstat  = el(eci_margins_table, 3, `column')
    local pvalue = el(eci_margins_table, 4, `column')
    local lower  = el(eci_margins_table, 5, `column')
    local upper  = el(eci_margins_table, 6, `column')

    // Clasificar la precisión estadística sin convertirla en una conclusión causal ni alterar el umbral principal del estudio.
    local significance "No"
    if `pvalue' < 0.10 local significance "10%"
    if `pvalue' < 0.05 local significance "5%"
    if `pvalue' < 0.01 local significance "1%"

    // Guardar el efecto marginal ECI y todas las cantidades necesarias para reproducir su interpretación.
    post `margins_post' ///
        ("ECI") ///
        ("`percentile'") ///
        (`inst_value') ///
        (`effect') (`se') (`tstat') (`pvalue') ///
        (`lower') (`upper') ///
        ("`significance'")
}

* Reestimar silenciosamente DIVX para reconstruir e(sample) después de cargar nuevamente la base analítica.
quietly xtreg divx $DIVX_REGRESSORS i.year if sample_divx == 1, ///
    fe $INFERENCE_MAIN

* Confirmar que la reestimación reproduce el coeficiente RENTS y la muestra del modelo complementario.
assert abs(_b[rents] - `divx_base_rents_b') < 1e-10
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == `divx_expected_n'
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == `divx_expected_countries'

* Calcular d(DIVX)/d(RENTS) en los mismos percentiles de INST utilizados para ECI, manteniendo así una comparación sobre puntos idénticos.
margins, dydx(rents) at(inst=(`inst_values'))

* Guardar la tabla completa del modelo DIVX antes de construir la figura.
matrix divx_margins_table = r(table)

* Graficar los efectos marginales DIVX con intervalo de confianza del 95 % y una referencia explícita en cero.
marginsplot, ///
    recast(line) ///
    recastci(rarea) ///
    plotopts(lcolor(maroon) lwidth(medthick)) ///
    ciopts(color(maroon%25) lcolor(maroon%45) lwidth(vthin)) ///
    yline(0, lcolor(gs8) lpattern(dash)) ///
    xlabel( ///
        `inst_p10' "P10" ///
        `inst_p25' "P25" ///
        `inst_p50' "P50" ///
        `inst_p75' "P75" ///
        `inst_p90' "P90", ///
        labsize(small)) ///
    ylabel(, labsize(small) angle(horizontal)) ///
    title( ///
        "DIVX: asociación marginal de RENTS según INST", ///
        size(medsmall)) ///
    subtitle( ///
        "TWFE; intervalos de confianza del 95 %", ///
        size(small)) ///
    ytitle("d(DIVX) / d(RENTS)", size(small)) ///
    xtitle("Percentil de calidad institucional (INST)", size(small)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    xsize(8) ///
    ysize(5) ///
    name(divx_rents_margins, replace)

* Exportar la figura DIVX en PDF para LaTeX y en PNG para revisión rápida.
graph export ///
    "$OUTPUT_STABILITY/divx_rents_marginal_effect_by_inst.pdf", ///
    replace
graph export ///
    "$OUTPUT_STABILITY/divx_rents_marginal_effect_by_inst.png", ///
    width(2400) replace

* Registrar los cinco resultados marginales de DIVX dentro del mismo reporte utilizado para ECI.
forvalues column = 1/5 {
    local percentile : word `column' of `inst_labels'
    local inst_value : word `column' of `inst_values'
    local effect = el(divx_margins_table, 1, `column')
    local se     = el(divx_margins_table, 2, `column')
    local tstat  = el(divx_margins_table, 3, `column')
    local pvalue = el(divx_margins_table, 4, `column')
    local lower  = el(divx_margins_table, 5, `column')
    local upper  = el(divx_margins_table, 6, `column')

    // Aplicar la misma clasificación descriptiva de significancia empleada para ECI.
    local significance "No"
    if `pvalue' < 0.10 local significance "10%"
    if `pvalue' < 0.05 local significance "5%"
    if `pvalue' < 0.01 local significance "1%"

    // Guardar el efecto marginal DIVX y su incertidumbre.
    post `margins_post' ///
        ("DIVX") ///
        ("`percentile'") ///
        (`inst_value') ///
        (`effect') (`se') (`tstat') (`pvalue') ///
        (`lower') (`upper') ///
        ("`significance'")
}

* Cerrar el archivo temporal después de registrar los diez efectos marginales.
postclose `margins_post'

* Abrir temporalmente el reporte, ordenar sus filas y exportarlo como CSV.
preserve
    use "`margins_report'", clear
    sort model inst_value
    format inst_value marginal_effect standard_error ///
        t_statistic p_value ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/rents_marginal_effects_by_inst.csv", ///
        replace datafmt
    list, noobs sepby(model) abbreviate(24)
restore


// 11.3. Resumir la prueba de igualdad entre petróleo, gas y carbón

* Crear un reporte compacto que reúna las pruebas ya previstas en los dos modelos y evite interpretar coeficientes individuales de forma aislada.
tempname resource_test_post
tempfile resource_test_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `resource_test_post' ///
    str8 model ///
    str90 null_hypothesis ///
    double f_statistic df1 df2 p_value ///
    str16 decision ///
    using "`resource_test_report'", replace

* Recuperar ECI y contrastar que los tres coeficientes transformados sean iguales entre sí.
estimates restore ECI_TWFE_MAIN
test (ln1p_oilpc = ln1p_gaspc) ///
     (ln1p_oilpc = ln1p_coalpc)
local eci_resource_decision "No rechazar H0"
if r(p) < 0.05 local eci_resource_decision "Rechazar H0"
* Escribir una fila de resultados dentro del archivo temporal.
post `resource_test_post' ///
    ("ECI") ///
    ("Los coeficientes de petróleo, gas y carbón son iguales") ///
    (r(F)) (r(df)) (r(df_r)) (r(p)) ///
    ("`eci_resource_decision'")

* Recuperar DIVX y aplicar exactamente la misma hipótesis de igualdad.
estimates restore DIVX_TWFE_MAIN
test (ln1p_oilpc = ln1p_gaspc) ///
     (ln1p_oilpc = ln1p_coalpc)
local divx_resource_decision "No rechazar H0"
if r(p) < 0.05 local divx_resource_decision "Rechazar H0"
* Escribir una fila de resultados dentro del archivo temporal.
post `resource_test_post' ///
    ("DIVX") ///
    ("Los coeficientes de petróleo, gas y carbón son iguales") ///
    (r(F)) (r(df)) (r(df_r)) (r(p)) ///
    ("`divx_resource_decision'")

* Cerrar el archivo temporal después de guardar las dos pruebas.
postclose `resource_test_post'

* Exportar la síntesis de igualdad entre recursos para su revisión conjunta.
preserve
    use "`resource_test_report'", clear
    format f_statistic p_value %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/resource_coefficient_equality.csv", ///
        replace datafmt
    list, noobs abbreviate(28)
restore


// 11.4. Evaluar la forma funcional de las rentas per cápita

* Comparar la especificación principal ln(1+x) con una alternativa que utiliza OILPC, GASPC y COALPC en niveles. RENTS permanece agregado y sin cambios. Esta prueba evalúa una decisión de transformación, no una desagregación entre hidrocarburos y minería ni una nueva ecuación principal.
tempname pc_transform_post
tempfile pc_transform_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `pc_transform_post' ///
    str8 model ///
    str24 specification ///
    double observations countries ///
    rents_coefficient rents_standard_error rents_p_value ///
    interaction_coefficient interaction_standard_error interaction_p_value ///
    str20 oil_term double oil_coefficient oil_p_value ///
    str20 gas_term double gas_coefficient gas_p_value ///
    str20 coal_term double coal_coefficient coal_p_value ///
    using "`pc_transform_report'", replace

* Recuperar el modelo ECI principal y registrar sus coeficientes bajo la transformación ln(1+x), que admite ceros y reduce la asimetría de las series.
estimates restore ECI_TWFE_MAIN
local eci_main_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local eci_main_interaction_p = ///
    2 * ttail(e(df_r), abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))
local eci_main_oil_p = ///
    2 * ttail(e(df_r), abs(_b[ln1p_oilpc] / _se[ln1p_oilpc]))
local eci_main_gas_p = ///
    2 * ttail(e(df_r), abs(_b[ln1p_gaspc] / _se[ln1p_gaspc]))
local eci_main_coal_p = ///
    2 * ttail(e(df_r), abs(_b[ln1p_coalpc] / _se[ln1p_coalpc]))
* Escribir una fila de resultados dentro del archivo temporal.
post `pc_transform_post' ///
    ("ECI") ("ln(1+x), principal") ///
    (e(N)) (e(N_g)) ///
    (_b[rents]) (_se[rents]) (`eci_main_rents_p') ///
    (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) ///
    (`eci_main_interaction_p') ///
    ("ln1p_oilpc") (_b[ln1p_oilpc]) (`eci_main_oil_p') ///
    ("ln1p_gaspc") (_b[ln1p_gaspc]) (`eci_main_gas_p') ///
    ("ln1p_coalpc") (_b[ln1p_coalpc]) (`eci_main_coal_p')

* Reestimar ECI sustituyendo únicamente los tres controles transformados por sus valores per cápita sin transformar; el resto de la ecuación no cambia.
quietly xtreg eci ///
    c.rents##c.inst ///
    oilpc gaspc coalpc ///
    hhi pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin ///
    i.year if sample_eci == 1, ///
    fe $INFERENCE_MAIN

* Comprobar que la alternativa ECI conserva exactamente la muestra aprobada.
assert e(sample) == sample_eci
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == `eci_expected_n'
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == `eci_expected_countries'

* Guardar la alternativa ECI para poder incluirla en la tabla comparativa final.
capture estimates drop ECI_PC_LEVELS_SENSITIVITY
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_PC_LEVELS_SENSITIVITY
estimates save ///
    "$OUTPUT_STABILITY/eci_per_capita_levels_sensitivity.ster", ///
    replace

* Calcular y registrar la incertidumbre de los términos relevantes en la especificación ECI con controles per cápita sin transformar.
local eci_levels_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local eci_levels_interaction_p = ///
    2 * ttail(e(df_r), abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))
local eci_levels_oil_p = ///
    2 * ttail(e(df_r), abs(_b[oilpc] / _se[oilpc]))
local eci_levels_gas_p = ///
    2 * ttail(e(df_r), abs(_b[gaspc] / _se[gaspc]))
local eci_levels_coal_p = ///
    2 * ttail(e(df_r), abs(_b[coalpc] / _se[coalpc]))
* Escribir una fila de resultados dentro del archivo temporal.
post `pc_transform_post' ///
    ("ECI") ("Niveles per capita") ///
    (e(N)) (e(N_g)) ///
    (_b[rents]) (_se[rents]) (`eci_levels_rents_p') ///
    (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) ///
    (`eci_levels_interaction_p') ///
    ("oilpc") (_b[oilpc]) (`eci_levels_oil_p') ///
    ("gaspc") (_b[gaspc]) (`eci_levels_gas_p') ///
    ("coalpc") (_b[coalpc]) (`eci_levels_coal_p')

* Recuperar el modelo DIVX principal y registrar la especificación aprobada con los tres componentes per cápita transformados mediante ln(1+x).
estimates restore DIVX_TWFE_MAIN
local divx_main_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local divx_main_interaction_p = ///
    2 * ttail(e(df_r), abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))
local divx_main_oil_p = ///
    2 * ttail(e(df_r), abs(_b[ln1p_oilpc] / _se[ln1p_oilpc]))
local divx_main_gas_p = ///
    2 * ttail(e(df_r), abs(_b[ln1p_gaspc] / _se[ln1p_gaspc]))
local divx_main_coal_p = ///
    2 * ttail(e(df_r), abs(_b[ln1p_coalpc] / _se[ln1p_coalpc]))
* Escribir una fila de resultados dentro del archivo temporal.
post `pc_transform_post' ///
    ("DIVX") ("ln(1+x), principal") ///
    (e(N)) (e(N_g)) ///
    (_b[rents]) (_se[rents]) (`divx_main_rents_p') ///
    (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) ///
    (`divx_main_interaction_p') ///
    ("ln1p_oilpc") (_b[ln1p_oilpc]) (`divx_main_oil_p') ///
    ("ln1p_gaspc") (_b[ln1p_gaspc]) (`divx_main_gas_p') ///
    ("ln1p_coalpc") (_b[ln1p_coalpc]) (`divx_main_coal_p')

* Reestimar DIVX con los controles OILPC, GASPC y COALPC en niveles, manteniendo la exclusión de HHI y todos los demás elementos de la ecuación aprobada.
quietly xtreg divx ///
    c.rents##c.inst ///
    oilpc gaspc coalpc ///
    pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin ///
    i.year if sample_divx == 1, ///
    fe $INFERENCE_MAIN

* Comprobar que la alternativa DIVX conserva la misma muestra país-año.
assert e(sample) == sample_divx
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == `divx_expected_n'
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == `divx_expected_countries'

* Guardar la alternativa DIVX para su revisión y exportación reproducible.
capture estimates drop DIVX_PC_LEVELS_SENSITIVITY
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_PC_LEVELS_SENSITIVITY
estimates save ///
    "$OUTPUT_STABILITY/divx_per_capita_levels_sensitivity.ster", ///
    replace

* Calcular y registrar la incertidumbre de los términos relevantes en la especificación DIVX con controles per cápita sin transformar.
local divx_levels_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local divx_levels_interaction_p = ///
    2 * ttail(e(df_r), abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))
local divx_levels_oil_p = ///
    2 * ttail(e(df_r), abs(_b[oilpc] / _se[oilpc]))
local divx_levels_gas_p = ///
    2 * ttail(e(df_r), abs(_b[gaspc] / _se[gaspc]))
local divx_levels_coal_p = ///
    2 * ttail(e(df_r), abs(_b[coalpc] / _se[coalpc]))
* Escribir una fila de resultados dentro del archivo temporal.
post `pc_transform_post' ///
    ("DIVX") ("Niveles per capita") ///
    (e(N)) (e(N_g)) ///
    (_b[rents]) (_se[rents]) (`divx_levels_rents_p') ///
    (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) ///
    (`divx_levels_interaction_p') ///
    ("oilpc") (_b[oilpc]) (`divx_levels_oil_p') ///
    ("gaspc") (_b[gaspc]) (`divx_levels_gas_p') ///
    ("coalpc") (_b[coalpc]) (`divx_levels_coal_p')

* Cerrar el archivo temporal una vez registradas las cuatro especificaciones.
postclose `pc_transform_post'

* Exportar la comparación numérica en formato abierto y con una fila por modelo-especificación para facilitar la revisión entre pares.
preserve
    use "`pc_transform_report'", clear
    sort model specification
    format *_coefficient *_standard_error *_p_value %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/per_capita_transformation_sensitivity.csv", ///
        replace datafmt
    list, noobs sepby(model) abbreviate(24)
restore

* Restablecer los modelos principales antes de continuar con las demás pruebas.
estimates restore ECI_TWFE_MAIN
* Restaurar una estimación previa desde la memoria de Stata.
estimates restore DIVX_TWFE_MAIN


// 11.5. Evaluar sensibilidad a las observaciones previamente señaladas

* Confirmar que la sección 4 dejó disponible el inventario de alertas. Estas filas son casos para revisión y no observaciones declaradas erróneas.
capture confirm file ///
    "$OUTPUT_DIAGNOSTICS/influential_observations.csv"
if _rc {
    display as error ///
        "No se encontró influential_observations.csv; ejecute el archivo 01."
    exit 601
}

* Transformar el inventario largo de alertas en dos indicadores país-año, uno para ECI y otro para DIVX.
tempfile influence_flags
preserve
    import delimited using ///
        "$OUTPUT_DIAGNOSTICS/influential_observations.csv", ///
        clear varnames(1)

    * Validar la estructura del inventario y recuperar sus conteos declarados.
    confirm variable country_iso3_code year model ///
        flagged_observations_model
    assert inlist(model, "ECI", "DIVX")
    isid country_iso3_code year model

    quietly summarize flagged_observations_model ///
        if model == "ECI", meanonly
    assert r(min) == r(max)
    local declared_eci_influential_n = r(max)
    quietly count if model == "ECI"
    assert r(N) == `declared_eci_influential_n'

    quietly summarize flagged_observations_model ///
        if model == "DIVX", meanonly
    assert r(min) == r(max)
    local declared_divx_influential_n = r(max)
    quietly count if model == "DIVX"
    assert r(N) == `declared_divx_influential_n'

    keep country_iso3_code year model
    duplicates drop
    generate byte influential = 1
    reshape wide influential, ///
        i(country_iso3_code year) j(model) string

    * Crear el indicador ECI si ninguna alerta hubiera sido registrada.
    capture confirm variable influentialECI
    if _rc generate byte influentialECI = 0

    * Crear el indicador DIVX si ninguna alerta hubiera sido registrada.
    capture confirm variable influentialDIVX
    if _rc generate byte influentialDIVX = 0

    * Reemplazar ausencias producidas por reshape con ceros explícitos.
    replace influentialECI  = 0 if missing(influentialECI)
    replace influentialDIVX = 0 if missing(influentialDIVX)

    * Asignar nombres claros antes de combinar los indicadores con el panel.
    rename influentialECI  influential_eci
    rename influentialDIVX influential_divx
    save "`influence_flags'", replace
restore

* Incorporar los dos indicadores sin eliminar observaciones del panel.
merge 1:1 country_iso3_code year using "`influence_flags'", ///
    keep(master match) nogen

* Completar con cero los país-año que nunca fueron señalados por los diagnósticos.
replace influential_eci  = 0 if missing(influential_eci)
replace influential_divx = 0 if missing(influential_divx)

* Verificar que la combinación reproduce el conteo ECI declarado por el
* diagnóstico vigente, sin depender de una cifra escrita manualmente.
quietly count if sample_eci == 1 & influential_eci == 1
local eci_influential_n = r(N)
assert `eci_influential_n' == `declared_eci_influential_n'

* Verificar de la misma forma el conteo dinámico del modelo DIVX.
quietly count if sample_divx == 1 & influential_divx == 1
local divx_influential_n = r(N)
assert `divx_influential_n' == `declared_divx_influential_n'

* Preparar un reporte que compare cada estimación base con la sensibilidad que excluye conjuntamente todas las observaciones señaladas.
tempname influential_post
tempfile influential_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `influential_post' ///
    str8 model ///
    str28 specification ///
    double observations countries ///
    rents_coefficient rents_standard_error rents_p_value ///
    interaction_coefficient interaction_standard_error interaction_p_value ///
    using "`influential_report'", replace

* Recuperar los coeficientes ECI originales y registrar la referencia base.
estimates restore ECI_TWFE_MAIN
local eci_base_rents_b = _b[rents]
local eci_base_rents_se = _se[rents]
local eci_base_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local eci_base_interaction_b = _b[c.rents#c.inst]
local eci_base_interaction_se = _se[c.rents#c.inst]
local eci_base_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))
* Escribir una fila de resultados dentro del archivo temporal.
post `influential_post' ///
    ("ECI") ("Modelo base") ///
    (e(N)) (e(N_g)) ///
    (`eci_base_rents_b') (`eci_base_rents_se') (`eci_base_rents_p') ///
    (`eci_base_interaction_b') ///
    (`eci_base_interaction_se') (`eci_base_interaction_p')

* Reestimar ECI sin las observaciones señaladas por el inventario vigente. Esta especificación se conserva únicamente como sensibilidad y no reemplaza ECI_TWFE_MAIN.
quietly xtreg eci $ECI_REGRESSORS i.year ///
    if sample_eci == 1 & influential_eci == 0, ///
    fe $INFERENCE_MAIN
capture estimates drop ECI_EXCL_INFLUENTIAL
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store ECI_EXCL_INFLUENTIAL
local eci_excl_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local eci_excl_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))
* Escribir una fila de resultados dentro del archivo temporal.
post `influential_post' ///
    ("ECI") ("Excluye alertas") ///
    (e(N)) (e(N_g)) ///
    (_b[rents]) (_se[rents]) (`eci_excl_rents_p') ///
    (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) ///
    (`eci_excl_interaction_p')

* Recuperar los coeficientes DIVX originales y registrar la referencia base.
estimates restore DIVX_TWFE_MAIN
local divx_base_rents_b = _b[rents]
local divx_base_rents_se = _se[rents]
local divx_base_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local divx_base_interaction_b = _b[c.rents#c.inst]
local divx_base_interaction_se = _se[c.rents#c.inst]
local divx_base_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))
* Escribir una fila de resultados dentro del archivo temporal.
post `influential_post' ///
    ("DIVX") ("Modelo base") ///
    (e(N)) (e(N_g)) ///
    (`divx_base_rents_b') (`divx_base_rents_se') (`divx_base_rents_p') ///
    (`divx_base_interaction_b') ///
    (`divx_base_interaction_se') (`divx_base_interaction_p')

* Reestimar DIVX sin las observaciones señaladas por el inventario vigente. Esta sensibilidad tampoco modifica la estimación complementaria principal.
quietly xtreg divx $DIVX_REGRESSORS i.year ///
    if sample_divx == 1 & influential_divx == 0, ///
    fe $INFERENCE_MAIN
capture estimates drop DIVX_EXCL_INFLUENTIAL
* Guardar el modelo estimado en memoria para comparaciones posteriores.
estimates store DIVX_EXCL_INFLUENTIAL
local divx_excl_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local divx_excl_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))
* Escribir una fila de resultados dentro del archivo temporal.
post `influential_post' ///
    ("DIVX") ("Excluye alertas") ///
    (e(N)) (e(N_g)) ///
    (_b[rents]) (_se[rents]) (`divx_excl_rents_p') ///
    (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) ///
    (`divx_excl_interaction_p')

* Cerrar el archivo que contiene las cuatro especificaciones comparadas.
postclose `influential_post'

* Exportar los coeficientes centrales con y sin observaciones señaladas.
preserve
    use "`influential_report'", clear
    sort model specification
    format rents_coefficient rents_standard_error rents_p_value ///
        interaction_coefficient interaction_standard_error ///
        interaction_p_value %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/influential_observation_sensitivity.csv", ///
        replace datafmt
    list, noobs sepby(model) abbreviate(26)
restore


// 11.6. Comprobar dependencia respecto de un solo país

* Recuperar la lista común de países incluidos en los dos modelos.
quietly levelsof country_id if sample_eci == 1, ///
    local(leave_one_out_country_ids)

* Crear un archivo donde cada fila registre una reestimación que excluye un país y un término central.
tempname leave_one_out_post
tempfile leave_one_out_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `leave_one_out_post' ///
    str8 model ///
    double excluded_country_id ///
    str3 excluded_country_iso3 ///
    str24 term ///
    double base_coefficient coefficient standard_error p_value ///
    observations countries ///
    using "`leave_one_out_report'", replace

* Excluir sucesivamente cada país del modelo ECI y registrar RENTS y la interacción institucional.
foreach excluded_id of local leave_one_out_country_ids {

    // Recuperar el código ISO3 del país omitido para que el reporte sea legible.
    quietly levelsof country_iso3_code ///
        if sample_eci == 1 & country_id == `excluded_id', ///
        local(excluded_iso3) clean

    // Reestimar ECI manteniendo todos los demás países, años y regresores.
    quietly xtreg eci $ECI_REGRESSORS i.year ///
        if sample_eci == 1 & country_id != `excluded_id', ///
        fe $INFERENCE_MAIN

    // Calcular el valor p convencional del coeficiente RENTS.
    local loo_rents_p = ///
        2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))

    // Guardar el resultado RENTS de esta exclusión.
    post `leave_one_out_post' ///
        ("ECI") (`excluded_id') ("`excluded_iso3'") ///
        ("RENTS") ///
        (`eci_base_rents_b') ///
        (_b[rents]) (_se[rents]) (`loo_rents_p') ///
        (e(N)) (e(N_g))

    // Calcular el valor p de la interacción RENTS x INST.
    local loo_interaction_p = ///
        2 * ttail(e(df_r), ///
            abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))

    // Guardar el resultado de la interacción para la misma exclusión.
    post `leave_one_out_post' ///
        ("ECI") (`excluded_id') ("`excluded_iso3'") ///
        ("RENTS x INST") ///
        (`eci_base_interaction_b') ///
        (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) ///
        (`loo_interaction_p') ///
        (e(N)) (e(N_g))
}

* Excluir sucesivamente cada país del modelo DIVX y registrar los mismos dos términos para una comparación simétrica.
foreach excluded_id of local leave_one_out_country_ids {

    // Recuperar el código ISO3 del país omitido.
    quietly levelsof country_iso3_code ///
        if sample_divx == 1 & country_id == `excluded_id', ///
        local(excluded_iso3) clean

    // Reestimar DIVX manteniendo la especificación complementaria completa.
    quietly xtreg divx $DIVX_REGRESSORS i.year ///
        if sample_divx == 1 & country_id != `excluded_id', ///
        fe $INFERENCE_MAIN

    // Calcular el valor p de RENTS en esta reestimación.
    local loo_rents_p = ///
        2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))

    // Guardar el resultado RENTS del modelo DIVX.
    post `leave_one_out_post' ///
        ("DIVX") (`excluded_id') ("`excluded_iso3'") ///
        ("RENTS") ///
        (`divx_base_rents_b') ///
        (_b[rents]) (_se[rents]) (`loo_rents_p') ///
        (e(N)) (e(N_g))

    // Calcular el valor p de la interacción en esta reestimación.
    local loo_interaction_p = ///
        2 * ttail(e(df_r), ///
            abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))

    // Guardar el resultado de la interacción DIVX.
    post `leave_one_out_post' ///
        ("DIVX") (`excluded_id') ("`excluded_iso3'") ///
        ("RENTS x INST") ///
        (`divx_base_interaction_b') ///
        (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) ///
        (`loo_interaction_p') ///
        (e(N)) (e(N_g))
}

* Cerrar el archivo después de completar las 196 combinaciones modelo-país-término.
postclose `leave_one_out_post'

* Exportar el detalle completo y construir una síntesis por modelo y término.
preserve
    use "`leave_one_out_report'", clear
    sort model term excluded_country_iso3

    * Identificar cambios de signo y la frecuencia con que cada término conserva significancia en las reestimaciones.
    generate byte sign_reversal = ///
        sign(coefficient) != sign(base_coefficient)
    generate byte significant_5  = p_value < 0.05
    generate byte significant_10 = p_value < 0.10

    * Guardar las 196 reestimaciones antes de reducirlas a un resumen.
    format base_coefficient coefficient standard_error p_value %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/leave_one_country_out.csv", ///
        replace datafmt

    * Resumir rangos de coeficientes y valores p, además de cambios de signo y frecuencias de significancia.
    collapse ///
        (count) repetitions=coefficient ///
        (firstnm) base_coefficient ///
        (min) min_coefficient=coefficient min_p_value=p_value ///
        (max) max_coefficient=coefficient max_p_value=p_value ///
        (sum) sign_reversals=sign_reversal ///
              significant_5 significant_10, ///
        by(model term)

    * Exportar la síntesis utilizada para decidir si un solo país domina el resultado central.
    format base_coefficient min_coefficient max_coefficient ///
        min_p_value max_p_value %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/leave_one_country_out_summary.csv", ///
        replace datafmt
    list, noobs sepby(model) abbreviate(24)
restore


// 11.7. Aplicar wild cluster bootstrap como inferencia alternativa

* Preparar reportes separados para seis pruebas individuales y dos contrastes
* conjuntos. Esta inferencia complementa, pero no sustituye, el agrupamiento
* convencional por país.
tempname wild_bootstrap_post wild_bootstrap_joint_post
tempfile wild_bootstrap_report wild_bootstrap_joint_report

postfile `wild_bootstrap_post' ///
    str8 model str24 term ///
    double coefficient conventional_p bootstrap_p ///
    ci_lower ci_upper ///
    str4 statistic_type double statistic_value ///
    numerator_df denominator_df ///
    long repetitions str8 seed int observations countries ///
    str12 weight_type byte significance_selected ///
    str12 hierarchy ///
    using "`wild_bootstrap_report'", replace

postfile `wild_bootstrap_joint_post' ///
    str8 model str40 hypothesis ///
    double conventional_f conventional_p ///
    bootstrap_f bootstrap_p numerator_df denominator_df ///
    long repetitions str8 seed int observations countries ///
    str12 weight_type byte significance_selected ///
    str12 hierarchy ///
    using "`wild_bootstrap_joint_report'", replace

* Reestimar ECI mediante xtreg con efectos de año explícitos. Esta es la misma
* ecuación principal y se utiliza porque boottest es compatible con xtreg.
quietly xtreg eci $ECI_REGRESSORS i.year ///
    if sample_eci == 1, ///
    fe $INFERENCE_MAIN

assert e(sample) == sample_eci
assert e(N) == `eci_expected_n'
assert e(N_g) == `eci_expected_countries'
assert abs(_b[rents] - `eci_base_rents_b') < 1e-10
assert abs(_b[c.rents#c.inst] - `eci_base_interaction_b') < 1e-10

local eci_bootstrap_n = e(N)
local eci_bootstrap_countries = e(N_g)
local eci_bootstrap_df_r = e(df_r)
local eci_bootstrap_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local eci_bootstrap_inst_p = ///
    2 * ttail(e(df_r), abs(_b[inst] / _se[inst]))
local eci_bootstrap_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))

quietly test rents inst c.rents#c.inst
local eci_conventional_joint_f = r(F)
local eci_conventional_joint_p = r(p)

* RENTS en ECI: conservar la semilla previamente aprobada.
boottest rents, ///
    cluster(country_id) reps(9999) seed(20260729) nograph
if missing(r(p)) | missing(r(t)) {
    display as error "boottest no produjo resultados para RENTS en ECI."
    exit 498
}
matrix eci_rents_bootstrap_ci = r(CI)
post `wild_bootstrap_post' ///
    ("ECI") ("RENTS") ///
    (_b[rents]) (`eci_bootstrap_rents_p') (r(p)) ///
    (el(eci_rents_bootstrap_ci, 1, 1)) ///
    (el(eci_rents_bootstrap_ci, 1, 2)) ///
    ("T") (r(t)) (r(df)) (r(df_r)) ///
    (r(reps)) ("20260729") (`eci_bootstrap_n') ///
    (`eci_bootstrap_countries') ("`r(weighttype)'") ///
    (0) ("SENSITIVITY")

* INST en ECI: completar el conjunto focal predefinido.
boottest inst, ///
    cluster(country_id) reps(9999) seed(20260733) nograph
if missing(r(p)) | missing(r(t)) {
    display as error "boottest no produjo resultados para INST en ECI."
    exit 498
}
matrix eci_inst_bootstrap_ci = r(CI)
post `wild_bootstrap_post' ///
    ("ECI") ("INST") ///
    (_b[inst]) (`eci_bootstrap_inst_p') (r(p)) ///
    (el(eci_inst_bootstrap_ci, 1, 1)) ///
    (el(eci_inst_bootstrap_ci, 1, 2)) ///
    ("T") (r(t)) (r(df)) (r(df_r)) ///
    (r(reps)) ("20260733") (`eci_bootstrap_n') ///
    (`eci_bootstrap_countries') ("`r(weighttype)'") ///
    (0) ("SENSITIVITY")

* Interacción RENTS x INST en ECI: conservar la semilla existente.
boottest c.rents#c.inst, ///
    cluster(country_id) reps(9999) seed(20260730) nograph
if missing(r(p)) | missing(r(t)) {
    display as error ///
        "boottest no produjo resultados para RENTS x INST en ECI."
    exit 498
}
matrix eci_interaction_bootstrap_ci = r(CI)
post `wild_bootstrap_post' ///
    ("ECI") ("RENTS x INST") ///
    (_b[c.rents#c.inst]) (`eci_bootstrap_interaction_p') (r(p)) ///
    (el(eci_interaction_bootstrap_ci, 1, 1)) ///
    (el(eci_interaction_bootstrap_ci, 1, 2)) ///
    ("T") (r(t)) (r(df)) (r(df_r)) ///
    (r(reps)) ("20260730") (`eci_bootstrap_n') ///
    (`eci_bootstrap_countries') ("`r(weighttype)'") ///
    (0) ("SENSITIVITY")

* Contrastar conjuntamente los tres términos focales de ECI.
boottest rents inst c.rents#c.inst, ///
    cluster(country_id) reps(9999) seed(20260735) nograph
if missing(r(p)) | missing(r(F)) {
    display as error ///
        "boottest no produjo la prueba conjunta focal de ECI."
    exit 498
}
post `wild_bootstrap_joint_post' ///
    ("ECI") ("RENTS_INST_INTERACTION_JOINT_ZERO") ///
    (`eci_conventional_joint_f') (`eci_conventional_joint_p') ///
    (r(F)) (r(p)) (r(df)) (r(df_r)) ///
    (r(reps)) ("20260735") (`eci_bootstrap_n') ///
    (`eci_bootstrap_countries') ("`r(weighttype)'") ///
    (0) ("SENSITIVITY")

* Reestimar DIVX mediante la misma especificación complementaria aprobada.
quietly xtreg divx $DIVX_REGRESSORS i.year ///
    if sample_divx == 1, ///
    fe $INFERENCE_MAIN

assert e(sample) == sample_divx
assert e(N) == `divx_expected_n'
assert e(N_g) == `divx_expected_countries'
assert abs(_b[rents] - `divx_base_rents_b') < 1e-10
assert abs(_b[c.rents#c.inst] - `divx_base_interaction_b') < 1e-10

local divx_bootstrap_n = e(N)
local divx_bootstrap_countries = e(N_g)
local divx_bootstrap_df_r = e(df_r)
local divx_bootstrap_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local divx_bootstrap_inst_p = ///
    2 * ttail(e(df_r), abs(_b[inst] / _se[inst]))
local divx_bootstrap_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))

quietly test rents inst c.rents#c.inst
local divx_conventional_joint_f = r(F)
local divx_conventional_joint_p = r(p)

* RENTS en DIVX: conservar la semilla previamente aprobada.
boottest rents, ///
    cluster(country_id) reps(9999) seed(20260731) nograph
if missing(r(p)) | missing(r(t)) {
    display as error "boottest no produjo resultados para RENTS en DIVX."
    exit 498
}
matrix divx_rents_bootstrap_ci = r(CI)
post `wild_bootstrap_post' ///
    ("DIVX") ("RENTS") ///
    (_b[rents]) (`divx_bootstrap_rents_p') (r(p)) ///
    (el(divx_rents_bootstrap_ci, 1, 1)) ///
    (el(divx_rents_bootstrap_ci, 1, 2)) ///
    ("T") (r(t)) (r(df)) (r(df_r)) ///
    (r(reps)) ("20260731") (`divx_bootstrap_n') ///
    (`divx_bootstrap_countries') ("`r(weighttype)'") ///
    (0) ("SENSITIVITY")

* INST en DIVX.
boottest inst, ///
    cluster(country_id) reps(9999) seed(20260734) nograph
if missing(r(p)) | missing(r(t)) {
    display as error "boottest no produjo resultados para INST en DIVX."
    exit 498
}
matrix divx_inst_bootstrap_ci = r(CI)
post `wild_bootstrap_post' ///
    ("DIVX") ("INST") ///
    (_b[inst]) (`divx_bootstrap_inst_p') (r(p)) ///
    (el(divx_inst_bootstrap_ci, 1, 1)) ///
    (el(divx_inst_bootstrap_ci, 1, 2)) ///
    ("T") (r(t)) (r(df)) (r(df_r)) ///
    (r(reps)) ("20260734") (`divx_bootstrap_n') ///
    (`divx_bootstrap_countries') ("`r(weighttype)'") ///
    (0) ("SENSITIVITY")

* Interacción RENTS x INST en DIVX: conservar la semilla existente.
boottest c.rents#c.inst, ///
    cluster(country_id) reps(9999) seed(20260732) nograph
if missing(r(p)) | missing(r(t)) {
    display as error ///
        "boottest no produjo resultados para RENTS x INST en DIVX."
    exit 498
}
matrix divx_interaction_bootstrap_ci = r(CI)
post `wild_bootstrap_post' ///
    ("DIVX") ("RENTS x INST") ///
    (_b[c.rents#c.inst]) (`divx_bootstrap_interaction_p') (r(p)) ///
    (el(divx_interaction_bootstrap_ci, 1, 1)) ///
    (el(divx_interaction_bootstrap_ci, 1, 2)) ///
    ("T") (r(t)) (r(df)) (r(df_r)) ///
    (r(reps)) ("20260732") (`divx_bootstrap_n') ///
    (`divx_bootstrap_countries') ("`r(weighttype)'") ///
    (0) ("SENSITIVITY")

* Contrastar conjuntamente los tres términos focales de DIVX.
boottest rents inst c.rents#c.inst, ///
    cluster(country_id) reps(9999) seed(20260736) nograph
if missing(r(p)) | missing(r(F)) {
    display as error ///
        "boottest no produjo la prueba conjunta focal de DIVX."
    exit 498
}
post `wild_bootstrap_joint_post' ///
    ("DIVX") ("RENTS_INST_INTERACTION_JOINT_ZERO") ///
    (`divx_conventional_joint_f') (`divx_conventional_joint_p') ///
    (r(F)) (r(p)) (r(df)) (r(df_r)) ///
    (r(reps)) ("20260736") (`divx_bootstrap_n') ///
    (`divx_bootstrap_countries') ("`r(weighttype)'") ///
    (0) ("SENSITIVITY")

postclose `wild_bootstrap_post'
postclose `wild_bootstrap_joint_post'

* Exportar y validar las seis pruebas individuales.
preserve
    use "`wild_bootstrap_report'", clear
    assert _N == 6
    isid model term
    assert observations == `eci_expected_n'
    assert countries == `eci_expected_countries'
    assert repetitions == 9999
    assert statistic_type == "T"
    assert numerator_df == 1
    assert denominator_df > 0
    assert inrange(conventional_p, 0, 1)
    assert inrange(bootstrap_p, 0, 1)
    assert weight_type == "rademacher"
    assert significance_selected == 0
    assert hierarchy == "SENSITIVITY"
    assert seed == "20260729" if model == "ECI" & term == "RENTS"
    assert seed == "20260733" if model == "ECI" & term == "INST"
    assert seed == "20260730" if ///
        model == "ECI" & term == "RENTS x INST"
    assert seed == "20260731" if model == "DIVX" & term == "RENTS"
    assert seed == "20260734" if model == "DIVX" & term == "INST"
    assert seed == "20260732" if ///
        model == "DIVX" & term == "RENTS x INST"
    sort model term
    format coefficient conventional_p bootstrap_p ///
        ci_lower ci_upper statistic_value ///
        numerator_df denominator_df %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/wild_cluster_bootstrap.csv", ///
        replace datafmt
    list, noobs sepby(model) abbreviate(24)
restore

* Exportar y validar las dos pruebas bootstrap conjuntas.
preserve
    use "`wild_bootstrap_joint_report'", clear
    assert _N == 2
    isid model
    assert observations == `eci_expected_n'
    assert countries == `eci_expected_countries'
    assert repetitions == 9999
    assert numerator_df == 3
    assert denominator_df > 0
    assert conventional_f >= 0
    assert bootstrap_f >= 0
    assert inrange(conventional_p, 0, 1)
    assert inrange(bootstrap_p, 0, 1)
    assert weight_type == "rademacher"
    assert significance_selected == 0
    assert hierarchy == "SENSITIVITY"
    assert seed == "20260735" if model == "ECI"
    assert seed == "20260736" if model == "DIVX"
    sort model
    format conventional_f conventional_p ///
        bootstrap_f bootstrap_p numerator_df denominator_df %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/wild_cluster_bootstrap_joint_tests.csv", ///
        replace datafmt
    list, noobs abbreviate(24)
restore


// 11.8. Evaluar tendencias lineales específicas por país

* Esta sensibilidad permite que cada país tenga una trayectoria lineal propia.
* Se mantiene la muestra común, los efectos fijos por país y año, los regresores
* aprobados y los errores estándar agrupados por país. La tendencia se centra en
* 1996 únicamente para facilitar la interpretación numérica del término temporal.
capture drop time_index
generate double time_index = year - 1996
label variable time_index "Índice temporal centrado en 1996"

* Definir los tres términos focales que se compararán con los modelos principales.
local trend_focal_terms rents inst c.rents#c.inst

* Conservar coeficientes y errores estándar base antes de ejecutar reghdfe.
estimates restore ECI_TWFE_MAIN
matrix eci_base_focal = ///
    (_b[rents], _se[rents] \ ///
     _b[inst], _se[inst] \ ///
     _b[c.rents#c.inst], _se[c.rents#c.inst])
local eci_base_df_r = e(df_r)

estimates restore DIVX_TWFE_MAIN
matrix divx_base_focal = ///
    (_b[rents], _se[rents] \ ///
     _b[inst], _se[inst] \ ///
     _b[c.rents#c.inst], _se[c.rents#c.inst])
local divx_base_df_r = e(df_r)

* Preparar el reporte focal que alimenta las matrices de robustez, un reporte
* completo para todos los regresores sustantivos y las pruebas conjuntas.
tempname country_trend_post country_trend_all_post ///
    country_trend_joint_post
tempfile country_trend_report country_trend_all_report ///
    country_trend_joint_report

postfile `country_trend_post' ///
    str8 model str24 term ///
    double base_coefficient base_standard_error base_p_value ///
    base_ci_lower base_ci_upper ///
    trend_coefficient trend_standard_error trend_p_value ///
    trend_ci_lower trend_ci_upper ///
    absolute_change percentage_change ///
    byte sign_stable ///
    long observations int countries singletons_removed ///
    int trend_center_year byte country_fe year_fe ///
    str12 hierarchy ///
    using "`country_trend_report'", replace

postfile `country_trend_all_post' ///
    str8 model int order str32 term ///
    str100 variable_label str40 channel ///
    double base_coefficient base_standard_error base_p_value ///
    base_ci_lower base_ci_upper ///
    trend_coefficient trend_standard_error trend_p_value ///
    trend_ci_lower trend_ci_upper ///
    absolute_change percentage_change ///
    byte sign_stable significant_base_5pct significant_trend_5pct ///
    long observations int countries singletons_removed ///
    int trend_center_year byte country_fe year_fe ///
    str12 hierarchy ///
    using "`country_trend_all_report'", replace

postfile `country_trend_joint_post' ///
    str8 model str36 hypothesis ///
    double f_statistic numerator_df denominator_df p_value ///
    long observations int countries singletons_removed ///
    int trend_center_year byte country_fe year_fe ///
    str12 hierarchy ///
    using "`country_trend_joint_report'", replace

* Estimar ECI con interceptos por país, efectos de año y pendientes temporales
* específicas por país. No se incorporan tendencias cuadráticas.
quietly reghdfe eci $ECI_REGRESSORS if sample_eci == 1, ///
    absorb(country_id year country_id#c.time_index) ///
    $INFERENCE_MAIN

* Verificar que la sensibilidad utiliza exactamente la muestra aprobada y que
* la absorción de pendientes no elimina observaciones singleton.
assert e(sample) == sample_eci
assert e(N) == `eci_expected_n'
assert e(N_clust) == `eci_expected_countries'
assert e(num_singletons) == 0

local eci_trend_n = e(N)
local eci_trend_countries = e(N_clust)
local eci_trend_singletons = e(num_singletons)
local eci_trend_df_r = e(df_r)

capture estimates drop ECI_COUNTRY_LINEAR_TRENDS
estimates store ECI_COUNTRY_LINEAR_TRENDS
estimates save ///
    "$OUTPUT_STABILITY/eci_country_linear_trends.ster", replace

* Comparar los tres términos focales con la estimación ECI principal.
local focal_term_order = 0
foreach focal_term of local trend_focal_terms {
    local ++focal_term_order

    local focal_label "RENTS"
    if `focal_term_order' == 2 local focal_label "INST"
    if `focal_term_order' == 3 local focal_label "RENTS x INST"

    local base_b = el(eci_base_focal, `focal_term_order', 1)
    local base_se = el(eci_base_focal, `focal_term_order', 2)
    local base_p = 2 * ttail(`eci_base_df_r', abs(`base_b' / `base_se'))
    local base_t_critical = invttail(`eci_base_df_r', 0.025)
    local base_ci_lower = `base_b' - `base_t_critical' * `base_se'
    local base_ci_upper = `base_b' + `base_t_critical' * `base_se'

    local trend_b = _b[`focal_term']
    local trend_se = _se[`focal_term']
    local trend_p = ///
        2 * ttail(`eci_trend_df_r', abs(`trend_b' / `trend_se'))
    local trend_t_critical = invttail(`eci_trend_df_r', 0.025)
    local trend_ci_lower = `trend_b' - `trend_t_critical' * `trend_se'
    local trend_ci_upper = `trend_b' + `trend_t_critical' * `trend_se'

    local absolute_change = abs(`trend_b' - `base_b')
    local percentage_change = .
    if abs(`base_b') > 1e-12 {
        local percentage_change = ///
            100 * `absolute_change' / abs(`base_b')
    }
    local sign_stable = sign(`base_b') == sign(`trend_b')

    post `country_trend_post' ///
        ("ECI") ("`focal_label'") ///
        (`base_b') (`base_se') (`base_p') ///
        (`base_ci_lower') (`base_ci_upper') ///
        (`trend_b') (`trend_se') (`trend_p') ///
        (`trend_ci_lower') (`trend_ci_upper') ///
        (`absolute_change') (`percentage_change') ///
        (`sign_stable') ///
        (`eci_trend_n') (`eci_trend_countries') ///
        (`eci_trend_singletons') ///
        (1996) (1) (1) ("SENSITIVITY")
}

* Exportar también todos los regresores sustantivos de ECI. La estimación con
* tendencias ya los contiene; este bloque únicamente evita perderlos al
* construir el reporte. No se agregan pruebas ni especificaciones nuevas.
local all_term_order = 0
foreach term of local eci_terms {
    local ++all_term_order

    if "`term'" == "c.rents#c.inst" {
        local term_label "Interacción entre rentas y calidad institucional"
    }
    else {
        local term_label : variable label `term'
        if `"`term_label'"' == "" local term_label "`term'"
    }

    local channel "Controles económicos y financieros"
    if inlist("`term'", "rents", "inst", "c.rents#c.inst") {
        local channel "Institucional"
    }
    else if inlist("`term'", ///
        "ln1p_oilpc", "ln1p_gaspc", "ln1p_coalpc") {
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

    local base_b = scalar(eci_xtreg_b_`all_term_order')
    local base_se = scalar(eci_xtreg_se_`all_term_order')
    local base_p = 2 * ttail(`eci_base_df_r', abs(`base_b' / `base_se'))
    local base_t_critical = invttail(`eci_base_df_r', 0.025)
    local base_ci_lower = `base_b' - `base_t_critical' * `base_se'
    local base_ci_upper = `base_b' + `base_t_critical' * `base_se'

    local trend_b = _b[`term']
    local trend_se = _se[`term']
    local trend_p = ///
        2 * ttail(`eci_trend_df_r', abs(`trend_b' / `trend_se'))
    local trend_t_critical = invttail(`eci_trend_df_r', 0.025)
    local trend_ci_lower = `trend_b' - `trend_t_critical' * `trend_se'
    local trend_ci_upper = `trend_b' + `trend_t_critical' * `trend_se'

    local absolute_change = abs(`trend_b' - `base_b')
    local percentage_change = .
    if abs(`base_b') > 1e-12 {
        local percentage_change = ///
            100 * `absolute_change' / abs(`base_b')
    }
    local sign_stable = sign(`base_b') == sign(`trend_b')
    local significant_base = `base_p' < 0.05
    local significant_trend = `trend_p' < 0.05

    post `country_trend_all_post' ///
        ("ECI") (`all_term_order') ("`term'") ///
        (`"`term_label'"') (`"`channel'"') ///
        (`base_b') (`base_se') (`base_p') ///
        (`base_ci_lower') (`base_ci_upper') ///
        (`trend_b') (`trend_se') (`trend_p') ///
        (`trend_ci_lower') (`trend_ci_upper') ///
        (`absolute_change') (`percentage_change') ///
        (`sign_stable') (`significant_base') (`significant_trend') ///
        (`eci_trend_n') (`eci_trend_countries') ///
        (`eci_trend_singletons') ///
        (1996) (1) (1) ("SENSITIVITY")
}

* Contrastar conjuntamente que RENTS, INST y su interacción sean iguales a cero.
quietly test rents inst c.rents#c.inst
post `country_trend_joint_post' ///
    ("ECI") ("RENTS_INST_INTERACTION_JOINT_ZERO") ///
    (r(F)) (r(df)) (r(df_r)) (r(p)) ///
    (`eci_trend_n') (`eci_trend_countries') ///
    (`eci_trend_singletons') ///
    (1996) (1) (1) ("SENSITIVITY")

* Repetir la misma sensibilidad para DIVX, conservando la exclusión de HHI.
quietly reghdfe divx $DIVX_REGRESSORS if sample_divx == 1, ///
    absorb(country_id year country_id#c.time_index) ///
    $INFERENCE_MAIN

assert e(sample) == sample_divx
assert e(N) == `divx_expected_n'
assert e(N_clust) == `divx_expected_countries'
assert e(num_singletons) == 0

local divx_trend_n = e(N)
local divx_trend_countries = e(N_clust)
local divx_trend_singletons = e(num_singletons)
local divx_trend_df_r = e(df_r)

capture estimates drop DIVX_COUNTRY_LINEAR_TRENDS
estimates store DIVX_COUNTRY_LINEAR_TRENDS
estimates save ///
    "$OUTPUT_STABILITY/divx_country_linear_trends.ster", replace

* Comparar los tres términos focales con la estimación DIVX principal.
local focal_term_order = 0
foreach focal_term of local trend_focal_terms {
    local ++focal_term_order

    local focal_label "RENTS"
    if `focal_term_order' == 2 local focal_label "INST"
    if `focal_term_order' == 3 local focal_label "RENTS x INST"

    local base_b = el(divx_base_focal, `focal_term_order', 1)
    local base_se = el(divx_base_focal, `focal_term_order', 2)
    local base_p = 2 * ttail(`divx_base_df_r', abs(`base_b' / `base_se'))
    local base_t_critical = invttail(`divx_base_df_r', 0.025)
    local base_ci_lower = `base_b' - `base_t_critical' * `base_se'
    local base_ci_upper = `base_b' + `base_t_critical' * `base_se'

    local trend_b = _b[`focal_term']
    local trend_se = _se[`focal_term']
    local trend_p = ///
        2 * ttail(`divx_trend_df_r', abs(`trend_b' / `trend_se'))
    local trend_t_critical = invttail(`divx_trend_df_r', 0.025)
    local trend_ci_lower = `trend_b' - `trend_t_critical' * `trend_se'
    local trend_ci_upper = `trend_b' + `trend_t_critical' * `trend_se'

    local absolute_change = abs(`trend_b' - `base_b')
    local percentage_change = .
    if abs(`base_b') > 1e-12 {
        local percentage_change = ///
            100 * `absolute_change' / abs(`base_b')
    }
    local sign_stable = sign(`base_b') == sign(`trend_b')

    post `country_trend_post' ///
        ("DIVX") ("`focal_label'") ///
        (`base_b') (`base_se') (`base_p') ///
        (`base_ci_lower') (`base_ci_upper') ///
        (`trend_b') (`trend_se') (`trend_p') ///
        (`trend_ci_lower') (`trend_ci_upper') ///
        (`absolute_change') (`percentage_change') ///
        (`sign_stable') ///
        (`divx_trend_n') (`divx_trend_countries') ///
        (`divx_trend_singletons') ///
        (1996) (1) (1) ("SENSITIVITY")
}

* Repetir el reporte completo para DIVX. HHI no aparece porque está excluido
* de esta ecuación por la identidad contable DIVX = 1 - HHI.
local all_term_order = 0
foreach term of local divx_terms {
    local ++all_term_order

    if "`term'" == "c.rents#c.inst" {
        local term_label "Interacción entre rentas y calidad institucional"
    }
    else {
        local term_label : variable label `term'
        if `"`term_label'"' == "" local term_label "`term'"
    }

    local channel "Controles económicos y financieros"
    if inlist("`term'", "rents", "inst", "c.rents#c.inst") {
        local channel "Institucional"
    }
    else if inlist("`term'", ///
        "ln1p_oilpc", "ln1p_gaspc", "ln1p_coalpc") {
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

    local base_b = scalar(divx_xtreg_b_`all_term_order')
    local base_se = scalar(divx_xtreg_se_`all_term_order')
    local base_p = 2 * ttail(`divx_base_df_r', abs(`base_b' / `base_se'))
    local base_t_critical = invttail(`divx_base_df_r', 0.025)
    local base_ci_lower = `base_b' - `base_t_critical' * `base_se'
    local base_ci_upper = `base_b' + `base_t_critical' * `base_se'

    local trend_b = _b[`term']
    local trend_se = _se[`term']
    local trend_p = ///
        2 * ttail(`divx_trend_df_r', abs(`trend_b' / `trend_se'))
    local trend_t_critical = invttail(`divx_trend_df_r', 0.025)
    local trend_ci_lower = `trend_b' - `trend_t_critical' * `trend_se'
    local trend_ci_upper = `trend_b' + `trend_t_critical' * `trend_se'

    local absolute_change = abs(`trend_b' - `base_b')
    local percentage_change = .
    if abs(`base_b') > 1e-12 {
        local percentage_change = ///
            100 * `absolute_change' / abs(`base_b')
    }
    local sign_stable = sign(`base_b') == sign(`trend_b')
    local significant_base = `base_p' < 0.05
    local significant_trend = `trend_p' < 0.05

    post `country_trend_all_post' ///
        ("DIVX") (`all_term_order') ("`term'") ///
        (`"`term_label'"') (`"`channel'"') ///
        (`base_b') (`base_se') (`base_p') ///
        (`base_ci_lower') (`base_ci_upper') ///
        (`trend_b') (`trend_se') (`trend_p') ///
        (`trend_ci_lower') (`trend_ci_upper') ///
        (`absolute_change') (`percentage_change') ///
        (`sign_stable') (`significant_base') (`significant_trend') ///
        (`divx_trend_n') (`divx_trend_countries') ///
        (`divx_trend_singletons') ///
        (1996) (1) (1) ("SENSITIVITY")
}

quietly test rents inst c.rents#c.inst
post `country_trend_joint_post' ///
    ("DIVX") ("RENTS_INST_INTERACTION_JOINT_ZERO") ///
    (r(F)) (r(df)) (r(df_r)) (r(p)) ///
    (`divx_trend_n') (`divx_trend_countries') ///
    (`divx_trend_singletons') ///
    (1996) (1) (1) ("SENSITIVITY")

postclose `country_trend_post'
postclose `country_trend_all_post'
postclose `country_trend_joint_post'

* Exportar el contraste término por término y validar su estructura.
preserve
    use "`country_trend_report'", clear
    assert _N == 6
    isid model term
    assert observations == `eci_expected_n'
    assert countries == `eci_expected_countries'
    assert singletons_removed == 0
    assert country_fe == 1 & year_fe == 1
    assert hierarchy == "SENSITIVITY"
    sort model term
    format base_coefficient base_standard_error base_p_value ///
        base_ci_lower base_ci_upper ///
        trend_coefficient trend_standard_error trend_p_value ///
        trend_ci_lower trend_ci_upper absolute_change %12.6f
    format percentage_change %12.3f
    export delimited using ///
        "$OUTPUT_STABILITY/country_linear_trend_sensitivity.csv", ///
        replace datafmt
    list, noobs sepby(model) abbreviate(24)
restore

* Exportar los 33 coeficientes sustantivos de ambos modelos. Este archivo es el
* insumo para estudiar los canales completos sin alterar el reporte focal.
preserve
    use "`country_trend_all_report'", clear
    assert _N == 33
    isid model term
    quietly count if model == "ECI"
    assert r(N) == 17
    quietly count if model == "DIVX"
    assert r(N) == 16
    assert term != "hhi" if model == "DIVX"
    quietly count if model == "ECI" & term == "hhi"
    assert r(N) == 1
    assert observations == `eci_expected_n'
    assert countries == `eci_expected_countries'
    assert singletons_removed == 0
    assert country_fe == 1 & year_fe == 1
    assert hierarchy == "SENSITIVITY"
    sort model order
    format base_coefficient base_standard_error base_p_value ///
        base_ci_lower base_ci_upper ///
        trend_coefficient trend_standard_error trend_p_value ///
        trend_ci_lower trend_ci_upper absolute_change %12.6f
    format percentage_change %12.3f
    export delimited using ///
        "$OUTPUT_STABILITY/country_linear_trend_all_coefficients.csv", ///
        replace datafmt
    list model term base_coefficient trend_coefficient ///
        base_p_value trend_p_value sign_stable, ///
        noobs sepby(model) abbreviate(24)
restore

* Exportar las pruebas conjuntas y verificar una fila por resultado.
preserve
    use "`country_trend_joint_report'", clear
    assert _N == 2
    isid model
    assert observations == `eci_expected_n'
    assert countries == `eci_expected_countries'
    assert singletons_removed == 0
    assert country_fe == 1 & year_fe == 1
    assert hierarchy == "SENSITIVITY"
    sort model
    format f_statistic p_value %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/country_linear_trend_joint_tests.csv", ///
        replace datafmt
    list, noobs abbreviate(24)
restore

* El índice temporal fue creado únicamente para esta sensibilidad.
drop time_index


// 11.9. Evaluar estabilidad temporal alrededor de 2014

* El corte se definió antes de observar estas estimaciones. El Banco Mundial
* documenta una caída cercana al 50 % del precio del petróleo entre junio de
* 2014 y febrero de 2015. Con datos anuales, 2014 debe leerse como un año de
* transición y no como un período completamente posterior al choque.
* Fuente: World Bank (2015), Understanding the Plunge in Oil Prices: Sources
* and Implications, Policy Research Note 1.
* https://documents1.worldbank.org/curated/en/726831468180852545/pdf/94725-NWP-PRN01-Mar2015-Oil-Prices-Box393265B-PUBLIC.pdf

capture drop post2014
generate byte post2014 = year >= 2014
label variable post2014 "Año 2014 o posterior"
assert inlist(post2014, 0, 1)

* Confirmar que el indicador temporal no altera las banderas de muestra.
quietly count if sample_eci == 1
assert r(N) == `eci_expected_n'
quietly count if sample_divx == 1
assert r(N) == `divx_expected_n'

* Documentar la cobertura de los dos regímenes dentro de la muestra común.
quietly levelsof country_iso3_code if sample_eci == 1, ///
    local(full_sample_iso3_codes) clean

quietly count if sample_eci == 1 & post2014 == 0
local pre2014_n = r(N)
quietly levelsof country_id if sample_eci == 1 & post2014 == 0, ///
    local(pre2014_country_ids)
local pre2014_countries : word count `pre2014_country_ids'
quietly levelsof country_iso3_code if sample_eci == 1 & post2014 == 0, ///
    local(pre2014_iso3_codes) clean
local pre2014_absent_iso3 : list ///
    full_sample_iso3_codes - pre2014_iso3_codes
local pre2014_absent_countries : word count `pre2014_absent_iso3'
quietly levelsof year if sample_eci == 1 & post2014 == 0, ///
    local(pre2014_years)
local pre2014_effective_years : word count `pre2014_years'
quietly summarize year if sample_eci == 1 & post2014 == 0, meanonly
local pre2014_first_year = r(min)
local pre2014_last_year = r(max)

quietly count if sample_eci == 1 & post2014 == 1
local from2014_n = r(N)
quietly levelsof country_id if sample_eci == 1 & post2014 == 1, ///
    local(from2014_country_ids)
local from2014_countries : word count `from2014_country_ids'
quietly levelsof country_iso3_code if sample_eci == 1 & post2014 == 1, ///
    local(from2014_iso3_codes) clean
local from2014_absent_iso3 : list ///
    full_sample_iso3_codes - from2014_iso3_codes
local from2014_absent_countries : word count `from2014_absent_iso3'
quietly levelsof year if sample_eci == 1 & post2014 == 1, ///
    local(from2014_years)
local from2014_effective_years : word count `from2014_years'
quietly summarize year if sample_eci == 1 & post2014 == 1, meanonly
local from2014_first_year = r(min)
local from2014_last_year = r(max)

assert `pre2014_n' + `from2014_n' == `eci_expected_n'
assert `pre2014_countries' > 0
assert `from2014_countries' > 0
assert `pre2014_countries' + `pre2014_absent_countries' == ///
    `eci_expected_countries'
assert `from2014_countries' + `from2014_absent_countries' == ///
    `eci_expected_countries'

tempname regime_coverage_post
tempfile regime_coverage_report
postfile `regime_coverage_post' ///
    byte order str12 regime str20 sample_scope ///
    int cutoff_year first_year last_year effective_years ///
    long observations int countries absent_countries ///
    str80 absent_country_codes double sample_share ///
    byte externally_prespecified significance_selected ///
    str32 external_reference str80 annual_data_caveat ///
    using "`regime_coverage_report'", replace

post `regime_coverage_post' ///
    (1) ("PRE_2014") ("ECI_DIVX_COMMON") ///
    (2014) (`pre2014_first_year') (`pre2014_last_year') ///
    (`pre2014_effective_years') (`pre2014_n') ///
    (`pre2014_countries') (`pre2014_absent_countries') ///
    ("`pre2014_absent_iso3'") ///
    (`pre2014_n' / `eci_expected_n') ///
    (1) (0) ("World Bank PRN 1 (2015)") ///
    ("2014 is excluded from the pre-cutoff regime.")

post `regime_coverage_post' ///
    (2) ("FROM_2014") ("ECI_DIVX_COMMON") ///
    (2014) (`from2014_first_year') (`from2014_last_year') ///
    (`from2014_effective_years') (`from2014_n') ///
    (`from2014_countries') (`from2014_absent_countries') ///
    ("`from2014_absent_iso3'") ///
    (`from2014_n' / `eci_expected_n') ///
    (1) (0) ("World Bank PRN 1 (2015)") ///
    ("Annual 2014 mixes months before and after the mid-year oil-price decline.")

postclose `regime_coverage_post'

preserve
    use "`regime_coverage_report'", clear
    assert _N == 2
    isid regime
    quietly summarize observations, meanonly
    assert r(sum) == `eci_expected_n'
    assert countries + absent_countries == `eci_expected_countries'
    egen double total_sample_share = total(sample_share)
    assert abs(total_sample_share - 1) < 1e-10
    drop total_sample_share
    assert externally_prespecified == 1
    assert significance_selected == 0
    sort order
    format sample_share %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/temporal_regime_coverage_2014.csv", ///
        replace datafmt
    list, noobs abbreviate(24)
restore

* Preparar los reportes de coeficientes por régimen y de estabilidad conjunta.
tempname regime_stability_post regime_joint_post
tempfile regime_stability_report regime_joint_report

postfile `regime_stability_post' ///
    str8 model str24 term ///
    double pre_coefficient pre_standard_error pre_p_value ///
    pre_ci_lower pre_ci_upper ///
    change_from_2014 change_standard_error change_p_value ///
    change_ci_lower change_ci_upper ///
    post_coefficient post_standard_error post_p_value ///
    post_ci_lower post_ci_upper ///
    byte sign_stable ///
    long observations int countries cutoff_year ///
    byte country_fe year_fe externally_prespecified ///
    significance_selected ///
    str12 hierarchy ///
    using "`regime_stability_report'", replace

postfile `regime_joint_post' ///
    str8 model str40 hypothesis ///
    double f_statistic numerator_df denominator_df p_value ///
    long observations int countries cutoff_year ///
    byte country_fe year_fe externally_prespecified ///
    significance_selected ///
    str12 hierarchy ///
    using "`regime_joint_report'", replace

local stability_base_terms rents inst c.rents#c.inst
local stability_change_terms ///
    1.post2014#c.rents ///
    1.post2014#c.inst ///
    1.post2014#c.rents#c.inst

* Estimar ECI en la muestra completa. Los efectos de año absorben cambios de
* nivel comunes; las interacciones identifican cambios en las pendientes focales.
quietly xtreg eci $ECI_REGRESSORS ///
    i.post2014#c.rents ///
    i.post2014#c.inst ///
    i.post2014#c.rents#c.inst ///
    i.year if sample_eci == 1, ///
    fe $INFERENCE_MAIN

assert e(sample) == sample_eci
assert e(N) == `eci_expected_n'
assert e(N_g) == `eci_expected_countries'

local eci_regime_n = e(N)
local eci_regime_countries = e(N_g)
local eci_regime_df_r = e(df_r)

capture estimates drop ECI_REGIME_STABILITY_2014
estimates store ECI_REGIME_STABILITY_2014
estimates save ///
    "$OUTPUT_STABILITY/eci_structural_stability_2014.ster", replace

local stability_term_order = 0
foreach base_term of local stability_base_terms {
    local ++stability_term_order
    local change_term : word `stability_term_order' ///
        of `stability_change_terms'

    local focal_label "RENTS"
    if `stability_term_order' == 2 local focal_label "INST"
    if `stability_term_order' == 3 local focal_label "RENTS x INST"

    local pre_b = _b[`base_term']
    local pre_se = _se[`base_term']
    local pre_p = 2 * ttail(`eci_regime_df_r', abs(`pre_b' / `pre_se'))
    local regime_t_critical = invttail(`eci_regime_df_r', 0.025)
    local pre_ci_lower = `pre_b' - `regime_t_critical' * `pre_se'
    local pre_ci_upper = `pre_b' + `regime_t_critical' * `pre_se'

    local change_b = _b[`change_term']
    local change_se = _se[`change_term']
    local change_p = ///
        2 * ttail(`eci_regime_df_r', abs(`change_b' / `change_se'))
    local change_ci_lower = ///
        `change_b' - `regime_t_critical' * `change_se'
    local change_ci_upper = ///
        `change_b' + `regime_t_critical' * `change_se'

    quietly lincom `base_term' + `change_term'
    local post_b = r(estimate)
    local post_se = r(se)
    local post_p = r(p)
    local post_ci_lower = r(lb)
    local post_ci_upper = r(ub)
    local sign_stable = sign(`pre_b') == sign(`post_b')

    post `regime_stability_post' ///
        ("ECI") ("`focal_label'") ///
        (`pre_b') (`pre_se') (`pre_p') ///
        (`pre_ci_lower') (`pre_ci_upper') ///
        (`change_b') (`change_se') (`change_p') ///
        (`change_ci_lower') (`change_ci_upper') ///
        (`post_b') (`post_se') (`post_p') ///
        (`post_ci_lower') (`post_ci_upper') ///
        (`sign_stable') (`eci_regime_n') ///
        (`eci_regime_countries') (2014) ///
        (1) (1) (1) (0) ("SENSITIVITY")
}

quietly test ///
    1.post2014#c.rents ///
    1.post2014#c.inst ///
    1.post2014#c.rents#c.inst
post `regime_joint_post' ///
    ("ECI") ("NO_FOCAL_COEFFICIENT_CHANGE_FROM_2014") ///
    (r(F)) (r(df)) (r(df_r)) (r(p)) ///
    (`eci_regime_n') (`eci_regime_countries') (2014) ///
    (1) (1) (1) (0) ("SENSITIVITY")

* Repetir el mismo contraste para DIVX sin introducir HHI.
quietly xtreg divx $DIVX_REGRESSORS ///
    i.post2014#c.rents ///
    i.post2014#c.inst ///
    i.post2014#c.rents#c.inst ///
    i.year if sample_divx == 1, ///
    fe $INFERENCE_MAIN

assert e(sample) == sample_divx
assert e(N) == `divx_expected_n'
assert e(N_g) == `divx_expected_countries'

local divx_regime_n = e(N)
local divx_regime_countries = e(N_g)
local divx_regime_df_r = e(df_r)

capture estimates drop DIVX_REGIME_STABILITY_2014
estimates store DIVX_REGIME_STABILITY_2014
estimates save ///
    "$OUTPUT_STABILITY/divx_structural_stability_2014.ster", replace

local stability_term_order = 0
foreach base_term of local stability_base_terms {
    local ++stability_term_order
    local change_term : word `stability_term_order' ///
        of `stability_change_terms'

    local focal_label "RENTS"
    if `stability_term_order' == 2 local focal_label "INST"
    if `stability_term_order' == 3 local focal_label "RENTS x INST"

    local pre_b = _b[`base_term']
    local pre_se = _se[`base_term']
    local pre_p = ///
        2 * ttail(`divx_regime_df_r', abs(`pre_b' / `pre_se'))
    local regime_t_critical = invttail(`divx_regime_df_r', 0.025)
    local pre_ci_lower = `pre_b' - `regime_t_critical' * `pre_se'
    local pre_ci_upper = `pre_b' + `regime_t_critical' * `pre_se'

    local change_b = _b[`change_term']
    local change_se = _se[`change_term']
    local change_p = ///
        2 * ttail(`divx_regime_df_r', abs(`change_b' / `change_se'))
    local change_ci_lower = ///
        `change_b' - `regime_t_critical' * `change_se'
    local change_ci_upper = ///
        `change_b' + `regime_t_critical' * `change_se'

    quietly lincom `base_term' + `change_term'
    local post_b = r(estimate)
    local post_se = r(se)
    local post_p = r(p)
    local post_ci_lower = r(lb)
    local post_ci_upper = r(ub)
    local sign_stable = sign(`pre_b') == sign(`post_b')

    post `regime_stability_post' ///
        ("DIVX") ("`focal_label'") ///
        (`pre_b') (`pre_se') (`pre_p') ///
        (`pre_ci_lower') (`pre_ci_upper') ///
        (`change_b') (`change_se') (`change_p') ///
        (`change_ci_lower') (`change_ci_upper') ///
        (`post_b') (`post_se') (`post_p') ///
        (`post_ci_lower') (`post_ci_upper') ///
        (`sign_stable') (`divx_regime_n') ///
        (`divx_regime_countries') (2014) ///
        (1) (1) (1) (0) ("SENSITIVITY")
}

quietly test ///
    1.post2014#c.rents ///
    1.post2014#c.inst ///
    1.post2014#c.rents#c.inst
post `regime_joint_post' ///
    ("DIVX") ("NO_FOCAL_COEFFICIENT_CHANGE_FROM_2014") ///
    (r(F)) (r(df)) (r(df_r)) (r(p)) ///
    (`divx_regime_n') (`divx_regime_countries') (2014) ///
    (1) (1) (1) (0) ("SENSITIVITY")

postclose `regime_stability_post'
postclose `regime_joint_post'

* Exportar y validar los coeficientes pre-2014, sus cambios y los valores
* implícitos desde 2014.
preserve
    use "`regime_stability_report'", clear
    assert _N == 6
    isid model term
    assert observations == `eci_expected_n'
    assert countries == `eci_expected_countries'
    assert cutoff_year == 2014
    assert country_fe == 1 & year_fe == 1
    assert externally_prespecified == 1
    assert significance_selected == 0
    assert hierarchy == "SENSITIVITY"
    assert inrange(pre_p_value, 0, 1)
    assert inrange(change_p_value, 0, 1)
    assert inrange(post_p_value, 0, 1)
    assert inrange(pre_coefficient, pre_ci_lower, pre_ci_upper)
    assert inrange(change_from_2014, change_ci_lower, change_ci_upper)
    assert inrange(post_coefficient, post_ci_lower, post_ci_upper)
    sort model term
    format pre_coefficient pre_standard_error pre_p_value ///
        pre_ci_lower pre_ci_upper ///
        change_from_2014 change_standard_error change_p_value ///
        change_ci_lower change_ci_upper ///
        post_coefficient post_standard_error post_p_value ///
        post_ci_lower post_ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/structural_stability_2014_coefficients.csv", ///
        replace datafmt
    list, noobs sepby(model) abbreviate(24)
restore

* Exportar la prueba conjunta de estabilidad para cada resultado.
preserve
    use "`regime_joint_report'", clear
    assert _N == 2
    isid model
    assert observations == `eci_expected_n'
    assert countries == `eci_expected_countries'
    assert cutoff_year == 2014
    assert externally_prespecified == 1
    assert significance_selected == 0
    assert hierarchy == "SENSITIVITY"
    assert inrange(p_value, 0, 1)
    sort model
    format f_statistic p_value %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/structural_stability_2014_joint_tests.csv", ///
        replace datafmt
    list, noobs abbreviate(24)
restore

* El indicador temporal se creó únicamente para esta sensibilidad.
drop post2014


// 11.10. Consolidar la evidencia focal de robustez sin reestimar modelos

* Crear una matriz larga que distinga coeficientes, inferencia alternativa,
* rangos leave-one-out, cambios temporales y efectos marginales. Cada fila
* conserva el archivo y los campos de origen para evitar comparaciones falsas.
tempname focal_post
tempfile focal_report

postfile `focal_post' ///
    str8 model str32 method str24 result_type str24 term ///
    str24 support_point double support_value ///
    double estimate double standard_error double p_value ///
    double ci_lower double ci_upper ///
    double reference_estimate double reference_p_value ///
    double estimate_min double estimate_max ///
    double p_value_at_min_estimate double p_value_at_max_estimate ///
    byte sign_stable long observations int countries ///
    int repetitions long excluded_observations byte sample_changed ///
    str28 inference_method str12 hierarchy byte comparable_to_main ///
    str100 source_file str160 source_fields ///
    str160 interpretation_scope byte significance_selected ///
    using "`focal_report'", replace

* Incorporar los tres coeficientes focales de cada M3 principal.
foreach focal_model in ECI DIVX {
    local focal_folder = lower("`focal_model'")
    local focal_section = cond("`focal_model'" == "ECI", 3, 4)
    preserve
        import delimited using ///
            "$OUTPUT_ROOT/0`focal_section'_`focal_folder'/`focal_folder'_twfe_coefficients.csv", ///
            clear varnames(1)
        gen str24 standard_term = ""
        replace standard_term = "RENTS" if term == "rents"
        replace standard_term = "INST" if term == "inst"
        replace standard_term = "RENTS x INST" if term == "c.rents#c.inst"
        keep if standard_term != ""
        assert _N == 3
        forvalues focal_i = 1/`=_N' {
            post `focal_post' ///
                ("`focal_model'") ("MAIN_TWFE") ("COEFFICIENT") ///
                (standard_term[`focal_i']) ("FULL_SAMPLE") (.) ///
                (coefficient[`focal_i']) (standard_error[`focal_i']) ///
                (p_value[`focal_i']) (ci_lower[`focal_i']) ///
                (ci_upper[`focal_i']) (.) (.) (.) (.) (.) (.) ///
                (1) (`contract_sample_n') (`contract_sample_countries') ///
                (.) (0) (0) ("CLUSTER_COUNTRY") ("MAIN") (1) ///
                ("0`focal_section'_`focal_folder'/`focal_folder'_twfe_coefficients.csv") ///
                ("coefficient; standard_error; p_value; ci_lower; ci_upper") ///
                ("Coeficiente focal del M3 principal en la muestra común.") ///
                (0)
        }
    restore
}

* Incorporar la exclusión diagnóstica de observaciones alertadas junto con su
* referencia interna de muestra completa.
preserve
    import delimited using ///
        "$OUTPUT_STABILITY/influential_observation_sensitivity.csv", ///
        clear varnames(1)
    assert _N == 4
    bysort model: egen double reference_rents = ///
        max(cond(specification == "Modelo base", rents_coefficient, .))
    bysort model: egen double reference_rents_p = ///
        max(cond(specification == "Modelo base", rents_p_value, .))
    bysort model: egen double reference_interaction = ///
        max(cond(specification == "Modelo base", interaction_coefficient, .))
    bysort model: egen double reference_interaction_p = ///
        max(cond(specification == "Modelo base", interaction_p_value, .))
    assert !missing(reference_rents, reference_interaction)
    forvalues focal_i = 1/`=_N' {
        local influence_method = cond( ///
            specification[`focal_i'] == "Modelo base", ///
            "INFLUENCE_BASE", "INFLUENCE_EXCLUSION")
        local influence_support = cond( ///
            specification[`focal_i'] == "Modelo base", ///
            "FULL_SAMPLE", "EXCLUDES_FLAGGED")
        local influence_changed = ///
            specification[`focal_i'] != "Modelo base"

        post `focal_post' ///
            (model[`focal_i']) ("`influence_method'") ("COEFFICIENT") ///
            ("RENTS") ("`influence_support'") (.) ///
            (rents_coefficient[`focal_i']) ///
            (rents_standard_error[`focal_i']) (rents_p_value[`focal_i']) ///
            (.) (.) (reference_rents[`focal_i']) ///
            (reference_rents_p[`focal_i']) (.) (.) (.) (.) ///
            (sign(rents_coefficient[`focal_i']) == ///
                sign(reference_rents[`focal_i'])) ///
            (observations[`focal_i']) (countries[`focal_i']) (.) ///
            (`contract_sample_n' - observations[`focal_i']) ///
            (`influence_changed') ("CLUSTER_COUNTRY") ///
            ("SENSITIVITY") (1) ///
            ("05_stability/influential_observation_sensitivity.csv") ///
            ("observations; countries; rents_coefficient; rents_standard_error; rents_p_value") ///
            ("Comparación diagnóstica; las alertas no autorizan eliminar filas del M3.") ///
            (0)

        post `focal_post' ///
            (model[`focal_i']) ("`influence_method'") ("COEFFICIENT") ///
            ("RENTS x INST") ("`influence_support'") (.) ///
            (interaction_coefficient[`focal_i']) ///
            (interaction_standard_error[`focal_i']) ///
            (interaction_p_value[`focal_i']) ///
            (.) (.) (reference_interaction[`focal_i']) ///
            (reference_interaction_p[`focal_i']) (.) (.) (.) (.) ///
            (sign(interaction_coefficient[`focal_i']) == ///
                sign(reference_interaction[`focal_i'])) ///
            (observations[`focal_i']) (countries[`focal_i']) (.) ///
            (`contract_sample_n' - observations[`focal_i']) ///
            (`influence_changed') ("CLUSTER_COUNTRY") ///
            ("SENSITIVITY") (1) ///
            ("05_stability/influential_observation_sensitivity.csv") ///
            ("observations; countries; interaction_coefficient; interaction_standard_error; interaction_p_value") ///
            ("Comparación diagnóstica; las alertas no autorizan eliminar filas del M3.") ///
            (0)
    }
restore

* Incorporar el rango obtenido al excluir un país por vez. Los valores p están
* asociados a los extremos del coeficiente y no son mínimos o máximos globales.
preserve
    import delimited using ///
        "$OUTPUT_STABILITY/leave_one_country_out_summary.csv", ///
        clear varnames(1)
    assert _N == 4
    assert inlist(term, "RENTS", "RENTS x INST")
    forvalues focal_i = 1/`=_N' {
        post `focal_post' ///
            (model[`focal_i']) ("LEAVE_ONE_COUNTRY_OUT") ///
            ("COEFFICIENT_RANGE") (term[`focal_i']) ///
            ("49_EXCLUSIONS") (.) (base_coefficient[`focal_i']) ///
            (.) (.) (.) (.) (base_coefficient[`focal_i']) (.) ///
            (min_coefficient[`focal_i']) (max_coefficient[`focal_i']) ///
            (min_p_value[`focal_i']) (max_p_value[`focal_i']) ///
            (sign_reversals[`focal_i'] == 0) (.) ///
            (`contract_sample_countries' - 1) (repetitions[`focal_i']) ///
            (.) (1) ("CLUSTER_COUNTRY") ("SENSITIVITY") (0) ///
            ("05_stability/leave_one_country_out_summary.csv") ///
            ("base_coefficient; min_coefficient; min_p_value; max_coefficient; max_p_value; sign_reversals") ///
            ("Rango entre 49 reestimaciones; no es un único coeficiente comparable con el M3.") ///
            (0)
    }
restore

* Incorporar la sensibilidad con tendencias lineales específicas por país.
preserve
    import delimited using ///
        "$OUTPUT_STABILITY/country_linear_trend_sensitivity.csv", ///
        clear varnames(1)
    assert _N == 6
    forvalues focal_i = 1/`=_N' {
        post `focal_post' ///
            (model[`focal_i']) ("COUNTRY_LINEAR_TRENDS") ///
            ("COEFFICIENT") (term[`focal_i']) ("FULL_SAMPLE") (.) ///
            (trend_coefficient[`focal_i']) ///
            (trend_standard_error[`focal_i']) (trend_p_value[`focal_i']) ///
            (trend_ci_lower[`focal_i']) (trend_ci_upper[`focal_i']) ///
            (base_coefficient[`focal_i']) (base_p_value[`focal_i']) ///
            (.) (.) (.) (.) (sign_stable[`focal_i']) ///
            (observations[`focal_i']) (countries[`focal_i']) ///
            (.) (0) (0) ("CLUSTER_COUNTRY") ///
            ("SENSITIVITY") (1) ///
            ("05_stability/country_linear_trend_sensitivity.csv") ///
            ("trend_coefficient; trend_standard_error; trend_p_value; trend_ci_lower; trend_ci_upper; base_coefficient; base_p_value") ///
            ("Mismo canal focal con tendencias lineales específicas por país.") ///
            (0)
    }
restore

* Incorporar por separado el coeficiente previo, el cambio desde 2014 y el
* coeficiente posterior. Estos tres resultados no comparten el mismo estimando.
preserve
    import delimited using ///
        "$OUTPUT_STABILITY/structural_stability_2014_coefficients.csv", ///
        clear varnames(1)
    assert _N == 6
    forvalues focal_i = 1/`=_N' {
        post `focal_post' ///
            (model[`focal_i']) ("REGIME_2014") ///
            ("PERIOD_COEFFICIENT") (term[`focal_i']) ///
            ("PRE_2014") (2014) (pre_coefficient[`focal_i']) ///
            (pre_standard_error[`focal_i']) (pre_p_value[`focal_i']) ///
            (pre_ci_lower[`focal_i']) (pre_ci_upper[`focal_i']) ///
            (.) (.) (.) (.) (.) (.) (sign_stable[`focal_i']) ///
            (observations[`focal_i']) (countries[`focal_i']) ///
            (.) (0) (0) ("CLUSTER_COUNTRY") ///
            ("SENSITIVITY") (0) ///
            ("05_stability/structural_stability_2014_coefficients.csv") ///
            ("pre_coefficient; pre_standard_error; pre_p_value; pre_ci_lower; pre_ci_upper") ///
            ("Coeficiente previo al corte externo; no equivale al coeficiente promedio del M3.") ///
            (significance_selected[`focal_i'])

        post `focal_post' ///
            (model[`focal_i']) ("REGIME_2014") ///
            ("COEFFICIENT_CHANGE") (term[`focal_i']) ///
            ("CHANGE_FROM_2014") (2014) ///
            (change_from_2014[`focal_i']) ///
            (change_standard_error[`focal_i']) (change_p_value[`focal_i']) ///
            (change_ci_lower[`focal_i']) (change_ci_upper[`focal_i']) ///
            (0) (.) (.) (.) (.) (.) (.) ///
            (observations[`focal_i']) (countries[`focal_i']) ///
            (.) (0) (0) ("CLUSTER_COUNTRY") ///
            ("SENSITIVITY") (0) ///
            ("05_stability/structural_stability_2014_coefficients.csv") ///
            ("change_from_2014; change_standard_error; change_p_value; change_ci_lower; change_ci_upper") ///
            ("Cambio desde 2014 respecto del periodo previo; su nulo es cambio igual a cero.") ///
            (significance_selected[`focal_i'])

        post `focal_post' ///
            (model[`focal_i']) ("REGIME_2014") ///
            ("PERIOD_COEFFICIENT") (term[`focal_i']) ///
            ("FROM_2014") (2014) (post_coefficient[`focal_i']) ///
            (post_standard_error[`focal_i']) (post_p_value[`focal_i']) ///
            (post_ci_lower[`focal_i']) (post_ci_upper[`focal_i']) ///
            (.) (.) (.) (.) (.) (.) (sign_stable[`focal_i']) ///
            (observations[`focal_i']) (countries[`focal_i']) ///
            (.) (0) (0) ("CLUSTER_COUNTRY") ///
            ("SENSITIVITY") (0) ///
            ("05_stability/structural_stability_2014_coefficients.csv") ///
            ("post_coefficient; post_standard_error; post_p_value; post_ci_lower; post_ci_upper") ///
            ("Coeficiente desde 2014; no equivale al coeficiente promedio del M3.") ///
            (significance_selected[`focal_i'])
    }
restore

* Incorporar el bootstrap como inferencia alternativa sobre los coeficientes
* principales, conservando el valor p convencional como referencia.
preserve
    import delimited using ///
        "$OUTPUT_STABILITY/wild_cluster_bootstrap.csv", ///
        clear varnames(1)
    assert _N == 6
    forvalues focal_i = 1/`=_N' {
        post `focal_post' ///
            (model[`focal_i']) ("WILD_CLUSTER_BOOTSTRAP") ///
            ("ALTERNATE_INFERENCE") (term[`focal_i']) ///
            ("FULL_SAMPLE") (.) (coefficient[`focal_i']) ///
            (.) (bootstrap_p[`focal_i']) ///
            (ci_lower[`focal_i']) (ci_upper[`focal_i']) ///
            (coefficient[`focal_i']) (conventional_p[`focal_i']) ///
            (.) (.) (.) (.) (1) ///
            (observations[`focal_i']) (countries[`focal_i']) ///
            (repetitions[`focal_i']) (0) (0) ///
            ("WILD_CLUSTER_BOOTSTRAP") (hierarchy[`focal_i']) (1) ///
            ("05_stability/wild_cluster_bootstrap.csv") ///
            ("coefficient; conventional_p; bootstrap_p; ci_lower; ci_upper; repetitions; seed") ///
            ("Mismo coeficiente del M3 con inferencia wild cluster bootstrap.") ///
            (significance_selected[`focal_i'])
    }
restore

* Incorporar los efectos marginales únicamente en percentiles observados de
* INST. Se identifican como un estimando distinto del coeficiente de RENTS.
preserve
    import delimited using ///
        "$OUTPUT_STABILITY/rents_marginal_effects_by_inst.csv", ///
        clear varnames(1)
    assert _N == 10
    assert inlist(institutional_percentile, "P10", "P25", "P50", "P75", "P90")
    forvalues focal_i = 1/`=_N' {
        post `focal_post' ///
            (model[`focal_i']) ("MARGINAL_EFFECTS") ///
            ("MARGINAL_EFFECT") ("dY/dRENTS") ///
            (institutional_percentile[`focal_i']) (inst_value[`focal_i']) ///
            (marginal_effect[`focal_i']) (standard_error[`focal_i']) ///
            (p_value[`focal_i']) (ci_lower[`focal_i']) ///
            (ci_upper[`focal_i']) (.) (.) (.) (.) (.) (.) (.) ///
            (`contract_sample_n') (`contract_sample_countries') ///
            (.) (0) (0) ("DELTA_METHOD_CLUSTER") ///
            ("SENSITIVITY") (0) ///
            ("05_stability/rents_marginal_effects_by_inst.csv") ///
            ("institutional_percentile; inst_value; marginal_effect; standard_error; p_value; ci_lower; ci_upper") ///
            ("Efecto marginal dentro del soporte observado de INST; no es el coeficiente aislado de RENTS.") ///
            (0)
    }
restore

postclose `focal_post'

* Validar cobertura, llave, procedencia y jerarquía antes de exportar.
preserve
    use "`focal_report'", clear
    assert _N == 58
    isid model method result_type term support_point
    assert inlist(model, "ECI", "DIVX")
    assert inlist(hierarchy, "MAIN", "SENSITIVITY")
    assert inlist(sample_changed, 0, 1)
    assert inlist(comparable_to_main, 0, 1)
    assert significance_selected == 0
    assert source_file != "" & source_fields != ""
    assert observations == `contract_sample_n' if sample_changed == 0
    assert observations < `contract_sample_n' if method == "INFLUENCE_EXCLUSION"
    assert missing(observations) if method == "LEAVE_ONE_COUNTRY_OUT"
    assert countries == `contract_sample_countries' ///
        if method != "LEAVE_ONE_COUNTRY_OUT"
    assert countries == `contract_sample_countries' - 1 ///
        if method == "LEAVE_ONE_COUNTRY_OUT"
    assert repetitions == 49 if method == "LEAVE_ONE_COUNTRY_OUT"
    assert repetitions == 9999 if method == "WILD_CLUSTER_BOOTSTRAP"
    quietly count if method == "MAIN_TWFE"
    assert r(N) == 6
    quietly count if method == "INFLUENCE_BASE"
    assert r(N) == 4
    quietly count if method == "INFLUENCE_EXCLUSION"
    assert r(N) == 4
    quietly count if method == "LEAVE_ONE_COUNTRY_OUT"
    assert r(N) == 4
    quietly count if method == "COUNTRY_LINEAR_TRENDS"
    assert r(N) == 6
    quietly count if method == "REGIME_2014"
    assert r(N) == 18
    quietly count if method == "WILD_CLUSTER_BOOTSTRAP"
    assert r(N) == 6
    quietly count if method == "MARGINAL_EFFECTS"
    assert r(N) == 10
    sort model method result_type term support_point
    format support_value estimate standard_error p_value ///
        ci_lower ci_upper reference_estimate reference_p_value ///
        estimate_min estimate_max p_value_at_min_estimate ///
        p_value_at_max_estimate %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/focal_robustness_evidence.csv", ///
        replace datafmt
restore

* Construir una segunda matriz para pruebas conjuntas. Separarla de los
* coeficientes impide tratar un contraste de hipótesis como si fuera un efecto.
tempname focal_joint_post
tempfile focal_joint_report

postfile `focal_joint_post' ///
    str8 model str32 method str48 hypothesis str40 test_target ///
    str24 statistic_type double statistic double numerator_df ///
    double denominator_df double p_value ///
    double reference_statistic double reference_p_value ///
    long observations int countries int repetitions byte sample_changed ///
    str28 inference_method str12 hierarchy byte comparable_to_main ///
    str100 source_file str160 source_fields ///
    str160 interpretation_scope byte significance_selected ///
    using "`focal_joint_report'", replace

* Prueba convencional del canal institucional en cada M3.
foreach focal_model in ECI DIVX {
    local focal_folder = lower("`focal_model'")
    local focal_section = cond("`focal_model'" == "ECI", 3, 4)
    preserve
        import delimited using ///
            "$OUTPUT_ROOT/0`focal_section'_`focal_folder'/`focal_folder'_twfe_joint_tests.csv", ///
            clear varnames(1)
        keep if order == 1
        assert _N == 1
        post `focal_joint_post' ///
            ("`focal_model'") ("MAIN_TWFE") ///
            ("RENTS_INST_INTERACTION_JOINT_ZERO") ///
            ("RENTS; INST; RENTS x INST") ///
            ("F_CLUSTER_ROBUST") (f_statistic[1]) ///
            (df1[1]) (df2[1]) (p_value[1]) (.) (.) ///
            (`contract_sample_n') (`contract_sample_countries') ///
            (.) (0) ("CLUSTER_COUNTRY") ("MAIN") (1) ///
            ("0`focal_section'_`focal_folder'/`focal_folder'_twfe_joint_tests.csv") ///
            ("f_statistic; df1; df2; p_value") ///
            ("Prueba conjunta convencional del canal focal en el M3.") ///
            (0)
    restore
}

* Pruebas conjuntas con tendencias específicas por país.
preserve
    import delimited using ///
        "$OUTPUT_STABILITY/country_linear_trend_joint_tests.csv", ///
        clear varnames(1)
    assert _N == 2
    forvalues focal_i = 1/`=_N' {
        post `focal_joint_post' ///
            (model[`focal_i']) ("COUNTRY_LINEAR_TRENDS") ///
            (hypothesis[`focal_i']) ("RENTS; INST; RENTS x INST") ///
            ("F_CLUSTER_ROBUST") (f_statistic[`focal_i']) ///
            (numerator_df[`focal_i']) (denominator_df[`focal_i']) ///
            (p_value[`focal_i']) (.) (.) ///
            (observations[`focal_i']) (countries[`focal_i']) ///
            (.) (0) ("CLUSTER_COUNTRY") ///
            (hierarchy[`focal_i']) (1) ///
            ("05_stability/country_linear_trend_joint_tests.csv") ///
            ("f_statistic; numerator_df; denominator_df; p_value") ///
            ("Prueba conjunta bajo tendencias lineales específicas por país.") ///
            (0)
    }
restore

* Prueba conjunta de ausencia de cambios focales desde el corte de 2014.
preserve
    import delimited using ///
        "$OUTPUT_STABILITY/structural_stability_2014_joint_tests.csv", ///
        clear varnames(1)
    assert _N == 2
    forvalues focal_i = 1/`=_N' {
        post `focal_joint_post' ///
            (model[`focal_i']) ("REGIME_2014") ///
            (hypothesis[`focal_i']) ///
            ("Cambios de RENTS; INST; RENTS x INST") ///
            ("F_CLUSTER_ROBUST") (f_statistic[`focal_i']) ///
            (numerator_df[`focal_i']) (denominator_df[`focal_i']) ///
            (p_value[`focal_i']) (.) (.) ///
            (observations[`focal_i']) (countries[`focal_i']) ///
            (.) (0) ("CLUSTER_COUNTRY") ///
            (hierarchy[`focal_i']) (0) ///
            ("05_stability/structural_stability_2014_joint_tests.csv") ///
            ("f_statistic; numerator_df; denominator_df; p_value; cutoff_year; externally_prespecified") ///
            ("Prueba de cambios desde un corte externo; no prueba conjunta del coeficiente promedio del M3.") ///
            (significance_selected[`focal_i'])
    }
restore

* Prueba conjunta wild cluster bootstrap, con el contraste convencional como
* referencia explícita y no como una prueba adicional seleccionada.
preserve
    import delimited using ///
        "$OUTPUT_STABILITY/wild_cluster_bootstrap_joint_tests.csv", ///
        clear varnames(1)
    assert _N == 2
    forvalues focal_i = 1/`=_N' {
        post `focal_joint_post' ///
            (model[`focal_i']) ("WILD_CLUSTER_BOOTSTRAP") ///
            (hypothesis[`focal_i']) ("RENTS; INST; RENTS x INST") ///
            ("WILD_CLUSTER_F") (bootstrap_f[`focal_i']) ///
            (numerator_df[`focal_i']) (denominator_df[`focal_i']) ///
            (bootstrap_p[`focal_i']) (conventional_f[`focal_i']) ///
            (conventional_p[`focal_i']) ///
            (observations[`focal_i']) (countries[`focal_i']) ///
            (repetitions[`focal_i']) (0) ///
            ("WILD_CLUSTER_BOOTSTRAP") ///
            (hierarchy[`focal_i']) (1) ///
            ("05_stability/wild_cluster_bootstrap_joint_tests.csv") ///
            ("bootstrap_f; bootstrap_p; conventional_f; conventional_p; numerator_df; denominator_df; repetitions; seed") ///
            ("Misma hipótesis focal del M3 con inferencia wild cluster bootstrap.") ///
            (significance_selected[`focal_i'])
    }
restore

postclose `focal_joint_post'

* Validar la llave, la muestra, la procedencia y la ausencia de selección por
* significancia en las ocho pruebas conjuntas consolidadas.
preserve
    use "`focal_joint_report'", clear
    assert _N == 8
    isid model method hypothesis
    assert inlist(model, "ECI", "DIVX")
    assert observations == `contract_sample_n'
    assert countries == `contract_sample_countries'
    assert sample_changed == 0
    assert significance_selected == 0
    assert source_file != "" & source_fields != ""
    assert inrange(p_value, 0, 1)
    assert repetitions == 9999 if method == "WILD_CLUSTER_BOOTSTRAP"
    quietly count if method == "MAIN_TWFE"
    assert r(N) == 2
    quietly count if method == "COUNTRY_LINEAR_TRENDS"
    assert r(N) == 2
    quietly count if method == "REGIME_2014"
    assert r(N) == 2
    quietly count if method == "WILD_CLUSTER_BOOTSTRAP"
    assert r(N) == 2
    sort model method hypothesis
    format statistic numerator_df denominator_df p_value ///
        reference_statistic reference_p_value %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/focal_joint_test_evidence.csv", ///
        replace datafmt
restore


// 11.11. Crear matrices de lectura y guía técnica de robustez

* Recuperar primero las pruebas conjuntas que contextualizan el bootstrap y el
* corte de 2014. Se guardan como escalares por modelo para incorporarlas a cada
* término sin realizar un cruce muchos-a-muchos.
preserve
    import delimited using ///
        "$OUTPUT_STABILITY/focal_joint_test_evidence.csv", ///
        clear varnames(1)
    assert _N == 8
    foreach reading_model in ECI DIVX {
        quietly summarize p_value if model == "`reading_model'" & ///
            method == "WILD_CLUSTER_BOOTSTRAP", meanonly
        assert r(N) == 1
        scalar reading_bootstrap_joint_`reading_model' = r(mean)

        quietly summarize p_value if model == "`reading_model'" & ///
            method == "REGIME_2014", meanonly
        assert r(N) == 1
        scalar reading_regime_joint_`reading_model' = r(mean)
    }
restore

* Construir una fila por modelo y término focal. INST conserva vacíos explícitos
* en influencia y leave-one-country-out porque esas fuentes solo evaluaron
* RENTS y RENTS x INST.
tempname reading_post
tempfile reading_report

postfile `reading_post' ///
    str8 model str16 term ///
    double main_estimate double main_standard_error double main_p_value ///
    double main_ci_lower double main_ci_upper ///
    double trend_estimate double trend_p_value ///
    double trend_abs_relative_change_pct byte trend_sign_same ///
    byte influence_available double influence_estimate ///
    double influence_p_value double influence_abs_change_pct ///
    byte influence_sign_same long influence_excluded_observations ///
    byte loo_available double loo_estimate_min double loo_estimate_max ///
    double loo_p_at_min_estimate double loo_p_at_max_estimate ///
    double loo_max_abs_deviation_pct byte loo_sign_same ///
    double bootstrap_p_value double bootstrap_ci_lower ///
    double bootstrap_ci_upper byte inference_agreement_5pct ///
    byte inference_agreement_10pct ///
    double pre_2014_estimate double from_2014_estimate ///
    double change_from_2014 double change_from_2014_p_value ///
    byte temporal_sign_same double bootstrap_joint_p_value ///
    double temporal_joint_change_p_value ///
    double comparable_estimate_min double comparable_estimate_max ///
    double max_abs_relative_deviation_pct ///
    byte comparable_sign_checks_passed byte comparable_sign_checks_total ///
    long observations int countries str100 source_files ///
    str160 interpretation_scope byte significance_selected ///
    using "`reading_report'", replace

preserve
    import delimited using ///
        "$OUTPUT_STABILITY/focal_robustness_evidence.csv", ///
        clear varnames(1)
    assert _N == 58
    isid model method result_type term support_point

    foreach reading_model in ECI DIVX {
        foreach reading_term in "RENTS" "INST" "RENTS x INST" {
            * Modelo principal y cobertura común.
            quietly summarize estimate if model == "`reading_model'" & ///
                term == "`reading_term'" & method == "MAIN_TWFE", meanonly
            assert r(N) == 1
            local reading_main_estimate = r(mean)
            assert abs(`reading_main_estimate') > 1e-12

            quietly summarize standard_error if model == "`reading_model'" & ///
                term == "`reading_term'" & method == "MAIN_TWFE", meanonly
            assert r(N) == 1
            local reading_main_se = r(mean)

            quietly summarize p_value if model == "`reading_model'" & ///
                term == "`reading_term'" & method == "MAIN_TWFE", meanonly
            assert r(N) == 1
            local reading_main_p = r(mean)

            quietly summarize ci_lower if model == "`reading_model'" & ///
                term == "`reading_term'" & method == "MAIN_TWFE", meanonly
            assert r(N) == 1
            local reading_main_ci_lower = r(mean)

            quietly summarize ci_upper if model == "`reading_model'" & ///
                term == "`reading_term'" & method == "MAIN_TWFE", meanonly
            assert r(N) == 1
            local reading_main_ci_upper = r(mean)

            quietly summarize observations if model == "`reading_model'" & ///
                term == "`reading_term'" & method == "MAIN_TWFE", meanonly
            assert r(N) == 1
            local reading_observations = r(mean)

            quietly summarize countries if model == "`reading_model'" & ///
                term == "`reading_term'" & method == "MAIN_TWFE", meanonly
            assert r(N) == 1
            local reading_countries = r(mean)

            * Sensibilidad con tendencias lineales por país.
            quietly summarize estimate if model == "`reading_model'" & ///
                term == "`reading_term'" & ///
                method == "COUNTRY_LINEAR_TRENDS", meanonly
            assert r(N) == 1
            local reading_trend_estimate = r(mean)

            quietly summarize p_value if model == "`reading_model'" & ///
                term == "`reading_term'" & ///
                method == "COUNTRY_LINEAR_TRENDS", meanonly
            assert r(N) == 1
            local reading_trend_p = r(mean)

            quietly summarize sign_stable if model == "`reading_model'" & ///
                term == "`reading_term'" & ///
                method == "COUNTRY_LINEAR_TRENDS", meanonly
            assert r(N) == 1
            local reading_trend_sign = r(mean)
            local reading_trend_relative = 100 * ///
                abs(`reading_trend_estimate' - `reading_main_estimate') / ///
                abs(`reading_main_estimate')

            * Exclusión de observaciones alertadas. La disponibilidad se guarda
            * como dato, no se rellena con el modelo base.
            quietly count if model == "`reading_model'" & ///
                term == "`reading_term'" & ///
                method == "INFLUENCE_EXCLUSION"
            local reading_influence_available = r(N)
            assert inlist(`reading_influence_available', 0, 1)
            local reading_influence_estimate = .
            local reading_influence_p = .
            local reading_influence_relative = .
            local reading_influence_sign = .
            local reading_influence_excluded = .
            if `reading_influence_available' == 1 {
                quietly summarize estimate if model == "`reading_model'" & ///
                    term == "`reading_term'" & ///
                    method == "INFLUENCE_EXCLUSION", meanonly
                local reading_influence_estimate = r(mean)
                quietly summarize p_value if model == "`reading_model'" & ///
                    term == "`reading_term'" & ///
                    method == "INFLUENCE_EXCLUSION", meanonly
                local reading_influence_p = r(mean)
                quietly summarize sign_stable if model == "`reading_model'" & ///
                    term == "`reading_term'" & ///
                    method == "INFLUENCE_EXCLUSION", meanonly
                local reading_influence_sign = r(mean)
                quietly summarize excluded_observations ///
                    if model == "`reading_model'" & ///
                    term == "`reading_term'" & ///
                    method == "INFLUENCE_EXCLUSION", meanonly
                local reading_influence_excluded = r(mean)
                local reading_influence_relative = 100 * ///
                    abs(`reading_influence_estimate' - ///
                    `reading_main_estimate') / abs(`reading_main_estimate')
            }

            * Rango de las 49 exclusiones individuales de países.
            quietly count if model == "`reading_model'" & ///
                term == "`reading_term'" & ///
                method == "LEAVE_ONE_COUNTRY_OUT"
            local reading_loo_available = r(N)
            assert inlist(`reading_loo_available', 0, 1)
            local reading_loo_min = .
            local reading_loo_max = .
            local reading_loo_p_min = .
            local reading_loo_p_max = .
            local reading_loo_relative = .
            local reading_loo_sign = .
            if `reading_loo_available' == 1 {
                quietly summarize estimate_min if model == "`reading_model'" & ///
                    term == "`reading_term'" & ///
                    method == "LEAVE_ONE_COUNTRY_OUT", meanonly
                local reading_loo_min = r(mean)
                quietly summarize estimate_max if model == "`reading_model'" & ///
                    term == "`reading_term'" & ///
                    method == "LEAVE_ONE_COUNTRY_OUT", meanonly
                local reading_loo_max = r(mean)
                quietly summarize p_value_at_min_estimate ///
                    if model == "`reading_model'" & ///
                    term == "`reading_term'" & ///
                    method == "LEAVE_ONE_COUNTRY_OUT", meanonly
                local reading_loo_p_min = r(mean)
                quietly summarize p_value_at_max_estimate ///
                    if model == "`reading_model'" & ///
                    term == "`reading_term'" & ///
                    method == "LEAVE_ONE_COUNTRY_OUT", meanonly
                local reading_loo_p_max = r(mean)
                quietly summarize sign_stable if model == "`reading_model'" & ///
                    term == "`reading_term'" & ///
                    method == "LEAVE_ONE_COUNTRY_OUT", meanonly
                local reading_loo_sign = r(mean)
                local reading_loo_relative = 100 * max( ///
                    abs(`reading_loo_min' - `reading_main_estimate'), ///
                    abs(`reading_loo_max' - `reading_main_estimate')) / ///
                    abs(`reading_main_estimate')
            }

            * Bootstrap: mismo coeficiente, inferencia alternativa.
            quietly summarize p_value if model == "`reading_model'" & ///
                term == "`reading_term'" & ///
                method == "WILD_CLUSTER_BOOTSTRAP", meanonly
            assert r(N) == 1
            local reading_bootstrap_p = r(mean)
            quietly summarize ci_lower if model == "`reading_model'" & ///
                term == "`reading_term'" & ///
                method == "WILD_CLUSTER_BOOTSTRAP", meanonly
            local reading_bootstrap_ci_lower = r(mean)
            quietly summarize ci_upper if model == "`reading_model'" & ///
                term == "`reading_term'" & ///
                method == "WILD_CLUSTER_BOOTSTRAP", meanonly
            local reading_bootstrap_ci_upper = r(mean)
            quietly summarize reference_p_value ///
                if model == "`reading_model'" & ///
                term == "`reading_term'" & ///
                method == "WILD_CLUSTER_BOOTSTRAP", meanonly
            assert r(N) == 1
            assert abs(r(mean) - `reading_main_p') < 1e-5
            local reading_inference_5 = ///
                (`reading_main_p' < 0.05) == (`reading_bootstrap_p' < 0.05)
            local reading_inference_10 = ///
                (`reading_main_p' < 0.10) == (`reading_bootstrap_p' < 0.10)

            * Corte externo de 2014: estimandos temporales separados.
            quietly summarize estimate if model == "`reading_model'" & ///
                term == "`reading_term'" & method == "REGIME_2014" & ///
                support_point == "PRE_2014", meanonly
            assert r(N) == 1
            local reading_pre_2014 = r(mean)
            quietly summarize estimate if model == "`reading_model'" & ///
                term == "`reading_term'" & method == "REGIME_2014" & ///
                support_point == "FROM_2014", meanonly
            assert r(N) == 1
            local reading_from_2014 = r(mean)
            quietly summarize estimate if model == "`reading_model'" & ///
                term == "`reading_term'" & method == "REGIME_2014" & ///
                support_point == "CHANGE_FROM_2014", meanonly
            assert r(N) == 1
            local reading_change_2014 = r(mean)
            quietly summarize p_value if model == "`reading_model'" & ///
                term == "`reading_term'" & method == "REGIME_2014" & ///
                support_point == "CHANGE_FROM_2014", meanonly
            assert r(N) == 1
            local reading_change_2014_p = r(mean)
            quietly summarize sign_stable if model == "`reading_model'" & ///
                term == "`reading_term'" & method == "REGIME_2014" & ///
                support_point == "FROM_2014", meanonly
            assert r(N) == 1
            local reading_temporal_sign = r(mean)

            * Resumir únicamente las comprobaciones comparables con el M3.
            local reading_comparable_min = min( ///
                `reading_main_estimate', `reading_trend_estimate')
            local reading_comparable_max = max( ///
                `reading_main_estimate', `reading_trend_estimate')
            local reading_max_relative = `reading_trend_relative'
            local reading_sign_passed = `reading_trend_sign'
            local reading_sign_total = 1
            if `reading_influence_available' == 1 {
                local reading_comparable_min = min( ///
                    `reading_comparable_min', `reading_influence_estimate', ///
                    `reading_loo_min')
                local reading_comparable_max = max( ///
                    `reading_comparable_max', `reading_influence_estimate', ///
                    `reading_loo_max')
                local reading_max_relative = max( ///
                    `reading_max_relative', `reading_influence_relative', ///
                    `reading_loo_relative')
                local reading_sign_passed = `reading_sign_passed' + ///
                    `reading_influence_sign' + `reading_loo_sign'
                local reading_sign_total = 3
            }

            post `reading_post' ///
                ("`reading_model'") ("`reading_term'") ///
                (`reading_main_estimate') (`reading_main_se') ///
                (`reading_main_p') (`reading_main_ci_lower') ///
                (`reading_main_ci_upper') (`reading_trend_estimate') ///
                (`reading_trend_p') (`reading_trend_relative') ///
                (`reading_trend_sign') (`reading_influence_available') ///
                (`reading_influence_estimate') (`reading_influence_p') ///
                (`reading_influence_relative') (`reading_influence_sign') ///
                (`reading_influence_excluded') (`reading_loo_available') ///
                (`reading_loo_min') (`reading_loo_max') ///
                (`reading_loo_p_min') (`reading_loo_p_max') ///
                (`reading_loo_relative') (`reading_loo_sign') ///
                (`reading_bootstrap_p') (`reading_bootstrap_ci_lower') ///
                (`reading_bootstrap_ci_upper') (`reading_inference_5') ///
                (`reading_inference_10') (`reading_pre_2014') ///
                (`reading_from_2014') (`reading_change_2014') ///
                (`reading_change_2014_p') (`reading_temporal_sign') ///
                (reading_bootstrap_joint_`reading_model') ///
                (reading_regime_joint_`reading_model') ///
                (`reading_comparable_min') (`reading_comparable_max') ///
                (`reading_max_relative') (`reading_sign_passed') ///
                (`reading_sign_total') (`reading_observations') ///
                (`reading_countries') ///
                ("focal_robustness_evidence.csv; focal_joint_test_evidence.csv") ///
                ("Comparables: M3, tendencias, influencia y LOO; bootstrap cambia inferencia; 2014 y márgenes cambian el estimando.") ///
                (0)
        }
    }
restore

postclose `reading_post'

* Validar la matriz de seis filas antes de exportarla.
preserve
    use "`reading_report'", clear
    assert _N == 6
    isid model term
    assert observations == `contract_sample_n'
    assert countries == `contract_sample_countries'
    assert main_ci_lower <= main_estimate & main_estimate <= main_ci_upper
    assert inrange(main_p_value, 0, 1)
    assert inrange(bootstrap_p_value, 0, 1)
    assert inrange(change_from_2014_p_value, 0, 1)
    assert inlist(inference_agreement_5pct, 0, 1)
    assert inlist(inference_agreement_10pct, 0, 1)
    assert influence_available == (term != "INST")
    assert loo_available == (term != "INST")
    assert comparable_sign_checks_total == 1 if term == "INST"
    assert comparable_sign_checks_total == 3 if term != "INST"
    assert inrange(comparable_sign_checks_passed, 0, ///
        comparable_sign_checks_total)
    assert max_abs_relative_deviation_pct >= 0
    assert source_files != ""
    assert significance_selected == 0
    gen byte model_order = cond(model == "ECI", 1, 2)
    gen byte term_order = cond(term == "RENTS", 1, ///
        cond(term == "INST", 2, 3))
    sort model_order term_order
    drop model_order term_order
    format main_estimate main_standard_error main_p_value ///
        main_ci_lower main_ci_upper trend_estimate trend_p_value ///
        influence_estimate influence_p_value loo_estimate_min ///
        loo_estimate_max loo_p_at_min_estimate loo_p_at_max_estimate ///
        bootstrap_p_value bootstrap_ci_lower bootstrap_ci_upper ///
        pre_2014_estimate from_2014_estimate change_from_2014 ///
        change_from_2014_p_value bootstrap_joint_p_value ///
        temporal_joint_change_p_value comparable_estimate_min ///
        comparable_estimate_max %12.6f
    format trend_abs_relative_change_pct ///
        influence_abs_change_pct ///
        loo_max_abs_deviation_pct ///
        max_abs_relative_deviation_pct %12.2f
    export delimited using ///
        "$OUTPUT_STABILITY/focal_robustness_reading_matrix.csv", ///
        replace datafmt
restore

* Resumir por modelo los cinco efectos marginales de RENTS dentro del soporte
* observado de INST. Esta tabla no se mezcla con los coeficientes del M3.
tempname support_post
tempfile support_report

postfile `support_post' ///
    str8 model int support_points double inst_min double inst_max ///
    double marginal_effect_min double marginal_effect_max ///
    int negative_points int positive_points int zero_points ///
    int significant_5_points int significant_10_points ///
    int ci_excludes_zero_points byte sign_consistent_across_support ///
    double p10_effect double p10_p_value ///
    double p50_effect double p50_p_value ///
    double p90_effect double p90_p_value ///
    long observations int countries str100 source_file ///
    str160 interpretation_scope byte significance_selected ///
    using "`support_report'", replace

preserve
    import delimited using ///
        "$OUTPUT_STABILITY/focal_robustness_evidence.csv", ///
        clear varnames(1)
    keep if method == "MARGINAL_EFFECTS"
    assert _N == 10
    foreach support_model in ECI DIVX {
        quietly count if model == "`support_model'"
        local support_points = r(N)
        assert `support_points' == 5

        quietly summarize support_value if model == "`support_model'", meanonly
        local support_inst_min = r(min)
        local support_inst_max = r(max)
        quietly summarize estimate if model == "`support_model'", meanonly
        local support_effect_min = r(min)
        local support_effect_max = r(max)
        quietly count if model == "`support_model'" & estimate < 0
        local support_negative = r(N)
        quietly count if model == "`support_model'" & estimate > 0
        local support_positive = r(N)
        quietly count if model == "`support_model'" & estimate == 0
        local support_zero = r(N)
        quietly count if model == "`support_model'" & p_value < 0.05
        local support_sig5 = r(N)
        quietly count if model == "`support_model'" & p_value < 0.10
        local support_sig10 = r(N)
        quietly count if model == "`support_model'" & ///
            (ci_lower > 0 | ci_upper < 0)
        local support_ci_excludes = r(N)
        local support_sign_consistent = ///
            (`support_negative' == 5 | `support_positive' == 5)

        foreach support_percentile in P10 P50 P90 {
            quietly summarize estimate if model == "`support_model'" & ///
                support_point == "`support_percentile'", meanonly
            assert r(N) == 1
            local support_`support_percentile'_effect = r(mean)
            quietly summarize p_value if model == "`support_model'" & ///
                support_point == "`support_percentile'", meanonly
            assert r(N) == 1
            local support_`support_percentile'_p = r(mean)
        }

        quietly summarize observations if model == "`support_model'", meanonly
        assert r(min) == r(max)
        local support_observations = r(mean)
        quietly summarize countries if model == "`support_model'", meanonly
        assert r(min) == r(max)
        local support_countries = r(mean)

        post `support_post' ///
            ("`support_model'") (`support_points') ///
            (`support_inst_min') (`support_inst_max') ///
            (`support_effect_min') (`support_effect_max') ///
            (`support_negative') (`support_positive') (`support_zero') ///
            (`support_sig5') (`support_sig10') (`support_ci_excludes') ///
            (`support_sign_consistent') ///
            (`support_P10_effect') (`support_P10_p') ///
            (`support_P50_effect') (`support_P50_p') ///
            (`support_P90_effect') (`support_P90_p') ///
            (`support_observations') (`support_countries') ///
            ("focal_robustness_evidence.csv") ///
            ("Cinco efectos marginales dentro de P10-P90 de INST; no equivalen al coeficiente aislado de RENTS.") ///
            (0)
    }
restore

postclose `support_post'

* Validar la tabla de soporte institucional.
preserve
    use "`support_report'", clear
    assert _N == 2
    isid model
    assert support_points == 5
    assert negative_points + positive_points + zero_points == support_points
    assert observations == `contract_sample_n'
    assert countries == `contract_sample_countries'
    assert inst_min[1] == inst_min[2]
    assert inst_max[1] == inst_max[2]
    assert inrange(significant_5_points, 0, support_points)
    assert inrange(significant_10_points, 0, support_points)
    assert inrange(ci_excludes_zero_points, 0, support_points)
    assert inlist(sign_consistent_across_support, 0, 1)
    assert source_file != ""
    assert significance_selected == 0
    gen byte model_order = cond(model == "ECI", 1, 2)
    sort model_order
    drop model_order
    format inst_min inst_max marginal_effect_min marginal_effect_max ///
        p10_effect p10_p_value p50_effect p50_p_value ///
        p90_effect p90_p_value %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/rents_marginal_support_summary.csv", ///
        replace datafmt
restore

* Calcular los conteos que alimentan la síntesis narrativa. Las afirmaciones
* del Markdown se regeneran con los datos y no quedan fijadas a este resultado.
preserve
    use "`reading_report'", clear
    local guide_focal_total = _N
    quietly count if inference_agreement_5pct == 1
    local guide_agreement_5 = r(N)
    quietly count if inference_agreement_10pct == 1
    local guide_agreement_10 = r(N)
    quietly count if term == "RENTS x INST" & trend_sign_same == 0
    local guide_interaction_trend_flips = r(N)
    quietly count if influence_available == 1 & influence_sign_same == 0
    local guide_influence_reversals = r(N)
    quietly count if loo_available == 1 & loo_sign_same == 0
    local guide_loo_reversals = r(N)
restore

preserve
    use "`support_report'", clear
    quietly summarize negative_points if model == "ECI", meanonly
    assert r(N) == 1
    local guide_eci_negative = r(mean)
    quietly summarize ci_excludes_zero_points if model == "ECI", meanonly
    assert r(N) == 1
    local guide_eci_ci_excludes = r(mean)
    quietly summarize negative_points if model == "DIVX", meanonly
    assert r(N) == 1
    local guide_divx_negative = r(mean)
    quietly summarize ci_excludes_zero_points if model == "DIVX", meanonly
    assert r(N) == 1
    local guide_divx_ci_excludes = r(mean)
restore

* Generar una guía técnica reproducible. Las tablas sustituyen un gráfico común
* porque los resultados combinan escalas, muestras y estimandos diferentes.
tempname reading_guide
file open `reading_guide' using ///
    "$OUTPUT_STABILITY/ROBUSTNESS_READING_GUIDE.md", ///
    write replace text

file write `reading_guide' ///
    "# Guía técnica para leer la robustez focal del M3" _n _n
file write `reading_guide' ///
    "Generada por 04_twfe_full.do el `c(current_date)'." _n _n
file write `reading_guide' "## Síntesis técnica" _n _n
file write `reading_guide' ///
    "La evidencia no admite una etiqueta única de robusto o no robusto. " ///
    "La lectura debe separar estabilidad de signo y magnitud, inferencia, " ///
    "cambios de muestra, estabilidad temporal y efectos marginales." _n _n
file write `reading_guide' ///
    "La inferencia convencional y el wild cluster bootstrap coinciden en la " ///
    "clasificación al 5 % para `guide_agreement_5' de " ///
    "`guide_focal_total' coeficientes y al 10 % para " ///
    "`guide_agreement_10' de `guide_focal_total'. Las tendencias lineales " ///
    "por país cambian el signo de RENTS x INST en " ///
    "`guide_interaction_trend_flips' de 2 modelos. La exclusión por " ///
    "influencia registra `guide_influence_reversals' reversiones entre " ///
    "4 coeficientes evaluados y leave-one-country-out registra " ///
    "`guide_loo_reversals'." _n _n
file write `reading_guide' ///
    "Los efectos marginales de RENTS son negativos en " ///
    "`guide_eci_negative' de 5 puntos observados de INST para ECI y en " ///
    "`guide_divx_negative' de 5 para DIVX. Sus intervalos excluyen cero en " ///
    "`guide_eci_ci_excludes' puntos para ECI y " ///
    "`guide_divx_ci_excludes' para DIVX." _n _n

file write `reading_guide' ///
    "## La estabilidad comparable difiere entre términos" _n _n
file write `reading_guide' ///
    "La columna de signos usa solo M3, tendencias, exclusión por influencia " ///
    "y leave-one-country-out. El cambio de 2014 se informa aparte porque " ///
    "corresponde a otro estimando." _n _n
file write `reading_guide' ///
    "| Modelo | Término | Coeficiente M3 | Signos comparables | Desvío máximo (%) | p bootstrap | p cambio 2014 | p cambio conjunto 2014 |" _n
file write `reading_guide' ///
    "|---|---|---:|---:|---:|---:|---:|---:|" _n

preserve
    use "`reading_report'", clear
    gen byte model_order = cond(model == "ECI", 1, 2)
    gen byte term_order = cond(term == "RENTS", 1, ///
        cond(term == "INST", 2, 3))
    sort model_order term_order
    forvalues guide_i = 1/`=_N' {
        local guide_model "`=model[`guide_i']'"
        local guide_term "`=term[`guide_i']'"
        local guide_main : display %9.6f main_estimate[`guide_i']
        local guide_sign_passed = comparable_sign_checks_passed[`guide_i']
        local guide_sign_total = comparable_sign_checks_total[`guide_i']
        local guide_deviation : display %9.2f ///
            max_abs_relative_deviation_pct[`guide_i']
        local guide_bootstrap : display %8.6f bootstrap_p_value[`guide_i']
        local guide_change : display %8.6f ///
            change_from_2014_p_value[`guide_i']
        local guide_change_joint : display %8.6f ///
            temporal_joint_change_p_value[`guide_i']
        file write `reading_guide' ///
            "| `guide_model' | `guide_term' | `guide_main' | " ///
            "`guide_sign_passed'/`guide_sign_total' | `guide_deviation' | " ///
            "`guide_bootstrap' | `guide_change' | `guide_change_joint' |" _n
    }
restore

file write `reading_guide' _n ///
    "El desvío porcentual puede ser grande cuando el coeficiente principal " ///
    "está próximo a cero. Por eso debe leerse junto con el rango de " ///
    "coeficientes y no como una puntuación de robustez." _n _n

file write `reading_guide' ///
    "## Efectos marginales dentro del soporte institucional" _n _n
file write `reading_guide' ///
    "| Modelo | Rango observado de INST | Rango del efecto marginal | Puntos negativos | IC que excluyen cero |" _n
file write `reading_guide' ///
    "|---|---:|---:|---:|---:|" _n

preserve
    use "`support_report'", clear
    gen byte model_order = cond(model == "ECI", 1, 2)
    sort model_order
    forvalues guide_i = 1/`=_N' {
        local guide_model "`=model[`guide_i']'"
        local guide_inst_min : display %8.3f inst_min[`guide_i']
        local guide_inst_max : display %8.3f inst_max[`guide_i']
        local guide_effect_min : display %9.6f marginal_effect_min[`guide_i']
        local guide_effect_max : display %9.6f marginal_effect_max[`guide_i']
        local guide_negative = negative_points[`guide_i']
        local guide_points = support_points[`guide_i']
        local guide_ci = ci_excludes_zero_points[`guide_i']
        file write `reading_guide' ///
            "| `guide_model' | [`guide_inst_min', `guide_inst_max'] | " ///
            "[`guide_effect_min', `guide_effect_max'] | " ///
            "`guide_negative'/`guide_points' | `guide_ci'/`guide_points' |" _n
    }
restore

file write `reading_guide' _n ///
    "Estos efectos marginales combinan RENTS y RENTS x INST. No deben " ///
    "interpretarse como el coeficiente aislado de RENTS ni extrapolarse " ///
    "fuera de P10-P90 de INST." _n _n

file write `reading_guide' ///
    "## Alcance, muestra y definiciones" _n _n
file write `reading_guide' ///
    "- Muestra principal: `contract_sample_n' observaciones, " ///
    "`contract_sample_countries' países y `contract_effective_years' años " ///
    "efectivos entre `contract_first_year' y `contract_last_year'." _n
file write `reading_guide' ///
    "- M3, tendencias y bootstrap conservan la muestra común." _n
file write `reading_guide' ///
    "- La exclusión por influencia modifica el número de observaciones; leave-one-country-out usa 48 países en cada repetición." _n
file write `reading_guide' ///
    "- Los resultados son asociaciones condicionadas con efectos fijos por país y año, no efectos causales." _n _n

file write `reading_guide' ///
    "## Método de síntesis" _n _n
file write `reading_guide' ///
    "La matriz compara signo, magnitud e incertidumbre solo cuando el " ///
    "estimando es comparable. El bootstrap se trata como inferencia " ///
    "alternativa sobre el mismo coeficiente; el corte de 2014 como cambio " ///
    "temporal; y los márgenes como derivadas evaluadas en valores observados " ///
    "de INST. Se usan tablas porque un gráfico común mezclaría escalas y " ///
    "estimandos diferentes." _n _n

file write `reading_guide' ///
    "## Limitaciones e incertidumbre" _n _n
file write `reading_guide' ///
    "- INST no fue evaluada en la exclusión por influencia ni en leave-one-country-out; sus celdas permanecen vacías." _n
file write `reading_guide' ///
    "- Las pruebas individuales del corte de 2014 no sustituyen la prueba conjunta preespecificada." _n
file write `reading_guide' ///
    "- La coincidencia de significancia entre métodos no demuestra estabilidad de magnitud ni causalidad." _n
file write `reading_guide' ///
    "- No se seleccionó ninguna especificación según su valor p." _n _n

file write `reading_guide' ///
    "## Siguiente paso recomendado" _n _n
file write `reading_guide' ///
    "Usar estas matrices como insumo para la comparación formal M1-M3 del " ///
    "archivo 05. La redacción debe distinguir resultados centrales, " ///
    "sensibilidades y cambios de estimando antes de incorporarse al TFM." _n _n

file write `reading_guide' ///
    "## Preguntas abiertas" _n _n
file write `reading_guide' ///
    "1. ¿La estabilidad de RENTS e INST se conserva al comparar M1, M2 y M3 sobre la misma muestra?" _n
file write `reading_guide' ///
    "2. ¿Las diferencias entre ECI y DIVX reflejan escala, precisión o canales estructurales distintos?" _n
file write `reading_guide' ///
    "3. ¿Las extensiones por petróleo-gas y minería modifican la lectura del resultado agregado?" _n

file close `reading_guide'

* El bloque genera síntesis y documentación; no deja una sensibilidad activa.
scalar drop reading_bootstrap_joint_ECI reading_bootstrap_joint_DIVX ///
    reading_regime_joint_ECI reading_regime_joint_DIVX


// 11.12. Cerrar la sección sin sustituir los modelos principales

* Recuperar la estimación DIVX principal para que la sección 8 encuentre los dos modelos base almacenados y ninguna sensibilidad activa por accidente.
estimates restore DIVX_TWFE_MAIN

* Informar las pruebas completadas y recordar su condición de sensibilidad.
display as result ///
    "Sección 7 completada: forma funcional, márgenes e influencia exportadas."
display as text ///
    "Las sensibilidades no sustituyen ECI_TWFE_MAIN ni DIVX_TWFE_MAIN."


// *****************************************************************************
// 12. Exportación de Resultados del Modelo Completo
// *****************************************************************************


// 12.1. Confirmar los modelos y resultados que alimentarán el paquete final

* Recuperar ECI y verificar que el objeto almacenado conserva la muestra aprobada. La sección 8 organiza resultados; no modifica la estimación.
estimates restore ECI_TWFE_MAIN
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == `eci_expected_n'
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == `eci_expected_countries'

* Recuperar DIVX y repetir las comprobaciones de cobertura antes de construir cualquier tabla comparativa.
estimates restore DIVX_TWFE_MAIN
* Validar automáticamente que la muestra contenga exactamente 1.044 observaciones.
assert e(N) == `divx_expected_n'
* Control de calidad automático que detiene el script si no se cumple la condición.
assert e(N_g) == `divx_expected_countries'

* Confirmar que ambos modelos continúan utilizando exactamente la misma muestra país-año, condición necesaria para su lectura conjunta.
assert `eci_expected_n' == `divx_expected_n'
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `eci_expected_countries' == `divx_expected_countries'
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `eci_expected_year_count' == `divx_expected_year_count'

* Verificar la existencia de los archivos numéricos generados en las secciones 5, 6 y 7. Si falta uno, el paquete final no debe presentarse como completo.
local prerequisite_files ///
    outputs/econometrics/stata-peer-2/01_twfe_main/03_eci/eci_twfe_coefficients.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/03_eci/eci_twfe_model_summary.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/03_eci/eci_twfe_joint_tests.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/04_divx/divx_twfe_coefficients.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/04_divx/divx_twfe_model_summary.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/04_divx/divx_twfe_joint_tests.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/rents_marginal_effects_by_inst.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/resource_coefficient_equality.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/per_capita_transformation_sensitivity.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/influential_observation_sensitivity.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/leave_one_country_out_summary.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/wild_cluster_bootstrap.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/wild_cluster_bootstrap_joint_tests.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/country_linear_trend_all_coefficients.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/focal_robustness_evidence.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/focal_joint_test_evidence.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/focal_robustness_reading_matrix.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/rents_marginal_support_summary.csv ///
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/ROBUSTNESS_READING_GUIDE.md

* Recorrer la lista anterior y detener la ejecución ante cualquier ausencia.
foreach prerequisite_file of local prerequisite_files {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "`prerequisite_file'"
    if _rc {
        display as error ///
            "Falta un resultado requerido para la sección 8:"
        display as error "`prerequisite_file'"
        exit 601
    }
}


// 12.2. Exportar la tabla econométrica principal ECI-DIVX

* Recuperar ambos modelos principales para que esttab utilice únicamente las especificaciones agregadas aprobadas.
estimates restore ECI_TWFE_MAIN
* Restaurar una estimación previa desde la memoria de Stata.
estimates restore DIVX_TWFE_MAIN

* Exportar una tabla LaTeX común. HHI aparece solo en ECI porque su inclusión en DIVX produciría una identidad contable.
esttab ECI_TWFE_MAIN DIVX_TWFE_MAIN ///
    using "$OUTPUT_FINAL/table_eci_divx_twfe.tex", ///
    replace ///
    booktabs ///
    label ///
    b(4) se(4) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("ECI" "DIVX") ///
    keep( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp ///
        vol rer ///
        humcap innov net ///
        log_gdppc govcons fin) ///
    order( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp ///
        vol rer ///
        humcap innov net ///
        log_gdppc govcons fin) ///
    coeflabels( ///
        rents "RENTS" ///
        inst "INST" ///
        c.rents#c.inst "RENTS x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        hhi "HHI" ///
        pexp "PEXP" ///
        fexp "FEXP" ///
        vol "VOL" ///
        rer "RER" ///
        humcap "HUMCAP" ///
        innov "INNOV" ///
        net "NET" ///
        log_gdppc "log(GDPPC)" ///
        govcons "GOVCONS" ///
        fin "FIN") ///
    stats(N N_g r2_w, ///
        fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within")) ///
    title( ///
        "Rentas extractivas, complejidad y diversificación exportadora") ///
    addnotes( ///
        "Errores estándar agrupados por país entre paréntesis." ///
        "Todos los modelos incluyen efectos fijos por país y año." ///
        "Los coeficientes representan asociaciones condicionadas, no efectos causales." ///
        "HHI se excluye de DIVX porque DIVX = 1 - HHI.")

* Exportar la misma tabla en texto plano para revisarla sin compilar LaTeX.
esttab ECI_TWFE_MAIN DIVX_TWFE_MAIN ///
    using "$OUTPUT_FINAL/table_eci_divx_twfe.txt", ///
    replace ///
    label ///
    compress ///
    b(4) se(4) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("ECI" "DIVX") ///
    keep( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp ///
        vol rer ///
        humcap innov net ///
        log_gdppc govcons fin) ///
    order( ///
        rents inst c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        hhi pexp fexp ///
        vol rer ///
        humcap innov net ///
        log_gdppc govcons fin) ///
    coeflabels( ///
        rents "RENTS" ///
        inst "INST" ///
        c.rents#c.inst "RENTS x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        hhi "HHI" ///
        pexp "PEXP" ///
        fexp "FEXP" ///
        vol "VOL" ///
        rer "RER" ///
        humcap "HUMCAP" ///
        innov "INNOV" ///
        net "NET" ///
        log_gdppc "log(GDPPC)" ///
        govcons "GOVCONS" ///
        fin "FIN") ///
    stats(N N_g r2_w, ///
        fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within")) ///
    addnotes( ///
        "Errores estándar agrupados por país entre paréntesis." ///
        "Efectos fijos por país y año en ambos modelos." ///
        "Resultados asociativos; no constituyen efectos causales.")

* Exportar una tabla LaTeX que compare la transformación principal ln(1+x) con los controles OILPC, GASPC y COALPC expresados en niveles per cápita.
esttab ///
    ECI_TWFE_MAIN ECI_PC_LEVELS_SENSITIVITY ///
    DIVX_TWFE_MAIN DIVX_PC_LEVELS_SENSITIVITY ///
    using "$OUTPUT_FINAL/table_per_capita_transformation_sensitivity.tex", ///
    replace ///
    booktabs ///
    label ///
    b(4) se(4) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles( ///
        "ECI: ln(1+x)" ///
        "ECI: niveles pc" ///
        "DIVX: ln(1+x)" ///
        "DIVX: niveles pc") ///
    keep( ///
        rents c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        oilpc gaspc coalpc) ///
    order( ///
        rents c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        oilpc gaspc coalpc) ///
    coeflabels( ///
        rents "RENTS agregado" ///
        c.rents#c.inst "RENTS x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        oilpc "OILPC en niveles" ///
        gaspc "GASPC en niveles" ///
        coalpc "COALPC en niveles") ///
    stats(N N_g r2_w, ///
        fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within")) ///
    title( ///
        "Sensibilidad a la transformación de las rentas per cápita") ///
    addnotes( ///
        "La alternativa cambia únicamente OILPC, GASPC y COALPC." ///
        "RENTS permanece agregado y con la misma definición en las cuatro columnas." ///
        "La especificación ln(1+x) es la principal; los niveles son una sensibilidad." ///
        "Errores estándar agrupados por país. Resultados asociativos.")

* Exportar la misma sensibilidad en texto plano para poder revisarla sin compilar LaTeX ni depender de software adicional.
esttab ///
    ECI_TWFE_MAIN ECI_PC_LEVELS_SENSITIVITY ///
    DIVX_TWFE_MAIN DIVX_PC_LEVELS_SENSITIVITY ///
    using "$OUTPUT_FINAL/table_per_capita_transformation_sensitivity.txt", ///
    replace ///
    label ///
    varwidth(24) ///
    modelwidth(18) ///
    b(4) se(4) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles( ///
        "ECI: ln(1+x)" ///
        "ECI: niveles pc" ///
        "DIVX: ln(1+x)" ///
        "DIVX: niveles pc") ///
    keep( ///
        rents c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        oilpc gaspc coalpc) ///
    order( ///
        rents c.rents#c.inst ///
        ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
        oilpc gaspc coalpc) ///
    coeflabels( ///
        rents "RENTS agregado" ///
        c.rents#c.inst "RENTS x INST" ///
        ln1p_oilpc "log(1 + OILPC)" ///
        ln1p_gaspc "log(1 + GASPC)" ///
        ln1p_coalpc "log(1 + COALPC)" ///
        oilpc "OILPC en niveles" ///
        gaspc "GASPC en niveles" ///
        coalpc "COALPC en niveles") ///
    stats(N N_g r2_w, ///
        fmt(0 0 3) ///
        labels("Observaciones" "Países" "R-cuadrado within")) ///
    addnotes( ///
        "Solo cambian OILPC, GASPC y COALPC; RENTS permanece agregado." ///
        "La especificación ln(1+x) es la principal." ///
        "Errores agrupados por país. Resultados asociativos.")


// 12.3. Consolidar coeficientes, resúmenes y pruebas conjuntas

* Combinar los coeficientes ECI y DIVX en un único archivo largo, conservando una columna que identifica el modelo de procedencia.
tempfile final_coefficients_dataset
preserve
    import delimited using ///
        "$OUTPUT_ECI/eci_twfe_coefficients.csv", ///
        clear varnames(1)
    generate str4 model = "ECI"
    tempfile eci_coefficients_final
    save "`eci_coefficients_final'", replace

    * Añadir los coeficientes DIVX con la misma estructura de columnas.
    import delimited using ///
        "$OUTPUT_DIVX/divx_twfe_coefficients.csv", ///
        clear varnames(1)
    generate str4 model = "DIVX"
    append using "`eci_coefficients_final'"
    order model order term variable_label channel
    sort model order

    * Verificar que el archivo reúne 17 términos ECI y 16 términos DIVX.
    quietly count
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert r(N) == 33
    bysort model: generate int terms_in_model = _N
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert terms_in_model == 17 if model == "ECI"
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert terms_in_model == 16 if model == "DIVX"
    drop terms_in_model

    * Guardar una copia temporal y exportar la versión final abierta.
    save "`final_coefficients_dataset'", replace
    export delimited using ///
        "$OUTPUT_FINAL/final_model_coefficients.csv", ///
        replace datafmt
restore

* Reunir los indicadores de cobertura y ajuste de los dos modelos.
preserve
    import delimited using ///
        "$OUTPUT_ECI/eci_twfe_model_summary.csv", ///
        clear varnames(1)
    generate str4 model_label = "ECI"
    tempfile eci_summary_final
    save "`eci_summary_final'", replace

    * Añadir el resumen DIVX y ordenar los modelos para su lectura conjunta.
    import delimited using ///
        "$OUTPUT_DIVX/divx_twfe_model_summary.csv", ///
        clear varnames(1)
    generate str4 model_label = "DIVX"
    append using "`eci_summary_final'"
    order model_label model dependent_variable
    sort model_label

    * Confirmar que existe una y solo una fila por modelo.
    isid model_label
    * Contar silenciosamente cuántas observaciones cumplen una condición determinada.
    quietly count
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert r(N) == 2

    * Exportar el resumen conjunto de cobertura y ajuste.
    export delimited using ///
        "$OUTPUT_FINAL/final_model_summaries.csv", ///
        replace datafmt
restore

* Reunir las ocho pruebas conjuntas de cada modelo dentro de un único reporte.
preserve
    import delimited using ///
        "$OUTPUT_ECI/eci_twfe_joint_tests.csv", ///
        clear varnames(1)
    generate str4 model = "ECI"
    tempfile eci_tests_final
    save "`eci_tests_final'", replace

    * Añadir las ocho pruebas DIVX y conservar su orden original.
    import delimited using ///
        "$OUTPUT_DIVX/divx_twfe_joint_tests.csv", ///
        clear varnames(1)
    generate str4 model = "DIVX"
    append using "`eci_tests_final'"
    order model order test null_hypothesis
    sort model order

    * Confirmar que cada modelo aporta exactamente ocho pruebas conjuntas.
    quietly count
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert r(N) == 16
    bysort model: assert _N == 8

    * Exportar el reporte conjunto de pruebas por canal y efectos temporales.
    export delimited using ///
        "$OUTPUT_FINAL/final_joint_tests.csv", ///
        replace datafmt
restore


// 12.4. Clasificar la evidencia sin convertir asociaciones en causalidad

* Abrir la base consolidada de coeficientes para asignar a cada término una categoría de lectura. Esta clasificación ordena la discusión, pero no altera coeficientes, errores estándar ni valores p.
preserve
    use "`final_coefficients_dataset'", clear

    * Traducir el valor p individual a una etiqueta descriptiva homogénea.
    generate str24 significance_level = "No significativo"
    replace significance_level = "Significativo al 10%" ///
        if p_value < 0.10
    replace significance_level = "Significativo al 5%" ///
        if p_value < 0.05
    replace significance_level = "Significativo al 1%" ///
        if p_value < 0.01

    * Registrar la dirección de la asociación estimada para facilitar la comparación de signos entre ECI y DIVX.
    generate str10 association_direction = ///
        cond(coefficient < 0, "Negativa", "Positiva")

    * Asignar inicialmente los regresores a la categoría de controles.
    generate str24 evidence_class = "Control"

    * Identificar la asociación agregada de RENTS como evidencia central.
    replace evidence_class = "Central" if term == "rents"

    * Identificar PEXP como evidencia comparativa central porque su signo significativo cambia entre complejidad y diversificación.
    replace evidence_class = "Central comparativa" if term == "pexp"

    * Mantener la interacción y la desagregación per cápita como evidencia no concluyente, dado que sus pruebas individuales y conjuntas no la respaldan.
    replace evidence_class = "No concluyente" ///
        if term == "c.rents#c.inst"
    replace evidence_class = "No concluyente" ///
        if inlist(term, ///
            "ln1p_oilpc", "ln1p_gaspc", "ln1p_coalpc")

    * Clasificar los resultados significativos restantes como complementarios, porque no constituyen por sí solos la hipótesis central del TFM.
    replace evidence_class = "Complementaria" ///
        if model == "ECI" & ///
        inlist(term, "inst", "hhi", "fexp")
    replace evidence_class = "Complementaria" ///
        if model == "DIVX" & ///
        inlist(term, "humcap", "net", "log_gdppc", "govcons")

    * Crear una nota interpretativa específica para cada familia de evidencia.
    generate str160 interpretation_note = ///
        "Control incluido en la especificación; interpretar con cautela."
    replace interpretation_note = ///
        "Asociación agregada central; la estabilidad se evalúa en la sección 7 y no implica causalidad." ///
        if term == "rents"
    replace interpretation_note = ///
        "El signo opuesto entre modelos distingue diversificación exportadora y complejidad económica." ///
        if term == "pexp"
    replace interpretation_note = ///
        "No hay evidencia estadística suficiente de moderación institucional." ///
        if term == "c.rents#c.inst"
    replace interpretation_note = ///
        "No se distingue una asociación individual robusta por recurso en esta especificación agregada." ///
        if inlist(term, ///
            "ln1p_oilpc", "ln1p_gaspc", "ln1p_coalpc")
    replace interpretation_note = ///
        "Resultado complementario del modelo ECI; no constituye evidencia causal." ///
        if model == "ECI" & ///
        inlist(term, "inst", "hhi", "fexp")
    replace interpretation_note = ///
        "Resultado complementario DIVX; requiere sensibilidad específica antes de una interpretación estructural." ///
        if model == "DIVX" & ///
        inlist(term, "humcap", "net", "log_gdppc", "govcons")

    * Ordenar y exportar la matriz completa de evidencia para la discusión.
    order model order term variable_label channel ///
        evidence_class association_direction significance_level ///
        coefficient standard_error p_value ci_lower ci_upper ///
        interpretation_note
    sort model order
    export delimited using ///
        "$OUTPUT_FINAL/evidence_classification.csv", ///
        replace datafmt
restore


// 12.5. Reunir las sensibilidades y figuras finales

* Copiar al paquete final los efectos marginales numéricos sin modificar el archivo original de la sección 7.
copy ///
    "$OUTPUT_STABILITY/rents_marginal_effects_by_inst.csv" ///
    "$OUTPUT_FINAL/final_rents_marginal_effects_by_inst.csv", ///
    replace

* Copiar la sensibilidad que excluye las observaciones previamente alertadas.
copy ///
    "$OUTPUT_STABILITY/influential_observation_sensitivity.csv" ///
    "$OUTPUT_FINAL/final_influential_observation_sensitivity.csv", ///
    replace

* Copiar el resumen de las 49 exclusiones individuales de países.
copy ///
    "$OUTPUT_STABILITY/leave_one_country_out_summary.csv" ///
    "$OUTPUT_FINAL/final_leave_one_country_out_summary.csv", ///
    replace

* Copiar la inferencia wild cluster bootstrap para RENTS y su interacción.
copy ///
    "$OUTPUT_STABILITY/wild_cluster_bootstrap.csv" ///
    "$OUTPUT_FINAL/final_wild_cluster_bootstrap.csv", ///
    replace

* Copiar la prueba de igualdad entre petróleo, gas y carbón de ambos modelos.
copy ///
    "$OUTPUT_STABILITY/resource_coefficient_equality.csv" ///
    "$OUTPUT_FINAL/final_resource_coefficient_equality.csv", ///
    replace

* Copiar la sensibilidad de forma funcional de OILPC, GASPC y COALPC. El nombre evita confundirla con una modificación de RENTS o con una desagregación.
copy ///
    "$OUTPUT_STABILITY/per_capita_transformation_sensitivity.csv" ///
    "$OUTPUT_FINAL/final_per_capita_transformation_sensitivity.csv", ///
    replace

* Copiar las matrices consolidadas que preservan tipo de resultado, soporte,
* cobertura, comparabilidad y procedencia exacta.
copy ///
    "$OUTPUT_STABILITY/focal_robustness_evidence.csv" ///
    "$OUTPUT_FINAL/final_focal_robustness_evidence.csv", ///
    replace
copy ///
    "$OUTPUT_STABILITY/focal_joint_test_evidence.csv" ///
    "$OUTPUT_FINAL/final_focal_joint_test_evidence.csv", ///
    replace

* Copiar los dos resúmenes de lectura y la guía técnica sin alterar sus fuentes.
copy ///
    "$OUTPUT_STABILITY/focal_robustness_reading_matrix.csv" ///
    "$OUTPUT_FINAL/final_focal_robustness_reading_matrix.csv", ///
    replace
copy ///
    "$OUTPUT_STABILITY/rents_marginal_support_summary.csv" ///
    "$OUTPUT_FINAL/final_rents_marginal_support_summary.csv", ///
    replace
copy ///
    "$OUTPUT_STABILITY/country_linear_trend_all_coefficients.csv" ///
    "$OUTPUT_FINAL/final_country_linear_trend_all_coefficients.csv", ///
    replace
copy ///
    "$OUTPUT_STABILITY/ROBUSTNESS_READING_GUIDE.md" ///
    "$OUTPUT_FINAL/ROBUSTNESS_READING_GUIDE.md", ///
    replace

* Combinar las dos figuras marginales conservando escalas verticales propias, pues ECI y DIVX se expresan en magnitudes distintas.
graph combine eci_rents_margins divx_rents_margins, ///
    cols(2) ///
    graphregion(color(white)) ///
    title( ///
        "Asociación marginal de RENTS según calidad institucional", ///
        size(medsmall)) ///
    subtitle( ///
        "Modelos TWFE; intervalos de confianza del 95 %", ///
        size(small)) ///
    note( ///
        "Resultados asociativos. La interacción RENTS x INST no es significativa en ninguno de los modelos.", ///
        size(vsmall)) ///
    name(final_rents_margins, replace)

* Exportar la figura comparada en PDF para LaTeX.
graph export ///
    "$OUTPUT_FINAL/figure_rents_marginal_effects_eci_divx.pdf", ///
    replace

* Exportar también una versión PNG para inspección visual inmediata.
graph export ///
    "$OUTPUT_FINAL/figure_rents_marginal_effects_eci_divx.png", ///
    width(3000) replace


// 12.6. Crear el índice reproducible de resultados

* Abrir un archivo Markdown que explique la función de cada familia de outputs.
tempname results_index
file open `results_index' using ///
    "$OUTPUT_FINAL/RESULTS_INDEX.md", ///
    write replace text

* Escribir la identificación y el alcance del paquete final.
file write `results_index' ///
    "# Índice de resultados econométricos agregados" _n _n
file write `results_index' ///
    "Generado por 04_twfe_full.do el `c(current_date)'." _n _n
file write `results_index' ///
    "Este paquete corresponde a los modelos agregados de RENTS. " ///
    "No contiene la futura desagregación hidrocarburos-minería." _n _n

* Documentar los archivos principales que alimentan la discusión del TFM.
file write `results_index' ///
    "## Resultados finales" _n _n
file write `results_index' ///
    "- table_eci_divx_twfe.tex: tabla LaTeX conjunta de los modelos principales." _n
file write `results_index' ///
    "- table_eci_divx_twfe.txt: versión en texto plano para revisión." _n
file write `results_index' ///
    "- table_per_capita_transformation_sensitivity.tex: sensibilidad LaTeX de ln(1+x) frente a niveles per cápita." _n
file write `results_index' ///
    "- table_per_capita_transformation_sensitivity.txt: versión de texto de la sensibilidad de transformación." _n
file write `results_index' ///
    "- final_model_coefficients.csv: coeficientes e incertidumbre de ECI y DIVX." _n
file write `results_index' ///
    "- final_model_summaries.csv: muestra, cobertura y ajuste de ambos modelos." _n
file write `results_index' ///
    "- final_joint_tests.csv: pruebas conjuntas por canal y efectos de año." _n
file write `results_index' ///
    "- evidence_classification.csv: clasificación de evidencia central, complementaria y no concluyente." _n _n

* Documentar las sensibilidades que respaldan o limitan la lectura principal.
file write `results_index' ///
    "## Estabilidad y efectos marginales" _n _n
file write `results_index' ///
    "- final_rents_marginal_effects_by_inst.csv: asociación marginal de RENTS en P10, P25, P50, P75 y P90 de INST." _n
file write `results_index' ///
    "- final_influential_observation_sensitivity.csv: comparación con exclusión de observaciones alertadas." _n
file write `results_index' ///
    "- final_leave_one_country_out_summary.csv: estabilidad al retirar un país por vez." _n
file write `results_index' ///
    "- final_wild_cluster_bootstrap.csv: inferencia bootstrap agrupada por país." _n
file write `results_index' ///
    "- final_resource_coefficient_equality.csv: igualdad entre petróleo, gas y carbón." _n
file write `results_index' ///
    "- final_per_capita_transformation_sensitivity.csv: comparación de ln(1+x) con OILPC, GASPC y COALPC en niveles." _n
file write `results_index' ///
    "- final_focal_robustness_evidence.csv: matriz trazable de 58 resultados focales, separada por estimando y método." _n
file write `results_index' ///
    "- final_focal_joint_test_evidence.csv: ocho pruebas conjuntas focales con inferencia y nulos explícitos." _n
file write `results_index' ///
    "- final_focal_robustness_reading_matrix.csv: lectura de signo, magnitud, inferencia, muestra y estabilidad temporal para seis coeficientes." _n
file write `results_index' ///
    "- final_rents_marginal_support_summary.csv: resumen de los cinco efectos marginales dentro del soporte observado de INST." _n
file write `results_index' ///
    "- final_country_linear_trend_all_coefficients.csv: comparación base-tendencias para los 33 coeficientes sustantivos de ECI y DIVX." _n
file write `results_index' ///
    "- ROBUSTNESS_READING_GUIDE.md: guía técnica reproducible para interpretar las matrices sin una etiqueta binaria de robustez." _n
file write `results_index' ///
    "- figure_rents_marginal_effects_eci_divx.pdf: figura comparada para LaTeX." _n
file write `results_index' ///
    "- figure_rents_marginal_effects_eci_divx.png: figura comparada para revisión visual." _n _n

* Registrar las reglas de interpretación que deben acompañar los resultados.
file write `results_index' ///
    "## Reglas de interpretación" _n _n
file write `results_index' ///
    "1. Los coeficientes describen asociaciones condicionadas dentro de los países; no identifican efectos causales." _n
file write `results_index' ///
    "2. RENTS debe interpretarse junto con los efectos marginales porque el modelo incluye RENTS x INST." _n
file write `results_index' ///
    "3. La interacción institucional es no concluyente en ambos modelos." _n
file write `results_index' ///
    "4. Las sensibilidades no sustituyen las especificaciones ECI_TWFE_MAIN y DIVX_TWFE_MAIN." _n
file write `results_index' ///
    "5. La sensibilidad de forma funcional solo cambia OILPC, GASPC y COALPC; RENTS permanece agregado." _n
file write `results_index' ///
    "6. HHI se excluye de DIVX porque DIVX = 1 - HHI." _n
file write `results_index' ///
    "7. La robustez se evalúa por estabilidad de signo, magnitud, incertidumbre, muestra y estimando; no solo por significancia." _n _n

* Cerrar el índice para asegurar que todo el contenido quede escrito en disco.
file close `results_index'


// 12.7. Crear el manifiesto y validar el paquete final

* Preparar un manifiesto legible por máquina con la finalidad de cada archivo.
tempname manifest_post
tempfile manifest_report
* Crear un archivo temporal para ir registrando resultados calculados.
postfile `manifest_post' ///
    int order ///
    str24 family ///
    str100 file ///
    str160 purpose ///
    using "`manifest_report'", replace

* Registrar la tabla común en sus dos formatos de revisión.
post `manifest_post' ///
    (1) ("Modelos principales") ///
    ("table_eci_divx_twfe.tex") ///
    ("Tabla LaTeX conjunta ECI-DIVX con errores agrupados por país.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (2) ("Modelos principales") ///
    ("table_eci_divx_twfe.txt") ///
    ("Versión de texto plano de la tabla econométrica principal.")

* Registrar los archivos numéricos consolidados.
post `manifest_post' ///
    (3) ("Resultados numéricos") ///
    ("final_model_coefficients.csv") ///
    ("Coeficientes, errores, valores p e intervalos de ambos modelos.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (4) ("Resultados numéricos") ///
    ("final_model_summaries.csv") ///
    ("Cobertura, ajuste y componentes de varianza de ECI y DIVX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (5) ("Resultados numéricos") ///
    ("final_joint_tests.csv") ///
    ("Pruebas conjuntas por canal, efectos temporales e igualdad de recursos.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (6) ("Interpretación") ///
    ("evidence_classification.csv") ///
    ("Clasificación no causal de evidencia central, complementaria y no concluyente.")

* Registrar las seis familias de sensibilidad.
post `manifest_post' ///
    (7) ("Estabilidad") ///
    ("final_rents_marginal_effects_by_inst.csv") ///
    ("Efectos marginales de RENTS en percentiles institucionales.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (8) ("Estabilidad") ///
    ("final_influential_observation_sensitivity.csv") ///
    ("Sensibilidad a observaciones potencialmente influyentes.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (9) ("Estabilidad") ///
    ("final_leave_one_country_out_summary.csv") ///
    ("Resumen de exclusiones individuales de los 49 países.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (10) ("Estabilidad") ///
    ("final_wild_cluster_bootstrap.csv") ///
    ("Contraste bootstrap de RENTS y RENTS x INST.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (11) ("Estabilidad") ///
    ("final_resource_coefficient_equality.csv") ///
    ("Prueba de igualdad entre petróleo, gas y carbón.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (12) ("Estabilidad") ///
    ("final_per_capita_transformation_sensitivity.csv") ///
    ("Comparación de ln(1+x) con controles per cápita en niveles.")

* Registrar las matrices focales consolidadas y trazables.
post `manifest_post' ///
    (13) ("Estabilidad") ///
    ("final_focal_robustness_evidence.csv") ///
    ("Matriz de resultados focales separada por estimando, método y soporte.")
post `manifest_post' ///
    (14) ("Estabilidad") ///
    ("final_focal_joint_test_evidence.csv") ///
    ("Pruebas conjuntas focales con hipótesis, inferencia y procedencia explícitas.")

* Registrar los productos de lectura técnica del bloque de cierre.
post `manifest_post' ///
    (15) ("Estabilidad") ///
    ("final_focal_robustness_reading_matrix.csv") ///
    ("Matriz de lectura de signo, magnitud, inferencia, muestra y estabilidad temporal.")
post `manifest_post' ///
    (16) ("Estabilidad") ///
    ("final_rents_marginal_support_summary.csv") ///
    ("Resumen de efectos marginales de RENTS dentro del soporte observado de INST.")
post `manifest_post' ///
    (17) ("Documentación") ///
    ("ROBUSTNESS_READING_GUIDE.md") ///
    ("Guía técnica reproducible para la lectura multidimensional de robustez.")

* Registrar las dos versiones de la tabla de sensibilidad de forma funcional.
post `manifest_post' ///
    (18) ("Tablas de sensibilidad") ///
    ("table_per_capita_transformation_sensitivity.tex") ///
    ("Tabla LaTeX de sensibilidad a la transformación per cápita.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (19) ("Tablas de sensibilidad") ///
    ("table_per_capita_transformation_sensitivity.txt") ///
    ("Versión de texto de la sensibilidad a la transformación per cápita.")

* Registrar la figura comparada y el índice explicativo.
post `manifest_post' ///
    (20) ("Figuras") ///
    ("figure_rents_marginal_effects_eci_divx.pdf") ///
    ("Figura comparada ECI-DIVX en formato apto para LaTeX.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (21) ("Figuras") ///
    ("figure_rents_marginal_effects_eci_divx.png") ///
    ("Figura comparada para inspección visual.")
* Escribir una fila de resultados dentro del archivo temporal.
post `manifest_post' ///
    (22) ("Documentación") ///
    ("RESULTS_INDEX.md") ///
    ("Índice, alcance y reglas de interpretación del paquete final.")

* Registrar el contraste completo que ya produce la estimación con tendencias.
post `manifest_post' ///
    (23) ("Estabilidad") ///
    ("final_country_linear_trend_all_coefficients.csv") ///
    ("Comparación base-tendencias para todos los regresores sustantivos.")

* Cerrar y exportar el manifiesto después de registrar sus veintitrés entradas.
postclose `manifest_post'
preserve
    use "`manifest_report'", clear
    sort order
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 23
    export delimited using ///
        "$OUTPUT_FINAL/results_manifest.csv", ///
        replace datafmt
restore

* Verificar que cada archivo anunciado por el manifiesto existe realmente.
local final_required_files ///
    table_eci_divx_twfe.tex ///
    table_eci_divx_twfe.txt ///
    final_model_coefficients.csv ///
    final_model_summaries.csv ///
    final_joint_tests.csv ///
    evidence_classification.csv ///
    final_rents_marginal_effects_by_inst.csv ///
    final_influential_observation_sensitivity.csv ///
    final_leave_one_country_out_summary.csv ///
    final_wild_cluster_bootstrap.csv ///
    final_resource_coefficient_equality.csv ///
    final_per_capita_transformation_sensitivity.csv ///
    final_focal_robustness_evidence.csv ///
    final_focal_joint_test_evidence.csv ///
    final_focal_robustness_reading_matrix.csv ///
    final_rents_marginal_support_summary.csv ///
    final_country_linear_trend_all_coefficients.csv ///
    ROBUSTNESS_READING_GUIDE.md ///
    table_per_capita_transformation_sensitivity.tex ///
    table_per_capita_transformation_sensitivity.txt ///
    figure_rents_marginal_effects_eci_divx.pdf ///
    figure_rents_marginal_effects_eci_divx.png ///
    RESULTS_INDEX.md ///
    results_manifest.csv

* Detener la ejecución si una salida final no fue creada correctamente.
foreach final_file of local final_required_files {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file ///
        "outputs/econometrics/stata-peer-2/01_twfe_main/06_final/`final_file'"
    if _rc {
        display as error ///
            "La sección 8 no pudo crear el archivo final:"
        display as error ///
            "outputs/econometrics/stata-peer-2/01_twfe_main/06_final/`final_file'"
        exit 603
    }
}

* Verificar nuevamente el número de filas de las consolidaciones principales.
preserve
    import delimited using ///
        "$OUTPUT_FINAL/final_model_coefficients.csv", ///
        clear varnames(1)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 33
restore

* Confirmar que el contraste completo de tendencias conserva los 33 términos
* sustantivos y la diferencia contable entre las ecuaciones ECI y DIVX.
preserve
    import delimited using ///
        "$OUTPUT_FINAL/final_country_linear_trend_all_coefficients.csv", ///
        clear varnames(1)
    assert _N == 33
    isid model term
    quietly count if model == "ECI"
    assert r(N) == 17
    quietly count if model == "DIVX"
    assert r(N) == 16
    assert term != "hhi" if model == "DIVX"
restore

* Confirmar que la matriz final contiene las 16 pruebas conjuntas previstas.
preserve
    import delimited using ///
        "$OUTPUT_FINAL/final_joint_tests.csv", ///
        clear varnames(1)
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert _N == 16
restore

* Informar el cierre exitoso y recordar el alcance agregado del archivo.
display as result ///
    "Sección 8 completada: paquete final agregado creado y validado."
display as result ///
    "Archivos finales: $OUTPUT_FINAL"
display as text ///
    "La desagregación hidrocarburos-minería queda fuera de este archivo."

* Cerrar el registro después de completar y validar las secciones 9 a 12.
display as result "Archivo 04 finalizado sin errores."
log close models_log
