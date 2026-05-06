library(WDI)
library(dplyr)
library(haven)

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

write_dta(
  gdppc,
  "C:/Users/julla/Downloads/1. Tesis de Maestría/data/raw/gdppc.dta"
)
