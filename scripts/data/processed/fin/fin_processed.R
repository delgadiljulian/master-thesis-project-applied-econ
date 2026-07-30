# CAPA: PROCESSED
# VARIABLE: FIN
# ENTRADAS: data/raw/fin/world_bank_wdi/,
#           data/raw/world_bank_wdi/ y data/processed/dres/
# SALIDAS: data/processed/fin/
#
# Construye la única FIN activa con el crédito doméstico al sector privado
# otorgado por bancos como porcentaje del PIB (FD.AST.PRVT.GD.ZS). La antigua
# medida amplia FS.AST.PRVT.GD.ZS se conserva como referencia de contraste y
# nunca se mezcla con la serie activa.

# Reunir ubicaciones posibles del helper compartido de rutas.
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

# Definir período, muestra y umbrales de aceptación de la sustitución.
start_year <- 1996L
end_year <- 2021L
analysis_years <- start_year:end_year
expected_country_count <- 55L
expected_row_count <- expected_country_count * length(analysis_years)
active_indicator_code <- "FD.AST.PRVT.GD.ZS"
active_indicator_name <- (
  "Domestic credit to private sector by banks (% of GDP)"
)
broad_reference_code <- "FS.AST.PRVT.GD.ZS"
minimum_active_observations <- 1300L
minimum_overlap_correlation <- 0.95
maximum_overlap_mae <- 3.00
large_difference_threshold <- 5.00
very_large_difference_threshold <- 20.00

# Definir entradas y salidas oficiales.
active_raw_file <- file.path(
  project_path,
  "data",
  "raw",
  "fin",
  "world_bank_wdi",
  "fin_banks_wdi_input_1980_2025.csv"
)
active_metadata_file <- file.path(
  project_path,
  "data",
  "raw",
  "fin",
  "world_bank_wdi",
  "fin_banks_wdi_metadata.csv"
)
active_manifest_file <- file.path(
  project_path,
  "data",
  "raw",
  "fin",
  "world_bank_wdi",
  "download_manifest.csv"
)
broad_reference_file <- file.path(
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
processed_path <- file.path(project_path, "data", "processed", "fin")
panel_csv_file <- file.path(processed_path, "fin_data.csv")
panel_dta_file <- file.path(processed_path, "fin_data.dta")
diagnostics_file <- file.path(
  processed_path,
  "fin_country_year_diagnostics_1996_2021.csv"
)
comparison_file <- file.path(
  processed_path,
  "fin_banks_broad_comparison_1996_2021.csv"
)
country_comparison_file <- file.path(
  processed_path,
  "fin_banks_broad_country_comparison_1996_2021.csv"
)
country_coverage_file <- file.path(
  processed_path,
  "fin_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  processed_path,
  "fin_year_coverage_1996_2021.csv"
)
validation_file <- file.path(
  processed_path,
  "fin_validation_summary.csv"
)

# Comprobar entradas, paquete Stata y posibles bloqueos de archivos.
required_files <- c(
  active_raw_file,
  active_metadata_file,
  active_manifest_file,
  broad_reference_file,
  sample_file
)
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
  comparison_file,
  country_comparison_file,
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

# Leer y validar la muestra fija DRES.
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
    any(!nzchar(dres_sample$country)) ||
    anyDuplicated(dres_sample$country_iso3_code) > 0L ||
    nrow(dres_sample) != expected_country_count
) {
  stop("La muestra DRES no contiene exactamente 55 países válidos.")
}
dres_sample <- dres_sample[order(dres_sample$country_iso3_code), ]
row.names(dres_sample) <- NULL

# Ejecutar la siguiente instrucción del bloque
panel_grid <- merge(
  dres_sample,
  data.frame(year = analysis_years),
  by = NULL,
  sort = FALSE
)
panel_grid <- panel_grid[
  order(panel_grid$country_iso3_code, panel_grid$year),
]
row.names(panel_grid) <- NULL

# Confirmar la identidad de la captura mediante metadatos y manifiesto.
active_metadata <- read.csv(
  active_metadata_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
if (
  nrow(active_metadata) != 1L ||
    active_metadata$indicator_code[1] != active_indicator_code ||
    active_metadata$indicator_name[1] != active_indicator_name
) {
  stop("Los metadatos no corresponden a la definición bancaria de FIN.")
}

# Cargar el archivo de datos
active_manifest <- read.csv(
  active_manifest_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
if (
  nrow(active_manifest) != 1L ||
    active_manifest$indicator_code[1] != active_indicator_code ||
    as.integer(active_manifest$sample_countries[1]) !=
      expected_country_count ||
    as.integer(active_manifest$analysis_country_years[1]) !=
      expected_row_count
) {
  stop("El manifiesto de FIN bancaria no coincide con la muestra esperada.")
}

# Leer y validar la serie bancaria activa.
active_raw <- read.csv(
  active_raw_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  fileEncoding = "UTF-8"
)
active_value_column <- "domestic_credit_private_banks_pct_gdp"
required_active_columns <- c(
  "country_iso3_code",
  "country_dres",
  "country_wdi",
  "year",
  active_value_column,
  "indicator_code",
  "indicator_name"
)
missing_active_columns <- setdiff(
  required_active_columns,
  names(active_raw)
)
if (length(missing_active_columns) > 0L) {
  stop(
    "Faltan columnas en la captura bancaria WDI: ",
    paste(missing_active_columns, collapse = ", ")
  )
}
active_raw$country_iso3_code <- toupper(
  trimws(active_raw$country_iso3_code)
)
active_raw$year <- as.integer(active_raw$year)
active_raw[[active_value_column]] <- as.numeric(
  active_raw[[active_value_column]]
)
if (
  any(!grepl("^[A-Z]{3}$", active_raw$country_iso3_code)) ||
    any(is.na(active_raw$year)) ||
    anyDuplicated(active_raw[c("country_iso3_code", "year")]) > 0L
) {
  stop("La captura bancaria contiene llaves país-año inválidas.")
}
if (
  any(active_raw$indicator_code != active_indicator_code) ||
    any(active_raw$indicator_name != active_indicator_name)
) {
  stop("La captura bancaria contiene otra definición de indicador.")
}
observed_active_raw <- !is.na(active_raw[[active_value_column]])
if (
  any(
    active_raw[[active_value_column]][observed_active_raw] < 0 |
      !is.finite(active_raw[[active_value_column]][observed_active_raw])
  )
) {
  stop("La captura bancaria contiene valores negativos o no finitos.")
}

# Ejecutar la siguiente instrucción del bloque
active_selected <- active_raw[
  active_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    active_raw$year %in% analysis_years,
  c("country_iso3_code", "year", active_value_column),
  drop = FALSE
]
if (
  nrow(active_selected) != expected_row_count ||
    anyDuplicated(active_selected[c("country_iso3_code", "year")]) > 0L
) {
  stop("La captura bancaria no conserva las 1.430 llaves esperadas.")
}
names(active_selected)[3] <- "fin_banks_wdi"

# Leer la antigua definición amplia únicamente como referencia.
broad_raw <- read.csv(
  broad_reference_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  fileEncoding = "UTF-8"
)
broad_value_column <- "domestic_credit_private_pct_gdp"
required_broad_columns <- c(
  "country_iso3_code",
  "year",
  broad_value_column
)
missing_broad_columns <- setdiff(
  required_broad_columns,
  names(broad_raw)
)
if (length(missing_broad_columns) > 0L) {
  stop(
    "Faltan columnas en la referencia amplia WDI: ",
    paste(missing_broad_columns, collapse = ", ")
  )
}
broad_raw$country_iso3_code <- toupper(
  trimws(broad_raw$country_iso3_code)
)
broad_raw$year <- as.integer(broad_raw$year)
broad_raw[[broad_value_column]] <- as.numeric(
  broad_raw[[broad_value_column]]
)
if (anyDuplicated(broad_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("La referencia amplia WDI contiene llaves duplicadas.")
}
broad_selected <- broad_raw[
  broad_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    broad_raw$year %in% analysis_years,
  c("country_iso3_code", "year", broad_value_column),
  drop = FALSE
]
names(broad_selected)[3] <- "fin_broad_wdi"

# Integrar ambas definiciones sin rellenar selectivamente ninguna de ellas.
fin_work <- merge(
  panel_grid,
  active_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
fin_work <- merge(
  fin_work,
  broad_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
fin_work <- fin_work[
  order(fin_work$country_iso3_code, fin_work$year),
]
row.names(fin_work) <- NULL

# Adoptar íntegramente la definición bancaria como la única FIN activa.
fin_work$fin <- fin_work$fin_banks_wdi
fin_work$active_source_code <- active_indicator_code
fin_work$broad_reference_code <- broad_reference_code
fin_work$value_above_100_percent <- as.integer(
  !is.na(fin_work$fin) & fin_work$fin > 100
)
fin_work$recovered_relative_to_broad <- as.integer(
  !is.na(fin_work$fin_banks_wdi) & is.na(fin_work$fin_broad_wdi)
)
fin_work$missing_in_bank_but_observed_in_broad <- as.integer(
  is.na(fin_work$fin_banks_wdi) & !is.na(fin_work$fin_broad_wdi)
)
fin_work$difference_banks_minus_broad <- (
  fin_work$fin_banks_wdi - fin_work$fin_broad_wdi
)
fin_work$absolute_difference <- abs(
  fin_work$difference_banks_minus_broad
)
fin_work$absolute_difference_above_5pp <- as.integer(
  !is.na(fin_work$absolute_difference) &
    fin_work$absolute_difference > large_difference_threshold
)
fin_work$absolute_difference_above_20pp <- as.integer(
  !is.na(fin_work$absolute_difference) &
    fin_work$absolute_difference > very_large_difference_threshold
)
fin_work$availability_status <- ifelse(
  !is.na(fin_work$fin_banks_wdi) & !is.na(fin_work$fin_broad_wdi),
  "observed_in_both",
  ifelse(
    !is.na(fin_work$fin_banks_wdi) & is.na(fin_work$fin_broad_wdi),
    "observed_only_in_bank_definition",
    ifelse(
      is.na(fin_work$fin_banks_wdi) & !is.na(fin_work$fin_broad_wdi),
      "observed_only_in_broad_definition",
      "missing_in_both"
    )
  )
)

# Ejecutar la siguiente instrucción del bloque
fin_panel <- fin_work[, c(
  "country_iso3_code",
  "country",
  "year",
  "fin"
)]

# Validar dimensión, dominio e identidad de la variable activa.
if (
  nrow(fin_panel) != expected_row_count ||
    length(unique(fin_panel$country_iso3_code)) != expected_country_count ||
    anyDuplicated(fin_panel[c("country_iso3_code", "year")]) > 0L
) {
  stop("FIN no conserva una cuadrícula única de 55 países y 26 años.")
}
available_fin <- fin_panel$fin[!is.na(fin_panel$fin)]
if (
  length(available_fin) < minimum_active_observations ||
    any(available_fin < 0 | !is.finite(available_fin))
) {
  stop("La FIN bancaria no supera los controles mínimos de cobertura y dominio.")
}
identity_difference <- abs(fin_work$fin - fin_work$fin_banks_wdi)
max_identity_difference <- if (all(is.na(identity_difference))) {
  0
} else {
  max(identity_difference, na.rm = TRUE)
}
identity_mismatch_count <- sum(
  identity_difference > 1e-12,
  na.rm = TRUE
)
if (identity_mismatch_count > 0L) {
  stop("FIN no coincide exactamente con la definición bancaria activa.")
}

# Evaluar concordancia con la definición amplia anterior.
overlap <- fin_work[
  !is.na(fin_work$fin_banks_wdi) &
    !is.na(fin_work$fin_broad_wdi),
  ,
  drop = FALSE
]
if (nrow(overlap) < 2L) {
  stop("No existe superposición suficiente para validar ambas definiciones.")
}
overlap_correlation <- cor(
  overlap$fin_banks_wdi,
  overlap$fin_broad_wdi
)
overlap_mae <- mean(overlap$absolute_difference)
overlap_rmse <- sqrt(mean(overlap$difference_banks_minus_broad^2))
overlap_median_abs_difference <- median(overlap$absolute_difference)
overlap_p95_abs_difference <- as.numeric(
  quantile(overlap$absolute_difference, probs = 0.95, names = FALSE)
)
overlap_max_abs_difference <- max(overlap$absolute_difference)
broad_reference_available <- sum(!is.na(fin_work$fin_broad_wdi))
active_available <- sum(!is.na(fin_work$fin_banks_wdi))
recovered_count <- sum(fin_work$recovered_relative_to_broad)
broad_not_covered_count <- sum(
  fin_work$missing_in_bank_but_observed_in_broad
)
replacement_validation_passed <- (
  active_available >= minimum_active_observations &&
    active_available > broad_reference_available &&
    broad_not_covered_count == 0L &&
    is.finite(overlap_correlation) &&
    overlap_correlation >= minimum_overlap_correlation &&
    overlap_mae <= maximum_overlap_mae
)
if (!replacement_validation_passed) {
  stop(
    "La definición bancaria no supera los umbrales de sustitución: ",
    "correlación=", round(overlap_correlation, 4),
    ", MAE=", round(overlap_mae, 4),
    ", faltantes frente a la serie amplia=", broad_not_covered_count, "."
  )
}

# Construir cobertura por país.
country_coverage_rows <- lapply(
  split(fin_work, fin_work$country_iso3_code),
  function(country_data) {
    observed <- !is.na(country_data$fin)
    available_years <- sum(observed)
    data.frame(
      country_iso3_code = country_data$country_iso3_code[1],
      country = country_data$country[1],
      expected_years = length(analysis_years),
      available_fin_years = available_years,
      missing_fin_years = length(analysis_years) - available_years,
      coverage_share = available_years / length(analysis_years),
      first_available_year = if (any(observed)) {
        min(country_data$year[observed])
      } else {
        NA_integer_
      },
      last_available_year = if (any(observed)) {
        max(country_data$year[observed])
      } else {
        NA_integer_
      },
      observations_above_100_percent = sum(
        country_data$value_above_100_percent
      ),
      recovered_relative_to_broad = sum(
        country_data$recovered_relative_to_broad
      ),
      missing_year_list = paste(
        country_data$year[!observed],
        collapse = ";"
      ),
      complete_1996_2021 = as.integer(
        available_years == length(analysis_years)
      ),
      stringsAsFactors = FALSE
    )
  }
)
coverage_by_country <- do.call(rbind, country_coverage_rows)
coverage_by_country <- coverage_by_country[
  order(coverage_by_country$country_iso3_code),
]
row.names(coverage_by_country) <- NULL

# Construir cobertura por año.
year_coverage_rows <- lapply(
  split(fin_work, fin_work$year),
  function(year_data) {
    available_countries <- sum(!is.na(year_data$fin))
    data.frame(
      year = year_data$year[1],
      expected_countries = expected_country_count,
      available_fin_countries = available_countries,
      missing_fin_countries = expected_country_count - available_countries,
      coverage_share = available_countries / expected_country_count,
      observations_above_100_percent = sum(
        year_data$value_above_100_percent
      ),
      recovered_relative_to_broad = sum(
        year_data$recovered_relative_to_broad
      ),
      stringsAsFactors = FALSE
    )
  }
)
coverage_by_year <- do.call(rbind, year_coverage_rows)
coverage_by_year <- coverage_by_year[
  order(coverage_by_year$year),
]
row.names(coverage_by_year) <- NULL

# Resumir concordancia por país.
country_comparison_rows <- lapply(
  split(fin_work, fin_work$country_iso3_code),
  function(country_data) {
    country_overlap <- country_data[
      !is.na(country_data$fin_banks_wdi) &
        !is.na(country_data$fin_broad_wdi),
      ,
      drop = FALSE
    ]
    country_correlation <- NA_real_
    if (
      nrow(country_overlap) >= 2L &&
        sd(country_overlap$fin_banks_wdi) > 0 &&
        sd(country_overlap$fin_broad_wdi) > 0
    ) {
      country_correlation <- cor(
        country_overlap$fin_banks_wdi,
        country_overlap$fin_broad_wdi
      )
    }
    data.frame(
      country_iso3_code = country_data$country_iso3_code[1],
      country = country_data$country[1],
      bank_available_years = sum(!is.na(country_data$fin_banks_wdi)),
      broad_available_years = sum(!is.na(country_data$fin_broad_wdi)),
      recovered_relative_to_broad = sum(
        country_data$recovered_relative_to_broad
      ),
      overlap_years = nrow(country_overlap),
      overlap_correlation = country_correlation,
      overlap_mae_percentage_points = if (nrow(country_overlap) > 0L) {
        mean(country_overlap$absolute_difference)
      } else {
        NA_real_
      },
      overlap_max_abs_difference = if (nrow(country_overlap) > 0L) {
        max(country_overlap$absolute_difference)
      } else {
        NA_real_
      },
      overlap_abs_difference_above_5pp = sum(
        country_data$absolute_difference_above_5pp
      ),
      overlap_abs_difference_above_20pp = sum(
        country_data$absolute_difference_above_20pp
      ),
      stringsAsFactors = FALSE
    )
  }
)
country_comparison <- do.call(rbind, country_comparison_rows)
country_comparison <- country_comparison[
  order(country_comparison$country_iso3_code),
]
row.names(country_comparison) <- NULL

# Guardar panel, diagnósticos y comparaciones.
write.csv(
  fin_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  fin_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
write.csv(
  fin_work,
  diagnostics_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
write.csv(
  fin_work[, c(
    "country_iso3_code",
    "country",
    "year",
    "fin_banks_wdi",
    "fin_broad_wdi",
    "difference_banks_minus_broad",
    "absolute_difference",
    "recovered_relative_to_broad",
    "absolute_difference_above_5pp",
    "absolute_difference_above_20pp",
    "availability_status"
  )],
  comparison_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
write.csv(
  country_comparison,
  country_comparison_file,
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
    !identical(as.integer(csv_check$year), as.integer(dta_check$year)) ||
    !identical(
      as.character(csv_check$country),
      as.character(dta_check$country)
    ) ||
    !identical(is.na(csv_check$fin), is.na(dta_check$fin))
) {
  stop("Las salidas CSV y Stata no conservan las mismas llaves o faltantes.")
}
format_difference <- abs(csv_check$fin - dta_check$fin)
max_csv_stata_difference <- if (all(is.na(format_difference))) {
  0
} else {
  max(format_difference, na.rm = TRUE)
}
if (max_csv_stata_difference > 1e-10) {
  stop("Las salidas CSV y Stata difieren numéricamente.")
}

# Guardar un resumen auditable de las verificaciones.
validation_summary <- data.frame(
  metric = c(
    "active_source_code",
    "active_source_name",
    "broad_reference_code",
    "start_year",
    "end_year",
    "dres_sample_countries",
    "expected_country_years",
    "actual_country_years",
    "available_fin_country_years",
    "missing_fin_country_years",
    "coverage_percent",
    "countries_with_any_fin",
    "countries_complete_1996_2021",
    "countries_with_partial_coverage",
    "countries_without_fin",
    "broad_reference_available_country_years",
    "broad_reference_missing_country_years",
    "recovered_relative_to_broad",
    "broad_observed_but_bank_missing",
    "overlap_country_years",
    "overlap_correlation",
    "overlap_mae_percentage_points",
    "overlap_rmse_percentage_points",
    "overlap_median_abs_difference",
    "overlap_p95_abs_difference",
    "overlap_max_abs_difference",
    "overlap_abs_difference_above_5pp",
    "overlap_abs_difference_above_20pp",
    "minimum_required_active_observations",
    "minimum_required_correlation",
    "maximum_allowed_mae",
    "replacement_validation_passed",
    "duplicate_country_year_keys",
    "negative_or_nonfinite_value_count",
    "observations_above_100_percent",
    "identity_mismatch_count",
    "identity_max_abs_difference",
    "fin_minimum",
    "fin_median",
    "fin_maximum",
    "csv_stata_max_abs_difference"
  ),
  value = c(
    active_indicator_code,
    active_indicator_name,
    broad_reference_code,
    start_year,
    end_year,
    expected_country_count,
    expected_row_count,
    nrow(fin_panel),
    active_available,
    sum(is.na(fin_panel$fin)),
    100 * mean(!is.na(fin_panel$fin)),
    sum(coverage_by_country$available_fin_years > 0L),
    sum(coverage_by_country$complete_1996_2021 == 1L),
    sum(
      coverage_by_country$available_fin_years > 0L &
        coverage_by_country$available_fin_years <
          length(analysis_years)
    ),
    sum(coverage_by_country$available_fin_years == 0L),
    broad_reference_available,
    sum(is.na(fin_work$fin_broad_wdi)),
    recovered_count,
    broad_not_covered_count,
    nrow(overlap),
    overlap_correlation,
    overlap_mae,
    overlap_rmse,
    overlap_median_abs_difference,
    overlap_p95_abs_difference,
    overlap_max_abs_difference,
    sum(fin_work$absolute_difference_above_5pp),
    sum(fin_work$absolute_difference_above_20pp),
    minimum_active_observations,
    minimum_overlap_correlation,
    maximum_overlap_mae,
    replacement_validation_passed,
    anyDuplicated(fin_panel[c("country_iso3_code", "year")]),
    sum(available_fin < 0 | !is.finite(available_fin)),
    sum(fin_work$value_above_100_percent),
    identity_mismatch_count,
    max_identity_difference,
    min(available_fin),
    median(available_fin),
    max(available_fin),
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
message("FIN procesada correctamente con la definición bancaria WDI.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
message(
  "Cobertura activa: ", active_available, " de ", expected_row_count,
  " país-años (",
  round(100 * active_available / expected_row_count, 2), "%)."
)
message(
  "Comparación bancaria-amplia: correlación=",
  round(overlap_correlation, 4),
  ", MAE=", round(overlap_mae, 4), " puntos porcentuales."
)
message(
  "Valores recuperados frente a la definición amplia: ",
  recovered_count, "."
)
