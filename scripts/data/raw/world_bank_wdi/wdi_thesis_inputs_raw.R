# CAPA: RAW
# FUENTE: World Development Indicators
# SALIDAS: data/raw/world_bank_wdi/
# Descargar los indicadores WDI necesarios para las variables de la tesis.
#
# Entradas: servicio oficial de descarga masiva del Banco Mundial.
# Salidas: ZIP originales, panel WDI 1980-2022 y manifiesto de trazabilidad.

# Reunir las ubicaciones desde las cuales puede encontrarse el helper de rutas.
helper_path <- c(
  # Buscar desde el archivo activo cuando el script se ejecuta en RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)))), "project_paths.R")
  },
  # Buscar desde la raíz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Buscar desde scripts/data/raw/world_bank_wdi/.
  file.path("..", "..", "..", "project_paths.R"),
  # Buscar desde scripts/.
  file.path("..", "project_paths.R"),
  # Buscar en el directorio de trabajo actual como última alternativa.
  "project_paths.R"
)

# Conservar la primera ubicación candidata que exista en el equipo.
helper_path <- helper_path[file.exists(helper_path)][1]
# Detener el script si no fue posible encontrar el helper de rutas.
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}

# Ejecutar el helper para habilitar la búsqueda de la raíz del repositorio.
source(helper_path)
# Obtener la ruta absoluta del proyecto sin depender del directorio de RStudio.
project_path <- find_project_path()
# Ampliar el tiempo permitido para cada descarga a diez minutos.
options(timeout = 600)

# Definir el horizonte general de recopilación establecido en la metodología.
download_years <- 1980:2022
# Crear el catálogo de indicadores estrictamente necesarios para el modelo.
indicator_catalog <- data.frame(
  # Asignar nombres legibles y estables a las columnas del panel combinado.
  variable = c(
    "oil_rents_pct_gdp",
    "natural_gas_rents_pct_gdp",
    "coal_rents_pct_gdp",
    "mineral_rents_pct_gdp",
    "population_total",
    "gdp_constant_usd",
    "gdp_per_capita_ppp_constant",
    "domestic_credit_private_pct_gdp",
    "government_consumption_pct_gdp",
    "scientific_technical_journal_articles",
    "internet_users_pct_population"
  ),
  # Registrar los códigos oficiales utilizados por la API del Banco Mundial.
  indicator_code = c(
    "NY.GDP.PETR.RT.ZS",
    "NY.GDP.NGAS.RT.ZS",
    "NY.GDP.COAL.RT.ZS",
    "NY.GDP.MINR.RT.ZS",
    "SP.POP.TOTL",
    "NY.GDP.MKTP.KD",
    "NY.GDP.PCAP.PP.KD",
    "FS.AST.PRVT.GD.ZS",
    "NE.CON.GOVT.ZS",
    "IP.JRN.ARTC.SC",
    "IT.NET.USER.ZS"
  ),
  # Documentar la interpretación que tendrá cada serie dentro del proyecto.
  purpose = c(
    "Construir RENTS extractivo y OILPC",
    "Construir RENTS extractivo y GASPC",
    "Construir RENTS extractivo y COALPC",
    "Completar RENTS extractivo con minería",
    "Construir variables per cápita",
    "Valorar rentas por habitante en términos reales",
    "Construir LOG_GDPPC en PPP constante",
    "Construir FIN",
    "Construir GOVCONS como control de consumo gubernamental",
    "Construir INNOV principal mediante artículos científicos per cápita",
    "Construir NET"
  ),
  # Evitar que R convierta automáticamente las cadenas en factores.
  stringsAsFactors = FALSE
)

# Construir la carpeta compartida de insumos WDI utilizados por varias variables.
raw_path <- file.path(project_path, "data", "raw", "world_bank_wdi")
# Construir la subcarpeta que conservará los ZIP originales de cada indicador.
source_zip_path <- file.path(raw_path, "source_zips")
# Crear ambas carpetas y sus directorios padres cuando todavía no existan.
dir.create(source_zip_path, recursive = TRUE, showWarnings = FALSE)
# Construir la ruta del panel combinado que se utilizará después para procesar variables.
output_file <- file.path(raw_path, "wdi_thesis_inputs_1980_2022.csv")
# Construir la ruta del manifiesto que documentará procedencia y fecha de descarga.
manifest_file <- file.path(raw_path, "wdi_thesis_download_manifest.csv")

# Definir una función que identifica la línea donde comienza un CSV del Banco Mundial.
find_csv_header <- function(path, required_fields) {
  # Leer únicamente las primeras doce líneas porque allí se ubica el encabezado.
  first_lines <- readLines(path, n = 12, warn = FALSE, encoding = "UTF-8")
  # Revisar en cuál línea aparecen todos los nombres de campo requeridos.
  header_line <- which(vapply(
    first_lines,
    # Confirmar que cada campo requerido aparezca en la línea evaluada.
    function(line) all(vapply(required_fields, grepl, logical(1), x = line, fixed = TRUE)),
    # Exigir que cada revisión devuelva un único valor verdadero o falso.
    logical(1)
  ))[1]
  # Detener el script si el formato cambió y no se reconoce el encabezado.
  if (is.na(header_line)) {
    stop("No se encontró el encabezado esperado en: ", path)
  }
  # Devolver el número de líneas que read.csv debe omitir.
  header_line - 1L
}

# Definir una función que descarga y convierte un indicador en un panel país-año.
download_wdi_indicator <- function(indicator_code, variable_name, years, zip_dir) {
  # Construir la dirección oficial de descarga masiva del indicador solicitado.
  source_url <- paste0(
    "https://api.worldbank.org/v2/en/indicator/",
    indicator_code,
    "?downloadformat=csv"
  )
  # Reemplazar los puntos para crear un nombre de ZIP compatible con Windows.
  zip_name <- paste0(gsub("\\.", "_", indicator_code), ".zip")
  # Unir la carpeta de destino con el nombre asignado al archivo original.
  zip_file <- file.path(zip_dir, zip_name)
  # Reutilizar el ZIP oficial ya almacenado para evitar descargas redundantes.
  if (file.exists(zip_file) && file.info(zip_file)$size > 0L) {
    message("Usando ZIP local de ", indicator_code, "...")
  } else {
    # Descargar el ZIP solamente cuando el insumo original todavía no existe.
    message("Descargando ", indicator_code, "...")
    download_result <- try(
      download.file(
        url = source_url,
        destfile = zip_file,
        mode = "wb",
        quiet = TRUE,
        method = "libcurl"
      ),
      silent = TRUE
    )
    # Usar Python cuando la instalación local de R no completa la conexión SSL.
    if (
      inherits(download_result, "try-error") ||
        !file.exists(zip_file) ||
        file.info(zip_file)$size == 0L
    ) {
      python_path <- Sys.which("python")
      python_downloader <- file.path(
        project_path,
        "scripts",
        "data",
        "raw",
        "world_bank_wdi",
        "download_wdi_zip_raw.py"
      )
      if (!nzchar(python_path) || !file.exists(python_downloader)) {
        stop("No existe un descargador HTTPS disponible para: ", indicator_code)
      }
      python_status <- system2(
        python_path,
        args = c(
          shQuote(python_downloader),
          shQuote(source_url),
          shQuote(zip_file)
        )
      )
      if (python_status != 0L) {
        stop("No fue posible descargar: ", indicator_code)
      }
    }
  }
  # Detener el script si el archivo no existe o quedó vacío.
  if (!file.exists(zip_file) || file.info(zip_file)$size == 0L) {
    stop("La descarga quedó vacía para: ", indicator_code)
  }
  # Consultar los nombres de los archivos incluidos dentro del ZIP.
  archive_files <- utils::unzip(zip_file, list = TRUE)$Name
  # Localizar el CSV principal que contiene las observaciones del indicador.
  data_entry <- grep("^API_.*\\.csv$", archive_files, value = TRUE)
  # Localizar el CSV que permite distinguir países de agregados regionales.
  country_entry <- grep("^Metadata_Country_.*\\.csv$", archive_files, value = TRUE)
  # Exigir exactamente un archivo de datos y uno de metadatos de países.
  if (length(data_entry) != 1L || length(country_entry) != 1L) {
    stop("El ZIP de ", indicator_code, " no tiene la estructura esperada.")
  }
  # Crear una carpeta temporal para extraer solamente los archivos necesarios.
  extract_path <- tempfile(pattern = "wdi_extract_")
  # Crear físicamente la carpeta temporal.
  dir.create(extract_path)
  # Programar la eliminación de esa carpeta cuando termine la función.
  on.exit(unlink(extract_path, recursive = TRUE, force = TRUE), add = TRUE)
  # Extraer el CSV de datos y los metadatos de países.
  utils::unzip(
    zip_file,
    files = c(data_entry, country_entry),
    exdir = extract_path
  )
  # Construir la ruta temporal del CSV principal.
  data_file <- file.path(extract_path, data_entry)
  # Construir la ruta temporal de los metadatos de países.
  country_file <- file.path(extract_path, country_entry)
  # Identificar cuántas líneas iniciales deben omitirse en el archivo principal.
  data_skip <- find_csv_header(data_file, c("Country Name", "Country Code", "Indicator Code"))
  # Identificar cuántas líneas iniciales deben omitirse en los metadatos.
  country_skip <- find_csv_header(country_file, c("Country Code", "Region"))
  # Leer las observaciones originales sin alterar los nombres de los años.
  raw_data <- read.csv(
    data_file,
    skip = data_skip,
    check.names = FALSE,
    stringsAsFactors = FALSE,
    na.strings = c("", "..")
  )
  # Leer los metadatos que identifican países y economías individuales.
  country_metadata <- read.csv(
    country_file,
    skip = country_skip,
    check.names = FALSE,
    stringsAsFactors = FALSE,
    na.strings = c("", "..")
  )
  # Confirmar que la descarga corresponde realmente al código solicitado.
  if (!indicator_code %in% unique(raw_data[["Indicator Code"]])) {
    stop("El archivo descargado no corresponde a: ", indicator_code)
  }
  # Convertir el horizonte requerido a texto para compararlo con las columnas.
  year_names <- as.character(years)
  # Identificar años que no estén presentes por un posible cambio de formato.
  missing_years <- setdiff(year_names, names(raw_data))
  # Informar cuando la propia fuente no publica columnas para parte del horizonte.
  if (length(missing_years) > 0L) {
    message(
      "La fuente no publica columnas para ", indicator_code, " en: ",
      paste(missing_years, collapse = ", "), ". Se conservarán como NA."
    )
  }
  # Conservar códigos cuya región no esté vacía, criterio WDI para países.
  valid_country_codes <- country_metadata[["Country Code"]][
    !is.na(country_metadata[["Region"]]) & nzchar(trimws(country_metadata[["Region"]]))
  ]
  # Crear una correspondencia entre cada código ISO3 y el nombre del país.
  country_map <- unique(data.frame(
    country_iso3_code = raw_data[["Country Code"]],
    country = raw_data[["Country Name"]],
    stringsAsFactors = FALSE
  ))
  # Excluir agregados regionales y códigos que no tengan tres letras mayúsculas.
  country_map <- country_map[
    country_map$country_iso3_code %in% valid_country_codes &
      grepl("^[A-Z]{3}$", country_map$country_iso3_code),
    ,
    drop = FALSE
  ]
  # Convertir la tabla ancha en observaciones individuales para cada país y año.
  long_data <- do.call(rbind, lapply(years, function(year_value) {
    # Crear una tabla correspondiente al año recorrido actualmente.
    data.frame(
      country_iso3_code = raw_data[["Country Code"]],
      year = as.integer(year_value),
      value = if (as.character(year_value) %in% names(raw_data)) {
        suppressWarnings(as.numeric(raw_data[[as.character(year_value)]]))
      } else {
        rep(NA_real_, nrow(raw_data))
      },
      stringsAsFactors = FALSE
    )
  }))
  # Reemplazar el nombre genérico del valor por el nombre descriptivo de la serie.
  names(long_data)[names(long_data) == "value"] <- variable_name
  # Conservar solamente observaciones correspondientes a países identificados.
  long_data <- long_data[
    long_data$country_iso3_code %in% country_map$country_iso3_code,
    ,
    drop = FALSE
  ]
  # Detener el script si un mismo país y año aparece más de una vez.
  if (anyDuplicated(long_data[c("country_iso3_code", "year")]) > 0L) {
    stop("La descarga contiene llaves duplicadas para: ", indicator_code)
  }
  # Devolver los datos, los países y la información de trazabilidad.
  list(
    data = long_data,
    country_map = country_map,
    source_url = source_url,
    zip_file = zip_file
  )
}

# Descargar cada una de las series registradas en el catálogo.
downloads <- lapply(seq_len(nrow(indicator_catalog)), function(index) {
  # Ejecutar la función con el código y nombre correspondientes a esta fila.
  download_wdi_indicator(
    indicator_code = indicator_catalog$indicator_code[index],
    variable_name = indicator_catalog$variable[index],
    years = download_years,
    zip_dir = source_zip_path
  )
})

# Unir todos los indicadores mediante las llaves comunes de país y año.
wdi_inputs <- Reduce(
  # Definir una unión completa que preserve observaciones aunque tengan faltantes.
  function(left, right) merge(
    left,
    right,
    by = c("country_iso3_code", "year"),
    all = TRUE,
    sort = FALSE
  ),
  # Extraer únicamente el panel numérico de cada resultado descargado.
  lapply(downloads, function(item) item$data)
)
# Apilar los mapas de países producidos por las distintas descargas.
country_map <- unique(do.call(rbind, lapply(downloads, function(item) item$country_map)))
# Conservar una sola correspondencia de nombre para cada código ISO3.
country_map <- country_map[!duplicated(country_map$country_iso3_code), ]
# Incorporar los nombres de país al panel combinado de indicadores.
wdi_inputs <- merge(
  country_map,
  wdi_inputs,
  by = "country_iso3_code",
  all.y = TRUE,
  sort = FALSE
)
# Definir el orden estable de identificación y variables en el archivo final.
ordered_columns <- c(
  "country_iso3_code",
  "country",
  "year",
  indicator_catalog$variable
)
# Reordenar físicamente las columnas según la estructura documentada.
wdi_inputs <- wdi_inputs[, ordered_columns]
# Ordenar las filas por país y año para facilitar inspección y procesamiento.
wdi_inputs <- wdi_inputs[order(wdi_inputs$country_iso3_code, wdi_inputs$year), ]
# Eliminar los números de fila heredados durante las uniones.
row.names(wdi_inputs) <- NULL
# Detener el script si existe más de una fila para el mismo país y año.
if (anyDuplicated(wdi_inputs[c("country_iso3_code", "year")]) > 0L) {
  stop("El panel WDI combinado contiene llaves país-año duplicadas.")
}
# Confirmar que el panel conserva exactamente el horizonte solicitado.
if (!identical(sort(unique(wdi_inputs$year)), as.integer(download_years))) {
  stop("El panel WDI no contiene exactamente el periodo 1980-2022.")
}
# Contar las observaciones no faltantes para cada indicador descargado.
non_missing_counts <- vapply(
  indicator_catalog$variable,
  # Sumar las celdas observadas dentro de cada columna.
  function(variable_name) sum(!is.na(wdi_inputs[[variable_name]])),
  # Exigir que cada resultado sea un único número entero.
  integer(1)
)
# Detener el script si alguna descarga quedó completamente vacía.
if (any(non_missing_counts == 0L)) {
  stop(
    "Los siguientes indicadores quedaron vacíos: ",
    paste(names(non_missing_counts)[non_missing_counts == 0L], collapse = ", ")
  )
}
# Guardar el panel combinado como insumo raw compartido por las variables.
write.csv(
  wdi_inputs,
  output_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Agregar al catálogo la dirección, archivo original y momento de descarga.
download_manifest <- transform(
  indicator_catalog,
  source_url = vapply(downloads, function(item) item$source_url, character(1)),
  source_zip = basename(vapply(downloads, function(item) item$zip_file, character(1))),
  downloaded_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  non_missing_1980_2022 = as.integer(non_missing_counts)
)
# Guardar el manifiesto junto con el panel para preservar la trazabilidad.
write.csv(
  download_manifest,
  manifest_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Informar que todas las descargas y validaciones terminaron correctamente.
message("Descarga compartida WDI terminada.")
# Mostrar la ubicación exacta del panel combinado.
message("Archivo combinado: ", output_file)
# Mostrar el número de países o economías individuales conservados.
message("Países/economías: ", length(unique(wdi_inputs$country_iso3_code)))
# Mostrar el número total de filas país-año del archivo raw.
message("Filas país-año: ", nrow(wdi_inputs))
# Mostrar los conteos de cobertura para revisar el resultado en la consola.
print(non_missing_counts)
