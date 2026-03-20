# R/local_projections.R
# Local projection functions for Phase 1: macro effects of tax cuts.
# Translates stata/Charts_October_1_2025_.do into R using fixest.
#
# Note: STATA code uses regife (interactive FE, Bai 2009). This translation
# uses standard TWFE via fixest::feols() as a working approximation.


#' Outcome definitions (defined once, shared across all treatments)
#' @return Named list of outcome specs
lp_outcomes <- function() {
  list(
    gdppc          = list(raw_var = "NGDPRPPPPC",        is_log = FALSE, y_label = "GDP per Capita Growth"),
    rev_tax        = list(raw_var = "i2_rev_tax",        is_log = FALSE, y_label = "Tax Revenue Growth"),
    tax_inc_prof_cp = list(raw_var = "i2_tax_inc_prof_cp", is_log = FALSE, y_label = "Income Tax Revenue Growth"),
    tax_inc_prof_id = list(raw_var = "i2_tax_inc_prof_id", is_log = FALSE, y_label = "Income Tax (Indiv.) Revenue Growth"),
    pvt_investment = list(raw_var = "lpvt_investment",   is_log = TRUE,  y_label = "Private Investment Growth"),
    fdi            = list(raw_var = "fdi_net_in",        is_log = FALSE, y_label = "FDI Growth"),
    consumption    = list(raw_var = "tot_consump_wdi",   is_log = FALSE, y_label = "Consumption Growth")
  )
}

#' Treatment definitions (defined once)
#' @return Named list of treatment specs
lp_treatments <- function() {
  list(
    cit = list(change_var = "change_corporate_tr",  level_var = "corporate_tr",  lag_level = TRUE),
    pit = list(change_var = "change_individual_tr", level_var = "individual_tr", lag_level = FALSE)
  )
}

#' Get specification for a local projection block
#'
#' Assembles a spec from the treatment × outcome cross product.
#' Block IDs have the form "{treatment}_{outcome}", e.g. "cit_gdppc".
#'
#' @param block_id Character string identifying the block
#' @return A list with fields: block_id, treatment_var, tax_level_var,
#'   lag_tax_level, outcome_raw_var, outcome_is_log, exclude_crisis,
#'   y_label, chart_filename
get_lp_spec <- function(block_id) {
  treatments <- lp_treatments()
  outcomes   <- lp_outcomes()

  # Parse block_id: match treatment prefix (cit_ or pit_), remainder is outcome
  tx_ids <- names(treatments)
  matched <- FALSE
  for (tx_id in tx_ids) {
    prefix <- paste0(tx_id, "_")
    if (startsWith(block_id, prefix)) {
      out_id <- sub(prefix, "", block_id, fixed = TRUE)
      matched <- TRUE
      break
    }
  }

  if (!matched || !out_id %in% names(outcomes)) {
    stop("Unknown block_id: ", block_id,
         ". Valid IDs: ", paste(lp_block_ids(), collapse = ", "))
  }

  tx  <- treatments[[tx_id]]
  out <- outcomes[[out_id]]

  list(
    block_id        = block_id,
    treatment_var   = tx$change_var,
    tax_level_var   = tx$level_var,
    lag_tax_level   = tx$lag_level,
    outcome_raw_var = out$raw_var,
    outcome_is_log  = out$is_log,
    exclude_crisis  = TRUE,
    y_label         = out$y_label,
    chart_filename  = paste0("Cumulative_Effect_", block_id, ".png")
  )
}


#' Prepare shared data for local projections
#'
#' Filters sample, creates income groups, real GDP, and regional dummies.
#' Translates STATA Step 1 common to all blocks in Charts_October_1_2025_.do.
#'
#' @param macro_data Tibble from the macro_data target
#' @return Tibble with panel structure and shared variables
prepare_lp_data <- function(macro_data) {
  macro_data |>
    filter(
      year >= 2000, year <= 2022,
      incomelevel != "LIC"
    ) |>
    # STATA: gen gp = incomelevel with reclassifications
    mutate(
      gp = case_when(
        group2 == "EAP" ~ "EAP",
        group2 == "China" ~ "China",
        ccode == "MNG" ~ "Mongolia",
        group2 == "PIC" ~ "PIC",
        incomelevel %in% c("LMC", "UMC") ~ "MIC",
        TRUE ~ incomelevel
      ),
      # Also fix group2 for Mongolia (STATA: replace group2 = "Mongolia" if ccode == "MNG")
      group2 = if_else(ccode == "MNG", "Mongolia", group2)
    ) |>
    filter(gp != "PIC") |>
    arrange(ccode2, year) |>
    group_by(ccode2) |>
    mutate(
      # STATA: gen real_gdp = ln(NGDPRPPPPC * LP)
      real_gdp = log(NGDPRPPPPC * LP),
      lag_real_gdp = lag(real_gdp),
      # Regional dummies
      east_asia = as.integer(group2 == "EAP"),
      hic = as.integer(group2 == "HIC")
    ) |>
    ungroup()
}


#' Prepare data for a specific LP block
#'
#' Constructs outcome growth, forward horizons, treatment, and controls
#' for one block specification.
#'
#' @param lp_data Tibble from prepare_lp_data()
#' @param block_id Character string identifying the block
#' @return Tibble ready for regression
prepare_block_data <- function(lp_data, block_id) {
  spec <- get_lp_spec(block_id)

  df <- lp_data |>
    group_by(ccode2) |>
    mutate(
      # Construct outcome growth
      outcome_growth = if (spec$outcome_is_log) {
        # Variable is already in log (e.g., lpvt_investment)
        .data[[spec$outcome_raw_var]] - lag(.data[[spec$outcome_raw_var]])
      } else {
        # Need to take log first
        log(.data[[spec$outcome_raw_var]]) - lag(log(.data[[spec$outcome_raw_var]]))
      }
    ) |>
    mutate(
      outcome_lag = lag(outcome_growth),
      # Forward outcomes for horizons 0-5
      outcome_h0 = lead(outcome_growth, 0),
      outcome_h1 = lead(outcome_growth, 1),
      outcome_h2 = lead(outcome_growth, 2),
      outcome_h3 = lead(outcome_growth, 3),
      outcome_h4 = lead(outcome_growth, 4),
      outcome_h5 = lead(outcome_growth, 5),
      # Treatment: positive = tax cut (natural sign convention)
      tax_cut = -.data[[spec$treatment_var]],
      lag_tax_cut = lag(tax_cut),
      # Tax level control
      tax_level = .data[[spec$tax_level_var]],
      lag_tax_level = lag(tax_level)
    ) |>
    ungroup()

  # Crisis exclusion: zero out treatment in crisis years
  # STATA: replace change_corporate_tr = 0 if inlist(year, 2008, 2009, 2020, 2021, 2022)
  # STATA: replace change_corporate_tr = 0 if banking_crisis == 1 | ...
  if (spec$exclude_crisis) {
    df <- df |>
      mutate(
        tax_cut = if_else(
          year %in% c(2008, 2009, 2020, 2021, 2022) |
            banking_crisis == 1 | currency_crisis == 1 | debt_crisis == 1,
          0, tax_cut
        )
      )
  }

  df
}


#' Run horizon-by-horizon local projection regressions
#'
#' @param block_data Tibble from prepare_block_data()
#' @param block_id Character string identifying the block
#' @param horizons Integer vector of horizons (default 0:5)
#' @return Named list of fixest model objects (H0, H1, ..., H5)
run_lp_regressions <- function(block_data, block_id, horizons = 0:5) {
  spec <- get_lp_spec(block_id)

  # Tax level control: lagged for CIT, contemporaneous for PIT
  # STATA CIT: l1.corporate_tr; STATA PIT: individual_tr
  tax_ctrl <- if (spec$lag_tax_level) "lag_tax_level" else "tax_level"

  models <- setNames(
    lapply(horizons, function(h) {
      outcome_var <- paste0("outcome_h", h)
      # STATA: regife outcome_h`h' outcome_lag l1.real_gdp
      #   c.change_corporate_tr##i.east_asia c.change_corporate_tr##i.hic
      #   l1.corporate_tr, ife(ccode2 year, 1) vce(cluster ccode2)
      fml <- as.formula(paste0(
        outcome_var, " ~ outcome_lag + lag_real_gdp + ",
        "tax_cut * east_asia + tax_cut * hic + ",
        tax_ctrl, " | ccode2 + year"
      ))
      fixest::feols(fml, data = block_data, vcov = ~ccode2)
    }),
    paste0("H", horizons)
  )

  models
}


#' Compute cumulative impulse response effects
#'
#' Extracts coefficients and variances from horizon-by-horizon models,
#' cumulates them, and computes delta-method SEs for MIC, EAP, and HIC.
#' Faithfully translates STATA Step 3 from Charts_October_1_2025_.do.
#'
#' @param model_list Named list of fixest models from run_lp_regressions()
#' @param block_id Character string identifying the block
#' @return Tibble with columns: horizon, group, coef, se, lower, upper
compute_cumulative_effects <- function(model_list, block_id) {
  results <- tibble(
    horizon = integer(),
    group = character(),
    coef = double(),
    se = double(),
    lower = double(),
    upper = double()
  )

  cum_coef_mic <- 0
  cum_var_mic <- 0
  cum_coef_eap <- 0
  cum_var_eap <- 0
  cum_coef_hic <- 0
  cum_var_hic <- 0

  for (h in 0:5) {
    model <- model_list[[paste0("H", h)]]
    b <- coef(model)
    V <- vcov(model)

    # Coefficient names in fixest for tax_cut * east_asia:
    # "tax_cut", "east_asia", "tax_cut:east_asia", "hic", "tax_cut:hic"
    i_main <- "tax_cut"
    i_eap <- "tax_cut:east_asia"
    i_hic <- "tax_cut:hic"

    if (!i_main %in% names(b)) next

    # MIC (baseline)
    coef_mic <- b[[i_main]]
    var_mic <- V[i_main, i_main]
    cum_coef_mic <- cum_coef_mic + coef_mic
    cum_var_mic <- cum_var_mic + var_mic

    results <- bind_rows(results, tibble(
      horizon = h, group = "MIC",
      coef = cum_coef_mic,
      se = sqrt(cum_var_mic),
      lower = cum_coef_mic - 1.96 * sqrt(cum_var_mic),
      upper = cum_coef_mic + 1.96 * sqrt(cum_var_mic)
    ))

    # EAP (total = baseline + interaction)
    if (i_eap %in% names(b)) {
      coef_eap <- b[[i_eap]]
      # Delta method: Var(main + interaction) = Var(main) + Var(int) + 2*Cov
      var_eap <- V[i_eap, i_eap] + 2 * V[i_main, i_eap]
      cum_coef_eap <- cum_coef_eap + coef_mic + coef_eap
      cum_var_eap <- cum_var_eap + var_mic + var_eap

      results <- bind_rows(results, tibble(
        horizon = h, group = "EAP",
        coef = cum_coef_eap,
        se = sqrt(cum_var_eap),
        lower = cum_coef_eap - 1.96 * sqrt(cum_var_eap),
        upper = cum_coef_eap + 1.96 * sqrt(cum_var_eap)
      ))
    }

    # HIC (total = baseline + interaction)
    if (i_hic %in% names(b)) {
      coef_hic <- b[[i_hic]]
      var_hic <- V[i_hic, i_hic] + 2 * V[i_main, i_hic]
      cum_coef_hic <- cum_coef_hic + coef_mic + coef_hic
      cum_var_hic <- cum_var_hic + var_mic + var_hic

      results <- bind_rows(results, tibble(
        horizon = h, group = "HIC",
        coef = cum_coef_hic,
        se = sqrt(cum_var_hic),
        lower = cum_coef_hic - 1.96 * sqrt(cum_var_hic),
        upper = cum_coef_hic + 1.96 * sqrt(cum_var_hic)
      ))
    }
  }

  results
}


#' Plot impulse response function for a single group
#'
#' @param cumulative_effects Tibble from compute_cumulative_effects()
#' @param block_id Character string identifying the block
#' @param group Which income group to plot (default "EAP")
#' @return A ggplot object
plot_irf <- function(cumulative_effects, block_id, group = "EAP") {
  spec <- get_lp_spec(block_id)

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


#' Save LP outputs to disk
#'
#' @param cumulative_effects Tibble from compute_cumulative_effects()
#' @param plot ggplot object from plot_irf()
#' @param block_id Character string identifying the block
#' @return List with csv_path and png_path
save_lp_outputs <- function(cumulative_effects, plot, block_id) {
  spec <- get_lp_spec(block_id)

  dir.create(here::here("output"), showWarnings = FALSE, recursive = TRUE)

  csv_path <- here::here("output", paste0(block_id, "_cumulative_effects.csv"))
  write_csv(cumulative_effects, csv_path)

  png_path <- here::here("output", spec$chart_filename)
  ggsave(png_path, plot, width = 6, height = 5, dpi = 300)

  list(csv_path = csv_path, png_path = png_path)
}


# --- Batch wrappers (iterate over blocks with purrr::map) -------------------

#' Canonical list of LP block IDs (treatment × outcome cross product)
lp_block_ids <- function() {
  tx_ids  <- names(lp_treatments())
  out_ids <- names(lp_outcomes())
  paste(rep(tx_ids, each = length(out_ids)), out_ids, sep = "_")
}

#' Run all LP blocks: data prep + regressions
#'
#' @param lp_data Tibble from prepare_lp_data()
#' @param blocks Character vector of block IDs (default: all)
#' @return Named list of model lists, one per block
run_all_lp_blocks <- function(lp_data, blocks = lp_block_ids()) {
  blocks |>
    purrr::set_names() |>
    purrr::map(\(bid) {
      block_data <- prepare_block_data(lp_data, bid)
      run_lp_regressions(block_data, bid)
    })
}

#' Compute cumulative effects for all blocks
#'
#' @param all_models Named list from run_all_lp_blocks()
#' @return Named list of tibbles, one per block
compute_all_cumulative_effects <- function(all_models) {
  all_models |>
    purrr::imap(\(models, bid) compute_cumulative_effects(models, bid))
}

#' Plot IRFs for all blocks
#'
#' @param all_cumulative Named list from compute_all_cumulative_effects()
#' @return Named list of ggplot objects, one per block
plot_all_irfs <- function(all_cumulative) {
  all_cumulative |>
    purrr::imap(\(cum_eff, bid) plot_irf(cum_eff, bid))
}

#' Save outputs for all blocks
#'
#' @param all_cumulative Named list from compute_all_cumulative_effects()
#' @param all_plots Named list from plot_all_irfs()
#' @return Named list of file path lists, one per block
save_all_lp_outputs <- function(all_cumulative, all_plots) {
  purrr::imap(all_cumulative, \(cum_eff, bid) {
    save_lp_outputs(cum_eff, all_plots[[bid]], bid)
  })
}
