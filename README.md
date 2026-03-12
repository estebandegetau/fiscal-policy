# Research Container Template

A reproducible research environment using Docker, R, Python, and modern data science tools.

## What This Template Provides

This template creates a fully reproducible research environment with:

| Component | Version | Purpose |
|-----------|---------|---------|
| **R** | 4.5 | Statistical computing and graphics |
| **Python** | 3.12 | General-purpose programming |
| **Quarto** | Latest | Scientific publishing |
| **TinyTeX** | Latest | PDF document generation |
| **Claude Code** | Latest | AI-assisted development |

### Pre-installed R Packages

- **tidyverse** - Data manipulation and visualization
- **targets** - Pipeline toolkit for reproducible workflows
- **tarchetypes** - Targets archetypes (Quarto integration, etc.)
- **here** - Project-relative file paths
- **renv** - Dependency management
- **quarto** - Quarto integration for R

### Pre-installed Python Packages

- **numpy** - Numerical computing
- **pandas** - Data manipulation
- **jupyter** - Interactive notebooks

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [VS Code](https://code.visualstudio.com/) with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### Quick Start

1. **Use this template** to create a new repository, or clone it directly:
   ```bash
   git clone https://github.com/YOUR_USERNAME/research-container-template.git my-project
   cd my-project
   ```

2. **Open in VS Code**:
   ```bash
   code .
   ```

3. **Reopen in Container**: When prompted, click "Reopen in Container" or run the command `Dev Containers: Reopen in Container` from the command palette (Ctrl+Shift+P / Cmd+Shift+P).

4. **Wait for the container to build**. The first build may take several minutes as it installs all dependencies.

5. **Start working!** The R environment is ready with all packages installed.

## Project Structure

```
├── .devcontainer/       # VS Code Dev Container configuration
│   └── devcontainer.json
├── .github/
│   └── workflows/       # GitHub Actions workflows
│       └── build-test.yml
├── R/                   # R function scripts (sourced by targets)
│   └── functions.R
├── data/                # Raw data files (gitignored by default)
├── output/              # Generated outputs (gitignored)
├── docs/                # Quarto documents
│   └── report.qmd
├── _targets/            # targets cache (gitignored)
├── _targets.R           # Pipeline definition
├── Dockerfile           # Container definition
├── renv/                # renv configuration (generated at build)
├── .Rprofile            # R startup configuration
└── README.md            # This file
```

## Customization Checklist

After creating your project from this template, update the following:

- [ ] **README.md**: Replace this content with your project description
- [ ] **Dockerfile**: Update the maintainer label with your information
- [ ] **_targets.R**: Define your analysis pipeline
- [ ] **R/functions.R**: Add your R functions
- [ ] **docs/report.qmd**: Write your research report
- [ ] **renv**: Run `renv::init()` then `renv::snapshot()` to track dependencies

## Using the targets Pipeline

The [targets](https://docs.ropensci.org/targets/) package manages your analysis pipeline:

```r
# View the pipeline
targets::tar_visnetwork()

# Run the pipeline
targets::tar_make()

# Load a target result
data <- targets::tar_read(target_name)

# Check pipeline status
targets::tar_outdated()
```

### Adding New Targets

1. Define functions in `R/` directory
2. Add targets to `_targets.R`
3. Run `targets::tar_make()`

## Managing R Packages with renv

Core packages (tidyverse, targets, etc.) are pre-installed in the container. To track your project's dependencies with renv:

```r
# Initialize renv for your project (first time only)
renv::init()

# Install a new package
install.packages("packagename")

# Update the lockfile after installing packages
renv::snapshot()

# Restore packages from lockfile (e.g., after pulling changes)
renv::restore()

# Check package status
renv::status()
```

**Workflow:**
1. Core packages are pre-installed at container build time
2. Run `renv::init()` when you want to start tracking dependencies
3. After installing new packages, run `renv::snapshot()` to update `renv.lock`
4. Commit `renv.lock` to version control for reproducibility

## Rendering Quarto Documents

```bash
# Render to HTML
quarto render docs/report.qmd --to html

# Render to PDF
quarto render docs/report.qmd --to pdf

# Render all documents
quarto render docs/
```

Or in R:
```r
quarto::quarto_render("docs/report.qmd")
```

## Using Claude Code

Claude Code is pre-installed in the container. To use it:

1. Set your API key as an environment variable (add to `.env` file, which is gitignored):
   ```
   ANTHROPIC_API_KEY=your-api-key-here
   ```

2. The devcontainer is configured to pass this key to the container.

3. Run Claude Code from the terminal:
   ```bash
   claude
   ```

## GitHub Actions

This template includes a GitHub Actions workflow that:

- Builds the Docker container on every push to `main` or when the Dockerfile changes
- Verifies the container builds successfully
- Tests that R and key packages load correctly

See `.github/workflows/build-test.yml` for details.

## Best Practices for Reproducibility

1. **Never edit data files manually** - All data transformations should be in code
2. **Use `here::here()` for file paths** - Ensures paths work across environments
3. **Commit `renv.lock`** - Captures exact package versions
4. **Document your pipeline** - Use comments in `_targets.R` and function documentation
5. **Use targets for long-running computations** - Avoids re-running unchanged steps
6. **Keep raw data immutable** - Store in `data/`, never modify

## Troubleshooting

### Container won't build

- Ensure Docker is running
- Try rebuilding without cache: `docker build --no-cache .`

### R packages won't install

- Core packages are pre-installed; just use `library()` to load them
- For new packages: `install.packages("pkg")` then `renv::snapshot()`
- Check system dependencies in Dockerfile if compilation fails
- Run `renv::status()` to diagnose renv issues

### Quarto PDF output fails

- Ensure TinyTeX is installed: `quarto install tinytex`
- Check for missing LaTeX packages in error output

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Citation

If you use this template, please cite:

```
[Add citation information for your project]
```
