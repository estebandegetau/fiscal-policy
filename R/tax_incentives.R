# R/tax_incentives.R
# Malaysian fiscal shocks published by the companion project
# Degetau & Samano (2026), https://github.com/estebandegetau/Fiscal-shocks:
#   - tax-incentive shocks (MY_incentive_shocks_clean.dta)
#   - statutory tax shocks: CIT, PIT, consumption (MY_tax_shocks_clean.dta)
# Files are fetched from their public URLs; the `*_url` targets
# (format = "url") track the server's ETag / Last-Modified headers, so any
# republication upstream invalidates everything downstream.

incentive_shocks_url <- function() {
  "https://www.estebandegetau.com/Fiscal-shocks/data/validated/MY_incentive_shocks_clean.dta"
}

tax_shocks_url <- function() {
  "https://www.estebandegetau.com/Fiscal-shocks/data/validated/MY_tax_shocks_clean.dta"
}

# Columns the downstream analysis relies on
.incentive_shocks_required_cols <- c(
  "shock_id", "act_label", "tax_type", "incentive_category", "direction",
  "rate_from", "rate_to", "delta_pp", "magnitude_note",
  "announced_year", "effective_year", "effective_quarter",
  "motivation", "exogenous"
)

.tax_shocks_required_cols <- c(
  "shock_id", "act_label", "tax_type", "direction",
  "rate_from", "rate_to", "delta_pp",
  "announced_year", "effective_year", "motivation", "exogenous"
)

#' Download and validate a Degetau & Samano (2026) shock file
#'
#' @param url URL of the Stata file
#' @param required_cols Columns that must be present
#' @param caller Name used in error messages
#' @return Tibble with one row per shock; Stata variable labels kept,
#'   empty strings converted to NA
.read_ds_shocks <- function(url, required_cols, caller) {
  tmp <- tempfile(fileext = ".dta")
  on.exit(unlink(tmp))
  utils::download.file(url, tmp, mode = "wb", quiet = TRUE)

  shocks <- haven::read_dta(tmp) |>
    mutate(across(where(is.character), haven::zap_empty))

  missing <- setdiff(required_cols, names(shocks))
  if (length(missing) > 0) {
    stop(caller, ": missing column(s): ", paste(missing, collapse = ", "))
  }
  if (anyDuplicated(shocks$shock_id) > 0) {
    stop(caller, ": duplicate shock_id(s)")
  }
  if (nrow(shocks) == 0) {
    stop(caller, ": dataset is empty")
  }

  shocks
}

#' Download and validate the tax-incentive shock dataset
#'
#' @param url URL of the Stata file (the `incentive_shocks_file` target)
read_incentive_shocks <- function(url) {
  .read_ds_shocks(url, .incentive_shocks_required_cols, "read_incentive_shocks")
}

#' Download and validate the statutory tax shock dataset (CIT, PIT, consumption)
#'
#' @param url URL of the Stata file (the `tax_shocks_file` target)
read_tax_shocks <- function(url) {
  .read_ds_shocks(url, .tax_shocks_required_cols, "read_tax_shocks")
}
