# CAPA: PROCESSED
# VARIABLE: DRES
# ENTRADAS: data/raw/atlas/ y data/raw/dres/
# SALIDAS: data/processed/dres/
# Construir DRES y seleccionar la muestra de países dependientes de recursos del subsuelo.
#
# Entradas: exportaciones Atlas SITC Rev. 2, catálogo de productos y población WDI.
# Salidas: panel país-año, promedio 1990-1995 y muestra DRES única de 20 %.

# Reunir las ubicaciones desde las cuales puede encontrarse el helper de rutas del proyecto.
helper_path <- c(
  # Buscar el helper desde la ubicación del archivo activo cuando se usa RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)))), "project_paths.R")
  },
  # Buscar el helper cuando la consola está ubicada en la raíz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Buscar el helper cuando la consola está ubicada en scripts/data/processed/dres/.
  file.path("..", "..", "..", "project_paths.R"),
  # Buscar el helper cuando la consola está ubicada en scripts/.
  file.path("..", "project_paths.R"),
  # Buscar el helper en el directorio de trabajo actual como última alternativa.
  "project_paths.R"
)

# Conservar la primera ruta candidata que exista realmente en el equipo.
helper_path <- helper_path[file.exists(helper_path)][1]
# Detener el script si no fue posible localizar el helper de rutas.
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}

# Ejecutar el helper para habilitar la función que encuentra la raíz del repositorio.
source(helper_path)
# Obtener la ruta absoluta del proyecto sin depender del directorio abierto en RStudio.
project_path <- find_project_path()

# Definir el periodo anterior a la estimación utilizado para clasificar los países.
base_years <- 1990:1995
# Definir el único umbral de selección utilizado por el modelo.
sample_threshold <- 0.20
# Registrar los conteos validados para detectar cambios inesperados en los insumos.
expected_sample_count <- 55L

# Relacionar cada familia SITC con el tipo de recurso no renovable que representa.
resource_groups <- data.frame(
  # Usar expresiones que identifican el inicio de los códigos SITC incluidos.
  code_pattern = c("^3", "^27", "^28", "^68", "^667", "^971"),
  # Asignar una etiqueta comprensible a cada familia de productos extractivos.
  resource_group = c(
    "mineral_fuels",
    "crude_minerals",
    "metalliferous_ores",
    "nonferrous_metals",
    "precious_stones",
    "nonmonetary_gold"
  ),
  # Evitar que R convierta automáticamente los textos en categorías numéricas.
  stringsAsFactors = FALSE
)

# Enumerar productos que pertenecen a grupos amplios, pero no provienen del subsuelo.
excluded_non_subsoil_codes <- c(
  "2711", # Fertilizantes crudos de origen animal o vegetal.
  "2786", # Escorias y residuos industriales, que no representan extracción directa.
  "2820", # Desperdicios y chatarra de hierro o acero.
  "2881", # Cenizas y residuos de metales comunes.
  "2882", # Desperdicios y chatarra de metales no ferrosos.
  "3510", # Electricidad, que no es un recurso natural del subsuelo.
  "6671", # Perlas naturales, que tienen origen biológico.
  "6674"  # Piedras preciosas sintéticas o reconstruidas.
)

# Enumerar territorios, áreas especiales, agregados y entidades fuera del ámbito nacional.
excluded_country_scope <- c(
  # Excluir territorios dependientes de Estados Unidos.
  ASM = "Territorio no soberano",
  GUM = "Territorio no soberano",
  MNP = "Territorio no soberano",
  # Excluir territorios británicos de ultramar y dependencias asociadas.
  AIA = "Territorio no soberano",
  BMU = "Territorio no soberano",
  VGB = "Territorio no soberano",
  CYM = "Territorio no soberano",
  FLK = "Territorio no soberano",
  GIB = "Territorio no soberano",
  MSR = "Territorio no soberano",
  PCN = "Territorio no soberano",
  SHN = "Territorio no soberano",
  SGS = "Territorio no soberano",
  TCA = "Territorio no soberano",
  # Excluir territorios y colectividades francesas.
  BLM = "Territorio no soberano",
  PYF = "Territorio no soberano",
  ATF = "Territorio no soberano",
  NCL = "Territorio no soberano",
  SPM = "Territorio no soberano",
  # Excluir territorios y antiguas entidades del Reino de los Países Bajos.
  ABW = "Territorio no soberano",
  BES = "Territorio no soberano",
  CUW = "Territorio no soberano",
  SXM = "Territorio no soberano",
  ANT = "Entidad histórica disuelta",
  # Excluir regiones administrativas especiales de China.
  HKG = "Región administrativa especial",
  MAC = "Región administrativa especial",
  # Excluir territorios externos de Australia.
  ATA = "Área sin soberanía nacional propia",
  BVT = "Territorio no soberano",
  CXR = "Territorio no soberano",
  CCK = "Territorio no soberano",
  HMD = "Territorio no soberano",
  NFK = "Territorio no soberano",
  # Excluir territorios autónomos o asociados que no forman parte del universo nacional adoptado.
  COK = "Estado asociado fuera del ámbito adoptado",
  FRO = "Territorio autónomo no soberano",
  GRL = "Territorio autónomo no soberano",
  NIU = "Estado asociado fuera del ámbito adoptado",
  TKL = "Territorio no soberano",
  # Excluir códigos sin una economía nacional identificable.
  ANS = "Comercio sin país declarado",
  USP = "Socios de servicios no identificados"
)

# Construir la carpeta que contiene los archivos comerciales descargados del Atlas.
atlas_path <- file.path(project_path, "data", "raw", "atlas", "sitc_rev2_trade")
# Construir la carpeta que contiene un archivo de exportaciones por economía.
country_files_path <- file.path(atlas_path, "country_exports")
# Localizar el catálogo que relaciona identificadores internos con códigos SITC.
product_catalog_file <- file.path(atlas_path, "atlas_sitc4_product_catalog.csv")
# Localizar el catálogo geográfico que relaciona códigos y nombres de economías.
country_catalog_file <- file.path(atlas_path, "atlas_country_catalog.csv")
# Localizar la población WDI que se conservará únicamente como diagnóstico descriptivo.
population_file <- file.path(
  project_path,
  "data",
  "raw",
  "dres",
  "world_bank_wdi",
  "dres_wdi_inputs_1990_1995.csv"
)
# Construir la carpeta donde se guardarán los resultados procesados de DRES.
processed_path <- file.path(project_path, "data", "processed", "dres")

# Reunir los archivos indispensables para comprobarlos antes de iniciar el procesamiento.
required_files <- c(product_catalog_file, country_catalog_file, population_file)
# Identificar cualquier archivo requerido que no exista en el repositorio.
missing_files <- required_files[!file.exists(required_files)]
# Interrumpir la ejecución si falta algún insumo que impida reproducir la selección.
if (length(missing_files) > 0L) {
  stop("Faltan archivos requeridos: ", paste(missing_files, collapse = ", "))
}
# Interrumpir la ejecución si no existe la carpeta con exportaciones por país.
if (!dir.exists(country_files_path)) {
  stop("No existe la carpeta de exportaciones Atlas por país: ", country_files_path)
}

# Crear la carpeta de resultados y sus directorios padres si todavía no existen.
dir.create(processed_path, recursive = TRUE, showWarnings = FALSE)

# Enumerar las salidas oficiales que el script reemplazará al terminar.
official_output_files <- file.path(processed_path, c(
  "dres_country_year_1990_1995.csv",
  "dres_country_profile_1990_1995.csv",
  "dres_sitc_product_scope.csv",
  "dres_trade_product_classification.csv",
  "dres_sample_20.csv",
  "dres_selection_summary.csv"
))
# Comprobar antes del cálculo que ningún resultado existente esté abierto en Excel.
for (output_file in official_output_files[file.exists(official_output_files)]) {
  # Intentar abrir y cerrar el archivo sin escribir contenido nuevo.
  output_connection <- try(file(output_file, open = "a"), silent = TRUE)
  # Detener la ejecución antes de producir salidas parciales cuando el archivo esté bloqueado.
  if (inherits(output_connection, "try-error")) {
    stop("Cierre el archivo antes de ejecutar el script: ", output_file)
  }
  # Cerrar inmediatamente la conexión utilizada para comprobar disponibilidad.
  close(output_connection)
}

# Leer el catálogo SITC como texto para conservar ceros iniciales en los códigos.
product_catalog <- read.csv(
  product_catalog_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
# Definir las columnas que deben estar presentes para interpretar cada producto.
required_product_columns <- c("code", "nameEn", "productId")
# Identificar columnas ausentes por un posible cambio en la estructura del Atlas.
missing_product_columns <- setdiff(required_product_columns, names(product_catalog))
# Detener el script si el catálogo no contiene la información mínima requerida.
if (length(missing_product_columns) > 0L) {
  stop("Faltan columnas en el catálogo SITC: ", paste(missing_product_columns, collapse = ", "))
}
# Detener el script si el catálogo repite un identificador interno de producto.
if (anyDuplicated(product_catalog$productId) > 0L) {
  stop("El catálogo SITC contiene identificadores de producto duplicados.")
}

# Crear una columna inicialmente vacía para clasificar los productos extractivos.
product_catalog$resource_group <- NA_character_
# Recorrer las seis familias SITC adoptadas en la definición de DRES.
for (index in seq_len(nrow(resource_groups))) {
  # Identificar productos cuyo código comienza con el patrón de la familia actual.
  selected_products <- grepl(resource_groups$code_pattern[index], product_catalog$code)
  # Registrar el nombre de la familia solamente en los productos seleccionados.
  product_catalog$resource_group[selected_products] <- resource_groups$resource_group[index]
}

# Retirar del numerador los productos biológicos o sintéticos identificados arriba.
product_catalog$resource_group[
  product_catalog$code %in% excluded_non_subsoil_codes
] <- NA_character_

# Identificar mercancías clasificadas mediante códigos SITC de cuatro dígitos.
product_catalog$is_classified_merchandise <- grepl("^[0-9]{4}$", product_catalog$code)
# Identificar la categoría de mercancías cuyo producto no pudo clasificarse.
product_catalog$is_unclassified_merchandise <- product_catalog$code == "XXXX"
# Definir el universo de mercancías utilizado como denominador de DRES.
product_catalog$is_merchandise <- product_catalog$is_classified_merchandise |
  product_catalog$is_unclassified_merchandise
# Identificar las categorías de servicios que deben quedar fuera del denominador.
product_catalog$is_service <- product_catalog$code %in% c(
  "financial",
  "ict",
  "transport",
  "travel",
  "unspecified"
)
# Detectar categorías que no sean mercancías ni servicios conocidos del Atlas.
unknown_trade_categories <- !product_catalog$is_merchandise & !product_catalog$is_service
# Detener el script si la fuente incorpora una categoría que todavía no fue clasificada.
if (any(unknown_trade_categories)) {
  stop(
    "El catálogo contiene categorías comerciales sin clasificar: ",
    paste(product_catalog$code[unknown_trade_categories], collapse = ", ")
  )
}
# Confirmar que la categoría conservadora de mercancías no clasificadas esté disponible.
if (!any(product_catalog$is_unclassified_merchandise)) {
  stop("El catálogo no contiene la categoría XXXX de mercancías no clasificadas.")
}
# Impedir que una categoría de servicios forme parte accidentalmente del numerador.
if (any(!is.na(product_catalog$resource_group) & !product_catalog$is_merchandise)) {
  stop("Una categoría no mercantil fue incorporada al numerador de DRES.")
}

# Conservar el subconjunto exacto de productos que integrará el numerador de DRES.
extractive_product_catalog <- product_catalog[!is.na(product_catalog$resource_group), ]
# Confirmar que el catálogo contiene oro no monetario, incorporado mediante SITC 971.
if (!any(grepl("^971", extractive_product_catalog$code))) {
  stop("El catálogo no contiene productos SITC 971 de oro no monetario.")
}
# Confirmar que el catálogo contiene diamantes y piedras naturales SITC 6672 y 6673.
if (!all(c("6672", "6673") %in% extractive_product_catalog$code)) {
  stop("El catálogo no contiene los productos SITC 6672 y 6673 esperados.")
}

# Leer el catálogo geográfico para recuperar nombres consistentes de los países.
country_catalog <- read.csv(
  country_catalog_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
# Definir las columnas geográficas necesarias para identificar cada economía.
required_country_columns <- c("iso3Code", "nameEn")
# Identificar columnas geográficas ausentes por cambios en el archivo original.
missing_country_columns <- setdiff(required_country_columns, names(country_catalog))
# Detener el script si no es posible relacionar códigos ISO3 con nombres de países.
if (length(missing_country_columns) > 0L) {
  stop("Faltan columnas en el catálogo de países: ", paste(missing_country_columns, collapse = ", "))
}
# Detener el script si un mismo código ISO3 aparece más de una vez en el catálogo.
if (anyDuplicated(country_catalog$iso3Code) > 0L) {
  stop("El catálogo de países contiene códigos ISO3 duplicados.")
}

# Obtener la lista ordenada de archivos CSV descargados por economía.
country_files <- sort(list.files(country_files_path, pattern = "\\.csv$", full.names = TRUE))
# Detener el script si la carpeta existe pero no contiene archivos comerciales.
if (length(country_files) == 0L) {
  stop("No se encontraron archivos CSV de exportaciones por país.")
}

# Definir una función que resume las exportaciones de una economía durante 1990-1995.
process_country_file <- function(country_file) {
  # Obtener el código ISO3 a partir del nombre asignado al archivo por el descargador.
  country_iso3_code <- tools::file_path_sans_ext(basename(country_file))
  # Recuperar el nombre de la economía desde el catálogo geográfico del Atlas.
  country_name <- country_catalog$nameEn[match(country_iso3_code, country_catalog$iso3Code)]
  # Detener el script si el archivo no puede vincularse con una economía del catálogo.
  if (is.na(country_name)) {
    stop("El archivo no aparece en el catálogo de países: ", country_file)
  }

  # Leer las observaciones comerciales como texto para controlar cada conversión.
  country_data <- read.csv(
    country_file,
    colClasses = "character",
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fileEncoding = "UTF-8"
  )
  # Definir las columnas mínimas para identificar año, producto y valor exportado.
  required_trade_columns <- c("year", "product_id", "export_value_usd")
  # Identificar columnas comerciales ausentes en el archivo de la economía actual.
  missing_trade_columns <- setdiff(required_trade_columns, names(country_data))
  # Detener el script si el archivo no conserva la estructura entregada por Atlas.
  if (length(missing_trade_columns) > 0L) {
    stop("Faltan columnas comerciales en ", country_file, ": ", paste(missing_trade_columns, collapse = ", "))
  }

  # Convertir el año a entero para seleccionar con precisión el periodo base.
  country_data$year <- suppressWarnings(as.integer(country_data$year))
  # Convertir el valor exportado a número para poder sumar productos.
  country_data$export_value_usd <- suppressWarnings(as.numeric(country_data$export_value_usd))
  # Detener el script si una observación del periodo no tiene año o valor interpretable.
  invalid_trade_values <- is.na(country_data$year) | is.na(country_data$export_value_usd)
  # Exigir valores válidos para evitar que las sumas oculten errores de lectura.
  if (any(invalid_trade_values)) {
    stop("El archivo contiene años o valores no numéricos: ", country_file)
  }

  # Conservar solamente los seis años utilizados para calcular el promedio de DRES.
  country_data <- country_data[country_data$year %in% base_years, , drop = FALSE]
  # Vincular cada identificador interno con su código SITC de cuatro dígitos.
  product_match <- match(country_data$product_id, product_catalog$productId)
  # Detener el script si aparece un producto que no puede clasificarse mediante el catálogo.
  if (any(is.na(product_match))) {
    stop("Hay productos sin código SITC en el archivo: ", country_file)
  }
  # Incorporar el código SITC necesario para aplicar la definición extractiva.
  country_data$sitc_code <- product_catalog$code[product_match]
  # Incorporar la familia de recurso; los productos no extractivos permanecen vacíos.
  country_data$resource_group <- product_catalog$resource_group[product_match]
  # Identificar las mercancías clasificadas mediante códigos SITC numéricos.
  country_data$is_classified_merchandise <-
    product_catalog$is_classified_merchandise[product_match]
  # Identificar las mercancías sin producto clasificado registradas como XXXX.
  country_data$is_unclassified_merchandise <-
    product_catalog$is_unclassified_merchandise[product_match]
  # Identificar todas las mercancías que integrarán el denominador de DRES.
  country_data$is_merchandise <- product_catalog$is_merchandise[product_match]
  # Identificar los servicios que se excluirán expresamente del denominador.
  country_data$is_service <- product_catalog$is_service[product_match]
  # Construir la llave producto-año utilizada para comprobar unicidad dentro del país.
  product_year_key <- country_data[c("year", "product_id")]
  # Detener el script si un mismo producto aparece repetido en el mismo país y año.
  if (anyDuplicated(product_year_key) > 0L) {
    stop("El archivo contiene llaves producto-año duplicadas: ", country_file)
  }
  # Identificar correcciones negativas conservadas originalmente en la capa raw.
  country_data$negative_correction <- country_data$export_value_usd < 0
  # Reemplazar por cero las correcciones negativas únicamente para realizar agregaciones.
  country_data$processed_export_value_usd <- pmax(country_data$export_value_usd, 0)

  # Crear seis filas vacías para garantizar una observación por año del periodo base.
  annual_result <- data.frame(
    country_iso3_code = rep(country_iso3_code, length(base_years)),
    country = rep(country_name, length(base_years)),
    year = as.integer(base_years),
    total_exports_usd = 0,
    classified_merchandise_exports_usd = 0,
    unclassified_merchandise_exports_usd = 0,
    services_exports_excluded_usd = 0,
    extractive_exports_usd = 0,
    mineral_fuels_usd = 0,
    crude_minerals_usd = 0,
    metalliferous_ores_usd = 0,
    nonferrous_metals_usd = 0,
    precious_stones_usd = 0,
    nonmonetary_gold_usd = 0,
    product_count = 0L,
    service_product_count = 0L,
    negative_rows_corrected = 0L,
    negative_service_rows_excluded = 0L,
    stringsAsFactors = FALSE
  )

  # Recorrer cada año para sumar productos sin crear un archivo comercial consolidado.
  for (year_value in base_years) {
    # Seleccionar las observaciones comerciales de la economía en el año actual.
    annual_data <- country_data[country_data$year == year_value, , drop = FALSE]
    # Localizar la fila donde se guardará el resumen del año actual.
    result_row <- which(annual_result$year == year_value)
    # Identificar las mercancías clasificadas o no clasificadas del año actual.
    merchandise_rows <- annual_data$is_merchandise
    # Sumar únicamente mercancías para construir el denominador correcto de DRES.
    annual_result$total_exports_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[merchandise_rows]
    )
    # Sumar las mercancías que poseen un código SITC de cuatro dígitos.
    annual_result$classified_merchandise_exports_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$is_classified_merchandise]
    )
    # Sumar por separado las mercancías sin producto clasificado registradas como XXXX.
    annual_result$unclassified_merchandise_exports_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$is_unclassified_merchandise]
    )
    # Cuantificar los servicios retirados para que la corrección sea auditable.
    annual_result$services_exports_excluded_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$is_service]
    )
    # Identificar los productos pertenecientes a cualquiera de las seis familias extractivas.
    extractive_rows <- !is.na(annual_data$resource_group) & merchandise_rows
    # Sumar las exportaciones extractivas para construir el numerador de DRES.
    annual_result$extractive_exports_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[extractive_rows]
    )
    # Sumar por separado combustibles minerales para facilitar la auditoría del numerador.
    annual_result$mineral_fuels_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$resource_group == "mineral_fuels"],
      na.rm = TRUE
    )
    # Sumar por separado minerales crudos incluidos en la división SITC 27.
    annual_result$crude_minerals_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$resource_group == "crude_minerals"],
      na.rm = TRUE
    )
    # Sumar por separado minerales metalíferos incluidos en la división SITC 28.
    annual_result$metalliferous_ores_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$resource_group == "metalliferous_ores"],
      na.rm = TRUE
    )
    # Sumar por separado metales no ferrosos incluidos en la división SITC 68.
    annual_result$nonferrous_metals_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$resource_group == "nonferrous_metals"],
      na.rm = TRUE
    )
    # Sumar piedras preciosas y diamantes no industriales de la división SITC 667.
    annual_result$precious_stones_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$resource_group == "precious_stones"],
      na.rm = TRUE
    )
    # Sumar el oro no monetario identificado mediante el código SITC 971.
    annual_result$nonmonetary_gold_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$resource_group == "nonmonetary_gold"],
      na.rm = TRUE
    )
    # Contar mercancías distintas para documentar la cobertura comercial de cada año.
    annual_result$product_count[result_row] <- length(unique(
      annual_data$product_id[merchandise_rows]
    ))
    # Contar servicios distintos para documentar qué registros fueron retirados.
    annual_result$service_product_count[result_row] <- length(unique(
      annual_data$product_id[annual_data$is_service]
    ))
    # Contar las correcciones negativas de mercancías transformadas a cero.
    annual_result$negative_rows_corrected[result_row] <- sum(
      annual_data$negative_correction & merchandise_rows
    )
    # Contar correcciones negativas pertenecientes a servicios ya excluidos.
    annual_result$negative_service_rows_excluded[result_row] <- sum(
      annual_data$negative_correction & annual_data$is_service
    )
  }

  # Calcular DRES solo cuando las exportaciones totales del año son positivas.
  annual_result$dres <- ifelse(
    annual_result$total_exports_usd > 0,
    annual_result$extractive_exports_usd / annual_result$total_exports_usd,
    NA_real_
  )
  # Devolver las seis observaciones anuales de la economía procesada.
  annual_result
}

# Procesar los archivos uno por uno para evitar cargar 300 MB de comercio simultáneamente.
country_year_parts <- lapply(country_files, process_country_file)
# Apilar los resúmenes pequeños en un panel país-año de 1990 a 1995.
dres_country_year <- do.call(rbind, country_year_parts)
# Eliminar números de fila heredados para mantener identificadores limpios.
row.names(dres_country_year) <- NULL
# Ordenar el panel por código de país y año para facilitar su revisión.
dres_country_year <- dres_country_year[
  order(dres_country_year$country_iso3_code, dres_country_year$year),
]

# Detener el script si una llave país-año aparece más de una vez.
if (anyDuplicated(dres_country_year[c("country_iso3_code", "year")]) > 0L) {
  stop("El panel DRES contiene llaves país-año duplicadas.")
}
# Reconstruir el denominador como suma de mercancías clasificadas y no clasificadas.
reconstructed_denominator <-
  dres_country_year$classified_merchandise_exports_usd +
  dres_country_year$unclassified_merchandise_exports_usd
# Definir una tolerancia proporcional para comparar valores monetarios de distinta escala.
denominator_tolerance <- pmax(1, dres_country_year$total_exports_usd) * 1e-10
# Detener el script si alguna observación no permite reconstruir exactamente el denominador.
if (any(abs(dres_country_year$total_exports_usd - reconstructed_denominator) >
  denominator_tolerance)) {
  stop("El denominador no coincide con la suma de mercancías clasificadas y XXXX.")
}
# Reconstruir el numerador mediante la suma de sus seis componentes extractivos.
reconstructed_numerator <- rowSums(dres_country_year[c(
  "mineral_fuels_usd",
  "crude_minerals_usd",
  "metalliferous_ores_usd",
  "nonferrous_metals_usd",
  "precious_stones_usd",
  "nonmonetary_gold_usd"
)])
# Definir una tolerancia proporcional para verificar el numerador extractivo.
numerator_tolerance <- pmax(1, dres_country_year$extractive_exports_usd) * 1e-10
# Detener el script si los componentes no reproducen el numerador total.
if (any(abs(dres_country_year$extractive_exports_usd - reconstructed_numerator) >
  numerator_tolerance)) {
  stop("Los componentes extractivos no coinciden con el numerador total de DRES.")
}
# Impedir que el numerador extractivo sea mayor que las exportaciones de mercancías.
if (any(dres_country_year$extractive_exports_usd >
  dres_country_year$total_exports_usd + denominator_tolerance)) {
  stop("El numerador extractivo supera el denominador de mercancías.")
}
# Identificar valores de DRES fuera del intervalo lógico entre cero y uno.
invalid_dres <- !is.na(dres_country_year$dres) &
  (dres_country_year$dres < 0 | dres_country_year$dres > 1)
# Detener el script si el numerador extractivo genera una participación inválida.
if (any(invalid_dres)) {
  stop("Se encontraron valores de DRES fuera del intervalo [0, 1].")
}

# Dividir el panel en grupos para resumir separadamente cada economía.
country_year_groups <- split(dres_country_year, dres_country_year$country_iso3_code)
# Construir una fila nacional con cobertura, promedio DRES y exportaciones medias.
dres_country_profile <- do.call(rbind, lapply(country_year_groups, function(country_data) {
  # Contar los años con mercancías positivas y, por tanto, con DRES calculable.
  complete_merchandise_years <- sum(!is.na(country_data$dres))
  # Calcular el promedio solo si existen observaciones para los seis años requeridos.
  dres_base_mean <- if (complete_merchandise_years == length(base_years)) {
    mean(country_data$dres)
  } else {
    NA_real_
  }
  # Promediar las exportaciones anuales únicamente como diagnóstico descriptivo.
  exports_base_mean_usd <- if (complete_merchandise_years == length(base_years)) {
    mean(country_data$total_exports_usd)
  } else {
    NA_real_
  }
  # Devolver el resumen nacional que después recibirá las banderas de muestra.
  data.frame(
    country_iso3_code = country_data$country_iso3_code[1],
    country = country_data$country[1],
    complete_merchandise_years = complete_merchandise_years,
    dres_base_mean = dres_base_mean,
    dres_base_mean_percent = 100 * dres_base_mean,
    exports_base_mean_usd = exports_base_mean_usd,
    negative_rows_corrected = sum(country_data$negative_rows_corrected),
    negative_service_rows_excluded = sum(country_data$negative_service_rows_excluded),
    services_exports_excluded_usd = sum(country_data$services_exports_excluded_usd),
    unclassified_merchandise_share = if (sum(country_data$total_exports_usd) > 0) {
      sum(country_data$unclassified_merchandise_exports_usd) /
        sum(country_data$total_exports_usd)
    } else {
      NA_real_
    },
    stringsAsFactors = FALSE
  )
}))
# Eliminar números de fila heredados del agrupamiento por país.
row.names(dres_country_profile) <- NULL

# Leer la población WDI para conservar el antiguo filtro como diagnóstico, no como exclusión.
population_data <- read.csv(
  population_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
# Convertir la población a número para calcular su promedio durante el periodo base.
population_data$population_total <- suppressWarnings(as.numeric(population_data$population_total))
# Conservar observaciones con población válida antes de agruparlas por país.
population_valid <- population_data[!is.na(population_data$population_total), ]
# Calcular la población media de 1990-1995 para cada código disponible en WDI.
population_mean <- aggregate(
  population_total ~ country_iso3_code,
  data = population_valid,
  FUN = mean
)
# Cambiar el nombre de la columna para dejar explícito el periodo resumido.
names(population_mean)[names(population_mean) == "population_total"] <- "population_base_mean"
# Incorporar la población media mediante una unión que no elimine economías de Atlas.
dres_country_profile$population_base_mean <- population_mean$population_base_mean[
  match(dres_country_profile$country_iso3_code, population_mean$country_iso3_code)
]

# Identificar países incluidos en el ámbito nacional definido para la tesis.
dres_country_profile$is_country_scope <- !dres_country_profile$country_iso3_code %in%
  names(excluded_country_scope)
# Incorporar la razón de exclusión para que cada decisión territorial sea auditable.
dres_country_profile$scope_exclusion_reason <- unname(
  excluded_country_scope[dres_country_profile$country_iso3_code]
)
# Reemplazar razones faltantes por texto vacío en los países incluidos.
dres_country_profile$scope_exclusion_reason[
  is.na(dres_country_profile$scope_exclusion_reason)
] <- ""
# Identificar países con los seis años de mercancías positivas requeridos para el promedio.
dres_country_profile$has_complete_base_merchandise <-
  dres_country_profile$complete_merchandise_years == length(base_years)
# Definir el universo elegible utilizando únicamente ámbito nacional y mercancías completas.
dres_country_profile$eligible_for_dres <-
  dres_country_profile$is_country_scope &
  dres_country_profile$has_complete_base_merchandise
# Conservar el antiguo umbral poblacional exclusivamente como diagnóstico descriptivo.
dres_country_profile$population_ge_1m_diagnostic <-
  !is.na(dres_country_profile$population_base_mean) &
  dres_country_profile$population_base_mean >= 1000000
# Conservar el antiguo umbral comercial exclusivamente como diagnóstico descriptivo.
dres_country_profile$exports_gt_1bn_diagnostic <-
  !is.na(dres_country_profile$exports_base_mean_usd) &
  dres_country_profile$exports_base_mean_usd > 1000000000

# Crear la muestra principal de países cuyo promedio DRES alcanza al menos 20 %.
dres_country_profile$sample_dres20 <-
  dres_country_profile$eligible_for_dres &
  !is.na(dres_country_profile$dres_base_mean) &
  dres_country_profile$dres_base_mean >= sample_threshold
# Ordenar el perfil para facilitar búsquedas por código ISO3.
dres_country_profile <- dres_country_profile[order(dres_country_profile$country_iso3_code), ]
# Eliminar números de fila heredados después del ordenamiento.
row.names(dres_country_profile) <- NULL

# Impedir que una economía excluida territorialmente aparezca en la muestra.
if (any(!dres_country_profile$is_country_scope & dres_country_profile$sample_dres20)) {
  stop("Una economía fuera del ámbito nacional fue incluida en una muestra DRES.")
}

# Definir una función que prepara una lista legible para un umbral específico.
build_sample_table <- function(sample_flag, threshold_value) {
  # Conservar solamente países cuya bandera corresponde al umbral solicitado.
  sample_table <- dres_country_profile[dres_country_profile[[sample_flag]], ]
  # Ordenar los países desde la dependencia extractiva más alta hasta la más baja.
  sample_table <- sample_table[order(-sample_table$dres_base_mean, sample_table$country_iso3_code), ]
  # Agregar el umbral para que el archivo pueda interpretarse de manera independiente.
  sample_table$sample_threshold <- threshold_value
  # Conservar las columnas necesarias para identificar y auditar la selección.
  sample_table[, c(
    "country_iso3_code",
    "country",
    "dres_base_mean",
    "dres_base_mean_percent",
    "complete_merchandise_years",
    "sample_threshold"
  )]
}

# Preparar la lista correspondiente al umbral principal de 20 %.
sample_dres20 <- build_sample_table("sample_dres20", sample_threshold)

# Obtener el conteo para compararlo con la selección validada.
actual_sample_count <- nrow(sample_dres20)
# Detener el script si la fuente o las reglas producen conteos distintos sin revisión previa.
if (!identical(actual_sample_count, expected_sample_count)) {
  stop(
    "El conteo DRES cambió. Esperado: ",
    expected_sample_count,
    "; obtenido: ",
    actual_sample_count,
    ". Revise los insumos antes de reemplazar las muestras."
  )
}

# Construir un resumen compacto con los conteos y validaciones principales.
dres_summary <- data.frame(
  # Nombrar cada resultado para que pueda citarse sin interpretar posiciones de fila.
  metric = c(
    "atlas_country_files",
    "countries_with_six_positive_merchandise_years",
    "eligible_countries_after_scope_and_coverage",
    "sample_dres20_countries",
    "negative_merchandise_rows_corrected_1990_1995",
    "negative_service_rows_excluded_1990_1995",
    "service_categories_excluded",
    "unclassified_merchandise_categories_in_denominator",
    "extractive_sitc4_products"
  ),
  # Registrar el valor calculado directamente desde los archivos procesados.
  value = c(
    length(country_files),
    sum(dres_country_profile$has_complete_base_merchandise),
    sum(dres_country_profile$eligible_for_dres),
    nrow(sample_dres20),
    sum(dres_country_profile$negative_rows_corrected),
    sum(dres_country_profile$negative_service_rows_excluded),
    sum(product_catalog$is_service),
    sum(product_catalog$is_unclassified_merchandise),
    nrow(extractive_product_catalog)
  ),
  # Mantener los nombres como texto simple para exportarlos sin códigos internos.
  stringsAsFactors = FALSE
)

# Guardar el panel anual utilizado para calcular el promedio de cada país.
write.csv(
  dres_country_year,
  file.path(processed_path, "dres_country_year_1990_1995.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar el perfil completo con cobertura, bandera de muestra y diagnósticos.
write.csv(
  dres_country_profile,
  file.path(processed_path, "dres_country_profile_1990_1995.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar el catálogo exacto de productos incorporados al numerador de DRES.
write.csv(
  extractive_product_catalog,
  file.path(processed_path, "dres_sitc_product_scope.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar la clasificación completa que distingue mercancías, servicios y numerador.
write.csv(
  product_catalog[, c(
    "productId",
    "code",
    "nameEn",
    "is_classified_merchandise",
    "is_unclassified_merchandise",
    "is_merchandise",
    "is_service",
    "resource_group"
  )],
  file.path(processed_path, "dres_trade_product_classification.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar la lista principal de países dependientes según el umbral de 20 %.
write.csv(
  sample_dres20,
  file.path(processed_path, "dres_sample_20.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar el resumen que alimentará las cifras del diagrama metodológico.
write.csv(
  dres_summary,
  file.path(processed_path, "dres_selection_summary.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Informar que el procesamiento terminó después de superar todas las validaciones.
message("Construcción de DRES terminada.")
# Mostrar la carpeta donde quedaron las salidas procesadas.
message("Resultados: ", processed_path)
# Mostrar el tamaño de la muestra única de 20 %.
message("Muestra DRES 20 %: ", nrow(sample_dres20), " países.")
