# ==============================================================================
# Script: generate_own_panel_income_boxplot.R
# Propósito: Generar gráficos de caja (boxplots) + puntos por nivel de ingreso
#            con datos 100% PROPIOS de nuestro panel maestro (1996-2021):
#            1. Dependencia extractiva (DRES %)
#            2. Rentas de Petróleo y Gas Natural (rents_oil_gas % del PIB)
# Entrada: data/processed/00_master_panel/master_panel_country_year.csv
# Salidas: docs/thesis/figures/panel_extractive_dependence_by_income_group.pdf
#          docs/thesis/figures/panel_oil_gas_rents_by_income_group.pdf
#          outputs/figures/original/...
# ==============================================================================

library(dplyr)
library(ggplot2)

# 1. Cargar el panel maestro
panel_file <- "data/processed/00_master_panel/master_panel_country_year.csv"
if (!file.exists(panel_file)) {
  stop("No se encontró el archivo del panel maestro: ", panel_file)
}

df <- read.csv(panel_file, stringsAsFactors = FALSE)

# 2. Mapeo de grupos de ingreso del Banco Mundial (clasificación histórica/estándar)
income_mapping <- c(
  # Low Income (LIC)
  "BDI" = "LIC", "CAF" = "LIC", "GMB" = "LIC", "LBR" = "LIC", "SLE" = "LIC", "YEM" = "LIC",
  
  # Lower Middle Income (LMIC)
  "ALB" = "LMIC", "BOL" = "LMIC", "CMR" = "LMIC", "COD" = "LMIC", "COG" = "LMIC", 
  "EGY" = "LMIC", "GHA" = "LMIC", "GIN" = "LMIC", "IDN" = "LMIC", "IND" = "LMIC", 
  "JOR" = "LMIC", "MRT" = "LMIC", "NGA" = "LMIC", "PNG" = "LMIC", "SYR" = "LMIC", 
  "TGO" = "LMIC", "VNM" = "LMIC", "ZMB" = "LMIC",
  
  # Upper Middle Income (UMIC)
  "ATG" = "UMIC", "COL" = "UMIC", "DZA" = "UMIC", "ECU" = "UMIC", "GAB" = "UMIC", 
  "GUY" = "UMIC", "IRQ" = "UMIC", "JAM" = "UMIC", "LBY" = "UMIC", "MNG" = "UMIC", 
  "PER" = "UMIC", "RUS" = "UMIC", "SUR" = "UMIC", "ZAF" = "UMIC", "CHL" = "UMIC",
  
  # High Income (HIC)
  "AGO" = "UMIC", 
  "ARE" = "HIC", "AUS" = "HIC", "BHR" = "HIC", "BRN" = "HIC", "ISR" = "HIC", 
  "KWT" = "HIC", "NOR" = "HIC", "NRU" = "UMIC", "OMN" = "HIC", "QAT" = "HIC", 
  "SAU" = "HIC", "SYC" = "HIC", "TTO" = "HIC"
)

# 3. Calcular promedios por país del panel
country_df <- df %>%
  group_by(country_iso3_code, country) %>%
  summarise(
    dres_pct = mean(dres_base_mean_percent, na.rm = TRUE),
    rents_pct = mean(rents, na.rm = TRUE),
    rents_oil_gas_pct = mean(rents_oil_gas, na.rm = TRUE),
    rents_mining_pct = mean(rents_mining, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    income_group = income_mapping[country_iso3_code]
  ) %>%
  filter(!is.na(income_group)) %>%
  mutate(
    income_group = factor(income_group, levels = c("LIC", "LMIC", "UMIC", "HIC"))
  )

# Palette común
fill_palette <- c(
  "LIC"  = "#e0f2fe",
  "LMIC" = "#bae6fd",
  "UMIC" = "#38bdf8",
  "HIC"  = "#0284c7"
)

# 4. Posicionamiento jitter común para puntos y etiquetas
pos <- position_jitter(width = 0.15, seed = 42)

# 4. Gráfico 1: DRES % por Grupo de Ingreso
p_dres <- ggplot(country_df, aes(x = income_group, y = dres_pct)) +
  geom_boxplot(fill = NA, color = "#1e293b", linewidth = 0.6, width = 0.5, outlier.shape = NA) +
  geom_point(position = pos, size = 2, color = "#0284c7", alpha = 0.8) +
  geom_text(aes(label = country_iso3_code), position = pos, vjust = -0.6, size = 2.3, color = "#334155", fontface = "bold") +
  scale_y_continuous(limits = c(0, 105), breaks = seq(0, 100, 25)) +
  labs(
    x = "Grupo de ingreso (Banco Mundial)",
    y = "Participación de exportaciones extractivas (DRES %)",
    title = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "none",
    axis.title.x = element_text(face = "bold", margin = margin(t = 10)),
    axis.title.y = element_text(face = "bold", margin = margin(r = 10)),
    axis.text = element_text(color = "#1e293b"),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank()
  )

# 5. Gráfico 2: Rentas de Hidrocarburos (rents_oil_gas % del PIB) por Grupo de Ingreso
p_oil_gas <- ggplot(country_df, aes(x = income_group, y = rents_oil_gas_pct)) +
  geom_boxplot(fill = NA, color = "#1e293b", linewidth = 0.6, width = 0.5, outlier.shape = NA) +
  geom_point(position = pos, size = 2, color = "#0284c7", alpha = 0.8) +
  geom_text(aes(label = country_iso3_code), position = pos, vjust = -0.6, size = 2.3, color = "#334155", fontface = "bold") +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(
    x = "Grupo de ingreso (Banco Mundial)",
    y = "Rentas de petróleo y gas natural (% del PIB)",
    title = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "none",
    axis.title.x = element_text(face = "bold", margin = margin(t = 10)),
    axis.title.y = element_text(face = "bold", margin = margin(r = 10)),
    axis.text = element_text(color = "#1e293b"),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank()
  )

# 6. Gráfico 3: Rentas de Minería (rents_mining % del PIB) por Grupo de Ingreso
p_mining <- ggplot(country_df, aes(x = income_group, y = rents_mining_pct)) +
  geom_boxplot(fill = NA, color = "#1e293b", linewidth = 0.6, width = 0.5, outlier.shape = NA) +
  geom_point(position = pos, size = 2, color = "#0284c7", alpha = 0.8) +
  geom_text(aes(label = country_iso3_code), position = pos, vjust = -0.6, size = 2.3, color = "#334155", fontface = "bold") +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(
    x = "Grupo de ingreso (Banco Mundial)",
    y = "Rentas de minería (% del PIB)",
    title = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "none",
    axis.title.x = element_text(face = "bold", margin = margin(t = 10)),
    axis.title.y = element_text(face = "bold", margin = margin(r = 10)),
    axis.text = element_text(color = "#1e293b"),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank()
  )

# 7. Guardar las figuras en PDF
pdf_dres_thesis <- "docs/thesis/figures/panel_extractive_dependence_by_income_group.pdf"
pdf_dres_orig   <- "outputs/figures/original/panel_extractive_dependence_by_income_group.pdf"

pdf_oil_gas_thesis <- "docs/thesis/figures/panel_oil_gas_rents_by_income_group.pdf"
pdf_oil_gas_orig   <- "outputs/figures/original/panel_oil_gas_rents_by_income_group.pdf"

pdf_mining_thesis <- "docs/thesis/figures/panel_mining_rents_by_income_group.pdf"
pdf_mining_orig   <- "outputs/figures/original/panel_mining_rents_by_income_group.pdf"

ggsave(pdf_dres_thesis, plot = p_dres, width = 7, height = 5.2, units = "in")
ggsave(pdf_dres_orig,   plot = p_dres, width = 7, height = 5.2, units = "in")

ggsave(pdf_oil_gas_thesis, plot = p_oil_gas, width = 7, height = 5.2, units = "in")
ggsave(pdf_oil_gas_orig,   plot = p_oil_gas, width = 7, height = 5.2, units = "in")

ggsave(pdf_mining_thesis, plot = p_mining, width = 7, height = 5.2, units = "in")
ggsave(pdf_mining_orig,   plot = p_mining, width = 7, height = 5.2, units = "in")

cat("Figuras generadas exitosamente:\n")
cat(" - DRES: ", pdf_dres_thesis, "\n")
cat(" - Oil & Gas Rents: ", pdf_oil_gas_thesis, "\n")
cat(" - Mining Rents: ", pdf_mining_thesis, "\n")


