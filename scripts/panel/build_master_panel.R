# CAPA: PANEL MAESTRO
# ETAPA ACTUAL: variables institucionales, de abundancia y estructurales
# ENTRADAS: paneles validados bajo data/processed/
# SALIDAS: data/processed/00_master_panel/
#
# Construye la cuadrícula fija de 55 países DRES para 1996-2021 e integra
# exclusivamente variables ya validadas en data/processed. La interacción se
# calcula como el producto directo RENTS * INST únicamente cuando ambas
# variables están observadas. No se centran, interpolan ni imputan valores.

# Localizar el helper compartido sin depender del directorio de ejecución.
helper_path <- c(
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    file.path(
      dirname(dirname(rstudioapi::getActiveDocumentContext()$path)),
      "project_paths.R"
    )
  },
  file.path("scripts", "project_paths.R"),
  file.path("..", "project_paths.R"),
  "project_paths.R"
)
helper_path <- helper_path[file.exists(helper_path)][1]
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}
source(helper_path)
project_path <- find_project_path()

# Definir la muestra y el período econométrico aprobados.
start_year <- 1996L
end_year <- 2021L
analysis_years <- start_year:end_year
structural_inst_missing_years <- c(1997L, 1999L, 2001L)
published_inst_years <- setdiff(
  analysis_years,
  structural_inst_missing_years
)
expected_country_count <- 55L
expected_row_count <- expected_country_count * length(analysis_years)
expected_published_inst_cells <- (
  expected_country_count * length(published_inst_years)
)

# Definir los insumos procesados oficiales.
dres_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
rents_file <- file.path(
  project_path,
  "data",
  "processed",
  "rents",
  "rents_data.csv"
)
inst_file <- file.path(
  project_path,
  "data",
  "processed",
  "inst",
  "inst_data.csv"
)
resource_rents_pc_file <- file.path(
  project_path,
  "data",
  "processed",
  "oilpc_gaspc_coalpc",
  "oilpc_gaspc_coalpc_data.csv"
)
export_specialization_file <- file.path(
  project_path,
  "data",
  "processed",
  "pexp_fexp",
  "pexp_fexp_data.csv"
)
vol_file <- file.path(
  project_path,
  "data",
  "processed",
  "vol",
  "vol_data.csv"
)
rer_file <- file.path(
  project_path,
  "data",
  "processed",
  "rer",
  "rer_data.csv"
)
humcap_file <- file.path(
  project_path,
  "data",
  "processed",
  "humcap",
  "humcap_data.csv"
)
innov_file <- file.path(
  project_path,
  "data",
  "processed",
  "innov",
  "innov_data.csv"
)
net_file <- file.path(
  project_path,
  "data",
  "processed",
  "net",
  "net_data.csv"
)
log_gdppc_file <- file.path(
  project_path,
  "data",
  "processed",
  "gdppc",
  "log_gdppc_data.csv"
)
govcons_file <- file.path(
  project_path,
  "data",
  "processed",
  "govcons",
  "govcons_data.csv"
)
fin_file <- file.path(
  project_path,
  "data",
  "processed",
  "fin",
  "fin_data.csv"
)
eci_file <- file.path(
  project_path,
  "data",
  "processed",
  "eci",
  "atlas",
  "eci_data.csv"
)
hhi_divx_file <- file.path(
  project_path,
  "data",
  "processed",
  "hhi_divx",
  "hhi_divx_country_year_1990_2022.csv"
)

# Definir una sola pareja de salidas equivalentes para el panel maestro.
output_path <- file.path(
  project_path,
  "data",
  "processed",
  "00_master_panel"
)
panel_csv_file <- file.path(output_path, "master_panel_country_year.csv")
panel_dta_file <- file.path(output_path, "master_panel_country_year.dta")
country_coverage_file <- file.path(
  output_path,
  "master_panel_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  output_path,
  "master_panel_year_coverage_1996_2021.csv"
)
validation_file <- file.path(
  output_path,
  "master_panel_validation_summary.csv"
)

# Comprobar que existan todos los insumos requeridos.
required_files <- c(
  dres_file,
  rents_file,
  inst_file,
  resource_rents_pc_file,
  export_specialization_file,
  vol_file,
  rer_file,
  humcap_file,
  innov_file,
  net_file,
  log_gdppc_file,
  govcons_file,
  fin_file,
  eci_file,
  hhi_divx_file
)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0L) {
  stop("Faltan archivos requeridos: ", paste(missing_files, collapse = ", "))
}
if (!requireNamespace("foreign", quietly = TRUE)) {
  stop("Falta el paquete de R 'foreign', requerido para la salida Stata.")
}
dir.create(output_path, recursive = TRUE, showWarnings = FALSE)

# Evitar reemplazar archivos que estén abiertos en otra aplicación.
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

# Leer la muestra fija seleccionada mediante DRES >= 20 %.
dres_sample <- read.csv(
  dres_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  fileEncoding = "UTF-8"
)
required_dres_columns <- c(
  "country_iso3_code",
  "country",
  "dres_base_mean",
  "dres_base_mean_percent",
  "sample_threshold"
)
missing_dres_columns <- setdiff(required_dres_columns, names(dres_sample))
if (length(missing_dres_columns) > 0L) {
  stop(
    "Faltan columnas en la muestra DRES: ",
    paste(missing_dres_columns, collapse = ", ")
  )
}
dres_sample <- dres_sample[, required_dres_columns]
dres_sample$country_iso3_code <- toupper(
  trimws(dres_sample$country_iso3_code)
)
dres_sample$country <- trimws(dres_sample$country)
dres_sample$dres_base_mean <- as.numeric(dres_sample$dres_base_mean)
dres_sample$dres_base_mean_percent <- as.numeric(
  dres_sample$dres_base_mean_percent
)
dres_sample$sample_threshold <- as.numeric(dres_sample$sample_threshold)

# Validar identificadores, tamaño y regla de selección de la muestra.
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
if (
  any(is.na(dres_sample$dres_base_mean)) ||
    any(is.na(dres_sample$dres_base_mean_percent)) ||
    any(is.na(dres_sample$sample_threshold))
) {
  stop("La muestra DRES contiene valores faltantes en su regla de selección.")
}
if (any(abs(dres_sample$sample_threshold - 0.2) > 1e-12)) {
  stop("La muestra DRES no corresponde exclusivamente al umbral de 20 %.")
}
if (
  any(
    dres_sample$dres_base_mean <
      dres_sample$sample_threshold - 1e-12
  )
) {
  stop("La muestra DRES contiene países por debajo del umbral de 20 %.")
}
dres_percent_difference <- max(
  abs(
    dres_sample$dres_base_mean_percent -
      100 * dres_sample$dres_base_mean
  )
)
if (dres_percent_difference > 1e-10) {
  stop("Las dos escalas publicadas de DRES no son equivalentes.")
}
dres_sample <- dres_sample[
  order(dres_sample$country_iso3_code),
]
row.names(dres_sample) <- NULL

# Crear la cuadrícula maestra fija de 55 países por 26 años.
panel_grid <- merge(
  dres_sample[, c(
    "country_iso3_code",
    "country",
    "dres_base_mean",
    "dres_base_mean_percent"
  )],
  data.frame(year = analysis_years),
  by = NULL,
  sort = FALSE
)
panel_grid <- panel_grid[
  order(panel_grid$country_iso3_code, panel_grid$year),
]
row.names(panel_grid) <- NULL

# Función común para leer y validar cada panel procesado.
read_processed_panel <- function(
  file_path,
  source_name,
  required_value_columns
) {
  source_data <- read.csv(
    file_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA", "N/A"),
    fileEncoding = "UTF-8"
  )
  required_columns <- c(
    "country_iso3_code",
    "country",
    "year",
    required_value_columns
  )
  missing_columns <- setdiff(required_columns, names(source_data))
  if (length(missing_columns) > 0L) {
    stop(
      "Faltan columnas en ", source_name, ": ",
      paste(missing_columns, collapse = ", ")
    )
  }
  source_data <- source_data[, required_columns]
  source_data$country_iso3_code <- toupper(
    trimws(source_data$country_iso3_code)
  )
  source_data$country <- trimws(source_data$country)
  source_data$year <- as.integer(source_data$year)
  for (column_name in required_value_columns) {
    source_data[[column_name]] <- as.numeric(source_data[[column_name]])
  }
  if (
    any(!grepl("^[A-Z]{3}$", source_data$country_iso3_code)) ||
      any(!nzchar(source_data$country)) ||
      any(is.na(source_data$year))
  ) {
    stop(source_name, " contiene identificadores país-año inválidos.")
  }
  if (
    anyDuplicated(source_data[c("country_iso3_code", "year")]) > 0L
  ) {
    stop(source_name, " contiene llaves país-año duplicadas.")
  }
  # Restringir cada fuente al período común del panel maestro. Esto permite
  # utilizar insumos validados que también conservan años posteriores, como ECI.
  source_data <- source_data[
    source_data$year %in% analysis_years,
    ,
    drop = FALSE
  ]
  if (nrow(source_data) != expected_row_count) {
    stop(
      source_name, " debería contener ", expected_row_count,
      " filas y contiene ", nrow(source_data), "."
    )
  }
  if (
    length(unique(source_data$country_iso3_code)) !=
      expected_country_count
  ) {
    stop(source_name, " no conserva exactamente los 55 países DRES.")
  }
  if (!setequal(unique(source_data$year), analysis_years)) {
    stop(source_name, " no cubre exactamente el período 1996-2021.")
  }
  source_data <- source_data[
    order(source_data$country_iso3_code, source_data$year),
  ]
  row.names(source_data) <- NULL
  source_data
}

# Leer únicamente las variables procesadas aprobadas para esta etapa.
rents_panel <- read_processed_panel(
  rents_file,
  "RENTS procesada",
  c("rents", "rents_oil_gas", "rents_mining")
)
inst_panel <- read_processed_panel(
  inst_file,
  "INST procesada",
  "inst"
)
resource_rents_pc_panel <- read_processed_panel(
  resource_rents_pc_file,
  "OILPC/GASPC/COALPC procesadas",
  c("oilpc", "gaspc", "coalpc")
)
export_specialization_panel <- read_processed_panel(
  export_specialization_file,
  "PEXP/FEXP procesadas",
  c("pexp", "fexp")
)
vol_panel <- read_processed_panel(
  vol_file,
  "VOL procesada",
  "vol"
)
rer_panel <- read_processed_panel(
  rer_file,
  "RER procesada",
  "rer"
)
humcap_panel <- read_processed_panel(
  humcap_file,
  "HUMCAP procesada",
  "humcap"
)
innov_panel <- read_processed_panel(
  innov_file,
  "INNOV procesada",
  "innov"
)
net_panel <- read_processed_panel(
  net_file,
  "NET procesada",
  "net"
)
log_gdppc_panel <- read_processed_panel(
  log_gdppc_file,
  "LOG_GDPPC procesada",
  "log_gdppc"
)
govcons_panel <- read_processed_panel(
  govcons_file,
  "GOVCONS procesada",
  "govcons"
)
fin_panel <- read_processed_panel(
  fin_file,
  "FIN procesada",
  "fin"
)
eci_panel <- read_processed_panel(
  eci_file,
  "ECI procesada",
  "eci"
)
hhi_divx_panel <- read_processed_panel(
  hhi_divx_file,
  "HHI/DIVX procesadas",
  c("hhi", "divx")
)

# Crear una llave explícita y comprobar correspondencia uno a uno.
make_key <- function(data) {
  paste(data$country_iso3_code, data$year, sep = "_")
}
grid_key <- make_key(panel_grid)
rents_key <- make_key(rents_panel)
inst_key <- make_key(inst_panel)
resource_rents_pc_key <- make_key(resource_rents_pc_panel)
export_specialization_key <- make_key(export_specialization_panel)
vol_key <- make_key(vol_panel)
rer_key <- make_key(rer_panel)
humcap_key <- make_key(humcap_panel)
innov_key <- make_key(innov_panel)
net_key <- make_key(net_panel)
log_gdppc_key <- make_key(log_gdppc_panel)
govcons_key <- make_key(govcons_panel)
fin_key <- make_key(fin_panel)
eci_key <- make_key(eci_panel)
hhi_divx_key <- make_key(hhi_divx_panel)
if (!identical(grid_key, rents_key)) {
  stop("Las llaves de RENTS no coinciden exactamente con la cuadrícula DRES.")
}
if (!identical(grid_key, inst_key)) {
  stop("Las llaves de INST no coinciden exactamente con la cuadrícula DRES.")
}
if (!identical(grid_key, resource_rents_pc_key)) {
  stop(
    "Las llaves de OILPC/GASPC/COALPC no coinciden con la cuadrícula DRES."
  )
}
if (!identical(grid_key, export_specialization_key)) {
  stop("Las llaves de PEXP/FEXP no coinciden con la cuadrícula DRES.")
}
if (!identical(grid_key, vol_key)) {
  stop("Las llaves de VOL no coinciden con la cuadrícula DRES.")
}
if (!identical(grid_key, rer_key)) {
  stop("Las llaves de RER no coinciden con la cuadrícula DRES.")
}
if (!identical(grid_key, humcap_key)) {
  stop("Las llaves de HUMCAP no coinciden con la cuadrícula DRES.")
}
if (!identical(grid_key, innov_key)) {
  stop("Las llaves de INNOV no coinciden con la cuadrícula DRES.")
}
if (!identical(grid_key, net_key)) {
  stop("Las llaves de NET no coinciden con la cuadrícula DRES.")
}
if (!identical(grid_key, log_gdppc_key)) {
  stop("Las llaves de LOG_GDPPC no coinciden con la cuadrícula DRES.")
}
if (!identical(grid_key, govcons_key)) {
  stop("Las llaves de GOVCONS no coinciden con la cuadrícula DRES.")
}
if (!identical(grid_key, fin_key)) {
  stop("Las llaves de FIN no coinciden con la cuadrícula DRES.")
}
if (!identical(grid_key, eci_key)) {
  stop("Las llaves de ECI no coinciden con la cuadrícula DRES.")
}
if (!identical(grid_key, hhi_divx_key)) {
  stop("Las llaves de HHI/DIVX no coinciden con la cuadrícula DRES.")
}
if (!identical(panel_grid$country, rents_panel$country)) {
  stop("Los nombres de país de RENTS no coinciden con la muestra DRES.")
}
if (!identical(panel_grid$country, inst_panel$country)) {
  stop("Los nombres de país de INST no coinciden con la muestra DRES.")
}
if (!identical(panel_grid$country, resource_rents_pc_panel$country)) {
  stop(
    "Los nombres de país de OILPC/GASPC/COALPC no coinciden con DRES."
  )
}
if (!identical(panel_grid$country, export_specialization_panel$country)) {
  stop("Los nombres de país de PEXP/FEXP no coinciden con DRES.")
}
if (!identical(panel_grid$country, vol_panel$country)) {
  stop("Los nombres de país de VOL no coinciden con DRES.")
}
if (!identical(panel_grid$country, rer_panel$country)) {
  stop("Los nombres de país de RER no coinciden con DRES.")
}
if (!identical(panel_grid$country, humcap_panel$country)) {
  stop("Los nombres de país de HUMCAP no coinciden con DRES.")
}
if (!identical(panel_grid$country, innov_panel$country)) {
  stop("Los nombres de país de INNOV no coinciden con DRES.")
}
if (!identical(panel_grid$country, net_panel$country)) {
  stop("Los nombres de país de NET no coinciden con DRES.")
}
if (!identical(panel_grid$country, log_gdppc_panel$country)) {
  stop("Los nombres de país de LOG_GDPPC no coinciden con DRES.")
}
if (!identical(panel_grid$country, govcons_panel$country)) {
  stop("Los nombres de país de GOVCONS no coinciden con DRES.")
}
if (!identical(panel_grid$country, fin_panel$country)) {
  stop("Los nombres de país de FIN no coinciden con DRES.")
}
if (!identical(panel_grid$country, eci_panel$country)) {
  stop("Los nombres de país de ECI no coinciden con DRES.")
}
if (!identical(panel_grid$country, hhi_divx_panel$country)) {
  stop("Los nombres de país de HHI/DIVX no coinciden con DRES.")
}

# Integrar las variables sin alterar el número ni el orden de filas.
master_panel <- panel_grid
master_panel$rents <- rents_panel$rents
master_panel$rents_oil_gas <- rents_panel$rents_oil_gas
master_panel$rents_mining <- rents_panel$rents_mining
master_panel$inst <- inst_panel$inst

# Construir RENTS x INST solo cuando ambos componentes están observados.
jointly_observed <- (
  !is.na(master_panel$rents) &
    !is.na(master_panel$inst)
)
master_panel$rents_x_inst <- NA_real_
master_panel$rents_x_inst[jointly_observed] <- (
  master_panel$rents[jointly_observed] *
    master_panel$inst[jointly_observed]
)
master_panel$oilpc <- resource_rents_pc_panel$oilpc
master_panel$gaspc <- resource_rents_pc_panel$gaspc
master_panel$coalpc <- resource_rents_pc_panel$coalpc
master_panel$pexp <- export_specialization_panel$pexp
master_panel$fexp <- export_specialization_panel$fexp
master_panel$vol <- vol_panel$vol
master_panel$rer <- rer_panel$rer
master_panel$humcap <- humcap_panel$humcap
master_panel$innov <- innov_panel$innov
master_panel$net <- net_panel$net
master_panel$log_gdppc <- log_gdppc_panel$log_gdppc
master_panel$govcons <- govcons_panel$govcons
master_panel$fin <- fin_panel$fin
master_panel$eci <- eci_panel$eci
master_panel$hhi <- hhi_divx_panel$hhi
master_panel$divx <- hhi_divx_panel$divx

# Validar dimensiones, llaves, faltantes, fórmula y dominio económico.
if (nrow(master_panel) != expected_row_count) {
  stop("La integración alteró el número esperado de filas del panel.")
}
duplicate_keys <- anyDuplicated(
  master_panel[c("country_iso3_code", "year")]
)
if (duplicate_keys > 0L) {
  stop("El panel maestro contiene llaves país-año duplicadas.")
}
missing_rule_mismatch_count <- sum(
  is.na(master_panel$rents_x_inst) !=
    (is.na(master_panel$rents) | is.na(master_panel$inst))
)
if (missing_rule_mismatch_count > 0L) {
  stop("RENTS x INST no respeta la disponibilidad conjunta de sus componentes.")
}
formula_difference <- abs(
  master_panel$rents_x_inst[jointly_observed] -
    master_panel$rents[jointly_observed] *
      master_panel$inst[jointly_observed]
)
formula_mismatch_count <- sum(formula_difference > 1e-12)
if (formula_mismatch_count > 0L) {
  stop("La validación independiente encontró errores en RENTS x INST.")
}
structural_inst_rows <- (
  master_panel$year %in% structural_inst_missing_years
)
structural_interaction_missing_count <- sum(
  is.na(master_panel$rents_x_inst[structural_inst_rows])
)
expected_structural_missing_count <- (
  expected_country_count * length(structural_inst_missing_years)
)
if (
  structural_interaction_missing_count !=
    expected_structural_missing_count
) {
  stop("La interacción no conserva correctamente los vacíos estructurales WGI.")
}
resource_rents_pc_columns <- c("oilpc", "gaspc", "coalpc")
for (column_name in resource_rents_pc_columns) {
  if (any(master_panel[[column_name]] < 0, na.rm = TRUE)) {
    stop(column_name, " contiene valores negativos en el panel maestro.")
  }
}
if (
  !identical(
    is.na(master_panel[, resource_rents_pc_columns]),
    is.na(resource_rents_pc_panel[, resource_rents_pc_columns])
  )
) {
  stop("El merge alteró los faltantes de OILPC, GASPC o COALPC.")
}
export_specialization_columns <- c("pexp", "fexp")
for (column_name in export_specialization_columns) {
  if (
    any(
      master_panel[[column_name]] < 0 |
        master_panel[[column_name]] > 100,
      na.rm = TRUE
    )
  ) {
    stop(column_name, " contiene valores por fuera del rango [0, 100].")
  }
}
joint_export_share_violation_count <- sum(
  master_panel$pexp + master_panel$fexp > 100 + 1e-10,
  na.rm = TRUE
)
if (joint_export_share_violation_count > 0L) {
  stop("PEXP y FEXP suman más de 100 % en una o más observaciones.")
}
if (
  !identical(
    is.na(master_panel[, export_specialization_columns]),
    is.na(export_specialization_panel[, export_specialization_columns])
  )
) {
  stop("El merge alteró los faltantes de PEXP o FEXP.")
}
if (any(master_panel$vol < 0, na.rm = TRUE)) {
  stop("VOL contiene valores negativos en el panel maestro.")
}
if (!identical(is.na(master_panel$vol), is.na(vol_panel$vol))) {
  stop("El merge alteró los faltantes de VOL.")
}
if (any(is.infinite(master_panel$rer), na.rm = TRUE)) {
  stop("RER contiene valores infinitos en el panel maestro.")
}
if (!identical(is.na(master_panel$rer), is.na(rer_panel$rer))) {
  stop("El merge alteró los faltantes de RER.")
}
if (
  any(master_panel$humcap <= 0, na.rm = TRUE) ||
    any(is.infinite(master_panel$humcap), na.rm = TRUE)
) {
  stop("HUMCAP contiene valores no positivos o infinitos.")
}
if (!identical(is.na(master_panel$humcap), is.na(humcap_panel$humcap))) {
  stop("El merge alteró los faltantes de HUMCAP.")
}
if (
  any(master_panel$innov < 0, na.rm = TRUE) ||
    any(is.infinite(master_panel$innov), na.rm = TRUE)
) {
  stop("INNOV contiene valores negativos o infinitos.")
}
if (!identical(is.na(master_panel$innov), is.na(innov_panel$innov))) {
  stop("El merge alteró los faltantes de INNOV.")
}
if (
  any(
    master_panel$net < 0 | master_panel$net > 100,
    na.rm = TRUE
  ) ||
    any(is.infinite(master_panel$net), na.rm = TRUE)
) {
  stop("NET contiene valores fuera de [0, 100] o infinitos.")
}
if (!identical(is.na(master_panel$net), is.na(net_panel$net))) {
  stop("El merge alteró los faltantes de NET.")
}
if (any(is.infinite(master_panel$log_gdppc), na.rm = TRUE)) {
  stop("LOG_GDPPC contiene valores infinitos.")
}
if (
  !identical(
    is.na(master_panel$log_gdppc),
    is.na(log_gdppc_panel$log_gdppc)
  )
) {
  stop("El merge alteró los faltantes de LOG_GDPPC.")
}
if (
  any(master_panel$govcons <= 0, na.rm = TRUE) ||
    any(is.infinite(master_panel$govcons), na.rm = TRUE)
) {
  stop("GOVCONS contiene valores no positivos o infinitos.")
}
if (!identical(is.na(master_panel$govcons), is.na(govcons_panel$govcons))) {
  stop("El merge alteró los faltantes de GOVCONS.")
}
if (
  any(master_panel$fin < 0, na.rm = TRUE) ||
    any(is.infinite(master_panel$fin), na.rm = TRUE)
) {
  stop("FIN contiene valores negativos o infinitos.")
}
if (!identical(is.na(master_panel$fin), is.na(fin_panel$fin))) {
  stop("El merge alteró los faltantes de FIN.")
}
if (any(is.infinite(master_panel$eci), na.rm = TRUE)) {
  stop("ECI contiene valores infinitos.")
}
if (!identical(is.na(master_panel$eci), is.na(eci_panel$eci))) {
  stop("El merge alteró los faltantes de ECI.")
}
hhi_divx_columns <- c("hhi", "divx")
for (column_name in hhi_divx_columns) {
  if (
    any(
      master_panel[[column_name]] < 0 |
        master_panel[[column_name]] > 1,
      na.rm = TRUE
    ) ||
      any(is.infinite(master_panel[[column_name]]), na.rm = TRUE)
  ) {
    stop(column_name, " contiene valores fuera de [0, 1] o infinitos.")
  }
}
if (
  !identical(
    is.na(master_panel[, hhi_divx_columns]),
    is.na(hhi_divx_panel[, hhi_divx_columns])
  )
) {
  stop("El merge alteró los faltantes de HHI o DIVX.")
}
hhi_divx_identity_difference <- abs(
  master_panel$hhi + master_panel$divx - 1
)
hhi_divx_identity_max_error <- max(
  hhi_divx_identity_difference,
  na.rm = TRUE
)
if (hhi_divx_identity_max_error > 1e-12) {
  stop("La identidad DIVX = 1 - HHI no se cumple en el panel maestro.")
}

# Resumir cobertura por país para todas las variables integradas.
country_coverage <- do.call(
  rbind,
  lapply(
    split(master_panel, master_panel$country_iso3_code),
    function(country_data) {
      observed_years <- country_data$year[
        !is.na(country_data$rents_x_inst)
      ]
      interaction_years <- length(observed_years)
      data.frame(
        country_iso3_code = country_data$country_iso3_code[1],
        country = country_data$country[1],
        expected_years = length(analysis_years),
        wgi_published_years = length(published_inst_years),
        available_rents_years = sum(!is.na(country_data$rents)),
        available_inst_years = sum(!is.na(country_data$inst)),
        available_rents_x_inst_years = interaction_years,
        available_oilpc_years = sum(!is.na(country_data$oilpc)),
        available_gaspc_years = sum(!is.na(country_data$gaspc)),
        available_coalpc_years = sum(!is.na(country_data$coalpc)),
        available_pexp_years = sum(!is.na(country_data$pexp)),
        available_fexp_years = sum(!is.na(country_data$fexp)),
        available_vol_years = sum(!is.na(country_data$vol)),
        available_rer_years = sum(!is.na(country_data$rer)),
        available_humcap_years = sum(!is.na(country_data$humcap)),
        available_innov_years = sum(!is.na(country_data$innov)),
        available_net_years = sum(!is.na(country_data$net)),
        available_log_gdppc_years = sum(!is.na(country_data$log_gdppc)),
        available_govcons_years = sum(!is.na(country_data$govcons)),
        available_fin_years = sum(!is.na(country_data$fin)),
        available_eci_years = sum(!is.na(country_data$eci)),
        available_hhi_years = sum(!is.na(country_data$hhi)),
        available_divx_years = sum(!is.na(country_data$divx)),
        missing_rents_x_inst_years = (
          length(analysis_years) - interaction_years
        ),
        first_available_interaction_year = if (interaction_years > 0L) {
          min(observed_years)
        } else {
          NA_integer_
        },
        last_available_interaction_year = if (interaction_years > 0L) {
          max(observed_years)
        } else {
          NA_integer_
        },
        full_period_coverage_share = (
          interaction_years / length(analysis_years)
        ),
        published_years_coverage_share = (
          interaction_years / length(published_inst_years)
        ),
        complete_in_published_years = as.integer(
          interaction_years == length(published_inst_years)
        ),
        stringsAsFactors = FALSE
      )
    }
  )
)
country_coverage <- country_coverage[
  order(
    country_coverage$available_rents_x_inst_years,
    country_coverage$country_iso3_code
  ),
]
row.names(country_coverage) <- NULL

# Resumir cobertura anual e identificar los años sin publicación WGI.
year_coverage <- do.call(
  rbind,
  lapply(
    split(master_panel, master_panel$year),
    function(year_data) {
      available_interaction <- sum(!is.na(year_data$rents_x_inst))
      data.frame(
        year = year_data$year[1],
        wgi_published_year = as.integer(
          !(year_data$year[1] %in% structural_inst_missing_years)
        ),
        expected_countries = expected_country_count,
        available_rents_countries = sum(!is.na(year_data$rents)),
        available_inst_countries = sum(!is.na(year_data$inst)),
        available_rents_x_inst_countries = available_interaction,
        available_oilpc_countries = sum(!is.na(year_data$oilpc)),
        available_gaspc_countries = sum(!is.na(year_data$gaspc)),
        available_coalpc_countries = sum(!is.na(year_data$coalpc)),
        available_pexp_countries = sum(!is.na(year_data$pexp)),
        available_fexp_countries = sum(!is.na(year_data$fexp)),
        available_vol_countries = sum(!is.na(year_data$vol)),
        available_rer_countries = sum(!is.na(year_data$rer)),
        available_humcap_countries = sum(!is.na(year_data$humcap)),
        available_innov_countries = sum(!is.na(year_data$innov)),
        available_net_countries = sum(!is.na(year_data$net)),
        available_log_gdppc_countries = sum(!is.na(year_data$log_gdppc)),
        available_govcons_countries = sum(!is.na(year_data$govcons)),
        available_fin_countries = sum(!is.na(year_data$fin)),
        available_eci_countries = sum(!is.na(year_data$eci)),
        available_hhi_countries = sum(!is.na(year_data$hhi)),
        available_divx_countries = sum(!is.na(year_data$divx)),
        missing_rents_x_inst_countries = (
          expected_country_count - available_interaction
        ),
        rents_x_inst_coverage_share = (
          available_interaction / expected_country_count
        ),
        stringsAsFactors = FALSE
      )
    }
  )
)
year_coverage <- year_coverage[order(year_coverage$year), ]
row.names(year_coverage) <- NULL

# Guardar una sola versión lógica del panel en CSV y Stata.
write.csv(
  master_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  master_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
write.csv(
  country_coverage,
  country_coverage_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
write.csv(
  year_coverage,
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
  stop("Las salidas CSV y Stata no conservan las mismas llaves.")
}
if (!identical(as.character(csv_check$country), as.character(dta_check$country))) {
  stop("Las salidas CSV y Stata no conservan los mismos nombres de país.")
}

# Ejecutar la siguiente instrucción del bloque
numeric_columns <- c(
  "dres_base_mean",
  "dres_base_mean_percent",
  "rents",
  "rents_oil_gas",
  "rents_mining",
  "inst",
  "rents_x_inst",
  "oilpc",
  "gaspc",
  "coalpc",
  "pexp",
  "fexp",
  "vol",
  "rer",
  "humcap",
  "innov",
  "net",
  "log_gdppc",
  "govcons",
  "fin",
  "eci",
  "hhi",
  "divx"
)
csv_stata_differences <- vapply(
  numeric_columns,
  function(column_name) {
    if (
      !identical(
        is.na(csv_check[[column_name]]),
        is.na(dta_check[[column_name]])
      )
    ) {
      stop(
        "CSV y Stata no conservan los mismos faltantes en ",
        column_name, "."
      )
    }
    difference <- abs(
      csv_check[[column_name]] - dta_check[[column_name]]
    )
    if (all(is.na(difference))) {
      0
    } else {
      max(difference, na.rm = TRUE)
    }
  },
  numeric(1)
)
max_csv_stata_difference <- max(csv_stata_differences)
if (max_csv_stata_difference > 1e-10) {
  stop("Las salidas CSV y Stata difieren numéricamente.")
}

# Guardar evidencia compacta de las validaciones realizadas.
available_interaction_count <- sum(!is.na(master_panel$rents_x_inst))
nonstructural_interaction_missing_count <- sum(
  is.na(master_panel$rents_x_inst) &
    !structural_inst_rows
)
validation_summary <- data.frame(
  metric = c(
    "start_year",
    "end_year",
    "dres_sample_countries",
    "expected_country_years",
    "actual_country_years",
    "available_rents_country_years",
    "available_inst_country_years",
    "available_rents_x_inst_country_years",
    "missing_rents_x_inst_country_years",
    "rents_x_inst_full_period_coverage_percent",
    "rents_x_inst_published_years_coverage_percent",
    "structural_wgi_missing_country_years",
    "nonstructural_rents_x_inst_missing_country_years",
    "rents_observed_inst_missing_country_years",
    "rents_missing_inst_observed_country_years",
    "both_components_missing_country_years",
    "countries_with_any_rents_x_inst",
    "countries_without_rents_x_inst",
    "countries_complete_in_wgi_published_years",
    "available_oilpc_country_years",
    "missing_oilpc_country_years",
    "oilpc_coverage_percent",
    "countries_without_oilpc",
    "available_gaspc_country_years",
    "missing_gaspc_country_years",
    "gaspc_coverage_percent",
    "countries_without_gaspc",
    "available_coalpc_country_years",
    "missing_coalpc_country_years",
    "coalpc_coverage_percent",
    "countries_without_coalpc",
    "country_years_with_all_three_pc_measures",
    "negative_oilpc_count",
    "negative_gaspc_count",
    "negative_coalpc_count",
    "available_pexp_country_years",
    "missing_pexp_country_years",
    "pexp_coverage_percent",
    "pexp_range_violation_count",
    "available_fexp_country_years",
    "missing_fexp_country_years",
    "fexp_coverage_percent",
    "fexp_range_violation_count",
    "pexp_fexp_joint_share_violation_count",
    "available_vol_country_years",
    "missing_vol_country_years",
    "vol_coverage_percent",
    "countries_without_vol",
    "negative_vol_count",
    "available_rer_country_years",
    "missing_rer_country_years",
    "rer_coverage_percent",
    "countries_without_rer",
    "nonfinite_rer_count",
    "available_humcap_country_years",
    "missing_humcap_country_years",
    "humcap_coverage_percent",
    "countries_without_humcap",
    "nonpositive_humcap_count",
    "nonfinite_humcap_count",
    "available_innov_country_years",
    "missing_innov_country_years",
    "innov_coverage_percent",
    "countries_without_innov",
    "zero_innov_count",
    "negative_innov_count",
    "nonfinite_innov_count",
    "available_net_country_years",
    "missing_net_country_years",
    "net_coverage_percent",
    "countries_without_net",
    "zero_net_count",
    "net_range_violation_count",
    "nonfinite_net_count",
    "available_log_gdppc_country_years",
    "missing_log_gdppc_country_years",
    "log_gdppc_coverage_percent",
    "countries_without_log_gdppc",
    "nonfinite_log_gdppc_count",
    "available_govcons_country_years",
    "missing_govcons_country_years",
    "govcons_coverage_percent",
    "countries_without_govcons",
    "nonpositive_govcons_count",
    "nonfinite_govcons_count",
    "available_fin_country_years",
    "missing_fin_country_years",
    "fin_coverage_percent",
    "countries_without_fin",
    "negative_fin_count",
    "nonfinite_fin_count",
    "fin_above_100_count",
    "available_eci_country_years",
    "missing_eci_country_years",
    "eci_coverage_percent",
    "countries_with_any_eci",
    "countries_complete_eci_1996_2021",
    "countries_with_partial_eci",
    "countries_without_eci",
    "nonfinite_eci_count",
    "available_hhi_country_years",
    "missing_hhi_country_years",
    "hhi_coverage_percent",
    "hhi_range_violation_count",
    "available_divx_country_years",
    "missing_divx_country_years",
    "divx_coverage_percent",
    "divx_range_violation_count",
    "hhi_divx_identity_max_error",
    "duplicate_country_year_keys",
    "missing_rule_mismatch_count",
    "formula_mismatch_count",
    "dres_scale_max_abs_difference",
    "csv_stata_max_abs_difference"
  ),
  value = c(
    start_year,
    end_year,
    expected_country_count,
    expected_row_count,
    nrow(master_panel),
    sum(!is.na(master_panel$rents)),
    sum(!is.na(master_panel$inst)),
    available_interaction_count,
    sum(is.na(master_panel$rents_x_inst)),
    100 * available_interaction_count / expected_row_count,
    100 * available_interaction_count / expected_published_inst_cells,
    structural_interaction_missing_count,
    nonstructural_interaction_missing_count,
    sum(!is.na(master_panel$rents) & is.na(master_panel$inst)),
    sum(is.na(master_panel$rents) & !is.na(master_panel$inst)),
    sum(is.na(master_panel$rents) & is.na(master_panel$inst)),
    sum(country_coverage$available_rents_x_inst_years > 0L),
    sum(country_coverage$available_rents_x_inst_years == 0L),
    sum(country_coverage$complete_in_published_years == 1L),
    sum(!is.na(master_panel$oilpc)),
    sum(is.na(master_panel$oilpc)),
    100 * mean(!is.na(master_panel$oilpc)),
    sum(country_coverage$available_oilpc_years == 0L),
    sum(!is.na(master_panel$gaspc)),
    sum(is.na(master_panel$gaspc)),
    100 * mean(!is.na(master_panel$gaspc)),
    sum(country_coverage$available_gaspc_years == 0L),
    sum(!is.na(master_panel$coalpc)),
    sum(is.na(master_panel$coalpc)),
    100 * mean(!is.na(master_panel$coalpc)),
    sum(country_coverage$available_coalpc_years == 0L),
    sum(
      rowSums(
        !is.na(master_panel[, resource_rents_pc_columns, drop = FALSE])
      ) == length(resource_rents_pc_columns)
    ),
    sum(master_panel$oilpc < 0, na.rm = TRUE),
    sum(master_panel$gaspc < 0, na.rm = TRUE),
    sum(master_panel$coalpc < 0, na.rm = TRUE),
    sum(!is.na(master_panel$pexp)),
    sum(is.na(master_panel$pexp)),
    100 * mean(!is.na(master_panel$pexp)),
    sum(
      master_panel$pexp < 0 | master_panel$pexp > 100,
      na.rm = TRUE
    ),
    sum(!is.na(master_panel$fexp)),
    sum(is.na(master_panel$fexp)),
    100 * mean(!is.na(master_panel$fexp)),
    sum(
      master_panel$fexp < 0 | master_panel$fexp > 100,
      na.rm = TRUE
    ),
    joint_export_share_violation_count,
    sum(!is.na(master_panel$vol)),
    sum(is.na(master_panel$vol)),
    100 * mean(!is.na(master_panel$vol)),
    sum(country_coverage$available_vol_years == 0L),
    sum(master_panel$vol < 0, na.rm = TRUE),
    sum(!is.na(master_panel$rer)),
    sum(is.na(master_panel$rer)),
    100 * mean(!is.na(master_panel$rer)),
    sum(country_coverage$available_rer_years == 0L),
    sum(is.infinite(master_panel$rer), na.rm = TRUE),
    sum(!is.na(master_panel$humcap)),
    sum(is.na(master_panel$humcap)),
    100 * mean(!is.na(master_panel$humcap)),
    sum(country_coverage$available_humcap_years == 0L),
    sum(master_panel$humcap <= 0, na.rm = TRUE),
    sum(is.infinite(master_panel$humcap), na.rm = TRUE),
    sum(!is.na(master_panel$innov)),
    sum(is.na(master_panel$innov)),
    100 * mean(!is.na(master_panel$innov)),
    sum(country_coverage$available_innov_years == 0L),
    sum(master_panel$innov == 0, na.rm = TRUE),
    sum(master_panel$innov < 0, na.rm = TRUE),
    sum(is.infinite(master_panel$innov), na.rm = TRUE),
    sum(!is.na(master_panel$net)),
    sum(is.na(master_panel$net)),
    100 * mean(!is.na(master_panel$net)),
    sum(country_coverage$available_net_years == 0L),
    sum(master_panel$net == 0, na.rm = TRUE),
    sum(
      master_panel$net < 0 | master_panel$net > 100,
      na.rm = TRUE
    ),
    sum(is.infinite(master_panel$net), na.rm = TRUE),
    sum(!is.na(master_panel$log_gdppc)),
    sum(is.na(master_panel$log_gdppc)),
    100 * mean(!is.na(master_panel$log_gdppc)),
    sum(country_coverage$available_log_gdppc_years == 0L),
    sum(is.infinite(master_panel$log_gdppc), na.rm = TRUE),
    sum(!is.na(master_panel$govcons)),
    sum(is.na(master_panel$govcons)),
    100 * mean(!is.na(master_panel$govcons)),
    sum(country_coverage$available_govcons_years == 0L),
    sum(master_panel$govcons <= 0, na.rm = TRUE),
    sum(is.infinite(master_panel$govcons), na.rm = TRUE),
    sum(!is.na(master_panel$fin)),
    sum(is.na(master_panel$fin)),
    100 * mean(!is.na(master_panel$fin)),
    sum(country_coverage$available_fin_years == 0L),
    sum(master_panel$fin < 0, na.rm = TRUE),
    sum(is.infinite(master_panel$fin), na.rm = TRUE),
    sum(master_panel$fin > 100, na.rm = TRUE),
    sum(!is.na(master_panel$eci)),
    sum(is.na(master_panel$eci)),
    100 * mean(!is.na(master_panel$eci)),
    sum(country_coverage$available_eci_years > 0L),
    sum(country_coverage$available_eci_years == length(analysis_years)),
    sum(
      country_coverage$available_eci_years > 0L &
        country_coverage$available_eci_years < length(analysis_years)
    ),
    sum(country_coverage$available_eci_years == 0L),
    sum(is.infinite(master_panel$eci), na.rm = TRUE),
    sum(!is.na(master_panel$hhi)),
    sum(is.na(master_panel$hhi)),
    100 * mean(!is.na(master_panel$hhi)),
    sum(
      master_panel$hhi < 0 | master_panel$hhi > 1,
      na.rm = TRUE
    ),
    sum(!is.na(master_panel$divx)),
    sum(is.na(master_panel$divx)),
    100 * mean(!is.na(master_panel$divx)),
    sum(
      master_panel$divx < 0 | master_panel$divx > 1,
      na.rm = TRUE
    ),
    hhi_divx_identity_max_error,
    duplicate_keys,
    missing_rule_mismatch_count,
    formula_mismatch_count,
    dres_percent_difference,
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
message("Panel maestro actualizado correctamente.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
message(
  "RENTS x INST: ", available_interaction_count, " de ",
  expected_row_count, " país-años (",
  round(100 * available_interaction_count / expected_row_count, 2), "%)."
)
message(
  "Cobertura en años publicados por WGI: ",
  available_interaction_count, " de ", expected_published_inst_cells,
  " país-años (",
  round(
    100 * available_interaction_count / expected_published_inst_cells,
    2
  ), "%)."
)
message(
  "OILPC/GASPC/COALPC: ",
  sum(!is.na(master_panel$oilpc)), "/",
  sum(!is.na(master_panel$gaspc)), "/",
  sum(!is.na(master_panel$coalpc)),
  " observaciones disponibles."
)
message(
  "PEXP/FEXP: ",
  sum(!is.na(master_panel$pexp)), "/",
  sum(!is.na(master_panel$fexp)),
  " observaciones disponibles."
)
message(
  "VOL: ", sum(!is.na(master_panel$vol)),
  " observaciones disponibles."
)
message(
  "RER: ", sum(!is.na(master_panel$rer)),
  " observaciones disponibles."
)
message(
  "HUMCAP: ", sum(!is.na(master_panel$humcap)),
  " observaciones disponibles."
)
message(
  "INNOV: ", sum(!is.na(master_panel$innov)),
  " observaciones disponibles."
)
message(
  "NET: ", sum(!is.na(master_panel$net)),
  " observaciones disponibles."
)
message(
  "LOG_GDPPC: ", sum(!is.na(master_panel$log_gdppc)),
  " observaciones disponibles."
)
message(
  "GOVCONS: ", sum(!is.na(master_panel$govcons)),
  " observaciones disponibles."
)
message(
  "FIN: ", sum(!is.na(master_panel$fin)),
  " observaciones disponibles."
)
message(
  "ECI: ", sum(!is.na(master_panel$eci)),
  " observaciones disponibles."
)
message(
  "HHI/DIVX: ",
  sum(!is.na(master_panel$hhi)), "/",
  sum(!is.na(master_panel$divx)),
  " observaciones disponibles."
)
