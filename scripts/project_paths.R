# Helper para rutas del proyecto:
# Busca la raiz de master-thesis-project-applied-econ desde el archivo activo
# de RStudio o desde getwd(). Sirve para que los scripts lean y guarden en
# data/raw, data/processed y outputs aunque la consola este parada en otra ruta.
# Entrada: nombre esperado de la carpeta principal del proyecto.
# Salida: ruta absoluta de la raiz del repositorio.
find_project_path <- function(project_dir = "master-thesis-project-applied-econ") {
  # Crear un vector vacio para reunir los puntos desde donde comenzara la busqueda.
  start_paths <- character()

  # Comprobar si el script se esta ejecutando dentro de una sesion de RStudio.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    # Intentar obtener la ruta del archivo activo; devolver texto vacio si falla.
    active_path <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(e) "")
    # Agregar la carpeta del archivo activo cuando RStudio devuelve una ruta valida.
    if (nzchar(active_path)) start_paths <- c(start_paths, dirname(active_path))
  }

  # Agregar como alternativa el directorio de trabajo actual de la consola de R.
  start_paths <- c(start_paths, getwd())

  # Definir una funcion interna que sube por las carpetas hasta encontrar el repo.
  find_root <- function(start) {
    # Normalizar la ruta inicial y usar barras compatibles con Windows y R.
    current <- normalizePath(start, winslash = "/", mustWork = FALSE)
    # Repetir la busqueda hasta encontrar el proyecto o llegar a la raiz del disco.
    repeat {
      # Verificar el nombre del repo y la existencia de sus carpetas data y scripts.
      if (
        basename(current) == project_dir &&
          dir.exists(file.path(current, "data")) &&
          dir.exists(file.path(current, "scripts"))
      ) {
        # Devolver inmediatamente la ruta cuando se cumplen las tres condiciones.
        return(current)
      }

      # Obtener la carpeta que contiene la ubicacion evaluada actualmente.
      parent <- dirname(current)
      # Detener el recorrido cuando la carpeta padre es igual a la carpeta actual.
      if (identical(parent, current)) break
      # Subir un nivel y continuar la busqueda desde esa carpeta padre.
      current <- parent
    }

    # Devolver un faltante cuando no se encontro el repositorio desde este inicio.
    NA_character_
  }

  # Ejecutar la busqueda desde cada ruta candidata y descartar resultados faltantes.
  roots <- na.omit(vapply(start_paths, find_root, character(1)))
  # Evaluar si al menos una de las rutas candidatas permitio encontrar el proyecto.
  if (length(roots) > 0) {
    # Devolver la primera raiz valida encontrada.
    roots[[1]]
  } else {
    # Detener el script con un mensaje claro si ninguna ruta condujo al proyecto.
    stop(paste0("No se pudo encontrar la raiz del proyecto ", project_dir, "."))
  }
}

# Definir una funcion auxiliar para localizar y ejecutar este mismo helper.
# Salida: carga find_project_path() en la sesion de R que llamo la funcion.
source_project_paths <- function() {
  # Inicializar como vacia la ruta del archivo abierto en RStudio.
  active_path <- ""
  # Comprobar si la API de RStudio esta instalada y disponible.
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    # Intentar leer la ruta del archivo activo sin interrumpir el script si falla.
    active_path <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(e) "")
  }

  # Reunir ubicaciones posibles de project_paths.R segun el directorio de ejecucion.
  candidates <- c(
    # Buscar desde el archivo activo cuando RStudio proporciona una ruta valida.
    if (nzchar(active_path)) file.path(dirname(dirname(dirname(active_path))), "project_paths.R"),
    # Buscar desde la raiz del repositorio.
    file.path("scripts", "project_paths.R"),
    # Buscar desde una subcarpeta ubicada dos niveles debajo de scripts/.
    file.path("..", "..", "project_paths.R"),
    # Buscar desde una subcarpeta ubicada un nivel debajo de scripts/.
    file.path("..", "project_paths.R"),
    # Buscar en el directorio de trabajo actual.
    "project_paths.R"
  )

  # Conservar la primera ubicacion candidata que exista en el equipo.
  helper_path <- candidates[file.exists(candidates)][1]
  # Detener la ejecucion si ninguna de las ubicaciones contiene el helper.
  if (is.na(helper_path)) {
    stop("No se pudo encontrar scripts/project_paths.R.")
  }

  # Ejecutar el archivo encontrado para cargar sus funciones en la sesion actual.
  source(helper_path)
}
