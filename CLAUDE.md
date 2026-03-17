# CLAUDE.md

This file is Claude's project-specific operating instructions. Read `COMPANION.md` for the permanent principles and full architecture. The sections below override or extend `COMPANION.md` for this project.

---

## Project Overview

**Title**: The Effects of Fiscal Policy in South East Asia
**Authors**: Esteban Degetau, Agustín Samano
**Affiliation**: World Bank

### Project Structure

- `R/` - R function definitions (sourced by targets)
- `data/` - Raw data files (not tracked in git)
- `output/` - Generated outputs (not tracked in git)
- `docs/` - Quarto documents for reports
- `_targets.R` - Pipeline definition
- `renv.lock` - R package dependencies (generated via `renv::init()` + `renv::snapshot()`)

### Research Problem

Governments frequently change tax and spending rules with little evidence of their effects on GDP, investment, and employment. Producing such evidence requires identifying the causal effect of fiscal shocks on these outcomes. Existing research (Romer & Romer 2010) has established methods for the US, but extending these to other countries — particularly South East Asia — has been limited by data availability and the difficulty of identifying exogenous fiscal shocks outside the US context.

### Our Solution

This project analyses the effects of exogenous fiscal shocks on macroeconomic and firm-level outcomes in South East Asia. It leverages a dataset of fiscal shock episodes produced by the authors in a complementary methodological paper (Degetau & Samano 2026), which uses LLMs to extend the Romer & Romer (2010) narrative identification approach to other countries. This project is the *applied* component: it takes the identified shocks as inputs and estimates their causal effects using local projections (Jordà 2005) and modern difference-in-differences methods.

### Key Innovation

Combining narratively identified fiscal shocks (produced via LLM-assisted methods in a companion paper) with firm-level micro data to estimate the causal effects of fiscal policy on investment and employment at the firm level in South East Asia.

### Research Contribution

- **Empirical**: First estimates of causal fiscal multiplier effects on firm-level investment and employment in South East Asia
- **Empirical**: Macro-level fiscal multiplier estimates for South East Asian countries using narratively identified shocks
- **Methodological**: Application of modern DiD methods to fiscal shock identification in a cross-country setting

### Measurement Instruments

<!-- Not yet specified — no LLM measurement instruments in this project. This is a purely analytical/econometric project. Instruments here refer to econometric estimation strategies (local projections, DiD) rather than LLM classification tasks. -->

### Validation Pipeline

<!-- Not yet specified — validation in this project means meeting econometric identification assumptions rather than LLM output validation stages. -->

### Success Criteria

- **Difference-in-differences**: Parallel pre-trends must hold (hard gate for causal interpretation)
- **Local projections**: Standard significance and robustness checks
<!-- Additional criteria TBA as instruments are specified -->

### Data and Scope

- **Primary data sources**:
  - Macro data: tax cut and hike episodes across South East Asian countries (translated from existing STATA analysis)
  - Micro data: firm-level investment and employment data (`data/firm_data.zip`)
  - Fiscal shocks: exogenous shock dataset from Degetau & Samano (2026) — used in Phase 3
- **Geographic scope**: South East Asia (with potential extension to other countries)
- **Temporal scope**: <!-- Not yet specified -->
- **Note**: There is no LLM training or evaluation in this project. All outputs are analytical (regressions, tables, figures).

### Strategic Framing

- **This project IS**: An applied econometrics project estimating causal effects of fiscal policy on macro and micro outcomes in South East Asia
- **This project IS NOT**: An LLM measurement or validation project — the LLM-based shock identification is done in a separate companion paper
- **This project IS NOT**: A replication of Romer & Romer (2010) — it uses their framework as extended by Degetau & Samano (2026) but estimates *effects*, not *shocks*

### Current Status

- **Phase 1** (Macro effects, all episodes): Not started — STATA code exists and needs translation to R
- **Phase 2** (Micro effects, all episodes): Not started
- **Phase 3** (Exogenous shocks, Degetau & Samano 2026): Not started

---

## Development Commands

### Pipeline

```r
# Run the pipeline
targets::tar_make()

# Visualize the pipeline
targets::tar_visnetwork()

# Check outdated targets
targets::tar_outdated()

# Read a target output
targets::tar_read(target)

# Initialize renv (first time only)
renv::init()

# Snapshot R packages after installing new ones
renv::snapshot()
```

### Documentation

```bash
# Render Quarto document
quarto render docs/report.qmd
```

---

## Technology Stack

### Languages and Packages

- **R 4.5** with tidyverse, targets, tarchetypes, here, renv, quarto, fixest (or equivalent for LP/DiD)
- **Quarto** for scientific publishing
- **targets** for reproducible pipelines
- **Claude Code** for AI-assisted development

### Valid Model IDs

Not applicable — this project does not make LLM API calls. Convention 3 is satisfied trivially.

### Data Sources

- Macro fiscal episode data (translated from STATA)
- Firm-level micro data: `data/firm_data.zip`
- Exogenous fiscal shocks: Degetau & Samano (2026) dataset (Phase 3)

---

## Coding Conventions

### R Code

- Use tidyverse style guide
- Use `here::here()` for all file paths
- Define functions in `R/` directory
- Core packages are pre-installed; use `renv::init()` then `renv::snapshot()` to track dependencies
- When translating from STATA: preserve variable names and logic, add comments noting the original STATA command where non-obvious

### Pipeline (targets)

- Define targets in `_targets.R`
- Keep functions in `R/` directory
- Use `tar_read()` and `tar_load()` to access results

### Quarto Documents

- Place in `docs/` directory
- Use `tar_read()` to load pipeline results
- Prefer HTML output for sharing, PDF for formal reports

---

## Phase Structure

- **Phase 1**: Macro effects using all tax cut/hike episodes. Translate existing STATA analysis into R. Local projections of fiscal episodes onto macro outcomes (GDP, investment, employment).
- **Phase 2**: Micro effects using all tax cut/hike episodes. Local projections and DiD estimation of fiscal episodes onto firm-level investment and employment using `data/firm_data.zip`.
- **Phase 3**: Repeat Phases 1–2 using only exogenous fiscal shocks identified by Degetau & Samano (2026). This is the core causal contribution.

---

## Research Companion Principles

The five principles governing Claude's role in this project. See `COMPANION.md` for full rationale.

1. **Human confers meaning.** Claude pattern-matches against instrument definitions but does not understand what the classification means for causal identification or external validity.
2. **Delegate instrumental, own the core.** Pipeline plumbing and documentation sync are fully delegable. Instrument design, success criteria, and error interpretation are human-owned.
3. **Credibility tracks involvement.** The human must have lived through the iteration history to defend decisions at peer review.
4. **Commits belong to humans.** Claude analyzes and proposes; the human decides and records the rationale.
5. **Error recoverability heuristic.** AI owns tasks where errors are recoverable. Humans own tasks where errors compound silently.

---

## Workflow Conventions

These 10 rules govern how Claude operates in this project. Verbatim from `COMPANION.md` — do not modify without updating both files.

1. **Plan-first mode.** When asked to diagnose, investigate, or propose, present findings and wait. Do NOT implement changes or run code unless explicitly told to.

2. **Root cause first.** When something fails, identify the root cause before proposing a fix. Do not patch symptoms.

3. **Model ID validation.** Not applicable — this project does not use LLM API calls.

4. **Prefer existing files.** Search with Glob/Grep before creating new files.

5. **No autonomous API calls.** Never run the pipeline on API-calling targets without explicit human approval. Read-only operations are always safe.

6. **Commit before pipeline runs.** Ensure no uncommitted changes to instrument files or pipeline functions before running.

7. **One change at a time.** Change one instrument component per iteration.

8. **Pipeline data validation.** After a pipeline run completes, verify result shape before proceeding.

9. **Quarto render safety.** Always render specific files, never the full project.

10. **Strategy reconciliation.** After stage gate crossings or when 3+ unresolved deltas accumulate in `docs/deltas.md`, run `/strategy-sync`.

---

## Claude Code Agents

<!-- Agents should be configured following the COMPANION.md taxonomy when needed. No project-specific agents configured yet. -->
