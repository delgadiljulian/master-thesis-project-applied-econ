library(WDI)
library(dplyr)
library(haven)

# Ajuste de ruta del proyecto: carga el helper que encuentra la raiz del repo
# aunque RStudio tenga el working directory en otra carpeta.
helper_path <- c(
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)), "project_paths.R")
  },
  file.path("scripts", "project_paths.R"),
  file.path("..", "project_paths.R"),
  "project_paths.R"
)
source(helper_path[file.exists(helper_path)][1])
project_path <- find_project_path()

# ---------------------------
# 1. Descargar
# ---------------------------
patents <- WDI(
  country = "all",
  indicator = "IP.PAT.RESD",
  start = 1980,
  end = 2022
)

# ---------------------------
# 2. Limpiar
# ---------------------------
patents <- patents %>%
  select(iso3c, country, year, IP.PAT.RESD) %>%
  rename(
    country_iso3_code = iso3c,
    PATENTS = IP.PAT.RESD
  ) %>%
  mutate(
    country_iso3_code = as.character(country_iso3_code),
    year = as.integer(year),
    PATENTS = log1p(PATENTS)
  ) %>%
  filter(!is.na(country_iso3_code)) %>%
  filter(nchar(country_iso3_code) == 3) %>%

  # eliminar agregados
  filter(!grepl(
    "World|income|Arab|Africa|Europe|Asia|IDA|IBRD",
    country
  )) %>%

  arrange(country_iso3_code, year)

# ---------------------------
# 3. Inspección
# ---------------------------
View(patents)

# ---------------------------
# 4. Diagnóstico
# ---------------------------
patents %>%
  summarise(
    countries = n_distinct(country_iso3_code),
    years = n_distinct(year)
  )

patents %>%
  group_by(country_iso3_code) %>%
  summarise(obs = n()) %>%
  arrange(obs)

# ---------------------------
# 5. Guardar
# ---------------------------
patents <- as.data.frame(patents)
attr(patents, "label") <- NULL
output_path <- file.path(project_path, "data", "raw", "innov", "world_bank_wdi", "patents.dta")
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

write_dta(
  patents,
  output_path
)
