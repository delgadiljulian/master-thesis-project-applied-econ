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
// Archivo: 01_data_preparation_diagnostics.do (Versión Codex)
// Contenido: Secciones 1 a 4 del análisis econométrico
// Continuación: 02_twfe_extractive_export_structure.do
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************


// *****************************************************************************
// 1. Configuración del Entorno y Rutas de Trabajo
// *****************************************************************************

// 1.1. Definir el entorno de ejecución

* Limpiar la sesión y fijar la versión de Stata
version 17.0
clear all
cls
macro drop _all
capture log close _all

* Establecer opciones comunes para que los resultados sean reproducibles
set more off
set varabbrev off
set type double
set linesize 255
set seed 20260729
set sortseed 20260729


// 1.2. Verificar e instalar los paquetes necesarios

* xtserial: prueba de Wooldridge para autocorrelación de primer orden.
capture which xtserial
if _rc {
    display as text ///
        "Instalando xtserial desde el archivo oficial de Stata Journal..."
    net install st0039, ///
        from("https://www.stata-journal.com/software/sj3-2")
}

* xttest3: prueba de Wald modificada para heterocedasticidad entre países.
capture which xttest3
if _rc {
    display as text "Instalando el paquete xttest3 desde SSC..."
    ssc install xttest3
}

* xtcsd: prueba de Pesaran para dependencia transversal de los residuos.
capture which xtcsd
if _rc {
    display as text "Instalando el paquete xtcsd desde SSC..."
    ssc install xtcsd
}

* Comprobar que Stata reconoce todos los comandos que utilizará el análisis
local required_commands ///
    isid encode levelsof xtset xtdescribe ///
    xtserial xttest3 xtcsd

* Recorrer la lista anterior y detener el archivo si falta algún comando.
foreach command of local required_commands {
    capture which `command'
    if _rc {
        display as error "Stata no encuentra el comando requerido: `command'"
        exit 199
    }
}


// 1.3. Establecer la raíz reproducible del proyecto

* Definir la ruta relativa del panel maestro. Esta ruta es igual para cualquier
* persona que clone el repositorio completo, sin importar dónde lo guarde.
local panel_relative ///
    "data/processed/00_master_panel/master_panel_country_year.dta"

* Guardar el directorio desde el cual se abrió Stata. A partir de esta
* ubicación se examinarán también ocho carpetas superiores, lo que permite
* ejecutar el archivo desde la raíz, desde su carpeta o desde logs/batch.
local project_current "`c(pwd)'"

* Construir automáticamente la ubicación habitual del repositorio en Windows.
* c(username) adapta la ruta al nombre del usuario que ejecuta el archivo.
local project_windows ///
    "C:/Users/`c(username)'/GitHub/master-thesis-project-applied-econ"

* Permitir una ruta manual para equipos que guarden el repositorio en otro
* lugar. Solo es necesario escribirla entre comillas si fallan las dos
* alternativas automáticas anteriores.
local project_manual ""

* Inicializar vacía la ruta global antes de evaluar las ubicaciones candidatas.
global PROJECT_ROOT ""

* Primera búsqueda: examinar el directorio actual y hasta ocho niveles
* superiores. La primera carpeta que contenga el panel maestro se adopta como
* raíz y se normaliza mediante c(pwd).
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

* Segunda búsqueda: probar la carpeta GitHub habitual del usuario de Windows
* únicamente si la búsqueda ascendente no encontró el repositorio.
if "$PROJECT_ROOT" == "" {
    capture confirm file "`project_windows'/`panel_relative'"
    if !_rc {
        global PROJECT_ROOT "`project_windows'"
    }
}

* Tercera búsqueda: utilizar la ruta manual únicamente si fue diligenciada y
* las alternativas automáticas anteriores fallaron.
if "$PROJECT_ROOT" == "" & "`project_manual'" != "" {
    capture confirm file "`project_manual'/`panel_relative'"
    if !_rc {
        global PROJECT_ROOT "`project_manual'"
    }
}

* Detener la ejecución con instrucciones precisas si ninguna ruta contiene el
* panel maestro. En ese caso basta con editar project_manual una sola vez.
if "$PROJECT_ROOT" == "" {
    display as error "No se pudo localizar la raíz del repositorio."
    display as error "Directorio desde el cual se abrió Stata: `c(pwd)'"
    display as error "Ubicación automática examinada: `project_windows'"
    display as error "Edite local project_manual en la sección 1.3."
    exit 601
}

* Cambiar el directorio de trabajo a la raíz identificada. A partir de este
* punto todas las rutas del análisis se construyen de forma relativa.
quietly cd "$PROJECT_ROOT"

* Mostrar el directorio definitivo para confirmar la ubicación del proyecto.
display as result "Raíz del proyecto localizada correctamente:"
pwd

* Guardar las rutas del insumo para utilizarlas en las demás secciones
global DATA_MASTER ///
    "$PROJECT_ROOT/data/processed/00_master_panel"
global PANEL_FILE ///
    "$DATA_MASTER/master_panel_country_year.dta"


// 1.4. Definir y crear las carpetas de resultados

* Centralizar todas las salidas de la versión Codex
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

* Crear las carpetas si todavía no existen
capture mkdir "$PROJECT_ROOT/outputs"
capture mkdir "$PROJECT_ROOT/outputs/econometrics"
capture mkdir "$OUTPUT_ROOT"
capture mkdir "$OUTPUT_DESIGN"
capture mkdir "$OUTPUT_SAMPLE"
capture mkdir "$OUTPUT_DIAGNOSTICS"
capture mkdir "$OUTPUT_ECI"
capture mkdir "$OUTPUT_DIVX"
capture mkdir "$OUTPUT_STABILITY"
capture mkdir "$OUTPUT_FINAL"
capture mkdir "$OUTPUT_LOGS"


// 1.5. Abrir el registro de ejecución

* Abrir un log de texto exclusivo para las secciones 1 a 4. replace asegura que
* el archivo corresponda únicamente a la ejecución más reciente.
log using "$OUTPUT_LOGS/01_data_preparation_diagnostics.log", ///
    text replace name(preparation_log)

* Mostrar en pantalla las rutas y opciones principales de la ejecución
display as text   "1. Configuración"
display as result "Configuración completada sin errores."
display as result "Stata:    versión 17.0"
display as result "Proyecto: $PROJECT_ROOT"
display as result "Panel:    $PANEL_FILE"
display as result "Salidas:  $OUTPUT_ROOT"
display as result "Inicio:   `c(current_date)' `c(current_time)'"

* Registrar en el log las versiones de los tres paquetes utilizados por los
* diagnósticos. Los paquetes de estimación se verifican en el archivo 02.
display as text "Dependencias externas verificadas:"
which xtserial
which xttest3
which xtcsd


// *****************************************************************************
// 2. Carga y Validación del Panel Maestro
// *****************************************************************************

* Mostrar mensaje de inicio de la sección 2 en la consola de Stata
display as text "2. Carga y validación del panel maestro"
display as text "Directorio de trabajo: `c(pwd)'"


// 2.1. Verificar y cargar el panel maestro

* Comprobar que el archivo existe antes de intentar abrirlo
capture confirm file "$PANEL_FILE"
if _rc {
    display as error "No se encontró el panel maestro:"
    display as error "$PANEL_FILE"
    exit 601
}

* Cargar el panel sin modificar el archivo original
use "$PANEL_FILE", clear

// Variable: country_iso3_code   // Etiqueta: Código ISO3 del país
// Variable: country             // Etiqueta: Nombre del país
// Variable: year                // Etiqueta: Año
// Variable: eci                 // Etiqueta: Complejidad económica (ECI)
// Variable: divx                // Etiqueta: Diversificación exportadora (1 - HHI)
// Variable: rents               // Etiqueta: Rentas extractivas del subsuelo (% PIB)
// Variable: inst                // Etiqueta: Calidad institucional
// Variable: rents_x_inst        // Etiqueta: Interacción entre RENTS e INST
// Variable: oilpc               // Etiqueta: Renta petrolera per cápita
// Variable: gaspc               // Etiqueta: Renta gasífera per cápita
// Variable: coalpc              // Etiqueta: Renta carbonífera per cápita
// Variable: hhi                 // Etiqueta: Concentración exportadora
// Variable: pexp                // Etiqueta: Exportaciones primarias no energéticas
// Variable: fexp                // Etiqueta: Exportaciones de combustibles
// Variable: vol                 // Etiqueta: Volatilidad de términos de intercambio
// Variable: rer                 // Etiqueta: Tipo de cambio real
// Variable: humcap              // Etiqueta: Capital humano
// Variable: innov               // Etiqueta: Innovación
// Variable: net                 // Etiqueta: Conectividad digital
// Variable: log_gdppc           // Etiqueta: Logaritmo del PIB per cápita PPA
// Variable: govcons             // Etiqueta: Consumo final del gobierno
// Variable: fin                 // Etiqueta: Profundidad financiera


// 2.2. Verificar la estructura mínima del archivo

* Confirmar que están presentes todas las variables requeridas
local required_vars ///
    country_iso3_code country dres_base_mean dres_base_mean_percent year ///
    rents rents_oil_gas rents_mining inst rents_x_inst ///
    oilpc gaspc coalpc pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin eci hhi divx

* Recorrer la lista y detener la validación cuando una variable no exista.
foreach var of local required_vars {
    capture confirm variable `var'
    if _rc {
        display as error "Falta la variable requerida: `var'"
        exit 111
    }
}

* Verificar que los identificadores de país sean variables de texto
foreach var in country_iso3_code country {
    capture confirm string variable `var'
    if _rc {
        display as error "La variable `var' debe ser de tipo string."
        exit 109
    }
}

* Verificar que las variables analíticas sean numéricas
local numeric_vars ///
    dres_base_mean dres_base_mean_percent year ///
    rents rents_oil_gas rents_mining inst rents_x_inst ///
    oilpc gaspc coalpc pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin eci hhi divx

* Recorrer las variables analíticas y confirmar que todas sean numéricas.
foreach var of local numeric_vars {
    capture confirm numeric variable `var'
    if _rc {
        display as error "La variable `var' debe ser numérica."
        exit 109
    }
}

* Aplicar etiquetas descriptivas después de verificar que todas las variables
* existen. Estas etiquetas se conservan en las bases derivadas y en los
* reportes de coeficientes de las secciones 5 y 6.
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
label variable oilpc             "Renta petrolera per cápita (USD/hab)"
label variable gaspc             "Renta gasífera per cápita (USD/hab)"
label variable coalpc            "Renta carbonífera per cápita (USD/hab)"
label variable hhi               "Concentración exportadora (HHI)"
label variable pexp              "Exportaciones primarias no energéticas"
label variable fexp              "Exportaciones de combustibles"
label variable vol               "Volatilidad de términos de intercambio"
label variable rer               "Tipo de cambio real"
label variable humcap            "Capital humano"
label variable innov             "Innovación"
label variable net               "Conectividad digital"
label variable log_gdppc         "Logaritmo del PIB per cápita PPA"
label variable govcons           "Consumo final del gobierno (% PIB)"
label variable fin               "Profundidad financiera"

* Mostrar la estructura general de la base cargada
describe


// 2.3. Verificar identificadores, llave país-año y dimensiones

* Comprobar que los identificadores no tengan valores faltantes
assert !missing(country_iso3_code)
assert !missing(country)
assert !missing(year)
assert strlen(country_iso3_code) == 3
assert country_iso3_code == upper(country_iso3_code)
assert year == floor(year)

* Verificar que cada código ISO3 corresponda a un único nombre de país
bysort country_iso3_code (country): assert country == country[1]
bysort country (country_iso3_code): assert country_iso3_code == ///
    country_iso3_code[1]

* Confirmar que la combinación país-año identifica cada observación
capture isid country_iso3_code year, sort
if _rc {
    display as error "La llave country_iso3_code-year no es única."
    duplicates report country_iso3_code year
    exit 459
}

* Verificar las dimensiones esperadas del panel
quietly count
local n_observations = r(N)
assert `n_observations' == 1430

* Recuperar los años extremos y confirmar el periodo 1996-2021.
quietly summarize year, meanonly
local first_year = r(min)
local last_year  = r(max)
assert `first_year' == 1996
assert `last_year'  == 2021

* Crear un identificador numérico de país para declarar el panel
capture confirm new variable country_id
if _rc {
    display as error "La variable country_id ya existe en el panel maestro."
    exit 110
}

* Codificar el identificador ISO3 para obtener una variable numérica de panel.
encode country_iso3_code, generate(country_id)
label variable country_id "Identificador numérico de país"

* Ubicar el identificador numérico de país en la tercera columna.
order country_id, after(country)

* Contar los identificadores numéricos distintos y confirmar los 55 países.
quietly levelsof country_id, local(panel_ids)
local n_countries : word count `panel_ids'
assert `n_countries' == 55

* Comprobar que cada país tenga los 26 años consecutivos del período
bysort country_id (year): assert _N == 26
by country_id: assert year == 1995 + _n

* Declarar la estructura país-año del panel
xtset country_id year


// 2.4. Verificar los dominios económicos y contables

* Comprobar las variables expresadas como proporciones entre cero y uno
local bounded_0_1 dres_base_mean hhi divx
foreach var of local bounded_0_1 {
    assert inrange(`var', 0, 1) if !missing(`var')
}

* Comprobar las variables expresadas como porcentajes entre cero y cien
local bounded_0_100 ///
    dres_base_mean_percent rents rents_oil_gas rents_mining ///
    pexp fexp net govcons

* Recorrer las variables porcentuales y verificar su dominio de cero a cien.
foreach var of local bounded_0_100 {
    assert inrange(`var', 0, 100) if !missing(`var')
}

* Comprobar que las variables que no admiten valores negativos sean válidas
local nonnegative_vars ///
    oilpc gaspc coalpc vol humcap innov log_gdppc fin

* Recorrer las variables no negativas y comprobar su dominio observado.
foreach var of local nonnegative_vars {
    assert `var' >= 0 if !missing(`var')
}

* Verificar la equivalencia entre la medida decimal y la porcentual
assert dres_base_mean >= 0.20
assert abs(dres_base_mean_percent - 100*dres_base_mean) <= 1e-10


// 2.5. Verificar las identidades construidas en el panel

* Comprobar que DIVX sea exactamente igual a uno menos HHI
assert missing(divx) == missing(hhi)
assert abs(divx - (1 - hhi)) <= 1e-10 if !missing(divx, hhi)

* Comprobar que RENTS sea la suma de las rentas petroleras, gasíferas y mineras
assert missing(rents) == ///
    (missing(rents_oil_gas) | missing(rents_mining))
assert abs(rents - (rents_oil_gas + rents_mining)) <= 1e-10 ///
    if !missing(rents, rents_oil_gas, rents_mining)

* Comprobar que RENTS_X_INST sea la interacción entre RENTS e INST
assert missing(rents_x_inst) == (missing(rents) | missing(inst))
assert abs(rents_x_inst - rents*inst) <= 1e-10 ///
    if !missing(rents_x_inst, rents, inst)


// 2.6. Presentar el resumen de la validación

* Reportar en la consola los resultados consolidados de la validación del panel
display as result "Validación del panel completada sin errores."
display as result "Observaciones: `n_observations'"
display as result "Países:       `n_countries'"
display as result "Período:      `first_year'-`last_year'"

* Mostrar la estructura balanceada del panel país-año.
xtdescribe

* Abrir el panel maestro en el Editor de Datos en modo de solo lectura.
browse


// *****************************************************************************
// 3. Preparación de Variables y Muestras Analíticas
// *****************************************************************************

// 3.1. Evaluar y transformar las rentas extractivas per cápita

* Eliminar únicamente variables derivadas para poder repetir esta sección
capture drop ln1p_oilpc ln1p_gaspc ln1p_coalpc
capture drop n_missing_eci n_missing_divx sample_eci sample_divx

* Crear un registro temporal para comparar niveles y logaritmos
tempname transform_post
tempfile transformation_report

* Definir las columnas que tendrá el reporte de transformación
postfile `transform_post' ///
    str12 variable long observations long zeros ///
    double zero_percent skewness_level skewness_ln1p ///
    using "`transformation_report'", replace

* Aplicar ln(1+x) para conservar los ceros y reducir la asimetría
foreach var in oilpc gaspc coalpc {
    // Contar las observaciones disponibles de la variable original
    quietly count if !missing(`var')
    local n_nonmissing = r(N)

    // Contar los ceros y calcular su participación entre los valores observados
    quietly count if `var' == 0
    local n_zeros = r(N)
    local zero_percent = 100 * `n_zeros' / `n_nonmissing'

    // Calcular la asimetría de la variable expresada en niveles
    quietly summarize `var', detail
    local skewness_level = r(skewness)

    // Crear la transformación logarítmica sin eliminar observaciones iguales a cero
    generate double ln1p_`var' = ln(1 + `var') if !missing(`var')
    local var_upper = upper("`var'")
    label variable ln1p_`var' "ln(1 + `var_upper')"

    // Calcular la asimetría después de aplicar la transformación ln(1+x)
    quietly summarize ln1p_`var', detail
    local skewness_ln1p = r(skewness)

    // Confirmar que la transformación no altere el patrón de valores faltantes
    assert missing(ln1p_`var') == missing(`var')
    assert ln1p_`var' == 0 if `var' == 0

    // Añadir al reporte una fila con los resultados de esta variable
    post `transform_post' ///
        ("`var'") (`n_nonmissing') (`n_zeros') ///
        (`zero_percent') (`skewness_level') (`skewness_ln1p')
}

* Cerrar el registro temporal para poder abrirlo y exportarlo
postclose `transform_post'

* Exportar la comparación utilizada para decidir la transformación
preserve
    * Abrir temporalmente el reporte sin perder el panel que está en memoria
    use "`transformation_report'", clear

    * Redondear y formatear los resultados para facilitar su lectura
    replace zero_percent = round(zero_percent, 0.01)
    replace skewness_level = round(skewness_level, 0.001)
    replace skewness_ln1p = round(skewness_ln1p, 0.001)
    format zero_percent %9.2f
    format skewness_level skewness_ln1p %9.3f

    * Ordenar las variables antes de guardar el reporte
    sort variable

    * Exportar la comparación a la carpeta de decisiones metodológicas
    export delimited using ///
        "$OUTPUT_DESIGN/resource_transformation_comparison.csv", ///
        replace datafmt

    * Mostrar la tabla de comparación en la ventana de resultados de Stata
    list, noobs abbreviate(20)

    * Recuperar el panel completo que estaba cargado antes de abrir el reporte
restore


// 3.2. Definir las variables de cada especificación

* Definir los regresores comunes de los modelos ECI y DIVX
global MODEL_COMMON ///
    rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin

* Añadir ECI como dependiente y HHI como regresor del modelo principal
global MODEL_ECI  eci  $MODEL_COMMON hhi

* Añadir DIVX como dependiente y excluir HHI por la identidad DIVX = 1 - HHI
global MODEL_DIVX divx $MODEL_COMMON


// 3.3. Construir las muestras mediante casos completos

* Contar valores faltantes en la ecuación principal con ECI
egen n_missing_eci = rowmiss($MODEL_ECI)

* Marcar con uno las observaciones que tienen información para todo el modelo ECI
generate byte sample_eci = n_missing_eci == 0
label variable sample_eci "Muestra completa del modelo ECI"

* Contar valores faltantes en la ecuación complementaria con DIVX
egen n_missing_divx = rowmiss($MODEL_DIVX)

* Marcar con uno las observaciones que tienen información para todo el modelo DIVX
generate byte sample_divx = n_missing_divx == 0
label variable sample_divx "Muestra completa del modelo DIVX"

* Confirmar que las banderas únicamente dependan de la información observada
assert inlist(sample_eci, 0, 1)
assert inlist(sample_divx, 0, 1)
assert sample_eci == (n_missing_eci == 0)
assert sample_divx == (n_missing_divx == 0)

* Verificar la cobertura efectiva de cada modelo

* Contar las observaciones y los países de la grilla maestra completa
quietly count
local n_grid = r(N)

* Contar los países que conforman la grilla maestra completa.
quietly levelsof country_id, local(grid_country_ids)
local n_grid_countries : word count `grid_country_ids'

* Contar las observaciones, países y años disponibles para el modelo ECI
quietly count if sample_eci == 1
local n_eci = r(N)
quietly levelsof country_id if sample_eci == 1, local(eci_country_ids)
local n_eci_countries : word count `eci_country_ids'
quietly summarize year if sample_eci == 1, meanonly
local eci_first_year = r(min)
local eci_last_year  = r(max)

* Contar las observaciones, países y años disponibles para el modelo DIVX
quietly count if sample_divx == 1
local n_divx = r(N)
quietly levelsof country_id if sample_divx == 1, local(divx_country_ids)
local n_divx_countries : word count `divx_country_ids'
quietly summarize year if sample_divx == 1, meanonly
local divx_first_year = r(min)
local divx_last_year  = r(max)

* Conservar los conteos para ejecutar las siguientes subsecciones por separado
global SAMPLE_N_GRID             `n_grid'
global SAMPLE_N_GRID_COUNTRIES   `n_grid_countries'
global SAMPLE_N_ECI              `n_eci'
global SAMPLE_N_ECI_COUNTRIES    `n_eci_countries'
global SAMPLE_ECI_FIRST_YEAR     `eci_first_year'
global SAMPLE_ECI_LAST_YEAR      `eci_last_year'
global SAMPLE_N_DIVX             `n_divx'
global SAMPLE_N_DIVX_COUNTRIES   `n_divx_countries'
global SAMPLE_DIVX_FIRST_YEAR    `divx_first_year'
global SAMPLE_DIVX_LAST_YEAR     `divx_last_year'

* Validar los conteos esperados del panel cerrado
assert $SAMPLE_N_GRID == 1430
assert $SAMPLE_N_GRID_COUNTRIES == 55
assert $SAMPLE_N_ECI == 1044
assert $SAMPLE_N_ECI_COUNTRIES == 49
assert $SAMPLE_N_DIVX == 1044
assert $SAMPLE_N_DIVX_COUNTRIES == 49

* Confirmar que las muestras coincidan con la disponibilidad actual del panel
quietly count if sample_eci != sample_divx

* Detener la ejecución si las dos banderas difieren en el panel actual
assert r(N) == 0


// 3.4. Documentar la composición de las muestras

* Registrar la disponibilidad individual de las variables de cada ecuación
tempname missingness_post
tempfile missingness_report

* Definir las columnas del reporte de disponibilidad por modelo y variable
postfile `missingness_post' ///
    str8 model str24 variable long available long missing ///
    double coverage_percent using "`missingness_report'", replace

* Recorrer todas las variables requeridas por el modelo principal con ECI
foreach var of global MODEL_ECI {
    // Contar cuántas observaciones tienen información para esta variable
    quietly count if !missing(`var')
    local available = r(N)

    // Calcular cuántas observaciones faltan y el porcentaje de cobertura
    local missing = $SAMPLE_N_GRID - `available'
    local coverage = 100 * `available' / $SAMPLE_N_GRID

    // Guardar los resultados de la variable en el reporte temporal
    post `missingness_post' ///
        ("ECI") ("`var'") (`available') (`missing') (`coverage')
}

* Repetir el mismo cálculo para el modelo complementario con DIVX
foreach var of global MODEL_DIVX {
    // Contar cuántas observaciones tienen información para esta variable
    quietly count if !missing(`var')
    local available = r(N)

    // Calcular cuántas observaciones faltan y el porcentaje de cobertura
    local missing = $SAMPLE_N_GRID - `available'
    local coverage = 100 * `available' / $SAMPLE_N_GRID

    // Guardar los resultados de la variable en el reporte temporal
    post `missingness_post' ///
        ("DIVX") ("`var'") (`available') (`missing') (`coverage')
}

* Cerrar el registro temporal para poder exportar su contenido
postclose `missingness_post'

* Exportar el reporte sin reemplazar el panel cargado en memoria
preserve
    * Abrir temporalmente el reporte de disponibilidad
    use "`missingness_report'", clear

    * Redondear y formatear el porcentaje de cobertura
    replace coverage_percent = round(coverage_percent, 0.01)
    format coverage_percent %9.2f

    * Ordenar las filas por modelo y nombre de variable
    sort model variable

    * Guardar el reporte como un archivo CSV reproducible
    export delimited using ///
        "$OUTPUT_SAMPLE/sample_missingness_by_variable.csv", ///
        replace datafmt

    * Recuperar el panel completo después de terminar la exportación
restore

* Crear el resumen general de observaciones, países y período
tempname sample_post
tempfile sample_report

* Definir las columnas del resumen general de las muestras
postfile `sample_post' ///
    str8 model long observations long excluded_observations ///
    int countries int excluded_countries int first_year int last_year ///
    using "`sample_report'", replace

* Guardar los conteos del modelo principal con ECI
post `sample_post' ///
    ("ECI") ($SAMPLE_N_ECI) ($SAMPLE_N_GRID - $SAMPLE_N_ECI) ///
    ($SAMPLE_N_ECI_COUNTRIES) ///
    ($SAMPLE_N_GRID_COUNTRIES - $SAMPLE_N_ECI_COUNTRIES) ///
    ($SAMPLE_ECI_FIRST_YEAR) ($SAMPLE_ECI_LAST_YEAR)

* Guardar los conteos del modelo complementario con DIVX
post `sample_post' ///
    ("DIVX") ($SAMPLE_N_DIVX) ($SAMPLE_N_GRID - $SAMPLE_N_DIVX) ///
    ($SAMPLE_N_DIVX_COUNTRIES) ///
    ($SAMPLE_N_GRID_COUNTRIES - $SAMPLE_N_DIVX_COUNTRIES) ///
    ($SAMPLE_DIVX_FIRST_YEAR) ($SAMPLE_DIVX_LAST_YEAR)

* Cerrar el registro temporal del resumen general
postclose `sample_post'

* Exportar y mostrar el resumen sin perder el panel que está en memoria
preserve
    * Abrir temporalmente el resumen general de las muestras
    use "`sample_report'", clear

    * Exportar el resumen a la carpeta de resultados de las muestras
    export delimited using "$OUTPUT_SAMPLE/sample_summary.csv", replace

    * Mostrar el resumen en la ventana de resultados de Stata
    list, noobs abbreviate(24)

    * Recuperar el panel completo después de revisar el resumen
restore

* Documentar la cobertura de cada país
preserve
    * Sumar por país las observaciones incluidas en cada muestra
    collapse ///
        (sum) observations_eci=sample_eci ///
        observations_divx=sample_divx, ///
        by(country_iso3_code country country_id)

    * Calcular cuántos de los 26 años quedan excluidos en cada modelo
    generate int excluded_eci  = 26 - observations_eci
    generate int excluded_divx = 26 - observations_divx

    * Organizar las columnas y ordenar alfabéticamente los países
    order country_iso3_code country country_id ///
        observations_eci excluded_eci ///
        observations_divx excluded_divx
    sort country_iso3_code

    * Exportar el detalle de cobertura por país
    export delimited using ///
        "$OUTPUT_SAMPLE/sample_coverage_by_country.csv", replace

    * Recuperar el panel completo después de terminar el reporte por país
restore

* Documentar la cobertura de cada año
preserve
    * Sumar por año los países incluidos en cada muestra
    collapse ///
        (sum) observations_eci=sample_eci ///
        observations_divx=sample_divx, by(year)

    * Calcular cuántos de los 55 países quedan excluidos en cada año
    generate int excluded_eci  = 55 - observations_eci
    generate int excluded_divx = 55 - observations_divx

    * Organizar las columnas y ordenar cronológicamente los años
    order year observations_eci excluded_eci ///
        observations_divx excluded_divx
    sort year

    * Exportar el detalle de cobertura anual
    export delimited using ///
        "$OUTPUT_SAMPLE/sample_coverage_by_year.csv", replace

    * Recuperar el panel completo después de terminar el reporte anual
restore


// 3.5. Guardar las bases derivadas sin modificar el panel maestro

* Guardar una copia derivada con las transformaciones y las banderas de muestra
save "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta", replace

* Guardar la muestra completa del modelo principal con ECI
preserve
    * Conservar temporalmente solo los casos completos del modelo ECI
    keep if sample_eci == 1

    * Guardar la muestra ECI como una base independiente
    save "$OUTPUT_SAMPLE/sample_eci.dta", replace

    * Recuperar el panel completo antes de construir la muestra DIVX
restore

* Guardar la muestra completa del modelo complementario con DIVX
preserve
    * Conservar temporalmente solo los casos completos del modelo DIVX
    keep if sample_divx == 1

    * Guardar la muestra DIVX como una base independiente
    save "$OUTPUT_SAMPLE/sample_divx.dta", replace

    * Recuperar nuevamente el panel completo
restore

* Informar en la ventana de resultados que la sección terminó correctamente
display as result "Preparación de variables y muestras completada sin errores."
display as result ///
    "Muestra ECI:  $SAMPLE_N_ECI observaciones y $SAMPLE_N_ECI_COUNTRIES países."
display as result ///
    "Muestra DIVX: $SAMPLE_N_DIVX observaciones y $SAMPLE_N_DIVX_COUNTRIES países."
display as result "No se imputaron ni interpolaron valores faltantes."

* Abrir la base derivada completa en el Editor de Datos en modo de solo lectura
use "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta", clear
browse


// *****************************************************************************
// 4. Estadísticas Descriptivas y Diagnósticos
// *****************************************************************************

// 4.1. Cargar y verificar la base preparada para el análisis

* Confirmar que la sección 3 haya creado la base analítica derivada
capture confirm file "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta"
if _rc {
    display as error "No se encontró la base preparada para las estimaciones."
    display as error "Ejecute primero las secciones 1, 2 y 3."
    exit 601
}

* Cargar la base derivada sin modificar el panel maestro original
use "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta", clear

* Declarar nuevamente la estructura país-año después de cargar el archivo
xtset country_id year

* Verificar que la base conserve la grilla y las muestras validadas
quietly count
assert r(N) == 1430

* Confirmar el número de casos completos de la ecuación ECI.
quietly count if sample_eci == 1
assert r(N) == 1044

* Confirmar el número de casos completos de la ecuación DIVX.
quietly count if sample_divx == 1
assert r(N) == 1044

* Definir las variables que se describirán y diagnosticarán
global DIAGNOSTIC_VARS ///
    eci divx rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin


// 4.2. Calcular estadísticas descriptivas

* Crear un registro temporal para almacenar los estadísticos de cada variable
tempname descriptive_post
tempfile descriptive_report

* Definir las columnas del reporte descriptivo
postfile `descriptive_post' ///
    str16 analysis_sample str24 variable ///
    long observations long zeros double zero_percent ///
    double mean sd min p25 median p75 max ///
    using "`descriptive_report'", replace

* Comparar el panel completo con la muestra efectiva de estimación
foreach analysis_sample in PANEL_COMPLETE ESTIMATION {
    // Recorrer todas las variables utilizadas en las dos ecuaciones
    foreach var of global DIAGNOSTIC_VARS {
        // Definir la restricción correspondiente a cada muestra
        local restriction "!missing(`var')"
        if "`analysis_sample'" == "ESTIMATION" {
            local restriction "sample_eci == 1 & !missing(`var')"
        }

        // Contar las observaciones disponibles de la variable
        quietly count if `restriction'
        local n_available = r(N)

        // Contar los valores iguales a cero dentro de la muestra correspondiente
        quietly count if `restriction' & `var' == 0
        local n_zeros = r(N)
        local zero_share = 100 * `n_zeros' / `n_available'

        // Calcular media, dispersión, percentiles y valores extremos
        quietly summarize `var' if `restriction', detail
        local var_mean   = r(mean)
        local var_sd     = r(sd)
        local var_min    = r(min)
        local var_p25    = r(p25)
        local var_median = r(p50)
        local var_p75    = r(p75)
        local var_max    = r(max)

        // Guardar una fila del reporte para esta variable y muestra
        post `descriptive_post' ///
            ("`analysis_sample'") ("`var'") ///
            (`n_available') (`n_zeros') (`zero_share') ///
            (`var_mean') (`var_sd') (`var_min') (`var_p25') ///
            (`var_median') (`var_p75') (`var_max')
    }
}

* Cerrar el registro para poder abrir y exportar sus resultados
postclose `descriptive_post'

* Exportar los estadísticos sin perder la base que está cargada en memoria
preserve
    * Abrir temporalmente el reporte descriptivo
    use "`descriptive_report'", clear

    * Redondear los porcentajes y aplicar formatos legibles
    replace zero_percent = round(zero_percent, 0.01)
    format zero_percent %9.2f
    format mean sd min p25 median p75 max %12.6f

    * Ordenar el reporte por muestra y variable
    sort analysis_sample variable

    * Guardar los descriptivos como un archivo CSV reproducible
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/descriptive_statistics.csv", ///
        replace datafmt

    * Mostrar el reporte en la ventana de resultados de Stata
    list, sepby(analysis_sample) noobs abbreviate(20)

    * Recuperar la base analítica completa
restore


// 4.3. Examinar la variación overall, between y within

* Crear un registro para documentar la variación temporal y entre países
tempname variation_post
tempfile variation_report

* Definir las columnas del reporte de variación del panel
postfile `variation_post' ///
    str24 variable long observations int countries ///
    double average_periods mean ///
    double sd_overall sd_between sd_within within_sd_ratio ///
    byte has_within_variation using "`variation_report'", replace

* Calcular la descomposición de variación en la muestra efectiva
foreach var of global DIAGNOSTIC_VARS {
    // Ejecutar xtsum individualmente para recuperar sus resultados almacenados
    quietly xtsum `var' if sample_eci == 1

    // Calcular la proporción de la desviación overall asociada a variación within
    local within_ratio = r(sd_w) / r(sd)

    // Identificar si la variable tiene variación temporal aprovechable
    local within_available = r(sd_w) > 1e-10

    // Guardar los resultados de esta variable
    post `variation_post' ///
        ("`var'") (r(N)) (r(n)) (r(Tbar)) (r(mean)) ///
        (r(sd)) (r(sd_b)) (r(sd_w)) (`within_ratio') ///
        (`within_available')
}

* Cerrar el registro temporal de variación
postclose `variation_post'

* Exportar el reporte sin reemplazar la base analítica
preserve
    * Abrir temporalmente el reporte de variación
    use "`variation_report'", clear

    * Aplicar formatos para facilitar la comparación
    format average_periods mean ///
        sd_overall sd_between sd_within within_sd_ratio %12.6f

    * Ordenar las variables y guardar el reporte
    sort variable
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/panel_variation.csv", ///
        replace datafmt

    * Mostrar la descomposición en la ventana de resultados
    list, noobs abbreviate(24)

    * Recuperar la base analítica
restore

* Mostrar también la salida estándar de xtsum para revisión directa
xtsum $DIAGNOSTIC_VARS if sample_eci == 1


// 4.4. Examinar las correlaciones entre las variables

* Calcular la matriz de correlaciones del modelo principal con ECI
quietly correlate $MODEL_ECI if sample_eci == 1
matrix correlation_eci = r(C)

* Exportar la matriz ECI con nombres de filas y columnas
preserve
    * Convertir la matriz en variables de Stata
    clear
    svmat double correlation_eci, names(col)

    * Crear una columna que identifique la variable de cada fila
    generate str24 variable = ""
    local row_number = 1
    foreach var of global MODEL_ECI {
        replace variable = "`var'" in `row_number'
        local ++row_number
    }

    * Organizar y exportar la matriz de correlaciones ECI
    order variable
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/correlation_matrix_eci.csv", replace
restore

* Calcular la matriz de correlaciones del modelo complementario con DIVX
quietly correlate $MODEL_DIVX if sample_divx == 1
matrix correlation_divx = r(C)

* Exportar la matriz DIVX con nombres de filas y columnas
preserve
    * Convertir la matriz en variables de Stata
    clear
    svmat double correlation_divx, names(col)

    * Crear una columna que identifique la variable de cada fila
    generate str24 variable = ""
    local row_number = 1
    foreach var of global MODEL_DIVX {
        replace variable = "`var'" in `row_number'
        local ++row_number
    }

    * Organizar y exportar la matriz de correlaciones DIVX
    order variable
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/correlation_matrix_divx.csv", replace
restore

* Mostrar correlaciones y significancia para revisión en la consola
pwcorr $MODEL_ECI if sample_eci == 1, sig star(0.05)
pwcorr $MODEL_DIVX if sample_divx == 1, sig star(0.05)


// 4.5. Evaluar la colinealidad de los regresores

* Crear un registro para los factores de inflación de la varianza
tempname vif_post
tempfile vif_report

* Definir las columnas del reporte de VIF
postfile `vif_post' ///
    str8 model str24 variable double vif str12 assessment ///
    using "`vif_report'", replace

* Definir los regresores del modelo ECI, incluido HHI
local regressors_eci "$MODEL_COMMON hhi"

* Residualizar cada regresor respecto de los efectos fijos de país y año
foreach var of local regressors_eci {
    // Eliminar la variable auxiliar si esta subsección se ejecuta nuevamente
    capture drop within_`var'

    // Separar la variación que no es explicada por las dummies de país y año
    quietly regress `var' i.country_id i.year if sample_eci == 1
    predict double within_`var' if e(sample), residuals
}

* Calcular cada VIF utilizando únicamente la variación residualizada
foreach target of local regressors_eci {
    // Retirar temporalmente la variable objetivo del lado derecho
    local remaining : list regressors_eci - target

    // Construir la lista residualizada de las demás covariables
    local within_remaining ""
    foreach var of local remaining {
        local within_remaining "`within_remaining' within_`var'"
    }

    // Regresar la variación within objetivo sobre las demás variaciones within
    quietly regress within_`target' `within_remaining' ///
        if sample_eci == 1

    // Obtener el VIF como 1 dividido por 1 menos el R cuadrado auxiliar
    local vif_value = 1 / (1 - e(r2))

    // Clasificar el valor sin eliminar automáticamente ninguna variable
    local vif_assessment "LOW"
    if `vif_value' >= 5  local vif_assessment "REVIEW"
    if `vif_value' >= 10 local vif_assessment "HIGH"

    // Guardar el resultado del regresor en el reporte
    post `vif_post' ///
        ("ECI") ("`target'") (`vif_value') ("`vif_assessment'")
}

* Definir los regresores del modelo DIVX, que excluye HHI
local regressors_divx "$MODEL_COMMON"

* Repetir el cálculo de VIF con el conjunto de regresores que excluye HHI
foreach target of local regressors_divx {
    // Retirar temporalmente la variable objetivo del lado derecho
    local remaining : list regressors_divx - target

    // Construir la lista residualizada de las demás covariables
    local within_remaining ""
    foreach var of local remaining {
        local within_remaining "`within_remaining' within_`var'"
    }

    // Regresar la variación within objetivo sobre las demás variaciones within
    quietly regress within_`target' `within_remaining' ///
        if sample_divx == 1

    // Obtener el VIF de la regresión auxiliar
    local vif_value = 1 / (1 - e(r2))

    // Clasificar el valor únicamente como señal de revisión
    local vif_assessment "LOW"
    if `vif_value' >= 5  local vif_assessment "REVIEW"
    if `vif_value' >= 10 local vif_assessment "HIGH"

    // Guardar el resultado del regresor en el reporte
    post `vif_post' ///
        ("DIVX") ("`target'") (`vif_value') ("`vif_assessment'")
}

* Cerrar y exportar el reporte de colinealidad
postclose `vif_post'

* Abrir temporalmente el reporte de VIF sin reemplazar la base analítica.
preserve
    * Abrir temporalmente el reporte de VIF
    use "`vif_report'", clear

    * Ordenar primero los valores más altos dentro de cada modelo
    gsort model -vif
    format vif %12.4f

    * Exportar y mostrar el reporte
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/vif_by_model.csv", replace datafmt
    list, sepby(model) noobs abbreviate(24)

    * Recuperar la base analítica
restore

* Eliminar las variables auxiliares utilizadas exclusivamente para calcular VIF
foreach var of local regressors_eci {
    drop within_`var'
}


// 4.6. Evaluar la estructura de los errores del panel

* Crear un registro para las pruebas de especificación de los errores
tempname tests_post
tempfile tests_report

* Definir las columnas del reporte de pruebas diagnósticas
postfile `tests_post' ///
    str8 model str32 test str80 null_hypothesis ///
    double statistic df1 df2 p_value str20 decision ///
    using "`tests_report'", replace

* Ejecutar las tres pruebas para los modelos ECI y DIVX
foreach model in ECI DIVX {
    // Definir la dependiente, los regresores y la bandera de cada modelo
    local dependent "eci"
    local regressors "$MODEL_COMMON hhi"
    local sample_flag "sample_eci"

    // Sustituir la configuración predeterminada cuando se evalúa DIVX.
    if "`model'" == "DIVX" {
        local dependent "divx"
        local regressors "$MODEL_COMMON"
        local sample_flag "sample_divx"
    }

    // Estimar silenciosamente el modelo auxiliar con efectos fijos de país y año
    quietly xtreg `dependent' `regressors' i.year ///
        if `sample_flag' == 1, fe

    // Probar heterocedasticidad entre países mediante Wald modificado
    noisily xttest3
    local hetero_stat = r(wald)
    local hetero_df   = r(df)
    local hetero_p    = r(p)
    local hetero_decision "DO NOT REJECT H0"
    if `hetero_p' < 0.05 local hetero_decision "REJECT H0"

    // Guardar el resultado de heterocedasticidad
    post `tests_post' ///
        ("`model'") ("Modified Wald") ///
        ("Equal error variance across countries") ///
        (`hetero_stat') (`hetero_df') (.) (`hetero_p') ///
        ("`hetero_decision'")

    // Probar autocorrelación de primer orden mediante Wooldridge
    noisily xtserial `dependent' `regressors' if `sample_flag' == 1
    local serial_stat = r(F)
    local serial_df1  = r(df)
    local serial_df2  = r(df_r)
    local serial_p    = r(p)
    local serial_decision "DO NOT REJECT H0"
    if `serial_p' < 0.05 local serial_decision "REJECT H0"

    // Guardar el resultado de autocorrelación
    post `tests_post' ///
        ("`model'") ("Wooldridge AR(1)") ///
        ("No first-order serial correlation") ///
        (`serial_stat') (`serial_df1') (`serial_df2') (`serial_p') ///
        ("`serial_decision'")

    // Reestimar el modelo auxiliar antes de la prueba postestimación de Pesaran
    quietly xtreg `dependent' `regressors' i.year ///
        if `sample_flag' == 1, fe

    // Probar independencia transversal de los residuos
    noisily xtcsd, pesaran abs
    local cd_stat = r(pesaran)
    local cd_p = 2 * normal(-abs(`cd_stat'))
    local cd_decision "DO NOT REJECT H0"
    if `cd_p' < 0.05 local cd_decision "REJECT H0"

    // Guardar el resultado de dependencia transversal
    post `tests_post' ///
        ("`model'") ("Pesaran CD") ///
        ("Cross-sectional independence of residuals") ///
        (`cd_stat') (.) (.) (`cd_p') ("`cd_decision'")

    // Conservar los valores p para definir la inferencia de los modelos
    if "`model'" == "ECI" {
        global P_HET_ECI    `hetero_p'
        global P_SERIAL_ECI `serial_p'
        global P_CD_ECI     `cd_p'
    }

    // Guardar por separado los valores p obtenidos para el modelo DIVX.
    if "`model'" == "DIVX" {
        global P_HET_DIVX    `hetero_p'
        global P_SERIAL_DIVX `serial_p'
        global P_CD_DIVX     `cd_p'
    }
}

* Cerrar y exportar el reporte de pruebas diagnósticas
postclose `tests_post'

* Abrir temporalmente el reporte de pruebas sin perder la base analítica.
preserve
    * Abrir temporalmente el reporte de pruebas
    use "`tests_report'", clear

    * Aplicar formatos y ordenar las pruebas por modelo
    format statistic p_value %12.6f
    sort model test

    * Exportar y mostrar los resultados
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/panel_error_tests.csv", replace datafmt
    list, sepby(model) noobs abbreviate(24)

    * Recuperar la base analítica
restore

* Adoptar errores agrupados por país si hay heterocedasticidad o autocorrelación
global INFERENCE_MAIN "vce(cluster country_id)"

* Mostrar la estrategia de inferencia que utilizarán los modelos principales.
display as result ///
    "Inferencia principal recomendada: errores estándar agrupados por país."

* Advertir si la dependencia transversal requiere una sensibilidad adicional
if $P_CD_ECI < 0.05 | $P_CD_DIVX < 0.05 {
    display as error ///
        "Alerta: revisar inferencia alternativa por dependencia transversal."
}


// 4.7. Identificar observaciones potencialmente influyentes

* Crear archivos temporales para reunir las alertas de los dos modelos
tempfile influence_eci influence_divx

* Calcular influencia mediante una regresión auxiliar TWFE para ECI
preserve
    * Estimar ECI con indicadores de país y año solo para fines diagnósticos
    quietly regress eci $MODEL_COMMON hhi ///
        i.country_id i.year if sample_eci == 1

    * Calcular umbrales convencionales según N y número de parámetros
    local influence_n = e(N)
    local influence_k = e(df_m) + 1
    local leverage_threshold = 2 * `influence_k' / `influence_n'
    local cooks_threshold = 4 / `influence_n'

    * Obtener apalancamiento, distancia de Cook y residuo estandarizado
    predict double leverage if e(sample), hat
    predict double cooks_distance if e(sample), cooksd
    predict double standardized_residual if e(sample), rstandard

    * Crear alertas separadas para cada criterio de influencia
    generate byte flag_leverage = ///
        leverage > `leverage_threshold' if e(sample)
    generate byte flag_cooks = ///
        cooks_distance > `cooks_threshold' if e(sample)
    generate byte flag_residual = ///
        abs(standardized_residual) > 3 if e(sample)

    * Conservar solo observaciones que activan al menos una alerta
    keep if e(sample) & ///
        (flag_leverage == 1 | flag_cooks == 1 | flag_residual == 1)

    * Identificar el modelo y guardar los umbrales utilizados
    generate str8 model = "ECI"
    generate double dependent_value = eci
    generate double leverage_cutoff = `leverage_threshold'
    generate double cooks_cutoff = `cooks_threshold'

    * Seleccionar las columnas necesarias para revisar cada observación
    keep model country_iso3_code country country_id year dependent_value ///
        leverage leverage_cutoff cooks_distance cooks_cutoff ///
        standardized_residual ///
        flag_leverage flag_cooks flag_residual

    * Guardar temporalmente las alertas del modelo ECI
    save "`influence_eci'", replace
restore

* Repetir el diagnóstico de influencia para el modelo DIVX
preserve
    * Estimar DIVX con efectos de país y año, excluyendo HHI
    quietly regress divx $MODEL_COMMON ///
        i.country_id i.year if sample_divx == 1

    * Calcular umbrales convencionales según N y número de parámetros
    local influence_n = e(N)
    local influence_k = e(df_m) + 1
    local leverage_threshold = 2 * `influence_k' / `influence_n'
    local cooks_threshold = 4 / `influence_n'

    * Obtener apalancamiento, distancia de Cook y residuo estandarizado
    predict double leverage if e(sample), hat
    predict double cooks_distance if e(sample), cooksd
    predict double standardized_residual if e(sample), rstandard

    * Crear alertas separadas para cada criterio de influencia
    generate byte flag_leverage = ///
        leverage > `leverage_threshold' if e(sample)
    generate byte flag_cooks = ///
        cooks_distance > `cooks_threshold' if e(sample)
    generate byte flag_residual = ///
        abs(standardized_residual) > 3 if e(sample)

    * Conservar solo observaciones que activan al menos una alerta
    keep if e(sample) & ///
        (flag_leverage == 1 | flag_cooks == 1 | flag_residual == 1)

    * Identificar el modelo y guardar los umbrales utilizados
    generate str8 model = "DIVX"
    generate double dependent_value = divx
    generate double leverage_cutoff = `leverage_threshold'
    generate double cooks_cutoff = `cooks_threshold'

    * Seleccionar las columnas necesarias para revisar cada observación
    keep model country_iso3_code country country_id year dependent_value ///
        leverage leverage_cutoff cooks_distance cooks_cutoff ///
        standardized_residual ///
        flag_leverage flag_cooks flag_residual

    * Guardar temporalmente las alertas del modelo DIVX
    save "`influence_divx'", replace
restore

* Unir y exportar las alertas sin excluir observaciones de las estimaciones
preserve
    * Abrir las alertas ECI y anexar las correspondientes a DIVX
    use "`influence_eci'", clear
    append using "`influence_divx'"

    * Ordenar primero las mayores distancias de Cook dentro de cada modelo
    gsort model -cooks_distance

    * Aplicar formatos y exportar el reporte
    format leverage leverage_cutoff ///
        cooks_distance cooks_cutoff standardized_residual %12.6f
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/influential_observations.csv", ///
        replace datafmt

    * Mostrar las alertas en la ventana de resultados
    list, sepby(model) noobs abbreviate(20)

    * Recuperar la base analítica completa
restore

* Informar que todos los descriptivos y diagnósticos fueron completados.
display as result "Sección 4 completada: descriptivos y diagnósticos exportados."
display as result ///
    "No se eliminaron países ni observaciones por los diagnósticos de influencia."

* Cerrar el registro al finalizar las secciones de preparación y diagnóstico
display as result "Archivo 01 completado: secciones 1 a 4 ejecutadas sin errores."
log close preparation_log
