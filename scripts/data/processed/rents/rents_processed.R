# CAPA: PROCESSED
# VARIABLE: RENTS
# ENTRADAS: data/raw/rents/ y data/processed/dres/
# SALIDAS: data/processed/rents/
#
# Construye tres medidas como porcentaje del PIB:
# - RENTS: petróleo + gas natural + carbón + minerales;
# - RENTS_OIL_GAS: petróleo + gas natural;
# - RENTS_MINING: carbón + minerales.
# Cada suma se calcula únicamente cuando todos sus componentes están observados;
# los faltantes nunca se sustituyen por cero.

# Reunir las ubicaciones posibles del helper compartido de rutas del proyecto.
helper_path <- c(
  # Buscar desde la ubicación del archivo activo cuando se utiliza RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(
      dirname(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)))),
      "project_paths.R"
    )
  },
  # Buscar cuando R se ejecuta desde la raíz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Buscar cuando el directorio de trabajo es scripts/data/processed/rents/.
  file.path("..", "..", "..", "project_paths.R"),
  # Buscar cuando el directorio de trabajo es scripts/.
  file.path("..", "project_paths.R"),
  # Buscar en el directorio de trabajo actual como última alternativa.
  "project_paths.R"
)

# Conservar la primera ubicación candidata que exista.
helper_path <- helper_path[file.exists(helper_path)][1]
# Interrumpir la ejecución si no se encuentra el helper del proyecto.
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}

# Cargar la función que localiza la raíz del repositorio.
source(helper_path)
# Obtener la ruta absoluta del proyecto sin depender del directorio de trabajo.
project_path <- find_project_path()

# Definir el período econométrico aprobado para la tesis.
start_year <- 1996L
end_year <- 2021L
analysis_years <- start_year:end_year

# Registrar el tamaño fijo de la muestra seleccionada mediante DRES >= 20 %.
expected_country_count <- 55L
# Calcular el tamaño esperado de la cuadrícula país-año.
expected_row_count <- expected_country_count * length(analysis_years)

# Identificar las cuatro columnas raw requeridas para construir RENTS.
component_columns <- c(
  "oil_rents_pct_gdp",
  "natural_gas_rents_pct_gdp",
  "coal_rents_pct_gdp",
  "mineral_rents_pct_gdp"
)
# Agrupar petróleo y gas como rentas de hidrocarburos.
oil_gas_component_columns <- c(
  "oil_rents_pct_gdp",
  "natural_gas_rents_pct_gdp"
)
# Agrupar carbón y minerales como rentas mineras.
mining_component_columns <- c(
  "coal_rents_pct_gdp",
  "mineral_rents_pct_gdp"
)

# Localizar el extracto raw que conserva los cuatro componentes WDI.
raw_file <- file.path(
  project_path,
  "data",
  "raw",
  "rents",
  "world_bank_wdi",
  "rents_wdi_inputs_1980_2022.csv"
)
# Localizar la lista fija de 55 países seleccionados mediante DRES.
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
# Definir la carpeta donde se guardará la variable procesada.
processed_path <- file.path(project_path, "data", "processed", "rents")

# Definir los nombres oficiales de las salidas procesadas.
panel_csv_file <- file.path(processed_path, "rents_data.csv")
panel_dta_file <- file.path(processed_path, "rents_data.dta")
coverage_file <- file.path(
  processed_path,
  "rents_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  processed_path,
  "rents_year_coverage_1996_2021.csv"
)
validation_file <- file.path(processed_path, "rents_validation_summary.csv")

# Interrumpir la ejecución si falta alguno de los dos insumos requeridos.
required_files <- c(raw_file, sample_file)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0L) {
  stop("Faltan archivos requeridos: ", paste(missing_files, collapse = ", "))
}

# Exigir la biblioteca utilizada para escribir y releer archivos Stata.
if (!requireNamespace("foreign", quietly = TRUE)) {
  stop("Falta el paquete de R 'foreign', requerido para la salida Stata.")
}

# Crear la carpeta de salida si todavía no existe.
dir.create(processed_path, recursive = TRUE, showWarnings = FALSE)

# Reunir todas las salidas que serán reemplazadas de forma reproducible.
official_output_files <- c(
  panel_csv_file,
  panel_dta_file,
  coverage_file,
  year_coverage_file,
  validation_file
)
# Comprobar que ningún archivo de salida existente esté bloqueado.
for (output_file in official_output_files[file.exists(official_output_files)]) {
  output_connection <- try(file(output_file, open = "ab"), silent = TRUE)
  if (inherits(output_connection, "try-error")) {
    stop("Cierre el archivo antes de ejecutar el script: ", output_file)
  }
  close(output_connection)
}

# Leer la muestra DRES como texto para preservar los códigos y nombres.
dres_sample <- read.csv(
  sample_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
# Verificar que la muestra contenga las columnas de identificación necesarias.
required_sample_columns <- c("country_iso3_code", "country")
missing_sample_columns <- setdiff(required_sample_columns, names(dres_sample))
if (length(missing_sample_columns) > 0L) {
  stop(
    "Faltan columnas en la muestra DRES: ",
    paste(missing_sample_columns, collapse = ", ")
  )
}

# Conservar únicamente los identificadores utilizados en el panel.
dres_sample <- dres_sample[, required_sample_columns]
# Normalizar los códigos ISO3 y retirar espacios laterales de los nombres.
dres_sample$country_iso3_code <- toupper(trimws(dres_sample$country_iso3_code))
dres_sample$country <- trimws(dres_sample$country)
# Detener el script si existen identificadores vacíos o códigos no válidos.
if (
  any(!grepl("^[A-Z]{3}$", dres_sample$country_iso3_code)) ||
    any(!nzchar(dres_sample$country))
) {
  stop("La muestra DRES contiene códigos ISO3 o nombres de país inválidos.")
}
# Detener el script si un país aparece más de una vez.
if (anyDuplicated(dres_sample$country_iso3_code) > 0L) {
  stop("La muestra DRES contiene códigos de país duplicados.")
}
# Detener el script si la muestra ya no contiene exactamente 55 países.
if (nrow(dres_sample) != expected_country_count) {
  stop(
    "Se esperaban ", expected_country_count,
    " países DRES y se encontraron ", nrow(dres_sample), "."
  )
}
# Ordenar la muestra para producir resultados deterministas.
dres_sample <- dres_sample[order(dres_sample$country_iso3_code), ]
row.names(dres_sample) <- NULL

# Leer los cuatro componentes raw sin convertir automáticamente los textos.
rents_raw <- read.csv(
  raw_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  fileEncoding = "UTF-8"
)
# Definir la estructura mínima requerida en el archivo raw.
required_raw_columns <- c(
  "country_iso3_code",
  "country",
  "year",
  component_columns
)
# Interrumpir la ejecución si cambió la estructura del extracto raw.
missing_raw_columns <- setdiff(required_raw_columns, names(rents_raw))
if (length(missing_raw_columns) > 0L) {
  stop(
    "Faltan columnas en los insumos raw: ",
    paste(missing_raw_columns, collapse = ", ")
  )
}

# Conservar únicamente los identificadores y componentes necesarios.
rents_raw <- rents_raw[, required_raw_columns]
# Normalizar los códigos de país y convertir el año a entero.
rents_raw$country_iso3_code <- toupper(trimws(rents_raw$country_iso3_code))
rents_raw$year <- as.integer(rents_raw$year)
# Convertir explícitamente los cuatro componentes a valores numéricos.
for (column_name in component_columns) {
  rents_raw[[column_name]] <- as.numeric(rents_raw[[column_name]])
}

# Detener el script si el raw contiene códigos o años no identificables.
if (
  any(!grepl("^[A-Z]{3}$", rents_raw$country_iso3_code)) ||
    any(is.na(rents_raw$year))
) {
  stop("Los insumos raw contienen códigos ISO3 o años inválidos.")
}
# Detener el script si existe más de una observación para el mismo país-año.
if (anyDuplicated(rents_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("Los insumos raw contienen llaves país-año duplicadas.")
}
# Las rentas publicadas como porcentaje del PIB no pueden ser negativas.
for (column_name in component_columns) {
  if (any(rents_raw[[column_name]] < 0, na.rm = TRUE)) {
    stop("El componente ", column_name, " contiene valores negativos.")
  }
}

# Conservar solo los países y años pertenecientes al período econométrico.
rents_selected <- rents_raw[
  rents_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    rents_raw$year %in% analysis_years,
  c("country_iso3_code", "year", component_columns),
  drop = FALSE
]

# Crear la cuadrícula completa de 55 países por 26 años.
panel_grid <- merge(
  dres_sample,
  data.frame(year = analysis_years),
  by = NULL,
  sort = FALSE
)
# Integrar los cuatro componentes sin eliminar países-año sin información.
rents_work <- merge(
  panel_grid,
  rents_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
# Ordenar el panel por país y año.
rents_work <- rents_work[
  order(rents_work$country_iso3_code, rents_work$year),
]
row.names(rents_work) <- NULL

# Contar cuántos componentes están observados en cada agregación.
component_count <- rowSums(!is.na(rents_work[, component_columns]))
oil_gas_component_count <- rowSums(
  !is.na(rents_work[, oil_gas_component_columns])
)
mining_component_count <- rowSums(
  !is.na(rents_work[, mining_component_columns])
)
# Identificar exclusivamente las filas completas para cada agregación.
all_components_observed <- component_count == length(component_columns)
all_oil_gas_components_observed <- (
  oil_gas_component_count == length(oil_gas_component_columns)
)
all_mining_components_observed <- (
  mining_component_count == length(mining_component_columns)
)

# Inicializar las tres medidas como faltantes para impedir sumas parciales.
rents_work$rents <- NA_real_
rents_work$rents_oil_gas <- NA_real_
rents_work$rents_mining <- NA_real_
# Construir RENTS total cuando existen los cuatro componentes.
rents_work$rents[all_components_observed] <- rowSums(
  rents_work[all_components_observed, component_columns, drop = FALSE]
)
# Construir el subagregado de petróleo y gas cuando ambos están observados.
rents_work$rents_oil_gas[all_oil_gas_components_observed] <- rowSums(
  rents_work[
    all_oil_gas_components_observed,
    oil_gas_component_columns,
    drop = FALSE
  ]
)
# Construir el subagregado minero cuando carbón y minerales están observados.
rents_work$rents_mining[all_mining_components_observed] <- rowSums(
  rents_work[
    all_mining_components_observed,
    mining_component_columns,
    drop = FALSE
  ]
)

# Construir el archivo principal con las tres medidas procesadas.
rents_panel <- rents_work[, c(
  "country_iso3_code",
  "country",
  "year",
  "rents",
  "rents_oil_gas",
  "rents_mining"
)]

# Verificar el tamaño exacto de la cuadrícula esperada.
if (nrow(rents_panel) != expected_row_count) {
  stop(
    "RENTS debería contener ", expected_row_count,
    " filas y contiene ", nrow(rents_panel), "."
  )
}
# Verificar que se conserven exactamente los 55 países.
if (length(unique(rents_panel$country_iso3_code)) != expected_country_count) {
  stop("RENTS no conserva exactamente los 55 países de la muestra DRES.")
}
# Verificar que no existan llaves país-año duplicadas.
duplicate_keys <- anyDuplicated(
  rents_panel[c("country_iso3_code", "year")]
)
if (duplicate_keys > 0L) {
  stop("RENTS contiene llaves país-año duplicadas.")
}
# Verificar que los años pertenezcan exclusivamente al período definido.
if (!all(rents_panel$year %in% analysis_years)) {
  stop("RENTS contiene años por fuera de 1996-2021.")
}
# Verificar que ninguna suma parcial haya producido un valor de RENTS.
if (any(!all_components_observed & !is.na(rents_work$rents))) {
  stop("Se calculó RENTS en filas con componentes faltantes.")
}
# Verificar que toda fila completa produzca un valor de RENTS.
if (any(all_components_observed & is.na(rents_work$rents))) {
  stop("Existen filas completas sin un valor calculado de RENTS.")
}
# Verificar que RENTS_OIL_GAS no contenga sumas parciales.
if (
  any(
    !all_oil_gas_components_observed &
      !is.na(rents_work$rents_oil_gas)
  )
) {
  stop("Se calculó RENTS_OIL_GAS con petróleo o gas faltante.")
}
# Verificar que toda fila con petróleo y gas produzca el subagregado.
if (
  any(
    all_oil_gas_components_observed &
      is.na(rents_work$rents_oil_gas)
  )
) {
  stop("Existen filas completas sin un valor calculado de RENTS_OIL_GAS.")
}
# Verificar que RENTS_MINING no contenga sumas parciales.
if (
  any(
    !all_mining_components_observed &
      !is.na(rents_work$rents_mining)
  )
) {
  stop("Se calculó RENTS_MINING con carbón o minerales faltantes.")
}
# Verificar que toda fila con carbón y minerales produzca el subagregado.
if (
  any(
    all_mining_components_observed &
      is.na(rents_work$rents_mining)
  )
) {
  stop("Existen filas completas sin un valor calculado de RENTS_MINING.")
}

# Recalcular la suma como control independiente de la fórmula.
formula_check <- rowSums(
  rents_work[all_components_observed, component_columns, drop = FALSE]
)
# Medir cualquier diferencia entre la fórmula y la variable construida.
formula_difference <- abs(
  rents_work$rents[all_components_observed] - formula_check
)
formula_mismatch_count <- sum(formula_difference > 1e-12)
if (formula_mismatch_count > 0L) {
  stop("La validación independiente encontró diferencias en la fórmula RENTS.")
}
# Verificar la fórmula independiente de petróleo y gas.
oil_gas_formula_check <- rowSums(
  rents_work[
    all_oil_gas_components_observed,
    oil_gas_component_columns,
    drop = FALSE
  ]
)
oil_gas_formula_mismatch_count <- sum(
  abs(
    rents_work$rents_oil_gas[all_oil_gas_components_observed] -
      oil_gas_formula_check
  ) > 1e-12
)
if (oil_gas_formula_mismatch_count > 0L) {
  stop("La fórmula de RENTS_OIL_GAS no coincide con petróleo más gas.")
}
# Verificar la fórmula independiente de carbón y minerales.
mining_formula_check <- rowSums(
  rents_work[
    all_mining_components_observed,
    mining_component_columns,
    drop = FALSE
  ]
)
mining_formula_mismatch_count <- sum(
  abs(
    rents_work$rents_mining[all_mining_components_observed] -
      mining_formula_check
  ) > 1e-12
)
if (mining_formula_mismatch_count > 0L) {
  stop("La fórmula de RENTS_MINING no coincide con carbón más minerales.")
}
# Verificar la identidad entre la medida total y los dos subagregados.
decomposition_mismatch_count <- sum(
  abs(
    rents_work$rents[all_components_observed] -
      rents_work$rents_oil_gas[all_components_observed] -
      rents_work$rents_mining[all_components_observed]
  ) > 1e-12
)
if (decomposition_mismatch_count > 0L) {
  stop("RENTS no coincide con RENTS_OIL_GAS más RENTS_MINING.")
}
# Detener el script si alguna de las tres sumas genera valores negativos.
rent_measure_columns <- c("rents", "rents_oil_gas", "rents_mining")
for (column_name in rent_measure_columns) {
  if (any(rents_panel[[column_name]] < 0, na.rm = TRUE)) {
    stop("La variable ", column_name, " contiene valores negativos.")
  }
}

# Construir el diagnóstico de cobertura para cada país.
coverage_by_country <- do.call(
  rbind,
  lapply(split(rents_work, rents_work$country_iso3_code), function(country_data) {
    observed_years <- country_data$year[!is.na(country_data$rents)]
    available_years <- length(observed_years)
    available_oil_gas_years <- sum(!is.na(country_data$rents_oil_gas))
    available_mining_years <- sum(!is.na(country_data$rents_mining))
    country_component_count <- rowSums(
      !is.na(country_data[, component_columns, drop = FALSE])
    )
    data.frame(
      country_iso3_code = country_data$country_iso3_code[1],
      country = country_data$country[1],
      expected_years = length(analysis_years),
      available_rents_years = available_years,
      missing_rents_years = length(analysis_years) - available_years,
      available_rents_oil_gas_years = available_oil_gas_years,
      missing_rents_oil_gas_years = (
        length(analysis_years) - available_oil_gas_years
      ),
      available_rents_mining_years = available_mining_years,
      missing_rents_mining_years = (
        length(analysis_years) - available_mining_years
      ),
      partial_component_years = sum(
        country_component_count > 0L &
          country_component_count < length(component_columns)
      ),
      all_components_missing_years = sum(country_component_count == 0L),
      published_zero_rents_years = sum(country_data$rents == 0, na.rm = TRUE),
      published_zero_rents_oil_gas_years = sum(
        country_data$rents_oil_gas == 0,
        na.rm = TRUE
      ),
      published_zero_rents_mining_years = sum(
        country_data$rents_mining == 0,
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
      oil_gas_coverage_share = (
        available_oil_gas_years / length(analysis_years)
      ),
      mining_coverage_share = (
        available_mining_years / length(analysis_years)
      ),
      complete_1996_2021 = as.integer(
        available_years == length(analysis_years)
      ),
      complete_oil_gas_1996_2021 = as.integer(
        available_oil_gas_years == length(analysis_years)
      ),
      complete_mining_1996_2021 = as.integer(
        available_mining_years == length(analysis_years)
      ),
      stringsAsFactors = FALSE
    )
  })
)
# Ordenar el diagnóstico desde la menor cobertura hacia la mayor.
coverage_by_country <- coverage_by_country[
  order(
    coverage_by_country$available_rents_years,
    coverage_by_country$country_iso3_code
  ),
]
row.names(coverage_by_country) <- NULL

# Construir un segundo diagnóstico para observar la cobertura en cada año.
coverage_by_year <- do.call(
  rbind,
  lapply(split(rents_work, rents_work$year), function(year_data) {
    available_country_years <- sum(!is.na(year_data$rents))
    available_oil_gas_country_years <- sum(
      !is.na(year_data$rents_oil_gas)
    )
    available_mining_country_years <- sum(
      !is.na(year_data$rents_mining)
    )
    data.frame(
      year = year_data$year[1],
      expected_countries = expected_country_count,
      available_rents_countries = available_country_years,
      missing_rents_countries = expected_country_count - available_country_years,
      available_rents_oil_gas_countries = available_oil_gas_country_years,
      missing_rents_oil_gas_countries = (
        expected_country_count - available_oil_gas_country_years
      ),
      available_rents_mining_countries = available_mining_country_years,
      missing_rents_mining_countries = (
        expected_country_count - available_mining_country_years
      ),
      published_zero_rents = sum(year_data$rents == 0, na.rm = TRUE),
      published_zero_rents_oil_gas = sum(
        year_data$rents_oil_gas == 0,
        na.rm = TRUE
      ),
      published_zero_rents_mining = sum(
        year_data$rents_mining == 0,
        na.rm = TRUE
      ),
      coverage_share = available_country_years / expected_country_count,
      oil_gas_coverage_share = (
        available_oil_gas_country_years / expected_country_count
      ),
      mining_coverage_share = (
        available_mining_country_years / expected_country_count
      ),
      stringsAsFactors = FALSE
    )
  })
)
# Ordenar el diagnóstico temporal desde 1996 hasta 2021.
coverage_by_year <- coverage_by_year[order(coverage_by_year$year), ]
row.names(coverage_by_year) <- NULL

# Guardar el panel procesado en CSV.
write.csv(
  rents_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar el mismo panel en formato Stata.
foreign::write.dta(
  rents_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
# Guardar la cobertura detallada por país.
write.csv(
  coverage_by_country,
  coverage_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar la cobertura temporal para detectar años con menor disponibilidad.
write.csv(
  coverage_by_year,
  year_coverage_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Releer ambas salidas para comprobar su equivalencia efectiva.
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

# Verificar que ambos formatos conserven nombres y número de filas.
if (
  !identical(names(csv_check), names(dta_check)) ||
    nrow(csv_check) != nrow(dta_check)
) {
  stop("Las salidas CSV y Stata no conservan la misma estructura.")
}
# Verificar que ambos formatos conserven exactamente las llaves país-año.
if (
  !identical(
    as.character(csv_check$country_iso3_code),
    as.character(dta_check$country_iso3_code)
  ) ||
    !identical(as.integer(csv_check$year), as.integer(dta_check$year))
) {
  stop("Las salidas CSV y Stata no conservan las mismas llaves país-año.")
}
# Verificar que los nombres de país sean equivalentes en ambos formatos.
if (!identical(as.character(csv_check$country), as.character(dta_check$country))) {
  stop("Las salidas CSV y Stata no conservan los mismos nombres de país.")
}
# Verificar faltantes y precisión numérica de las tres medidas.
csv_stata_differences <- setNames(
  numeric(length(rent_measure_columns)),
  rent_measure_columns
)
for (column_name in rent_measure_columns) {
  if (
    !identical(
      is.na(csv_check[[column_name]]),
      is.na(dta_check[[column_name]])
    )
  ) {
    stop(
      "Las salidas CSV y Stata no conservan los mismos faltantes de ",
      column_name, "."
    )
  }
  format_difference <- abs(
    csv_check[[column_name]] - dta_check[[column_name]]
  )
  csv_stata_differences[[column_name]] <- if (
    all(is.na(format_difference))
  ) {
    0
  } else {
    max(format_difference, na.rm = TRUE)
  }
}
# Detener el script si alguna diferencia supera la tolerancia de precisión.
max_csv_stata_difference <- max(csv_stata_differences)
if (max_csv_stata_difference > 1e-10) {
  stop("Las salidas CSV y Stata difieren numéricamente.")
}

# Resumir las verificaciones principales en un archivo auditable.
validation_summary <- data.frame(
  metric = c(
    "start_year",
    "end_year",
    "dres_sample_countries",
    "expected_country_years",
    "actual_country_years",
    "available_rents_country_years",
    "missing_rents_country_years",
    "rents_coverage_percent",
    "countries_with_any_rents",
    "countries_complete_1996_2021",
    "countries_without_rents",
    "available_rents_oil_gas_country_years",
    "missing_rents_oil_gas_country_years",
    "rents_oil_gas_coverage_percent",
    "countries_with_any_rents_oil_gas",
    "countries_complete_oil_gas_1996_2021",
    "countries_without_rents_oil_gas",
    "available_rents_mining_country_years",
    "missing_rents_mining_country_years",
    "rents_mining_coverage_percent",
    "countries_with_any_rents_mining",
    "countries_complete_mining_1996_2021",
    "countries_without_rents_mining",
    "rows_with_all_four_components",
    "rows_with_partial_components",
    "rows_with_all_components_missing",
    "published_zero_rents",
    "published_zero_rents_oil_gas",
    "published_zero_rents_mining",
    "negative_rents",
    "negative_rents_oil_gas",
    "negative_rents_mining",
    "rents_above_100_percent_gdp",
    "rents_oil_gas_above_100_percent_gdp",
    "rents_mining_above_100_percent_gdp",
    "duplicate_country_year_keys",
    "rents_formula_mismatch_count",
    "rents_oil_gas_formula_mismatch_count",
    "rents_mining_formula_mismatch_count",
    "decomposition_mismatch_count",
    "rents_csv_stata_max_abs_difference",
    "rents_oil_gas_csv_stata_max_abs_difference",
    "rents_mining_csv_stata_max_abs_difference",
    "all_measures_csv_stata_max_abs_difference"
  ),
  value = c(
    start_year,
    end_year,
    expected_country_count,
    expected_row_count,
    nrow(rents_panel),
    sum(!is.na(rents_panel$rents)),
    sum(is.na(rents_panel$rents)),
    100 * mean(!is.na(rents_panel$rents)),
    sum(coverage_by_country$available_rents_years > 0L),
    sum(coverage_by_country$complete_1996_2021 == 1L),
    sum(coverage_by_country$available_rents_years == 0L),
    sum(!is.na(rents_panel$rents_oil_gas)),
    sum(is.na(rents_panel$rents_oil_gas)),
    100 * mean(!is.na(rents_panel$rents_oil_gas)),
    sum(coverage_by_country$available_rents_oil_gas_years > 0L),
    sum(coverage_by_country$complete_oil_gas_1996_2021 == 1L),
    sum(coverage_by_country$available_rents_oil_gas_years == 0L),
    sum(!is.na(rents_panel$rents_mining)),
    sum(is.na(rents_panel$rents_mining)),
    100 * mean(!is.na(rents_panel$rents_mining)),
    sum(coverage_by_country$available_rents_mining_years > 0L),
    sum(coverage_by_country$complete_mining_1996_2021 == 1L),
    sum(coverage_by_country$available_rents_mining_years == 0L),
    sum(all_components_observed),
    sum(
      component_count > 0L &
        component_count < length(component_columns)
    ),
    sum(component_count == 0L),
    sum(rents_panel$rents == 0, na.rm = TRUE),
    sum(rents_panel$rents_oil_gas == 0, na.rm = TRUE),
    sum(rents_panel$rents_mining == 0, na.rm = TRUE),
    sum(rents_panel$rents < 0, na.rm = TRUE),
    sum(rents_panel$rents_oil_gas < 0, na.rm = TRUE),
    sum(rents_panel$rents_mining < 0, na.rm = TRUE),
    sum(rents_panel$rents > 100, na.rm = TRUE),
    sum(rents_panel$rents_oil_gas > 100, na.rm = TRUE),
    sum(rents_panel$rents_mining > 100, na.rm = TRUE),
    duplicate_keys,
    formula_mismatch_count,
    oil_gas_formula_mismatch_count,
    mining_formula_mismatch_count,
    decomposition_mismatch_count,
    csv_stata_differences[["rents"]],
    csv_stata_differences[["rents_oil_gas"]],
    csv_stata_differences[["rents_mining"]],
    max_csv_stata_difference
  ),
  stringsAsFactors = FALSE
)
# Guardar el resumen después de completar la verificación entre formatos.
write.csv(
  validation_summary,
  validation_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Mostrar un resumen compacto al finalizar correctamente.
message("RENTS y sus dos subagregados se procesaron correctamente.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
message(
  "RENTS total: ", sum(!is.na(rents_panel$rents)), " de ",
  expected_row_count, " país-años (",
  round(100 * mean(!is.na(rents_panel$rents)), 2), "%)."
)
message(
  "RENTS_OIL_GAS: ", sum(!is.na(rents_panel$rents_oil_gas)), " de ",
  expected_row_count, " país-años (",
  round(100 * mean(!is.na(rents_panel$rents_oil_gas)), 2), "%)."
)
message(
  "RENTS_MINING: ", sum(!is.na(rents_panel$rents_mining)), " de ",
  expected_row_count, " país-años (",
  round(100 * mean(!is.na(rents_panel$rents_mining)), 2), "%)."
)
