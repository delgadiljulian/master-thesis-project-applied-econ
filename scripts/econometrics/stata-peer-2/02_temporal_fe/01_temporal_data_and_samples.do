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
// Módulo: 02_temporal_fe — Efectos fijos y orden temporal
// Archivo: 01_temporal_data_and_samples.do (Versión Codex)
// Contenido: Secciones 1 a 6 — preparación del panel, construcción temporal
//            y muestras T0--T5
// Continuación: 02_lagged_and_cumulative_models.do
// Insumo principal: data/processed/00_master_panel/
//                   master_panel_country_year.dta
// Fecha: Segundo Cuatrimestre 2026
//
// ESTADO: IMPLEMENTADO Y VALIDADO EN STATA 17.
// *****************************************************************************


// *****************************************************************************
// PROPÓSITO, ALCANCE Y CONTRATO ECONOMÉTRICO DEL ARCHIVO 01
// *****************************************************************************
//
// 1. OBJETIVO DEL MÓDULO TEMPORAL:
//    Este archivo inicia el módulo de diagnóstico de orden temporal y dinámica panel.
//    Convierte el panel maestro congelado (1996--2021, N=1430) en una base temporal
//    rigurosa y auditable, definiendo las submuestras analíticas T0--T5.
//
// 2. ESPECIFICACIONES TEMPORALES EVALUADAS:
//    - T0 (Contemporáneo / Baseline): Y_it = f(RENTS_it, INST_it, RENTS_it × INST_it, X_it)
//    - T1 (Rezago 1 año):           Y_it = f(RENTS_i,t-1, INST_i,t-1, RENTS_i,t-1 × INST_i,t-1, X_i,t-1)
//    - T2 (Rezago 2 años):          Y_it = f(RENTS_i,t-2, INST_i,t-2, RENTS_i,t-2 × INST_i,t-2, X_i,t-2)
//    - T3 (Promedio trienal t..t-2):Y_it = f(bar(RENTS)_i,t-2..t, bar(INST)_i,t-2..t, bar(X)_i,t-2..t)
//    - T4 (Placebo / Adelanto t+1): Y_it = f(RENTS_i,t+1, INST_i,t+1, RENTS_i,t+1 × INST_i,t+1, X_i,t+1)
//    - T5 (Primeras diferencias):   Delta Y_it = f(Delta RENTS_it, Delta INST_it, Delta X_it)
//
// 3. REGLAS DE INTEGRIDAD EN PANEL:
//    - Todas las transformaciones se construyen sobre la estructura xtset country_id year.
//    - Un rezago L1.X solo es válido si existe continuidad de año (year - year[_n-1] == 1).
//    - El promedio móvil trienal exige presencia continua en t, t-1 y t-2.
//    - Las submuestras ECI y DIVX se auditan separadamente para garantizar N=1044 en T0.
//    - Cada pérdida de observaciones por efecto de rezagos/diferencias se documenta en CSV.
//
// 4. ENTRADAS Y SALIDAS DEL PROCESO:
//    - Entradas: data/processed/00_master_panel/master_panel_country_year.dta
//    - Salidas:  00_design/temporal_specification_register.csv
//               01_sample/temporal_sample_summary.csv
//               01_sample/temporal_sample_by_country.csv
//               01_sample/temporal_sample_by_year.csv
//               01_sample/temporal_panel.dta
//               logs/01_temporal_data_and_samples.log
// *****************************************************************************

// *****************************************************************************
// 1. Configuración reproducible del entorno
// *****************************************************************************

// 1.1. Limpiar la sesión y fijar la versión de Stata

* La configuración replica las convenciones del modelo TWFE principal.
* La precisión y las semillas permiten repetir los resultados sin cambios.

* Limpiar la sesión y cerrar cualquier log que haya quedado abierto.
version 17.0
clear all
cls
macro drop _all
capture log close _all

* Fijar opciones reproducibles comunes a los tres archivos del módulo temporal.
set more off
set varabbrev off
set type double
set linesize 255
set seed 20260729
set sortseed 20260729


// 1.2. Localizar la raíz del repositorio

* El panel maestro permite identificar automáticamente la raíz del proyecto.
* La búsqueda ascendente funciona desde distintas carpetas del proyecto.

* Definir el marcador relativo que debe existir en la raíz del repositorio.
local panel_relative ///
    "data/processed/00_master_panel/master_panel_country_year.dta"

* Registrar el directorio inicial y las dos rutas alternativas permitidas.
local project_current "`c(pwd)'"
local project_windows ///
    "C:/Users/`c(username)'/GitHub/master-thesis-project-applied-econ"
local project_manual ""
global PROJECT_ROOT ""

* Buscar primero desde el directorio actual y hasta ocho niveles superiores.
local project_candidate "`project_current'"
forvalues search_level = 0/8 {
    if "$PROJECT_ROOT" == "" {
        capture confirm file "`project_candidate'/`panel_relative'"
        if !_rc {
            quietly cd "`project_candidate'"
            global PROJECT_ROOT "`c(pwd)'"
        }
    }
    local project_candidate "`project_candidate'/.."
}

* Probar la ubicación habitual de Windows si la búsqueda ascendente falló.
if "$PROJECT_ROOT" == "" {
    capture confirm file "`project_windows'/`panel_relative'"
    if !_rc {
        global PROJECT_ROOT "`project_windows'"
    }
}

* Probar finalmente una ruta manual cuando haya sido diligenciada.
if "$PROJECT_ROOT" == "" & "`project_manual'" != "" {
    capture confirm file "`project_manual'/`panel_relative'"
    if !_rc {
        global PROJECT_ROOT "`project_manual'"
    }
}

* Detener la ejecución con información suficiente si no aparece el repositorio.
if "$PROJECT_ROOT" == "" {
    display as error "No se pudo localizar la raíz del repositorio."
    display as error "Directorio inicial: `c(pwd)'"
    display as error "Ruta automática examinada: `project_windows'"
    display as error "Edite project_manual en la sección 1.2 si es necesario."
    exit 601
}

* Adoptar la raíz validada como directorio de trabajo del análisis.
quietly cd "$PROJECT_ROOT"
display as result "Raíz del proyecto localizada correctamente:"
pwd


// 1.3. Definir entradas, outputs y registro de ejecución

* Todas las salidas se guardan dentro de la carpeta del módulo temporal.
* El archivo no puede sobrescribir el módulo TWFE ni el panel maestro.

* Definir el insumo maestro y la carpeta del módulo temporal.
global DATA_MASTER ///
    "$PROJECT_ROOT/data/processed/00_master_panel"
global PANEL_FILE ///
    "$DATA_MASTER/master_panel_country_year.dta"
global SCRIPT_ROOT ///
    "$PROJECT_ROOT/scripts/econometrics/stata-peer-2/02_temporal_fe"
global OUTPUT_ROOT ///
    "$PROJECT_ROOT/outputs/econometrics/stata-peer-2/02_temporal_fe"

* Separar outputs por función para preservar trazabilidad entre etapas.
global OUTPUT_DESIGN      "$OUTPUT_ROOT/00_design"
global OUTPUT_SAMPLE      "$OUTPUT_ROOT/01_sample"
global OUTPUT_DIAGNOSTICS "$OUTPUT_ROOT/02_diagnostics"
global OUTPUT_ECI         "$OUTPUT_ROOT/03_eci"
global OUTPUT_DIVX        "$OUTPUT_ROOT/04_divx"
global OUTPUT_CUMULATIVE  "$OUTPUT_ROOT/05_cumulative"
global OUTPUT_PLACEBO     "$OUTPUT_ROOT/06_placebo"
global OUTPUT_CHANGES     "$OUTPUT_ROOT/07_changes"
global OUTPUT_STABILITY   "$OUTPUT_ROOT/08_stability"
global OUTPUT_FINAL       "$OUTPUT_ROOT/09_final"
global OUTPUT_LOGS        "$OUTPUT_ROOT/logs"
global ADO_PROJECT        "$OUTPUT_ROOT/ado"

* Crear las carpetas evita que las etapas posteriores improvisen ubicaciones.
* capture evita que Stata se detenga cuando una carpeta ya existe.
capture mkdir "$PROJECT_ROOT/outputs"
capture mkdir "$PROJECT_ROOT/outputs/econometrics"
capture mkdir "$PROJECT_ROOT/outputs/econometrics/stata-peer-2"
capture mkdir "$OUTPUT_ROOT"
capture mkdir "$OUTPUT_DESIGN"
capture mkdir "$OUTPUT_SAMPLE"
capture mkdir "$OUTPUT_DIAGNOSTICS"
capture mkdir "$OUTPUT_ECI"
capture mkdir "$OUTPUT_DIVX"
capture mkdir "$OUTPUT_CUMULATIVE"
capture mkdir "$OUTPUT_PLACEBO"
capture mkdir "$OUTPUT_CHANGES"
capture mkdir "$OUTPUT_STABILITY"
capture mkdir "$OUTPUT_FINAL"
capture mkdir "$OUTPUT_LOGS"
capture mkdir "$ADO_PROJECT"
capture mkdir "$ADO_PROJECT/plus"

* Abrir un registro exclusivo del primer archivo temporal.
log using "$OUTPUT_LOGS/01_temporal_data_and_samples.log", ///
    text replace name(temporal_data_log)

* Registrar las rutas y condiciones principales de esta ejecución.
display as text   "1. Configuración reproducible del entorno"
display as result "Configuración completada sin errores."
display as result "Stata:    versión 17.0"
display as result "Proyecto: $PROJECT_ROOT"
display as result "Panel:    $PANEL_FILE"
display as result "Salidas:  $OUTPUT_ROOT"
display as result "Inicio:   `c(current_date)' `c(current_time)'"


// 1.4. Verificar comandos y dependencias

* La preparación utiliza principalmente herramientas incluidas en Stata.
* Todo paquete adicional deberá justificarse y guardarse dentro del proyecto.

* Añadir la biblioteca ado del módulo sin sustituir las rutas existentes.
adopath ++ "$ADO_PROJECT/plus"

* Las secciones 1 y 2 utilizan únicamente comandos incluidos en Stata 17.
local required_commands ///
    isid encode levelsof xtset xtdescribe

* Confirmar que todos los comandos requeridos estén disponibles.
foreach command of local required_commands {
    capture which `command'
    if _rc {
        display as error "Stata no encuentra el comando requerido: `command'"
        exit 199
    }
}

display as text "Dependencias de las secciones 1 y 2: comandos nativos."
foreach command of local required_commands {
    which `command'
}


// *****************************************************************************
// 2. Carga y validación del panel maestro
// *****************************************************************************

// 2.1. Comprobar la existencia y estructura del insumo

* Cada combinación de país y año debe identificar una sola observación.
* Las variables cuantitativas deben estar almacenadas como valores numéricos.
* Los códigos, nombres e identificadores de país deben ser coherentes.

display as text "2. Carga y validación del panel maestro"
display as text "Directorio de trabajo: `c(pwd)'"

* Comprobar que el archivo exista antes de intentar cargarlo.
capture confirm file "$PANEL_FILE"
if _rc {
    display as error "No se encontró el panel maestro:"
    display as error "$PANEL_FILE"
    exit 601
}

* Cargar una copia en memoria; el archivo maestro nunca se guarda ni reemplaza.
use "$PANEL_FILE", clear

* Confirmar todas las variables necesarias para este módulo y sus extensiones.
local required_vars ///
    country_iso3_code country dres_base_mean dres_base_mean_percent year ///
    rents rents_oil_gas rents_mining inst rents_x_inst ///
    oilpc gaspc coalpc pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin eci hhi divx

foreach var of local required_vars {
    capture confirm variable `var'
    if _rc {
        display as error "Falta la variable requerida: `var'"
        exit 111
    }
}

* Los identificadores de país deben ser cadenas y no contener valores faltantes.
foreach var in country_iso3_code country {
    capture confirm string variable `var'
    if _rc {
        display as error "La variable `var' debe ser de tipo string."
        exit 109
    }
    assert !missing(`var')
}

* Las demás variables requeridas deben estar almacenadas como numéricas.
local numeric_vars ///
    dres_base_mean dres_base_mean_percent year ///
    rents rents_oil_gas rents_mining inst rents_x_inst ///
    oilpc gaspc coalpc pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin eci hhi divx

foreach var of local numeric_vars {
    capture confirm numeric variable `var'
    if _rc {
        display as error "La variable `var' debe ser numérica."
        exit 109
    }
}

* Validar formato y correspondencia biunívoca de los identificadores nacionales.
assert !missing(year)
assert strlen(country_iso3_code) == 3
assert country_iso3_code == upper(country_iso3_code)
assert year == floor(year)
bysort country_iso3_code (country): assert country == country[1]
bysort country (country_iso3_code): assert country_iso3_code == ///
    country_iso3_code[1]

* Confirmar la llave país-año antes de calcular rezagos y adelantos.
capture isid country_iso3_code year, sort
if _rc {
    display as error "La llave country_iso3_code-year no es única."
    duplicates report country_iso3_code year
    exit 459
}

* Congelar las dimensiones esperadas del panel maestro publicado.
quietly count
local n_observations = r(N)
assert `n_observations' == 1430

quietly summarize year, meanonly
local first_year = r(min)
local last_year  = r(max)
local n_calendar_years = `last_year' - `first_year' + 1
assert `first_year' == 1996
assert `last_year'  == 2021
assert `n_calendar_years' == 26

* Mostrar la estructura cargada después de completar las verificaciones mínimas.
describe


// 2.2. Confirmar variables y definiciones sustantivas

* Variables mínimas del bloque focal:
*   - dependientes: eci y divx;
*   - exposición: rents;
*   - moderador: inst;
*   - interacción: rents_x_inst;
*   - identificadores: country_iso3_code, country y year.

* Comprobar que RENTS sume las rentas de hidrocarburos y minerales.
* Comprobar que DIVX sea igual a uno menos el índice HHI.

* Comprobar variables definidas como proporciones entre cero y uno.
local bounded_0_1 dres_base_mean hhi divx
foreach var of local bounded_0_1 {
    assert inrange(`var', 0, 1) if !missing(`var')
}

* Comprobar variables definidas como porcentajes entre cero y cien.
local bounded_0_100 ///
    dres_base_mean_percent rents rents_oil_gas rents_mining ///
    pexp fexp net govcons

foreach var of local bounded_0_100 {
    assert inrange(`var', 0, 100) if !missing(`var')
}

* Comprobar variables que, por construcción, no pueden ser negativas.
local nonnegative_vars ///
    oilpc gaspc coalpc vol humcap innov log_gdppc fin

foreach var of local nonnegative_vars {
    assert `var' >= 0 if !missing(`var')
}

* Verificar la regla que identifica economías dependientes de recursos.
assert dres_base_mean >= 0.20
assert abs(dres_base_mean_percent - 100*dres_base_mean) <= 1e-10

* DIVX debe ser exactamente el complemento de HHI.
assert missing(divx) == missing(hhi)
assert abs(divx - (1 - hhi)) <= 1e-10 if !missing(divx, hhi)

* RENTS debe ser la suma de hidrocarburos y minería.
assert missing(rents) == ///
    (missing(rents_oil_gas) | missing(rents_mining))
assert abs(rents - (rents_oil_gas + rents_mining)) <= 1e-10 ///
    if !missing(rents, rents_oil_gas, rents_mining)

* La interacción focal debe coincidir con el producto RENTS × INST.
assert missing(rents_x_inst) == (missing(rents) | missing(inst))
assert abs(rents_x_inst - rents*inst) <= 1e-10 ///
    if !missing(rents_x_inst, rents, inst)

* Aplicar etiquetas consistentes con el TWFE principal a la copia en memoria.
label variable country_iso3_code "Código ISO3 del país"
label variable country           "Nombre del país"
label variable year              "Año"
label variable eci               "Complejidad económica (ECI)"
label variable divx              "Diversificación exportadora (DIVX = 1 - HHI)"
label variable rents             "Rentas extractivas del subsuelo (% PIB)"
label variable rents_oil_gas     "Rentas de hidrocarburos (% PIB)"
label variable rents_mining      "Rentas mineras (% PIB)"
label variable inst              "Calidad institucional (INST)"
label variable rents_x_inst      "RENTS x INST"
label variable hhi               "Concentración exportadora (HHI)"


// 2.3. Declarar y describir el panel

* Registrar países, años, observaciones y datos faltantes por variable.
* Una grilla completa no garantiza datos disponibles para todas las variables.
* Por eso se validan por separado la grilla y la cobertura de cada variable.

* Evitar sobrescribir un identificador numérico que no pertenezca al diseño.
capture confirm new variable country_id
if _rc {
    display as error "La variable country_id ya existe en el panel maestro."
    exit 110
}

* Crear el identificador numérico de panel a partir del código ISO3 validado.
encode country_iso3_code, generate(country_id)
label variable country_id "Identificador numérico de país"
order country_id, after(country)

* Verificar los 55 países y la grilla completa de 26 años consecutivos.
quietly levelsof country_id, local(panel_ids)
local n_countries : word count `panel_ids'
assert `n_countries' == 55
bysort country_id (year): assert _N == 26
by country_id: assert year == 1995 + _n

* Declarar la estructura país-año y confirmar que Stata reconoce el panel.
xtset country_id year
xtdescribe

* Informar el estado alcanzado sin anticipar la construcción de T0--T5.
display as result "Secciones 1 y 2 completadas sin errores."
display as result "Observaciones del panel maestro: `n_observations'"
display as result "Países:                       `n_countries'"
display as result "Período:                      `first_year'-`last_year'"
display as result "Siguiente bloque pendiente: sección 3."


// *****************************************************************************
// 3. Construcción de términos temporales T0--T5
// *****************************************************************************

// 3.1. T0 — referencia contemporánea

* T0 usa RENTS, INST y su interacción en el mismo año del resultado.
* Esta especificación reproduce el bloque focal M1 del modelo TWFE.
* Los demás controles del modelo completo no se trasladan automáticamente.

display as text "3. Construcción de términos temporales T0--T5"

* Crear nombres T0 permite reconocer las variables contemporáneas.
* Esta convención evita mezclar variables de horizontes temporales distintos.
generate double t0_rents = rents
generate double t0_inst = inst
generate double t0_rents_x_inst = rents_x_inst

label variable t0_rents "T0: RENTS contemporánea"
label variable t0_inst "T0: INST contemporánea"
label variable t0_rents_x_inst "T0: RENTS x INST contemporánea"

* Comprobar que T0 conserva exactamente las definiciones del panel maestro.
assert t0_rents == rents if !missing(rents)
assert missing(t0_rents) == missing(rents)
assert t0_inst == inst if !missing(inst)
assert missing(t0_inst) == missing(inst)
assert t0_rents_x_inst == rents_x_inst if !missing(rents_x_inst)
assert missing(t0_rents_x_inst) == missing(rents_x_inst)


// 3.2. T1 — exposición rezagada un año

* T1 utilizará RENTS(i,t-1), INST(i,t-1) y la interacción observada en t-1.
* La interacción rezagada solo combina variables correspondientes al mismo año.

* Marcar si existe el año calendario inmediatamente anterior dentro del país.
generate byte continuity_l1 = ///
    !missing(L1.year) & year == L1.year + 1
label variable continuity_l1 "Existe t-1 consecutivo dentro del país"

* Construir los tres términos T1 únicamente cuando t-1 sea consecutivo.
generate double t1_rents = L1.rents if continuity_l1 == 1
generate double t1_inst = L1.inst if continuity_l1 == 1
generate double t1_rents_x_inst = L1.rents_x_inst ///
    if continuity_l1 == 1

label variable t1_rents "T1: RENTS rezagada un año"
label variable t1_inst "T1: INST rezagada un año"
label variable t1_rents_x_inst "T1: RENTS x INST rezagada un año"

* La interacción T1 debe ser el producto observado en el mismo año t-1.
assert abs(t1_rents_x_inst - t1_rents*t1_inst) <= 1e-10 ///
    if !missing(t1_rents_x_inst, t1_rents, t1_inst)
assert missing(t1_rents_x_inst) == ///
    (missing(t1_rents) | missing(t1_inst)) if continuity_l1 == 1


// 3.3. T2 — promedio retrospectivo de tres años

* T2 promedia cada variable focal entre el año actual y los dos anteriores.
* Cada promedio exige tres valores válidos en años consecutivos.

* Marcar la disponibilidad de una ventana completa t, t-1 y t-2.
generate byte continuity_l2 = ///
    continuity_l1 == 1 & !missing(L2.year) & year == L2.year + 2
label variable continuity_l2 "Existen t-1 y t-2 consecutivos dentro del país"

* Conservar el segundo rezago de cada término para T2 y T3.
generate double t3_rents_l2 = L2.rents if continuity_l2 == 1
generate double t3_inst_l2 = L2.inst if continuity_l2 == 1
generate double t3_rents_x_inst_l2 = L2.rents_x_inst ///
    if continuity_l2 == 1

* Calcular medias únicamente con tres observaciones válidas y consecutivas.
generate double t2_ma3_rents = ///
    (t0_rents + t1_rents + t3_rents_l2)/3 ///
    if continuity_l2 == 1 & ///
    !missing(t0_rents, t1_rents, t3_rents_l2)

generate double t2_ma3_inst = ///
    (t0_inst + t1_inst + t3_inst_l2)/3 ///
    if continuity_l2 == 1 & ///
    !missing(t0_inst, t1_inst, t3_inst_l2)

generate double t2_ma3_rents_x_inst = ///
    (t0_rents_x_inst + t1_rents_x_inst + t3_rents_x_inst_l2)/3 ///
    if continuity_l2 == 1 & ///
    !missing(t0_rents_x_inst, t1_rents_x_inst, t3_rents_x_inst_l2)

label variable t2_ma3_rents "T2: promedio RENTS t a t-2"
label variable t2_ma3_inst "T2: promedio INST t a t-2"
label variable t2_ma3_rents_x_inst ///
    "T2: promedio de RENTS x INST t a t-2"

* T2 promedia productos anuales; no utiliza el producto de dos promedios.
generate double check_t2_product_of_means = ///
    t2_ma3_rents*t2_ma3_inst if ///
    !missing(t2_ma3_rents, t2_ma3_inst)
label variable check_t2_product_of_means ///
    "Solo auditoría: media RENTS por media INST"


// 3.4. T3 — rezagos distribuidos 0--2

* T3 conserva por separado RENTS del año actual y sus dos rezagos.
* Esto permite estimar cada coeficiente, su suma y una prueba conjunta.
* Las interacciones distribuidas quedan preparadas para el diagnóstico.
* Solo se usarán si su colinealidad permite una interpretación estable.

* Preparar explícitamente los tres horizontes de RENTS, INST e interacción.
* La disponibilidad de estas variables no implica que todas entren al modelo T3.
generate double t3_rents_l0 = t0_rents
generate double t3_rents_l1 = t1_rents
generate double t3_inst_l0 = t0_inst
generate double t3_inst_l1 = t1_inst
generate double t3_rents_x_inst_l0 = t0_rents_x_inst
generate double t3_rents_x_inst_l1 = t1_rents_x_inst

label variable t3_rents_l0 "T3: RENTS en t"
label variable t3_rents_l1 "T3: RENTS en t-1"
label variable t3_rents_l2 "T3: RENTS en t-2"
label variable t3_inst_l0 "T3: INST en t"
label variable t3_inst_l1 "T3: INST en t-1"
label variable t3_inst_l2 "T3: INST en t-2"
label variable t3_rents_x_inst_l0 "T3: RENTS x INST en t"
label variable t3_rents_x_inst_l1 "T3: RENTS x INST en t-1"
label variable t3_rents_x_inst_l2 "T3: RENTS x INST en t-2"

* Verificar que cada interacción distribuida pertenece a su propio año.
foreach lag in 0 1 2 {
    assert abs(t3_rents_x_inst_l`lag' - ///
        t3_rents_l`lag'*t3_inst_l`lag') <= 1e-10 ///
        if !missing(t3_rents_x_inst_l`lag', ///
            t3_rents_l`lag', t3_inst_l`lag')
}


// 3.5. T4 — adelanto placebo

* T4 añade el valor de RENTS del año siguiente como prueba placebo.
* El adelanto no funciona como instrumento ni demuestra exogeneidad.
* Su función es detectar señales de anticipación, persistencia o simultaneidad.

* Marcar la existencia del año calendario siguiente y construir su RENTS.
generate byte continuity_f1 = ///
    !missing(F1.year) & F1.year == year + 1
generate double t4_rents_f1 = F1.rents if continuity_f1 == 1

label variable continuity_f1 "Existe t+1 consecutivo dentro del país"
label variable t4_rents_f1 "T4: adelanto de RENTS en t+1"


// 3.6. T5 — primeras diferencias

* T5 calcula el cambio anual de ECI, DIVX, RENTS e INST.
* La diferencia elimina características nacionales constantes en el tiempo.
* También puede amplificar errores de medición y exige cautela.

* Construir diferencias únicamente cuando existe t-1 consecutivo.
generate double t5_d_eci = D1.eci if continuity_l1 == 1
generate double t5_d_divx = D1.divx if continuity_l1 == 1
generate double t5_d_rents = D1.rents if continuity_l1 == 1
generate double t5_d_inst = D1.inst if continuity_l1 == 1

label variable t5_d_eci "T5: cambio anual de ECI"
label variable t5_d_divx "T5: cambio anual de DIVX"
label variable t5_d_rents "T5: cambio anual de RENTS"
label variable t5_d_inst "T5: cambio anual de INST"

* Reconciliar cada diferencia con la resta explícita entre t y t-1.
assert abs(t5_d_eci - (eci - L1.eci)) <= 1e-10 ///
    if !missing(t5_d_eci, eci, L1.eci)
assert abs(t5_d_divx - (divx - L1.divx)) <= 1e-10 ///
    if !missing(t5_d_divx, divx, L1.divx)
assert abs(t5_d_rents - (rents - L1.rents)) <= 1e-10 ///
    if !missing(t5_d_rents, rents, L1.rents)
assert abs(t5_d_inst - (inst - L1.inst)) <= 1e-10 ///
    if !missing(t5_d_inst, inst, L1.inst)


// 3.7. Validación de continuidad temporal

* Cada variable temporal conserva indicadores de continuidad entre años.
* Las pérdidas se separan entre límites temporales y datos faltantes.
* Esta separación evita atribuir todas las pérdidas a una misma causa.

* Los límites temporales deben aparecer solo al inicio o al final de cada país.
* Las comprobaciones harán visible cualquier cambio futuro en la grilla.
assert continuity_l1 == (year > `first_year')
assert continuity_l2 == (year > `first_year' + 1)
assert continuity_f1 == (year < `last_year')

* Construir banderas de completitud focal separadas de la continuidad temporal.
generate byte focal_complete_t0 = ///
    !missing(t0_rents, t0_inst, t0_rents_x_inst)
generate byte focal_complete_t1 = continuity_l1 == 1 & ///
    !missing(t1_rents, t1_inst, t1_rents_x_inst)
generate byte focal_complete_t2 = continuity_l2 == 1 & ///
    !missing(t2_ma3_rents, t2_ma3_inst, t2_ma3_rents_x_inst)
* T3 básico requiere RENTS del año actual y de los dos años anteriores.
* Las interacciones distribuidas solo se aceptarán después de revisar el VIF.
generate byte focal_complete_t3 = continuity_l2 == 1 & ///
    !missing(t3_rents_l0, t3_rents_l1, t3_rents_l2, t3_inst_l0)

* Conservar por separado la completitud de la expansión potencial de T3.
generate byte focal_complete_t3_expanded = continuity_l2 == 1 & ///
    !missing(t3_rents_l0, t3_rents_l1, t3_rents_l2, ///
        t3_inst_l0, t3_inst_l1, t3_inst_l2, ///
        t3_rents_x_inst_l0, t3_rents_x_inst_l1, ///
        t3_rents_x_inst_l2)
generate byte focal_complete_t4 = continuity_f1 == 1 & ///
    !missing(t0_rents, t0_inst, t0_rents_x_inst, t4_rents_f1)
generate byte focal_complete_t5 = continuity_l1 == 1 & ///
    !missing(t5_d_rents, t5_d_inst)

label variable focal_complete_t0 "Bloque focal completo para T0"
label variable focal_complete_t1 "Bloque focal completo para T1"
label variable focal_complete_t2 "Bloque focal completo para T2"
label variable focal_complete_t3 "Bloque focal completo para T3 básico"
label variable focal_complete_t3_expanded ///
    "Bloque focal completo para T3 ampliado"
label variable focal_complete_t4 "Bloque focal completo para T4"
label variable focal_complete_t5 "Bloque focal completo para T5"

* T2 y T3 ampliado requieren tres años completos de las variables focales.
* Por eso ambos deben tener la misma disponibilidad de observaciones.
* T3 básico puede usar más observaciones, pero nunca menos que T2.
assert focal_complete_t2 == focal_complete_t3_expanded
assert focal_complete_t2 <= focal_complete_t3

* Reportar las fronteras temporales antes de definir las muestras de resultados.
quietly count if continuity_l1 == 0
local n_without_l1 = r(N)
quietly count if continuity_l2 == 0
local n_without_l2 = r(N)
quietly count if continuity_f1 == 0
local n_without_f1 = r(N)

display as result "Construcción temporal validada."
display as result "Filas sin t-1 por frontera:      `n_without_l1'"
display as result "Filas sin ventana t a t-2:       `n_without_l2'"
display as result "Filas sin t+1 por frontera:      `n_without_f1'"


// *****************************************************************************
// 4. Definición y congelación de muestras
// *****************************************************************************

// 4.1. Muestras específicas por resultado y especificación

* Una muestra exige el resultado y todos los términos usados por su modelo.
* La presencia aislada de una variable no hace utilizable una observación.
* El tamaño reportado debe coincidir con las observaciones estimadas.

display as text "4. Definición y congelación de muestras"

* Crear muestras propias de ECI para cada especificación temporal.
generate byte sample_t0_eci = focal_complete_t0 == 1 & !missing(eci)
generate byte sample_t1_eci = focal_complete_t1 == 1 & !missing(eci)
generate byte sample_t2_eci = focal_complete_t2 == 1 & !missing(eci)
generate byte sample_t3_eci = focal_complete_t3 == 1 & !missing(eci)
generate byte sample_t3_expanded_eci = ///
    focal_complete_t3_expanded == 1 & !missing(eci)
generate byte sample_t4_eci = focal_complete_t4 == 1 & !missing(eci)
generate byte sample_t5_eci = focal_complete_t5 == 1 & !missing(t5_d_eci)

* Crear muestras propias de DIVX con las mismas reglas de exposición.
generate byte sample_t0_divx = focal_complete_t0 == 1 & !missing(divx)
generate byte sample_t1_divx = focal_complete_t1 == 1 & !missing(divx)
generate byte sample_t2_divx = focal_complete_t2 == 1 & !missing(divx)
generate byte sample_t3_divx = focal_complete_t3 == 1 & !missing(divx)
generate byte sample_t3_expanded_divx = ///
    focal_complete_t3_expanded == 1 & !missing(divx)
generate byte sample_t4_divx = focal_complete_t4 == 1 & !missing(divx)
generate byte sample_t5_divx = focal_complete_t5 == 1 & !missing(t5_d_divx)

* Etiquetar las doce muestras para conservar su definición en la base derivada.
label variable sample_t0_eci "Muestra ECI T0 contemporánea"
label variable sample_t1_eci "Muestra ECI T1 rezagada"
label variable sample_t2_eci "Muestra ECI T2 promedio tres años"
label variable sample_t3_eci "Muestra ECI T3 rezagos 0--2"
label variable sample_t3_expanded_eci ///
    "Muestra ECI T3 con interacciones distribuidas"
label variable sample_t4_eci "Muestra ECI T4 adelanto placebo"
label variable sample_t5_eci "Muestra ECI T5 primeras diferencias"
label variable sample_t0_divx "Muestra DIVX T0 contemporánea"
label variable sample_t1_divx "Muestra DIVX T1 rezagada"
label variable sample_t2_divx "Muestra DIVX T2 promedio tres años"
label variable sample_t3_divx "Muestra DIVX T3 rezagos 0--2"
label variable sample_t3_expanded_divx ///
    "Muestra DIVX T3 con interacciones distribuidas"
label variable sample_t4_divx "Muestra DIVX T4 adelanto placebo"
label variable sample_t5_divx "Muestra DIVX T5 primeras diferencias"

* T2 coincide con la expansión de T3 y debe ser subconjunto del T3 básico.
assert sample_t2_eci == sample_t3_expanded_eci
assert sample_t2_divx == sample_t3_expanded_divx
assert sample_t2_eci <= sample_t3_eci
assert sample_t2_divx <= sample_t3_divx


// 4.2. Muestra común para comparación T0--T3

* La comparación principal utiliza observaciones comunes a todos los modelos.
* También se conservan las muestras propias de cada horizonte.
* Así se separa el cambio temporal del cambio en la composición de la muestra.

* Congelar la intersección T0--T3 por resultado y para ambos resultados juntos.
generate byte sample_common_t0_t3_eci = ///
    sample_t0_eci & sample_t1_eci & sample_t2_eci & sample_t3_eci
generate byte sample_common_t0_t3_divx = ///
    sample_t0_divx & sample_t1_divx & sample_t2_divx & sample_t3_divx
generate byte sample_common_t0_t3_both = ///
    sample_common_t0_t3_eci & sample_common_t0_t3_divx

label variable sample_common_t0_t3_eci ///
    "Muestra común ECI para T0--T3"
label variable sample_common_t0_t3_divx ///
    "Muestra común DIVX para T0--T3"
label variable sample_common_t0_t3_both ///
    "Muestra común conjunta ECI-DIVX para T0--T3"

* T2 y T3 determinan la intersección porque exigen la ventana más larga.
* Las comprobaciones harán visible cualquier cambio futuro en esta relación.
assert sample_common_t0_t3_eci == sample_t2_eci
assert sample_common_t0_t3_divx == sample_t2_divx


// 4.3. Pérdidas y exclusiones

* Cada muestra reporta observaciones, países, grupos y cobertura temporal.
* También informa períodos por país y pérdidas frente a T0.
* Los países excluidos aparecen mediante su código ISO3.

* Validar que todas las banderas sean binarias y nunca contengan missing.
local temporal_samples ///
    sample_t0_eci sample_t1_eci sample_t2_eci sample_t3_eci ///
    sample_t3_expanded_eci sample_t4_eci sample_t5_eci ///
    sample_t0_divx sample_t1_divx sample_t2_divx sample_t3_divx ///
    sample_t3_expanded_divx sample_t4_divx sample_t5_divx ///
    sample_common_t0_t3_eci sample_common_t0_t3_divx ///
    sample_common_t0_t3_both

foreach sample of local temporal_samples {
    assert inlist(`sample', 0, 1)
}

* Crear banderas permite identificar por qué se pierde cada observación.
* Los límites del calendario se separan de los datos faltantes internos.
generate byte loss_t0_focal_missing = focal_complete_t0 == 0
generate byte loss_t1_boundary = continuity_l1 == 0
generate byte loss_t1_focal_missing = ///
    continuity_l1 == 1 & focal_complete_t1 == 0
generate byte loss_t2_boundary = continuity_l2 == 0
generate byte loss_t2_focal_missing = ///
    continuity_l2 == 1 & focal_complete_t2 == 0
generate byte loss_t3_boundary = continuity_l2 == 0
generate byte loss_t3_focal_missing = ///
    continuity_l2 == 1 & focal_complete_t3 == 0
generate byte loss_t4_boundary = continuity_f1 == 0
generate byte loss_t4_focal_missing = ///
    continuity_f1 == 1 & focal_complete_t4 == 0
generate byte loss_t5_boundary = continuity_l1 == 0
generate byte loss_t5_focal_missing = ///
    continuity_l1 == 1 & focal_complete_t5 == 0

label variable loss_t0_focal_missing "Pérdida T0 por exposición faltante"
label variable loss_t1_boundary "Pérdida T1 por frontera inicial"
label variable loss_t1_focal_missing "Pérdida T1 por exposición faltante"
label variable loss_t2_boundary "Pérdida T2 por ventana inicial"
label variable loss_t2_focal_missing "Pérdida T2 por exposición faltante"
label variable loss_t3_boundary "Pérdida T3 por ventana inicial"
label variable loss_t3_focal_missing "Pérdida T3 por exposición faltante"
label variable loss_t4_boundary "Pérdida T4 por frontera final"
label variable loss_t4_focal_missing "Pérdida T4 por exposición faltante"
label variable loss_t5_boundary "Pérdida T5 por frontera inicial"
label variable loss_t5_focal_missing "Pérdida T5 por exposición faltante"

* Registrar también pérdidas debidas exclusivamente a la variable dependiente.
foreach outcome in eci divx {
    generate byte loss_t0_`outcome'_outcome = ///
        focal_complete_t0 == 1 & missing(`outcome')
    generate byte loss_t1_`outcome'_outcome = ///
        focal_complete_t1 == 1 & missing(`outcome')
    generate byte loss_t2_`outcome'_outcome = ///
        focal_complete_t2 == 1 & missing(`outcome')
    generate byte loss_t3_`outcome'_outcome = ///
        focal_complete_t3 == 1 & missing(`outcome')
    generate byte loss_t4_`outcome'_outcome = ///
        focal_complete_t4 == 1 & missing(`outcome')
}

generate byte loss_t5_eci_outcome = ///
    focal_complete_t5 == 1 & missing(t5_d_eci)
generate byte loss_t5_divx_outcome = ///
    focal_complete_t5 == 1 & missing(t5_d_divx)

* Mostrar un resumen permite revisar las pérdidas antes de exportarlas.
* La sección 5 reutiliza estas mismas banderas sin reconstruirlas.
foreach outcome in eci divx {
    foreach model in t0 t1 t2 t3 t4 t5 {
        quietly count if sample_`model'_`outcome' == 1
        local sample_n = r(N)
        quietly levelsof country_id if sample_`model'_`outcome' == 1, ///
            local(sample_countries)
        local sample_g : word count `sample_countries'
        quietly summarize year if sample_`model'_`outcome' == 1, meanonly
        local sample_first = r(min)
        local sample_last = r(max)
        display as result ///
            "`outcome' `model': N=`sample_n'; países=`sample_g'; " ///
            "años=`sample_first'-`sample_last'"
    }
}

* Mostrar también la muestra potencial de T3 ampliado y la intersección T0--T3.
foreach outcome in eci divx {
    quietly count if sample_t3_expanded_`outcome' == 1
    local expanded_n = r(N)
    quietly levelsof country_id if sample_t3_expanded_`outcome' == 1, ///
        local(expanded_countries)
    local expanded_g : word count `expanded_countries'
    display as result ///
        "`outcome' t3 ampliado: N=`expanded_n'; países=`expanded_g'"

    quietly count if sample_common_t0_t3_`outcome' == 1
    local common_n = r(N)
    quietly levelsof country_id if sample_common_t0_t3_`outcome' == 1, ///
        local(common_countries)
    local common_g : word count `common_countries'
    quietly summarize year if sample_common_t0_t3_`outcome' == 1, meanonly
    local common_first = r(min)
    local common_last = r(max)
    display as result ///
        "`outcome' común T0--T3: N=`common_n'; países=`common_g'; " ///
        "años=`common_first'-`common_last'"
}

quietly count if sample_common_t0_t3_both == 1
local common_both_n = r(N)
display as result ///
    "Muestra común conjunta ECI-DIVX T0--T3: N=`common_both_n'"

* Cuantificar si la cobertura de ECI y DIVX genera composiciones diferentes.
foreach model in t0 t1 t2 t3 t4 t5 {
    quietly count if sample_`model'_eci != sample_`model'_divx
    local sample_difference_`model' = r(N)
    display as result ///
        "Diferencias ECI-DIVX en `model': `sample_difference_`model''"
}

* Contar los países que no aportan observaciones a cada muestra.
* La sección 5 exportará sus códigos sin volver a calcular la pérdida.
foreach outcome in eci divx {
    foreach model in t0 t1 t2 t3 t4 t5 {
        tempvar country_sample_count excluded_country_tag
        bysort country_id: egen long `country_sample_count' = ///
            total(sample_`model'_`outcome')
        egen byte `excluded_country_tag' = tag(country_id) ///
            if `country_sample_count' == 0
        quietly count if `excluded_country_tag' == 1
        local excluded_n = r(N)
        display as result ///
            "Países excluidos de `outcome' `model': " ///
            "`excluded_n'"
        if `excluded_n' > 0 {
            list country_iso3_code country ///
                if `excluded_country_tag' == 1, ///
                noobs abbreviate(24) separator(0)
        }
        drop `country_sample_count' `excluded_country_tag'
    }
}

* Resumir causas de pérdida que la sección 5 exportará a archivos auditables.
foreach model in t0 t1 t2 t3 t4 t5 {
    capture confirm variable loss_`model'_boundary
    if !_rc {
        quietly count if loss_`model'_boundary == 1
        local loss_boundary_`model' = r(N)
    }
    else {
        local loss_boundary_`model' = 0
    }
    quietly count if loss_`model'_focal_missing == 1
    local loss_focal_`model' = r(N)
    display as result ///
        "Pérdidas `model': frontera=`loss_boundary_`model''; " ///
        "exposición faltante=`loss_focal_`model''"
}

* Confirmar que la llave y la grilla no cambiaron durante las transformaciones.
isid country_iso3_code year
quietly count
assert r(N) == `n_observations'

display as result "Secciones 3 y 4 completadas sin errores."
display as result "Variables T0--T5 y muestras quedaron congeladas en memoria."
display as result "Siguiente bloque pendiente: sección 5."


// *****************************************************************************
// 5. Auditoría y exportación de la base temporal
// *****************************************************************************

// 5.1. Registro previo de especificaciones

* El registro documenta el diseño definido para cada modelo T0--T5.
* Incluye resultado, horizonte, términos, efectos fijos, inferencia y muestra.
* Este archivo demuestra que el diseño se fijó antes de revisar resultados.

display as text "5. Auditoría y exportación de la base temporal"

* Construir el registro de diseño sin alterar el panel que permanece en memoria.
tempname specification_post
tempfile specification_report

postfile `specification_post' ///
    int order str16 model str32 horizon ///
    str244 focal_terms str244 interaction_rule str244 purpose ///
    str80 fixed_effects str80 inference ///
    str32 sample_eci str32 sample_divx str32 implementation_status ///
    using "`specification_report'", replace

post `specification_post' ///
    (1) ("T0") ("Contemporáneo") ///
    ("RENTS(t); INST(t); RENTS(t) x INST(t)") ///
    ("Interacción contemporánea observada") ///
    ("Referencia focal comparable con M1 del TWFE") ///
    ("País y año") ("Errores agrupados por país") ///
    ("sample_t0_eci") ("sample_t0_divx") ("Congelado")

post `specification_post' ///
    (2) ("T1") ("Rezago de un año") ///
    ("RENTS(t-1); INST(t-1); RENTS(t-1) x INST(t-1)") ///
    ("Los tres términos pertenecen al mismo año t-1") ///
    ("Especificación temporal principal de precedencia") ///
    ("País y año") ("Cluster país y wild bootstrap") ///
    ("sample_t1_eci") ("sample_t1_divx") ("Congelado")

post `specification_post' ///
    (3) ("T2") ("Promedio retrospectivo t a t-2") ///
    ("Media de RENTS; media de INST; media de RENTS x INST") ///
    ("Promedio de productos anuales, no producto de promedios") ///
    ("Resumir exposición reciente con tres años completos") ///
    ("País y año") ("Cluster país y wild bootstrap") ///
    ("sample_t2_eci") ("sample_t2_divx") ("Congelado")

post `specification_post' ///
    (4) ("T3") ("Rezagos distribuidos 0--2") ///
    ("RENTS(t); RENTS(t-1); RENTS(t-2); INST(t)") ///
    ("Sin interacciones distribuidas en la versión básica") ///
    ("Estimar términos individuales, suma y prueba conjunta") ///
    ("País y año") ("Cluster país y wild bootstrap") ///
    ("sample_t3_eci") ("sample_t3_divx") ("Congelado")

post `specification_post' ///
    (5) ("T3X") ("T3 ampliado condicional") ///
    ("RENTS, INST e interacción en t, t-1 y t-2") ///
    ("Solo se estima si VIF y matriz de varianzas son informativos") ///
    ("Evaluar moderación distribuida sin seleccionar por valor p") ///
    ("País y año") ("Cluster país y wild bootstrap") ///
    ("sample_t3_expanded_eci") ("sample_t3_expanded_divx") ///
    ("Condicional a diagnóstico")

post `specification_post' ///
    (6) ("T4") ("Adelanto placebo t+1") ///
    ("Bloque T0 y RENTS(t+1)") ///
    ("No añade INST ni interacción futuras") ///
    ("Alerta de anticipación, persistencia o simultaneidad") ///
    ("País y año") ("Errores agrupados por país") ///
    ("sample_t4_eci") ("sample_t4_divx") ("Congelado")

post `specification_post' ///
    (7) ("T5") ("Primeras diferencias anuales") ///
    ("Delta Y; delta RENTS; delta INST") ///
    ("Sin interacción en la especificación predefinida") ///
    ("Sensibilidad de cambios anuales de corto plazo") ///
    ("Efectos de año") ("Errores agrupados por país") ///
    ("sample_t5_eci") ("sample_t5_divx") ("Congelado")

postclose `specification_post'

preserve
    use "`specification_report'", clear
    isid order
    assert _N == 7
    quietly count if implementation_status == "Congelado"
    assert r(N) == 6
    quietly count if model == "T3X" & ///
        implementation_status == "Condicional a diagnóstico"
    assert r(N) == 1
    sort order
    export delimited using ///
        "$OUTPUT_DESIGN/temporal_specification_register.csv", ///
        replace datafmt
restore


// 5.2. Resúmenes de muestra y cobertura

* Las tablas deben poder revisarse sin abrir la base de datos de Stata.
* Cada porcentaje identifica su denominador de manera explícita.
* La precisión numérica permite reconciliar porcentajes y conteos.

* Definir las ocho muestras que deben aparecer en los reportes de cobertura.
local report_models ///
    t0 t1 t2 t3 t3_expanded t4 t5 common_t0_t3

* Crear el resumen general de muestras para ECI y DIVX.
tempname sample_summary_post
tempfile sample_summary_report

postfile `sample_summary_post' ///
    int order str8 outcome str16 model str32 sample_variable ///
    long observations observations_lost_vs_panel ///
    long observations_lost_vs_t0 ///
    int countries excluded_countries calendar_years ///
    int first_year last_year ///
    double average_periods_per_country ///
    int minimum_periods_per_country maximum_periods_per_country ///
    str80 excluded_country_codes ///
    using "`sample_summary_report'", replace

local summary_order = 0
foreach outcome in eci divx {
    quietly count if sample_t0_`outcome' == 1
    local t0_reference_n = r(N)

    foreach model of local report_models {
        local ++summary_order

        if "`model'" == "t3_expanded" {
            local sample_variable "sample_t3_expanded_`outcome'"
        }
        else if "`model'" == "common_t0_t3" {
            local sample_variable "sample_common_t0_t3_`outcome'"
        }
        else {
            local sample_variable "sample_`model'_`outcome'"
        }

        quietly count if `sample_variable' == 1
        local sample_n = r(N)
        local expected_n_`outcome'_`model' = `sample_n'

        quietly levelsof country_id if `sample_variable' == 1, ///
            local(sample_country_ids)
        local sample_countries : word count `sample_country_ids'

        quietly levelsof year if `sample_variable' == 1, ///
            local(sample_year_values)
        local sample_years : word count `sample_year_values'

        quietly summarize year if `sample_variable' == 1, meanonly
        local sample_first_year = r(min)
        local sample_last_year = r(max)

        tempvar sample_periods sample_country_tag
        bysort country_id: egen int `sample_periods' = ///
            total(`sample_variable')
        egen byte `sample_country_tag' = tag(country_id) ///
            if `sample_periods' > 0
        quietly summarize `sample_periods' ///
            if `sample_country_tag' == 1, meanonly
        local average_periods = r(mean)
        local minimum_periods = r(min)
        local maximum_periods = r(max)

        local excluded_countries = `n_countries' - `sample_countries'
        local excluded_codes ""
        if `excluded_countries' > 0 {
            quietly levelsof country_iso3_code ///
                if `sample_periods' == 0, ///
                local(excluded_codes) clean
        }

        post `sample_summary_post' ///
            (`summary_order') ("`outcome'") ("`model'") ///
            ("`sample_variable'") (`sample_n') ///
            (`n_observations' - `sample_n') ///
            (`t0_reference_n' - `sample_n') ///
            (`sample_countries') (`excluded_countries') ///
            (`sample_years') (`sample_first_year') (`sample_last_year') ///
            (`average_periods') (`minimum_periods') (`maximum_periods') ///
            ("`excluded_codes'")

        drop `sample_periods' `sample_country_tag'
    }
}

postclose `sample_summary_post'

preserve
    use "`sample_summary_report'", clear
    isid outcome model
    assert _N == 16
    format average_periods_per_country %9.3f
    sort outcome order
    export delimited using ///
        "$OUTPUT_SAMPLE/temporal_sample_summary.csv", replace datafmt
restore

* Exportar las causas de pérdida con categorías mutuamente excluyentes.
tempname loss_post
tempfile loss_report

postfile `loss_post' ///
    int order str8 outcome str8 model ///
    long grid_observations boundary_loss focal_missing_loss ///
    outcome_missing_loss total_excluded retained_observations ///
    using "`loss_report'", replace

local loss_order = 0
foreach outcome in eci divx {
    foreach model in t0 t1 t2 t3 t4 t5 {
        local ++loss_order

        capture confirm variable loss_`model'_boundary
        if !_rc {
            quietly count if loss_`model'_boundary == 1
            local boundary_loss = r(N)
        }
        else {
            local boundary_loss = 0
        }

        quietly count if loss_`model'_focal_missing == 1
        local focal_missing_loss = r(N)
        quietly count if loss_`model'_`outcome'_outcome == 1
        local outcome_missing_loss = r(N)
        quietly count if sample_`model'_`outcome' == 1
        local retained_observations = r(N)
        local total_excluded = `n_observations' - `retained_observations'

        assert `boundary_loss' + `focal_missing_loss' + ///
            `outcome_missing_loss' == `total_excluded'

        post `loss_post' ///
            (`loss_order') ("`outcome'") ("`model'") ///
            (`n_observations') (`boundary_loss') ///
            (`focal_missing_loss') (`outcome_missing_loss') ///
            (`total_excluded') (`retained_observations')
    }
}

postclose `loss_post'

preserve
    use "`loss_report'", clear
    isid outcome model
    assert _N == 12
    assert boundary_loss + focal_missing_loss + ///
        outcome_missing_loss == total_excluded
    assert retained_observations + total_excluded == grid_observations
    sort outcome order
    export delimited using ///
        "$OUTPUT_SAMPLE/temporal_sample_loss_summary.csv", ///
        replace datafmt
restore

* Exportar una fila por resultado, modelo y país.
tempname country_post
tempfile country_report

postfile `country_post' ///
    int order str8 outcome str16 model str32 sample_variable ///
    int country_id str3 country_iso3_code str80 country ///
    int sample_observations first_year last_year calendar_span ///
    internal_gaps byte excluded ///
    using "`country_report'", replace

quietly levelsof country_id, local(all_country_ids)
local country_order = 0

foreach outcome in eci divx {
    foreach model of local report_models {
        if "`model'" == "t3_expanded" {
            local sample_variable "sample_t3_expanded_`outcome'"
        }
        else if "`model'" == "common_t0_t3" {
            local sample_variable "sample_common_t0_t3_`outcome'"
        }
        else {
            local sample_variable "sample_`model'_`outcome'"
        }

        foreach panel_id of local all_country_ids {
            local ++country_order
            quietly levelsof country_iso3_code ///
                if country_id == `panel_id', local(country_code) clean
            quietly levelsof country ///
                if country_id == `panel_id', local(country_name) clean

            quietly count if country_id == `panel_id' & ///
                `sample_variable' == 1
            local country_n = r(N)

            if `country_n' > 0 {
                quietly summarize year if country_id == `panel_id' & ///
                    `sample_variable' == 1, meanonly
                local country_first = r(min)
                local country_last = r(max)
                local country_span = `country_last' - `country_first' + 1
                local country_gaps = `country_span' - `country_n'
                local country_excluded = 0
            }
            else {
                local country_first = .
                local country_last = .
                local country_span = 0
                local country_gaps = 0
                local country_excluded = 1
            }

            post `country_post' ///
                (`country_order') ("`outcome'") ("`model'") ///
                ("`sample_variable'") (`panel_id') ("`country_code'") ///
                ("`country_name'") (`country_n') (`country_first') ///
                (`country_last') (`country_span') (`country_gaps') ///
                (`country_excluded')
        }
    }
}

postclose `country_post'

preserve
    use "`country_report'", clear
    isid outcome model country_id
    assert _N == 880
    sort outcome model country_iso3_code
    export delimited using ///
        "$OUTPUT_SAMPLE/temporal_sample_by_country.csv", ///
        replace datafmt
restore

* Exportar una fila por resultado, modelo y año calendario.
tempname year_post
tempfile year_report

postfile `year_post' ///
    int order str8 outcome str16 model str32 sample_variable ///
    int year observations countries excluded_countries ///
    using "`year_report'", replace

local year_order = 0
foreach outcome in eci divx {
    foreach model of local report_models {
        if "`model'" == "t3_expanded" {
            local sample_variable "sample_t3_expanded_`outcome'"
        }
        else if "`model'" == "common_t0_t3" {
            local sample_variable "sample_common_t0_t3_`outcome'"
        }
        else {
            local sample_variable "sample_`model'_`outcome'"
        }

        forvalues calendar_year = `first_year'/`last_year' {
            local ++year_order
            quietly count if year == `calendar_year' & ///
                `sample_variable' == 1
            local year_n = r(N)

            if `year_n' > 0 {
                quietly levelsof country_id if year == `calendar_year' & ///
                    `sample_variable' == 1, local(year_country_ids)
                local year_countries : word count `year_country_ids'
            }
            else {
                local year_countries = 0
            }

            post `year_post' ///
                (`year_order') ("`outcome'") ("`model'") ///
                ("`sample_variable'") (`calendar_year') (`year_n') ///
                (`year_countries') (`n_countries' - `year_countries')
        }
    }
}

postclose `year_post'

preserve
    use "`year_report'", clear
    isid outcome model year
    assert _N == 416
    sort outcome model year
    export delimited using ///
        "$OUTPUT_SAMPLE/temporal_sample_by_year.csv", ///
        replace datafmt
restore


// 5.3. Base de traspaso a los archivos 02 y 03

* La base temporal conserva intactas las variables originales del panel.
* También incluye variables temporales, continuidad y banderas de muestra.
* La base se guarda ordenada y con una sola fila por país-año.

* Ordenar las variables de identificación y comprobar nuevamente la llave.
order country_iso3_code country country_id year
sort country_id year
isid country_iso3_code year
assert _N == `n_observations'

* Registrar la fecha de creación de la base derivada en sus características.
char _dta[temporal_module] "02_temporal_fe"
char _dta[temporal_stage] "Secciones 1 a 6 completas"
char _dta[temporal_created] "`c(current_date)' `c(current_time)'"
char _dta[temporal_source] ///
    "data/processed/00_master_panel/master_panel_country_year.dta"

* Guardar una nueva base sin modificar el panel maestro.
save "$OUTPUT_SAMPLE/temporal_panel.dta", replace

display as result "Sección 5 completada: reportes y base temporal exportados."


// *****************************************************************************
// 6. Controles de cierre y traspaso
// *****************************************************************************

* El archivo se considerará completo únicamente si:
*   - la llave país-año continúa siendo única;
*   - ninguna variable temporal atraviesa un año faltante;
*   - los conteos exportados coinciden con las banderas guardadas;
*   - el panel maestro no fue modificado;
*   - temporal_panel.dta puede abrirse en una sesión nueva.

* El marcador de cierre aparece únicamente después de aprobar los controles.
* Su presencia confirma que el archivo terminó sin omitir validaciones.

display as text "6. Controles de cierre y traspaso"

* Confirmar la existencia de todos los productos obligatorios de esta etapa.
local required_outputs ///
    00_design/temporal_specification_register.csv ///
    01_sample/temporal_sample_summary.csv ///
    01_sample/temporal_sample_loss_summary.csv ///
    01_sample/temporal_sample_by_country.csv ///
    01_sample/temporal_sample_by_year.csv ///
    01_sample/temporal_panel.dta

foreach relative_output of local required_outputs {
    capture confirm file "$OUTPUT_ROOT/`relative_output'"
    if _rc {
        display as error "No se encontró el output obligatorio:"
        display as error "$OUTPUT_ROOT/`relative_output'"
        exit 601
    }
}

* Reabrir la base confirma que conserva una sola fila por país-año.
preserve
    use "$OUTPUT_SAMPLE/temporal_panel.dta", clear
    isid country_iso3_code year
    assert _N == `n_observations'
    quietly levelsof country_id, local(saved_country_ids)
    local saved_countries : word count `saved_country_ids'
    assert `saved_countries' == `n_countries'
    quietly summarize year, meanonly
    assert r(min) == `first_year'
    assert r(max) == `last_year'
    xtset country_id year

    confirm variable ///
        t0_rents t1_rents t2_ma3_rents ///
        t3_rents_l0 t3_rents_l1 t3_rents_l2 ///
        t4_rents_f1 t5_d_eci t5_d_divx ///
        sample_t0_eci sample_t5_eci ///
        sample_t0_divx sample_t5_divx ///
        sample_common_t0_t3_eci sample_common_t0_t3_divx

    foreach outcome in eci divx {
        foreach model of local report_models {
            if "`model'" == "t3_expanded" {
                local sample_variable "sample_t3_expanded_`outcome'"
            }
            else if "`model'" == "common_t0_t3" {
                local sample_variable "sample_common_t0_t3_`outcome'"
            }
            else {
                local sample_variable "sample_`model'_`outcome'"
            }
            quietly count if `sample_variable' == 1
            assert r(N) == `expected_n_`outcome'_`model''
        }
    }
restore

* Reabrir y verificar cada CSV mediante su llave y número esperado de filas.
preserve
    import delimited using ///
        "$OUTPUT_DESIGN/temporal_specification_register.csv", ///
        clear varnames(1)
    isid model
    assert _N == 7
restore

preserve
    import delimited using ///
        "$OUTPUT_SAMPLE/temporal_sample_summary.csv", ///
        clear varnames(1)
    isid outcome model
    assert _N == 16
    assert observations + observations_lost_vs_panel == `n_observations'
restore

preserve
    import delimited using ///
        "$OUTPUT_SAMPLE/temporal_sample_loss_summary.csv", ///
        clear varnames(1)
    isid outcome model
    assert _N == 12
    assert retained_observations + total_excluded == grid_observations
restore

preserve
    import delimited using ///
        "$OUTPUT_SAMPLE/temporal_sample_by_country.csv", ///
        clear varnames(1)
    isid outcome model country_id
    assert _N == 880
restore

preserve
    import delimited using ///
        "$OUTPUT_SAMPLE/temporal_sample_by_year.csv", ///
        clear varnames(1)
    isid outcome model year
    assert _N == 416
restore

* Crear el manifiesto solo después de aprobar las validaciones anteriores.
tempname manifest_post
tempfile manifest_report

postfile `manifest_post' ///
    int order str100 relative_path str48 artifact ///
    long expected_rows str16 status ///
    using "`manifest_report'", replace

post `manifest_post' ///
    (1) ("00_design/temporal_specification_register.csv") ///
    ("Registro de especificaciones T0--T5") (7) ("Validado")
post `manifest_post' ///
    (2) ("01_sample/temporal_sample_summary.csv") ///
    ("Resumen de muestras") (16) ("Validado")
post `manifest_post' ///
    (3) ("01_sample/temporal_sample_loss_summary.csv") ///
    ("Causas de pérdida") (12) ("Validado")
post `manifest_post' ///
    (4) ("01_sample/temporal_sample_by_country.csv") ///
    ("Cobertura por país") (880) ("Validado")
post `manifest_post' ///
    (5) ("01_sample/temporal_sample_by_year.csv") ///
    ("Cobertura por año") (416) ("Validado")
post `manifest_post' ///
    (6) ("01_sample/temporal_panel.dta") ///
    ("Panel temporal derivado") (`n_observations') ("Validado")

postclose `manifest_post'

preserve
    use "`manifest_report'", clear
    isid order
    assert _N == 6
    export delimited using ///
        "$OUTPUT_FINAL/temporal_output_manifest.csv", replace datafmt
restore

* Cerrar la etapa dejando una frase inequívoca para el futuro ejecutor batch.
display as result "Todas las verificaciones de las secciones 1 a 6 aprobaron."
display as result ///
    "Archivo temporal 01 finalizado: datos y muestras T0--T5 validados."
display as result "TEMPORAL_01_COMPLETED_OK"
display as result "Panel derivado: $OUTPUT_SAMPLE/temporal_panel.dta"
display as result "Fin: `c(current_date)' `c(current_time)'"

log close temporal_data_log
