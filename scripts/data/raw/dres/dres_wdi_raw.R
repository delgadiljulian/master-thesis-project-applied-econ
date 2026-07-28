# CAPA: RAW
# VARIABLE: DRES
# SALIDAS: data/raw/dres/
# Descargar insumos WDI para validar la construcción de DRES.
#
# Este script solo prepara la capa raw utilizada para contrastar los resultados.
# La construcción principal con Atlas y la muestra única de 20 % se realiza
# mediante scripts/data/processed/dres/dres_processed.R.

# Reunir varias ubicaciones posibles del archivo que identifica la raiz del repo.
helper_path <- c(
  # Si el script esta abierto en RStudio, buscar el helper desde su ubicacion.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)))), "project_paths.R")
  },
  # Probar esta ruta cuando R se ejecuta desde la raiz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Probar esta ruta cuando R se ejecuta desde scripts/data/raw/dres/.
  file.path("..", "..", "..", "project_paths.R"),
  # Probar esta ruta cuando R se ejecuta desde scripts/.
  file.path("..", "project_paths.R"),
  # Probar esta ruta cuando el helper esta en el directorio de trabajo actual.
  "project_paths.R"
)

# Conservar solamente la primera ruta candidata que exista en el equipo.
helper_path <- helper_path[file.exists(helper_path)][1]
# Detener la ejecucion con un mensaje claro si no se encontro el helper.
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}

# Ejecutar el helper para que su funcion quede disponible en esta sesion de R.
source(helper_path)
# Obtener la ruta absoluta de la raiz del repositorio.
project_path <- find_project_path()

# Permitir hasta diez minutos para cada descarga antes de declarar un error.
options(timeout = 600)

# Definir los seis anos que la metodologia utiliza como periodo base de DRES.
base_years <- 1990:1995

# Crear un catalogo que relaciona los nombres internos con los codigos WDI.
indicator_catalog <- data.frame(
  # Asignar nombres legibles a las cuatro variables que tendra el archivo final.
  variable = c(
    "fuel_exports_share",                 # Participacion de combustibles exportados.
    "ores_metals_exports_share",          # Participacion de minerales y metales.
    "merchandise_exports_current_usd",    # Exportaciones totales en dolares corrientes.
    "population_total"                    # Poblacion total del pais.
  ),
  # Registrar el codigo oficial usado por la API del Banco Mundial.
  indicator_code = c(
    "TX.VAL.FUEL.ZS.UN",  # Fuel exports (% of merchandise exports).
    "TX.VAL.MMTL.ZS.UN",  # Ores and metals exports (% of merchandise exports).
    "TX.VAL.MRCH.CD.WT",  # Merchandise exports (current US$).
    "SP.POP.TOTL"         # Population, total.
  ),
  # Guardar una descripcion que luego aparecera en el manifiesto de descarga.
  description = c(
    "Fuel exports (% of merchandise exports)",
    "Ores and metals exports (% of merchandise exports)",
    "Merchandise exports (current US$)",
    "Population, total"
  ),
  # Evitar que R convierta automaticamente los textos en variables categoricas.
  stringsAsFactors = FALSE
)

# Construir la ruta donde se guardaran los insumos raw combinados de DRES.
raw_path <- file.path(
  project_path,                 # Comenzar desde la raiz del proyecto.
  "data",                      # Entrar en la carpeta general de datos.
  "raw",                       # Usar la capa que conserva datos sin transformar.
  "dres",                      # Entrar en los insumos de la variable DRES.
  "world_bank_wdi"             # Separar los archivos obtenidos del Banco Mundial.
)
# Construir una subcarpeta para conservar los ZIP originales de cada indicador.
source_zip_path <- file.path(raw_path, "source_zips")

# Crear la carpeta y sus padres si todavia no existen.
dir.create(source_zip_path, recursive = TRUE, showWarnings = FALSE)

# Definir una funcion que encuentra en que fila comienza el encabezado de un CSV.
find_csv_header <- function(path, required_fields) {
  # Leer solo las primeras doce lineas porque los archivos WDI incluyen notas iniciales.
  first_lines <- readLines(path, n = 12, warn = FALSE, encoding = "UTF-8")
  # Identificar la primera linea que contiene todos los nombres de columna esperados.
  header_line <- which(vapply(
    # Revisar cada una de las lineas iniciales del archivo.
    first_lines,
    # Confirmar que todos los campos requeridos aparezcan en la linea evaluada.
    function(line) all(vapply(required_fields, grepl, logical(1), x = line, fixed = TRUE)),
    # Indicar que cada revision debe devolver un unico valor verdadero o falso.
    logical(1)
  ))[1]

  # Detener el script si el formato del archivo cambio y no se encontro el encabezado.
  if (is.na(header_line)) {
    stop("No se encontro el encabezado esperado en: ", path)
  }

  # Devolver cuantas lineas debe omitir read.csv antes de leer los nombres de columna.
  header_line - 1L
}

# Definir una funcion que descarga, valida y organiza un indicador WDI.
download_wdi_indicator <- function(indicator_code, variable_name, years, zip_dir) {
  # Construir la URL oficial de descarga masiva para el indicador solicitado.
  url <- paste0(
    "https://api.worldbank.org/v2/en/indicator/",
    indicator_code,
    "?downloadformat=csv"
  )

  # Reemplazar los puntos del codigo para obtener un nombre de archivo compatible.
  zip_name <- paste0(gsub("\\.", "_", indicator_code), ".zip")
  # Unir la carpeta de destino con el nombre asignado al ZIP.
  zip_file <- file.path(zip_dir, zip_name)

  # Informar en la consola cual indicador esta comenzando a descargarse.
  message("Descargando ", indicator_code, "...")
  # Descargar el ZIP original desde la API del Banco Mundial.
  download.file(
    url = url,             # Usar la direccion construida para este indicador.
    destfile = zip_file,   # Guardar el resultado en la carpeta de ZIP originales.
    mode = "wb",          # Escribir en modo binario para no corromper el ZIP.
    quiet = TRUE,          # Evitar imprimir una barra de progreso extensa.
    method = "libcurl"    # Utilizar el metodo de descarga HTTPS de R.
  )

  # Verificar que el archivo exista y que su tamano sea mayor que cero bytes.
  if (!file.exists(zip_file) || file.info(zip_file)$size == 0) {
    stop("La descarga quedo vacia para: ", indicator_code)
  }

  # Consultar la lista de archivos internos del ZIP sin extraerlos todavia.
  archive_files <- utils::unzip(zip_file, list = TRUE)$Name
  # Localizar el CSV principal que contiene las observaciones del indicador.
  data_entry <- grep("^API_.*\\.csv$", archive_files, value = TRUE)
  # Localizar el CSV que identifica paises, regiones y agregados geograficos.
  country_entry <- grep("^Metadata_Country_.*\\.csv$", archive_files, value = TRUE)

  # Exigir un unico archivo de datos y un unico archivo de metadatos de paises.
  if (length(data_entry) != 1L || length(country_entry) != 1L) {
    stop("El ZIP de ", indicator_code, " no tiene la estructura esperada.")
  }

  # Crear una carpeta temporal para extraer solo los archivos necesarios.
  extract_path <- tempfile(pattern = "wdi_extract_")
  # Crear fisicamente esa carpeta temporal.
  dir.create(extract_path)
  # Programar su eliminacion automatica cuando la funcion termine o falle.
  on.exit(unlink(extract_path, recursive = TRUE, force = TRUE), add = TRUE)

  # Extraer el CSV de datos y el CSV de metadatos dentro de la carpeta temporal.
  utils::unzip(
    zip_file,                              # Leer el ZIP que se acaba de descargar.
    files = c(data_entry, country_entry),  # Extraer solamente los dos CSV requeridos.
    exdir = extract_path                   # Guardarlos en la carpeta temporal.
  )

  # Construir la ruta completa del CSV que contiene las observaciones.
  data_file <- file.path(extract_path, data_entry)
  # Construir la ruta completa del CSV que contiene los metadatos de paises.
  country_file <- file.path(extract_path, country_entry)

  # Calcular cuantas lineas iniciales deben omitirse en el archivo de datos.
  data_skip <- find_csv_header(
    data_file,                                            # Revisar el CSV principal.
    c("Country Name", "Country Code", "Indicator Code") # Buscar estas columnas.
  )
  # Calcular cuantas lineas iniciales deben omitirse en los metadatos de paises.
  country_skip <- find_csv_header(
    country_file,                 # Revisar el CSV de metadatos.
    c("Country Code", "Region") # Buscar estas columnas.
  )

  # Leer las observaciones del indicador como una tabla de R.
  raw_data <- read.csv(
    data_file,                 # Abrir el CSV principal extraido.
    skip = data_skip,          # Omitir las notas previas al encabezado.
    check.names = FALSE,       # Conservar nombres como los anos 1990, 1991, etc.
    stringsAsFactors = FALSE,  # Mantener los textos como texto simple.
    na.strings = c("", "..") # Interpretar celdas vacias y ".." como faltantes.
  )
  # Leer los metadatos que permiten distinguir paises de agregados regionales.
  country_metadata <- read.csv(
    country_file,              # Abrir el CSV de metadatos extraido.
    skip = country_skip,       # Omitir sus notas previas al encabezado.
    check.names = FALSE,       # Conservar exactamente los nombres originales.
    stringsAsFactors = FALSE,  # Mantener los textos como texto simple.
    na.strings = c("", "..") # Convertir codigos de ausencia en valores faltantes.
  )

  # Confirmar que el archivo descargado corresponde al codigo solicitado.
  if (!indicator_code %in% unique(raw_data[["Indicator Code"]])) {
    stop("El archivo descargado no corresponde a: ", indicator_code)
  }

  # Convertir los anos solicitados a texto para compararlos con los nombres de columna.
  year_names <- as.character(years)
  # Identificar si alguno de los anos solicitados no aparece en el archivo.
  missing_years <- setdiff(year_names, names(raw_data))
  # Detener la ejecucion si el indicador no incluye todo el periodo requerido.
  if (length(missing_years) > 0) {
    stop(
      "Faltan anos en la descarga de ",
      indicator_code,
      ": ",
      paste(missing_years, collapse = ", ")
    )
  }

  # Conservar codigos cuya region no esta vacia, criterio WDI para paises/economias.
  valid_country_codes <- country_metadata[["Country Code"]][
    !is.na(country_metadata[["Region"]]) &
      nzchar(trimws(country_metadata[["Region"]]))
  ]

  # Crear una tabla unica que relaciona cada codigo ISO3 con el nombre del pais.
  country_map <- unique(data.frame(
    country_iso3_code = raw_data[["Country Code"]], # Copiar el codigo del pais.
    country = raw_data[["Country Name"]],           # Copiar el nombre del pais.
    # Mantener ambos campos como texto y no como factores.
    stringsAsFactors = FALSE
  ))
  # Eliminar agregados regionales y codigos que no tengan tres letras mayusculas.
  country_map <- country_map[
    country_map$country_iso3_code %in% valid_country_codes &
      grepl("^[A-Z]{3}$", country_map$country_iso3_code),
    ,             # Conservar todas las columnas del mapa.
    drop = FALSE  # Mantener el resultado como data frame aunque quede una fila.
  ]

  # Convertir la tabla ancha de anos en un panel largo con una fila por pais y ano.
  long_data <- do.call(rbind, lapply(years, function(year_value) {
    # Crear una tabla para el ano que se esta recorriendo.
    data.frame(
      country_iso3_code = raw_data[["Country Code"]], # Repetir el codigo de cada pais.
      year = as.integer(year_value),                   # Registrar el ano como entero.
      # Convertir los valores a numeros y tratar textos no numericos como faltantes.
      value = suppressWarnings(as.numeric(raw_data[[as.character(year_value)]])),
      # Evitar conversiones automaticas de texto a categorias.
      stringsAsFactors = FALSE
    )
  }))
  # Cambiar el nombre generico "value" por el nombre descriptivo del indicador.
  names(long_data)[names(long_data) == "value"] <- variable_name

  # Conservar solamente filas correspondientes a paises/economias validos.
  long_data <- long_data[
    long_data$country_iso3_code %in% country_map$country_iso3_code,
    ,             # Conservar todas las columnas del panel.
    drop = FALSE  # Mantener el resultado como data frame.
  ]

  # Devolver juntos los datos limpios y la informacion necesaria para el manifiesto.
  list(
    data = long_data,        # Panel largo del indicador.
    country_map = country_map, # Correspondencia entre codigo y nombre del pais.
    url = url,               # Direccion utilizada para la descarga.
    zip_file = zip_file      # Ruta local del ZIP original.
  )
}

# Recorrer las cuatro filas del catalogo y descargar cada indicador por separado.
downloads <- lapply(seq_len(nrow(indicator_catalog)), function(index) {
  # Llamar la funcion usando el codigo y el nombre definidos en la fila actual.
  download_wdi_indicator(
    indicator_code = indicator_catalog$indicator_code[index], # Codigo WDI que se consulta.
    variable_name = indicator_catalog$variable[index],         # Nombre de la columna final.
    years = base_years,                                        # Periodo 1990-1995.
    zip_dir = source_zip_path                                  # Carpeta para los ZIP originales.
  )
})

# Unir los cuatro paneles usando codigo de pais y ano como llave comun.
dres_inputs <- Reduce(
  # Definir como se combinara cada panel nuevo con el resultado acumulado.
  function(left, right) {
    # Hacer una union completa para no eliminar observaciones con datos faltantes.
    merge(
      left,                                     # Panel acumulado hasta este punto.
      right,                                    # Siguiente indicador que se agregara.
      by = c("country_iso3_code", "year"),     # Llaves que identifican cada observacion.
      all = TRUE,                               # Conservar filas presentes en cualquiera.
      sort = FALSE                              # Posponer el ordenamiento hasta el final.
    )
  },
  # Extraer solamente la tabla de datos de cada resultado descargado.
  lapply(downloads, function(item) item$data)
)

# Apilar los mapas de paises devueltos por las cuatro descargas y eliminar repeticiones.
country_map <- unique(do.call(rbind, lapply(downloads, function(item) {
  # Extraer el mapa codigo-nombre de cada indicador.
  item$country_map
})))
# Conservar una sola fila por codigo ISO3 en el mapa consolidado.
country_map <- country_map[!duplicated(country_map$country_iso3_code), ]

# Incorporar el nombre del pais al panel combinado de indicadores.
dres_inputs <- merge(
  country_map,                # Tabla que contiene codigo y nombre del pais.
  dres_inputs,                # Panel combinado de los cuatro indicadores.
  by = "country_iso3_code",  # Unir ambas tablas mediante el codigo ISO3.
  all.y = TRUE,               # Conservar todas las observaciones del panel.
  sort = FALSE                # Mantener temporalmente el orden existente.
)

# Definir un orden claro y estable para las columnas del archivo final.
ordered_columns <- c(
  "country_iso3_code",       # Primera columna: codigo internacional del pais.
  "country",                 # Segunda columna: nombre legible del pais.
  "year",                    # Tercera columna: ano de la observacion.
  indicator_catalog$variable # Columnas restantes: los cuatro indicadores WDI.
)
# Reordenar fisicamente las columnas segun la lista anterior.
dres_inputs <- dres_inputs[, ordered_columns]
# Ordenar las filas alfabeticamente por codigo de pais y cronologicamente por ano.
dres_inputs <- dres_inputs[order(dres_inputs$country_iso3_code, dres_inputs$year), ]
# Eliminar los numeros de fila heredados para que no se exporten como identificadores.
row.names(dres_inputs) <- NULL

# Verificar que cada combinacion de pais y ano aparezca una sola vez.
if (anyDuplicated(dres_inputs[c("country_iso3_code", "year")]) > 0) {
  stop("La descarga contiene llaves pais-ano duplicadas.")
}

# Obtener la lista ordenada de anos realmente presentes en el panel combinado.
downloaded_years <- sort(unique(dres_inputs$year))
# Confirmar que esa lista coincida exactamente con el periodo base esperado.
if (!identical(downloaded_years, as.integer(base_years))) {
  stop("Los anos descargados no coinciden con 1990-1995.")
}

# Contar cuantas observaciones validas tiene cada uno de los cuatro indicadores.
non_missing_counts <- vapply(
  # Recorrer los nombres de variables definidos en el catalogo.
  indicator_catalog$variable,
  # Sumar las celdas cuyo valor no esta ausente en cada columna.
  function(variable_name) sum(!is.na(dres_inputs[[variable_name]])),
  # Indicar que cada conteo debe ser un unico numero entero.
  integer(1)
)

# Impedir la escritura de resultados si algun indicador quedo totalmente vacio.
if (any(non_missing_counts == 0)) {
  stop(
    "Uno o mas indicadores no tienen observaciones: ",
    paste(names(non_missing_counts)[non_missing_counts == 0], collapse = ", ")
  )
}

# Construir la ruta del CSV que reunira todas las observaciones pais-ano.
output_file <- file.path(raw_path, "dres_wdi_inputs_1990_1995.csv")
# Construir la ruta del CSV que documentara las fuentes descargadas.
manifest_file <- file.path(raw_path, "dres_wdi_download_manifest.csv")

# Guardar el panel combinado en un archivo CSV facil de leer desde otros programas.
write.csv(
  dres_inputs,             # Exportar la tabla final de insumos DRES.
  output_file,             # Escribirla en la ruta construida anteriormente.
  row.names = FALSE,       # No crear una columna adicional con numeros de fila.
  na = "",                # Representar los datos faltantes con celdas vacias.
  fileEncoding = "UTF-8"  # Usar una codificacion compatible con nombres internacionales.
)

# Agregar al catalogo la URL, el ZIP y la fecha de cada descarga.
download_manifest <- transform(
  indicator_catalog, # Partir de los nombres, codigos y descripciones originales.
  # Extraer la URL utilizada por cada llamada a la funcion de descarga.
  source_url = vapply(downloads, function(item) item$url, character(1)),
  # Extraer solo el nombre, sin la ruta completa, de cada ZIP guardado.
  source_zip = basename(vapply(downloads, function(item) item$zip_file, character(1))),
  # Registrar el momento de ejecucion usando la zona horaria universal UTC.
  downloaded_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
)

# Guardar el manifiesto para documentar la procedencia de los datos raw.
write.csv(
  download_manifest,       # Exportar la tabla de trazabilidad de las fuentes.
  manifest_file,           # Escribirla junto al panel combinado.
  row.names = FALSE,       # No agregar numeros de fila al CSV.
  na = "",                # Representar cualquier faltante como una celda vacia.
  fileEncoding = "UTF-8"  # Conservar correctamente todos los caracteres de texto.
)

# Informar que todas las etapas terminaron sin errores.
message("Descarga DRES terminada.")
# Mostrar la ubicacion exacta del archivo combinado.
message("Archivo combinado: ", output_file)
# Mostrar cuantos paises o economias diferentes contiene el panel.
message("Paises/economias: ", length(unique(dres_inputs$country_iso3_code)))
# Mostrar el numero total de observaciones pais-ano.
message("Filas pais-ano: ", nrow(dres_inputs))
# Introducir en consola el resumen de cobertura por indicador.
message("Cobertura no faltante:")
# Imprimir los cuatro conteos de observaciones no faltantes.
print(non_missing_counts)
