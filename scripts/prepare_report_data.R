args <- commandArgs(trailingOnly = TRUE)
project_dir <- normalizePath(
  if (length(args) > 0) args[[1]] else getwd(),
  winslash = "/", mustWork = TRUE
)

node <- Sys.which("node")
if (!nzchar(node)) stop("Node.js is required to localize the lightweight CSV artifacts.")
status <- system2(
  node,
  c(shQuote(file.path(project_dir, "tools", "localize_csvs.mjs")), shQuote(project_dir))
)
if (!identical(status, 0L)) stop("CSV localization failed.")

csv_pairs <- list(
  c("beta_1_estimativas.csv", "beta_1_estimates.csv"),
  c("checks.csv", "validation_checks.csv"),
  c("metricas_theta.csv", "theta_metrics.csv"),
  c("qualidade.csv", "quality.csv"),
  c("resumo_tri.csv", "irt_summary.csv"),
  c("tabela_parametros.csv", "item_parameter_table.csv"),
  c("theta_medias.csv", "theta_means.csv"),
  c("thetas.csv", "thetas.csv")
)
numeric_tokens <- function(path) {
  text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  pattern <- "(?<![A-Za-z_])[-+]?(?:[0-9]+\\.[0-9]*|\\.[0-9]+|[0-9]+)(?:[eE][-+]?[0-9]+)?"
  regmatches(text, gregexpr(pattern, text, perl = TRUE))[[1]]
}
for (pair in csv_pairs) {
  source <- file.path(project_dir, "Spreadsheets (PT-BR)", pair[[1]])
  target <- file.path(project_dir, "Spreadsheets (EN)", pair[[2]])
  if (!file.exists(source) || !file.exists(target)) stop("Missing CSV pair: ", paste(pair, collapse = " / "))
  if (!identical(numeric_tokens(source), numeric_tokens(target))) {
    stop("Numeric CSV parity failed: ", paste(pair, collapse = " / "))
  }
}

workbooks <- c(
  "classic_joint_crm_comparison.xlsx", "crm_item_parameter_comparison.xlsx",
  "estimated_theta_statistics.xlsx"
)
missing_workbooks <- workbooks[!file.exists(file.path(project_dir, "Spreadsheets (EN)", workbooks))]
if (length(missing_workbooks)) stop("Localized workbooks are missing: ", paste(missing_workbooks, collapse = ", "))

message("Lightweight bilingual report data prepared and validated without running simulations or MCMC estimation.")
