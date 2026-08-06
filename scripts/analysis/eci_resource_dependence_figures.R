# ETAPA: ANALISIS DESCRIPTIVO
# Proposito: producir mapas y graficos descriptivos sobre complejidad economica
# y dependencia de recursos naturales.
# Entradas: Atlas de Complejidad, indicadores WDI y geometria mundial de Natural Earth.
# Salidas: figuras PDF guardadas en outputs/figures/original/.

# Cargar ggplot2 para construir graficos y mapas.
library(ggplot2)
# Cargar sf para trabajar con geometria espacial.
library(sf)
# Cargar rnaturalearth para obtener el mapa base mundial.
library(rnaturalearth)
# Cargar los datos auxiliares utilizados por rnaturalearth.
library(rnaturalearthdata)
# Cargar dplyr para filtrar, unir y transformar tablas.
library(dplyr)
# Cargar WDI para descargar indicadores del Banco Mundial.
library(WDI)
# Cargar tidyverse para operaciones adicionales de manipulacion y visualizacion.
library(tidyverse)
# Cargar readr para leer archivos CSV.
library(readr)
# Cargar countrycode para convertir entre codigos y nombres de paises.
library(countrycode)
# Cargar ggrepel para ubicar etiquetas sin superponerlas.
library(ggrepel)

# Ajuste de ruta del proyecto: carga el helper que encuentra la raiz del repo
# aunque RStudio tenga el working directory en otra carpeta.
# Reunir ubicaciones posibles del helper que identifica la raiz del proyecto.
helper_path <- c(
  # Buscar desde el archivo activo cuando se usa RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path))), "project_paths.R")
  },
  # Probar rutas relativas habituales desde diferentes directorios de trabajo.
  file.path("scripts", "project_paths.R"),
  file.path("..", "..", "project_paths.R"),
  file.path("..", "project_paths.R"),
  "project_paths.R"
)
# Ejecutar la primera ubicacion del helper que exista.
source(helper_path[file.exists(helper_path)][1])
# Obtener la ruta absoluta de la raiz del repositorio.
project_path <- find_project_path()

# Construir la carpeta comun donde se guardan las figuras originales.
fig_path <- file.path(project_path, "outputs", "figures", "original")
# Crear esa carpeta y sus padres si todavia no existen.
dir.create(fig_path, recursive = TRUE, showWarnings = FALSE)

#############################################################################
# MAPA #1 Resource Dependent Countries Map
#############################################################################

# ============================================
# 1. Cargar mapa base del mundo
# ============================================

# Retornar el resultado de la función
world <- ne_countries(scale = "medium", returnclass = "sf")

# ============================================
# 2. Definir países dependientes de recursos
# ============================================

# Ejecutar la siguiente instrucción del bloque
energy_countries <- c(
  "SAU","QAT","ARE","KWT",
  "NOR","VEN","NGA","RUS",
  "IRN","IRQ","KAZ",
  "USA","CAN"
)

# Ejecutar la siguiente instrucción del bloque
mining_countries <- c(
  "CHL","AUS","BWA","PER",
  "ZMB","MNG","ZAF","NAM","COD",
  "CHN"
)

# ============================================
# 3. Clasificar países (usar iso_a3_eh)
# ============================================

# Ejecutar la siguiente instrucción del bloque
world_map <- world %>%
  mutate(resource_type = case_when(
    iso_a3_eh %in% energy_countries ~ "Energy exporters",
    iso_a3_eh %in% mining_countries ~ "Mining exporters",
    TRUE ~ "Other countries"
  ))

# ============================================
# 4. Crear mapa
# ============================================

# Generar visualización gráfica
map <- ggplot(world_map) +
  geom_sf(aes(fill = resource_type), color = "gray55", size = 0.12) +

  # Ejecutar la siguiente instrucción del bloque
  scale_fill_manual(values = c(
    "Energy exporters" = "#b24a3a",
    "Mining exporters" = "#5b76a8",
    "Other countries" = "gray92"
  )) +

  # Ejecutar la siguiente instrucción del bloque
  coord_sf(expand = FALSE) +

  # Ejecutar la siguiente instrucción del bloque
  theme_minimal() +

  # Ejecutar la siguiente instrucción del bloque
  theme(
    axis.text = element_blank(),
    axis.title = element_blank(),
    panel.grid = element_blank(),
    legend.position = "bottom"
  )

# Ejecutar la siguiente instrucción del bloque
map

# ============================================
# 5. Exportar mapa
# ============================================

# Ejecutar la siguiente instrucción del bloque
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

# Ejecutar la siguiente instrucción del bloque
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

# Retornar el resultado de la función
world <- ne_countries(scale = "medium", returnclass = "sf")

# Unir mapa con datos
world_rents <- world %>%
  left_join(resource_data, by = c("iso_a3" = "iso3c"))

# ============================================
# 9. Crear categorías de dependencia
# ============================================

# Ejecutar la siguiente instrucción del bloque
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

# Generar visualización gráfica
map_rents <- ggplot(world_rents) +
  geom_sf(aes(fill = resource_dependence),
          color = "gray60", size = 0.1) +

  # Ejecutar la siguiente instrucción del bloque
  scale_fill_manual(
    values = c(
      "Low (<5%)" = "#f1eef6",
      "Moderate (5–15%)" = "#bdc9e1",
      "High (15–30%)" = "#74a9cf",
      "Very high (>30%)" = "#0570b0"
    ),
    na.value = "gray90"
  ) +

  # Ejecutar la siguiente instrucción del bloque
  labs(
    fill = "Resource rents\n(% of GDP)"
  ) +

  # Ejecutar la siguiente instrucción del bloque
  coord_sf(expand = FALSE) +

  # Ejecutar la siguiente instrucción del bloque
  theme_void() +

  # Ejecutar la siguiente instrucción del bloque
  theme(
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.title = element_text(size = 10),
    legend.text = element_text(size = 9),
    plot.margin = margin(5,5,5,5)
  )

# Ejecutar la siguiente instrucción del bloque
map_rents

# ============================================
# 11. Exportar mapa
# ============================================

# Ejecutar la siguiente instrucción del bloque
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

# Cargar el archivo de datos
eci_data <- read_csv(
  file.path(
    project_path,
    "data",
    "raw",
    "eci",
    "atlas",
    "atlas_eci_country_year_1995_2022.csv"
  )
)

# Ejecutar la siguiente instrucción del bloque
names(world)

# Ejecutar la siguiente instrucción del bloque
world %>%
  filter(name == "Norway") %>%
  select(name, iso_a3, iso_a3_eh, wb_a3)

# ============================================
# 13. Filtrar año de análisis
# ============================================

# Ejecutar la siguiente instrucción del bloque
eci_latest <- eci_data %>%
  filter(year == 2021) %>%
  mutate(iso3 = country_iso3_code)

# ============================================
# 14.1. Unir datos de ECI con el mapa mundial
# ============================================

# Ejecutar la siguiente instrucción del bloque
world_eci <- world %>%
  left_join(
    eci_latest,
    by = c("iso_a3_eh" = "iso3")
  )

# Ejecutar la siguiente instrucción del bloque
world_eci %>%
  filter(iso_a3_eh %in% c("FRA","NOR")) %>%
  select(name, iso_a3_eh, eci)

# ============================================
# 14.2. Crear cuartiles de complejidad económica
# ============================================


# Ejecutar la siguiente instrucción del bloque
world_eci <- world_eci %>%

  # Ejecutar la siguiente instrucción del bloque
  mutate(

    # Ejecutar la siguiente instrucción del bloque
    eci_quartile = ntile(eci, 4),

    # Ejecutar la siguiente instrucción del bloque
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

# Generar visualización gráfica
eci_map <- ggplot(world_eci) +

  # Ejecutar la siguiente instrucción del bloque
  geom_sf(
    aes(fill = eci),
    color = "gray50",
    size = 0.12
  ) +

  # Ejecutar la siguiente instrucción del bloque
  scale_fill_viridis_c(
    option = "C",
    na.value = "gray90",
    name = "Economic\nComplexity\nIndex"
  ) +

  # Ejecutar la siguiente instrucción del bloque
  coord_sf(expand = FALSE) +

  # Ejecutar la siguiente instrucción del bloque
  theme_minimal() +

  # Ejecutar la siguiente instrucción del bloque
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

# Ejecutar la siguiente instrucción del bloque
eci_map

# ============================================
# 17. Exportar mapa para LaTeX
# ============================================

# Ejecutar la siguiente instrucción del bloque
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

# Generar visualización gráfica
eci_map_quartiles <- ggplot(world_eci) +

  # Ejecutar la siguiente instrucción del bloque
  geom_sf(
    aes(fill = eci_quartile),
    color = "gray50",
    size = 0.12
  ) +

  # Ejecutar la siguiente instrucción del bloque
  scale_fill_manual(

    # Ejecutar la siguiente instrucción del bloque
    values = c(
      "Q1 (Low complexity)" = "#440154",
      "Q2 (Lower-middle complexity)" = "#31688e",
      "Q3 (Upper-middle complexity)" = "#35b779",
      "Q4 (High complexity)" = "#fde725"
    ),

    # Ejecutar la siguiente instrucción del bloque
    na.value = "gray90"

  # Ejecutar la siguiente instrucción del bloque
  ) +

  # Ejecutar la siguiente instrucción del bloque
  coord_sf(expand = FALSE) +

  # Ejecutar la siguiente instrucción del bloque
  theme_minimal() +

  # Ejecutar la siguiente instrucción del bloque
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

# Ejecutar la siguiente instrucción del bloque
eci_map_quartiles

# Ejecutar la siguiente instrucción del bloque
eci_latest %>%
  filter(country_iso3_code %in% c("BRA","ARG","CHL","URY","COL","PER")) %>%
  select(country_iso3_code, eci)

# ============================================
# 17. Exportar mapa para LaTeX
# ============================================

# Ejecutar la siguiente instrucción del bloque
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

# Ejecutar la siguiente instrucción del bloque
eci_latest <- eci_data %>%
  filter(year == 2021) %>%
  select(
    iso3 = country_iso3_code,
    eci
  )


# ============================================
# 2. Preparar dataset de resource rents
# ============================================

# Ejecutar la siguiente instrucción del bloque
resource_rents <- resource_data %>%
  select(
    iso3 = iso3c,
    rents,
    country
  )


# ============================================
# 3. Unir datasets
# ============================================

# Ejecutar la siguiente instrucción del bloque
eci_rents <- eci_latest %>%
  inner_join(resource_rents, by = "iso3")


# ============================================
# 4. Calcular regresión para mostrar R²
# ============================================

# Ejecutar la siguiente instrucción del bloque
model <- lm(eci ~ rents, data = eci_rents)

# Ejecutar la siguiente instrucción del bloque
r2 <- summary(model)$r.squared



# ============================================
# 5. Identificar outliers para etiquetar
# ============================================

# Ejecutar la siguiente instrucción del bloque
label_countries <- eci_rents %>%
  filter(
    rents > 35 | eci > 1.5 | eci < -1.8
  )



# ============================================
# 6. Scatter plot mejorado
# ============================================

# Generar visualización gráfica
eci_vs_rents_1 <- ggplot(eci_rents,
                       aes(x = rents, y = eci)) +

  # Ejecutar la siguiente instrucción del bloque
  geom_point(
    color = "#2b8cbe",
    size = 2.4,
    alpha = 0.65
  ) +

  # Ejecutar la siguiente instrucción del bloque
  geom_smooth(
    method = "lm",
    color = "#d7301f",
    linewidth = 1.1,
    se = TRUE
  ) +

  # Ejecutar la siguiente instrucción del bloque
  geom_text(
    data = label_countries,
    aes(label = iso3),
    size = 3.3,
    vjust = -0.7
  ) +

  # Ejecutar la siguiente instrucción del bloque
  annotate(
    "text",
    x = 45,
    y = 1.9,
    label = paste0("R² = ", round(r2,3)),
    size = 4
  ) +

  # Ejecutar la siguiente instrucción del bloque
  labs(
    title = "Economic Complexity and Natural Resource Dependence",
    subtitle = "Economic Complexity Index vs Natural Resource Rents (% of GDP)",
    x = "Natural resource rents (% of GDP)",
    y = "Economic Complexity Index (ECI)"
  ) +

  # Ejecutar la siguiente instrucción del bloque
  coord_cartesian(xlim = c(0,60)) +

  # Ejecutar la siguiente instrucción del bloque
  theme_minimal() +

  # Ejecutar la siguiente instrucción del bloque
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11),
    axis.title = element_text(size = 11),
    panel.grid.minor = element_blank()
  )



# ============================================
# 7. Mostrar gráfico
# ============================================

# Ejecutar la siguiente instrucción del bloque
eci_vs_rents_1

################################################################################
# FIGURE: Economic Complexity vs Resource Rents (Refined Version)
################################################################################


# ============================================
# 1. Preparar datos
# ============================================

# Ejecutar la siguiente instrucción del bloque
eci_latest <- eci_data %>%
  filter(year == 2021) %>%
  select(
    iso3 = country_iso3_code,
    eci
  )

# Ejecutar la siguiente instrucción del bloque
resource_rents <- resource_data %>%
  select(
    iso3 = iso3c,
    rents,
    country
  )

# Ejecutar la siguiente instrucción del bloque
eci_rents <- eci_latest %>%
  inner_join(resource_rents, by = "iso3")


# ============================================
# 2. Regresión OLS
# ============================================

# Ejecutar la siguiente instrucción del bloque
model <- lm(eci ~ rents, data = eci_rents)
r2 <- summary(model)$r.squared


# ============================================
# 3. Etiquetar solo extremos reales
# ============================================

# Ejecutar la siguiente instrucción del bloque
label_countries <- eci_rents %>%
  filter(
    rents > 40 |
      eci > 1.7 |
      eci < -2
  )


# ============================================
# 4. Gráfico refinado
# ============================================

# Generar visualización gráfica
eci_vs_rents_2 <- ggplot(
  eci_rents,
  aes(x = rents, y = eci)
) +

  # Ejecutar la siguiente instrucción del bloque
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

  # Ejecutar la siguiente instrucción del bloque
  geom_text(
    data = label_countries,
    aes(label = iso3),
    size = 3.2,
    vjust = -0.6
  ) +

  # Ejecutar la siguiente instrucción del bloque
  annotate(
    "text",
    x = 48,
    y = 2.1,
    label = paste0("OLS R² = ", round(r2,3)),
    size = 4
  ) +

  # Ejecutar la siguiente instrucción del bloque
  labs(
    title = "Economic Complexity and Natural Resource Dependence",
    subtitle = "LOESS (blue) and OLS (red dashed)",
    x = "Natural resource rents (% of GDP)",
    y = "Economic Complexity Index (ECI)"
  ) +

  # Ejecutar la siguiente instrucción del bloque
  coord_cartesian(xlim = c(0,60)) +

  # Ejecutar la siguiente instrucción del bloque
  theme_minimal() +

  # Ejecutar la siguiente instrucción del bloque
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11),
    axis.title = element_text(size = 11),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank()
  )


# Ejecutar la siguiente instrucción del bloque
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

# Ejecutar la siguiente instrucción del bloque
label_countries <- eci_rents_clean %>%
  filter(iso3 %in% highlight_countries)

# Generar visualización gráfica
eci_vs_rents_trim <- ggplot(
  eci_rents_clean,
  aes(x = rents, y = eci)
) +

  # Ejecutar la siguiente instrucción del bloque
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

  # Ejecutar la siguiente instrucción del bloque
  geom_text_repel(
    data = label_countries,
    aes(label = iso3),
    size = 3.2,
    max.overlaps = 20
  ) +

  # Ejecutar la siguiente instrucción del bloque
  annotate(
    "text",
    x = 35,
    y = 2.1,
    label = paste0("OLS R² = ", round(r2,3)),
    size = 4
  ) +

  # Ejecutar la siguiente instrucción del bloque
  labs(
    x = "Natural resource rents (% of GDP)",
    y = "Economic Complexity Index (ECI)",
    caption = "Blue line: LOESS smoothing | Red dashed line: OLS linear fit"
  ) +

  # Ejecutar la siguiente instrucción del bloque
  coord_cartesian(xlim = c(0,40)) +

  # Ejecutar la siguiente instrucción del bloque
  theme_minimal() +

  # Ejecutar la siguiente instrucción del bloque
  theme(
    axis.title = element_text(size = 11),
    panel.grid.minor = element_blank()
  )

# Ejecutar la siguiente instrucción del bloque
eci_vs_rents_trim

# ============================================
# Exportar Figura
# ============================================

# Ejecutar la siguiente instrucción del bloque
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

# Ejecutar la siguiente instrucción del bloque
eci_latest <- eci_data %>%
  filter(year == 2021) %>%
  select(
    iso3 = country_iso3_code,
    eci
  )

# Ejecutar la siguiente instrucción del bloque
resource_rents <- resource_data %>%
  select(
    iso3 = iso3c,
    rents,
    country
  )

# Ejecutar la siguiente instrucción del bloque
eci_rents <- eci_latest %>%
  inner_join(resource_rents, by = "iso3")


# ============================================
# 2. Crear variable log
# ============================================

# Ejecutar la siguiente instrucción del bloque
eci_rents <- eci_rents %>%
  mutate(
    log_rents = log(rents + 0.1)
  )


# ============================================
# 3. Regresión OLS
# ============================================

# Ejecutar la siguiente instrucción del bloque
model <- lm(eci ~ log_rents, data = eci_rents)
r2 <- summary(model)$r.squared


# ============================================
# 4. Etiquetar extremos
# ============================================

# Ejecutar la siguiente instrucción del bloque
label_countries <- eci_rents %>%
  filter(
    rents > 40 |
      eci > 1.7 |
      eci < -2
  )


# ============================================
# 5. Scatter plot
# ============================================

# Generar visualización gráfica
eci_vs_rents_log <- ggplot(
  eci_rents,
  aes(x = log_rents, y = eci)
) +

  # Ejecutar la siguiente instrucción del bloque
  geom_point(
    color = "#3b8bc2",
    size = 2.2,
    alpha = 0.6
  ) +

  # Ejecutar la siguiente instrucción del bloque
  geom_smooth(
    method = "loess",
    color = "#08306b",
    linewidth = 1.4,
    se = FALSE
  ) +

  # Ejecutar la siguiente instrucción del bloque
  geom_smooth(
    method = "lm",
    color = "#cb181d",
    linewidth = 1,
    linetype = "dashed",
    se = TRUE,
    alpha = 0.15
  ) +

  # Ejecutar la siguiente instrucción del bloque
  geom_text(
    data = label_countries,
    aes(label = iso3),
    size = 3.2,
    vjust = -0.6
  ) +

  # Ejecutar la siguiente instrucción del bloque
  annotate(
    "text",
    x = 3,
    y = 2.1,
    label = paste0("OLS R² = ", round(r2,3)),
    size = 4
  ) +

  # Ejecutar la siguiente instrucción del bloque
  labs(
    title = "Economic Complexity and Natural Resource Dependence",
    subtitle = "Log scale for resource rents",
    x = "log(Resource rents + 0.1)",
    y = "Economic Complexity Index (ECI)"
  ) +

  # Ejecutar la siguiente instrucción del bloque
  theme_minimal() +

  # Ejecutar la siguiente instrucción del bloque
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11),
    axis.title = element_text(size = 11),
    panel.grid.minor = element_blank()
  )

# Ejecutar la siguiente instrucción del bloque
eci_vs_rents_log


################################################################################
# FIGURE: Economic Complexity vs Resource Rents (Log scale + Regions)
################################################################################

# ============================================
# 1. Preparar datos ECI
# ============================================

# Ejecutar la siguiente instrucción del bloque
eci_latest <- eci_data %>%
  filter(year == 2021) %>%
  select(
    iso3 = country_iso3_code,
    eci
  )


# ============================================
# 2. Preparar datos de resource rents
# ============================================

# Ejecutar la siguiente instrucción del bloque
resource_rents <- resource_data %>%
  select(
    iso3 = iso3c,
    rents,
    country
  )


# ============================================
# 3. Unir datasets
# ============================================

# Ejecutar la siguiente instrucción del bloque
eci_rents <- eci_latest %>%
  inner_join(resource_rents, by = "iso3")


# ============================================
# 4. Crear log(resource rents)
# ============================================

# Ejecutar la siguiente instrucción del bloque
eci_rents <- eci_rents %>%
  mutate(
    log_rents = log(rents + 0.1)
  )


# ============================================
# 5. Crear regiones del mundo
# ============================================

# Ejecutar la siguiente instrucción del bloque
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

# Ejecutar la siguiente instrucción del bloque
model <- lm(eci ~ log_rents, data = eci_rents)

# Ejecutar la siguiente instrucción del bloque
r2 <- summary(model)$r.squared


# ============================================
# 7. Etiquetar países extremos
# ============================================

# Ejecutar la siguiente instrucción del bloque
label_countries <- eci_rents %>%
  filter(
    rents > 40 |
      eci > 1.7 |
      eci < -2
  )


# ============================================
# 8. Scatter plot final
# ============================================

# Ejecutar la siguiente instrucción del bloque
scale_color_brewer(palette = "Set2")

# Generar visualización gráfica
eci_vs_rents_clean <- ggplot(
  eci_rents,
  aes(
    x = log_rents,
    y = eci
  )
) +

  # Ejecutar la siguiente instrucción del bloque
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

  # Ejecutar la siguiente instrucción del bloque
  geom_text(
    data = label_countries,
    aes(label = iso3),
    size = 3.2,
    vjust = -0.7
  ) +

  # Ejecutar la siguiente instrucción del bloque
  annotate(
    "text",
    x = 3,
    y = 2.1,
    label = paste0("OLS R² = ", round(r2,3)),
    size = 4
  ) +

  # Ejecutar la siguiente instrucción del bloque
  labs(
    title = "Economic Complexity and Natural Resource Dependence",
    subtitle = "Log scale for resource rents",
    x = "log(Resource rents + 0.1)",
    y = "Economic Complexity Index (ECI)"
  ) +

  # Ejecutar la siguiente instrucción del bloque
  theme_minimal() +

  # Ejecutar la siguiente instrucción del bloque
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11),
    axis.title = element_text(size = 11),
    panel.grid.minor = element_blank()
  )


# Ejecutar la siguiente instrucción del bloque
eci_vs_rents_clean


################################################################################
# FIGURE: Economic Complexity vs Resource Dependence (Log + Quadrants)
################################################################################

# ============================================
# 1. Preparar datos
# ============================================

# Ejecutar la siguiente instrucción del bloque
eci_latest <- eci_data %>%
  filter(year == 2021) %>%
  select(
    iso3 = country_iso3_code,
    eci
  )

# Ejecutar la siguiente instrucción del bloque
resource_rents <- resource_data %>%
  select(
    iso3 = iso3c,
    rents,
    country
  )

# Ejecutar la siguiente instrucción del bloque
eci_rents <- eci_latest %>%
  inner_join(resource_rents, by = "iso3")


# ============================================
# 2. Crear variable log
# ============================================

# Ejecutar la siguiente instrucción del bloque
eci_rents <- eci_rents %>%
  mutate(
    log_rents = log(rents + 0.1)
  )


# ============================================
# 3. Regresión OLS
# ============================================

# Ejecutar la siguiente instrucción del bloque
model <- lm(eci ~ log_rents, data = eci_rents)
r2 <- summary(model)$r.squared


# ============================================
# 4. Etiquetar extremos
# ============================================

# Ejecutar la siguiente instrucción del bloque
label_countries <- eci_rents %>%
  filter(
    rents > 40 |
      eci > 1.7 |
      eci < -2
  )

# ============================================
# 4b. Etiquetas adicionales para cuadrantes
# ============================================

# Ejecutar la siguiente instrucción del bloque
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

# Ejecutar la siguiente instrucción del bloque
median_log_rents <- quantile(eci_rents$log_rents, 0.6)

# ============================================
# 6. Scatter plot final
# ============================================

# Generar visualización gráfica
eci_vs_rents_log_quad <- ggplot(
  eci_rents,
  aes(x = log_rents, y = eci)
) +

  # Ejecutar la siguiente instrucción del bloque
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

  # Ejecutar la siguiente instrucción del bloque
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

  # Ejecutar la siguiente instrucción del bloque
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

  # Ejecutar la siguiente instrucción del bloque
  annotate(
    "text",
    x = median_log_rents + 1.5,
    y = 1.8,
    label = "High complexity\nResource exporters",
    size = 3.6
  ) +

  # Ejecutar la siguiente instrucción del bloque
  annotate(
    "text",
    x = median_log_rents - 1.3,
    y = -1.8,
    label = "Low complexity\nLow resource rents",
    size = 3.6
  ) +

  # Ejecutar la siguiente instrucción del bloque
  annotate(
    "text",
    x = median_log_rents + 1.5,
    y = -1.8,
    label = "Resource-dependent\neconomies",
    size = 3.6
  ) +

  # Ejecutar la siguiente instrucción del bloque
  scale_color_manual(
    name = "",
    values = c(
      "LOESS" = "#08306b",
      "OLS" = "#cb181d"
    )
  ) +

  # Ejecutar la siguiente instrucción del bloque
  scale_linetype_manual(
    name = "",
    values = c(
      "LOESS" = "solid",
      "OLS" = "dashed"
    )
  ) +

  # Ejecutar la siguiente instrucción del bloque
  labs(
    x = "log(Resource rents + 0.1)",
    y = "Economic Complexity Index (ECI)"
  ) +

  # Ejecutar la siguiente instrucción del bloque
  theme_minimal() +

  # Ejecutar la siguiente instrucción del bloque
  theme(
    legend.position = "top",
    axis.title = element_text(size = 11),
    panel.grid.minor = element_blank()
  )

# Ejecutar la siguiente instrucción del bloque
eci_vs_rents_log_quad

# ============================================
# Exportar Figura
# ============================================

# Ejecutar la siguiente instrucción del bloque
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

# Ejecutar la siguiente instrucción del bloque
mean_rents <- mean(eci_rents$rents, na.rm = TRUE)
median_rents <- median(eci_rents$rents, na.rm = TRUE)

# Generar visualización gráfica
rents_density <- ggplot(
  eci_rents,
  aes(x = rents)
) +

  # Ejecutar la siguiente instrucción del bloque
  geom_density(
    fill = "#6baed6",
    alpha = 0.5,
    color = "#08519c",
    linewidth = 1
  ) +

  # Ejecutar la siguiente instrucción del bloque
  geom_vline(
    aes(xintercept = mean_rents, color = "Mean", linetype = "Mean"),
    linewidth = 1
  ) +

  # Ejecutar la siguiente instrucción del bloque
  geom_vline(
    aes(xintercept = median_rents, color = "Median", linetype = "Median"),
    linewidth = 1
  ) +

  # Ejecutar la siguiente instrucción del bloque
  scale_color_manual(
    name = "",
    values = c(
      "Mean" = "#cb181d",
      "Median" = "#238b45"
    )
  ) +

  # Ejecutar la siguiente instrucción del bloque
  scale_linetype_manual(
    name = "",
    values = c(
      "Mean" = "dashed",
      "Median" = "dotted"
    )
  ) +

  # Ejecutar la siguiente instrucción del bloque
  labs(
    x = "Natural resource rents (% of GDP)",
    y = "Density"
  ) +

  # Ejecutar la siguiente instrucción del bloque
  theme_minimal() +

  # Ejecutar la siguiente instrucción del bloque
  theme(
    legend.position = "top"
  )

# Ejecutar la siguiente instrucción del bloque
rents_density

# ============================================
# Exportar Figura
# ============================================

# Ejecutar la siguiente instrucción del bloque
ggsave(
  "rents_density.pdf",
  plot = rents_density,
  path = fig_path,
  width = 8,
  height = 6
)
