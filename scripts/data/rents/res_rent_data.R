# Proposito: descargar las rentas totales de recursos naturales como porcentaje del PIB.
# Entrada: indicador WDI NY.GDP.TOTL.RT.ZS para 1980-2022.
# Salida: data/raw/rents/world_bank_wdi/res_rent.dta.

# Cargar WDI para consultar la API del Banco Mundial.
library(WDI)
# Cargar dplyr para limpiar y resumir la tabla.
library(dplyr)
# Cargar haven para exportar el resultado a Stata.
library(haven)

# Ajuste de ruta del proyecto: carga el helper que encuentra la raiz del repo
# aunque RStudio tenga el working directory en otra carpeta.
# Reunir ubicaciones posibles del helper de rutas.
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
# Ejecutar la primera ubicacion del helper que exista.
source(helper_path[file.exists(helper_path)][1])
# Obtener la ruta absoluta del repositorio.
project_path <- find_project_path()

# Descargar las rentas totales de recursos naturales para todos los paises disponibles.
res_rent <- WDI(
  country = "all",               # Incluir todos los paises y agregados.
  indicator = "NY.GDP.TOTL.RT.ZS", # Rentas naturales totales como % del PIB.
  start = 1980,                   # Comenzar el periodo historico.
  end = 2022                      # Terminar en el ultimo ano del panel.
)

# Preparar la variable de rentas para integrarla posteriormente al panel.
res_rent <- res_rent %>%
  # Conservar identificadores, ano y valor del indicador.
  select(iso3c, country, year, NY.GDP.TOTL.RT.ZS) %>%
  # Estandarizar los nombres de codigo e indicador.
  rename(
    country_iso3_code = iso3c,
    RES_RENT = NY.GDP.TOTL.RT.ZS
  ) %>%
  # Convertir codigo y ano a tipos consistentes.
  mutate(
    country_iso3_code = as.character(country_iso3_code),
    year = as.integer(year)
  ) %>%
  # Eliminar filas sin codigo geografico.
  filter(!is.na(country_iso3_code)) %>%
  # Conservar codigos de tres caracteres.
  filter(nchar(country_iso3_code) == 3) %>%

  # Excluir agregados regionales y grupos de ingreso por su nombre.
  filter(!grepl(
    "World|income|Arab|Africa|Europe|Asia|IDA|IBRD",
    country
  )) %>%

  # Ordenar las observaciones por pais y ano.
  arrange(country_iso3_code, year)

# ---------------------------
# Inspección
# ---------------------------
# Abrir la tabla en RStudio para inspeccion manual opcional.
View(res_rent)

# ---------------------------
# Diagnóstico mínimo
# ---------------------------
# Contar paises y anos distintos como diagnostico basico de cobertura.
res_rent %>%
  summarise(
    countries = n_distinct(country_iso3_code), # Unidades geograficas distintas.
    years = n_distinct(year)                   # Anos distintos.
  )

# ---------------------------
# Convertir a data frame base para evitar atributos incompatibles con Stata.
# ---------------------------
# Realizar la conversion de clase antes de exportar.
res_rent <- as.data.frame(res_rent)
# Eliminar una etiqueta global innecesaria.
attr(res_rent, "label") <- NULL

# ---------------------------
# Guardar
# ---------------------------
# Construir la ruta completa del archivo final.
output_path <- file.path(project_path, "data", "raw", "rents", "world_bank_wdi", "res_rent.dta")
# Crear la carpeta de destino si no existe.
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

# Guardar el panel de rentas naturales en formato Stata.
write_dta(
  res_rent,   # Exportar la tabla limpia.
  output_path # Guardarla en data/raw/rents/world_bank_wdi/.
)
