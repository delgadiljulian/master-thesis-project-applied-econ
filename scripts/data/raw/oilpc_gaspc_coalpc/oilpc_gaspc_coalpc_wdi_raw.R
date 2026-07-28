# CAPA: RAW
# VARIABLES: OILPC, GASPC y COALPC
# SALIDAS: data/raw/oilpc_gaspc_coalpc/
# Proposito: preparar los insumos raw de OILPC, GASPC y COALPC.
# Entrada: panel WDI compartido y muestra DRES de referencia.
# Salidas: insumos raw en CSV y Stata, y diagnostico de cobertura.

# Reunir las ubicaciones desde las cuales puede encontrarse el helper de rutas.
helper_path <- c(
  # Buscar desde el archivo activo cuando el script se ejecuta en RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)))), "project_paths.R")
  },
  # Buscar desde la raiz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Buscar desde scripts/data/raw/oilpc_gaspc_coalpc/.
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

# Construir la ruta del panel compartido descargado directamente desde WDI.
wdi_file <- file.path(
  project_path,
  "data",
  "raw",
  "world_bank_wdi",
  "wdi_thesis_inputs_1980_2022.csv"
)
# Construir la ruta de la muestra DRES utilizada para diagnosticar cobertura.
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
# Detener el script si falta alguno de los insumos requeridos.
if (!file.exists(wdi_file)) {
  stop("Primero ejecute scripts/data/raw/world_bank_wdi/wdi_thesis_inputs_raw.R.")
}
if (!file.exists(sample_file)) {
  stop("No se encontro data/processed/dres/dres_sample_20.csv.")
}

# Leer el panel WDI sin convertir automaticamente los textos en factores.
wdi_inputs <- read.csv(
  wdi_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
# Leer la lista de paises pertenecientes a la muestra DRES del 20 por ciento.
dres_sample <- read.csv(
  sample_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  fileEncoding = "UTF-8"
)

# Definir los tres componentes de rentas y los dos denominadores requeridos.
input_columns <- c(
  "oil_rents_pct_gdp",
  "natural_gas_rents_pct_gdp",
  "coal_rents_pct_gdp",
  "gdp_constant_usd",
  "population_total"
)
# Definir las columnas de identificacion y valores que debe contener el raw.
required_columns <- c(
  "country_iso3_code",
  "country",
  "year",
  input_columns
)
# Identificar si alguna columna requerida falta por un cambio en el descargador.
missing_columns <- setdiff(required_columns, names(wdi_inputs))
# Detener el script cuando la estructura de entrada no coincide con la esperada.
if (length(missing_columns) > 0L) {
  stop("Faltan columnas WDI: ", paste(missing_columns, collapse = ", "))
}

# Conservar solamente los cinco insumos, sin construir valores por habitante.
resource_pc_raw <- wdi_inputs[, required_columns]
# Normalizar la llave pais-anio y ordenar las observaciones.
resource_pc_raw$country_iso3_code <-
  toupper(trimws(resource_pc_raw$country_iso3_code))
resource_pc_raw$year <- as.integer(resource_pc_raw$year)
resource_pc_raw <- resource_pc_raw[
  order(resource_pc_raw$country_iso3_code, resource_pc_raw$year),
]
row.names(resource_pc_raw) <- NULL

# Comprobar la granularidad y el dominio de los identificadores.
if (anyDuplicated(resource_pc_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("Los insumos raw de OILPC-GASPC-COALPC contienen llaves duplicadas.")
}
if (any(!grepl("^[A-Z]{3}$", resource_pc_raw$country_iso3_code))) {
  stop("Los insumos raw contienen codigos de pais invalidos.")
}
if (any(!resource_pc_raw$year %in% 1980:2022)) {
  stop("Los insumos raw contienen anios por fuera de 1980-2022.")
}

# Verificar que las participaciones de rentas publicadas no sean negativas.
rent_columns <- c(
  "oil_rents_pct_gdp",
  "natural_gas_rents_pct_gdp",
  "coal_rents_pct_gdp"
)
for (column_name in rent_columns) {
  if (any(resource_pc_raw[[column_name]] < 0, na.rm = TRUE)) {
    stop("La columna ", column_name, " contiene valores negativos.")
  }
}
# Verificar que el PIB real y la poblacion sean positivos cuando estan presentes.
if (any(resource_pc_raw$gdp_constant_usd <= 0, na.rm = TRUE)) {
  stop("El PIB real contiene valores nulos o negativos.")
}
if (any(resource_pc_raw$population_total <= 0, na.rm = TRUE)) {
  stop("La poblacion contiene valores nulos o negativos.")
}

# Confirmar que todos los paises DRES esten representados en el panel compartido.
missing_sample_countries <- setdiff(
  dres_sample$country_iso3_code,
  resource_pc_raw$country_iso3_code
)
if (length(missing_sample_countries) > 0L) {
  stop(
    "Faltan paises DRES en los insumos WDI: ",
    paste(missing_sample_countries, collapse = ", ")
  )
}

# Definir los anios del panel econometrico principal.
analysis_years <- 1996:2022
# Conservar la cuadricula de los 55 paises DRES durante 1996-2022.
sample_grid <- resource_pc_raw[
  resource_pc_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    resource_pc_raw$year %in% analysis_years,
  ,
  drop = FALSE
]
# Calcular el numero esperado de observaciones de la cuadricula completa.
expected_cells <- nrow(dres_sample) * length(analysis_years)
# Detener el script si la cuadricula no contiene exactamente 55 paises por 27 anios.
if (nrow(sample_grid) != expected_cells) {
  stop(
    "La cuadricula DRES deberia contener ", expected_cells,
    " filas y contiene ", nrow(sample_grid), "."
  )
}
if (anyDuplicated(sample_grid[c("country_iso3_code", "year")]) > 0L) {
  stop("La cuadricula DRES contiene llaves duplicadas.")
}

# Registrar los codigos oficiales WDI de los cinco insumos.
source_codes <- c(
  oil_rents_pct_gdp = "NY.GDP.PETR.RT.ZS",
  natural_gas_rents_pct_gdp = "NY.GDP.NGAS.RT.ZS",
  coal_rents_pct_gdp = "NY.GDP.COAL.RT.ZS",
  gdp_constant_usd = "NY.GDP.MKTP.KD",
  population_total = "SP.POP.TOTL"
)

# Definir una funcion para resumir la cobertura de un insumo o combinacion.
summarise_coverage <- function(variable_name, role, source_code, observed) {
  # Contar observaciones disponibles por pais durante 1996-2022.
  country_counts <- tapply(
    observed,
    sample_grid$country_iso3_code,
    sum
  )
  # Completar con cero cualquier pais sin observaciones.
  all_country_counts <- setNames(
    integer(nrow(dres_sample)),
    dres_sample$country_iso3_code
  )
  all_country_counts[names(country_counts)] <- as.integer(country_counts)

  # Contar observaciones por pais durante el periodo disponible hasta 2021.
  through_2021 <- sample_grid$year <= 2021
  expected_cells_2021 <- nrow(dres_sample) * sum(analysis_years <= 2021)
  observed_cells_2021 <- sum(observed[through_2021])
  country_counts_2021 <- tapply(
    observed[through_2021],
    sample_grid$country_iso3_code[through_2021],
    sum
  )
  all_country_counts_2021 <- setNames(
    integer(nrow(dres_sample)),
    dres_sample$country_iso3_code
  )
  all_country_counts_2021[names(country_counts_2021)] <-
    as.integer(country_counts_2021)

  # Devolver una fila compacta con cobertura total y hasta 2021.
  data.frame(
    variable = variable_name,
    role = role,
    source_code = source_code,
    expected_country_years_1996_2022 = expected_cells,
    observed_country_years_1996_2022 = sum(observed),
    coverage_percent_1996_2022 = 100 * sum(observed) / expected_cells,
    expected_country_years_1996_2021 = expected_cells_2021,
    observed_country_years_1996_2021 = observed_cells_2021,
    coverage_percent_1996_2021 =
      100 * observed_cells_2021 / expected_cells_2021,
    countries_with_any_data = sum(all_country_counts > 0L),
    countries_complete_1996_2022 = sum(all_country_counts == 27L),
    countries_complete_1996_2021 = sum(all_country_counts_2021 == 26L),
    countries_without_data = sum(all_country_counts == 0L),
    first_observed_year = if (any(observed)) {
      min(sample_grid$year[observed])
    } else {
      NA_integer_
    },
    last_observed_year = if (any(observed)) {
      max(sample_grid$year[observed])
    } else {
      NA_integer_
    },
    stringsAsFactors = FALSE
  )
}

# Construir una fila de cobertura para cada insumo publicado por WDI.
coverage_rows <- lapply(input_columns, function(column_name) {
  summarise_coverage(
    column_name,
    "insumo_raw",
    source_codes[[column_name]],
    !is.na(sample_grid[[column_name]])
  )
})

# Definir los insumos necesarios posteriormente para cada variable per capita.
oilpc_columns <- c("oil_rents_pct_gdp", "gdp_constant_usd", "population_total")
gaspc_columns <- c(
  "natural_gas_rents_pct_gdp",
  "gdp_constant_usd",
  "population_total"
)
coalpc_columns <- c("coal_rents_pct_gdp", "gdp_constant_usd", "population_total")
# Anadir diagnosticos conjuntos sin realizar todavia los calculos per capita.
coverage_rows[[length(coverage_rows) + 1L]] <- summarise_coverage(
  "oilpc_input_bundle",
  "insumos_conjuntos_para_procesamiento",
  paste(source_codes[oilpc_columns], collapse = " + "),
  complete.cases(sample_grid[, oilpc_columns])
)
coverage_rows[[length(coverage_rows) + 1L]] <- summarise_coverage(
  "gaspc_input_bundle",
  "insumos_conjuntos_para_procesamiento",
  paste(source_codes[gaspc_columns], collapse = " + "),
  complete.cases(sample_grid[, gaspc_columns])
)
coverage_rows[[length(coverage_rows) + 1L]] <- summarise_coverage(
  "coalpc_input_bundle",
  "insumos_conjuntos_para_procesamiento",
  paste(source_codes[coalpc_columns], collapse = " + "),
  complete.cases(sample_grid[, coalpc_columns])
)
coverage_rows[[length(coverage_rows) + 1L]] <- summarise_coverage(
  "all_five_inputs",
  "insumos_conjuntos_para_procesamiento",
  paste(source_codes[input_columns], collapse = " + "),
  complete.cases(sample_grid[, input_columns])
)
# Unir los resumenes individuales y conjuntos en una sola tabla.
coverage_summary <- do.call(rbind, coverage_rows)
row.names(coverage_summary) <- NULL

# Construir la carpeta especifica de los insumos WDI de abundancia.
output_path <- file.path(
  project_path,
  "data",
  "raw",
  "oilpc_gaspc_coalpc",
  "world_bank_wdi"
)
dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
# Construir los nombres de las salidas raw y del diagnostico.
csv_file <- file.path(
  output_path,
  "oilpc_gaspc_coalpc_wdi_inputs_1980_2022.csv"
)
dta_file <- file.path(
  output_path,
  "oilpc_gaspc_coalpc_wdi_inputs_1980_2022.dta"
)
coverage_file <- file.path(
  output_path,
  "oilpc_gaspc_coalpc_raw_coverage_dres20.csv"
)

# Guardar los cinco insumos publicados sin transformarlos ni imputarlos.
write.csv(
  resource_pc_raw,
  csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar exactamente las mismas columnas y valores en formato Stata.
if (requireNamespace("haven", quietly = TRUE)) {
  haven::write_dta(resource_pc_raw, dta_file, version = 14)
} else {
  foreign::write.dta(resource_pc_raw, dta_file, version = 12)
}
# Guardar el diagnostico de cobertura sobre la muestra DRES.
write.csv(
  coverage_summary,
  coverage_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Informar que la preparacion de los insumos raw termino correctamente.
message("Raw de OILPC-GASPC-COALPC terminado.")
message("Archivo CSV: ", csv_file)
print(coverage_summary)
