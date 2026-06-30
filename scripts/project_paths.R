# Helper para rutas del proyecto:
# Busca la raiz de master-thesis-project-applied-econ desde el archivo activo
# de RStudio o desde getwd(). Sirve para que los scripts lean y guarden en
# data/raw, data/processed y outputs aunque la consola este parada en otra ruta.
find_project_path <- function(project_dir = "master-thesis-project-applied-econ") {
  start_paths <- character()

  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    active_path <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(e) "")
    if (nzchar(active_path)) start_paths <- c(start_paths, dirname(active_path))
  }

  start_paths <- c(start_paths, getwd())

  find_root <- function(start) {
    current <- normalizePath(start, winslash = "/", mustWork = FALSE)
    repeat {
      if (
        basename(current) == project_dir &&
          dir.exists(file.path(current, "data")) &&
          dir.exists(file.path(current, "scripts"))
      ) {
        return(current)
      }

      parent <- dirname(current)
      if (identical(parent, current)) break
      current <- parent
    }

    NA_character_
  }

  roots <- na.omit(vapply(start_paths, find_root, character(1)))
  if (length(roots) > 0) {
    roots[[1]]
  } else {
    stop(paste0("No se pudo encontrar la raiz del proyecto ", project_dir, "."))
  }
}

source_project_paths <- function() {
  active_path <- ""
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    active_path <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(e) "")
  }

  candidates <- c(
    if (nzchar(active_path)) file.path(dirname(dirname(active_path)), "project_paths.R"),
    file.path("scripts", "project_paths.R"),
    file.path("..", "project_paths.R"),
    "project_paths.R"
  )

  helper_path <- candidates[file.exists(candidates)][1]
  if (is.na(helper_path)) {
    stop("No se pudo encontrar scripts/project_paths.R.")
  }

  source(helper_path)
}
