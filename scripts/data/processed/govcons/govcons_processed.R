# CAPA: PROCESSED
# VARIABLE: GOVCONS
# ENTRADAS: data/raw/govcons/world_bank_wdi/ y data/processed/dres/
# SALIDAS: data/processed/govcons/
#
# Construye GOVCONS como el gasto de consumo final del gobierno general en
# porcentaje del PIB. Los ceros anómalos de Venezuela en 1996-2011 se marcan
# como faltantes; no se interpolan, imputan ni sustituyen por otra fuente.

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
flagged_zero_country <- "VEN"
flagged_zero_years <- 1996:2011

# Definir entradas y salidas oficiales.
raw_file <- file.path(
  project_path,
  "data",
  "raw",
  "govcons",
  "world_bank_wdi",
  "govcons_wdi_input_1980_2022.csv"
)
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
processed_path <- file.path(project_path, "data", "processed", "govcons")
panel_csv_file <- file.path(processed_path, "govcons_data.csv")
panel_dta_file <- file.path(processed_path, "govcons_data.dta")
diagnostics_file <- file.path(
  processed_path,
  "govcons_country_year_diagnostics_1996_2021.csv"
)
country_coverage_file <- file.path(
  processed_path,
  "govcons_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  processed_path,
  "govcons_year_coverage_1996_2021.csv"
)
validation_file <- file.path(
  processed_path,
  "govcons_validation_summary.csv"
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

# Leer el porcentaje publicado por WDI sin modificar la capa raw.
govcons_raw <- read.csv(
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
  "government_consumption_pct_gdp"
)
missing_raw_columns <- setdiff(required_raw_columns, names(govcons_raw))
if (length(missing_raw_columns) > 0L) {
  stop(
    "Faltan columnas en el insumo WDI: ",
    paste(missing_raw_columns, collapse = ", ")
  )
}
govcons_raw <- govcons_raw[, required_raw_columns]
govcons_raw$country_iso3_code <- toupper(
  trimws(govcons_raw$country_iso3_code)
)
govcons_raw$year <- as.integer(govcons_raw$year)
govcons_raw$government_consumption_pct_gdp <- as.numeric(
  govcons_raw$government_consumption_pct_gdp
)
if (
  any(!grepl("^[A-Z]{3}$", govcons_raw$country_iso3_code)) ||
    any(is.na(govcons_raw$year))
) {
  stop("El insumo WDI contiene códigos ISO3 o años inválidos.")
}
if (anyDuplicated(govcons_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("El insumo WDI contiene llaves país-año duplicadas.")
}
observed_raw <- !is.na(govcons_raw$government_consumption_pct_gdp)
if (
  any(
    govcons_raw$government_consumption_pct_gdp[observed_raw] < 0 |
      !is.finite(
        govcons_raw$government_consumption_pct_gdp[observed_raw]
      )
  )
) {
  stop("El insumo GOVCONS contiene valores negativos o no finitos.")
}

# Seleccionar el período y construir la cuadrícula completa de 55 países.
govcons_selected <- govcons_raw[
  govcons_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    govcons_raw$year %in% analysis_years,
  c("country_iso3_code", "year", "government_consumption_pct_gdp"),
  drop = FALSE
]
panel_grid <- merge(
  dres_sample,
  data.frame(year = analysis_years),
  by = NULL,
  sort = FALSE
)
govcons_work <- merge(
  panel_grid,
  govcons_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
govcons_work <- govcons_work[
  order(govcons_work$country_iso3_code, govcons_work$year),
]
row.names(govcons_work) <- NULL

# Identificar de manera reproducible la secuencia anómala publicada para VEN.
zero_input <- (
  !is.na(govcons_work$government_consumption_pct_gdp) &
    govcons_work$government_consumption_pct_gdp == 0
)
expected_flagged_zero <- (
  govcons_work$country_iso3_code == flagged_zero_country &
    govcons_work$year %in% flagged_zero_years
)
if (!identical(zero_input, expected_flagged_zero)) {
  stop(
    "Los ceros de GOVCONS ya no coinciden exactamente con Venezuela 1996-2011; ",
    "revise la fuente antes de procesar."
  )
}

# Conservar valores positivos y convertir únicamente los ceros anómalos en NA.
govcons_work$govcons <- govcons_work$government_consumption_pct_gdp
govcons_work$govcons[zero_input] <- NA_real_
govcons_work$availability_status <- ifelse(
  zero_input,
  "source_zero_flagged_missing",
  ifelse(
    is.na(govcons_work$government_consumption_pct_gdp),
    "missing_in_wdi",
    "observed"
  )
)
govcons_panel <- govcons_work[, c(
  "country_iso3_code",
  "country",
  "year",
  "govcons"
)]

# Validar dimensiones, llaves, período, dominio y regla de depuración.
if (nrow(govcons_panel) != expected_row_count) {
  stop(
    "GOVCONS debería contener ", expected_row_count,
    " filas y contiene ", nrow(govcons_panel), "."
  )
}
if (
  length(unique(govcons_panel$country_iso3_code)) !=
    expected_country_count
) {
  stop("GOVCONS no conserva exactamente los 55 países DRES.")
}
duplicate_keys <- anyDuplicated(
  govcons_panel[c("country_iso3_code", "year")]
)
if (duplicate_keys > 0L) {
  stop("GOVCONS contiene llaves país-año duplicadas.")
}
if (!all(govcons_panel$year %in% analysis_years)) {
  stop("GOVCONS contiene años por fuera de 1996-2021.")
}
available_govcons <- govcons_panel$govcons[
  !is.na(govcons_panel$govcons)
]
if (
  any(!is.finite(available_govcons)) ||
    any(available_govcons <= 0)
) {
  stop("GOVCONS procesada contiene valores no positivos o no finitos.")
}
if (any(!is.na(govcons_work$govcons[zero_input]))) {
  stop("Uno o más ceros anómalos permanecieron como valores válidos.")
}

# Verificar que los valores positivos coincidan exactamente con la fuente.
valid_input <- (
  !is.na(govcons_work$government_consumption_pct_gdp) &
    !zero_input
)
identity_difference <- abs(
  govcons_work$govcons[valid_input] -
    govcons_work$government_consumption_pct_gdp[valid_input]
)
identity_mismatch_count <- sum(identity_difference > 0)
max_identity_difference <- if (length(identity_difference) == 0L) {
  0
} else {
  max(identity_difference)
}
if (identity_mismatch_count > 0L) {
  stop("Los valores positivos de GOVCONS no coinciden con la fuente WDI.")
}

# Construir diagnósticos de cobertura por país y por año.
coverage_by_country <- do.call(
  rbind,
  lapply(
    split(govcons_work, govcons_work$country_iso3_code),
    function(country_data) {
      observed_years <- country_data$year[!is.na(country_data$govcons)]
      missing_years <- country_data$year[is.na(country_data$govcons)]
      available_years <- length(observed_years)
      data.frame(
        country_iso3_code = country_data$country_iso3_code[1],
        country = country_data$country[1],
        expected_years = length(analysis_years),
        available_govcons_years = available_years,
        missing_govcons_years = length(analysis_years) - available_years,
        source_zero_values_flagged = sum(
          country_data$availability_status ==
            "source_zero_flagged_missing"
        ),
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
        missing_year_list = paste(missing_years, collapse = ";"),
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
    coverage_by_country$available_govcons_years,
    coverage_by_country$country_iso3_code
  ),
]
row.names(coverage_by_country) <- NULL

coverage_by_year <- do.call(
  rbind,
  lapply(split(govcons_work, govcons_work$year), function(year_data) {
    available_countries <- sum(!is.na(year_data$govcons))
    data.frame(
      year = year_data$year[1],
      expected_countries = expected_country_count,
      available_govcons_countries = available_countries,
      missing_govcons_countries = (
        expected_country_count - available_countries
      ),
      source_zero_values_flagged = sum(
        year_data$availability_status == "source_zero_flagged_missing"
      ),
      coverage_share = available_countries / expected_country_count,
      stringsAsFactors = FALSE
    )
  })
)
coverage_by_year <- coverage_by_year[order(coverage_by_year$year), ]
row.names(coverage_by_year) <- NULL

# Guardar panel y diagnósticos.
write.csv(
  govcons_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  govcons_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
write.csv(
  govcons_work,
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
if (!identical(is.na(csv_check$govcons), is.na(dta_check$govcons))) {
  stop("Las salidas CSV y Stata no conservan los mismos faltantes.")
}
format_difference <- abs(csv_check$govcons - dta_check$govcons)
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
    "raw_observed_country_years",
    "source_zero_values_flagged_missing",
    "available_govcons_country_years",
    "missing_govcons_country_years",
    "coverage_percent",
    "countries_with_any_govcons",
    "countries_complete_1996_2021",
    "countries_with_partial_coverage",
    "countries_without_govcons",
    "duplicate_country_year_keys",
    "negative_or_nonfinite_input_count",
    "nonpositive_processed_value_count",
    "identity_mismatch_count",
    "identity_max_abs_difference",
    "govcons_minimum",
    "govcons_median",
    "govcons_maximum",
    "csv_stata_max_abs_difference"
  ),
  value = c(
    start_year,
    end_year,
    expected_country_count,
    expected_row_count,
    nrow(govcons_panel),
    sum(!is.na(govcons_work$government_consumption_pct_gdp)),
    sum(zero_input),
    length(available_govcons),
    sum(is.na(govcons_panel$govcons)),
    100 * mean(!is.na(govcons_panel$govcons)),
    sum(coverage_by_country$available_govcons_years > 0L),
    sum(coverage_by_country$complete_1996_2021 == 1L),
    sum(
      coverage_by_country$available_govcons_years > 0L &
        coverage_by_country$available_govcons_years <
          length(analysis_years)
    ),
    sum(coverage_by_country$available_govcons_years == 0L),
    duplicate_keys,
    0,
    sum(available_govcons <= 0 | !is.finite(available_govcons)),
    identity_mismatch_count,
    max_identity_difference,
    min(available_govcons),
    median(available_govcons),
    max(available_govcons),
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
message("GOVCONS procesada correctamente.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
message(
  "Cobertura: ", length(available_govcons), " de ",
  expected_row_count, " país-años (",
  round(100 * mean(!is.na(govcons_panel$govcons)), 2), "%)."
)
message(
  "Ceros anómalos tratados como faltantes: ", sum(zero_input), "."
)
