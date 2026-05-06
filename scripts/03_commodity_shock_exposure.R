############################################################
# SHOCK EXPOSURE INDEX
# Commodity price volatility exposure
############################################################

########################################################################################### PART I.

############################################################
# 1. INSTALAR Y CARGAR LIBRERÍAS
############################################################

library(tidyverse)
library(readxl)
library(lubridate)
library(rugarch)
library(haven)
library(janitor)
library(ggplot2)
library(reshape2)
library(corrplot)
library(dplyr)
library(stringr)
library(readr)
library(tidyr)
library(purrr)
library(ggplot2)
library(igraph)
library(ggraph)
library(tidygraph)
library(zoo)
library(forcats)
library(ggrepel)

############################################################
# PATHS DEL PROYECTO
############################################################

project_path <- "C:/Users/julla/Downloads/1. Tesis de Maestría"

raw_path  <- file.path(project_path, "data", "raw")
proc_path <- file.path(project_path, "data", "processed")

############################################################
# CARGAR PRECIOS DE COMMODITIES (PINK SHEET)
############################################################

prices <- read_excel(
  "C:/Users/julla/Downloads/1. Tesis de Maestría/data/raw/the_pink_sheet/CMO-Historical-Data-Monthly.xlsx",
  sheet = "Monthly Prices",
  skip = 4
)

names(prices)[1] <- "date"

# convert to character
prices$date <- as.character(prices$date)

# keep only rows that look like 1960M01
prices <- prices %>%
  filter(str_detect(date, "^[0-9]{4}M[0-9]{2}$"))

# convert to proper Date
prices <- prices %>%
  mutate(
    date = as.Date(
      paste0(substr(date,1,4), "-", substr(date,6,7), "-01")
    )
  )

glimpse(prices)

# Convertir las columnas de commodities de texto a numerico
prices <- prices %>%
  mutate(
    across(
      -date,
      ~ as.numeric(gsub(",", "", .))
    )
  )

glimpse(prices)

############################################################
# EXPORTAR DATASET A STATA (.DTA)
############################################################

# clean column names before exporting
prices <- prices %>%
  janitor::clean_names()

# export data
write_dta(
  prices,
  "C:/Users/julla/Downloads/1. Tesis de Maestría/data/processed/pink_sheet_clean.dta"
)

# read again
stata_data <- read_dta(
  "C:/Users/julla/Downloads/1. Tesis de Maestría/data/processed/pink_sheet_clean.dta"
)

# open viewer
# View(stata_data)
names(stata_data)
colnames(stata_data)

############################################################
# Clean filtering for extractive commodities
############################################################

# filtering
extractive_prices <- stata_data %>%
  select(
    date,
    crude_oil_average,
    coal_australian,
    coal_south_african,
    natural_gas_us,
    natural_gas_europe,
    liquefied_natural_gas_japan,
    aluminum,
    iron_ore_cfr_spot,
    copper,
    lead,
    tin,
    nickel,
    zinc,
    gold,
    platinum,
    silver
  )

# check
glimpse(extractive_prices)

############################################################
# Create labels with units and attach them before write_dta(). and export
############################################################

attr(extractive_prices$crude_oil_average, "label") <- "Crude oil price, average (US$/bbl)"
attr(extractive_prices$coal_australian, "label") <- "Coal price, Australian (US$/mt)"
attr(extractive_prices$coal_south_african, "label") <- "Coal price, South African (US$/mt)"
attr(extractive_prices$natural_gas_us, "label") <- "Natural gas price, US (US$/mmbtu)"
attr(extractive_prices$natural_gas_europe, "label") <- "Natural gas price, Europe (US$/mmbtu)"
attr(extractive_prices$liquefied_natural_gas_japan, "label") <- "LNG price, Japan (US$/mmbtu)"
attr(extractive_prices$aluminum, "label") <- "Aluminum price (US$/mt)"
attr(extractive_prices$iron_ore_cfr_spot, "label") <- "Iron ore price, CFR spot (US$/mt)"
attr(extractive_prices$copper, "label") <- "Copper price (US$/mt)"
attr(extractive_prices$lead, "label") <- "Lead price (US$/mt)"
attr(extractive_prices$tin, "label") <- "Tin price (US$/mt)"
attr(extractive_prices$nickel, "label") <- "Nickel price (US$/mt)"
attr(extractive_prices$zinc, "label") <- "Zinc price (US$/mt)"
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

# export
write_dta(
  extractive_prices,
  "C:/Users/julla/Downloads/1. Tesis de Maestría/data/processed/pink_sheet_clean.dta"
)

############################################################
# 4. LIMPIEZA BÁSICA
############################################################

prices <- prices %>%
  mutate(date = as.Date(date)) %>%
  arrange(date)

# open viewer
View(extractive_prices)

############################################################
# 5. CALCULAR RETORNOS LOGARÍTMICOS
############################################################

returns <- extractive_prices %>%
  arrange(date) %>%
  mutate(
    across(
      -date,
      ~ log(. / lag(.))
    )
  ) %>%
  slice(-1)   # eliminar primera fila con NA

############################################################
# 6. MATRIZ DE COVARIANZA DE RETORNOS
############################################################

returns_matrix <- returns %>%
  select(-date) %>%
  as.matrix()

cov_matrix <- cov(
  returns_matrix,
  use = "pairwise.complete.obs"
)

# Annualizar volatilidad (datos mensuales)
cov_matrix <- cov_matrix * 12

print(cov_matrix)

# Clean console table
knitr::kable(
  round(cov_matrix, 4),
  caption = "Annualized Covariance Matrix of Commodity Returns"
)

############################################################
# Heatmap (the best way to visualize covariance)
############################################################

cov_df <- melt(cov_matrix)

ggplot(cov_df, aes(Var1, Var2, fill = value)) +
  geom_tile() +
  scale_fill_gradient2(
    low = "blue",
    mid = "white",
    high = "red",
    midpoint = 0
  ) +
  theme_minimal() +
  labs(
    title = "Covariance Matrix of Commodity Returns",
    x = "",
    y = ""
  ) +
  theme(
    axis.text.x = element_text(angle = 60, hjust = 1),
    axis.text.y = element_text(size = 10)
  )

############################################################
# CORRELATION MATRIX OF COMMODITY RETURNS
############################################################

# Compute correlation matrix
cor_matrix <- cor(
  returns_matrix,
  use = "pairwise.complete.obs"
)

# Round for easier interpretation
cor_matrix <- round(cor_matrix, 2)

# Print matrix in console
print(cor_matrix)

############################################################
# VISUALIZATION: CORRELATION HEATMAP
############################################################

# Open larger plotting window (important for readability)
dev.new(width = 10, height = 10)

# Plot correlation matrix
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

# calcular desviación estándar mensual ignorando NA
volatility <- returns %>%
  select(-date) %>%
  summarise(
    across(
      everything(),
      ~ sd(.x, na.rm = TRUE)
    )
  ) %>%
  pivot_longer(
    everything(),
    names_to = "commodity",
    values_to = "sd_monthly"
  )


# 2. ANUALIZAR VOLATILIDAD

volatility <- volatility %>%
  mutate(
    sd_annual = sd_monthly * sqrt(12)
  ) %>%
  filter(!is.na(sd_annual)) %>%      # eliminar commodities sin datos
  arrange(desc(sd_annual))

print(volatility)

# 3. GRÁFICO MEJORADO

ggplot(
  volatility,
  aes(
    x = fct_reorder(commodity, sd_annual),
    y = sd_annual,
    fill = sd_annual
  )
) +
  
  geom_col(width = 0.75) +
  
  coord_flip() +
  
  scale_fill_gradient(
    low = "#9ecae1",
    high = "#08519c"
  ) +
  
  labs(
    title = "Annual Volatility of Commodity Returns",
    subtitle = "Computed from monthly log returns (Pink Sheet data)",
    x = "",
    y = "Annualized volatility (standard deviation)"
  ) +
  
  theme_minimal(base_size = 13) +
  
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

energy_index <- returns %>%
  select(crude_oil_average, coal_australian, coal_south_african,
         natural_gas_us, natural_gas_europe, liquefied_natural_gas_japan) %>%
  rowMeans(na.rm = TRUE)

industrial_index <- returns %>%
  select(aluminum, iron_ore_cfr_spot, copper, lead, tin, nickel, zinc) %>%
  rowMeans(na.rm = TRUE)

precious_index <- returns %>%
  select(gold, platinum, silver) %>%
  rowMeans(na.rm = TRUE)

sector_returns <- tibble(
  date = returns$date,
  energy = energy_index,
  industrial_metals = industrial_index,
  precious_metals = precious_index
)

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

events <- tibble(
  event = c(
    "Oil shock",
    "Global inflation / gold spike",
    "Global financial crisis",
    "COVID shock",
    "Energy crisis"
  ),
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

# Compute global shock index
returns$global_shock <- rowMeans(
  returns %>% select(-date),
  na.rm = TRUE
)

# Important historical events
events <- tibble(
  event = c(
    "Oil shock",
    "Second oil shock",
    "Global financial crisis",
    "COVID shock"
  ),
  date = as.Date(c(
    "1973-10-01",
    "1979-01-01",
    "2008-09-01",
    "2020-03-01"
  ))
)

# Plot
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

specialization <- read_dta(
  "C:/Users/julla/Downloads/1. Tesis de Maestría/data/processed/commodity_specialization.dta"
)

glimpse(specialization)

############################################################
# 8. EXTRAER COMMODITIES PRINCIPALES Y SUS PESOS
############################################################

commodities <- colnames(cov_matrix)

parsed_weights <- specialization %>%
  select(country, main_commodities) %>%
  mutate(main_commodities = as.character(main_commodities)) %>%
  separate_rows(main_commodities, sep = ",") %>%
  mutate(main_commodities = str_trim(main_commodities)) %>%
  extract(
    main_commodities,
    into = c("commodity_name", "share"),
    regex = "([A-Za-z ]+) ([0-9\\.]+)",
    remove = TRUE
  ) %>%
  mutate(
    share = as.numeric(share) / 100,
    commodity_name = str_to_lower(str_trim(commodity_name))
  )

############################################################
# 9. MAPEAR NOMBRES A COMMODITIES DEL PINK SHEET
############################################################

parsed_weights <- parsed_weights %>%
  mutate(
    commodity = case_when(
      str_detect(commodity_name, "oil") ~ "crude_oil_average",
      str_detect(commodity_name, "gas") ~ "natural_gas_us",
      str_detect(commodity_name, "coal") ~ "coal_australian",
      str_detect(commodity_name, "copper") ~ "copper",
      str_detect(commodity_name, "aluminum") ~ "aluminum",
      str_detect(commodity_name, "iron") ~ "iron_ore_cfr_spot",
      str_detect(commodity_name, "gold") ~ "gold",
      str_detect(commodity_name, "silver") ~ "silver",
      str_detect(commodity_name, "nickel") ~ "nickel",
      str_detect(commodity_name, "zinc") ~ "zinc",
      str_detect(commodity_name, "tin") ~ "tin",
      str_detect(commodity_name, "lead") ~ "lead",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(commodity))

############################################################
# 10. CONSTRUIR MATRIZ DE PESOS POR PAÍS
############################################################

export_weights <- parsed_weights %>%
  group_by(country, commodity) %>%
  summarise(
    share = sum(share),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = commodity,
    values_from = share
  )

# replace NA with 0
export_weights[is.na(export_weights)] <- 0

# ensure all covariance commodities exist
missing_cols <- setdiff(commodities, colnames(export_weights))

for(c in missing_cols){
  export_weights[[c]] <- 0
}

export_weights <- export_weights %>%
  select(country, all_of(commodities))

############################################################
# 11. FUNCIÓN PARA CALCULAR EXPOSURE INDEX
############################################################

compute_exposure <- function(w, Sigma) {
  
  w <- as.numeric(w)
  
  if(sum(w) > 0){
    w <- w / sum(w)
  }
  
  w <- as.matrix(w)
  
  exposure <- t(w) %*% Sigma %*% w
  
  return(as.numeric(exposure))
}

############################################################
# 12. CALCULAR EXPOSURE PARA TODOS LOS PAÍSES
############################################################

exposure_results <- export_weights %>%
  rowwise() %>%
  mutate(
    shock_exposure_variance = compute_exposure(
      c_across(-country),
      cov_matrix
    )
  ) %>%
  ungroup()

############################################################
# 13. EXPOSURE EN DESVIACIÓN ESTÁNDAR
############################################################

exposure_results <- exposure_results %>%
  mutate(
    shock_exposure_sd = sqrt(shock_exposure_variance)
  )

print(exposure_results)

############################################################
# 14. GUARDAR RESULTADOS
############################################################

write_csv(
  exposure_results,
  file.path(proc_path, "country_shock_exposure_index.csv")
)

# Ver los resultados ordenados

exposure_results %>%
  arrange(desc(shock_exposure_sd)) %>%
  print(n = 20)

# Ver distribución del índice

summary(exposure_results$shock_exposure_sd)

ggplot(exposure_results, aes(x = shock_exposure_sd)) +
  geom_histogram(bins = 25, fill = "steelblue") +
  theme_minimal() +
  labs(
    title = "Distribution of Commodity Shock Exposure",
    x = "Exposure (Standard Deviation)",
    y = "Countries"
  )

# verificar si países más dependientes también tienen mayor exposición.

merged <- specialization %>%
  select(country, commodities, energy, mining) %>%
  left_join(exposure_results, by = "country")

# Gráfico simple:

ggplot(merged, aes(commodities, shock_exposure_sd)) +
  geom_point() +
  theme_minimal() +
  labs(
    x = "Commodity Export Share",
    y = "Shock Exposure Index",
    title = "Commodity Dependence and Shock Exposure"
  )

# Gráfico para explorar

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