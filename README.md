# CRM Logistic Regression

Reproducible R study comparing two-stage and joint Bayesian estimation for logistic regression with latent traits measured by the Continuous Response Model (CRM).

## Technical report

The methodological report documents the CRM specification, logistic regression for a dichotomous distal outcome, item-parameter interpretation, the simulation design, model diagnostics, and numerical comparisons.

- [Read the technical report in English](https://ingodube.github.io/CRM-Logistic-Regression/metodologia.html).

## Repository structure

- `Spreadsheets (EN)/` and `Spreadsheets (PT-BR)/`: localized CSV and XLSX analytical tables.
- `report/`: the two R Markdown sources, shared figure, Pandoc template, CSS, and the protected PT-BR source PDF.
- `docs/`: self-contained HTML publication. `index.html` redirects access to the English report.
- `scripts/`: lightweight data preparation, rendering, report parity, preservation, and repository validation.
- `tools/`: deterministic localization tools for CSV files and the English report.
- `renv.lock`: pinned R package versions.

## Restore the environment

Install R 4.6.1 or a compatible release, then run:

```r
install.packages("renv")
renv::restore()
```

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
