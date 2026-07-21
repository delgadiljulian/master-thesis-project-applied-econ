# Proposito: descargar consumo del gobierno como proxy preliminar de la variable fiscal.
# Entrada: indicador WDI NE.CON.GOVT.ZS para 1990-2022.
# Salida: data/raw/fisc/world_bank_wdi/fisc.dta.

# Cargar WDI para consultar la API del Banco Mundial.
library(WDI)
# Cargar dplyr para filtrar, renombrar y seleccionar columnas.
library(dplyr)

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
# Obtener la ruta absoluta de la raiz del repositorio.
project_path <- find_project_path()

# ===============================
# 2. Descargar FISC
# ===============================
# Descargar el consumo final del gobierno como porcentaje del PIB.
df_fisc <- WDI(
  country = "all",            # Solicitar todos los paises y agregados.
  indicator = "NE.CON.GOVT.ZS", # Usar el codigo WDI del consumo gubernamental.
  start = 1990,                # Comenzar en el periodo base de la tesis.
  end = 2022,                  # Terminar en el ultimo ano del panel.
  extra = TRUE                 # Incluir metadatos como la region de cada fila.
)

# Abrir la descarga original en RStudio para una inspeccion manual opcional.
View(df_fisc)

# ===============================
# 3. Eliminar agregados (solo pseudo-países)
# ===============================
# Eliminar filas que WDI identifica explicitamente como agregados.
df_fisc <- df_fisc %>%
  filter(region != "Aggregates")

# ===============================
# 4. Limpieza y renombre
# ===============================
# Estandarizar nombres y conservar solo las columnas necesarias.
df_fisc <- df_fisc %>%
  # Renombrar codigo e indicador con la convencion del proyecto.
  rename(
    iso3 = iso3c,
    year = year,
    FISC = NE.CON.GOVT.ZS
  ) %>%
  # Conservar nombre del pais, codigo, ano y valor fiscal.
  select(country, iso3, year, FISC)

# ===============================
# 5. Panel final
# ===============================
# Abrir el panel final para comprobar visualmente su estructura.
View(df_fisc)

# ===============================
# 6. Guardar como .dta
# ===============================
# Cargar haven en este punto para exportar a formato Stata.
library(haven)

# Construir la ruta completa del archivo de salida.
file_path <- file.path(project_path, "data", "raw", "fisc", "world_bank_wdi", "fisc.dta")
# Crear la carpeta de destino si todavia no existe.
dir.create(dirname(file_path), recursive = TRUE, showWarnings = FALSE)

# Guardar la tabla fiscal limpia en formato Stata.
write_dta(df_fisc, file_path)
