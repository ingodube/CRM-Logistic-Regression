---
name: audit-r-paths
description: Audit and correct R file and directory paths while preserving source data and statistical logic. Use for absolute paths, setwd calls, manual separators, machine-dependent outputs, missing directories, or bilingual path reproducibility.
---

# Audit R Paths

1. Read `AGENTS.md` and `README.md` before changing the project.
2. Inventory R files with `rg --files -g '*.R'`.
3. Search for absolute paths, `setwd()`, `getwd()`, `file.path()`, and `dir.create()`.
4. Never run simulations or full MCMC estimation during a path audit.
5. Derive the repository root from the executing file and construct paths with `file.path()`.
6. EN report code may read only `Spreadsheets (EN)/`; PT-BR report code may read only `Spreadsheets (PT-BR)/`.
7. Create generated output directories with `dir.create(..., recursive = TRUE, showWarnings = FALSE)` before writing.
8. Never store personal drive letters, home-relative paths, or machine-specific directories.
9. Run `Rscript scripts/validate_reproducibility.R` before concluding.

Execute complete support files with `Rscript` so the repository root can be derived reliably. Keep report dependencies in `renv.lock`.
