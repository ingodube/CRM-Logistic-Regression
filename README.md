# CRM Logistic Regression

Reproducible R study comparing two-stage and joint Bayesian estimation for logistic regression with latent traits measured by the Continuous Response Model (CRM).

## Technical report

The methodological report documents the CRM specification, logistic regression for a dichotomous distal outcome, item-parameter interpretation, the simulation design, model diagnostics, and numerical comparisons.

- [Read the technical report in English](https://ingodube.github.io/CRM-Logistic-Regression/metodologia.html) — default and canonical version.
- [Read the technical report in Portuguese (PT-BR)](https://ingodube.github.io/CRM-Logistic-Regression/methodology-pt-br.html).

## Repository structure

- `Codes (EN)/` and `Codes (PT-BR)/`: localized analytical R programs and lightweight analysis helpers. The English programs are generated deterministically from the reviewed PT-BR programs without changing statistical expressions or numeric literals.
- `Spreadsheets (EN)/` and `Spreadsheets (PT-BR)/`: localized CSV and XLSX analytical tables.
- `Results (EN)/` and `Results (PT-BR)/`: localized text, figure, PDF, TeX, JSON, and NDJSON results.
- `Simulated Data/`: the single source-data tree. Its 19,000 files are preserved and must never be overwritten.
- `report/`: the two R Markdown sources, shared figure, Pandoc template, CSS, and the protected PT-BR source PDF.
- `docs/`: self-contained HTML publication. `index.html` redirects access to the English report.
- `scripts/`: preparation, rendering, parity, preservation, and reproducibility validators.
- `tools/`: deterministic localization tools for analytical code, CSV files, workbooks, and the English report.
- `renv.lock`: pinned R package versions.

## Restore the environment

Install R 4.6.1 or a compatible release and JAGS, then run:

```r
install.packages("renv")
renv::restore()
```

The archived `mcmcplots` 0.4.3 package is restored from the official CRAN archive recorded in `renv.lock`.

## Validate and render

Run the lightweight pipeline from the repository root:

```powershell
Rscript scripts/prepare_report_data.R
Rscript scripts/render_reports.R
Rscript scripts/validate_reports.R
Rscript scripts/compare_report_text.R
Rscript scripts/validate_reproducibility.R
Rscript -e "renv::status()"
git diff --check
```

These commands do not run the 1,000-replication simulation or the full MCMC estimation.

## Run one analytical scenario

Execute a complete localized program with `Rscript` or `source()`. For example:

```powershell
Rscript "Codes (EN)/IRT/Structural Regression/Logistic Regression/CRM - Normal (Wang and Zeng)/Classic/n = 100 p = 10/IRT Classic Logistic Regression n = 100 p = 10.R"
```

Do not execute isolated lines in the console because the program derives the repository root from its source-file path. Continue to build paths with `file.path()` relative to that root.

## Contribution convention

Use short, neutral, imperative commit messages in English, for example: `Publish edited report`.
