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
# 1. Descargar en bloques
# ---------------------------
gdppc_1 <- WDI(
  country = "all",
  indicator = "NY.GDP.PCAP.KD",
  start = 1980,
  end = 2005
)

gdppc_2 <- WDI(
  country = "all",
  indicator = "NY.GDP.PCAP.KD",
  start = 2006,
  end = 2022
)

# ---------------------------
# 2. Unir
# ---------------------------
gdppc <- bind_rows(gdppc_1, gdppc_2)

# ---------------------------
# 3. Limpiar (bien hecho)
# ---------------------------
gdppc <- gdppc %>%
  select(iso3c, country, year, NY.GDP.PCAP.KD) %>%
  rename(
    country_iso3_code = iso3c,
    GDPPC = NY.GDP.PCAP.KD
  ) %>%
  mutate(
    country_iso3_code = as.character(country_iso3_code),
    year = as.integer(year),

    # evitar log(0) o NA raros
    GDPPC = log(GDPPC)
  ) %>%
  filter(!is.na(country_iso3_code)) %>%
  filter(nchar(country_iso3_code) == 3) %>%

  # eliminar agregados (otra vez, pero ya deberías automatizarlo)
  filter(!grepl(
    "World|income|Arab|Africa|Europe|Asia|IDA|IBRD",
    country
  )) %>%

  arrange(country_iso3_code, year)

# ---------------------------
# Inspección
# ---------------------------
View(gdppc)

# ---------------------------
# Diagnóstico
# ---------------------------
gdppc %>%
  summarise(
    countries = n_distinct(country_iso3_code),
    years = n_distinct(year)
  )

gdppc %>%
  group_by(country_iso3_code) %>%
  summarise(obs = sum(!is.na(GDPPC))) %>%
  arrange(obs)

# ---------------------------
# 4. Guardar
# ---------------------------
gdppc <- as.data.frame(gdppc)
attr(gdppc, "label") <- NULL
output_path <- file.path(project_path, "data", "raw", "gdppc", "world_bank_wdi", "gdppc.dta")
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

write_dta(
  gdppc,
  output_path
)
