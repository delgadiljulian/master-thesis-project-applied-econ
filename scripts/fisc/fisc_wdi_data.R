# ===============================
# 1. Librerías
# ===============================
library(WDI)
library(dplyr)

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

# ===============================
# 2. Descargar FISC
# ===============================
df_fisc <- WDI(
  country = "all",
  indicator = "NE.CON.GOVT.ZS",
  start = 1990,
  end = 2022,
  extra = TRUE
)

View(df_fisc)

# ===============================
# 3. Eliminar agregados (solo pseudo-países)
# ===============================
df_fisc <- df_fisc %>%
  filter(region != "Aggregates")

# ===============================
# 4. Limpieza y renombre
# ===============================
df_fisc <- df_fisc %>%
  rename(
    iso3 = iso3c,
    year = year,
    FISC = NE.CON.GOVT.ZS
  ) %>%
  select(country, iso3, year, FISC)

# ===============================
# 5. Panel final
# ===============================
View(df_fisc)

# ===============================
# 6. Guardar como .dta
# ===============================
library(haven)

file_path <- file.path(project_path, "data", "raw", "fisc", "world_bank_wdi", "fisc.dta")
dir.create(dirname(file_path), recursive = TRUE, showWarnings = FALSE)

write_dta(df_fisc, file_path)
