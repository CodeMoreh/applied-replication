################################################################################
# Title:        Silberzahn et al. (2018) – the 29 teams' effect estimates
# Purpose:      Turn the published crowdsourcing results into the workshop's
#               committed copy, so the deck can rebuild the paper's Figure 3
#               from numbers rather than reproduce the image.
# Reads:        osf.io/gvm2z, component "Results: Data", file
#               "Crowdsourcing Effects in OR with Subgroups.csv" (public;
#               fetched over the network, nothing licensed is involved)
# Writes:       data/silberzahn29.csv
# Author:       Chris Moreh
# Last updated: 2026-07-31
################################################################################

library(dplyr)
library(readr)
library(stringr)

src <- "https://osf.io/download/yprcx/"

# The OSF copy is CR-terminated, which read_csv reads as a single line.
raw <- src |>
  url() |>
  readLines(warn = FALSE) |>
  paste(collapse = "\n") |>
  str_replace_all("\r", "\n") |>
  I() |>
  read_csv(show_col_types = FALSE)

# Two published forks, both worth naming on the slide: the response
# distribution the team assumed, and how it handled the non-independence of
# repeated players and referees. "misc" holds the two teams whose approach
# (Dirichlet-process clustering, Tobit) sits outside the three families.
sz <- raw |>
  transmute(
    team          = Team,
    approach      = str_squish(Analytic.Approach),
    distribution  = recode(Distribution, misc = "Other"),
    clustering    = Non_independence,
    or            = OR,
    or_lo         = OR_lo,
    or_hi         = OR_hi,
    significant   = or_lo > 1 | or_hi < 1
  ) |>
  arrange(distribution, or)

# The paper's own summary, as a guard: anything that moves here means the
# source file changed under us.
stopifnot(
  nrow(sz) == 29,
  round(median(sz$or), 3) == 1.310,
  round(min(sz$or), 3) == 0.888,
  round(max(sz$or), 3) == 2.931,
  sum(sz$significant) == 20
)

write_csv(sz, "data/silberzahn29.csv")
