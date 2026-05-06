library(WDI)
library(dplyr)
library(haven)

# ---------------------------
# 1. Descargar en bloques
# ---------------------------
fin_1 <- WDI(
  country = "all",
  indicator = "FS.AST.PRVT.GD.ZS",
  start = 1980,
  end = 2005
)

fin_2 <- WDI(
  country = "all",
  indicator = "FS.AST.PRVT.GD.ZS",
  start = 2006,
  end = 2022
)

# ---------------------------
# 2. Unir
# ---------------------------
fin <- bind_rows(fin_1, fin_2)

# ---------------------------
# 3. Limpiar
# ---------------------------
fin <- fin %>%
  select(iso3c, country, year, FS.AST.PRVT.GD.ZS) %>%
  rename(
    country_iso3_code = iso3c,
    FIN = FS.AST.PRVT.GD.ZS
  ) %>%
  mutate(
    country_iso3_code = as.character(country_iso3_code),
    year = as.integer(year)
  ) %>%
  filter(!is.na(country_iso3_code)) %>%
  filter(nchar(country_iso3_code) == 3) %>%
  filter(!grepl(
    "World|income|Arab|Africa|Europe|Asia|IDA|IBRD",
    country
  )) %>%
  arrange(country_iso3_code, year)

# ---------------------------
# 4. Inspección manual
# ---------------------------
View(fin)

# ---------------------------
# 5. Diagnóstico
# ---------------------------
fin %>%
  summarise(
    countries = n_distinct(country_iso3_code),
    years = n_distinct(year)
  )

fin %>%
  group_by(country_iso3_code) %>%
  summarise(obs = n()) %>%
  arrange(obs)

# ---------------------------
# 6. Guardar
# ---------------------------
fin <- as.data.frame(fin)
attr(fin, "label") <- NULL

write_dta(
  fin,
  "C:/Users/julla/Downloads/1. Tesis de Maestría/data/raw/fin.dta"
)

