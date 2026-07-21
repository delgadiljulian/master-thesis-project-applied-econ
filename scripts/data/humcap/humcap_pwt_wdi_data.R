# Proposito: preparar el indice de capital humano de Penn World Table como alternativa a WDI.
# Entrada: base pwt10.0 incluida en el paquete pwt10.
# Salida: data/raw/humcap/pwt/humcap_pwt.dta.

# Cargar pwt10 para acceder a la version 10.0 de Penn World Table.
library(pwt10)
# Cargar dplyr para limpiar y ordenar la tabla.
library(dplyr)
# Cargar haven para guardar el resultado en formato Stata.
library(haven)

# Ajuste de ruta del proyecto: carga el helper que encuentra la raiz del repo
# aunque RStudio tenga el working directory en otra carpeta.
# Reunir ubicaciones posibles del helper de rutas del repositorio.
helper_path <- c(
  # Buscar desde el archivo activo cuando se usa RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path))), "project_paths.R")
  },
  # Probar rutas relativas habituales desde diferentes carpetas de ejecucion.
  file.path("scripts", "project_paths.R"),
  file.path("..", "..", "project_paths.R"),
  file.path("..", "project_paths.R"),
  "project_paths.R"
)
# Ejecutar la primera ruta candidata que exista.
source(helper_path[file.exists(helper_path)][1])
# Obtener la ruta absoluta del proyecto.
project_path <- find_project_path()

# Cargar en memoria la base pwt10.0 distribuida por el paquete.
data("pwt10.0")

# Preparar una tabla pais-ano con el indicador de capital humano de PWT.
humcap_pwt <- pwt10.0 %>%
  # Conservar unicamente identificadores, ano y el indice hc.
  select(
    isocode, # Codigo ISO3 del pais.
    country, # Nombre del pais.
    year,    # Ano de la observacion.
    hc       # Indice de capital humano de Penn World Table.
  ) %>%
  # Adoptar los nombres utilizados por el panel de la tesis.
  rename(
    country_iso3_code = isocode,
    HUMCAP = hc
  ) %>%
  # Asegurar que el codigo del pais sea texto simple.
  mutate(
    country_iso3_code = as.character(country_iso3_code)
  ) %>%
  # Eliminar filas sin codigo internacional.
  filter(!is.na(country_iso3_code)) %>%
  # Conservar solamente codigos de tres caracteres.
  filter(nchar(country_iso3_code) == 3) %>%
  # Ordenar la tabla por pais y ano.
  arrange(country_iso3_code, year)

# Abrir el resultado en el visor de RStudio para inspeccion manual opcional.
View(humcap_pwt)

# Convertir a data frame base para evitar atributos especiales del paquete.
humcap_pwt <- as.data.frame(humcap_pwt)
# Eliminar la etiqueta general antes de exportar a Stata.
attr(humcap_pwt, "label") <- NULL
# Construir la ruta del archivo de salida dentro de la fuente PWT.
output_path <- file.path(project_path, "data", "raw", "humcap", "pwt", "humcap_pwt.dta")
# Crear la carpeta de salida y cualquier carpeta padre faltante.
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

# Guardar la alternativa PWT de capital humano en formato Stata.
write_dta(
  humcap_pwt, # Exportar la tabla limpia.
  output_path # Escribirla en data/raw/humcap/pwt/.
)
