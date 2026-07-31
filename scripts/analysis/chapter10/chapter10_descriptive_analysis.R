# CAPA: ANALYSIS
# CAPÍTULO: 10 - Datos y construcción de variables
# ENTRADAS: data/processed/00_master_panel/master_panel_country_year.csv
# SALIDAS: outputs/tables/chapter10/ y outputs/figures/chapter10/
#
# Punto de entrada único para los cuadros y gráficos descriptivos del capítulo
# 10. Valida el panel, define las muestras analíticas y genera las cuatro tablas
# y las siete figuras de revisión del capítulo. El script utiliza únicamente
# el panel maestro y no modifica el documento del TFM.

# Localizar el helper compartido de rutas desde RStudio o desde la consola.
active_path <- ""
if (requireNamespace("rstudioapi", quietly = TRUE) &&
    rstudioapi::isAvailable()) {
  active_path <- tryCatch(
    rstudioapi::getActiveDocumentContext()$path,
    error = function(e) ""
  )
}

# Ejecutar la siguiente instrucción del bloque
helper_candidates <- c(
  if (nzchar(active_path)) {
    file.path(
      dirname(dirname(dirname(active_path))),
      "project_paths.R"
    )
  },
  file.path("scripts", "project_paths.R"),
  file.path("..", "..", "project_paths.R"),
  "project_paths.R"
)
helper_path <- helper_candidates[file.exists(helper_candidates)][1]
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}

# Ejecutar la siguiente instrucción del bloque
source(helper_path)
project_path <- find_project_path()

# Definir el insumo inmutable y las carpetas reservadas para resultados.
panel_file <- file.path(
  project_path,
  "data",
  "processed",
  "00_master_panel",
  "master_panel_country_year.csv"
)
tables_path <- file.path(
  project_path,
  "outputs",
  "tables",
  "chapter10"
)
figures_path <- file.path(
  project_path,
  "outputs",
  "figures",
  "chapter10"
)

# Evaluar condición de control de flujo
if (!file.exists(panel_file)) {
  stop("No se encontró el panel maestro: ", panel_file)
}
dir.create(tables_path, recursive = TRUE, showWarnings = FALSE)
dir.create(figures_path, recursive = TRUE, showWarnings = FALSE)

# Leer el panel sin alterar sus columnas, valores ni orden en disco.
panel <- read.csv(
  panel_file,
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  check.names = FALSE,
  fileEncoding = "UTF-8"
)

# Declarar las variables requeridas por el capítulo y por cada ecuación.
id_columns <- c(
  "country_iso3_code",
  "country",
  "year",
  "dres_base_mean",
  "dres_base_mean_percent"
)
common_regressors <- c(
  "rents",
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
  "fin"
)
chapter_variables <- c(
  id_columns,
  "rents_oil_gas",
  "rents_mining",
  common_regressors,
  "eci",
  "hhi",
  "divx"
)
eci_required <- c("eci", "hhi", common_regressors)
divx_required <- c("divx", common_regressors)

# Ejecutar la siguiente instrucción del bloque
missing_columns <- setdiff(chapter_variables, names(panel))
if (length(missing_columns) > 0L) {
  stop(
    "Faltan columnas requeridas para el capítulo 10: ",
    paste(missing_columns, collapse = ", ")
  )
}

# Validar la cuadrícula fija y las identidades derivadas.
expected_rows <- 55L * 26L
expected_years <- 1996:2021
duplicate_keys <- anyDuplicated(
  panel[c("country_iso3_code", "year")]
)
valid_iso3 <- all(grepl("^[A-Z]{3}$", panel$country_iso3_code))
observed_years <- sort(unique(panel$year))
country_count <- length(unique(panel$country_iso3_code))

# Ejecutar la siguiente instrucción del bloque
interaction_observed <- !is.na(panel$rents_x_inst)
interaction_components <- !is.na(panel$rents) & !is.na(panel$inst)
interaction_error <- max(
  abs(
    panel$rents_x_inst[interaction_observed] -
      panel$rents[interaction_observed] *
      panel$inst[interaction_observed]
  ),
  na.rm = TRUE
)
interaction_pattern_ok <- identical(
  interaction_observed,
  interaction_components
)

# Ejecutar la siguiente instrucción del bloque
divx_observed <- !is.na(panel$divx) & !is.na(panel$hhi)
divx_error <- max(
  abs(
    panel$divx[divx_observed] -
      (1 - panel$hhi[divx_observed])
  ),
  na.rm = TRUE
)

# Ejecutar la siguiente instrucción del bloque
validation <- data.frame(
  check = c(
    "rows_55_by_26",
    "unique_country_year_keys",
    "countries_55",
    "years_1996_2021",
    "valid_iso3_codes",
    "eci_individual_coverage",
    "divx_individual_coverage",
    "rents_x_inst_availability",
    "rents_x_inst_identity",
    "divx_identity"
  ),
  expected = c(
    as.character(expected_rows),
    "0 duplicate keys",
    "55",
    "1996:2021",
    "all valid",
    "1,430 available observations",
    "1,430 available observations",
    "same as RENTS and INST",
    "maximum error <= 1e-10",
    "maximum error <= 1e-10"
  ),
  observed = c(
    as.character(nrow(panel)),
    paste(duplicate_keys, "duplicate keys"),
    as.character(country_count),
    paste(observed_years, collapse = ";"),
    if (valid_iso3) "all valid" else "invalid codes found",
    paste(sum(!is.na(panel$eci)), "available observations"),
    paste(sum(!is.na(panel$divx)), "available observations"),
    if (interaction_pattern_ok) {
      "same as RENTS and INST"
    } else {
      "availability mismatch"
    },
    format(interaction_error, scientific = TRUE),
    format(divx_error, scientific = TRUE)
  ),
  passed = c(
    nrow(panel) == expected_rows,
    duplicate_keys == 0L,
    country_count == 55L,
    identical(observed_years, expected_years),
    valid_iso3,
    sum(!is.na(panel$eci)) == expected_rows,
    sum(!is.na(panel$divx)) == expected_rows,
    interaction_pattern_ok,
    is.finite(interaction_error) && interaction_error <= 1e-10,
    is.finite(divx_error) && divx_error <= 1e-10
  ),
  stringsAsFactors = FALSE
)

# Evaluar condición de control de flujo
if (!all(validation$passed)) {
  failed <- validation$check[!validation$passed]
  stop(
    "Fallaron las validaciones del panel: ",
    paste(failed, collapse = ", ")
  )
}

# Definir las muestras sin imputar ni eliminar filas del panel fuente.
eci_complete <- complete.cases(panel[eci_required])
divx_complete <- complete.cases(panel[divx_required])

# Ejecutar la siguiente instrucción del bloque
eci_sample <- panel[eci_complete, , drop = FALSE]
divx_sample <- panel[divx_complete, , drop = FALSE]
eci_available <- panel[!is.na(panel$eci), , drop = FALSE]
divx_available <- panel[!is.na(panel$divx), , drop = FALSE]

# Ejecutar la siguiente instrucción del bloque
sample_summary <- data.frame(
  sample = c(
    "master_grid",
    "eci_individual_coverage",
    "divx_individual_coverage",
    "eci_model_complete_case",
    "divx_model_complete_case"
  ),
  scope = c(
    "Grilla completa país-año",
    "Disponibilidad individual de ECI",
    "Disponibilidad individual de DIVX",
    "ECI más todos los regresores del modelo",
    "DIVX más todos los regresores del modelo"
  ),
  observations = c(
    nrow(panel),
    nrow(eci_available),
    nrow(divx_available),
    nrow(eci_sample),
    nrow(divx_sample)
  ),
  countries = c(
    length(unique(panel$country_iso3_code)),
    length(unique(eci_available$country_iso3_code)),
    length(unique(divx_available$country_iso3_code)),
    length(unique(eci_sample$country_iso3_code)),
    length(unique(divx_sample$country_iso3_code))
  ),
  years_with_observations = c(
    length(unique(panel$year)),
    length(unique(eci_available$year)),
    length(unique(divx_available$year)),
    length(unique(eci_sample$year)),
    length(unique(divx_sample$year))
  ),
  first_year = c(
    min(panel$year),
    min(eci_available$year),
    min(divx_available$year),
    min(eci_sample$year),
    min(divx_sample$year)
  ),
  last_year = c(
    max(panel$year),
    max(eci_available$year),
    max(divx_available$year),
    max(eci_sample$year),
    max(divx_sample$year)
  ),
  share_of_master_grid_percent = c(
    100,
    100 * nrow(eci_available) / nrow(panel),
    100 * nrow(divx_available) / nrow(panel),
    100 * nrow(eci_sample) / nrow(panel),
    100 * nrow(divx_sample) / nrow(panel)
  ) |>
    round(2),
  stringsAsFactors = FALSE
)

# El panel está cerrado; cualquier cambio de estas dimensiones debe revisarse.
if (
  nrow(eci_sample) != 1044L ||
    length(unique(eci_sample$country_iso3_code)) != 49L
) {
  stop(
    "La muestra ECI esperada era de 1.044 observaciones y 49 países."
  )
}
if (
  nrow(divx_sample) != 1044L ||
    length(unique(divx_sample$country_iso3_code)) != 49L
) {
  stop(
    "La muestra DIVX esperada era de 1.044 observaciones y 49 países."
  )
}

# Las dos muestras coinciden porque ECI, HHI y DIVX tienen cobertura completa.
same_model_rows <- identical(which(eci_complete), which(divx_complete))
if (!same_model_rows) {
  stop(
    "Las muestras completas de ECI y DIVX dejaron de coincidir; ",
    "debe revisarse la disponibilidad de las variables dependientes o HHI."
  )
}
model_sample <- eci_sample

# ---------------------------------------------------------------------------
# TABLA 1: fuentes, definiciones, unidades y cobertura
# ---------------------------------------------------------------------------

# Ejecutar la siguiente instrucción del bloque
variable_dictionary <- data.frame(
  variable = c(
    "DRES",
    "ECI",
    "DIVX",
    "RENTS",
    "RENTS_OIL_GAS",
    "RENTS_MINING",
    "INST",
    "RENTS_X_INST",
    "OILPC",
    "GASPC",
    "COALPC",
    "HHI",
    "PEXP",
    "FEXP",
    "VOL",
    "RER",
    "HUMCAP",
    "INNOV",
    "NET",
    "LOG_GDPPC",
    "GOVCONS",
    "FIN"
  ),
  panel_column = c(
    "dres_base_mean_percent",
    "eci",
    "divx",
    "rents",
    "rents_oil_gas",
    "rents_mining",
    "inst",
    "rents_x_inst",
    "oilpc",
    "gaspc",
    "coalpc",
    "hhi",
    "pexp",
    "fexp",
    "vol",
    "rer",
    "humcap",
    "innov",
    "net",
    "log_gdppc",
    "govcons",
    "fin"
  ),
  role = c(
    "Criterio de selección muestral",
    "Dependiente principal",
    "Dependiente complementaria",
    "Explicativa principal",
    "Auxiliar de desagregación",
    "Auxiliar de desagregación",
    "Moderadora",
    "Interacción",
    "Explicativa de abundancia",
    "Explicativa de abundancia",
    "Explicativa de abundancia",
    "Explicativa estructural solo en el modelo ECI",
    "Explicativa estructural",
    "Explicativa estructural",
    "Explicativa macroeconómica",
    "Explicativa macroeconómica",
    "Explicativa de capacidades",
    "Explicativa de capacidades",
    "Explicativa de capacidades",
    "Control del nivel de desarrollo",
    "Control fiscal",
    "Explicativa financiera"
  ),
  definition = c(
    paste(
      "Participación media de combustibles minerales, minerales, metales,",
      "piedras preciosas naturales y oro no monetario en las exportaciones",
      "de mercancías durante 1990-1995."
    ),
    paste(
      "Índice de Complejidad Económica de la API oficial del Atlas;",
      "valores mayores indican mayores capacidades productivas y sofisticación."
    ),
    paste(
      "Diversificación exportadora definida como 1 - HHI;",
      "valores mayores indican menor concentración."
    ),
    paste(
      "Suma de las rentas de petróleo, gas natural, carbón y minerales;",
      "se calcula únicamente cuando los cuatro componentes están observados."
    ),
    paste(
      "Suma de las rentas de petróleo y gas natural cuando ambos componentes",
      "están observados; no integra la especificación principal."
    ),
    paste(
      "Suma de las rentas de carbón y minerales cuando ambos componentes",
      "están observados; no integra la especificación principal."
    ),
    paste(
      "Promedio simple de los estimadores WGI de control de la corrupción,",
      "Estado de derecho y efectividad gubernamental."
    ),
    paste(
      "Producto directo de RENTS e INST, calculado únicamente cuando ambos",
      "componentes están observados."
    ),
    paste(
      "Renta petrolera real por habitante: renta petrolera como proporción",
      "del PIB por PIB real, dividida por la población."
    ),
    paste(
      "Renta de gas natural real por habitante: renta gasífera como proporción",
      "del PIB por PIB real, dividida por la población."
    ),
    paste(
      "Renta carbonífera real por habitante: renta del carbón como proporción",
      "del PIB por PIB real, dividida por la población."
    ),
    paste(
      "Índice Herfindahl-Hirschman de concentración entre productos SITC",
      "Rev. 2 de cuatro dígitos; excluye servicios y el residuo XXXX."
    ),
    paste(
      "Participación de las secciones SITC Rev. 2 0, 1, 2 y 4, más la",
      "división 68, en las exportaciones de mercancías."
    ),
    paste(
      "Participación de la sección SITC Rev. 2 3 en las exportaciones",
      "de mercancías."
    ),
    paste(
      "Desviación estándar muestral móvil de cinco variaciones porcentuales",
      "logarítmicas anuales del índice CTOT del FMI con ponderaciones fijas."
    ),
    paste(
      "Logaritmo de pl_gdpo de PWT 11.0;",
      "un aumento representa una apreciación real."
    ),
    paste(
      "Exponencial de una función por tramos de los años promedio de",
      "escolaridad adulta, con los retornos educativos utilizados por PWT."
    ),
    paste(
      "Logaritmo de uno más los artículos científicos y técnicos",
      "por millón de habitantes."
    ),
    paste(
      "Personas que utilizan internet como porcentaje de la población."
    ),
    paste(
      "Logaritmo natural del PIB per cápita en PPA y dólares",
      "internacionales constantes."
    ),
    paste(
      "Gasto de consumo final del gobierno general como porcentaje del PIB."
    ),
    paste(
      "Crédito doméstico al sector privado otorgado por bancos",
      "como porcentaje del PIB."
    )
  ),
  unit = c(
    "% de exportaciones de mercancías; promedio 1990-1995",
    "Índice",
    "Índice entre 0 y 1",
    "% del PIB",
    "% del PIB",
    "% del PIB",
    "Promedio de estimadores WGI",
    "Producto de % del PIB por índice WGI",
    "Dólares constantes por habitante",
    "Dólares constantes por habitante",
    "Dólares constantes por habitante",
    "Índice entre 0 y 1",
    "% de exportaciones de mercancías",
    "% de exportaciones de mercancías",
    "Desviación estándar de variaciones logarítmicas porcentuales",
    "Logaritmo del nivel de precios relativo",
    "Índice de capital humano",
    "Logaritmo de artículos por millón",
    "% de la población",
    "Logaritmo de dólares internacionales constantes PPA",
    "% del PIB",
    "% del PIB"
  ),
  source = c(
    "Atlas of Economic Complexity / Harvard Growth Lab; elaboración propia",
    "Atlas of Economic Complexity / Harvard Growth Lab, API GraphQL",
    "Atlas of Economic Complexity / Harvard Growth Lab; elaboración propia",
    "World Development Indicators (Banco Mundial); elaboración propia",
    "World Development Indicators (Banco Mundial); elaboración propia",
    "World Development Indicators (Banco Mundial); elaboración propia",
    "Worldwide Governance Indicators (Banco Mundial); elaboración propia",
    "Elaboración propia con RENTS e INST",
    "World Development Indicators (Banco Mundial); elaboración propia",
    "World Development Indicators (Banco Mundial); elaboración propia",
    "World Development Indicators (Banco Mundial); elaboración propia",
    "Atlas of Economic Complexity / Harvard Growth Lab; elaboración propia",
    "Atlas of Economic Complexity / Harvard Growth Lab; elaboración propia",
    "Atlas of Economic Complexity / Harvard Growth Lab; elaboración propia",
    "Fondo Monetario Internacional, CTOT; elaboración propia",
    "Penn World Table 11.0",
    "PNUD, Human Development Report 2025; elaboración propia",
    "World Development Indicators (Banco Mundial); elaboración propia",
    "World Development Indicators (Banco Mundial)",
    "World Development Indicators (Banco Mundial); elaboración propia",
    "National Accounts Main Aggregates (Naciones Unidas)",
    "World Development Indicators (Banco Mundial)"
  ),
  stringsAsFactors = FALSE
)

# Definir función principal o auxiliar
coverage_rows <- lapply(seq_len(nrow(variable_dictionary)), function(i) {
  metadata <- variable_dictionary[i, , drop = FALSE]
  column_name <- metadata$panel_column

  # Evaluar condición de control de flujo
  if (metadata$variable == "DRES") {
    data_scope <- panel[
      !duplicated(panel$country_iso3_code),
      c("country_iso3_code", column_name),
      drop = FALSE
    ]
    observed <- !is.na(data_scope[[column_name]])
    potential <- nrow(data_scope)
    countries_with_data <- sum(observed)
    countries_complete <- countries_with_data
    countries_without_data <- sum(!observed)
    coverage_basis <- "Países de la muestra fija"
    coverage_period <- "Promedio 1990-1995"
  } else {
    observed <- !is.na(panel[[column_name]])
    potential <- nrow(panel)
    availability_by_country <- tapply(
      observed,
      panel$country_iso3_code,
      sum
    )
    countries_with_data <- sum(availability_by_country > 0L)
    countries_complete <- sum(availability_by_country == 26L)
    countries_without_data <- sum(availability_by_country == 0L)
    coverage_basis <- "Observaciones país-año de la grilla maestra"
    coverage_period <- "1996-2021"
  }

  # Ejecutar la siguiente instrucción del bloque
  data.frame(
    metadata,
    coverage_basis = coverage_basis,
    coverage_period = coverage_period,
    available_observations = sum(observed),
    potential_observations = potential,
    missing_observations = potential - sum(observed),
    coverage_percent = round(100 * mean(observed), 2),
    countries_with_data = countries_with_data,
    countries_complete = countries_complete,
    countries_without_data = countries_without_data,
    stringsAsFactors = FALSE
  )
})
table_01_variable_sources_definitions_coverage <- do.call(
  rbind,
  coverage_rows
)

# ---------------------------------------------------------------------------
# TABLA 2: estadísticos descriptivos
# ---------------------------------------------------------------------------

# Definir función principal o auxiliar
summarize_numeric_variable <- function(
    values,
    variable,
    role,
    unit,
    sample_scope,
    potential_observations
) {
  observed_values <- values[!is.na(values)]
  data.frame(
    variable = variable,
    role = role,
    unit = unit,
    sample_scope = sample_scope,
    observations = length(observed_values),
    potential_observations = potential_observations,
    missing_observations = potential_observations - length(observed_values),
    coverage_percent = round(
      100 * length(observed_values) / potential_observations,
      2
    ),
    mean = round(mean(observed_values), 4),
    standard_deviation = round(stats::sd(observed_values), 4),
    median = round(stats::median(observed_values), 4),
    minimum = round(min(observed_values), 4),
    maximum = round(max(observed_values), 4),
    stringsAsFactors = FALSE
  )
}

# Ejecutar la siguiente instrucción del bloque
dres_country_values <- panel[
  !duplicated(panel$country_iso3_code),
  "dres_base_mean_percent"
]
dres_metadata <- variable_dictionary[
  variable_dictionary$variable == "DRES",
  ,
  drop = FALSE
]
descriptive_rows <- list(
  summarize_numeric_variable(
    values = dres_country_values,
    variable = dres_metadata$variable,
    role = dres_metadata$role,
    unit = dres_metadata$unit,
    sample_scope = "Muestra fija: 55 promedios país de 1990-1995",
    potential_observations = 55L
  )
)

# Ejecutar la siguiente instrucción del bloque
panel_metadata <- variable_dictionary[
  variable_dictionary$variable != "DRES",
  ,
  drop = FALSE
]
for (i in seq_len(nrow(panel_metadata))) {
  metadata <- panel_metadata[i, , drop = FALSE]
  column_name <- metadata$panel_column
  descriptive_rows[[length(descriptive_rows) + 1L]] <-
    summarize_numeric_variable(
      values = panel[[column_name]],
      variable = metadata$variable,
      role = metadata$role,
      unit = metadata$unit,
      sample_scope = "Grilla maestra: valores disponibles",
      potential_observations = nrow(panel)
    )
  descriptive_rows[[length(descriptive_rows) + 1L]] <-
    summarize_numeric_variable(
      values = model_sample[[column_name]],
      variable = metadata$variable,
      role = metadata$role,
      unit = metadata$unit,
      sample_scope = "Muestra econométrica completa: 1.044 país-años",
      potential_observations = nrow(model_sample)
    )
}
table_02_descriptive_statistics <- do.call(rbind, descriptive_rows)

# ---------------------------------------------------------------------------
# TABLA 3: grilla, cobertura de dependientes y muestras econométricas
# ---------------------------------------------------------------------------

# Ejecutar la siguiente instrucción del bloque
model_country_codes <- sort(unique(model_sample$country_iso3_code))
excluded_model_countries <- unique(
  panel[
    !panel$country_iso3_code %in% model_country_codes,
    c("country_iso3_code", "country"),
    drop = FALSE
  ]
)
excluded_model_countries <- excluded_model_countries[
  order(excluded_model_countries$country_iso3_code),
  ,
  drop = FALSE
]
excluded_model_country_codes <- paste(
  excluded_model_countries$country_iso3_code,
  collapse = ";"
)
excluded_model_country_names <- paste(
  excluded_model_countries$country,
  collapse = ";"
)
years_without_complete_model_observations <- paste(
  setdiff(expected_years, sort(unique(model_sample$year))),
  collapse = ";"
)

# Ejecutar la siguiente instrucción del bloque
table_03_econometric_sample_comparison <- data.frame(
  sample_summary,
  excluded_observations_from_master_grid = (
    nrow(panel) - sample_summary$observations
  ),
  excluded_countries_from_fixed_sample = (
    country_count - sample_summary$countries
  ),
  same_country_year_rows_as_other_model = c(
    NA,
    NA,
    NA,
    same_model_rows,
    same_model_rows
  ),
  years_without_observations = c(
    "",
    "",
    "",
    years_without_complete_model_observations,
    years_without_complete_model_observations
  ),
  excluded_country_codes = c(
    "",
    "",
    "",
    excluded_model_country_codes,
    excluded_model_country_codes
  ),
  excluded_country_names = c(
    "",
    "",
    "",
    excluded_model_country_names,
    excluded_model_country_names
  ),
  interpretation = c(
    "Cuadrícula fija de 55 países por 26 años.",
    "Disponibilidad individual de ECI; no exige regresores.",
    "Disponibilidad individual de DIVX; no exige regresores.",
    "Intersección de ECI, HHI y todos los regresores del modelo principal.",
    "Intersección de DIVX y todos los regresores; HHI se excluye."
  ),
  stringsAsFactors = FALSE
)

# ---------------------------------------------------------------------------
# TABLA 4: patrones de faltantes
# ---------------------------------------------------------------------------

# Ejecutar la siguiente instrucción del bloque
structural_years_by_variable <- lapply(
  panel_metadata$panel_column,
  function(column_name) {
    available_by_year <- tapply(
      !is.na(panel[[column_name]]),
      panel$year,
      sum
    )
    as.integer(names(available_by_year)[available_by_year == 0L])
  }
)
names(structural_years_by_variable) <- panel_metadata$variable

# Ejecutar la siguiente instrucción del bloque
expected_wgi_structural_years <- c(1997L, 1999L, 2001L)
for (variable_name in c("INST", "RENTS_X_INST")) {
  if (
    !identical(
      sort(structural_years_by_variable[[variable_name]]),
      expected_wgi_structural_years
    )
  ) {
    stop(
      "Los años estructurales de ",
      variable_name,
      " no coinciden con 1997, 1999 y 2001."
    )
  }
}

# Ejecutar la siguiente instrucción del bloque
missing_pattern_rows <- list()
for (i in seq_len(nrow(panel_metadata))) {
  metadata <- panel_metadata[i, , drop = FALSE]
  variable_name <- metadata$variable
  column_name <- metadata$panel_column
  missing_flag <- is.na(panel[[column_name]])
  missing_total <- sum(missing_flag)

  # Evaluar condición de control de flujo
  if (missing_total == 0L) {
    next
  }

  # Ejecutar la siguiente instrucción del bloque
  structural_years <- structural_years_by_variable[[variable_name]]
  structural_missing_total <- sum(
    missing_flag & panel$year %in% structural_years
  )
  missing_by_country <- tapply(
    missing_flag,
    panel$country_iso3_code,
    sum
  )

  # Ejecutar la siguiente instrucción del bloque
  missing_pattern_rows[[length(missing_pattern_rows) + 1L]] <- data.frame(
    pattern_type = "Resumen por variable",
    variable = variable_name,
    entity = "Toda la grilla",
    available_observations = sum(!missing_flag),
    potential_observations = nrow(panel),
    missing_observations = missing_total,
    coverage_percent = round(100 * mean(!missing_flag), 2),
    structural_missing_observations = structural_missing_total,
    other_missing_observations = missing_total - structural_missing_total,
    countries_affected = sum(missing_by_country > 0L),
    countries_without_data = sum(missing_by_country == 26L),
    missing_years = paste(structural_years, collapse = ";"),
    note = if (length(structural_years) > 0L) {
      "Los años listados están ausentes para los 55 países."
    } else {
      "No existen años completamente ausentes para los 55 países."
    },
    stringsAsFactors = FALSE
  )

  # Evaluar condición de control de flujo
  if (length(structural_years) > 0L) {
    for (year_value in structural_years) {
      year_rows <- panel$year == year_value
      year_missing <- sum(missing_flag[year_rows])
      missing_pattern_rows[[length(missing_pattern_rows) + 1L]] <-
        data.frame(
          pattern_type = "Año estructural",
          variable = variable_name,
          entity = as.character(year_value),
          available_observations = sum(!missing_flag[year_rows]),
          potential_observations = sum(year_rows),
          missing_observations = year_missing,
          coverage_percent = round(
            100 * mean(!missing_flag[year_rows]),
            2
          ),
          structural_missing_observations = year_missing,
          other_missing_observations = 0L,
          countries_affected = year_missing,
          countries_without_data = NA_integer_,
          missing_years = as.character(year_value),
          note = if (variable_name %in% c("INST", "RENTS_X_INST")) {
            "WGI no publicó los tres insumos institucionales en este año."
          } else {
            "La fuente no presenta observaciones para ningún país este año."
          },
          stringsAsFactors = FALSE
        )
    }
  }

  # Iterar sobre los elementos del conjunto
  for (country_code in unique(panel$country_iso3_code)) {
    country_rows <- panel$country_iso3_code == country_code
    country_data <- panel[country_rows, , drop = FALSE]
    country_missing_years <- country_data$year[
      is.na(country_data[[column_name]])
    ]
    country_specific_years <- setdiff(
      country_missing_years,
      structural_years
    )
    available_country_observations <- (
      26L - length(country_missing_years)
    )

    # "Ausencia relevante": sin datos o al menos tres faltantes adicionales
    # a los años estructuralmente ausentes para todos los países.
    if (
      available_country_observations > 0L &&
        length(country_specific_years) < 3L
    ) {
      next
    }

    # Ejecutar la siguiente instrucción del bloque
    country_name <- unique(country_data$country)
    missing_pattern_rows[[length(missing_pattern_rows) + 1L]] <-
      data.frame(
        pattern_type = "Ausencia relevante por país",
        variable = variable_name,
        entity = paste0(country_name, " (", country_code, ")"),
        available_observations = available_country_observations,
        potential_observations = 26L,
        missing_observations = length(country_missing_years),
        coverage_percent = round(
          100 * available_country_observations / 26L,
          2
        ),
        structural_missing_observations = sum(
          country_missing_years %in% structural_years
        ),
        other_missing_observations = length(country_specific_years),
        countries_affected = 1L,
        countries_without_data = as.integer(
          available_country_observations == 0L
        ),
        missing_years = paste(country_missing_years, collapse = ";"),
        note = if (available_country_observations == 0L) {
          "El país no tiene observaciones para esta variable en 1996-2021."
        } else {
          paste(
            "Tiene al menos tres faltantes adicionales a los años",
            "estructuralmente ausentes para todos los países."
          )
        },
        stringsAsFactors = FALSE
      )
  }
}
table_04_missing_data_patterns <- do.call(
  rbind,
  missing_pattern_rows
)

# Validaciones específicas de las cuatro tablas para revisión.
if (
  nrow(table_01_variable_sources_definitions_coverage) !=
    nrow(variable_dictionary) ||
    anyDuplicated(table_01_variable_sources_definitions_coverage$variable)
) {
  stop("La tabla 1 no contiene exactamente una fila por variable.")
}
if (
  table_01_variable_sources_definitions_coverage$coverage_percent[
    table_01_variable_sources_definitions_coverage$variable == "ECI"
  ] != 100 ||
    table_01_variable_sources_definitions_coverage$coverage_percent[
      table_01_variable_sources_definitions_coverage$variable == "DIVX"
    ] != 100
) {
  stop("ECI y DIVX deben conservar 100 % de cobertura en la tabla 1.")
}
if (
  nrow(table_02_descriptive_statistics) !=
    1L + 2L * nrow(panel_metadata) ||
    any(!is.finite(table_02_descriptive_statistics$mean)) ||
    any(!is.finite(table_02_descriptive_statistics$standard_deviation))
) {
  stop("La tabla 2 tiene dimensiones o estadísticos no válidos.")
}
if (nrow(table_03_econometric_sample_comparison) != 5L) {
  stop("La tabla 3 debe contener exactamente cinco definiciones de muestra.")
}
if (
  !all(
    c("Resumen por variable", "Año estructural") %in%
      table_04_missing_data_patterns$pattern_type
  )
) {
  stop("La tabla 4 no documenta los resúmenes y años estructurales.")
}

# Registrar la versión exacta del insumo utilizado por el capítulo.
input_manifest <- data.frame(
  input_file = normalizePath(
    panel_file,
    winslash = "/",
    mustWork = TRUE
  ),
  input_md5 = unname(tools::md5sum(panel_file)),
  executed_at_utc = format(
    Sys.time(),
    tz = "UTC",
    usetz = TRUE
  ),
  r_version = R.version.string,
  rows = nrow(panel),
  countries = country_count,
  first_year = min(panel$year),
  last_year = max(panel$year),
  stringsAsFactors = FALSE
)

# Funciones únicas que utilizarán los siguientes bloques del capítulo.
write_chapter10_table <- function(data, filename) {
  if (!grepl("[.]csv$", filename, ignore.case = TRUE)) {
    stop("Las tablas intermedias del capítulo deben guardarse como CSV.")
  }
  destination <- file.path(tables_path, filename)
  write.csv(
    data,
    destination,
    row.names = FALSE,
    na = "",
    fileEncoding = "UTF-8"
  )
  destination
}

# Definir función principal o auxiliar
save_chapter10_figure_pdf <- function(
    draw_figure,
    filename_stem,
    width = 8,
    height = 5.5
) {
  if (!is.function(draw_figure)) {
    stop("draw_figure debe ser una función que dibuje una figura.")
  }
  if (!grepl("^[a-z0-9_]+$", filename_stem)) {
    stop("El nombre base de la figura contiene caracteres no permitidos.")
  }

  # Ejecutar la siguiente instrucción del bloque
  pdf_destination <- file.path(
    figures_path,
    paste0(filename_stem, ".pdf")
  )

  # Ejecutar la siguiente instrucción del bloque
  grDevices::cairo_pdf(
    filename = pdf_destination,
    width = width,
    height = height,
    family = "sans"
  )
  tryCatch(
    draw_figure(),
    finally = grDevices::dev.off()
  )

  # Ejecutar la siguiente instrucción del bloque
  pdf_destination
}

# Escribir los controles técnicos y las cuatro tablas para revisión.
validation_file <- write_chapter10_table(
  validation,
  "chapter10_input_validation.csv"
)
sample_summary_file <- write_chapter10_table(
  sample_summary,
  "chapter10_sample_summary.csv"
)
manifest_file <- write_chapter10_table(
  input_manifest,
  "chapter10_input_manifest.csv"
)
table_01_file <- write_chapter10_table(
  table_01_variable_sources_definitions_coverage,
  "table_01_variable_sources_definitions_coverage.csv"
)
table_02_file <- write_chapter10_table(
  table_02_descriptive_statistics,
  "table_02_descriptive_statistics.csv"
)
table_03_file <- write_chapter10_table(
  table_03_econometric_sample_comparison,
  "table_03_econometric_sample_comparison.csv"
)
table_04_file <- write_chapter10_table(
  table_04_missing_data_patterns,
  "table_04_missing_data_patterns.csv"
)

# ---------------------------------------------------------------------------
# FIGURAS: contratos, datos y estilo compartido
# ---------------------------------------------------------------------------

# Paleta sobria y apta para impresión.
figure_colours <- c(
  blue = "#1F5A93",
  blue_light = "#DCE8F2",
  gold = "#B07A21",
  orange = "#D95F02",
  green = "#1B9E77",
  purple = "#7570B3",
  charcoal = "#24292F",
  grey = "#667085",
  grid = "#D9DEE5"
)

# Definir función principal o auxiliar
mean_or_na <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  mean(x, na.rm = TRUE)
}

# Definir función principal o auxiliar
draw_panel_axes <- function(
    x_ticks,
    y_ticks,
    x_labels = x_ticks,
    y_labels = y_ticks,
    show_x = TRUE
) {
  graphics::abline(
    h = y_ticks,
    col = figure_colours["grid"],
    lwd = 0.8
  )
  graphics::axis(
    2,
    at = y_ticks,
    labels = y_labels,
    las = 1,
    col = NA,
    col.ticks = figure_colours["charcoal"],
    col.axis = figure_colours["charcoal"]
  )
  if (show_x) {
    graphics::axis(
      1,
      at = x_ticks,
      labels = x_labels,
      col = NA,
      col.ticks = figure_colours["charcoal"],
      col.axis = figure_colours["charcoal"]
    )
  }
}

# Insumos país y año sin ponderar a los países por el número de observaciones.
country_dres <- unique(
  panel[c(
    "country_iso3_code",
    "country",
    "dres_base_mean_percent"
  )]
)
country_dres <- country_dres[
  order(country_dres$dres_base_mean_percent),
  ,
  drop = FALSE
]

# Ejecutar la siguiente instrucción del bloque
country_means <- stats::aggregate(
  panel[c(
    "rents_oil_gas",
    "rents_mining",
    "rents",
    "eci",
    "divx"
  )],
  by = list(country_iso3_code = panel$country_iso3_code),
  FUN = mean_or_na
)
country_names <- unique(
  panel[c("country_iso3_code", "country")]
)
country_means <- merge(
  country_names,
  country_means,
  by = "country_iso3_code",
  all.y = TRUE,
  sort = TRUE
)

# Ejecutar la siguiente instrucción del bloque
yearly_summary <- do.call(
  rbind,
  lapply(
    split(panel, panel$year),
    function(year_data) {
      data.frame(
        year = unique(year_data$year),
        eci_q25 = unname(
          stats::quantile(year_data$eci, 0.25, na.rm = TRUE)
        ),
        eci_median = stats::median(year_data$eci, na.rm = TRUE),
        eci_q75 = unname(
          stats::quantile(year_data$eci, 0.75, na.rm = TRUE)
        ),
        divx_q25 = unname(
          stats::quantile(year_data$divx, 0.25, na.rm = TRUE)
        ),
        divx_median = stats::median(year_data$divx, na.rm = TRUE),
        divx_q75 = unname(
          stats::quantile(year_data$divx, 0.75, na.rm = TRUE)
        ),
        stringsAsFactors = FALSE
      )
    }
  )
)
row.names(yearly_summary) <- NULL

# Ejecutar la siguiente instrucción del bloque
extractive_profile <- country_means[
  complete.cases(
    country_means[c("rents_oil_gas", "rents_mining")]
  ),
  ,
  drop = FALSE
]
rents_relationship <- country_means[
  complete.cases(
    country_means[c("rents", "eci", "divx")]
  ),
  ,
  drop = FALSE
]

# Evaluar condición de control de flujo
if (
  nrow(country_dres) != 55L ||
    anyNA(country_dres$dres_base_mean_percent) ||
    nrow(extractive_profile) != 53L ||
    nrow(yearly_summary) != 26L ||
    anyNA(yearly_summary) ||
    nrow(rents_relationship) != 53L
) {
  stop(
    "Las muestras de las figuras no coinciden con el panel validado: ",
    "se esperaban 55 países para DRES, 53 perfiles extractivos, ",
    "26 años y 53 promedios país con RENTS."
  )
}

# FIGURA 1
# Pregunta: ¿cómo se distribuye el criterio de selección DRES?
# Grano: un promedio 1990-1995 por país (55 observaciones).
# Lectura: la muestra cubre un rango amplio por encima del umbral de 20 %.
draw_figure_01 <- function() {
  graphics::par(
    family = "sans",
    mar = c(4.4, 4.5, 1.0, 1.2),
    mgp = c(2.6, 0.7, 0),
    tcl = -0.25,
    las = 1,
    fg = "black",
    col.axis = "black",
    col.lab = "black",
    cex.axis = 0.82,
    cex.lab = 0.88
  )

  # Ejecutar la siguiente instrucción del bloque
  histogram <- graphics::hist(
    country_dres$dres_base_mean_percent,
    breaks = seq(20, 100, by = 10),
    right = FALSE,
    include.lowest = TRUE,
    plot = FALSE
  )
  y_limit <- c(0, max(histogram$counts) * 1.32)
  y_ticks <- pretty(y_limit, n = 5)

  # Generar visualización gráfica
  graphics::plot(
    NA,
    xlim = c(18, 100),
    ylim = y_limit,
    xaxs = "i",
    yaxs = "i",
    axes = FALSE,
    xlab = "DRES: participación de exportaciones extractivas (%)",
    ylab = "Número de países"
  )
  graphics::abline(
    h = y_ticks,
    col = figure_colours["grid"],
    lwd = 0.8
  )
  graphics::rect(
    histogram$breaks[-length(histogram$breaks)],
    0,
    histogram$breaks[-1],
    histogram$counts,
    col = figure_colours["blue"],
    border = "white",
    lwd = 1.2
  )
  graphics::abline(
    v = 20,
    col = figure_colours["gold"],
    lwd = 2,
    lty = 2
  )

  # Un país representativo por intervalo vincula la distribución con casos
  # concretos sin convertir el histograma en una lista de 55 etiquetas.
  dres_bin <- findInterval(
    country_dres$dres_base_mean_percent,
    histogram$breaks,
    all.inside = TRUE
  )
  bin_midpoints <- head(histogram$breaks, -1L) +
    diff(histogram$breaks) / 2
  representative_rows <- vapply(
    seq_along(histogram$counts),
    function(bin_index) {
      rows <- which(dres_bin == bin_index)
      rows[which.min(
        abs(
          country_dres$dres_base_mean_percent[rows] -
            bin_midpoints[bin_index]
        )
      )]
    },
    integer(1)
  )
  representative_x <- country_dres$dres_base_mean_percent[
    representative_rows
  ]
  representative_y <- histogram$counts[dres_bin[representative_rows]]
  graphics::segments(
    representative_x,
    representative_y + 0.06,
    representative_x,
    representative_y + 0.28,
    col = figure_colours["grey"],
    lwd = 0.8
  )
  graphics::text(
    representative_x,
    representative_y + 0.32,
    labels = country_dres$country_iso3_code[representative_rows],
    pos = 3,
    offset = 0.10,
    cex = 0.62,
    col = figure_colours["charcoal"]
  )

  # Ejecutar la siguiente instrucción del bloque
  graphics::axis(
    1,
    at = seq(20, 100, by = 10),
    labels = seq(20, 100, by = 10),
    col = NA,
    col.ticks = figure_colours["charcoal"]
  )
  graphics::axis(
    2,
    at = y_ticks,
    labels = y_ticks,
    col = NA,
    col.ticks = figure_colours["charcoal"]
  )
}

# FIGURA 2
# Pregunta: ¿predominan las rentas energéticas o las rentas mineras?
# Grano: promedio 1996-2021 por país (53 países con ambos componentes).
# Lectura: se replica la orientación del diagrama de Anne (2021): minería en
# el eje horizontal y energía en el vertical. Las líneas delimitan una
# participación mínima del 75 % para declarar predominio de un componente.
draw_figure_02 <- function() {
  graphics::par(
    family = "sans",
    mar = c(4.4, 4.7, 3.3, 1.2),
    mgp = c(2.7, 0.7, 0),
    tcl = -0.25,
    las = 1,
    fg = "black",
    col.axis = "black",
    col.lab = "black",
    cex.axis = 0.82,
    cex.lab = 0.88
  )

  # Ejecutar la siguiente instrucción del bloque
  mining <- extractive_profile$rents_mining
  energy <- extractive_profile$rents_oil_gas

  # La transformación abre la zona próxima a cero sin alterar las etiquetas,
  # que continúan expresadas en puntos porcentuales del PIB.
  x <- sqrt(mining)
  y <- sqrt(energy)
  x_values <- c(0, 0.1, 0.5, 1, 2, 5, 10, 15)
  y_values <- c(0, 1, 5, 10, 20, 30, 40, 50)
  x_values <- x_values[x_values <= ceiling(max(mining))]
  y_values <- y_values[y_values <= ceiling(max(energy) / 10) * 10]
  x_ticks <- sqrt(x_values)
  y_ticks <- sqrt(y_values)
  x_limit <- c(-0.10, sqrt(max(mining)) * 1.10)
  y_limit <- c(-0.12, sqrt(max(energy)) * 1.08)

  # Ejecutar la siguiente instrucción del bloque
  profile_levels <- c(
    "Petróleo y gas ≥ 75 %",
    "Carbón y minerales ≥ 75 %",
    "Perfil mixto (25–75 %)"
  )
  total_extractive_rents <- energy + mining
  energy_share <- ifelse(
    total_extractive_rents == 0,
    0.50,
    energy / total_extractive_rents
  )
  profile <- ifelse(
    energy_share >= 0.75,
    profile_levels[1],
    ifelse(
      energy_share <= 0.25,
      profile_levels[2],
      profile_levels[3]
    )
  )
  profile_colours <- c(
    "Petróleo y gas ≥ 75 %" = unname(figure_colours["orange"]),
    "Carbón y minerales ≥ 75 %" = unname(figure_colours["green"]),
    "Perfil mixto (25–75 %)" = unname(figure_colours["purple"])
  )
  profile_symbols <- c(
    "Petróleo y gas ≥ 75 %" = 21,
    "Carbón y minerales ≥ 75 %" = 22,
    "Perfil mixto (25–75 %)" = 24
  )

  # Generar visualización gráfica
  graphics::plot(
    x,
    y,
    type = "n",
    xlim = x_limit,
    ylim = y_limit,
    xaxs = "i",
    yaxs = "i",
    axes = FALSE,
    xlab = "Rentas de carbón y minerales (% del PIB)",
    ylab = "Rentas de petróleo y gas (% del PIB)"
  )
  draw_panel_axes(
    x_ticks,
    y_ticks,
    x_labels = sub("\\.", ",", format(x_values, trim = TRUE)),
    y_labels = sub("\\.", ",", format(y_values, trim = TRUE))
  )

  # Ejecutar la siguiente instrucción del bloque
  dominance_ratio <- 0.75 / 0.25
  upper_boundary_slope <- sqrt(dominance_ratio)
  lower_boundary_slope <- 1 / upper_boundary_slope
  upper_boundary_x <- seq(
    0,
    min(x_limit[2], y_limit[2] / upper_boundary_slope),
    length.out = 200
  )
  lower_boundary_x <- seq(
    0,
    x_limit[2],
    length.out = 200
  )
  graphics::lines(
    upper_boundary_x,
    upper_boundary_slope * upper_boundary_x,
    col = figure_colours["grey"],
    lty = 2,
    lwd = 1.2
  )
  graphics::lines(
    lower_boundary_x,
    lower_boundary_slope * lower_boundary_x,
    col = figure_colours["grey"],
    lty = 2,
    lwd = 1.2
  )

  # Iterar sobre los elementos del conjunto
  for (profile_name in profile_levels) {
    rows <- profile == profile_name
    graphics::points(
      x[rows],
      y[rows],
      pch = profile_symbols[profile_name],
      cex = 1.30,
      bg = grDevices::adjustcolor(
        profile_colours[profile_name],
        alpha.f = 0.82
      ),
      col = profile_colours[profile_name],
      lwd = 0.9
    )
  }

  # Ejecutar la siguiente instrucción del bloque
  # Etiquetar todos los casos no nulos siguiendo la convención de Hausmann
  not_at_origin <- !(mining == 0 & energy == 0)
  label_rows <- which(not_at_origin)
  label_positions <- ifelse(
    x[label_rows] >= stats::quantile(x[not_at_origin], 0.85),
    2,
    4
  )
  # Ajustar casos particulares para evitar solapamiento visual
  label_positions[
    extractive_profile$country_iso3_code[label_rows] == "IDN"
  ] <- 4
  label_positions[
    extractive_profile$country_iso3_code[label_rows] == "BOL"
  ] <- 3
  label_positions[
    extractive_profile$country_iso3_code[label_rows] == "COL"
  ] <- 2

  graphics::text(
    x[label_rows],
    y[label_rows],
    labels = extractive_profile$country_iso3_code[label_rows],
    pos = label_positions,
    offset = 0.30,
    cex = 0.52,
    col = figure_colours["charcoal"],
    xpd = NA
  )

  # Ejecutar la siguiente instrucción del bloque
  countries_at_origin <- sum(mining == 0 & energy == 0)
  if (countries_at_origin > 1L) {
    graphics::segments(
      0,
      0,
      sqrt(0.025),
      sqrt(0.25),
      col = figure_colours["grey"],
      lwd = 0.8
    )
    graphics::text(
      sqrt(0.025),
      sqrt(0.25),
      labels = paste(countries_at_origin, "países en (0; 0)"),
      pos = 4,
      offset = 0.25,
      cex = 0.70,
      col = figure_colours["grey"]
    )
  }

  # Ejecutar la siguiente instrucción del bloque
  graphics::text(
    x_limit[2],
    y_limit[2] * 1.035,
    labels = "Escalas: raíz cuadrada",
    adj = c(1, 0),
    cex = 0.68,
    col = figure_colours["grey"],
    xpd = NA
  )

  # Ejecutar la siguiente instrucción del bloque
  graphics::legend(
    x = mean(x_limit),
    y = y_limit[2] * 1.12,
    xjust = 0.5,
    yjust = 1,
    xpd = NA,
    ncol = 2,
    title = "Tipo de perfil extractivo",
    legend = c(profile_levels, "Límites de predominio"),
    pch = c(unname(profile_symbols[profile_levels]), NA),
    pt.bg = c(unname(profile_colours[profile_levels]), NA),
    col = c(unname(profile_colours[profile_levels]), figure_colours["grey"]),
    lty = c(NA, NA, NA, 2),
    lwd = c(NA, NA, NA, 1.2),
    pt.cex = 1.15,
    cex = 0.72,
    bty = "n"
  )
}

# FIGURA 3
# Pregunta: ¿cómo evoluciona la distribución anual de ECI?
# Grano: 55 países por año, 1996-2021.
# Lectura: línea = mediana; banda = intervalo intercuartílico.
draw_annual_figure <- function(
    median_values,
    lower_values,
    upper_values,
    y_label
) {
  graphics::par(
    family = "sans",
    mar = c(4.4, 4.4, 1.0, 1.2),
    mgp = c(2.5, 0.65, 0),
    tcl = -0.22,
    las = 1,
    fg = "black",
    col.axis = "black",
    col.lab = "black",
    cex.axis = 0.82,
    cex.lab = 0.88
  )

  # Ejecutar la siguiente instrucción del bloque
  y_limit <- range(lower_values, upper_values)
  y_padding <- diff(y_limit) * 0.08
  y_limit <- y_limit + c(-y_padding, y_padding)
  y_ticks <- pretty(y_limit, n = 5)

  # Generar visualización gráfica
  graphics::plot(
    yearly_summary$year,
    median_values,
    type = "n",
    xlim = range(yearly_summary$year),
    ylim = y_limit,
    xaxs = "i",
    yaxs = "i",
    axes = FALSE,
    xlab = "Año",
    ylab = y_label
  )
  draw_panel_axes(
    x_ticks = seq(1996, 2021, by = 5),
    y_ticks = y_ticks,
    show_x = TRUE
  )
  graphics::polygon(
    c(yearly_summary$year, rev(yearly_summary$year)),
    c(lower_values, rev(upper_values)),
    col = grDevices::adjustcolor(
      figure_colours["blue"],
      alpha.f = 0.17
    ),
    border = NA
  )
  graphics::lines(
    yearly_summary$year,
    median_values,
    col = figure_colours["blue"],
    lwd = 2.2
  )
  graphics::points(
    yearly_summary$year,
    median_values,
    pch = 21,
    cex = 0.65,
    bg = "white",
    col = figure_colours["blue"],
    lwd = 1
  )
  graphics::legend(
    "top",
    inset = c(0, 0.03),
    legend = c("Mediana", "Intervalo intercuartílico"),
    col = c(figure_colours["blue"], NA),
    lwd = c(2.2, NA),
    pch = c(NA, 22),
    pt.bg = c(NA, grDevices::adjustcolor(
      figure_colours["blue"],
      alpha.f = 0.17
    )),
    pt.cex = c(NA, 1.4),
    bty = "n",
    cex = 0.76,
    horiz = TRUE,
    xpd = NA
  )
}

# Definir función principal o auxiliar
draw_figure_03 <- function() {
  draw_annual_figure(
    yearly_summary$eci_median,
    yearly_summary$eci_q25,
    yearly_summary$eci_q75,
    "ECI"
  )
}

# FIGURA 4
# Pregunta: ¿cómo evoluciona la distribución anual de DIVX?
# Grano: 55 países por año, 1996-2021.
# Lectura: línea = mediana; banda = intervalo intercuartílico.
draw_figure_04 <- function() {
  draw_annual_figure(
    yearly_summary$divx_median,
    yearly_summary$divx_q25,
    yearly_summary$divx_q75,
    "DIVX"
  )
}

# FIGURA 5
# Pregunta: ¿cómo se asocian las rentas y ECI?
# Grano: promedio 1996-2021 por país (53 países con RENTS observado).
# Lectura: tendencia lineal descriptiva con intervalo de confianza del 95 %.
draw_country_relationship_figure <- function(y, y_label, labels) {
  graphics::par(
    family = "sans",
    mar = c(4.4, 4.5, 1.0, 1.2),
    mgp = c(2.5, 0.65, 0),
    tcl = -0.22,
    las = 1,
    fg = "black",
    col.axis = "black",
    col.lab = "black",
    cex.axis = 0.82,
    cex.lab = 0.88
  )

  # Ejecutar la siguiente instrucción del bloque
  x <- rents_relationship$rents
  x_padding <- max(x) * 0.035
  x_limit <- c(-x_padding, max(x) * 1.08)
  y_limit <- range(y)
  y_padding <- diff(y_limit) * 0.08
  y_limit <- y_limit + c(-y_padding, y_padding)
  x_ticks <- seq(0, ceiling(max(x) / 10) * 10, by = 10)
  y_ticks <- pretty(y_limit, n = 5)

  # Generar visualización gráfica
  graphics::plot(
    x,
    y,
    type = "n",
    xlim = x_limit,
    ylim = y_limit,
    xaxs = "i",
    yaxs = "i",
    axes = FALSE,
    xlab = "RENTS promedio (% del PIB)",
    ylab = y_label
  )
  draw_panel_axes(x_ticks, y_ticks)

  # Ejecutar la siguiente instrucción del bloque
  model <- stats::lm(y ~ x)
  x_grid <- seq(min(x), max(x), length.out = 200)
  prediction <- stats::predict(
    model,
    newdata = data.frame(x = x_grid),
    interval = "confidence",
    level = 0.95
  )
  graphics::polygon(
    c(x_grid, rev(x_grid)),
    c(prediction[, "lwr"], rev(prediction[, "upr"])),
    col = grDevices::adjustcolor(
      figure_colours["blue"],
      alpha.f = 0.14
    ),
    border = NA
  )
  graphics::lines(
    x_grid,
    prediction[, "fit"],
    col = figure_colours["blue"],
    lwd = 2
  )
  graphics::points(
    x,
    y,
    pch = 21,
    cex = 1,
    bg = grDevices::adjustcolor(
      figure_colours["blue"],
      alpha.f = 0.72
    ),
    col = "white",
    lwd = 0.7
  )

  # Etiquetar todos los casos (ISO3 de los 53 países) siguiendo la convención de Hausmann
  label_rows <- seq_along(x)
  label_positions <- ifelse(x[label_rows] >= stats::quantile(x, 0.85), 2, 4)
  
  graphics::text(
    x[label_rows],
    y[label_rows],
    labels = labels[label_rows],
    pos = label_positions,
    offset = 0.30,
    cex = 0.52,
    col = figure_colours["charcoal"],
    xpd = NA
  )
}

# Definir función principal o auxiliar
draw_figure_05 <- function() {
  draw_country_relationship_figure(
    rents_relationship$eci,
    "ECI medio",
    rents_relationship$country_iso3_code
  )
}

# FIGURA 6
# Pregunta: ¿cómo se asocian las rentas y DIVX?
# Grano: promedio 1996-2021 por país (53 países con RENTS observado).
# Lectura: tendencia lineal descriptiva con intervalo de confianza del 95 %.
draw_figure_06 <- function() {
  draw_country_relationship_figure(
    rents_relationship$divx,
    "DIVX medio",
    rents_relationship$country_iso3_code
  )
}

# FIGURA 7
# Pregunta: ¿cómo se relaciona el ECI con las rentas extractivas en escala
# logarítmica dentro de la muestra seleccionada?
# Grano: promedio 1996-2021 por país (53 países con RENTS observado).
# Lectura: LOESS y OLS resumen una asociación descriptiva; los cuadrantes se
# definen mediante ECI = 0 y la mediana muestral de RENTS.
draw_figure_07 <- function() {
  graphics::par(
    family = "sans",
    mar = c(4.6, 4.8, 1.5, 1.2),
    mgp = c(2.7, 0.7, 0),
    tcl = -0.23,
    las = 1,
    fg = "black",
    col.axis = "black",
    col.lab = "black",
    cex.axis = 0.82,
    cex.lab = 0.88
  )

  # Ejecutar la siguiente instrucción del bloque
  x <- log(rents_relationship$rents + 0.1)
  y <- rents_relationship$eci
  codes <- rents_relationship$country_iso3_code

  # Ejecutar la siguiente instrucción del bloque
  x_limit <- range(x) + c(-0.18, 0.18)
  y_limit <- range(y) + c(-0.16, 0.22)
  x_ticks <- pretty(x_limit, n = 7)
  y_ticks <- pretty(y_limit, n = 6)
  x_threshold <- stats::median(x)
  rents_threshold <- stats::median(rents_relationship$rents)

  # Generar visualización gráfica
  graphics::plot(
    x,
    y,
    type = "n",
    xlim = x_limit,
    ylim = y_limit,
    xaxs = "i",
    yaxs = "i",
    axes = FALSE,
    xlab = "log(RENTS promedio + 0,1)",
    ylab = "ECI medio"
  )
  draw_panel_axes(x_ticks, y_ticks)

  # Banda de confianza y recta OLS.
  ols_model <- stats::lm(y ~ x)
  x_grid <- seq(min(x), max(x), length.out = 300)
  ols_prediction <- stats::predict(
    ols_model,
    newdata = data.frame(x = x_grid),
    interval = "confidence",
    level = 0.95
  )
  graphics::polygon(
    c(x_grid, rev(x_grid)),
    c(
      ols_prediction[, "lwr"],
      rev(ols_prediction[, "upr"])
    ),
    col = grDevices::adjustcolor(
      figure_colours["grey"],
      alpha.f = 0.15
    ),
    border = NA
  )

  # Umbrales conceptuales. La mediana se expresa en la unidad original.
  graphics::abline(
    v = x_threshold,
    h = 0,
    col = figure_colours["grey"],
    lty = 3,
    lwd = 1.25
  )

  # Las dos tendencias se distinguen también mediante el tipo de línea.
  loess_model <- stats::loess(
    y ~ x,
    span = 0.80,
    degree = 1,
    control = stats::loess.control(surface = "direct")
  )
  loess_prediction <- stats::predict(
    loess_model,
    newdata = data.frame(x = x_grid)
  )
  finite_loess <- is.finite(loess_prediction)
  graphics::lines(
    x_grid[finite_loess],
    loess_prediction[finite_loess],
    col = figure_colours["blue"],
    lwd = 2.5,
    lty = 1
  )
  graphics::lines(
    x_grid,
    ols_prediction[, "fit"],
    col = figure_colours["gold"],
    lwd = 2.1,
    lty = 2
  )

  # Ejecutar la siguiente instrucción del bloque
  graphics::points(
    x,
    y,
    pch = 21,
    cex = 1.02,
    bg = grDevices::adjustcolor(
      figure_colours["blue"],
      alpha.f = 0.58
    ),
    col = "white",
    lwd = 0.65
  )

  # Etiquetar todos los casos (ISO3 de los 53 países) siguiendo la convención de Hausmann
  label_positions <- ifelse(x >= stats::quantile(x, 0.85), 2, 4)
  graphics::text(
    x,
    y,
    labels = codes,
    pos = label_positions,
    offset = 0.30,
    cex = 0.52,
    col = "black",
    xpd = NA
  )

  # Ejecutar la siguiente instrucción del bloque
  left_midpoint <- mean(c(x_limit[1], x_threshold))
  right_midpoint <- mean(c(x_threshold, x_limit[2]))
  upper_label_y <- y_limit[2] - 0.48
  lower_label_y <- y_limit[1] + 0.43
  quadrant_labels <- c(
    "ECI >= 0\nRENTS < mediana muestral",
    "ECI >= 0\nRENTS >= mediana muestral",
    "ECI < 0\nRENTS < mediana muestral",
    "ECI < 0\nRENTS >= mediana muestral"
  )
  graphics::text(
    c(
      left_midpoint,
      right_midpoint,
      left_midpoint,
      right_midpoint
    ),
    c(
      upper_label_y,
      upper_label_y,
      lower_label_y,
      lower_label_y
    ),
    labels = quadrant_labels,
    cex = 0.76,
    font = 1,
    col = "black"
  )

  # Ejecutar la siguiente instrucción del bloque
  median_value_label <- paste0(
    formatC(
      rents_threshold,
      digits = 2,
      format = "f",
      decimal.mark = ","
    ),
    " %"
  )
  graphics::text(
    x_threshold + 0.06,
    y_limit[2] - 0.04,
    labels = median_value_label,
    adj = c(0, 1),
    cex = 0.62,
    col = "black"
  )
  graphics::text(
    x_limit[1] + 0.05,
    0,
    labels = "ECI = 0",
    adj = c(0, -0.25),
    cex = 0.62,
    col = "black"
  )

  # Ejecutar la siguiente instrucción del bloque
  r_squared_label <- paste0(
    "OLS: R² = ",
    formatC(
      summary(ols_model)$r.squared,
      digits = 3,
      format = "f",
      decimal.mark = ","
    )
  )
  graphics::text(
    x_limit[2] - 0.08,
    y_limit[2] - 0.04,
    labels = r_squared_label,
    adj = c(1, 1),
    cex = 0.68,
    col = "black"
  )

  # Ejecutar la siguiente instrucción del bloque
  graphics::legend(
    "top",
    inset = c(0, -0.015),
    legend = c("LOESS", "OLS"),
    col = c(
      figure_colours["blue"],
      figure_colours["gold"]
    ),
    lwd = c(2.5, 2.1),
    lty = c(1, 2),
    horiz = TRUE,
    bty = "n",
    cex = 0.72,
    text.col = "black",
    xpd = NA
  )
}

# Ejecutar la siguiente instrucción del bloque
figure_01_file <- save_chapter10_figure_pdf(
  draw_figure_01,
  "figure_01_dres_distribution",
  width = 8.4,
  height = 5.5
)
figure_02_file <- save_chapter10_figure_pdf(
  draw_figure_02,
  "figure_02_extractive_profile_country",
  width = 8.4,
  height = 6.0
)
figure_03_file <- save_chapter10_figure_pdf(
  draw_figure_03,
  "figure_03_eci_annual_evolution",
  width = 8.4,
  height = 5.5
)
figure_04_file <- save_chapter10_figure_pdf(
  draw_figure_04,
  "figure_04_divx_annual_evolution",
  width = 8.4,
  height = 5.5
)
figure_05_file <- save_chapter10_figure_pdf(
  draw_figure_05,
  "figure_05_rents_eci_country_means",
  width = 8.4,
  height = 5.5
)
figure_06_file <- save_chapter10_figure_pdf(
  draw_figure_06,
  "figure_06_rents_divx_country_means",
  width = 8.4,
  height = 5.5
)
figure_07_file <- save_chapter10_figure_pdf(
  draw_figure_07,
  "figure_07_eci_log_rents_quadrants",
  width = 8.4,
  height = 5.8
)

# Ejecutar la siguiente instrucción del bloque
message("Preparación reproducible del capítulo 10 completada.")
message("Panel validado: ", nrow(panel), " filas y ", country_count, " países.")
message(
  "Cobertura individual de ECI: ",
  nrow(eci_available),
  " observaciones (",
  round(100 * nrow(eci_available) / nrow(panel), 2),
  "%)."
)
message(
  "Cobertura individual de DIVX: ",
  nrow(divx_available),
  " observaciones (",
  round(100 * nrow(divx_available) / nrow(panel), 2),
  "%)."
)
message(
  "Muestra econométrica completa con ECI: ",
  nrow(eci_sample),
  " observaciones de ",
  length(unique(eci_sample$country_iso3_code)),
  " países."
)
message(
  "Muestra econométrica completa con DIVX: ",
  nrow(divx_sample),
  " observaciones de ",
  length(unique(divx_sample$country_iso3_code)),
  " países."
)
message("Validación: ", validation_file)
message("Resumen de muestras: ", sample_summary_file)
message("Manifiesto: ", manifest_file)
message("Tabla 1: ", table_01_file)
message("Tabla 2: ", table_02_file)
message("Tabla 3: ", table_03_file)
message("Tabla 4: ", table_04_file)
message("Figura 1: ", figure_01_file)
message("Figura 2: ", figure_02_file)
message("Figura 3: ", figure_03_file)
message("Figura 4: ", figure_04_file)
message("Figura 5: ", figure_05_file)
message("Figura 6: ", figure_06_file)
message("Figura 7: ", figure_07_file)
