# CAPA: PROCESSED
# VARIABLES: PEXP y FEXP
# ENTRADAS: data/raw/atlas/sitc_rev2_trade/ y data/processed/dres/
# SALIDAS: data/processed/pexp_fexp/
#
# Construye PEXP y FEXP como porcentajes de las exportaciones de mercancías.
# PEXP incluye las secciones SITC Rev. 2 0, 1, 2 y 4, más la división 68;
# FEXP incluye la sección 3. Ambas comparten un denominador que incorpora las
# mercancías SITC clasificadas y XXXX, y excluye cinco categorías de servicios.

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

# Definir el período econométrico y la muestra esperada.
start_year <- 1996L
end_year <- 2021L
analysis_years <- start_year:end_year
expected_country_count <- 55L
expected_row_count <- expected_country_count * length(analysis_years)
service_codes <- c(
  "financial",
  "ict",
  "transport",
  "travel",
  "unspecified"
)

# Definir entradas y salidas.
atlas_path <- file.path(
  project_path,
  "data",
  "raw",
  "atlas",
  "sitc_rev2_trade"
)
country_files_path <- file.path(atlas_path, "country_exports")
product_catalog_file <- file.path(
  atlas_path,
  "atlas_sitc4_product_catalog.csv"
)
sample_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_sample_20.csv"
)
processed_path <- file.path(
  project_path,
  "data",
  "processed",
  "pexp_fexp"
)
panel_csv_file <- file.path(processed_path, "pexp_fexp_data.csv")
panel_dta_file <- file.path(processed_path, "pexp_fexp_data.dta")
country_year_diagnostics_file <- file.path(
  processed_path,
  "pexp_fexp_country_year_diagnostics_1996_2021.csv"
)
country_coverage_file <- file.path(
  processed_path,
  "pexp_fexp_country_coverage_1996_2021.csv"
)
year_coverage_file <- file.path(
  processed_path,
  "pexp_fexp_year_coverage_1996_2021.csv"
)
validation_file <- file.path(
  processed_path,
  "pexp_fexp_validation_summary.csv"
)

# Comprobar entradas y dependencia para la salida Stata.
required_files <- c(product_catalog_file, sample_file)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0L) {
  stop("Faltan archivos requeridos: ", paste(missing_files, collapse = ", "))
}
if (!dir.exists(country_files_path)) {
  stop("No existe la carpeta de exportaciones Atlas: ", country_files_path)
}
if (!requireNamespace("foreign", quietly = TRUE)) {
  stop("Falta el paquete de R 'foreign', requerido para la salida Stata.")
}
dir.create(processed_path, recursive = TRUE, showWarnings = FALSE)
official_output_files <- c(
  panel_csv_file,
  panel_dta_file,
  country_year_diagnostics_file,
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
missing_sample_columns <- setdiff(
  required_sample_columns,
  names(dres_sample)
)
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
    any(!nzchar(dres_sample$country))
) {
  stop("La muestra DRES contiene códigos ISO3 o nombres inválidos.")
}
if (
  anyDuplicated(dres_sample$country_iso3_code) > 0L ||
    nrow(dres_sample) != expected_country_count
) {
  stop("La muestra DRES no contiene exactamente 55 países únicos.")
}
dres_sample <- dres_sample[order(dres_sample$country_iso3_code), ]
row.names(dres_sample) <- NULL

# Leer el catálogo como texto para conservar los ceros iniciales.
product_catalog <- read.csv(
  product_catalog_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
required_product_columns <- c("code", "nameEn", "productId")
missing_product_columns <- setdiff(
  required_product_columns,
  names(product_catalog)
)
if (length(missing_product_columns) > 0L) {
  stop(
    "Faltan columnas en el catálogo SITC: ",
    paste(missing_product_columns, collapse = ", ")
  )
}
if (anyDuplicated(product_catalog$productId) > 0L) {
  stop("El catálogo SITC contiene productId duplicados.")
}

# Clasificar exhaustivamente mercancías, XXXX y servicios.
product_catalog$is_classified_merchandise <- grepl(
  "^[0-9]{4}$",
  product_catalog$code
)
product_catalog$is_unclassified_merchandise <- (
  product_catalog$code == "XXXX"
)
product_catalog$is_merchandise <- (
  product_catalog$is_classified_merchandise |
    product_catalog$is_unclassified_merchandise
)
product_catalog$is_service <- product_catalog$code %in% service_codes
unknown_categories <- (
  !product_catalog$is_merchandise &
    !product_catalog$is_service
)
if (any(unknown_categories)) {
  stop(
    "El catálogo contiene categorías no clasificadas: ",
    paste(product_catalog$code[unknown_categories], collapse = ", ")
  )
}
if (sum(product_catalog$is_service) != length(service_codes)) {
  stop("El catálogo no contiene exactamente las cinco categorías de servicios.")
}
if (sum(product_catalog$is_unclassified_merchandise) != 1L) {
  stop("El catálogo no contiene exactamente una categoría XXXX.")
}

# Identificar los productos del numerador PEXP y comprobar su exclusión de FEXP.
sitc_section <- substr(product_catalog$code, 1L, 1L)
sitc_division <- substr(product_catalog$code, 1L, 2L)
product_catalog$is_pexp <- (
  product_catalog$is_classified_merchandise &
    (
      sitc_section %in% c("0", "1", "2", "4") |
        sitc_division == "68"
    )
)
product_catalog$is_fexp <- (
  product_catalog$is_classified_merchandise &
    sitc_section == "3"
)
pexp_fexp_overlap_products <- sum(
  product_catalog$is_pexp & product_catalog$is_fexp
)
if (pexp_fexp_overlap_products > 0L) {
  stop("PEXP y FEXP contienen productos SITC superpuestos.")
}
if (
  any(
    product_catalog$is_pexp &
      !product_catalog$is_merchandise
  )
) {
  stop("PEXP contiene categorías que no son mercancías clasificadas.")
}

# Localizar los 55 archivos comerciales requeridos.
selected_country_files <- file.path(
  country_files_path,
  paste0(dres_sample$country_iso3_code, ".csv")
)
missing_country_files <- selected_country_files[
  !file.exists(selected_country_files)
]
if (length(missing_country_files) > 0L) {
  stop(
    "Faltan archivos comerciales: ",
    paste(missing_country_files, collapse = ", ")
  )
}

# Procesar un país por vez para evitar cargar simultáneamente toda la fuente.
process_country_file <- function(country_file) {
  expected_iso3 <- tools::file_path_sans_ext(basename(country_file))
  country_name <- dres_sample$country[
    match(expected_iso3, dres_sample$country_iso3_code)
  ]
  country_data <- read.csv(
    country_file,
    colClasses = "character",
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fileEncoding = "UTF-8"
  )
  required_trade_columns <- c(
    "iso3_code",
    "year",
    "product_id",
    "export_value_usd"
  )
  missing_trade_columns <- setdiff(
    required_trade_columns,
    names(country_data)
  )
  if (length(missing_trade_columns) > 0L) {
    stop(
      "Faltan columnas en ", country_file, ": ",
      paste(missing_trade_columns, collapse = ", ")
    )
  }
  country_data <- country_data[, required_trade_columns]
  country_data$iso3_code <- toupper(trimws(country_data$iso3_code))
  country_data$year <- as.integer(country_data$year)
  country_data$export_value_usd <- as.numeric(
    country_data$export_value_usd
  )
  if (
    any(is.na(country_data$year)) ||
      any(is.na(country_data$export_value_usd))
  ) {
    stop("El archivo contiene años o valores no numéricos: ", country_file)
  }
  if (
    length(unique(country_data$iso3_code)) != 1L ||
      unique(country_data$iso3_code) != expected_iso3
  ) {
    stop("El código ISO3 no coincide con el nombre del archivo: ", country_file)
  }
  product_match <- match(
    country_data$product_id,
    product_catalog$productId
  )
  if (any(is.na(product_match))) {
    stop("Hay productos sin correspondencia SITC en: ", country_file)
  }
  country_data$is_merchandise <- (
    product_catalog$is_merchandise[product_match]
  )
  country_data$is_classified_merchandise <- (
    product_catalog$is_classified_merchandise[product_match]
  )
  country_data$is_unclassified_merchandise <- (
    product_catalog$is_unclassified_merchandise[product_match]
  )
  country_data$is_service <- product_catalog$is_service[product_match]
  country_data$is_pexp <- product_catalog$is_pexp[product_match]
  country_data$is_fexp <- product_catalog$is_fexp[product_match]
  country_data$negative_correction <- country_data$export_value_usd < 0
  country_data$processed_export_value_usd <- pmax(
    country_data$export_value_usd,
    0
  )
  country_data <- country_data[
    country_data$year %in% analysis_years,
    ,
    drop = FALSE
  ]
  if (
    anyDuplicated(
      country_data[c("year", "product_id")]
    ) > 0L
  ) {
    stop("El archivo contiene llaves producto-año duplicadas: ", country_file)
  }

  annual_result <- data.frame(
    country_iso3_code = rep(expected_iso3, length(analysis_years)),
    country = rep(country_name, length(analysis_years)),
    year = analysis_years,
    pexp_exports_usd = 0,
    fexp_exports_usd = 0,
    classified_merchandise_exports_usd = 0,
    unclassified_merchandise_exports_usd = 0,
    total_merchandise_exports_usd = 0,
    services_exports_excluded_usd = 0,
    negative_merchandise_rows_corrected = 0L,
    negative_pexp_rows_corrected = 0L,
    negative_fexp_rows_corrected = 0L,
    pexp = NA_real_,
    fexp = NA_real_,
    stringsAsFactors = FALSE
  )
  for (year_value in analysis_years) {
    annual_data <- country_data[
      country_data$year == year_value,
      ,
      drop = FALSE
    ]
    result_row <- which(annual_result$year == year_value)
    annual_result$pexp_exports_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$is_pexp]
    )
    annual_result$fexp_exports_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$is_fexp]
    )
    annual_result$classified_merchandise_exports_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[
        annual_data$is_classified_merchandise
      ]
    )
    annual_result$unclassified_merchandise_exports_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[
        annual_data$is_unclassified_merchandise
      ]
    )
    annual_result$total_merchandise_exports_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$is_merchandise]
    )
    annual_result$services_exports_excluded_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$is_service]
    )
    annual_result$negative_merchandise_rows_corrected[result_row] <- sum(
      annual_data$negative_correction & annual_data$is_merchandise
    )
    annual_result$negative_pexp_rows_corrected[result_row] <- sum(
      annual_data$negative_correction & annual_data$is_pexp
    )
    annual_result$negative_fexp_rows_corrected[result_row] <- sum(
      annual_data$negative_correction & annual_data$is_fexp
    )
  }
  positive_denominator <- annual_result$total_merchandise_exports_usd > 0
  annual_result$pexp[positive_denominator] <- (
    100 *
      annual_result$pexp_exports_usd[positive_denominator] /
      annual_result$total_merchandise_exports_usd[positive_denominator]
  )
  annual_result$fexp[positive_denominator] <- (
    100 *
      annual_result$fexp_exports_usd[positive_denominator] /
      annual_result$total_merchandise_exports_usd[positive_denominator]
  )
  annual_result
}

# Construir y ordenar el panel completo.
pexp_fexp_parts <- lapply(selected_country_files, process_country_file)
pexp_fexp_diagnostics <- do.call(rbind, pexp_fexp_parts)
pexp_fexp_diagnostics <- pexp_fexp_diagnostics[
  order(
    pexp_fexp_diagnostics$country_iso3_code,
    pexp_fexp_diagnostics$year
  ),
]
row.names(pexp_fexp_diagnostics) <- NULL
pexp_fexp_panel <- pexp_fexp_diagnostics[, c(
  "country_iso3_code",
  "country",
  "year",
  "pexp",
  "fexp"
)]

# Validar dimensiones, llaves, denominadores, fórmula y rango.
if (
  nrow(pexp_fexp_panel) != expected_row_count ||
    length(
      unique(pexp_fexp_panel$country_iso3_code)
    ) != expected_country_count
) {
  stop("PEXP-FEXP no conserva la cuadrícula de 55 países por 26 años.")
}
duplicate_keys <- anyDuplicated(
  pexp_fexp_panel[c("country_iso3_code", "year")]
)
if (duplicate_keys > 0L) {
  stop("PEXP-FEXP contiene llaves país-año duplicadas.")
}
nonpositive_denominator_count <- sum(
  pexp_fexp_diagnostics$total_merchandise_exports_usd <= 0
)
if (nonpositive_denominator_count > 0L) {
  stop("Existen país-años sin exportaciones de mercancías positivas.")
}
reconstructed_denominator <- (
  pexp_fexp_diagnostics$classified_merchandise_exports_usd +
    pexp_fexp_diagnostics$unclassified_merchandise_exports_usd
)
denominator_tolerance <- pmax(
  1,
  pexp_fexp_diagnostics$total_merchandise_exports_usd
) * 1e-10
denominator_mismatch_count <- sum(
  abs(
    pexp_fexp_diagnostics$total_merchandise_exports_usd -
      reconstructed_denominator
  ) > denominator_tolerance
)
if (denominator_mismatch_count > 0L) {
  stop("El denominador no coincide con mercancías clasificadas más XXXX.")
}
pexp_formula_check <- (
  100 *
    pexp_fexp_diagnostics$pexp_exports_usd /
    pexp_fexp_diagnostics$total_merchandise_exports_usd
)
pexp_formula_mismatch_count <- sum(
  abs(pexp_fexp_diagnostics$pexp - pexp_formula_check) > 1e-10
)
if (pexp_formula_mismatch_count > 0L) {
  stop("La fórmula PEXP no coincide con numerador dividido por denominador.")
}
fexp_formula_check <- (
  100 *
    pexp_fexp_diagnostics$fexp_exports_usd /
    pexp_fexp_diagnostics$total_merchandise_exports_usd
)
fexp_formula_mismatch_count <- sum(
  abs(pexp_fexp_diagnostics$fexp - fexp_formula_check) > 1e-10
)
if (fexp_formula_mismatch_count > 0L) {
  stop("La fórmula FEXP no coincide con numerador dividido por denominador.")
}
pexp_range_violation_count <- sum(
  pexp_fexp_panel$pexp < 0 | pexp_fexp_panel$pexp > 100,
  na.rm = TRUE
)
if (pexp_range_violation_count > 0L) {
  stop("PEXP contiene valores por fuera de [0, 100].")
}
fexp_range_violation_count <- sum(
  pexp_fexp_panel$fexp < 0 | pexp_fexp_panel$fexp > 100,
  na.rm = TRUE
)
if (fexp_range_violation_count > 0L) {
  stop("FEXP contiene valores por fuera de [0, 100].")
}
# Las participaciones no deben superar conjuntamente el total mercantil.
joint_share_violation_count <- sum(
  pexp_fexp_panel$pexp + pexp_fexp_panel$fexp > 100 + 1e-10,
  na.rm = TRUE
)
if (joint_share_violation_count > 0L) {
  stop("PEXP más FEXP supera 100 % en una o más observaciones.")
}

# Construir diagnósticos de cobertura por país y año.
coverage_by_country <- do.call(
  rbind,
  lapply(
    split(
      pexp_fexp_diagnostics,
      pexp_fexp_diagnostics$country_iso3_code
    ),
    function(country_data) {
      observed_pexp_years <- country_data$year[!is.na(country_data$pexp)]
      observed_fexp_years <- country_data$year[!is.na(country_data$fexp)]
      available_pexp_years <- length(observed_pexp_years)
      available_fexp_years <- length(observed_fexp_years)
      data.frame(
        country_iso3_code = country_data$country_iso3_code[1],
        country = country_data$country[1],
        expected_years = length(analysis_years),
        available_pexp_years = available_pexp_years,
        missing_pexp_years = (
          length(analysis_years) - available_pexp_years
        ),
        available_fexp_years = available_fexp_years,
        missing_fexp_years = (
          length(analysis_years) - available_fexp_years
        ),
        first_available_year = if (available_pexp_years > 0L) {
          min(observed_pexp_years)
        } else {
          NA_integer_
        },
        last_available_year = if (available_pexp_years > 0L) {
          max(observed_pexp_years)
        } else {
          NA_integer_
        },
        pexp_coverage_share = (
          available_pexp_years / length(analysis_years)
        ),
        fexp_coverage_share = (
          available_fexp_years / length(analysis_years)
        ),
        complete_pexp_1996_2021 = as.integer(
          available_pexp_years == length(analysis_years)
        ),
        complete_fexp_1996_2021 = as.integer(
          available_fexp_years == length(analysis_years)
        ),
        mean_pexp = mean(country_data$pexp, na.rm = TRUE),
        mean_fexp = mean(country_data$fexp, na.rm = TRUE),
        maximum_unclassified_merchandise_share = max(
          country_data$unclassified_merchandise_exports_usd /
            country_data$total_merchandise_exports_usd,
          na.rm = TRUE
        ),
        negative_merchandise_rows_corrected = sum(
          country_data$negative_merchandise_rows_corrected
        ),
        stringsAsFactors = FALSE
      )
    }
  )
)
coverage_by_country <- coverage_by_country[
  order(
    coverage_by_country$available_pexp_years,
    coverage_by_country$country_iso3_code
  ),
]
row.names(coverage_by_country) <- NULL

coverage_by_year <- do.call(
  rbind,
  lapply(
    split(pexp_fexp_diagnostics, pexp_fexp_diagnostics$year),
    function(year_data) {
    available_pexp_countries <- sum(!is.na(year_data$pexp))
    available_fexp_countries <- sum(!is.na(year_data$fexp))
    data.frame(
      year = year_data$year[1],
      expected_countries = expected_country_count,
      available_pexp_countries = available_pexp_countries,
      missing_pexp_countries = (
        expected_country_count - available_pexp_countries
      ),
      available_fexp_countries = available_fexp_countries,
      missing_fexp_countries = (
        expected_country_count - available_fexp_countries
      ),
      pexp_coverage_share = (
        available_pexp_countries / expected_country_count
      ),
      fexp_coverage_share = (
        available_fexp_countries / expected_country_count
      ),
      mean_pexp = mean(year_data$pexp, na.rm = TRUE),
      mean_fexp = mean(year_data$fexp, na.rm = TRUE),
      maximum_unclassified_merchandise_share = max(
        year_data$unclassified_merchandise_exports_usd /
          year_data$total_merchandise_exports_usd,
        na.rm = TRUE
      ),
      stringsAsFactors = FALSE
    )
  })
)
coverage_by_year <- coverage_by_year[order(coverage_by_year$year), ]
row.names(coverage_by_year) <- NULL

# Guardar el panel y sus diagnósticos.
write.csv(
  pexp_fexp_panel,
  panel_csv_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
foreign::write.dta(
  pexp_fexp_panel,
  panel_dta_file,
  version = 12,
  convert.factors = "string"
)
write.csv(
  pexp_fexp_diagnostics,
  country_year_diagnostics_file,
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

# Releer CSV y Stata para comprobar su equivalencia efectiva.
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
    !identical(as.character(csv_check$country), as.character(dta_check$country))
) {
  stop("Las salidas CSV y Stata no conservan la identificación del panel.")
}
measure_columns <- c("pexp", "fexp")
csv_stata_differences <- setNames(
  numeric(length(measure_columns)),
  measure_columns
)
for (measure_name in measure_columns) {
  if (
    !identical(
      is.na(csv_check[[measure_name]]),
      is.na(dta_check[[measure_name]])
    )
  ) {
    stop(
      "Las salidas CSV y Stata no conservan los faltantes de ",
      toupper(measure_name), "."
    )
  }
  format_difference <- abs(
    csv_check[[measure_name]] - dta_check[[measure_name]]
  )
  csv_stata_differences[[measure_name]] <- max(
    format_difference,
    na.rm = TRUE
  )
}
max_csv_stata_difference <- max(csv_stata_differences)
if (max_csv_stata_difference > 1e-10) {
  stop("Las salidas CSV y Stata difieren numéricamente.")
}

# Guardar un resumen auditable.
unclassified_share <- (
  pexp_fexp_diagnostics$unclassified_merchandise_exports_usd /
    pexp_fexp_diagnostics$total_merchandise_exports_usd
)
validation_summary <- data.frame(
  metric = c(
    "start_year",
    "end_year",
    "dres_sample_countries",
    "expected_country_years",
    "actual_country_years",
    "available_pexp_country_years",
    "missing_pexp_country_years",
    "pexp_coverage_percent",
    "countries_with_any_pexp",
    "countries_complete_pexp_1996_2021",
    "countries_without_pexp",
    "available_fexp_country_years",
    "missing_fexp_country_years",
    "fexp_coverage_percent",
    "countries_with_any_fexp",
    "countries_complete_fexp_1996_2021",
    "countries_without_fexp",
    "classified_sitc4_products_in_catalog",
    "pexp_products_in_catalog",
    "fexp_products_in_catalog",
    "pexp_fexp_overlap_products",
    "service_categories_excluded",
    "xxxx_categories_in_denominator",
    "negative_merchandise_rows_corrected",
    "negative_pexp_rows_corrected",
    "negative_fexp_rows_corrected",
    "nonpositive_denominator_count",
    "denominator_mismatch_count",
    "pexp_formula_mismatch_count",
    "fexp_formula_mismatch_count",
    "pexp_range_violation_count",
    "fexp_range_violation_count",
    "joint_share_violation_count",
    "country_years_xxxx_share_gt_10pct",
    "mean_unclassified_merchandise_share",
    "maximum_unclassified_merchandise_share",
    "pexp_minimum",
    "pexp_median",
    "pexp_mean",
    "pexp_maximum",
    "fexp_minimum",
    "fexp_median",
    "fexp_mean",
    "fexp_maximum",
    "duplicate_country_year_keys",
    "pexp_csv_stata_max_abs_difference",
    "fexp_csv_stata_max_abs_difference",
    "all_measures_csv_stata_max_abs_difference"
  ),
  value = c(
    start_year,
    end_year,
    expected_country_count,
    expected_row_count,
    nrow(pexp_fexp_panel),
    sum(!is.na(pexp_fexp_panel$pexp)),
    sum(is.na(pexp_fexp_panel$pexp)),
    100 * mean(!is.na(pexp_fexp_panel$pexp)),
    sum(coverage_by_country$available_pexp_years > 0L),
    sum(coverage_by_country$complete_pexp_1996_2021 == 1L),
    sum(coverage_by_country$available_pexp_years == 0L),
    sum(!is.na(pexp_fexp_panel$fexp)),
    sum(is.na(pexp_fexp_panel$fexp)),
    100 * mean(!is.na(pexp_fexp_panel$fexp)),
    sum(coverage_by_country$available_fexp_years > 0L),
    sum(coverage_by_country$complete_fexp_1996_2021 == 1L),
    sum(coverage_by_country$available_fexp_years == 0L),
    sum(product_catalog$is_classified_merchandise),
    sum(product_catalog$is_pexp),
    sum(product_catalog$is_fexp),
    pexp_fexp_overlap_products,
    sum(product_catalog$is_service),
    sum(product_catalog$is_unclassified_merchandise),
    sum(pexp_fexp_diagnostics$negative_merchandise_rows_corrected),
    sum(pexp_fexp_diagnostics$negative_pexp_rows_corrected),
    sum(pexp_fexp_diagnostics$negative_fexp_rows_corrected),
    nonpositive_denominator_count,
    denominator_mismatch_count,
    pexp_formula_mismatch_count,
    fexp_formula_mismatch_count,
    pexp_range_violation_count,
    fexp_range_violation_count,
    joint_share_violation_count,
    sum(unclassified_share > 0.10),
    mean(unclassified_share),
    max(unclassified_share),
    min(pexp_fexp_panel$pexp),
    median(pexp_fexp_panel$pexp),
    mean(pexp_fexp_panel$pexp),
    max(pexp_fexp_panel$pexp),
    min(pexp_fexp_panel$fexp),
    median(pexp_fexp_panel$fexp),
    mean(pexp_fexp_panel$fexp),
    max(pexp_fexp_panel$fexp),
    duplicate_keys,
    csv_stata_differences[["pexp"]],
    csv_stata_differences[["fexp"]],
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

message("PEXP y FEXP se procesaron correctamente.")
message("CSV: ", panel_csv_file)
message("Stata: ", panel_dta_file)
message(
  "PEXP: ", sum(!is.na(pexp_fexp_panel$pexp)), " de ",
  expected_row_count, " país-años (",
  round(100 * mean(!is.na(pexp_fexp_panel$pexp)), 2), "%)."
)
message(
  "FEXP: ", sum(!is.na(pexp_fexp_panel$fexp)), " de ",
  expected_row_count, " país-años (",
  round(100 * mean(!is.na(pexp_fexp_panel$fexp)), 2), "%)."
)
