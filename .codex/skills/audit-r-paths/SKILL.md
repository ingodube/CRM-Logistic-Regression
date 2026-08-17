---
name: audit-r-paths
description: Audit and correct R file and directory paths while preserving source data and statistical logic. Use for absolute paths, setwd calls, manual separators, machine-dependent outputs, missing directories, or bilingual path reproducibility.
---

# Audit R Paths

1. Read `AGENTS.md` and `README.md` before changing the project.
2. Inventory R files with `rg --files -g '*.R'`.
3. Search for absolute paths, `setwd()`, `getwd()`, `file.path()`, and `dir.create()`.
4. Treat `Simulated Data/` as immutable input and never run simulations during a path audit.
5. Derive the repository root from the executing file and construct paths with `file.path()`.
6. EN code must read `Simulated Data/` and write only to `Results (EN)/` or `Spreadsheets (EN)/`; PT-BR code must write to its corresponding localized trees.
7. Create output directories with `dir.create(..., recursive = TRUE, showWarnings = FALSE)` before writing.
8. Never store personal drive letters, home-relative paths, or machine-specific directories.
9. Run `Rscript scripts/validate_reproducibility.R` before concluding.

Execute complete files with `Rscript` or `source()` so the repository root can be derived reliably. Keep dependencies in `renv.lock` and validate JAGS separately.
