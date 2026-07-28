# CAPA: RAW
# FUENTE: Atlas of Economic Complexity
# SALIDAS: data/raw/atlas/
# Descargar exportaciones por país, año y producto para varias variables de la tesis.
#
# Fuente: Atlas of Economic Complexity del Growth Lab de Harvard.
# Clasificación: SITC Revisión 2 a cuatro dígitos, comparable desde 1962.
# Periodo solicitado: 1990-2022, para cubrir el periodo base y el panel final.
# Salida principal: un CSV por país con sus exportaciones hacia el mundo.
#
# La misma base permite construir DRES, HHI, DIVX, PEXP y FEXP. Se conserva una
# sola copia raw para evitar duplicaciones y diferencias entre variables que
# deben partir de la misma información comercial.

# Reunir ubicaciones posibles del archivo que identifica la raíz del repositorio.
helper_path <- c(
  # Si el script está abierto en RStudio, buscar el helper desde su ubicación.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)))), "project_paths.R")
  },
  # Probar esta ruta cuando R se ejecuta desde la raíz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Probar esta ruta cuando R se ejecuta desde scripts/data/raw/atlas/.
  file.path("..", "..", "..", "project_paths.R"),
  # Probar esta ruta cuando R se ejecuta desde scripts/.
  file.path("..", "project_paths.R"),
  # Probar esta ruta cuando el helper está en el directorio de trabajo actual.
  "project_paths.R"
)

# Conservar solamente la primera ruta candidata que exista en el equipo.
helper_path <- helper_path[file.exists(helper_path)][1]
# Detener la ejecución con un mensaje claro si no se encontró el helper.
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}

# Ejecutar el helper para que su función quede disponible en esta sesión de R.
source(helper_path)
# Obtener la ruta absoluta de la raíz del repositorio.
project_path <- find_project_path()

# Definir los paquetes externos estrictamente necesarios para consultar y leer la API.
required_packages <- c(
  "httr2",    # Enviar de forma segura las solicitudes HTTPS al Atlas.
  "jsonlite"  # Convertir las respuestas JSON en objetos comprensibles para R.
)
# Identificar cuáles paquetes requeridos todavía no están instalados.
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
# Detener el script e indicar el comando de instalación si falta algún paquete.
if (length(missing_packages) > 0L) {
  stop(
    "Faltan paquetes de R. Instálelos una sola vez con: install.packages(c(",
    paste(sprintf("\"%s\"", missing_packages), collapse = ", "),
    "))"
  )
}

# Permitir hasta cinco minutos para recibir cada respuesta de la API.
options(timeout = 300)

# Registrar la dirección pública de la API GraphQL del Atlas.
api_url <- "https://atlas.hks.harvard.edu/api/graphql"
# Definir el primer año necesario para el periodo base de dependencia exportadora.
first_year <- 1990L
# Definir el último año del panel econométrico planteado en la metodología.
last_year <- 2022L
# Elegir la clasificación SITC para mantener comparabilidad durante todo el periodo.
product_class <- "SITC"
# Usar el mayor detalle SITC disponible para medir concentración entre productos.
product_level <- 4L
# Respetar holgadamente el límite público de 120 solicitudes por minuto.
seconds_between_requests <- 0.7
# Permitir varios intentos ante una interrupción temporal de internet o del servidor.
maximum_attempts <- 5L

# Construir la carpeta general que conservará el comercio SITC del Atlas.
raw_path <- file.path(
  project_path,      # Comenzar desde la raíz del proyecto.
  "data",           # Entrar en la carpeta general de datos.
  "raw",            # Usar la capa que conserva datos sin transformar.
  "atlas",          # Agrupar la fuente compartida según su proveedor.
  "sitc_rev2_trade" # Identificar la clasificación y el contenido comercial.
)
# Construir una subcarpeta con un archivo independiente por economía consultada.
country_files_path <- file.path(raw_path, "country_exports")
# Crear la carpeta y sus directorios padres si todavía no existen.
dir.create(country_files_path, recursive = TRUE, showWarnings = FALSE)

# Definir una función que envía una consulta y controla errores temporales.
atlas_query <- function(query_text, query_label) {
  # Repetir la solicitud hasta obtener una respuesta válida o agotar los intentos.
  for (attempt in seq_len(maximum_attempts)) {
    # Informar qué consulta se está intentando y en qué número de intento va.
    message(query_label, " | intento ", attempt, " de ", maximum_attempts)

    # Intentar la consulta sin cerrar abruptamente el script ante un error temporal.
    result <- tryCatch(
      {
        # Crear una solicitud dirigida al punto de acceso oficial del Atlas.
        request <- httr2::request(api_url)
        # Indicar que el contenido enviado y recibido utiliza el formato JSON.
        request <- httr2::req_headers(
          request,
          "Content-Type" = "application/json",
          "Accept" = "application/json"
        )
        # Incorporar la consulta GraphQL dentro del cuerpo JSON de la solicitud.
        request <- httr2::req_body_json(request, list(query = query_text))
        # Evitar que una respuesta lenta mantenga el proceso abierto indefinidamente.
        request <- httr2::req_timeout(request, seconds = 300)
        # Enviar la solicitud al servidor del Atlas.
        response <- httr2::req_perform(request)
        # Convertir la respuesta JSON en listas y tablas que R pueda interpretar.
        body <- httr2::resp_body_json(response, simplifyVector = TRUE)

        # Detectar errores GraphQL que pueden venir dentro de una respuesta HTTP válida.
        if (!is.null(body$errors)) {
          # Reunir los mensajes devueltos por el servidor en un único texto legible.
          error_messages <- vapply(body$errors, function(x) x$message, character(1))
          # Tratar esos mensajes como un error para activar los reintentos controlados.
          stop(paste(error_messages, collapse = " | "))
        }

        # Exigir que la respuesta contenga el bloque de datos esperado por GraphQL.
        if (is.null(body$data)) {
          stop("La respuesta del Atlas no contiene el bloque 'data'.")
        }

        # Devolver el contenido validado y terminar los reintentos de esta consulta.
        body$data
      },
      # Conservar el mensaje del error para decidir si corresponde intentar de nuevo.
      error = function(error_condition) error_condition
    )

    # Entregar inmediatamente los datos cuando la consulta terminó correctamente.
    if (!inherits(result, "error")) {
      return(result)
    }

    # Detener la ejecución si el último intento también terminó con error.
    if (attempt == maximum_attempts) {
      stop(
        "No fue posible completar '",
        query_label,
        "'. Último error: ",
        conditionMessage(result)
      )
    }

    # Calcular una espera creciente para no insistir de inmediato al servidor.
    retry_wait <- 2^(attempt - 1L)
    # Informar el error y el tiempo que transcurrirá antes del siguiente intento.
    message("Error temporal: ", conditionMessage(result), ". Esperando ", retry_wait, " s.")
    # Pausar la ejecución durante el intervalo calculado.
    Sys.sleep(retry_wait)
  }
}

# Preparar una consulta que obtiene el catálogo de países y territorios del Atlas.
country_catalog_query <- paste0(
  "{ locationCountry { ",
  "countryId iso3Code nameEn ",
  "} }"
)
# Ejecutar la consulta del catálogo geográfico.
country_catalog_response <- atlas_query(country_catalog_query, "Catálogo de países")
# Convertir el resultado geográfico en una tabla convencional de R.
country_catalog <- as.data.frame(
  country_catalog_response$locationCountry,
  stringsAsFactors = FALSE
)

# Confirmar que el catálogo incluya los tres campos necesarios para cada economía.
required_country_columns <- c("countryId", "iso3Code", "nameEn")
# Identificar campos geográficos ausentes por un posible cambio futuro de la API.
missing_country_columns <- setdiff(required_country_columns, names(country_catalog))
# Detener la ejecución si la estructura geográfica ya no coincide con la esperada.
if (length(missing_country_columns) > 0L) {
  stop("Faltan columnas en el catálogo de países: ", paste(missing_country_columns, collapse = ", "))
}

# Extraer el código numérico M49 que GraphQL espera en las consultas comerciales.
country_catalog$country_m49 <- sub("^country-", "", country_catalog$countryId)
# Confirmar que todos los identificadores extraídos contienen únicamente números.
if (any(!grepl("^[0-9]+$", country_catalog$country_m49))) {
  stop("El Atlas devolvió identificadores de país con un formato no reconocido.")
}

# Ordenar el catálogo por código ISO3 para producir archivos estables entre ejecuciones.
country_catalog <- country_catalog[order(country_catalog$iso3Code), ]
# Restaurar una numeración consecutiva después de ordenar la tabla.
rownames(country_catalog) <- NULL
# Guardar el catálogo geográfico utilizado en esta descarga.
write.csv(
  country_catalog,                                           # Escribir una fila por economía del Atlas.
  file.path(raw_path, "atlas_country_catalog.csv"),         # Usar un nombre que identifica fuente y contenido.
  row.names = FALSE,                                         # No crear una columna artificial con números de fila.
  fileEncoding = "UTF-8"                                    # Conservar correctamente tildes y caracteres especiales.
)

# Preparar una consulta con la clasificación SITC Revisión 2 a cuatro dígitos.
product_catalog_query <- paste0(
  "{ productSitc(productLevel: ",
  product_level,
  ") { productId code nameEn naturalResource } }"
)
# Ejecutar la consulta del catálogo de productos.
product_catalog_response <- atlas_query(product_catalog_query, "Catálogo SITC de productos")
# Convertir el resultado de productos en una tabla convencional de R.
product_catalog <- as.data.frame(
  product_catalog_response$productSitc,
  stringsAsFactors = FALSE
)

# Confirmar que el catálogo incluya la identificación y descripción de cada producto.
required_product_columns <- c("productId", "code", "nameEn", "naturalResource")
# Identificar campos de productos ausentes por un posible cambio futuro de la API.
missing_product_columns <- setdiff(required_product_columns, names(product_catalog))
# Detener la ejecución si la estructura de productos ya no coincide con la esperada.
if (length(missing_product_columns) > 0L) {
  stop("Faltan columnas en el catálogo SITC: ", paste(missing_product_columns, collapse = ", "))
}

# Ordenar los productos por su código SITC publicado para facilitar su revisión.
product_catalog <- product_catalog[order(product_catalog$code), ]
# Restaurar una numeración consecutiva después de ordenar la tabla.
rownames(product_catalog) <- NULL
# Guardar el catálogo que permitirá interpretar los identificadores internos del Atlas.
write.csv(
  product_catalog,                                            # Escribir código, nombre y clasificación de recursos.
  file.path(raw_path, "atlas_sitc4_product_catalog.csv"),    # Identificar explícitamente el nivel SITC del archivo.
  row.names = FALSE,                                          # No crear una columna artificial con números de fila.
  fileEncoding = "UTF-8"                                     # Conservar correctamente los nombres de productos.
)

# Crear una función que considera completo un archivo previamente descargado.
is_completed_country_file <- function(file_path) {
  # Exigir que el archivo exista antes de intentar inspeccionarlo.
  if (!file.exists(file_path)) return(FALSE)
  # Exigir que el archivo tenga contenido y no sea un archivo vacío por una interrupción.
  if (file.info(file_path)$size <= 0) return(FALSE)
  # Leer únicamente el encabezado para comprobar la estructura sin cargar todos los datos.
  header <- tryCatch(names(read.csv(file_path, nrows = 0, check.names = FALSE)), error = function(e) character())
  # Definir las columnas que debe tener incluso una economía sin observaciones comerciales.
  expected <- c("country_id", "iso3_code", "country_name", "year", "product_id", "export_value_usd")
  # Aceptar el archivo solamente cuando contiene exactamente las columnas esperadas.
  identical(header, expected)
}

# Recorrer todas las economías del catálogo para descargar sus exportaciones a mundo.
for (country_index in seq_len(nrow(country_catalog))) {
  # Extraer el código ISO3 usado para nombrar el archivo de esta economía.
  iso3_code <- country_catalog$iso3Code[country_index]
  # Extraer el identificador numérico utilizado por el punto de acceso comercial.
  country_m49 <- country_catalog$country_m49[country_index]
  # Extraer el nombre legible que acompañará cada observación comercial.
  country_name <- country_catalog$nameEn[country_index]
  # Construir la ruta final del archivo individual de esta economía.
  country_file <- file.path(country_files_path, paste0(iso3_code, ".csv"))

  # Omitir una economía ya descargada para poder reanudar el proceso tras una interrupción.
  if (is_completed_country_file(country_file)) {
    message("Ya existe un archivo válido para ", iso3_code, "; se omite la descarga.")
    next
  }

  # Construir la consulta que pide exportaciones a mundo por año y producto.
  trade_query <- paste0(
    "{ countryProductYear(",
    "countryId: ", country_m49, ", ",
    "productClass: ", product_class, ", ",
    "productLevel: ", product_level, ", ",
    "yearMin: ", first_year, ", ",
    "yearMax: ", last_year,
    ") { year productId exportValue } }"
  )
  # Ejecutar la consulta comercial de la economía actual.
  trade_response <- atlas_query(trade_query, paste0("Exportaciones de ", iso3_code))
  # Extraer el bloque que contiene observaciones por año y producto.
  trade_records <- trade_response$countryProductYear

  # Crear una tabla vacía con estructura estable cuando no hay comercio disponible.
  if (length(trade_records) == 0L) {
    # Definir las mismas columnas que utilizarán las economías con observaciones.
    country_data <- data.frame(
      country_id = character(),       # Identificador interno del Atlas.
      iso3_code = character(),         # Código internacional ISO3.
      country_name = character(),      # Nombre legible de la economía.
      year = integer(),                # Año de la observación comercial.
      product_id = character(),        # Identificador que se une al catálogo SITC.
      export_value_usd = numeric(),    # Exportaciones corrientes en dólares.
      stringsAsFactors = FALSE         # Mantener los textos como texto simple.
    )
  } else {
    # Convertir las observaciones comerciales recibidas en una tabla de R.
    trade_records <- as.data.frame(trade_records, stringsAsFactors = FALSE)
    # Reorganizar y renombrar los campos para que sean claros fuera de GraphQL.
    country_data <- data.frame(
      country_id = country_catalog$countryId[country_index],  # Repetir el identificador de la economía.
      iso3_code = iso3_code,                                  # Repetir el código ISO3 de la economía.
      country_name = country_name,                            # Repetir el nombre legible de la economía.
      year = as.integer(trade_records$year),                  # Conservar el año como número entero.
      product_id = as.character(trade_records$productId),     # Conservar el identificador del producto.
      export_value_usd = as.numeric(trade_records$exportValue), # Conservar el valor exportado como número.
      stringsAsFactors = FALSE                                # Mantener los textos como texto simple.
    )
  }

  # Detectar años que estén fuera del intervalo explícitamente solicitado.
  invalid_years <- country_data$year < first_year | country_data$year > last_year
  # Detener el proceso si el servidor devolvió observaciones ajenas al periodo.
  if (any(invalid_years, na.rm = TRUE)) {
    stop("El Atlas devolvió años fuera de 1990-2022 para ", iso3_code, ".")
  }
  # Detectar correcciones negativas que deberán tratarse posteriormente en la capa processed.
  invalid_values <- country_data$export_value_usd < 0
  # Conservar los valores raw, pero advertir cuántos no pueden usarse directamente como participaciones.
  if (any(invalid_values, na.rm = TRUE)) {
    message(
      "Advertencia: ",
      sum(invalid_values, na.rm = TRUE),
      " observación(es) negativa(s) se conservarán sin modificar para ",
      iso3_code,
      "."
    )
  }

  # Crear un archivo temporal para no dejar un CSV incompleto si se interrumpe la escritura.
  temporary_file <- tempfile(pattern = paste0(iso3_code, "_"), tmpdir = country_files_path, fileext = ".csv")
  # Escribir las observaciones de esta economía en el archivo temporal.
  write.csv(
    country_data,                  # Guardar todas las combinaciones año-producto recibidas.
    temporary_file,                # Usar primero la ruta temporal segura.
    row.names = FALSE,             # No crear una columna artificial con números de fila.
    fileEncoding = "UTF-8"        # Conservar correctamente los nombres de las economías.
  )
  # Mover el archivo completo a su nombre definitivo de manera atómica.
  if (!file.rename(temporary_file, country_file)) {
    stop("No fue posible guardar el archivo definitivo de ", iso3_code, ".")
  }

  # Informar cuántas observaciones quedaron almacenadas para esta economía.
  message("Guardadas ", nrow(country_data), " observaciones para ", iso3_code, ".")
  # Pausar brevemente para mantener una frecuencia respetuosa con la API pública.
  Sys.sleep(seconds_between_requests)
}

# Reunir las rutas individuales siguiendo el orden estable del catálogo geográfico.
country_files <- file.path(country_files_path, paste0(country_catalog$iso3Code, ".csv"))
# Exigir que todas las economías tengan un archivo, incluso cuando esté vacío de observaciones.
if (any(!file.exists(country_files))) {
  stop("Faltan archivos de países; no se generarán resúmenes con una descarga incompleta.")
}

# Inicializar el contador total de observaciones almacenadas en los archivos por país.
total_trade_rows <- 0L
# Inicializar el contador de correcciones negativas conservadas en la capa raw.
total_negative_rows <- 0L
# Crear una lista que reunirá resúmenes pequeños de cobertura por economía y año.
coverage_parts <- vector("list", length(country_files))

# Leer y validar un archivo por vez para no cargar millones de filas simultáneamente.
for (file_index in seq_along(country_files)) {
  # Leer las observaciones de una sola economía.
  country_data <- read.csv(
    country_files[file_index],     # Abrir el archivo individual correspondiente.
    stringsAsFactors = FALSE,      # Mantener códigos y nombres como texto simple.
    check.names = FALSE            # Conservar exactamente los nombres de las columnas.
  )

  # Revisar las claves y los valores únicamente cuando la economía tiene observaciones.
  if (nrow(country_data) > 0L) {
    # Definir los campos que nunca deberían estar vacíos en una observación comercial.
    required_trade_fields <- c("country_id", "iso3_code", "year", "product_id", "export_value_usd")
    # Detener el proceso si alguna fila carece de una clave o de su valor exportado.
    if (anyNA(country_data[required_trade_fields])) {
      stop("Hay valores faltantes en campos obligatorios de ", basename(country_files[file_index]), ".")
    }

    # Detectar repeticiones de la misma combinación país-año-producto.
    duplicate_trade_keys <- anyDuplicated(country_data[c("year", "product_id")])
    # Detener el proceso porque una duplicación alteraría las participaciones y el HHI.
    if (duplicate_trade_keys > 0L) {
      stop("Hay claves año-producto duplicadas en ", basename(country_files[file_index]), ".")
    }

    # Identificar productos comerciales que no aparezcan en el catálogo SITC descargado.
    unknown_product_ids <- setdiff(unique(country_data$product_id), product_catalog$productId)
    # Detener el proceso si no es posible asignar un código SITC a alguna observación.
    if (length(unknown_product_ids) > 0L) {
      stop(
        "Hay identificadores de producto sin correspondencia en ",
        basename(country_files[file_index]),
        ": ",
        paste(head(unknown_product_ids, 10L), collapse = ", ")
      )
    }

    # Confirmar nuevamente que las filas almacenadas pertenecen al periodo solicitado.
    rows_outside_period <- country_data$year < first_year | country_data$year > last_year
    # Detener la validación si un archivo individual contiene años inesperados.
    if (any(rows_outside_period)) {
      stop("Hay años fuera de 1990-2022 en ", basename(country_files[file_index]), ".")
    }
  }

  # Incrementar el contador con las filas aportadas por esta economía.
  total_trade_rows <- total_trade_rows + nrow(country_data)
  # Contar correcciones negativas para documentarlas sin transformar el dato original.
  total_negative_rows <- total_negative_rows + sum(country_data$export_value_usd < 0, na.rm = TRUE)

  # Preparar un resumen país-año únicamente cuando existen observaciones.
  if (nrow(country_data) > 0L) {
    # Contar productos observados y sumar exportaciones para cada año disponible.
    year_summary <- aggregate(
      country_data$export_value_usd,                           # Resumir el valor exportado.
      by = list(year = country_data$year),                     # Formar un grupo por año.
      FUN = function(values) c(products = length(values), exports = sum(values, na.rm = TRUE))
    )
    # Extraer del resultado matricial el número de productos por país-año.
    product_count <- year_summary$x[, "products"]
    # Extraer del resultado matricial la suma exportada por país-año.
    export_sum <- year_summary$x[, "exports"]
    # Guardar un resumen pequeño que facilite revisar la cobertura sin abrir el archivo grande.
    coverage_parts[[file_index]] <- data.frame(
      country_id = country_data$country_id[1],                 # Identificar la economía del resumen.
      iso3_code = country_data$iso3_code[1],                   # Conservar su código ISO3.
      country_name = country_data$country_name[1],             # Conservar su nombre legible.
      year = as.integer(year_summary$year),                    # Registrar cada año con información.
      product_count = as.integer(product_count),               # Contar productos exportados observados.
      total_exports_usd = as.numeric(export_sum),              # Sumar exportaciones corrientes del año.
      stringsAsFactors = FALSE                                 # Mantener los textos como texto simple.
    )
  }
}

# Descartar las posiciones vacías correspondientes a economías sin observaciones.
coverage_parts <- coverage_parts[lengths(coverage_parts) > 0L]
# Unir todos los resúmenes país-año en una sola tabla pequeña de control.
coverage <- do.call(rbind, coverage_parts)
# Ordenar la cobertura por país y año para facilitar su lectura.
coverage <- coverage[order(coverage$iso3_code, coverage$year), ]
# Restaurar una numeración consecutiva después de ordenar la tabla.
rownames(coverage) <- NULL
# Guardar el resumen de cobertura que permitirá detectar vacíos antes de construir el panel.
write.csv(
  coverage,                                               # Escribir una fila por país-año disponible.
  file.path(raw_path, "atlas_sitc4_coverage_1990_2022.csv"), # Identificar clasificación y periodo.
  row.names = FALSE,                                      # No crear una columna artificial con números de fila.
  fileEncoding = "UTF-8"                                 # Conservar correctamente los nombres de las economías.
)

# Contar cuántas economías poseen al menos una observación durante el periodo.
countries_with_data <- length(unique(coverage$iso3_code))
# Crear un manifiesto con las decisiones y dimensiones principales de la descarga.
download_manifest <- data.frame(
  field = c(
    "download_completed_utc",    # Momento en que terminó la ejecución.
    "source",                    # Institución que publica y armoniza los datos.
    "api_url",                   # Punto exacto utilizado para obtenerlos.
    "product_classification",    # Sistema que define las categorías de productos.
    "product_level",             # Número de dígitos solicitado.
    "first_year",                # Primer año incluido.
    "last_year",                 # Último año incluido.
    "catalog_countries",         # Economías consultadas en la API.
    "countries_with_data",       # Economías con observaciones durante el periodo.
    "catalog_products",          # Productos incluidos en el catálogo SITC.
    "trade_rows",                # Filas distribuidas entre los archivos por país.
    "negative_trade_rows",       # Correcciones negativas conservadas sin modificar.
    "storage_layout"             # Forma de almacenamiento que evita duplicar los datos.
  ),
  value = c(
    format(Sys.time(), tz = "UTC", usetz = TRUE),             # Registrar fecha y hora en una zona inequívoca.
    "Growth Lab at Harvard University - Atlas of Economic Complexity", # Nombrar la fuente académica.
    api_url,                                                    # Conservar la URL pública consultada.
    "SITC Revision 2",                                        # Documentar la revisión histórica armonizada.
    as.character(product_level),                               # Guardar el nivel de detalle como texto.
    as.character(first_year),                                  # Guardar el límite inferior como texto.
    as.character(last_year),                                   # Guardar el límite superior como texto.
    as.character(nrow(country_catalog)),                        # Registrar el tamaño del catálogo geográfico.
    as.character(countries_with_data),                          # Registrar cuántas economías tienen datos.
    as.character(nrow(product_catalog)),                        # Registrar el número de productos disponibles.
    as.character(total_trade_rows),                             # Registrar el total de filas en los archivos por país.
    as.character(total_negative_rows),                          # Registrar las correcciones que requerirán tratamiento.
    "One CSV per country; no consolidated trade file"          # Documentar que no se crea una segunda copia completa.
  ),
  stringsAsFactors = FALSE                                      # Mantener todos los valores como texto simple.
)
# Guardar el manifiesto junto a los archivos raw de la descarga.
write.csv(
  download_manifest,                                  # Escribir decisiones, fuente y dimensiones.
  file.path(raw_path, "download_manifest.csv"),      # Utilizar un nombre estándar y fácil de localizar.
  row.names = FALSE,                                  # No crear una columna artificial con números de fila.
  fileEncoding = "UTF-8"                             # Conservar correctamente todos los textos.
)

# Informar que la descarga y la validación terminaron correctamente.
message("Descarga validada en: ", normalizePath(country_files_path, winslash = "/"))
# Informar el número total de observaciones distribuidas entre los archivos por país.
message("Filas comerciales almacenadas: ", format(total_trade_rows, big.mark = ","))
# Informar cuántas economías cuentan con información dentro del periodo.
message("Economías con datos: ", countries_with_data, " de ", nrow(country_catalog), ".")
