# CAPA: RAW
# VARIABLE: GOVCONS
# SALIDAS: data/raw/govcons/
# Proposito: preparar el indicador raw de consumo gubernamental GOVCONS.
# Entrada: panel WDI compartido y muestra DRES de referencia.
# Salidas: insumo raw en CSV y Stata, y diagnosticos de cobertura.

# Reunir las ubicaciones desde las cuales puede encontrarse el helper de rutas.
helper_path <- c(
  # Buscar desde el archivo activo cuando el script se ejecuta en RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)))), "project_paths.R")
  },
  # Buscar desde la raiz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Buscar desde scripts/data/raw/govcons/.
  file.path("..", "..", "..", "project_paths.R"),
  # Buscar desde scripts/.
  file.path("..", "project_paths.R"),
  # Buscar en el directorio de trabajo actual como ultima alternativa.
  "project_paths.R"
)

# Conservar la primera ubicacion candidata que exista realmente.
helper_path <- helper_path[file.exists(helper_path)][1]
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}

# Ejecutar el helper para habilitar la busqueda de la raiz del repositorio.
source(helper_path)
project_path <- find_project_path()

# Verificar que exista al menos una biblioteca capaz de escribir archivos Stata.
if (
  !requireNamespace("haven", quietly = TRUE) &&
    !requireNamespace("foreign", quietly = TRUE)
) {
  stop("Falta una biblioteca compatible con Stata: haven o foreign.")
}

# Construir las rutas de los insumos requeridos.
wdi_file <- file.path(
  project_path,
  "data",
  "raw",
  "world_bank_wdi",
  "wdi_thesis_inputs_1980_2022.csv"
)
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
if (!file.exists(wdi_file)) {
  stop("Primero ejecute scripts/data/raw/world_bank_wdi/wdi_thesis_inputs_raw.R.")
}
if (!file.exists(sample_file)) {
  stop("No se encontro data/processed/dres/dres_sample_20.csv.")
}

# Leer el panel WDI y la muestra DRES sin convertir textos en factores.
wdi_inputs <- read.csv(
  wdi_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
dres_sample <- read.csv(
  sample_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  fileEncoding = "UTF-8"
)

# Definir el indicador oficial y los identificadores que deben conservarse.
value_column <- "government_consumption_pct_gdp"
required_columns <- c(
  "country_iso3_code",
  "country",
  "year",
  value_column
)
missing_columns <- setdiff(required_columns, names(wdi_inputs))
if (length(missing_columns) > 0L) {
  stop("Faltan columnas WDI: ", paste(missing_columns, collapse = ", "))
}

# Validar que la muestra de referencia tenga exactamente 55 paises distintos.
if (
  nrow(dres_sample) != 55L ||
    anyDuplicated(dres_sample$country_iso3_code) > 0L
) {
  stop("La muestra DRES de referencia no contiene 55 paises unicos.")
}

# Conservar el indicador publicado sin renombrarlo como GOVCONS ni transformarlo.
govcons_raw <- wdi_inputs[, required_columns]
govcons_raw$country_iso3_code <- toupper(
  trimws(govcons_raw$country_iso3_code)
)
govcons_raw$year <- as.integer(govcons_raw$year)
govcons_raw <- govcons_raw[
  order(govcons_raw$country_iso3_code, govcons_raw$year),
]
row.names(govcons_raw) <- NULL

# Comprobar granularidad, identificadores, horizonte y valores admisibles.
if (anyDuplicated(govcons_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("El insumo raw de GOVCONS contiene llaves pais-anio duplicadas.")
}
if (any(!grepl("^[A-Z]{3}$", govcons_raw$country_iso3_code))) {
  stop("El insumo raw de GOVCONS contiene codigos de pais invalidos.")
}
if (any(!govcons_raw$year %in% 1980:2022)) {
  stop("El insumo raw de GOVCONS contiene anios por fuera de 1980-2022.")
}
observed_raw_values <- govcons_raw[[value_column]][
  !is.na(govcons_raw[[value_column]])
]
if (any(!is.finite(observed_raw_values))) {
  stop("El consumo gubernamental contiene valores no finitos.")
}
if (any(observed_raw_values < 0)) {
  stop("El consumo gubernamental contiene valores negativos.")
}

# Confirmar que los 55 paises DRES aparezcan en la cuadricula WDI compartida.
missing_sample_countries <- setdiff(
  dres_sample$country_iso3_code,
  govcons_raw$country_iso3_code
)
if (length(missing_sample_countries) > 0L) {
  stop(
    "Faltan paises DRES en el insumo WDI: ",
    paste(missing_sample_countries, collapse = ", ")
  )
}

# Conservar la cuadricula principal de 55 paises durante 1996-2022.
analysis_years <- 1996:2022
sample_grid <- govcons_raw[
  govcons_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    govcons_raw$year %in% analysis_years,
  ,
  drop = FALSE
]
expected_cells <- nrow(dres_sample) * length(analysis_years)
if (nrow(sample_grid) != expected_cells) {
  stop(
    "La cuadricula DRES deberia contener ", expected_cells,
    " filas y contiene ", nrow(sample_grid), "."
  )
}
if (anyDuplicated(sample_grid[c("country_iso3_code", "year")]) > 0L) {
  stop("La cuadricula DRES de GOVCONS contiene llaves duplicadas.")
}

# Construir el diagnostico de cobertura para cada pais.
country_coverage_rows <- lapply(
  sort(unique(dres_sample$country_iso3_code)),
  function(country_code) {
    country_data <- sample_grid[
      sample_grid$country_iso3_code == country_code,
      ,
      drop = FALSE
    ]
    observed <- !is.na(country_data[[value_column]])
    missing_years <- country_data$year[!observed]
    observed_values <- country_data[[value_column]][observed]
    data.frame(
      country_iso3_code = country_code,
      country = country_data$country[1],
      expected_years = length(analysis_years),
      observed_years = sum(observed),
      coverage_percent = 100 * sum(observed) / length(analysis_years),
      first_observed_year = if (any(observed)) {
        min(country_data$year[observed])
      } else {
        NA_integer_
      },
      last_observed_year = if (any(observed)) {
        max(country_data$year[observed])
      } else {
        NA_integer_
      },
      minimum_observed_value = if (any(observed)) {
        min(observed_values)
      } else {
        NA_real_
      },
      maximum_observed_value = if (any(observed)) {
        max(observed_values)
      } else {
        NA_real_
      },
      zero_observations = sum(observed_values == 0),
      missing_years = paste(missing_years, collapse = ";"),
      complete_1996_2022 = sum(observed) == length(analysis_years),
      stringsAsFactors = FALSE
    )
  }
)
country_coverage <- do.call(rbind, country_coverage_rows)
row.names(country_coverage) <- NULL

# Resumir cobertura y rango sin alterar los valores publicados.
observed_grid <- !is.na(sample_grid[[value_column]])
observed_values <- sample_grid[[value_column]][observed_grid]
coverage_summary <- data.frame(
  variable = value_column,
  source_code = "NE.CON.GOVT.ZS",
  expected_country_years_1996_2022 = expected_cells,
  observed_country_years_1996_2022 = sum(observed_grid),
  coverage_percent_1996_2022 = 100 * sum(observed_grid) / expected_cells,
  countries_with_any_data = sum(country_coverage$observed_years > 0L),
  countries_complete_1996_2022 = sum(country_coverage$complete_1996_2022),
  countries_incomplete_1996_2022 = sum(!country_coverage$complete_1996_2022),
  countries_without_data = sum(country_coverage$observed_years == 0L),
  first_observed_year = min(sample_grid$year[observed_grid]),
  last_observed_year = max(sample_grid$year[observed_grid]),
  minimum_observed_value = min(observed_values),
  median_observed_value = median(observed_values),
  maximum_observed_value = max(observed_values),
  zero_observations = sum(observed_values == 0),
  stringsAsFactors = FALSE
)

# Construir la carpeta y los nombres de las salidas.
output_path <- file.path(
  project_path,
  "data",
  "raw",
  "govcons",
  "world_bank_wdi"
)
dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
csv_file <- file.path(
  output_path,
  "govcons_wdi_input_1980_2022.csv"
)
dta_file <- file.path(
  output_path,
  "govcons_wdi_input_1980_2022.dta"
)
summary_file <- file.path(
  output_path,
  "govcons_raw_coverage_summary_dres20.csv"
)
country_coverage_file <- file.path(
  output_path,
  "govcons_raw_country_coverage_dres20.csv"
)

# Guardar el indicador sin transformaciones ni imputaciones.
write.csv(
  govcons_raw,
  csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
if (requireNamespace("haven", quietly = TRUE)) {
  haven::write_dta(govcons_raw, dta_file, version = 14)
} else {
  foreign::write.dta(govcons_raw, dta_file, version = 12)
}
write.csv(
  coverage_summary,
  summary_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
write.csv(
  country_coverage,
  country_coverage_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

message("Raw de GOVCONS terminado.")
message("Archivo CSV: ", csv_file)
print(coverage_summary)
