library(WDI)
library(dplyr)
library(haven)

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
write_dta(
  res_rent,
  "C:/Users/julla/Downloads/1. Tesis de Maestría/data/raw/res_rent.dta"
)
