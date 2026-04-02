# R/did.R
# Phase 2: Difference-in-Differences estimation of firm-level effects
# of tax changes using the did package (Callaway & Sant'Anna 2021).
#
# Design: absorbing binary treatment — once a country cuts taxes, it stays
# treated forever. The did package handles staggered adoption, provides
# group-time ATTs, event-study aggregation, and built-in pre-trend tests.


#' Classify countries into regional groups for DiD analysis
#'
#' Mirrors the LP pipeline's grouping logic (R/local_projections.R:93-101),
#' simplified to three groups: EAP, MIC, HIC.
#' Countries not matching any group (China, Mongolia, PIC) get NA.
#'
#' @param group2 Character vector of World Bank group2 classification
#' @param incomelevel Character vector of income level codes
#' @return Character vector: "EAP", "MIC", "HIC", or NA
classify_region <- function(group2, incomelevel) {
  case_when(
    group2 == "EAP" ~ "EAP",
    incomelevel %in% c("LMC", "UMC") ~ "MIC",
    incomelevel == "HIC" ~ "HIC",
    TRUE ~ NA_character_
  )
}


#' Treatment definitions for DiD
#' @return Named list of treatment specs
did_treatments <- function() {
  list(
    cit = list(change_var = "change_corporate_tr"),
    pit = list(change_var = "change_individual_tr")
  )
}

#' Outcome definitions for DiD (firm-level)
#' @return Named list of outcome specs (var, label, transform)
did_outcomes <- function() {
  list(
    income_tax           = list(var = "income_tax",           label = "asinh(Income Tax Payable)", transform = "asinh"),
    income_taxes         = list(var = "income_taxes",         label = "asinh(Income Taxes)",       transform = "asinh"),
    social_expenditure   = list(var = "social_expenditure",   label = "log(Social Exp.)",          transform = "log"),
    revenues             = list(var = "revenues",             label = "asinh(Revenue)",            transform = "asinh"),
    employees            = list(var = "employees",            label = "log(Employment)",           transform = "log"),
    investments          = list(var = "investments",          label = "asinh(Investment)",          transform = "asinh"),
    net_profit           = list(var = "net_profit",           label = "asinh(Net Profit)",       transform = "asinh"),
    total_assets         = list(var = "total_assets",         label = "log(Total Assets)",       transform = "log"),
    profit_per_employee  = list(var = "profit_per_employee",  label = "asinh(Profit/Employee)",  transform = "asinh")
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
  outcomes <- did_outcomes()
  outcome_vars <- purrr::map_chr(outcomes, "var")

  # Select only needed columns early to reduce memory (~1.4 GB -> ~40 MB)
  keep_cols <- c("ccode", "country", "year", "firm_id", tx$change_var,
                 "banking_crisis", "currency_crisis", "debt_crisis",
                 "group2", "incomelevel",
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
      )
    ) |>
    # Transform outcomes: log (positive only) or asinh (handles negatives/zeros)
    mutate(
      across(
        all_of(purrr::map_chr(purrr::keep(outcomes, \(o) o$transform == "log"), "var")),
        \(x) if_else(x > 0, log(x), NA_real_),
        .names = "t_{.col}"
      ),
      across(
        all_of(purrr::map_chr(purrr::keep(outcomes, \(o) o$transform == "asinh"), "var")),
        \(x) asinh(x),
        .names = "t_{.col}"
      )
    ) |>
    mutate(region = classify_region(group2, incomelevel)) |>
    select(ccode, country, year, firm_id,
           first_treated_year, treated, region,
           all_of(outcome_vars),
           starts_with("t_"))

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
#' Uses transformed outcomes (t_investments, t_employees, etc.) for
#' estimation. Filters to firms with non-missing transformed outcome
#' across all panel years before estimating.
#'
#' @param did_data Tibble from prepare_did_data()
#' @param outcome_var Character: base outcome name (e.g. "investments")
#' @return att_gt object from the did package
run_did_estimation <- function(did_data, outcome_var) {
  t_var <- paste0("t_", outcome_var)

  # Keep only firms with non-missing transformed outcome in every year
  n_years <- n_distinct(did_data$year)
  complete_firms <- did_data |>
    filter(!is.na(.data[[t_var]])) |>
    count(firm_id) |>
    filter(n == n_years) |>
    pull(firm_id)

  est_data <- did_data |>
    filter(firm_id %in% complete_firms) |>
    mutate(firm_id_num = as.integer(factor(firm_id)))

  did::att_gt(
    yname  = t_var,
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



#' Plot event-study coefficients from DiD summary data
#'
#' @param es_data Tibble with columns e, att, se (from did_summaries$event_study)
#' @param crit_val Numeric: simultaneous critical value for CI bands (default 1.96)
#' @param title Character: plot title
#' @return ggplot object
plot_did_event_study <- function(es_data, crit_val = 1.96, title = "") {
  es <- es_data |>
    mutate(
      lower = att - crit_val * se,
      upper = att + crit_val * se
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


# --- Scope & spec helpers -----------------------------------------------------

#' Parse a three-part block ID into scope, treatment, and outcome
#'
#' Block IDs have the form {scope}_{tx}_{outcome}. Scope tokens (world, EAP,
#' MIC, HIC, or 3-letter country codes) and tx tokens (cit, pit) never contain
#' underscores, so we split on "_" and take the first two parts; the remainder
#' (which may contain underscores, e.g. "total_assets") is the outcome.
#'
#' @param bid Character: block ID string
#' @return Named list with elements scope, tx, outcome
parse_block_id <- function(bid) {
  parts <- strsplit(bid, "_", fixed = TRUE)[[1]]
  list(
    scope   = parts[1],
    tx      = parts[2],
    outcome = paste(parts[-(1:2)], collapse = "_")
  )
}


#' Build the full specification tibble for DiD estimation
#'
#' Crosses scope × treatment × outcome. Scopes: "world" plus three regions
#' (EAP, MIC, HIC). Country-level estimation is infeasible because treatment
#' is assigned at country level (no within-country control firms).
#'
#' @return Tibble with columns: scope, scope_type, tx, outcome, block_id
did_spec <- function() {
  scopes      <- c("world", "EAP", "MIC", "HIC")
  scope_types <- c(world = "world", EAP = "region", MIC = "region", HIC = "region")

  tidyr::expand_grid(
    scope   = scopes,
    tx      = names(did_treatments()),
    outcome = names(did_outcomes())
  ) |>
    dplyr::mutate(
      scope_type = scope_types[scope],
      block_id   = paste(scope, tx, outcome, sep = "_")
    )
}


#' Filter prepared DiD data to a geographic scope
#'
#' @param data Tibble from prepare_did_data()
#' @param scope Character: "world" or a region name (EAP, MIC, HIC)
#' @param scope_type Character: "world" or "region"
#' @return Filtered tibble
filter_did_scope <- function(data, scope, scope_type) {
  switch(scope_type,
    world  = data,
    region = dplyr::filter(data, region == scope)
  )
}


# --- Batch wrappers -----------------------------------------------------------


#' Run all DiD estimations across scope × treatment × outcome combinations
#'
#' @param did_data_list Named list of prepared data (one per treatment)
#' @return Named list of att_gt objects (or NULL for failed estimations),
#'   keyed by block_id ({scope}_{tx}_{outcome})
run_all_did_blocks <- function(did_data_list) {
  outcomes <- did_outcomes()
  spec <- did_spec()

  spec$block_id |>
    purrr::set_names() |>
    purrr::map(\(bid) {
      row <- spec[spec$block_id == bid, ]
      data_scoped <- filter_did_scope(
        did_data_list[[row$tx]], row$scope, row$scope_type
      )
      tryCatch(
        run_did_estimation(data_scoped, outcomes[[row$outcome]]$var),
        error = function(e) {
          warning(sprintf("DiD estimation failed for %s: %s", bid, e$message))
          NULL
        }
      )
    })
}


#' Extract lightweight summaries from all DiD models
#'
#' Aggregates each att_gt object into event-study, group-level, and overall ATT,
#' then extracts only the small numeric fields the notebook needs. This avoids
#' serialising the full DIDparams (which embeds the estimation data) into the
#' target store.
#'
#' @param did_models Named list of att_gt objects (or NULL) from run_all_did_blocks()
#' @return Tibble with columns: block_id, scope, tx, outcome, n,
#'   overall_att, overall_se, wpval, event_study (list-col),
#'   event_study_crit_val, group_att (list-col)
extract_did_summaries <- function(did_models) {
  did_models |>
    purrr::discard(is.null) |>
    purrr::imap_dfr(\(mod, bid) {
      tryCatch({
        parsed  <- parse_block_id(bid)
        es_agg  <- did::aggte(mod, type = "dynamic")
        grp_agg <- did::aggte(mod, type = "group")
        ov_agg  <- did::aggte(mod, type = "simple")

        tibble::tibble(
          block_id  = bid,
          scope     = parsed$scope,
          tx        = parsed$tx,
          outcome   = parsed$outcome,
          n         = nrow(mod$DIDparams$data),
          overall_att = ov_agg$overall.att,
          overall_se  = ov_agg$overall.se,
          wpval       = mod$Wpval,
          event_study = list(tibble::tibble(
            e   = es_agg$egt,
            att = es_agg$att.egt,
            se  = es_agg$se.egt
          )),
          event_study_crit_val = es_agg$crit.val.egt,
          group_att = list(tibble::tibble(
            group = grp_agg$egt,
            att   = grp_agg$att.egt,
            se    = grp_agg$se.egt
          ))
        )
      }, error = function(e) {
        warning(sprintf("Aggregation failed for %s: %s", bid, e$message))
        NULL
      })
    })
}
