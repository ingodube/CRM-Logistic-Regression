---
name: produce-technical-report
description: Produce, revise, render, validate, and publish the bilingual R Markdown methodological report in this repository. Use for report content, CSS, template, figures, tables, cross-references, published HTML, localization parity, or GitHub Pages changes.
---

# Produce the Technical Report

## Required workflow

1. Read `AGENTS.md`, `README.md`, both sources in `report/`, the Pandoc template, CSS, and report validators before editing.
2. Edit the R Markdown sources; never edit only the rendered HTML.
3. Treat `technical_report_pt_br.Rmd` and `Technical Report Source (PT-BR).pdf` as the protected Portuguese source pair. Only the authorized AI declaration and operational path references may differ after normalization.
4. Keep English as the default at `docs/metodologia.html`, PT-BR at `docs/methodology-pt-br.html`, and redirect `docs/index.html` to English.
5. Preserve `Simulated Data/`, saved replication matrices, formulas, citations, semantic IDs, and all analytical values.
6. Keep complete simulation and estimation chunks visible but disabled by default with `eval=FALSE`. Execute only lightweight tables and figures from saved results.
7. Keep the language dropdown, `lang`, canonical URLs, `hreflang`, `aria-current`, keyboard focus, and responsive behavior valid in both pages.
8. Run, from the repository root:

```powershell
Rscript scripts/prepare_report_data.R
Rscript scripts/render_reports.R
Rscript scripts/validate_reports.R
Rscript scripts/compare_report_text.R
Rscript scripts/validate_reproducibility.R
Rscript -e "renv::status()"
git diff --check
```

9. Do not run the 1,000-replication simulation or full MCMC estimation.
10. After publication, require successful workflows and HTTP 200 for both public report URLs.

## Editorial rules

- Use American English in the EN source and Brazilian Portuguese in the PT-BR source.
- Put figure and table titles above their elements.
- Keep the white reading surface, dark outer background, orange accent, 46-rem reading width, collapsible contents, and responsive layout.
- Keep display equations centered without individual scrollbars.
- Keep references justified with the final line aligned left.
- State that AI supported code structure, consistency review, formatting, rendering automation, and English translation; retain human responsibility for all scientific content.

## Localization parity

- The two report sources must share citations, references, semantic IDs, equations, chunk IDs, figures, tables, links, and numeric values.
- Translate displayed code identifiers, messages, labels, and paths without changing package APIs, statistical expressions, or required input literals.
- Rebuild localized artifacts deterministically and retain their parity checks.
