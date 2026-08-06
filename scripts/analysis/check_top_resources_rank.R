# Check ECI rankings within the panel over time
library(dplyr)

# Helper para localizar la raíz del proyecto desde cualquier directorio
active_path <- ""
if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  active_path <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(e) "")
}
candidates <- c(
  if (nzchar(active_path)) file.path(dirname(dirname(dirname(active_path))), "project_paths.R"),
  file.path("scripts", "project_paths.R"),
  file.path("..", "..", "project_paths.R"),
  "project_paths.R"
)
helper_path <- candidates[file.exists(candidates)][1]
if (!is.na(helper_path)) source(helper_path)

root <- if (exists("find_project_path")) find_project_path() else "."
panel_path <- file.path(root, "data", "processed", "00_master_panel", "master_panel_country_year.csv")

panel <- read.csv(panel_path)

sel_countries <- c("SAU", "NOR", "VEN", "AGO", "LBY", "ARE", "KWT", "QAT", "IRN", "COG", "GAB", "OMN")

# Rank countries in each year within our panel
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
