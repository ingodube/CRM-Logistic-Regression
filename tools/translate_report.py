#!/usr/bin/env python3
"""Create the English R Markdown report while preserving its scientific markup."""

from __future__ import annotations

import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "report" / "technical_report_pt_br.Rmd"
TARGET = ROOT / "report" / "technical_report_en.Rmd"
CACHE = ROOT / "tools" / "translation-cache.json"

ENGLISH_YAML = """---
title: "Incorporating Measurement Error from Item Response Theory for Continuous Responses into Dichotomous Distal Outcomes: A Bayesian Approach"
author: "Ingo Dube Souza"
affiliation: "MSc Program in Statistics and Data Science (PGECD/UFBA)"
secondary-affiliation: "Department of Industrial Economics (SENAI/CIMATEC)"
email: "ingo.dube@ufba.br"
keywords: "IRT; Regression; Distal Outcome; MCMC; EM Algorithm."
lang: en
language-label: "Language"
language-current: "EN"
english-current: true
keywords-label: "Keywords"
toc-label: "Contents"
english-url: "metodologia.html"
portuguese-url: "methodology-pt-br.html"
canonical-url: "https://ingodube.github.io/CRM-Logistic-Regression/metodologia.html"
output:
  html_document:
    self_contained: true
    toc: true
    toc_float: false
    number_sections: true
    fig_caption: false
    theme: null
    math_method: mathml
    template: technical-report.html
    css: technical-report.css
---
"""

PT_REPLACEMENTS = {
    "figuras/figura-1-modelo-estrutural.png": "figures/figure-1-structural-model.png",
    "figures/figura-1-modelo-estrutural.png": "figures/figure-1-structural-model.png",
    '"dados/beta_1_estimativas.csv"': '"../Spreadsheets (PT-BR)/beta_1_estimativas.csv"',
    '"dados/tabela_parametros.csv"': '"../Spreadsheets (PT-BR)/tabela_parametros.csv"',
    '"dados/theta_medias.csv"': '"../Spreadsheets (PT-BR)/theta_medias.csv"',
    "e automação da renderização.": "e automação da renderização e tradução do relatório para o inglês.",
}

CODE_REPLACEMENTS = [
    ("figuras/figura-1-modelo-estrutural.png", "figures/figure-1-structural-model.png"),
    ("figures/figura-1-modelo-estrutural.png", "figures/figure-1-structural-model.png"),
    ('"dados/beta_1_estimativas.csv"', '"../Spreadsheets (EN)/beta_1_estimates.csv"'),
    ('"dados/tabela_parametros.csv"', '"../Spreadsheets (EN)/item_parameter_table.csv"'),
    ('"dados/theta_medias.csv"', '"../Spreadsheets (EN)/theta_means.csv"'),
    ('"../Spreadsheets (PT-BR)/beta_1_estimativas.csv"', '"../Spreadsheets (EN)/beta_1_estimates.csv"'),
    ('"../Spreadsheets (PT-BR)/tabela_parametros.csv"', '"../Spreadsheets (EN)/item_parameter_table.csv"'),
    ('"../Spreadsheets (PT-BR)/theta_medias.csv"', '"../Spreadsheets (EN)/theta_means.csv"'),
    ("Dados.dir.TRI", "irt_data_dir"), ("Dados.dir.Reg", "regression_data_dir"),
    ("DadosTRI_", "IRTData_"), ("Dados reg.log.", "LogisticRegressionData_"),
    ("montar_dados_crm", "build_crm_data"), ("dados_curvas", "curve_data"),
    ("n_itens", "n_items"), ("lambda_fator", "lambda_factor"),
    ("plot_cenario_crm", "plot_crm_scenario"), ("nome_cenario", "scenario_name"),
    ("plots_itens", "item_plots"), ("painel_itens", "item_panel"),
    ("cenario_artigo", "article_scenario"), ("cenario_alpha", "alpha_scenario"),
    ("cenario_a", "a_scenario"), ("cenario_b", "b_scenario"),
    ("thetas_reais", "true_thetas"), ("param_itens_reais", "true_item_parameters"),
    ("param.itens", "item.parameters"), ("resultados", "results"),
    ("logito", "logit"), ("data.logistico", "logistic_data"),
    ("theta_estimados", "theta_estimates"), ("a_estimados", "a_estimates"),
    ("b_estimados", "b_estimates"), ("alpha_estimados", "alpha_estimates"),
    ("beta_0_estimados", "beta_0_estimates"), ("beta_1_estimados", "beta_1_estimates"),
    ("fit_TRI", "irt_fit"), ("fit_theta", "theta_fit"),
    ("modelo_jags", "jags_model"), ("modelo", "model_specification"),
    ("amostras_jags", "jags_samples"), ("amostras", "samples"),
    ("theta.est.medio", "mean_theta_estimate"), ("Vicio_", "Bias_"),
    ("EQM_", "MSE_"), ("beta_resultados", "beta_results"),
    ("theta_resultados", "theta_results"), ("tabela", "table_data"),
    ("valores", "values"), ("metodo", "method"),
    ("theta_verdadeiro", "true_theta"), ("theta_estimado_medio", "mean_theta_estimate"),
    ('"Duas etapas"', '"Two-step"'), ('"Conjunto"', '"Joint"'),
    ('"Tamanho amostral (n)"', '"Sample size (n)"'), ('"Método"', '"Method"'),
    ("<th colspan=\"3\">Vicio</th>", "<th colspan=\"3\">Bias</th>"),
]

FIXED_TRANSLATIONS = {
    "# Introdução {#introducao}": "# Introduction {#introducao}",
    "# Metodologia {#metodologia}": "# Methodology {#metodologia}",
    "# Resultados Numéricos {#resultados-numericos}": "# Numerical Results {#resultados-numericos}",
    "# Conclusão e Trabalhos Futuros {#conclusao-trabalhos-futuros}": "# Conclusion and Future Work {#conclusao-trabalhos-futuros}",
    "# Referências {#referencias}": "# References {#referencias}",
}

AI_EN = """<section class="ai-declaration" aria-labelledby="declaracao-uso-ia">
<h1 id="declaracao-uso-ia">Declaration on the use of artificial intelligence</h1>

<p>During the preparation of this work, OpenAI's ChatGPT/Codex, using the GPT-5 model, was used to support code structuring, consistency review, report formatting, the visual organization of tables and figures, rendering automation, and translation of the report into English. The scientific content, construction of the statistical model, interpretation of results, validation of estimates, and final responsibility for the work belong to the author. The artificial intelligence tool was not used as an author, did not replace the author's critical analysis, and does not alter human responsibility for the integrity, accuracy, and presentation of the information.</p>
</section>"""


def load_cache() -> dict[str, str]:
    if CACHE.exists():
        return json.loads(CACHE.read_text(encoding="utf-8"))
    return {}


def save_cache(cache: dict[str, str]) -> None:
    CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def google_translate(text: str, cache: dict[str, str]) -> str:
    if text in cache:
        return cache[text]
    query = urllib.parse.urlencode({"client": "gtx", "sl": "pt", "tl": "en", "dt": "t", "q": text})
    url = "https://translate.googleapis.com/translate_a/single?" + query
    for attempt in range(5):
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                payload = json.loads(response.read().decode("utf-8"))
            result = "".join(part[0] for part in payload[0] if part[0])
            cache[text] = result
            if len(cache) % 20 == 0:
                save_cache(cache)
            return result
        except Exception:
            if attempt == 4:
                raise
            time.sleep(2 ** attempt)
    raise RuntimeError("Translation failed")


PROTECTED = re.compile(r"`[^`]+`|\$[^$\n]+\$|\[[^\]]+\]\(#[^)]+\)|<[^>]+>|\{#[^}]+\}")


def protect(text: str) -> tuple[str, list[str]]:
    values: list[str] = []
    def replace(match: re.Match[str]) -> str:
        values.append(match.group(0))
        return f"ZXQKEEP{len(values)-1:03d}QXZ"
    return PROTECTED.sub(replace, text), values


def restore(text: str, values: list[str]) -> str:
    for index, value in enumerate(values):
        token = f"ZXQKEEP{index:03d}QXZ"
        variants = [token, token.lower(), token.replace("KEEP", " KEEP "), token.replace("QXZ", " QXZ")]
        for variant in variants:
            text = text.replace(variant, value)
        text = re.sub(rf"ZXQ\s*KEEP\s*{index:03d}\s*QXZ", lambda _: value, text, flags=re.I)
    return text


def translate_block(block: str, cache: dict[str, str]) -> str:
    stripped = block.strip()
    if not stripped:
        return block
    if stripped in FIXED_TRANSLATIONS:
        return block.replace(stripped, FIXED_TRANSLATIONS[stripped])
    prepared = re.sub(r"\bTRI\b", "IRT", block)
    protected, values = protect(prepared)
    translated = google_translate(protected, cache)
    restored = restore(translated, values)
    return restored.replace("item response theory (IRT)", "Item Response Theory (IRT)")


def localize_code(code: str) -> str:
    result = code
    for source, target in CODE_REPLACEMENTS:
        result = result.replace(source, target)
    result = result.replace("fit_theta$thetas", "theta_fit$thetas")
    result = result.replace("table_data$metodo", "table_data$method")
    result = result.replace("figures/figura-1-model_specification-estrutural.png", "figures/figure-1-structural-model.png")
    result = result.replace("dados = curve_data", "data = curve_data")
    result = result.replace('<th rowspan="2">Método</th>', '<th rowspan="2">Method</th>')
    return result


def update_portuguese(source: str) -> str:
    result = source.replace("template: template.html", "template: technical-report.html")
    result = result.replace("css: estilo.css", "css: technical-report.css")
    for old, new in PT_REPLACEMENTS.items():
        result = result.replace(old, new)
    yaml_insert = 'lang: pt-BR\nlanguage-label: "Idioma"\nlanguage-current: "PT-BR"\nportuguese-current: true\nkeywords-label: "Palavras-chave"\ntoc-label: "Sumário"\nenglish-url: "metodologia.html"\nportuguese-url: "methodology-pt-br.html"\ncanonical-url: "https://ingodube.github.io/CRM-Logistic-Regression/methodology-pt-br.html"'
    if "language-label:" not in result:
        result = result.replace("lang: pt-BR", yaml_insert)
    elif "portuguese-current:" not in result:
        result = result.replace('language-current: "PT-BR"', 'language-current: "PT-BR"\nportuguese-current: true\nkeywords-label: "Palavras-chave"\ntoc-label: "Sumário"')
    return result


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    SOURCE.write_text(update_portuguese(source), encoding="utf-8", newline="\n")
    body = re.sub(r"\A---\n.*?\n---\n", "", source, count=1, flags=re.S)
    cache = load_cache()
    output: list[str] = []
    block: list[str] = []
    in_code = False
    in_math = False
    in_references = False
    in_ai = False

    def flush() -> None:
        nonlocal block
        if block:
            output.append(translate_block("\n".join(block), cache))
            block = []

    for line in body.splitlines():
        if line == "# Referências {#referencias}":
            flush(); output.append(FIXED_TRANSLATIONS[line]); in_references = True; continue
        if in_references and line.startswith('<section class="ai-declaration"'):
            output.append(AI_EN); in_ai = True; continue
        if in_ai:
            continue
        if in_references:
            output.append(line.replace(" e ", " and ") if line.startswith('<p id="ref-') else line)
            continue
        if line.startswith("```"):
            flush(); output.append(line); in_code = not in_code; continue
        if in_code:
            output.append(localize_code(line)); continue
        if line.strip() == "$$":
            flush(); output.append(line); in_math = not in_math; continue
        if in_math:
            output.append(line); continue
        if not line.strip():
            flush(); output.append(""); continue
        block.append(line)
    flush()
    save_cache(cache)
    english = ENGLISH_YAML + "\n".join(output).rstrip() + "\n"
    english = re.sub(
        r"\[([^\]]+)\]\((#ref-[^)]+)\)",
        lambda match: f"[{match.group(1).replace(' e ', ' and ')}]({match.group(2)})",
        english,
    )
    for old, new in {
        "[Figura ": "[Figure ", "[Tabela ": "[Table ",
        "### Concurrent Estimation": "### Joint Estimation",
        "Concurrent estimation": "Joint estimation",
        "simultaneous estimation": "joint estimation",
        "Simultaneous estimation": "Joint estimation",
        "accumulated characteristic curves": "cumulative characteristic curves",
        "accumulated probability": "cumulative probability",
        "latent trace": "latent trait",
    }.items():
        english = english.replace(old, new)
    TARGET.write_text(english, encoding="utf-8", newline="\n")
    print(json.dumps({"source": str(SOURCE), "target": str(TARGET), "translated_blocks": len(cache)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
