# ===============================
# 1. Librerías
# ===============================
library(WDI)
library(dplyr)

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

file_path <- "C:/Users/julla/Downloads/1. Tesis de Maestría/data/raw/fisc.dta"

write_dta(df_fisc, file_path)

