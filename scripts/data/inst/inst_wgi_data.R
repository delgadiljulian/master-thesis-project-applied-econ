# Proposito: convertir la descarga original de Worldwide Governance Indicators a Stata.
# Entrada: CSV original almacenado en data/raw/inst/world_bank_wgi/.
# Salida: data/raw/inst/world_bank_wgi/inst_raw.dta.

# Cargar readr para leer el CSV con control explicito de codificacion.
library(readr)
# Cargar haven para escribir la tabla en formato Stata.
library(haven)
# Cargar janitor para normalizar los nombres de las columnas.
library(janitor)

# Ajuste de ruta del proyecto: carga el helper que encuentra la raiz del repo
# aunque RStudio tenga el working directory en otra carpeta.
# Reunir las ubicaciones posibles del helper de rutas.
helper_path <- c(
  # Buscar desde el archivo activo cuando se ejecuta en RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path))), "project_paths.R")
  },
  # Probar rutas relativas habituales desde diferentes directorios de trabajo.
  file.path("scripts", "project_paths.R"),
  file.path("..", "..", "project_paths.R"),
  file.path("..", "project_paths.R"),
  "project_paths.R"
)
# Ejecutar la primera copia del helper encontrada.
source(helper_path[file.exists(helper_path)][1])
# Obtener la ruta absoluta de la raiz del proyecto.
project_path <- find_project_path()

# Construir la ruta del CSV original descargado de WGI.
file_path <- file.path(
  project_path, # Comenzar desde la raiz del repositorio.
  "data", "raw", "inst", "world_bank_wgi", # Entrar en la fuente institucional.
  "0a8b502f-696a-4678-91cf-132f60b7a8e0_Data.csv" # Abrir el archivo original.
)

# Leer el CSV usando latin1 para interpretar correctamente caracteres especiales.
df_raw <- read_csv(file_path, locale = locale(encoding = "latin1"))

# Convertir los nombres de columna a minusculas y guiones bajos compatibles con Stata.
df_raw <- janitor::clean_names(df_raw)

# Construir la ruta del archivo Stata que conservara la misma informacion raw.
output_path <- file.path(project_path, "data", "raw", "inst", "world_bank_wgi", "inst_raw.dta")
# Crear la carpeta de destino si todavia no existe.
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
# Escribir la tabla con nombres normalizados en formato Stata.
write_dta(df_raw, output_path)

# Abrir el resultado en el visor de RStudio para una inspeccion manual opcional.
View(df_raw)
