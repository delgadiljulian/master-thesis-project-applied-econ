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

rer <- WDI(
  country = "all",
  indicator = "PX.REX.REER",
  start = 1980,
  end = 2022
)

rer <- rer %>%
  select(iso3c, country, year, PX.REX.REER) %>%
  rename(
    country_iso3_code = iso3c,
    RER = PX.REX.REER
  ) %>%
  mutate(
    country_iso3_code = as.character(country_iso3_code),
    year = as.integer(year)
  ) %>%
  filter(!is.na(country_iso3_code)) %>%
  filter(nchar(country_iso3_code) == 3) %>%

  # eliminar agregados (sí, otra vez)
  filter(!grepl(
    "World|income|Arab|Africa|Europe|Asia|IDA|IBRD",
    country
  )) %>%

  arrange(country_iso3_code, year)

# inspección
View(rer)

# diagnóstico real (aquí se ve el problema de verdad)
rer %>%
  group_by(country_iso3_code) %>%
  summarise(obs = sum(!is.na(RER))) %>%
  arrange(obs)

# guardar
rer <- as.data.frame(rer)
attr(rer, "label") <- NULL
output_path <- file.path(project_path, "data", "raw", "rer", "world_bank_wdi", "rer.dta")
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

write_dta(
  rer,
  output_path
)
