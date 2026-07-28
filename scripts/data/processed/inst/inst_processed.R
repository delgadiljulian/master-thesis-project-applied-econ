# CAPA: PROCESSED
# VARIABLE: INST
# ENTRADAS: data/raw/inst/ y data/processed/dres/
# SALIDAS: data/processed/inst/
#
# Construye INST como el promedio simple de los estimadores WGI de control de
# la corrupción, Estado de derecho y efectividad gubernamental. El índice solo
# se calcula cuando los tres componentes están observados. No se interpola ni
# se imputan los años estructuralmente ausentes de WGI.

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
structural_missing_years <- c(1997L, 1999L, 2001L)
published_years <- setdiff(analysis_years, structural_missing_years)
expected_country_count <- 55L
expected_row_count <- expected_country_count * length(analysis_years)
expected_published_cells <- expected_country_count * length(published_years)

# Identificar los tres estimadores WGI utilizados en el promedio.
component_columns <- c(
  "control_of_corruption_est",
  "rule_of_law_est",
  "government_effectiveness_est"
)

# Definir entradas y salidas oficiales.
raw_file <- file.path(
  project_path,
  "data",
  "raw",
  "inst",
  "world_bank_wgi",
  "inst_wgi_inputs_1996_2024.csv"
)
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
processed_path <- file.path(project_path, "data", "processed", "inst")
panel_csv_file <- file.path(processed_path, "inst_data.csv")
panel_dta_file <- file.path(processed_path, "inst_data.dta")
country_coverage_file <- file.path(
  processed_path,
  "inst_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  processed_path,
  "inst_year_coverage_1996_2021.csv"
)
validation_file <- file.path(
  processed_path,
  "inst_validation_summary.csv"
)

# Comprobar que las entradas estén disponibles.
required_files <- c(raw_file, sample_file)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0L) {
  stop("Faltan archivos requeridos: ", paste(missing_files, collapse = ", "))
}
if (!requireNamespace("foreign", quietly = TRUE)) {
  stop("Falta el paquete de R 'foreign', requerido para la salida Stata.")
}
dir.create(processed_path, recursive = TRUE, showWarnings = FALSE)

# Detectar archivos abiertos antes de reemplazar las salidas reproducibles.
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

# Leer y validar la muestra fija DRES de 55 países.
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
if (anyDuplicated(dres_sample$country_iso3_code) > 0L) {
  stop("La muestra DRES contiene códigos de país duplicados.")
}
if (nrow(dres_sample) != expected_country_count) {
  stop(
    "Se esperaban ", expected_country_count,
    " países DRES y se encontraron ", nrow(dres_sample), "."
  )
}
dres_sample <- dres_sample[order(dres_sample$country_iso3_code), ]
row.names(dres_sample) <- NULL

# Leer los tres componentes WGI sin modificar la capa raw.
inst_raw <- read.csv(
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
  component_columns
)
missing_raw_columns <- setdiff(required_raw_columns, names(inst_raw))
if (length(missing_raw_columns) > 0L) {
  stop(
    "Faltan columnas en los insumos raw: ",
    paste(missing_raw_columns, collapse = ", ")
  )
}
inst_raw <- inst_raw[, required_raw_columns]
inst_raw$country_iso3_code <- toupper(trimws(inst_raw$country_iso3_code))
inst_raw$year <- as.integer(inst_raw$year)
for (column_name in component_columns) {
  inst_raw[[column_name]] <- as.numeric(inst_raw[[column_name]])
}
if (
  any(!grepl("^[A-Z]{3}$", inst_raw$country_iso3_code)) ||
    any(is.na(inst_raw$year))
) {
  stop("Los insumos raw contienen códigos ISO3 o años inválidos.")
}
if (anyDuplicated(inst_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("Los insumos raw contienen llaves país-año duplicadas.")
}
# La escala publicada por WGI es aproximadamente de -2,5 a 2,5.
for (column_name in component_columns) {
  if (any(abs(inst_raw[[column_name]]) > 3, na.rm = TRUE)) {
    stop("El componente ", column_name, " contiene valores fuera de [-3, 3].")
  }
}

# Seleccionar exclusivamente los países y años del período econométrico.
inst_selected <- inst_raw[
  inst_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    inst_raw$year %in% analysis_years,
  c("country_iso3_code", "year", component_columns),
  drop = FALSE
]

# Crear la cuadrícula completa y conservar explícitamente todos los faltantes.
panel_grid <- merge(
  dres_sample,
  data.frame(year = analysis_years),
  by = NULL,
  sort = FALSE
)
inst_work <- merge(
  panel_grid,
  inst_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
inst_work <- inst_work[
  order(inst_work$country_iso3_code, inst_work$year),
]
row.names(inst_work) <- NULL

# Construir el promedio solo cuando los tres componentes están disponibles.
component_count <- rowSums(!is.na(inst_work[, component_columns]))
all_components_observed <- component_count == length(component_columns)
inst_work$inst <- NA_real_
inst_work$inst[all_components_observed] <- rowMeans(
  inst_work[all_components_observed, component_columns, drop = FALSE]
)
inst_panel <- inst_work[, c(
  "country_iso3_code",
  "country",
  "year",
  "inst"
)]

# Validar dimensiones, llaves, período y regla de observación conjunta.
if (nrow(inst_panel) != expected_row_count) {
  stop(
    "INST debería contener ", expected_row_count,
    " filas y contiene ", nrow(inst_panel), "."
  )
}
if (length(unique(inst_panel$country_iso3_code)) != expected_country_count) {
  stop("INST no conserva exactamente los 55 países de la muestra DRES.")
}
duplicate_keys <- anyDuplicated(
  inst_panel[c("country_iso3_code", "year")]
)
if (duplicate_keys > 0L) {
  stop("INST contiene llaves país-año duplicadas.")
}
if (!all(inst_panel$year %in% analysis_years)) {
  stop("INST contiene años por fuera de 1996-2021.")
}
if (any(!all_components_observed & !is.na(inst_work$inst))) {
  stop("Se calculó INST en filas con uno o más componentes faltantes.")
}
if (any(all_components_observed & is.na(inst_work$inst))) {
  stop("Existen filas completas sin un valor calculado de INST.")
}

# Recalcular el promedio para verificar la fórmula de manera independiente.
formula_check <- rowMeans(
  inst_work[all_components_observed, component_columns, drop = FALSE]
)
formula_difference <- abs(
  inst_work$inst[all_components_observed] - formula_check
)
formula_mismatch_count <- sum(formula_difference > 1e-12)
if (formula_mismatch_count > 0L) {
  stop("La validación independiente encontró diferencias en la fórmula INST.")
}
range_violation_count <- sum(abs(inst_panel$inst) > 3, na.rm = TRUE)
if (range_violation_count > 0L) {
  stop("INST contiene valores fuera del rango plausible [-3, 3].")
}

# Verificar que los años no publicados por WGI permanezcan completamente vacíos.
structural_rows <- inst_work$year %in% structural_missing_years
structural_missing_cells <- sum(is.na(inst_work$inst[structural_rows]))
if (
  structural_missing_cells !=
    expected_country_count * length(structural_missing_years)
) {
  stop("Los vacíos estructurales de WGI no se conservaron correctamente.")
}
nonstructural_missing_cells <- sum(
  is.na(inst_work$inst) & !structural_rows
)

# Construir el diagnóstico de cobertura para cada país.
coverage_by_country <- do.call(
  rbind,
  lapply(split(inst_work, inst_work$country_iso3_code), function(country_data) {
    published_country_data <- country_data[
      country_data$year %in% published_years,
    ]
    observed_years <- country_data$year[!is.na(country_data$inst)]
    available_years <- length(observed_years)
    data.frame(
      country_iso3_code = country_data$country_iso3_code[1],
      country = country_data$country[1],
      expected_years = length(analysis_years),
      wgi_published_years = length(published_years),
      available_inst_years = available_years,
      structural_missing_years = length(structural_missing_years),
      country_specific_missing_years = sum(
        is.na(published_country_data$inst)
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
      full_period_coverage_share = (
        available_years / length(analysis_years)
      ),
      published_years_coverage_share = (
        available_years / length(published_years)
      ),
      complete_in_published_years = as.integer(
        available_years == length(published_years)
      ),
      stringsAsFactors = FALSE
    )
  })
)
coverage_by_country <- coverage_by_country[
  order(
    coverage_by_country$available_inst_years,
    coverage_by_country$country_iso3_code
  ),
]
row.names(coverage_by_country) <- NULL

# Construir el diagnóstico anual y marcar los vacíos estructurales.
coverage_by_year <- do.call(
  rbind,
  lapply(split(inst_work, inst_work$year), function(year_data) {
    available_countries <- sum(!is.na(year_data$inst))
    data.frame(
      year = year_data$year[1],
      wgi_published_year = as.integer(
        !(year_data$year[1] %in% structural_missing_years)
      ),
      expected_countries = expected_country_count,
      available_inst_countries = available_countries,
      missing_inst_countries = expected_country_count - available_countries,
      coverage_share = available_countries / expected_country_count,
      stringsAsFactors = FALSE
    )
  })
)
coverage_by_year <- coverage_by_year[order(coverage_by_year$year), ]
row.names(coverage_by_year) <- NULL

# Guardar el panel procesado y los dos diagnósticos de cobertura.
write.csv(
  inst_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  inst_panel,
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
if (!identical(is.na(csv_check$inst), is.na(dta_check$inst))) {
  stop("Las salidas CSV y Stata no conservan los mismos faltantes de INST.")
}
format_difference <- abs(csv_check$inst - dta_check$inst)
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
    "structural_missing_year_count",
    "wgi_published_year_count",
    "expected_country_years",
    "expected_published_country_years",
    "actual_country_years",
    "available_inst_country_years",
    "missing_inst_country_years",
    "full_period_coverage_percent",
    "published_years_coverage_percent",
    "structural_missing_country_years",
    "country_specific_missing_country_years",
    "countries_with_any_inst",
    "countries_complete_in_published_years",
    "countries_without_inst",
    "rows_with_all_three_components",
    "rows_with_partial_components",
    "rows_with_all_components_missing",
    "duplicate_country_year_keys",
    "range_violation_count",
    "formula_mismatch_count",
    "csv_stata_max_abs_difference"
  ),
  value = c(
    start_year,
    end_year,
    expected_country_count,
    length(structural_missing_years),
    length(published_years),
    expected_row_count,
    expected_published_cells,
    nrow(inst_panel),
    sum(!is.na(inst_panel$inst)),
    sum(is.na(inst_panel$inst)),
    100 * mean(!is.na(inst_panel$inst)),
    100 * sum(!is.na(inst_panel$inst)) / expected_published_cells,
    structural_missing_cells,
    nonstructural_missing_cells,
    sum(coverage_by_country$available_inst_years > 0L),
    sum(coverage_by_country$complete_in_published_years == 1L),
    sum(coverage_by_country$available_inst_years == 0L),
    sum(all_components_observed),
    sum(
      component_count > 0L &
        component_count < length(component_columns)
    ),
    sum(component_count == 0L),
    duplicate_keys,
    range_violation_count,
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

# Mostrar un resumen compacto al finalizar correctamente.
message("INST procesada correctamente.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
message(
  "Cobertura total: ", sum(!is.na(inst_panel$inst)), " de ",
  expected_row_count, " país-años (",
  round(100 * mean(!is.na(inst_panel$inst)), 2), "%)."
)
message(
  "Cobertura en años publicados: ", sum(!is.na(inst_panel$inst)), " de ",
  expected_published_cells, " país-años (",
  round(
    100 * sum(!is.na(inst_panel$inst)) / expected_published_cells,
    2
  ), "%)."
)
