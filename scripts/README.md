# Scripts

Los scripts se organizan primero por etapa de investigación. Dentro de la etapa
de datos, el segundo nivel identifica explícitamente si un script pertenece a
la capa raw o processed.

```text
scripts/
  data/
    raw/                      # Descargas, importaciones e insumos sin transformar
      atlas/
      pwt/
      world_bank_wdi/
      dres/
      eci/
      rents/
      inst/
      oilpc_gaspc_coalpc/
      vol/
      rer/
      humcap/
      innov/
      net/
      gdppc/
      govcons/
      fin/
    processed/                # Construcción de variables del modelo
      dres/
      eci/
      hhi_divx/
  panel/                      # Integración del panel maestro país-año
  analysis/                   # Figuras descriptivas y análisis exploratorio
    eci/
  literature/                 # Reproducción y extracción de estudios previos
    anne2021/
  econometrics/               # Estimaciones y diagnósticos de la tesis
  project_paths.R             # Helper compartido de rutas para R
```

## Flujo de trabajo

1. `data/raw/` descarga, importa y preserva los insumos originales o casi
   originales sin construir variables econométricas.
2. `data/processed/` aplica las fórmulas aprobadas y escribe las variables
   definitivas. Cada panel procesado se guarda con contenido y estructura
   equivalentes en CSV (`.csv`) y Stata (`.dta`).
3. `panel/` combina las variables procesadas en
   `data/processed/00_master_panel/`.
4. `analysis/` contiene figuras descriptivas y análisis exploratorio; no prepara
   insumos raw ni variables del modelo.
5. `literature/` reproduce o extrae evidencia de estudios previos.
6. `econometrics/` contendrá el modelo principal con ECI y el modelo
   complementario con DIVX.

No deben existir constructores de variables directamente dentro de
`scripts/data/`. La capa se identifica por la carpeta y por el sufijo `_raw` o
`_processed`.

## Secuencia actualmente implementada

1. `data/raw/atlas/atlas_sitc_trade_raw.R` descarga la fuente comercial SITC
   Rev. 2 compartida.
2. `data/processed/dres/dres_processed.R` construye DRES y la selección fija del
   20 %. `dres_processed_validation.R` verifica esa clasificación sin definir
   muestras econométricas adicionales.
3. `data/raw/eci/eci_atlas_api_raw.py` descarga una captura completa de ECI
   desde la API GraphQL oficial del Atlas. Luego,
   `data/processed/eci/eci_atlas_processed.R` y
   `data/processed/hhi_divx/hhi_divx_atlas_processed.R` construyen los paneles
   procesados de ECI, HHI y DIVX.
4. `data/raw/world_bank_wdi/wdi_thesis_inputs_raw.R` descarga los insumos WDI
   compartidos.
5. `data/raw/pwt/pwt11_raw.R` descarga la fuente compartida PWT 11.0.
6. Los demás scripts bajo `data/raw/` preparan insumos y diagnósticos sin
   aplicar las transformaciones reservadas para `data/processed/`.

Los scripts pueden ejecutarse sin depender de un directorio de trabajo fijo.
Los archivos R utilizan `project_paths.R`; los archivos Python localizan la raíz
del repositorio desde su propia ubicación.

## Convención de comentarios

Cada script debe ser legible para una persona que evalúe la tesis sin experiencia
previa en el lenguaje utilizado:

- comenzar con capa, variable o fuente, entradas y salidas;
- explicar filtros, transformaciones, uniones, fórmulas y decisiones
  metodológicas;
- documentar funciones, validaciones y motivos de interrupción;
- identificar los archivos creados o modificados;
- evitar comentarios que solamente repitan mecánicamente el código.
