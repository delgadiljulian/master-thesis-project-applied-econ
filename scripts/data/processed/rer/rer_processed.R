# CAPA: PROCESSED
# VARIABLE: RER
# ENTRADAS: data/raw/rer/pwt/ y data/processed/dres/
# SALIDAS: data/processed/rer/
#
# Construye RER como el logaritmo natural del nivel de precios del producto
# relativo a Estados Unidos (pl_gdpo) de PWT 11.0. No interpola ni imputa.

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
  "rer",
  "pwt",
  "rer_pwt11_input_1950_2023.csv"
)
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
processed_path <- file.path(project_path, "data", "processed", "rer")
panel_csv_file <- file.path(processed_path, "rer_data.csv")
panel_dta_file <- file.path(processed_path, "rer_data.dta")
diagnostics_file <- file.path(
  processed_path,
  "rer_country_year_diagnostics_1996_2021.csv"
)
country_coverage_file <- file.path(
  processed_path,
  "rer_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  processed_path,
  "rer_year_coverage_1996_2021.csv"
)
validation_file <- file.path(
  processed_path,
  "rer_validation_summary.csv"
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

# Leer el nivel de precios publicado por PWT sin modificar la capa raw.
rer_raw <- read.csv(
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
  "output_price_level_pwt"
)
missing_raw_columns <- setdiff(required_raw_columns, names(rer_raw))
if (length(missing_raw_columns) > 0L) {
  stop(
    "Faltan columnas en el insumo PWT: ",
    paste(missing_raw_columns, collapse = ", ")
  )
}
rer_raw <- rer_raw[, required_raw_columns]
rer_raw$country_iso3_code <- toupper(trimws(rer_raw$country_iso3_code))
rer_raw$year <- as.integer(rer_raw$year)
rer_raw$output_price_level_pwt <- as.numeric(
  rer_raw$output_price_level_pwt
)
if (
  any(!grepl("^[A-Z]{3}$", rer_raw$country_iso3_code)) ||
    any(is.na(rer_raw$year))
) {
  stop("El insumo PWT contiene códigos ISO3 o años inválidos.")
}
if (anyDuplicated(rer_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("El insumo PWT contiene llaves país-año duplicadas.")
}
observed_level <- !is.na(rer_raw$output_price_level_pwt)
if (
  any(
    rer_raw$output_price_level_pwt[observed_level] <= 0 |
      !is.finite(rer_raw$output_price_level_pwt[observed_level])
  )
) {
  stop("pl_gdpo contiene valores observados no positivos o no finitos.")
}

# Seleccionar el período y construir la cuadrícula completa de 55 países.
rer_selected <- rer_raw[
  rer_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    rer_raw$year %in% analysis_years,
  c("country_iso3_code", "year", "output_price_level_pwt"),
  drop = FALSE
]
panel_grid <- merge(
  dres_sample,
  data.frame(year = analysis_years),
  by = NULL,
  sort = FALSE
)
rer_work <- merge(
  panel_grid,
  rer_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
rer_work <- rer_work[
  order(rer_work$country_iso3_code, rer_work$year),
]
row.names(rer_work) <- NULL

# Aplicar la transformación definida: logaritmo natural de pl_gdpo.
rer_work$rer <- NA_real_
available_level <- !is.na(rer_work$output_price_level_pwt)
rer_work$rer[available_level] <- log(
  rer_work$output_price_level_pwt[available_level]
)
rer_work$availability_status <- ifelse(
  available_level,
  "observed",
  "missing_in_pwt"
)
rer_panel <- rer_work[, c(
  "country_iso3_code",
  "country",
  "year",
  "rer"
)]

# Validar dimensiones, llaves, período y correspondencia con el insumo.
if (nrow(rer_panel) != expected_row_count) {
  stop(
    "RER debería contener ", expected_row_count,
    " filas y contiene ", nrow(rer_panel), "."
  )
}
if (length(unique(rer_panel$country_iso3_code)) != expected_country_count) {
  stop("RER no conserva exactamente los 55 países de la muestra DRES.")
}
duplicate_keys <- anyDuplicated(
  rer_panel[c("country_iso3_code", "year")]
)
if (duplicate_keys > 0L) {
  stop("RER contiene llaves país-año duplicadas.")
}
if (!all(rer_panel$year %in% analysis_years)) {
  stop("RER contiene años por fuera de 1996-2021.")
}
if (!identical(is.na(rer_work$rer), is.na(rer_work$output_price_level_pwt))) {
  stop("Los faltantes de RER no coinciden con los faltantes de pl_gdpo.")
}
if (any(!is.finite(rer_panel$rer[!is.na(rer_panel$rer)]))) {
  stop("RER contiene valores no finitos.")
}

# Recalcular la fórmula de manera independiente y medir su diferencia.
formula_check <- log(rer_work$output_price_level_pwt[available_level])
formula_difference <- abs(rer_work$rer[available_level] - formula_check)
formula_mismatch_count <- sum(formula_difference > 1e-12)
max_formula_difference <- if (length(formula_difference) == 0L) {
  0
} else {
  max(formula_difference)
}
if (formula_mismatch_count > 0L) {
  stop("La validación independiente encontró diferencias en la fórmula RER.")
}

# Construir diagnósticos de cobertura por país y por año.
coverage_by_country <- do.call(
  rbind,
  lapply(split(rer_work, rer_work$country_iso3_code), function(country_data) {
    observed_years <- country_data$year[!is.na(country_data$rer)]
    available_years <- length(observed_years)
    data.frame(
      country_iso3_code = country_data$country_iso3_code[1],
      country = country_data$country[1],
      expected_years = length(analysis_years),
      available_rer_years = available_years,
      missing_rer_years = length(analysis_years) - available_years,
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
    coverage_by_country$available_rer_years,
    coverage_by_country$country_iso3_code
  ),
]
row.names(coverage_by_country) <- NULL

coverage_by_year <- do.call(
  rbind,
  lapply(split(rer_work, rer_work$year), function(year_data) {
    available_countries <- sum(!is.na(year_data$rer))
    data.frame(
      year = year_data$year[1],
      expected_countries = expected_country_count,
      available_rer_countries = available_countries,
      missing_rer_countries = expected_country_count - available_countries,
      coverage_share = available_countries / expected_country_count,
      stringsAsFactors = FALSE
    )
  })
)
coverage_by_year <- coverage_by_year[order(coverage_by_year$year), ]
row.names(coverage_by_year) <- NULL

# Guardar panel y diagnósticos.
write.csv(
  rer_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  rer_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
write.csv(
  rer_work,
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
if (!identical(as.character(csv_check$country), as.character(dta_check$country))) {
  stop("Las salidas CSV y Stata no conservan los mismos nombres de país.")
}
if (!identical(is.na(csv_check$rer), is.na(dta_check$rer))) {
  stop("Las salidas CSV y Stata no conservan los mismos faltantes de RER.")
}
format_difference <- abs(csv_check$rer - dta_check$rer)
max_csv_stata_difference <- if (all(is.na(format_difference))) {
  0
} else {
  max(format_difference, na.rm = TRUE)
}
if (max_csv_stata_difference > 1e-10) {
  stop("Las salidas CSV y Stata difieren numéricamente.")
}

# Guardar un resumen compacto y auditable de todas las verificaciones.
available_rer <- rer_panel$rer[!is.na(rer_panel$rer)]
available_levels <- rer_work$output_price_level_pwt[available_level]
validation_summary <- data.frame(
  metric = c(
    "start_year",
    "end_year",
    "dres_sample_countries",
    "expected_country_years",
    "actual_country_years",
    "available_rer_country_years",
    "missing_rer_country_years",
    "coverage_percent",
    "countries_with_any_rer",
    "countries_complete_1996_2021",
    "countries_without_rer",
    "duplicate_country_year_keys",
    "nonpositive_or_nonfinite_input_count",
    "nonfinite_rer_count",
    "formula_mismatch_count",
    "formula_max_abs_difference",
    "pl_gdpo_minimum",
    "pl_gdpo_median",
    "pl_gdpo_maximum",
    "rer_minimum",
    "rer_median",
    "rer_maximum",
    "csv_stata_max_abs_difference"
  ),
  value = c(
    start_year,
    end_year,
    expected_country_count,
    expected_row_count,
    nrow(rer_panel),
    length(available_rer),
    sum(is.na(rer_panel$rer)),
    100 * mean(!is.na(rer_panel$rer)),
    sum(coverage_by_country$available_rer_years > 0L),
    sum(coverage_by_country$complete_1996_2021 == 1L),
    sum(coverage_by_country$available_rer_years == 0L),
    duplicate_keys,
    0,
    sum(!is.finite(available_rer)),
    formula_mismatch_count,
    max_formula_difference,
    min(available_levels),
    median(available_levels),
    max(available_levels),
    min(available_rer),
    median(available_rer),
    max(available_rer),
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
message("RER procesada correctamente.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
message(
  "Cobertura: ", length(available_rer), " de ", expected_row_count,
  " país-años (", round(100 * mean(!is.na(rer_panel$rer)), 2), "%)."
)
message(
  "Países completos: ",
  sum(coverage_by_country$complete_1996_2021 == 1L), " de ",
  expected_country_count, "."
)
