# CAPA: PROCESSED
# VARIABLE: VOL
# ENTRADAS: data/raw/vol/imf_ctot/ y data/processed/dres/
# SALIDAS: data/processed/vol/
#
# Construye VOL como la desviación estándar móvil de cinco variaciones
# logarítmicas porcentuales anuales del índice CTOT del FMI con ponderaciones
# fijas. Cada ventana requiere seis niveles consecutivos y no admite imputación.

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

# Definir período, ventana y tamaño de la muestra.
start_year <- 1996L
end_year <- 2021L
analysis_years <- start_year:end_year
rolling_growth_count <- 5L
required_level_count <- rolling_growth_count + 1L
calculation_years <- (
  start_year - rolling_growth_count
):end_year
expected_country_count <- 55L
expected_row_count <- expected_country_count * length(analysis_years)

# Definir entradas y salidas oficiales.
raw_file <- file.path(
  project_path,
  "data",
  "raw",
  "vol",
  "imf_ctot",
  "vol_ctot_input_1962_2022.csv"
)
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
processed_path <- file.path(project_path, "data", "processed", "vol")
panel_csv_file <- file.path(processed_path, "vol_data.csv")
panel_dta_file <- file.path(processed_path, "vol_data.dta")
diagnostics_file <- file.path(
  processed_path,
  "vol_country_year_diagnostics_1996_2021.csv"
)
country_coverage_file <- file.path(
  processed_path,
  "vol_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  processed_path,
  "vol_year_coverage_1996_2021.csv"
)
validation_file <- file.path(
  processed_path,
  "vol_validation_summary.csv"
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

# Leer los niveles CTOT con ponderaciones fijas.
ctot_raw <- read.csv(
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
  "ctot_net_export_price_fixed"
)
missing_raw_columns <- setdiff(required_raw_columns, names(ctot_raw))
if (length(missing_raw_columns) > 0L) {
  stop(
    "Faltan columnas en el insumo CTOT: ",
    paste(missing_raw_columns, collapse = ", ")
  )
}
ctot_raw <- ctot_raw[, required_raw_columns]
ctot_raw$country_iso3_code <- toupper(trimws(ctot_raw$country_iso3_code))
ctot_raw$year <- as.integer(ctot_raw$year)
ctot_raw$ctot_net_export_price_fixed <- as.numeric(
  ctot_raw$ctot_net_export_price_fixed
)
if (
  any(!grepl("^[A-Z]{3}$", ctot_raw$country_iso3_code)) ||
    any(is.na(ctot_raw$year))
) {
  stop("El insumo CTOT contiene códigos ISO3 o años inválidos.")
}
if (anyDuplicated(ctot_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("El insumo CTOT contiene llaves país-año duplicadas.")
}
observed_ctot <- !is.na(ctot_raw$ctot_net_export_price_fixed)
if (
  any(
    ctot_raw$ctot_net_export_price_fixed[observed_ctot] <= 0 |
      !is.finite(
        ctot_raw$ctot_net_export_price_fixed[observed_ctot]
      )
  )
) {
  stop("El índice CTOT contiene valores no positivos o no finitos.")
}

# Crear una cuadrícula que incluye los cinco años previos necesarios.
ctot_selected <- ctot_raw[
  ctot_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    ctot_raw$year %in% calculation_years,
  c("country_iso3_code", "year", "ctot_net_export_price_fixed"),
  drop = FALSE
]
calculation_grid <- merge(
  dres_sample,
  data.frame(year = calculation_years),
  by = NULL,
  sort = FALSE
)
ctot_work <- merge(
  calculation_grid,
  ctot_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
ctot_work <- ctot_work[
  order(ctot_work$country_iso3_code, ctot_work$year),
]
row.names(ctot_work) <- NULL

# Calcular variaciones y ventanas de forma independiente para cada país.
calculate_country_volatility <- function(country_data) {
  country_data <- country_data[order(country_data$year), ]
  level <- country_data$ctot_net_export_price_fixed
  country_data$ctot_log_change_pct <- c(
    NA_real_,
    100 * diff(log(level))
  )
  country_data$window_level_count <- NA_integer_
  country_data$window_growth_count <- NA_integer_
  country_data$vol <- NA_real_
  for (target_year in analysis_years) {
    target_row <- which(country_data$year == target_year)
    level_rows <- country_data$year %in% (
      target_year - rolling_growth_count
    ):target_year
    growth_rows <- country_data$year %in% (
      target_year - rolling_growth_count + 1L
    ):target_year
    level_count <- sum(
      !is.na(country_data$ctot_net_export_price_fixed[level_rows])
    )
    growth_count <- sum(
      !is.na(country_data$ctot_log_change_pct[growth_rows])
    )
    country_data$window_level_count[target_row] <- level_count
    country_data$window_growth_count[target_row] <- growth_count
    if (
      level_count == required_level_count &&
        growth_count == rolling_growth_count
    ) {
      country_data$vol[target_row] <- sd(
        country_data$ctot_log_change_pct[growth_rows]
      )
    }
  }
  country_data[country_data$year %in% analysis_years, ]
}
vol_parts <- lapply(
  split(ctot_work, ctot_work$country_iso3_code),
  calculate_country_volatility
)
vol_diagnostics <- do.call(rbind, vol_parts)
vol_diagnostics <- vol_diagnostics[
  order(vol_diagnostics$country_iso3_code, vol_diagnostics$year),
]
row.names(vol_diagnostics) <- NULL
vol_panel <- vol_diagnostics[, c(
  "country_iso3_code",
  "country",
  "year",
  "vol"
)]

# Validar dimensiones, llaves y regla de ventana completa.
if (
  nrow(vol_panel) != expected_row_count ||
    length(unique(vol_panel$country_iso3_code)) != expected_country_count
) {
  stop("VOL no conserva la cuadrícula esperada de 55 países por 26 años.")
}
duplicate_keys <- anyDuplicated(
  vol_panel[c("country_iso3_code", "year")]
)
if (duplicate_keys > 0L) {
  stop("VOL contiene llaves país-año duplicadas.")
}
eligible_window <- (
  vol_diagnostics$window_level_count == required_level_count &
    vol_diagnostics$window_growth_count == rolling_growth_count
)
if (any(!eligible_window & !is.na(vol_diagnostics$vol))) {
  stop("Se calculó VOL con una ventana incompleta.")
}
if (any(eligible_window & is.na(vol_diagnostics$vol))) {
  stop("Existen ventanas completas sin un valor calculado de VOL.")
}
if (any(vol_panel$vol < 0, na.rm = TRUE)) {
  stop("VOL contiene valores negativos.")
}

# Recalcular las desviaciones estándar como control de fórmula.
formula_mismatch_count <- 0L
for (country_code in unique(ctot_work$country_iso3_code)) {
  country_data <- ctot_work[
    ctot_work$country_iso3_code == country_code,
  ]
  country_data <- country_data[order(country_data$year), ]
  growth <- c(
    NA_real_,
    100 * diff(log(country_data$ctot_net_export_price_fixed))
  )
  for (target_year in analysis_years) {
    output_value <- vol_panel$vol[
      vol_panel$country_iso3_code == country_code &
        vol_panel$year == target_year
    ]
    growth_window <- growth[
      country_data$year %in% (
        target_year - rolling_growth_count + 1L
      ):target_year
    ]
    expected_value <- if (
      length(growth_window) == rolling_growth_count &&
        all(!is.na(growth_window))
    ) {
      sd(growth_window)
    } else {
      NA_real_
    }
    mismatch <- (
      xor(is.na(output_value), is.na(expected_value)) ||
        (
          !is.na(output_value) &&
            abs(output_value - expected_value) > 1e-12
        )
    )
    formula_mismatch_count <- formula_mismatch_count + as.integer(mismatch)
  }
}
if (formula_mismatch_count > 0L) {
  stop("La validación independiente encontró diferencias en la fórmula VOL.")
}

# Construir diagnósticos de cobertura.
coverage_by_country <- do.call(
  rbind,
  lapply(split(vol_diagnostics, vol_diagnostics$country_iso3_code), function(x) {
    observed_years <- x$year[!is.na(x$vol)]
    available_years <- length(observed_years)
    data.frame(
      country_iso3_code = x$country_iso3_code[1],
      country = x$country[1],
      expected_years = length(analysis_years),
      available_vol_years = available_years,
      missing_vol_years = length(analysis_years) - available_years,
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
    coverage_by_country$available_vol_years,
    coverage_by_country$country_iso3_code
  ),
]
row.names(coverage_by_country) <- NULL

coverage_by_year <- do.call(
  rbind,
  lapply(split(vol_diagnostics, vol_diagnostics$year), function(x) {
    available_countries <- sum(!is.na(x$vol))
    data.frame(
      year = x$year[1],
      expected_countries = expected_country_count,
      available_vol_countries = available_countries,
      missing_vol_countries = expected_country_count - available_countries,
      coverage_share = available_countries / expected_country_count,
      mean_vol = mean(x$vol, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
)
coverage_by_year <- coverage_by_year[order(coverage_by_year$year), ]
row.names(coverage_by_year) <- NULL

# Guardar panel y diagnósticos.
write.csv(
  vol_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  vol_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
write.csv(
  vol_diagnostics,
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
if (!identical(is.na(csv_check$vol), is.na(dta_check$vol))) {
  stop("Las salidas CSV y Stata no conservan los mismos faltantes de VOL.")
}
format_difference <- abs(csv_check$vol - dta_check$vol)
max_csv_stata_difference <- max(format_difference, na.rm = TRUE)
if (max_csv_stata_difference > 1e-10) {
  stop("Las salidas CSV y Stata difieren numéricamente.")
}

# Guardar un resumen auditable.
validation_summary <- data.frame(
  metric = c(
    "start_year",
    "end_year",
    "rolling_growth_count",
    "required_level_count",
    "dres_sample_countries",
    "expected_country_years",
    "actual_country_years",
    "available_vol_country_years",
    "missing_vol_country_years",
    "vol_coverage_percent",
    "countries_with_any_vol",
    "countries_complete_1996_2021",
    "countries_without_vol",
    "rows_with_complete_six_level_window",
    "rows_with_incomplete_window",
    "negative_vol",
    "vol_minimum",
    "vol_median",
    "vol_mean",
    "vol_p99",
    "vol_maximum",
    "duplicate_country_year_keys",
    "formula_mismatch_count",
    "csv_stata_max_abs_difference"
  ),
  value = c(
    start_year,
    end_year,
    rolling_growth_count,
    required_level_count,
    expected_country_count,
    expected_row_count,
    nrow(vol_panel),
    sum(!is.na(vol_panel$vol)),
    sum(is.na(vol_panel$vol)),
    100 * mean(!is.na(vol_panel$vol)),
    sum(coverage_by_country$available_vol_years > 0L),
    sum(coverage_by_country$complete_1996_2021 == 1L),
    sum(coverage_by_country$available_vol_years == 0L),
    sum(eligible_window),
    sum(!eligible_window),
    sum(vol_panel$vol < 0, na.rm = TRUE),
    min(vol_panel$vol, na.rm = TRUE),
    median(vol_panel$vol, na.rm = TRUE),
    mean(vol_panel$vol, na.rm = TRUE),
    unname(quantile(vol_panel$vol, 0.99, na.rm = TRUE)),
    max(vol_panel$vol, na.rm = TRUE),
    duplicate_keys,
    formula_mismatch_count,
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

message("VOL procesada correctamente.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
message(
  "Cobertura: ", sum(!is.na(vol_panel$vol)), " de ",
  expected_row_count, " país-años (",
  round(100 * mean(!is.na(vol_panel$vol)), 2), "%)."
)
