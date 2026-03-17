---
name: quarto-style
description: Style guide for writing and editing Quarto (.qmd) documents in this project. Apply when creating or modifying any .qmd file.
user-invocable: false
---

## Project Adaptation Required

Before using this skill, configure the following project-specific items:

- **`R/gt_theme.R`**: If your project does not use a custom gt theme, remove or comment out the `source(here("R/gt_theme.R"))` and `set_theme(theme_minimal())` lines in the setup chunk. Replace `%>% gt_theme_report()` with `%>% opt_stylize()` or remove it.
- **Writing tone audience**: Replace the `<!-- ADAPT: your audience -->` placeholder in the Writing Style section with your target reader (e.g., "development economist", "public health researcher", "policy analyst unfamiliar with machine learning").
- **Config inheritance paths**: Adapt the inheritance chain to your directory structure. If you don't use `docs/`, `notebooks/`, and `reports/` directories, update accordingly.

---

# Quarto Style Guide

This skill defines conventions for all `.qmd` files in the project. Apply these rules when creating or editing Quarto documents.

## Configuration Inheritance

Settings cascade from project-level down. **Do not repeat inherited settings** in individual `.qmd` files.

### Inheritance chain

```
_quarto.yml              (project-wide defaults)
  ├── docs/_metadata.yml   (docs/ directory defaults)
  ├── notebooks/_metadata.yml  (notebooks/ directory defaults)
  └── reports/_metadata.yml    (reports/ directory defaults)
        └── individual.qmd   (only document-specific overrides)
```

### Before writing a `.qmd` file

**Read the relevant config files** to know what's already inherited:

1. **Always read** `_quarto.yml` for project-wide defaults (citations, execute, layout options)
2. **Read the directory's** `_metadata.yml` (e.g., `reports/_metadata.yml`) for format and execute defaults
3. **Do not repeat** any setting that is already defined at a higher level

### What individual `.qmd` files should specify

Only settings **unique to that document**:

```yaml
---
title: "Document Title"
subtitle: "Optional Subtitle"
date: today              # or explicit date; author's choice
date-format: long        # always include this
---
```

Override directory defaults only when necessary (e.g., `number-sections: true` for a proposal).


## Setup Chunk

Include the targets setup block **only when the document reads pipeline data**:

```r
#| label: setup
#| cache: false

library(targets)
library(tidyverse)
library(gt)
library(here)

here::i_am("path/to/this-document.qmd")
tar_config_set(store = here("_targets"))
# source(here("R/gt_theme.R"))   # ADAPT: uncomment if using a custom gt theme
# set_theme(theme_minimal())

# Load data
data <- tar_read(target_name)
```

Documents that don't use pipeline data (e.g., pure prose proposals) skip this entirely.

## Tables

**Always use `gt` for tables.** Never use `kableExtra` (incompatible with Typst) or markdown tables.

### Project theme

If using a custom gt theme, all tables must end with `%>% gt_theme_report()`. Otherwise, use `%>% opt_stylize()` or another gt finishing function. This applies consistent formatting across all tables.

Required pattern:

```r
#| label: tbl-descriptive-name
#| tbl-cap: "Human-readable table caption"

data %>%
  gt() %>%
  cols_label(col1 = "Readable Name") %>%
  gt_theme_report()   # ADAPT: replace with your theme function if different
```

### Rules

- Always use Quarto chunk options `label: tbl-{ref}` and `tbl-cap:` for table titles and cross-referencing
- Reference tables in text with `@tbl-{ref}` (e.g., `@tbl-descriptive-name`)
- Do **not** use `tab_header()` for the main title; use `tbl-cap:` instead so Quarto handles numbering and cross-references
- Always pipe the theme function as the **last** step in the gt chain
- Let tables take their natural width; do not force `table.width = pct(100)`
- Use `tab_footnote()` for methodological notes
- Use `tab_style()` for conditional formatting when it aids interpretation
- Use `fmt_percent()`, `fmt_number()`, etc. for consistent number formatting
- Tables in Typst output will not break across pages (`reports/_metadata.yml` handles this)

## Plots

Set the global theme once in the setup chunk via `set_theme(theme_minimal())`. Individual plots should **not** add `+ theme_minimal()`.

```r
#| label: fig-descriptive-name
#| fig-cap: "Human-readable figure caption"

ggplot(data, aes(x, y)) +
  geom_*() +
  labs(
    x = "X Axis Label",
    y = "Y Axis Label"
  )
```

- Always use Quarto chunk options `label: fig-{ref}` and `fig-cap:` for figure titles and cross-referencing
- Reference figures in text with `@fig-{ref}` (e.g., `@fig-descriptive-name`)
- Do **not** put the main title in `labs(title = ...)`; use `fig-cap:` instead so Quarto handles numbering and cross-references
- Always provide axis labels via `labs()`
- `theme_minimal()` is set globally in setup; do not repeat per plot
- Use `scales::comma`, `scales::percent`, `scales::dollar_format()` for axis formatting

## Markdown Formatting

### Blank lines before block elements (CRITICAL)

A blank line is **required** before bullet lists, numbered lists, block quotes, and code blocks. This applies in both markdown body text and `cat()` output in R chunks.

```markdown
<!-- WRONG -->
**Some text:**
- Bullet 1
- Bullet 2

<!-- CORRECT -->
**Some text:**

- Bullet 1
- Bullet 2
```

In R code chunks with `results='asis'`:

```r
# WRONG
cat("Some text:\n")
cat("- Bullet 1\n")

# CORRECT
cat("Some text:\n\n")
cat("- Bullet 1\n")
```

### Horizontal rules

**NEVER end a section or document with a `---` divider.** Horizontal rules should only appear *between* two sections of content, never trailing after the last paragraph of a section. When in doubt, omit the rule entirely. Prefer using headings (`##`, `###`) to separate content rather than horizontal rules.

### Callout boxes

Use Quarto callout boxes for important notes, warnings, or tips:

```markdown
::: {.callout-note}
Important context the reader should know.
:::

::: {.callout-warning}
A caveat or limitation.
:::
```

### Cross-references

Use Quarto cross-reference syntax for figures, tables, and sections when the document is long enough to benefit from it.

- Figures: `label: fig-{ref}` + `fig-cap:` in chunk options, reference with `@fig-{ref}`
- Tables: `label: tbl-{ref}` + `tbl-cap:` in chunk options, reference with `@tbl-{ref}`
- Sections: `{#sec-label}` on heading, reference with `@sec-label`

## Citations

- Use `@key` syntax for in-text citations
- Use `[@key]` for parenthetical citations
- All references go in `references.bib` at the project root
- Citation style and bibliography are configured in `_quarto.yml`; do not override in individual files
- End documents that use citations with:

```markdown
## References {.unnumbered}

::: {#refs}
:::
```

## Writing Style

### Tone

- **Active voice** preferred over passive
- **Concise and direct.** Say what happened and what it means
- Write for <!-- ADAPT: your audience --> who may not be a machine learning specialist
- Explain technical LLM concepts; assume domain knowledge in your field

### Emphasis

- **Bold** for key terms, findings, and important numbers on first use
- *Italics* for emphasis within sentences and for terms being defined
- Do not overuse either; if everything is bold, nothing stands out

### Dashes

Minimize use of em dashes. Prefer shorter sentences, colons, or parentheses instead.

```markdown
<!-- Avoid -->
The model achieved 92% accuracy --- exceeding the target --- on the test set.

<!-- Prefer -->
The model achieved 92% accuracy, exceeding the target, on the test set.
The model achieved 92% accuracy (exceeding the target) on the test set.
```

### Numbers and metrics

- Report percentages with one decimal: `92.3%`, not `92.307%`
- Always include the target alongside the result: "92.3% accuracy (target: >85%)"
- Use `scales::comma()` for large numbers in R output

### Structure

- **No mandatory section template.** Structure follows the document's purpose
- When a summary/overview section is included, place it first
- End with References section (if citations used) and optionally a Technical Appendix

## Code Chunks

### Execute options

Default execute options are set in `_metadata.yml` per directory (read it first). Override in individual chunks only when needed:

```r
#| echo: true       # Show this specific chunk in a report
#| cache: true       # Cache expensive computation
#| fig-width: 8      # Control figure size
#| fig-height: 5
```

### Dynamic markdown

When generating markdown from R, use `results: 'asis'` and `cat()`:

```r
#| results: 'asis'

cat(sprintf("**Result:** %.1f%% accuracy\n\n", value * 100))

# Remember blank line before bullets
cat("**Key findings:**\n\n")
cat("- Finding 1\n")
cat("- Finding 2\n")
```

### Chunk labels

Use Quarto's `fig-` and `tbl-` prefixes so cross-references work automatically:

```r
#| label: fig-magnitude-distribution
#| fig-cap: "Distribution of instrument outputs"

#| label: tbl-instrument-performance
#| tbl-cap: "Instrument performance across all stages"
```

Labels must be descriptive kebab-case with the appropriate prefix (`fig-` or `tbl-`). Chunks that produce neither a figure nor a table use plain kebab-case labels (e.g., `label: setup`, `label: load-data`).
