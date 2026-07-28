# CAPA: PROCESSED
# VARIABLE: NET
# ENTRADAS: data/raw/net/world_bank_wdi/ y data/processed/dres/
# SALIDAS: data/processed/net/
#
# Construye NET conservando en su escala porcentual el indicador de personas
# que utilizan internet (IT.NET.USER.ZS). No transforma, interpola ni imputa.

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
  "net",
  "world_bank_wdi",
  "net_wdi_input_1980_2022.csv"
)
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
processed_path <- file.path(project_path, "data", "processed", "net")
panel_csv_file <- file.path(processed_path, "net_data.csv")
panel_dta_file <- file.path(processed_path, "net_data.dta")
diagnostics_file <- file.path(
  processed_path,
  "net_country_year_diagnostics_1996_2021.csv"
)
country_coverage_file <- file.path(
  processed_path,
  "net_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  processed_path,
  "net_year_coverage_1996_2021.csv"
)
validation_file <- file.path(
  processed_path,
  "net_validation_summary.csv"
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
net_raw <- read.csv(
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
  "internet_users_pct_population"
)
missing_raw_columns <- setdiff(required_raw_columns, names(net_raw))
if (length(missing_raw_columns) > 0L) {
  stop(
    "Faltan columnas en el insumo WDI: ",
    paste(missing_raw_columns, collapse = ", ")
  )
}
net_raw <- net_raw[, required_raw_columns]
net_raw$country_iso3_code <- toupper(trimws(net_raw$country_iso3_code))
net_raw$year <- as.integer(net_raw$year)
net_raw$internet_users_pct_population <- as.numeric(
  net_raw$internet_users_pct_population
)
if (
  any(!grepl("^[A-Z]{3}$", net_raw$country_iso3_code)) ||
    any(is.na(net_raw$year))
) {
  stop("El insumo WDI contiene códigos ISO3 o años inválidos.")
}
if (anyDuplicated(net_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("El insumo WDI contiene llaves país-año duplicadas.")
}
observed_net <- !is.na(net_raw$internet_users_pct_population)
if (
  any(
    net_raw$internet_users_pct_population[observed_net] < 0 |
      net_raw$internet_users_pct_population[observed_net] > 100 |
      !is.finite(net_raw$internet_users_pct_population[observed_net])
  )
) {
  stop("El porcentaje de usuarios de internet contiene valores inválidos.")
}

# Seleccionar el período y construir la cuadrícula completa de 55 países.
net_selected <- net_raw[
  net_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    net_raw$year %in% analysis_years,
  c("country_iso3_code", "year", "internet_users_pct_population"),
  drop = FALSE
]
panel_grid <- merge(
  dres_sample,
  data.frame(year = analysis_years),
  by = NULL,
  sort = FALSE
)
net_work <- merge(
  panel_grid,
  net_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
net_work <- net_work[
  order(net_work$country_iso3_code, net_work$year),
]
row.names(net_work) <- NULL

# Conservar el porcentaje en niveles y marcar explícitamente los faltantes.
net_work$net <- net_work$internet_users_pct_population
net_work$availability_status <- ifelse(
  is.na(net_work$net),
  "missing_in_wdi",
  "observed"
)
net_panel <- net_work[, c(
  "country_iso3_code",
  "country",
  "year",
  "net"
)]

# Validar dimensiones, llaves, período, dominio y correspondencia con raw.
if (nrow(net_panel) != expected_row_count) {
  stop(
    "NET debería contener ", expected_row_count,
    " filas y contiene ", nrow(net_panel), "."
  )
}
if (length(unique(net_panel$country_iso3_code)) != expected_country_count) {
  stop("NET no conserva exactamente los 55 países de la muestra DRES.")
}
duplicate_keys <- anyDuplicated(net_panel[c("country_iso3_code", "year")])
if (duplicate_keys > 0L) {
  stop("NET contiene llaves país-año duplicadas.")
}
if (!all(net_panel$year %in% analysis_years)) {
  stop("NET contiene años por fuera de 1996-2021.")
}
if (
  !identical(
    is.na(net_work$net),
    is.na(net_work$internet_users_pct_population)
  )
) {
  stop("Los faltantes de NET no coinciden con los faltantes del indicador.")
}
available_net <- net_panel$net[!is.na(net_panel$net)]
if (
  any(!is.finite(available_net)) ||
    any(available_net < 0) ||
    any(available_net > 100)
) {
  stop("NET contiene valores fuera del rango porcentual 0-100.")
}

# Comprobar que no se aplicó ninguna transformación al valor publicado.
identity_difference <- abs(
  net_work$net[!is.na(net_work$net)] -
    net_work$internet_users_pct_population[
      !is.na(net_work$internet_users_pct_population)
    ]
)
identity_mismatch_count <- sum(identity_difference > 0)
max_identity_difference <- if (length(identity_difference) == 0L) {
  0
} else {
  max(identity_difference)
}
if (identity_mismatch_count > 0L) {
  stop("NET no coincide exactamente con el porcentaje publicado por WDI.")
}

# Construir diagnósticos de cobertura por país y por año.
coverage_by_country <- do.call(
  rbind,
  lapply(split(net_work, net_work$country_iso3_code), function(country_data) {
    observed_years <- country_data$year[!is.na(country_data$net)]
    missing_years <- country_data$year[is.na(country_data$net)]
    available_years <- length(observed_years)
    data.frame(
      country_iso3_code = country_data$country_iso3_code[1],
      country = country_data$country[1],
      expected_years = length(analysis_years),
      available_net_years = available_years,
      missing_net_years = length(analysis_years) - available_years,
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
  })
)
coverage_by_country <- coverage_by_country[
  order(
    coverage_by_country$available_net_years,
    coverage_by_country$country_iso3_code
  ),
]
row.names(coverage_by_country) <- NULL

coverage_by_year <- do.call(
  rbind,
  lapply(split(net_work, net_work$year), function(year_data) {
    available_countries <- sum(!is.na(year_data$net))
    data.frame(
      year = year_data$year[1],
      expected_countries = expected_country_count,
      available_net_countries = available_countries,
      missing_net_countries = expected_country_count - available_countries,
      zero_value_countries = sum(year_data$net == 0, na.rm = TRUE),
      coverage_share = available_countries / expected_country_count,
      stringsAsFactors = FALSE
    )
  })
)
coverage_by_year <- coverage_by_year[order(coverage_by_year$year), ]
row.names(coverage_by_year) <- NULL

# Guardar panel y diagnósticos.
write.csv(
  net_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  net_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
write.csv(
  net_work,
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
if (!identical(is.na(csv_check$net), is.na(dta_check$net))) {
  stop("Las salidas CSV y Stata no conservan los mismos faltantes.")
}
format_difference <- abs(csv_check$net - dta_check$net)
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
    "available_net_country_years",
    "missing_net_country_years",
    "coverage_percent",
    "countries_with_any_net",
    "countries_complete_1996_2021",
    "countries_with_partial_coverage",
    "countries_without_net",
    "duplicate_country_year_keys",
    "out_of_range_or_nonfinite_count",
    "zero_value_country_years",
    "identity_mismatch_count",
    "identity_max_abs_difference",
    "net_minimum",
    "net_median",
    "net_maximum",
    "csv_stata_max_abs_difference"
  ),
  value = c(
    start_year,
    end_year,
    expected_country_count,
    expected_row_count,
    nrow(net_panel),
    length(available_net),
    sum(is.na(net_panel$net)),
    100 * mean(!is.na(net_panel$net)),
    sum(coverage_by_country$available_net_years > 0L),
    sum(coverage_by_country$complete_1996_2021 == 1L),
    sum(
      coverage_by_country$available_net_years > 0L &
        coverage_by_country$available_net_years <
          length(analysis_years)
    ),
    sum(coverage_by_country$available_net_years == 0L),
    duplicate_keys,
    0,
    sum(net_work$net == 0, na.rm = TRUE),
    identity_mismatch_count,
    max_identity_difference,
    min(available_net),
    median(available_net),
    max(available_net),
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
message("NET procesada correctamente.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
message(
  "Cobertura: ", length(available_net), " de ", expected_row_count,
  " país-años (",
  round(100 * mean(!is.na(net_panel$net)), 2), "%)."
)
message(
  "Países completos: ",
  sum(coverage_by_country$complete_1996_2021 == 1L), " de ",
  expected_country_count, "."
)
