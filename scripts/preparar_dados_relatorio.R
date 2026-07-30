args <- commandArgs(trailingOnly = TRUE)
project_dir <- normalizePath(if (length(args) > 0) args[[1]] else getwd(), winslash = "/", mustWork = TRUE)

results_root <- file.path(
  project_dir, "Resultados", "TRI", "Regressão Estrutural",
  "Regressão Logística", "CRM - Normal (Wang e Zeng)"
)
output_dir <- file.path(project_dir, "relatorio", "dados")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

scenarios <- c(100, 250, 500, 1000)
methods <- c("Classic", "Joint")
method_labels <- c(Classic = "Duas etapas", Joint = "Conjunto")

read_numeric_vector <- function(path) {
  values <- scan(path, what = numeric(), quiet = TRUE)
  if (length(values) != 1000 || any(!is.finite(values))) {
    stop("Resultado de beta_1 inválido: ", path)
  }
  values
}

read_numeric_matrix <- function(path, expected_rows) {
  values <- as.matrix(read.table(path, header = FALSE))
  if (!all(dim(values) == c(expected_rows, 1000)) || any(!is.finite(values))) {
    stop("Matriz de resultados inválida: ", path)
  }
  values
}

calculate_metrics <- function(estimates, true_values) {
  data.frame(
    vicio = mean(rowMeans(estimates) - true_values),
    rmse = mean(sqrt(rowMeans((estimates - true_values)^2)))
  )
}

beta_rows <- list()
theta_rows <- list()
theta_metric_rows <- list()
parameter_rows <- list()

set.seed(448291 + 10)
true_items <- data.frame(
  a = runif(n = 10, min = 0.30, max = 2.50),
  b = rnorm(n = 10, mean = 0, sd = 1),
  alpha = runif(n = 10, min = 0.30, max = 2.50)
)

for (n in scenarios) {
  set.seed(228371 + n)
  theta_true <- rnorm(n, mean = 0, sd = 1)

  for (method in methods) {
    scenario_dir <- file.path(results_root, method, paste0("n = ", n, " p = 10"))
    beta_file <- if (method == "Classic") "beta_1_estimados_EM.txt" else "beta_1_estimados_mean.txt"
    theta_file <- if (method == "Classic") "theta_estimados_EM.txt" else "thetas_estimados_mean.txt"

    beta_rows[[length(beta_rows) + 1]] <- data.frame(
      n = n,
      metodo = method_labels[[method]],
      replicacao = seq_len(1000),
      beta_1 = read_numeric_vector(file.path(scenario_dir, beta_file)),
      stringsAsFactors = FALSE
    )

    theta_matrix <- read_numeric_matrix(file.path(scenario_dir, theta_file), n)

    theta_rows[[length(theta_rows) + 1]] <- data.frame(
      n = n,
      metodo = method_labels[[method]],
      individuo = seq_len(n),
      theta_verdadeiro = theta_true,
      theta_estimado_medio = rowMeans(theta_matrix),
      stringsAsFactors = FALSE
    )

    theta_metrics <- calculate_metrics(theta_matrix, theta_true)
    theta_metric_rows[[length(theta_metric_rows) + 1]] <- data.frame(
      n = n,
      metodo = method_labels[[method]],
      vicio = theta_metrics$vicio,
      rmse = theta_metrics$rmse,
      media = mean(theta_matrix),
      desvio_padrao = sd(as.numeric(theta_matrix)),
      minimo = min(theta_matrix),
      maximo = max(theta_matrix),
      amplitude = max(theta_matrix) - min(theta_matrix),
      stringsAsFactors = FALSE
    )

    item_files <- if (method == "Classic") {
      c(a = "a_estimados_EM.txt", b = "b_estimados_EM.txt", alpha = "alpha_estimados_EM.txt")
    } else {
      c(a = "a_estimados_mean.txt", b = "b_estimados_mean.txt", alpha = "alpha_estimados_mean.txt")
    }
    item_metrics <- lapply(names(item_files), function(parameter) {
      estimates <- read_numeric_matrix(file.path(scenario_dir, item_files[[parameter]]), 10)
      calculate_metrics(estimates, true_items[[parameter]])
    })
    names(item_metrics) <- names(item_files)
    parameter_rows[[length(parameter_rows) + 1]] <- data.frame(
      n = n,
      metodo = method_labels[[method]],
      vicio_a = item_metrics$a$vicio,
      vicio_b = item_metrics$b$vicio,
      vicio_alpha = item_metrics$alpha$vicio,
      rmse_a = item_metrics$a$rmse,
      rmse_b = item_metrics$b$rmse,
      rmse_alpha = item_metrics$alpha$rmse,
      stringsAsFactors = FALSE
    )
  }
}

beta_data <- do.call(rbind, beta_rows)
theta_data <- do.call(rbind, theta_rows)
theta_metrics <- do.call(rbind, theta_metric_rows)
parameter_table <- do.call(rbind, parameter_rows)

expected_theta <- data.frame(
  n = rep(scenarios, each = 2),
  metodo = rep(c("Duas etapas", "Conjunto"), times = length(scenarios)),
  vicio = c(-0.0129877, -0.0128045, -0.0409782, -0.0410382,
            0.0053054, 0.0054828, 0.0311680, 0.0311900),
  rmse = c(0.2001679, 0.2114091, 0.2030311, 0.2051130,
           0.2017679, 0.1971523, 0.2017156, 0.1993584)
)

if (any(abs(theta_metrics$vicio - expected_theta$vicio) > 0.0000001) ||
    any(abs(theta_metrics$rmse - expected_theta$rmse) > 0.0000001)) {
  stop("As métricas dos traços divergem dos valores de controle auditados.")
}

method_codes <- c("Duas etapas" = "Classic", "Conjunto" = "Joint")
summary_table <- data.frame(
  n = parameter_table$n,
  p = 10,
  method = unname(method_codes[parameter_table$metodo]),
  bias_theta = theta_metrics$vicio,
  rmse_theta = theta_metrics$rmse,
  bias_a = parameter_table$vicio_a,
  rmse_a = parameter_table$rmse_a,
  bias_b = parameter_table$vicio_b,
  rmse_b = parameter_table$rmse_b,
  bias_alpha = parameter_table$vicio_alpha,
  rmse_alpha = parameter_table$rmse_alpha,
  stringsAsFactors = FALSE
)

theta_statistics <- data.frame(
  n = theta_metrics$n,
  p = 10,
  method = unname(method_codes[theta_metrics$metodo]),
  mean = theta_metrics$media,
  sd = theta_metrics$desvio_padrao,
  min = theta_metrics$minimo,
  max = theta_metrics$maximo,
  range = theta_metrics$amplitude,
  bias = theta_metrics$vicio,
  rmse = theta_metrics$rmse,
  stringsAsFactors = FALSE
)

analysis_dir <- file.path(results_root, "Analise_Classic_vs_Joint")
dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)

write.csv(beta_data, file.path(output_dir, "beta_1_estimativas.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(theta_data, file.path(output_dir, "theta_medias.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(theta_metrics, file.path(output_dir, "metricas_theta.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(parameter_table, file.path(output_dir, "tabela_parametros.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(summary_table, file.path(analysis_dir, "resumo_tri.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write.csv(theta_statistics, file.path(analysis_dir, "thetas.csv"), row.names = FALSE, fileEncoding = "UTF-8")

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Pacote jsonlite ausente; execute renv::restore().")
}

jsonlite::write_json(
  list(summary = summary_table, theta_stats = theta_statistics),
  file.path(analysis_dir, "metrics.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  na = "null"
)

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Pacote openxlsx ausente; execute renv::restore().")
}

header_style <- openxlsx::createStyle(
  textDecoration = "bold", fgFill = "#F5F5F3",
  border = "Bottom", borderColour = "#202124"
)

summary_workbook <- openxlsx::createWorkbook()
openxlsx::addWorksheet(summary_workbook, "Resumo_TRI", gridLines = FALSE)
openxlsx::writeData(summary_workbook, "Resumo_TRI", summary_table)
openxlsx::addStyle(summary_workbook, "Resumo_TRI", header_style,
                   rows = 1, cols = seq_len(ncol(summary_table)), gridExpand = TRUE)
openxlsx::setColWidths(summary_workbook, "Resumo_TRI",
                       cols = seq_len(ncol(summary_table)), widths = "auto")
openxlsx::freezePane(summary_workbook, "Resumo_TRI", firstActiveRow = 2)
openxlsx::saveWorkbook(
  summary_workbook,
  file.path(analysis_dir, "comparacao_classic_joint_crm.xlsx"),
  overwrite = TRUE
)

parameter_workbook <- openxlsx::createWorkbook()
openxlsx::addWorksheet(parameter_workbook, "Parametros_TRI", gridLines = FALSE)
openxlsx::writeData(parameter_workbook, "Parametros_TRI", parameter_table)
openxlsx::addStyle(parameter_workbook, "Parametros_TRI", header_style,
                   rows = 1, cols = seq_len(ncol(parameter_table)), gridExpand = TRUE)
openxlsx::setColWidths(parameter_workbook, "Parametros_TRI",
                       cols = seq_len(ncol(parameter_table)), widths = "auto")
openxlsx::freezePane(parameter_workbook, "Parametros_TRI", firstActiveRow = 2)
openxlsx::saveWorkbook(
  parameter_workbook,
  file.path(analysis_dir, "comparacao_parametros_tri_crm.xlsx"),
  overwrite = TRUE
)

message(
  "Dados derivados preparados: ", nrow(beta_data), " estimativas de beta_1; ",
  nrow(theta_data), " médias de theta; ", nrow(parameter_table), " linhas da tabela; ",
  nrow(theta_metrics), " linhas de métricas dos traços."
)
