# Proposito: descargar el credito privado como indicador de desarrollo financiero.
# Entrada: indicador WDI FS.AST.PRVT.GD.ZS para 1980-2022.
# Salida: data/raw/fin/world_bank_wdi/fin.dta.

# Cargar WDI para consultar la API del Banco Mundial.
library(WDI)
# Cargar dplyr para unir, limpiar y diagnosticar el panel.
library(dplyr)
# Cargar haven para guardar el resultado en formato Stata.
library(haven)

# Ajuste de ruta del proyecto: carga el helper que encuentra la raiz del repo
# aunque RStudio tenga el working directory en otra carpeta.
# Reunir posibles ubicaciones del helper que encuentra la raiz del proyecto.
helper_path <- c(
  # Buscar desde el archivo activo cuando se usa RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path))), "project_paths.R")
  },
  # Probar rutas relativas habituales desde la raiz o desde scripts/data/fin/.
  file.path("scripts", "project_paths.R"),
  file.path("..", "..", "project_paths.R"),
  file.path("..", "project_paths.R"),
  "project_paths.R"
)
# Ejecutar la primera ruta candidata que exista.
source(helper_path[file.exists(helper_path)][1])
# Obtener la ruta absoluta del repositorio.
project_path <- find_project_path()

# ---------------------------
# 1. Descargar en bloques
# ---------------------------
# Descargar el primer bloque temporal para reducir el tamano de cada consulta.
fin_1 <- WDI(
  country = "all",                # Solicitar todos los paises y agregados.
  indicator = "FS.AST.PRVT.GD.ZS", # Credito domestico al sector privado (% del PIB).
  start = 1980,                    # Primer ano del periodo historico.
  end = 2005                       # Ultimo ano del primer bloque.
)

# Descargar el segundo bloque temporal hasta el final del panel de la tesis.
fin_2 <- WDI(
  country = "all",                # Mantener el mismo universo geografico.
  indicator = "FS.AST.PRVT.GD.ZS", # Mantener el mismo indicador financiero.
  start = 2006,                    # Continuar sin superponer el primer bloque.
  end = 2022                       # Terminar en el ultimo ano solicitado.
)

# ---------------------------
# 2. Unir
# ---------------------------
# Apilar ambos bloques para formar una sola serie 1980-2022.
fin <- bind_rows(fin_1, fin_2)

# ---------------------------
# 3. Limpiar
# ---------------------------
# Seleccionar y estandarizar las variables necesarias para el panel.
fin <- fin %>%
  # Conservar codigo, nombre, ano y valor del indicador.
  select(iso3c, country, year, FS.AST.PRVT.GD.ZS) %>%
  # Renombrar las columnas con la convencion de la tesis.
  rename(
    country_iso3_code = iso3c,
    FIN = FS.AST.PRVT.GD.ZS
  ) %>%
  # Asegurar tipos consistentes para codigo y ano.
  mutate(
    country_iso3_code = as.character(country_iso3_code),
    year = as.integer(year)
  ) %>%
  # Eliminar filas que no tienen codigo geografico.
  filter(!is.na(country_iso3_code)) %>%
  # Conservar codigos de tres caracteres.
  filter(nchar(country_iso3_code) == 3) %>%
  # Excluir agregados regionales y grupos de ingreso identificables por nombre.
  filter(!grepl(
    "World|income|Arab|Africa|Europe|Asia|IDA|IBRD",
    country
  )) %>%
  # Ordenar las observaciones por pais y ano.
  arrange(country_iso3_code, year)

# ---------------------------
# 4. Inspección manual
# ---------------------------
# Abrir el panel en RStudio para inspeccion manual opcional.
View(fin)

# ---------------------------
# 5. Diagnóstico
# ---------------------------
# Contar cuantos paises y anos distintos quedaron despues de la limpieza.
fin %>%
  summarise(
    countries = n_distinct(country_iso3_code), # Numero de unidades geograficas.
    years = n_distinct(year)                   # Numero de anos disponibles.
  )

# Contar observaciones por pais para detectar paneles especialmente incompletos.
fin %>%
  # Formar un grupo separado para cada codigo ISO3.
  group_by(country_iso3_code) %>%
  # Contar el numero de filas disponibles dentro de cada pais.
  summarise(obs = n()) %>%
  # Mostrar primero los paises con menor cobertura.
  arrange(obs)

# ---------------------------
# 6. Guardar
# ---------------------------
# Convertir a data frame base para evitar atributos incompatibles con Stata.
fin <- as.data.frame(fin)
# Eliminar una etiqueta global innecesaria.
attr(fin, "label") <- NULL
# Construir la ruta completa del archivo final.
output_path <- file.path(project_path, "data", "raw", "fin", "world_bank_wdi", "fin.dta")
# Crear la carpeta de destino si hace falta.
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

# Guardar el panel financiero en formato Stata.
write_dta(
  fin,        # Exportar la tabla limpia.
  output_path # Escribirla en data/raw/fin/world_bank_wdi/.
)
