# ########################################################################### #
# Title:        Multilevel reference numbers from the real respondents
# Purpose:      Capture what the licensed file gives for the models the
#               individual-level companion page runs live on the twin, so the
#               page can show both and the reader can see whether they agree.
#               The statistics module already displays these fits as captured
#               text; what is written here is the numbers behind them, in a
#               form a page can read and compare against.
#
#               Three models, in the order the argument needs them: country
#               level only, which counts every respondent as fresh information
#               about a predictor that varies 270 times; country and
#               country-year, which does not; and a random slope, which asks
#               whether the effect differs by country.
#
# Reads:        _planning_data/person_level_full.rds   (licensed, local only)
# Writes:       companion/_model-outputs/person_multilevel_real.csv
#               Coefficients, variance components and degrees of freedom.
#               Aggregate, and committed.
# Author:       Chris Moreh
# Last updated: 2026-07-31
# ########################################################################### #

suppressPackageStartupMessages({
  library(dplyr); library(purrr); library(readr); library(lmerTest)
})

ind <- readRDS("_planning_data/person_level_full.rds") |>
  mutate(cy = paste(cntry, year, sep = "_"))

specs <- list(
  two_level   = cosmo ~ unemp + (1 | cntry),
  three_level = cosmo ~ unemp + (1 | cntry) + (1 | cy),
  slopes      = cosmo ~ unemp + (1 + unemp | cntry) + (1 | cy)
)

summarise_fit <- function(m, label) {
  p  <- summary(m)$coefficients
  vc <- as.data.frame(VarCorr(m))
  bind_rows(
    tibble(model = label, kind = "fixed", term = rownames(p),
           value = p[, "Estimate"], se = p[, "Std. Error"],
           statistic = p[, "t value"], df = p[, "df"]),
    tibble(model = label, kind = "random",
           term = ifelse(is.na(vc$var2), paste0(vc$grp, ": ", vc$var1),
                         paste0(vc$grp, ": ", vc$var1, " ~ ", vc$var2)),
           value = vc$sdcor, se = NA, statistic = NA, df = NA),
    tibble(model = label, kind = "n", term = c("respondents", "cells", "countries"),
           value = c(nobs(m), n_distinct(ind$cy), n_distinct(ind$cntry)),
           se = NA, statistic = NA, df = NA))
}

out <- imap(specs, function(f, nm) {
  cat("fitting", nm, "...\n")
  summarise_fit(lmer(f, data = ind), nm)
}) |> list_rbind()

write_csv(out |> mutate(across(where(is.numeric), \(x) signif(x, 6))),
          "companion/_model-outputs/person_multilevel_real.csv")

cat("\n--- what the levels do to the evidence ---\n")
print(out |> filter(kind == "fixed", term == "unemp") |>
        select(model, value, se, statistic, df) |>
        mutate(across(where(is.numeric), \(x) signif(x, 4))) |>
        as.data.frame(), right = FALSE)
cat("\n--- variance components ---\n")
print(out |> filter(kind == "random") |>
        select(model, term, value) |>
        mutate(value = signif(value, 4)) |> as.data.frame(), right = FALSE)
