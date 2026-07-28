# CAPA: PROCESSED
# VARIABLE: FIN
#
# Punto de entrada estable. La definición activa se encuentra en
# fin_wdi_banks_processed.R; la antigua medida amplia WDI se conserva
# únicamente como referencia de contraste dentro de ese flujo.

candidate_paths <- c(
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    file.path(
      dirname(rstudioapi::getActiveDocumentContext()$path),
      "fin_wdi_banks_processed.R"
    )
  },
  file.path(
    "scripts",
    "data",
    "processed",
    "fin",
    "fin_wdi_banks_processed.R"
  ),
  "fin_wdi_banks_processed.R"
)
active_script <- candidate_paths[file.exists(candidate_paths)][1]
if (is.na(active_script)) {
  stop("No se pudo encontrar fin_wdi_banks_processed.R.")
}
source(active_script)
