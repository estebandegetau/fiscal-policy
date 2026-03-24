# R/did.R
# Phase 2: Difference-in-Differences estimation of firm-level effects
# of tax changes using the did package (Callaway & Sant'Anna 2021).
#
# Design: absorbing binary treatment — once a country cuts taxes, it stays
# treated forever. The did package handles staggered adoption, provides
# group-time ATTs, event-study aggregation, and built-in pre-trend tests.


#' Treatment definitions for DiD
#' @return Named list of treatment specs
did_treatments <- function() {
  list(
    cit = list(change_var = "change_corporate_tr"),
    pit = list(change_var = "change_individual_tr")
  )
}

#' Outcome definitions for DiD (firm-level)
#' @return Named list of outcome specs (var = base name, log version used in estimation)
did_outcomes <- function() {
  list(
    investments = list(var = "investments", label = "log(Investment)"),
    employees   = list(var = "employees",   label = "log(Employment)")
  )
}


#' Prepare firm-level panel data for did::att_gt()
#'
#' Constructs absorbing binary treatment from continuous tax change variables.
#' A tax cut event occurs when the change variable is negative (tax rate decreased).
#' Crisis years (2008-09, 2020-22) and banking/currency/debt crises are excluded
#' from treatment identification (forced to non-event).
#'
#' The panel is restricted to 2006-2017 (the window with best firm coverage)
#' and balanced: only firms with non-missing data in all 12 years are kept.
#' This avoids the did package's internal unbalanced-panel code path which
#' triggers a segfault in fastglm::colMax_dense.
#'
#' @param orbis_merged Firm x country x year panel with macro variables joined
#' @param treatment_key Character: "cit" or "pit"
#' @return Tibble ready for did::att_gt()
prepare_did_data <- function(orbis_merged, treatment_key) {
  tx <- did_treatments()[[treatment_key]]
  outcome_vars <- purrr::map_chr(did_outcomes(), "var")

  # Select only needed columns early to reduce memory (~1.4 GB -> ~40 MB)
  keep_cols <- c("ccode", "year", "firm_id", tx$change_var,
                 "banking_crisis", "currency_crisis", "debt_crisis",
                 outcome_vars)
  df_slim <- orbis_merged |>
    select(all_of(keep_cols))

  # Build country-level treatment timeline
  country_events <- df_slim |>
    distinct(ccode, year, .keep_all = TRUE) |>
    mutate(
      # Tax cut event: negative change means rate decreased (NA -> 0)
      tax_cut_event = as.integer(
        coalesce(.data[[tx$change_var]], 0) < 0
      ),
      # Crisis exclusion: force to 0 in crisis periods
      tax_cut_event = if_else(
        year %in% c(2008, 2009, 2020, 2021, 2022) |
          coalesce(banking_crisis, 0) == 1 |
          coalesce(currency_crisis, 0) == 1 |
          coalesce(debt_crisis, 0) == 1,
        0L, tax_cut_event
      )
    ) |>
    group_by(ccode) |>
    summarise(
      # 0 = never treated (did package convention); numeric for Inf compatibility
      first_treated_year = {
        event_years <- year[!is.na(tax_cut_event) & tax_cut_event == 1]
        if (length(event_years) == 0) 0 else min(event_years)
      },
      .groups = "drop"
    )

  # Panel window: 2006-2017 (best coverage in Orbis data)
  year_min <- 2006L
  year_max <- 2017L
  n_years  <- year_max - year_min + 1L

  # Join treatment, restrict window, log-transform outcomes, balance panel
  df <- df_slim |>
    filter(!is.na(firm_id), year >= year_min, year <= year_max) |>
    left_join(country_events, by = "ccode") |>
    mutate(
      treated = as.integer(
        first_treated_year > 0 & year >= first_treated_year
      ),
      # Log-transform firm outcomes (positive values only)
      log_investments = if_else(investments > 0, log(investments), NA_real_),
      log_employees   = if_else(employees > 0,   log(employees),   NA_real_)
    ) |>
    select(ccode, year, firm_id,
           first_treated_year, treated,
           investments, employees, log_investments, log_employees)

  # Balance panel: keep only firms observed in all years of the window
  # (did::att_gt with panel=TRUE requires balanced data)
  balanced_firms <- df |>
    group_by(firm_id) |>
    filter(n() == n_years) |>
    ungroup()

  # Re-encode firm_id_num after filtering
  balanced_firms <- balanced_firms |>
    mutate(firm_id_num = as.integer(factor(firm_id)))

  balanced_firms
}


#' Run did::att_gt() for one treatment x outcome combination
#'
#' Uses log-transformed outcomes (log_investments, log_employees) for
#' better-behaved estimation. Filters to firms with non-missing outcome
#' across all panel years before estimating.
#'
#' @param did_data Tibble from prepare_did_data()
#' @param outcome_var Character: base outcome name ("investments" or "employees")
#' @return att_gt object from the did package
run_did_estimation <- function(did_data, outcome_var) {
  log_var <- paste0("log_", outcome_var)

  # Keep only firms with non-missing log outcome in every year
  n_years <- n_distinct(did_data$year)
  complete_firms <- did_data |>
    filter(!is.na(.data[[log_var]])) |>
    count(firm_id) |>
    filter(n == n_years) |>
    pull(firm_id)

  est_data <- did_data |>
    filter(firm_id %in% complete_firms) |>
    mutate(firm_id_num = as.integer(factor(firm_id)))

  did::att_gt(
    yname  = log_var,
    tname  = "year",
    idname = "firm_id_num",
    gname  = "first_treated_year",
    xformla = ~1,
    control_group = "notyettreated",
    base_period = "universal",
    panel = TRUE,
    data = est_data
  )
}


#' Aggregate group-time ATTs into event-study and overall ATT
#'
#' @param att_gt_obj Object from run_did_estimation()
#' @return List with elements: event_study (aggte object), overall (aggte object)
aggregate_did_results <- function(att_gt_obj) {
  list(
    event_study = did::aggte(att_gt_obj, type = "dynamic"),
    overall     = did::aggte(att_gt_obj, type = "simple")
  )
}


#' Plot event-study coefficients from DiD aggregation
#'
#' @param aggte_obj aggte object from aggregate_did_results()$event_study
#' @param title Character: plot title
#' @return ggplot object
plot_did_event_study <- function(aggte_obj, title = "") {
  es <- data.frame(
    e     = aggte_obj$egt,
    att   = aggte_obj$att.egt,
    se    = aggte_obj$se.egt
  ) |>
    mutate(
      lower = att - 1.96 * se,
      upper = att + 1.96 * se
    )

  ggplot(es, aes(x = e, y = att)) +
    geom_ribbon(aes(ymin = lower, ymax = upper), fill = "grey85", alpha = 0.5) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 2) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    geom_vline(xintercept = -0.5, linetype = "dotted", color = "red") +
    labs(
      x = "Event Time (years relative to treatment)",
      y = "ATT",
      title = title
    ) +
    theme_minimal(base_size = 13)
}


# --- Batch wrappers -----------------------------------------------------------

#' Canonical list of DiD block IDs (treatment × outcome)
did_block_ids <- function() {
  tx_ids  <- names(did_treatments())
  out_ids <- names(did_outcomes())
  paste(rep(tx_ids, each = length(out_ids)), out_ids, sep = "_")
}


#' Run all DiD estimations across treatment × outcome combinations
#'
#' @param did_data_list Named list of prepared data (one per treatment)
#' @return Named list of att_gt objects, keyed by block_id
run_all_did_blocks <- function(did_data_list) {
  outcomes <- did_outcomes()

  did_block_ids() |>
    purrr::set_names() |>
    purrr::map(\(bid) {
      # Parse block_id
      tx_id  <- sub("_.*", "", bid)
      out_id <- sub("^[^_]+_", "", bid)
      out    <- outcomes[[out_id]]

      run_did_estimation(did_data_list[[tx_id]], out$var)
    })
}


#' Aggregate all DiD results (event-study + overall ATT)
#'
#' @param did_models Named list of att_gt objects from run_all_did_blocks()
#' @return Named list of lists (each with event_study and overall)
aggregate_all_did_results <- function(did_models) {
  did_models |>
    purrr::map(\(att_gt_obj) aggregate_did_results(att_gt_obj))
}


#' Plot all event-study figures
#'
#' @param did_results Named list from aggregate_all_did_results()
#' @return Named list of ggplot objects
plot_all_did_event_studies <- function(did_results) {
  treatments <- did_treatments()
  outcomes   <- did_outcomes()

  tx_labels <- c(cit = "CIT", pit = "PIT")

  did_results |>
    purrr::imap(\(res, bid) {
      tx_id  <- sub("_.*", "", bid)
      out_id <- sub("^[^_]+_", "", bid)
      title  <- paste0(tx_labels[[tx_id]], " Cut \u2192 ", outcomes[[out_id]]$label)
      plot_did_event_study(res$event_study, title = title)
    })
}
