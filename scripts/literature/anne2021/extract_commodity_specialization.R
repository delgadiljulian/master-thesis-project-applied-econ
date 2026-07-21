# Proposito: reproducir las tablas de especializacion exportadora publicadas por
# Anne (2021) y generar una base descriptiva de economias extractivas.
# Entrada: docs/literature/resource-dependent-economies/40.pdf.
# Salidas: data/processed/literature/anne2021/commodity_specialization.dta y
# graficos descriptivos en outputs/figures/original/.

# Cargar pdftools para convertir las paginas del articulo en texto.
library(pdftools)
# Cargar stringr para reconocer y separar patrones dentro del texto extraido.
library(stringr)
# Cargar dplyr para limpiar y transformar la tabla resultante.
library(dplyr)
# Cargar haven para guardar la base en formato Stata.
library(haven)
# Cargar labelled para documentar variables y categorias dentro del .dta.
library(labelled)
# Cargar ggplot2 para producir los graficos descriptivos.
library(ggplot2)
# Cargar ggtern para construir el grafico ternario de especializacion.
library(ggtern)

# Ajuste de ruta del proyecto:
# RStudio no siempre ejecuta el script desde la carpeta del repositorio.
# Este bloque ubica la raiz de master-thesis-project-applied-econ para que
# las rutas a docs/, data/ y outputs/ funcionen aunque el working directory
# este apuntando a otra carpeta.
project_path <- {
  # Crear un vector vacio con los puntos iniciales de busqueda.
  start_paths <- character()
  # Comprobar si el script esta abierto en RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    # Intentar obtener la ruta del archivo activo sin detenerse si falla.
    active_path <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(e) "")
    # Agregar la carpeta del archivo activo cuando la ruta no esta vacia.
    if (nzchar(active_path)) start_paths <- c(start_paths, dirname(active_path))
  }
  # Agregar tambien el directorio de trabajo actual como alternativa.
  start_paths <- c(start_paths, getwd())

  # Definir una funcion que sube por las carpetas hasta encontrar el repositorio.
  find_root <- function(start) {
    # Normalizar la ruta inicial para que la comparacion sea consistente.
    current <- normalizePath(start, winslash = "/", mustWork = FALSE)
    # Repetir la busqueda hasta hallar el repo o alcanzar la raiz del disco.
    repeat {
      # Verificar nombre del proyecto y presencia de las carpetas data y scripts.
      if (
        basename(current) == "master-thesis-project-applied-econ" &&
          dir.exists(file.path(current, "data")) &&
          dir.exists(file.path(current, "scripts"))
      ) {
        # Devolver la ruta apenas se identifique correctamente el repositorio.
        return(current)
      }
      # Obtener la carpeta padre de la ubicacion evaluada.
      parent <- dirname(current)
      # Detener el recorrido si ya se alcanzo la raiz del sistema de archivos.
      if (identical(parent, current)) break
      # Subir un nivel para continuar la busqueda.
      current <- parent
    }
    # Devolver un valor faltante si este punto inicial no condujo al repositorio.
    NA_character_
  }

  # Buscar la raiz desde cada punto inicial y eliminar resultados faltantes.
  roots <- na.omit(vapply(start_paths, find_root, character(1)))
  # Evaluar si la busqueda encontro al menos una ruta valida.
  if (length(roots) > 0) {
    # Usar la primera raiz valida encontrada.
    roots[[1]]
  } else {
    # Detener el script si no se puede ubicar el repositorio.
    stop("No se pudo encontrar la raiz del proyecto master-thesis-project-applied-econ.")
  }
}

####################################################################################################
# CONSTRUCCIÓN DEL PANEL
####################################################################################################

# Construir la ruta absoluta del articulo almacenado en la biblioteca del proyecto.
pdf_file <- file.path(
  project_path, "docs", "literature", "resource-dependent-economies", "40.pdf"
)

# Convertir todas las paginas del PDF en un vector de textos.
txt <- pdf_text(pdf_file)

# Confirmar mediante el titulo que se esta leyendo el articulo correcto.
if (!str_detect(paste(txt[seq_len(min(5, length(txt)))], collapse = " "), "Beyond the resource curse")) {
  stop("El PDF indicado no parece corresponder a Anne (2021): Beyond the resource curse.")
}

# Identificar las cuatro paginas que contienen las tablas por grupo de ingreso.
pages <- c(28, 29, 30, 31)

# Verificar que el PDF tenga suficientes paginas para realizar la extraccion.
if (length(txt) < max(pages)) {
  stop("El PDF indicado no tiene las paginas esperadas para extraer las tablas de Anne (2021).")
}

# Asociar cada pagina con la categoria de ingreso indicada por el articulo.
income_labels <- c("LIC", "LMIC", "UMIC", "HIC")

# Definir una funcion que transforma una pagina y su grupo de ingreso en una tabla.
# Entradas: numero de pagina y etiqueta de ingreso correspondiente.
# Salida: data frame con pais, ISO3 y participaciones exportadoras.
extract_table <- function(page_number, income_group) {

  # Seleccionar el texto de la pagina que se esta procesando.
  page_text <- txt[page_number]

  # Separar la pagina en lineas individuales.
  lines <- unlist(str_split(page_text, "\n"))
  # Eliminar las lineas completamente vacias.
  lines <- lines[lines != ""]

  # Conservar las lineas que contienen un codigo ISO3 entre parentesis.
  country_rows <- lines[str_detect(lines, "\\([A-Z]{3}\\)")]

  # Separar cada fila en siete columnas usando grupos de dos o mas espacios.
  data <- str_split_fixed(country_rows, "\\s{2,}", 7)

  # Convertir la matriz de textos en un data frame.
  df <- as.data.frame(data, stringsAsFactors = FALSE)

  # Asignar nombres descriptivos a las siete columnas extraidas.
  colnames(df) <- c(
    "country",
    "raw_agri",
    "food",
    "mining",
    "energy",
    "commodities",
    "main_commodities"
  )

  # Separar el codigo ISO3 del nombre completo del pais.
  df <- df %>%
    mutate(
      iso3 = str_extract(country, "(?<=\\().+?(?=\\))"), # Extraer texto entre parentesis.
      country = str_remove(country, " \\(.*\\)")        # Retirar el codigo del nombre.
    )

  # Convertir participaciones exportadoras de texto a valores numericos.
  df <- df %>%
    mutate(
      mining = as.numeric(str_extract(mining, "[0-9.]+")),       # Porcentaje minero.
      energy = as.numeric(str_extract(energy, "[0-9.]+")),       # Porcentaje energetico.
      commodities = as.numeric(str_extract(commodities, "[0-9.]+")), # Total reportado.
      income_group = income_group                                # Grupo de la pagina.
    )

  # Devolver solamente las variables necesarias para el analisis posterior.
  df %>%
    select(country, iso3, income_group, mining, energy, commodities, main_commodities)
}

# Ejecutar la funcion una vez por pagina y grupo de ingreso.
tables <- mapply(
  extract_table,                 # Funcion que procesa cada pagina.
  page_number = pages,           # Paginas 28 a 31.
  income_group = income_labels,  # Etiquetas LIC, LMIC, UMIC y HIC.
  SIMPLIFY = FALSE               # Conservar los resultados como una lista de tablas.
)

# Apilar las cuatro tablas en una unica base de paises.
df_final <- bind_rows(tables)

# Detener el script si un cambio en el PDF impidio extraer observaciones.
if (nrow(df_final) == 0) {
  stop("No se extrajeron filas desde el PDF. Revisar pdf_file, pages o el formato de las tablas.")
}

# Recalcular la participacion extractiva como mineria mas energia.
df_final <- df_final %>%
  mutate(
    commodities = mining + energy
  )

# Calcular la participacion de todas las demas exportaciones.
df_final <- df_final %>%
  mutate(
    other_exports = 100 - commodities
  )

# Fijar el orden economico de las categorias de ingreso, de menor a mayor.
df_final$income_group <- factor(
  df_final$income_group,
  levels = c("LIC", "LMIC", "UMIC", "HIC")
)

# Reemplazar filas cuyo texto quedo separado incorrectamente durante el scraping.
# Cada reemplazo reproduce manualmente el contenido visible en la tabla original.
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

# Definir palabras clave que identifican commodities mineros o energeticos.
extractive_pattern <- "oil|gas|aluminum|copper|gold|iron|uranium|zinc|diamond|nickel|silver|coal|phosphate|potash"

# Extraer de la lista de productos solamente aquellos que coinciden con el patron.
df_final <- df_final %>%
  mutate(
    # Separar cada combinacion de nombre de producto y participacion numerica.
    main_commodities_extractive = str_extract_all(
      main_commodities,
      regex("[A-Za-z ]+ [0-9.]+")
    ),
    # Filtrar dentro de cada lista los productos extractivos y volver a unirlos.
    main_commodities_extractive = sapply(
      main_commodities_extractive,
      function(x) {
        # Conservar coincidencias y separarlas con comas en una sola cadena.
        x[str_detect(tolower(x), extractive_pattern)] |>
          paste(collapse = ", ")
      }
    )
  )

# Eliminar la columna original que todavia incluye productos no extractivos.
df_final <- df_final %>%
  select(-main_commodities)

# Dar a la columna filtrada el nombre utilizado por los scripts posteriores.
df_final <- df_final %>%
  rename(main_commodities = main_commodities_extractive)

# Conservar paises para los cuales se identifico al menos un producto extractivo.
df_final <- df_final %>%
  filter(!is.na(main_commodities) & main_commodities != "")

# Detener el script si el filtro anterior elimina todas las observaciones.
if (nrow(df_final) == 0) {
  stop("El filtro de commodities extractivos dejo la base vacia. Revisar extractive_pattern o main_commodities.")
}

# Clasificar cada pais como energetico, minero o mixto segun la razon entre shares.
df_final <- df_final %>%
  mutate(resource_type = case_when(
    energy > mining * 1.5 ~ 1, # Energia supera en al menos 50 % a mineria.
    mining > energy * 1.5 ~ 2, # Mineria supera en al menos 50 % a energia.
    TRUE ~ 3                   # Ninguna domina suficientemente: economia mixta.
  ))

# Documentar el significado de la participacion minera dentro del archivo Stata.
var_label(df_final$mining) <- "% of total exports: mining"
# Documentar el significado de la participacion energetica.
var_label(df_final$energy) <- "% of total exports: energy"
# Documentar el total de exportaciones extractivas.
var_label(df_final$commodities) <- "% of total exports: extractive commodities (mining + energy)"
# Documentar la lista de productos y ponderaciones tomada del articulo.
var_label(df_final$main_commodities) <- "Main extractive commodities in the CSCPI with corresponding weights computed over 2003–2007"
# Documentar los codigos numericos de especializacion.
var_label(df_final$resource_type) <- "Type of extractive specialization (1 = energy exporter; 2 = mining exporter; 3 = mixed extractive economy)"
# Asociar cada codigo numerico con una etiqueta legible.
val_labels(df_final$resource_type) <- c(
  "Energy exporter" = 1,
  "Mining exporter" = 2,
  "Mixed extractive" = 3
)

# Corregir valores puntuales que el scraping leyo mal frente a la tabla original.
df_final <- df_final %>%
  mutate(
    # Corregir la participacion minera de Papua Nueva Guinea y Bolivia.
    mining = case_when(
      country == "Papua New Guinea" ~ 41.4,
      country == "Bolivia" ~ 17.3,
      TRUE ~ mining
    ),
    # Corregir la participacion energetica de esos mismos paises.
    energy = case_when(
      country == "Papua New Guinea" ~ 23.7,
      country == "Bolivia" ~ 41.8,
      TRUE ~ energy
    ),
    # Recalcular el total extractivo despues de las correcciones.
    commodities = mining + energy
  )

# Construir la ruta del dataset procesado derivado de Anne (2021).
output_path <- file.path(
  project_path,
  "data",
  "processed",
  "literature",
  "anne2021",
  "commodity_specialization.dta"
)
# Crear la carpeta de destino si todavia no existe.
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

# Guardar la tabla final en formato Stata.
write_dta(df_final, output_path)

# Abrir la base para una inspeccion visual opcional.
View(df_final)
# Mostrar tipos de variables y primeras propiedades del objeto.
str(df_final)
# Mostrar estadisticas descriptivas de todas las columnas.
summary(df_final)

df_final %>%
  filter(is.na(mining) | is.na(energy) | is.na(commodities))

####################################################################################################
# GRÁFICOS DESCRIPTIVOS / EXPLORATORIOS
####################################################################################################

# Path para guardar los gráficos

fig_path <- file.path(project_path, "outputs", "figures", "original")
dir.create(fig_path, recursive = TRUE, showWarnings = FALSE)

# 1. Distribución de dependencia extractiva: Histograma de commodities

df_histogram <- df_final %>%
  filter(!is.na(commodities))

if (nrow(df_histogram) == 0) {
  stop("No hay valores numericos validos de commodities para graficar el histograma.")
}

mean_commodities <- mean(df_histogram$commodities, na.rm = TRUE)

p_histogram <- ggplot(df_histogram, aes(x = commodities)) +

  geom_histogram(
    bins = 20,
    fill = "#4c72b0",
    color = "white",
    alpha = 0.9
  ) +

  geom_vline(
    aes(xintercept = mean_commodities, linetype = "Mean dependence"),
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

p_specialization_triangle <- ggtern(
  data = df_final,
  aes(
    x = other_exports,
    y = mining,
    z = energy,
    color = factor(resource_type)
  )
) +

  geom_point(size = 3, alpha = 0.9) +

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
    x = "Other exports (%)",
    y = "Mining exports (%)",
    z = "Energy exports (%)"
  ) +

  theme_bw()

p_specialization_triangle

ggsave(
  filename = "extractive_specialization_triangle.pdf",
  plot = p_specialization_triangle,
  path = fig_path,
  width = 6.5,
  height = 5.5
)
