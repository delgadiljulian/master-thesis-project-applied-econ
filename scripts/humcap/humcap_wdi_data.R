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

humcap <- WDI(
  country = "all",
  indicator = "HD.HCI.OVRL",
  start = 2010,
  end = 2022
)

humcap <- humcap %>%
  select(iso3c, country, year, HD.HCI.OVRL) %>%
  rename(
    country_iso3_code = iso3c,
    HUMCAP = HD.HCI.OVRL
  ) %>%
  filter(!is.na(country_iso3_code)) %>%
  filter(nchar(country_iso3_code) == 3) %>%
  arrange(country_iso3_code, year)

View(humcap)

# Guardar
humcap <- as.data.frame(humcap)
attr(humcap, "label") <- NULL
output_path <- file.path(project_path, "data", "raw", "humcap", "world_bank_wdi", "humcap.dta")
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

write_dta(
  humcap,
  output_path
)
