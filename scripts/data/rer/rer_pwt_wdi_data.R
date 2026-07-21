# Preparar los insumos raw del tipo de cambio real desde PWT y WDI.
#
# Entradas: Penn World Table 11.0 y panel WDI compartido.
# Salidas: datos raw en CSV y Stata, y diagnóstico de cobertura de la muestra.

# Reunir las ubicaciones desde las cuales puede encontrarse el helper de rutas.
helper_path <- c(
  # Buscar desde el archivo activo cuando el script se ejecuta en RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path))), "project_paths.R")
  },
  # Buscar desde la raíz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Buscar desde scripts/data/rer/.
  file.path("..", "..", "project_paths.R"),
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
# Verificar que haven esté instalado antes de leer y escribir archivos Stata.
if (!requireNamespace("haven", quietly = TRUE)) {
  stop("Falta el paquete haven. Instálelo con install.packages('haven').")
}

# Construir la ruta del archivo oficial compartido de Penn World Table 11.0.
pwt_file <- file.path(project_path, "data", "raw", "pwt", "pwt110.dta")
# Construir la ruta del panel compartido descargado directamente desde WDI.
wdi_file <- file.path(
  project_path,
  "data",
  "raw",
  "world_bank_wdi",
  "wdi_thesis_inputs_1980_2022.csv"
)
# Construir la ruta de la muestra DRES de referencia utilizada para diagnosticar cobertura.
sample_file <- file.path(project_path, "data", "processed", "dres", "dres_sample_20.csv")
# Detener el script si todavía no existe el archivo oficial de PWT.
if (!file.exists(pwt_file)) {
  stop("Primero ejecute scripts/data/pwt/pwt11_data.R.")
}
# Detener el script si todavía no existe el panel compartido del Banco Mundial.
if (!file.exists(wdi_file)) {
  stop("Primero ejecute scripts/data/world_bank_wdi/wdi_thesis_inputs.R.")
}
# Detener el script si todavía no existe la muestra DRES de referencia.
if (!file.exists(sample_file)) {
  stop("No se encontró data/processed/dres/dres_sample_20.csv.")
}

# Leer Penn World Table preservando los nombres originales de sus variables.
pwt_source <- as.data.frame(haven::read_dta(pwt_file))
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

# Definir las columnas de PWT indispensables para construir la medida principal.
pwt_required <- c("countrycode", "country", "year", "pl_gdpo")
# Identificar columnas de PWT que falten por una eventual revisión de la fuente.
pwt_missing <- setdiff(pwt_required, names(pwt_source))
# Detener el script si la estructura de PWT no coincide con la esperada.
if (length(pwt_missing) > 0L) {
  stop("Faltan columnas PWT: ", paste(pwt_missing, collapse = ", "))
}
# Definir las columnas WDI necesarias para conservar el REER de robustez.
wdi_required <- c(
  "country_iso3_code",
  "country",
  "year",
  "real_effective_exchange_rate_index"
)
# Identificar columnas WDI que falten por una eventual revisión del descargador.
wdi_missing <- setdiff(wdi_required, names(wdi_inputs))
# Detener el script si la estructura WDI no coincide con la esperada.
if (length(wdi_missing) > 0L) {
  stop("Faltan columnas WDI: ", paste(wdi_missing, collapse = ", "))
}

# Conservar el horizonte general de recopilación definido para la tesis.
raw_years <- 1980:2022
# Seleccionar las columnas de PWT sin calcular todavía el logaritmo de pl_gdpo.
pwt_raw <- pwt_source[pwt_source$year %in% raw_years, pwt_required]
# Estandarizar el código de país para poder unir las dos fuentes.
names(pwt_raw)[names(pwt_raw) == "countrycode"] <- "country_iso3_code"
# Distinguir el nombre de país reportado por PWT antes de efectuar la unión.
names(pwt_raw)[names(pwt_raw) == "country"] <- "country_pwt"
# Convertir el año de PWT a entero.
pwt_raw$year <- as.integer(pwt_raw$year)

# Seleccionar la serie de robustez y sus identificadores desde WDI.
wdi_raw <- wdi_inputs[wdi_inputs$year %in% raw_years, wdi_required]
# Distinguir el nombre de país reportado por WDI antes de efectuar la unión.
names(wdi_raw)[names(wdi_raw) == "country"] <- "country_wdi"
# Acortar el nombre del REER para que también sea válido dentro de Stata.
names(wdi_raw)[names(wdi_raw) == "real_effective_exchange_rate_index"] <- "reer_index"
# Convertir el año de WDI a entero.
wdi_raw$year <- as.integer(wdi_raw$year)

# Detener el script si PWT contiene llaves país-año duplicadas.
if (anyDuplicated(pwt_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("PWT contiene llaves país-año duplicadas para RER.")
}
# Detener el script si WDI contiene llaves país-año duplicadas.
if (anyDuplicated(wdi_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("WDI contiene llaves país-año duplicadas para RER.")
}

# Unir las fuentes preservando países que aparezcan solamente en una de ellas.
rer_raw <- merge(
  pwt_raw,
  wdi_raw,
  by = c("country_iso3_code", "year"),
  all = TRUE,
  sort = FALSE
)
# Priorizar el nombre de PWT y completar los faltantes con el nombre de WDI.
rer_raw$country <- ifelse(
  !is.na(rer_raw$country_pwt) & nzchar(rer_raw$country_pwt),
  rer_raw$country_pwt,
  rer_raw$country_wdi
)
# Definir el orden estable de identificadores y medidas originales.
rer_raw <- rer_raw[, c(
  "country_iso3_code",
  "country",
  "year",
  "pl_gdpo",
  "reer_index"
)]
# Ordenar las observaciones por código de país y año.
rer_raw <- rer_raw[order(rer_raw$country_iso3_code, rer_raw$year), ]
# Eliminar los números de fila heredados de la unión.
row.names(rer_raw) <- NULL

# Detener el script si la unión creó llaves país-año duplicadas.
if (anyDuplicated(rer_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("Los insumos raw de RER contienen llaves país-año duplicadas.")
}
# Detener el script si aparecen códigos de país con formato diferente de ISO3.
if (any(!grepl("^[A-Z]{3}$", rer_raw$country_iso3_code))) {
  stop("Los insumos raw de RER contienen códigos de país inválidos.")
}
# Detener el script si PWT contiene niveles de precios no positivos.
if (any(rer_raw$pl_gdpo <= 0, na.rm = TRUE)) {
  stop("La serie pl_gdpo contiene valores no positivos.")
}
# Detener el script si el REER de robustez contiene índices no positivos.
if (any(rer_raw$reer_index <= 0, na.rm = TRUE)) {
  stop("La serie REER contiene valores no positivos.")
}

# Definir los años que integrarán el panel econométrico principal.
analysis_years <- 1996:2022
# Conservar únicamente la cuadrícula correspondiente a los 55 países DRES.
sample_grid <- rer_raw[
  rer_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    rer_raw$year %in% analysis_years,
  ,
  drop = FALSE
]
# Calcular el número de celdas esperado en una cuadrícula país-año completa.
expected_cells <- nrow(dres_sample) * length(analysis_years)
# Definir las series que serán evaluadas en el diagnóstico de cobertura.
coverage_variables <- c("pl_gdpo", "reer_index")
# Definir el papel econométrico previsto para cada serie evaluada.
coverage_roles <- c("principal", "robustez")
# Registrar los códigos o nombres oficiales que permiten rastrear cada medida.
coverage_codes <- c("PWT11.0:pl_gdpo", "WDI:PX.REX.REER")

# Construir una fila de cobertura para cada alternativa de tipo de cambio real.
coverage_rows <- lapply(seq_along(coverage_variables), function(index) {
  # Recuperar el nombre de la columna evaluada en esta iteración.
  variable_name <- coverage_variables[index]
  # Identificar las observaciones no faltantes de la serie.
  observed <- !is.na(sample_grid[[variable_name]])
  # Contar los años observados para cada país de la muestra.
  country_counts <- tapply(observed, sample_grid$country_iso3_code, sum)
  # Completar con cero los países que no aparezcan en el resultado de tapply.
  all_country_counts <- setNames(integer(nrow(dres_sample)), dres_sample$country_iso3_code)
  # Incorporar los conteos calculados en los códigos correspondientes.
  all_country_counts[names(country_counts)] <- as.integer(country_counts)
  # Devolver un resumen compacto y legible de cobertura.
  data.frame(
    variable = variable_name,
    role = coverage_roles[index],
    source_code = coverage_codes[index],
    expected_country_years = expected_cells,
    observed_country_years = sum(observed),
    coverage_percent = 100 * sum(observed) / expected_cells,
    countries_with_any_data = sum(all_country_counts > 0L),
    countries_with_complete_data = sum(all_country_counts == length(analysis_years)),
    countries_without_data = sum(all_country_counts == 0L),
    stringsAsFactors = FALSE
  )
})
# Unir los resúmenes individuales en una sola tabla de diagnóstico.
coverage_summary <- do.call(rbind, coverage_rows)
# Eliminar los números de fila generados al apilar las tablas.
row.names(coverage_summary) <- NULL

# Construir la carpeta específica donde se guardarán los insumos raw de RER.
output_path <- file.path(project_path, "data", "raw", "rer", "pwt_wdi")
# Crear la carpeta de salida y sus directorios padres si todavía no existen.
dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
# Construir el nombre del archivo raw en formato CSV.
csv_file <- file.path(output_path, "rer_inputs_1980_2022.csv")
# Construir el nombre equivalente para Stata.
dta_file <- file.path(output_path, "rer_inputs_1980_2022.dta")
# Construir la ubicación del diagnóstico de cobertura sobre la muestra DRES.
coverage_file <- file.path(output_path, "rer_raw_coverage_dres20.csv")

# Guardar los niveles originales sin calcular todavía logaritmos ni índices nuevos.
write.csv(
  rer_raw,
  csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar el mismo contenido en un archivo compatible con Stata.
haven::write_dta(rer_raw, dta_file, version = 14)
# Guardar el diagnóstico para documentar la disponibilidad de ambas medidas.
write.csv(
  coverage_summary,
  coverage_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Informar que la preparación de los insumos raw terminó correctamente.
message("Raw de RER terminado.")
# Mostrar la ubicación del archivo principal para facilitar su revisión.
message("Archivo CSV: ", csv_file)
# Mostrar el diagnóstico de cobertura en la consola.
print(coverage_summary)
