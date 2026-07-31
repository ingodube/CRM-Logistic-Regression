args <- commandArgs(trailingOnly = TRUE)
project_dir <- normalizePath(if (length(args) > 0) args[[1]] else getwd(), winslash = "/", mustWork = TRUE)

required_directories <- file.path(project_dir, c("Dados Simulados", "Resultados"))
missing_directories <- required_directories[!dir.exists(required_directories)]

if (length(missing_directories) > 0) {
  stop("Diretórios obrigatórios ausentes: ", paste(missing_directories, collapse = ", "))
}

result_r_files <- list.files(file.path(project_dir, "Resultados"), pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
r_files <- c(
  result_r_files,
  list.files(file.path(project_dir, "scripts"), pattern = "\\.R$", recursive = TRUE, full.names = TRUE),
  file.path(project_dir, "renv", "activate.R")
)
r_files <- unique(r_files[file.exists(r_files)])

if (length(r_files) == 0) {
  stop("Nenhum arquivo R encontrado em Resultados.")
}

parse_errors <- vapply(r_files, function(path) {
  tryCatch({
    parse(file = path, encoding = "UTF-8")
    ""
  }, error = function(error) conditionMessage(error))
}, character(1))

if (any(nzchar(parse_errors))) {
  details <- paste(names(parse_errors)[nzchar(parse_errors)], parse_errors[nzchar(parse_errors)], sep = ": ")
  stop("Erros de sintaxe R:\n", paste(details, collapse = "\n"))
}

absolute_path_pattern <- "(?<![A-Za-z])[A-Za-z]:[/\\\\]|~[/\\\\]"
absolute_path_hits <- unlist(lapply(result_r_files, function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  matches <- grep(absolute_path_pattern, lines, perl = TRUE)
  if (length(matches) == 0) return(character())
  paste0(path, ":", matches)
}), use.names = FALSE)

if (length(absolute_path_hits) > 0) {
  stop("Caminhos absolutos encontrados:\n", paste(absolute_path_hits, collapse = "\n"))
}

scenario_indices <- c(`100` = 1, `250` = 2, `500` = 3, `1000` = 4)
method_labels <- c(Classic = "TRI Classic Reg. Log.", Joint = "TRI Joint Reg. Log.")

for (method in names(method_labels)) {
  for (n in names(scenario_indices)) {
    path <- file.path(
      project_dir, "Resultados", "TRI", "Regressão Estrutural",
      "Regressão Logística", "CRM - Normal (Wang e Zeng)", method,
      paste0("n = ", n, " p = 10"),
      paste0(method_labels[[method]], " n = ", n, " p = 10.R")
    )
    code <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    theta_refs <- regmatches(code, gregexpr("thetas_reais\\[\\[[1-4]\\]\\]", code))[[1]]
    expected_ref <- paste0("thetas_reais[[", scenario_indices[[n]], "]]" )
    if (length(theta_refs) == 0 || any(theta_refs != expected_ref)) {
      stop("Seletor de theta inconsistente em: ", path)
    }
    item_refs <- regmatches(code, gregexpr("param_itens_reais\\[\\[[1-9]\\]\\]", code))[[1]]
    if (length(item_refs) == 0 || any(item_refs != "param_itens_reais[[1]]")) {
      stop("Seletor dos parâmetros dos itens inconsistente em: ", path)
    }
    if (method == "Joint" && !grepl("Diagnóstico das cadeias da última replicação processada", code, fixed = TRUE)) {
      stop("Escopo do diagnóstico MCMC não documentado em: ", path)
    }
  }
}

if (any(vapply(result_r_files, function(path) {
  any(grepl("medan\\(", readLines(path, warn = FALSE, encoding = "UTF-8")))
}, logical(1)))) {
  stop("Foi encontrada uma chamada inválida a medan().")
}

required_packages <- c(
  "bayesplot", "coda", "doParallel", "dplyr", "EstCRM", "foreach",
  "ggplot2", "loo", "Metrics", "mcmcplots", "openxlsx", "patchwork",
  "psych", "purrr", "R2jags", "rjags", "simcausal", "tidyr", "truncnorm"
)
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0) {
  stop("Pacotes ausentes; execute renv::restore(): ", paste(missing_packages, collapse = ", "))
}

jags_version <- tryCatch(as.character(rjags::jags.version()), error = function(error) NA_character_)

if (is.na(jags_version)) {
  stop("JAGS não foi localizado pelo pacote rjags.")
}

scenarios <- c(100, 250, 500, 1000)
expected_directories <- c(
  file.path(project_dir, "Dados Simulados", "Regressão", "Regressão Logística", paste0("n = ", scenarios)),
  file.path(project_dir, "Dados Simulados", "TRI", "Modelo de Mensuração", "CRM - Normal (Wang e Zeng)", "Geral", paste0("n = ", scenarios, " p = 10")),
  file.path(project_dir, "Resultados", "TRI", "Regressão Estrutural", "Regressão Logística", "CRM - Normal (Wang e Zeng)", "Classic", paste0("n = ", scenarios, " p = 10")),
  file.path(project_dir, "Resultados", "TRI", "Regressão Estrutural", "Regressão Logística", "CRM - Normal (Wang e Zeng)", "Joint", paste0("n = ", scenarios, " p = 10"))
)
missing_expected_directories <- expected_directories[!dir.exists(expected_directories)]

if (length(missing_expected_directories) > 0) {
  stop("Diretórios de cenário ausentes:\n", paste(missing_expected_directories, collapse = "\n"))
}

message("Validação concluída: ", length(r_files), " scripts R; R ", getRversion(), "; JAGS ", jags_version, ".")
