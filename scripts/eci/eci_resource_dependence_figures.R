# ============================================
# 1. Cargar librerías
# ============================================

library(ggplot2)
library(sf)
library(rnaturalearth)
library(rnaturalearthdata)
library(dplyr)
library(WDI)
library(tidyverse)
library(readr)
library(countrycode)
library(ggrepel)

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

fig_path <- file.path(project_path, "outputs", "figures", "original")
dir.create(fig_path, recursive = TRUE, showWarnings = FALSE)

#############################################################################
# MAPA #1 Resource Dependent Countries Map
#############################################################################

# ============================================
# 1. Cargar mapa base del mundo
# ============================================

world <- ne_countries(scale = "medium", returnclass = "sf")

# ============================================
# 2. Definir países dependientes de recursos
# ============================================

energy_countries <- c(
  "SAU","QAT","ARE","KWT",
  "NOR","VEN","NGA","RUS",
  "IRN","IRQ","KAZ",
  "USA","CAN"
)

mining_countries <- c(
  "CHL","AUS","BWA","PER",
  "ZMB","MNG","ZAF","NAM","COD",
  "CHN"
)

# ============================================
# 3. Clasificar países (usar iso_a3_eh)
# ============================================

world_map <- world %>%
  mutate(resource_type = case_when(
    iso_a3_eh %in% energy_countries ~ "Energy exporters",
    iso_a3_eh %in% mining_countries ~ "Mining exporters",
    TRUE ~ "Other countries"
  ))

# ============================================
# 4. Crear mapa
# ============================================

map <- ggplot(world_map) +
  geom_sf(aes(fill = resource_type), color = "gray55", size = 0.12) +

  scale_fill_manual(values = c(
    "Energy exporters" = "#b24a3a",
    "Mining exporters" = "#5b76a8",
    "Other countries" = "gray92"
  )) +

  coord_sf(expand = FALSE) +

  theme_minimal() +

  theme(
    axis.text = element_blank(),
    axis.title = element_blank(),
    panel.grid = element_blank(),
    legend.position = "bottom"
  )

map

# ============================================
# 5. Exportar mapa
# ============================================

ggsave(
  "resource_dependent_map.pdf",
  plot = map,
  path = fig_path,
  width = 11,
  height = 6
)

############################################################################################
# MAPA #2 Resource Rents World Map
################################################################################


# ============================================
# 7. Descargar datos del Banco Mundial
# Natural resource rents (% of GDP)
# ============================================

resource_data <- WDI(
  indicator = "NY.GDP.TOTL.RT.ZS",
  start = 2021,
  end = 2021,
  extra = TRUE
)

# Limpiar dataset
resource_data <- resource_data %>%
  select(iso3c, country, rents = NY.GDP.TOTL.RT.ZS)

# ============================================
# 8. Cargar mapa mundial
# ============================================

world <- ne_countries(scale = "medium", returnclass = "sf")

# Unir mapa con datos
world_rents <- world %>%
  left_join(resource_data, by = c("iso_a3" = "iso3c"))

# ============================================
# 9. Crear categorías de dependencia
# ============================================

world_rents <- world_rents %>%
  mutate(resource_dependence = case_when(
    rents < 5 ~ "Low (<5%)",
    rents >= 5 & rents < 15 ~ "Moderate (5–15%)",
    rents >= 15 & rents < 30 ~ "High (15–30%)",
    rents >= 30 ~ "Very high (>30%)",
    TRUE ~ NA_character_
  ))

# ============================================
# 10. Crear mapa
# ============================================

map_rents <- ggplot(world_rents) +
  geom_sf(aes(fill = resource_dependence),
          color = "gray60", size = 0.1) +

  scale_fill_manual(
    values = c(
      "Low (<5%)" = "#f1eef6",
      "Moderate (5–15%)" = "#bdc9e1",
      "High (15–30%)" = "#74a9cf",
      "Very high (>30%)" = "#0570b0"
    ),
    na.value = "gray90"
  ) +

  labs(
    fill = "Resource rents\n(% of GDP)"
  ) +

  coord_sf(expand = FALSE) +

  theme_void() +

  theme(
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.title = element_text(size = 10),
    legend.text = element_text(size = 9),
    plot.margin = margin(5,5,5,5)
  )

map_rents

# ============================================
# 11. Exportar mapa
# ============================================

ggsave(
  "resource_rents_world_map.pdf",
  plot = map_rents,
  path = fig_path,
  width = 10,
  height = 5
)

################################################################################
# MAPA GLOBAL DE COMPLEJIDAD ECONÓMICA (ECI)
################################################################################


# ============================================
# 12. Cargar dataset de complejidad económica
# ============================================

eci_data <- read_csv(
  file.path(project_path, "data", "raw", "eci", "atlas", "growth_proj_eci_rankings.csv")
)

names(world)

world %>%
  filter(name == "Norway") %>%
  select(name, iso_a3, iso_a3_eh, wb_a3)

# ============================================
# 13. Filtrar año de análisis
# ============================================

eci_latest <- eci_data %>%
  filter(year == 2021) %>%
  mutate(iso3 = country_iso3_code)

# ============================================
# 14.1. Unir datos de ECI con el mapa mundial
# ============================================

world_eci <- world %>%
  left_join(
    eci_latest,
    by = c("iso_a3_eh" = "iso3")
  )

world_eci %>%
  filter(iso_a3_eh %in% c("FRA","NOR")) %>%
  select(name, iso_a3_eh, eci_hs92)

# ============================================
# 14.2. Crear cuartiles de complejidad económica
# ============================================


world_eci <- world_eci %>%

  mutate(

    eci_quartile = ntile(eci_hs92, 4),

    eci_quartile = case_when(
      eci_quartile == 1 ~ "Q1 (Low complexity)",
      eci_quartile == 2 ~ "Q2 (Lower-middle complexity)",
      eci_quartile == 3 ~ "Q3 (Upper-middle complexity)",
      eci_quartile == 4 ~ "Q4 (High complexity)"
    )

  )

# ============================================
# 15. Construir mapa ECI
# ============================================

eci_map <- ggplot(world_eci) +

  geom_sf(
    aes(fill = eci_hs92),
    color = "gray50",
    size = 0.12
  ) +

  scale_fill_viridis_c(
    option = "C",
    na.value = "gray90",
    name = "Economic\nComplexity\nIndex"
  ) +

  coord_sf(expand = FALSE) +

  theme_minimal() +

  theme(
    axis.text = element_blank(),
    axis.title = element_blank(),
    panel.grid = element_blank(),
    legend.position = "bottom",
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11)
  )

# ============================================
# 16. Mostrar mapa
# ============================================

eci_map

# ============================================
# 17. Exportar mapa para LaTeX
# ============================================

ggsave(
  "eci_world_map.pdf",
  plot = eci_map,
  path = fig_path,
  width = 11,
  height = 6
)

# ============================================
# 18. Mapa ECI por cuartiles
# ============================================

eci_map_quartiles <- ggplot(world_eci) +

  geom_sf(
    aes(fill = eci_quartile),
    color = "gray50",
    size = 0.12
  ) +

  scale_fill_manual(

    values = c(
      "Q1 (Low complexity)" = "#440154",
      "Q2 (Lower-middle complexity)" = "#31688e",
      "Q3 (Upper-middle complexity)" = "#35b779",
      "Q4 (High complexity)" = "#fde725"
    ),

    na.value = "gray90"

  ) +

  coord_sf(expand = FALSE) +

  theme_minimal() +

  theme(
    axis.text = element_blank(),
    axis.title = element_blank(),
    panel.grid = element_blank(),
    legend.position = "bottom",
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11)
  )

# ============================================
# 19. Mostrar mapa
# ============================================

eci_map_quartiles

eci_latest %>%
  filter(country_iso3_code %in% c("BRA","ARG","CHL","URY","COL","PER")) %>%
  select(country_iso3_code, eci_hs92)

# ============================================
# 17. Exportar mapa para LaTeX
# ============================================

ggsave(
  "eci_world_map_quartiles.pdf",
  plot = eci_map_quartiles,
  path = fig_path,
  width = 12,
  height = 6
)

################################################################################
# FIGURE: Economic Complexity vs Resource Rents
################################################################################


# ============================================
# 1. Preparar dataset ECI
# ============================================

eci_latest <- eci_data %>%
  filter(year == 2021) %>%
  select(
    iso3 = country_iso3_code,
    eci = eci_hs92
  )


# ============================================
# 2. Preparar dataset de resource rents
# ============================================

resource_rents <- resource_data %>%
  select(
    iso3 = iso3c,
    rents,
    country
  )


# ============================================
# 3. Unir datasets
# ============================================

eci_rents <- eci_latest %>%
  inner_join(resource_rents, by = "iso3")


# ============================================
# 4. Calcular regresión para mostrar R²
# ============================================

model <- lm(eci ~ rents, data = eci_rents)

r2 <- summary(model)$r.squared



# ============================================
# 5. Identificar outliers para etiquetar
# ============================================

label_countries <- eci_rents %>%
  filter(
    rents > 35 | eci > 1.5 | eci < -1.8
  )



# ============================================
# 6. Scatter plot mejorado
# ============================================

eci_vs_rents_1 <- ggplot(eci_rents,
                       aes(x = rents, y = eci)) +

  geom_point(
    color = "#2b8cbe",
    size = 2.4,
    alpha = 0.65
  ) +

  geom_smooth(
    method = "lm",
    color = "#d7301f",
    linewidth = 1.1,
    se = TRUE
  ) +

  geom_text(
    data = label_countries,
    aes(label = iso3),
    size = 3.3,
    vjust = -0.7
  ) +

  annotate(
    "text",
    x = 45,
    y = 1.9,
    label = paste0("R² = ", round(r2,3)),
    size = 4
  ) +

  labs(
    title = "Economic Complexity and Natural Resource Dependence",
    subtitle = "Economic Complexity Index vs Natural Resource Rents (% of GDP)",
    x = "Natural resource rents (% of GDP)",
    y = "Economic Complexity Index (ECI)"
  ) +

  coord_cartesian(xlim = c(0,60)) +

  theme_minimal() +

  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11),
    axis.title = element_text(size = 11),
    panel.grid.minor = element_blank()
  )



# ============================================
# 7. Mostrar gráfico
# ============================================

eci_vs_rents_1

################################################################################
# FIGURE: Economic Complexity vs Resource Rents (Refined Version)
################################################################################


# ============================================
# 1. Preparar datos
# ============================================

eci_latest <- eci_data %>%
  filter(year == 2021) %>%
  select(
    iso3 = country_iso3_code,
    eci = eci_hs92
  )

resource_rents <- resource_data %>%
  select(
    iso3 = iso3c,
    rents,
    country
  )

eci_rents <- eci_latest %>%
  inner_join(resource_rents, by = "iso3")


# ============================================
# 2. Regresión OLS
# ============================================

model <- lm(eci ~ rents, data = eci_rents)
r2 <- summary(model)$r.squared


# ============================================
# 3. Etiquetar solo extremos reales
# ============================================

label_countries <- eci_rents %>%
  filter(
    rents > 40 |
      eci > 1.7 |
      eci < -2
  )


# ============================================
# 4. Gráfico refinado
# ============================================

eci_vs_rents_2 <- ggplot(
  eci_rents,
  aes(x = rents, y = eci)
) +

  geom_point(
    color = "#3b8bc2",
    size = 2.2,
    alpha = 0.6
  ) +

  # LOESS principal
  geom_smooth(
    method = "loess",
    color = "#08306b",
    linewidth = 1.4,
    se = FALSE
  ) +

  # OLS secundaria
  geom_smooth(
    method = "lm",
    color = "#cb181d",
    linewidth = 1,
    linetype = "dashed",
    se = TRUE,
    alpha = 0.15
  ) +

  geom_text(
    data = label_countries,
    aes(label = iso3),
    size = 3.2,
    vjust = -0.6
  ) +

  annotate(
    "text",
    x = 48,
    y = 2.1,
    label = paste0("OLS R² = ", round(r2,3)),
    size = 4
  ) +

  labs(
    title = "Economic Complexity and Natural Resource Dependence",
    subtitle = "LOESS (blue) and OLS (red dashed)",
    x = "Natural resource rents (% of GDP)",
    y = "Economic Complexity Index (ECI)"
  ) +

  coord_cartesian(xlim = c(0,60)) +

  theme_minimal() +

  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11),
    axis.title = element_text(size = 11),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank()
  )


eci_vs_rents_2

################################################################################
# FIGURE: Economic Complexity vs Resource Rents (Trimmed version)
################################################################################

# quitar NA
eci_rents_clean <- eci_rents %>%
  filter(!is.na(rents), !is.na(eci))

# países a etiquetar
highlight_countries <- c(
  "NOR","CAN","AUS",
  "USA","CHN",
  "RUS","SAU","QAT","ARE","KWT","VEN","NGA",
  "CHL","PER","ZAF","BWA","COD","MNG",
  "HTI","NPL","MDG"
)

label_countries <- eci_rents_clean %>%
  filter(iso3 %in% highlight_countries)

eci_vs_rents_trim <- ggplot(
  eci_rents_clean,
  aes(x = rents, y = eci)
) +

  geom_point(
    color = "#3b8bc2",
    size = 2.2,
    alpha = 0.6
  ) +

  # LOESS
  geom_smooth(
    method = "loess",
    color = "#08306b",
    linewidth = 1.4,
    se = FALSE
  ) +

  # OLS
  geom_smooth(
    method = "lm",
    color = "#cb181d",
    linewidth = 1,
    linetype = "dashed",
    se = TRUE,
    alpha = 0.15
  ) +

  geom_text_repel(
    data = label_countries,
    aes(label = iso3),
    size = 3.2,
    max.overlaps = 20
  ) +

  annotate(
    "text",
    x = 35,
    y = 2.1,
    label = paste0("OLS R² = ", round(r2,3)),
    size = 4
  ) +

  labs(
    x = "Natural resource rents (% of GDP)",
    y = "Economic Complexity Index (ECI)",
    caption = "Blue line: LOESS smoothing | Red dashed line: OLS linear fit"
  ) +

  coord_cartesian(xlim = c(0,40)) +

  theme_minimal() +

  theme(
    axis.title = element_text(size = 11),
    panel.grid.minor = element_blank()
  )

eci_vs_rents_trim

# ============================================
# Exportar Figura
# ============================================

ggsave(
  "eci_vs_resource_rents_trim.pdf",
  plot = eci_vs_rents_trim,
  path = fig_path,
  width = 8,
  height = 6
)

################################################################################
# FIGURE: Economic Complexity vs Resource Rents (Log-scale version)
################################################################################


# ============================================
# 1. Preparar datos
# ============================================

eci_latest <- eci_data %>%
  filter(year == 2021) %>%
  select(
    iso3 = country_iso3_code,
    eci = eci_hs92
  )

resource_rents <- resource_data %>%
  select(
    iso3 = iso3c,
    rents,
    country
  )

eci_rents <- eci_latest %>%
  inner_join(resource_rents, by = "iso3")


# ============================================
# 2. Crear variable log
# ============================================

eci_rents <- eci_rents %>%
  mutate(
    log_rents = log(rents + 0.1)
  )


# ============================================
# 3. Regresión OLS
# ============================================

model <- lm(eci ~ log_rents, data = eci_rents)
r2 <- summary(model)$r.squared


# ============================================
# 4. Etiquetar extremos
# ============================================

label_countries <- eci_rents %>%
  filter(
    rents > 40 |
      eci > 1.7 |
      eci < -2
  )


# ============================================
# 5. Scatter plot
# ============================================

eci_vs_rents_log <- ggplot(
  eci_rents,
  aes(x = log_rents, y = eci)
) +

  geom_point(
    color = "#3b8bc2",
    size = 2.2,
    alpha = 0.6
  ) +

  geom_smooth(
    method = "loess",
    color = "#08306b",
    linewidth = 1.4,
    se = FALSE
  ) +

  geom_smooth(
    method = "lm",
    color = "#cb181d",
    linewidth = 1,
    linetype = "dashed",
    se = TRUE,
    alpha = 0.15
  ) +

  geom_text(
    data = label_countries,
    aes(label = iso3),
    size = 3.2,
    vjust = -0.6
  ) +

  annotate(
    "text",
    x = 3,
    y = 2.1,
    label = paste0("OLS R² = ", round(r2,3)),
    size = 4
  ) +

  labs(
    title = "Economic Complexity and Natural Resource Dependence",
    subtitle = "Log scale for resource rents",
    x = "log(Resource rents + 0.1)",
    y = "Economic Complexity Index (ECI)"
  ) +

  theme_minimal() +

  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11),
    axis.title = element_text(size = 11),
    panel.grid.minor = element_blank()
  )

eci_vs_rents_log


################################################################################
# FIGURE: Economic Complexity vs Resource Rents (Log scale + Regions)
################################################################################

# ============================================
# 1. Preparar datos ECI
# ============================================

eci_latest <- eci_data %>%
  filter(year == 2021) %>%
  select(
    iso3 = country_iso3_code,
    eci = eci_hs92
  )


# ============================================
# 2. Preparar datos de resource rents
# ============================================

resource_rents <- resource_data %>%
  select(
    iso3 = iso3c,
    rents,
    country
  )


# ============================================
# 3. Unir datasets
# ============================================

eci_rents <- eci_latest %>%
  inner_join(resource_rents, by = "iso3")


# ============================================
# 4. Crear log(resource rents)
# ============================================

eci_rents <- eci_rents %>%
  mutate(
    log_rents = log(rents + 0.1)
  )


# ============================================
# 5. Crear regiones del mundo
# ============================================

eci_rents <- eci_rents %>%
  mutate(
    region = countrycode(
      iso3,
      origin = "iso3c",
      destination = "region"
    )
  )


# ============================================
# 6. Regresión OLS
# ============================================

model <- lm(eci ~ log_rents, data = eci_rents)

r2 <- summary(model)$r.squared


# ============================================
# 7. Etiquetar países extremos
# ============================================

label_countries <- eci_rents %>%
  filter(
    rents > 40 |
      eci > 1.7 |
      eci < -2
  )


# ============================================
# 8. Scatter plot final
# ============================================

scale_color_brewer(palette = "Set2")

eci_vs_rents_clean <- ggplot(
  eci_rents,
  aes(
    x = log_rents,
    y = eci
  )
) +

  geom_point(
    color = "grey55",
    size = 2.3,
    alpha = 0.6
  ) +

  # LOESS principal
  geom_smooth(
    method = "loess",
    color = "#08306b",
    linewidth = 1.5,
    se = FALSE
  ) +

  # OLS secundaria
  geom_smooth(
    method = "lm",
    color = "#cb181d",
    linetype = "dashed",
    linewidth = 1,
    se = TRUE,
    alpha = 0.12
  ) +

  geom_text(
    data = label_countries,
    aes(label = iso3),
    size = 3.2,
    vjust = -0.7
  ) +

  annotate(
    "text",
    x = 3,
    y = 2.1,
    label = paste0("OLS R² = ", round(r2,3)),
    size = 4
  ) +

  labs(
    title = "Economic Complexity and Natural Resource Dependence",
    subtitle = "Log scale for resource rents",
    x = "log(Resource rents + 0.1)",
    y = "Economic Complexity Index (ECI)"
  ) +

  theme_minimal() +

  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11),
    axis.title = element_text(size = 11),
    panel.grid.minor = element_blank()
  )


eci_vs_rents_clean


################################################################################
# FIGURE: Economic Complexity vs Resource Dependence (Log + Quadrants)
################################################################################

# ============================================
# 1. Preparar datos
# ============================================

eci_latest <- eci_data %>%
  filter(year == 2021) %>%
  select(
    iso3 = country_iso3_code,
    eci = eci_hs92
  )

resource_rents <- resource_data %>%
  select(
    iso3 = iso3c,
    rents,
    country
  )

eci_rents <- eci_latest %>%
  inner_join(resource_rents, by = "iso3")


# ============================================
# 2. Crear variable log
# ============================================

eci_rents <- eci_rents %>%
  mutate(
    log_rents = log(rents + 0.1)
  )


# ============================================
# 3. Regresión OLS
# ============================================

model <- lm(eci ~ log_rents, data = eci_rents)
r2 <- summary(model)$r.squared


# ============================================
# 4. Etiquetar extremos
# ============================================

label_countries <- eci_rents %>%
  filter(
    rents > 40 |
      eci > 1.7 |
      eci < -2
  )

# ============================================
# 4b. Etiquetas adicionales para cuadrantes
# ============================================

quadrant_labels <- eci_rents %>%
  filter(
    iso3 %in% c(

      # economías avanzadas extractivas
      "NOR","CAN","AUS",

      # grandes economías para referencia
      "USA","CHN",

      # energy exporters
      "RUS","SAU","QAT","ARE","KWT","VEN","NGA",

      # mining exporters
      "CHL","PER","ZAF","BWA","COD","MNG",

      # países de baja complejidad para contraste
      "HTI","NPL","MDG"
    )
  )

# ============================================
# 5. Punto de corte para cuadrantes
# ============================================

median_log_rents <- quantile(eci_rents$log_rents, 0.6)

# ============================================
# 6. Scatter plot final
# ============================================

eci_vs_rents_log_quad <- ggplot(
  eci_rents,
  aes(x = log_rents, y = eci)
) +

  geom_point(
    color = "#3b8bc2",
    size = 2.2,
    alpha = 0.6
  ) +

  # LOESS
  geom_smooth(
    aes(color = "LOESS", linetype = "LOESS"),
    method = "loess",
    linewidth = 1.4,
    se = FALSE
  ) +

  # OLS
  geom_smooth(
    aes(color = "OLS", linetype = "OLS"),
    method = "lm",
    linewidth = 1,
    se = TRUE,
    alpha = 0.15
  ) +

  # líneas de cuadrantes
  geom_vline(
    xintercept = median_log_rents,
    linetype = "dashed",
    color = "#08519c",
    linewidth = 1
  ) +

  geom_hline(
    yintercept = 0,
    linetype = "dashed",
    color = "#08519c",
    linewidth = 1
  ) +

  # etiquetas países extremos
  geom_text(
    data = label_countries,
    aes(label = iso3),
    size = 3.2,
    vjust = -0.6
  ) +

  geom_text(
    data = quadrant_labels,
    aes(label = iso3),
    size = 3.2,
    vjust = -0.6,
    color = "black"
  ) +

  # R2
  annotate(
    "text",
    x = 3,
    y = 2.1,
    label = paste0("OLS R² = ", round(r2,3)),
    size = 4
  ) +

  # etiquetas cuadrantes
  annotate(
    "text",
    x = median_log_rents - 1.3,
    y = 1.8,
    label = "High complexity\nLow resource dependence",
    size = 3.6
  ) +

  annotate(
    "text",
    x = median_log_rents + 1.5,
    y = 1.8,
    label = "High complexity\nResource exporters",
    size = 3.6
  ) +

  annotate(
    "text",
    x = median_log_rents - 1.3,
    y = -1.8,
    label = "Low complexity\nLow resource rents",
    size = 3.6
  ) +

  annotate(
    "text",
    x = median_log_rents + 1.5,
    y = -1.8,
    label = "Resource-dependent\neconomies",
    size = 3.6
  ) +

  scale_color_manual(
    name = "",
    values = c(
      "LOESS" = "#08306b",
      "OLS" = "#cb181d"
    )
  ) +

  scale_linetype_manual(
    name = "",
    values = c(
      "LOESS" = "solid",
      "OLS" = "dashed"
    )
  ) +

  labs(
    x = "log(Resource rents + 0.1)",
    y = "Economic Complexity Index (ECI)"
  ) +

  theme_minimal() +

  theme(
    legend.position = "top",
    axis.title = element_text(size = 11),
    panel.grid.minor = element_blank()
  )

eci_vs_rents_log_quad

# ============================================
# Exportar Figura
# ============================================

ggsave(
  "eci_vs_rents_log_quad.pdf",
  plot = eci_vs_rents_log_quad,
  path = fig_path,
  width = 8,
  height = 6
)

#########################################################################
# FIGURE: Distribution of Natural Resource Rents
#########################################################################

mean_rents <- mean(eci_rents$rents, na.rm = TRUE)
median_rents <- median(eci_rents$rents, na.rm = TRUE)

rents_density <- ggplot(
  eci_rents,
  aes(x = rents)
) +

  geom_density(
    fill = "#6baed6",
    alpha = 0.5,
    color = "#08519c",
    linewidth = 1
  ) +

  geom_vline(
    aes(xintercept = mean_rents, color = "Mean", linetype = "Mean"),
    linewidth = 1
  ) +

  geom_vline(
    aes(xintercept = median_rents, color = "Median", linetype = "Median"),
    linewidth = 1
  ) +

  scale_color_manual(
    name = "",
    values = c(
      "Mean" = "#cb181d",
      "Median" = "#238b45"
    )
  ) +

  scale_linetype_manual(
    name = "",
    values = c(
      "Mean" = "dashed",
      "Median" = "dotted"
    )
  ) +

  labs(
    x = "Natural resource rents (% of GDP)",
    y = "Density"
  ) +

  theme_minimal() +

  theme(
    legend.position = "top"
  )

rents_density

# ============================================
# Exportar Figura
# ============================================

ggsave(
  "rents_density.pdf",
  plot = rents_density,
  path = fig_path,
  width = 8,
  height = 6
)
