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
  tar_target(did_summaries, extract_did_summaries(did_models)),
  tar_quarto(
    did_notebook,
    "notebooks/did.qmd",
    cache = FALSE
    ),

  # Firm-level local projections (LP on orbis_merged, continuous treatment)
  # Memory-efficient: run regressions and extract results in one pass
  tar_target(lp_firm_data, prepare_lp_firm_data(orbis_merged)),
  tar_target(lp_firm_results, run_all_lp_firm_results(lp_firm_data)),
  tar_target(lp_firm_cumulative, lp_firm_results$cumulative),
  tar_target(lp_firm_plots, plot_all_lp_firm_irfs(lp_firm_cumulative)),
  tar_target(lp_firm_output, save_all_lp_firm_outputs(lp_firm_cumulative, lp_firm_plots)),
  tar_quarto(
    lp_firms,
    "notebooks/lp_firms.qmd",
    cache = FALSE
  ),

  # Malaysia tax-incentive shocks (Degetau & Samano 2026), fetched from the web.
  # format = "url" re-downloads whenever the remote file changes.
  tar_target(incentive_shocks_file, incentive_shocks_url(), format = "url"),
  tar_target(incentive_shocks, read_incentive_shocks(incentive_shocks_file)),
  # Statutory tax shocks (CIT, PIT, consumption) with exogeneity classification
  tar_target(tax_shocks_file, tax_shocks_url(), format = "url"),
  tar_target(tax_shocks, read_tax_shocks(tax_shocks_file)),
  tar_quarto(
    tax_incentives,
    "notebooks/tax_incentives.qmd",
    cache = FALSE
  ),

  # Milestone 1 (Malaysia): firm-level data suitability
  tar_target(my_osiris, read_osiris_my(orbis_file), format = "feather"),
  tar_target(my_osiris_clean, clean_osiris_my(my_osiris), format = "feather"),
  tar_target(
    my_census_dir,
    here::here("data/firm_data/my"),
    format = "file"
  ),
  tar_target(my_census, read_census_my(my_census_dir), format = "feather"),
  tar_target(
    my_census30,
    read_census30_my(file.path(my_census_dir, "30% Economic Census Data")),
    format = "feather"
  ),
  tar_target(my_wdi_gfcf, fetch_wdi_gfcf_my()),

  # Milestone 1 suitability tests (R/ms1_diagnostics.R)
  tar_target(ms1_integrity_osiris, test_integrity_osiris(my_osiris, my_osiris_clean)),
  tar_target(ms1_census_linkage, test_census_linkage(my_census)),
  tar_target(ms1_integrity_census30, test_integrity_census30(my_census30)),
  tar_target(
    ms1_representativeness,
    test_representativeness(my_osiris_clean, my_census, my_wdi_gfcf)
  ),
  tar_target(ms1_state_distribution, test_state_distribution(my_census, my_census30)),
  tar_target(ms1_coverage, test_coverage(my_osiris_clean, my_census)),
  tar_target(ms1_investment_rate, test_investment_rate(my_osiris_clean, my_census)),
  tar_target(ms1_etr, test_etr(my_osiris_clean)),
  tar_target(ms1_feasibility, build_feasibility_matrix(incentive_shocks, tax_shocks)),
  tar_target(ms1_event_means, test_event_means(my_osiris_clean, my_census)),
  tar_target(ms1_mde, test_mde(my_osiris_clean, my_census)),
  tar_quarto(
    ms1_report,
    "docs/ms1_data_suitability.qmd",
    cache = FALSE
  )
)
