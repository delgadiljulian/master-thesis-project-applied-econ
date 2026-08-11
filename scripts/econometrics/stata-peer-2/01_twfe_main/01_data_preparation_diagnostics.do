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

* Limpiar la sesión y fijar la versión de Stata.
version 17.0
* Limpiar la memoria de Stata borrando todas las variables cargadas.
clear all
* Limpiar la consola de comandos de Stata.
cls
* Eliminar todas las variables temporales y globales de la memoria.
macro drop _all
* Cerrar cualquier registro de texto (log) abierto previamente.
capture log close _all

* Establecer opciones comunes para que los resultados sean reproducibles.
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

* Comprobar que Stata reconoce todos los comandos que utilizará el análisis.
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

* Definir la ruta relativa del panel maestro. Esta ruta es igual para cualquier persona que clone el repositorio completo, sin importar dónde lo guarde.
local panel_relative ///
    "data/processed/00_master_panel/master_panel_country_year.dta"

* Guardar el directorio desde el cual se abrió Stata. A partir de esta ubicación se examinarán también ocho carpetas superiores, lo que permite ejecutar el archivo desde la raíz, desde su carpeta o desde logs/batch.
local project_current "`c(pwd)'"

* Construir automáticamente la ubicación habitual del repositorio en Windows. c(username) adapta la ruta al nombre del usuario que ejecuta el archivo.
local project_windows ///
    "C:/Users/`c(username)'/GitHub/master-thesis-project-applied-econ"

* Permitir una ruta manual para equipos que guarden el repositorio en otro lugar. Solo es necesario escribirla entre comillas si fallan las dos alternativas automáticas anteriores.
local project_manual ""

* Inicializar vacía la ruta global antes de evaluar las ubicaciones candidatas.
global PROJECT_ROOT ""

* Primera búsqueda: examinar el directorio actual y hasta ocho niveles superiores. La primera carpeta que contenga el panel maestro se adopta como raíz y se normaliza mediante c(pwd).
local project_candidate "`project_current'"
forvalues search_level = 0/8 {
    if "$PROJECT_ROOT" == "" {
        * Verificar la existencia de un archivo antes de intentar cargarlo.
        capture confirm file "`project_candidate'/`panel_relative'"
        if !_rc {
            quietly cd "`project_candidate'"
            global PROJECT_ROOT "`c(pwd)'"
        }
    }
    local project_candidate "`project_candidate'/.."
}

* Segunda búsqueda: probar la carpeta GitHub habitual del usuario de Windows únicamente si la búsqueda ascendente no encontró el repositorio.
if "$PROJECT_ROOT" == "" {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "`project_windows'/`panel_relative'"
    if !_rc {
        global PROJECT_ROOT "`project_windows'"
    }
}

* Tercera búsqueda: utilizar la ruta manual únicamente si fue diligenciada y las alternativas automáticas anteriores fallaron.
if "$PROJECT_ROOT" == "" & "`project_manual'" != "" {
    * Verificar la existencia de un archivo antes de intentar cargarlo.
    capture confirm file "`project_manual'/`panel_relative'"
    if !_rc {
        global PROJECT_ROOT "`project_manual'"
    }
}

* Detener la ejecución con instrucciones precisas si ninguna ruta contiene el panel maestro. En ese caso basta con editar project_manual una sola vez.
if "$PROJECT_ROOT" == "" {
    display as error "No se pudo localizar la raíz del repositorio."
    display as error "Directorio desde el cual se abrió Stata: `c(pwd)'"
    display as error "Ubicación automática examinada: `project_windows'"
    display as error "Edite local project_manual en la sección 1.3."
    exit 601
}

* Cambiar el directorio de trabajo a la raíz identificada. A partir de este punto todas las rutas del análisis se construyen de forma relativa.
quietly cd "$PROJECT_ROOT"

* Mostrar el directorio definitivo para confirmar la ubicación del proyecto.
display as result "Raíz del proyecto localizada correctamente:"
pwd

* Guardar las rutas del insumo para utilizarlas en las demás secciones.
global DATA_MASTER ///
    "$PROJECT_ROOT/data/processed/00_master_panel"
global PANEL_FILE ///
    "$DATA_MASTER/master_panel_country_year.dta"


// 1.4. Definir y crear las carpetas de resultados

* Centralizar todas las salidas de la versión Codex.
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

* Crear las carpetas si todavía no existen.
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

* Abrir un log de texto exclusivo para las secciones 1 a 4. replace asegura que el archivo corresponda únicamente a la ejecución más reciente.
log using "$OUTPUT_LOGS/01_data_preparation_diagnostics.log", ///
    text replace name(preparation_log)

* Mostrar en pantalla las rutas y opciones principales de la ejecución.
display as text   "1. Configuración"
display as result "Configuración completada sin errores."
display as result "Stata:    versión 17.0"
display as result "Proyecto: $PROJECT_ROOT"
display as result "Panel:    $PANEL_FILE"
display as result "Salidas:  $OUTPUT_ROOT"
display as result "Inicio:   `c(current_date)' `c(current_time)'"

* Registrar en el log las versiones de los tres paquetes utilizados por los diagnósticos. Los paquetes de estimación se verifican en el archivo 02.
display as text "Dependencias externas verificadas:"
which xtserial
which xttest3
which xtcsd


// *****************************************************************************
// 2. Carga y Validación del Panel Maestro
// *****************************************************************************

* Mostrar mensaje de inicio de la sección 2 en la consola de Stata.
display as text "2. Carga y validación del panel maestro"
display as text "Directorio de trabajo: `c(pwd)'"


// 2.1. Verificar y cargar el panel maestro

* Comprobar que el archivo existe antes de intentar abrirlo.
capture confirm file "$PANEL_FILE"
if _rc {
    display as error "No se encontró el panel maestro:"
    display as error "$PANEL_FILE"
    exit 601
}

* Cargar el panel sin modificar el archivo original.
use "$PANEL_FILE", clear

// Variable: country_iso3_code // Etiqueta: Código ISO3 del país Variable: country // Etiqueta: Nombre del país Variable: year // Etiqueta: Año Variable: eci // Etiqueta: Complejidad económica (ECI) Variable: divx // Etiqueta: Diversificación exportadora (1 - HHI) Variable: rents // Etiqueta: Rentas extractivas del subsuelo (% PIB) Variable: inst // Etiqueta: Calidad institucional Variable: rents_x_inst // Etiqueta: Interacción entre RENTS e INST Variable: oilpc // Etiqueta: Renta petrolera per cápita Variable: gaspc // Etiqueta: Renta gasífera per cápita Variable: coalpc // Etiqueta: Renta carbonífera per cápita Variable: hhi // Etiqueta: Concentración exportadora Variable: pexp // Etiqueta: Exportaciones primarias no energéticas Variable: fexp // Etiqueta: Exportaciones de combustibles Variable: vol // Etiqueta: Volatilidad de términos de intercambio Variable: rer // Etiqueta: Tipo de cambio real Variable: humcap // Etiqueta: Capital humano Variable: innov // Etiqueta: Innovación Variable: net // Etiqueta: Conectividad digital Variable: log_gdppc // Etiqueta: Logaritmo del PIB per cápita PPA Variable: govcons // Etiqueta: Consumo final del gobierno Variable: fin // Etiqueta: Profundidad financiera.


// 2.2. Verificar la estructura mínima del archivo

* Confirmar que están presentes todas las variables requeridas.
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

* Verificar que los identificadores de país sean variables de texto.
foreach var in country_iso3_code country {
    capture confirm string variable `var'
    if _rc {
        display as error "La variable `var' debe ser de tipo string."
        exit 109
    }
}

* Verificar que las variables analíticas sean numéricas.
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

* Aplicar etiquetas descriptivas después de verificar que todas las variables existen. Estas etiquetas se conservan en las bases derivadas y en los reportes de coeficientes de las secciones 5 y 6.
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

* Mostrar la estructura general de la base cargada.
describe


// 2.3. Verificar identificadores, llave país-año y dimensiones

* Comprobar que los identificadores no tengan valores faltantes.
assert !missing(country_iso3_code)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(country)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert !missing(year)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert strlen(country_iso3_code) == 3
* Control de calidad automático que detiene el script si no se cumple la condición.
assert country_iso3_code == upper(country_iso3_code)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert year == floor(year)

* Verificar que cada código ISO3 corresponda a un único nombre de país.
bysort country_iso3_code (country): assert country == country[1]
bysort country (country_iso3_code): assert country_iso3_code == ///
    country_iso3_code[1]

* Confirmar que la combinación país-año identifica cada observación.
capture isid country_iso3_code year, sort
if _rc {
    display as error "La llave country_iso3_code-year no es única."
    duplicates report country_iso3_code year
    exit 459
}

* Verificar las dimensiones esperadas del panel.
quietly count
local n_observations = r(N)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `n_observations' == 1430

* Recuperar los años extremos y confirmar el periodo 1996-2021.
quietly summarize year, meanonly
local first_year = r(min)
local last_year  = r(max)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `first_year' == 1996
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `last_year'  == 2021

* Crear un identificador numérico de país para declarar el panel.
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
* Control de calidad automático que detiene el script si no se cumple la condición.
assert `n_countries' == 55

* Comprobar que cada país tenga los 26 años consecutivos del período.
bysort country_id (year): assert _N == 26
by country_id: assert year == 1995 + _n

* Declarar la estructura país-año del panel.
xtset country_id year


// 2.4. Verificar los dominios económicos y contables

* Comprobar las variables expresadas como proporciones entre cero y uno.
local bounded_0_1 dres_base_mean hhi divx
foreach var of local bounded_0_1 {
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert inrange(`var', 0, 1) if !missing(`var')
}

* Comprobar las variables expresadas como porcentajes entre cero y cien.
local bounded_0_100 ///
    dres_base_mean_percent rents rents_oil_gas rents_mining ///
    pexp fexp net govcons

* Recorrer las variables porcentuales y verificar su dominio de cero a cien.
foreach var of local bounded_0_100 {
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert inrange(`var', 0, 100) if !missing(`var')
}

* Comprobar que las variables que no admiten valores negativos sean válidas.
local nonnegative_vars ///
    oilpc gaspc coalpc vol humcap innov log_gdppc fin

* Recorrer las variables no negativas y comprobar su dominio observado.
foreach var of local nonnegative_vars {
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert `var' >= 0 if !missing(`var')
}

* Verificar la equivalencia entre la medida decimal y la porcentual.
assert dres_base_mean >= 0.20
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(dres_base_mean_percent - 100*dres_base_mean) <= 1e-10


// 2.5. Verificar las identidades construidas en el panel

* Comprobar que DIVX sea exactamente igual a uno menos HHI.
assert missing(divx) == missing(hhi)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(divx - (1 - hhi)) <= 1e-10 if !missing(divx, hhi)

* Comprobar que RENTS sea la suma de las rentas petroleras, gasíferas y mineras.
assert missing(rents) == ///
    (missing(rents_oil_gas) | missing(rents_mining))
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(rents - (rents_oil_gas + rents_mining)) <= 1e-10 ///
    if !missing(rents, rents_oil_gas, rents_mining)

* Comprobar que RENTS_X_INST sea la interacción entre RENTS e INST.
assert missing(rents_x_inst) == (missing(rents) | missing(inst))
* Control de calidad automático que detiene el script si no se cumple la condición.
assert abs(rents_x_inst - rents*inst) <= 1e-10 ///
    if !missing(rents_x_inst, rents, inst)


// 2.6. Presentar el resumen de la validación

* Reportar en la consola los resultados consolidados de la validación del panel.
display as result "Validación del panel completada sin errores."
display as result "Observaciones: `n_observations'"
display as result "Países:       `n_countries'"
display as result "Período:      `first_year'-`last_year'"

* Mostrar la estructura balanceada del panel país-año.
xtdescribe

* No abrir el Editor de Datos desde el script. Esto mantiene la ejecución
* reproducible tanto en modo interactivo como mediante el ejecutor por lotes.


// *****************************************************************************
// 3. Preparación de Variables y Muestras Analíticas
// *****************************************************************************

// 3.1. Evaluar y transformar las rentas extractivas per cápita

* Eliminar únicamente variables derivadas para poder repetir esta sección.
capture drop ln1p_oilpc ln1p_gaspc ln1p_coalpc
capture drop n_missing_eci n_missing_divx sample_eci sample_divx

* Crear un registro temporal para comparar niveles y logaritmos.
tempname transform_post
tempfile transformation_report

* Definir las columnas que tendrá el reporte de transformación.
postfile `transform_post' ///
    str12 variable long observations long zeros ///
    double zero_percent skewness_level skewness_ln1p ///
    using "`transformation_report'", replace

* Aplicar ln(1+x) para conservar los ceros y reducir la asimetría.
foreach var in oilpc gaspc coalpc {
    // Contar las observaciones disponibles de la variable original.
    quietly count if !missing(`var')
    local n_nonmissing = r(N)

    // Contar los ceros y calcular su participación entre los valores observados.
    quietly count if `var' == 0
    local n_zeros = r(N)
    local zero_percent = 100 * `n_zeros' / `n_nonmissing'

    // Calcular la asimetría de la variable expresada en niveles.
    quietly summarize `var', detail
    local skewness_level = r(skewness)

    // Crear la transformación logarítmica sin eliminar observaciones iguales a cero.
    generate double ln1p_`var' = ln(1 + `var') if !missing(`var')
    local var_upper = upper("`var'")
    label variable ln1p_`var' "ln(1 + `var_upper')"

    // Calcular la asimetría después de aplicar la transformación ln(1+x).
    quietly summarize ln1p_`var', detail
    local skewness_ln1p = r(skewness)

    // Confirmar que la transformación no altere el patrón de valores faltantes.
    assert missing(ln1p_`var') == missing(`var')
    * Control de calidad automático que detiene el script si no se cumple la condición.
    assert ln1p_`var' == 0 if `var' == 0

    // Añadir al reporte una fila con los resultados de esta variable.
    post `transform_post' ///
        ("`var'") (`n_nonmissing') (`n_zeros') ///
        (`zero_percent') (`skewness_level') (`skewness_ln1p')
}

* Cerrar el registro temporal para poder abrirlo y exportarlo.
postclose `transform_post'

* Exportar la comparación utilizada para decidir la transformación.
preserve
    * Abrir temporalmente el reporte sin perder el panel que está en memoria.
    use "`transformation_report'", clear

    * Redondear y formatear los resultados para facilitar su lectura.
    replace zero_percent = round(zero_percent, 0.01)
    replace skewness_level = round(skewness_level, 0.001)
    replace skewness_ln1p = round(skewness_ln1p, 0.001)
    format zero_percent %9.2f
    format skewness_level skewness_ln1p %9.3f

    * Ordenar las variables antes de guardar el reporte.
    sort variable

    * Exportar la comparación a la carpeta de decisiones metodológicas.
    export delimited using ///
        "$OUTPUT_DESIGN/resource_transformation_comparison.csv", ///
        replace datafmt

    * Mostrar la tabla de comparación en la ventana de resultados de Stata.
    list, noobs abbreviate(20)

    * Recuperar el panel completo que estaba cargado antes de abrir el reporte.
restore


// 3.2. Definir las variables de cada especificación

* Definir los regresores comunes de los modelos ECI y DIVX.
global MODEL_COMMON ///
    rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin

* Añadir ECI como dependiente y HHI como regresor del modelo principal.
global MODEL_ECI  eci  $MODEL_COMMON hhi

* Añadir DIVX como dependiente y excluir HHI por la identidad DIVX = 1 - HHI.
global MODEL_DIVX divx $MODEL_COMMON


// 3.3. Construir las muestras mediante casos completos

* Contar valores faltantes en la ecuación principal con ECI.
egen n_missing_eci = rowmiss($MODEL_ECI)

* Marcar con uno las observaciones que tienen información para todo el modelo ECI.
generate byte sample_eci = n_missing_eci == 0
label variable sample_eci "Muestra completa del modelo ECI"

* Contar valores faltantes en la ecuación complementaria con DIVX.
egen n_missing_divx = rowmiss($MODEL_DIVX)

* Marcar con uno las observaciones que tienen información para todo el modelo DIVX.
generate byte sample_divx = n_missing_divx == 0
label variable sample_divx "Muestra completa del modelo DIVX"

* Confirmar que las banderas únicamente dependan de la información observada.
assert inlist(sample_eci, 0, 1)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert inlist(sample_divx, 0, 1)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_eci == (n_missing_eci == 0)
* Control de calidad automático que detiene el script si no se cumple la condición.
assert sample_divx == (n_missing_divx == 0)

* Verificar la cobertura efectiva de cada modelo.

* Contar las observaciones y los países de la grilla maestra completa.
quietly count
local n_grid = r(N)

* Contar los países que conforman la grilla maestra completa.
quietly levelsof country_id, local(grid_country_ids)
local n_grid_countries : word count `grid_country_ids'

* Contar las observaciones, países y años disponibles para el modelo ECI.
quietly count if sample_eci == 1
local n_eci = r(N)
quietly levelsof country_id if sample_eci == 1, local(eci_country_ids)
local n_eci_countries : word count `eci_country_ids'
quietly summarize year if sample_eci == 1, meanonly
local eci_first_year = r(min)
local eci_last_year  = r(max)

* Contar las observaciones, países y años disponibles para el modelo DIVX.
quietly count if sample_divx == 1
local n_divx = r(N)
quietly levelsof country_id if sample_divx == 1, local(divx_country_ids)
local n_divx_countries : word count `divx_country_ids'
quietly summarize year if sample_divx == 1, meanonly
local divx_first_year = r(min)
local divx_last_year  = r(max)

* Conservar los conteos para ejecutar las siguientes subsecciones por separado.
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

* Validar los conteos esperados del panel cerrado.
assert $SAMPLE_N_GRID == 1430
* Control de calidad automático que detiene el script si no se cumple la condición.
assert $SAMPLE_N_GRID_COUNTRIES == 55
* Control de calidad automático que detiene el script si no se cumple la condición.
assert $SAMPLE_N_ECI == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert $SAMPLE_N_ECI_COUNTRIES == 49
* Control de calidad automático que detiene el script si no se cumple la condición.
assert $SAMPLE_N_DIVX == 1044
* Control de calidad automático que detiene el script si no se cumple la condición.
assert $SAMPLE_N_DIVX_COUNTRIES == 49

* Confirmar que las muestras coincidan con la disponibilidad actual del panel.
quietly count if sample_eci != sample_divx

* Detener la ejecución si las dos banderas difieren en el panel actual.
assert r(N) == 0


// 3.4. Documentar la composición de las muestras

* Registrar la disponibilidad individual de las variables de cada ecuación.
tempname missingness_post
tempfile missingness_report

* Definir las columnas del reporte de disponibilidad por modelo y variable.
postfile `missingness_post' ///
    str8 model str24 variable long available long missing ///
    double coverage_percent using "`missingness_report'", replace

* Recorrer todas las variables requeridas por el modelo principal con ECI.
foreach var of global MODEL_ECI {
    // Contar cuántas observaciones tienen información para esta variable.
    quietly count if !missing(`var')
    local available = r(N)

    // Calcular cuántas observaciones faltan y el porcentaje de cobertura.
    local missing = $SAMPLE_N_GRID - `available'
    local coverage = 100 * `available' / $SAMPLE_N_GRID

    // Guardar los resultados de la variable en el reporte temporal.
    post `missingness_post' ///
        ("ECI") ("`var'") (`available') (`missing') (`coverage')
}

* Repetir el mismo cálculo para el modelo complementario con DIVX.
foreach var of global MODEL_DIVX {
    // Contar cuántas observaciones tienen información para esta variable.
    quietly count if !missing(`var')
    local available = r(N)

    // Calcular cuántas observaciones faltan y el porcentaje de cobertura.
    local missing = $SAMPLE_N_GRID - `available'
    local coverage = 100 * `available' / $SAMPLE_N_GRID

    // Guardar los resultados de la variable en el reporte temporal.
    post `missingness_post' ///
        ("DIVX") ("`var'") (`available') (`missing') (`coverage')
}

* Cerrar el registro temporal para poder exportar su contenido.
postclose `missingness_post'

* Exportar el reporte sin reemplazar el panel cargado en memoria.
preserve
    * Abrir temporalmente el reporte de disponibilidad.
    use "`missingness_report'", clear

    * Redondear y formatear el porcentaje de cobertura.
    replace coverage_percent = round(coverage_percent, 0.01)
    format coverage_percent %9.2f

    * Ordenar las filas por modelo y nombre de variable.
    sort model variable

    * Guardar el reporte como un archivo CSV reproducible.
    export delimited using ///
        "$OUTPUT_SAMPLE/sample_missingness_by_variable.csv", ///
        replace datafmt

    * Recuperar el panel completo después de terminar la exportación.
restore

* Crear el resumen general de observaciones, países y período.
tempname sample_post
tempfile sample_report

* Definir las columnas del resumen general de las muestras.
postfile `sample_post' ///
    str8 model long observations long excluded_observations ///
    int countries int excluded_countries int first_year int last_year ///
    using "`sample_report'", replace

* Guardar los conteos del modelo principal con ECI.
post `sample_post' ///
    ("ECI") ($SAMPLE_N_ECI) ($SAMPLE_N_GRID - $SAMPLE_N_ECI) ///
    ($SAMPLE_N_ECI_COUNTRIES) ///
    ($SAMPLE_N_GRID_COUNTRIES - $SAMPLE_N_ECI_COUNTRIES) ///
    ($SAMPLE_ECI_FIRST_YEAR) ($SAMPLE_ECI_LAST_YEAR)

* Guardar los conteos del modelo complementario con DIVX.
post `sample_post' ///
    ("DIVX") ($SAMPLE_N_DIVX) ($SAMPLE_N_GRID - $SAMPLE_N_DIVX) ///
    ($SAMPLE_N_DIVX_COUNTRIES) ///
    ($SAMPLE_N_GRID_COUNTRIES - $SAMPLE_N_DIVX_COUNTRIES) ///
    ($SAMPLE_DIVX_FIRST_YEAR) ($SAMPLE_DIVX_LAST_YEAR)

* Cerrar el registro temporal del resumen general.
postclose `sample_post'

* Exportar y mostrar el resumen sin perder el panel que está en memoria.
preserve
    * Abrir temporalmente el resumen general de las muestras.
    use "`sample_report'", clear

    * Exportar el resumen a la carpeta de resultados de las muestras.
    export delimited using "$OUTPUT_SAMPLE/sample_summary.csv", replace

    * Mostrar el resumen en la ventana de resultados de Stata.
    list, noobs abbreviate(24)

    * Recuperar el panel completo después de revisar el resumen.
restore

* Documentar la cobertura de cada país.
preserve
    * Sumar por país las observaciones incluidas en cada muestra.
    collapse ///
        (sum) observations_eci=sample_eci ///
        observations_divx=sample_divx, ///
        by(country_iso3_code country country_id)

    * Calcular cuántos de los 26 años quedan excluidos en cada modelo.
    generate int excluded_eci  = 26 - observations_eci
    generate int excluded_divx = 26 - observations_divx

    * Organizar las columnas y ordenar alfabéticamente los países.
    order country_iso3_code country country_id ///
        observations_eci excluded_eci ///
        observations_divx excluded_divx
    sort country_iso3_code

    * Exportar el detalle de cobertura por país.
    export delimited using ///
        "$OUTPUT_SAMPLE/sample_coverage_by_country.csv", replace

    * Recuperar el panel completo después de terminar el reporte por país.
restore

* Documentar la cobertura de cada año.
preserve
    * Sumar por año los países incluidos en cada muestra.
    collapse ///
        (sum) observations_eci=sample_eci ///
        observations_divx=sample_divx, by(year)

    * Calcular cuántos de los 55 países quedan excluidos en cada año.
    generate int excluded_eci  = 55 - observations_eci
    generate int excluded_divx = 55 - observations_divx

    * Organizar las columnas y ordenar cronológicamente los años.
    order year observations_eci excluded_eci ///
        observations_divx excluded_divx
    sort year

    * Exportar el detalle de cobertura anual.
    export delimited using ///
        "$OUTPUT_SAMPLE/sample_coverage_by_year.csv", replace

    * Recuperar el panel completo después de terminar el reporte anual.
restore

* Documentar la estructura temporal efectiva de cada país. Este reporte
* distingue los países completamente excluidos de aquellos que participan en
* la muestra pero presentan vacíos al inicio, al final o dentro de su período.
preserve
    * Identificar los países que aportan al menos una observación a cada
    * muestra, sin modificar las banderas de casos completos.
    bysort country_id: egen byte eligible_eci = max(sample_eci)
    bysort country_id: egen byte eligible_divx = max(sample_divx)

    * Conservar el año únicamente cuando la observación pertenece a la muestra.
    generate int observed_year_eci = year if sample_eci == 1
    generate int observed_year_divx = year if sample_divx == 1

    * Resumir la cobertura temporal de cada país.
    collapse ///
        (sum) observations_eci=sample_eci ///
        observations_divx=sample_divx ///
        (min) first_year_eci=observed_year_eci ///
        first_year_divx=observed_year_divx ///
        (max) last_year_eci=observed_year_eci ///
        last_year_divx=observed_year_divx ///
        eligible_eci eligible_divx, ///
        by(country_iso3_code country country_id)

    * Calcular la extensión observada y separar faltantes internos de faltantes
    * ubicados antes o después del período efectivo de cada país.
    generate int observed_span_eci = ///
        last_year_eci - first_year_eci + 1 if eligible_eci == 1
    generate int observed_span_divx = ///
        last_year_divx - first_year_divx + 1 if eligible_divx == 1

    generate int internal_missing_eci = ///
        observed_span_eci - observations_eci if eligible_eci == 1
    generate int internal_missing_divx = ///
        observed_span_divx - observations_divx if eligible_divx == 1

    generate int leading_missing_eci = ///
        first_year_eci - 1996 if eligible_eci == 1
    generate int leading_missing_divx = ///
        first_year_divx - 1996 if eligible_divx == 1

    generate int trailing_missing_eci = ///
        2021 - last_year_eci if eligible_eci == 1
    generate int trailing_missing_divx = ///
        2021 - last_year_divx if eligible_divx == 1

    * Clasificar la continuidad temporal sin imputar ni completar años.
    generate str20 temporal_status_eci = "FULLY_EXCLUDED"
    replace temporal_status_eci = "CONTINUOUS" if ///
        eligible_eci == 1 & internal_missing_eci == 0
    replace temporal_status_eci = "INTERRUPTED" if ///
        eligible_eci == 1 & internal_missing_eci > 0

    generate str20 temporal_status_divx = "FULLY_EXCLUDED"
    replace temporal_status_divx = "CONTINUOUS" if ///
        eligible_divx == 1 & internal_missing_divx == 0
    replace temporal_status_divx = "INTERRUPTED" if ///
        eligible_divx == 1 & internal_missing_divx > 0

    * La identidad de muestras debe mantenerse también en este resumen.
    assert observations_eci == observations_divx
    assert eligible_eci == eligible_divx
    assert first_year_eci == first_year_divx if eligible_eci == 1
    assert last_year_eci == last_year_divx if eligible_eci == 1
    assert internal_missing_eci == internal_missing_divx ///
        if eligible_eci == 1

    * Ordenar y exportar el contrato temporal por país.
    order country_iso3_code country country_id ///
        eligible_eci observations_eci first_year_eci last_year_eci ///
        observed_span_eci internal_missing_eci ///
        leading_missing_eci trailing_missing_eci temporal_status_eci ///
        eligible_divx observations_divx first_year_divx last_year_divx ///
        observed_span_divx internal_missing_divx ///
        leading_missing_divx trailing_missing_divx temporal_status_divx
    sort country_iso3_code

    export delimited using ///
        "$OUTPUT_SAMPLE/sample_time_structure_by_country.csv", ///
        replace datafmt
restore

* Documentar la estructura temporal por año usando como denominador los países
* elegibles de cada muestra. Así se evita confundir los países completamente
* excluidos con faltantes temporales entre los países participantes.
preserve
    * Marcar si cada país aparece alguna vez en las muestras analíticas.
    bysort country_id: egen byte eligible_eci = max(sample_eci)
    bysort country_id: egen byte eligible_divx = max(sample_divx)

    * Contar por año las observaciones incluidas y los países elegibles.
    collapse ///
        (sum) observations_eci=sample_eci ///
        observations_divx=sample_divx ///
        eligible_countries_eci=eligible_eci ///
        eligible_countries_divx=eligible_divx, by(year)

    * Separar ausencias temporales de exclusiones completas.
    generate int temporarily_absent_eci = ///
        eligible_countries_eci - observations_eci
    generate int temporarily_absent_divx = ///
        eligible_countries_divx - observations_divx

    generate int fully_excluded_countries_eci = ///
        $SAMPLE_N_GRID_COUNTRIES - eligible_countries_eci
    generate int fully_excluded_countries_divx = ///
        $SAMPLE_N_GRID_COUNTRIES - eligible_countries_divx

    * Clasificar cada año según la cobertura de los países elegibles.
    generate str20 coverage_status_eci = "PARTIAL_COVERAGE"
    replace coverage_status_eci = "FULL_COVERAGE" if ///
        observations_eci == eligible_countries_eci
    replace coverage_status_eci = "COMMON_GAP" if observations_eci == 0

    generate str20 coverage_status_divx = "PARTIAL_COVERAGE"
    replace coverage_status_divx = "FULL_COVERAGE" if ///
        observations_divx == eligible_countries_divx
    replace coverage_status_divx = "COMMON_GAP" if observations_divx == 0

    * Confirmar nuevamente que las dos muestras tienen la misma cobertura.
    assert observations_eci == observations_divx
    assert eligible_countries_eci == eligible_countries_divx
    assert coverage_status_eci == coverage_status_divx

    * Conservar los conteos anuales para el contrato consolidado de la muestra.
    quietly count if coverage_status_eci == "FULL_COVERAGE"
    local full_coverage_years_eci = r(N)
    quietly count if coverage_status_eci == "PARTIAL_COVERAGE"
    local partial_coverage_years_eci = r(N)
    quietly count if coverage_status_eci == "COMMON_GAP"
    local common_gap_years_eci = r(N)

    quietly count if coverage_status_divx == "FULL_COVERAGE"
    local full_coverage_years_divx = r(N)
    quietly count if coverage_status_divx == "PARTIAL_COVERAGE"
    local partial_coverage_years_divx = r(N)
    quietly count if coverage_status_divx == "COMMON_GAP"
    local common_gap_years_divx = r(N)

    * Ordenar cronológicamente y exportar el reporte anual mejorado.
    order year ///
        eligible_countries_eci observations_eci temporarily_absent_eci ///
        fully_excluded_countries_eci coverage_status_eci ///
        eligible_countries_divx observations_divx temporarily_absent_divx ///
        fully_excluded_countries_divx coverage_status_divx
    sort year

    export delimited using ///
        "$OUTPUT_SAMPLE/sample_time_structure_by_year.csv", ///
        replace datafmt
restore

* Crear un contrato consolidado de la muestra para que los archivos de
* estimación puedan verificar dimensiones, cobertura y reglas de construcción.
quietly levelsof year if sample_eci == 1, local(effective_years_eci)
local n_effective_years_eci : word count `effective_years_eci'

quietly levelsof year if sample_divx == 1, local(effective_years_divx)
local n_effective_years_divx : word count `effective_years_divx'

tempname contract_post
tempfile sample_contract

postfile `contract_post' ///
    str8 model long grid_observations sample_observations ///
    int grid_countries sample_countries total_calendar_years ///
    effective_years first_year last_year ///
    int full_coverage_years partial_coverage_years common_gap_years ///
    byte samples_identical no_imputation no_interpolation ///
    str32 key_definition str20 sample_rule ///
    using "`sample_contract'", replace

post `contract_post' ///
    ("ECI") ($SAMPLE_N_GRID) ($SAMPLE_N_ECI) ///
    ($SAMPLE_N_GRID_COUNTRIES) ($SAMPLE_N_ECI_COUNTRIES) (26) ///
    (`n_effective_years_eci') ($SAMPLE_ECI_FIRST_YEAR) ///
    ($SAMPLE_ECI_LAST_YEAR) ///
    (`full_coverage_years_eci') (`partial_coverage_years_eci') ///
    (`common_gap_years_eci') ///
    (1) (1) (1) ("country_iso3_code + year") ("COMPLETE_CASES")

post `contract_post' ///
    ("DIVX") ($SAMPLE_N_GRID) ($SAMPLE_N_DIVX) ///
    ($SAMPLE_N_GRID_COUNTRIES) ($SAMPLE_N_DIVX_COUNTRIES) (26) ///
    (`n_effective_years_divx') ($SAMPLE_DIVX_FIRST_YEAR) ///
    ($SAMPLE_DIVX_LAST_YEAR) ///
    (`full_coverage_years_divx') (`partial_coverage_years_divx') ///
    (`common_gap_years_divx') ///
    (1) (1) (1) ("country_iso3_code + year") ("COMPLETE_CASES")

postclose `contract_post'

preserve
    * Exportar el contrato en formato tabular y verificar sus invariantes.
    use "`sample_contract'", clear
    assert sample_observations == 1044
    assert sample_countries == 49
    assert samples_identical == 1
    assert no_imputation == 1
    assert no_interpolation == 1
    assert effective_years == 23

    sort model
    export delimited using ///
        "$OUTPUT_SAMPLE/sample_contract.csv", replace datafmt
    list, noobs abbreviate(24)
restore


// 3.5. Guardar las bases derivadas sin modificar el panel maestro

* Guardar una copia derivada con las transformaciones y las banderas de muestra.
save "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta", replace

* Guardar la muestra completa del modelo principal con ECI.
preserve
    * Conservar temporalmente solo los casos completos del modelo ECI.
    keep if sample_eci == 1

    * Guardar la muestra ECI como una base independiente.
    save "$OUTPUT_SAMPLE/sample_eci.dta", replace

    * Recuperar el panel completo antes de construir la muestra DIVX.
restore

* Guardar la muestra completa del modelo complementario con DIVX.
preserve
    * Conservar temporalmente solo los casos completos del modelo DIVX.
    keep if sample_divx == 1

    * Guardar la muestra DIVX como una base independiente.
    save "$OUTPUT_SAMPLE/sample_divx.dta", replace

    * Recuperar nuevamente el panel completo.
restore

* Informar en la ventana de resultados que la sección terminó correctamente.
display as result "Preparación de variables y muestras completada sin errores."
display as result ///
    "Muestra ECI:  $SAMPLE_N_ECI observaciones y $SAMPLE_N_ECI_COUNTRIES países."
display as result ///
    "Muestra DIVX: $SAMPLE_N_DIVX observaciones y $SAMPLE_N_DIVX_COUNTRIES países."
display as result "No se imputaron ni interpolaron valores faltantes."

* Recargar la base derivada completa para ejecutar los diagnósticos siguientes.
* No se abre el Editor de Datos para preservar la ejecución por lotes.
use "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta", clear


// *****************************************************************************
// 4. Estadísticas Descriptivas y Diagnósticos
// *****************************************************************************

// 4.1. Cargar y verificar la base preparada para el análisis

* Confirmar que la sección 3 haya creado la base analítica derivada.
capture confirm file "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta"
if _rc {
    display as error "No se encontró la base preparada para las estimaciones."
    display as error "Ejecute primero las secciones 1, 2 y 3."
    exit 601
}

* Cargar la base derivada sin modificar el panel maestro original.
use "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta", clear

* Declarar nuevamente la estructura país-año después de cargar el archivo.
xtset country_id year

* Verificar que la base conserve la grilla y las muestras validadas.
quietly count
* Control de calidad automático que detiene el script si no se cumple la condición.
assert r(N) == 1430

* Confirmar el número de casos completos de la ecuación ECI.
quietly count if sample_eci == 1
* Control de calidad automático que detiene el script si no se cumple la condición.
assert r(N) == 1044

* Confirmar el número de casos completos de la ecuación DIVX.
quietly count if sample_divx == 1
* Control de calidad automático que detiene el script si no se cumple la condición.
assert r(N) == 1044

* Confirmar que los diagnósticos ECI y DIVX parten de exactamente las mismas
* llaves país-año, no solo de muestras con el mismo tamaño.
assert sample_eci == sample_divx

* Verificar los países y años efectivos de la muestra común.
quietly levelsof country_id if sample_eci == 1, local(diagnostic_country_ids)
local diagnostic_countries : word count `diagnostic_country_ids'
assert `diagnostic_countries' == 49

quietly levelsof year if sample_eci == 1, local(diagnostic_years)
local diagnostic_effective_years : word count `diagnostic_years'
assert `diagnostic_effective_years' == 23

* Verificar que el contrato generado en la sección 3 esté disponible y sea
* coherente con la base que alimenta los diagnósticos.
capture confirm file "$OUTPUT_SAMPLE/sample_contract.csv"
if _rc {
    display as error "No se encontró sample_contract.csv."
    display as error "Ejecute nuevamente la sección 3.4."
    exit 601
}

preserve
    import delimited using "$OUTPUT_SAMPLE/sample_contract.csv", ///
        clear varnames(1)
    assert _N == 2
    assert sample_observations == 1044
    assert sample_countries == 49
    assert effective_years == 23
    assert samples_identical == 1
    assert no_imputation == 1
    assert no_interpolation == 1
restore

* Definir las variables que se describirán y diagnosticarán.
global DIAGNOSTIC_VARS ///
    eci divx rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin


// 4.2. Calcular estadísticas descriptivas

* Crear un registro temporal para almacenar los estadísticos de cada variable.
tempname descriptive_post
tempfile descriptive_report

* Definir las columnas del reporte descriptivo.
postfile `descriptive_post' ///
    str16 analysis_sample str24 variable ///
    long observations long zeros double zero_percent ///
    double mean sd min p25 median p75 max ///
    using "`descriptive_report'", replace

* Comparar el panel completo con la muestra efectiva de estimación.
foreach analysis_sample in PANEL_COMPLETE ESTIMATION {
    // Recorrer todas las variables utilizadas en las dos ecuaciones.
    foreach var of global DIAGNOSTIC_VARS {
        // Definir la restricción correspondiente a cada muestra.
        local restriction "!missing(`var')"
        if "`analysis_sample'" == "ESTIMATION" {
            local restriction "sample_eci == 1 & !missing(`var')"
        }

        // Contar las observaciones disponibles de la variable.
        quietly count if `restriction'
        local n_available = r(N)

        // Detener el diagnóstico si una variable carece de observaciones. Esto
        // evita divisiones por cero y resúmenes faltantes silenciosos.
        if `n_available' == 0 {
            display as error ///
                "La variable `var' no tiene observaciones en `analysis_sample'."
            exit 2000
        }

        // Contar los valores iguales a cero dentro de la muestra correspondiente.
        quietly count if `restriction' & `var' == 0
        local n_zeros = r(N)
        local zero_share = 100 * `n_zeros' / `n_available'

        // Calcular media, dispersión, percentiles y valores extremos.
        quietly summarize `var' if `restriction', detail
        local var_mean   = r(mean)
        local var_sd     = r(sd)
        local var_min    = r(min)
        local var_p25    = r(p25)
        local var_median = r(p50)
        local var_p75    = r(p75)
        local var_max    = r(max)

        // Guardar una fila del reporte para esta variable y muestra.
        post `descriptive_post' ///
            ("`analysis_sample'") ("`var'") ///
            (`n_available') (`n_zeros') (`zero_share') ///
            (`var_mean') (`var_sd') (`var_min') (`var_p25') ///
            (`var_median') (`var_p75') (`var_max')
    }
}

* Cerrar el registro para poder abrir y exportar sus resultados.
postclose `descriptive_post'

* Exportar los estadísticos sin perder la base que está cargada en memoria.
preserve
    * Abrir temporalmente el reporte descriptivo.
    use "`descriptive_report'", clear

    * Redondear los porcentajes y aplicar formatos legibles.
    replace zero_percent = round(zero_percent, 0.01)
    format zero_percent %9.2f
    format mean sd min p25 median p75 max %12.6f

    * Ordenar el reporte por muestra y variable.
    sort analysis_sample variable

    * Guardar los descriptivos como un archivo CSV reproducible.
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/descriptive_statistics.csv", ///
        replace datafmt

    * Mostrar el reporte en la ventana de resultados de Stata.
    list, sepby(analysis_sample) noobs abbreviate(20)

    * Recuperar la base analítica completa.
restore


// 4.3. Examinar la variación overall, between y within

* Crear un registro para documentar la variación temporal y entre países.
tempname variation_post
tempfile variation_report

* Definir las columnas del reporte de variación del panel.
postfile `variation_post' ///
    str24 variable long observations int countries ///
    double average_periods mean ///
    double sd_overall sd_between sd_within within_sd_ratio ///
    within_variance_share ///
    byte has_within_variation using "`variation_report'", replace

* Calcular la descomposición de variación en la muestra efectiva.
foreach var of global DIAGNOSTIC_VARS {
    // Ejecutar xtsum individualmente para recuperar sus resultados almacenados.
    quietly xtsum `var' if sample_eci == 1

    // Calcular por separado la razón de desviaciones estándar y la proporción
    // de varianza within. La primera no debe interpretarse como participación
    // de la varianza.
    local within_ratio = .
    local within_variance_share = .
    if r(sd) > 1e-10 {
        local within_ratio = r(sd_w) / r(sd)
        local within_variance_share = (r(sd_w)^2) / (r(sd)^2)
    }

    // Identificar si la variable tiene variación temporal aprovechable.
    local within_available = r(sd_w) > 1e-10

    // Guardar los resultados de esta variable.
    post `variation_post' ///
        ("`var'") (r(N)) (r(n)) (r(Tbar)) (r(mean)) ///
        (r(sd)) (r(sd_b)) (r(sd_w)) (`within_ratio') ///
        (`within_variance_share') ///
        (`within_available')
}

* Cerrar el registro temporal de variación.
postclose `variation_post'

* Exportar el reporte sin reemplazar la base analítica.
preserve
    * Abrir temporalmente el reporte de variación.
    use "`variation_report'", clear

    * Aplicar formatos para facilitar la comparación.
    format average_periods mean ///
        sd_overall sd_between sd_within within_sd_ratio ///
        within_variance_share %12.6f

    * Ordenar las variables y guardar el reporte.
    sort variable
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/panel_variation.csv", ///
        replace datafmt

    * Mostrar la descomposición en la ventana de resultados.
    list, noobs abbreviate(24)

    * Recuperar la base analítica.
restore

* Mostrar también la salida estándar de xtsum para revisión directa.
xtsum $DIAGNOSTIC_VARS if sample_eci == 1


// 4.4. Examinar las correlaciones entre las variables

* Calcular la matriz de correlaciones del modelo principal con ECI.
quietly correlate $MODEL_ECI if sample_eci == 1
matrix correlation_eci = r(C)

* Exportar la matriz ECI con nombres de filas y columnas.
preserve
    * Convertir la matriz en variables de Stata.
    clear
    svmat double correlation_eci, names(col)

    * Crear una columna que identifique la variable de cada fila.
    generate str24 variable = ""
    local row_number = 1
    foreach var of global MODEL_ECI {
        replace variable = "`var'" in `row_number'
        local ++row_number
    }

    * Organizar y exportar la matriz de correlaciones ECI.
    order variable
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/correlation_matrix_eci.csv", replace
restore

* Calcular la matriz de correlaciones del modelo complementario con DIVX.
quietly correlate $MODEL_DIVX if sample_divx == 1
matrix correlation_divx = r(C)

* Exportar la matriz DIVX con nombres de filas y columnas.
preserve
    * Convertir la matriz en variables de Stata.
    clear
    svmat double correlation_divx, names(col)

    * Crear una columna que identifique la variable de cada fila.
    generate str24 variable = ""
    local row_number = 1
    foreach var of global MODEL_DIVX {
        replace variable = "`var'" in `row_number'
        local ++row_number
    }

    * Organizar y exportar la matriz de correlaciones DIVX.
    order variable
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/correlation_matrix_divx.csv", replace
restore

* Mostrar correlaciones y significancia para revisión en la consola.
pwcorr $MODEL_ECI if sample_eci == 1, sig star(0.05)
pwcorr $MODEL_DIVX if sample_divx == 1, sig star(0.05)


// 4.5. Evaluar la colinealidad de los regresores

* Crear un registro para los factores de inflación de la varianza.
tempname vif_post
tempfile vif_report

* Definir las columnas del reporte de VIF.
postfile `vif_post' ///
    str8 model str24 variable ///
    double auxiliary_r2 tolerance vif ///
    int auxiliary_rank expected_rank byte rank_deficient ///
    str16 assessment ///
    using "`vif_report'", replace

* Definir los regresores del modelo ECI, incluido HHI.
local regressors_eci "$MODEL_COMMON hhi"

* Residualizar cada regresor respecto de los efectos fijos de país y año.
foreach var of local regressors_eci {
    // Eliminar la variable auxiliar si esta subsección se ejecuta nuevamente.
    capture drop within_`var'

    // Separar la variación que no es explicada por las dummies de país y año.
    quietly regress `var' i.country_id i.year if sample_eci == 1
    assert e(N) == 1044
    assert e(sample) == sample_eci
    predict double within_`var' if e(sample), residuals
}

* Calcular cada VIF utilizando únicamente la variación residualizada.
foreach target of local regressors_eci {
    // Retirar temporalmente la variable objetivo del lado derecho.
    local remaining : list regressors_eci - target

    // Construir la lista residualizada de las demás covariables.
    local within_remaining ""
    foreach var of local remaining {
        local within_remaining "`within_remaining' within_`var'"
    }

    // Regresar la variación within objetivo sobre las demás variaciones within.
    quietly regress within_`target' `within_remaining' ///
        if sample_eci == 1

    // Registrar el ajuste, la tolerancia y el rango efectivo de la ecuación
    // auxiliar antes de calcular el VIF.
    local auxiliary_r2 = e(r2)
    local tolerance_value = 1 - `auxiliary_r2'
    local auxiliary_rank = e(rank)
    local n_remaining : word count `within_remaining'
    local expected_rank = `n_remaining' + 1
    local rank_deficient = `auxiliary_rank' < `expected_rank'

    // Evitar dividir por una tolerancia nula o numéricamente despreciable.
    local vif_value = .
    if `tolerance_value' > 1e-10 {
        local vif_value = 1 / `tolerance_value'
    }

    // Clasificar el valor sin eliminar automáticamente ninguna variable.
    local vif_assessment "LOW"
    if `vif_value' >= 5 & !missing(`vif_value') ///
        local vif_assessment "REVIEW"
    if `vif_value' >= 10 & !missing(`vif_value') ///
        local vif_assessment "HIGH"
    if missing(`vif_value') local vif_assessment "COLLINEAR"

    // Guardar el resultado del regresor en el reporte.
    post `vif_post' ///
        ("ECI") ("`target'") ///
        (`auxiliary_r2') (`tolerance_value') (`vif_value') ///
        (`auxiliary_rank') (`expected_rank') (`rank_deficient') ///
        ("`vif_assessment'")
}

* Definir los regresores del modelo DIVX, que excluye HHI.
local regressors_divx "$MODEL_COMMON"

* Repetir el cálculo de VIF con el conjunto de regresores que excluye HHI.
foreach target of local regressors_divx {
    // Retirar temporalmente la variable objetivo del lado derecho.
    local remaining : list regressors_divx - target

    // Construir la lista residualizada de las demás covariables.
    local within_remaining ""
    foreach var of local remaining {
        local within_remaining "`within_remaining' within_`var'"
    }

    // Regresar la variación within objetivo sobre las demás variaciones within.
    quietly regress within_`target' `within_remaining' ///
        if sample_divx == 1

    // Recuperar el ajuste, la tolerancia y el rango de la ecuación auxiliar.
    local auxiliary_r2 = e(r2)
    local tolerance_value = 1 - `auxiliary_r2'
    local auxiliary_rank = e(rank)
    local n_remaining : word count `within_remaining'
    local expected_rank = `n_remaining' + 1
    local rank_deficient = `auxiliary_rank' < `expected_rank'

    // Calcular el VIF únicamente cuando la tolerancia sea positiva.
    local vif_value = .
    if `tolerance_value' > 1e-10 {
        local vif_value = 1 / `tolerance_value'
    }

    // Clasificar el valor únicamente como señal de revisión.
    local vif_assessment "LOW"
    if `vif_value' >= 5 & !missing(`vif_value') ///
        local vif_assessment "REVIEW"
    if `vif_value' >= 10 & !missing(`vif_value') ///
        local vif_assessment "HIGH"
    if missing(`vif_value') local vif_assessment "COLLINEAR"

    // Guardar el resultado del regresor en el reporte.
    post `vif_post' ///
        ("DIVX") ("`target'") ///
        (`auxiliary_r2') (`tolerance_value') (`vif_value') ///
        (`auxiliary_rank') (`expected_rank') (`rank_deficient') ///
        ("`vif_assessment'")
}

* Cerrar y exportar el reporte de colinealidad.
postclose `vif_post'

* Abrir temporalmente el reporte de VIF sin reemplazar la base analítica.
preserve
    * Abrir temporalmente el reporte de VIF.
    use "`vif_report'", clear

    * Ordenar primero los valores más altos dentro de cada modelo.
    gsort model -vif
    format auxiliary_r2 tolerance vif %12.6f

    * Exportar y mostrar el reporte.
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/vif_by_model.csv", replace datafmt
    list, sepby(model) noobs abbreviate(24)

    * Recuperar la base analítica.
restore

* Eliminar las variables auxiliares utilizadas exclusivamente para calcular VIF.
foreach var of local regressors_eci {
    drop within_`var'
}


// 4.6. Evaluar la estructura de los errores del panel

* Crear un registro para las pruebas de especificación de los errores.
tempname tests_post
tempfile tests_report

* Definir las columnas del reporte de pruebas diagnósticas.
postfile `tests_post' ///
    str8 model str32 test str80 null_hypothesis ///
    double statistic df1 df2 p_value ///
    long observations int countries byte includes_year_fe ///
    str20 decision str20 sample_rule ///
    using "`tests_report'", replace

* xtserial no admite la notación factorial i.year. Crear indicadores anuales
* explícitos sobre la muestra común permite evaluar la misma estructura
* temporal del M3 sin modificar la base guardada. Se omite el primer año como
* categoría de referencia.
quietly levelsof year if sample_eci == 1, local(error_test_years)
local error_test_base_year : word 1 of `error_test_years'
local error_test_year_dummies ""

foreach diagnostic_year of local error_test_years {
    if `diagnostic_year' != `error_test_base_year' {
        generate byte diagnostic_year_`diagnostic_year' = ///
            year == `diagnostic_year'
        local error_test_year_dummies ///
            "`error_test_year_dummies' diagnostic_year_`diagnostic_year'"
    }
}

* Ejecutar las tres pruebas para los modelos ECI y DIVX.
foreach model in ECI DIVX {
    // Definir la dependiente, los regresores y la bandera de cada modelo.
    local dependent "eci"
    local regressors "$MODEL_COMMON hhi"
    local sample_flag "sample_eci"

    // Sustituir la configuración predeterminada cuando se evalúa DIVX.
    if "`model'" == "DIVX" {
        local dependent "divx"
        local regressors "$MODEL_COMMON"
        local sample_flag "sample_divx"
    }

    // Verificar las dimensiones de la muestra utilizada por cada diagnóstico.
    quietly count if `sample_flag' == 1
    local diagnostic_n = r(N)
    assert `diagnostic_n' == 1044

    quietly levelsof country_id if `sample_flag' == 1, ///
        local(error_test_country_ids)
    local diagnostic_n_countries : word count `error_test_country_ids'
    assert `diagnostic_n_countries' == 49

    // Estimar silenciosamente el modelo auxiliar con efectos fijos de país y año.
    quietly xtreg `dependent' `regressors' i.year ///
        if `sample_flag' == 1, fe
    assert e(N) == `diagnostic_n'
    assert e(sample) == `sample_flag'

    // Probar heterocedasticidad entre países mediante Wald modificado.
    noisily xttest3
    local hetero_stat = r(wald)
    local hetero_df   = r(df)
    local hetero_p    = r(p)
    if missing(`hetero_stat', `hetero_df', `hetero_p') {
        display as error ///
            "La prueba Modified Wald no devolvió resultados completos para `model'."
        exit 498
    }
    local hetero_decision "DO NOT REJECT H0"
    if `hetero_p' < 0.05 local hetero_decision "REJECT H0"

    // Guardar el resultado de heterocedasticidad.
    post `tests_post' ///
        ("`model'") ("Modified Wald") ///
        ("Equal error variance across countries") ///
        (`hetero_stat') (`hetero_df') (.) (`hetero_p') ///
        (`diagnostic_n') (`diagnostic_n_countries') (1) ///
        ("`hetero_decision'") ("COMPLETE_CASES")

    // Probar autocorrelación de primer orden mediante Wooldridge. Los efectos
    // de año se incluyen para alinear la ecuación auxiliar con el M3.
    capture noisily xtserial `dependent' `regressors' ///
        `error_test_year_dummies' ///
        if `sample_flag' == 1
    local serial_rc = _rc
    if `serial_rc' != 0 {
        display as error ///
            "xtserial no pudo estimar la ecuación completa de `model'."
        exit `serial_rc'
    }
    local serial_stat = r(F)
    local serial_df1  = r(df)
    local serial_df2  = r(df_r)
    local serial_p    = r(p)
    if missing(`serial_stat', `serial_df1', `serial_df2', `serial_p') {
        display as error ///
            "La prueba Wooldridge no devolvió resultados completos para `model'."
        exit 498
    }
    local serial_decision "DO NOT REJECT H0"
    if `serial_p' < 0.05 local serial_decision "REJECT H0"

    // Guardar el resultado de autocorrelación.
    post `tests_post' ///
        ("`model'") ("Wooldridge AR(1)") ///
        ("No first-order serial correlation") ///
        (`serial_stat') (`serial_df1') (`serial_df2') (`serial_p') ///
        (`diagnostic_n') (`diagnostic_n_countries') (1) ///
        ("`serial_decision'") ("COMPLETE_CASES")

    // Reestimar el modelo auxiliar antes de la prueba postestimación de Pesaran.
    quietly xtreg `dependent' `regressors' i.year ///
        if `sample_flag' == 1, fe
    assert e(N) == `diagnostic_n'
    assert e(sample) == `sample_flag'

    // Probar independencia transversal de los residuos.
    noisily xtcsd, pesaran abs
    local cd_stat = r(pesaran)
    local cd_p = 2 * normal(-abs(`cd_stat'))
    if missing(`cd_stat', `cd_p') {
        display as error ///
            "La prueba Pesaran CD no devolvió resultados completos para `model'."
        exit 498
    }
    local cd_decision "DO NOT REJECT H0"
    if `cd_p' < 0.05 local cd_decision "REJECT H0"

    // Guardar el resultado de dependencia transversal.
    post `tests_post' ///
        ("`model'") ("Pesaran CD") ///
        ("Cross-sectional independence of residuals") ///
        (`cd_stat') (.) (.) (`cd_p') ///
        (`diagnostic_n') (`diagnostic_n_countries') (1) ///
        ("`cd_decision'") ("COMPLETE_CASES")

    // Conservar los valores p para definir la inferencia de los modelos.
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

* Eliminar los indicadores creados exclusivamente para xtserial.
drop `error_test_year_dummies'

* Cerrar y exportar el reporte de pruebas diagnósticas.
postclose `tests_post'

* Abrir temporalmente el reporte de pruebas sin perder la base analítica.
preserve
    * Abrir temporalmente el reporte de pruebas.
    use "`tests_report'", clear

    * Aplicar formatos y ordenar las pruebas por modelo.
    format statistic p_value %12.6f
    sort model test

    * Exportar y mostrar los resultados.
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/panel_error_tests.csv", replace datafmt
    list, sepby(model) noobs abbreviate(24)

    * Recuperar la base analítica.
restore

* Mantener errores agrupados por país como decisión de diseño. Las pruebas
* anteriores diagnostican la estructura residual, pero no seleccionan la
* inferencia principal mediante una votación de valores p.
global INFERENCE_MAIN "vce(cluster country_id)"

* Mostrar la estrategia de inferencia que utilizarán los modelos principales.
display as result ///
    "Inferencia principal recomendada: errores estándar agrupados por país."

* Advertir si la dependencia transversal requiere una sensibilidad adicional.
if $P_CD_ECI < 0.05 | $P_CD_DIVX < 0.05 {
    display as error ///
        "Alerta: revisar inferencia alternativa por dependencia transversal."
}


// 4.7. Identificar observaciones potencialmente influyentes

* Crear archivos temporales para reunir las alertas de los dos modelos.
tempfile influence_eci influence_divx

* Calcular influencia mediante una regresión auxiliar TWFE para ECI.
preserve
    * Estimar ECI con indicadores de país y año solo para fines diagnósticos.
    quietly regress eci $MODEL_COMMON hhi ///
        i.country_id i.year if sample_eci == 1

    * Confirmar que la regresión auxiliar utiliza exactamente la muestra ECI.
    assert e(N) == 1044
    assert e(sample) == sample_eci

    * Calcular umbrales convencionales según N y número de parámetros.
    local influence_n = e(N)
    local influence_k = e(df_m) + 1
    local leverage_threshold = 2 * `influence_k' / `influence_n'
    local cooks_threshold = 4 / `influence_n'

    * Obtener apalancamiento, distancia de Cook y residuo estandarizado.
    predict double leverage if e(sample), hat
    predict double cooks_distance if e(sample), cooksd
    predict double standardized_residual if e(sample), rstandard

    * Crear alertas separadas para cada criterio de influencia.
    generate byte flag_leverage = ///
        leverage > `leverage_threshold' if e(sample)
    generate byte flag_cooks = ///
        cooks_distance > `cooks_threshold' if e(sample)
    generate byte flag_residual = ///
        abs(standardized_residual) > 3 if e(sample)

    * Contar las alertas de cada criterio y su unión para evitar valores
    * esperados escritos manualmente en archivos posteriores.
    quietly count if e(sample) & flag_leverage == 1
    local eci_flagged_leverage = r(N)
    quietly count if e(sample) & flag_cooks == 1
    local eci_flagged_cooks = r(N)
    quietly count if e(sample) & flag_residual == 1
    local eci_flagged_residual = r(N)
    quietly count if e(sample) & ///
        (flag_leverage == 1 | flag_cooks == 1 | flag_residual == 1)
    local eci_flagged_any = r(N)

    * Conservar solo observaciones que activan al menos una alerta.
    keep if e(sample) & ///
        (flag_leverage == 1 | flag_cooks == 1 | flag_residual == 1)

    * Identificar el modelo y guardar los umbrales utilizados.
    generate str8 model = "ECI"
    generate double dependent_value = eci
    generate double leverage_cutoff = `leverage_threshold'
    generate double cooks_cutoff = `cooks_threshold'
    generate int model_observations = `influence_n'
    generate int model_parameters = `influence_k'
    generate int flagged_observations_model = `eci_flagged_any'
    generate int flagged_leverage_model = `eci_flagged_leverage'
    generate int flagged_cooks_model = `eci_flagged_cooks'
    generate int flagged_residual_model = `eci_flagged_residual'

    * Seleccionar las columnas necesarias para revisar cada observación.
    keep model country_iso3_code country country_id year dependent_value ///
        leverage leverage_cutoff cooks_distance cooks_cutoff ///
        standardized_residual ///
        flag_leverage flag_cooks flag_residual ///
        model_observations model_parameters ///
        flagged_observations_model flagged_leverage_model ///
        flagged_cooks_model flagged_residual_model

    * Guardar temporalmente las alertas del modelo ECI.
    save "`influence_eci'", replace
restore

* Repetir el diagnóstico de influencia para el modelo DIVX.
preserve
    * Estimar DIVX con efectos de país y año, excluyendo HHI.
    quietly regress divx $MODEL_COMMON ///
        i.country_id i.year if sample_divx == 1

    * Confirmar que la regresión auxiliar utiliza exactamente la muestra DIVX.
    assert e(N) == 1044
    assert e(sample) == sample_divx

    * Calcular umbrales convencionales según N y número de parámetros.
    local influence_n = e(N)
    local influence_k = e(df_m) + 1
    local leverage_threshold = 2 * `influence_k' / `influence_n'
    local cooks_threshold = 4 / `influence_n'

    * Obtener apalancamiento, distancia de Cook y residuo estandarizado.
    predict double leverage if e(sample), hat
    predict double cooks_distance if e(sample), cooksd
    predict double standardized_residual if e(sample), rstandard

    * Crear alertas separadas para cada criterio de influencia.
    generate byte flag_leverage = ///
        leverage > `leverage_threshold' if e(sample)
    generate byte flag_cooks = ///
        cooks_distance > `cooks_threshold' if e(sample)
    generate byte flag_residual = ///
        abs(standardized_residual) > 3 if e(sample)

    * Contar las alertas de cada criterio y su unión para documentar el
    * diagnóstico sin depender de conteos rígidos.
    quietly count if e(sample) & flag_leverage == 1
    local divx_flagged_leverage = r(N)
    quietly count if e(sample) & flag_cooks == 1
    local divx_flagged_cooks = r(N)
    quietly count if e(sample) & flag_residual == 1
    local divx_flagged_residual = r(N)
    quietly count if e(sample) & ///
        (flag_leverage == 1 | flag_cooks == 1 | flag_residual == 1)
    local divx_flagged_any = r(N)

    * Conservar solo observaciones que activan al menos una alerta.
    keep if e(sample) & ///
        (flag_leverage == 1 | flag_cooks == 1 | flag_residual == 1)

    * Identificar el modelo y guardar los umbrales utilizados.
    generate str8 model = "DIVX"
    generate double dependent_value = divx
    generate double leverage_cutoff = `leverage_threshold'
    generate double cooks_cutoff = `cooks_threshold'
    generate int model_observations = `influence_n'
    generate int model_parameters = `influence_k'
    generate int flagged_observations_model = `divx_flagged_any'
    generate int flagged_leverage_model = `divx_flagged_leverage'
    generate int flagged_cooks_model = `divx_flagged_cooks'
    generate int flagged_residual_model = `divx_flagged_residual'

    * Seleccionar las columnas necesarias para revisar cada observación.
    keep model country_iso3_code country country_id year dependent_value ///
        leverage leverage_cutoff cooks_distance cooks_cutoff ///
        standardized_residual ///
        flag_leverage flag_cooks flag_residual ///
        model_observations model_parameters ///
        flagged_observations_model flagged_leverage_model ///
        flagged_cooks_model flagged_residual_model

    * Guardar temporalmente las alertas del modelo DIVX.
    save "`influence_divx'", replace
restore

* Unir y exportar las alertas sin excluir observaciones de las estimaciones.
preserve
    * Abrir las alertas ECI y anexar las correspondientes a DIVX.
    use "`influence_eci'", clear
    append using "`influence_divx'"

    * Ordenar primero las mayores distancias de Cook dentro de cada modelo.
    gsort model -cooks_distance

    * Aplicar formatos y exportar el reporte.
    format leverage leverage_cutoff ///
        cooks_distance cooks_cutoff standardized_residual %12.6f
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/influential_observations.csv", ///
        replace datafmt

    * Mostrar las alertas en la ventana de resultados.
    list, sepby(model) noobs abbreviate(20)

    * Recuperar la base analítica completa.
restore

// 4.8. Evaluar persistencia y propiedades temporales de las variables centrales

* Mantener el diagnóstico intensivo para las dependientes y variables focales.
* La interacción RENTS_X_INST no se evalúa como un proceso estocástico autónomo.
local temporal_core_vars eci divx rents inst

* Añadir un inventario temporal acotado para los catorce controles del M3. HHI
* se conserva únicamente como control de ECI; nunca entra en la ecuación DIVX.
local temporal_control_vars ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc hhi pexp fexp ///
    vol rer humcap innov net log_gdppc govcons fin
local temporal_all_vars `temporal_core_vars' `temporal_control_vars'

* Crear primeras diferencias únicamente en memoria. El operador D. respeta la
* frecuencia anual declarada y devuelve missing cuando existe un vacío.
foreach var of local temporal_all_vars {
    capture drop diagnostic_d_`var'
    generate double diagnostic_d_`var' = D.`var' ///
        if sample_eci == 1 & L.sample_eci == 1
    label variable diagnostic_d_`var' ///
        "Primera diferencia diagnóstica de `var'"
}

* -----------------------------------------------------------------------------
* 4.8.1. Persistencia descriptiva de primer orden
* -----------------------------------------------------------------------------

tempname persistence_post
tempfile persistence_report

postfile `persistence_post' ///
    str8 variable str8 sample ///
    long source_observations valid_lag_pairs ///
    int countries double lag_pair_loss_percent ///
    double ar1_coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper int cluster_df ///
    str24 interpretation ///
    using "`persistence_report'", replace

foreach var of local temporal_core_vars {
    * ECI, RENTS e INST utilizan la bandera principal; DIVX conserva su bandera
    * propia aunque ambas muestras hayan sido validadas como idénticas.
    local sample_flag "sample_eci"
    local sample_name "ECI"
    if "`var'" == "divx" {
        local sample_flag "sample_divx"
        local sample_name "DIVX"
    }

    quietly count if `sample_flag' == 1 & !missing(`var')
    local persistence_source_n = r(N)
    assert `persistence_source_n' == 1044

    * Contar únicamente pares de años consecutivos presentes en la muestra.
    quietly count if `sample_flag' == 1 & L.`sample_flag' == 1 & ///
        !missing(`var', L.`var')
    local persistence_valid_pairs = r(N)
    local persistence_loss = 100 * ///
        (`persistence_source_n' - `persistence_valid_pairs') / ///
        `persistence_source_n'

    * Estimar persistencia condicional a efectos fijos de país y año. Este
    * coeficiente es descriptivo y no se interpreta como un modelo dinámico
    * causal ni como sustituto de una prueba de raíz unitaria.
    quietly xtreg `var' L.`var' i.year ///
        if `sample_flag' == 1 & L.`sample_flag' == 1, ///
        fe vce(cluster country_id)

    assert e(N) == `persistence_valid_pairs'
    assert e(N_g) == 49

    local persistence_b = _b[L.`var']
    local persistence_se = _se[L.`var']
    local persistence_t = `persistence_b' / `persistence_se'
    local persistence_df = e(df_r)
    local persistence_p = ///
        2 * ttail(`persistence_df', abs(`persistence_t'))
    local persistence_critical = invttail(`persistence_df', 0.025)
    local persistence_lower = ///
        `persistence_b' - `persistence_critical' * `persistence_se'
    local persistence_upper = ///
        `persistence_b' + `persistence_critical' * `persistence_se'

    local persistence_label "ABS_RHO_BELOW_0_50"
    if abs(`persistence_b') >= 0.50 {
        local persistence_label "ABS_RHO_0_50_TO_0_79"
    }
    if abs(`persistence_b') >= 0.80 {
        local persistence_label "ABS_RHO_AT_LEAST_0_80"
    }

    post `persistence_post' ///
        ("`var'") ("`sample_name'") ///
        (`persistence_source_n') (`persistence_valid_pairs') ///
        (e(N_g)) (`persistence_loss') ///
        (`persistence_b') (`persistence_se') (`persistence_t') ///
        (`persistence_p') (`persistence_lower') (`persistence_upper') ///
        (`persistence_df') ("`persistence_label'")
}

postclose `persistence_post'

preserve
    use "`persistence_report'", clear
    assert _N == 4
    assert source_observations == 1044
    assert countries == 49
    assert valid_lag_pairs < source_observations
    format lag_pair_loss_percent ar1_coefficient standard_error ///
        t_statistic p_value ci_lower ci_upper %12.8f
    sort variable
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/temporal_persistence.csv", ///
        replace datafmt
    list, noobs abbreviate(24)
restore

* -----------------------------------------------------------------------------
* 4.8.2. Elegibilidad de las pruebas de raíz unitaria del panel
* -----------------------------------------------------------------------------

tempname eligibility_post
tempfile eligibility_report

postfile `eligibility_post' ///
    str8 variable str16 series_form ///
    long observations int countries min_periods max_periods ///
    double average_periods long total_internal_gaps ///
    int common_gap_years byte strongly_balanced ///
    fisher_eligible ips_eligible ///
    str40 fisher_status str40 ips_status ///
    using "`eligibility_report'", replace

* IPS permite paneles desbalanceados, pero no vacíos dentro de cada serie. Las
* condiciones se calculan para cada variable y forma antes de ejecutar pruebas.
foreach var of local temporal_core_vars {
    local sample_flag "sample_eci"
    if "`var'" == "divx" local sample_flag "sample_divx"

    foreach series_form in LEVEL FIRST_DIFFERENCE {
        local temporal_test_var "`var'"
        if "`series_form'" == "FIRST_DIFFERENCE" {
            local temporal_test_var "diagnostic_d_`var'"
        }

        preserve
            keep if `sample_flag' == 1 & !missing(`temporal_test_var')

            quietly count
            local eligibility_n = r(N)

            quietly levelsof country_id, local(eligibility_country_ids)
            local eligibility_countries : word count ///
                `eligibility_country_ids'

            * Obtener períodos y extremos observados de cada país.
            bysort country_id (year): generate int periods_in_country = _N
            by country_id: generate byte first_country_row = _n == 1
            by country_id: generate int first_observed_year = year[1]
            by country_id: generate int last_observed_year = year[_N]

            quietly summarize periods_in_country ///
                if first_country_row == 1, meanonly
            local eligibility_min_t = r(min)
            local eligibility_max_t = r(max)
            local eligibility_mean_t = r(mean)

            * Contar años ausentes dentro del intervalo observado de cada país.
            by country_id (year): generate int internal_gap = 0
            by country_id (year): replace internal_gap = ///
                year - year[_n-1] - 1 if _n > 1
            quietly summarize internal_gap, meanonly
            local eligibility_internal_gaps = r(sum)

            * Contar años calendario sin ninguna observación disponible.
            quietly levelsof year, local(eligibility_observed_years)
            local eligibility_n_years : word count ///
                `eligibility_observed_years'
            local eligibility_common_gaps = 26 - `eligibility_n_years'

            * Un panel es fuertemente balanceado solo cuando todos los países
            * comparten cantidad, inicio y fin, sin vacíos internos.
            quietly summarize first_observed_year ///
                if first_country_row == 1, meanonly
            local eligibility_same_start = r(min) == r(max)
            quietly summarize last_observed_year ///
                if first_country_row == 1, meanonly
            local eligibility_same_end = r(min) == r(max)

            local eligibility_strong_balance = ///
                (`eligibility_min_t' == `eligibility_max_t') & ///
                (`eligibility_internal_gaps' == 0) & ///
                (`eligibility_same_start' == 1) & ///
                (`eligibility_same_end' == 1)

            * Fisher-ADF admite vacíos. IPS se habilita solo si no hay vacíos
            * individuales y cada país conserva al menos nueve períodos.
            local fisher_ok = ///
                (`eligibility_countries' > 1) & (`eligibility_min_t' >= 8)
            local ips_ok = ///
                (`eligibility_internal_gaps' == 0) & ///
                (`eligibility_min_t' >= 9)

            local fisher_label "ELIGIBLE_GAPS_ALLOWED"
            if !`fisher_ok' local fisher_label "NOT_APPLICABLE_SHORT_SERIES"

            local ips_label "ELIGIBLE_NO_INTERNAL_GAPS"
            if !`ips_ok' local ips_label "NOT_APPLICABLE_INTERNAL_GAPS"

            post `eligibility_post' ///
                ("`var'") ("`series_form'") ///
                (`eligibility_n') (`eligibility_countries') ///
                (`eligibility_min_t') (`eligibility_max_t') ///
                (`eligibility_mean_t') (`eligibility_internal_gaps') ///
                (`eligibility_common_gaps') ///
                (`eligibility_strong_balance') (`fisher_ok') (`ips_ok') ///
                ("`fisher_label'") ("`ips_label'")
        restore
    }
}

postclose `eligibility_post'

preserve
    use "`eligibility_report'", clear
    assert _N == 8
    assert countries == 49
    assert fisher_eligible == 1
    format average_periods %12.4f
    sort variable series_form
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/panel_unit_root_eligibility.csv", ///
        replace datafmt
    list, sepby(variable) noobs abbreviate(24)
restore

* Determinar si IPS es admisible en la muestra común. Esta condición es
* dinámica y no se sustituye mediante recortes o interpolación.
preserve
    keep if sample_eci == 1
    bysort country_id (year): generate int ips_internal_gap = 0
    by country_id (year): replace ips_internal_gap = ///
        year - year[_n-1] - 1 if _n > 1
    quietly count if ips_internal_gap > 0
    local ips_common_eligible = r(N) == 0
restore

* -----------------------------------------------------------------------------
* 4.8.3. Fisher-ADF e IPS cuando sea admisible
* -----------------------------------------------------------------------------

tempname unitroot_post
tempfile unitroot_report

postfile `unitroot_post' ///
    str8 variable str16 series_form str12 method ///
    str8 deterministics byte demeaned int lags ///
    long observations int countries ///
    double statistic p_value byte reject_5pct ///
    str20 decision int return_code ///
    str48 applicability_note ///
    str48 null_hypothesis str64 alternative_hypothesis ///
    using "`unitroot_report'", replace

foreach var of local temporal_core_vars {
    local sample_flag "sample_eci"
    if "`var'" == "divx" local sample_flag "sample_divx"

    foreach series_form in LEVEL FIRST_DIFFERENCE {
        local temporal_test_var "`var'"
        if "`series_form'" == "FIRST_DIFFERENCE" {
            local temporal_test_var "diagnostic_d_`var'"
        }

        foreach deterministic in CONSTANT TREND {
            local deterministic_option ""
            if "`deterministic'" == "TREND" {
                local deterministic_option "trend"
            }

            foreach unitroot_lag in 1 2 {
                foreach demean_status in RAW DEMEANED {
                    local demean_option ""
                    local demean_flag = 0
                    if "`demean_status'" == "DEMEANED" {
                        local demean_option "demean"
                        local demean_flag = 1
                    }

                    * Fisher-ADF es la prueba principal porque admite paneles
                    * desbalanceados y vacíos dentro de cada serie.
                    capture quietly xtunitroot fisher `temporal_test_var' ///
                        if `sample_flag' == 1, ///
                        dfuller lags(`unitroot_lag') ///
                        `deterministic_option' `demean_option'
                    local fisher_rc = _rc

                    local fisher_n = .
                    local fisher_groups = .
                    local fisher_stat = .
                    local fisher_p = .
                    local fisher_reject = .
                    local fisher_decision "NOT_APPLICABLE"
                    local fisher_note "COMMAND_RETURNED_ERROR"

                    if `fisher_rc' == 0 {
                        local fisher_n = r(N)
                        local fisher_groups = r(N_g)
                        local fisher_stat = r(P)
                        local fisher_p = r(p_P)
                        local fisher_note "FISHER_ALLOWS_INTERNAL_GAPS"

                        if missing(`fisher_stat', `fisher_p') {
                            local fisher_decision "INCONCLUSIVE"
                            local fisher_reject = .
                        }
                        else {
                            local fisher_reject = `fisher_p' < 0.05
                            local fisher_decision "DO_NOT_REJECT"
                            if `fisher_reject' == 1 {
                                local fisher_decision "REJECT_UNIT_ROOT"
                            }
                        }
                    }

                    post `unitroot_post' ///
                        ("`var'") ("`series_form'") ("FISHER_ADF") ///
                        ("`deterministic'") (`demean_flag') ///
                        (`unitroot_lag') (`fisher_n') (`fisher_groups') ///
                        (`fisher_stat') (`fisher_p') (`fisher_reject') ///
                        ("`fisher_decision'") (`fisher_rc') ///
                        ("`fisher_note'") ///
                        ("All panels contain unit roots") ///
                        ("At least one panel is stationary")

                    * IPS se ejecuta solo si no existen vacíos internos. Cuando
                    * la condición falla, se registra explícitamente sin
                    * alterar el panel para forzar la prueba.
                    local ips_rc = .
                    local ips_n = .
                    local ips_groups = .
                    local ips_stat = .
                    local ips_p = .
                    local ips_reject = .
                    local ips_decision "NOT_APPLICABLE"
                    local ips_note "INTERNAL_GAPS_NOT_ALLOWED"

                    if `ips_common_eligible' == 1 {
                        capture quietly xtunitroot ips ///
                            `temporal_test_var' if `sample_flag' == 1, ///
                            lags(`unitroot_lag') ///
                            `deterministic_option' `demean_option'
                        local ips_rc = _rc
                        local ips_note "COMMAND_RETURNED_ERROR"

                        if `ips_rc' == 0 {
                            local ips_n = r(N)
                            local ips_groups = r(N_g)
                            local ips_stat = r(wtbar)
                            local ips_p = r(p_wtbar)
                            local ips_note "IPS_NO_INTERNAL_GAPS"

                            if missing(`ips_stat', `ips_p') {
                                local ips_decision "INCONCLUSIVE"
                                local ips_reject = .
                            }
                            else {
                                local ips_reject = `ips_p' < 0.05
                                local ips_decision "DO_NOT_REJECT"
                                if `ips_reject' == 1 {
                                    local ips_decision "REJECT_UNIT_ROOT"
                                }
                            }
                        }
                    }

                    post `unitroot_post' ///
                        ("`var'") ("`series_form'") ("IPS") ///
                        ("`deterministic'") (`demean_flag') ///
                        (`unitroot_lag') (`ips_n') (`ips_groups') ///
                        (`ips_stat') (`ips_p') (`ips_reject') ///
                        ("`ips_decision'") (`ips_rc') ///
                        ("`ips_note'") ///
                        ("All panels contain unit roots") ///
                        ("A nonzero fraction of panels is stationary")
                }
            }
        }
    }
}

postclose `unitroot_post'

preserve
    use "`unitroot_report'", clear
    assert _N == 128
    assert decision == "NOT_APPLICABLE" if method == "IPS" & ///
        `ips_common_eligible' == 0
    assert !missing(statistic, p_value) if ///
        method == "FISHER_ADF" & return_code == 0
    format statistic p_value %14.10f
    sort variable series_form method deterministics demeaned lags
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/panel_unit_root_tests.csv", ///
        replace datafmt
    tabulate method decision, missing
restore

* -----------------------------------------------------------------------------
* 4.8.4. Inventario temporal acotado de los controles del M3
* -----------------------------------------------------------------------------

* Este bloque aprovecha la revisión amplia sugerida por Peer 1, pero evita una
* batería exploratoria de especificaciones. Para cada control se preespecifica
* Fisher-ADF con constante, un rezago y datos sustraídos de la media transversal.
* Los resultados son diagnósticos: no autorizan transformar ni eliminar controles.
tempname control_inventory_post control_unitroot_post
tempfile control_inventory_report control_unitroot_report

postfile `control_inventory_post' ///
    str16 variable str12 model_scope ///
    long source_observations valid_lag_pairs int countries ///
    double lag_pair_loss_percent ///
    int min_periods max_periods double average_periods ///
    long total_internal_gaps int common_gap_years ///
    double ar1_coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper int cluster_df str24 persistence_label ///
    byte model_change_authorized str140 interpretation_limit ///
    using "`control_inventory_report'", replace

postfile `control_unitroot_post' ///
    str16 variable str12 model_scope str16 series_form str12 method ///
    str8 deterministics byte demeaned int lags ///
    long observations int countries double statistic p_value ///
    byte reject_5pct str36 decision int return_code ///
    str48 null_hypothesis str64 alternative_hypothesis ///
    byte model_change_authorized str140 interpretation_limit ///
    using "`control_unitroot_report'", replace

foreach var of local temporal_control_vars {
    local control_scope "BOTH"
    if "`var'" == "hhi" local control_scope "ECI_ONLY"

    quietly count if sample_eci == 1 & !missing(`var')
    local control_source_n = r(N)
    assert `control_source_n' == 1044

    quietly levelsof country_id if sample_eci == 1 & !missing(`var'), ///
        local(control_country_ids)
    local control_countries : word count `control_country_ids'
    assert `control_countries' == 49

    quietly count if sample_eci == 1 & L.sample_eci == 1 & ///
        !missing(`var', L.`var')
    local control_valid_pairs = r(N)
    local control_pair_loss = 100 * ///
        (`control_source_n' - `control_valid_pairs') / `control_source_n'

    * Calcular cobertura y vacíos sin alterar el panel que permanece en memoria.
    preserve
        keep if sample_eci == 1 & !missing(`var')
        bysort country_id (year): generate int control_periods = _N
        by country_id: generate byte control_first_row = _n == 1
        by country_id (year): generate int control_internal_gap = 0
        by country_id (year): replace control_internal_gap = ///
            year - year[_n-1] - 1 if _n > 1

        quietly summarize control_periods if control_first_row == 1, meanonly
        local control_min_t = r(min)
        local control_max_t = r(max)
        local control_mean_t = r(mean)
        quietly summarize control_internal_gap, meanonly
        local control_internal_gaps = r(sum)
        quietly levelsof year, local(control_observed_years)
        local control_n_years : word count `control_observed_years'
        local control_common_gaps = 26 - `control_n_years'
    restore

    * Persistencia descriptiva condicionada a efectos fijos de país y año.
    quietly xtreg `var' L.`var' i.year ///
        if sample_eci == 1 & L.sample_eci == 1, ///
        fe vce(cluster country_id)
    assert e(N) == `control_valid_pairs'
    assert e(N_g) == `control_countries'

    local control_ar1_b = _b[L.`var']
    local control_ar1_se = _se[L.`var']
    local control_ar1_t = `control_ar1_b' / `control_ar1_se'
    local control_ar1_df = e(df_r)
    local control_ar1_p = ///
        2 * ttail(`control_ar1_df', abs(`control_ar1_t'))
    local control_ar1_critical = invttail(`control_ar1_df', 0.025)
    local control_ar1_lower = ///
        `control_ar1_b' - `control_ar1_critical' * `control_ar1_se'
    local control_ar1_upper = ///
        `control_ar1_b' + `control_ar1_critical' * `control_ar1_se'

    local control_persistence_label "ABS_RHO_BELOW_0_50"
    if abs(`control_ar1_b') >= 0.50 {
        local control_persistence_label "ABS_RHO_0_50_TO_0_79"
    }
    if abs(`control_ar1_b') >= 0.80 {
        local control_persistence_label "ABS_RHO_AT_LEAST_0_80"
    }

    post `control_inventory_post' ///
        ("`var'") ("`control_scope'") ///
        (`control_source_n') (`control_valid_pairs') (`control_countries') ///
        (`control_pair_loss') (`control_min_t') (`control_max_t') ///
        (`control_mean_t') (`control_internal_gaps') ///
        (`control_common_gaps') (`control_ar1_b') (`control_ar1_se') ///
        (`control_ar1_t') (`control_ar1_p') (`control_ar1_lower') ///
        (`control_ar1_upper') (`control_ar1_df') ///
        ("`control_persistence_label'") (0) ///
        ("Persistencia descriptiva; no es un modelo dinamico causal ni una regla de seleccion.")

    * Ejecutar una sola especificación Fisher-ADF predefinida en nivel y primera
    * diferencia. Cualquier fallo o resultado vacío detiene el archivo.
    foreach control_form in LEVEL FIRST_DIFFERENCE {
        local control_test_var "`var'"
        if "`control_form'" == "FIRST_DIFFERENCE" {
            local control_test_var "diagnostic_d_`var'"
        }

        capture quietly xtunitroot fisher `control_test_var' ///
            if sample_eci == 1, dfuller lags(1) demean
        local control_fisher_rc = _rc
        if `control_fisher_rc' != 0 {
            display as error ///
                "Fisher-ADF fallo para `var' en `control_form'."
            exit `control_fisher_rc'
        }

        local control_fisher_n = r(N)
        local control_fisher_groups = r(N_g)
        local control_fisher_stat = r(P)
        local control_fisher_p = r(p_P)

        if missing(`control_fisher_stat', `control_fisher_p') {
            display as error ///
                "Fisher-ADF devolvio resultados vacios para `var' en `control_form'."
            exit 498
        }

        local control_fisher_reject = `control_fisher_p' < 0.05
        local control_fisher_decision "DO_NOT_REJECT_UNIT_ROOT_NULL"
        if `control_fisher_reject' == 1 {
            local control_fisher_decision "REJECT_UNIT_ROOT_NULL"
        }

        post `control_unitroot_post' ///
            ("`var'") ("`control_scope'") ("`control_form'") ///
            ("FISHER_ADF") ("CONSTANT") (1) (1) ///
            (`control_fisher_n') (`control_fisher_groups') ///
            (`control_fisher_stat') (`control_fisher_p') ///
            (`control_fisher_reject') ///
            ("`control_fisher_decision'") (`control_fisher_rc') ///
            ("All panels contain unit roots") ///
            ("At least one panel is stationary") (0) ///
            ("El rechazo no demuestra estacionariedad universal ni clasifica automaticamente I(0) o I(1).")
    }
}

postclose `control_inventory_post'
postclose `control_unitroot_post'

preserve
    use "`control_inventory_report'", clear
    assert _N == 14
    isid variable
    assert source_observations == 1044
    assert countries == 49
    assert valid_lag_pairs < source_observations
    assert model_change_authorized == 0
    quietly count if variable == "hhi" & model_scope == "ECI_ONLY"
    assert r(N) == 1
    quietly count if variable != "hhi" & model_scope == "BOTH"
    assert r(N) == 13
    assert !missing(ar1_coefficient, standard_error, p_value)
    format lag_pair_loss_percent ar1_coefficient standard_error ///
        t_statistic p_value ci_lower ci_upper %12.8f
    sort variable
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/temporal_control_inventory.csv", ///
        replace datafmt
    list variable model_scope source_observations valid_lag_pairs ///
        ar1_coefficient p_value, noobs abbreviate(24)
restore

preserve
    use "`control_unitroot_report'", clear
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
    quietly count if variable == "hhi" & model_scope == "ECI_ONLY"
    assert r(N) == 2
    quietly count if variable != "hhi" & model_scope == "BOTH"
    assert r(N) == 26
    format statistic p_value %14.10f
    sort variable series_form
    export delimited using ///
        "$OUTPUT_DIAGNOSTICS/panel_unit_root_controls.csv", ///
        replace datafmt
    tabulate series_form decision, missing
restore

* Eliminar las primeras diferencias creadas exclusivamente para diagnóstico.
foreach var of local temporal_all_vars {
    drop diagnostic_d_`var'
}

// 4.9. Consolidar el registro de decisiones econométricas

* Verificar que todos los insumos de los bloques 1 a 3 estén disponibles antes
* de traducir los diagnósticos en decisiones metodológicas.
capture confirm file "$OUTPUT_SAMPLE/sample_contract.csv"
if _rc {
    display as error "Falta sample_contract.csv para el registro de decisiones."
    exit 601
}

capture confirm file "$OUTPUT_DIAGNOSTICS/panel_variation.csv"
if _rc {
    display as error "Falta panel_variation.csv para el registro de decisiones."
    exit 601
}

capture confirm file "$OUTPUT_DIAGNOSTICS/panel_error_tests.csv"
if _rc {
    display as error "Falta panel_error_tests.csv para el registro de decisiones."
    exit 601
}

capture confirm file "$OUTPUT_DIAGNOSTICS/influential_observations.csv"
if _rc {
    display as error ///
        "Falta influential_observations.csv para el registro de decisiones."
    exit 601
}

capture confirm file "$OUTPUT_DIAGNOSTICS/temporal_persistence.csv"
if _rc {
    display as error ///
        "Falta temporal_persistence.csv para el registro de decisiones."
    exit 601
}

capture confirm file "$OUTPUT_DIAGNOSTICS/panel_unit_root_eligibility.csv"
if _rc {
    display as error ///
        "Falta panel_unit_root_eligibility.csv para el registro de decisiones."
    exit 601
}

capture confirm file "$OUTPUT_DIAGNOSTICS/panel_unit_root_tests.csv"
if _rc {
    display as error ///
        "Falta panel_unit_root_tests.csv para el registro de decisiones."
    exit 601
}

capture confirm file "$OUTPUT_DIAGNOSTICS/temporal_control_inventory.csv"
if _rc {
    display as error ///
        "Falta temporal_control_inventory.csv para el registro de decisiones."
    exit 601
}

capture confirm file "$OUTPUT_DIAGNOSTICS/panel_unit_root_controls.csv"
if _rc {
    display as error ///
        "Falta panel_unit_root_controls.csv para el registro de decisiones."
    exit 601
}

* Recuperar el contrato de muestra sin mantener cifras duplicadas en el código.
preserve
    import delimited using "$OUTPUT_SAMPLE/sample_contract.csv", ///
        clear varnames(1)
    assert _N == 2
    assert sample_observations[1] == sample_observations[2]
    assert sample_countries[1] == sample_countries[2]
    assert effective_years[1] == effective_years[2]
    assert samples_identical == 1
    assert no_imputation == 1
    assert no_interpolation == 1

    quietly summarize sample_observations, meanonly
    local decision_sample_n = r(min)
    quietly summarize sample_countries, meanonly
    local decision_sample_countries = r(min)
    quietly summarize effective_years, meanonly
    local decision_effective_years = r(min)
restore

* Recuperar la disponibilidad de variación within de la variable institucional.
preserve
    import delimited using "$OUTPUT_DIAGNOSTICS/panel_variation.csv", ///
        clear varnames(1)
    quietly count if variable == "inst"
    assert r(N) == 1
    quietly summarize within_variance_share if variable == "inst", meanonly
    local decision_inst_within_share = r(mean)
restore

* Resumir las pruebas de heterocedasticidad, autocorrelación y dependencia
* transversal, conservando sus dimensiones y efectos de año.
preserve
    import delimited using "$OUTPUT_DIAGNOSTICS/panel_error_tests.csv", ///
        clear varnames(1)
    assert _N == 6
    assert observations == `decision_sample_n'
    assert countries == `decision_sample_countries'
    assert includes_year_fe == 1

    quietly count if test == "Modified Wald" & decision == "REJECT H0"
    local decision_hetero_rejects = r(N)
    quietly count if test == "Wooldridge AR(1)" & decision == "REJECT H0"
    local decision_serial_rejects = r(N)
    quietly count if test == "Pesaran CD" & decision == "DO NOT REJECT H0"
    local decision_cd_nonrejects = r(N)
restore

* Recuperar dinámicamente los conteos de influencia y comprobar que coincidan
* con el número de filas exportado para cada modelo.
preserve
    import delimited using ///
        "$OUTPUT_DIAGNOSTICS/influential_observations.csv", ///
        clear varnames(1)

    quietly summarize flagged_observations_model if model == "ECI", meanonly
    assert r(min) == r(max)
    local decision_influence_eci = r(max)
    quietly count if model == "ECI"
    assert r(N) == `decision_influence_eci'

    quietly summarize flagged_observations_model if model == "DIVX", meanonly
    assert r(min) == r(max)
    local decision_influence_divx = r(max)
    quietly count if model == "DIVX"
    assert r(N) == `decision_influence_divx'
restore

* Recuperar los coeficientes descriptivos de persistencia de las variables
* relevantes para la interpretación y las sensibilidades del M3.
preserve
    import delimited using "$OUTPUT_DIAGNOSTICS/temporal_persistence.csv", ///
        clear varnames(1)
    assert _N == 4
    assert source_observations == `decision_sample_n'
    assert countries == `decision_sample_countries'

    quietly summarize ar1_coefficient if variable == "divx", meanonly
    local decision_persistence_divx = r(mean)
    quietly summarize ar1_coefficient if variable == "rents", meanonly
    local decision_persistence_rents = r(mean)
    quietly summarize ar1_coefficient if variable == "inst", meanonly
    local decision_persistence_inst = r(mean)
restore

* Confirmar la elegibilidad documentada para Fisher e IPS.
preserve
    import delimited using ///
        "$OUTPUT_DIAGNOSTICS/panel_unit_root_eligibility.csv", ///
        clear varnames(1)
    assert _N == 8
    quietly count if fisher_eligible == 1
    local decision_fisher_eligible = r(N)
    quietly count if ips_eligible == 0
    local decision_ips_not_eligible = r(N)
restore

assert `decision_fisher_eligible' == 8
assert `decision_ips_not_eligible' == 8

* Resumir los resultados de raíces unitarias sin convertirlos en selección
* automática de especificaciones.
preserve
    import delimited using ///
        "$OUTPUT_DIAGNOSTICS/panel_unit_root_tests.csv", ///
        clear varnames(1)
    assert _N == 128

    quietly count if method == "FISHER_ADF" & return_code == 0
    local decision_fisher_success = r(N)
    quietly count if method == "IPS" & decision == "NOT_APPLICABLE"
    local decision_ips_not_applicable = r(N)

    foreach decision_var in eci divx rents inst {
        quietly count if method == "FISHER_ADF" & ///
            variable == "`decision_var'" & series_form == "LEVEL" & ///
            decision == "REJECT_UNIT_ROOT"
        local dlevrej_`decision_var' = r(N)

        quietly count if method == "FISHER_ADF" & ///
            variable == "`decision_var'" & ///
            series_form == "FIRST_DIFFERENCE" & ///
            decision == "REJECT_UNIT_ROOT"
        local ddiffrej_`decision_var' = r(N)
    }
restore

assert `decision_fisher_success' == 64
assert `decision_ips_not_applicable' == 64

* Resumir el inventario temporal ampliado de los catorce controles del M3 sin
* convertir persistencia o raíces unitarias en criterios automáticos de modelo.
preserve
    import delimited using ///
        "$OUTPUT_DIAGNOSTICS/temporal_control_inventory.csv", ///
        clear varnames(1)
    assert _N == 14
    isid variable
    assert source_observations == `decision_sample_n'
    assert countries == `decision_sample_countries'
    assert model_change_authorized == 0
    quietly count if abs(ar1_coefficient) >= 0.80
    local decision_ctrl_hi_persist = r(N)
restore

preserve
    import delimited using ///
        "$OUTPUT_DIAGNOSTICS/panel_unit_root_controls.csv", ///
        clear varnames(1)
    assert _N == 28
    isid variable series_form
    assert return_code == 0
    assert model_change_authorized == 0
    quietly count if series_form == "LEVEL" & ///
        decision == "REJECT_UNIT_ROOT_NULL"
    local decision_ctrl_lev_reject = r(N)
    quietly count if series_form == "FIRST_DIFFERENCE" & ///
        decision == "REJECT_UNIT_ROOT_NULL"
    local decision_ctrl_diff_reject = r(N)
restore

* Convertir cifras dinámicas a texto legible para el registro.
local decision_inst_within_text : display ///
    %6.4f `decision_inst_within_share'
local decision_divx_rho_text : display ///
    %6.3f `decision_persistence_divx'
local decision_rents_rho_text : display ///
    %6.3f `decision_persistence_rents'
local decision_inst_rho_text : display ///
    %6.3f `decision_persistence_inst'

tempname decision_post
tempfile decision_register

postfile `decision_post' ///
    str4 decision_id str32 evidence_area ///
    str80 evidence_source str160 evidence_result ///
    str20 hierarchy str40 target_script ///
    str32 implementation_status ///
    str180 methodological_action str180 interpretation_limit ///
    byte significance_selected ///
    using "`decision_register'", replace

* D01: contrato común de estimación.
post `decision_post' ///
    ("D01") ("COMMON_SAMPLE") ///
    ("sample_contract.csv") ///
    ("N=`decision_sample_n'; countries=`decision_sample_countries'; effective_years=`decision_effective_years'; ECI_DIVX_IDENTICAL=1") ///
    ("MAIN") ("04_twfe_full.do") ("ACTIVE") ///
    ("Mantener la misma muestra país-año para ECI y DIVX.") ///
    ("Los cambios entre ecuaciones no deben provenir de cobertura diferente.") ///
    (0)

* D02: identidad contable entre DIVX y HHI.
post `decision_post' ///
    ("D02") ("OUTCOME_IDENTITY") ///
    ("01_data_preparation_diagnostics.do") ///
    ("DIVX = 1 - HHI validado en el panel preparado.") ///
    ("MAIN") ("04_twfe_full.do") ("ACTIVE") ///
    ("Excluir HHI de toda ecuación cuya dependiente sea DIVX.") ///
    ("Incluir HHI produciría una identidad mecánica.") ///
    (0)

* D03: inferencia principal frente a heterocedasticidad y correlación serial.
post `decision_post' ///
    ("D03") ("CLUSTERED_INFERENCE") ///
    ("panel_error_tests.csv") ///
    ("Modified_Wald_rejections=`decision_hetero_rejects'/2; Wooldridge_rejections=`decision_serial_rejects'/2; clusters=`decision_sample_countries'") ///
    ("MAIN") ("04_twfe_full.do") ("ACTIVE") ///
    ("Mantener errores estándar agrupados por país.") ///
    ("La inferencia no se selecciona mediante una votación de valores p.") ///
    (0)

* D04: bootstrap con un número moderado de conglomerados.
post `decision_post' ///
    ("D04") ("WILD_CLUSTER_BOOTSTRAP") ///
    ("panel_error_tests.csv") ///
    ("Clusters=`decision_sample_countries'; heteroscedasticity_and_serial_correlation_detected=1") ///
    ("SENSITIVITY") ("04_twfe_full.do") ///
    ("IMPLEMENTED") ///
    ("Usar wild cluster bootstrap para términos y pruebas focales predefinidas.") ///
    ("No aplicar bootstrap a todas las combinaciones posibles de coeficientes.") ///
    (0)

* D05: dependencia transversal residual.
post `decision_post' ///
    ("D05") ("CROSS_SECTIONAL_DEPENDENCE") ///
    ("panel_error_tests.csv") ///
    ("Pesaran_CD_nonrejections=`decision_cd_nonrejects'/2 after_year_FE=1") ///
    ("EXCLUDED") ("04_twfe_full.do") ("NOT_REQUIRED") ///
    ("No adoptar CCE como estimador principal con la evidencia residual vigente.") ///
    ("Reconsiderar únicamente si nuevos diagnósticos detectan dependencia sustantiva.") ///
    (0)

* D06: variación institucional dentro de cada país.
post `decision_post' ///
    ("D06") ("INSTITUTIONAL_WITHIN_VARIATION") ///
    ("panel_variation.csv") ///
    ("INST_within_variance_ratio=`decision_inst_within_text'") ///
    ("MAIN") ("04_twfe_full.do") ("ACTIVE") ///
    ("Interpretar INST y su interacción con cautela; conservar intervalos de confianza.") ///
    ("La baja variación within limita la precisión, no justifica eliminar INST.") ///
    (0)

* D07: efectos marginales dentro del soporte institucional observado.
post `decision_post' ///
    ("D07") ("MARGINAL_EFFECT_SUPPORT") ///
    ("panel_variation.csv; temporal_persistence.csv") ///
    ("INST_within_ratio=`decision_inst_within_text'; INST_AR1=`decision_inst_rho_text'") ///
    ("SENSITIVITY") ("04_twfe_full.do") ///
    ("IMPLEMENTED") ///
    ("Evaluar efectos marginales de RENTS solo en valores observados de INST.") ///
    ("No extrapolar efectos fuera del soporte institucional de la muestra.") ///
    (0)

* D08: persistencia de las variables focales.
post `decision_post' ///
    ("D08") ("TEMPORAL_PERSISTENCE") ///
    ("temporal_persistence.csv") ///
    ("DIVX_AR1=`decision_divx_rho_text'; RENTS_AR1=`decision_rents_rho_text'; INST_AR1=`decision_inst_rho_text'") ///
    ("SENSITIVITY") ("04_twfe_full.do") ("IMPLEMENTED") ///
    ("Añadir tendencias lineales específicas por país como sensibilidad exigente.") ///
    ("La sensibilidad no reemplaza el M3 en niveles ni demuestra causalidad.") ///
    (0)

* D09: lectura no uniforme de las raíces unitarias.
post `decision_post' ///
    ("D09") ("PANEL_UNIT_ROOT_EVIDENCE") ///
    ("panel_unit_root_tests.csv") ///
    ("Level_rejections_eci=`dlevrej_eci'/8; divx=`dlevrej_divx'/8; rents=`dlevrej_rents'/8; inst=`dlevrej_inst'/8") ///
    ("MAIN") ("04_twfe_full.do") ("DIAGNOSTIC_ONLY") ///
    ("Conservar el M3 principal y documentar evidencia mixta de estacionariedad.") ///
    ("Fisher rechaza que todos los paneles tengan raíz; no prueba estacionariedad universal.") ///
    (0)

* D10: restricciones de IPS.
post `decision_post' ///
    ("D10") ("IPS_ELIGIBILITY") ///
    ("panel_unit_root_eligibility.csv; panel_unit_root_tests.csv") ///
    ("Eligibility_rows_not_eligible=`decision_ips_not_eligible'/8; IPS_not_applicable=`decision_ips_not_applicable'/64") ///
    ("NOT_APPLICABLE") ("01_data_preparation_diagnostics.do") ///
    ("NOT_APPLICABLE") ///
    ("No ejecutar IPS mientras existan vacíos internos en las series individuales.") ///
    ("No balancear, recortar ni interpolar el panel para forzar la prueba.") ///
    (0)

* D11: primeras diferencias como evidencia complementaria, no como M3.
post `decision_post' ///
    ("D11") ("FIRST_DIFFERENCES") ///
    ("panel_unit_root_tests.csv") ///
    ("Difference_rejections_eci=`ddiffrej_eci'/8; divx=`ddiffrej_divx'/8; rents=`ddiffrej_rents'/8; inst=`ddiffrej_inst'/8") ///
    ("EXCLUDED") ("04_twfe_full.do") ("OUTSIDE_CORE") ///
    ("No sustituir automáticamente el M3 por una ecuación en primeras diferencias.") ///
    ("Diferenciar cambia el estimando y la interpretación de la interacción.") ///
    (0)

* D12: observaciones influyentes.
post `decision_post' ///
    ("D12") ("INFLUENTIAL_OBSERVATIONS") ///
    ("influential_observations.csv") ///
    ("ECI_flagged=`decision_influence_eci'; DIVX_flagged=`decision_influence_divx'") ///
    ("SENSITIVITY") ("04_twfe_full.do") ///
    ("IMPLEMENTED") ///
    ("Usar conteos dinámicos, exclusión diagnóstica y leave-one-country-out.") ///
    ("Las alertas no autorizan eliminar observaciones del modelo principal.") ///
    (0)

* D13: estabilidad alrededor de 2014.
* Justificación externa preespecificada: World Bank (2015), Understanding the
* Plunge in Oil Prices: Sources and Implications, Policy Research Note 1.
* https://documents1.worldbank.org/curated/en/726831468180852545/pdf/94725-NWP-PRN01-Mar2015-Oil-Prices-Box393265B-PUBLIC.pdf
post `decision_post' ///
    ("D13") ("REGIME_STABILITY_2014") ///
    ("World Bank Policy Research Note 1 (2015)") ///
    ("Oil prices fell almost 50pct Jun2014-Feb2015; cutoff externally prespecified") ///
    ("CONDITIONAL") ("04_twfe_full.do") ///
    ("IMPLEMENTED_WITH_JUSTIFICATION") ///
    ("Probar cambios post-2014 mediante interacciones en la muestra completa.") ///
    ("2014 es año de transición; la sensibilidad no identifica efectos causales.") ///
    (0)

* D14: cointegración y modelos de corrección de errores.
post `decision_post' ///
    ("D14") ("COINTEGRATION_ECM") ///
    ("panel_unit_root_tests.csv") ///
    ("Mixed_integration_evidence; IPS_not_applicable; no_cointegrating_vector_tested") ///
    ("EXCLUDED") ("NONE") ("EXCLUDED") ///
    ("No estimar cointegración ni ECM dentro del núcleo TWFE.") ///
    ("No realizar afirmaciones de equilibrio o superconsistencia de largo plazo.") ///
    (0)

* D15: modelos multivariados de series de tiempo.
post `decision_post' ///
    ("D15") ("VAR_VEC_GRANGER") ///
    ("Research_design_and_panel_structure") ///
    ("Country_panel_with_common_shocks; no_single_system_identification") ///
    ("EXCLUDED") ("NONE") ("EXCLUDED") ///
    ("No incorporar VAR, VEC, Granger, IRF o FEVD en estos archivos.") ///
    ("Estas técnicas no identifican el parámetro asociativo central del TFM.") ///
    (0)

* D16: filtros y proyecciones locales.
post `decision_post' ///
    ("D16") ("HP_FILTER_AND_LOCAL_PROJECTIONS") ///
    ("Research_design_and_current_identification") ///
    ("No_predefined_shock_identification_or_horizon_family_in_M3") ///
    ("EXCLUDED") ("NONE") ("EXCLUDED") ///
    ("No usar HP como inferencia ni añadir proyecciones locales al M3.") ///
    ("Las proyecciones requieren identificación, rezagos, muestra común y multiplicidad.") ///
    (0)

* D17: alcance interpretativo común.
post `decision_post' ///
    ("D17") ("INTERPRETATION_SCOPE") ///
    ("ECONOMETRIC_STRATEGY.md") ///
    ("Observational panel; no external instrument; TWFE association design") ///
    ("MAIN") ("04_twfe_full.do") ("ACTIVE") ///
    ("Describir todos los resultados como asociaciones condicionales dentro del país.") ///
    ("No interpretar coeficientes como efectos causales o parámetros de largo plazo.") ///
    (0)

* D18: inventario temporal ampliado de los controles del M3.
post `decision_post' ///
    ("D18") ("CONTROL_TEMPORAL_INVENTORY") ///
    ("temporal_control_inventory.csv; panel_unit_root_controls.csv") ///
    ("Controls=14; abs_AR1_ge_0.80=`decision_ctrl_hi_persist'; level_rejections=`decision_ctrl_lev_reject'/14; difference_rejections=`decision_ctrl_diff_reject'/14") ///
    ("MAIN") ("04_twfe_full.do") ("DIAGNOSTIC_ONLY") ///
    ("Usar el inventario como contexto temporal y validar su completitud antes de estimar M3.") ///
    ("No transformar, excluir ni seleccionar controles mediante resultados de significancia.") ///
    (0)

postclose `decision_post'

preserve
    use "`decision_register'", clear

    * Validar completitud, unicidad, jerarquías y ausencia de selección por
    * significancia antes de exportar el registro.
    assert _N == 18
    isid decision_id
    assert !missing(evidence_area, evidence_source, evidence_result)
    assert !missing(hierarchy, target_script, implementation_status)
    assert !missing(methodological_action, interpretation_limit)
    assert inlist(hierarchy, "MAIN", "SENSITIVITY", "CONDITIONAL", ///
        "NOT_APPLICABLE", "EXCLUDED")
    assert significance_selected == 0

    sort decision_id
    export delimited using ///
        "$OUTPUT_DESIGN/econometric_decision_register.csv", ///
        replace datafmt
    list decision_id evidence_area hierarchy implementation_status, ///
        noobs abbreviate(32)
restore

* Informar que todos los descriptivos y diagnósticos fueron completados.
display as result "Sección 4 completada: descriptivos y diagnósticos exportados."
display as result ///
    "No se eliminaron países ni observaciones por los diagnósticos de influencia."

* Cerrar el registro al finalizar las secciones de preparación y diagnóstico.
display as result "Archivo 01 completado: secciones 1 a 4 ejecutadas sin errores."
log close preparation_log
