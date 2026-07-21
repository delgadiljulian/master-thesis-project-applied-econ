# Preparar el Índice de Complejidad Económica para la muestra principal DRES.
#
# Entradas: datos ECI del Atlas y lista de 55 países seleccionados con DRES >= 20 %.
# Salidas: panel ECI 1996-2022 en CSV y Stata, cobertura por país y validación general.

# Reunir las ubicaciones desde las cuales puede encontrarse el helper de rutas del proyecto.
helper_path <- c(
  # Buscar el helper desde la ubicación del archivo activo cuando se usa RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path))), "project_paths.R")
  },
  # Buscar el helper cuando la consola está ubicada en la raíz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Buscar el helper cuando la consola está ubicada en scripts/data/eci/.
  file.path("..", "..", "project_paths.R"),
  # Buscar el helper cuando la consola está ubicada en scripts/.
  file.path("..", "project_paths.R"),
  # Buscar el helper en el directorio de trabajo actual como última alternativa.
  "project_paths.R"
)

# Conservar la primera ruta candidata que exista realmente en el equipo.
helper_path <- helper_path[file.exists(helper_path)][1]
# Detener el script si no fue posible localizar el helper de rutas.
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}

# Ejecutar el helper para habilitar la función que encuentra la raíz del repositorio.
source(helper_path)
# Obtener la ruta absoluta del proyecto sin depender del directorio abierto en RStudio.
project_path <- find_project_path()

# Definir el primer año del periodo principal de estimación de la tesis.
start_year <- 1996L
# Definir el último año del periodo principal de estimación de la tesis.
end_year <- 2022L
# Construir la secuencia completa de años que debe contener cada país.
analysis_years <- start_year:end_year
# Registrar el tamaño validado de la muestra principal seleccionada mediante DRES.
expected_country_count <- 55L
# Calcular el número de observaciones esperado en la cuadrícula completa país-año.
expected_row_count <- expected_country_count * length(analysis_years)

# Localizar el archivo bruto que contiene las series ECI publicadas por el Atlas.
raw_eci_file <- file.path(
  project_path,
  "data",
  "raw",
  "eci",
  "atlas",
  "growth_proj_eci_rankings.csv"
)
# Localizar la lista oficial de países de la muestra DRES de referencia.
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
# Construir la carpeta destinada a los resultados procesados de ECI.
processed_path <- file.path(project_path, "data", "processed", "eci", "atlas")

# Reunir los insumos indispensables para comprobarlos antes de procesar los datos.
required_files <- c(raw_eci_file, sample_file)
# Identificar cualquier insumo requerido que no exista en el repositorio.
missing_files <- required_files[!file.exists(required_files)]
# Interrumpir la ejecución si falta un archivo necesario para reproducir el panel.
if (length(missing_files) > 0L) {
  stop("Faltan archivos requeridos: ", paste(missing_files, collapse = ", "))
}
# Interrumpir la ejecución si R no dispone del paquete que permite escribir archivos Stata.
if (!requireNamespace("foreign", quietly = TRUE)) {
  stop("Falta el paquete de R 'foreign', requerido para crear la salida .dta.")
}

# Crear la carpeta de resultados y sus directorios padres si todavía no existen.
dir.create(processed_path, recursive = TRUE, showWarnings = FALSE)
# Construir la ruta de la versión CSV del panel ECI.
panel_csv_file <- file.path(processed_path, "eci_data.csv")
# Construir la ruta de la versión Stata del mismo panel ECI.
panel_dta_file <- file.path(processed_path, "eci_data.dta")
# Construir la ruta del diagnóstico detallado de cobertura por país.
coverage_file <- file.path(processed_path, "eci_country_coverage_1996_2022.csv")
# Construir la ruta del resumen general de validación.
validation_file <- file.path(processed_path, "eci_validation_summary.csv")
# Reunir todas las salidas oficiales que el script reemplazará al terminar.
official_output_files <- c(panel_csv_file, panel_dta_file, coverage_file, validation_file)

# Comprobar antes del cálculo que ningún resultado existente esté bloqueado por otro programa.
for (output_file in official_output_files[file.exists(official_output_files)]) {
  # Intentar abrir y cerrar el archivo sin escribir contenido nuevo.
  output_connection <- try(file(output_file, open = "ab"), silent = TRUE)
  # Detener la ejecución antes de producir salidas parciales si un archivo está bloqueado.
  if (inherits(output_connection, "try-error")) {
    stop("Cierre el archivo antes de ejecutar el script: ", output_file)
  }
  # Cerrar inmediatamente la conexión utilizada para comprobar disponibilidad.
  close(output_connection)
}

# Leer la muestra DRES como texto para conservar exactamente los códigos de país.
dres_sample <- read.csv(
  sample_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
# Definir las columnas necesarias para identificar cada país seleccionado.
required_sample_columns <- c("country_iso3_code", "country")
# Identificar columnas ausentes por un posible cambio en la salida de DRES.
missing_sample_columns <- setdiff(required_sample_columns, names(dres_sample))
# Detener el script si la muestra no conserva la estructura esperada.
if (length(missing_sample_columns) > 0L) {
  stop("Faltan columnas en la muestra DRES: ", paste(missing_sample_columns, collapse = ", "))
}
# Estandarizar los códigos ISO3 en mayúsculas y sin espacios laterales.
dres_sample$country_iso3_code <- toupper(trimws(dres_sample$country_iso3_code))
# Detener el script si algún país carece de código ISO3 o nombre legible.
if (any(!nzchar(dres_sample$country_iso3_code)) || any(!nzchar(dres_sample$country))) {
  stop("La muestra DRES contiene códigos o nombres de país vacíos.")
}
# Detener el script si un mismo código de país aparece más de una vez.
if (anyDuplicated(dres_sample$country_iso3_code) > 0L) {
  stop("La muestra DRES contiene códigos de país duplicados.")
}
# Detener el script si la muestra principal cambió de tamaño sin revisión previa.
if (nrow(dres_sample) != expected_country_count) {
  stop(
    "La muestra DRES principal cambió. Se esperaban ", expected_country_count,
    " países y se encontraron ", nrow(dres_sample), "."
  )
}
# Conservar únicamente la identificación necesaria para construir el panel ECI.
dres_sample <- dres_sample[, required_sample_columns]
# Ordenar la muestra por código para que las salidas sean deterministas.
dres_sample <- dres_sample[order(dres_sample$country_iso3_code), ]
# Eliminar números de fila heredados después del ordenamiento.
row.names(dres_sample) <- NULL

# Leer el archivo original del Atlas sin modificar los nombres de sus columnas.
raw_eci <- read.csv(
  raw_eci_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  fileEncoding = "UTF-8"
)
# Definir las columnas del Atlas que se conservarán para análisis y trazabilidad.
required_eci_columns <- c(
  "country_id",
  "country_iso3_code",
  "year",
  "growth_proj",
  "in_rankings",
  "eci_sitc",
  "eci_rank_sitc",
  "eci_hs92",
  "eci_rank_hs92",
  "eci_hs12",
  "eci_rank_hs12"
)
# Identificar columnas ausentes por un posible cambio en la descarga del Atlas.
missing_eci_columns <- setdiff(required_eci_columns, names(raw_eci))
# Detener el script si el archivo bruto no contiene la estructura esperada.
if (length(missing_eci_columns) > 0L) {
  stop("Faltan columnas en los datos ECI: ", paste(missing_eci_columns, collapse = ", "))
}
# Conservar únicamente las columnas necesarias para el panel y sus verificaciones.
raw_eci <- raw_eci[, required_eci_columns]
# Estandarizar los códigos ISO3 del Atlas en mayúsculas y sin espacios laterales.
raw_eci$country_iso3_code <- toupper(trimws(raw_eci$country_iso3_code))
# Convertir el año a número entero para aplicar correctamente el filtro temporal.
raw_eci$year <- as.integer(raw_eci$year)
# Detener el script si existen filas sin código de país o sin año identificable.
if (any(!nzchar(raw_eci$country_iso3_code)) || any(is.na(raw_eci$year))) {
  stop("Los datos ECI contienen códigos de país vacíos o años no válidos.")
}
# Detener el script si el Atlas contiene más de una fila para el mismo país y año.
if (anyDuplicated(raw_eci[c("country_iso3_code", "year")]) > 0L) {
  stop("Los datos ECI contienen llaves país-año duplicadas.")
}

# Definir las columnas del Atlas que deben interpretarse como valores numéricos.
numeric_eci_columns <- c(
  "country_id",
  "growth_proj",
  "eci_sitc",
  "eci_rank_sitc",
  "eci_hs92",
  "eci_rank_hs92",
  "eci_hs12",
  "eci_rank_hs12"
)
# Convertir cada indicador y ranking a número, conservando como faltantes las celdas vacías.
for (column_name in numeric_eci_columns) {
  raw_eci[[column_name]] <- as.numeric(raw_eci[[column_name]])
}
# Normalizar como texto la marca original para poder validar sus categorías.
ranking_text <- tolower(trimws(as.character(raw_eci$in_rankings)))
# Conservar como faltantes las celdas que el archivo original no reporta.
ranking_text[is.na(raw_eci$in_rankings)] <- NA_character_
# Identificar cualquier categoría distinta de verdadero, falso, uno o cero.
invalid_ranking_values <- !is.na(ranking_text) & !ranking_text %in% c("true", "false", "1", "0")
# Detener el script si una marca no vacía de rankings no puede convertirse a 1 o 0.
if (any(invalid_ranking_values)) {
  stop("La columna in_rankings contiene valores que no pudieron interpretarse.")
}
# Convertir la marca validada de inclusión en rankings a 1, 0 o faltante para Stata.
raw_eci$in_rankings <- ifelse(
  is.na(ranking_text),
  NA_integer_,
  ifelse(
    ranking_text %in% c("true", "1"),
    1L,
    0L
  )
)

# Conservar solo los años del periodo econométrico principal.
raw_eci <- raw_eci[raw_eci$year %in% analysis_years, ]
# Conservar solo los países identificados por la muestra principal DRES.
raw_eci <- raw_eci[raw_eci$country_iso3_code %in% dres_sample$country_iso3_code, ]
# Ordenar los registros disponibles antes de integrarlos con la cuadrícula completa.
raw_eci <- raw_eci[order(raw_eci$country_iso3_code, raw_eci$year), ]
# Eliminar números de fila heredados después de los filtros.
row.names(raw_eci) <- NULL

# Crear todas las combinaciones entre los 55 países y los años 1996-2022.
panel_grid <- merge(
  dres_sample,
  data.frame(year = analysis_years),
  by = NULL,
  sort = FALSE
)
# Integrar a la cuadrícula los valores ECI disponibles sin eliminar ningún país-año.
eci_panel <- merge(
  panel_grid,
  raw_eci,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
# Ordenar el panel por país y año para facilitar su lectura y uso econométrico.
eci_panel <- eci_panel[order(eci_panel$country_iso3_code, eci_panel$year), ]
# Organizar las columnas comenzando por la identificación del país y del año.
eci_panel <- eci_panel[, c(
  "country_id",
  "country_iso3_code",
  "country",
  "year",
  "growth_proj",
  "in_rankings",
  "eci_sitc",
  "eci_rank_sitc",
  "eci_hs92",
  "eci_rank_hs92",
  "eci_hs12",
  "eci_rank_hs12"
)]
# Eliminar números de fila heredados después del ordenamiento final.
row.names(eci_panel) <- NULL

# Detener el script si la cuadrícula no contiene exactamente 55 países por 27 años.
if (nrow(eci_panel) != expected_row_count) {
  stop(
    "El panel ECI debería contener ", expected_row_count,
    " filas y contiene ", nrow(eci_panel), "."
  )
}
# Detener el script si se perdió o se agregó algún país durante la integración.
if (length(unique(eci_panel$country_iso3_code)) != expected_country_count) {
  stop("El panel ECI no conserva exactamente los 55 países de la muestra DRES.")
}
# Detener el script si la salida contiene llaves país-año duplicadas.
if (anyDuplicated(eci_panel[c("country_iso3_code", "year")]) > 0L) {
  stop("El panel ECI contiene llaves país-año duplicadas.")
}
# Detener el script si se generó un año por fuera del periodo definido.
if (!all(eci_panel$year %in% analysis_years)) {
  stop("El panel ECI contiene años por fuera de 1996-2022.")
}

# Calcular la cobertura de ECI HS92 para cada país de la muestra principal.
coverage_by_country <- do.call(
  rbind,
  lapply(split(eci_panel, eci_panel$country_iso3_code), function(country_data) {
    # Identificar los años que sí tienen un valor ECI HS92 observado.
    observed_years <- country_data$year[!is.na(country_data$eci_hs92)]
    # Contar los años disponibles dentro de los 27 años esperados.
    available_years <- length(observed_years)
    # Devolver una fila de diagnóstico para el país evaluado.
    data.frame(
      country_iso3_code = country_data$country_iso3_code[1],
      country = country_data$country[1],
      expected_years = length(analysis_years),
      available_eci_hs92_years = available_years,
      missing_eci_hs92_years = length(analysis_years) - available_years,
      first_available_year = if (available_years > 0L) min(observed_years) else NA_integer_,
      last_available_year = if (available_years > 0L) max(observed_years) else NA_integer_,
      coverage_share = available_years / length(analysis_years),
      complete_1996_2022 = as.integer(available_years == length(analysis_years)),
      stringsAsFactors = FALSE
    )
  })
)
# Ordenar el diagnóstico desde los países con menor cobertura hacia los más completos.
coverage_by_country <- coverage_by_country[
  order(coverage_by_country$available_eci_hs92_years, coverage_by_country$country_iso3_code),
]
# Eliminar números de fila heredados después del ordenamiento del diagnóstico.
row.names(coverage_by_country) <- NULL

# Contar cuántos países tienen al menos una observación de ECI HS92.
countries_with_eci <- sum(coverage_by_country$available_eci_hs92_years > 0L)
# Contar cuántos países tienen los 27 años completos de ECI HS92.
countries_complete <- sum(coverage_by_country$complete_1996_2022 == 1L)
# Contar cuántos países tienen una serie parcial, pero no completamente vacía.
countries_partial <- sum(
  coverage_by_country$available_eci_hs92_years > 0L &
    coverage_by_country$complete_1996_2022 == 0L
)
# Contar cuántos países no tienen ninguna observación ECI HS92.
countries_without_eci <- sum(coverage_by_country$available_eci_hs92_years == 0L)
# Contar el total de observaciones ECI HS92 disponibles en el panel.
available_country_years <- sum(!is.na(eci_panel$eci_hs92))
# Contar el total de observaciones ECI HS92 faltantes en la cuadrícula completa.
missing_country_years <- sum(is.na(eci_panel$eci_hs92))

# Construir una tabla sencilla con las verificaciones principales de la salida.
validation_summary <- data.frame(
  metric = c(
    "start_year",
    "end_year",
    "dres_sample_countries",
    "countries_with_eci_hs92",
    "countries_complete_1996_2022",
    "countries_with_partial_coverage",
    "countries_without_eci_hs92",
    "expected_country_years",
    "available_eci_hs92_country_years",
    "missing_eci_hs92_country_years",
    "duplicate_country_year_keys"
  ),
  value = c(
    start_year,
    end_year,
    expected_country_count,
    countries_with_eci,
    countries_complete,
    countries_partial,
    countries_without_eci,
    expected_row_count,
    available_country_years,
    missing_country_years,
    anyDuplicated(eci_panel[c("country_iso3_code", "year")])
  ),
  stringsAsFactors = FALSE
)

# Guardar el panel en CSV con celdas vacías para representar valores faltantes.
write.csv(
  eci_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar exactamente el mismo panel en formato Stata para el trabajo econométrico.
foreign::write.dta(
  eci_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
# Guardar la cobertura por país para documentar la muestra efectiva del modelo ECI.
write.csv(
  coverage_by_country,
  coverage_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar el resumen de validación para revisar rápidamente dimensiones y faltantes.
write.csv(
  validation_summary,
  validation_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Informar en consola dónde quedaron almacenadas las dos versiones del panel.
message("Panel ECI CSV guardado en: ", panel_csv_file)
message("Panel ECI Stata guardado en: ", panel_dta_file)
# Informar el tamaño de la cuadrícula construida para facilitar la verificación manual.
message("Panel construido: ", expected_country_count, " países y ", expected_row_count, " país-años.")
# Informar la cobertura efectiva de la serie principal ECI HS92.
message(
  "Cobertura ECI HS92: ", countries_with_eci, " países con datos, ",
  countries_complete, " completos, ", countries_partial, " parcial y ",
  countries_without_eci, " sin observaciones."
)
