args <- commandArgs(trailingOnly = TRUE)
project_dir <- normalizePath(if (length(args) > 0) args[[1]] else getwd(),
                             winslash = "/", mustWork = TRUE)
pdf_path <- file.path(project_dir, "Projeto_Ingo.pdf")
rmd_path <- file.path(project_dir, "relatorio", "relatorio_metodologico.Rmd")

if (!requireNamespace("stringi", quietly = TRUE)) {
  stop("Pacote stringi ausente; execute renv::restore().")
}

pdftotext <- Sys.which("pdftotext")
if (!nzchar(pdftotext)) {
  stop("Utilitário pdftotext não localizado. Instale o Poppler para comparar o texto.")
}

pdf_text_path <- tempfile(fileext = ".txt")
status <- system2(pdftotext,
                  c("-raw", "-enc", "UTF-8", shQuote(pdf_path),
                    shQuote(pdf_text_path)))
if (!identical(status, 0L)) stop("Falha ao extrair o texto do PDF.")

pdf_lines <- readLines(pdf_text_path, warn = FALSE, encoding = "UTF-8")
pdf_lines <- pdf_lines[!grepl("^[[:space:]]*[0-9]+[[:space:]]*$", pdf_lines)]
pdf_text <- paste(pdf_lines, collapse = "\n")
pdf_text <- gsub("Tabela 1:[\\s\\S]*?0\\.0278", " ",
                 pdf_text, perl = TRUE)
pdf_text <- gsub("-\n[[:space:]]*", "", pdf_text)
pdf_text <- gsub("\n", " ", pdf_text)

normalizar <- function(x) {
  x <- stringi::stri_trans_nfc(x)
  x <- gsub("\\[([^]]+)\\]\\(#[^)]+\\)", "\\1", x)
  x <- gsub("Figura 6", "Figura 2", x, fixed = TRUE)
  x <- gsub("Figura 7", "Figura 3", x, fixed = TRUE)
  x <- gsub("β", " beta ", x, fixed = TRUE)
  x <- gsub("θ", " theta ", x, fixed = TRUE)
  x <- gsub("α", " alpha ", x, fixed = TRUE)
  x <- gsub("\\\\widehat", "", x)
  x <- gsub("\\\\(l|c)dots", " ", x)
  x <- gsub("\\\\operatorname", "", x)
  x <- gsub("\\\\beta", " beta ", x)
  x <- gsub("\\\\theta", " theta ", x)
  x <- gsub("\\\\alpha", " alpha ", x)
  x <- gsub("\\\\[[:alpha:]]+", " ", x)
  x <- gsub("[`$\\\\{}_]", " ", x)
  x <- stringi::stri_trans_general(x, "Latin-ASCII")
  x <- tolower(x)
  x <- gsub("[^[:alnum:]]+", " ", x)
  x <- gsub("\\b(y|z|w|x|a|b|q|f|k|theta|beta|alpha)(ij|i|j|[0-9]+)\\b",
            "\\1 \\2", x, perl = TRUE)
  x <- gsub("\\bb[[:space:]]+(?=(beta|theta))", "", x, perl = TRUE)
  trimws(gsub("[[:space:]]+", " ", x))
}

rmd <- readLines(rmd_path, warn = FALSE, encoding = "UTF-8")

intervalo <- function(inicio, fim) {
  a <- grep(inicio, rmd)
  b <- grep(fim, rmd)
  if (length(a) != 1 || length(b) != 1 || b <= a) {
    stop("Não foi possível delimitar: ", inicio, " até ", fim)
  }
  seq.int(a + 1L, b - 1L)
}

indices <- c(
  intervalo("^# Introdução \\{#introducao\\}$",
            "^# Metodologia \\{#metodologia\\}$"),
  intervalo("^# Metodologia \\{#metodologia\\}$",
            "^### Interpretação dos parâmetros \\{#interpretacao-parametros\\}$"),
  intervalo("^## Regressão Logística \\{#regressao-logistica\\}$",
            "^## Métodos de Estimação \\{#metodos-estimacao\\}$"),
  intervalo("^# Resultados Numéricos \\{#resultados-numericos\\}$",
            "^# Conclusão e Trabalhos Futuros \\{#conclusao-trabalhos-futuros\\}$"),
  intervalo("^# Conclusão e Trabalhos Futuros \\{#conclusao-trabalhos-futuros\\}$",
            "^# Referências \\{#referencias\\}$"),
  intervalo("^# Referências \\{#referencias\\}$",
            "^<section class=\"ai-declaration\"")
)

selecionadas <- logical(length(rmd))
selecionadas[indices] <- TRUE
em_codigo <- FALSE
em_equacao <- FALSE
paragrafos <- character()

for (i in seq_along(rmd)) {
  linha <- rmd[[i]]
  if (grepl("^```", linha)) {
    em_codigo <- !em_codigo
    next
  }
  if (grepl("^\\$\\$", linha)) {
    em_equacao <- !em_equacao
    next
  }
  if (!selecionadas[[i]] || em_codigo || em_equacao || !nzchar(trimws(linha))) next
  if (grepl("^#", linha) ||
      grepl("Tabela 1:", linha, fixed = TRUE) ||
      grepl("^</?div", linha) && !grepl("Figura", linha)) next
  linha <- gsub("<[^>]+>", " ", linha)
  linha <- gsub("\\[([^]]+)\\]\\(#[^)]+\\)", "\\1", linha)
  partes <- strsplit(linha, "(?<=[.!?])\\s+", perl = TRUE)[[1]]
  textos <- vapply(partes, normalizar, character(1))
  paragrafos <- c(paragrafos, textos[nchar(textos) >= 35])
}

pdf_normalizado <- normalizar(pdf_text)
ausentes <- paragrafos[!vapply(paragrafos, grepl, logical(1),
                               x = pdf_normalizado, fixed = TRUE)]

if (length(ausentes) > 0) {
  palavras <- strsplit(ausentes[[1]], " ", fixed = TRUE)[[1]]
  prefixo <- paste(head(palavras, 8), collapse = " ")
  posicao <- regexpr(prefixo, pdf_normalizado, fixed = TRUE)[[1]]
  contexto <- if (posicao > 0) {
    substr(pdf_normalizado, posicao, posicao + nchar(ausentes[[1]]) + 120)
  } else {
    "prefixo não localizado no PDF normalizado"
  }
  candidato <- if (posicao > 0) {
    substr(pdf_normalizado, posicao, posicao + nchar(ausentes[[1]]) - 1L)
  } else ""
  primeira_diferenca <- if (posicao > 0) {
    fonte_chars <- strsplit(ausentes[[1]], "", fixed = TRUE)[[1]]
    pdf_chars <- strsplit(candidato, "", fixed = TRUE)[[1]]
    which(fonte_chars != pdf_chars)[1]
  } else NA_integer_
  detalhe <- if (!is.na(primeira_diferenca)) {
    paste0("posição ", primeira_diferenca, "; fonte='",
           substr(ausentes[[1]], max(1, primeira_diferenca - 30),
                  primeira_diferenca + 45), "'; PDF='",
           substr(candidato, max(1, primeira_diferenca - 30),
                  primeira_diferenca + 45), "'")
  } else "sem diferença localizada"
  stop(
    "Primeira diferença: ", detalhe,
    "\nContexto do primeiro trecho no PDF:\n", contexto,
    "\nA comparação normalizada encontrou trechos divergentes do PDF:\n- ",
    paste(head(ausentes, 8), collapse = "\n- "),
    if (length(ausentes) > 8) "\n- ..." else ""
  )
}

message("Comparação concluída: ", length(paragrafos),
        " parágrafos preservados conferem com o PDF após normalização.")
