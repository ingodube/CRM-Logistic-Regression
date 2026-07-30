args <- commandArgs(trailingOnly = TRUE)
project_dir <- normalizePath(if (length(args) > 0) args[[1]] else getwd(), winslash = "/", mustWork = TRUE)
html_path <- file.path(project_dir, "docs", "index.html")
rmd_path <- file.path(project_dir, "relatorio", "relatorio_metodologico.Rmd")

if (!file.exists(html_path)) {
  stop("Relatório renderizado não encontrado: ", html_path)
}

html <- paste(readLines(html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
rmd <- paste(readLines(rmd_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
plain <- gsub("<script[^>]*>.*?</script>", " ", html, perl = TRUE)
plain <- gsub("<style[^>]*>.*?</style>", " ", plain, perl = TRUE)
plain <- gsub("<[^>]+>", " ", plain, perl = TRUE)
plain <- gsub("&nbsp;|&#160;", " ", plain)
plain <- gsub("&amp;", "&", plain)
plain <- gsub("&lt;", "<", plain)
plain <- gsub("&gt;", ">", plain)
plain <- gsub("[[:space:]]+", " ", plain)

count_matches <- function(pattern, x, fixed = FALSE) {
  matches <- gregexpr(pattern, x, fixed = fixed, perl = !fixed)[[1]]
  if (identical(matches[[1]], -1L)) 0L else length(matches)
}

extract_matches <- function(pattern, x) {
  matches <- gregexpr(pattern, x, perl = TRUE)
  regmatches(x, matches)[[1]]
}

required_phrases <- c(
  "Incorporando o Erro de Mensuração da Teoria da Resposta ao Item",
  "Ingo Dube Souza",
  "Palavras-chave",
  "Introdução",
  "Teoria da Resposta ao Item para Respostas Contínuas",
  "Estimação em Duas Etapas",
  "Estimação Simultânea",
  "Estudo com Dados Simulados",
  "Resultados Numéricos",
  "Conclusão e Trabalhos Futuros",
  "Wang, T. e Zeng, L. (1998)",
  "Zopluoglu, C. (2012)"
)

missing_phrases <- required_phrases[!vapply(required_phrases, grepl, logical(1), x = plain, fixed = TRUE)]
if (length(missing_phrases) > 0) {
  stop("Conteúdo obrigatório ausente: ", paste(missing_phrases, collapse = "; "))
}

if (grepl(">Resumo<", html, fixed = TRUE) || grepl("id=\"resumo\"", html, fixed = TRUE)) {
  stop("Uma seção de resumo foi encontrada, mas deve ser omitida.")
}

for (figure in c("Figura 1:", "Figura 2:", "Figura 3:", "Tabela 1:")) {
  if (!grepl(figure, plain, fixed = TRUE)) stop("Elemento obrigatório ausente: ", figure)
}

if (!grepl("data:image/png;base64", html, fixed = TRUE)) {
  stop("O relatório não está autocontido ou não incorporou as figuras.")
}

for (class_name in c("report-page", "report-header", "report-meta", "report-toc", "report-content")) {
  if (!grepl(class_name, html, fixed = TRUE)) stop("Estrutura visual ausente: ", class_name)
}

if (!grepl("--accent: #e65b2c", html, fixed = TRUE) ||
    !grepl("max-width: 46rem", html, fixed = TRUE)) {
  stop("O padrão visual de publicação não foi incorporado ao relatório.")
}

if (grepl("script.src  = \"http", html, fixed = TRUE) ||
    grepl("<link rel=\"stylesheet\" href=\"http", html, fixed = TRUE)) {
  stop("O relatório depende de um recurso externo de apresentação.")
}

if (!grepl("<math", html, fixed = TRUE)) {
  stop("As expressões matemáticas não foram incorporadas como MathML.")
}

expected_source <- "Fonte: elaboração própria do autor."
if (count_matches(expected_source, rmd, fixed = TRUE) != 4L ||
    count_matches(expected_source, plain, fixed = TRUE) != 4L) {
  stop("As quatro figuras e tabelas devem apresentar a fonte do autor.")
}

if (grepl("Nota de auditoria", rmd, fixed = TRUE) ||
    grepl("nota-metodologica", rmd, fixed = TRUE) ||
    grepl("Nota de auditoria", plain, fixed = TRUE) ||
    grepl("nota-metodologica", html, fixed = TRUE)) {
  stop("Uma nota ou classe de auditoria permaneceu no relatório.")
}

email <- "ingo.dube@ufba.br"
if (count_matches(email, plain, fixed = TRUE) != 1L ||
    count_matches(paste0("mailto:", email), html, fixed = TRUE) != 1L) {
  stop("O e-mail institucional deve aparecer uma vez e possuir um único mailto válido.")
}

ai_title <- "Declaração de uso de inteligência artificial"
ai_text <- paste(
  "Durante a preparação deste trabalho, foi utilizado o ChatGPT/Codex, da OpenAI, com modelo GPT-5, como ferramenta de apoio à estruturação dos códigos, revisão de consistência, formatação do relatório, organização visual de tabelas e figuras e automação da renderização.",
  "O conteúdo científico, a construção do modelo estatístico, a interpretação dos resultados, a validação das estimativas e a responsabilidade final pelo trabalho são do autor.",
  "A ferramenta de inteligência artificial não foi utilizada como autora, não substituiu a análise crítica do autor e não altera a responsabilidade humana sobre a integridade, a precisão e a apresentação das informações."
)
if (!grepl(ai_title, plain, fixed = TRUE) || !grepl(ai_text, plain, fixed = TRUE)) {
  stop("A declaração de uso de inteligência artificial está ausente ou foi alterada.")
}

reference_position <- regexpr('id="referencias"', html, fixed = TRUE)[[1]]
ai_position <- regexpr('id="declaracao-uso-ia"', html, fixed = TRUE)[[1]]
if (reference_position < 0L || ai_position <= reference_position) {
  stop("A declaração de uso de IA deve aparecer após as referências.")
}

toc_start <- regexpr('<nav id="TOC"', html, fixed = TRUE)[[1]]
toc_end <- regexpr('</nav>', html, fixed = TRUE)[[1]]
if (toc_start < 0L || toc_end <= toc_start) stop("Sumário não localizado.")
toc_html <- substr(html, toc_start, toc_end + nchar('</nav>') - 1L)
if (grepl("declaracao-uso-ia", toc_html, fixed = TRUE)) {
  stop("A declaração de uso de IA não deve aparecer no sumário.")
}

html_ids <- sub('^id="|"$', '', extract_matches('id="[^"]+"', html))
duplicated_ids <- unique(html_ids[duplicated(html_ids)])
if (length(duplicated_ids) > 0L) {
  stop("IDs duplicados no HTML: ", paste(duplicated_ids, collapse = ", "))
}

fragment_links <- sub('^href="#|"$', '', extract_matches('href="#[^"]+"', html))
missing_targets <- setdiff(fragment_links, html_ids)
if (length(missing_targets) > 0L) {
  stop("Links internos sem destino: ", paste(missing_targets, collapse = ", "))
}

toc_targets <- sub('^href="#|"$', '', extract_matches('href="#[^"]+"', toc_html))
if (length(toc_targets) != 16L || anyDuplicated(toc_targets)) {
  stop("O sumário deve conter 16 destinos internos únicos.")
}

reference_ids <- gsub('^<p id="|">$', '',
                      extract_matches('<p id="ref-[^"]+">', rmd))
if (length(reference_ids) != 57L || anyDuplicated(reference_ids)) {
  stop("As 57 referências devem possuir IDs internos únicos.")
}

citation_section <- sub('(?s)# Referências \\{#referencias\\}.*$', '', rmd,
                        perl = TRUE)
citation_targets <- sub('^#', '',
                        extract_matches('#ref-[a-z0-9-]+', citation_section))
missing_reference_targets <- setdiff(citation_targets, reference_ids)
if (length(citation_targets) == 0L || length(missing_reference_targets) > 0L) {
  stop("Citações com destino bibliográfico ausente: ",
       paste(missing_reference_targets, collapse = ", "))
}

body_rmd <- sub('(?s)^.*?# Introdução \\{#introducao\\}', '', rmd, perl = TRUE)
body_rmd <- sub('(?s)# Referências \\{#referencias\\}.*$', '', body_rmd,
                perl = TRUE)
body_rmd <- gsub('(?ms)^```.*?^```[[:space:]]*$', ' ', body_rmd, perl = TRUE)
body_without_links <- gsub('\\[[^]]+\\]\\(#ref-[^)]+\\)', ' ', body_rmd,
                           perl = TRUE)
unlinked_citations <- c(
  extract_matches(
    '[[:upper:]][[:alpha:]-]+(?:[[:space:]][[:alpha:].-]+){0,4}[[:space:]]*\\((?:19|20)[0-9]{2}[a-z]?\\)',
    body_without_links
  ),
  extract_matches(
    '\\([^\\n)]*[[:alpha:]][^\\n)]*(?:19|20)[0-9]{2}[a-z]?[^\\n)]*\\)',
    body_without_links
  )
)
if (length(unlinked_citations) > 0L) {
  stop("Há citações autor-data sem hiperlink no texto: ",
       paste(unique(unlinked_citations), collapse = "; "))
}

required_chunks <- c(
  "parametros-verdadeiros", "geracao-crm", "geracao-desfecho",
  "estimacao-em", "regressao-duas-etapas", "especificacao-jags",
  "amostragem-jags", "diagnostico-cadeias", "vies-rmse",
  "figura-1", "figura-2", "tabela-1", "figura-3"
)
missing_chunks <- required_chunks[!vapply(
  required_chunks,
  function(chunk) grepl(paste0("```{r ", chunk), rmd, fixed = TRUE),
  logical(1)
)]
if (length(missing_chunks) > 0) {
  stop("Blocos obrigatórios ausentes: ", paste(missing_chunks, collapse = "; "))
}

if (!grepl("eval = FALSE", rmd, fixed = TRUE)) {
  stop("Os blocos pesados não estão desativados por padrão.")
}

if (!all(vapply(c("Duas etapas", "Conjunto"), grepl,
                logical(1), x = plain, fixed = TRUE))) {
  stop("Os dois métodos não aparecem nos resultados renderizados.")
}

metrics_path <- file.path(project_dir, "relatorio", "dados", "metricas_theta.csv")
if (!file.exists(metrics_path)) stop("Métricas recalculadas dos traços não encontradas.")
metrics <- read.csv(metrics_path, check.names = FALSE)
expected_bias <- c(-0.0129877, -0.0128045, -0.0409782, -0.0410382,
                   0.0053054, 0.0054828, 0.0311680, 0.0311900)
expected_rmse <- c(0.2001679, 0.2114091, 0.2030311, 0.2051130,
                   0.2017679, 0.1971523, 0.2017156, 0.1993584)
if (nrow(metrics) != 8 ||
    any(abs(metrics$vicio - expected_bias) > 0.0000001) ||
    any(abs(metrics$rmse - expected_rmse) > 0.0000001)) {
  stop("As métricas recalculadas dos traços não conferem com os valores de controle.")
}

message("Relatório validado: conteúdo, links, estrutura e figuras essenciais presentes.")
