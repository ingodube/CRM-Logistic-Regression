args <- commandArgs(trailingOnly = TRUE)
project_dir <- normalizePath(
  if (length(args) > 0) args[[1]] else getwd(),
  winslash = "/", mustWork = TRUE
)
pdf_path <- file.path(project_dir, "report", "Technical Report Source (PT-BR).pdf")
rmd_path <- file.path(project_dir, "report", "technical_report_pt_br.Rmd")

if (!requireNamespace("stringi", quietly = TRUE)) {
  stop("The stringi package is missing; run renv::restore().")
}
pdftotext <- Sys.which("pdftotext")
if (!nzchar(pdftotext)) stop("pdftotext was not found. Install Poppler to compare protected text.")

extracted_path <- tempfile(fileext = ".txt")
status <- system2(pdftotext, c("-raw", "-enc", "UTF-8", shQuote(pdf_path), shQuote(extracted_path)))
if (!identical(status, 0L)) stop("Failed to extract text from the source PDF.")

pdf_lines <- readLines(extracted_path, warn = FALSE, encoding = "UTF-8")
pdf_lines <- pdf_lines[!grepl("^[[:space:]]*[0-9]+[[:space:]]*$", pdf_lines)]
pdf_text <- paste(pdf_lines, collapse = "\n")
pdf_text <- gsub("Tabela 1:[\\s\\S]*?0\\.0278", " ", pdf_text, perl = TRUE)
pdf_text <- gsub("-\n[[:space:]]*", "", pdf_text)
pdf_text <- gsub("\n", " ", pdf_text)

normalize_text <- function(text) {
  text <- stringi::stri_trans_nfc(text)
  text <- gsub("\\[([^]]+)\\]\\(#[^)]+\\)", "\\1", text)
  text <- gsub("Figura 6", "Figura 2", text, fixed = TRUE)
  text <- gsub("Figura 7", "Figura 3", text, fixed = TRUE)
  text <- gsub("β", " beta ", text, fixed = TRUE)
  text <- gsub("θ", " theta ", text, fixed = TRUE)
  text <- gsub("α", " alpha ", text, fixed = TRUE)
  text <- gsub("\\\\widehat", "", text)
  text <- gsub("\\\\(l|c)dots", " ", text)
  text <- gsub("\\\\operatorname", "", text)
  text <- gsub("\\\\beta", " beta ", text)
  text <- gsub("\\\\theta", " theta ", text)
  text <- gsub("\\\\alpha", " alpha ", text)
  text <- gsub("\\\\[[:alpha:]]+", " ", text)
  text <- gsub("[`$\\\\{}_]", " ", text)
  text <- stringi::stri_trans_general(text, "Latin-ASCII")
  text <- tolower(text)
  text <- gsub("[^[:alnum:]]+", " ", text)
  text <- gsub("\\b(y|z|w|x|a|b|q|f|k|theta|beta|alpha)(ij|i|j|[0-9]+)\\b", "\\1 \\2", text, perl = TRUE)
  text <- gsub("\\bb[[:space:]]+(?=(beta|theta))", "", text, perl = TRUE)
  trimws(gsub("[[:space:]]+", " ", text))
}

rmd <- readLines(rmd_path, warn = FALSE, encoding = "UTF-8")
section_range <- function(start_pattern, end_pattern) {
  start <- grep(start_pattern, rmd)
  end <- grep(end_pattern, rmd)
  if (length(start) != 1L || length(end) != 1L || end <= start) {
    stop("Could not delimit protected section: ", start_pattern, " to ", end_pattern)
  }
  seq.int(start + 1L, end - 1L)
}

protected_indices <- c(
  section_range("^# Introdução \\{#introducao\\}$", "^# Metodologia \\{#metodologia\\}$"),
  section_range("^# Metodologia \\{#metodologia\\}$", "^### Interpretação dos parâmetros \\{#interpretacao-parametros\\}$"),
  section_range("^## Regressão Logística \\{#regressao-logistica\\}$", "^## Métodos de Estimação \\{#metodos-estimacao\\}$"),
  section_range("^# Resultados Numéricos \\{#resultados-numericos\\}$", "^# Conclusão e Trabalhos Futuros \\{#conclusao-trabalhos-futuros\\}$"),
  section_range("^# Conclusão e Trabalhos Futuros \\{#conclusao-trabalhos-futuros\\}$", "^# Referências \\{#referencias\\}$"),
  section_range("^# Referências \\{#referencias\\}$", "^<section class=\"ai-declaration\"")
)

selected <- logical(length(rmd))
selected[protected_indices] <- TRUE
in_code <- FALSE
in_equation <- FALSE
paragraphs <- character()
for (index in seq_along(rmd)) {
  line <- rmd[[index]]
  if (grepl("^```", line)) { in_code <- !in_code; next }
  if (grepl("^\\$\\$", line)) { in_equation <- !in_equation; next }
  if (!selected[[index]] || in_code || in_equation || !nzchar(trimws(line))) next
  if (grepl("^#", line) || grepl("Tabela 1:", line, fixed = TRUE) ||
      (grepl("^</?div", line) && !grepl("Figura", line))) next
  line <- gsub("<[^>]+>", " ", line)
  line <- gsub("\\[([^]]+)\\]\\(#[^)]+\\)", "\\1", line)
  sentences <- strsplit(line, "(?<=[.!?])\\s+", perl = TRUE)[[1]]
  normalized <- vapply(sentences, normalize_text, character(1))
  paragraphs <- c(paragraphs, normalized[nchar(normalized) >= 35])
}

normalized_pdf <- normalize_text(pdf_text)
missing <- paragraphs[!vapply(paragraphs, grepl, logical(1), x = normalized_pdf, fixed = TRUE)]
if (length(missing)) {
  stop(
    "Protected PT-BR text differs from the source PDF. First unmatched normalized passage:\n",
    missing[[1]]
  )
}
if (length(paragraphs) != 190L) stop("Expected 190 protected paragraphs; found ", length(paragraphs), ".")

message("Protected-text comparison passed: 190 PT-BR paragraphs match the source PDF after normalization.")
