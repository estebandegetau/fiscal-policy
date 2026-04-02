# R/lp_firms.R
# Firm-level local projections: effect of tax rate changes on firm outcomes.
# Adapts the macro LP framework (R/local_projections.R) to firm-level data
# from orbis_merged, using the same 9 outcomes as the DiD analysis (R/did.R).


#' Outcome definitions for firm-level LP
#'
#' Wraps did_outcomes() and adds y_label for IRF plot axes.
#' @return Named list of outcome specs (var, transform, y_label)
lp_firm_outcomes <- function() {
  did_outs <- did_outcomes()
  purrr::imap(did_outs, \(spec, id) {
    label <- gsub("_", " ", id) |> tools::toTitleCase()
    list(
      var       = spec$var,
      transform = spec$transform,
      y_label   = paste0(label, " (", spec$transform, " \u0394)")
    )
  })
}


#' Canonical list of firm-level LP block IDs
#' @return Character vector of block IDs (treatment x outcome)
lp_firm_block_ids <- function() {
  tx_ids  <- names(lp_treatments())
  out_ids <- names(lp_firm_outcomes())
  paste(rep(tx_ids, each = length(out_ids)), out_ids, sep = "_")
}


#' Get specification for a firm-level LP block
#'
#' Parses block_id into treatment + outcome components.
#' Block IDs have the form "{treatment}_{outcome}" where outcome may
#' contain underscores (e.g. "cit_profit_per_employee").
#'
#' @param block_id Character string
#' @return Named list with spec fields
get_lp_firm_spec <- function(block_id) {
  treatments <- lp_treatments()
  outcomes   <- lp_firm_outcomes()

  matched <- FALSE
  for (tx_id in names(treatments)) {
    prefix <- paste0(tx_id, "_")
    if (startsWith(block_id, prefix)) {
      out_id <- sub(prefix, "", block_id, fixed = TRUE)
      matched <- TRUE
      break
    }
  }

  if (!matched || !out_id %in% names(outcomes)) {
    stop("Unknown firm LP block_id: ", block_id,
         ". Valid IDs: ", paste(lp_firm_block_ids(), collapse = ", "))
  }

  tx  <- treatments[[tx_id]]
  out <- outcomes[[out_id]]

  list(
    block_id      = block_id,
    treatment_var = tx$change_var,
    level_var     = tx$level_var,
    lag_level     = tx$lag_level,
    outcome_var   = out$var,
    transform     = out$transform,
    y_label       = out$y_label,
    chart_filename = paste0("Cumulative_Effect_firm_", block_id, ".png")
  )
}


#' Prepare shared firm-level panel for LP estimation
#'
#' Combines DiD-style balanced panel construction with LP-style variable prep.
#' Filters to 2006-2017, balances the panel, transforms outcomes, and adds
#' regional dummies needed for the interaction specification.
#'
#' @param orbis_merged Firm x country x year panel from merge_orbis_data()
#' @return Tibble: balanced firm panel with transformed outcomes and controls
prepare_lp_firm_data <- function(orbis_merged) {
  outcomes    <- lp_firm_outcomes()
  treatments  <- lp_treatments()
  outcome_vars <- purrr::map_chr(outcomes, "var")
  tx_change_vars <- purrr::map_chr(treatments, "change_var")
  tx_level_vars  <- purrr::map_chr(treatments, "level_var")

  # Select needed columns early (memory optimisation)
  keep_cols <- c(
    "ccode", "country", "year", "firm_id",
    "group2", "incomelevel",
    tx_change_vars, tx_level_vars,
    "banking_crisis", "currency_crisis", "debt_crisis",
    outcome_vars
  )

  year_min <- 2006L
  year_max <- 2017L
  n_years  <- year_max - year_min + 1L

  df <- orbis_merged |>
    select(all_of(keep_cols)) |>
    filter(
      !is.na(firm_id),
      year >= year_min, year <= year_max,
      incomelevel != "LIC"
    )

  # Transform outcomes: log (positive only) or asinh
  log_vars  <- purrr::map_chr(purrr::keep(outcomes, \(o) o$transform == "log"), "var")
  asinh_vars <- purrr::map_chr(purrr::keep(outcomes, \(o) o$transform == "asinh"), "var")

  df <- df |>
    mutate(
      across(all_of(log_vars),   \(x) if_else(x > 0, log(x), NA_real_), .names = "t_{.col}"),
      across(all_of(asinh_vars), \(x) asinh(x), .names = "t_{.col}")
    )

  # Balance panel: keep firms observed in all years
  df <- df |>
    group_by(firm_id) |>
    filter(n() == n_years) |>
    ungroup()

  # Regional dummies and firm numeric ID
  df |>
    mutate(
      east_asia   = as.integer(group2 == "EAP"),
      hic         = as.integer(incomelevel == "HIC"),
      region      = classify_region(group2, incomelevel),
      firm_id_num = as.integer(factor(firm_id))
    ) |>
    arrange(firm_id, year)
}


#' Prepare data for a specific firm-level LP block
#'
#' Computes outcome growth (first-difference of transformed outcome),
#' forward horizons, treatment, and controls — all grouped by firm.
#'
#' @param lp_firm_data Tibble from prepare_lp_firm_data()
#' @param block_id Character string identifying the block
#' @return Tibble ready for regression
prepare_lp_firm_block <- function(lp_firm_data, block_id) {
  spec <- get_lp_firm_spec(block_id)
  t_var <- paste0("t_", spec$outcome_var)

  df <- lp_firm_data |>
    group_by(firm_id) |>
    mutate(
      outcome_growth = .data[[t_var]] - lag(.data[[t_var]]),
      outcome_lag    = lag(outcome_growth),
      outcome_h0     = lead(outcome_growth, 0),
      outcome_h1     = lead(outcome_growth, 1),
      outcome_h2     = lead(outcome_growth, 2),
      outcome_h3     = lead(outcome_growth, 3),
      outcome_h4     = lead(outcome_growth, 4),
      outcome_h5     = lead(outcome_growth, 5),
      # Treatment: positive = tax cut
      tax_cut        = -.data[[spec$treatment_var]],
      # Tax level control (lagged)
      tax_level      = .data[[spec$level_var]],
      lag_tax_level  = lag(tax_level)
    ) |>
    ungroup()

  # Crisis exclusion: zero out treatment
  df |>
    mutate(
      tax_cut = if_else(
        year %in% c(2008, 2009, 2020, 2021, 2022) |
          coalesce(banking_crisis, 0) == 1 |
          coalesce(currency_crisis, 0) == 1 |
          coalesce(debt_crisis, 0) == 1,
        0, tax_cut
      )
    )
}


#' Run horizon-by-horizon firm-level LP regressions
#'
#' Specification: outcome_h{h} ~ outcome_lag + tax_cut * east_asia +
#'   tax_cut * hic + lag_tax_level | firm_id_num + year
#' Clustered at country level (vcov = ~ccode).
#'
#' @param block_data Tibble from prepare_lp_firm_block()
#' @param block_id Character string identifying the block
#' @param horizons Integer vector (default 0:5)
#' @return Named list of fixest model objects (H0..H5)
run_lp_firm_regressions <- function(block_data, block_id, horizons = 0:5) {
  setNames(
    lapply(horizons, function(h) {
      fml <- as.formula(paste0(
        "outcome_h", h,
        " ~ outcome_lag + tax_cut * east_asia + tax_cut * hic + ",
        "lag_tax_level | firm_id_num + year"
      ))
      fixest::feols(fml, data = block_data, vcov = ~ccode)
    }),
    paste0("H", horizons)
  )
}


#' Plot IRF for a firm-level LP block
#'
#' @param cumulative_effects Tibble from compute_cumulative_effects()
#' @param block_id Character string identifying the block
#' @param group Which group to plot (default "EAP")
#' @return ggplot object
plot_lp_firm_irf <- function(cumulative_effects, block_id, group = "EAP") {
  spec <- get_lp_firm_spec(block_id)

  plot_data <- cumulative_effects |>
    filter(group == !!group) |>
    mutate(across(c(coef, lower, upper), ~ .x * 100))

  ggplot(plot_data, aes(x = horizon)) +
    geom_ribbon(aes(ymin = lower, ymax = upper), fill = "grey85", alpha = 0.5) +
    geom_line(aes(y = coef), linewidth = 0.8) +
    geom_point(aes(y = coef), size = 2) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    scale_x_continuous(breaks = 0:5) +
    labs(
      x = "Years After Tax Cut",
      y = paste0("Cumulative Effect on\n", spec$y_label, " (pp)")
    ) +
    theme_minimal(base_size = 13)
}


# --- Batch wrappers -----------------------------------------------------------

#' Run all firm-level LP blocks
#'
#' @param lp_firm_data Tibble from prepare_lp_firm_data()
#' @param blocks Character vector of block IDs (default: all 18)
#' @return Named list of model lists, one per block
run_all_lp_firm_blocks <- function(lp_firm_data, blocks = lp_firm_block_ids()) {
  blocks |>
    purrr::set_names() |>
    purrr::map(\(bid) {
      block_data <- prepare_lp_firm_block(lp_firm_data, bid)
      run_lp_firm_regressions(block_data, bid)
    })
}

#' Plot IRFs for all firm-level LP blocks
#'
#' @param all_cumulative Named list from compute_all_cumulative_effects()
#' @return Named list of ggplot objects
plot_all_lp_firm_irfs <- function(all_cumulative) {
  all_cumulative |>
    purrr::imap(\(cum_eff, bid) plot_lp_firm_irf(cum_eff, bid))
}

#' Save outputs for all firm-level LP blocks
#'
#' @param all_cumulative Named list from compute_all_cumulative_effects()
#' @param all_plots Named list from plot_all_lp_firm_irfs()
#' @return Named list of file path lists
save_all_lp_firm_outputs <- function(all_cumulative, all_plots) {
  dir.create(here::here("output"), showWarnings = FALSE, recursive = TRUE)

  purrr::imap(all_cumulative, \(cum_eff, bid) {
    spec <- get_lp_firm_spec(bid)

    csv_path <- here::here("output", paste0("firm_", bid, "_cumulative_effects.csv"))
    write_csv(cum_eff, csv_path)

    png_path <- here::here("output", spec$chart_filename)
    ggsave(png_path, all_plots[[bid]], width = 6, height = 5, dpi = 300)

    list(csv_path = csv_path, png_path = png_path)
  })
}
