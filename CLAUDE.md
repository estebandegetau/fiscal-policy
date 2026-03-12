# Claude Code Project Configuration

This is a reproducible research project using R, Python, and Quarto.

## Project Structure

- `R/` - R function definitions (sourced by targets)
- `data/` - Raw data files (not tracked in git)
- `output/` - Generated outputs (not tracked in git)
- `docs/` - Quarto documents for reports
- `_targets.R` - Pipeline definition
- `renv.lock` - R package dependencies (generated via `renv::init()` + `renv::snapshot()`)

## Key Technologies

- **R 4.5** with tidyverse, targets, tarchetypes, here, renv, quarto
- **Python 3.12** with numpy, pandas, jupyter
- **Quarto** for scientific publishing
- **targets** for reproducible pipelines
- **Claude Code** for AI-assisted development

## Coding Conventions

### R Code
- Use tidyverse style guide
- Use `here::here()` for all file paths
- Define functions in `R/` directory
- Core packages are pre-installed; use `renv::init()` then `renv::snapshot()` to track dependencies

### Pipeline (targets)
- Define targets in `_targets.R`
- Keep functions in `R/` directory
- Use `tar_read()` and `tar_load()` to access results

### Quarto Documents
- Place in `docs/` directory
- Use `tar_read()` to load pipeline results
- Prefer HTML output for sharing, PDF for formal reports

## Common Commands

```r
# Run the pipeline
targets::tar_make()

# Visualize the pipeline
targets::tar_visnetwork()

# Check outdated targets
targets::tar_outdated()

# Initialize renv (first time only)
renv::init()

# Snapshot R packages after installing new ones
renv::snapshot()
```

```bash
# Render Quarto document
quarto render docs/report.qmd
```
