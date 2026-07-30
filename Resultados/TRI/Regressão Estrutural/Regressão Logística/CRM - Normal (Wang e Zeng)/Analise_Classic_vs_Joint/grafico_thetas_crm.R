# Grafico dos thetas estimados vs. thetas verdadeiros - CRM
# Autor: script gerado para comparacao Classic vs Joint
#
# Saidas:
# - grafico_thetas_estimados_crm.png
# - grafico_thetas_estimados_crm.pdf
# - estatisticas_thetas_estimados_crm.xlsx

install_if_missing <- FALSE

required_packages <- c("ggplot2", "dplyr", "tidyr", "purrr", "openxlsx")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0) {
  if (install_if_missing) {
    install.packages(missing_packages, dependencies = TRUE, repos = "https://cloud.r-project.org")
  } else {
    stop(
      "Pacotes ausentes: ",
      paste(missing_packages, collapse = ", "),
      ". Instale-os ou defina install_if_missing <- TRUE."
    )
  }
}

library(ggplot2)
library(dplyr)
library(tidyr)
library(purrr)
library(openxlsx)

root_dir <- normalizePath(file.path(dirname(if (sys.nframe() > 0 && !is.null(sys.frame(1)$ofile)) sys.frame(1)$ofile else sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])), ".."), winslash = "/", mustWork = TRUE)
output_dir <- file.path(root_dir, "Analise_Classic_vs_Joint")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

scenarios <- tibble::tibble(
  n = c(100, 250, 500, 1000),
  p = 10
)

methods <- tibble::tibble(
  metodo = c("Classic", "Joint"),
  metodo_label = c("Duas etapas", "Conjunto"),
  theta_file = c("theta_estimados_EM.txt", "thetas_estimados_mean.txt")
)

read_theta_matrix <- function(n, p, metodo, theta_file) {
  path <- file.path(root_dir, metodo, paste0("n = ", n, " p = ", p), theta_file)
  
  if (!file.exists(path)) {
    stop("Arquivo nao encontrado: ", path)
  }
  
  theta_mat <- as.matrix(read.table(path, header = FALSE))
  storage.mode(theta_mat) <- "numeric"
  
  expected_dim <- c(n, 1000)
  observed_dim <- dim(theta_mat)
  
  if (!all(observed_dim == expected_dim)) {
    stop(
      "Dimensao invalida em ", path,
      ". Esperado: ", paste(expected_dim, collapse = " x "),
      "; observado: ", paste(observed_dim, collapse = " x ")
    )
  }
  
  if (any(!is.finite(theta_mat))) {
    stop("Valores nao finitos encontrados em: ", path)
  }
  
  theta_mat
}

true_theta <- function(n) {
  set.seed(228371 + n)
  rnorm(n, mean = 0, sd = 1)
}

theta_data <- tidyr::crossing(scenarios, methods) %>%
  mutate(
    theta_real = map(n, true_theta),
    theta_estimados = pmap(
      list(n, p, metodo, theta_file),
      read_theta_matrix
    ),
    theta_estimado_medio = map(theta_estimados, rowMeans),
    individuo = map(n, seq_len)
  )

plot_data <- theta_data %>%
  select(n, p, metodo, metodo_label, individuo, theta_real, theta_estimado_medio) %>%
  unnest(cols = c(individuo, theta_real, theta_estimado_medio)) %>%
  mutate(
    n_label = paste0("n = ", n),
    metodo_label = factor(metodo_label, levels = c("Duas etapas", "Conjunto")),
    n_label = factor(n_label, levels = paste0("n = ", scenarios$n))
  )

theta_stats <- theta_data %>%
  
  mutate(
    valores = map(theta_estimados, as.vector),
    media = map_dbl(valores, mean),
    desvio_padrao = map_dbl(valores, sd),
    minimo = map_dbl(valores, min),
    maximo = map_dbl(valores, max),
    amplitude = maximo - minimo,
    vicio = map2_dbl(theta_estimado_medio, theta_real, ~ mean(.x - .y)),
    rmse = map2_dbl(theta_estimados, theta_real, ~ mean(sqrt(rowMeans((.x - .y)^2)))),
    media_thetas_medios = map_dbl(theta_estimado_medio, mean),
    desvio_padrao_thetas_medios = map_dbl(theta_estimado_medio, sd)
  ) %>%
  select(
    n, p, metodo, metodo_label,
    media, desvio_padrao, minimo, maximo, amplitude,
    media_thetas_medios, desvio_padrao_thetas_medios
  ) %>%
  arrange(n, metodo)

wb <- createWorkbook()

addWorksheet(wb, "Estatisticas")
writeData(wb, "Estatisticas", theta_stats)
setColWidths(wb, "Estatisticas", cols = 1:ncol(theta_stats), widths = "auto")
addStyle(
  wb, "Estatisticas",
  style = createStyle(textDecoration = "bold", fgFill = "#D9E8F5", border = "Bottom"),
  rows = 1, cols = 1:ncol(theta_stats), gridExpand = TRUE
)
freezePane(wb, "Estatisticas", firstActiveRow = 2)

addWorksheet(wb, "Dados_grafico")
writeData(wb, "Dados_grafico", plot_data)
setColWidths(wb, "Dados_grafico", cols = 1:ncol(plot_data), widths = "auto")
addStyle(
  wb, "Dados_grafico",
  style = createStyle(textDecoration = "bold", fgFill = "#D9E8F5", border = "Bottom"),
  rows = 1, cols = 1:ncol(plot_data), gridExpand = TRUE
)
freezePane(wb, "Dados_grafico", firstActiveRow = 2)

excel_path <- file.path(output_dir, "estatisticas_thetas_estimados_crm.xlsx")
saveWorkbook(wb, excel_path, overwrite = TRUE)

theta_plot <- ggplot(
  plot_data,
  aes(x = theta_real, y = theta_estimado_medio)
) +
  geom_point(color = "#00B7EB", size = 0.85, alpha = 0.95) +
  geom_abline(intercept = 0, slope = 1, color = "#7A7A7A", linewidth = 0.25, linetype = "dashed") +
  facet_grid(metodo_label ~ n_label) +
  coord_equal() +
  labs(
    x = expression(theta~"verdadeiro"),
    y = expression("media de "~theta~" estimado")
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.background = element_rect(fill = "white", color = "white"),
    panel.background = element_rect(fill = "white", color = "white"),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    panel.border = element_blank(),
    strip.background = element_rect(fill = "white", color = "white"),
    strip.text = element_text(color = "black", face = "bold", size = 10),
    axis.text = element_text(color = "black", size = 8),
    axis.title = element_text(color = "black", size = 10),
    plot.margin = margin(12, 12, 12, 12),
    legend.position = "none"
  )

png_path <- file.path(output_dir, "grafico_thetas_estimados_crm.png")
pdf_path <- file.path(output_dir, "grafico_thetas_estimados_crm.pdf")

ggsave(
  filename = png_path,
  plot = theta_plot,
  width = 11,
  height = 8,
  dpi = 300,
  bg = "white"
)

ggsave(
  filename = pdf_path,
  plot = theta_plot,
  width = 11,
  height = 8,
  bg = "white"
)

if (interactive()) {
  print(theta_plot)
}
message("Grafico PNG salvo em: ", png_path)
message("Grafico PDF salvo em: ", pdf_path)
message("Planilha Excel salva em: ", excel_path)
