# CAPA: PROCESSED
# VARIABLE: GOVCONS
#
# Punto de entrada estable. La definición activa se encuentra en
# govcons_un_ama_processed.R; WDI se conserva únicamente como referencia de
# contraste dentro de ese flujo.

candidate_paths <- c(
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    file.path(
      dirname(rstudioapi::getActiveDocumentContext()$path),
      "govcons_un_ama_processed.R"
    )
  },
  file.path(
    "scripts",
    "data",
    "processed",
    "govcons",
    "govcons_un_ama_processed.R"
  ),
  "govcons_un_ama_processed.R"
)
active_script <- candidate_paths[file.exists(candidate_paths)][1]
if (is.na(active_script)) {
  stop("No se pudo encontrar govcons_un_ama_processed.R.")
}
source(active_script)
