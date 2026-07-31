# Script to check ECI over time for top resource-rich countries
library(dplyr)

panel <- read.csv("data/processed/00_master_panel/master_panel_country_year.csv")

# Selected countries
sel_countries <- c("SAU", "NOR", "VEN", "AGO", "LBY", "ARE", "KWT", "QAT", "IRN", "COG", "GAB", "OMN")

df_sel <- panel %>%
  filter(country_iso3_code %in% sel_countries) %>%
  select(country_iso3_code, year, eci) %>%
  arrange(country_iso3_code, year)

print(head(df_sel))
summary(df_sel)
cat("Available years per country:\n")
print(table(df_sel$country_iso3_code))
