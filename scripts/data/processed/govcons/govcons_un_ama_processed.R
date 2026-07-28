# CAPA: PROCESSED
# VARIABLE: GOVCONS
# ENTRADAS: data/raw/govcons/un_ama/,
#           data/raw/world_bank_wdi/ y data/processed/dres/
# SALIDAS: data/processed/govcons/
#
# Construye la única GOVCONS activa con la serie de Cuentas Nacionales de
# Naciones Unidas. WDI se conserva como referencia de contraste y nunca se
# mezcla con la serie activa.

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

# Definir período, muestra y umbrales de aceptación de la sustitución.
start_year <- 1996L
end_year <- 2021L
analysis_years <- start_year:end_year
expected_country_count <- 55L
expected_row_count <- expected_country_count * length(analysis_years)
expected_un_series_code <- 16L
expected_un_item_id <- 3L
expected_un_item_name <- "General government final consumption expenditure"
flagged_zero_country <- "VEN"
flagged_zero_years <- 1996:2011
minimum_overlap_correlation <- 0.90
maximum_overlap_mae <- 1.50
large_difference_threshold <- 5.00

# Definir entradas y salidas oficiales.
un_raw_file <- file.path(
  project_path,
  "data",
  "raw",
  "govcons",
  "un_ama",
  "govcons_un_ama_1970_2024.csv"
)
un_metadata_file <- file.path(
  project_path,
  "data",
  "raw",
  "govcons",
  "un_ama",
  "govcons_un_ama_metadata.csv"
)
un_manifest_file <- file.path(
  project_path,
  "data",
  "raw",
  "govcons",
  "un_ama",
  "download_manifest.csv"
)
wdi_raw_file <- file.path(
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
processed_path <- file.path(project_path, "data", "processed", "govcons")
panel_csv_file <- file.path(processed_path, "govcons_data.csv")
panel_dta_file <- file.path(processed_path, "govcons_data.dta")
diagnostics_file <- file.path(
  processed_path,
  "govcons_country_year_diagnostics_1996_2021.csv"
)
comparison_file <- file.path(
  processed_path,
  "govcons_un_wdi_comparison_1996_2021.csv"
)
country_comparison_file <- file.path(
  processed_path,
  "govcons_un_wdi_country_comparison_1996_2021.csv"
)
country_coverage_file <- file.path(
  processed_path,
  "govcons_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  processed_path,
  "govcons_year_coverage_1996_2021.csv"
)
validation_file <- file.path(
  processed_path,
  "govcons_validation_summary.csv"
)

# Comprobar entradas, paquete de Stata y posibles bloqueos de archivos.
required_files <- c(
  un_raw_file,
  un_metadata_file,
  un_manifest_file,
  wdi_raw_file,
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

# Leer y validar la serie porcentual de Naciones Unidas.
un_raw <- read.csv(
  un_raw_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  fileEncoding = "UTF-8"
)
required_un_columns <- c(
  "country_iso3_code",
  "country_m49",
  "country_un",
  "year",
  "government_consumption_pct_gdp_un",
  "series_code",
  "item_id",
  "item_name"
)
missing_un_columns <- setdiff(required_un_columns, names(un_raw))
if (length(missing_un_columns) > 0L) {
  stop(
    "Faltan columnas en la captura ONU: ",
    paste(missing_un_columns, collapse = ", ")
  )
}
un_raw$country_iso3_code <- toupper(trimws(un_raw$country_iso3_code))
un_raw$year <- as.integer(un_raw$year)
un_raw$government_consumption_pct_gdp_un <- as.numeric(
  un_raw$government_consumption_pct_gdp_un
)
un_raw$series_code <- as.integer(un_raw$series_code)
un_raw$item_id <- as.integer(un_raw$item_id)
if (
  any(un_raw$series_code != expected_un_series_code) ||
    any(un_raw$item_id != expected_un_item_id) ||
    any(trimws(un_raw$item_name) != expected_un_item_name)
) {
  stop("La captura ONU no corresponde a la serie 16, componente 3.")
}
if (anyDuplicated(un_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("La captura ONU contiene llaves país-año duplicadas.")
}

un_selected <- un_raw[
  un_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    un_raw$year %in% analysis_years,
  c(
    "country_iso3_code",
    "year",
    "country_m49",
    "country_un",
    "government_consumption_pct_gdp_un"
  ),
  drop = FALSE
]
names(un_selected)[
  names(un_selected) == "government_consumption_pct_gdp_un"
] <- "govcons_un"
un_selected <- un_selected[
  order(un_selected$country_iso3_code, un_selected$year),
]
row.names(un_selected) <- NULL

un_grid <- merge(
  panel_grid,
  un_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
un_grid <- un_grid[order(un_grid$country_iso3_code, un_grid$year), ]
row.names(un_grid) <- NULL
if (
  nrow(un_grid) != expected_row_count ||
    sum(is.na(un_grid$govcons_un)) != 0L ||
    any(!is.finite(un_grid$govcons_un)) ||
    any(un_grid$govcons_un <= 0)
) {
  stop("La serie ONU no ofrece 1.430 valores positivos y finitos.")
}
if (
  length(unique(un_grid$country_iso3_code)) != expected_country_count ||
    anyDuplicated(un_grid[c("country_iso3_code", "year")]) > 0L
) {
  stop("La serie ONU no conserva las 1.430 llaves esperadas.")
}

# Leer WDI como referencia de contraste y reproducir su depuración anterior.
wdi_raw <- read.csv(
  wdi_raw_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  na.strings = c("", "NA", "N/A"),
  fileEncoding = "UTF-8"
)
required_wdi_columns <- c(
  "country_iso3_code",
  "year",
  "government_consumption_pct_gdp"
)
missing_wdi_columns <- setdiff(required_wdi_columns, names(wdi_raw))
if (length(missing_wdi_columns) > 0L) {
  stop(
    "Faltan columnas en la referencia WDI: ",
    paste(missing_wdi_columns, collapse = ", ")
  )
}
wdi_raw$country_iso3_code <- toupper(trimws(wdi_raw$country_iso3_code))
wdi_raw$year <- as.integer(wdi_raw$year)
wdi_raw$government_consumption_pct_gdp <- as.numeric(
  wdi_raw$government_consumption_pct_gdp
)
if (anyDuplicated(wdi_raw[c("country_iso3_code", "year")]) > 0L) {
  stop("La referencia WDI contiene llaves país-año duplicadas.")
}
wdi_selected <- wdi_raw[
  wdi_raw$country_iso3_code %in% dres_sample$country_iso3_code &
    wdi_raw$year %in% analysis_years,
  c("country_iso3_code", "year", "government_consumption_pct_gdp"),
  drop = FALSE
]
names(wdi_selected)[3] <- "govcons_wdi_raw"

govcons_work <- merge(
  un_grid,
  wdi_selected,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
govcons_work <- govcons_work[
  order(govcons_work$country_iso3_code, govcons_work$year),
]
row.names(govcons_work) <- NULL

wdi_zero_flagged <- (
  !is.na(govcons_work$govcons_wdi_raw) &
    govcons_work$govcons_wdi_raw == 0
)
expected_wdi_zero_flag <- (
  govcons_work$country_iso3_code == flagged_zero_country &
    govcons_work$year %in% flagged_zero_years
)
if (!identical(wdi_zero_flagged, expected_wdi_zero_flag)) {
  stop(
    "Los ceros WDI ya no coinciden exactamente con Venezuela 1996-2011."
  )
}
govcons_work$govcons_wdi_reference <- govcons_work$govcons_wdi_raw
govcons_work$govcons_wdi_reference[wdi_zero_flagged] <- NA_real_

# Expandir los metadatos de la ONU a una clasificación país-año.
un_metadata <- read.csv(
  un_metadata_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
required_metadata_columns <- c(
  "country_iso3_code",
  "indicator_name",
  "years",
  "organisation_name",
  "publication_name",
  "method_name"
)
missing_metadata_columns <- setdiff(
  required_metadata_columns,
  names(un_metadata)
)
if (length(missing_metadata_columns) > 0L) {
  stop(
    "Faltan columnas en los metadatos ONU: ",
    paste(missing_metadata_columns, collapse = ", ")
  )
}
un_metadata$country_iso3_code <- toupper(
  trimws(un_metadata$country_iso3_code)
)
un_metadata <- un_metadata[
  un_metadata$country_iso3_code %in% dres_sample$country_iso3_code &
    trimws(un_metadata$indicator_name) == expected_un_item_name,
]
if (
  length(unique(un_metadata$country_iso3_code)) != expected_country_count
) {
  stop("Los metadatos ONU no cubren los 55 países de la muestra.")
}

direct_method_names <- c(
  "None",
  "Nominal values from this source are used"
)
expanded_metadata <- do.call(
  rbind,
  lapply(seq_len(nrow(un_metadata)), function(row_index) {
    metadata_row <- un_metadata[row_index, ]
    year_tokens <- as.integer(
      regmatches(
        metadata_row$years,
        gregexpr("[0-9]{4}", metadata_row$years)
      )[[1]]
    )
    if (length(year_tokens) == 0L) {
      stop(
        "No se pudo interpretar el período de metadatos: ",
        metadata_row$years
      )
    }
    metadata_years <- if (length(year_tokens) == 1L) {
      year_tokens[1]
    } else {
      seq.int(year_tokens[1], year_tokens[2])
    }
    metadata_years <- metadata_years[
      metadata_years %in% analysis_years
    ]
    if (length(metadata_years) == 0L) {
      return(NULL)
    }
    data.frame(
      country_iso3_code = metadata_row$country_iso3_code,
      year = metadata_years,
      method_class = if (
        trimws(metadata_row$method_name) %in% direct_method_names
      ) {
        "direct"
      } else {
        "derived"
      },
      organisation_name = metadata_row$organisation_name,
      publication_name = metadata_row$publication_name,
      method_name = metadata_row$method_name,
      stringsAsFactors = FALSE
    )
  })
)

collapse_unique <- function(values) {
  values <- sort(unique(trimws(values[nzchar(trimws(values))])))
  paste(values, collapse = " | ")
}

metadata_country_year <- do.call(
  rbind,
  lapply(
    split(
      expanded_metadata,
      paste(
        expanded_metadata$country_iso3_code,
        expanded_metadata$year,
        sep = "-"
      )
    ),
    function(country_year_data) {
      method_classes <- sort(unique(country_year_data$method_class))
      data.frame(
        country_iso3_code = country_year_data$country_iso3_code[1],
        year = country_year_data$year[1],
        un_method_class = if (length(method_classes) > 1L) {
          "mixed"
        } else {
          method_classes[1]
        },
        un_metadata_records = nrow(country_year_data),
        un_organisations = collapse_unique(
          country_year_data$organisation_name
        ),
        un_publications = collapse_unique(
          country_year_data$publication_name
        ),
        un_methods = collapse_unique(country_year_data$method_name),
        stringsAsFactors = FALSE
      )
    }
  )
)
metadata_country_year <- metadata_country_year[
  order(
    metadata_country_year$country_iso3_code,
    metadata_country_year$year
  ),
]
row.names(metadata_country_year) <- NULL

govcons_work <- merge(
  govcons_work,
  metadata_country_year,
  by = c("country_iso3_code", "year"),
  all.x = TRUE,
  sort = FALSE
)
govcons_work <- govcons_work[
  order(govcons_work$country_iso3_code, govcons_work$year),
]
row.names(govcons_work) <- NULL
if (any(is.na(govcons_work$un_method_class))) {
  stop("Uno o más valores ONU no tienen metadatos país-año.")
}

# Comparar las dos fuentes sin mezclar sus valores.
overlap <- !is.na(govcons_work$govcons_wdi_reference)
govcons_work$difference_un_minus_wdi <- ifelse(
  overlap,
  govcons_work$govcons_un - govcons_work$govcons_wdi_reference,
  NA_real_
)
govcons_work$absolute_difference <- abs(
  govcons_work$difference_un_minus_wdi
)
govcons_work$comparison_status <- ifelse(
  overlap,
  "overlap",
  ifelse(
    wdi_zero_flagged,
    "wdi_zero_flagged_un_recovered",
    "wdi_missing_un_recovered"
  )
)

overlap_count <- sum(overlap)
overlap_correlation <- cor(
  govcons_work$govcons_un[overlap],
  govcons_work$govcons_wdi_reference[overlap]
)
overlap_mae <- mean(govcons_work$absolute_difference[overlap])
overlap_rmse <- sqrt(mean(
  govcons_work$difference_un_minus_wdi[overlap]^2
))
overlap_median_absolute_difference <- median(
  govcons_work$absolute_difference[overlap]
)
overlap_p95_absolute_difference <- as.numeric(quantile(
  govcons_work$absolute_difference[overlap],
  probs = 0.95,
  names = FALSE
))
overlap_max_absolute_difference <- max(
  govcons_work$absolute_difference[overlap]
)
large_difference_count <- sum(
  govcons_work$absolute_difference[overlap] >
    large_difference_threshold
)

active_nonpositive_or_nonfinite <- sum(
  !is.finite(govcons_work$govcons_un) |
    govcons_work$govcons_un <= 0
)
replacement_validation_passed <- (
  nrow(govcons_work) == expected_row_count &&
    sum(is.na(govcons_work$govcons_un)) == 0L &&
    anyDuplicated(govcons_work[c("country_iso3_code", "year")]) == 0L &&
    active_nonpositive_or_nonfinite == 0L &&
    overlap_count == 1152L &&
    is.finite(overlap_correlation) &&
    overlap_correlation >= minimum_overlap_correlation &&
    overlap_mae <= maximum_overlap_mae
)
if (!replacement_validation_passed) {
  stop(
    "La serie ONU no superó los umbrales de sustitución: correlación=",
    round(overlap_correlation, 4),
    ", MAE=",
    round(overlap_mae, 4),
    "."
  )
}

# Activar exclusivamente la serie ONU después de superar la validación.
govcons_work$govcons <- govcons_work$govcons_un
govcons_panel <- govcons_work[, c(
  "country_iso3_code",
  "country",
  "year",
  "govcons"
)]

# Construir diagnósticos por país y por año.
coverage_by_country <- do.call(
  rbind,
  lapply(
    split(govcons_work, govcons_work$country_iso3_code),
    function(country_data) {
      data.frame(
        country_iso3_code = country_data$country_iso3_code[1],
        country = country_data$country[1],
        expected_years = length(analysis_years),
        available_govcons_years = sum(!is.na(country_data$govcons)),
        missing_govcons_years = sum(is.na(country_data$govcons)),
        complete_1996_2021 = as.integer(
          all(!is.na(country_data$govcons))
        ),
        un_direct_years = sum(
          country_data$un_method_class == "direct"
        ),
        un_derived_years = sum(
          country_data$un_method_class == "derived"
        ),
        un_mixed_years = sum(
          country_data$un_method_class == "mixed"
        ),
        wdi_reference_years = sum(
          !is.na(country_data$govcons_wdi_reference)
        ),
        un_recovered_wdi_missing_years = sum(
          is.na(country_data$govcons_wdi_reference)
        ),
        stringsAsFactors = FALSE
      )
    }
  )
)
coverage_by_country <- coverage_by_country[
  order(coverage_by_country$country_iso3_code),
]
row.names(coverage_by_country) <- NULL

coverage_by_year <- do.call(
  rbind,
  lapply(split(govcons_work, govcons_work$year), function(year_data) {
    data.frame(
      year = year_data$year[1],
      expected_countries = expected_country_count,
      available_govcons_countries = sum(!is.na(year_data$govcons)),
      missing_govcons_countries = sum(is.na(year_data$govcons)),
      un_direct_values = sum(year_data$un_method_class == "direct"),
      un_derived_values = sum(year_data$un_method_class == "derived"),
      un_mixed_values = sum(year_data$un_method_class == "mixed"),
      wdi_reference_values = sum(
        !is.na(year_data$govcons_wdi_reference)
      ),
      un_recovered_wdi_missing_values = sum(
        is.na(year_data$govcons_wdi_reference)
      ),
      stringsAsFactors = FALSE
    )
  }))
coverage_by_year <- coverage_by_year[order(coverage_by_year$year), ]
row.names(coverage_by_year) <- NULL

country_comparison <- do.call(
  rbind,
  lapply(
    split(govcons_work, govcons_work$country_iso3_code),
    function(country_data) {
      country_overlap <- country_data[
        !is.na(country_data$govcons_wdi_reference),
      ]
      overlap_years <- nrow(country_overlap)
      country_correlation <- NA_real_
      if (
        overlap_years > 1L &&
          sd(country_overlap$govcons_un) > 0 &&
          sd(country_overlap$govcons_wdi_reference) > 0
      ) {
        country_correlation <- cor(
          country_overlap$govcons_un,
          country_overlap$govcons_wdi_reference
        )
      }
      data.frame(
        country_iso3_code = country_data$country_iso3_code[1],
        country = country_data$country[1],
        overlap_years = overlap_years,
        un_recovered_wdi_missing_years = sum(
          is.na(country_data$govcons_wdi_reference)
        ),
        correlation = country_correlation,
        mean_difference_un_minus_wdi = if (overlap_years > 0L) {
          mean(country_overlap$difference_un_minus_wdi)
        } else {
          NA_real_
        },
        mae = if (overlap_years > 0L) {
          mean(country_overlap$absolute_difference)
        } else {
          NA_real_
        },
        rmse = if (overlap_years > 0L) {
          sqrt(mean(country_overlap$difference_un_minus_wdi^2))
        } else {
          NA_real_
        },
        maximum_absolute_difference = if (overlap_years > 0L) {
          max(country_overlap$absolute_difference)
        } else {
          NA_real_
        },
        stringsAsFactors = FALSE
      )
    }
  )
)
country_comparison <- country_comparison[
  order(
    -country_comparison$mae,
    country_comparison$country_iso3_code,
    na.last = TRUE
  ),
]
row.names(country_comparison) <- NULL

comparison_output <- govcons_work[, c(
  "country_iso3_code",
  "country",
  "year",
  "govcons_un",
  "govcons_wdi_raw",
  "govcons_wdi_reference",
  "difference_un_minus_wdi",
  "absolute_difference",
  "comparison_status",
  "un_method_class"
)]

# Guardar panel activo, comparación y diagnósticos.
write.csv(
  govcons_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  govcons_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
write.csv(
  govcons_work,
  diagnostics_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
write.csv(
  comparison_output,
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

# Releer CSV y Stata para verificar equivalencia.
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
    !identical(
      as.character(csv_check$country),
      as.character(dta_check$country)
    ) ||
    !identical(is.na(csv_check$govcons), is.na(dta_check$govcons))
) {
  stop("Las salidas CSV y Stata no son estructuralmente equivalentes.")
}
format_difference <- abs(csv_check$govcons - dta_check$govcons)
max_csv_stata_difference <- max(format_difference, na.rm = TRUE)
if (max_csv_stata_difference > 1e-10) {
  stop("Las salidas CSV y Stata difieren numéricamente.")
}

# Guardar un resumen compacto y auditable.
wdi_available_count <- sum(!is.na(govcons_work$govcons_wdi_reference))
recovered_count <- sum(is.na(govcons_work$govcons_wdi_reference))
recovered_rows <- govcons_work[
  is.na(govcons_work$govcons_wdi_reference),
]
validation_summary <- data.frame(
  metric = c(
    "active_source",
    "start_year",
    "end_year",
    "dres_sample_countries",
    "expected_country_years",
    "actual_country_years",
    "available_govcons_country_years",
    "missing_govcons_country_years",
    "coverage_percent",
    "countries_complete_1996_2021",
    "wdi_reference_available_country_years",
    "wdi_reference_missing_country_years",
    "un_recovered_wdi_missing_country_years",
    "un_recovered_direct_values",
    "un_recovered_derived_values",
    "un_recovered_mixed_values",
    "un_all_direct_values",
    "un_all_derived_values",
    "un_all_mixed_values",
    "overlap_country_years",
    "overlap_correlation",
    "overlap_mae_percentage_points",
    "overlap_rmse_percentage_points",
    "overlap_median_abs_difference",
    "overlap_p95_abs_difference",
    "overlap_max_abs_difference",
    "overlap_abs_difference_above_5pp",
    "minimum_required_correlation",
    "maximum_allowed_mae",
    "replacement_validation_passed",
    "duplicate_country_year_keys",
    "nonpositive_or_nonfinite_active_values",
    "govcons_minimum",
    "govcons_median",
    "govcons_maximum",
    "csv_stata_max_abs_difference"
  ),
  value = as.character(c(
    "UNSD National Accounts Main Aggregates series 16 item 3",
    start_year,
    end_year,
    expected_country_count,
    expected_row_count,
    nrow(govcons_panel),
    sum(!is.na(govcons_panel$govcons)),
    sum(is.na(govcons_panel$govcons)),
    100 * mean(!is.na(govcons_panel$govcons)),
    sum(coverage_by_country$complete_1996_2021 == 1L),
    wdi_available_count,
    recovered_count,
    recovered_count,
    sum(recovered_rows$un_method_class == "direct"),
    sum(recovered_rows$un_method_class == "derived"),
    sum(recovered_rows$un_method_class == "mixed"),
    sum(govcons_work$un_method_class == "direct"),
    sum(govcons_work$un_method_class == "derived"),
    sum(govcons_work$un_method_class == "mixed"),
    overlap_count,
    overlap_correlation,
    overlap_mae,
    overlap_rmse,
    overlap_median_absolute_difference,
    overlap_p95_absolute_difference,
    overlap_max_absolute_difference,
    large_difference_count,
    minimum_overlap_correlation,
    maximum_overlap_mae,
    replacement_validation_passed,
    anyDuplicated(govcons_panel[c("country_iso3_code", "year")]),
    active_nonpositive_or_nonfinite,
    min(govcons_panel$govcons),
    median(govcons_panel$govcons),
    max(govcons_panel$govcons),
    max_csv_stata_difference
  )),
  stringsAsFactors = FALSE
)
write.csv(
  validation_summary,
  validation_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

message("GOVCONS procesada correctamente con la fuente ONU.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
message(
  "Cobertura activa: ", sum(!is.na(govcons_panel$govcons)),
  " de ", expected_row_count, " país-años (100%)."
)
message(
  "Comparación ONU-WDI: correlación=",
  round(overlap_correlation, 4),
  ", MAE=", round(overlap_mae, 4),
  " puntos porcentuales."
)
message(
  "Valores recuperados frente a WDI: ", recovered_count,
  " (directos=", sum(recovered_rows$un_method_class == "direct"),
  ", derivados=", sum(recovered_rows$un_method_class == "derived"),
  ", mixtos=", sum(recovered_rows$un_method_class == "mixed"), ")."
)
