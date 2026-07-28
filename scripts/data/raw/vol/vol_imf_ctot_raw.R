# CAPA: RAW
# VARIABLE FUTURA: VOL
# SALIDAS: data/raw/vol/
# Proposito: preparar los indices raw que alimentaran VOL.
# Entrada principal: IMF Commodity Terms of Trade (CTOT), API SDMX 3.0.
# Salidas: indices anuales en niveles, formatos CSV y Stata, y diagnosticos.

# Reunir las ubicaciones desde las cuales puede encontrarse el helper de rutas.
helper_path <- c(
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)))), "project_paths.R")
  },
  file.path("scripts", "project_paths.R"),
  file.path("..", "..", "..", "project_paths.R"),
  file.path("..", "project_paths.R"),
  "project_paths.R"
)

# Conservar la primera ubicacion candidata que exista realmente.
helper_path <- helper_path[file.exists(helper_path)][1]
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}

# Ejecutar el helper y obtener la raiz absoluta del repositorio.
source(helper_path)
project_path <- find_project_path()

# Verificar que exista una biblioteca capaz de escribir archivos Stata.
if (
  !requireNamespace("haven", quietly = TRUE) &&
    !requireNamespace("foreign", quietly = TRUE)
) {
  stop("Falta una biblioteca compatible con Stata: haven o foreign.")
}

# Definir la consulta oficial del IMF Data API.
api_url <- paste0(
  "https://api.imf.org/external/sdmx/3.0/data/dataflow/",
  "IMF.RES/CTOT/+/",
  "*.CEMPI_CTOTNX_TT.H_FW_IX.A"
)

# Construir las rutas de entrada auxiliar y salida raw.
wdi_file <- file.path(
  project_path,
  "data",
  "raw",
  "world_bank_wdi",
  "wdi_thesis_inputs_1980_2022.csv"
)
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
output_path <- file.path(
  project_path,
  "data",
  "raw",
  "vol",
  "imf_ctot"
)
dir.create(output_path, recursive = TRUE, showWarnings = FALSE)

# Detener el script si faltan los insumos locales para nombres y diagnosticos.
if (!file.exists(wdi_file)) {
  stop("No se encontro el panel WDI compartido para recuperar nombres de pais.")
}
if (!file.exists(sample_file)) {
  stop("No se encontro data/processed/dres/dres_sample_20.csv.")
}

# Guardar una copia exacta de la respuesta tabular de la API oficial. El
# descargador usa solamente la biblioteca estandar de Python porque la
# instalacion local de R no dispone de credenciales SSL compatibles con el
# portal SDMX del FMI.
source_file <- file.path(output_path, "imf_ctot_api_source.csv")
python_path <- Sys.which("python")
if (!nzchar(python_path)) {
  stop("No se encontro Python para descargar la respuesta SDMX del FMI.")
}
download_script <- file.path(
  project_path,
  "scripts",
  "data",
  "raw",
  "vol",
  "download_imf_ctot_raw.py"
)
download_status <- system2(
  python_path,
  args = c(
    shQuote(download_script),
    shQuote(api_url),
    shQuote(source_file)
  )
)
if (download_status != 0L || !file.exists(source_file)) {
  stop("No fue posible descargar el flujo CTOT desde la API oficial del FMI.")
}

# Leer la respuesta SDMX y comprobar su estructura.
api_data <- read.csv(
  source_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
required_api_columns <- c(
  "STRUCTURE_ID",
  "COUNTRY",
  "INDICATOR",
  "WGT_TYPE",
  "FREQUENCY",
  "TIME_PERIOD",
  "OBS_VALUE"
)
missing_api_columns <- setdiff(required_api_columns, names(api_data))
if (length(missing_api_columns) > 0L) {
  stop(
    "La respuesta del FMI no contiene las columnas esperadas: ",
    paste(missing_api_columns, collapse = ", ")
  )
}

# Conservar exclusivamente la serie anual y la ponderacion fija acordadas.
api_data <- api_data[
  api_data$INDICATOR == "CEMPI_CTOTNX_TT" &
    api_data$WGT_TYPE == "H_FW_IX" &
    api_data$FREQUENCY == "A",
  ,
  drop = FALSE
]
api_data$COUNTRY <- toupper(trimws(api_data$COUNTRY))
api_data$TIME_PERIOD <- as.integer(api_data$TIME_PERIOD)
api_data$OBS_VALUE <- as.numeric(api_data$OBS_VALUE)

# Validar llave, identificadores, ponderaciones y valores del indice.
if (
  anyDuplicated(
    api_data[c("COUNTRY", "INDICATOR", "WGT_TYPE", "FREQUENCY", "TIME_PERIOD")]
  ) > 0L
) {
  stop("La respuesta CTOT contiene llaves de serie-anio duplicadas.")
}
if (any(!grepl("^[A-Z]{3}$", api_data$COUNTRY))) {
  stop("La respuesta CTOT contiene codigos de pais invalidos.")
}
if (any(api_data$WGT_TYPE != "H_FW_IX")) {
  stop("La respuesta CTOT contiene ponderaciones no solicitadas.")
}
observed_api_values <- api_data$OBS_VALUE[!is.na(api_data$OBS_VALUE)]
if (
  any(!is.finite(observed_api_values)) ||
    any(observed_api_values <= 0)
) {
  stop("Los indices CTOT contienen valores no positivos o no finitos.")
}

# Conservar en el extracto de la tesis solamente 1962-2022.
thesis_source <- api_data[
  api_data$TIME_PERIOD %in% 1962:2022,
  c("COUNTRY", "TIME_PERIOD", "WGT_TYPE", "OBS_VALUE"),
  drop = FALSE
]

# Seleccionar y renombrar la unica variante de ponderaciones fijas.
fixed_data <- thesis_source[
  thesis_source$WGT_TYPE == "H_FW_IX",
  c("COUNTRY", "TIME_PERIOD", "OBS_VALUE"),
  drop = FALSE
]
names(fixed_data) <- c(
  "country_iso3_code",
  "year",
  "ctot_net_export_price_fixed"
)

# Conservar los niveles sin transformarlos.
ctot_raw <- fixed_data
if (anyDuplicated(ctot_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("El extracto raw de CTOT contiene llaves pais-anio duplicadas.")
}

# Recuperar nombres de pais desde el panel WDI compartido.
wdi_inputs <- read.csv(
  wdi_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
country_lookup <- unique(
  wdi_inputs[c("country_iso3_code", "country")]
)
country_lookup <- country_lookup[
  !duplicated(country_lookup$country_iso3_code),
  ,
  drop = FALSE
]
ctot_raw <- merge(
  ctot_raw,
  country_lookup,
  by = "country_iso3_code",
  all.x = TRUE,
  sort = FALSE
)
ctot_raw <- ctot_raw[
  ,
  c(
    "country_iso3_code",
    "country",
    "year",
    "ctot_net_export_price_fixed"
  )
]
ctot_raw <- ctot_raw[
  order(ctot_raw$country_iso3_code, ctot_raw$year),
]
row.names(ctot_raw) <- NULL

# Leer la muestra DRES y construir la cuadricula 1996-2022.
dres_sample <- read.csv(
  sample_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  fileEncoding = "UTF-8"
)
analysis_years <- 1996:2022
sample_grid <- merge(
  expand.grid(
    country_iso3_code = sort(unique(dres_sample$country_iso3_code)),
    year = analysis_years,
    stringsAsFactors = FALSE
  ),
  dres_sample[c("country_iso3_code", "country")],
  by = "country_iso3_code",
  all.x = TRUE,
  sort = FALSE
)
sample_grid <- merge(
  sample_grid,
  ctot_raw[
    ,
    c(
      "country_iso3_code",
      "year",
      "ctot_net_export_price_fixed"
    )
  ],
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
sample_grid <- sample_grid[
  order(sample_grid$country_iso3_code, sample_grid$year),
]
row.names(sample_grid) <- NULL

# Confirmar que la cuadricula contiene 55 paises por 27 anios.
expected_cells <- nrow(dres_sample) * length(analysis_years)
if (nrow(sample_grid) != expected_cells) {
  stop(
    "La cuadricula DRES deberia contener ", expected_cells,
    " filas y contiene ", nrow(sample_grid), "."
  )
}
if (anyDuplicated(sample_grid[c("country_iso3_code", "year")]) > 0L) {
  stop("La cuadricula DRES de CTOT contiene llaves duplicadas.")
}

# Evaluar si cada pais-anio tendria los seis niveles necesarios para calcular
# cinco variaciones anuales y su desviacion estandar movil. Este diagnostico no
# construye VOL ni agrega transformaciones a la capa raw.
fixed_lookup <- setNames(
  ctot_raw$ctot_net_export_price_fixed,
  paste(ctot_raw$country_iso3_code, ctot_raw$year, sep = "_")
)
sample_grid$prospective_vol_5y_eligible <- mapply(
  function(country_code, current_year) {
    required_keys <- paste(
      country_code,
      (current_year - 5L):current_year,
      sep = "_"
    )
    required_values <- fixed_lookup[required_keys]
    length(required_values) == 6L && all(!is.na(required_values))
  },
  sample_grid$country_iso3_code,
  sample_grid$year
)

# Construir el diagnostico de cobertura por pais.
country_coverage_rows <- lapply(
  sort(unique(sample_grid$country_iso3_code)),
  function(country_code) {
    country_data <- sample_grid[
      sample_grid$country_iso3_code == country_code,
      ,
      drop = FALSE
    ]
    fixed_observed <- !is.na(
      country_data$ctot_net_export_price_fixed
    )
    eligible <- country_data$prospective_vol_5y_eligible
    data.frame(
      country_iso3_code = country_code,
      country = country_data$country[1],
      expected_years = length(analysis_years),
      fixed_weight_observed_years = sum(fixed_observed),
      prospective_vol_5y_eligible_years = sum(eligible),
      fixed_weight_missing_years = paste(
        country_data$year[!fixed_observed],
        collapse = ";"
      ),
      prospective_vol_5y_missing_years = paste(
        country_data$year[!eligible],
        collapse = ";"
      ),
      fixed_weight_complete_1996_2022 = all(fixed_observed),
      prospective_vol_5y_complete_1996_2022 = all(eligible),
      stringsAsFactors = FALSE
    )
  }
)
country_coverage <- do.call(rbind, country_coverage_rows)
row.names(country_coverage) <- NULL

# Resumir cobertura raw y elegibilidad futura de la definicion de VOL.
fixed_observed <- !is.na(sample_grid$ctot_net_export_price_fixed)
eligible <- sample_grid$prospective_vol_5y_eligible
coverage_summary <- data.frame(
  source_indicator = "CEMPI_CTOTNX_TT",
  weight_code = "H_FW_IX",
  expected_country_years_1996_2022 = expected_cells,
  fixed_weight_observed_country_years = sum(fixed_observed),
  fixed_weight_coverage_percent = 100 * sum(fixed_observed) / expected_cells,
  countries_with_fixed_weight_data = sum(
    country_coverage$fixed_weight_observed_years > 0L
  ),
  countries_complete_fixed_weight_1996_2022 = sum(
    country_coverage$fixed_weight_complete_1996_2022
  ),
  countries_without_fixed_weight_data = sum(
    country_coverage$fixed_weight_observed_years == 0L
  ),
  prospective_vol_5y_eligible_country_years = sum(eligible),
  prospective_vol_5y_coverage_percent = 100 * sum(eligible) / expected_cells,
  countries_complete_prospective_vol_5y = sum(
    country_coverage$prospective_vol_5y_complete_1996_2022
  ),
  stringsAsFactors = FALSE
)

# Documentar la descarga y el corte aplicado por la tesis.
download_manifest <- data.frame(
  provider = "International Monetary Fund",
  dataset = "Commodity Terms of Trade (CTOT)",
  dataflow = unique(api_data$STRUCTURE_ID)[1],
  indicator = "CEMPI_CTOTNX_TT",
  indicator_description = paste(
    "Commodity Net Export Price Index, individual commodities weighted",
    "by the ratio of net exports to total commodity trade"
  ),
  weight_type = "H_FW_IX",
  frequency = "Annual",
  source_url = api_url,
  downloaded_at_utc = format(
    Sys.time(),
    tz = "UTC",
    format = "%Y-%m-%d %H:%M:%S UTC"
  ),
  source_first_year = min(api_data$TIME_PERIOD, na.rm = TRUE),
  source_last_year = max(api_data$TIME_PERIOD, na.rm = TRUE),
  thesis_extract_first_year = 1962L,
  thesis_extract_last_year = 2022L,
  source_rows = nrow(api_data),
  extract_rows = nrow(ctot_raw),
  stringsAsFactors = FALSE
)

# Construir los nombres de las salidas.
csv_file <- file.path(output_path, "vol_ctot_input_1962_2022.csv")
dta_file <- file.path(output_path, "vol_ctot_input_1962_2022.dta")
summary_file <- file.path(
  output_path,
  "vol_raw_coverage_summary_dres20.csv"
)
country_coverage_file <- file.path(
  output_path,
  "vol_raw_country_coverage_dres20.csv"
)
manifest_file <- file.path(
  output_path,
  "imf_ctot_download_manifest.csv"
)

# Guardar los niveles raw sin logaritmos, diferencias ni ventanas moviles.
write.csv(
  ctot_raw,
  csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
if (requireNamespace("haven", quietly = TRUE)) {
  haven::write_dta(ctot_raw, dta_file, version = 14)
} else {
  foreign::write.dta(ctot_raw, dta_file, version = 12)
}
write.csv(
  coverage_summary,
  summary_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
write.csv(
  country_coverage,
  country_coverage_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
write.csv(
  download_manifest,
  manifest_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

message("Raw de VOL-CTOT terminado.")
message("Archivo CSV: ", csv_file)
print(coverage_summary)
