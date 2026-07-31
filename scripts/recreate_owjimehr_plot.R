# Script to generate ECI score evolution for top resource-rich countries
library(ggplot2)
library(dplyr)
library(ggrepel)

# Load master panel data
panel <- read.csv("data/processed/00_master_panel/master_panel_country_year.csv")

# Selected countries (matching Owjimehr (2024) as closely as possible from our panel)
sel_countries <- c("NOR", "ARE", "SAU", "VEN", "IRN", "QAT", "OMN", "KWT", "GAB", "LBY", "AGO", "COG")

df_plot <- panel %>%
  filter(country_iso3_code %in% sel_countries) %>%
  select(country_iso3_code, country, year, eci) %>%
  arrange(country_iso3_code, year)

# Color palette of 12 distinct but harmonious colors
colors <- c(
  "NOR" = "#1f77b4", # Blue
  "ARE" = "#ff7f0e", # Orange
  "SAU" = "#2ca02c", # Green
  "VEN" = "#d62728", # Red
  "IRN" = "#9467bd", # Purple
  "QAT" = "#8c564b", # Brown
  "OMN" = "#e377c2", # Pink
  "KWT" = "#7f7f7f", # Grey
  "GAB" = "#bcbd22", # Olive
  "ARE" = "#17becf", # Cyan
  "LBY" = "#aec7e8", # Light blue
  "AGO" = "#ffbb78", # Light orange
  "COG" = "#98df8a"  # Light green
)

# Label positions at the last year (2021) to place labels directly on the plot
label_data <- df_plot %>%
  filter(year == 2021)

p <- ggplot(df_plot, aes(x = year, y = eci, group = country_iso3_code)) +
  geom_line(aes(color = country_iso3_code), linewidth = 0.8, alpha = 0.85) +
  geom_point(aes(color = country_iso3_code), size = 1.5, alpha = 0.85) +
  # Add country labels at the end of each line
  geom_text_repel(
    data = label_data,
    aes(label = country_iso3_code, color = country_iso3_code),
    nudge_x = 0.8,
    direction = "y",
    hjust = 0,
    size = 3.0,
    segment.color = "grey75",
    segment.size = 0.3,
    box.padding = 0.1,
    point.padding = 0.2,
    xlim = c(2021, 2024.5)             # Expand right limit to fit labels
  ) +
  scale_x_continuous(
    name = "Año",
    breaks = seq(1996, 2021, 4),
    limits = c(1996, 2025)             # Extra space on the right for labels
  ) +
  scale_y_continuous(
    name = "Índice de Complejidad Económica (ECI)"
  ) +
  scale_color_manual(
    values = colors,
    guide = "none"                     # Suppress standard legend since we have direct labels
  ) +
  theme_classic(base_family = "sans") +
  theme(
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black", linewidth = 0.5),
    axis.text = element_text(color = "black", size = 10),
    axis.title = element_text(color = "black", size = 10, face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(t = 15, r = 25, b = 15, l = 15)
  )

output_orig <- "outputs/figures/original/chapter10_recreated_owjimehr.pdf"
output_thesis <- "docs/thesis/figures/chapter10_recreated_owjimehr.pdf"

ggsave(output_orig, plot = p, width = 7.5, height = 5.2, device = cairo_pdf)
ggsave(output_thesis, plot = p, width = 7.5, height = 5.2, device = cairo_pdf)

cat("Plot successfully saved to:", output_orig, "and", output_thesis, "\n")
