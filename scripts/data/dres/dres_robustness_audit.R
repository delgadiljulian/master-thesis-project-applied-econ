# Auditar la construcción de DRES y comparar definiciones metodológicas alternativas.
#
# Entradas: comercio Atlas SITC Rev. 2, catálogos Atlas, perfil DRES y validación WDI.
# Salidas: perfiles de sensibilidad, cambios de muestra y controles de calidad.

# Reunir las rutas posibles del helper que identifica la raíz del repositorio.
helper_path <- c(
  # Buscar el helper desde el archivo activo cuando el script se abre en RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path))), "project_paths.R")
  },
  # Buscar el helper cuando R se ejecuta desde la raíz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Buscar el helper cuando R se ejecuta desde scripts/data/dres/.
  file.path("..", "..", "project_paths.R"),
  # Buscar el helper cuando R se ejecuta desde scripts/.
  file.path("..", "project_paths.R"),
  # Buscar el helper en el directorio de trabajo como última alternativa.
  "project_paths.R"
)

# Conservar solamente la primera ruta candidata que exista en el equipo.
helper_path <- helper_path[file.exists(helper_path)][1]
# Detener la auditoría si no fue posible encontrar el helper del proyecto.
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}

# Ejecutar el helper para habilitar la búsqueda de la raíz del repositorio.
source(helper_path)
# Obtener la ruta absoluta del proyecto sin depender de la carpeta abierta en RStudio.
project_path <- find_project_path()

# Definir los seis años utilizados para clasificar la dependencia extractiva inicial.
base_years <- 1990:1995
# Definir los tres umbrales utilizados en la tesis para construir muestras anidadas.
sample_thresholds <- c(0.20, 0.30, 0.40)
# Definir los códigos biológicos o sintéticos ya excluidos de la construcción principal.
baseline_exclusions <- c("2711", "6671", "6674")
# Definir códigos adicionales que no representan extracción directa del subsuelo.
scope_correction_exclusions <- c("3510", "2786", "2820", "2881", "2882")

# Construir la ruta de la base comercial compartida del Atlas.
atlas_path <- file.path(project_path, "data", "raw", "atlas", "sitc_rev2_trade")
# Construir la ruta de los archivos comerciales independientes por economía.
country_files_path <- file.path(atlas_path, "country_exports")
# Construir la ruta del catálogo de productos SITC a cuatro dígitos.
product_catalog_file <- file.path(atlas_path, "atlas_sitc4_product_catalog.csv")
# Construir la ruta del perfil DRES que contiene las decisiones de ámbito nacional.
baseline_profile_file <- file.path(
  project_path,
  "data",
  "processed",
  "dres",
  "dres_country_profile_1990_1995.csv"
)
# Construir la ruta de los indicadores WDI utilizados como validación externa.
wdi_file <- file.path(
  project_path,
  "data",
  "raw",
  "dres",
  "world_bank_wdi",
  "dres_wdi_inputs_1990_1995.csv"
)
# Construir la carpeta específica que recibirá todas las salidas de robustez.
output_path <- file.path(project_path, "data", "processed", "dres", "robustness")

# Reunir los archivos indispensables para comprobarlos antes de iniciar la auditoría.
required_files <- c(product_catalog_file, baseline_profile_file, wdi_file)
# Identificar cualquier insumo ausente que impida reproducir las verificaciones.
missing_files <- required_files[!file.exists(required_files)]
# Detener la auditoría si falta algún archivo requerido.
if (length(missing_files) > 0L) {
  stop("Faltan archivos requeridos: ", paste(missing_files, collapse = ", "))
}
# Detener la auditoría si no existe la carpeta con exportaciones por economía.
if (!dir.exists(country_files_path)) {
  stop("No existe la carpeta de exportaciones Atlas: ", country_files_path)
}

# Crear la carpeta de resultados y sus directorios padres cuando sea necesario.
dir.create(output_path, recursive = TRUE, showWarnings = FALSE)

# Leer el catálogo de productos como texto para conservar ceros iniciales.
product_catalog <- read.csv(
  product_catalog_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
# Exigir las columnas que permiten vincular identificadores, códigos y nombres.
required_product_columns <- c("productId", "code", "nameEn")
# Identificar columnas ausentes por un posible cambio de estructura del Atlas.
missing_product_columns <- setdiff(required_product_columns, names(product_catalog))
# Detener la auditoría si el catálogo no permite clasificar los productos.
if (length(missing_product_columns) > 0L) {
  stop("Faltan columnas en el catálogo SITC: ", paste(missing_product_columns, collapse = ", "))
}
# Detener la auditoría si el catálogo repite identificadores internos de producto.
if (anyDuplicated(product_catalog$productId) > 0L) {
  stop("El catálogo SITC contiene productId duplicados.")
}

# Identificar la definición actualmente utilizada por el script principal de DRES.
product_catalog$scope_baseline <- (
  grepl("^3", product_catalog$code) |
    grepl("^27", product_catalog$code) |
    grepl("^28", product_catalog$code) |
    grepl("^68", product_catalog$code) |
    grepl("^667", product_catalog$code) |
    grepl("^971", product_catalog$code)
) & !product_catalog$code %in% baseline_exclusions
# Construir una corrección mínima que elimina electricidad, escorias y chatarra.
product_catalog$scope_corrected <- product_catalog$scope_baseline &
  !product_catalog$code %in% scope_correction_exclusions
# Construir una variante que elimina oro y piedras preciosas por riesgo de reexportación.
product_catalog$scope_no_gold_gems <- product_catalog$scope_corrected &
  !grepl("^667|^971", product_catalog$code)
# Construir una variante estrictamente aguas arriba de combustibles y minerales.
product_catalog$scope_upstream <- (
  grepl("^322", product_catalog$code) |
    product_catalog$code == "3330" |
    product_catalog$code %in% c("3413", "3414") |
    grepl("^27", product_catalog$code) |
    grepl("^28", product_catalog$code) |
    product_catalog$code %in% c("6672", "6673") |
    grepl("^971", product_catalog$code)
) & !product_catalog$code %in% c(baseline_exclusions, scope_correction_exclusions)
# Construir la aproximación más cercana a los indicadores WDI de combustibles y metales.
product_catalog$scope_wdi_like <-
  grepl("^3|^27|^28|^68", product_catalog$code)
# Identificar códigos numéricos que representan mercancías clasificadas en SITC.
product_catalog$is_classified_merchandise <- grepl("^[0-9]{4}$", product_catalog$code)
# Tratar la discrepancia comercial sin producto como mercancía no clasificada.
product_catalog$is_merchandise <- product_catalog$is_classified_merchandise |
  product_catalog$code == "XXXX"
# Identificar las cinco categorías de servicios que no deben integrar el denominador.
product_catalog$is_service <- product_catalog$code %in% c(
  "financial",
  "ict",
  "transport",
  "travel",
  "unspecified"
)

# Leer el perfil principal para reutilizar nombres y decisiones territoriales auditadas.
baseline_profile <- read.csv(
  baseline_profile_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
# Convertir la bandera territorial a un valor lógico interpretable por R.
baseline_profile$is_country_scope <- baseline_profile$is_country_scope == "TRUE"
# Exigir una fila única por código nacional antes de utilizar el perfil como dimensión.
if (anyDuplicated(baseline_profile$country_iso3_code) > 0L) {
  stop("El perfil DRES contiene códigos nacionales duplicados.")
}

# Obtener la lista ordenada de archivos comerciales disponibles por economía.
country_files <- sort(list.files(country_files_path, pattern = "\\.csv$", full.names = TRUE))
# Detener la auditoría si la carpeta comercial está vacía.
if (length(country_files) == 0L) {
  stop("No se encontraron archivos comerciales Atlas por economía.")
}

# Definir una función auxiliar que suma una columna sin propagar valores faltantes.
safe_sum <- function(values) {
  # Devolver la suma numérica de los valores recibidos.
  sum(values, na.rm = TRUE)
}

# Definir una función que audita un archivo nacional sin consolidar los 300 MB raw.
audit_country_file <- function(country_file) {
  # Obtener el código ISO3 a partir del nombre del archivo comercial.
  country_iso3_code <- tools::file_path_sans_ext(basename(country_file))
  # Recuperar el nombre del país desde el perfil procesado de DRES.
  country_name <- baseline_profile$country[
    match(country_iso3_code, baseline_profile$country_iso3_code)
  ]
  # Detener la auditoría si el archivo no puede vincularse con el perfil nacional.
  if (is.na(country_name)) {
    stop("El archivo comercial no aparece en el perfil DRES: ", country_file)
  }

  # Leer las observaciones comerciales como texto para controlar las conversiones.
  country_data <- read.csv(
    country_file,
    colClasses = "character",
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fileEncoding = "UTF-8"
  )
  # Exigir las columnas mínimas que definen la llave y el valor comercial.
  required_trade_columns <- c("year", "product_id", "export_value_usd")
  # Identificar columnas ausentes por un cambio inesperado del archivo raw.
  missing_trade_columns <- setdiff(required_trade_columns, names(country_data))
  # Detener la auditoría si no es posible reconstruir la información comercial.
  if (length(missing_trade_columns) > 0L) {
    stop("Faltan columnas comerciales en ", country_file, ".")
  }

  # Convertir el año a entero para aplicar límites temporales exactos.
  country_data$year <- suppressWarnings(as.integer(country_data$year))
  # Convertir el valor exportado a número para realizar agregaciones.
  country_data$export_value_usd <- suppressWarnings(as.numeric(country_data$export_value_usd))
  # Identificar filas con años o valores que no pudieron convertirse.
  invalid_values <- is.na(country_data$year) | is.na(country_data$export_value_usd)
  # Detener la auditoría si existen valores comerciales imposibles de interpretar.
  if (any(invalid_values)) {
    stop("Hay años o valores no numéricos en: ", country_file)
  }

  # Conservar solamente los seis años que determinan la pertenencia a la muestra.
  country_data <- country_data[country_data$year %in% base_years, , drop = FALSE]
  # Vincular cada observación con su fila correspondiente del catálogo SITC.
  product_match <- match(country_data$product_id, product_catalog$productId)
  # Detener la auditoría si aparece un producto que no puede clasificarse.
  if (any(is.na(product_match))) {
    stop("Hay productos sin correspondencia SITC en: ", country_file)
  }
  # Incorporar el código SITC para aplicar las definiciones alternativas.
  country_data$sitc_code <- product_catalog$code[product_match]
  # Incorporar el nombre del producto para que las anomalías sean legibles.
  country_data$product_name <- product_catalog$nameEn[product_match]
  # Incorporar la definición principal a cada observación comercial.
  country_data$scope_baseline <- product_catalog$scope_baseline[product_match]
  # Incorporar la definición con correcciones conceptuales mínimas.
  country_data$scope_corrected <- product_catalog$scope_corrected[product_match]
  # Incorporar la variante sin oro ni piedras preciosas.
  country_data$scope_no_gold_gems <- product_catalog$scope_no_gold_gems[product_match]
  # Incorporar la variante estrictamente aguas arriba.
  country_data$scope_upstream <- product_catalog$scope_upstream[product_match]
  # Incorporar la aproximación comparable con los grupos amplios de WDI.
  country_data$scope_wdi_like <- product_catalog$scope_wdi_like[product_match]
  # Identificar mercancías clasificadas mediante un código SITC numérico.
  country_data$is_classified_merchandise <-
    product_catalog$is_classified_merchandise[product_match]
  # Identificar mercancías clasificadas o registradas como discrepancia comercial.
  country_data$is_merchandise <- product_catalog$is_merchandise[product_match]
  # Identificar servicios que deben excluirse del denominador de DRES.
  country_data$is_service <- product_catalog$is_service[product_match]

  # Identificar llaves producto-año repetidas dentro del archivo nacional.
  duplicate_key <- duplicated(country_data[c("year", "product_id")]) |
    duplicated(country_data[c("year", "product_id")], fromLast = TRUE)
  # Conservar las filas duplicadas con suficiente información para investigarlas.
  duplicate_rows <- country_data[duplicate_key, c(
    "year",
    "product_id",
    "sitc_code",
    "product_name",
    "export_value_usd"
  ), drop = FALSE]
  # Agregar el código nacional a las filas duplicadas cuando existan.
  if (nrow(duplicate_rows) > 0L) {
    duplicate_rows$country_iso3_code <- country_iso3_code
    duplicate_rows$country <- country_name
  }

  # Detectar años que mezclan el agregado 3340 con sus cinco subproductos detallados.
  mixed_level_rows <- do.call(rbind, lapply(base_years, function(year_value) {
    # Seleccionar únicamente los productos refinados de petróleo del año evaluado.
    petroleum_rows <- country_data[
      country_data$year == year_value & grepl("^334", country_data$sitc_code),
      c("year", "product_id", "sitc_code", "product_name", "export_value_usd"),
      drop = FALSE
    ]
    # Comprobar si el agregado 3340 convive con alguna categoría 3341 a 3345.
    has_mixed_levels <- "3340" %in% petroleum_rows$sitc_code &
      any(petroleum_rows$sitc_code %in% paste0("334", 1:5))
    # Devolver solamente los registros que podrían producir doble conteo.
    if (has_mixed_levels) petroleum_rows else petroleum_rows[0, , drop = FALSE]
  }))
  # Incorporar la identidad nacional cuando se encuentra una mezcla de niveles.
  if (nrow(mixed_level_rows) > 0L) {
    mixed_level_rows$country_iso3_code <- country_iso3_code
    mixed_level_rows$country <- country_name
  }

  # Identificar correcciones negativas conservadas en la capa raw.
  negative_rows <- country_data[country_data$export_value_usd < 0, c(
    "year",
    "product_id",
    "sitc_code",
    "product_name",
    "export_value_usd",
    "scope_baseline",
    "scope_corrected"
  ), drop = FALSE]
  # Agregar la identidad nacional a las correcciones negativas encontradas.
  if (nrow(negative_rows) > 0L) {
    negative_rows$country_iso3_code <- country_iso3_code
    negative_rows$country <- country_name
  }

  # Conservar los valores raw para probar si las correcciones deberían compensar sumas.
  country_data$value_raw <- country_data$export_value_usd
  # Reproducir el tratamiento principal que transforma correcciones negativas a cero.
  country_data$value_zeroed <- pmax(country_data$export_value_usd, 0)

  # Crear seis filas nacionales para asegurar que los años faltantes sean visibles.
  annual_result <- data.frame(
    country_iso3_code = rep(country_iso3_code, length(base_years)),
    country = rep(country_name, length(base_years)),
    year = as.integer(base_years),
    row_count = 0L,
    product_count = 0L,
    total_exports_zeroed = 0,
    total_exports_raw = 0,
    total_merchandise_zeroed = 0,
    total_merchandise_raw = 0,
    total_classified_merchandise_zeroed = 0,
    total_services_zeroed = 0,
    trade_discrepancy_zeroed = 0,
    numerator_baseline = 0,
    numerator_baseline_raw = 0,
    numerator_corrected = 0,
    numerator_no_gold_gems = 0,
    numerator_upstream = 0,
    numerator_wdi_like = 0,
    stringsAsFactors = FALSE
  )

  # Recorrer los seis años para producir agregados comparables entre variantes.
  for (year_value in base_years) {
    # Seleccionar las observaciones correspondientes al año actual.
    annual_data <- country_data[country_data$year == year_value, , drop = FALSE]
    # Identificar la fila donde se almacenará el resumen anual.
    result_row <- which(annual_result$year == year_value)
    # Contar las filas comerciales disponibles para detectar años vacíos.
    annual_result$row_count[result_row] <- nrow(annual_data)
    # Contar productos únicos para detectar cambios anormales de cobertura.
    annual_result$product_count[result_row] <- length(unique(annual_data$product_id))
    # Sumar el denominador después de transformar correcciones negativas a cero.
    annual_result$total_exports_zeroed[result_row] <- safe_sum(annual_data$value_zeroed)
    # Sumar el denominador respetando el signo original de las correcciones.
    annual_result$total_exports_raw[result_row] <- safe_sum(annual_data$value_raw)
    # Sumar únicamente mercancías y discrepancias comerciales para el denominador correcto.
    annual_result$total_merchandise_zeroed[result_row] <- safe_sum(
      annual_data$value_zeroed[annual_data$is_merchandise]
    )
    # Conservar el denominador de mercancías con los signos originales como sensibilidad.
    annual_result$total_merchandise_raw[result_row] <- safe_sum(
      annual_data$value_raw[annual_data$is_merchandise]
    )
    # Sumar mercancías con código SITC conocido y excluir la categoría de discrepancias.
    annual_result$total_classified_merchandise_zeroed[result_row] <- safe_sum(
      annual_data$value_zeroed[annual_data$is_classified_merchandise]
    )
    # Cuantificar los servicios que el script principal incorporó accidentalmente.
    annual_result$total_services_zeroed[result_row] <- safe_sum(
      annual_data$value_zeroed[annual_data$is_service]
    )
    # Cuantificar la categoría Atlas de mercancías sin producto identificable.
    annual_result$trade_discrepancy_zeroed[result_row] <- safe_sum(
      annual_data$value_zeroed[annual_data$sitc_code == "XXXX"]
    )
    # Sumar el numerador que reproduce exactamente la definición principal.
    annual_result$numerator_baseline[result_row] <- safe_sum(
      annual_data$value_zeroed[annual_data$scope_baseline]
    )
    # Sumar el numerador principal conservando las correcciones negativas originales.
    annual_result$numerator_baseline_raw[result_row] <- safe_sum(
      annual_data$value_raw[annual_data$scope_baseline]
    )
    # Sumar el numerador que elimina electricidad, escorias y chatarra identificable.
    annual_result$numerator_corrected[result_row] <- safe_sum(
      annual_data$value_zeroed[annual_data$scope_corrected]
    )
    # Sumar el numerador corregido después de retirar oro y piedras preciosas.
    annual_result$numerator_no_gold_gems[result_row] <- safe_sum(
      annual_data$value_zeroed[annual_data$scope_no_gold_gems]
    )
    # Sumar el numerador más restrictivo de productos extractivos aguas arriba.
    annual_result$numerator_upstream[result_row] <- safe_sum(
      annual_data$value_zeroed[annual_data$scope_upstream]
    )
    # Sumar los grupos amplios que permiten una comparación aproximada con WDI.
    annual_result$numerator_wdi_like[result_row] <- safe_sum(
      annual_data$value_zeroed[annual_data$scope_wdi_like]
    )
  }

  # Calcular la participación principal cuando el denominador anual sea positivo.
  annual_result$dres_baseline <- ifelse(
    annual_result$total_exports_zeroed > 0,
    annual_result$numerator_baseline / annual_result$total_exports_zeroed,
    NA_real_
  )
  # Calcular la participación respetando el signo original de las correcciones.
  annual_result$dres_negative_raw <- ifelse(
    annual_result$total_exports_raw > 0,
    annual_result$numerator_baseline_raw / annual_result$total_exports_raw,
    NA_real_
  )
  # Calcular la definición principal después de corregir el denominador a mercancías.
  annual_result$dres_goods_baseline <- ifelse(
    annual_result$total_merchandise_zeroed > 0,
    annual_result$numerator_baseline / annual_result$total_merchandise_zeroed,
    NA_real_
  )
  # Excluir también las discrepancias sin producto para probar su efecto en el denominador.
  annual_result$dres_classified_goods <- ifelse(
    annual_result$total_classified_merchandise_zeroed > 0,
    annual_result$numerator_baseline / annual_result$total_classified_merchandise_zeroed,
    NA_real_
  )
  # Calcular la participación con la corrección mínima del ámbito del subsuelo.
  annual_result$dres_corrected <- ifelse(
    annual_result$total_merchandise_zeroed > 0,
    annual_result$numerator_corrected / annual_result$total_merchandise_zeroed,
    NA_real_
  )
  # Calcular la participación sin oro ni piedras preciosas naturales.
  annual_result$dres_no_gold_gems <- ifelse(
    annual_result$total_merchandise_zeroed > 0,
    annual_result$numerator_no_gold_gems / annual_result$total_merchandise_zeroed,
    NA_real_
  )
  # Calcular la participación estricta de productos extractivos aguas arriba.
  annual_result$dres_upstream <- ifelse(
    annual_result$total_merchandise_zeroed > 0,
    annual_result$numerator_upstream / annual_result$total_merchandise_zeroed,
    NA_real_
  )
  # Calcular la participación aproximada a las categorías WDI.
  annual_result$dres_wdi_like <- ifelse(
    annual_result$total_merchandise_zeroed > 0,
    annual_result$numerator_wdi_like / annual_result$total_merchandise_zeroed,
    NA_real_
  )

  # Devolver los agregados anuales y las anomalías separadas para combinarlas después.
  list(
    annual = annual_result,
    duplicates = duplicate_rows,
    negatives = negative_rows,
    mixed_levels = mixed_level_rows
  )
}

# Procesar cada archivo de forma secuencial para mantener bajo el uso de memoria.
audit_parts <- lapply(country_files, audit_country_file)
# Apilar los pequeños resúmenes anuales producidos para cada economía.
annual_audit <- do.call(rbind, lapply(audit_parts, function(part) part$annual))
# Eliminar números de fila heredados para mantener una salida limpia.
row.names(annual_audit) <- NULL
# Ordenar la auditoría por país y año para facilitar la inspección manual.
annual_audit <- annual_audit[order(annual_audit$country_iso3_code, annual_audit$year), ]

# Identificar los países que realmente contienen filas producto-año duplicadas.
duplicate_parts <- lapply(audit_parts, function(part) part$duplicates)
# Conservar solamente los bloques de duplicados que tienen al menos una fila.
duplicate_parts <- duplicate_parts[vapply(duplicate_parts, nrow, integer(1)) > 0L]
# Apilar los duplicados o crear una tabla vacía cuando no exista ninguno.
duplicate_audit <- if (length(duplicate_parts) > 0L) {
  do.call(rbind, duplicate_parts)
} else {
  data.frame(
    year = integer(0),
    product_id = character(0),
    sitc_code = character(0),
    product_name = character(0),
    export_value_usd = numeric(0),
    country_iso3_code = character(0),
    country = character(0),
    stringsAsFactors = FALSE
  )
}
# Eliminar números de fila heredados en la tabla de duplicados.
row.names(duplicate_audit) <- NULL

# Identificar los países que contienen correcciones comerciales negativas.
negative_parts <- lapply(audit_parts, function(part) part$negatives)
# Conservar solamente los bloques de correcciones que tienen al menos una fila.
negative_parts <- negative_parts[vapply(negative_parts, nrow, integer(1)) > 0L]
# Apilar las correcciones o crear una tabla vacía cuando no exista ninguna.
negative_audit <- if (length(negative_parts) > 0L) {
  do.call(rbind, negative_parts)
} else {
  data.frame(
    year = integer(0),
    product_id = character(0),
    sitc_code = character(0),
    product_name = character(0),
    export_value_usd = numeric(0),
    scope_baseline = logical(0),
    scope_corrected = logical(0),
    country_iso3_code = character(0),
    country = character(0),
    stringsAsFactors = FALSE
  )
}
# Eliminar números de fila heredados en la tabla de correcciones negativas.
row.names(negative_audit) <- NULL

# Reunir los casos donde un agregado comercial convive con sus desagregaciones.
mixed_level_parts <- lapply(audit_parts, function(part) part$mixed_levels)
# Conservar solamente los bloques nacionales que contienen alguna mezcla de niveles.
mixed_level_parts <- mixed_level_parts[vapply(mixed_level_parts, nrow, integer(1)) > 0L]
# Apilar los casos detectados o crear una tabla vacía cuando no exista ninguno.
mixed_level_audit <- if (length(mixed_level_parts) > 0L) {
  do.call(rbind, mixed_level_parts)
} else {
  data.frame(
    year = integer(0),
    product_id = character(0),
    sitc_code = character(0),
    product_name = character(0),
    export_value_usd = numeric(0),
    country_iso3_code = character(0),
    country = character(0),
    stringsAsFactors = FALSE
  )
}
# Eliminar números de fila heredados en la auditoría de niveles comerciales.
row.names(mixed_level_audit) <- NULL

# Dividir el panel anual para resumir cada país de forma independiente.
country_groups <- split(annual_audit, annual_audit$country_iso3_code)
# Construir una fila de robustez por economía con todas las definiciones alternativas.
robustness_profile <- do.call(rbind, lapply(country_groups, function(country_data) {
  # Contar los años con un denominador comercial positivo.
  complete_years <- sum(!is.na(country_data$dres_baseline))
  # Contar los años que realmente tienen exportaciones positivas de mercancías.
  complete_goods_years <- sum(!is.na(country_data$dres_goods_baseline))
  # Conservar los valores anuales válidos de la definición principal.
  valid_baseline <- country_data$dres_baseline[!is.na(country_data$dres_baseline)]
  # Calcular el promedio principal cuando existen los seis años requeridos.
  mean_baseline <- if (complete_years == 6L) mean(valid_baseline) else NA_real_
  # Calcular el promedio después de retirar servicios del denominador.
  mean_goods_baseline <- if (complete_goods_years == 6L) {
    mean(country_data$dres_goods_baseline)
  } else {
    NA_real_
  }
  # Calcular el promedio cuando también se retiran discrepancias no clasificadas.
  mean_classified_goods <- if (complete_goods_years == 6L) {
    mean(country_data$dres_classified_goods)
  } else {
    NA_real_
  }
  # Calcular el promedio con correcciones de alcance conceptual.
  mean_corrected <- if (complete_goods_years == 6L) mean(country_data$dres_corrected) else NA_real_
  # Calcular el promedio después de retirar oro y piedras preciosas.
  mean_no_gold_gems <- if (complete_goods_years == 6L) mean(country_data$dres_no_gold_gems) else NA_real_
  # Calcular el promedio de la definición estricta aguas arriba.
  mean_upstream <- if (complete_goods_years == 6L) mean(country_data$dres_upstream) else NA_real_
  # Calcular el promedio de la aproximación comparable con WDI.
  mean_wdi_like <- if (complete_goods_years == 6L) mean(country_data$dres_wdi_like) else NA_real_
  # Calcular el promedio conservando el signo original de las correcciones negativas.
  mean_negative_raw <- if (complete_years == 6L) mean(country_data$dres_negative_raw) else NA_real_
  # Calcular la mediana para reducir la influencia de años extremos.
  median_corrected <- if (complete_goods_years == 6L) {
    median(country_data$dres_corrected)
  } else {
    NA_real_
  }
  # Calcular el cociente corregido de sumas para ponderar por exportaciones de mercancías.
  pooled_corrected <- if (complete_goods_years == 6L) {
    sum(country_data$numerator_corrected) / sum(country_data$total_merchandise_zeroed)
  } else {
    NA_real_
  }
  # Calcular el promedio de la primera mitad del periodo base.
  first_half_mean <- if (complete_goods_years == 6L) {
    mean(country_data$dres_corrected[country_data$year %in% 1990:1992])
  } else {
    NA_real_
  }
  # Calcular el promedio de la segunda mitad del periodo base.
  second_half_mean <- if (complete_goods_years == 6L) {
    mean(country_data$dres_corrected[country_data$year %in% 1993:1995])
  } else {
    NA_real_
  }
  # Calcular seis promedios alternativos eliminando un año cada vez.
  leave_one_out_means <- if (complete_goods_years == 6L) {
    vapply(seq_along(valid_baseline), function(index) {
      mean(country_data$dres_corrected[-index])
    }, numeric(1))
  } else {
    rep(NA_real_, 6L)
  }
  # Calcular el promedio disponible para evaluar una regla de cobertura de cinco años.
  available_mean <- if (complete_goods_years >= 5L) {
    mean(country_data$dres_corrected, na.rm = TRUE)
  } else {
    NA_real_
  }
  # Medir qué proporción del total descargado corresponde a servicios.
  service_share <- if (sum(country_data$total_exports_zeroed) > 0) {
    sum(country_data$total_services_zeroed) / sum(country_data$total_exports_zeroed)
  } else {
    NA_real_
  }
  # Medir qué proporción de las mercancías corresponde a discrepancias sin producto.
  discrepancy_share <- if (sum(country_data$total_merchandise_zeroed) > 0) {
    sum(country_data$trade_discrepancy_zeroed) /
      sum(country_data$total_merchandise_zeroed)
  } else {
    NA_real_
  }
  # Medir la variación relativa del número de productos reportados entre años.
  product_count_cv <- if (mean(country_data$product_count) > 0) {
    stats::sd(country_data$product_count) / mean(country_data$product_count)
  } else {
    NA_real_
  }
  # Devolver una fila nacional con todas las métricas de sensibilidad.
  data.frame(
    country_iso3_code = country_data$country_iso3_code[1],
    country = country_data$country[1],
    complete_years = complete_years,
    complete_goods_years = complete_goods_years,
    dres_baseline_mean = mean_baseline,
    dres_goods_baseline_mean = mean_goods_baseline,
    dres_classified_goods_mean = mean_classified_goods,
    dres_corrected_mean = mean_corrected,
    dres_no_gold_gems_mean = mean_no_gold_gems,
    dres_upstream_mean = mean_upstream,
    dres_wdi_like_mean = mean_wdi_like,
    dres_negative_raw_mean = mean_negative_raw,
    dres_median_corrected = median_corrected,
    dres_pooled_corrected = pooled_corrected,
    dres_first_half_mean = first_half_mean,
    dres_second_half_mean = second_half_mean,
    dres_leave_one_out_min = suppressWarnings(min(leave_one_out_means, na.rm = TRUE)),
    dres_leave_one_out_max = suppressWarnings(max(leave_one_out_means, na.rm = TRUE)),
    dres_available_mean_5plus = available_mean,
    minimum_annual_dres_corrected = suppressWarnings(
      min(country_data$dres_corrected, na.rm = TRUE)
    ),
    maximum_annual_dres_corrected = suppressWarnings(
      max(country_data$dres_corrected, na.rm = TRUE)
    ),
    service_share_download = service_share,
    trade_discrepancy_share_goods = discrepancy_share,
    product_count_min = min(country_data$product_count),
    product_count_max = max(country_data$product_count),
    product_count_cv = product_count_cv,
    stringsAsFactors = FALSE
  )
}))
# Eliminar números de fila heredados después de agrupar por país.
row.names(robustness_profile) <- NULL

# Reemplazar infinitos generados por países sin valores válidos con valores faltantes.
numeric_columns <- vapply(robustness_profile, is.numeric, logical(1))
# Recorrer cada columna numérica para limpiar infinitos positivos o negativos.
for (column_name in names(robustness_profile)[numeric_columns]) {
  # Identificar valores no finitos que no representan una estadística válida.
  invalid_numeric <- !is.finite(robustness_profile[[column_name]])
  # Reemplazar los valores no finitos por NA para hacer visible la falta de cobertura.
  robustness_profile[[column_name]][invalid_numeric] <- NA_real_
}

# Incorporar la decisión territorial sin eliminar ningún registro de la auditoría.
robustness_profile$is_country_scope <- baseline_profile$is_country_scope[
  match(robustness_profile$country_iso3_code, baseline_profile$country_iso3_code)
]
# Definir la elegibilidad principal como país del ámbito y seis años completos.
robustness_profile$eligible_baseline <- robustness_profile$is_country_scope &
  robustness_profile$complete_years == 6L
# Definir la elegibilidad corregida mediante seis años positivos de mercancías.
robustness_profile$eligible_goods <- robustness_profile$is_country_scope &
  robustness_profile$complete_goods_years == 6L
# Definir una elegibilidad alternativa que exige al menos cinco de los seis años.
robustness_profile$eligible_five_years <- robustness_profile$is_country_scope &
  robustness_profile$complete_goods_years >= 5L

# Crear banderas de pertenencia para cada definición y cada umbral.
for (threshold in sample_thresholds) {
  # Convertir el umbral a una etiqueta entera utilizada en los nombres de columnas.
  threshold_label <- as.character(round(100 * threshold))
  # Reproducir la muestra principal construida con el promedio de cocientes anuales.
  robustness_profile[[paste0("sample_baseline_", threshold_label)]] <-
    robustness_profile$eligible_baseline &
    robustness_profile$dres_baseline_mean >= threshold
  # Construir la muestra que corrige únicamente la presencia de servicios.
  robustness_profile[[paste0("sample_goods_baseline_", threshold_label)]] <-
    robustness_profile$eligible_goods &
    !is.na(robustness_profile$dres_goods_baseline_mean) &
    robustness_profile$dres_goods_baseline_mean >= threshold
  # Construir la muestra que también retira discrepancias sin producto identificado.
  robustness_profile[[paste0("sample_classified_goods_", threshold_label)]] <-
    robustness_profile$eligible_goods &
    !is.na(robustness_profile$dres_classified_goods_mean) &
    robustness_profile$dres_classified_goods_mean >= threshold
  # Construir la muestra con electricidad, escorias y chatarra identificable excluidas.
  robustness_profile[[paste0("sample_corrected_", threshold_label)]] <-
    robustness_profile$eligible_goods &
    !is.na(robustness_profile$dres_corrected_mean) &
    robustness_profile$dres_corrected_mean >= threshold
  # Construir la muestra que también excluye oro y piedras preciosas.
  robustness_profile[[paste0("sample_no_gold_gems_", threshold_label)]] <-
    robustness_profile$eligible_goods &
    !is.na(robustness_profile$dres_no_gold_gems_mean) &
    robustness_profile$dres_no_gold_gems_mean >= threshold
  # Construir la muestra con la definición estrictamente aguas arriba.
  robustness_profile[[paste0("sample_upstream_", threshold_label)]] <-
    robustness_profile$eligible_goods &
    !is.na(robustness_profile$dres_upstream_mean) &
    robustness_profile$dres_upstream_mean >= threshold
  # Construir la muestra utilizando la mediana de los seis años.
  robustness_profile[[paste0("sample_median_", threshold_label)]] <-
    robustness_profile$eligible_goods &
    !is.na(robustness_profile$dres_median_corrected) &
    robustness_profile$dres_median_corrected >= threshold
  # Construir la muestra utilizando el cociente de exportaciones acumuladas.
  robustness_profile[[paste0("sample_pooled_", threshold_label)]] <-
    robustness_profile$eligible_goods &
    !is.na(robustness_profile$dres_pooled_corrected) &
    robustness_profile$dres_pooled_corrected >= threshold
  # Construir la muestra que acepta cinco años y promedia la información disponible.
  robustness_profile[[paste0("sample_five_year_", threshold_label)]] <-
    robustness_profile$eligible_five_years &
    !is.na(robustness_profile$dres_available_mean_5plus) &
    robustness_profile$dres_available_mean_5plus >= threshold
}

# Identificar países del 20 % que permanecen incluidos al retirar cualquier año.
robustness_profile$stable_leave_one_out_20 <- robustness_profile$eligible_goods &
  robustness_profile$dres_leave_one_out_min >= 0.20
# Identificar países que superan el 20 % en ambas mitades del periodo base.
robustness_profile$stable_halves_20 <- robustness_profile$eligible_goods &
  robustness_profile$dres_first_half_mean >= 0.20 &
  robustness_profile$dres_second_half_mean >= 0.20
# Identificar países que superan el 20 % en cada uno de los seis años.
robustness_profile$stable_every_year_20 <- robustness_profile$eligible_goods &
  robustness_profile$minimum_annual_dres_corrected >= 0.20
# Identificar países muy cercanos al umbral principal en un margen de dos puntos.
robustness_profile$near_threshold_20 <- robustness_profile$eligible_goods &
  abs(robustness_profile$dres_corrected_mean - 0.20) <= 0.02
# Calcular el efecto de la corrección conceptual sobre el promedio principal.
robustness_profile$corrected_change_pp <- 100 * (
  robustness_profile$dres_corrected_mean - robustness_profile$dres_goods_baseline_mean
)
# Calcular el efecto de retirar oro y piedras preciosas sobre el promedio principal.
robustness_profile$no_gold_gems_change_pp <- 100 * (
  robustness_profile$dres_no_gold_gems_mean - robustness_profile$dres_corrected_mean
)
# Calcular el efecto de conservar correcciones negativas en lugar de llevarlas a cero.
robustness_profile$negative_treatment_change_pp <- 100 * (
  robustness_profile$dres_negative_raw_mean - robustness_profile$dres_baseline_mean
)
# Calcular cuánto cambia DRES al retirar servicios del denominador descargado.
robustness_profile$goods_denominator_change_pp <- 100 * (
  robustness_profile$dres_goods_baseline_mean - robustness_profile$dres_baseline_mean
)
# Calcular cuánto cambia DRES al retirar además discrepancias comerciales sin producto.
robustness_profile$classified_denominator_change_pp <- 100 * (
  robustness_profile$dres_classified_goods_mean -
    robustness_profile$dres_goods_baseline_mean
)

# Ordenar el perfil final por código nacional para facilitar uniones posteriores.
robustness_profile <- robustness_profile[order(robustness_profile$country_iso3_code), ]
# Eliminar números de fila heredados después del ordenamiento.
row.names(robustness_profile) <- NULL

# Definir las variantes que se resumirán de forma comparable en una tabla larga.
variant_columns <- c(
  baseline_current = "dres_baseline_mean",
  goods_denominator = "dres_goods_baseline_mean",
  classified_goods_denominator = "dres_classified_goods_mean",
  corrected_scope = "dres_corrected_mean",
  no_gold_gems = "dres_no_gold_gems_mean",
  upstream_only = "dres_upstream_mean",
  median_six_years = "dres_median_corrected",
  pooled_exports = "dres_pooled_corrected",
  available_five_years = "dres_available_mean_5plus"
)
# Inicializar una lista que recibirá un bloque de conteos por variante.
sample_count_parts <- vector("list", length(variant_columns))
# Recorrer las variantes para contar países en cada umbral.
for (variant_index in seq_along(variant_columns)) {
  # Recuperar el nombre legible de la variante actual.
  variant_name <- names(variant_columns)[variant_index]
  # Recuperar la columna numérica que contiene el DRES de la variante.
  metric_column <- unname(variant_columns[variant_index])
  # Aplicar la regla de cinco años solamente a la variante diseñada para ella.
  eligible_flag <- if (variant_name == "available_five_years") {
    robustness_profile$eligible_five_years
  } else if (variant_name == "baseline_current") {
    robustness_profile$eligible_baseline
  } else {
    robustness_profile$eligible_goods
  }
  # Crear tres filas con los conteos correspondientes a los umbrales de la tesis.
  sample_count_parts[[variant_index]] <- data.frame(
    variant = rep(variant_name, length(sample_thresholds)),
    threshold = sample_thresholds,
    countries = vapply(sample_thresholds, function(threshold) {
      sum(eligible_flag & robustness_profile[[metric_column]] >= threshold, na.rm = TRUE)
    }, integer(1)),
    stringsAsFactors = FALSE
  )
}
# Apilar los conteos de todas las variantes en una sola tabla legible.
sample_counts <- do.call(rbind, sample_count_parts)
# Eliminar números de fila heredados de la tabla de conteos.
row.names(sample_counts) <- NULL

# Identificar cambios de pertenencia respecto de la muestra principal del 20 %.
membership_changes <- robustness_profile[
  robustness_profile$sample_baseline_20 != robustness_profile$sample_corrected_20 |
    robustness_profile$sample_baseline_20 != robustness_profile$sample_goods_baseline_20 |
    robustness_profile$sample_baseline_20 != robustness_profile$sample_classified_goods_20 |
    robustness_profile$sample_baseline_20 != robustness_profile$sample_no_gold_gems_20 |
    robustness_profile$sample_baseline_20 != robustness_profile$sample_upstream_20 |
    robustness_profile$sample_baseline_20 != robustness_profile$sample_median_20 |
    robustness_profile$sample_baseline_20 != robustness_profile$sample_pooled_20,
  c(
    "country_iso3_code",
    "country",
    "dres_baseline_mean",
    "dres_goods_baseline_mean",
    "dres_classified_goods_mean",
    "dres_corrected_mean",
    "dres_no_gold_gems_mean",
    "dres_upstream_mean",
    "dres_median_corrected",
    "dres_pooled_corrected",
    "sample_baseline_20",
    "sample_goods_baseline_20",
    "sample_classified_goods_20",
    "sample_corrected_20",
    "sample_no_gold_gems_20",
    "sample_upstream_20",
    "sample_median_20",
    "sample_pooled_20"
  ),
  drop = FALSE
]
# Ordenar los cambios desde el país más cercano al umbral principal.
membership_changes <- membership_changes[
  order(abs(membership_changes$dres_baseline_mean - 0.20)),
]
# Eliminar números de fila heredados después del ordenamiento.
row.names(membership_changes) <- NULL

# Leer la validación WDI como texto para controlar explícitamente los faltantes.
wdi_data <- read.csv(
  wdi_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
# Convertir las dos participaciones WDI de porcentaje a fracción decimal.
wdi_data$wdi_share <- (
  suppressWarnings(as.numeric(wdi_data$fuel_exports_share)) +
    suppressWarnings(as.numeric(wdi_data$ores_metals_exports_share))
) / 100
# Conservar solo observaciones con ambas participaciones WDI disponibles.
wdi_valid <- wdi_data[!is.na(wdi_data$wdi_share), c(
  "country_iso3_code",
  "year",
  "wdi_share"
)]
# Convertir el año WDI a entero antes de realizar la unión.
wdi_valid$year <- as.integer(wdi_valid$year)
# Unir WDI con las dos definiciones Atlas que se quieren comparar.
validation_panel <- merge(
  annual_audit[c(
    "country_iso3_code",
    "year",
    "dres_baseline",
    "dres_goods_baseline",
    "dres_wdi_like"
  )],
  wdi_valid,
  by = c("country_iso3_code", "year"),
  all = FALSE
)
# Retirar uniones sin denominador Atlas válido antes de calcular correlaciones.
validation_panel <- validation_panel[stats::complete.cases(validation_panel), ]
# Calcular errores absolutos en puntos porcentuales para facilitar la interpretación.
validation_panel$baseline_abs_error_pp <- 100 * abs(
  validation_panel$dres_baseline - validation_panel$wdi_share
)
# Calcular el error después de corregir el denominador a exportaciones de mercancías.
validation_panel$goods_baseline_abs_error_pp <- 100 * abs(
  validation_panel$dres_goods_baseline - validation_panel$wdi_share
)
# Calcular el error de la definición Atlas comparable con las categorías WDI.
validation_panel$wdi_like_abs_error_pp <- 100 * abs(
  validation_panel$dres_wdi_like - validation_panel$wdi_share
)
# Resumir la validez concurrente de Atlas frente a WDI sin ocultar la cobertura limitada.
validation_summary <- data.frame(
  metric = c(
    "comparable_country_year_rows",
    "comparable_countries",
    "correlation_baseline_vs_wdi",
    "correlation_goods_baseline_vs_wdi",
    "correlation_wdi_like_vs_wdi",
    "median_abs_error_baseline_pp",
    "median_abs_error_goods_baseline_pp",
    "median_abs_error_wdi_like_pp"
  ),
  value = c(
    nrow(validation_panel),
    length(unique(validation_panel$country_iso3_code)),
    stats::cor(validation_panel$dres_baseline, validation_panel$wdi_share),
    stats::cor(validation_panel$dres_goods_baseline, validation_panel$wdi_share),
    stats::cor(validation_panel$dres_wdi_like, validation_panel$wdi_share),
    stats::median(validation_panel$baseline_abs_error_pp),
    stats::median(validation_panel$goods_baseline_abs_error_pp),
    stats::median(validation_panel$wdi_like_abs_error_pp)
  ),
  stringsAsFactors = FALSE
)

# Construir un inventario explícito de productos incluidos en cada definición.
scope_audit <- product_catalog[
  product_catalog$scope_baseline |
    product_catalog$scope_corrected |
    product_catalog$scope_no_gold_gems |
    product_catalog$scope_upstream |
    product_catalog$scope_wdi_like,
  c(
    "code",
    "nameEn",
    "productId",
    "scope_baseline",
    "scope_corrected",
    "scope_no_gold_gems",
    "scope_upstream",
    "scope_wdi_like"
  ),
  drop = FALSE
]
# Ordenar el inventario según el código SITC para facilitar su revisión.
scope_audit <- scope_audit[order(scope_audit$code), ]
# Eliminar números de fila heredados después del ordenamiento.
row.names(scope_audit) <- NULL

# Construir indicadores compactos de los controles de calidad ejecutados.
quality_summary <- data.frame(
  check = c(
    "country_files",
    "annual_rows",
    "duplicate_product_year_rows",
    "mixed_334_product_level_rows",
    "negative_raw_rows",
    "countries_with_six_years",
    "countries_with_six_merchandise_years",
    "countries_with_at_least_five_years",
    "baseline_sample_20",
    "goods_denominator_sample_20",
    "classified_goods_denominator_sample_20",
    "corrected_scope_sample_20",
    "no_gold_gems_sample_20",
    "upstream_sample_20",
    "pooled_sample_20",
    "median_sample_20",
    "stable_leave_one_out_20",
    "stable_halves_20",
    "stable_every_year_20",
    "near_threshold_20"
  ),
  value = c(
    length(country_files),
    nrow(annual_audit),
    nrow(duplicate_audit),
    nrow(mixed_level_audit),
    nrow(negative_audit),
    sum(robustness_profile$eligible_baseline),
    sum(robustness_profile$eligible_goods),
    sum(robustness_profile$eligible_five_years),
    sum(robustness_profile$sample_baseline_20),
    sum(robustness_profile$sample_goods_baseline_20),
    sum(robustness_profile$sample_classified_goods_20),
    sum(robustness_profile$sample_corrected_20),
    sum(robustness_profile$sample_no_gold_gems_20),
    sum(robustness_profile$sample_upstream_20),
    sum(robustness_profile$sample_pooled_20),
    sum(robustness_profile$sample_median_20),
    sum(robustness_profile$stable_leave_one_out_20),
    sum(robustness_profile$stable_halves_20),
    sum(robustness_profile$stable_every_year_20),
    sum(robustness_profile$near_threshold_20)
  ),
  stringsAsFactors = FALSE
)

# Guardar el panel anual que permite reproducir todas las variantes de DRES.
write.csv(
  annual_audit,
  file.path(output_path, "dres_robustness_country_year.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar el perfil nacional con métricas y banderas de sensibilidad.
write.csv(
  robustness_profile,
  file.path(output_path, "dres_robustness_country_profile.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar los conteos obtenidos para cada definición y umbral.
write.csv(
  sample_counts,
  file.path(output_path, "dres_robustness_sample_counts.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar los países cuya clasificación del 20 % depende de la definición elegida.
write.csv(
  membership_changes,
  file.path(output_path, "dres_robustness_membership_changes.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar la auditoría de llaves producto-año duplicadas.
write.csv(
  duplicate_audit,
  file.path(output_path, "dres_duplicate_product_year_audit.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar cualquier mezcla del agregado 3340 con sus subproductos 3341 a 3345.
write.csv(
  mixed_level_audit,
  file.path(output_path, "dres_mixed_product_level_audit.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar cada corrección comercial negativa con su clasificación SITC.
write.csv(
  negative_audit,
  file.path(output_path, "dres_negative_values_audit.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar las observaciones Atlas y WDI utilizadas en la validación concurrente.
write.csv(
  validation_panel,
  file.path(output_path, "dres_atlas_wdi_validation_panel.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar las estadísticas de correlación y error frente a WDI.
write.csv(
  validation_summary,
  file.path(output_path, "dres_atlas_wdi_validation_summary.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar el catálogo comparado de productos de todas las definiciones.
write.csv(
  scope_audit,
  file.path(output_path, "dres_product_scope_robustness.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar el resumen compacto de controles y tamaños de muestra.
write.csv(
  quality_summary,
  file.path(output_path, "dres_robustness_quality_summary.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Informar en la consola que la auditoría terminó correctamente.
message("Auditoría de robustez de DRES terminada.")
# Mostrar la carpeta donde quedaron las salidas para facilitar su localización.
message("Resultados: ", output_path)
# Mostrar el número de países de la definición principal al 20 %.
message("Muestra principal 20 %: ", sum(robustness_profile$sample_baseline_20), " países.")
# Mostrar el número de países después de la corrección conceptual mínima.
message(
  "Muestra corregida 20 %: ",
  sum(robustness_profile$sample_corrected_20, na.rm = TRUE),
  " países."
)
# Mostrar el número de países de la definición estrictamente aguas arriba.
message(
  "Muestra aguas arriba 20 %: ",
  sum(robustness_profile$sample_upstream_20, na.rm = TRUE),
  " países."
)
