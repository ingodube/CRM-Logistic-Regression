# Plot of estimated versus true theta values - CRM
# Generated for the Classic versus Joint comparison
#
# Outputs:
# - crm_estimated_thetas_plot.png
# - crm_estimated_thetas_plot.pdf
# - estimated_theta_statistics.xlsx

install_if_missing <- FALSE

required_packages <- c("ggplot2", "dplyr", "tidyr", "purrr", "openxlsx")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0) {
  if (install_if_missing) {
    install.packages(missing_packages, dependencies = TRUE, repos = "https://cloud.r-project.org")
  } else {
    stop(
      "Missing packages: ",
      paste(missing_packages, collapse = ", "),
      ". Install them or set install_if_missing <- TRUE."
    )
  }
}

library(ggplot2)
library(dplyr)
library(tidyr)
library(purrr)
library(openxlsx)

script_path <- gsub("~+~", " ", if (sys.nframe() > 0 && !is.null(sys.frame(1)$ofile)) sys.frame(1)$ofile else sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1]), fixed = TRUE)
repo_root <- normalizePath(file.path(dirname(script_path), "../../../../../.."), winslash = "/", mustWork = TRUE)
root_dir <- file.path(repo_root, "Results (EN)", "IRT", "Structural Regression", "Logistic Regression", "CRM - Normal (Wang and Zeng)")
output_dir <- file.path(root_dir, "Classic_vs_Joint_Analysis")
spreadsheets_dir <- file.path(repo_root, "Spreadsheets (EN)")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(spreadsheets_dir, recursive = TRUE, showWarnings = FALSE)

scenarios <- tibble::tibble(
  n = c(100, 250, 500, 1000),
  p = 10
)

methods <- tibble::tibble(
  method = c("Classic", "Joint"),
  method_label = c("Two-stage", "Joint"),
  theta_file = c("theta_estimates_EM.txt", "theta_estimates_mean.txt")
)

read_theta_matrix <- function(n, p, method, theta_file) {
  path <- file.path(root_dir, method, paste0("n = ", n, " p = ", p), theta_file)

  if (!file.exists(path)) {
    stop("File not found: ", path)
  }

  theta_mat <- as.matrix(read.table(path, header = FALSE))
  storage.mode(theta_mat) <- "numeric"

  expected_dim <- c(n, 1000)
  observed_dim <- dim(theta_mat)

  if (!all(observed_dim == expected_dim)) {
    stop(
      "Invalid dimensions em ", path,
      ". Expected: ", paste(expected_dim, collapse = " x "),
      "; observed: ", paste(observed_dim, collapse = " x ")
    )
  }

  if (any(!is.finite(theta_mat))) {
    stop("Non-finite values found in: ", path)
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
    theta_estimates = pmap(
      list(n, p, method, theta_file),
      read_theta_matrix
    ),
    mean_theta_estimate = map(theta_estimates, rowMeans),
    individual = map(n, seq_len)
  )

plot_data <- theta_data %>%
  select(n, p, method, method_label, individual, theta_real, mean_theta_estimate) %>%
  unnest(cols = c(individual, theta_real, mean_theta_estimate)) %>%
  mutate(
    n_label = paste0("n = ", n),
    method_label = factor(method_label, levels = c("Two-stage", "Joint")),
    n_label = factor(n_label, levels = paste0("n = ", scenarios$n))
  )

theta_stats <- theta_data %>%

  mutate(
    values = map(theta_estimates, as.vector),
    mean_value = map_dbl(values, mean),
    standard_deviation = map_dbl(values, sd),
    minimum = map_dbl(values, min),
    maximum = map_dbl(values, max),
    range_value = maximum - minimum,
    bias = map2_dbl(mean_theta_estimate, theta_real, ~ mean(.x - .y)),
    rmse = map2_dbl(theta_estimates, theta_real, ~ mean(sqrt(rowMeans((.x - .y)^2)))),
    mean_of_mean_thetas = map_dbl(mean_theta_estimate, mean),
    sd_of_mean_thetas = map_dbl(mean_theta_estimate, sd)
  ) %>%
  select(
    n, p, method, method_label,
    mean_value, standard_deviation, minimum, maximum, range_value,
    mean_of_mean_thetas, sd_of_mean_thetas
  ) %>%
  arrange(n, method)

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

addWorksheet(wb, "Data_grafico")
writeData(wb, "Data_grafico", plot_data)
setColWidths(wb, "Data_grafico", cols = 1:ncol(plot_data), widths = "auto")
addStyle(
  wb, "Data_grafico",
  style = createStyle(textDecoration = "bold", fgFill = "#D9E8F5", border = "Bottom"),
  rows = 1, cols = 1:ncol(plot_data), gridExpand = TRUE
)
freezePane(wb, "Data_grafico", firstActiveRow = 2)

excel_path <- file.path(spreadsheets_dir, "estimated_theta_statistics.xlsx")
saveWorkbook(wb, excel_path, overwrite = TRUE)

theta_plot <- ggplot(
  plot_data,
  aes(x = theta_real, y = mean_theta_estimate)
) +
  geom_point(color = "#00B7EB", size = 0.85, alpha = 0.95) +
  geom_abline(intercept = 0, slope = 1, color = "#7A7A7A", linewidth = 0.25, linetype = "dashed") +
  facet_grid(method_label ~ n_label) +
  coord_equal() +
  labs(
    x = expression("True"~theta),
    y = expression("Mean estimated "~theta)
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

png_path <- file.path(output_dir, "crm_estimated_thetas_plot.png")
pdf_path <- file.path(output_dir, "crm_estimated_thetas_plot.pdf")

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
message("PNG plot saved to: ", png_path)
message("PDF plot saved to: ", pdf_path)
message("Excel workbook saved to: ", excel_path)
