# CAPA: RAW
# VARIABLE: NET
# SALIDAS: data/raw/net/
# Proposito: preparar el indicador raw de conectividad digital NET.
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
  # Buscar desde scripts/data/raw/net/.
  file.path("..", "..", "..", "project_paths.R"),
  # Buscar desde scripts/.
  file.path("..", "project_paths.R"),
  # Buscar en el directorio de trabajo actual como ultima alternativa.
  "project_paths.R"
)

# Conservar la primera ubicacion candidata que exista realmente.
helper_path <- helper_path[file.exists(helper_path)][1]
# Detener el script si no fue posible encontrar el helper de rutas.
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}

# Ejecutar el helper para habilitar la busqueda de la raiz del repositorio.
source(helper_path)
# Obtener la ruta absoluta del proyecto sin depender del directorio de RStudio.
project_path <- find_project_path()
# Verificar que exista al menos una biblioteca capaz de escribir archivos Stata.
if (
  !requireNamespace("haven", quietly = TRUE) &&
    !requireNamespace("foreign", quietly = TRUE)
) {
  stop("Falta una biblioteca compatible con Stata: haven o foreign.")
}

# Construir las rutas de los dos insumos requeridos.
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
# Detener el script si falta alguno de los insumos.
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

# Definir la columna oficial de usuarios de internet y los identificadores.
value_column <- "internet_users_pct_population"
required_columns <- c(
  "country_iso3_code",
  "country",
  "year",
  value_column
)
# Detener el script si la descarga compartida cambio de estructura.
missing_columns <- setdiff(required_columns, names(wdi_inputs))
if (length(missing_columns) > 0L) {
  stop("Faltan columnas WDI: ", paste(missing_columns, collapse = ", "))
}

# Conservar solamente el indicador publicado, sin transformarlo.
net_raw <- wdi_inputs[, required_columns]
# Normalizar la llave pais-anio y ordenar las observaciones.
net_raw$country_iso3_code <- toupper(trimws(net_raw$country_iso3_code))
net_raw$year <- as.integer(net_raw$year)
net_raw <- net_raw[order(net_raw$country_iso3_code, net_raw$year), ]
row.names(net_raw) <- NULL

# Comprobar granularidad, identificadores, horizonte y rango porcentual.
if (anyDuplicated(net_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("El insumo raw de NET contiene llaves pais-anio duplicadas.")
}
if (any(!grepl("^[A-Z]{3}$", net_raw$country_iso3_code))) {
  stop("El insumo raw de NET contiene codigos de pais invalidos.")
}
if (any(!net_raw$year %in% 1980:2022)) {
  stop("El insumo raw de NET contiene anios por fuera de 1980-2022.")
}
if (
  any(net_raw[[value_column]] < 0, na.rm = TRUE) ||
    any(net_raw[[value_column]] > 100, na.rm = TRUE)
) {
  stop("El porcentaje de usuarios de internet contiene valores fuera de 0-100.")
}

# Verificar que los 55 paises DRES aparezcan en la fuente compartida.
missing_sample_countries <- setdiff(
  dres_sample$country_iso3_code,
  net_raw$country_iso3_code
)
if (length(missing_sample_countries) > 0L) {
  stop(
    "Faltan paises DRES en el insumo WDI: ",
    paste(missing_sample_countries, collapse = ", ")
  )
}

# Conservar la cuadricula principal de 55 paises durante 1996-2022.
analysis_years <- 1996:2022
sample_grid <- net_raw[
  net_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    net_raw$year %in% analysis_years,
  ,
  drop = FALSE
]
# Confirmar que la cuadricula contiene exactamente 55 paises por 27 anios.
expected_cells <- nrow(dres_sample) * length(analysis_years)
if (nrow(sample_grid) != expected_cells) {
  stop(
    "La cuadricula DRES deberia contener ", expected_cells,
    " filas y contiene ", nrow(sample_grid), "."
  )
}
if (anyDuplicated(sample_grid[c("country_iso3_code", "year")]) > 0L) {
  stop("La cuadricula DRES de NET contiene llaves duplicadas.")
}

# Construir el diagnostico de cobertura para cada pais.
country_coverage_rows <- lapply(
  sort(unique(dres_sample$country_iso3_code)),
  function(country_code) {
    # Seleccionar los 27 anios del pais evaluado.
    country_data <- sample_grid[
      sample_grid$country_iso3_code == country_code,
      ,
      drop = FALSE
    ]
    # Identificar observaciones disponibles y anios faltantes.
    observed <- !is.na(country_data[[value_column]])
    missing_years <- country_data$year[!observed]
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
      missing_years = paste(missing_years, collapse = ";"),
      complete_1996_2022 = sum(observed) == length(analysis_years),
      stringsAsFactors = FALSE
    )
  }
)
country_coverage <- do.call(rbind, country_coverage_rows)
row.names(country_coverage) <- NULL

# Resumir la cobertura total sobre la cuadricula de la tesis.
observed_grid <- !is.na(sample_grid[[value_column]])
coverage_summary <- data.frame(
  variable = "internet_users_pct_population",
  source_code = "IT.NET.USER.ZS",
  expected_country_years_1996_2022 = expected_cells,
  observed_country_years_1996_2022 = sum(observed_grid),
  coverage_percent_1996_2022 = 100 * sum(observed_grid) / expected_cells,
  countries_with_any_data = sum(country_coverage$observed_years > 0L),
  countries_complete_1996_2022 = sum(country_coverage$complete_1996_2022),
  countries_incomplete_1996_2022 = sum(!country_coverage$complete_1996_2022),
  countries_without_data = sum(country_coverage$observed_years == 0L),
  first_observed_year = min(sample_grid$year[observed_grid]),
  last_observed_year = max(sample_grid$year[observed_grid]),
  stringsAsFactors = FALSE
)

# Construir la carpeta especifica del insumo raw de NET.
output_path <- file.path(
  project_path,
  "data",
  "raw",
  "net",
  "world_bank_wdi"
)
dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
# Construir los nombres de las salidas raw y de cobertura.
csv_file <- file.path(output_path, "net_wdi_input_1980_2022.csv")
dta_file <- file.path(output_path, "net_wdi_input_1980_2022.dta")
summary_file <- file.path(
  output_path,
  "net_raw_coverage_summary_dres20.csv"
)
country_coverage_file <- file.path(
  output_path,
  "net_raw_country_coverage_dres20.csv"
)

# Guardar el indicador publicado sin transformaciones ni imputaciones.
write.csv(
  net_raw,
  csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar exactamente las mismas columnas y valores en formato Stata.
if (requireNamespace("haven", quietly = TRUE)) {
  haven::write_dta(net_raw, dta_file, version = 14)
} else {
  foreign::write.dta(net_raw, dta_file, version = 12)
}
# Guardar los dos diagnosticos de cobertura.
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

# Informar que la preparacion del insumo raw termino correctamente.
message("Raw de NET terminado.")
message("Archivo CSV: ", csv_file)
print(coverage_summary)
