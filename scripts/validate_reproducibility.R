args <- commandArgs(trailingOnly = TRUE)
project_dir <- normalizePath(
  if (length(args) > 0) args[[1]] else getwd(),
  winslash = "/", mustWork = TRUE
)

required_directories <- file.path(project_dir, c(
  "Spreadsheets (EN)", "Spreadsheets (PT-BR)", "report", "docs", "scripts", "tools"
))
missing_directories <- required_directories[!dir.exists(required_directories)]
if (length(missing_directories)) {
  stop("Required directories are missing: ", paste(missing_directories, collapse = ", "))
}

removed_paths <- file.path(project_dir, c(
  "Codes (EN)", "Codes (PT-BR)", "Results (EN)", "Results (PT-BR)",
  "Simulated Data", "SOURCE_DATA_CHECKSUM.md", "tools/localize_repository.py",
  "tools/localize_workbooks.mjs"
))
unexpected_paths <- removed_paths[file.exists(removed_paths) | dir.exists(removed_paths)]
if (length(unexpected_paths)) {
  stop("Removed repository paths were recreated: ", paste(unexpected_paths, collapse = ", "))
}

r_files <- c(
  list.files(file.path(project_dir, "scripts"), pattern = "\\.R$", recursive = TRUE, full.names = TRUE),
  file.path(project_dir, "renv", "activate.R")
)
r_files <- unique(r_files[file.exists(r_files)])
parse_errors <- vapply(r_files, function(path) {
  tryCatch({
    parse(file = path, encoding = "UTF-8")
    ""
  }, error = function(error) conditionMessage(error))
}, character(1))
if (any(nzchar(parse_errors))) {
  failed <- names(parse_errors)[nzchar(parse_errors)]
  stop("R syntax errors:\n", paste(failed, parse_errors[failed], sep = ": ", collapse = "\n"))
}

report_sources <- file.path(project_dir, "report", c(
  "technical_report_en.Rmd", "technical_report_pt_br.Rmd",
  "technical-report.html", "technical-report.css"
))
missing_sources <- report_sources[!file.exists(report_sources)]
if (length(missing_sources)) {
  stop("Report sources are missing: ", paste(missing_sources, collapse = ", "))
}

spreadsheet_files <- lapply(c("EN", "PT-BR"), function(locale) {
  list.files(
    file.path(project_dir, paste0("Spreadsheets (", locale, ")")),
    pattern = "\\.(csv|xlsx)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE
  )
})
if (!length(spreadsheet_files[[1]]) || !length(spreadsheet_files[[2]])) {
  stop("Both localized spreadsheet trees must contain CSV or XLSX artifacts.")
}

required_packages <- c("dplyr", "ggplot2", "knitr", "patchwork", "rmarkdown", "stringi")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Missing packages; run renv::restore(): ", paste(missing_packages, collapse = ", "))
}
if (!nzchar(Sys.which("node"))) stop("Node.js is required for deterministic CSV localization.")

message(
  "Repository validation passed: ", length(r_files), " R files parsed; ",
  length(spreadsheet_files[[1]]), " EN and ", length(spreadsheet_files[[2]]),
  " PT-BR spreadsheet artifacts; removed analytical trees remain absent; R ", getRversion(), "."
)
