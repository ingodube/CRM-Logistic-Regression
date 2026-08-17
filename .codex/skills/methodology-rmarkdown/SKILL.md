---
name: methodology-rmarkdown
description: Format, revise, render, and validate publication-ready methodological reports written in R Markdown, including bilingual scientific reports with equations, cross-references, figures, tables, and preserved analytical parity.
---

# Methodology R Markdown

## Core workflow

1. Inspect both `.Rmd` sources, generated output, README links, publishing workflow, template, CSS, and validators.
2. Preserve the computational workflow and all statistical values unless the user explicitly requests an analytical change.
3. Edit source documents and render both localized outputs.
4. Validate visible text, figures, tables, equations, internal links, citations, semantic IDs, and language metadata.
5. For bilingual reports, keep a reviewed source per language and avoid browser-time translation.

## Formatting

- Use justified body prose, centered figure/table titles, centered display equations, and restrained institutional styling.
- Constrain the reading width, retain responsive behavior, and avoid horizontal overflow on mobile.
- Put visible construction code before the associated figure, then the title, figure, source, and interpretation.
- Use inline mathematics for variables and code formatting for exact function, object, and file names.
- Keep references internally linked and consistently formatted.

## Validation

- Render every localized source successfully.
- Confirm self-contained HTML and no external presentation dependency.
- Check duplicate IDs, broken fragments, language switching, focus, keyboard use, and mobile layout.
- Compare equations, citations, figures, tables, links, and numeric values between languages.
- Verify protected-source text against its reference artifact after normalization.
- Publish only after local validators, environment status, and repository diff checks pass.
