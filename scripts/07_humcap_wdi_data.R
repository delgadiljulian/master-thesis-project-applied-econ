library(WDI)
library(dplyr)
library(haven)

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

write_dta(
  humcap,
  "C:/Users/julla/Downloads/1. Tesis de Maestría/data/raw/humcap.dta"
)

