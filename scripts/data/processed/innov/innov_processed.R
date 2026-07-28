# CAPA: PROCESSED
# VARIABLE: INNOV
# ENTRADAS: data/raw/innov/world_bank_wdi/ y data/processed/dres/
# SALIDAS: data/processed/innov/
#
# Construye INNOV como log(1 + artículos científicos y técnicos por millón de
# habitantes). Conserva los ceros publicados y no interpola ni imputa.

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
population_scale <- 1000000

# Definir entradas y salidas oficiales.
raw_file <- file.path(
  project_path,
  "data",
  "raw",
  "innov",
  "world_bank_wdi",
  "innov_wdi_input_1980_2022.csv"
)
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
processed_path <- file.path(project_path, "data", "processed", "innov")
panel_csv_file <- file.path(processed_path, "innov_data.csv")
panel_dta_file <- file.path(processed_path, "innov_data.dta")
diagnostics_file <- file.path(
  processed_path,
  "innov_country_year_diagnostics_1996_2021.csv"
)
country_coverage_file <- file.path(
  processed_path,
  "innov_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  processed_path,
  "innov_year_coverage_1996_2021.csv"
)
validation_file <- file.path(
  processed_path,
  "innov_validation_summary.csv"
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

# Leer los dos insumos WDI sin modificar la capa raw.
innov_raw <- read.csv(
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
  "scientific_articles",
  "population_total"
)
missing_raw_columns <- setdiff(required_raw_columns, names(innov_raw))
if (length(missing_raw_columns) > 0L) {
  stop(
    "Faltan columnas en los insumos WDI: ",
    paste(missing_raw_columns, collapse = ", ")
  )
}
innov_raw <- innov_raw[, required_raw_columns]
innov_raw$country_iso3_code <- toupper(
  trimws(innov_raw$country_iso3_code)
)
innov_raw$year <- as.integer(innov_raw$year)
innov_raw$scientific_articles <- as.numeric(innov_raw$scientific_articles)
innov_raw$population_total <- as.numeric(innov_raw$population_total)
if (
  any(!grepl("^[A-Z]{3}$", innov_raw$country_iso3_code)) ||
    any(is.na(innov_raw$year))
) {
  stop("Los insumos WDI contienen códigos ISO3 o años inválidos.")
}
if (anyDuplicated(innov_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("Los insumos WDI contienen llaves país-año duplicadas.")
}
observed_articles <- !is.na(innov_raw$scientific_articles)
observed_population <- !is.na(innov_raw$population_total)
if (
  any(
    innov_raw$scientific_articles[observed_articles] < 0 |
      !is.finite(innov_raw$scientific_articles[observed_articles])
  )
) {
  stop("Los artículos contienen valores negativos o no finitos.")
}
if (
  any(
    innov_raw$population_total[observed_population] <= 0 |
      !is.finite(innov_raw$population_total[observed_population])
  )
) {
  stop("La población contiene valores no positivos o no finitos.")
}

# Seleccionar el período y construir la cuadrícula completa de 55 países.
innov_selected <- innov_raw[
  innov_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    innov_raw$year %in% analysis_years,
  c(
    "country_iso3_code",
    "year",
    "scientific_articles",
    "population_total"
  ),
  drop = FALSE
]
panel_grid <- merge(
  dres_sample,
  data.frame(year = analysis_years),
  by = NULL,
  sort = FALSE
)
innov_work <- merge(
  panel_grid,
  innov_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
innov_work <- innov_work[
  order(innov_work$country_iso3_code, innov_work$year),
]
row.names(innov_work) <- NULL

# Construir la tasa por millón y aplicar log(1 + x).
complete_inputs <- (
  !is.na(innov_work$scientific_articles) &
    !is.na(innov_work$population_total)
)
innov_work$scientific_articles_per_million <- NA_real_
innov_work$scientific_articles_per_million[complete_inputs] <- (
  population_scale *
    innov_work$scientific_articles[complete_inputs] /
    innov_work$population_total[complete_inputs]
)
innov_work$innov <- NA_real_
innov_work$innov[complete_inputs] <- log1p(
  innov_work$scientific_articles_per_million[complete_inputs]
)
innov_work$availability_status <- ifelse(
  complete_inputs,
  "observed",
  ifelse(
    is.na(innov_work$scientific_articles) &
      is.na(innov_work$population_total),
    "both_inputs_missing",
    ifelse(
      is.na(innov_work$scientific_articles),
      "articles_missing",
      "population_missing"
    )
  )
)
innov_panel <- innov_work[, c(
  "country_iso3_code",
  "country",
  "year",
  "innov"
)]

# Validar dimensiones, llaves, período, dominio y regla de disponibilidad.
if (nrow(innov_panel) != expected_row_count) {
  stop(
    "INNOV debería contener ", expected_row_count,
    " filas y contiene ", nrow(innov_panel), "."
  )
}
if (length(unique(innov_panel$country_iso3_code)) != expected_country_count) {
  stop("INNOV no conserva exactamente los 55 países de la muestra DRES.")
}
duplicate_keys <- anyDuplicated(
  innov_panel[c("country_iso3_code", "year")]
)
if (duplicate_keys > 0L) {
  stop("INNOV contiene llaves país-año duplicadas.")
}
if (!all(innov_panel$year %in% analysis_years)) {
  stop("INNOV contiene años por fuera de 1996-2021.")
}
if (!identical(!is.na(innov_work$innov), complete_inputs)) {
  stop("La disponibilidad de INNOV no coincide con sus dos insumos.")
}
available_rates <- innov_work$scientific_articles_per_million[
  complete_inputs
]
available_innov <- innov_panel$innov[!is.na(innov_panel$innov)]
if (
  any(!is.finite(available_rates)) ||
    any(available_rates < 0) ||
    any(!is.finite(available_innov)) ||
    any(available_innov < 0)
) {
  stop("INNOV o la tasa por millón contienen valores inválidos.")
}

# Recalcular las dos etapas de la fórmula de manera independiente.
rate_check <- (
  population_scale *
    innov_work$scientific_articles[complete_inputs] /
    innov_work$population_total[complete_inputs]
)
innov_check <- log(1 + rate_check)
rate_difference <- abs(available_rates - rate_check)
innov_difference <- abs(available_innov - innov_check)
rate_mismatch_count <- sum(rate_difference > 1e-12)
formula_mismatch_count <- sum(innov_difference > 1e-12)
max_rate_difference <- if (length(rate_difference) == 0L) {
  0
} else {
  max(rate_difference)
}
max_formula_difference <- if (length(innov_difference) == 0L) {
  0
} else {
  max(innov_difference)
}
if (rate_mismatch_count > 0L || formula_mismatch_count > 0L) {
  stop("La validación independiente encontró diferencias en INNOV.")
}

# Construir diagnósticos de cobertura por país y por año.
coverage_by_country <- do.call(
  rbind,
  lapply(split(innov_work, innov_work$country_iso3_code), function(country_data) {
    observed_years <- country_data$year[!is.na(country_data$innov)]
    available_years <- length(observed_years)
    data.frame(
      country_iso3_code = country_data$country_iso3_code[1],
      country = country_data$country[1],
      expected_years = length(analysis_years),
      available_innov_years = available_years,
      missing_innov_years = length(analysis_years) - available_years,
      zero_article_years = sum(
        country_data$scientific_articles == 0,
        na.rm = TRUE
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
      coverage_share = available_years / length(analysis_years),
      complete_1996_2021 = as.integer(
        available_years == length(analysis_years)
      ),
      stringsAsFactors = FALSE
    )
  })
)
coverage_by_country <- coverage_by_country[
  order(
    coverage_by_country$available_innov_years,
    coverage_by_country$country_iso3_code
  ),
]
row.names(coverage_by_country) <- NULL

coverage_by_year <- do.call(
  rbind,
  lapply(split(innov_work, innov_work$year), function(year_data) {
    available_countries <- sum(!is.na(year_data$innov))
    data.frame(
      year = year_data$year[1],
      expected_countries = expected_country_count,
      available_innov_countries = available_countries,
      missing_innov_countries = expected_country_count - available_countries,
      zero_article_countries = sum(
        year_data$scientific_articles == 0,
        na.rm = TRUE
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
  innov_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  innov_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
write.csv(
  innov_work,
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
if (!identical(is.na(csv_check$innov), is.na(dta_check$innov))) {
  stop("Las salidas CSV y Stata no conservan los mismos faltantes.")
}
format_difference <- abs(csv_check$innov - dta_check$innov)
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
    "available_innov_country_years",
    "missing_innov_country_years",
    "coverage_percent",
    "countries_complete_1996_2021",
    "countries_without_innov",
    "duplicate_country_year_keys",
    "negative_or_nonfinite_article_count",
    "nonpositive_or_nonfinite_population_count",
    "zero_article_country_years",
    "rate_mismatch_count",
    "rate_max_abs_difference",
    "formula_mismatch_count",
    "formula_max_abs_difference",
    "articles_per_million_minimum",
    "articles_per_million_median",
    "articles_per_million_maximum",
    "innov_minimum",
    "innov_median",
    "innov_maximum",
    "csv_stata_max_abs_difference"
  ),
  value = c(
    start_year,
    end_year,
    expected_country_count,
    expected_row_count,
    nrow(innov_panel),
    length(available_innov),
    sum(is.na(innov_panel$innov)),
    100 * mean(!is.na(innov_panel$innov)),
    sum(coverage_by_country$complete_1996_2021 == 1L),
    sum(coverage_by_country$available_innov_years == 0L),
    duplicate_keys,
    0,
    0,
    sum(innov_work$scientific_articles == 0, na.rm = TRUE),
    rate_mismatch_count,
    max_rate_difference,
    formula_mismatch_count,
    max_formula_difference,
    min(available_rates),
    median(available_rates),
    max(available_rates),
    min(available_innov),
    median(available_innov),
    max(available_innov),
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
message("INNOV procesada correctamente.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
message(
  "Cobertura: ", length(available_innov), " de ", expected_row_count,
  " país-años (",
  round(100 * mean(!is.na(innov_panel$innov)), 2), "%)."
)
message(
  "País-años con cero artículos conservados: ",
  sum(innov_work$scientific_articles == 0, na.rm = TRUE), "."
)
