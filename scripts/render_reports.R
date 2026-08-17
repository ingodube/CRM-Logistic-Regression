args <- commandArgs(trailingOnly = TRUE)
project_dir <- normalizePath(
  if (length(args) > 0) args[[1]] else getwd(),
  winslash = "/", mustWork = TRUE
)

if (!requireNamespace("rmarkdown", quietly = TRUE)) {
  stop("The rmarkdown package is missing; run renv::restore().")
}

if (!rmarkdown::pandoc_available()) {
  candidates <- c(
    Sys.getenv("RSTUDIO_PANDOC", unset = ""),
    "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools",
    "C:/Program Files/RStudio/bin/pandoc"
  )
  candidates <- candidates[
    nzchar(candidates) & file.exists(file.path(candidates, "pandoc.exe"))
  ]
  if (length(candidates) == 0) {
    stop("Pandoc was not found. Install Pandoc or RStudio, or set RSTUDIO_PANDOC.")
  }
  Sys.setenv(RSTUDIO_PANDOC = candidates[[1]])
}

docs_dir <- file.path(project_dir, "docs")
dir.create(docs_dir, recursive = TRUE, showWarnings = FALSE)

reports <- list(
  list(
    source = "technical_report_en.Rmd",
    output = "metodologia.html",
    canonical = "https://ingodube.github.io/CRM-Logistic-Regression/metodologia.html"
  ),
  list(
    source = "technical_report_pt_br.Rmd",
    output = "methodology-pt-br.html",
    canonical = "https://ingodube.github.io/CRM-Logistic-Regression/methodology-pt-br.html"
  )
)

for (report in reports) {
  rmarkdown::render(
    input = file.path(project_dir, "report", report$source),
    output_file = report$output,
    output_dir = docs_dir,
    envir = new.env(parent = globalenv()),
    clean = TRUE,
    quiet = FALSE
  )
}

for (report in reports) {
  output_path <- file.path(docs_dir, report$output)
  html <- readLines(output_path, warn = FALSE, encoding = "UTF-8")
  metadata <- c(
    sprintf('<link rel="canonical" href="%s">', report$canonical),
    '<link rel="alternate" hreflang="en" href="https://ingodube.github.io/CRM-Logistic-Regression/metodologia.html">',
    '<link rel="alternate" hreflang="pt-BR" href="https://ingodube.github.io/CRM-Logistic-Regression/methodology-pt-br.html">',
    '<link rel="alternate" hreflang="x-default" href="https://ingodube.github.io/CRM-Logistic-Regression/metodologia.html">'
  )
  viewport_line <- grep('<meta name="viewport"', html, fixed = TRUE)
  if (length(viewport_line) != 1L) stop("Could not locate the viewport metadata in ", report$output)
  html <- append(html, metadata, after = viewport_line)
  html <- sub("[[:blank:]]+$", "", html)
  writeLines(html, output_path, useBytes = TRUE)
}

index <- c(
  "<!doctype html>",
  '<html lang="en">',
  "<head>",
  '<meta charset="utf-8">',
  '<meta name="viewport" content="width=device-width, initial-scale=1">',
  '<meta http-equiv="refresh" content="0; url=metodologia.html">',
  '<link rel="canonical" href="https://ingodube.github.io/CRM-Logistic-Regression/metodologia.html">',
  '<title>CRM Logistic Regression — Technical Report</title>',
  "</head>",
  "<body>",
  '<p>The technical report is available in <a href="metodologia.html">English</a> and <a href="methodology-pt-br.html" lang="pt-BR">Portuguese (PT-BR)</a>.</p>',
  '<script>window.location.replace("metodologia.html");</script>',
  "</body>",
  "</html>"
)
writeLines(index, file.path(docs_dir, "index.html"), useBytes = TRUE)

message("Bilingual reports rendered in ", docs_dir)
