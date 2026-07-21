# Proposito: construir volatilidad de commodities y un indice de exposicion a
# choques de precios para cada pais segun su canasta exportadora extractiva.
# Entradas: World Bank Pink Sheet y especializacion por commodities de Anne (2021).
# Salidas: precios limpios, matrices de covarianza y correlacion, figuras y
# data/processed/vol/world_bank_pink_sheet/country_shock_exposure_index.csv.

########################################################################################### PART I.

############################################################
# 1. CARGAR LIBRERIAS
############################################################

# Cargar tidyverse para manipulacion general de datos y graficos.
library(tidyverse)
# Cargar readxl para leer el archivo Excel de la Pink Sheet.
library(readxl)
# Cargar lubridate para trabajar con fechas mensuales.
library(lubridate)
# Cargar rugarch para modelos de volatilidad GARCH.
library(rugarch)
# Cargar haven para leer y escribir archivos Stata.
library(haven)
# Cargar janitor para normalizar nombres de columnas.
library(janitor)
# Cargar ggplot2 para construir graficos estadisticos.
library(ggplot2)
# Cargar reshape2 para convertir matrices en tablas largas.
library(reshape2)
# Cargar corrplot para visualizar matrices de correlacion.
library(corrplot)
# Cargar dplyr para filtros, uniones y transformaciones tabulares.
library(dplyr)
# Cargar stringr para reconocer nombres y patrones de commodities.
library(stringr)
# Cargar readr para guardar resultados en CSV.
library(readr)
# Cargar tidyr para separar filas y ensanchar matrices de ponderaciones.
library(tidyr)
# Cargar purrr para aplicar funciones sobre listas y columnas.
library(purrr)
# Cargar igraph para representar relaciones entre commodities como una red.
library(igraph)
# Cargar ggraph para visualizar la red de correlaciones.
library(ggraph)
# Cargar tidygraph para manipular la red con una sintaxis tabular.
library(tidygraph)
# Cargar zoo para operaciones con series de tiempo.
library(zoo)
# Cargar forcats para ordenar categorias dentro de los graficos.
library(forcats)
# Cargar ggrepel para evitar superposicion entre etiquetas.
library(ggrepel)

############################################################
# PATHS DEL PROYECTO
############################################################

# Ajuste de ruta del proyecto: carga el helper que encuentra la raiz del repo
# aunque RStudio tenga el working directory en otra carpeta.
# Reunir las ubicaciones posibles del helper de rutas.
helper_path <- c(
  # Buscar desde el archivo activo cuando se ejecuta en RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    file.path(dirname(dirname(dirname(rstudioapi::getActiveDocumentContext()$path))), "project_paths.R")
  },
  # Probar rutas relativas habituales desde diferentes carpetas de ejecucion.
  file.path("scripts", "project_paths.R"),
  file.path("..", "..", "project_paths.R"),
  file.path("..", "project_paths.R"),
  "project_paths.R"
)
# Ejecutar la primera ubicacion del helper que exista.
source(helper_path[file.exists(helper_path)][1])
# Obtener la ruta absoluta de la raiz del repositorio.
project_path <- find_project_path()

# Construir la ruta donde se encuentra el Excel original de la Pink Sheet.
raw_path <- file.path(project_path, "data", "raw", "vol", "world_bank_pink_sheet")
# Construir la ruta donde se guardaran datos procesados e indices de exposicion.
proc_path <- file.path(project_path, "data", "processed", "vol", "world_bank_pink_sheet")
# Crear la carpeta procesada y sus padres si todavia no existen.
dir.create(proc_path, recursive = TRUE, showWarnings = FALSE)

############################################################
# CARGAR PRECIOS DE COMMODITIES (PINK SHEET)
############################################################

# Leer la hoja mensual del archivo original del Banco Mundial.
prices <- read_excel(
  file.path(raw_path, "world_bank_commodity_index.xlsx"), # Abrir el Excel original.
  sheet = "Monthly Prices",                              # Seleccionar precios mensuales.
  skip = 4                                               # Omitir las notas iniciales.
)

# Renombrar la primera columna como fecha.
names(prices)[1] <- "date"

# Convertir temporalmente la fecha a texto para reconocer el formato AAAAMMM.
prices$date <- as.character(prices$date)

# Conservar unicamente filas cuya fecha tiene el formato 1960M01.
prices <- prices %>%
  filter(str_detect(date, "^[0-9]{4}M[0-9]{2}$"))

# Convertir cada periodo mensual en una fecha correspondiente al primer dia del mes.
prices <- prices %>%
  mutate(
    date = as.Date(
      # Separar ano y mes del texto y agregar el dia 01.
      paste0(substr(date,1,4), "-", substr(date,6,7), "-01")
    )
  )

# Mostrar la estructura inicial del archivo leido.
glimpse(prices)

# Convertir las columnas de commodities de texto a numerico
prices <- prices %>%
  mutate(
    # Aplicar la conversion a todas las columnas salvo la fecha.
    across(
      -date,
      # Retirar separadores de miles y convertir cada precio a numero.
      ~ as.numeric(gsub(",", "", .))
    )
  )

# Mostrar la estructura despues de convertir los precios a numeros.
glimpse(prices)

############################################################
# EXPORTAR DATASET A STATA (.DTA)
############################################################

# Normalizar los nombres de columnas antes de exportar.
prices <- prices %>%
  janitor::clean_names()

# Guardar una version limpia y reproducible de todos los precios en formato Stata.
write_dta(
  prices,                                          # Exportar la tabla mensual limpia.
  file.path(proc_path, "pink_sheet_clean.dta")    # Guardarla en la capa procesada.
)

# Volver a leer el .dta para confirmar que la exportacion es utilizable.
stata_data <- read_dta(
  file.path(proc_path, "pink_sheet_clean.dta")
)

# Dejar disponible una inspeccion visual opcional sin ejecutarla automaticamente.
# View(stata_data)
# Mostrar nombres de columnas como control de la estructura exportada.
names(stata_data)
# Mostrar nuevamente los nombres mediante una funcion equivalente.
colnames(stata_data)

############################################################
# Clean filtering for extractive commodities
############################################################

# Seleccionar solo precios de energia, metales industriales y metales preciosos.
extractive_prices <- stata_data %>%
  select(
    date,                        # Fecha mensual de la observacion.
    # Energia.
    crude_oil_average,
    coal_australian,
    coal_south_african,
    natural_gas_us,
    natural_gas_europe,
    liquefied_natural_gas_japan,
    # Metales industriales.
    aluminum,
    iron_ore_cfr_spot,
    copper,
    lead,
    tin,
    nickel,
    zinc,
    # Metales preciosos.
    gold,
    platinum,
    silver
  )

# Mostrar la estructura de la canasta extractiva seleccionada.
glimpse(extractive_prices)

############################################################
# Create labels with units and attach them before write_dta(). and export
############################################################

# Asignar a cada columna una etiqueta con el producto y su unidad de medida.
# Documentar primero los precios de productos energeticos.
attr(extractive_prices$crude_oil_average, "label") <- "Crude oil price, average (US$/bbl)"
attr(extractive_prices$coal_australian, "label") <- "Coal price, Australian (US$/mt)"
attr(extractive_prices$coal_south_african, "label") <- "Coal price, South African (US$/mt)"
attr(extractive_prices$natural_gas_us, "label") <- "Natural gas price, US (US$/mmbtu)"
attr(extractive_prices$natural_gas_europe, "label") <- "Natural gas price, Europe (US$/mmbtu)"
attr(extractive_prices$liquefied_natural_gas_japan, "label") <- "LNG price, Japan (US$/mmbtu)"
# Documentar despues los precios de metales industriales.
attr(extractive_prices$aluminum, "label") <- "Aluminum price (US$/mt)"
attr(extractive_prices$iron_ore_cfr_spot, "label") <- "Iron ore price, CFR spot (US$/mt)"
attr(extractive_prices$copper, "label") <- "Copper price (US$/mt)"
attr(extractive_prices$lead, "label") <- "Lead price (US$/mt)"
attr(extractive_prices$tin, "label") <- "Tin price (US$/mt)"
attr(extractive_prices$nickel, "label") <- "Nickel price (US$/mt)"
attr(extractive_prices$zinc, "label") <- "Zinc price (US$/mt)"
# Documentar finalmente los precios de metales preciosos.
attr(extractive_prices$gold, "label") <- "Gold price (US$/troy oz)"
attr(extractive_prices$platinum, "label") <- "Platinum price (US$/troy oz)"
attr(extractive_prices$silver, "label") <- "Silver price (US$/troy oz)"

############################################################
# Reordering the dataset (Energy → Industrial metals → Precious metals.)
############################################################

# Define the desired order
extractive_order <- c(
  "date",

  # Energy
  "crude_oil_average",
  "coal_australian",
  "coal_south_african",
  "natural_gas_us",
  "natural_gas_europe",
  "liquefied_natural_gas_japan",

  # Industrial metals
  "aluminum",
  "iron_ore_cfr_spot",
  "copper",
  "lead",
  "tin",
  "nickel",
  "zinc",

  # Precious metals
  "gold",
  "platinum",
  "silver"
)

# Reorder the dataset
extractive_prices <- extractive_prices %>%
  select(all_of(extractive_order))

# Commodity sector classification

commodity_sector <- tibble(
  commodity = extractive_order[-1],
  sector = c(
    rep("Energy", 6),
    rep("Industrial metals", 7),
    rep("Precious metals", 3)
  )
)

# Guardar nuevamente la version extractiva con etiquetas y orden sectorial.
write_dta(
  extractive_prices,                           # Exportar solo commodities extractivos.
  file.path(proc_path, "pink_sheet_clean.dta") # Reemplazar la version procesada.
)

############################################################
# 4. LIMPIEZA BÁSICA
############################################################

# Asegurar que la tabla general este ordenada cronologicamente.
prices <- prices %>%
  # Confirmar que la fecha use la clase Date.
  mutate(date = as.Date(date)) %>%
  # Ordenar desde el mes mas antiguo al mas reciente.
  arrange(date)

# Abrir la canasta extractiva en RStudio para inspeccion manual opcional.
View(extractive_prices)

############################################################
# 5. CALCULAR RETORNOS LOGARÍTMICOS
############################################################

# Calcular retornos mensuales como el logaritmo del precio actual sobre el previo.
returns <- extractive_prices %>%
  # Confirmar que los meses esten en orden antes de aplicar rezagos.
  arrange(date) %>%
  # Aplicar la misma formula a todas las columnas excepto la fecha.
  mutate(
    across(
      -date,
      # Calcular log(P_t / P_t-1) para cada commodity.
      ~ log(. / lag(.))
    )
  ) %>%
  # Eliminar la primera fila, que no tiene un periodo anterior.
  slice(-1)

############################################################
# 6. MATRIZ DE COVARIANZA DE RETORNOS
############################################################

# Convertir los retornos, sin la fecha, en una matriz numerica.
returns_matrix <- returns %>%
  select(-date) %>%
  as.matrix()

# Calcular covarianzas usando todos los pares de observaciones disponibles.
cov_matrix <- cov(
  returns_matrix,                # Matriz mensual de retornos.
  use = "pairwise.complete.obs" # Admitir historias con meses faltantes.
)

# Annualizar volatilidad (datos mensuales)
cov_matrix <- cov_matrix * 12

# Imprimir la matriz anualizada completa en la consola.
print(cov_matrix)

# Mostrar una version redondeada y legible de la matriz en la consola.
knitr::kable(
  round(cov_matrix, 4), # Redondear a cuatro decimales.
  caption = "Annualized Covariance Matrix of Commodity Returns" # Agregar titulo.
)

############################################################
# Heatmap (the best way to visualize covariance)
############################################################

# Convertir la matriz cuadrada en una tabla larga apta para ggplot.
cov_df <- melt(cov_matrix)

# Dibujar un mapa de calor donde color y signo representan la covarianza.
ggplot(cov_df, aes(Var1, Var2, fill = value)) +
  # Crear una celda para cada par de commodities.
  geom_tile() +
  # Usar azul para covarianzas negativas y rojo para positivas.
  scale_fill_gradient2(
    low = "blue",
    mid = "white",
    high = "red",
    midpoint = 0
  ) +
  # Aplicar un tema visual limpio.
  theme_minimal() +
  # Definir titulo y retirar textos redundantes de los ejes.
  labs(
    title = "Covariance Matrix of Commodity Returns",
    x = "",
    y = ""
  ) +
  # Rotar etiquetas para que todos los nombres sean legibles.
  theme(
    axis.text.x = element_text(angle = 60, hjust = 1),
    axis.text.y = element_text(size = 10)
  )

############################################################
# CORRELATION MATRIX OF COMMODITY RETURNS
############################################################

# Calcular correlaciones usando los pares mensuales disponibles.
cor_matrix <- cor(
  returns_matrix,
  use = "pairwise.complete.obs"
)

# Redondear a dos decimales para facilitar la lectura.
cor_matrix <- round(cor_matrix, 2)

# Imprimir la matriz de correlacion en la consola.
print(cor_matrix)

############################################################
# VISUALIZATION: CORRELATION HEATMAP
############################################################

# Abrir una ventana amplia para que las etiquetas no se superpongan.
dev.new(width = 10, height = 10)

# Visualizar el triangulo superior de la matriz de correlacion.
corrplot(
  cor_matrix,
  method = "color",      # color heatmap
  type = "upper",        # show upper triangle only
  order = "original",    # keep commodity order
  tl.col = "black",      # label color
  tl.srt = 45,           # rotate labels
  tl.cex = 0.8,          # label size
  addrect = 3            # draw rectangles for sector clusters
)

############################################################
# 1. VOLATILIDAD ANUAL DE CADA COMMODITY
############################################################

# Calcular una desviacion estandar mensual para cada commodity.
volatility <- returns %>%
  # Retirar la fecha porque no participa en el calculo.
  select(-date) %>%
  # Resumir cada columna de retornos en una sola desviacion estandar.
  summarise(
    across(
      everything(),
      # Ignorar meses faltantes al calcular cada desviacion.
      ~ sd(.x, na.rm = TRUE)
    )
  ) %>%
  # Pasar de una fila ancha a una tabla commodity-valor.
  pivot_longer(
    everything(),            # Reorganizar todas las columnas de productos.
    names_to = "commodity",  # Guardar el nombre del producto.
    values_to = "sd_monthly" # Guardar su volatilidad mensual.
  )


# 2. ANUALIZAR VOLATILIDAD

# Convertir volatilidad mensual a anual multiplicando por raiz de doce.
volatility <- volatility %>%
  mutate(
    sd_annual = sd_monthly * sqrt(12)
  ) %>%
  # Eliminar commodities cuya volatilidad no pudo calcularse.
  filter(!is.na(sd_annual)) %>%
  # Ordenar desde la mayor volatilidad anual a la menor.
  arrange(desc(sd_annual))

# Mostrar la tabla ordenada de volatilidades.
print(volatility)

# 3. GRÁFICO MEJORADO

# Construir un grafico de barras horizontales ordenado por volatilidad.
ggplot(
  volatility,
  aes(
    x = fct_reorder(commodity, sd_annual),
    y = sd_annual,
    fill = sd_annual
  )
) +

  # Dibujar una barra para cada commodity.
  geom_col(width = 0.75) +

  # Intercambiar ejes para facilitar la lectura de nombres largos.
  coord_flip() +

  # Usar un azul mas oscuro para volatilidades mayores.
  scale_fill_gradient(
    low = "#9ecae1",
    high = "#08519c"
  ) +

  # Definir titulos y unidades de los ejes.
  labs(
    title = "Annual Volatility of Commodity Returns",
    subtitle = "Computed from monthly log returns (Pink Sheet data)",
    x = "",
    y = "Annualized volatility (standard deviation)"
  ) +

  # Aplicar un tema limpio con texto base legible.
  theme_minimal(base_size = 13) +

  # Ajustar leyenda, textos y lineas de referencia.
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(size = 12, color = "gray40"),
    axis.text.y = element_text(size = 11),
    axis.text.x = element_text(size = 10),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank()
  )

############################################################
# 2. SECTOR PRICE INDICES
############################################################

# Calcular el retorno sectorial de energia como promedio mensual de sus productos.
energy_index <- returns %>%
  select(crude_oil_average, coal_australian, coal_south_african,
         natural_gas_us, natural_gas_europe, liquefied_natural_gas_japan) %>%
  rowMeans(na.rm = TRUE)

# Calcular el retorno promedio de los metales industriales.
industrial_index <- returns %>%
  select(aluminum, iron_ore_cfr_spot, copper, lead, tin, nickel, zinc) %>%
  rowMeans(na.rm = TRUE)

# Calcular el retorno promedio de los metales preciosos.
precious_index <- returns %>%
  select(gold, platinum, silver) %>%
  rowMeans(na.rm = TRUE)

# Reunir fecha y tres retornos sectoriales en una sola tabla.
sector_returns <- tibble(
  date = returns$date,                   # Fecha mensual.
  energy = energy_index,                 # Retorno promedio de energia.
  industrial_metals = industrial_index, # Retorno promedio de metales industriales.
  precious_metals = precious_index       # Retorno promedio de metales preciosos.
)

# Convertir los sectores de columnas a filas para graficarlos conjuntamente.
sector_returns_long <- sector_returns %>%
  pivot_longer(-date)

ggplot(
  sector_returns_long,
  aes(date, value, color = name)
) +

  geom_line(
    linewidth = 0.6,
    alpha = 0.8
  ) +

  scale_color_manual(
    values = c(
      "energy" = "#d73027",
      "industrial_metals" = "#1a9850",
      "precious_metals" = "#4575b4"
    ),
    labels = c(
      "Energy",
      "Industrial metals",
      "Precious metals"
    )
  ) +

  labs(
    title = "Commodity Sector Returns",
    subtitle = "Monthly log returns constructed from World Bank Pink Sheet prices",
    x = "",
    y = "Log return",
    color = "Sector"
  ) +

  theme_minimal(base_size = 13) +

  theme(
    legend.position = "top",
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    panel.grid.minor = element_blank()
  )

# Gráfico de volatilidad (mucho más claro)

ggplot(sector_vol_long, aes(date, value, color = name)) +

  geom_line(linewidth = 1) +

  scale_x_date(
    date_breaks = "5 years",
    date_labels = "%Y"
  ) +

  scale_color_manual(
    values = c(
      "energy_vol" = "#d73027",
      "industrial_vol" = "#1a9850",
      "precious_vol" = "#4575b4"
    ),
    labels = c(
      "Energy",
      "Industrial metals",
      "Precious metals"
    )
  ) +

  theme_minimal(base_size = 13) +

  labs(
    title = "Rolling 12-Month Volatility of Commodity Sectors",
    subtitle = "Volatility computed from monthly log returns",
    x = "",
    y = "Volatility",
    color = "Sector"
  ) +

  theme(
    legend.position = "top",
    panel.grid.minor = element_blank()
  )

############################################################
# GRÁFICO MEJORADO CON EVENTOS HISTÓRICOS
############################################################

# Crear una tabla de choques historicos que se marcaran en el grafico.
events <- tibble(
  # Registrar una etiqueta corta para cada episodio.
  event = c(
    "Oil shock",
    "Global inflation / gold spike",
    "Global financial crisis",
    "COVID shock",
    "Energy crisis"
  ),
  # Asignar una fecha mensual representativa a cada episodio.
  date = as.Date(c(
    "1973-10-01",
    "1980-01-01",
    "2009-03-01",
    "2020-03-01",
    "2022-02-01"
  ))
)

# GRÁFICO FINAL

ggplot(sector_vol_long, aes(date, value, color = name)) +

  geom_line(linewidth = 1) +

  # líneas verticales eventos
  geom_vline(
    data = events,
    aes(xintercept = date),
    linetype = "dashed",
    color = "black",
    alpha = 0.7
  ) +

  # etiquetas de eventos
  geom_text(
    data = events,
    aes(x = date, y = 0.23, label = event),
    angle = 90,
    vjust = -0.4,
    size = 3,
    inherit.aes = FALSE
  ) +

  scale_x_date(
    date_breaks = "5 years",
    date_labels = "%Y"
  ) +

  scale_y_continuous(
    limits = c(0, 0.24)   # deja espacio para etiquetas
  ) +

  scale_color_manual(
    values = c(
      "energy_vol" = "#d73027",
      "industrial_vol" = "#1a9850",
      "precious_vol" = "#4575b4"
    ),
    labels = c(
      "Energy",
      "Industrial metals",
      "Precious metals"
    )
  ) +

  coord_cartesian(clip = "off") +

  theme_minimal(base_size = 13) +

  labs(
    title = "Rolling 12-Month Volatility of Commodity Sectors",
    subtitle = "Volatility computed from monthly log returns",
    x = "",
    y = "Volatility",
    color = "Sector"
  ) +

  theme(
    legend.position = "top",
    panel.grid.minor = element_blank(),

    # margen superior extra para texto
    plot.margin = margin(
      t = 25,
      r = 20,
      b = 10,
      l = 10
    )
  )

############################################################
# 3. PRINCIPAL COMPONENT ANALYSIS
############################################################

# PCA no acepta NA ni valores infinitos
# primero limpiamos la matriz de retornos

returns_matrix_clean <- returns_matrix

# reemplazar infinitos por NA
returns_matrix_clean[is.infinite(returns_matrix_clean)] <- NA

# eliminar filas con NA solo para PCA
returns_matrix_pca <- returns_matrix_clean[
  complete.cases(returns_matrix_clean),
]

# correr PCA
pca <- prcomp(
  returns_matrix_pca,
  scale. = TRUE
)

# resumen del PCA
summary(pca)

# extraer loadings
pca_loadings <- as.data.frame(pca$rotation)

# imprimir los primeros tres componentes
print(pca_loadings[,1:3])

# PCA LOADINGS PLOT (PC1)

# extraer loadings del primer componente
pc1_loadings <- pca_loadings %>%
  rownames_to_column("commodity") %>%
  select(commodity, PC1)

# ordenar por magnitud del loading
pc1_loadings <- pc1_loadings %>%
  arrange(desc(abs(PC1)))

# gráfico
ggplot(pc1_loadings,
       aes(x = fct_reorder(commodity, PC1), y = PC1, fill = PC1)) +

  geom_col(width = 0.75) +

  coord_flip() +

  scale_fill_gradient2(
    low = "#2166ac",
    mid = "white",
    high = "#b2182b",
    midpoint = 0
  ) +

  theme_minimal(base_size = 13) +

  labs(
    title = "Contribution of Commodities to the Global Shock Factor (PC1)",
    subtitle = "Principal Component Analysis of commodity returns",
    x = "",
    y = "PC1 Loading"
  ) +

  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank()
  )

screeplot(pca, type = "lines")

############################################################
# 4. HIERARCHICAL CLUSTERING
############################################################

# without boxes classification

dist_matrix <- dist(t(returns_matrix))

cluster <- hclust(dist_matrix)

plot(cluster,
     main = "Commodity Price Clusters",
     xlab = "",
     sub = "")

# 1. Compute distance between commodities
dist_matrix <- dist(
  t(returns_matrix),
  method = "euclidean"
)

# 2. Hierarchical clustering (Ward method works well for economic data)
cluster <- hclust(
  dist_matrix,
  method = "ward.D2"
)

# 3. Plot dendrogram
plot(
  cluster,
  main = "Commodity Price Clusters",
  xlab = "",
  sub = "",
  cex = 0.9
)

# 4. Highlight clusters (optional but useful)
rect.hclust(cluster, k = 4, border = "red")

# 5. PCA BIPLOT (PC1 vs PC2)

# 1. Extract loadings from PCA
pca_loadings <- as.data.frame(pca$rotation)

# 2. Keep only first two principal components
pca_plot_data <- pca_loadings[, 1:2]
pca_plot_data$commodity <- rownames(pca_plot_data)

############################################################
# 5. PCA SCATTER (PC1 vs PC2)
############################################################
graphics.off()

# Extract loadings
pca_loadings <- as.data.frame(pca$rotation)

# Keep first two PCs
pca_plot_data <- pca_loadings[,1:2]
pca_plot_data$commodity <- rownames(pca_plot_data)

# Sector classification
ggplot(pca_plot_data, aes(PC1, PC2, color = sector)) +

  geom_point(size = 4) +

  geom_text(aes(label = commodity), vjust = -0.8) +

  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.4) +
  geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.4) +

  theme_minimal() +

  labs(
    title = "Commodity Market Structure in PCA Space",
    x = "PC1",
    y = "PC2"
  )


############################################################
# 6. GLOBAL COMMODITY SHOCK INDEX
############################################################

# Calcular el choque global como el retorno promedio de los commodities disponibles.
returns$global_shock <- rowMeans(
  returns %>% select(-date), # Promediar todas las series salvo la fecha.
  na.rm = TRUE               # Ignorar faltantes mensuales.
)

# Crear una tabla de eventos historicos para contextualizar la serie global.
events <- tibble(
  # Registrar una etiqueta legible para cada episodio.
  event = c(
    "Oil shock",
    "Second oil shock",
    "Global financial crisis",
    "COVID shock"
  ),
  # Asignar una fecha representativa a cada choque.
  date = as.Date(c(
    "1973-10-01",
    "1979-01-01",
    "2008-09-01",
    "2020-03-01"
  ))
)

# Graficar el choque promedio y marcar los principales episodios historicos.
ggplot(returns, aes(date, global_shock)) +

  geom_line(color = "#8b2f2f", linewidth = 0.6) +

  geom_hline(yintercept = 0,
             linetype = "dashed",
             alpha = 0.5) +

  geom_vline(
    data = events,
    aes(xintercept = date),
    linetype = "dashed",
    color = "black",
    alpha = 0.6
  ) +

  geom_smooth(
    method = "loess",
    se = FALSE,
    color = "black",
    linewidth = 0.8
  ) +

  theme_minimal(base_size = 13) +

  labs(
    title = "Global Commodity Shock Index",
    subtitle = "Average monthly returns across commodities",
    x = "",
    y = "Global shock"
  ) +

  theme(
    panel.grid.minor = element_blank()
  )

############################################################
# COMMODITY PRICE NETWORK
# Correlation-based transmission of commodity shocks
############################################################

############################################################
# 1. COMPUTE CORRELATION MATRIX
############################################################

cor_matrix <- cor(
  returns_matrix,
  use = "pairwise.complete.obs"
)

############################################################
# 2. CONVERT CORRELATION MATRIX TO EDGE LIST
############################################################

cor_df <- as.data.frame(as.table(cor_matrix))

names(cor_df) <- c("commodity1", "commodity2", "correlation")

# remove self correlations
cor_df <- cor_df %>%
  filter(commodity1 != commodity2)

# keep only strong correlations
threshold <- 0.4

cor_df <- cor_df %>%
  filter(abs(correlation) > threshold)

############################################################
# 3. CREATE COMMODITY NETWORK
############################################################

commodity_network <- graph_from_data_frame(
  cor_df,
  directed = FALSE
)

# store correlation as edge weight
E(commodity_network)$weight <- cor_df$correlation

# node centrality (how connected each commodity is)
V(commodity_network)$degree <- degree(commodity_network)

############################################################
# 4. ADD SECTOR INFORMATION
############################################################

sector_data <- tibble(
  commodity = colnames(returns_matrix),
  sector = c(
    rep("Energy", 6),
    rep("Industrial metals", 7),
    rep("Precious metals", 3)
  )
)

V(commodity_network)$sector <- sector_data$sector[
  match(V(commodity_network)$name, sector_data$commodity)
]

############################################################
# 5. PLOT NETWORK
############################################################

ggraph(commodity_network, layout = "fr") +

  geom_edge_link(
    aes(width = abs(weight)),
    alpha = 0.6,
    colour = "grey40"
  ) +

  geom_node_point(
    aes(color = sector, size = degree)
  ) +

  geom_node_text(
    aes(label = name),
    repel = TRUE,
    size = 4
  ) +

  scale_edge_width(range = c(0.3, 2)) +

  theme_void() +

  labs(
    title = "Commodity Price Network",
    subtitle = "Edges represent correlations above |0.4|"
  ) +

  scale_size(range = c(4,8))



########################################################################################### PART II.

############################################################
# 7. CARGAR ESPECIALIZACIÓN DE COMMODITIES POR PAÍS
############################################################

# Leer la base de especializacion extractiva reproducida desde Anne (2021).
specialization <- read_dta(
  file.path(
    project_path, "data", "processed", "literature", "anne2021",
    "commodity_specialization.dta" # Abrir la tabla de productos y ponderaciones.
  )
)

# Mostrar la estructura de la base leida.
glimpse(specialization)

############################################################
# 8. EXTRAER COMMODITIES PRINCIPALES Y SUS PESOS
############################################################

# Guardar los nombres de commodities incluidos en la matriz de covarianza.
commodities <- colnames(cov_matrix)

# Convertir la lista de productos de cada pais en una fila por producto y peso.
parsed_weights <- specialization %>%
  # Conservar el pais y la cadena con productos y participaciones.
  select(country, main_commodities) %>%
  # Asegurar que la lista de productos sea texto simple.
  mutate(main_commodities = as.character(main_commodities)) %>%
  # Separar en filas distintas los productos delimitados por comas.
  separate_rows(main_commodities, sep = ",") %>%
  # Eliminar espacios sobrantes al inicio y final de cada producto.
  mutate(main_commodities = str_trim(main_commodities)) %>%
  # Separar el nombre del producto y su participacion numerica.
  extract(
    main_commodities,                     # Procesar la cadena producto-peso.
    into = c("commodity_name", "share"), # Crear dos columnas nuevas.
    regex = "([A-Za-z ]+) ([0-9\\.]+)", # Reconocer texto seguido de un numero.
    remove = TRUE                         # Retirar la cadena original ya separada.
  ) %>%
  # Convertir porcentajes a proporciones y normalizar los nombres de productos.
  mutate(
    share = as.numeric(share) / 100,                    # Pasar de porcentaje a 0-1.
    commodity_name = str_to_lower(str_trim(commodity_name)) # Limpiar y usar minusculas.
  )

############################################################
# 9. MAPEAR NOMBRES A COMMODITIES DEL PINK SHEET
############################################################

# Traducir los nombres del articulo a las columnas disponibles en la Pink Sheet.
parsed_weights <- parsed_weights %>%
  mutate(
    commodity = case_when(
      str_detect(commodity_name, "oil") ~ "crude_oil_average", # Petroleo.
      str_detect(commodity_name, "gas") ~ "natural_gas_us",    # Gas natural.
      str_detect(commodity_name, "coal") ~ "coal_australian", # Carbon.
      str_detect(commodity_name, "copper") ~ "copper",        # Cobre.
      str_detect(commodity_name, "aluminum") ~ "aluminum",    # Aluminio.
      str_detect(commodity_name, "iron") ~ "iron_ore_cfr_spot", # Mineral de hierro.
      str_detect(commodity_name, "gold") ~ "gold",            # Oro.
      str_detect(commodity_name, "silver") ~ "silver",        # Plata.
      str_detect(commodity_name, "nickel") ~ "nickel",        # Niquel.
      str_detect(commodity_name, "zinc") ~ "zinc",            # Zinc.
      str_detect(commodity_name, "tin") ~ "tin",              # Estano.
      str_detect(commodity_name, "lead") ~ "lead",            # Plomo.
      TRUE ~ NA_character_                                       # Sin equivalencia disponible.
    )
  ) %>%
  # Excluir productos que no pudieron vincularse con una serie de precios.
  filter(!is.na(commodity))

############################################################
# 10. CONSTRUIR MATRIZ DE PESOS POR PAÍS
############################################################

# Construir una matriz con una fila por pais y una columna por commodity.
export_weights <- parsed_weights %>%
  # Agrupar posibles repeticiones del mismo producto dentro de un pais.
  group_by(country, commodity) %>%
  # Sumar sus participaciones y retirar la agrupacion.
  summarise(
    share = sum(share), # Peso exportador total del commodity en el pais.
    .groups = "drop"   # Devolver una tabla sin grupos activos.
  ) %>%
  # Convertir nombres de commodities en columnas separadas.
  pivot_wider(
    names_from = commodity, # Usar el producto como nombre de columna.
    values_from = share     # Rellenar cada celda con su participacion.
  )

# Interpretar combinaciones pais-producto ausentes como peso igual a cero.
export_weights[is.na(export_weights)] <- 0

# Identificar commodities de la covarianza que no aparecen en las exportaciones.
missing_cols <- setdiff(commodities, colnames(export_weights))

# Crear con ceros cualquier columna faltante para alinear pesos y covarianzas.
for (commodity_name in missing_cols) {
  export_weights[[commodity_name]] <- 0
}

# Ordenar las columnas exactamente como aparecen en la matriz de covarianza.
export_weights <- export_weights %>%
  select(country, all_of(commodities))

############################################################
# 11. FUNCIÓN PARA CALCULAR EXPOSURE INDEX
############################################################

# Definir una funcion que calcula la varianza de una canasta: w' Sigma w.
# Entradas: vector de pesos w y matriz de covarianza Sigma.
# Salida: varianza escalar de la exposicion del pais.
compute_exposure <- function(w, Sigma) {

  # Convertir los pesos recibidos a un vector numerico simple.
  w <- as.numeric(w)

# Normalizar los pesos para que sumen uno cuando existe alguna participacion.
  if (sum(w) > 0) {
    w <- w / sum(w)
  }

  # Convertir el vector en matriz columna para realizar algebra matricial.
  w <- as.matrix(w)

  # Aplicar la formula de varianza de portafolio a precios de commodities.
  exposure <- t(w) %*% Sigma %*% w

  # Devolver el resultado como un numero y no como una matriz de 1 por 1.
  return(as.numeric(exposure))
}

############################################################
# 12. CALCULAR EXPOSURE PARA TODOS LOS PAÍSES
############################################################

# Calcular la exposicion separadamente para cada fila-pais.
exposure_results <- export_weights %>%
  # Activar operaciones fila por fila.
  rowwise() %>%
  # Crear la varianza de exposicion usando todos los pesos excepto el pais.
  mutate(
    shock_exposure_variance = compute_exposure(
      c_across(-country), # Reunir las participaciones del pais actual.
      cov_matrix          # Usar la covarianza anualizada de retornos.
    )
  ) %>%
  # Desactivar el modo fila por fila una vez terminado el calculo.
  ungroup()

############################################################
# 13. EXPOSURE EN DESVIACIÓN ESTÁNDAR
############################################################

# Convertir la varianza de exposicion en desviacion estandar interpretable.
exposure_results <- exposure_results %>%
  mutate(
    shock_exposure_sd = sqrt(shock_exposure_variance)
  )

# Imprimir todos los resultados en la consola para inspeccion.
print(exposure_results)

############################################################
# 14. GUARDAR RESULTADOS
############################################################

# Guardar la matriz de pesos y los dos indices de exposicion por pais.
write_csv(
  exposure_results,                                      # Exportar los resultados.
  file.path(proc_path, "country_shock_exposure_index.csv") # Usar la carpeta procesada.
)

# Mostrar los veinte paises con mayor desviacion estandar de exposicion.
exposure_results %>%
  arrange(desc(shock_exposure_sd)) %>%
  print(n = 20)

# Resumir la distribucion del indice mediante estadisticas basicas.
summary(exposure_results$shock_exposure_sd)

# Graficar un histograma de exposicion entre paises.
ggplot(exposure_results, aes(x = shock_exposure_sd)) +
  geom_histogram(bins = 25, fill = "steelblue") +
  theme_minimal() +
  labs(
    title = "Distribution of Commodity Shock Exposure",
    x = "Exposure (Standard Deviation)",
    y = "Countries"
  )

# Unir dependencia exportadora y exposicion para explorar su relacion.
merged <- specialization %>%
  # Conservar las medidas descriptivas de dependencia extractiva.
  select(country, commodities, energy, mining) %>%
  # Agregar los indices calculados usando el nombre del pais.
  left_join(exposure_results, by = "country")

# Graficar dependencia extractiva total frente al indice de exposicion.
ggplot(merged, aes(commodities, shock_exposure_sd)) +
  geom_point() +
  theme_minimal() +
  labs(
    x = "Commodity Export Share",
    y = "Shock Exposure Index",
    title = "Commodity Dependence and Shock Exposure"
  )

# Graficar los veinte paises con mayor exposicion a choques.
ggplot(
  exposure_results %>% arrange(desc(shock_exposure_sd)) %>% slice(1:20),
  aes(
    x = reorder(country, shock_exposure_sd),
    y = shock_exposure_sd
  )
) +
  geom_col(fill = "darkred") +
  coord_flip() +
  theme_minimal() +
  labs(
    title = "Top 20 Countries by Commodity Shock Exposure",
    x = "",
    y = "Exposure (Std. Dev.)"
  )

############################################################
# FIN
############################################################
