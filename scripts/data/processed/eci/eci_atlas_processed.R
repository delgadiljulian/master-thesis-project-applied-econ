# CAPA: PROCESSED
# VARIABLE: ECI
# ENTRADAS: data/raw/eci/atlas/ y data/processed/dres/
# SALIDAS: data/processed/eci/atlas/
#
# Construye la única serie ECI utilizada por la tesis a partir del campo
# countryYear.eci de la API oficial del Atlas of Economic Complexity.

# Ejecutar la siguiente instrucción del bloque
helper_path <- c(
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)))), "project_paths.R")
  },
  file.path("scripts", "project_paths.R"),
  file.path("..", "..", "..", "project_paths.R"),
  file.path("..", "project_paths.R"),
  "project_paths.R"
)
helper_path <- helper_path[file.exists(helper_path)][1]
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}
source(helper_path)
project_path <- find_project_path()

# Ejecutar la siguiente instrucción del bloque
start_year <- 1996L
end_year <- 2021L
analysis_years <- start_year:end_year
expected_country_count <- 55L
expected_year_count <- length(analysis_years)
expected_row_count <- expected_country_count * expected_year_count

# Ejecutar la siguiente instrucción del bloque
raw_eci_file <- file.path(
  project_path,
  "data",
  "raw",
  "eci",
  "atlas",
  "atlas_eci_country_year_1995_2022.csv"
)
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
processed_path <- file.path(
  project_path,
  "data",
  "processed",
  "eci",
  "atlas"
)

# Ejecutar la siguiente instrucción del bloque
required_files <- c(raw_eci_file, sample_file)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0L) {
  stop("Faltan archivos requeridos: ", paste(missing_files, collapse = ", "))
}
if (!requireNamespace("foreign", quietly = TRUE)) {
  stop("Falta el paquete de R 'foreign', requerido para crear la salida .dta.")
}

# Ejecutar la siguiente instrucción del bloque
dir.create(processed_path, recursive = TRUE, showWarnings = FALSE)
panel_csv_file <- file.path(processed_path, "eci_data.csv")
panel_dta_file <- file.path(processed_path, "eci_data.dta")
coverage_file <- file.path(
  processed_path,
  "eci_country_coverage_1996_2021.csv"
)
validation_file <- file.path(
  processed_path,
  "eci_validation_summary.csv"
)
official_output_files <- c(
  panel_csv_file,
  panel_dta_file,
  coverage_file,
  validation_file
)

# Iterar sobre los elementos del conjunto
for (output_file in official_output_files[file.exists(official_output_files)]) {
  output_connection <- try(file(output_file, open = "ab"), silent = TRUE)
  if (inherits(output_connection, "try-error")) {
    stop("Cierre el archivo antes de ejecutar el script: ", output_file)
  }
  close(output_connection)
}

# Cargar el archivo de datos
dres_sample <- read.csv(
  sample_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
required_sample_columns <- c("country_iso3_code", "country")
missing_sample_columns <- setdiff(required_sample_columns, names(dres_sample))
if (length(missing_sample_columns) > 0L) {
  stop(
    "Faltan columnas en la muestra DRES: ",
    paste(missing_sample_columns, collapse = ", ")
  )
}
dres_sample <- dres_sample[, required_sample_columns]
dres_sample$country_iso3_code <- toupper(
  trimws(dres_sample$country_iso3_code)
)
if (
  any(!nzchar(dres_sample$country_iso3_code)) ||
    any(!nzchar(dres_sample$country))
) {
  stop("La muestra DRES contiene códigos o nombres de país vacíos.")
}
if (anyDuplicated(dres_sample$country_iso3_code) > 0L) {
  stop("La muestra DRES contiene códigos de país duplicados.")
}
if (nrow(dres_sample) != expected_country_count) {
  stop(
    "La muestra DRES principal cambió. Se esperaban ",
    expected_country_count,
    " países y se encontraron ",
    nrow(dres_sample),
    "."
  )
}
dres_sample <- dres_sample[order(dres_sample$country_iso3_code), ]
row.names(dres_sample) <- NULL

# Cargar el archivo de datos
raw_eci <- read.csv(
  raw_eci_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A", "null"),
  fileEncoding = "UTF-8"
)
required_eci_columns <- c(
  "atlas_country_id",
  "country_iso3_code",
  "country_atlas",
  "year",
  "eci"
)
missing_eci_columns <- setdiff(required_eci_columns, names(raw_eci))
if (length(missing_eci_columns) > 0L) {
  stop(
    "Faltan columnas en la captura ECI de la API: ",
    paste(missing_eci_columns, collapse = ", ")
  )
}
raw_eci <- raw_eci[, required_eci_columns]
raw_eci$country_iso3_code <- toupper(trimws(raw_eci$country_iso3_code))
raw_eci$year <- as.integer(raw_eci$year)
raw_eci$eci <- as.numeric(raw_eci$eci)
if (
  any(!nzchar(raw_eci$country_iso3_code)) ||
    any(is.na(raw_eci$year))
) {
  stop("La captura ECI contiene códigos vacíos o años no válidos.")
}
if (anyDuplicated(raw_eci[c("country_iso3_code", "year")]) > 0L) {
  stop("La captura ECI contiene llaves país-año duplicadas.")
}
if (any(is.infinite(raw_eci$eci), na.rm = TRUE)) {
  stop("La captura ECI contiene valores infinitos.")
}

# Ejecutar la siguiente instrucción del bloque
raw_eci <- raw_eci[
  raw_eci$country_iso3_code %in% dres_sample$country_iso3_code &
    raw_eci$year %in% analysis_years,
]
raw_eci <- raw_eci[
  order(raw_eci$country_iso3_code, raw_eci$year),
]
row.names(raw_eci) <- NULL

# Ejecutar la siguiente instrucción del bloque
sample_without_api <- setdiff(
  dres_sample$country_iso3_code,
  unique(raw_eci$country_iso3_code)
)
if (length(sample_without_api) > 0L) {
  stop(
    "La API no devolvió países de la muestra DRES: ",
    paste(sample_without_api, collapse = ", ")
  )
}

# Ejecutar la siguiente instrucción del bloque
panel_grid <- merge(
  dres_sample,
  data.frame(year = analysis_years),
  by = NULL,
  sort = FALSE
)
eci_panel <- merge(
  panel_grid,
  raw_eci[, c("country_iso3_code", "year", "eci")],
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
eci_panel <- eci_panel[
  order(eci_panel$country_iso3_code, eci_panel$year),
  c("country_iso3_code", "country", "year", "eci")
]
row.names(eci_panel) <- NULL

# Evaluar condición de control de flujo
if (nrow(eci_panel) != expected_row_count) {
  stop(
    "El panel ECI debería contener ",
    expected_row_count,
    " filas y contiene ",
    nrow(eci_panel),
    "."
  )
}
if (length(unique(eci_panel$country_iso3_code)) != expected_country_count) {
  stop("El panel ECI no conserva exactamente los 55 países DRES.")
}
if (anyDuplicated(eci_panel[c("country_iso3_code", "year")]) > 0L) {
  stop("El panel ECI contiene llaves país-año duplicadas.")
}
if (any(is.na(eci_panel$eci))) {
  stop(
    "La serie ECI de la API no cubre completamente los 55 países en 1996-2021."
  )
}
if (any(is.infinite(eci_panel$eci))) {
  stop("El panel ECI contiene valores infinitos.")
}

# Ejecutar la siguiente instrucción del bloque
coverage_by_country <- do.call(
  rbind,
  lapply(
    split(eci_panel, eci_panel$country_iso3_code),
    function(country_data) {
      observed_years <- country_data$year[!is.na(country_data$eci)]
      available_years <- length(observed_years)
      data.frame(
        country_iso3_code = country_data$country_iso3_code[1],
        country = country_data$country[1],
        expected_years = expected_year_count,
        available_eci_years = available_years,
        missing_eci_years = expected_year_count - available_years,
        first_available_year = min(observed_years),
        last_available_year = max(observed_years),
        coverage_share = available_years / expected_year_count,
        complete_1996_2021 = as.integer(
          available_years == expected_year_count
        ),
        stringsAsFactors = FALSE
      )
    }
  )
)
coverage_by_country <- coverage_by_country[
  order(coverage_by_country$country_iso3_code),
]
row.names(coverage_by_country) <- NULL

# Ejecutar la siguiente instrucción del bloque
validation_summary <- data.frame(
  metric = c(
    "start_year",
    "end_year",
    "dres_sample_countries",
    "expected_country_years",
    "actual_country_years",
    "available_eci_country_years",
    "missing_eci_country_years",
    "eci_coverage_percent",
    "countries_with_any_eci",
    "countries_complete_1996_2021",
    "countries_with_partial_eci",
    "countries_without_eci",
    "duplicate_country_year_keys",
    "nonfinite_eci_count"
  ),
  value = c(
    start_year,
    end_year,
    expected_country_count,
    expected_row_count,
    nrow(eci_panel),
    sum(!is.na(eci_panel$eci)),
    sum(is.na(eci_panel$eci)),
    100 * mean(!is.na(eci_panel$eci)),
    sum(coverage_by_country$available_eci_years > 0L),
    sum(coverage_by_country$complete_1996_2021 == 1L),
    sum(
      coverage_by_country$available_eci_years > 0L &
        coverage_by_country$complete_1996_2021 == 0L
    ),
    sum(coverage_by_country$available_eci_years == 0L),
    anyDuplicated(eci_panel[c("country_iso3_code", "year")]),
    sum(is.infinite(eci_panel$eci))
  ),
  stringsAsFactors = FALSE
)

# Guardar o exportar los resultados
write.csv(
  eci_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  eci_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
write.csv(
  coverage_by_country,
  coverage_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
write.csv(
  validation_summary,
  validation_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Cargar el archivo de datos
csv_check <- read.csv(
  panel_csv_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
dta_check <- foreign::read.dta(
  panel_dta_file,
  convert.dates = FALSE,
  convert.factors = FALSE,
  convert.underscore = FALSE,
  warn.missing.labels = TRUE
)
if (
  !identical(names(csv_check), names(dta_check)) ||
    nrow(csv_check) != nrow(dta_check)
) {
  stop("Las salidas CSV y Stata de ECI no conservan la misma estructura.")
}
if (
  !identical(
    as.character(csv_check$country_iso3_code),
    as.character(dta_check$country_iso3_code)
  ) ||
    !identical(as.integer(csv_check$year), as.integer(dta_check$year))
) {
  stop("Las salidas CSV y Stata de ECI no conservan las mismas llaves.")
}
if (
  !identical(is.na(csv_check$eci), is.na(dta_check$eci)) ||
    max(abs(csv_check$eci - dta_check$eci)) > 1e-10
) {
  stop("Las salidas CSV y Stata de ECI difieren numéricamente.")
}

# Ejecutar la siguiente instrucción del bloque
message("Panel ECI CSV guardado en: ", panel_csv_file)
message("Panel ECI Stata guardado en: ", panel_dta_file)
message(
  "Cobertura ECI validada: ",
  sum(!is.na(eci_panel$eci)),
  " de ",
  expected_row_count,
  " país-años, 55 países completos y cero faltantes."
)
