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
    "rvest",
    "fixest",
    "did"
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
  # tar_quarto(
  #   explore_orbis,
  #   "notebooks/explore_orbis.qmd",
  #   cache = F
  # ),
  tar_target(
    orbis_merged, # Balanced panel
    merge_orbis_data(orbis_clean, macro_data),
    format = "feather"
  ),

  # Phase 1: Macro local projections (translated from stata/Charts_October_1_2025_.do)
  tar_target(lp_data, prepare_lp_data(macro_data)),
  tar_target(lp_models, run_all_lp_blocks(lp_data)),
  tar_target(lp_cumulative, compute_all_cumulative_effects(lp_models)),
  tar_target(lp_plots, plot_all_irfs(lp_cumulative)),
  tar_target(lp_output, save_all_lp_outputs(lp_cumulative, lp_plots)),
  # tar_quarto(
  #   local_projections,
  #   here::here("notebooks/local_projections.qmd"),
  #   cache = F
  # )

  # Phase 2: Micro DiD (firm-level effects of tax changes)
  tar_target(did_data_cit, prepare_did_data(orbis_merged, "cit")),
  tar_target(did_data_pit, prepare_did_data(orbis_merged, "pit")),
  tar_target(did_models, run_all_did_blocks(list(cit = did_data_cit, pit = did_data_pit))),
  tar_target(did_results, aggregate_all_did_results(did_models)),
  tar_target(did_plots, plot_all_did_event_studies(did_results))
)
