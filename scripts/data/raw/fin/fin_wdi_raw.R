# CAPA: RAW
# VARIABLE: FIN
#
# Punto de entrada estable. La descarga activa se encuentra en
# fin_wdi_banks_raw.py y utiliza FD.AST.PRVT.GD.ZS. La antigua serie amplia
# FS.AST.PRVT.GD.ZS se conserva únicamente como referencia de contraste en la
# descarga WDI compartida.

candidate_paths <- c(
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    file.path(
      dirname(rstudioapi::getActiveDocumentContext()$path),
      "fin_wdi_banks_raw.py"
    )
  },
  file.path(
    "scripts",
    "data",
    "raw",
    "fin",
    "fin_wdi_banks_raw.py"
  ),
  "fin_wdi_banks_raw.py"
)
active_script <- candidate_paths[file.exists(candidate_paths)][1]
if (is.na(active_script)) {
  stop("No se pudo encontrar fin_wdi_banks_raw.py.")
}

python_candidates <- c(
  Sys.which("python"),
  Sys.which("python3"),
  Sys.which("py")
)
python_command <- python_candidates[nzchar(python_candidates)][1]
if (is.na(python_command)) {
  stop("No se encontró una instalación de Python para ejecutar la descarga.")
}

status <- system2(
  python_command,
  args = shQuote(normalizePath(active_script, winslash = "/", mustWork = TRUE))
)
if (!identical(status, 0L)) {
  stop("La descarga de FIN terminó con código de error ", status, ".")
}
