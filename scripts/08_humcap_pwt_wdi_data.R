library(pwt10)
library(dplyr)
library(haven)

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

write_dta(
  humcap_pwt,
  "C:/Users/julla/Downloads/1. Tesis de Maestría/data/raw/humcap_pwt.dta"
)
