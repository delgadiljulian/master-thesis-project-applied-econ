# Proposito: descargar el indice de capital humano del Banco Mundial y guardarlo en Stata.
# Entrada: API de World Development Indicators para 2010-2022.
# Salida: data/raw/humcap/world_bank_wdi/humcap.dta.

# Cargar WDI para consultar la API del Banco Mundial.
library(WDI)
# Cargar dplyr para seleccionar, renombrar, filtrar y ordenar columnas.
library(dplyr)
# Cargar haven para escribir el resultado en formato .dta de Stata.
library(haven)

# Ajuste de ruta del proyecto: carga el helper que encuentra la raiz del repo
# aunque RStudio tenga el working directory en otra carpeta.
# Reunir ubicaciones posibles del helper de rutas del proyecto.
helper_path <- c(
  # Buscar desde el archivo activo cuando el script se ejecuta en RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path))), "project_paths.R")
  },
  # Probar rutas relativas habituales desde la raiz o desde scripts/data/humcap/.
  file.path("scripts", "project_paths.R"),
  file.path("..", "..", "project_paths.R"),
  file.path("..", "project_paths.R"),
  "project_paths.R"
)
# Ejecutar la primera copia del helper que exista.
source(helper_path[file.exists(helper_path)][1])
# Obtener la ruta absoluta de la raiz del repositorio.
project_path <- find_project_path()

# Descargar el indicador general de capital humano para todos los paises disponibles.
humcap <- WDI(
  country = "all",          # Solicitar todos los paises y agregados disponibles.
  indicator = "HD.HCI.OVRL", # Usar el codigo WDI del Human Capital Index.
  start = 2010,              # Comenzar en el primer ano solicitado.
  end = 2022                 # Terminar en el ultimo ano del panel de la tesis.
)

# Conservar las columnas necesarias y normalizar sus nombres.
humcap <- humcap %>%
  # Seleccionar identificadores, ano y valor del indicador.
  select(iso3c, country, year, HD.HCI.OVRL) %>%
  # Usar los nombres estandarizados del panel de la tesis.
  rename(
    country_iso3_code = iso3c,
    HUMCAP = HD.HCI.OVRL
  ) %>%
  # Eliminar filas sin codigo internacional de pais.
  filter(!is.na(country_iso3_code)) %>%
  # Conservar codigos de tres caracteres y excluir la mayoria de agregados WDI.
  filter(nchar(country_iso3_code) == 3) %>%
  # Ordenar primero por pais y despues por ano.
  arrange(country_iso3_code, year)

# Abrir la tabla en el visor de RStudio para una inspeccion manual opcional.
View(humcap)

# Convertir el objeto a data frame base para evitar atributos incompatibles con Stata.
humcap <- as.data.frame(humcap)
# Eliminar una etiqueta global que no aporta informacion al archivo final.
attr(humcap, "label") <- NULL
# Construir la ruta completa del archivo de salida.
output_path <- file.path(project_path, "data", "raw", "humcap", "world_bank_wdi", "humcap.dta")
# Crear la carpeta de destino si todavia no existe.
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

# Escribir el panel limpio en formato Stata.
write_dta(
  humcap,      # Guardar la tabla de capital humano.
  output_path  # Usar la ruta definida dentro de data/raw/humcap/.
)
