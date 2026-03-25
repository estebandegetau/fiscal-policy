
# R/functions.R
# Define your R functions here. They will be automatically sourced by targets.
# Organize functions into multiple files as your project grows.

#' Scrape ISO 3166 country codes from iban.com
#'
#' @return A tibble with columns: country, alpha2, alpha3, numeric
scrape_country_codes <- function() {
  page <- rvest::read_html("https://www.iban.com/country-codes")
  tbl <- rvest::html_table(page)[[1]]
  tbl |>
    rename(
      country = Country,
      alpha2 = `Alpha-2 code`,
      alpha3 = `Alpha-3 code`,
      numeric = Numeric
    ) |>
    as_tibble()
}


clean_orbis_data <- function(data, country_codes) {

  codes_to_merge <- country_codes |>
    select(alpha2, alpha3)

  data |>
    select(
        firm_id = OS_ID_NUMBER,
        firm_name = NAME,
        firm_status = STATUS,
        close_date = CLOSDATE,
        listed = LISTED,
        stock_xch = STOCKXCH,
        city = CITY,
        province_code = PROVCODE,
        alpha2 = CNTRYCDE,
        currency = CURRENCY,
        ex_rate_usd = EXRATE_USD,
        total_assets = DATA13077,
        inventory = DATA20010,
        short_term_investment = DATA13051,
        investments = DATA20215,
        loans = DATA21010,
        income_tax = DATA21040, # Income tax payable
        social_expenditure = DATA21045,
        dividends = DATA21050,
        revenues = DATA13004,
        research_development = DATA22020,
        income_taxes = DATA13035, # Income taxes
        net_profit = DATA13045,
        employees = DATA23000,
        profit_per_employee = DATA31040
    ) |>
    left_join(codes_to_merge, join_by(alpha2)) |>
    mutate(
      close_date = lubridate::floor_date(close_date, "months"),
      year = year(close_date)
    ) |>
    slice_max(
      by = c(firm_id, year),
      order_by = close_date,
      n = 1
    ) |>
    # Convert monetary variables from local currency to USD
    mutate(
      across(
        c(investments, total_assets, revenues, net_profit, profit_per_employee,
          research_development, social_expenditure, income_tax,
          income_taxes, inventory, short_term_investment, loans, dividends),
        \(x) x * ex_rate_usd
      )
    )
}


merge_orbis_data <- function(orbis_clean, macro_data) {
  empty_panel <- macro_data |>
    distinct(ccode) |>
    mutate(
      year = list(seq(2000, 2022))
    ) |>
    unnest(year)

  empty_panel |>
    left_join(macro_data, by = join_by(ccode, year)) |>
    left_join(orbis_clean, by = join_by(ccode == alpha3, year))

}
