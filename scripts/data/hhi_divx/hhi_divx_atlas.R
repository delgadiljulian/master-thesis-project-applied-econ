# Construir HHI y DIVX para la muestra principal de países seleccionada mediante DRES.
#
# Entradas: muestra DRES de 20 %, exportaciones Atlas SITC Rev. 2 y catálogo de productos.
# Salidas: panel país-año de HHI y DIVX, cobertura por país y resumen de validación.

# Reunir las ubicaciones desde las cuales puede encontrarse el helper de rutas del proyecto.
helper_path <- c(
  # Buscar el helper desde la ubicación del archivo activo cuando se usa RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path))), "project_paths.R")
  },
  # Buscar el helper cuando la consola está ubicada en la raíz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Buscar el helper cuando la consola está ubicada en scripts/data/hhi_divx/.
  file.path("..", "..", "project_paths.R"),
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

# Definir el periodo completo disponible en la descarga comercial del Atlas.
analysis_years <- 1990:2022
# Registrar el tamaño validado de la muestra principal DRES.
expected_country_count <- 55L
# Definir los códigos de las cinco categorías de servicios que no son mercancías.
service_codes <- c("financial", "ict", "transport", "travel", "unspecified")

# Construir la ruta del insumo comercial compartido por varias variables de la tesis.
atlas_path <- file.path(project_path, "data", "raw", "atlas", "sitc_rev2_trade")
# Construir la ruta de los archivos de exportaciones separados por economía.
country_files_path <- file.path(atlas_path, "country_exports")
# Localizar el catálogo que relaciona identificadores internos con códigos SITC.
product_catalog_file <- file.path(atlas_path, "atlas_sitc4_product_catalog.csv")
# Localizar la lista oficial de países seleccionados con el umbral DRES de 20 %.
sample_file <- file.path(project_path, "data", "processed", "dres", "dres_sample_20.csv")
# Construir la carpeta destinada a los resultados procesados de HHI y DIVX.
processed_path <- file.path(project_path, "data", "processed", "hhi_divx")

# Reunir los insumos indispensables para comprobarlos antes de procesar datos.
required_files <- c(product_catalog_file, sample_file)
# Identificar cualquier insumo requerido que no exista en el repositorio.
missing_files <- required_files[!file.exists(required_files)]
# Interrumpir la ejecución si falta un archivo necesario para reproducir el cálculo.
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
  "hhi_divx_country_year_1990_2022.csv",
  "hhi_divx_country_coverage_1990_2022.csv",
  "hhi_divx_validation_summary.csv"
))
# Comprobar antes del cálculo que ningún resultado existente esté abierto en Excel.
for (output_file in official_output_files[file.exists(official_output_files)]) {
  # Intentar abrir y cerrar el archivo sin modificar su contenido.
  output_connection <- try(file(output_file, open = "a"), silent = TRUE)
  # Detener la ejecución antes de producir salidas parciales si el archivo está bloqueado.
  if (inherits(output_connection, "try-error")) {
    stop("Cierre el archivo antes de ejecutar el script: ", output_file)
  }
  # Cerrar inmediatamente la conexión utilizada para comprobar disponibilidad.
  close(output_connection)
}

# Leer la muestra DRES como texto para conservar exactamente los códigos de país.
dres_sample <- read.csv(
  sample_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
# Definir las columnas necesarias para identificar cada país seleccionado.
required_sample_columns <- c("country_iso3_code", "country")
# Identificar columnas ausentes por un posible cambio en la salida de DRES.
missing_sample_columns <- setdiff(required_sample_columns, names(dres_sample))
# Detener el script si la muestra no conserva la estructura esperada.
if (length(missing_sample_columns) > 0L) {
  stop("Faltan columnas en la muestra DRES: ", paste(missing_sample_columns, collapse = ", "))
}
# Detener el script si un mismo código de país aparece más de una vez.
if (anyDuplicated(dres_sample$country_iso3_code) > 0L) {
  stop("La muestra DRES contiene códigos de país duplicados.")
}
# Detener el script si la muestra principal cambió de tamaño sin revisión previa.
if (nrow(dres_sample) != expected_country_count) {
  stop(
    "La muestra DRES principal cambió. Se esperaban ", expected_country_count,
    " países y se encontraron ", nrow(dres_sample), "."
  )
}
# Ordenar los países por código para que el procesamiento sea determinista.
dres_sample <- dres_sample[order(dres_sample$country_iso3_code), ]
# Eliminar números de fila heredados después del ordenamiento.
row.names(dres_sample) <- NULL

# Leer el catálogo SITC como texto para conservar los ceros iniciales de los códigos.
product_catalog <- read.csv(
  product_catalog_file,
  colClasses = "character",
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
# Definir las columnas mínimas para identificar y describir cada producto.
required_product_columns <- c("code", "nameEn", "productId")
# Identificar columnas ausentes por un posible cambio en el catálogo del Atlas.
missing_product_columns <- setdiff(required_product_columns, names(product_catalog))
# Detener el script si el catálogo no contiene la información necesaria.
if (length(missing_product_columns) > 0L) {
  stop("Faltan columnas en el catálogo SITC: ", paste(missing_product_columns, collapse = ", "))
}
# Detener el script si un identificador interno aparece más de una vez.
if (anyDuplicated(product_catalog$productId) > 0L) {
  stop("El catálogo SITC contiene identificadores de producto duplicados.")
}

# Identificar mercancías clasificadas mediante códigos SITC de cuatro dígitos.
product_catalog$is_classified_merchandise <- grepl("^[0-9]{4}$", product_catalog$code)
# Identificar el residuo de mercancías que el Atlas no asigna a un producto SITC.
product_catalog$is_unclassified_merchandise <- product_catalog$code == "XXXX"
# Identificar las categorías de servicios que deben quedar fuera del cálculo.
product_catalog$is_service <- product_catalog$code %in% service_codes
# Detectar categorías que no correspondan a mercancías ni a servicios conocidos.
unknown_trade_categories <- !product_catalog$is_classified_merchandise &
  !product_catalog$is_unclassified_merchandise &
  !product_catalog$is_service
# Detener el script si la fuente incorpora una categoría que todavía no fue clasificada.
if (any(unknown_trade_categories)) {
  stop(
    "El catálogo contiene categorías comerciales sin clasificar: ",
    paste(product_catalog$code[unknown_trade_categories], collapse = ", ")
  )
}
# Confirmar que el residuo XXXX esté disponible para medir la cobertura de clasificación.
if (sum(product_catalog$is_unclassified_merchandise) != 1L) {
  stop("El catálogo debe contener una única categoría XXXX de discrepancias comerciales.")
}
# Confirmar que estén presentes exactamente las cinco categorías de servicios conocidas.
if (sum(product_catalog$is_service) != length(service_codes)) {
  stop("El catálogo no contiene las cinco categorías de servicios esperadas.")
}

# Construir la ruta esperada del archivo comercial de cada país seleccionado.
selected_country_files <- file.path(
  country_files_path,
  paste0(dres_sample$country_iso3_code, ".csv")
)
# Identificar países seleccionados cuyo archivo comercial no esté disponible.
missing_country_files <- selected_country_files[!file.exists(selected_country_files)]
# Detener el script si falta información comercial para un país de la muestra.
if (length(missing_country_files) > 0L) {
  stop("Faltan archivos comerciales: ", paste(missing_country_files, collapse = ", "))
}

# Definir una función que calcula HHI y DIVX para una economía entre 1990 y 2022.
process_country_file <- function(country_file) {
  # Obtener el código ISO3 a partir del nombre asignado al archivo por el descargador.
  country_iso3_code <- tools::file_path_sans_ext(basename(country_file))
  # Recuperar el nombre del país desde la muestra oficial de DRES.
  country_name <- dres_sample$country[match(country_iso3_code, dres_sample$country_iso3_code)]
  # Detener el script si el archivo no puede vincularse con la muestra seleccionada.
  if (is.na(country_name)) {
    stop("El archivo no pertenece a la muestra DRES de 20 %: ", country_file)
  }

  # Leer las observaciones comerciales como texto para controlar cada conversión.
  country_data <- read.csv(
    country_file,
    colClasses = "character",
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fileEncoding = "UTF-8"
  )
  # Definir las columnas necesarias para identificar país, año, producto y valor exportado.
  required_trade_columns <- c("iso3_code", "year", "product_id", "export_value_usd")
  # Identificar columnas comerciales ausentes en el archivo actual.
  missing_trade_columns <- setdiff(required_trade_columns, names(country_data))
  # Detener el script si el archivo no conserva la estructura entregada por el Atlas.
  if (length(missing_trade_columns) > 0L) {
    stop("Faltan columnas comerciales en ", country_file, ": ", paste(missing_trade_columns, collapse = ", "))
  }
  # Confirmar que todas las filas pertenecen al código indicado por el nombre del archivo.
  if (any(country_data$iso3_code != country_iso3_code)) {
    stop("El archivo contiene observaciones de otro país: ", country_file)
  }

  # Convertir el año a entero para seleccionar el periodo de análisis.
  country_data$year <- suppressWarnings(as.integer(country_data$year))
  # Convertir el valor exportado a número para calcular las participaciones.
  country_data$export_value_usd <- suppressWarnings(as.numeric(country_data$export_value_usd))
  # Identificar observaciones cuyo año o valor no pudo interpretarse.
  invalid_trade_values <- is.na(country_data$year) | is.na(country_data$export_value_usd)
  # Detener el script para impedir que una suma oculte errores de lectura.
  if (any(invalid_trade_values)) {
    stop("El archivo contiene años o valores no numéricos: ", country_file)
  }

  # Conservar solamente los años comprendidos entre 1990 y 2022.
  country_data <- country_data[country_data$year %in% analysis_years, , drop = FALSE]
  # Vincular cada identificador interno con su posición en el catálogo SITC.
  product_match <- match(country_data$product_id, product_catalog$productId)
  # Detener el script si aparece un producto que no puede clasificarse con el catálogo.
  if (any(is.na(product_match))) {
    stop("Hay productos sin código SITC en el archivo: ", country_file)
  }
  # Incorporar el código comercial necesario para separar mercancías y servicios.
  country_data$sitc_code <- product_catalog$code[product_match]
  # Identificar las mercancías con producto SITC conocido.
  country_data$is_classified_merchandise <-
    product_catalog$is_classified_merchandise[product_match]
  # Identificar las discrepancias de mercancías agrupadas en XXXX.
  country_data$is_unclassified_merchandise <-
    product_catalog$is_unclassified_merchandise[product_match]
  # Identificar los servicios que quedarán excluidos del cálculo.
  country_data$is_service <- product_catalog$is_service[product_match]
  # Construir la llave producto-año utilizada para comprobar unicidad dentro del país.
  product_year_key <- country_data[c("year", "product_id")]
  # Detener el script si un mismo producto aparece repetido en el mismo año.
  if (anyDuplicated(product_year_key) > 0L) {
    stop("El archivo contiene llaves producto-año duplicadas: ", country_file)
  }
  # Identificar correcciones negativas conservadas originalmente en la capa raw.
  country_data$negative_correction <- country_data$export_value_usd < 0
  # Reemplazar por cero las correcciones negativas únicamente para las agregaciones.
  country_data$processed_export_value_usd <- pmax(country_data$export_value_usd, 0)

  # Crear una fila para cada año solicitado, incluso cuando no haya exportaciones positivas.
  annual_result <- data.frame(
    country_iso3_code = rep(country_iso3_code, length(analysis_years)),
    country = rep(country_name, length(analysis_years)),
    year = as.integer(analysis_years),
    classified_merchandise_exports_usd = 0,
    unclassified_merchandise_exports_usd = 0,
    total_merchandise_exports_usd = 0,
    services_exports_excluded_usd = 0,
    classified_product_count = 0L,
    negative_merchandise_rows_corrected = 0L,
    negative_service_rows_excluded = 0L,
    classified_merchandise_coverage = NA_real_,
    unclassified_merchandise_share = NA_real_,
    hhi = NA_real_,
    divx = NA_real_,
    hhi_xxxx_as_one_product_sensitivity = NA_real_,
    divx_xxxx_as_one_product_sensitivity = NA_real_,
    hhi_difference_xxxx_sensitivity = NA_real_,
    coverage_flag = "sin_exportaciones_mercancias",
    stringsAsFactors = FALSE
  )

  # Recorrer cada año para resumir los productos sin consolidar los archivos raw.
  for (year_value in analysis_years) {
    # Conservar las observaciones correspondientes al año actual.
    annual_data <- country_data[country_data$year == year_value, , drop = FALSE]
    # Localizar la fila de salida reservada para el año actual.
    result_row <- match(year_value, annual_result$year)
    # Identificar productos SITC clasificados utilizados en el HHI oficial.
    classified_rows <- annual_data$is_classified_merchandise
    # Identificar la discrepancia XXXX conservada únicamente como diagnóstico.
    unclassified_rows <- annual_data$is_unclassified_merchandise
    # Identificar todos los registros mercantiles, clasificados o no clasificados.
    merchandise_rows <- classified_rows | unclassified_rows
    # Sumar exportaciones con producto SITC conocido.
    classified_total <- sum(annual_data$processed_export_value_usd[classified_rows])
    # Sumar por separado el residuo XXXX que no identifica productos homogéneos.
    unclassified_total <- sum(annual_data$processed_export_value_usd[unclassified_rows])
    # Reconstruir las exportaciones totales de mercancías sin incluir servicios.
    merchandise_total <- classified_total + unclassified_total
    # Registrar las exportaciones clasificadas en la fila país-año.
    annual_result$classified_merchandise_exports_usd[result_row] <- classified_total
    # Registrar las exportaciones no clasificadas en la fila país-año.
    annual_result$unclassified_merchandise_exports_usd[result_row] <- unclassified_total
    # Registrar el total de mercancías utilizado para medir cobertura.
    annual_result$total_merchandise_exports_usd[result_row] <- merchandise_total
    # Cuantificar los servicios excluidos para que la decisión sea auditable.
    annual_result$services_exports_excluded_usd[result_row] <- sum(
      annual_data$processed_export_value_usd[annual_data$is_service]
    )
    # Contar productos SITC con exportaciones estrictamente positivas.
    annual_result$classified_product_count[result_row] <- sum(
      classified_rows & annual_data$processed_export_value_usd > 0
    )
    # Contar correcciones negativas de mercancías transformadas a cero.
    annual_result$negative_merchandise_rows_corrected[result_row] <- sum(
      annual_data$negative_correction & merchandise_rows
    )
    # Contar correcciones negativas de servicios excluidas del cálculo.
    annual_result$negative_service_rows_excluded[result_row] <- sum(
      annual_data$negative_correction & annual_data$is_service
    )

    # Calcular indicadores solamente cuando existen exportaciones clasificadas positivas.
    if (classified_total > 0) {
      # Extraer los valores positivos de los productos SITC clasificados.
      classified_values <- annual_data$processed_export_value_usd[
        classified_rows & annual_data$processed_export_value_usd > 0
      ]
      # Convertir cada valor en una participación de las exportaciones clasificadas.
      classified_shares <- classified_values / classified_total
      # Sumar las participaciones al cuadrado para obtener el HHI oficial.
      annual_result$hhi[result_row] <- sum(classified_shares^2)
      # Calcular la diversificación como complemento exacto del HHI.
      annual_result$divx[result_row] <- 1 - annual_result$hhi[result_row]
    }

    # Medir cobertura cuando el país registra exportaciones de mercancías positivas.
    if (merchandise_total > 0) {
      # Calcular la proporción del total asignada a productos SITC conocidos.
      annual_result$classified_merchandise_coverage[result_row] <-
        classified_total / merchandise_total
      # Calcular la proporción del total agrupada en el residuo XXXX.
      annual_result$unclassified_merchandise_share[result_row] <-
        unclassified_total / merchandise_total
      # Calcular un HHI alternativo que trata XXXX artificialmente como un producto.
      if (classified_total > 0) {
        # Expresar los productos clasificados sobre el total que también contiene XXXX.
        classified_shares_total <- annual_data$processed_export_value_usd[
          classified_rows & annual_data$processed_export_value_usd > 0
        ] / merchandise_total
        # Expresar el residuo XXXX como si fuera una categoría homogénea única.
        unclassified_share_total <- unclassified_total / merchandise_total
        # Sumar cuadrados para cuantificar la sensibilidad de esa decisión alternativa.
        annual_result$hhi_xxxx_as_one_product_sensitivity[result_row] <-
          sum(classified_shares_total^2) + unclassified_share_total^2
        # Calcular el complemento del HHI alternativo.
        annual_result$divx_xxxx_as_one_product_sensitivity[result_row] <-
          1 - annual_result$hhi_xxxx_as_one_product_sensitivity[result_row]
        # Registrar cuánto cambia el HHI frente a la definición oficial.
        annual_result$hhi_difference_xxxx_sensitivity[result_row] <-
          annual_result$hhi_xxxx_as_one_product_sensitivity[result_row] -
          annual_result$hhi[result_row]
      }
      # Clasificar cobertura casi completa cuando XXXX no supera 1 %.
      if (annual_result$unclassified_merchandise_share[result_row] <= 0.01) {
        annual_result$coverage_flag[result_row] <- "alta_ge_99pct"
      # Clasificar cobertura buena cuando la parte clasificada está entre 95 % y 99 %.
      } else if (annual_result$unclassified_merchandise_share[result_row] <= 0.05) {
        annual_result$coverage_flag[result_row] <- "buena_95_99pct"
      # Clasificar cobertura moderada cuando la parte clasificada está entre 90 % y 95 %.
      } else if (annual_result$unclassified_merchandise_share[result_row] <= 0.10) {
        annual_result$coverage_flag[result_row] <- "moderada_90_95pct"
      # Advertir cobertura baja cuando más de 10 % permanece sin producto SITC.
      } else {
        annual_result$coverage_flag[result_row] <- "baja_lt_90pct"
      }
    }
  }

  # Devolver las 33 observaciones anuales de la economía procesada.
  annual_result
}

# Procesar únicamente los 55 archivos correspondientes a la muestra principal DRES.
hhi_divx_parts <- lapply(selected_country_files, process_country_file)
# Apilar los resúmenes pequeños en un panel país-año de 1990 a 2022.
hhi_divx_country_year <- do.call(rbind, hhi_divx_parts)
# Eliminar números de fila heredados para mantener identificadores limpios.
row.names(hhi_divx_country_year) <- NULL
# Ordenar el panel por código de país y año para facilitar su revisión.
hhi_divx_country_year <- hhi_divx_country_year[
  order(hhi_divx_country_year$country_iso3_code, hhi_divx_country_year$year),
]

# Calcular el número exacto de filas esperado para un panel balanceado solicitado.
expected_country_year_rows <- expected_country_count * length(analysis_years)
# Detener el script si falta o sobra alguna combinación país-año.
if (nrow(hhi_divx_country_year) != expected_country_year_rows) {
  stop("El panel HHI-DIVX no contiene todas las combinaciones país-año esperadas.")
}
# Detener el script si una llave país-año aparece más de una vez.
if (anyDuplicated(hhi_divx_country_year[c("country_iso3_code", "year")]) > 0L) {
  stop("El panel HHI-DIVX contiene llaves país-año duplicadas.")
}
# Confirmar que el panel contiene exactamente los países de la muestra DRES.
if (!identical(
  sort(unique(hhi_divx_country_year$country_iso3_code)),
  sort(dres_sample$country_iso3_code)
)) {
  stop("Los países del panel HHI-DIVX no coinciden con la muestra DRES.")
}
# Confirmar que el panel cubre exactamente el periodo solicitado.
if (!identical(sort(unique(hhi_divx_country_year$year)), as.integer(analysis_years))) {
  stop("Los años del panel HHI-DIVX no coinciden con 1990-2022.")
}
# Reconstruir el total mercantil como suma de productos clasificados y XXXX.
reconstructed_merchandise_total <-
  hhi_divx_country_year$classified_merchandise_exports_usd +
  hhi_divx_country_year$unclassified_merchandise_exports_usd
# Definir una tolerancia proporcional para comparar valores de distinta escala.
merchandise_tolerance <- pmax(1, hhi_divx_country_year$total_merchandise_exports_usd) * 1e-10
# Detener el script si el total mercantil no puede reconstruirse exactamente.
if (any(abs(
  hhi_divx_country_year$total_merchandise_exports_usd - reconstructed_merchandise_total
) > merchandise_tolerance)) {
  stop("El total mercantil no coincide con la suma de productos clasificados y XXXX.")
}
# Identificar filas para las cuales se obtuvo un HHI oficial.
valid_hhi_rows <- !is.na(hhi_divx_country_year$hhi)
# Detener el script si un HHI calculado queda fuera del intervalo lógico.
if (any(hhi_divx_country_year$hhi[valid_hhi_rows] < 0 |
  hhi_divx_country_year$hhi[valid_hhi_rows] > 1)) {
  stop("Se encontraron valores de HHI fuera del intervalo [0, 1].")
}
# Detener el script si un DIVX calculado queda fuera del intervalo lógico.
if (any(hhi_divx_country_year$divx[valid_hhi_rows] < 0 |
  hhi_divx_country_year$divx[valid_hhi_rows] > 1)) {
  stop("Se encontraron valores de DIVX fuera del intervalo [0, 1].")
}
# Confirmar que DIVX sea el complemento numérico exacto del HHI.
if (any(abs(
  hhi_divx_country_year$hhi[valid_hhi_rows] +
  hhi_divx_country_year$divx[valid_hhi_rows] - 1
) > 1e-12)) {
  stop("La identidad HHI + DIVX = 1 no se cumple.")
}
# Confirmar que no se calcule HHI cuando las exportaciones clasificadas son cero.
if (any(valid_hhi_rows & hhi_divx_country_year$classified_merchandise_exports_usd <= 0)) {
  stop("Se calculó HHI sin exportaciones clasificadas positivas.")
}
# Confirmar que todos los años con exportaciones clasificadas tengan HHI.
if (any(!valid_hhi_rows & hhi_divx_country_year$classified_merchandise_exports_usd > 0)) {
  stop("Falta HHI para años con exportaciones clasificadas positivas.")
}
# Identificar filas con el HHI alternativo utilizado para la sensibilidad de XXXX.
valid_sensitivity_rows <- !is.na(
  hhi_divx_country_year$hhi_xxxx_as_one_product_sensitivity
)
# Detener el script si el HHI alternativo queda fuera del intervalo lógico.
if (any(hhi_divx_country_year$hhi_xxxx_as_one_product_sensitivity[
  valid_sensitivity_rows
] < 0 | hhi_divx_country_year$hhi_xxxx_as_one_product_sensitivity[
  valid_sensitivity_rows
] > 1)) {
  stop("El HHI alternativo de XXXX queda fuera del intervalo [0, 1].")
}

# Dividir el panel en grupos para resumir separadamente cada país.
country_year_groups <- split(
  hhi_divx_country_year,
  hhi_divx_country_year$country_iso3_code
)
# Construir una fila de cobertura y sensibilidad para cada país.
hhi_divx_country_coverage <- do.call(rbind, lapply(country_year_groups, function(country_data) {
  # Identificar observaciones con una participación XXXX medible.
  valid_coverage_rows <- !is.na(country_data$unclassified_merchandise_share)
  # Identificar observaciones con una diferencia de sensibilidad medible.
  valid_difference_rows <- !is.na(country_data$hhi_difference_xxxx_sensitivity)
  # Devolver los principales diagnósticos del país durante 1990-2022.
  data.frame(
    country_iso3_code = country_data$country_iso3_code[1],
    country = country_data$country[1],
    years_requested = length(analysis_years),
    years_with_hhi = sum(!is.na(country_data$hhi)),
    years_without_hhi = sum(is.na(country_data$hhi)),
    years_with_xxxx = sum(country_data$unclassified_merchandise_exports_usd > 0),
    years_xxxx_share_gt_5pct = sum(
      valid_coverage_rows & country_data$unclassified_merchandise_share > 0.05
    ),
    years_xxxx_share_gt_10pct = sum(
      valid_coverage_rows & country_data$unclassified_merchandise_share > 0.10
    ),
    mean_unclassified_merchandise_share = if (any(valid_coverage_rows)) {
      mean(country_data$unclassified_merchandise_share[valid_coverage_rows])
    } else {
      NA_real_
    },
    max_unclassified_merchandise_share = if (any(valid_coverage_rows)) {
      max(country_data$unclassified_merchandise_share[valid_coverage_rows])
    } else {
      NA_real_
    },
    max_abs_hhi_difference_xxxx_sensitivity = if (any(valid_difference_rows)) {
      max(abs(country_data$hhi_difference_xxxx_sensitivity[valid_difference_rows]))
    } else {
      NA_real_
    },
    stringsAsFactors = FALSE
  )
}))
# Eliminar números de fila heredados del agrupamiento por país.
row.names(hhi_divx_country_coverage) <- NULL
# Ordenar la cobertura por código de país para facilitar su comparación con DRES.
hhi_divx_country_coverage <- hhi_divx_country_coverage[
  order(hhi_divx_country_coverage$country_iso3_code),
]

# Construir un resumen compacto con los principales controles de calidad.
hhi_divx_validation_summary <- data.frame(
  # Nombrar cada resultado para que pueda interpretarse sin depender de su posición.
  metric = c(
    "sample_countries",
    "analysis_years",
    "expected_country_year_rows",
    "country_year_rows",
    "country_years_with_hhi",
    "country_years_without_hhi",
    "country_years_with_xxxx",
    "country_years_xxxx_share_gt_5pct",
    "country_years_xxxx_share_gt_10pct",
    "classified_sitc4_products_in_catalog",
    "service_categories_excluded",
    "negative_merchandise_rows_corrected",
    "negative_service_rows_excluded",
    "mean_unclassified_merchandise_share",
    "max_unclassified_merchandise_share",
    "max_abs_hhi_difference_xxxx_sensitivity",
    "duplicate_country_year_keys",
    "hhi_divx_identity_max_error"
  ),
  # Calcular cada valor directamente desde las entradas y el panel validado.
  value = c(
    length(unique(hhi_divx_country_year$country_iso3_code)),
    length(unique(hhi_divx_country_year$year)),
    expected_country_year_rows,
    nrow(hhi_divx_country_year),
    sum(valid_hhi_rows),
    sum(!valid_hhi_rows),
    sum(hhi_divx_country_year$unclassified_merchandise_exports_usd > 0),
    sum(hhi_divx_country_year$unclassified_merchandise_share > 0.05, na.rm = TRUE),
    sum(hhi_divx_country_year$unclassified_merchandise_share > 0.10, na.rm = TRUE),
    sum(product_catalog$is_classified_merchandise),
    sum(product_catalog$is_service),
    sum(hhi_divx_country_year$negative_merchandise_rows_corrected),
    sum(hhi_divx_country_year$negative_service_rows_excluded),
    mean(hhi_divx_country_year$unclassified_merchandise_share, na.rm = TRUE),
    max(hhi_divx_country_year$unclassified_merchandise_share, na.rm = TRUE),
    max(abs(hhi_divx_country_year$hhi_difference_xxxx_sensitivity), na.rm = TRUE),
    anyDuplicated(hhi_divx_country_year[c("country_iso3_code", "year")]),
    max(abs(
      hhi_divx_country_year$hhi[valid_hhi_rows] +
      hhi_divx_country_year$divx[valid_hhi_rows] - 1
    ))
  ),
  # Mantener los nombres como texto simple al exportar el archivo.
  stringsAsFactors = FALSE
)

# Guardar el panel anual listo para incorporarse posteriormente al panel maestro.
write.csv(
  hhi_divx_country_year,
  file.path(processed_path, "hhi_divx_country_year_1990_2022.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar la cobertura temporal y la sensibilidad de XXXX resumidas por país.
write.csv(
  hhi_divx_country_coverage,
  file.path(processed_path, "hhi_divx_country_coverage_1990_2022.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Guardar los conteos que permiten auditar la ejecución sin abrir el panel completo.
write.csv(
  hhi_divx_validation_summary,
  file.path(processed_path, "hhi_divx_validation_summary.csv"),
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)

# Informar que el procesamiento terminó después de superar todas las validaciones.
message("Construcción de HHI y DIVX terminada.")
# Mostrar la carpeta donde quedaron las salidas procesadas.
message("Resultados: ", processed_path)
# Mostrar el número de países procesados.
message("Países: ", length(unique(hhi_divx_country_year$country_iso3_code)), ".")
# Mostrar el número de observaciones con HHI y DIVX calculables.
message("Observaciones con HHI y DIVX: ", sum(valid_hhi_rows), ".")
# Mostrar cuántas observaciones requieren cautela por más de 10 % en XXXX.
message(
  "País-años con más de 10 % de mercancías en XXXX: ",
  sum(hhi_divx_country_year$unclassified_merchandise_share > 0.10, na.rm = TRUE),
  "."
)
