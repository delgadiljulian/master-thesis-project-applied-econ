# Preparar los insumos raw de innovación descargados del Banco Mundial.
#
# Entrada: panel WDI compartido y muestra DRES de referencia.
# Salidas: datos raw en CSV y Stata, y diagnóstico de cobertura de la muestra.

# Reunir las ubicaciones desde las cuales puede encontrarse el helper de rutas.
helper_path <- c(
  # Buscar desde el archivo activo cuando el script se ejecuta en RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path))), "project_paths.R")
  },
  # Buscar desde la raíz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Buscar desde scripts/data/innov/.
  file.path("..", "..", "project_paths.R"),
  # Buscar desde scripts/.
  file.path("..", "project_paths.R"),
  # Buscar en el directorio de trabajo actual como última alternativa.
  "project_paths.R"
)

# Conservar la primera ubicación candidata que exista realmente.
helper_path <- helper_path[file.exists(helper_path)][1]
# Detener el script si no fue posible encontrar el helper de rutas.
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}

# Ejecutar el helper para habilitar la búsqueda de la raíz del repositorio.
source(helper_path)
# Obtener la ruta absoluta del proyecto sin depender del directorio de RStudio.
project_path <- find_project_path()
# Verificar que haven esté instalado antes de intentar escribir archivos Stata.
if (!requireNamespace("haven", quietly = TRUE)) {
  stop("Falta el paquete haven. Instálelo con install.packages('haven').")
}

# Construir la ruta del panel compartido descargado directamente desde WDI.
wdi_file <- file.path(
  project_path,
  "data",
  "raw",
  "world_bank_wdi",
  "wdi_thesis_inputs_1980_2022.csv"
)
# Construir la ruta de la muestra DRES de referencia utilizada para diagnosticar cobertura.
sample_file <- file.path(project_path, "data", "processed", "dres", "dres_sample_20.csv")
# Detener el script si todavía no existe el panel compartido del Banco Mundial.
if (!file.exists(wdi_file)) {
  stop("Primero ejecute scripts/data/world_bank_wdi/wdi_thesis_inputs.R.")
}
# Detener el script si todavía no existe la muestra DRES de referencia.
if (!file.exists(sample_file)) {
  stop("No se encontró data/processed/dres/dres_sample_20.csv.")
}

# Leer el panel WDI sin convertir automáticamente los textos en factores.
wdi_inputs <- read.csv(
  wdi_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
# Leer la lista de países pertenecientes a la muestra DRES del 20 por ciento.
dres_sample <- read.csv(
  sample_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  fileEncoding = "UTF-8"
)

# Definir las columnas necesarias para construir INNOV y sus pruebas de robustez.
required_columns <- c(
  "country_iso3_code",
  "country",
  "year",
  "scientific_technical_journal_articles",
  "resident_patent_applications",
  "rd_expenditure_pct_gdp",
  "population_total"
)
# Identificar si alguna columna requerida falta por un cambio en el descargador.
missing_columns <- setdiff(required_columns, names(wdi_inputs))
# Detener el script cuando la estructura de entrada no coincide con la esperada.
if (length(missing_columns) > 0L) {
  stop("Faltan columnas WDI: ", paste(missing_columns, collapse = ", "))
}

# Conservar solamente identificadores e insumos de innovación sin transformarlos.
innov_raw <- wdi_inputs[, required_columns]
# Acortar los nombres extensos para que también sean válidos dentro de Stata.
names(innov_raw)[names(innov_raw) == "scientific_technical_journal_articles"] <- "scientific_articles"
# Adoptar un nombre breve y explícito para las solicitudes de patentes de residentes.
names(innov_raw)[names(innov_raw) == "resident_patent_applications"] <- "resident_patents"
# Convertir el año a entero para preservar una llave país-año consistente.
innov_raw$year <- as.integer(innov_raw$year)
# Ordenar las observaciones por código de país y año.
innov_raw <- innov_raw[order(innov_raw$country_iso3_code, innov_raw$year), ]
# Eliminar los números de fila heredados de la tabla de entrada.
row.names(innov_raw) <- NULL

# Detener el script si aparece más de una observación para un mismo país y año.
if (anyDuplicated(innov_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("Los insumos raw de INNOV contienen llaves país-año duplicadas.")
}
# Detener el script si existen códigos de país vacíos o con formato diferente de ISO3.
if (any(!grepl("^[A-Z]{3}$", innov_raw$country_iso3_code))) {
  stop("Los insumos raw de INNOV contienen códigos de país inválidos.")
}
# Detener el script si los conteos de artículos contienen valores negativos.
if (any(innov_raw$scientific_articles < 0, na.rm = TRUE)) {
  stop("La serie de artículos científicos contiene valores negativos.")
}
# Detener el script si los conteos de patentes contienen valores negativos.
if (any(innov_raw$resident_patents < 0, na.rm = TRUE)) {
  stop("La serie de patentes contiene valores negativos.")
}
# Detener el script si la población observada contiene valores no positivos.
if (any(innov_raw$population_total <= 0, na.rm = TRUE)) {
  stop("La serie de población contiene valores no positivos.")
}

# Definir los años que integrarán el panel econométrico principal.
analysis_years <- 1996:2022
# Conservar únicamente la cuadrícula correspondiente a los 55 países DRES.
sample_grid <- innov_raw[
  innov_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    innov_raw$year %in% analysis_years,
  ,
  drop = FALSE
]
# Calcular el número de celdas esperado en una cuadrícula país-año completa.
expected_cells <- nrow(dres_sample) * length(analysis_years)
# Definir las series que serán evaluadas en el diagnóstico de cobertura.
coverage_variables <- c(
  "scientific_articles",
  "resident_patents",
  "rd_expenditure_pct_gdp"
)
# Definir el papel econométrico previsto para cada serie evaluada.
coverage_roles <- c("principal", "robustez", "alternativa_no_prioritaria")
# Registrar los códigos oficiales WDI que permiten rastrear cada indicador.
coverage_codes <- c("IP.JRN.ARTC.SC", "IP.PAT.RESD", "GB.XPD.RSDV.GD.ZS")

# Construir una fila de cobertura para cada indicador de innovación.
coverage_rows <- lapply(seq_along(coverage_variables), function(index) {
  # Recuperar el nombre de la columna evaluada en esta iteración.
  variable_name <- coverage_variables[index]
  # Identificar las observaciones no faltantes de la serie.
  observed <- !is.na(sample_grid[[variable_name]])
  # Contar los años observados para cada país de la muestra.
  country_counts <- tapply(observed, sample_grid$country_iso3_code, sum)
  # Completar con cero los países que no aparezcan en el resultado de tapply.
  all_country_counts <- setNames(integer(nrow(dres_sample)), dres_sample$country_iso3_code)
  # Incorporar los conteos calculados en los códigos correspondientes.
  all_country_counts[names(country_counts)] <- as.integer(country_counts)
  # Devolver un resumen compacto y legible de cobertura.
  data.frame(
    variable = variable_name,
    role = coverage_roles[index],
    source_code = coverage_codes[index],
    expected_country_years = expected_cells,
    observed_country_years = sum(observed),
    coverage_percent = 100 * sum(observed) / expected_cells,
    countries_with_any_data = sum(all_country_counts > 0L),
    countries_with_complete_data = sum(all_country_counts == length(analysis_years)),
    countries_without_data = sum(all_country_counts == 0L),
    stringsAsFactors = FALSE
  )
})
# Unir los resúmenes individuales en una sola tabla de diagnóstico.
coverage_summary <- do.call(rbind, coverage_rows)
# Eliminar los números de fila generados al apilar las tablas.
row.names(coverage_summary) <- NULL

# Construir la carpeta específica donde se guardarán los insumos raw de INNOV.
output_path <- file.path(project_path, "data", "raw", "innov", "world_bank_wdi")
# Crear la carpeta de salida y sus directorios padres si todavía no existen.
dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
# Construir el nombre del archivo raw en formato CSV.
csv_file <- file.path(output_path, "innov_wdi_inputs_1980_2022.csv")
# Construir el nombre equivalente para Stata.
dta_file <- file.path(output_path, "innov_wdi_inputs_1980_2022.dta")
# Construir la ubicación del diagnóstico de cobertura sobre la muestra DRES.
coverage_file <- file.path(output_path, "innov_raw_coverage_dres20.csv")

# Guardar los valores originales en CSV sin aplicar tasas per cápita ni logaritmos.
write.csv(
  innov_raw,
  csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar el mismo contenido en un archivo compatible con Stata.
haven::write_dta(innov_raw, dta_file, version = 14)
# Guardar el diagnóstico para documentar la disponibilidad de cada alternativa.
write.csv(
  coverage_summary,
  coverage_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Informar que la preparación de los insumos raw terminó correctamente.
message("Raw de INNOV terminado.")
# Mostrar la ubicación del archivo principal para facilitar su revisión.
message("Archivo CSV: ", csv_file)
# Mostrar el diagnóstico de cobertura en la consola.
print(coverage_summary)
