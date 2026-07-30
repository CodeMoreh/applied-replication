# ########################################################################### #
# Title:        Does the twin reproduce the analysis?
# Purpose:      Fit one specification on the real respondents and on the
#               synthetic twin, and put the two coefficient vectors side by
#               side. This is the only thing that establishes a synthetic
#               dataset works: a generator can be built with great care and
#               still fail to carry some feature an estimator depends on, and
#               the way to find out is to run the estimator on both.
#
#               The model is the published specification with its cross-level
#               interactions dropped, which is the form a covariance-preserving
#               synthesis can reproduce and therefore the form the twin may be
#               quoted for.
#
#               The random structure is matched deliberately. The real file has
#               sixteen survey waves across ten years, so its finest cluster is
#               the country-wave; the twin is built on the 270 country-years of
#               the public panel and can have no finer one. Both fits therefore
#               use country and country-year, and the country-wave version is
#               reported separately so the cost of that choice is visible
#               rather than buried.
#
# Reads:        _planning_data/person_level_full.rds   (licensed, local only)
#               data/EUframes_person_full.csv          ($TWIN_FILE overrides)
# Writes:       companion/_model-outputs/twin_validation.csv
#               A coefficient comparison: aggregate, and committed.
# Author:       Chris Moreh
# Last updated: 2026-07-30
# ########################################################################### #

suppressPackageStartupMessages({
  library(dplyr); library(purrr); library(readr); library(tidyr); library(lme4)
})

LEVELS <- list(
  edu3  = c("low", "mid", "high"),
  ses   = c("manual", "self_employed", "manager", "white_collar",
            "house_person", "unemployed", "retired", "student"),
  urban = c("large_town", "rural", "small_town")
)

prep <- function(d) {
  d |>
    mutate(edu3  = factor(edu3,  levels = LEVELS$edu3),
           ses   = factor(ses,   levels = LEVELS$ses),
           urban = factor(urban, levels = LEVELS$urban),
           mage    = age    - mean(age,    na.rm = TRUE),
           munemp  = unemp  - mean(unemp,  na.rm = TRUE),
           mgrowth = growth - mean(growth, na.rm = TRUE),
           cy = paste(cntry, year, sep = "_"))
}

fit_anchor <- function(d, y, cluster = "cy") {
  f <- reformulate(c("female", "mage", "edu3", "ses", "urban",
                     "mgrowth", "munemp", "(1 | cntry)",
                     paste0("(1 | ", cluster, ")")), response = y)
  m <- lmer(f, data = d, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  fx <- summary(m)$coefficients
  tibble(outcome = y, term = rownames(fx),
         estimate = fx[, "Estimate"], se = fx[, "Std. Error"])
}

real <- prep(readRDS("_planning_data/person_level_full.rds"))
twin <- prep(read_csv(Sys.getenv("TWIN_FILE", "data/EUframes_person_full.csv"),
                      show_col_types = FALSE))

cat("real:", nrow(real), "respondents | twin:", nrow(twin), "\n\n")

outcomes <- c("cosmo", "util", "comm", "lib")
cat("Fitting on the real respondents...\n")
r_fit <- map(outcomes, \(y) { cat("  ", y, "\n"); fit_anchor(real, y) }) |>
  list_rbind() |> rename(real = estimate, real_se = se)
cat("Fitting on the twin...\n")
t_fit <- map(outcomes, \(y) { cat("  ", y, "\n"); fit_anchor(twin, y) }) |>
  list_rbind() |> rename(twin = estimate, twin_se = se)

# Two yardsticks, because they answer different questions. Against the real
# fit's own standard error: does the twin reproduce the coefficient to the
# precision 416,698 respondents afford? That is a very demanding test, and
# failing it does not mean the twin is unusable. Against the two-sample
# standard error: is the difference larger than the twin's own sampling noise?
# That is the question a reader quoting a number from the twin actually has.
comp <- r_fit |>
  left_join(t_fit, by = c("outcome", "term")) |>
  mutate(gap = twin - real, gap_in_se = gap / real_se,
         z = gap / sqrt(real_se^2 + twin_se^2))

write_csv(comp |> mutate(across(where(is.numeric), \(x) signif(x, 6))),
          "companion/_model-outputs/twin_validation.csv")

cat("\n--- the macro slopes, which are what the case is about ---\n")
print(comp |> filter(term %in% c("munemp", "mgrowth")) |>
        select(outcome, term, real, twin, gap_in_se) |>
        mutate(across(where(is.numeric), \(x) signif(x, 4))) |>
        as.data.frame(), right = FALSE)

cat("\n--- being unemployed, against manual workers ---\n")
print(comp |> filter(term == "sesunemployed") |>
        select(outcome, real, twin, gap_in_se) |>
        mutate(across(where(is.numeric), \(x) signif(x, 4))) |>
        as.data.frame(), right = FALSE)

cat("\n--- every coefficient, summarised ---\n")
cat("  terms compared:", nrow(comp), "\n")
cat("  within 1 SE of the real estimate:",
    sum(abs(comp$gap_in_se) < 1), "\n")
cat("  within 2 SE:", sum(abs(comp$gap_in_se) < 2), "\n")
worst <- comp |> slice_max(abs(gap_in_se), n = 6)
cat("\n  furthest off:\n")
print(worst |> select(outcome, term, real, twin, gap_in_se) |>
        mutate(across(where(is.numeric), \(x) signif(x, 4))) |>
        as.data.frame(), right = FALSE)
