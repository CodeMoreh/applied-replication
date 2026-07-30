# ########################################################################### #
# Title:        Person-level extract carrying the original author's full
#               regression variable set
# Purpose:      Build the individual-level file the simulated twin has to
#               reproduce. The existing extract in the companion article's
#               repository carries age, gender and banded education; the
#               published models also use an eight-category socio-economic
#               position, a three-category urbanisation measure, education as
#               the age at which full-time schooling finished, and left-right
#               self-placement. All four are added here, so the joint
#               distribution the twin must preserve can be estimated over the
#               variables the case actually analyses.
#
#               Variable positions are resolved from the files' own value
#               labels rather than hard-coded, and the resolved mapping is
#               printed: two waves place the occupation item well outside their
#               demographic block (ZA4414 at v71, ZA4819 at v477), so a
#               positional guess would silently read the wrong column.
#
# Reads:        _planning_data/raw/*.dta   (GESIS licensed, local only)
#               data/EUframes_cy.csv
# Writes:       _planning_data/person_level_full.rds
#               NEITHER is committed. The raw files are licensed and the
#               extract is derived microdata; only aggregate summaries and
#               fully synthetic files ever leave this directory.
# Author:       Chris Moreh
# Last updated: 2026-07-30
# ########################################################################### #

suppressPackageStartupMessages({
  library(haven); library(dplyr); library(purrr); library(readr); library(tibble)
})

rawdir <- "_planning_data/raw"

# The wave inventory, item positions and country variables are the verified
# ones from the companion article's build; the covariate columns below are
# resolved by label instead.
waves <- tribble(
  ~file,                ~eb,    ~year, ~cntry_v,   ~items_from, ~items_style, ~w1_v,
  "ZA4056_v1-0-1.dta", "61.0",  2004,  "isocntry",  63,   "v", "v9",
  "ZA4229_v1-1-0.dta", "62.0",  2004,  "v7",        105,  "v", "v8",
  "ZA4411_v1-1-0.dta", "63.4",  2005,  "v7",        89,   "v", "v8",
  "ZA4414_v1-1-0.dta", "64.2",  2005,  "v7",        118,  "v", "v8",
  "ZA4506_v1-0-1.dta", "65.2",  2006,  "v7",        98,   "v", "v8",
  "ZA4530_v2-1-0.dta", "67.2",  2007,  "v7",        130,  "v", "v8",
  "ZA4744_v5-0-0.dta", "69.2",  2008,  "v7",        218,  "v", "v8",
  "ZA4819_v3-0-2.dta", "70.1",  2008,  "v7",        234,  "v", "v8",
  "ZA4994_v3-0-0.dta", "72.4",  2009,  "v7",        221,  "v", "v8",
  "ZA5234_v2-0-1.dta", "73.4",  2010,  "v7",        277,  "v", "v8",
  "ZA5449_v2-2-0.dta", "74.2",  2010,  "v7",        306,  "v", "v8",
  "ZA5481_v2-0-1.dta", "75.3",  2011,  "v7",        315,  "v", "v8",
  "ZA5567_v2-0-1.dta", "76.3",  2011,  "isocntry",  0,    "qa12", "w1",
  "ZA5612_v2-0-0.dta", "77.3",  2012,  "isocntry",  0,    "qa15", "w1",
  "ZA5685_v2-0-0.dta", "78.1",  2012,  "isocntry",  0,    "qa13", "w1",
  "ZA5689_v2-0-0.dta", "79.3",  2013,  "isocntry",  0,    "qa14", "w1"
)

eu27 <- c("AT","BE","BG","CY","CZ","DE","DK","EE","ES","FI","FR","GB","GR",
          "HU","IE","IT","LT","LU","LV","MT","NL","PL","PT","RO","SE","SI","SK")

# Item positions among the 14 meaning items; the Euro item (8) is excluded, so
# the denominator runs over 13. Same grouping as the published scales:
# cosmopolitan = peace, democracy, travel, diversity, say; utilitarian =
# economic prosperity, social protection; communitarian = unemployment, loss of
# identity, crime, borders; libertarian = waste, bureaucracy.
dim_idx <- list(cosmo = c(1, 3, 5, 6, 7), util = c(2, 4),
                comm  = c(9, 12, 13, 14), lib  = c(10, 11))

# The label each covariate is found by. Anchored at the end so the RECODED
# siblings sitting next to each one are never matched instead.
covariate_labels <- c(
  age    = "AGE EXACT$",
  gender = "GENDER$|D10 SEX$",
  edu    = "AGE EDUCATION$",
  occ    = "OCCUPATION OF RESPONDENT$",
  urban  = "TYPE OF COMMUNITY$",
  rile   = "LEFT-RIGHT PLACEMENT$"
)

label_of <- function(d) {
  map_chr(d, function(x) {
    l <- attr(x, "label"); if (is.null(l)) "" else as.character(l)
  })
}

# Resolves one covariate to a column name, or NA when the wave does not carry
# it. Ambiguity is an error rather than a first-match: a second candidate means
# the label pattern has stopped being specific and the mapping needs looking at.
resolve <- function(nm, lab, pattern, wave, what) {
  i <- grep(pattern, lab, ignore.case = TRUE)
  if (length(i) == 0) return(NA_character_)
  if (length(i) > 1)
    stop(wave, ": '", what, "' matched ", length(i), " variables (",
         paste(nm[i], collapse = ", "), ") - tighten the pattern",
         call. = FALSE)
  nm[i]
}

read_wave <- function(w) {
  items <- if (w$items_style == "v") paste0("v", w$items_from:(w$items_from + 13))
           else paste0(w$items_style, "_", 1:14)

  head <- read_dta(file.path(rawdir, w$file), n_max = 0)
  nm <- names(head); lab <- label_of(head)
  cov <- imap_chr(covariate_labels, \(p, k) resolve(nm, lab, p, w$file, k))

  cols <- c(w$cntry_v, items, w$w1_v, na.omit(unname(cov)))
  d <- read_dta(file.path(rawdir, w$file), col_select = all_of(cols))
  d <- d[, cols]
  names(d) <- c("cntry", paste0("it", 1:14), "w1", names(cov)[!is.na(cov)])
  for (miss in names(cov)[is.na(cov)]) d[[miss]] <- NA_real_

  d <- d |> mutate(across(starts_with("it"), \(x) as.numeric(x)))
  vals <- unique(na.omit(unlist(d[paste0("it", 1:14)])))
  stopifnot("framing items not coded 0/1" = all(vals %in% c(0, 1)))

  d |>
    mutate(cntry = as.character(cntry),
           cntry = recode(cntry, "DE-E" = "DE", "DE-W" = "DE",
                          "GB-GBN" = "GB", "GB-NIR" = "GB"),
           eb = w$eb, year = w$year,
           across(c(age, gender, edu, occ, urban, rile, w1), \(x) as.numeric(x))) |>
    filter(cntry %in% eu27)
}

# --- read ------------------------------------------------------------------
cat("Resolving covariates and reading 16 waves...\n")
mapping <- map(seq_len(nrow(waves)), function(i) {
  w <- waves[i, ]
  head <- read_dta(file.path(rawdir, w$file), n_max = 0)
  nm <- names(head); lab <- label_of(head)
  c(file = w$file,
    imap_chr(covariate_labels, \(p, k) resolve(nm, lab, p, w$file, k)))
}) |> bind_rows()
print(as.data.frame(mapping), right = FALSE)

ind <- map(seq_len(nrow(waves)), \(i) read_wave(waves[i, ])) |> bind_rows()
cat("\nperson-level rows:", nrow(ind), "\n")

# --- the published variable constructions ----------------------------------
# Education is the age at which full-time schooling finished. 'Still studying'
# (98) is replaced by the respondent's age, as the published preparation does;
# 'no full-time education' and the refusal codes go to missing. The three-band
# cut is the published one.
#
# Socio-economic position collapses the 18-category occupation item into the
# eight groups the published models use, with the unemployed as their own
# category. The three-category recode Eurobarometer also ships is NOT usable
# here: it folds the unemployed together with students, retirees and house
# persons under 'not working'.
ind <- ind |>
  mutate(
    female = as.integer(gender == 2),
    edu    = if_else(edu %in% c(0, 97, 99), NA_real_, edu),
    edu    = if_else(edu == 98, age, edu),
    edu3   = case_when(edu < 16              ~ "low",
                       edu >= 16 & edu <= 19 ~ "mid",
                       edu > 19              ~ "high",
                       TRUE                  ~ NA_character_),
    ses    = case_when(occ %in% 5:9   ~ "self_employed",
                       occ %in% 10:12 ~ "manager",
                       occ %in% 13:14 ~ "white_collar",
                       occ %in% 15:18 ~ "manual",
                       occ == 1       ~ "house_person",
                       occ == 3       ~ "unemployed",
                       occ == 4       ~ "retired",
                       occ == 2       ~ "student",
                       TRUE           ~ NA_character_),
    unemployed = as.integer(ses == "unemployed"),
    urban  = case_when(urban == 1 ~ "rural", urban == 2 ~ "small_town",
                       urban == 3 ~ "large_town", TRUE ~ NA_character_),
    rile   = if_else(rile %in% 1:10, rile, NA_real_)
  )

# Relative-frequency scales, exactly as published: each dimension's mentions
# over the respondent's total mentions, and zero for anyone who mentions
# nothing.
ind <- ind |>
  mutate(
    s_cosmo = rowSums(across(all_of(paste0("it", dim_idx$cosmo)))),
    s_util  = rowSums(across(all_of(paste0("it", dim_idx$util)))),
    s_comm  = rowSums(across(all_of(paste0("it", dim_idx$comm)))),
    s_lib   = rowSums(across(all_of(paste0("it", dim_idx$lib)))),
    s_all   = rowSums(across(all_of(paste0("it", c(1:7, 9:14))))),
    cosmo = if_else(s_cosmo == 0, 0, s_cosmo / s_all),
    util  = if_else(s_util  == 0, 0, s_util  / s_all),
    comm  = if_else(s_comm  == 0, 0, s_comm  / s_all),
    lib   = if_else(s_lib   == 0, 0, s_lib   / s_all),
    pos   = if_else(s_cosmo + s_util == 0, 0, (s_cosmo + s_util) / s_all),
    neg   = if_else(s_comm  + s_lib  == 0, 0, (s_comm  + s_lib)  / s_all)
  )

# The 13 binary items are kept. They are what the joint synthesis has to
# reproduce: simulating the items preserves the instrument's own correlation
# structure, and the four scales then follow by the construction above rather
# than being modelled as if they were free-standing outcomes.
keep_items <- paste0("it", c(1:7, 9:14))

panel <- read_csv("data/EUframes_cy.csv", show_col_types = FALSE)
ind <- ind |>
  select(cntry, year, eb, w1, all_of(keep_items),
         age, female, edu, edu3, ses, unemployed, urban, rile,
         cosmo, util, comm, lib, pos, neg) |>
  left_join(panel |> select(cntry, year, unemp, growth, bailout),
            by = c("cntry", "year"))

dir.create("_planning_data", showWarnings = FALSE)
saveRDS(ind, "_planning_data/person_level_full.rds")
cat("written: _planning_data/person_level_full.rds (", nrow(ind), "rows )\n")

# --- validation ------------------------------------------------------------
# The aggregation has to reproduce the committed panel, or something in the
# item mapping has moved.
agg <- ind |>
  summarise(mcosmo = mean(cosmo), mutil = mean(util), mcomm = mean(comm),
            mlib = mean(lib), mpos = mean(pos), mneg = mean(neg),
            n_cy = n(), .by = c(cntry, year))
chk <- agg |> inner_join(panel, by = c("cntry", "year"),
                         suffix = c("_new", "_pub"))
cat("\ncells matched:", nrow(chk), "of", nrow(panel), "\n")
walk(c("mcosmo", "mutil", "mcomm", "mlib", "mpos", "mneg"), \(v)
  cat(sprintf("  max |diff| %-7s %.2e\n", v,
              max(abs(chk[[paste0(v, "_new")]] - chk[[paste0(v, "_pub")]])))))
cat("  n_cy identical:", all(chk$n_cy_new == chk$n_cy_pub), "\n")

cat("\ncoverage (share non-missing):\n")
cov_tbl <- ind |>
  summarise(across(c(age, female, edu3, ses, urban, rile, w1),
                   \(x) round(mean(!is.na(x)), 4)))
print(as.data.frame(cov_tbl), right = FALSE)

cat("\nsocio-economic position:\n")
print(ind |> count(ses) |> mutate(share = round(n / sum(n), 4)) |>
        arrange(desc(n)) |> as.data.frame(), right = FALSE)

cat("\nunemployed share by year, against the published rate:\n")
print(ind |>
  summarise(unemployed_share = round(100 * mean(unemployed, na.rm = TRUE), 2),
            published_rate = round(mean(unemp), 2), .by = year) |>
  arrange(year) |> as.data.frame(), right = FALSE)
