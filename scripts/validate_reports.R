args <- commandArgs(trailingOnly = TRUE)
project_dir <- normalizePath(
  if (length(args) > 0) args[[1]] else getwd(),
  winslash = "/", mustWork = TRUE
)

read_text <- function(path) paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
matches <- function(pattern, text) regmatches(text, gregexpr(pattern, text, perl = TRUE))[[1]]
count_fixed <- function(needle, text) {
  found <- gregexpr(needle, text, fixed = TRUE)[[1]]
  if (identical(found[[1]], -1L)) 0L else length(found)
}
plain_text <- function(html) {
  text <- gsub("<script[^>]*>.*?</script>", " ", html, perl = TRUE)
  text <- gsub("<style[^>]*>.*?</style>", " ", text, perl = TRUE)
  text <- gsub("<[^>]+>", " ", text, perl = TRUE)
  text <- gsub("&nbsp;|&#160;", " ", text)
  text <- gsub("&amp;", "&", text)
  trimws(gsub("[[:space:]]+", " ", text))
}
assert_no_forbidden_english_terms <- function(project_dir) {
  forbidden_pattern <- paste0("two-", "stage|two_", "stage")
  text_paths <- c(
    file.path(project_dir, "README.md"),
    file.path(project_dir, "report", "technical_report_en.Rmd"),
    file.path(project_dir, "tools", c("localize_csvs.mjs", "translate_report.py")),
    list.files(
      file.path(project_dir, "Spreadsheets (EN)"),
      pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE
    ),
    file.path(project_dir, "docs", "metodologia.html")
  )
  text_hits <- vapply(text_paths, function(path) {
    grepl(forbidden_pattern, read_text(path), ignore.case = TRUE, perl = TRUE)
  }, logical(1))
  if (any(text_hits)) {
    stop(
      "Forbidden English terminology found in: ",
      paste(normalizePath(text_paths[text_hits], winslash = "/"), collapse = ", ")
    )
  }

  workbooks <- list.files(
    file.path(project_dir, "Spreadsheets (EN)"),
    pattern = "\\.xlsx$", full.names = TRUE, ignore.case = TRUE
  )
  for (workbook in workbooks) {
    extraction_dir <- tempfile("xlsx-terminology-")
    dir.create(extraction_dir)
    on.exit(unlink(extraction_dir, recursive = TRUE, force = TRUE), add = TRUE)
    utils::unzip(workbook, exdir = extraction_dir)
    xml_paths <- list.files(extraction_dir, pattern = "\\.xml$", recursive = TRUE, full.names = TRUE)
    xml_hit <- vapply(xml_paths, function(path) {
      grepl(forbidden_pattern, read_text(path), ignore.case = TRUE, perl = TRUE)
    }, logical(1))
    if (any(xml_hit)) {
      stop("Forbidden English terminology found in workbook: ", basename(workbook))
    }
  }
}

reports <- list(
  EN = list(
    html = file.path(project_dir, "docs", "metodologia.html"),
    rmd = file.path(project_dir, "report", "technical_report_en.Rmd"),
    lang = "en", current = "English (EN)",
    title = "Incorporating Measurement Error from Item Response Theory",
    headings = c("Introduction", "Methodology", "Numerical Results", "Conclusion and Future Work", "References"),
    figures = paste0("Figure ", 1:7, ":"), table = "Table 1:"
  ),
  `PT-BR` = list(
    html = file.path(project_dir, "docs", "methodology-pt-br.html"),
    rmd = file.path(project_dir, "report", "technical_report_pt_br.Rmd"),
    lang = "pt-BR", current = "Português (PT-BR)",
    title = "Incorporando o Erro de Mensuração da Teoria da Resposta ao Item",
    headings = c("Introdução", "Metodologia", "Resultados Numéricos", "Conclusão e Trabalhos Futuros", "Referências"),
    figures = paste0("Figura ", 1:7, ":"), table = "Tabela 1:"
  )
)

for (locale in names(reports)) {
  report <- reports[[locale]]
  if (!file.exists(report$html)) stop("Rendered report is missing: ", report$html)
  html <- read_text(report$html)
  plain <- plain_text(html)
  required <- c(report$title, report$headings, report$figures, report$table,
                "Ingo Dube Souza", "ChatGPT/Codex")
  missing <- required[!vapply(required, grepl, logical(1), x = plain, fixed = TRUE)]
  if (length(missing)) stop(locale, " required content is missing: ", paste(missing, collapse = "; "))
  structural <- c(
    paste0('<html lang="', report$lang, '"'),
    '<nav class="language-bar"', '<details class="language-switcher">',
    'hreflang="en"', 'hreflang="pt-BR"', 'hreflang="x-default"',
    '<link rel="canonical"', 'aria-current="page"',
    'data:image/png;base64', "--accent: #e65b2c", "max-width: 46rem",
    "pre.sourceCode { overflow: auto; }", '<div class="table-scroll">', "<math"
  )
  absent <- structural[!vapply(structural, grepl, logical(1), x = html, fixed = TRUE)]
  if (length(absent)) stop(locale, " structural requirements are missing: ", paste(absent, collapse = "; "))
  if (grepl('<link rel="stylesheet" href="http', html, fixed = TRUE) ||
      grepl('script.src  = "http', html, fixed = TRUE)) {
    stop(locale, " report depends on an external presentation resource.")
  }
  ids <- sub('^id="([^"]+)"$', '\\1', matches('id="[^"]+"', html))
  duplicates <- unique(ids[duplicated(ids)])
  if (length(duplicates)) stop(locale, " duplicate HTML IDs: ", paste(duplicates, collapse = ", "))
  fragments <- sub('^href="#([^"]+)"$', '\\1', matches('href="#[^"]+"', html))
  broken <- setdiff(fragments, ids)
  if (length(broken)) stop(locale, " broken fragments: ", paste(broken, collapse = ", "))
  if (count_fixed('aria-current="page">', html) != 1L) {
    stop(locale, " must mark exactly one language link as current.")
  }
}

en_rmd <- read_text(reports$EN$rmd)
pt_rmd <- read_text(reports$`PT-BR`$rmd)
id_pattern <- "\\{#[a-z0-9-]+\\}|id=\"[a-z0-9-]+\""
if (!identical(sort(matches(id_pattern, en_rmd)), sort(matches(id_pattern, pt_rmd)))) {
  stop("Semantic IDs differ between report sources.")
}
math_pattern <- "(?s)\\$\\$.*?\\$\\$"
if (!identical(matches(math_pattern, en_rmd), matches(math_pattern, pt_rmd))) {
  stop("Display equations differ between report sources.")
}
chunk_pattern <- "```\\{r[[:space:]]+[^,}]+"
if (!identical(matches(chunk_pattern, en_rmd), matches(chunk_pattern, pt_rmd))) {
  stop("R chunk identifiers differ between report sources.")
}
number_pattern <- "(?<![A-Za-z_])[-+]?(?:[0-9]+\\.[0-9]*|\\.[0-9]+|[0-9]+)(?:[eE][-+]?[0-9]+)?"
normalize_number_punctuation <- function(text) {
  text <- gsub("(?<=[0-9]),(?=[0-9]{3}\\b)", "", text, perl = TRUE)
  gsub("(?<=[0-9]),(?=[0-9]{1,2}\\b)", ".", text, perl = TRUE)
}
en_numbers <- matches(number_pattern, normalize_number_punctuation(sub("(?s)\\A---.*?---", "", en_rmd, perl = TRUE)))
pt_numbers <- matches(number_pattern, normalize_number_punctuation(sub("(?s)\\A---.*?---", "", pt_rmd, perl = TRUE)))
if (!identical(en_numbers, pt_numbers)) stop("Numeric tokens differ between report sources.")

index <- read_text(file.path(project_dir, "docs", "index.html"))
if (!grepl('url=metodologia.html', index, fixed = TRUE) ||
    !grepl('window.location.replace("metodologia.html")', index, fixed = TRUE)) {
  stop("docs/index.html does not redirect to the English report.")
}

assert_no_forbidden_english_terms(project_dir)

message("Bilingual report validation passed: content, parity, links, accessibility, and self-containment.")
