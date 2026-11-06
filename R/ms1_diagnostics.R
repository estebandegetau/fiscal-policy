# R/ms1_diagnostics.R
# Milestone 1 suitability tests. Each function returns a small tibble (or a
# list of tibbles) for docs/ms1_data_suitability.qmd; no model objects stored.

winsorize <- function(x, p = c(0.01, 0.99)) {
  q <- quantile(x, p, na.rm = TRUE)
  pmin(pmax(x, q[1]), q[2])
}

# Broad SIC divisions for Osiris sector breakdowns
sic_division <- function(sic2) {
  s <- suppressWarnings(as.integer(sic2))
  case_when(
    s <= 9 ~ "Agriculture",
    s <= 14 ~ "Mining",
    s <= 17 ~ "Construction",
    s <= 39 ~ "Manufacturing",
    s <= 49 ~ "Transport & utilities",
    s <= 59 ~ "Trade",
    s <= 67 ~ "Finance & real estate",
    s <= 89 ~ "Services",
    TRUE ~ "Other"
  )
}

census_waves <- c(2000L, 2005L, 2010L, 2015L)

# A. Integrity ------------------------------------------------------------------

#' Osiris integrity checks (one row per check)
test_integrity_osiris <- function(osiris_raw, osiris) {
  tibble(
    check = c(
      "Firm-statements (raw)",
      "Firm-years after de-duplication",
      "Firms",
      "Firm-years with two statements (fiscal year-end change)",
      "Firm-years with a non-12-month statement",
      "Firm-years with consolidated accounts",
      "Firm-years reported in USD, not MYR",
      "Firms delisted by download date"
    ),
    value = c(
      nrow(osiris_raw),
      nrow(osiris),
      n_distinct(osiris$firm_id),
      sum(osiris$dup_year),
      sum(osiris$non_annual),
      sum(str_starts(osiris$consol_code, "C")),
      sum(!osiris$myr),
      n_distinct(osiris$firm_id[osiris$listed == "Delisted"])
    )
  )
}

#' Census linkage: do IDs in consecutive waves describe the same establishment?
#'
#' A fall in industry-code agreement at 2005-2010 relative to 2010-2015 points
#' to the MSIC 2000 -> MSIC 2008 reclassification.
test_census_linkage <- function(census) {
  pairs <- tibble(from = census_waves[-4], to = census_waves[-1])

  pmap(pairs, \(from, to) {
    a <- filter(census, wave == from)
    b <- filter(census, wave == to)
    l <- inner_join(a, b, by = "id", suffix = c("_a", "_b"))
    tibble(
      waves = paste(from, to, sep = "–"),
      establishments_from = nrow(a),
      linked = nrow(l),
      share_linked = nrow(l) / nrow(a),
      same_startdate = mean(l$startdate_a == l$startdate_b, na.rm = TRUE),
      same_state = mean(l$state_a == l$state_b, na.rm = TRUE),
      same_industry3 = mean(l$misc3_a == l$misc3_b, na.rm = TRUE)
    )
  }) |>
    bind_rows() |>
    mutate(in_all_waves = c(
      length(Reduce(intersect, split(census$id, census$wave))), NA, NA
    ))
}

#' Integrity checks for the 2022 Economic Census extract
test_integrity_census30 <- function(census30) {
  manuf <- census30 |>
    filter(str_detect(file, "^Man")) |>
    group_by(file) |>
    summarise(
      establishments = n(),
      persons_engaged = sum(persons, na.rm = TRUE),
      fixed_assets_bn = sum(fixed_assets, na.rm = TRUE) / 1e9,
      .groups = "drop"
    )
  shared_ids <- census30 |>
    filter(str_detect(file, "^Man")) |>
    group_by(id) |>
    filter(n_distinct(file) == 2) |>
    summarise(same = n_distinct(msic) == 1 & n_distinct(state) == 1 &
                n_distinct(persons) == 1)

  list(
    manufacturing_files = manuf,
    checks = tibble(
      check = c(
        "Establishments (all sector files)",
        "Sector files",
        "Rows with no single state (national-level entries)",
        "Dummy IDs appearing more than once",
        "Manufacturing IDs shared by both manufacturing files",
        "… of which describe the same establishment"
      ),
      value = c(
        nrow(census30),
        n_distinct(census30$file),
        sum(is.na(census30$state)),
        sum(duplicated(census30$id)),
        nrow(shared_ids),
        sum(shared_ids$same)
      )
    )
  )
}

# B. Representativeness -------------------------------------------------------

#' Investment in each source as a share of WDI gross fixed capital formation
#'
#' Osiris capex is in MYR thousands (UNIT = 3). Census purchases are assumed
#' to be MYR thousands (no dictionary); census waves are matched both to the
#' wave year and to the year before, because the reference year is unknown.
test_representativeness <- function(osiris, census, wdi) {
  gfcf <- wdi |>
    pivot_wider(names_from = indicator, values_from = value)

  osiris_agg <- osiris |>
    filter(myr, year <= 2017) |>
    group_by(year) |>
    summarise(investment = sum(capex, na.rm = TRUE) * 1e3, .groups = "drop") |>
    mutate(source = "Osiris (listed firms)", match = "Same year")

  census_agg <- census |>
    group_by(wave) |>
    summarise(investment = sum(total_purchase, na.rm = TRUE) * 1e3, .groups = "drop") |>
    cross_join(tibble(lag = c(0L, 1L))) |>
    transmute(
      year = wave - lag,
      investment,
      source = "Manufacturing Census",
      match = if_else(lag == 0, "Same year", "Year before wave")
    )

  bind_rows(osiris_agg, census_agg) |>
    left_join(gfcf, by = "year") |>
    mutate(
      share_private = investment / gfcf_private,
      share_total = investment / gfcf_total
    )
}

#' State distribution: 2015 Manufacturing Census vs 2022 Economic Census
test_state_distribution <- function(census, census30) {
  bind_rows(
    census |>
      filter(wave == 2015) |>
      count(state) |>
      mutate(source = "Manufacturing Census 2015"),
    census30 |>
      filter(str_detect(file, "^Man"), !is.na(state)) |>
      count(state) |>
      mutate(source = "Economic Census 2022 (manufacturing)")
  ) |>
    group_by(source) |>
    mutate(share = n / sum(n)) |>
    ungroup() |>
    left_join(my_state_codes(), by = "state")
}

# C. Measuring investment -----------------------------------------------------

#' Variable coverage by year (Osiris) and by wave (census)
test_coverage <- function(osiris, census) {
  osiris_cov <- osiris |>
    group_by(year) |>
    summarise(
      units = n(),
      capex = mean(!is.na(capex)),
      ppe = mean(!is.na(ppe)),
      employment = mean(!is.na(employees)),
      tax_and_ebt = mean(!is.na(income_taxes) & !is.na(ebt)),
      zero_investment = mean(capex == 0, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(source = "Osiris")

  census_cov <- census |>
    group_by(year = wave) |>
    summarise(
      units = n(),
      capex = mean(!is.na(total_purchase)),
      ppe = mean(!is.na(total_bookvaluejan)),
      employment = mean(!is.na(empl)),
      tax_and_ebt = 0,
      zero_investment = mean(total_purchase == 0, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(source = "Manufacturing Census")

  bind_rows(osiris_cov, census_cov) |>
    relocate(source)
}

#' Distribution of the investment rate (I / lagged K), raw and winsorized
test_investment_rate <- function(osiris, census) {
  census_rate <- census |>
    mutate(inv_rate = if_else(total_bookvaluejan > 0,
                              total_purchase / total_bookvaluejan, NA_real_))

  summarise_rate <- function(x, source) {
    x <- x[is.finite(x)]
    w <- winsorize(x)
    tibble(
      source = source,
      version = c("Raw", "Winsorized 1/99"),
      n = length(x),
      p10 = c(quantile(x, 0.10), quantile(w, 0.10)),
      median = c(median(x), median(w)),
      mean = c(mean(x), mean(w)),
      p90 = c(quantile(x, 0.90), quantile(w, 0.90)),
      max = c(max(x), max(w))
    )
  }

  bind_rows(
    summarise_rate(osiris$inv_rate, "Osiris (capex / lagged net PP&E)"),
    summarise_rate(census_rate$inv_rate,
                   "Manufacturing Census (purchases / opening book value)")
  )
}

# D. Effective tax rate --------------------------------------------------------

#' Effective tax rate as a marker of incentive use (Osiris)
#'
#' @param low Threshold below which a firm-year counts as "likely incentivised"
test_etr <- function(osiris, low = 0.05) {
  e <- osiris |>
    filter(!is.na(etr)) |>
    mutate(division = sic_division(sic2))

  persistence <- e |>
    arrange(firm_id, year) |>
    group_by(firm_id) |>
    mutate(etr_lag = if_else(lag(year) == year - 1, lag(etr), NA_real_)) |>
    ungroup() |>
    filter(!is.na(etr_lag))

  by_firm <- e |>
    group_by(firm_id, firm_name, division) |>
    summarise(
      years = n(),
      share_low = mean(etr < low),
      median_etr = median(etr),
      .groups = "drop"
    )

  list(
    distribution = tibble(
      statistic = c(
        "Firm-years with positive pre-tax earnings",
        "Median effective tax rate",
        "Share of firm-years with ETR below 5%",
        "Share of firm-years with ETR above 40%",
        "Year-on-year correlation of ETR (winsorized)",
        "Year-on-year persistence of low-ETR status",
        "Firms with ETR below 5% in most years (≥5 years observed)"
      ),
      value = c(
        nrow(e),
        median(e$etr),
        mean(e$etr < low),
        mean(e$etr > 0.40),
        cor(winsorize(persistence$etr), winsorize(persistence$etr_lag)),
        mean(persistence$etr < low & persistence$etr_lag < low) /
          mean(persistence$etr_lag < low),
        sum(by_firm$years >= 5 & by_firm$share_low > 0.5)
      )
    ),
    by_division = e |>
      group_by(division) |>
      summarise(
        firm_years = n(),
        median_etr = median(etr),
        share_low = mean(etr < low),
        .groups = "drop"
      ) |>
      arrange(desc(share_low)),
    # Candidates for the Bursa annual-report hand-check
    candidates = by_firm |>
      filter(years >= 5) |>
      arrange(desc(share_low), median_etr) |>
      slice_head(n = 20)
  )
}

# E. Feasibility matrix --------------------------------------------------------

#' Statutory headline and SME rate cuts, in the shape of the shock dataset
statutory_shocks <- function(cit_rates) {
  cuts <- function(rate, label, base) {
    cit_rates |>
      arrange(year) |>
      mutate(prev = lag(.data[[rate]])) |>
      filter(!is.na(prev), .data[[rate]] < prev) |>
      transmute(
        shock_id = sprintf("%s-%d", base, year),
        act_label = sprintf("%s cut %g%% → %g%%", label, prev, .data[[rate]]),
        incentive_category = label,
        effective_year = year,
        exogenous = NA_real_
      )
  }
  sme_intro <- cit_rates |>
    filter(!is.na(sme_rate)) |>
    slice_min(year, n = 1) |>
    transmute(
      shock_id = sprintf("SME-%d", year),
      act_label = sprintf("SME rate introduced: 28%% → %g%%", sme_rate),
      incentive_category = "SME rate",
      effective_year = year,
      exogenous = NA_real_
    )
  bind_rows(
    cuts("headline_rate", "Statutory rate", "CIT"),
    sme_intro,
    cuts("sme_rate", "SME rate", "SME")
  )
}

#' Author-review judgments for each shock (drafted by Claude, FOR AUTHOR REVIEW)
#'
#' exposure: how the shock differentiates firms; cost: cost of mapping
#' eligibility to firms in our data; verdict: proposed use.
feasibility_judgments <- function() {
  tribble(
    ~shock_id, ~exposure, ~proxy, ~cost, ~verdict,
    "MY-INCENT-01", "Status (Bumiputera restructuring)", "None", "High: firm equity history not observed", "Infeasible",
    "MY-INCENT-02", "Status (Pioneer / ITA approval)", "Osiris: low ETR", "High: MIDA approvals not public by firm", "Descriptive",
    "MY-INCENT-03", "Zone (Labuan)", "Census: state 15", "Low", "Infeasible",
    "MY-INCENT-04", "Status (reinvesting manufacturers)", "Census: manufacturing", "Medium", "Infeasible",
    "MY-INCENT-05", "Status + zone (MSC status)", "None (ICT services not in Mfg Census)", "High: MSC list must be matched by name", "Descriptive",
    "MY-INCENT-06", "Sector (biomass power)", "None (utilities not in Mfg Census)", "Medium", "Infeasible",
    "MY-INCENT-07", "Zone (Iskandar, south Johor)", "Census: state = Johor; Osiris: city", "Low (state); Medium (geocode Osiris cities)", "Causal candidate (one treated state)",
    "MY-INCENT-08", "Status (GBI-certified buildings)", "None", "High: certification lists by project", "Infeasible",
    "MY-INCENT-09", "Zone + sector (TRX financial firms)", "Osiris: finance SIC + KL city", "Medium: few eligible firms", "Descriptive",
    "MY-INCENT-10", "Investors (personal income tax)", "None (start-ups not in data)", "High", "Infeasible",
    "MY-INCENT-11", "Status (Principal Hub approval)", "None", "High", "Infeasible",
    "MY-INCENT-12", "Status (relocating firms)", "None", "High", "Infeasible",
    "MY-INCENT-13", "Sector (pharmaceuticals, MSIC 21)", "2022 Census: MSIC 21", "Low", "Descriptive",
    "MY-INCENT-14", "Status (relocating firms)", "None", "High", "Infeasible",
    "MY-INCENT-15", "Product (EVs; consumption tax)", "None", "High", "Infeasible",
    "CIT-2007", "All firms; bite depends on ETR", "Osiris: pre-period ETR", "Low", "Causal candidate",
    "CIT-2008", "All firms; bite depends on ETR", "Osiris: pre-period ETR", "Low", "Causal candidate",
    "CIT-2009", "All firms; bite depends on ETR", "Osiris: pre-period ETR", "Low", "Causal candidate",
    "CIT-2016", "All firms; bite depends on ETR", "Osiris: pre-period ETR", "Low", "Causal candidate (short post-period)",
    "SME-2003", "Size (paid-up capital ≤ RM2.5m)", "Census: employment / sales proxy", "Medium: paid-up capital not observed", "Descriptive",
    "SME-2016", "Size (paid-up capital ≤ RM2.5m)", "Census: employment / sales proxy", "Medium", "Infeasible (after last panel wave)",
    "SME-2017", "Size (paid-up capital ≤ RM2.5m)", "Census: employment / sales proxy", "Medium", "Infeasible (after last panel wave)",
    "SME-2019", "Size (paid-up capital ≤ RM2.5m)", "Census: employment / sales proxy", "Medium", "Infeasible (after last panel wave)",
    "SME-2023", "Size (paid-up capital ≤ RM2.5m)", "Census: employment / sales proxy", "Medium", "Infeasible (after last panel wave)"
  )
}

#' Shock x dataset feasibility matrix
#'
#' Timing columns are computed; exposure, proxy, cost and verdict come from
#' feasibility_judgments() and are flagged for author review in the report.
#' Osiris investment data are usable 2004-2017 (capex coverage); census waves
#' are dated by file year.
build_feasibility_matrix <- function(incentive_shocks, cit_rates, osiris_years = 2004:2017) {
  shocks <- bind_rows(
    incentive_shocks |>
      transmute(shock_id, act_label, incentive_category, effective_year,
                exogenous = as.numeric(exogenous)),
    statutory_shocks(cit_rates)
  )

  shocks |>
    mutate(
      osiris_pre = map_int(effective_year, \(y) sum(osiris_years < y)),
      osiris_post = map_int(effective_year, \(y) sum(osiris_years >= y)),
      census_pre = map_int(effective_year, \(y) sum(census_waves < y)),
      census_post = map_int(effective_year, \(y) sum(census_waves >= y)),
      census2022 = effective_year <= 2022
    ) |>
    left_join(feasibility_judgments(), by = "shock_id")
}

# F. Identification prerequisites ---------------------------------------------

#' Firms' exposure to statutory cuts: pre-period average ETR below 5%
#'
#' Firms already paying (near) zero tax should not respond to a headline cut,
#' so they are a candidate control group.
osiris_etr_exposure <- function(osiris, pre_years, low = 0.05) {
  osiris |>
    filter(year %in% pre_years, !is.na(etr)) |>
    group_by(firm_id) |>
    summarise(pre_etr = mean(winsorize(etr, c(0, 1))), .groups = "drop") |>
    mutate(group = if_else(pre_etr < low, "Low ETR (pre-period)", "Taxpaying"))
}

#' Raw means of the investment rate by exposure group (not estimates)
test_event_means <- function(osiris, census) {
  osiris_w <- osiris |>
    filter(!is.na(inv_rate)) |>
    mutate(inv_rate = winsorize(inv_rate))

  osiris_means <- list(
    `Headline cuts 2007–09` = 2004:2006,
    `Headline cut 2016` = 2012:2015
  ) |>
    imap(\(pre, design) {
      osiris_w |>
        inner_join(osiris_etr_exposure(osiris, pre), by = "firm_id") |>
        group_by(design = design, group, year) |>
        summarise(mean = mean(inv_rate), n = n(), .groups = "drop")
    }) |>
    bind_rows()

  census_means <- census |>
    mutate(
      group = if_else(state == "01", "Johor", "Other states"),
      invests = total_purchase > 0
    ) |>
    filter(!is.na(group)) |>
    group_by(design = "Iskandar 2007 (census)", group, year = wave) |>
    summarise(mean = mean(invests, na.rm = TRUE), n = n(), .groups = "drop")

  bind_rows(
    mutate(osiris_means, outcome = "Investment rate (winsorized)"),
    mutate(census_means, outcome = "Share of establishments investing")
  )
}

#' Minimum detectable effects for the candidate designs
#'
#' Firm-level pre/post difference in mean outcome; MDE = 2.8 x SE of the
#' treated-control difference in means (80% power, 5% two-sided). Collapsing
#' to one difference per firm accounts for serial correlation.
test_mde <- function(osiris, census) {
  mde_row <- function(d, design, outcome, treated_label) {
    s <- d |>
      group_by(treated) |>
      summarise(n = n(), sd = sd(diff), .groups = "drop")
    pooled_sd <- sd(d$diff)
    n_t <- s$n[s$treated]
    n_c <- s$n[!s$treated]
    tibble(
      design, outcome, treated = treated_label, n_treated = n_t,
      n_control = n_c, sd_change = pooled_sd,
      mde = 2.8 * pooled_sd * sqrt(1 / n_t + 1 / n_c),
      mean_outcome = mean(d$pre_mean)
    )
  }

  osiris_w <- osiris |>
    filter(!is.na(inv_rate)) |>
    mutate(inv_rate = winsorize(inv_rate))

  osiris_design <- function(pre, post, design) {
    osiris_w |>
      filter(year %in% c(pre, post)) |>
      group_by(firm_id) |>
      summarise(
        pre_mean = mean(inv_rate[year %in% pre]),
        post_mean = mean(inv_rate[year %in% post]),
        .groups = "drop"
      ) |>
      filter(is.finite(pre_mean), is.finite(post_mean)) |>
      inner_join(osiris_etr_exposure(osiris, pre), by = "firm_id") |>
      mutate(diff = post_mean - pre_mean, treated = group == "Taxpaying") |>
      mde_row(design, "Investment rate (winsorized)", "Taxpaying firms")
  }

  census_design <- census |>
    filter(wave %in% c(2005, 2010)) |>
    mutate(invests = as.numeric(total_purchase > 0)) |>
    select(id, wave, state, invests) |>
    pivot_wider(names_from = wave, values_from = c(invests, state)) |>
    filter(!is.na(invests_2005), !is.na(invests_2010), !is.na(state_2005)) |>
    transmute(
      pre_mean = invests_2005,
      diff = invests_2010 - invests_2005,
      treated = state_2005 == "01"
    ) |>
    mde_row("Iskandar 2007 (Census 2005→2010)", "Share investing",
            "Johor establishments")

  bind_rows(
    osiris_design(2004:2006, 2007:2010, "Headline cuts 2007–09 (Osiris)"),
    osiris_design(2012:2015, 2016:2017, "Headline cut 2016 (Osiris)"),
    census_design
  )
}
