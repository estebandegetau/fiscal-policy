# _targets.R
# This file defines the targets pipeline for your research project.
# See https://books.ropensci.org/targets/ for documentation.

# Load packages required for the pipeline
library(targets)
library(tarchetypes)

# Source R functions
# tar_source() will source all .R files in R/
tar_source()

# Set target options
tar_option_set(
  packages = c("tidyverse", "here"),
  format = "rds",          # Default storage format
  memory = "transient",    # Free memory after target runs
  garbage_collection = TRUE
)

# Define the pipeline
list(
  # Example: Load raw data
  # tar_target(
  #   raw_data,
  #   read_csv(here("data", "raw_data.csv"))
  # ),

 # Example: Clean data
  # tar_target(
  #   clean_data,
  #   clean_raw_data(raw_data)  # Function defined in R/
  # ),

  # Example: Fit model
  # tar_target(
  #   model,
  #   fit_model(clean_data)
  # ),

  # Example: Render Quarto report
  # tar_quarto(
  #   report,
  #   path = here("docs", "report.qmd")
  # ),

  # Placeholder target - replace with your pipeline
  tar_target(
    example_target,
    "Replace this with your actual pipeline targets"
  )
)
