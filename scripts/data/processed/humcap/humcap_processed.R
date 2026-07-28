# Punto de entrada estable para la definición activa de HUMCAP.
# La implementación se encuentra en humcap_undp_processed.R.

candidate_paths <- c(
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    file.path(
      dirname(rstudioapi::getActiveDocumentContext()$path),
      "humcap_undp_processed.R"
    )
  },
  file.path(
    "scripts",
    "data",
    "processed",
    "humcap",
    "humcap_undp_processed.R"
  ),
  "humcap_undp_processed.R"
)
active_script <- candidate_paths[file.exists(candidate_paths)][1]
if (is.na(active_script)) {
  stop("No se pudo encontrar humcap_undp_processed.R.")
}
source(active_script)
