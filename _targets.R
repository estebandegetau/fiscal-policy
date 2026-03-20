# _targets.R
# This file defines the targets pipeline for your research project.
# See https://books.ropensci.org/targets/ for documentation.

# Load packages required for the pipeline
pacman::p_load(targets, tarchetypes)

# Source R functions
# tar_source() will source all .R files in R/
tar_source()

# Set target options
tar_option_set(
  packages = c(
    "tidyverse",
    "here",
    "haven",
    "labelled",
    "arrow",
    "rvest"
    ),
  format = "rds",          # Default storage format
  memory = "transient",    # Free memory after target runs
  garbage_collection = TRUE
)

# Define the pipeline
list(
  tar_target(
    orbis_file,
    here::here("data/firm_data/BvD_firmdata.dta"),
    format = "file"
  ),
  tar_target(
    orbis_raw,
    haven::read_dta(orbis_file),
    format = "feather"
  ),
  tar_target(
    macro_data_file,
    here::here("data/Full_sample_filtered.dta"),
    format = "file"
  ),
  tar_target(
    macro_data,
    haven::read_dta(macro_data_file)
  ),
  tar_target(
    country_codes,
    scrape_country_codes()
  ),
  tar_target(
    orbis_clean,
    clean_orbis_data(orbis_raw, country_codes),
    format = "feather"
  ),
  tar_quarto(
    explore_orbis,
    here::here("notebooks/explore_orbis.qmd"),
    cache = F
  ),
  tar_target(
    orbis_merged, # Balanced panel
    merge_orbis_data(orbis_clean, macro_data),
    format = "feather"
  )
)
