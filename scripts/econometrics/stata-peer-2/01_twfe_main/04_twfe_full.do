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
// Archivo: 04_twfe_full.do (Versión Codex)
// Contenido: Secciones 9 a 12 del análisis econométrico
// Requisito operativo: ejecutar primero el archivo 01
// Fecha: Segundo Cuatrimestre 2026
// *****************************************************************************


// *****************************************************************************
// INICIALIZACIÓN DEL ARCHIVO 04
// *****************************************************************************

// A.1. Limpiar la sesión y fijar el entorno reproducible

* Este archivo puede ejecutarse en una sesión nueva después del archivo 01.
* La numeración econométrica continúa directamente en la sección 9.
version 17.0
clear all
cls
macro drop _all
capture log close _all

* Configurar la forma en que Stata presenta, almacena y reproduce los
* resultados. Se desactúan las pausas y abreviaciones, se fija precisión double,
* se amplía el ancho del log y se establecen semillas para procesos aleatorios.
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

* Examinar primero el directorio actual y hasta ocho niveles superiores.
* Después se probará la ubicación habitual de Windows; project_manual queda
* disponible para otros equipos.
local project_current "`c(pwd)'"
local project_windows ///
    "C:/Users/`c(username)'/GitHub/master-thesis-project-applied-econ"
local project_manual ""
global PROJECT_ROOT ""

* Buscar el marcador desde el directorio actual y ascendiendo como máximo
* ocho niveles. Esto permite ejecutarlo desde su carpeta o desde logs/batch
* sin depender de una ruta absoluta.
local project_candidate "`project_current'"
forvalues search_level = 0/8 {
    if "$PROJECT_ROOT" == "" {
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
    capture confirm file "`project_windows'/`project_marker'"
    if !_rc {
        global PROJECT_ROOT "`project_windows'"
    }
}

* Probar finalmente la ruta manual cuando haya sido diligenciada.
if "$PROJECT_ROOT" == "" & "`project_manual'" != "" {
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

* Cambiar a la raíz identificada y mostrarla en pantalla para que el usuario
* pueda verificar desde dónde se ejecutará el resto del análisis.
quietly cd "$PROJECT_ROOT"
display as result "Raíz del proyecto localizada correctamente:"
pwd


// A.3. Definir las entradas, salidas y el log del archivo 04

* Centralizar las rutas de todas las salidas econométricas. Cada macro global
* identifica una carpeta específica y evita repetir rutas absolutas más abajo.
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

* Crear la estructura de carpetas necesaria. capture permite repetir el archivo
* sin detenerse cuando alguna carpeta ya existe.
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

* Abrir un registro de texto exclusivo para las secciones 9 a 12. replace
* garantiza que el log corresponda únicamente a la ejecución más reciente.
log using "$OUTPUT_LOGS/04_twfe_full.log", ///
    text replace name(models_log)


// A.4. Verificar e instalar los paquetes de estimación y exportación

* Añadir una biblioteca de paquetes exclusiva de stata-peer-2 sin reemplazar
* las rutas donde ya están instalados ftools, reghdfe y esttab.
adopath ++ "$ADO_PROJECT/plus"

* Indicar que las nuevas instalaciones deben escribirse en la biblioteca local,
* no en la carpeta personal del usuario.
net set ado "$ADO_PROJECT/plus"

* Confirmar que la biblioteca local y las rutas existentes forman parte de la
* búsqueda de comandos ado.
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

* boottest permite contrastar los términos centrales mediante wild cluster
* bootstrap. Esta inferencia se utilizará únicamente como sensibilidad.
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

* Actualizar el índice de bibliotecas Mata después de añadir la ruta local.
* boottest guarda sus funciones compiladas dentro de lboottest.mlib.
mata: mata mlib index


// A.5. Comprobar que el archivo 01 produjo la base analítica

* Guardar en una macro local la ruta de la base derivada que alimenta los dos
* modelos econométricos.
local estimation_file ///
    "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta"

* Detener la ejecución con una instrucción clara si todavía no se ha ejecutado
* el archivo 01 o si su base analítica no está disponible.
capture confirm file "`estimation_file'"
if _rc {
    display as error "No se encontró la base preparada para las estimaciones."
    display as error "Ejecute primero:"
    display as error ///
        "01_data_preparation_diagnostics.do"
    exit 601
}

* Informar que todas las comprobaciones de inicialización fueron superadas y
* que el archivo puede comenzar la estimación del modelo principal.
display as result ///
    "Inicialización del archivo 04 completada; comienza la sección 9."


// *****************************************************************************
// 9. Modelo TWFE Completo: ECI [Ecuación 9.17]
// *****************************************************************************


// 9.1. Cargar y verificar la muestra del modelo principal

* Abrir la base derivada en la sección 3. El panel maestro original permanece
* intacto; todas las estimaciones utilizan exclusivamente esta copia analítica.
use "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta", clear

* Confirmar que la base conserva una sola observación por país y año.
isid country_iso3_code year

* Confirmar que las variables necesarias para el modelo siguen disponibles.
confirm variable ///
    eci sample_eci country_id year ///
    rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin

* Verificar nuevamente que la interacción almacenada corresponde exactamente
* al producto entre las rentas extractivas y la calidad institucional.
assert abs(rents_x_inst - rents * inst) < 1e-10 ///
    if !missing(rents_x_inst, rents, inst)

* Declarar el identificador del país y el año como dimensiones del panel.
xtset country_id year

* Contar las observaciones y los países que deben entrar en la estimación.
* Estos valores se compararán después con la muestra utilizada por xtreg.
quietly count if sample_eci == 1
local eci_expected_n = r(N)

* Identificar los países presentes en la muestra y contar cuántos paneles
* individuales aportan al modelo ECI.
quietly levelsof country_id if sample_eci == 1, ///
    local(eci_expected_country_ids)
local eci_expected_countries : word count `eci_expected_country_ids'

* Identificar los años efectivos de estimación y contar los periodos con al
* menos una observación completa.
quietly levelsof year if sample_eci == 1, local(eci_expected_years)
local eci_expected_year_count : word count `eci_expected_years'

* Recuperar los extremos temporales para documentar el intervalo cubierto por
* la muestra analítica.
quietly summarize year if sample_eci == 1, meanonly
local eci_first_year = r(min)
local eci_last_year  = r(max)

* Los WGI no publicaron los componentes de INST en 1997, 1999 y 2001.
* Por ello la muestra de casos completos contiene 23 años efectivos dentro del
* intervalo 1996-2021. Se conservan los vacíos: no se imputan ni interpolan.
foreach structural_wgi_gap in 1997 1999 2001 {
    quietly count if year == `structural_wgi_gap' & sample_eci == 1
    assert r(N) == 0
}

* Mostrar en pantalla la cobertura que deberá reproducir la estimación.
display as text ///
    "Muestra esperada para ECI: `eci_expected_n' observaciones, " ///
    "`eci_expected_countries' países y `eci_expected_year_count' años."
display as text ///
    "Años WGI sin casos completos: 1997, 1999 y 2001."


// 9.2. Definir la ecuación ECI y la estrategia de inferencia

* Escribir la interacción con notación factorial. El operador ## incorpora
* RENTS, INST y RENTS x INST y permitirá calcular efectos marginales en la
* sección 7 sin reconstruir manualmente el modelo.
global ECI_REGRESSORS ///
    c.rents##c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin

* Definir los 17 términos sustantivos que se reportarán. Los indicadores de año
* también forman parte de la estimación, pero no se mostrarán como coeficientes
* individuales en las tablas principales.
local eci_terms ///
    rents inst c.rents#c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin

* Aplicar la decisión aprobada en el Control C. Los errores se agrupan por país
* porque los diagnósticos detectaron heterocedasticidad y autocorrelación.
global INFERENCE_MAIN "vce(cluster country_id)"


// 9.3. Estimar el modelo principal mediante xtreg

* Estimar la ecuación completa de la metodología:
* - fe absorbe los efectos fijos por país;
* - i.year incorpora los efectos fijos por año;
* - vce(cluster country_id) permite dependencia arbitraria dentro de cada país.
xtreg eci $ECI_REGRESSORS i.year if sample_eci == 1, ///
    fe $INFERENCE_MAIN

* Eliminar una copia previa con el mismo nombre para que la sección pueda
* ejecutarse nuevamente durante la revisión interactiva.
capture estimates drop ECI_TWFE_MAIN

* Guardar la estimación principal en la memoria de Stata.
estimates store ECI_TWFE_MAIN

* Guardar también una copia permanente para recuperarla sin reestimar.
estimates save "$OUTPUT_ECI/eci_twfe_main.ster", replace

* Comprobar que xtreg utilizó todos y únicamente los casos completos definidos
* en la sección 3. Cualquier diferencia detiene inmediatamente el archivo.
assert e(sample) == sample_eci
assert e(N)   == `eci_expected_n'
assert e(N_g) == `eci_expected_countries'

* Guardar los principales resultados globales antes de ejecutar pruebas o abrir
* archivos temporales de resultados.
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

* Con errores agrupados por país, Stata utiliza G-1 grados de libertad para la
* inferencia, donde G es el número de países que actúan como conglomerados.
assert `eci_df_error' == `eci_clusters' - 1

* Mostrar el tamaño de la estimación y su principal medida de ajuste within.
display as result ///
    "Modelo ECI estimado con `eci_n' observaciones y `eci_countries' países."
display as result ///
    "R-cuadrado within: " %9.4f `eci_r2_within'


// 9.4. Exportar los coeficientes y la incertidumbre del modelo

* Crear un reporte largo con una fila por término sustantivo. Este formato
* facilita revisar coeficientes, errores estándar, valores p e intervalos.
tempname eci_coefficients_post
tempfile eci_coefficients_report

* Definir la estructura del archivo temporal que recibirá una fila por
* coeficiente sustantivo del modelo.
postfile `eci_coefficients_post' ///
    int order ///
    str32 term ///
    str100 variable_label ///
    str32 channel ///
    double coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper ///
    using "`eci_coefficients_report'", replace

* Utilizar la distribución t con grados de libertad determinados por los
* conglomerados de país para construir intervalos de confianza del 95 %.
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

    // Reemplazar la categoría predeterminada cuando el término pertenece a uno
    // de los canales sustantivos de la especificación.
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

    // Añadir al archivo temporal todos los resultados calculados para el término
    // que se encuentra activo en esta iteración.
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

    * Mostrar los coeficientes en la ventana de resultados para facilitar la
    * revisión cuando el archivo se ejecute de forma interactiva.
    list term coefficient standard_error p_value ci_lower ci_upper, ///
        noobs abbreviate(24)
restore


// 9.5. Exportar el resumen general de la estimación

* Crear una tabla de una fila con tamaño de muestra, cobertura, ajuste y
* componentes de la varianza del modelo de efectos fijos.
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

* Abrir temporalmente el resumen, aplicar formatos y conservar intacta la base
* analítica que permanece en memoria.
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
post `eci_tests_post' ///
    (1) ///
    ("Canal institucional") ///
    ("RENTS, INST y RENTS x INST son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 2: los coeficientes de petróleo, gas y carbón son conjuntamente cero.
test ln1p_oilpc ln1p_gaspc ln1p_coalpc
post `eci_tests_post' ///
    (2) ///
    ("Canal de abundancia") ///
    ("Petróleo, gas y carbón son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 3: concentración y especialización exportadora son conjuntamente cero.
test hhi pexp fexp
post `eci_tests_post' ///
    (3) ///
    ("Canal estructural") ///
    ("HHI, PEXP y FEXP son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 4: volatilidad y tipo de cambio real son conjuntamente cero.
test vol rer
post `eci_tests_post' ///
    (4) ///
    ("Canal macroeconómico") ///
    ("VOL y RER son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 5: capital humano, innovación y conectividad son conjuntamente cero.
test humcap innov net
post `eci_tests_post' ///
    (5) ///
    ("Capacidades productivas") ///
    ("HUMCAP, INNOV y NET son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 6: los tres controles económicos y financieros son conjuntamente cero.
test log_gdppc govcons fin
post `eci_tests_post' ///
    (6) ///
    ("Controles económicos y financieros") ///
    ("log(GDPPC), GOVCONS y FIN son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 7: verificar la relevancia conjunta de los efectos temporales.
testparm i.year
post `eci_tests_post' ///
    (7) ///
    ("Efectos fijos por año") ///
    ("Todos los indicadores de año son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 8: evaluar si petróleo, gas y carbón tienen el mismo coeficiente.
* Esta prueba no impone que los efectos sean cero, sino que sean iguales.
test (ln1p_oilpc = ln1p_gaspc) ///
     (ln1p_oilpc = ln1p_coalpc)
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

* Estimar exactamente la misma ecuación absorbiendo directamente los efectos
* fijos por país y año. Esta no es una especificación adicional: funciona como
* una comprobación numérica independiente del modelo principal.
reghdfe eci $ECI_REGRESSORS if sample_eci == 1, ///
    absorb(country_id year) $INFERENCE_MAIN

* Eliminar una copia previa con el mismo nombre si se repite esta sección.
capture estimates drop ECI_REGHDFE_CHECK

* Guardar la estimación de comprobación sin reemplazar el resultado principal.
estimates store ECI_REGHDFE_CHECK
estimates save "$OUTPUT_ECI/eci_reghdfe_check.ster", replace

* Verificar que reghdfe conservó la misma muestra utilizada por xtreg.
assert e(N) == `eci_n'

* Guardar el tamaño de la comprobación, el número de singletons y la tolerancia
* numérica que se utilizará para comparar ambos comandos.
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

* Reiniciar el contador para que el orden coincida con el reporte de
* coeficientes producido anteriormente.
local eci_term_order = 0

* Recorrer los términos sustantivos y comparar las dos implementaciones.
foreach term of local eci_terms {
    local ++eci_term_order

    // Comparar coeficientes y registrar también cualquier diferencia entre los
    // errores estándar producidos por los dos comandos.
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

* Exportar una tabla provisional con los coeficientes sustantivos. La sección 8
* se encargará posteriormente del formato final y de integrar ECI con DIVX.
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

* Abrir nuevamente la base analítica completa. Este paso evita que una
* transformación temporal de la sección 9 pueda afectar el modelo DIVX.
use "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta", clear

* Confirmar que cada fila continúa identificada de manera única por país y año.
isid country_iso3_code year

* Verificar que están disponibles DIVX, su bandera de muestra y todos los
* regresores previstos. HHI se conserva únicamente para validar la identidad
* DIVX = 1 - HHI; no se incorporará en la ecuación econométrica.
confirm variable ///
    divx hhi sample_divx country_id year ///
    rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin

* Confirmar que la variable dependiente complementaria sigue correspondiendo
* exactamente al inverso del índice de concentración exportadora.
assert abs(divx - (1 - hhi)) < 1e-10 if !missing(divx, hhi)

* Confirmar también la identidad de la interacción institucional.
assert abs(rents_x_inst - rents * inst) < 1e-10 ///
    if !missing(rents_x_inst, rents, inst)

* Declarar nuevamente la estructura país-año del panel.
xtset country_id year

* Contar las observaciones que deben ingresar en el modelo DIVX.
quietly count if sample_divx == 1
local divx_expected_n = r(N)

* Identificar los países presentes y contar cuántos paneles individuales
* aportan observaciones al modelo complementario.
quietly levelsof country_id if sample_divx == 1, ///
    local(divx_expected_country_ids)
local divx_expected_countries : word count `divx_expected_country_ids'

* Identificar los años efectivos y contar los periodos representados en la
* muestra completa del modelo DIVX.
quietly levelsof year if sample_divx == 1, local(divx_expected_years)
local divx_expected_year_count : word count `divx_expected_years'

* Recuperar el primer y el último año para documentar la cobertura temporal.
quietly summarize year if sample_divx == 1, meanonly
local divx_first_year = r(min)
local divx_last_year  = r(max)

* Verificar que los vacíos estructurales de WGI permanecen fuera de la muestra.
foreach structural_wgi_gap in 1997 1999 2001 {
    quietly count if year == `structural_wgi_gap' & sample_divx == 1
    assert r(N) == 0
}

* Mostrar en pantalla la cobertura que deberá conservar la estimación DIVX.
display as text ///
    "Muestra esperada para DIVX: `divx_expected_n' observaciones, " ///
    "`divx_expected_countries' países y `divx_expected_year_count' años."
display as text ///
    "Años WGI sin casos completos: 1997, 1999 y 2001."


// 10.2. Definir la ecuación DIVX y excluir HHI

* Mantener la misma especificación aprobada para ECI, excepto HHI. Incluir HHI
* sería una identidad mecánica porque DIVX se construye como 1 - HHI.
global DIVX_REGRESSORS ///
    c.rents##c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin

* Definir los 16 términos sustantivos que se exportarán. Los indicadores de año
* permanecen en la estimación, pero no se muestran individualmente.
local divx_terms ///
    rents inst c.rents#c.inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    pexp fexp ///
    vol rer ///
    humcap innov net ///
    log_gdppc govcons fin

* Buscar el nombre HHI dentro de la lista de regresores para impedir que una
* edición futura introduzca accidentalmente esta identidad en la ecuación.
local divx_hhi_position = strpos(" $DIVX_REGRESSORS ", " hhi ")

* Detener la ejecución si la búsqueda anterior encuentra HHI.
assert `divx_hhi_position' == 0

* Conservar la inferencia aprobada en el Control C: errores estándar agrupados
* por país para responder a heterocedasticidad y autocorrelación.
global INFERENCE_MAIN "vce(cluster country_id)"


// 10.3. Estimar el modelo complementario mediante xtreg

* Estimar DIVX con efectos fijos por país, indicadores de año y errores
* agrupados por país. La estructura es idéntica a ECI salvo por la exclusión de
* HHI y el cambio de variable dependiente.
xtreg divx $DIVX_REGRESSORS i.year if sample_divx == 1, ///
    fe $INFERENCE_MAIN

* Eliminar de la memoria una estimación anterior con el mismo nombre para que
* esta sección pueda ejecutarse nuevamente durante la revisión.
capture estimates drop DIVX_TWFE_MAIN

* Guardar la estimación principal en la memoria activa de Stata.
estimates store DIVX_TWFE_MAIN

* Guardar una copia permanente que pueda recuperarse sin volver a estimar.
estimates save "$OUTPUT_DIVX/divx_twfe_main.ster", replace

* Comprobar que la estimación utilizó todos y únicamente los casos previstos.
assert e(sample) == sample_divx
assert e(N)   == `divx_expected_n'
assert e(N_g) == `divx_expected_countries'

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

* Definir la estructura del archivo temporal que recibirá una fila por
* coeficiente sustantivo.
postfile `divx_coefficients_post' ///
    int order ///
    str32 term ///
    str100 variable_label ///
    str32 channel ///
    double coefficient standard_error t_statistic p_value ///
    ci_lower ci_upper ///
    using "`divx_coefficients_report'", replace

* Calcular el valor crítico t correspondiente a 49 conglomerados y reiniciar el
* contador que define el orden de presentación.
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

    // Reemplazar la categoría predeterminada cuando el término pertenece a uno
    // de los canales sustantivos del modelo.
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
post `divx_tests_post' ///
    (1) ///
    ("Canal institucional") ///
    ("RENTS, INST y RENTS x INST son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 2: petróleo, gas y carbón son conjuntamente cero.
test ln1p_oilpc ln1p_gaspc ln1p_coalpc
post `divx_tests_post' ///
    (2) ///
    ("Canal de abundancia") ///
    ("Petróleo, gas y carbón son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 3: PEXP y FEXP son conjuntamente cero. HHI queda expresamente fuera
* porque constituye la transformación inversa de la variable dependiente.
test pexp fexp
post `divx_tests_post' ///
    (3) ///
    ("Canal estructural") ///
    ("PEXP y FEXP son conjuntamente cero; HHI está excluido") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 4: volatilidad y tipo de cambio real son conjuntamente cero.
test vol rer
post `divx_tests_post' ///
    (4) ///
    ("Canal macroeconómico") ///
    ("VOL y RER son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 5: capital humano, innovación y conectividad son conjuntamente cero.
test humcap innov net
post `divx_tests_post' ///
    (5) ///
    ("Capacidades productivas") ///
    ("HUMCAP, INNOV y NET son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 6: los controles económicos y financieros son conjuntamente cero.
test log_gdppc govcons fin
post `divx_tests_post' ///
    (6) ///
    ("Controles económicos y financieros") ///
    ("log(GDPPC), GOVCONS y FIN son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 7: los indicadores de año son conjuntamente cero.
testparm i.year
post `divx_tests_post' ///
    (7) ///
    ("Efectos fijos por año") ///
    ("Todos los indicadores de año son conjuntamente cero") ///
    (r(F)) (r(df)) (r(df_r)) (r(p))

* Prueba 8: petróleo, gas y carbón tienen el mismo coeficiente.
test (ln1p_oilpc = ln1p_gaspc) ///
     (ln1p_oilpc = ln1p_coalpc)
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

* Reestimar exactamente la misma ecuación absorbiendo los efectos fijos por
* país y año. Esta es una comprobación numérica, no un modelo alternativo.
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

* Recuperar el modelo xtreg porque constituye la estimación complementaria que
* se comparará con ECI en el Control E.
estimates restore DIVX_TWFE_MAIN

* Exportar una tabla provisional. La sección 8 integrará posteriormente los dos
* modelos dentro de una presentación común.
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

* Abrir nuevamente la base derivada para que todas las sensibilidades partan de
* la misma información utilizada por los modelos principales.
use "$OUTPUT_SAMPLE/master_panel_estimation_sample.dta", clear

* Confirmar que la llave país-año continúa identificando cada observación.
isid country_iso3_code year

* Verificar las variables que se utilizarán para efectos marginales,
* exclusiones y reestimaciones de estabilidad.
confirm variable ///
    eci divx sample_eci sample_divx ///
    country_iso3_code country_id year ///
    rents inst rents_x_inst ///
    ln1p_oilpc ln1p_gaspc ln1p_coalpc ///
    hhi pexp fexp vol rer humcap innov net ///
    log_gdppc govcons fin

* Confirmar que ECI y DIVX utilizan exactamente las mismas observaciones. Esta
* igualdad permite comparar las sensibilidades sin cambios de composición.
assert sample_eci == sample_divx

* Declarar nuevamente las dimensiones del panel antes de reestimar modelos.
xtset country_id year

* Calcular percentiles de INST dentro de la muestra común. Se emplean P10, P25,
* P50, P75 y P90 para evitar que casos extremos determinen toda la figura.
quietly summarize inst if sample_eci == 1, detail
local inst_p10 = r(p10)
local inst_p25 = r(p25)
local inst_p50 = r(p50)
local inst_p75 = r(p75)
local inst_p90 = r(p90)
local inst_min = r(min)
local inst_max = r(max)

* Reunir los cinco valores y sus nombres en macros que se reutilizarán para
* ambos modelos y para la exportación del reporte.
local inst_values ///
    "`inst_p10' `inst_p25' `inst_p50' `inst_p75' `inst_p90'"
local inst_labels "P10 P25 P50 P75 P90"

* Mostrar el rango completo y los puntos seleccionados para que el usuario
* pueda verificar qué niveles institucionales alimentan los márgenes.
display as text ///
    "Rango observado de INST: " %9.4f `inst_min' " a " %9.4f `inst_max'
display as text ///
    "Valores de referencia: `inst_values'"

* Recuperar los coeficientes centrales ECI almacenados. La marca e(sample) ya no
* es válida después de use, pero los coeficientes y la matriz de varianzas sí.
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

* Crear un archivo temporal común para guardar efectos, errores estándar,
* valores p e intervalos de confianza de ECI y DIVX.
tempname margins_post
tempfile margins_report
postfile `margins_post' ///
    str8 model ///
    str4 institutional_percentile ///
    double inst_value marginal_effect standard_error ///
    t_statistic p_value ci_lower ci_upper ///
    str12 significance ///
    using "`margins_report'", replace

* Reestimar silenciosamente el modelo ECI aprobado. La recarga de la base
* invalida la marca interna e(sample) de una estimación restaurada y margins
* necesita reconstruirla sobre los mismos 1.044 casos.
quietly xtreg eci $ECI_REGRESSORS i.year if sample_eci == 1, ///
    fe $INFERENCE_MAIN

* Confirmar que la reestimación utilizada por margins reproduce el coeficiente
* RENTS del modelo principal y conserva su muestra completa.
assert abs(_b[rents] - `eci_base_rents_b') < 1e-10
assert e(N) == `eci_expected_n'
assert e(N_g) == `eci_expected_countries'

* Calcular d(ECI)/d(RENTS) en los cinco percentiles institucionales. Con una
* interacción lineal, cada margen combina el coeficiente de RENTS con el de
* RENTS x INST y conserva su incertidumbre conjunta.
margins, dydx(rents) at(inst=(`inst_values'))

* Conservar la tabla completa devuelta por margins antes de construir la
* figura o ejecutar cualquier otro comando.
matrix eci_margins_table = r(table)

* Graficar la asociación marginal estimada y su intervalo de confianza del
* 95 %. La línea horizontal en cero permite identificar dónde cambia el signo.
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

* Recorrer las cinco columnas de la tabla de margins y registrar cada resultado
* con el percentil institucional correspondiente.
forvalues column = 1/5 {
    local percentile : word `column' of `inst_labels'
    local inst_value : word `column' of `inst_values'
    local effect = el(eci_margins_table, 1, `column')
    local se     = el(eci_margins_table, 2, `column')
    local tstat  = el(eci_margins_table, 3, `column')
    local pvalue = el(eci_margins_table, 4, `column')
    local lower  = el(eci_margins_table, 5, `column')
    local upper  = el(eci_margins_table, 6, `column')

    // Clasificar la precisión estadística sin convertirla en una conclusión
    // causal ni alterar el umbral principal del estudio.
    local significance "No"
    if `pvalue' < 0.10 local significance "10%"
    if `pvalue' < 0.05 local significance "5%"
    if `pvalue' < 0.01 local significance "1%"

    // Guardar el efecto marginal ECI y todas las cantidades necesarias para
    // reproducir su interpretación.
    post `margins_post' ///
        ("ECI") ///
        ("`percentile'") ///
        (`inst_value') ///
        (`effect') (`se') (`tstat') (`pvalue') ///
        (`lower') (`upper') ///
        ("`significance'")
}

* Reestimar silenciosamente DIVX para reconstruir e(sample) después de cargar
* nuevamente la base analítica.
quietly xtreg divx $DIVX_REGRESSORS i.year if sample_divx == 1, ///
    fe $INFERENCE_MAIN

* Confirmar que la reestimación reproduce el coeficiente RENTS y la muestra del
* modelo complementario.
assert abs(_b[rents] - `divx_base_rents_b') < 1e-10
assert e(N) == `divx_expected_n'
assert e(N_g) == `divx_expected_countries'

* Calcular d(DIVX)/d(RENTS) en los mismos percentiles de INST utilizados para
* ECI, manteniendo así una comparación sobre puntos idénticos.
margins, dydx(rents) at(inst=(`inst_values'))

* Guardar la tabla completa del modelo DIVX antes de construir la figura.
matrix divx_margins_table = r(table)

* Graficar los efectos marginales DIVX con intervalo de confianza del 95 % y
* una referencia explícita en cero.
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

* Registrar los cinco resultados marginales de DIVX dentro del mismo reporte
* utilizado para ECI.
forvalues column = 1/5 {
    local percentile : word `column' of `inst_labels'
    local inst_value : word `column' of `inst_values'
    local effect = el(divx_margins_table, 1, `column')
    local se     = el(divx_margins_table, 2, `column')
    local tstat  = el(divx_margins_table, 3, `column')
    local pvalue = el(divx_margins_table, 4, `column')
    local lower  = el(divx_margins_table, 5, `column')
    local upper  = el(divx_margins_table, 6, `column')

    // Aplicar la misma clasificación descriptiva de significancia empleada
    // para ECI.
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

* Crear un reporte compacto que reúna las pruebas ya previstas en los dos
* modelos y evite interpretar coeficientes individuales de forma aislada.
tempname resource_test_post
tempfile resource_test_report
postfile `resource_test_post' ///
    str8 model ///
    str90 null_hypothesis ///
    double f_statistic df1 df2 p_value ///
    str16 decision ///
    using "`resource_test_report'", replace

* Recuperar ECI y contrastar que los tres coeficientes transformados sean
* iguales entre sí.
estimates restore ECI_TWFE_MAIN
test (ln1p_oilpc = ln1p_gaspc) ///
     (ln1p_oilpc = ln1p_coalpc)
local eci_resource_decision "No rechazar H0"
if r(p) < 0.05 local eci_resource_decision "Rechazar H0"
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

* Comparar la especificación principal ln(1+x) con una alternativa que utiliza
* OILPC, GASPC y COALPC en niveles. RENTS permanece agregado y sin cambios.
* Esta prueba evalúa una decisión de transformación, no una desagregación entre
* hidrocarburos y minería ni una nueva ecuación principal.
tempname pc_transform_post
tempfile pc_transform_report
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

* Recuperar el modelo ECI principal y registrar sus coeficientes bajo la
* transformación ln(1+x), que admite ceros y reduce la asimetría de las series.
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
post `pc_transform_post' ///
    ("ECI") ("ln(1+x), principal") ///
    (e(N)) (e(N_g)) ///
    (_b[rents]) (_se[rents]) (`eci_main_rents_p') ///
    (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) ///
    (`eci_main_interaction_p') ///
    ("ln1p_oilpc") (_b[ln1p_oilpc]) (`eci_main_oil_p') ///
    ("ln1p_gaspc") (_b[ln1p_gaspc]) (`eci_main_gas_p') ///
    ("ln1p_coalpc") (_b[ln1p_coalpc]) (`eci_main_coal_p')

* Reestimar ECI sustituyendo únicamente los tres controles transformados por
* sus valores per cápita sin transformar; el resto de la ecuación no cambia.
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
assert e(N) == `eci_expected_n'
assert e(N_g) == `eci_expected_countries'

* Guardar la alternativa ECI para poder incluirla en la tabla comparativa final.
capture estimates drop ECI_PC_LEVELS_SENSITIVITY
estimates store ECI_PC_LEVELS_SENSITIVITY
estimates save ///
    "$OUTPUT_STABILITY/eci_per_capita_levels_sensitivity.ster", ///
    replace

* Calcular y registrar la incertidumbre de los términos relevantes en la
* especificación ECI con controles per cápita sin transformar.
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
post `pc_transform_post' ///
    ("ECI") ("Niveles per capita") ///
    (e(N)) (e(N_g)) ///
    (_b[rents]) (_se[rents]) (`eci_levels_rents_p') ///
    (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) ///
    (`eci_levels_interaction_p') ///
    ("oilpc") (_b[oilpc]) (`eci_levels_oil_p') ///
    ("gaspc") (_b[gaspc]) (`eci_levels_gas_p') ///
    ("coalpc") (_b[coalpc]) (`eci_levels_coal_p')

* Recuperar el modelo DIVX principal y registrar la especificación aprobada con
* los tres componentes per cápita transformados mediante ln(1+x).
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
post `pc_transform_post' ///
    ("DIVX") ("ln(1+x), principal") ///
    (e(N)) (e(N_g)) ///
    (_b[rents]) (_se[rents]) (`divx_main_rents_p') ///
    (_b[c.rents#c.inst]) (_se[c.rents#c.inst]) ///
    (`divx_main_interaction_p') ///
    ("ln1p_oilpc") (_b[ln1p_oilpc]) (`divx_main_oil_p') ///
    ("ln1p_gaspc") (_b[ln1p_gaspc]) (`divx_main_gas_p') ///
    ("ln1p_coalpc") (_b[ln1p_coalpc]) (`divx_main_coal_p')

* Reestimar DIVX con los controles OILPC, GASPC y COALPC en niveles, manteniendo
* la exclusión de HHI y todos los demás elementos de la ecuación aprobada.
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
assert e(N) == `divx_expected_n'
assert e(N_g) == `divx_expected_countries'

* Guardar la alternativa DIVX para su revisión y exportación reproducible.
capture estimates drop DIVX_PC_LEVELS_SENSITIVITY
estimates store DIVX_PC_LEVELS_SENSITIVITY
estimates save ///
    "$OUTPUT_STABILITY/divx_per_capita_levels_sensitivity.ster", ///
    replace

* Calcular y registrar la incertidumbre de los términos relevantes en la
* especificación DIVX con controles per cápita sin transformar.
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

* Exportar la comparación numérica en formato abierto y con una fila por
* modelo-especificación para facilitar la revisión entre pares.
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
estimates restore DIVX_TWFE_MAIN


// 11.5. Evaluar sensibilidad a las observaciones previamente señaladas

* Confirmar que la sección 4 dejó disponible el inventario de alertas. Estas
* filas son casos para revisión y no observaciones declaradas erróneas.
capture confirm file ///
    "$OUTPUT_DIAGNOSTICS/influential_observations.csv"
if _rc {
    display as error ///
        "No se encontró influential_observations.csv; ejecute el archivo 01."
    exit 601
}

* Transformar el inventario largo de alertas en dos indicadores país-año, uno
* para ECI y otro para DIVX.
tempfile influence_flags
preserve
    import delimited using ///
        "$OUTPUT_DIAGNOSTICS/influential_observations.csv", ///
        clear varnames(1)
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

* Completar con cero los país-año que nunca fueron señalados por los
* diagnósticos.
replace influential_eci  = 0 if missing(influential_eci)
replace influential_divx = 0 if missing(influential_divx)

* Verificar que la combinación reproduce exactamente las 70 alertas ECI.
quietly count if sample_eci == 1 & influential_eci == 1
local eci_influential_n = r(N)
assert `eci_influential_n' == 70

* Verificar que la combinación reproduce exactamente las 75 alertas DIVX.
quietly count if sample_divx == 1 & influential_divx == 1
local divx_influential_n = r(N)
assert `divx_influential_n' == 75

* Preparar un reporte que compare cada estimación base con la sensibilidad que
* excluye conjuntamente todas las observaciones señaladas.
tempname influential_post
tempfile influential_report
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
post `influential_post' ///
    ("ECI") ("Modelo base") ///
    (e(N)) (e(N_g)) ///
    (`eci_base_rents_b') (`eci_base_rents_se') (`eci_base_rents_p') ///
    (`eci_base_interaction_b') ///
    (`eci_base_interaction_se') (`eci_base_interaction_p')

* Reestimar ECI sin las 70 observaciones señaladas. Esta especificación se
* conserva únicamente como sensibilidad y no reemplaza ECI_TWFE_MAIN.
quietly xtreg eci $ECI_REGRESSORS i.year ///
    if sample_eci == 1 & influential_eci == 0, ///
    fe $INFERENCE_MAIN
capture estimates drop ECI_EXCL_INFLUENTIAL
estimates store ECI_EXCL_INFLUENTIAL
local eci_excl_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local eci_excl_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))
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
post `influential_post' ///
    ("DIVX") ("Modelo base") ///
    (e(N)) (e(N_g)) ///
    (`divx_base_rents_b') (`divx_base_rents_se') (`divx_base_rents_p') ///
    (`divx_base_interaction_b') ///
    (`divx_base_interaction_se') (`divx_base_interaction_p')

* Reestimar DIVX sin las 75 observaciones señaladas. Esta sensibilidad tampoco
* modifica la estimación complementaria principal.
quietly xtreg divx $DIVX_REGRESSORS i.year ///
    if sample_divx == 1 & influential_divx == 0, ///
    fe $INFERENCE_MAIN
capture estimates drop DIVX_EXCL_INFLUENTIAL
estimates store DIVX_EXCL_INFLUENTIAL
local divx_excl_rents_p = ///
    2 * ttail(e(df_r), abs(_b[rents] / _se[rents]))
local divx_excl_interaction_p = ///
    2 * ttail(e(df_r), ///
        abs(_b[c.rents#c.inst] / _se[c.rents#c.inst]))
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

* Crear un archivo donde cada fila registre una reestimación que excluye un
* país y un término central.
tempname leave_one_out_post
tempfile leave_one_out_report
postfile `leave_one_out_post' ///
    str8 model ///
    double excluded_country_id ///
    str3 excluded_country_iso3 ///
    str24 term ///
    double base_coefficient coefficient standard_error p_value ///
    observations countries ///
    using "`leave_one_out_report'", replace

* Excluir sucesivamente cada país del modelo ECI y registrar RENTS y la
* interacción institucional.
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

* Excluir sucesivamente cada país del modelo DIVX y registrar los mismos dos
* términos para una comparación simétrica.
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

* Cerrar el archivo después de completar las 196 combinaciones
* modelo-país-término.
postclose `leave_one_out_post'

* Exportar el detalle completo y construir una síntesis por modelo y término.
preserve
    use "`leave_one_out_report'", clear
    sort model term excluded_country_iso3

    * Identificar cambios de signo y la frecuencia con que cada término conserva
    * significancia en las reestimaciones.
    generate byte sign_reversal = ///
        sign(coefficient) != sign(base_coefficient)
    generate byte significant_5  = p_value < 0.05
    generate byte significant_10 = p_value < 0.10

    * Guardar las 196 reestimaciones antes de reducirlas a un resumen.
    format base_coefficient coefficient standard_error p_value %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/leave_one_country_out.csv", ///
        replace datafmt

    * Resumir rangos de coeficientes y valores p, además de cambios de signo y
    * frecuencias de significancia.
    collapse ///
        (count) repetitions=coefficient ///
        (firstnm) base_coefficient ///
        (min) min_coefficient=coefficient min_p_value=p_value ///
        (max) max_coefficient=coefficient max_p_value=p_value ///
        (sum) sign_reversals=sign_reversal ///
              significant_5 significant_10, ///
        by(model term)

    * Exportar la síntesis utilizada para decidir si un solo país domina el
    * resultado central.
    format base_coefficient min_coefficient max_coefficient ///
        min_p_value max_p_value %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/leave_one_country_out_summary.csv", ///
        replace datafmt
    list, noobs sepby(model) abbreviate(24)
restore


// 11.7. Aplicar wild cluster bootstrap como inferencia alternativa

* Preparar un reporte para los valores p e intervalos de confianza bootstrap.
* Esta inferencia complementa, pero no sustituye, el agrupamiento convencional.
tempname wild_bootstrap_post
tempfile wild_bootstrap_report
postfile `wild_bootstrap_post' ///
    str8 model ///
    str24 term ///
    double coefficient conventional_p bootstrap_p ///
    ci_lower ci_upper repetitions ///
    str12 weight_type ///
    using "`wild_bootstrap_report'", replace

* Reestimar ECI mediante xtreg con efectos de año explícitos. boottest no admite
* reghdfe con dos conjuntos absorbidos, mientras que esta es precisamente la
* especificación principal aprobada.
quietly xtreg eci $ECI_REGRESSORS i.year ///
    if sample_eci == 1, ///
    fe $INFERENCE_MAIN

* Confirmar nuevamente que el coeficiente RENTS coincide con la referencia.
assert abs(_b[rents] - `eci_base_rents_b') < 1e-10

* Aplicar wild cluster bootstrap al coeficiente RENTS de ECI con 9.999
* repeticiones y una semilla fija.
boottest rents, ///
    cluster(country_id) ///
    reps(9999) ///
    seed(20260729) ///
    nograph

* Detener la ejecución si boottest no devuelve una probabilidad válida.
if missing(r(p)) {
    display as error ///
        "boottest no produjo un valor p para RENTS en ECI."
    exit 498
}

* Guardar intervalo de confianza bootstrap de RENTS en ECI
matrix eci_rents_bootstrap_ci = r(CI)
post `wild_bootstrap_post' ///
    ("ECI") ("RENTS") ///
    (_b[rents]) (`eci_base_rents_p') (r(p)) ///
    (el(eci_rents_bootstrap_ci, 1, 1)) ///
    (el(eci_rents_bootstrap_ci, 1, 2)) ///
    (r(reps)) ("`r(weighttype)'")

* Aplicar el mismo procedimiento a la interacción RENTS x INST de ECI.
boottest c.rents#c.inst, ///
    cluster(country_id) ///
    reps(9999) ///
    seed(20260730) ///
    nograph

* Detener la ejecución si falta el resultado bootstrap de la interacción ECI.
if missing(r(p)) {
    display as error ///
        "boottest no produjo un valor p para RENTS x INST en ECI."
    exit 498
}

* Guardar intervalo de confianza bootstrap de RENTS x INST en ECI
matrix eci_interaction_bootstrap_ci = r(CI)
post `wild_bootstrap_post' ///
    ("ECI") ("RENTS x INST") ///
    (_b[c.rents#c.inst]) (`eci_base_interaction_p') (r(p)) ///
    (el(eci_interaction_bootstrap_ci, 1, 1)) ///
    (el(eci_interaction_bootstrap_ci, 1, 2)) ///
    (r(reps)) ("`r(weighttype)'")

* Reestimar DIVX mediante xtreg con efectos de año explícitos para utilizar una
* especificación compatible con boottest.
quietly xtreg divx $DIVX_REGRESSORS i.year ///
    if sample_divx == 1, ///
    fe $INFERENCE_MAIN

* Confirmar que el coeficiente RENTS coincide con la estimación DIVX base.
assert abs(_b[rents] - `divx_base_rents_b') < 1e-10

* Aplicar wild cluster bootstrap al coeficiente RENTS de DIVX.
boottest rents, ///
    cluster(country_id) ///
    reps(9999) ///
    seed(20260731) ///
    nograph

* Detener la ejecución si falta el valor p bootstrap de RENTS en DIVX.
if missing(r(p)) {
    display as error ///
        "boottest no produjo un valor p para RENTS en DIVX."
    exit 498
}

* Guardar intervalo de confianza bootstrap de RENTS en DIVX
matrix divx_rents_bootstrap_ci = r(CI)
post `wild_bootstrap_post' ///
    ("DIVX") ("RENTS") ///
    (_b[rents]) (`divx_base_rents_p') (r(p)) ///
    (el(divx_rents_bootstrap_ci, 1, 1)) ///
    (el(divx_rents_bootstrap_ci, 1, 2)) ///
    (r(reps)) ("`r(weighttype)'")

* Aplicar wild cluster bootstrap a la interacción RENTS x INST de DIVX.
boottest c.rents#c.inst, ///
    cluster(country_id) ///
    reps(9999) ///
    seed(20260732) ///
    nograph

* Detener la ejecución si falta el resultado bootstrap de la interacción DIVX.
if missing(r(p)) {
    display as error ///
        "boottest no produjo un valor p para RENTS x INST en DIVX."
    exit 498
}

* Guardar intervalo de confianza bootstrap de RENTS x INST en DIVX
matrix divx_interaction_bootstrap_ci = r(CI)
post `wild_bootstrap_post' ///
    ("DIVX") ("RENTS x INST") ///
    (_b[c.rents#c.inst]) (`divx_base_interaction_p') (r(p)) ///
    (el(divx_interaction_bootstrap_ci, 1, 1)) ///
    (el(divx_interaction_bootstrap_ci, 1, 2)) ///
    (r(reps)) ("`r(weighttype)'")

* Cerrar el archivo después de las cuatro pruebas bootstrap.
postclose `wild_bootstrap_post'

* Exportar la comparación entre inferencia convencional y bootstrap.
preserve
    use "`wild_bootstrap_report'", clear
    sort model term
    format coefficient conventional_p bootstrap_p ///
        ci_lower ci_upper %12.6f
    export delimited using ///
        "$OUTPUT_STABILITY/wild_cluster_bootstrap.csv", ///
        replace datafmt
    list, noobs sepby(model) abbreviate(24)
restore


// 11.8. Cerrar la sección sin sustituir los modelos principales

* Recuperar la estimación DIVX principal para que la sección 8 encuentre los dos
* modelos base almacenados y ninguna sensibilidad activa por accidente.
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

* Recuperar ECI y verificar que el objeto almacenado conserva la muestra
* aprobada. La sección 8 organiza resultados; no modifica la estimación.
estimates restore ECI_TWFE_MAIN
assert e(N) == `eci_expected_n'
assert e(N_g) == `eci_expected_countries'

* Recuperar DIVX y repetir las comprobaciones de cobertura antes de construir
* cualquier tabla comparativa.
estimates restore DIVX_TWFE_MAIN
assert e(N) == `divx_expected_n'
assert e(N_g) == `divx_expected_countries'

* Confirmar que ambos modelos continúan utilizando exactamente la misma muestra
* país-año, condición necesaria para su lectura conjunta.
assert `eci_expected_n' == `divx_expected_n'
assert `eci_expected_countries' == `divx_expected_countries'
assert `eci_expected_year_count' == `divx_expected_year_count'

* Verificar la existencia de los archivos numéricos generados en las secciones
* 5, 6 y 7. Si falta uno, el paquete final no debe presentarse como completo.
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
    outputs/econometrics/stata-peer-2/01_twfe_main/05_stability/wild_cluster_bootstrap.csv

* Recorrer la lista anterior y detener la ejecución ante cualquier ausencia.
foreach prerequisite_file of local prerequisite_files {
    capture confirm file "`prerequisite_file'"
    if _rc {
        display as error ///
            "Falta un resultado requerido para la sección 8:"
        display as error "`prerequisite_file'"
        exit 601
    }
}


// 12.2. Exportar la tabla econométrica principal ECI-DIVX

* Recuperar ambos modelos principales para que esttab utilice únicamente las
* especificaciones agregadas aprobadas.
estimates restore ECI_TWFE_MAIN
estimates restore DIVX_TWFE_MAIN

* Exportar una tabla LaTeX común. HHI aparece solo en ECI porque su inclusión
* en DIVX produciría una identidad contable.
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

* Exportar una tabla LaTeX que compare la transformación principal ln(1+x) con
* los controles OILPC, GASPC y COALPC expresados en niveles per cápita.
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

* Exportar la misma sensibilidad en texto plano para poder revisarla sin
* compilar LaTeX ni depender de software adicional.
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

* Combinar los coeficientes ECI y DIVX en un único archivo largo, conservando
* una columna que identifica el modelo de procedencia.
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
    assert r(N) == 33
    bysort model: generate int terms_in_model = _N
    assert terms_in_model == 17 if model == "ECI"
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
    quietly count
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
    assert r(N) == 16
    bysort model: assert _N == 8

    * Exportar el reporte conjunto de pruebas por canal y efectos temporales.
    export delimited using ///
        "$OUTPUT_FINAL/final_joint_tests.csv", ///
        replace datafmt
restore


// 12.4. Clasificar la evidencia sin convertir asociaciones en causalidad

* Abrir la base consolidada de coeficientes para asignar a cada término una
* categoría de lectura. Esta clasificación ordena la discusión, pero no altera
* coeficientes, errores estándar ni valores p.
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

    * Registrar la dirección de la asociación estimada para facilitar la
    * comparación de signos entre ECI y DIVX.
    generate str10 association_direction = ///
        cond(coefficient < 0, "Negativa", "Positiva")

    * Asignar inicialmente los regresores a la categoría de controles.
    generate str24 evidence_class = "Control"

    * Identificar la asociación agregada de RENTS como evidencia central.
    replace evidence_class = "Central" if term == "rents"

    * Identificar PEXP como evidencia comparativa central porque su signo
    * significativo cambia entre complejidad y diversificación.
    replace evidence_class = "Central comparativa" if term == "pexp"

    * Mantener la interacción y la desagregación per cápita como evidencia no
    * concluyente, dado que sus pruebas individuales y conjuntas no la respaldan.
    replace evidence_class = "No concluyente" ///
        if term == "c.rents#c.inst"
    replace evidence_class = "No concluyente" ///
        if inlist(term, ///
            "ln1p_oilpc", "ln1p_gaspc", "ln1p_coalpc")

    * Clasificar los resultados significativos restantes como complementarios,
    * porque no constituyen por sí solos la hipótesis central del TFM.
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

* Copiar al paquete final los efectos marginales numéricos sin modificar el
* archivo original de la sección 7.
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

* Copiar la sensibilidad de forma funcional de OILPC, GASPC y COALPC. El nombre
* evita confundirla con una modificación de RENTS o con una desagregación.
copy ///
    "$OUTPUT_STABILITY/per_capita_transformation_sensitivity.csv" ///
    "$OUTPUT_FINAL/final_per_capita_transformation_sensitivity.csv", ///
    replace

* Combinar las dos figuras marginales conservando escalas verticales propias,
* pues ECI y DIVX se expresan en magnitudes distintas.
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
    "6. HHI se excluye de DIVX porque DIVX = 1 - HHI." _n _n

* Cerrar el índice para asegurar que todo el contenido quede escrito en disco.
file close `results_index'


// 12.7. Crear el manifiesto y validar el paquete final

* Preparar un manifiesto legible por máquina con la finalidad de cada archivo.
tempname manifest_post
tempfile manifest_report
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
post `manifest_post' ///
    (2) ("Modelos principales") ///
    ("table_eci_divx_twfe.txt") ///
    ("Versión de texto plano de la tabla econométrica principal.")

* Registrar los archivos numéricos consolidados.
post `manifest_post' ///
    (3) ("Resultados numéricos") ///
    ("final_model_coefficients.csv") ///
    ("Coeficientes, errores, valores p e intervalos de ambos modelos.")
post `manifest_post' ///
    (4) ("Resultados numéricos") ///
    ("final_model_summaries.csv") ///
    ("Cobertura, ajuste y componentes de varianza de ECI y DIVX.")
post `manifest_post' ///
    (5) ("Resultados numéricos") ///
    ("final_joint_tests.csv") ///
    ("Pruebas conjuntas por canal, efectos temporales e igualdad de recursos.")
post `manifest_post' ///
    (6) ("Interpretación") ///
    ("evidence_classification.csv") ///
    ("Clasificación no causal de evidencia central, complementaria y no concluyente.")

* Registrar las seis familias de sensibilidad.
post `manifest_post' ///
    (7) ("Estabilidad") ///
    ("final_rents_marginal_effects_by_inst.csv") ///
    ("Efectos marginales de RENTS en percentiles institucionales.")
post `manifest_post' ///
    (8) ("Estabilidad") ///
    ("final_influential_observation_sensitivity.csv") ///
    ("Sensibilidad a observaciones potencialmente influyentes.")
post `manifest_post' ///
    (9) ("Estabilidad") ///
    ("final_leave_one_country_out_summary.csv") ///
    ("Resumen de exclusiones individuales de los 49 países.")
post `manifest_post' ///
    (10) ("Estabilidad") ///
    ("final_wild_cluster_bootstrap.csv") ///
    ("Contraste bootstrap de RENTS y RENTS x INST.")
post `manifest_post' ///
    (11) ("Estabilidad") ///
    ("final_resource_coefficient_equality.csv") ///
    ("Prueba de igualdad entre petróleo, gas y carbón.")
post `manifest_post' ///
    (12) ("Estabilidad") ///
    ("final_per_capita_transformation_sensitivity.csv") ///
    ("Comparación de ln(1+x) con controles per cápita en niveles.")

* Registrar las dos versiones de la tabla de sensibilidad de forma funcional.
post `manifest_post' ///
    (13) ("Tablas de sensibilidad") ///
    ("table_per_capita_transformation_sensitivity.tex") ///
    ("Tabla LaTeX de sensibilidad a la transformación per cápita.")
post `manifest_post' ///
    (14) ("Tablas de sensibilidad") ///
    ("table_per_capita_transformation_sensitivity.txt") ///
    ("Versión de texto de la sensibilidad a la transformación per cápita.")

* Registrar la figura comparada y el índice explicativo.
post `manifest_post' ///
    (15) ("Figuras") ///
    ("figure_rents_marginal_effects_eci_divx.pdf") ///
    ("Figura comparada ECI-DIVX en formato apto para LaTeX.")
post `manifest_post' ///
    (16) ("Figuras") ///
    ("figure_rents_marginal_effects_eci_divx.png") ///
    ("Figura comparada para inspección visual.")
post `manifest_post' ///
    (17) ("Documentación") ///
    ("RESULTS_INDEX.md") ///
    ("Índice, alcance y reglas de interpretación del paquete final.")

* Cerrar y exportar el manifiesto después de registrar sus diecisiete entradas.
postclose `manifest_post'
preserve
    use "`manifest_report'", clear
    sort order
    assert _N == 17
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
    table_per_capita_transformation_sensitivity.tex ///
    table_per_capita_transformation_sensitivity.txt ///
    figure_rents_marginal_effects_eci_divx.pdf ///
    figure_rents_marginal_effects_eci_divx.png ///
    RESULTS_INDEX.md ///
    results_manifest.csv

* Detener la ejecución si una salida final no fue creada correctamente.
foreach final_file of local final_required_files {
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
    assert _N == 33
restore

* Confirmar que la matriz final contiene las 16 pruebas conjuntas previstas.
preserve
    import delimited using ///
        "$OUTPUT_FINAL/final_joint_tests.csv", ///
        clear varnames(1)
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
