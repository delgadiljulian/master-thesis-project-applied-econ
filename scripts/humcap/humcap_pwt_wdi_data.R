library(pwt10)
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

data("pwt10.0")

humcap_pwt <- pwt10.0 %>%
  select(
    isocode,
    country,
    year,
    hc
  ) %>%
  rename(
    country_iso3_code = isocode,
    HUMCAP = hc
  ) %>%
  mutate(
    country_iso3_code = as.character(country_iso3_code)
  ) %>%
  filter(!is.na(country_iso3_code)) %>%
  filter(nchar(country_iso3_code) == 3) %>%
  arrange(country_iso3_code, year)

View(humcap_pwt)

# Guardar
humcap_pwt <- as.data.frame(humcap_pwt)
attr(humcap_pwt, "label") <- NULL
output_path <- file.path(project_path, "data", "raw", "humcap", "pwt", "humcap_pwt.dta")
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

write_dta(
  humcap_pwt,
  output_path
)
