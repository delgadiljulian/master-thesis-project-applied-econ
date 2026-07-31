# Check ECI rankings within the panel over time
library(dplyr)

panel <- read.csv("data/processed/00_master_panel/master_panel_country_year.csv")

sel_countries <- c("SAU", "NOR", "VEN", "AGO", "LBY", "ARE", "KWT", "QAT", "IRN", "COG", "GAB", "OMN")

# Rank countries in each year within our 55 panel
ranked_panel <- panel %>%
  group_by(year) %>%
  mutate(
    # rank of eci within the panel (rank 1 is the highest ECI)
    eci_rank = rank(-eci, ties.method = "first")
  ) %>%
  ungroup()

df_sel <- ranked_panel %>%
  filter(country_iso3_code %in% sel_countries) %>%
  select(country_iso3_code, year, eci, eci_rank) %>%
  arrange(country_iso3_code, year)

print(head(df_sel, 15))
