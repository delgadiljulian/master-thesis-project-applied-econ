# Script to rename figure files from chapter10_* to graph-oriented names

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

mapping <- c(
  "chapter10_divx_annual_evolution.pdf" = "divx_annual_evolution.pdf",
  "chapter10_dres_distribution.pdf" = "dres_distribution.pdf",
  "chapter10_eci_annual_evolution.pdf" = "eci_annual_evolution.pdf",
  "chapter10_eci_log_rents_quadrants.pdf" = "eci_log_rents_quadrants.pdf",
  "chapter10_extractive_profile_country.pdf" = "extractive_profile_country.pdf",
  "chapter10_recreated_brunnschweiler.pdf" = "recreated_brunnschweiler.pdf",
  "chapter10_recreated_figure_a7.pdf" = "recreated_hausmann_eci_rents.pdf",
  "chapter10_recreated_figure_a9.pdf" = "recreated_financial_dev_eci.pdf",
  "chapter10_recreated_owjimehr.pdf" = "recreated_owjimehr.pdf",
  "chapter10_rents_divx_country_means.pdf" = "rents_divx_country_means.pdf",
  "chapter10_rents_eci_country_means.pdf" = "rents_eci_country_means.pdf"
)

dirs <- c(
  file.path(root, "outputs", "figures", "original"),
  file.path(root, "docs", "thesis", "figures")
)

for (d in dirs) {
  for (old_name in names(mapping)) {
    new_name <- mapping[[old_name]]
    old_path <- file.path(d, old_name)
    new_path <- file.path(d, new_name)
    if (file.exists(old_path)) {
      file.rename(old_path, new_path)
      cat("Renamed:", old_path, "->", new_path, "\n")
    }
  }
}
