library(readr)
library(haven)
library(janitor)

# Ajuste de ruta del proyecto: carga el helper que encuentra la raiz del repo
# aunque RStudio tenga el working directory en otra carpeta.
helper_path <- c(
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(rstudioapi::getActiveDocumentContext()$path)), "project_paths.R")
  },
  file.path("scripts", "project_paths.R"),
  file.path("..", "project_paths.R"),
  "project_paths.R"
)
source(helper_path[file.exists(helper_path)][1])
project_path <- find_project_path()

file_path <- file.path(
  project_path,
  "data",
  "raw",
  "inst",
  "world_bank_wgi",
  "0a8b502f-696a-4678-91cf-132f60b7a8e0_Data.csv"
)

df_raw <- read_csv(file_path, locale = locale(encoding = "latin1"))

# Limpiar nombres de columnas (robusto para Stata)
df_raw <- janitor::clean_names(df_raw)

# Guardar en .dta
output_path <- file.path(project_path, "data", "raw", "inst", "world_bank_wgi", "inst_raw.dta")
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
write_dta(df_raw, output_path)

View(df_raw)
