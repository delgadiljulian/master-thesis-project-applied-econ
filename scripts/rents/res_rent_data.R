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

res_rent <- WDI(
  country = "all",
  indicator = "NY.GDP.TOTL.RT.ZS",
  start = 1980,
  end = 2022
)

res_rent <- res_rent %>%
  select(iso3c, country, year, NY.GDP.TOTL.RT.ZS) %>%
  rename(
    country_iso3_code = iso3c,
    RES_RENT = NY.GDP.TOTL.RT.ZS
  ) %>%
  mutate(
    country_iso3_code = as.character(country_iso3_code),
    year = as.integer(year)
  ) %>%
  filter(!is.na(country_iso3_code)) %>%
  filter(nchar(country_iso3_code) == 3) %>%

  # eliminar agregados (otra vez… sí, otra vez)
  filter(!grepl(
    "World|income|Arab|Africa|Europe|Asia|IDA|IBRD",
    country
  )) %>%

  arrange(country_iso3_code, year)

# ---------------------------
# Inspección
# ---------------------------
View(res_rent)

# ---------------------------
# Diagnóstico mínimo
# ---------------------------
res_rent %>%
  summarise(
    countries = n_distinct(country_iso3_code),
    years = n_distinct(year)
  )

# ---------------------------
# Limpieza atributos (ok, pero no era el problema crítico)
# ---------------------------
res_rent <- as.data.frame(res_rent)
attr(res_rent, "label") <- NULL

# ---------------------------
# Guardar
# ---------------------------
output_path <- file.path(project_path, "data", "raw", "rents", "world_bank_wdi", "res_rent.dta")
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

write_dta(
  res_rent,
  output_path
)
