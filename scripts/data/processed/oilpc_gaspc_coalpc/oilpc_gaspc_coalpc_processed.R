# CAPA: PROCESSED
# VARIABLES: OILPC, GASPC y COALPC
# ENTRADAS: data/raw/oilpc_gaspc_coalpc/ y data/processed/dres/
# SALIDAS: data/processed/oilpc_gaspc_coalpc/
#
# Construye las rentas petroleras, gasíferas y carboníferas en dólares
# constantes por habitante. Cada medida se calcula únicamente cuando su renta
# como porcentaje del PIB, el PIB real y la población están observados.

# Reunir las ubicaciones posibles del helper compartido de rutas.
helper_path <- c(
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    file.path(
      dirname(dirname(dirname(dirname(
        rstudioapi::getActiveDocumentContext()$path
      )))),
      "project_paths.R"
    )
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

# Definir período y tamaño de la muestra fija.
start_year <- 1996L
end_year <- 2021L
analysis_years <- start_year:end_year
expected_country_count <- 55L
expected_row_count <- expected_country_count * length(analysis_years)

# Relacionar cada variable procesada con su participación de renta WDI.
rent_column_by_measure <- c(
  oilpc = "oil_rents_pct_gdp",
  gaspc = "natural_gas_rents_pct_gdp",
  coalpc = "coal_rents_pct_gdp"
)
measure_columns <- names(rent_column_by_measure)
shared_input_columns <- c("gdp_constant_usd", "population_total")
required_value_columns <- c(
  unname(rent_column_by_measure),
  shared_input_columns
)

# Definir entradas y salidas oficiales.
raw_file <- file.path(
  project_path,
  "data",
  "raw",
  "oilpc_gaspc_coalpc",
  "world_bank_wdi",
  "oilpc_gaspc_coalpc_wdi_inputs_1980_2022.csv"
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
  "oilpc_gaspc_coalpc"
)
panel_csv_file <- file.path(
  processed_path,
  "oilpc_gaspc_coalpc_data.csv"
)
panel_dta_file <- file.path(
  processed_path,
  "oilpc_gaspc_coalpc_data.dta"
)
country_coverage_file <- file.path(
  processed_path,
  "oilpc_gaspc_coalpc_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  processed_path,
  "oilpc_gaspc_coalpc_year_coverage_1996_2021.csv"
)
validation_file <- file.path(
  processed_path,
  "oilpc_gaspc_coalpc_validation_summary.csv"
)

# Comprobar entradas, dependencia de Stata y disponibilidad de salidas.
required_files <- c(raw_file, sample_file)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0L) {
  stop("Faltan archivos requeridos: ", paste(missing_files, collapse = ", "))
}
if (!requireNamespace("foreign", quietly = TRUE)) {
  stop("Falta el paquete de R 'foreign', requerido para la salida Stata.")
}
dir.create(processed_path, recursive = TRUE, showWarnings = FALSE)
official_output_files <- c(
  panel_csv_file,
  panel_dta_file,
  country_coverage_file,
  year_coverage_file,
  validation_file
)
for (output_file in official_output_files[file.exists(official_output_files)]) {
  output_connection <- try(file(output_file, open = "ab"), silent = TRUE)
  if (inherits(output_connection, "try-error")) {
    stop("Cierre el archivo antes de ejecutar el script: ", output_file)
  }
  close(output_connection)
}

# Leer y validar la muestra DRES.
dres_sample <- read.csv(
  sample_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
required_sample_columns <- c("country_iso3_code", "country")
missing_sample_columns <- setdiff(
  required_sample_columns,
  names(dres_sample)
)
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
dres_sample$country <- trimws(dres_sample$country)
if (
  any(!grepl("^[A-Z]{3}$", dres_sample$country_iso3_code)) ||
    any(!nzchar(dres_sample$country))
) {
  stop("La muestra DRES contiene códigos ISO3 o nombres inválidos.")
}
if (
  anyDuplicated(dres_sample$country_iso3_code) > 0L ||
    nrow(dres_sample) != expected_country_count
) {
  stop("La muestra DRES no contiene exactamente 55 países únicos.")
}
dres_sample <- dres_sample[order(dres_sample$country_iso3_code), ]
row.names(dres_sample) <- NULL

# Leer los cinco insumos raw sin modificar su capa.
resource_raw <- read.csv(
  raw_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  fileEncoding = "UTF-8"
)
required_raw_columns <- c(
  "country_iso3_code",
  "country",
  "year",
  required_value_columns
)
missing_raw_columns <- setdiff(required_raw_columns, names(resource_raw))
if (length(missing_raw_columns) > 0L) {
  stop(
    "Faltan columnas en los insumos raw: ",
    paste(missing_raw_columns, collapse = ", ")
  )
}
resource_raw <- resource_raw[, required_raw_columns]
resource_raw$country_iso3_code <- toupper(
  trimws(resource_raw$country_iso3_code)
)
resource_raw$year <- as.integer(resource_raw$year)
for (column_name in required_value_columns) {
  resource_raw[[column_name]] <- as.numeric(resource_raw[[column_name]])
}
if (
  any(!grepl("^[A-Z]{3}$", resource_raw$country_iso3_code)) ||
    any(is.na(resource_raw$year))
) {
  stop("Los insumos raw contienen códigos ISO3 o años inválidos.")
}
if (anyDuplicated(resource_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("Los insumos raw contienen llaves país-año duplicadas.")
}
for (column_name in unname(rent_column_by_measure)) {
  if (any(resource_raw[[column_name]] < 0, na.rm = TRUE)) {
    stop("La participación ", column_name, " contiene valores negativos.")
  }
}
if (any(resource_raw$gdp_constant_usd <= 0, na.rm = TRUE)) {
  stop("El PIB real contiene valores nulos o negativos.")
}
if (any(resource_raw$population_total <= 0, na.rm = TRUE)) {
  stop("La población contiene valores nulos o negativos.")
}

# Crear la cuadrícula completa de 55 países por 26 años.
resource_selected <- resource_raw[
  resource_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    resource_raw$year %in% analysis_years,
  c("country_iso3_code", "year", required_value_columns),
  drop = FALSE
]
panel_grid <- merge(
  dres_sample,
  data.frame(year = analysis_years),
  by = NULL,
  sort = FALSE
)
resource_work <- merge(
  panel_grid,
  resource_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
resource_work <- resource_work[
  order(resource_work$country_iso3_code, resource_work$year),
]
row.names(resource_work) <- NULL

# Construir cada medida únicamente con su paquete completo de insumos.
complete_input_by_measure <- list()
for (measure_name in measure_columns) {
  rent_column <- rent_column_by_measure[[measure_name]]
  input_columns <- c(rent_column, shared_input_columns)
  complete_inputs <- complete.cases(resource_work[, input_columns])
  complete_input_by_measure[[measure_name]] <- complete_inputs
  resource_work[[measure_name]] <- NA_real_
  resource_work[[measure_name]][complete_inputs] <- (
    resource_work[[rent_column]][complete_inputs] / 100 *
      resource_work$gdp_constant_usd[complete_inputs] /
      resource_work$population_total[complete_inputs]
  )
}

# Conservar identificación y las tres variables procesadas.
resource_panel <- resource_work[, c(
  "country_iso3_code",
  "country",
  "year",
  measure_columns
)]

# Validar dimensiones, llaves y reglas de construcción.
if (nrow(resource_panel) != expected_row_count) {
  stop(
    "El panel debería contener ", expected_row_count,
    " filas y contiene ", nrow(resource_panel), "."
  )
}
if (
  length(unique(resource_panel$country_iso3_code)) != expected_country_count
) {
  stop("El panel no conserva los 55 países de la muestra DRES.")
}
duplicate_keys <- anyDuplicated(
  resource_panel[c("country_iso3_code", "year")]
)
if (duplicate_keys > 0L) {
  stop("El panel contiene llaves país-año duplicadas.")
}
if (!all(resource_panel$year %in% analysis_years)) {
  stop("El panel contiene años por fuera de 1996-2021.")
}

# Recalcular y verificar por separado las tres fórmulas.
formula_mismatch_counts <- setNames(
  numeric(length(measure_columns)),
  measure_columns
)
for (measure_name in measure_columns) {
  rent_column <- rent_column_by_measure[[measure_name]]
  complete_inputs <- complete_input_by_measure[[measure_name]]
  if (any(!complete_inputs & !is.na(resource_work[[measure_name]]))) {
    stop("Se calculó ", measure_name, " con uno o más insumos faltantes.")
  }
  if (any(complete_inputs & is.na(resource_work[[measure_name]]))) {
    stop("Existen filas completas sin un valor de ", measure_name, ".")
  }
  formula_check <- (
    resource_work[[rent_column]][complete_inputs] / 100 *
      resource_work$gdp_constant_usd[complete_inputs] /
      resource_work$population_total[complete_inputs]
  )
  formula_mismatch_counts[[measure_name]] <- sum(
    abs(resource_work[[measure_name]][complete_inputs] - formula_check) >
      1e-10
  )
  if (formula_mismatch_counts[[measure_name]] > 0L) {
    stop("La validación encontró diferencias en la fórmula de ", measure_name)
  }
  if (any(resource_work[[measure_name]] < 0, na.rm = TRUE)) {
    stop(measure_name, " contiene valores negativos.")
  }
}

# Construir cobertura por país para las tres variables.
coverage_by_country <- do.call(
  rbind,
  lapply(
    split(resource_work, resource_work$country_iso3_code),
    function(country_data) {
      country_row <- data.frame(
        country_iso3_code = country_data$country_iso3_code[1],
        country = country_data$country[1],
        expected_years = length(analysis_years),
        stringsAsFactors = FALSE
      )
      for (measure_name in measure_columns) {
        observed_years <- country_data$year[
          !is.na(country_data[[measure_name]])
        ]
        available_years <- length(observed_years)
        country_row[[paste0("available_", measure_name, "_years")]] <- (
          available_years
        )
        country_row[[paste0("missing_", measure_name, "_years")]] <- (
          length(analysis_years) - available_years
        )
        country_row[[paste0("published_zero_", measure_name, "_years")]] <- sum(
          country_data[[measure_name]] == 0,
          na.rm = TRUE
        )
        country_row[[paste0("first_", measure_name, "_year")]] <- if (
          available_years > 0L
        ) {
          min(observed_years)
        } else {
          NA_integer_
        }
        country_row[[paste0("last_", measure_name, "_year")]] <- if (
          available_years > 0L
        ) {
          max(observed_years)
        } else {
          NA_integer_
        }
        country_row[[paste0(measure_name, "_coverage_share")]] <- (
          available_years / length(analysis_years)
        )
        country_row[[paste0("complete_", measure_name, "_1996_2021")]] <- (
          as.integer(available_years == length(analysis_years))
        )
      }
      country_row
    }
  )
)
coverage_by_country <- coverage_by_country[
  order(
    coverage_by_country$available_oilpc_years,
    coverage_by_country$country_iso3_code
  ),
]
row.names(coverage_by_country) <- NULL

# Construir cobertura anual para detectar faltantes temporales.
coverage_by_year <- do.call(
  rbind,
  lapply(split(resource_work, resource_work$year), function(year_data) {
    year_row <- data.frame(
      year = year_data$year[1],
      expected_countries = expected_country_count,
      stringsAsFactors = FALSE
    )
    for (measure_name in measure_columns) {
      available_countries <- sum(!is.na(year_data[[measure_name]]))
      year_row[[paste0("available_", measure_name, "_countries")]] <- (
        available_countries
      )
      year_row[[paste0("missing_", measure_name, "_countries")]] <- (
        expected_country_count - available_countries
      )
      year_row[[paste0(measure_name, "_coverage_share")]] <- (
        available_countries / expected_country_count
      )
    }
    year_row
  })
)
coverage_by_year <- coverage_by_year[order(coverage_by_year$year), ]
row.names(coverage_by_year) <- NULL

# Guardar panel y diagnósticos.
write.csv(
  resource_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  resource_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
write.csv(
  coverage_by_country,
  country_coverage_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
write.csv(
  coverage_by_year,
  year_coverage_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Releer CSV y Stata para comprobar equivalencia.
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
  stop("Las salidas CSV y Stata no conservan la misma estructura.")
}
if (
  !identical(
    as.character(csv_check$country_iso3_code),
    as.character(dta_check$country_iso3_code)
  ) ||
    !identical(as.integer(csv_check$year), as.integer(dta_check$year)) ||
    !identical(as.character(csv_check$country), as.character(dta_check$country))
) {
  stop("Las salidas CSV y Stata no conservan la identificación del panel.")
}
csv_stata_differences <- setNames(
  numeric(length(measure_columns)),
  measure_columns
)
for (measure_name in measure_columns) {
  if (
    !identical(
      is.na(csv_check[[measure_name]]),
      is.na(dta_check[[measure_name]])
    )
  ) {
    stop("CSV y Stata no conservan los faltantes de ", measure_name, ".")
  }
  format_difference <- abs(
    csv_check[[measure_name]] - dta_check[[measure_name]]
  )
  csv_stata_differences[[measure_name]] <- if (
    all(is.na(format_difference))
  ) {
    0
  } else {
    max(format_difference, na.rm = TRUE)
  }
}
max_csv_stata_difference <- max(csv_stata_differences)
if (max_csv_stata_difference > 1e-8) {
  stop("Las salidas CSV y Stata difieren numéricamente.")
}

# Resumir verificaciones generales y específicas de cada variable.
validation_summary <- data.frame(
  metric = c(
    "start_year",
    "end_year",
    "dres_sample_countries",
    "expected_country_years",
    "actual_country_years",
    "duplicate_country_year_keys",
    "gdp_nonpositive_count",
    "population_nonpositive_count",
    "rows_with_all_five_inputs"
  ),
  value = c(
    start_year,
    end_year,
    expected_country_count,
    expected_row_count,
    nrow(resource_panel),
    duplicate_keys,
    sum(resource_work$gdp_constant_usd <= 0, na.rm = TRUE),
    sum(resource_work$population_total <= 0, na.rm = TRUE),
    sum(complete.cases(resource_work[, required_value_columns]))
  ),
  stringsAsFactors = FALSE
)
for (measure_name in measure_columns) {
  available_count <- sum(!is.na(resource_panel[[measure_name]]))
  country_available_column <- paste0("available_", measure_name, "_years")
  complete_country_column <- paste0(
    "complete_", measure_name, "_1996_2021"
  )
  measure_summary <- data.frame(
    metric = c(
      paste0("available_", measure_name, "_country_years"),
      paste0("missing_", measure_name, "_country_years"),
      paste0(measure_name, "_coverage_percent"),
      paste0("countries_with_any_", measure_name),
      paste0("countries_complete_", measure_name, "_1996_2021"),
      paste0("countries_without_", measure_name),
      paste0("published_zero_", measure_name),
      paste0("negative_", measure_name),
      paste0(measure_name, "_minimum"),
      paste0(measure_name, "_median"),
      paste0(measure_name, "_p99"),
      paste0(measure_name, "_maximum"),
      paste0(measure_name, "_formula_mismatch_count"),
      paste0(measure_name, "_csv_stata_max_abs_difference")
    ),
    value = c(
      available_count,
      expected_row_count - available_count,
      100 * available_count / expected_row_count,
      sum(coverage_by_country[[country_available_column]] > 0L),
      sum(coverage_by_country[[complete_country_column]] == 1L),
      sum(coverage_by_country[[country_available_column]] == 0L),
      sum(resource_panel[[measure_name]] == 0, na.rm = TRUE),
      sum(resource_panel[[measure_name]] < 0, na.rm = TRUE),
      min(resource_panel[[measure_name]], na.rm = TRUE),
      median(resource_panel[[measure_name]], na.rm = TRUE),
      unname(
        quantile(resource_panel[[measure_name]], 0.99, na.rm = TRUE)
      ),
      max(resource_panel[[measure_name]], na.rm = TRUE),
      formula_mismatch_counts[[measure_name]],
      csv_stata_differences[[measure_name]]
    ),
    stringsAsFactors = FALSE
  )
  validation_summary <- rbind(validation_summary, measure_summary)
}
validation_summary <- rbind(
  validation_summary,
  data.frame(
    metric = "all_measures_csv_stata_max_abs_difference",
    value = max_csv_stata_difference,
    stringsAsFactors = FALSE
  )
)
write.csv(
  validation_summary,
  validation_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Mostrar un resumen compacto al finalizar correctamente.
message("OILPC, GASPC y COALPC se procesaron correctamente.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
for (measure_name in measure_columns) {
  available_count <- sum(!is.na(resource_panel[[measure_name]]))
  message(
    toupper(measure_name), ": ", available_count, " de ",
    expected_row_count, " país-años (",
    round(100 * available_count / expected_row_count, 2), "%)."
  )
}
