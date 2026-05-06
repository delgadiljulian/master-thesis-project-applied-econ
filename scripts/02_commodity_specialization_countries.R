## TABLA/DATOS DE LA THESIS ANNE (2021): Beyond the resource curse: Macroeconomic strategies in resource dependent economies

library(pdftools)
library(stringr)
library(dplyr)
library(haven)
library(labelled)
library(ggplot2)
library(ggtern)

####################################################################################################
# CONSTRUCCIÓN DEL PANEL
####################################################################################################

# Ruta del PDF

pdf_file <- "C:/Users/julla/Downloads/1. Tesis de Maestría/docs/literature/Resource Dependent Economies/40.pdf"

# Leer PDF

txt <- pdf_text(pdf_file)

# Páginas con las tablas

pages <- c(28, 29, 30, 31)

# Etiquetas de grupo de ingreso

income_labels <- c("LIC", "LMIC", "UMIC", "HIC")

# Función para extraer tabla

extract_table <- function(page_number, income_group) {
  
  page_text <- txt[page_number]
  
  lines <- unlist(str_split(page_text, "\n"))
  lines <- lines[lines != ""]
  
  country_rows <- lines[str_detect(lines, "\\([A-Z]{3}\\)")]
  
  data <- str_split_fixed(country_rows, "\\s{2,}", 7)
  
  df <- as.data.frame(data, stringsAsFactors = FALSE)
  
  colnames(df) <- c(
    "country",
    "raw_agri",
    "food",
    "mining",
    "energy",
    "commodities",
    "main_commodities"
  )
  
  df <- df %>%
    mutate(
      iso3 = str_extract(country, "(?<=\\().+?(?=\\))"),
      country = str_remove(country, " \\(.*\\)")
    )
  
  df <- df %>%
    mutate(
      mining = as.numeric(str_extract(mining, "[0-9.]+")),
      energy = as.numeric(str_extract(energy, "[0-9.]+")),
      commodities = as.numeric(str_extract(commodities, "[0-9.]+")),
      income_group = income_group
    )
  
  df %>%
    select(country, iso3, income_group, mining, energy, commodities, main_commodities)
}

# Extraer tablas

tables <- mapply(
  extract_table,
  page_number = pages,
  income_group = income_labels,
  SIMPLIFY = FALSE
)

# Unir tablas

df_final <- bind_rows(tables)

# Recalcular commodities extractivos

df_final <- df_final %>%
  mutate(
    commodities = mining + energy
  )

# Definir la tercera variable
df_final <- df_final %>%
  mutate(
    other_exports = 100 - commodities
  )

# ordenar niveles del factor
df_final$income_group <- factor(
  df_final$income_group,
  levels = c("LIC", "LMIC", "UMIC", "HIC")
)

# Correcciones manuales del scraping

df_final <- df_final %>%
  mutate(
    main_commodities = case_when(
      country == "Malawi" ~ "Tobacco 66.7, Sugar 12, Tea 8.4",
      country == "Mauritania" ~ "Iron ore 43.8, Fish 20.7, Crude oil 10.5, Copper 5.9",
      country == "Burkina Faso" ~ "Cotton 81.8",
      country == "Mozambique" ~ "Aluminum 61.2, Tobacco 9.1, Shrimp 5.1",
      country == "Zimbabwe" ~ "Nickel 34.1, Tobacco 25.3, Cotton 10.5, Coal 7.9, Gold 5.4",
      country == "Burundi" ~ "Coffee 51.5, Gold 30.9, Tea 5.2",
      country == "Tanzania" ~ "Gold 22.7, Fish 12.5, Tobacco 8.3, Silver 7.2, Copper 6.7, Coffee 6.7, Cotton 6",
      country == "Niger" ~ "Uranium 42.9, Beef 18.3, Gasoline 14.7, Crude oil 7.6, Gold 5.5",
      country == "Sierra Leone" ~ "Diamonds 49.1, Coffee 21.5, Cocoa 6.8, Aluminum 6.1",
      country == "Papua New Guinea" ~ "Crude oil 22.8, Copper 20.7, Gold 20.4, Timber 9.6",
      country == "Bolivia" ~ "Natural gas 44.1, Crude oil 9.5, Tin 7.3",
      country == "Solomon Islands" ~ "Timber 72.6, Fish 15.2",
      country == "Guyana" ~ "Sugar 25.1, Gold 22, Aluminum 11.7, Rice 10.2, Diamonds 8.4, Timber 7.7, Shrimp 6.9",
      country == "Ghana" ~ "Cocoa 54, Tea 7.3, Gold 5.9",
      country == "Bhutan" ~ "Copper 47, Bananas 10.4, Coconut oil 9.1, Palm oil 8.1",
      country == "Swaziland" ~ "Sugar 21.5, Wood pulp 21.9",
      country == "Peru" ~ "Copper 27.2, Gold 22.6, Zinc 7.8, Gasoline 7.1, Tin 5.2",
      country == "Suriname" ~ "Aluminum 53.9, Gold 26.6, Gasoline 5",
      country == "Namibia" ~ "Diamonds 33.2, Fish 25.4, Zinc 15.2, Uranium 6.8, Copper 5.7, Beef 5.3",
      country == "Australia" ~ "Coal 19.9, Iron ore 11.7, Aluminum 11.1, Gold 8.3, Crude oil 6.9, Beef 5.9, Copper 5.4, Natural gas 5.1",
      country == "Iceland" ~ "Fish 60.2, Aluminum 27.4",
      country == "Chile" ~ "Copper 62.4, Fish 7, Bananas 6",
      TRUE ~ main_commodities
    )
  )

# Lista de commodities extractivos

extractive_pattern <- "oil|gas|aluminum|copper|gold|iron|uranium|zinc|diamond|nickel|silver|coal|phosphate|potash"

# Extraer solo extractivos

df_final <- df_final %>%
  mutate(
    main_commodities_extractive = str_extract_all(
      main_commodities,
      regex("[A-Za-z ]+ [0-9.]+")
    ),
    main_commodities_extractive = sapply(
      main_commodities_extractive,
      function(x) {
        x[str_detect(tolower(x), extractive_pattern)] |>
          paste(collapse = ", ")
      }
    )
  )

# Eliminar columna original

df_final <- df_final %>%
  select(-main_commodities)

# Renombrar columna limpia

df_final <- df_final %>%
  rename(main_commodities = main_commodities_extractive)

# Filtra por existencia de commodity extractivo identificado.

df_final <- df_final %>%
  filter(!is.na(main_commodities) & main_commodities != "")

# Variable que identifique si el país es petrolero, minero o mixto.

df_final <- df_final %>%
  mutate(resource_type = case_when(
    energy > mining * 1.5 ~ 1,   # petrolero
    mining > energy * 1.5 ~ 2,   # minero
    TRUE ~ 3                     # mixto
  ))

# Labels 

var_label(df_final$mining) <- "% of total exports: mining"
var_label(df_final$energy) <- "% of total exports: energy"
var_label(df_final$commodities) <- "% of total exports: extractive commodities (mining + energy)"
var_label(df_final$main_commodities) <- "Main extractive commodities in the CSCPI with corresponding weights computed over 2003–2007"
var_label(df_final$resource_type) <- "Type of extractive specialization (1 = energy exporter; 2 = mining exporter; 3 = mixed extractive economy)"
val_labels(df_final$resource_type) <- c(
  "Energy exporter" = 1,
  "Mining exporter" = 2,
  "Mixed extractive" = 3
)

# Corrección de valores erroneos en mining y energy

df_final <- df_final %>%
  mutate(
    mining = case_when(
      country == "Papua New Guinea" ~ 41.4,
      country == "Bolivia" ~ 17.3,
      TRUE ~ mining
    ),
    energy = case_when(
      country == "Papua New Guinea" ~ 23.7,
      country == "Bolivia" ~ 41.8,
      TRUE ~ energy
    ),
    commodities = mining + energy
  )

# Guardar dataset

output_path <- "C:/Users/julla/Downloads/1. Tesis de Maestría/data/processed/commodity_specialization.dta"

write_dta(df_final, output_path)

# Revisiones

View(df_final)
str(df_final)
summary(df_final)

df_final %>%
  filter(is.na(mining) | is.na(energy) | is.na(commodities))

####################################################################################################
# GRÁFICOS DESCRIPTIVOS / EXPLORATORIOS
####################################################################################################

# Path para guardar los gráficos

fig_path <- "C:/Users/julla/Downloads/1. Tesis de Maestría/outputs/figures/Figuras propias/"

# 1. Distribución de dependencia extractiva: Histograma de commodities

p_histogram <-ggplot(df_final, aes(x = commodities)) +
  
  geom_histogram(
    bins = 20,
    fill = "#4c72b0",
    color = "white",
    alpha = 0.9
  ) +
  
  geom_vline(
    aes(xintercept = mean(commodities, na.rm = TRUE),
        linetype = "Mean dependence"),
    color = "#d95f02",
    linewidth = 1
  ) +
  
  scale_linetype_manual(
    name = "",
    values = c("Mean dependence" = "dashed")
  ) +
  
  labs(
    x = "Share of exports from extractive commodities (%)",
    y = "Number of countries"
  ) +
  
  theme_classic() +
  
  theme(
    axis.text = element_text(size = 11),
    axis.title = element_text(size = 12),
    legend.position = "top"
  )

# Mostrar gráfico

p_histogram

# Guardar gráfico

ggsave(
  filename = "extractive_dependence_histogram.pdf",
  plot = p_histogram,
  path = fig_path,
  width = 6.5,
  height = 4.5
)

# 2. Minería vs energía

p_scatter_specialization <- ggplot(df_final, aes(x = mining, y = energy, color = factor(resource_type))) +
  
  geom_point(size = 3, alpha = 0.85) +
  
  geom_vline(xintercept = 20, linetype = "dashed", color = "gray50") +
  geom_hline(yintercept = 20, linetype = "dashed", color = "gray50") +
  
  annotate("text",
           x = 20, y = max(df_final$energy) + 2,
           label = "mining < 20%",
           hjust = -0.1,
           size = 4,
           color = "gray40") +
  
  annotate("text",
           x = max(df_final$mining) + 2, y = 20,
           label = "energy < 20%",
           vjust = -0.5,
           size = 4,
           color = "gray40") +
  
  scale_color_manual(
    name = "Type of extractive specialization",
    values = c("1" = "#d95f02", "2" = "#1b9e77", "3" = "#7570b3"),
    labels = c(
      "Energy exporters",
      "Mining exporters",
      "Mixed extractive economies"
    )
  ) +
  
  labs(
    x = "% of exports from mining",
    y = "% of exports from energy"
  ) +
  
  theme_classic() +
  
  guides(color = guide_legend(nrow = 2)) +
  
  theme(
    legend.position = "top",
    legend.direction = "horizontal",
    legend.title = element_text(size = 11),
    legend.text = element_text(size = 10)
  )

# Mostrar gráfico

p_scatter_specialization

# Guardar gráfico

ggsave(
  filename = "extractive_specialization_scatter.pdf",
  plot = p_scatter_specialization,
  path = fig_path,
  width = 6.5,
  height = 4.5
)

# 4. Dependencia por tipo de recurso

ggplot(df_final,
       aes(x = factor(resource_type),
           y = commodities,
           fill = factor(resource_type))) +
  
  geom_boxplot(alpha = 0.85, width = 0.6) +
  
  geom_jitter(
    width = 0.15,
    alpha = 0.7,
    color = "gray40",
    size = 1.8
  ) +
  
  scale_fill_manual(
    name = "Type of extractive specialization",
    values = c("#d95f02", "#1b9e77", "#7570b3"),
    labels = c(
      "Energy exporters",
      "Mining exporters",
      "Mixed extractive economies"
    )
  ) +
  
  scale_x_discrete(
    labels = c(
      "Energy exporters",
      "Mining exporters",
      "Mixed economies"
    )
  ) +
  
  labs(
    x = "",
    y = "% of exports from extractive commodities"
  ) +
  
  theme_classic() +
  theme(
    legend.position = "none",
    axis.text.x = element_text(size = 11)
  )

# 5. Tipos de economías extractivas

ggplot(df_final,
       aes(x = factor(resource_type),
           fill = factor(resource_type))) +
  
  geom_bar(
    width = 0.6,
    alpha = 0.9,
    color = "black",
    linewidth = 0.4
  ) +
  
  scale_fill_manual(
    values = c("#d95f02", "#1b9e77", "#7570b3"),
    labels = c(
      "Energy exporters",
      "Mining exporters",
      "Mixed extractive economies"
    )
  ) +
  
  scale_x_discrete(
    labels = c(
      "Energy exporters",
      "Mining exporters",
      "Mixed economies"
    )
  ) +
  
  labs(
    x = "",
    y = "Number of countries"
  ) +
  
  theme_classic() +
  
  theme(
    legend.position = "none",
    axis.text.x = element_text(size = 11),
    plot.title = element_text(size = 13)
  )


# 6. Dependencia vs ingreso

p_commodities_income_boxplot <- ggplot(df_final, aes(x = income_group, y = commodities, fill = income_group)) +
  
  geom_boxplot(alpha = 0.9, width = 0.6, outlier.color = "black") +
  
  geom_jitter(width = 0.15, alpha = 0.5, color = "black") +
  
  scale_fill_brewer(palette = "Blues") +
  
  labs(
    x = "Income group (from low to high income)",
    y = "Share of exports from extractive commodities (%)"
  ) +
  
  theme_classic() +
  
  theme(
    plot.title = element_text(size = 14),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 11),
    legend.position = "none"
  )

# Mostrar gráfico

p_commodities_income_boxplot

# Guardar gráfico

ggsave(
  filename = "p_commodities_income_boxplot.pdf",
  plot = p_commodities_income_boxplot,
  path = fig_path,
  width = 6.5,
  height = 4.5
)

# 7. Dependencia energética vs ingreso

p_energy_income_boxplot <- ggplot(df_final, aes(x = income_group, y = energy, fill = income_group)) +
  
  geom_boxplot(alpha = 0.9, width = 0.6, outlier.color = "black") +
  
  geom_jitter(width = 0.15, alpha = 0.5, color = "gray40") +
  
  scale_fill_brewer(palette = "Oranges") +
  
  labs(
    x = "Income group (from low to high income)",
    y = "Share of exports from energy (%)"
  ) +
  
  theme_classic() +
  
  theme(
    plot.title = element_text(size = 14),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 11),
    legend.position = "none"
  )

# Mostrar gráfico

p_energy_income_boxplot

# Guardar gráfico

ggsave(
  filename = "p_energy_income_boxplot.pdf",
  plot = p_energy_income_boxplot,
  path = fig_path,
  width = 6.5,
  height = 4.5
)

# 8. Dependencia minera vs ingreso

p_mining_income_boxplot <- ggplot(df_final, aes(x = income_group, y = mining, fill = income_group)) +
  
  geom_boxplot(alpha = 0.9, width = 0.6, outlier.color = "black") +
  
  geom_jitter(width = 0.15, alpha = 0.5, color = "gray40") +
  
  scale_fill_brewer(palette = "Greens") +
  
  labs(
    x = "Income group (from low to high income)",
    y = "Share of exports from mining (%)"
  ) +
  
  theme_classic() +
  
  theme(
    plot.title = element_text(size = 14),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 11),
    legend.position = "none"
  )

# Mostrar gráfico

p_mining_income_boxplot

# Guardar gráfico

ggsave(
  filename = "p_mining_income_boxplot.pdf",
  plot = p_mining_income_boxplot,
  path = fig_path,
  width = 6.5,
  height = 4.5
)

####################################################################################################
# GRÁFICOS POR ARREGLAR
####################################################################################################

# 3. Triángulo de especialización (mining–energy–rest of exports).

ggtern(data = df_final,
       aes(T = other_exports,
           L = mining,
           R = energy,
           color = factor(resource_type))) +
  
  ggtern::geom_point(size = 3, alpha = 0.9) +
  
  scale_color_manual(
    name = "Type of extractive specialization",
    values = c("1" = "#d95f02", "2" = "#1b9e77", "3" = "#7570b3"),
    labels = c(
      "1" = "Energy exporters",
      "2" = "Mining exporters",
      "3" = "Mixed extractive economies"
    )
  ) +
  
  labs(
    T = "Other exports (%)",
    L = "Mining exports (%)",
    R = "Energy exports (%)"
  ) +
  
  theme_bw()
