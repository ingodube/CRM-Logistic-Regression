args <- commandArgs(trailingOnly = TRUE)
project_dir <- normalizePath(if (length(args) > 0) args[[1]] else getwd(), winslash = "/", mustWork = TRUE)
setwd(project_dir)

if (!requireNamespace("rmarkdown", quietly = TRUE)) {
  stop("Pacote rmarkdown ausente; execute renv::restore().")
}

if (!rmarkdown::pandoc_available()) {
  candidates <- c(
    Sys.getenv("RSTUDIO_PANDOC", unset = ""),
    "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools",
    "C:/Program Files/RStudio/bin/pandoc"
  )
  candidates <- candidates[nzchar(candidates) & file.exists(file.path(candidates, "pandoc.exe"))]
  if (length(candidates) == 0) {
    stop("Pandoc não localizado. Instale o Pandoc ou o RStudio, ou defina RSTUDIO_PANDOC.")
  }
  Sys.setenv(RSTUDIO_PANDOC = candidates[[1]])
}

dir.create(file.path(project_dir, "docs"), recursive = TRUE, showWarnings = FALSE)

rmarkdown::render(
  input = file.path(project_dir, "relatorio", "relatorio_metodologico.Rmd"),
  output_file = "index.html",
  output_dir = file.path(project_dir, "docs"),
  envir = new.env(parent = globalenv()),
  clean = TRUE,
  quiet = FALSE
)

message("Relatório renderizado em ", file.path(project_dir, "docs", "index.html"))
