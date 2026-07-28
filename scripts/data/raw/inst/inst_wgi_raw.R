# CAPA: RAW
# VARIABLE: INST
# SALIDAS: data/raw/inst/
# Proposito: preparar por separado los tres componentes raw del indice institucional.
# Entrada: descarga original de Worldwide Governance Indicators y muestra DRES.
# Salidas: insumos raw en CSV y Stata, y diagnostico de cobertura.

# Reunir las ubicaciones desde las cuales puede encontrarse el helper de rutas.
helper_path <- c(
  # Buscar desde el archivo activo cuando el script se ejecuta en RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)))), "project_paths.R")
  },
  # Buscar desde la raiz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Buscar desde scripts/data/raw/inst/.
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

# Construir la ruta de la descarga original de WGI.
wgi_file <- file.path(
  project_path,
  "data",
  "raw",
  "inst",
  "world_bank_wgi",
  "0a8b502f-696a-4678-91cf-132f60b7a8e0_Data.csv"
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
if (!file.exists(wgi_file)) {
  stop("No se encontro la descarga original de Worldwide Governance Indicators.")
}
if (!file.exists(sample_file)) {
  stop("No se encontro data/processed/dres/dres_sample_20.csv.")
}

# Leer la descarga original y reconocer el marcador de faltantes utilizado por WGI.
wgi_wide <- read.csv(
  wgi_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "..", "NA"),
  check.names = FALSE,
  fileEncoding = "latin1"
)
# Leer la lista de paises pertenecientes a la muestra DRES del 20 por ciento.
dres_sample <- read.csv(
  sample_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  fileEncoding = "UTF-8"
)

# Definir los tres estimadores institucionales adoptados por la tesis.
component_codes <- c(
  control_of_corruption_est = "GOV_WGI_CC.EST",
  rule_of_law_est = "GOV_WGI_RL.EST",
  government_effectiveness_est = "GOV_WGI_GE.EST"
)
# Definir las columnas de identificacion que debe contener la descarga.
required_columns <- c("Country Name", "Country Code", "Series Name", "Series Code")
# Identificar las columnas anuales publicadas por WGI.
year_columns <- grep(
  "^[0-9]{4} \\[YR[0-9]{4}\\]$",
  names(wgi_wide),
  value = TRUE
)
# Detener el script si la estructura de entrada no coincide con la esperada.
missing_columns <- setdiff(required_columns, names(wgi_wide))
if (length(missing_columns) > 0L) {
  stop("Faltan columnas WGI: ", paste(missing_columns, collapse = ", "))
}
if (length(year_columns) == 0L) {
  stop("La descarga WGI no contiene columnas anuales reconocibles.")
}

# Conservar unicamente las tres series de estimaciones, sin puntajes ni errores.
wgi_components <- wgi_wide[
  wgi_wide[["Series Code"]] %in% unname(component_codes),
  c(required_columns, year_columns),
  drop = FALSE
]
# Verificar que cada codigo corresponda a una fila por pais.
series_country_keys <- wgi_components[c("Country Code", "Series Code")]
if (anyDuplicated(series_country_keys) > 0L) {
  stop("La descarga WGI contiene series institucionales duplicadas por pais.")
}
missing_series <- setdiff(unname(component_codes), unique(wgi_components[["Series Code"]]))
if (length(missing_series) > 0L) {
  stop("Faltan series institucionales: ", paste(missing_series, collapse = ", "))
}

# Convertir las columnas anuales al formato largo pais-anio.
source_years <- as.integer(sub(" .*", "", year_columns))
component_tables <- lapply(names(component_codes), function(component_name) {
  # Seleccionar una de las tres series y ordenar los paises.
  component_wide <- wgi_components[
    wgi_components[["Series Code"]] == component_codes[[component_name]],
    ,
    drop = FALSE
  ]
  component_wide <- component_wide[
    order(component_wide[["Country Code"]]),
    ,
    drop = FALSE
  ]
  # Expandir cada fila pais a una observacion por anio publicado.
  component_long <- data.frame(
    country_iso3_code = rep(component_wide[["Country Code"]], each = length(source_years)),
    country = rep(component_wide[["Country Name"]], each = length(source_years)),
    year = rep(source_years, times = nrow(component_wide)),
    value = as.numeric(as.vector(t(as.matrix(component_wide[, year_columns, drop = FALSE])))),
    stringsAsFactors = FALSE
  )
  # Renombrar el valor con el nombre explicito del componente.
  names(component_long)[names(component_long) == "value"] <- component_name
  component_long
})

# Unir los tres componentes usando la llave pais-anio.
inst_raw <- Reduce(
  function(left, right) {
    merge(
      left,
      right,
      by = c("country_iso3_code", "country", "year"),
      all = TRUE,
      sort = FALSE
    )
  },
  component_tables
)
# Normalizar identificadores y ordenar la tabla final.
inst_raw$country_iso3_code <- toupper(trimws(inst_raw$country_iso3_code))
inst_raw$year <- as.integer(inst_raw$year)
inst_raw <- inst_raw[
  order(inst_raw$country_iso3_code, inst_raw$year),
  c(
    "country_iso3_code",
    "country",
    "year",
    names(component_codes)
  )
]
row.names(inst_raw) <- NULL

# Comprobar la granularidad, los identificadores y el rango de los estimadores.
if (anyDuplicated(inst_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("Los insumos raw de INST contienen llaves pais-anio duplicadas.")
}
if (any(!grepl("^[A-Z]{3}$", inst_raw$country_iso3_code))) {
  stop("Los insumos raw de INST contienen codigos de pais invalidos.")
}
if (any(!inst_raw$year %in% source_years)) {
  stop("Los insumos raw de INST contienen anios ajenos a la descarga.")
}
for (component_name in names(component_codes)) {
  if (any(abs(inst_raw[[component_name]]) > 3, na.rm = TRUE)) {
    stop("La columna ", component_name, " contiene valores fuera del rango WGI esperado.")
  }
}

# Definir la cuadricula completa del periodo econometrico principal.
analysis_years <- 1996:2022
sample_grid <- expand.grid(
  country_iso3_code = sort(unique(dres_sample$country_iso3_code)),
  year = analysis_years,
  stringsAsFactors = FALSE
)
# Incorporar a la cuadricula los tres componentes raw disponibles.
sample_grid <- merge(
  sample_grid,
  inst_raw[
    inst_raw$country_iso3_code %in% dres_sample$country_iso3_code &
      inst_raw$year %in% analysis_years,
    c("country_iso3_code", "year", names(component_codes)),
    drop = FALSE
  ],
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
# Ordenar la cuadricula para que los diagnosticos sean reproducibles.
sample_grid <- sample_grid[order(sample_grid$country_iso3_code, sample_grid$year), ]
row.names(sample_grid) <- NULL

# Confirmar que la cuadricula conserva exactamente 55 paises por 27 anios.
expected_cells <- nrow(dres_sample) * length(analysis_years)
if (nrow(sample_grid) != expected_cells) {
  stop(
    "La cuadricula DRES deberia contener ", expected_cells,
    " filas y contiene ", nrow(sample_grid), "."
  )
}
missing_sample_countries <- setdiff(
  dres_sample$country_iso3_code,
  inst_raw$country_iso3_code
)
if (length(missing_sample_countries) > 0L) {
  stop(
    "Faltan paises DRES en los insumos WGI: ",
    paste(missing_sample_countries, collapse = ", ")
  )
}

# Identificar los anios estructuralmente ausentes en la publicacion WGI.
published_analysis_years <- intersect(source_years, analysis_years)
structural_missing_years <- setdiff(analysis_years, published_analysis_years)
if (!identical(structural_missing_years, c(1997L, 1999L, 2001L))) {
  stop(
    "Los anios estructuralmente ausentes cambiaron: ",
    paste(structural_missing_years, collapse = ", ")
  )
}
# Calcular el denominador correspondiente solo a los anios publicados.
expected_published_cells <- nrow(dres_sample) * length(published_analysis_years)

# Definir una funcion para resumir la cobertura de cada componente o combinacion.
summarise_coverage <- function(variable_name, role, source_code, observed) {
  # Identificar las filas correspondientes a los anios realmente publicados.
  in_published_year <- sample_grid$year %in% published_analysis_years
  # Contar observaciones por pais dentro de los anios publicados.
  country_counts <- tapply(
    observed[in_published_year],
    sample_grid$country_iso3_code[in_published_year],
    sum
  )
  # Completar con cero cualquier pais sin observaciones.
  all_country_counts <- setNames(integer(nrow(dres_sample)), dres_sample$country_iso3_code)
  all_country_counts[names(country_counts)] <- as.integer(country_counts)

  # Devolver una fila compacta con cobertura total y sobre anios publicados.
  data.frame(
    variable = variable_name,
    role = role,
    source_code = source_code,
    expected_country_years_1996_2022 = expected_cells,
    published_country_years_1996_2022 = expected_published_cells,
    observed_country_years_1996_2022 = sum(observed),
    coverage_percent_full_period = 100 * sum(observed) / expected_cells,
    coverage_percent_published_years =
      100 * sum(observed[in_published_year]) / expected_published_cells,
    countries_with_any_data = sum(all_country_counts > 0L),
    countries_complete_in_published_years =
      sum(all_country_counts == length(published_analysis_years)),
    structural_missing_years = paste(structural_missing_years, collapse = ";"),
    last_observed_year = if (any(observed)) {
      max(sample_grid$year[observed])
    } else {
      NA_integer_
    },
    stringsAsFactors = FALSE
  )
}

# Construir una fila de cobertura para cada estimador institucional.
coverage_rows <- lapply(names(component_codes), function(component_name) {
  summarise_coverage(
    component_name,
    "componente_raw",
    component_codes[[component_name]],
    !is.na(sample_grid[[component_name]])
  )
})
# Anadir un diagnostico conjunto sin agregar ni estandarizar los componentes.
all_components_observed <- complete.cases(sample_grid[, names(component_codes)])
coverage_rows[[length(coverage_rows) + 1L]] <- summarise_coverage(
  "all_three_components",
  "insumos_conjuntos_para_procesamiento",
  paste(unname(component_codes), collapse = " + "),
  all_components_observed
)
coverage_summary <- do.call(rbind, coverage_rows)
row.names(coverage_summary) <- NULL

# Construir las rutas de las salidas raw y de diagnostico.
output_path <- file.path(project_path, "data", "raw", "inst", "world_bank_wgi")
dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
csv_file <- file.path(output_path, "inst_wgi_inputs_1996_2024.csv")
dta_file <- file.path(output_path, "inst_wgi_inputs_1996_2024.dta")
coverage_file <- file.path(output_path, "inst_raw_coverage_dres20_1996_2022.csv")

# Guardar los tres estimadores publicados sin agregarlos ni imputarlos.
write.csv(
  inst_raw,
  csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar exactamente las mismas columnas y valores en formato Stata.
if (requireNamespace("haven", quietly = TRUE)) {
  haven::write_dta(inst_raw, dta_file, version = 14)
} else {
  foreign::write.dta(inst_raw, dta_file, version = 12)
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
message("Raw de INST terminado.")
message("Archivo CSV: ", csv_file)
print(coverage_summary)
