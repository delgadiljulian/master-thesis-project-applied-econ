# Proposito: descargar el PIB per capita real y transformarlo a logaritmos.
# Entrada: indicador WDI NY.GDP.PCAP.KD para 1980-2022.
# Salida: data/raw/gdppc/world_bank_wdi/gdppc.dta.

# Cargar WDI para descargar el indicador del Banco Mundial.
library(WDI)
# Cargar dplyr para unir y transformar el panel.
library(dplyr)
# Cargar haven para guardar el resultado en formato Stata.
library(haven)

# Ajuste de ruta del proyecto: carga el helper que encuentra la raiz del repo
# aunque RStudio tenga el working directory en otra carpeta.
# Reunir posibles ubicaciones del helper de rutas.
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
# Ejecutar la primera copia existente del helper.
source(helper_path[file.exists(helper_path)][1])
# Obtener la ruta absoluta de la raiz del repositorio.
project_path <- find_project_path()

# ---------------------------
# 1. Descargar en bloques
# ---------------------------
# Descargar el primer bloque temporal del PIB per capita real.
gdppc_1 <- WDI(
  country = "all",             # Incluir todos los paises y agregados disponibles.
  indicator = "NY.GDP.PCAP.KD", # PIB per capita en dolares constantes.
  start = 1980,                 # Comenzar el periodo historico.
  end = 2005                    # Cerrar el primer bloque de descarga.
)

# Descargar el segundo bloque temporal sin superponer anos.
gdppc_2 <- WDI(
  country = "all",             # Mantener el universo geografico.
  indicator = "NY.GDP.PCAP.KD", # Mantener la definicion del indicador.
  start = 2006,                 # Continuar despues del primer bloque.
  end = 2022                    # Terminar en el ultimo ano del panel.
)

# ---------------------------
# 2. Unir
# ---------------------------
# Apilar ambos bloques en una sola tabla 1980-2022.
gdppc <- bind_rows(gdppc_1, gdppc_2)

# ---------------------------
# 3. Limpiar y transformar
# ---------------------------
# Preparar el indicador con la estructura requerida por la tesis.
gdppc <- gdppc %>%
  # Conservar identificadores, ano y valor del PIB per capita.
  select(iso3c, country, year, NY.GDP.PCAP.KD) %>%
  # Estandarizar los nombres de las columnas.
  rename(
    country_iso3_code = iso3c,
    GDPPC = NY.GDP.PCAP.KD
  ) %>%
  # Convertir tipos y aplicar el logaritmo natural al PIB per capita.
  mutate(
    country_iso3_code = as.character(country_iso3_code),
    year = as.integer(year),

    # Aplicar logaritmo para usar LOG_GDPPC en las estimaciones.
    GDPPC = log(GDPPC)
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

  # Ordenar el panel por pais y ano.
  arrange(country_iso3_code, year)

# ---------------------------
# Inspección
# ---------------------------
# Abrir la tabla en RStudio para inspeccion manual opcional.
View(gdppc)

# ---------------------------
# Diagnóstico
# ---------------------------
# Resumir el numero de paises y anos presentes.
gdppc %>%
  summarise(
    countries = n_distinct(country_iso3_code), # Unidades geograficas distintas.
    years = n_distinct(year)                   # Anos distintos.
  )

# Contar valores validos por pais para revisar la cobertura temporal.
gdppc %>%
  # Formar grupos por codigo ISO3.
  group_by(country_iso3_code) %>%
  # Contar solo observaciones no faltantes de GDPPC.
  summarise(obs = sum(!is.na(GDPPC))) %>%
  # Mostrar primero los paises con menor cobertura.
  arrange(obs)

# ---------------------------
# 4. Guardar
# ---------------------------
# Convertir a data frame base antes de exportar.
gdppc <- as.data.frame(gdppc)
# Eliminar una etiqueta general innecesaria.
attr(gdppc, "label") <- NULL
# Construir la ruta completa del archivo Stata.
output_path <- file.path(project_path, "data", "raw", "gdppc", "world_bank_wdi", "gdppc.dta")
# Crear la carpeta de salida si aun no existe.
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

# Guardar el panel de PIB per capita logaritmico.
write_dta(
  gdppc,      # Exportar la tabla limpia.
  output_path # Guardarla en data/raw/gdppc/world_bank_wdi/.
)
