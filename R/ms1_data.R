# R/ms1_data.R
# Milestone 1 (Malaysia tax incentives): loaders for the firm-level sources.
#   - Osiris (BvD), Malaysian listed companies, annual, MYR
#   - DOSM Manufacturing Census, 2000/2005/2010/2015 waves (establishment panel)
#   - DOSM 30% Economic Census, 2022 cross-section, all sectors
# Plus the statutory CIT rate schedule and the WDI investment benchmark.
# Malaysia-only work stays in ringgit; clean_orbis_data() (R/cleaning.R) is left
# untouched because the cross-country Phase 2 pipeline depends on its USD output.

# Osiris -----------------------------------------------------------------------

#' Read Malaysian firms from the raw Osiris file, keeping only needed columns
#'
#' @param path Path to BvD_firmdata.dta (the `orbis_file` target)
#' @return Tibble, one row per firm-statement; monetary values in MYR thousands
read_osiris_my <- function(path) {
  haven::read_dta(
    path,
    col_select = c(
      OS_ID_NUMBER, NAME, CLOSDATE, MONTHS, CONSOL_CODE, LISTED, CITY,
      CNTRYCDE, ICB, CSICUSCDE, CAICS12COD, INCORDTE_YEAR, UNIT, CURRENCY,
      DATA15515, DATA13068, DATA13077, DATA13004, DATA23000,
      DATA13034, DATA13035, DATA13021
    )
  ) |>
    filter(CNTRYCDE == "MY") |>
    haven::zap_labels() |>
    transmute(
      firm_id = OS_ID_NUMBER,
      firm_name = NAME,
      close_date = as.Date(CLOSDATE),
      months = MONTHS,
      consol_code = CONSOL_CODE,
      listed = LISTED,
      city = CITY,
      icb = ICB,
      sic = as.character(CSICUSCDE),
      naics = as.character(CAICS12COD),
      incorp_year = INCORDTE_YEAR,
      unit = UNIT,
      currency = CURRENCY,
      capex = DATA15515,         # Additions to fixed assets (cash flow)
      ppe = DATA13068,           # Net property, plant & equipment
      total_assets = DATA13077,
      revenues = DATA13004,
      employees = DATA23000,
      ebt = DATA13034,           # Earnings before tax
      income_taxes = DATA13035,  # Income tax expense
      depreciation = DATA13021
    )
}

#' Build a firm-year Osiris panel with investment rate and effective tax rate
#'
#' Duplicate firm-years arise when a firm changes its fiscal year-end. We keep
#' the 12-month statement where one exists, otherwise the latest statement,
#' and flag the year.
#'
#' @param osiris Output of read_osiris_my()
#' @return Tibble, one row per firm-year
clean_osiris_my <- function(osiris) {
  osiris |>
    mutate(year = lubridate::year(close_date)) |>
    add_count(firm_id, year, name = "n_statements") |>
    arrange(firm_id, year, desc(months == 12), desc(close_date)) |>
    distinct(firm_id, year, .keep_all = TRUE) |>
    mutate(
      dup_year = n_statements > 1,
      non_annual = months != 12,
      sic2 = substr(sic, 1, 2),
      capex = abs(capex)  # stored as a cash outflow in some statements
    ) |>
    arrange(firm_id, year) |>
    group_by(firm_id) |>
    mutate(
      ppe_lag = if_else(lag(year) == year - 1, lag(ppe), NA_real_),
      inv_rate = if_else(ppe_lag > 0, capex / ppe_lag, NA_real_)
    ) |>
    ungroup() |>
    # Osiris stores the tax expense as a negative number
    mutate(
      etr = if_else(ebt > 0, -income_taxes / ebt, NA_real_),
      myr = currency == "MYR"
    ) |>
    select(-n_statements)
}

# Manufacturing Census --------------------------------------------------------

#' Stack the four Manufacturing Census waves into an establishment panel
#'
#' The variable dictionary is not available; column meanings are inferred from
#' names. `wave` is the file year; the reference year is undocumented.
#'
#' @param dir Directory holding the *basic.dta and *assets.dta files
#' @return Tibble, one row per establishment-wave
read_census_my <- function(dir) {
  waves <- c("2000", "2005", "2010", "2015")

  basic_cols <- c(
    "id", "misc", "state", "ownership", "percent_ownership", "f46",
    "startdate", "empl", "sales", "output", "exportpercent", "rd"
  )
  asset_cols <- c(
    "id", "total_purchase", "machineryequipment_purchase",
    "computer_purchase", "buildings_purchase", "total_sold",
    "total_bookvaluejan", "total_bookvaluedec", "total_depreciation"
  )

  read_wave <- function(wave) {
    file_of <- function(type) {
      # 2010 files carry the suffix after the type ("2010basic_add3353cos")
      name <- if (wave == "2010") sprintf("2010%s_add3353cos.dta", type)
              else sprintf("%s%s.dta", wave, type)
      file.path(dir, name)
    }
    basic <- haven::read_dta(file_of("basic"), col_select = any_of(basic_cols))
    assets <- haven::read_dta(file_of("assets"), col_select = any_of(asset_cols))

    basic |>
      left_join(assets, by = "id") |>
      haven::zap_labels() |>
      mutate(
        across(any_of(c("id", "misc", "state", "ownership", "f46")),
               as.character),
        wave = as.integer(wave)
      )
  }

  map(waves, read_wave) |>
    bind_rows() |>
    mutate(
      misc3 = substr(misc, 1, 3),
      state = harmonise_my_state(state),
      startdate = suppressWarnings(as.integer(startdate))
    )
}

# 30% Economic Census 2022 -----------------------------------------------------

#' Read the 2022 Economic Census extracts (one xlsx per sector)
#'
#' Header rows differ across files (some have none on row 3) and not every file
#' carries an SME column, so the header row is located by searching for
#' "Sector" and columns are selected by name.
#'
#' @param dir Directory holding the "Data Request_World Bank_*.xlsx" files
#' @return Tibble, one row per establishment, with the source file
read_census30_my <- function(dir) {
  files <- list.files(dir, pattern = "^Data Request.*\\.xlsx$", full.names = TRUE)

  keep <- c(
    id = "Dummy ID", id = "Dummy ID-MOF",
    sector = "Sector", subsector = "Sub-sector", ref_year = "Reference Year",
    msic = "MSIC 2008", state = "State", sme = "SME",
    persons = "Total number of persons engaged",
    fixed_assets = "Value of Fixed Asset", output = "Output",
    value_added = "Value Added"
  )

  read_one <- function(f) {
    peek <- suppressMessages(
      readxl::read_excel(f, sheet = 1, col_names = FALSE, n_max = 10)
    )
    header_row <- which(apply(peek, 1, \(r) any(r == "Sector", na.rm = TRUE)))[1]
    if (is.na(header_row)) {
      warning("read_census30_my: no header row found in ", basename(f))
      return(NULL)
    }
    suppressMessages(readxl::read_excel(
      f, sheet = 1, skip = header_row - 1, col_types = "text",
      .name_repair = "unique"
    )) |>
      select(any_of(keep)) |>
      mutate(
        across(any_of(c("persons", "fixed_assets", "output", "value_added")),
               \(x) suppressWarnings(as.numeric(x))),
        file = str_remove_all(basename(f), "^Data Request_World Bank_|\\.xlsx$")
      )
  }

  sme_labels <- c(`1` = "Micro", `2` = "Small", `3` = "Medium", `4` = "Large")

  map(files, read_one) |>
    compact() |>
    bind_rows() |>
    filter(!is.na(sector)) |>
    mutate(
      state = harmonise_my_state(state),
      sme = str_to_title(coalesce(sme_labels[sme], sme)),
      sme = if_else(sme == "Big", "Large", sme)
    )
}

#' DOSM state codes (from "Senarai Rujukan Kod.xlsx")
#'
#' The Manufacturing Census `state` field takes the same 16 values; we assume
#' it uses these codes (no dictionary available).
my_state_codes <- function() {
  tibble(
    state = sprintf("%02d", 1:16),
    state_name = c(
      "Johor", "Kedah", "Kelantan", "Melaka", "Negeri Sembilan", "Pahang",
      "Pulau Pinang", "Perak", "Perlis", "Selangor", "Terengganu", "Sabah",
      "Sarawak", "WP Kuala Lumpur", "WP Labuan", "WP Putrajaya"
    )
  )
}

#' Map free-text or numeric state entries to two-digit DOSM codes
#'
#' Entries that name no single state (e.g. "Malaysia") become NA.
harmonise_my_state <- function(x) {
  codes <- my_state_codes()
  key <- str_to_lower(x) |>
    str_replace_all("w\\.p\\.|wilayah persekutuan", "wp") |>
    str_squish()
  by_name <- set_names(codes$state, str_to_lower(codes$state_name))
  by_num <- suppressWarnings(sprintf("%02d", as.integer(x)))
  case_when(
    !is.na(by_name[key]) ~ unname(by_name[key]),
    by_num %in% codes$state ~ by_num,
    TRUE ~ NA_character_
  )
}

# Statutory CIT schedule ------------------------------------------------------

#' Malaysian statutory corporate income tax rates by year of assessment
#'
#' Hand-entered from Budget speeches / LHDN public rulings. FOR AUTHOR
#' VERIFICATION: no documented source exists in the repository.
#' `sme_rate` applies to the first tranche of chargeable income of resident
#' SMEs (paid-up capital <= RM2.5m); NA = no separate SME rate.
#'
#' @return Tibble, one row per year of assessment 2000-2024
my_statutory_cit <- function() {
  tibble(year = 2000:2024) |>
    mutate(
      headline_rate = case_when(
        year <= 2006 ~ 28,
        year == 2007 ~ 27,
        year == 2008 ~ 26,
        year <= 2015 ~ 25,
        TRUE ~ 24
      ),
      sme_rate = case_when(
        year <= 2002 ~ NA_real_,
        year <= 2015 ~ 20,
        year == 2016 ~ 19,
        year <= 2018 ~ 18,
        year <= 2022 ~ 17,
        TRUE ~ 15  # first RM150k from YA2023; 17% on the next RM450k
      ),
      source = "Budget speeches / LHDN; to be verified by authors"
    )
}

# WDI benchmark ---------------------------------------------------------------

#' Fetch Malaysian gross fixed capital formation from the World Bank API
#'
#' External network call (convention 5): run only with author approval.
#'
#' @return Tibble with year, indicator and value (current MYR)
fetch_wdi_gfcf_my <- function() {
  indicators <- c(
    gfcf_private = "NE.GDI.FPRV.CN",
    gfcf_total = "NE.GDI.FTOT.CN"
  )
  imap(indicators, \(code, name) {
    url <- sprintf(
      "https://api.worldbank.org/v2/country/MYS/indicator/%s?format=json&per_page=100",
      code
    )
    jsonlite::fromJSON(url)[[2]] |>
      as_tibble() |>
      transmute(year = as.integer(date), indicator = name, value = value)
  }) |>
    bind_rows() |>
    filter(!is.na(value))
}
