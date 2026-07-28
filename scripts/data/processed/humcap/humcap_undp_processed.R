# CAPA: PROCESSED
# VARIABLE: HUMCAP
# ENTRADAS: data/raw/humcap/undp_hdr/, data/raw/pwt/ y data/processed/dres/
# SALIDAS: data/processed/humcap/
#
# Construye una única HUMCAP activa aplicando la función de retornos educativos
# de PWT a los años medios de escolaridad de adultos publicados por el PNUD.
# PWT 11.0 se conserva únicamente como referencia de contraste.

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

start_year <- 1996L
end_year <- 2021L
analysis_years <- start_year:end_year
expected_country_count <- 55L
expected_row_count <- expected_country_count * length(analysis_years)
active_indicator_code <- "UNDP_HDR_MYS_PWT_RETURNS"
active_source_code <- "UNDP_HDR_MYS"
reference_source_code <- "PWT11.0:hc"
minimum_active_observations <- 1390L
minimum_recovered_observations <- 180L
maximum_lost_observations <- 3L
minimum_level_correlation <- 0.90
minimum_within_correlation <- 0.85
minimum_median_country_correlation <- 0.95
minimum_annual_change_correlation <- 0.45
maximum_relative_mae <- 0.08

active_raw_file <- file.path(
  project_path,
  "data",
  "raw",
  "humcap",
  "undp_hdr",
  "humcap_undp_mys_input_1990_2023.csv"
)
active_metadata_file <- file.path(
  project_path,
  "data",
  "raw",
  "humcap",
  "undp_hdr",
  "humcap_undp_metadata.csv"
)
active_manifest_file <- file.path(
  project_path,
  "data",
  "raw",
  "humcap",
  "undp_hdr",
  "download_manifest.csv"
)
pwt_reference_file <- file.path(
  project_path,
  "data",
  "raw",
  "humcap",
  "undp_hdr",
  "humcap_pwt11_reference_1996_2021.csv"
)
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
processed_path <- file.path(project_path, "data", "processed", "humcap")
panel_csv_file <- file.path(processed_path, "humcap_data.csv")
panel_dta_file <- file.path(processed_path, "humcap_data.dta")
diagnostics_file <- file.path(
  processed_path,
  "humcap_country_year_diagnostics_1996_2021.csv"
)
comparison_file <- file.path(
  processed_path,
  "humcap_undp_pwt_comparison_1996_2021.csv"
)
country_comparison_file <- file.path(
  processed_path,
  "humcap_undp_pwt_country_comparison_1996_2021.csv"
)
country_coverage_file <- file.path(
  processed_path,
  "humcap_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  processed_path,
  "humcap_year_coverage_1996_2021.csv"
)
validation_file <- file.path(
  processed_path,
  "humcap_validation_summary.csv"
)

required_files <- c(
  active_raw_file,
  active_metadata_file,
  active_manifest_file,
  pwt_reference_file,
  sample_file
)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0L) {
  stop("Faltan archivos requeridos: ", paste(missing_files, collapse = ", "))
}
if (!requireNamespace("foreign", quietly = TRUE)) {
  stop("Falta el paquete de R 'foreign', requerido para archivos Stata.")
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
  nrow(dres_sample) != expected_country_count ||
    anyDuplicated(dres_sample$country_iso3_code) > 0L ||
    any(!grepl("^[A-Z]{3}$", dres_sample$country_iso3_code)) ||
    any(!nzchar(dres_sample$country))
) {
  stop("La muestra DRES no contiene exactamente 55 países válidos.")
}
dres_sample <- dres_sample[order(dres_sample$country_iso3_code), ]
row.names(dres_sample) <- NULL
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

active_metadata <- read.csv(
  active_metadata_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
if (
  nrow(active_metadata) != 1L ||
    active_metadata$indicator_code[1] != active_source_code ||
    active_metadata$population_scope[1] != "Adults ages 25 years and older"
) {
  stop("Los metadatos no corresponden a MYS del PNUD.")
}
active_manifest <- read.csv(
  active_manifest_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
if (
  nrow(active_manifest) != 1L ||
    active_manifest$indicator_code[1] != active_source_code ||
    as.integer(active_manifest$sample_countries[1]) != expected_country_count ||
    as.integer(active_manifest$analysis_country_years[1]) != expected_row_count
) {
  stop("El manifiesto PNUD no coincide con la muestra esperada.")
}

active_raw <- read.csv(
  active_raw_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  fileEncoding = "UTF-8"
)
active_value_column <- "mean_years_schooling_undp"
required_active_columns <- c(
  "country_iso3_code",
  "year",
  active_value_column,
  "indicator_code",
  "indicator_name",
  "source_vintage"
)
missing_active_columns <- setdiff(required_active_columns, names(active_raw))
if (length(missing_active_columns) > 0L) {
  stop(
    "Faltan columnas en la captura PNUD: ",
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
  stop("La captura PNUD contiene llaves país-año inválidas.")
}
if (any(active_raw$indicator_code != active_source_code)) {
  stop("La captura PNUD contiene otro indicador.")
}
observed_mys <- !is.na(active_raw[[active_value_column]])
if (any(
  active_raw[[active_value_column]][observed_mys] < 0 |
    active_raw[[active_value_column]][observed_mys] > 20 |
    !is.finite(active_raw[[active_value_column]][observed_mys])
)) {
  stop("La captura PNUD contiene valores MYS fuera de dominio.")
}
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
  stop("La captura PNUD no conserva las 1.430 llaves esperadas.")
}
names(active_selected)[3] <- "mean_years_schooling_undp"

returns_function <- function(schooling) {
  ifelse(
    schooling <= 4,
    0.134 * schooling,
    ifelse(
      schooling <= 8,
      0.134 * 4 + 0.101 * (schooling - 4),
      0.134 * 4 + 0.101 * 4 + 0.068 * (schooling - 8)
    )
  )
}
active_selected$humcap_undp <- exp(
  returns_function(active_selected$mean_years_schooling_undp)
)

pwt_reference <- read.csv(
  pwt_reference_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  fileEncoding = "UTF-8"
)
required_pwt_columns <- c(
  "country_iso3_code",
  "year",
  "humcap_pwt",
  "reference_source_code"
)
missing_pwt_columns <- setdiff(required_pwt_columns, names(pwt_reference))
if (length(missing_pwt_columns) > 0L) {
  stop(
    "Faltan columnas en la referencia PWT: ",
    paste(missing_pwt_columns, collapse = ", ")
  )
}
pwt_reference$country_iso3_code <- toupper(
  trimws(as.character(pwt_reference$country_iso3_code))
)
pwt_reference$year <- as.integer(pwt_reference$year)
pwt_reference$humcap_pwt <- as.numeric(pwt_reference$humcap_pwt)
if (
  nrow(pwt_reference) != expected_row_count ||
    any(pwt_reference$reference_source_code != reference_source_code) ||
    anyDuplicated(
      pwt_reference[c("country_iso3_code", "year")]
    ) > 0L
) {
  stop("La referencia PWT contiene llaves duplicadas.")
}
pwt_reference <- pwt_reference[
  ,
  c("country_iso3_code", "year", "humcap_pwt")
]

humcap_work <- merge(
  panel_grid,
  active_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
humcap_work <- merge(
  humcap_work,
  pwt_reference,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
humcap_work <- humcap_work[
  order(humcap_work$country_iso3_code, humcap_work$year),
]
row.names(humcap_work) <- NULL
humcap_work$humcap <- humcap_work$humcap_undp
humcap_work$active_source_code <- active_indicator_code
humcap_work$reference_source_code <- reference_source_code
humcap_work$recovered_relative_to_pwt <- as.integer(
  !is.na(humcap_work$humcap_undp) &
    is.na(humcap_work$humcap_pwt)
)
humcap_work$lost_relative_to_pwt <- as.integer(
  is.na(humcap_work$humcap_undp) &
    !is.na(humcap_work$humcap_pwt)
)
humcap_work$difference_undp_minus_pwt <- (
  humcap_work$humcap_undp - humcap_work$humcap_pwt
)
humcap_work$absolute_difference <- abs(
  humcap_work$difference_undp_minus_pwt
)
humcap_work$availability_status <- ifelse(
  !is.na(humcap_work$humcap_undp) &
    !is.na(humcap_work$humcap_pwt),
  "observed_in_both",
  ifelse(
    !is.na(humcap_work$humcap_undp) &
      is.na(humcap_work$humcap_pwt),
    "observed_only_in_undp",
    ifelse(
      is.na(humcap_work$humcap_undp) &
        !is.na(humcap_work$humcap_pwt),
      "observed_only_in_pwt",
      "missing_in_both"
    )
  )
)

humcap_panel <- humcap_work[
  ,
  c("country_iso3_code", "country", "year", "humcap")
]
if (
  nrow(humcap_panel) != expected_row_count ||
    length(unique(humcap_panel$country_iso3_code)) != expected_country_count ||
    anyDuplicated(humcap_panel[c("country_iso3_code", "year")]) > 0L
) {
  stop("HUMCAP no conserva una cuadrícula única de 55 países y 26 años.")
}
available_humcap <- humcap_panel$humcap[!is.na(humcap_panel$humcap)]
if (
  length(available_humcap) < minimum_active_observations ||
    any(available_humcap <= 0 | !is.finite(available_humcap))
) {
  stop("La HUMCAP derivada no supera los controles de cobertura y dominio.")
}

identity_check <- exp(
  returns_function(humcap_work$mean_years_schooling_undp)
)
identity_difference <- abs(humcap_work$humcap - identity_check)
identity_mismatch_count <- sum(identity_difference > 1e-12, na.rm = TRUE)
identity_max_difference <- if (all(is.na(identity_difference))) {
  0
} else {
  max(identity_difference, na.rm = TRUE)
}
if (identity_mismatch_count > 0L) {
  stop("HUMCAP no coincide exactamente con la fórmula declarada.")
}

overlap <- humcap_work[
  !is.na(humcap_work$humcap_undp) &
    !is.na(humcap_work$humcap_pwt),
  ,
  drop = FALSE
]
if (nrow(overlap) < 2L) {
  stop("No existe superposición suficiente entre PNUD y PWT.")
}
level_correlation <- cor(overlap$humcap_undp, overlap$humcap_pwt)
mae <- mean(overlap$absolute_difference)
rmse <- sqrt(mean(overlap$difference_undp_minus_pwt^2))
median_absolute_difference <- median(overlap$absolute_difference)
p95_absolute_difference <- as.numeric(
  quantile(overlap$absolute_difference, probs = 0.95, names = FALSE)
)
maximum_absolute_difference <- max(overlap$absolute_difference)
relative_mae <- mae / mean(overlap$humcap_pwt)

overlap$undp_within <- ave(
  overlap$humcap_undp,
  overlap$country_iso3_code,
  FUN = function(values) values - mean(values)
)
overlap$pwt_within <- ave(
  overlap$humcap_pwt,
  overlap$country_iso3_code,
  FUN = function(values) values - mean(values)
)
within_correlation <- cor(overlap$undp_within, overlap$pwt_within)

annual_change_rows <- lapply(
  split(overlap, overlap$country_iso3_code),
  function(country_data) {
    country_data <- country_data[order(country_data$year), ]
    if (nrow(country_data) < 2L) {
      return(NULL)
    }
    consecutive <- diff(country_data$year) == 1L
    data.frame(
      country_iso3_code = country_data$country_iso3_code[-1][consecutive],
      year = country_data$year[-1][consecutive],
      undp_change = diff(country_data$humcap_undp)[consecutive],
      pwt_change = diff(country_data$humcap_pwt)[consecutive],
      stringsAsFactors = FALSE
    )
  }
)
annual_changes <- do.call(rbind, annual_change_rows)
annual_change_correlation <- cor(
  annual_changes$undp_change,
  annual_changes$pwt_change
)

inverse_returns_function <- function(human_capital) {
  phi <- log(human_capital)
  ifelse(
    phi <= 0.134 * 4,
    phi / 0.134,
    ifelse(
      phi <= 0.134 * 4 + 0.101 * 4,
      4 + (phi - 0.134 * 4) / 0.101,
      8 + (phi - 0.134 * 4 - 0.101 * 4) / 0.068
    )
  )
}
overlap$pwt_implied_schooling <- inverse_returns_function(
  overlap$humcap_pwt
)
overlap$schooling_absolute_difference <- abs(
  overlap$mean_years_schooling_undp -
    overlap$pwt_implied_schooling
)
schooling_mae_years <- mean(overlap$schooling_absolute_difference)
schooling_median_absolute_difference <- median(
  overlap$schooling_absolute_difference
)

country_comparison_rows <- lapply(
  split(humcap_work, humcap_work$country_iso3_code),
  function(country_data) {
    country_overlap <- country_data[
      !is.na(country_data$humcap_undp) &
        !is.na(country_data$humcap_pwt),
      ,
      drop = FALSE
    ]
    country_correlation <- NA_real_
    if (
      nrow(country_overlap) >= 2L &&
        sd(country_overlap$humcap_undp) > 0 &&
        sd(country_overlap$humcap_pwt) > 0
    ) {
      country_correlation <- cor(
        country_overlap$humcap_undp,
        country_overlap$humcap_pwt
      )
    }
    data.frame(
      country_iso3_code = country_data$country_iso3_code[1],
      country = country_data$country[1],
      undp_available_years = sum(!is.na(country_data$humcap_undp)),
      pwt_available_years = sum(!is.na(country_data$humcap_pwt)),
      recovered_relative_to_pwt = sum(
        country_data$recovered_relative_to_pwt
      ),
      lost_relative_to_pwt = sum(country_data$lost_relative_to_pwt),
      overlap_years = nrow(country_overlap),
      overlap_correlation = country_correlation,
      overlap_mae = if (nrow(country_overlap) > 0L) {
        mean(country_overlap$absolute_difference)
      } else {
        NA_real_
      },
      overlap_max_absolute_difference = if (nrow(country_overlap) > 0L) {
        max(country_overlap$absolute_difference)
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  }
)
country_comparison <- do.call(rbind, country_comparison_rows)
country_comparison <- country_comparison[
  order(country_comparison$country_iso3_code),
]
row.names(country_comparison) <- NULL
valid_country_correlations <- country_comparison$overlap_correlation[
  is.finite(country_comparison$overlap_correlation)
]
median_country_correlation <- median(valid_country_correlations)

active_available <- sum(!is.na(humcap_work$humcap_undp))
pwt_available <- sum(!is.na(humcap_work$humcap_pwt))
recovered_count <- sum(humcap_work$recovered_relative_to_pwt)
lost_count <- sum(humcap_work$lost_relative_to_pwt)
replacement_validation_passed <- (
  active_available >= minimum_active_observations &&
    active_available > pwt_available &&
    recovered_count >= minimum_recovered_observations &&
    lost_count <= maximum_lost_observations &&
    level_correlation >= minimum_level_correlation &&
    within_correlation >= minimum_within_correlation &&
    median_country_correlation >= minimum_median_country_correlation &&
    annual_change_correlation >= minimum_annual_change_correlation &&
    relative_mae <= maximum_relative_mae
)
if (!replacement_validation_passed) {
  stop(
    "La serie PNUD no supera los umbrales de sustitución: ",
    "correlación=", round(level_correlation, 4),
    ", correlación within=", round(within_correlation, 4),
    ", correlación cambios=", round(annual_change_correlation, 4),
    ", MAE relativo=", round(relative_mae, 4),
    ", recuperadas=", recovered_count,
    ", perdidas=", lost_count,
    "."
  )
}

country_coverage_rows <- lapply(
  split(humcap_work, humcap_work$country_iso3_code),
  function(country_data) {
    observed <- !is.na(country_data$humcap)
    available_years <- sum(observed)
    data.frame(
      country_iso3_code = country_data$country_iso3_code[1],
      country = country_data$country[1],
      expected_years = length(analysis_years),
      available_humcap_years = available_years,
      missing_humcap_years = length(analysis_years) - available_years,
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
      recovered_relative_to_pwt = sum(
        country_data$recovered_relative_to_pwt
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

year_coverage_rows <- lapply(
  split(humcap_work, humcap_work$year),
  function(year_data) {
    available_countries <- sum(!is.na(year_data$humcap))
    data.frame(
      year = year_data$year[1],
      expected_countries = expected_country_count,
      available_humcap_countries = available_countries,
      missing_humcap_countries = expected_country_count -
        available_countries,
      coverage_share = available_countries / expected_country_count,
      recovered_relative_to_pwt = sum(
        year_data$recovered_relative_to_pwt
      ),
      stringsAsFactors = FALSE
    )
  }
)
coverage_by_year <- do.call(rbind, year_coverage_rows)
coverage_by_year <- coverage_by_year[order(coverage_by_year$year), ]
row.names(coverage_by_year) <- NULL

write.csv(
  humcap_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  humcap_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
write.csv(
  humcap_work,
  diagnostics_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
write.csv(
  humcap_work[
    ,
    c(
      "country_iso3_code",
      "country",
      "year",
      "mean_years_schooling_undp",
      "humcap_undp",
      "humcap_pwt",
      "difference_undp_minus_pwt",
      "absolute_difference",
      "recovered_relative_to_pwt",
      "lost_relative_to_pwt",
      "availability_status"
    )
  ],
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
    nrow(csv_check) != nrow(dta_check) ||
    !identical(
      as.character(csv_check$country_iso3_code),
      as.character(dta_check$country_iso3_code)
    ) ||
    !identical(as.integer(csv_check$year), as.integer(dta_check$year)) ||
    !identical(is.na(csv_check$humcap), is.na(dta_check$humcap))
) {
  stop("Las salidas CSV y Stata no conservan la misma estructura.")
}
format_difference <- abs(csv_check$humcap - dta_check$humcap)
max_csv_stata_difference <- if (all(is.na(format_difference))) {
  0
} else {
  max(format_difference, na.rm = TRUE)
}
if (max_csv_stata_difference > 1e-10) {
  stop("Las salidas CSV y Stata difieren numéricamente.")
}

validation_summary <- data.frame(
  metric = c(
    "active_indicator_code",
    "active_source_code",
    "reference_source_code",
    "start_year",
    "end_year",
    "dres_sample_countries",
    "expected_country_years",
    "actual_country_years",
    "available_humcap_country_years",
    "missing_humcap_country_years",
    "coverage_percent",
    "countries_with_any_humcap",
    "countries_complete_1996_2021",
    "countries_with_partial_coverage",
    "countries_without_humcap",
    "pwt_reference_available_country_years",
    "recovered_relative_to_pwt",
    "lost_relative_to_pwt",
    "overlap_country_years",
    "overlap_level_correlation",
    "overlap_within_country_correlation",
    "median_country_correlation",
    "annual_change_correlation",
    "overlap_mae",
    "overlap_relative_mae",
    "overlap_rmse",
    "overlap_median_absolute_difference",
    "overlap_p95_absolute_difference",
    "overlap_maximum_absolute_difference",
    "schooling_mae_years",
    "schooling_median_absolute_difference",
    "replacement_validation_passed",
    "duplicate_country_year_keys",
    "nonpositive_or_nonfinite_value_count",
    "identity_mismatch_count",
    "identity_max_abs_difference",
    "humcap_minimum",
    "humcap_median",
    "humcap_maximum",
    "csv_stata_max_abs_difference"
  ),
  value = c(
    active_indicator_code,
    active_source_code,
    reference_source_code,
    start_year,
    end_year,
    expected_country_count,
    expected_row_count,
    nrow(humcap_panel),
    active_available,
    sum(is.na(humcap_panel$humcap)),
    100 * mean(!is.na(humcap_panel$humcap)),
    sum(coverage_by_country$available_humcap_years > 0L),
    sum(coverage_by_country$complete_1996_2021 == 1L),
    sum(
      coverage_by_country$available_humcap_years > 0L &
        coverage_by_country$available_humcap_years <
          length(analysis_years)
    ),
    sum(coverage_by_country$available_humcap_years == 0L),
    pwt_available,
    recovered_count,
    lost_count,
    nrow(overlap),
    level_correlation,
    within_correlation,
    median_country_correlation,
    annual_change_correlation,
    mae,
    relative_mae,
    rmse,
    median_absolute_difference,
    p95_absolute_difference,
    maximum_absolute_difference,
    schooling_mae_years,
    schooling_median_absolute_difference,
    replacement_validation_passed,
    anyDuplicated(humcap_panel[c("country_iso3_code", "year")]),
    sum(available_humcap <= 0 | !is.finite(available_humcap)),
    identity_mismatch_count,
    identity_max_difference,
    min(available_humcap),
    median(available_humcap),
    max(available_humcap),
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

message("HUMCAP procesada correctamente con MYS del PNUD.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
message(
  "Cobertura activa: ",
  active_available,
  " de ",
  expected_row_count,
  " país-años (",
  round(100 * active_available / expected_row_count, 2),
  "%)."
)
message(
  "Comparación PNUD-PWT: correlación=",
  round(level_correlation, 4),
  ", within=",
  round(within_correlation, 4),
  ", cambios anuales=",
  round(annual_change_correlation, 4),
  "."
)
message(
  "Recuperadas frente a PWT: ",
  recovered_count,
  "; perdidas: ",
  lost_count,
  "."
)
