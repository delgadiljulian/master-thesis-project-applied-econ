library(WDI)
library(dplyr)
library(haven)

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

write_dta(
  rer,
  "C:/Users/julla/Downloads/1. Tesis de Maestría/data/raw/rer.dta"
)
