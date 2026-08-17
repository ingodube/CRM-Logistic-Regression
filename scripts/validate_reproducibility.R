args <- commandArgs(trailingOnly = TRUE)
project_dir <- normalizePath(
  if (length(args) > 0) args[[1]] else getwd(),
  winslash = "/", mustWork = TRUE
)

required_directories <- file.path(project_dir, c(
  "Codes (EN)", "Codes (PT-BR)", "Spreadsheets (EN)",
  "Spreadsheets (PT-BR)", "Results (EN)", "Results (PT-BR)",
  "Simulated Data", "report", "docs", "scripts", "tools"
))
missing_directories <- required_directories[!dir.exists(required_directories)]
if (length(missing_directories)) {
  stop("Required directories are missing: ", paste(missing_directories, collapse = ", "))
}

code_roots <- file.path(project_dir, c("Codes (EN)", "Codes (PT-BR)"))
code_files <- unlist(lapply(
  code_roots, list.files, pattern = "\\.R$", recursive = TRUE, full.names = TRUE
))
support_files <- list.files(
  file.path(project_dir, "scripts"), pattern = "\\.R$",
  recursive = TRUE, full.names = TRUE
)
r_files <- unique(c(code_files, support_files, file.path(project_dir, "renv", "activate.R")))

parse_errors <- vapply(r_files, function(path) {
  tryCatch({ parse(file = path, encoding = "UTF-8"); "" },
           error = function(error) conditionMessage(error))
}, character(1))
if (any(nzchar(parse_errors))) {
  failed <- names(parse_errors)[nzchar(parse_errors)]
  stop("R syntax errors:\n", paste(failed, parse_errors[failed], sep = ": ", collapse = "\n"))
}

read_code <- function(path) paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
absolute_path_pattern <- "(?<![A-Za-z])[A-Za-z]:[/\\\\]|~[/\\\\]"
absolute_hits <- code_files[vapply(
  code_files, function(path) grepl(absolute_path_pattern, read_code(path), perl = TRUE), logical(1)
)]
if (length(absolute_hits)) stop("Absolute paths found in analytical code: ", paste(absolute_hits, collapse = ", "))

for (locale in c("EN", "PT-BR")) {
  locale_files <- code_files[grepl(paste0("Codes \\(", locale, "\\)"), code_files)]
  expected_output <- paste0("Results (", locale, ")")
  invalid <- locale_files[!vapply(locale_files, function(path) {
    code <- read_code(path)
    is_plot_helper <- grepl("plot_crm_thetas[.]R$|grafico_thetas_crm[.]R$", path)
    paths_ok <- if (is_plot_helper) {
      grepl(expected_output, code, fixed = TRUE) &&
        grepl(paste0("Spreadsheets (", locale, ")"), code, fixed = TRUE)
    } else {
      grepl("Simulated Data", code, fixed = TRUE) && grepl(expected_output, code, fixed = TRUE)
    }
    setwd_calls <- matches <- regmatches(code, gregexpr("setwd\\s*\\([^)]*\\)", code, perl = TRUE))[[1]]
    setwd_ok <- length(setwd_calls) == 0L || all(setwd_calls == "setwd(main.dir)")
    paths_ok && setwd_ok
  }, logical(1))]
  if (length(invalid)) {
    stop("Portable input/output paths are missing in ", locale, " code: ",
         paste(invalid, collapse = ", "))
  }
}

numeric_tokens <- function(text) {
  pattern <- "(?<![A-Za-z_])[-+]?(?:[0-9]+\\.[0-9]*|\\.[0-9]+|[0-9]+)(?:[eE][-+]?[0-9]+)?"
  regmatches(text, gregexpr(pattern, text, perl = TRUE))[[1]]
}
en_files <- sort(code_files[grepl("Codes \\(EN\\)", code_files)])
pt_files <- sort(code_files[grepl("Codes \\(PT-BR\\)", code_files)])
if (length(en_files) != length(pt_files)) stop("The EN/PT-BR R file counts differ.")
en_numeric <- unlist(lapply(en_files, function(path) numeric_tokens(read_code(path))), use.names = FALSE)
pt_numeric <- unlist(lapply(pt_files, function(path) numeric_tokens(read_code(path))), use.names = FALSE)
if (!identical(sort(en_numeric), sort(pt_numeric))) {
  stop("Numeric tokens differ between the EN and PT-BR analytical trees.")
}

source_files <- list.files(file.path(project_dir, "Simulated Data"), recursive = TRUE, full.names = TRUE)
if (length(source_files) != 19000L) stop("Expected 19,000 simulated source-data files; found ", length(source_files), ".")

aggregate_git_blob_md5 <- function(project_dir) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("The digest package is required for cross-platform checksum validation.")
  }
  entries <- system2(
    "git",
    c("-C", shQuote(project_dir), "ls-files", "--stage", "--", shQuote("Simulated Data")),
    stdout = TRUE
  )
  hashes <- sub("^[0-9]+ ([0-9a-f]+) [0-9]+.*$", "\\1", entries)
  if (length(hashes) != 19000L || any(hashes == entries)) {
    stop("Could not read the 19,000 simulated source-data objects from the Git index.")
  }
  digest::digest(paste(sort(hashes), collapse = "\n"), algo = "md5", serialize = FALSE)
}
expected_source_digest <- "26c5f43f34cb45e13481fc8d90d339d8"
source_digest <- aggregate_git_blob_md5(project_dir)
if (!identical(source_digest, expected_source_digest)) {
  stop("Simulated source-data checksum changed: expected ", expected_source_digest,
       "; found ", source_digest, ".")
}

result_txt <- lapply(c("EN", "PT-BR"), function(locale) {
  list.files(file.path(project_dir, paste0("Results (", locale, ")")),
             pattern = "\\.txt$", recursive = TRUE, full.names = TRUE)
})
if (length(result_txt[[1]]) != length(result_txt[[2]]) ||
    !identical(sort(unname(tools::md5sum(result_txt[[1]]))),
               sort(unname(tools::md5sum(result_txt[[2]]))))) {
  stop("Numeric TXT results differ between the EN and PT-BR trees.")
}

required_packages <- c(
  "bayesplot", "coda", "digest", "doParallel", "dplyr", "EstCRM", "foreach",
  "ggplot2", "loo", "Metrics", "mcmcplots", "openxlsx", "patchwork",
  "psych", "purrr", "R2jags", "rjags", "simcausal", "tidyr", "truncnorm"
)
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop("Missing packages; run renv::restore(): ", paste(missing_packages, collapse = ", "))
}
jags_version <- tryCatch(as.character(rjags::jags.version()), error = function(error) NA_character_)
if (is.na(jags_version)) stop("JAGS was not found by rjags.")

message(
  "Reproducibility validation passed: ", length(r_files), " R files; ",
  length(source_files), " source-data files (aggregate MD5 ", source_digest,
  "); ", length(result_txt[[1]]), " paired TXT results; R ", getRversion(),
  "; JAGS ", jags_version, "."
)
