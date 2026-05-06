library(readr)
library(haven)
library(janitor)

file_path <- "C:/Users/julla/Downloads/1. Tesis de Maestría/data/raw/0a8b502f-696a-4678-91cf-132f60b7a8e0_Data.csv"

df_raw <- read_csv(file_path, locale = locale(encoding = "latin1"))

# Limpiar nombres de columnas (robusto para Stata)
df_raw <- janitor::clean_names(df_raw)

# Guardar en .dta
write_dta(df_raw, "C:/Users/julla/Downloads/1. Tesis de Maestría/data/raw/inst_raw.dta")

View(df_raw)
