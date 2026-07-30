---
name: methodology-rmarkdown
description: Format, revise, render, validate, and publish methodological reports written in R Markdown or similar R-based reporting files. Use when Codex edits technical methodology documents, epidemiological/statistical reports, survey-method reports, or R Markdown reports that need consistent structure, justified prose, mathematical notation, figure captions, numbered references, and publication-ready output.
---

# Methodology R Markdown

## Core Workflow

1. Inspect the existing `.Rmd`, generated output, README/linking files, and repo publishing setup before editing.
2. Preserve the document's computational workflow unless the user explicitly asks to change the analysis.
3. Edit the source `.Rmd`; never edit only the rendered report.
4. Render the report after edits and validate the rendered text, figures, links, and references.
5. If the report is public, verify the public URL after commit and push.

## Report Structure

- Use a precise technical title that states the method, data source, software, and case study when applicable.
- Make the first chapter `Introdução` for Portuguese reports unless the user requests another language.
- Write the introduction as technical report prose:
  - define the study object and why it matters;
  - explain the role of indicators or methods;
  - state the data source and analytic objective;
  - avoid operational rendering details such as local CSV/XLSX loading, plotting internals, or artifact paths.
- Keep operational details in methods, reproducibility, or limitations sections.

## Formatting Rules

- Justify body paragraphs with CSS such as `body p { text-align: justify; }`.
- Keep references left-aligned even when body text is justified.
- Center figure titles and display equations.
- For methodological reports, prefer a restrained institutional aesthetic:
  - use a light neutral page background and a white reading surface;
  - use one primary blue or institutional accent color for headings, links, table headers, and callout borders;
  - keep the maximum reading width constrained so long paragraphs remain readable.
- Add a concise opening block when the report is public-facing:
  - include report type, title, subtitle, authors, date, repository link, and short chips for data source, method, and topic;
  - avoid marketing language or dashboard-style decoration.
- Use reusable callout boxes for high-value reading anchors such as methodological objective, estimator, statistical caution, and applied interpretation.
- Style tables consistently with light borders, subtle header backgrounds, readable spacing, and left-aligned captions.
- Put figure titles above plots as document text, not inside `ggplot`:
  - `Figura N: descrição do gráfico`
  - use a class such as `.figure-title`;
  - remove `title =` from `labs()` and remove `plot.title` styling from plot themes.
- Apply one common plotting theme across the report:
  - keep the existing geoms and data transformations unchanged unless the user asks for analytic changes;
  - use softer grid lines, legible axis labels, top legends, adequate plot margins, and a consistent visual separator or emphasis for national totals such as `Brasil` when present.
- Use inline math for mathematical concepts in prose:
  - write `$w_i$`, `$y_i$`, `$x_i$`, `$\hat{p}$`, `$IC_{95\%}$`, `$taxa_{100k}$`;
  - keep function names, column names, and file identifiers in backticks.
- Use display equations for estimators and central formulas.

## Language Rules

- Avoid referring to code as "script" in visible prose.
- Prefer "código", "códigos", "arquivo R", "rotina analítica", "método implementado", or indirect phrasing.
- Keep exact file names only when useful for reader orientation.
- Do not describe the work as "HTML"; call it "relatório", "trabalho", or "documento".

## References

- Use numbered references (`[1]`, `[2]`) when the surrounding work uses numeric citation style.
- Cite methodological choices where they matter, not only at the end.
- For survey proportion intervals:
  - cite Brown, Cai, and DasGupta for limitations of Wald intervals for binomial proportions;
  - cite Korn and Graubard for confidence intervals for proportions in complex survey data;
  - cite software documentation only as implementation support, not as the sole statistical justification.
- Keep the reference list consistent with the citation order or established numbering in the document.

## Validation Checklist

- Render the `.Rmd` successfully with the repo's known Pandoc/R setup.
- Extract visible text from the rendered report and check:
  - new title and first chapter;
  - no forbidden operational introduction text;
  - no visible "script"/"scripts" except unavoidable file names if accepted;
  - mathematical variables are inline math, not backticked code;
  - figure captions exist above all plots;
  - no plot titles are generated inside `ggplot`;
  - required references are present;
  - public links work.
- Commit and push only after the rendered output and source are both updated.
