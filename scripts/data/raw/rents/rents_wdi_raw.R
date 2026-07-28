# CAPA: RAW
# VARIABLE FUTURA: RENTS
# SALIDAS: data/raw/rents/
# Propósito: preparar los cuatro componentes raw de las rentas extractivas.
# Entrada: panel WDI compartido y muestra DRES de referencia.
# Salidas: insumos raw en CSV y Stata, y diagnóstico de cobertura.

# Reunir las ubicaciones desde las cuales puede encontrarse el helper de rutas.
helper_path <- c(
  # Buscar desde el archivo activo cuando el script se ejecuta en RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)))), "project_paths.R")
  },
  # Buscar desde la raíz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Buscar desde scripts/data/raw/rents/.
  file.path("..", "..", "..", "project_paths.R"),
  # Buscar desde scripts/.
  file.path("..", "project_paths.R"),
  # Buscar en el directorio de trabajo actual como última alternativa.
  "project_paths.R"
)

# Conservar la primera ubicación candidata que exista realmente.
helper_path <- helper_path[file.exists(helper_path)][1]
# Detener el script si no fue posible encontrar el helper de rutas.
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}

# Ejecutar el helper para habilitar la búsqueda de la raíz del repositorio.
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
# Detener el script si todavía no existe el panel compartido del Banco Mundial.
if (!file.exists(wdi_file)) {
  stop("Primero ejecute scripts/data/raw/world_bank_wdi/wdi_thesis_inputs_raw.R.")
}
# Detener el script si todavía no existe la muestra DRES de referencia.
if (!file.exists(sample_file)) {
  stop("No se encontró data/processed/dres/dres_sample_20.csv.")
}

# Leer el panel WDI sin convertir automáticamente los textos en factores.
wdi_inputs <- read.csv(
  wdi_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
# Leer la lista de países pertenecientes a la muestra DRES del 20 por ciento.
dres_sample <- read.csv(
  sample_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  fileEncoding = "UTF-8"
)

# Definir los cuatro componentes de rentas extractivas adoptados por la tesis.
component_columns <- c(
  "oil_rents_pct_gdp",
  "natural_gas_rents_pct_gdp",
  "coal_rents_pct_gdp",
  "mineral_rents_pct_gdp"
)
# Definir las columnas de identificación y componentes que debe contener el raw.
required_columns <- c(
  "country_iso3_code",
  "country",
  "year",
  component_columns
)
# Identificar si alguna columna requerida falta por un cambio en el descargador.
missing_columns <- setdiff(required_columns, names(wdi_inputs))
# Detener el script cuando la estructura de entrada no coincide con la esperada.
if (length(missing_columns) > 0L) {
  stop("Faltan columnas WDI: ", paste(missing_columns, collapse = ", "))
}

# Conservar únicamente identificadores y componentes sin calcular todavía RENTS.
rents_raw <- wdi_inputs[, required_columns]
# Convertir el año a entero para preservar una llave país-año consistente.
rents_raw$year <- as.integer(rents_raw$year)
# Normalizar los códigos de país como texto ISO3 en mayúsculas.
rents_raw$country_iso3_code <- toupper(trimws(rents_raw$country_iso3_code))
# Ordenar las observaciones por país y año.
rents_raw <- rents_raw[order(rents_raw$country_iso3_code, rents_raw$year), ]
# Eliminar los números de fila heredados después del ordenamiento.
row.names(rents_raw) <- NULL

# Detener el script si aparece más de una observación para el mismo país y año.
if (anyDuplicated(rents_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("Los insumos raw de RENTS contienen llaves país-año duplicadas.")
}
# Detener el script si existe un código de país vacío o diferente del formato ISO3.
if (any(!grepl("^[A-Z]{3}$", rents_raw$country_iso3_code))) {
  stop("Los insumos raw de RENTS contienen códigos de país inválidos.")
}
# Detener el script si aparece un año por fuera del horizonte de la descarga.
if (any(!rents_raw$year %in% 1980:2022)) {
  stop("Los insumos raw de RENTS contienen años por fuera de 1980-2022.")
}
# Detener el script si alguno de los porcentajes publicados es negativo.
for (column_name in component_columns) {
  if (any(rents_raw[[column_name]] < 0, na.rm = TRUE)) {
    stop("La columna ", column_name, " contiene valores negativos.")
  }
}

# Verificar que todos los países DRES estén representados en el panel compartido.
missing_sample_countries <- setdiff(
  dres_sample$country_iso3_code,
  rents_raw$country_iso3_code
)
# Detener el script si falta por completo algún país de la muestra de referencia.
if (length(missing_sample_countries) > 0L) {
  stop(
    "Faltan países DRES en los insumos WDI: ",
    paste(missing_sample_countries, collapse = ", ")
  )
}

# Definir los años del panel econométrico principal.
analysis_years <- 1996:2022
# Conservar la cuadrícula de los 55 países DRES durante 1996-2022.
sample_grid <- rents_raw[
  rents_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    rents_raw$year %in% analysis_years,
  ,
  drop = FALSE
]
# Calcular el número esperado de observaciones de la cuadrícula completa.
expected_cells <- nrow(dres_sample) * length(analysis_years)
# Detener el script si la cuadrícula no contiene exactamente 55 países por 27 años.
if (nrow(sample_grid) != expected_cells) {
  stop(
    "La cuadrícula DRES debería contener ", expected_cells,
    " filas y contiene ", nrow(sample_grid), "."
  )
}
# Detener el script si la cuadrícula contiene llaves país-año duplicadas.
if (anyDuplicated(sample_grid[c("country_iso3_code", "year")]) > 0L) {
  stop("La cuadrícula DRES de RENTS contiene llaves duplicadas.")
}

# Registrar los códigos oficiales WDI de los cuatro componentes.
component_codes <- c(
  "NY.GDP.PETR.RT.ZS",
  "NY.GDP.NGAS.RT.ZS",
  "NY.GDP.COAL.RT.ZS",
  "NY.GDP.MINR.RT.ZS"
)
# Definir una función para resumir la cobertura de un componente o combinación.
summarise_coverage <- function(variable_name, role, source_code, observed) {
  # Contar las observaciones disponibles para cada país durante 1996-2022.
  country_counts <- tapply(
    observed,
    sample_grid$country_iso3_code,
    sum
  )
  # Completar con cero cualquier país sin observaciones.
  all_country_counts <- setNames(
    integer(nrow(dres_sample)),
    dres_sample$country_iso3_code
  )
  # Incorporar los conteos calculados en los códigos correspondientes.
  all_country_counts[names(country_counts)] <- as.integer(country_counts)

  # Identificar las filas pertenecientes al período disponible hasta 2021.
  through_2021 <- sample_grid$year <= 2021
  # Contar las observaciones disponibles por país durante 1996-2021.
  country_counts_2021 <- tapply(
    observed[through_2021],
    sample_grid$country_iso3_code[through_2021],
    sum
  )
  # Completar con cero cualquier país ausente del conteo hasta 2021.
  all_country_counts_2021 <- setNames(
    integer(nrow(dres_sample)),
    dres_sample$country_iso3_code
  )
  # Incorporar los conteos calculados para el período 1996-2021.
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
    countries_with_any_data = sum(all_country_counts > 0L),
    countries_complete_1996_2022 = sum(all_country_counts == 27L),
    countries_complete_1996_2021 = sum(all_country_counts_2021 == 26L),
    countries_without_data = sum(all_country_counts == 0L),
    last_observed_year = if (any(observed)) {
      max(sample_grid$year[observed])
    } else {
      NA_integer_
    },
    stringsAsFactors = FALSE
  )
}

# Construir una fila de cobertura para cada componente publicado por WDI.
coverage_rows <- lapply(seq_along(component_columns), function(index) {
  # Identificar las observaciones no faltantes del componente evaluado.
  observed <- !is.na(sample_grid[[component_columns[index]]])
  # Resumir la cobertura individual del componente.
  summarise_coverage(
    component_columns[index],
    "componente_raw",
    component_codes[index],
    observed
  )
})
# Identificar las observaciones donde están presentes los cuatro componentes.
all_components_observed <- complete.cases(sample_grid[, component_columns])
# Añadir un diagnóstico conjunto sin calcular la suma de RENTS.
coverage_rows[[length(coverage_rows) + 1L]] <- summarise_coverage(
  "all_four_components",
  "insumos_conjuntos_para_procesamiento",
  paste(component_codes, collapse = " + "),
  all_components_observed
)
# Unir los resúmenes individuales y conjunto en una sola tabla.
coverage_summary <- do.call(rbind, coverage_rows)
# Eliminar los números de fila generados al apilar los resultados.
row.names(coverage_summary) <- NULL

# Construir la carpeta específica de los insumos raw de rentas extractivas.
output_path <- file.path(
  project_path,
  "data",
  "raw",
  "rents",
  "world_bank_wdi"
)
# Crear la carpeta de salida y sus directorios padres si no existen.
dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
# Construir los nombres de las tres salidas raw y de diagnóstico.
csv_file <- file.path(output_path, "rents_wdi_inputs_1980_2022.csv")
dta_file <- file.path(output_path, "rents_wdi_inputs_1980_2022.dta")
coverage_file <- file.path(output_path, "rents_raw_coverage_dres20.csv")

# Guardar los cuatro componentes publicados sin sumarlos ni imputarlos.
write.csv(
  rents_raw,
  csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar exactamente las mismas columnas y valores en formato Stata.
if (requireNamespace("haven", quietly = TRUE)) {
  # Preferir haven cuando esté disponible por su soporte de formatos recientes.
  haven::write_dta(rents_raw, dta_file, version = 14)
} else {
  # Utilizar foreign como alternativa incluida en la instalación estándar de R.
  foreign::write.dta(rents_raw, dta_file, version = 12)
}
# Guardar el diagnóstico de cobertura sobre la muestra DRES.
write.csv(
  coverage_summary,
  coverage_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Informar que la preparación de los insumos raw terminó correctamente.
message("Raw de RENTS terminado.")
# Mostrar la ubicación del archivo principal para facilitar su revisión.
message("Archivo CSV: ", csv_file)
# Mostrar el diagnóstico de cobertura en la consola.
print(coverage_summary)
