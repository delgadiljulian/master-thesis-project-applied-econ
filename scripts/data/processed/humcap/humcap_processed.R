# CAPA: PROCESSED
# VARIABLE: HUMCAP
# ENTRADAS: data/raw/humcap/pwt/ y data/processed/dres/
# SALIDAS: data/processed/humcap/
#
# Construye HUMCAP conservando en niveles el índice de capital humano hc de
# PWT 11.0. No aplica logaritmos, interpolaciones ni imputaciones.

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

# Definir el período econométrico efectivo y la muestra esperada.
start_year <- 1996L
end_year <- 2021L
analysis_years <- start_year:end_year
expected_country_count <- 55L
expected_row_count <- expected_country_count * length(analysis_years)

# Definir entradas y salidas oficiales.
raw_file <- file.path(
  project_path,
  "data",
  "raw",
  "humcap",
  "pwt",
  "humcap_pwt11_input_1950_2023.csv"
)
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
processed_path <- file.path(project_path, "data", "processed", "humcap")
panel_csv_file <- file.path(processed_path, "humcap_data.csv")
panel_dta_file <- file.path(processed_path, "humcap_data.dta")
diagnostics_file <- file.path(
  processed_path,
  "humcap_country_year_diagnostics_1996_2021.csv"
)
country_coverage_file <- file.path(
  processed_path,
  "humcap_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  processed_path,
  "humcap_year_coverage_1996_2021.csv"
)
validation_file <- file.path(
  processed_path,
  "humcap_validation_summary.csv"
)

# Comprobar entradas y dependencia de Stata.
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
  diagnostics_file,
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

# Leer y validar la muestra fija DRES de 55 países.
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

# Leer el índice hc publicado por PWT sin modificar la capa raw.
humcap_raw <- read.csv(
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
  "human_capital_index_pwt"
)
missing_raw_columns <- setdiff(required_raw_columns, names(humcap_raw))
if (length(missing_raw_columns) > 0L) {
  stop(
    "Faltan columnas en el insumo PWT: ",
    paste(missing_raw_columns, collapse = ", ")
  )
}
humcap_raw <- humcap_raw[, required_raw_columns]
humcap_raw$country_iso3_code <- toupper(
  trimws(humcap_raw$country_iso3_code)
)
humcap_raw$year <- as.integer(humcap_raw$year)
humcap_raw$human_capital_index_pwt <- as.numeric(
  humcap_raw$human_capital_index_pwt
)
if (
  any(!grepl("^[A-Z]{3}$", humcap_raw$country_iso3_code)) ||
    any(is.na(humcap_raw$year))
) {
  stop("El insumo PWT contiene códigos ISO3 o años inválidos.")
}
if (anyDuplicated(humcap_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("El insumo PWT contiene llaves país-año duplicadas.")
}
observed_hc <- !is.na(humcap_raw$human_capital_index_pwt)
if (
  any(
    humcap_raw$human_capital_index_pwt[observed_hc] <= 0 |
      !is.finite(humcap_raw$human_capital_index_pwt[observed_hc])
  )
) {
  stop("El índice hc contiene valores observados no positivos o no finitos.")
}

# Seleccionar el período y construir la cuadrícula completa de 55 países.
humcap_selected <- humcap_raw[
  humcap_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    humcap_raw$year %in% analysis_years,
  c("country_iso3_code", "year", "human_capital_index_pwt"),
  drop = FALSE
]
panel_grid <- merge(
  dres_sample,
  data.frame(year = analysis_years),
  by = NULL,
  sort = FALSE
)
humcap_work <- merge(
  panel_grid,
  humcap_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
humcap_work <- humcap_work[
  order(humcap_work$country_iso3_code, humcap_work$year),
]
row.names(humcap_work) <- NULL

# Conservar el índice en niveles y marcar explícitamente su disponibilidad.
humcap_work$humcap <- humcap_work$human_capital_index_pwt
humcap_work$availability_status <- ifelse(
  is.na(humcap_work$humcap),
  "missing_in_pwt",
  "observed"
)
humcap_panel <- humcap_work[, c(
  "country_iso3_code",
  "country",
  "year",
  "humcap"
)]

# Validar dimensiones, llaves, período y correspondencia con el insumo.
if (nrow(humcap_panel) != expected_row_count) {
  stop(
    "HUMCAP debería contener ", expected_row_count,
    " filas y contiene ", nrow(humcap_panel), "."
  )
}
if (length(unique(humcap_panel$country_iso3_code)) != expected_country_count) {
  stop("HUMCAP no conserva exactamente los 55 países de la muestra DRES.")
}
duplicate_keys <- anyDuplicated(
  humcap_panel[c("country_iso3_code", "year")]
)
if (duplicate_keys > 0L) {
  stop("HUMCAP contiene llaves país-año duplicadas.")
}
if (!all(humcap_panel$year %in% analysis_years)) {
  stop("HUMCAP contiene años por fuera de 1996-2021.")
}
if (
  !identical(
    is.na(humcap_work$humcap),
    is.na(humcap_work$human_capital_index_pwt)
  )
) {
  stop("Los faltantes de HUMCAP no coinciden con los faltantes de hc.")
}
available_humcap <- humcap_panel$humcap[!is.na(humcap_panel$humcap)]
if (
  any(!is.finite(available_humcap)) ||
    any(available_humcap <= 0)
) {
  stop("HUMCAP contiene valores no positivos o no finitos.")
}

# Comprobar que no se aplicó ninguna transformación al índice publicado.
identity_difference <- abs(
  humcap_work$humcap[!is.na(humcap_work$humcap)] -
    humcap_work$human_capital_index_pwt[
      !is.na(humcap_work$human_capital_index_pwt)
    ]
)
identity_mismatch_count <- sum(identity_difference > 0)
max_identity_difference <- if (length(identity_difference) == 0L) {
  0
} else {
  max(identity_difference)
}
if (identity_mismatch_count > 0L) {
  stop("HUMCAP no coincide exactamente con el índice hc publicado.")
}

# Construir diagnósticos de cobertura por país y por año.
coverage_by_country <- do.call(
  rbind,
  lapply(
    split(humcap_work, humcap_work$country_iso3_code),
    function(country_data) {
      observed_years <- country_data$year[!is.na(country_data$humcap)]
      available_years <- length(observed_years)
      data.frame(
        country_iso3_code = country_data$country_iso3_code[1],
        country = country_data$country[1],
        expected_years = length(analysis_years),
        available_humcap_years = available_years,
        missing_humcap_years = length(analysis_years) - available_years,
        first_available_year = if (available_years > 0L) {
          min(observed_years)
        } else {
          NA_integer_
        },
        last_available_year = if (available_years > 0L) {
          max(observed_years)
        } else {
          NA_integer_
        },
        coverage_share = available_years / length(analysis_years),
        complete_1996_2021 = as.integer(
          available_years == length(analysis_years)
        ),
        stringsAsFactors = FALSE
      )
    }
  )
)
coverage_by_country <- coverage_by_country[
  order(
    coverage_by_country$available_humcap_years,
    coverage_by_country$country_iso3_code
  ),
]
row.names(coverage_by_country) <- NULL

coverage_by_year <- do.call(
  rbind,
  lapply(split(humcap_work, humcap_work$year), function(year_data) {
    available_countries <- sum(!is.na(year_data$humcap))
    data.frame(
      year = year_data$year[1],
      expected_countries = expected_country_count,
      available_humcap_countries = available_countries,
      missing_humcap_countries = expected_country_count - available_countries,
      coverage_share = available_countries / expected_country_count,
      stringsAsFactors = FALSE
    )
  })
)
coverage_by_year <- coverage_by_year[order(coverage_by_year$year), ]
row.names(coverage_by_year) <- NULL

# Guardar panel y diagnósticos.
write.csv(
  humcap_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  humcap_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
write.csv(
  humcap_work,
  diagnostics_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
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

# Releer CSV y Stata para comprobar estructura, faltantes y precisión.
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
    !identical(as.integer(csv_check$year), as.integer(dta_check$year))
) {
  stop("Las salidas CSV y Stata no conservan las mismas llaves país-año.")
}
if (
  !identical(
    as.character(csv_check$country),
    as.character(dta_check$country)
  )
) {
  stop("Las salidas CSV y Stata no conservan los mismos nombres de país.")
}
if (!identical(is.na(csv_check$humcap), is.na(dta_check$humcap))) {
  stop("Las salidas CSV y Stata no conservan los mismos faltantes.")
}
format_difference <- abs(csv_check$humcap - dta_check$humcap)
max_csv_stata_difference <- if (all(is.na(format_difference))) {
  0
} else {
  max(format_difference, na.rm = TRUE)
}
if (max_csv_stata_difference > 1e-10) {
  stop("Las salidas CSV y Stata difieren numéricamente.")
}

# Guardar un resumen compacto y auditable de todas las verificaciones.
validation_summary <- data.frame(
  metric = c(
    "start_year",
    "end_year",
    "dres_sample_countries",
    "expected_country_years",
    "actual_country_years",
    "available_humcap_country_years",
    "missing_humcap_country_years",
    "coverage_percent",
    "countries_with_any_humcap",
    "countries_complete_1996_2021",
    "countries_with_partial_coverage",
    "countries_without_humcap",
    "duplicate_country_year_keys",
    "nonpositive_or_nonfinite_input_count",
    "identity_mismatch_count",
    "identity_max_abs_difference",
    "humcap_minimum",
    "humcap_median",
    "humcap_maximum",
    "csv_stata_max_abs_difference"
  ),
  value = c(
    start_year,
    end_year,
    expected_country_count,
    expected_row_count,
    nrow(humcap_panel),
    length(available_humcap),
    sum(is.na(humcap_panel$humcap)),
    100 * mean(!is.na(humcap_panel$humcap)),
    sum(coverage_by_country$available_humcap_years > 0L),
    sum(coverage_by_country$complete_1996_2021 == 1L),
    sum(
      coverage_by_country$available_humcap_years > 0L &
        coverage_by_country$available_humcap_years <
          length(analysis_years)
    ),
    sum(coverage_by_country$available_humcap_years == 0L),
    duplicate_keys,
    0,
    identity_mismatch_count,
    max_identity_difference,
    min(available_humcap),
    median(available_humcap),
    max(available_humcap),
    max_csv_stata_difference
  ),
  stringsAsFactors = FALSE
)
write.csv(
  validation_summary,
  validation_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Mostrar un resumen compacto al finalizar correctamente.
message("HUMCAP procesada correctamente.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
message(
  "Cobertura: ", length(available_humcap), " de ", expected_row_count,
  " país-años (",
  round(100 * mean(!is.na(humcap_panel$humcap)), 2), "%)."
)
message(
  "Países completos: ",
  sum(coverage_by_country$complete_1996_2021 == 1L), " de ",
  expected_country_count, "."
)
