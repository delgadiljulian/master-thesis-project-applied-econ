# CAPA: RAW
# FUENTE: Penn World Table 11.0
# SALIDAS: data/raw/pwt/
# Descargar Penn World Table 11.0 como fuente compartida del proyecto.
#
# Entrada: archivo Stata oficial alojado por la Universidad de Groningen.
# Salidas: archivo original usado por HUMCAP y RER, y manifiesto de trazabilidad.

# Reunir las ubicaciones desde las cuales puede encontrarse el helper de rutas.
helper_path <- c(
  # Buscar desde el archivo activo cuando se ejecuta dentro de RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)))), "project_paths.R")
  },
  # Buscar desde la raíz del repositorio.
  file.path("scripts", "project_paths.R"),
  # Buscar desde scripts/data/raw/pwt/.
  file.path("..", "..", "..", "project_paths.R"),
  # Buscar desde scripts/.
  file.path("..", "project_paths.R"),
  # Buscar en el directorio de trabajo actual como última alternativa.
  "project_paths.R"
)

# Conservar la primera ubicación candidata que exista en el equipo.
helper_path <- helper_path[file.exists(helper_path)][1]
# Detener el script si no fue posible localizar el helper de rutas.
if (is.na(helper_path)) {
  stop("No se pudo encontrar scripts/project_paths.R.")
}
# Ejecutar el helper para habilitar la búsqueda de la raíz del proyecto.
source(helper_path)
# Obtener la ruta absoluta del repositorio.
project_path <- find_project_path()
# Permitir hasta diez minutos para completar la descarga.
options(timeout = 600)

# Registrar el enlace oficial del archivo Stata de PWT 11.0.
source_url <- "https://dataverse.nl/api/access/datafile/554030"
# Construir la carpeta compartida destinada a Penn World Table.
raw_path <- file.path(project_path, "data", "raw", "pwt")
# Crear la carpeta y sus directorios padres si todavía no existen.
dir.create(raw_path, recursive = TRUE, showWarnings = FALSE)
# Construir la ruta donde se conservará intacto el archivo oficial.
output_file <- file.path(raw_path, "pwt110.dta")
# Construir la ruta del manifiesto de procedencia y versión.
manifest_file <- file.path(raw_path, "pwt110_download_manifest.csv")

# Informar en la consola que comienza la descarga oficial.
message("Descargando Penn World Table 11.0...")
# Descargar el archivo Stata siguiendo la redirección segura del repositorio.
download.file(
  url = source_url,
  destfile = output_file,
  mode = "wb",
  quiet = TRUE,
  method = "libcurl"
)
# Detener el script si el archivo no existe o quedó vacío.
if (!file.exists(output_file) || file.info(output_file)$size == 0L) {
  stop("La descarga de PWT 11.0 quedó vacía.")
}
# Detener el script si el tamaño es demasiado pequeño para contener la base oficial.
if (file.info(output_file)$size < 1000000L) {
  stop("El archivo descargado es demasiado pequeño y podría contener una página de error.")
}
# Construir una fila que documenta versión, cobertura y origen del archivo.
download_manifest <- data.frame(
  source = "Penn World Table",
  version = "11.0",
  years_published = "1950-2023",
  source_url = source_url,
  local_file = basename(output_file),
  file_size_bytes = as.numeric(file.info(output_file)$size),
  downloaded_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  stringsAsFactors = FALSE
)
# Guardar el manifiesto junto con el archivo original.
write.csv(
  download_manifest,
  manifest_file,
  row.names = FALSE,
  na = "",
  fileEncoding = "UTF-8"
)
# Informar la ruta final para facilitar una revisión manual.
message("PWT 11.0 guardado en: ", output_file)
# Informar el tamaño descargado como verificación adicional.
message("Tamaño descargado: ", file.info(output_file)$size, " bytes.")
