# R/tax_incentives.R
# Tax-incentive shocks for Malaysia, published by the companion project
# Degetau & Samano (2026), https://github.com/estebandegetau/Fiscal-shocks.
# The file is fetched from its public URL; the `incentive_shocks_url` target
# (format = "url") tracks the server's ETag / Last-Modified headers, so any
# republication upstream invalidates everything downstream.

incentive_shocks_url <- function() {
  "https://www.estebandegetau.com/Fiscal-shocks/data/validated/MY_incentive_shocks_clean.dta"
}

# Columns the downstream analysis relies on
.incentive_shocks_required_cols <- c(
  "shock_id", "act_label", "tax_type", "incentive_category", "direction",
  "rate_from", "rate_to", "delta_pp", "magnitude_note",
  "announced_year", "effective_year", "effective_quarter",
  "motivation", "exogenous"
)

#' Download and validate the tax-incentive shock dataset
#'
#' @param url URL of the Stata file (the `incentive_shocks_url` target)
#' @return Tibble with one row per incentive shock; Stata variable labels kept,
#'   empty strings converted to NA
read_incentive_shocks <- function(url) {
  tmp <- tempfile(fileext = ".dta")
  on.exit(unlink(tmp))
  utils::download.file(url, tmp, mode = "wb", quiet = TRUE)

  shocks <- haven::read_dta(tmp) |>
    mutate(across(where(is.character), haven::zap_empty))

  missing <- setdiff(.incentive_shocks_required_cols, names(shocks))
  if (length(missing) > 0) {
    stop("read_incentive_shocks: missing column(s): ",
         paste(missing, collapse = ", "))
  }
  if (anyDuplicated(shocks$shock_id) > 0) {
    stop("read_incentive_shocks: duplicate shock_id(s)")
  }
  if (nrow(shocks) == 0) {
    stop("read_incentive_shocks: dataset is empty")
  }

  shocks
}
