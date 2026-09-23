# ########################################################################### #
# Title:        Claim 2 – the education gap, on the respondents and on the
#               education-band panel
# Purpose:      Compute the tables the individual-level module quotes for the
#               second claim of the paper: that high unemployment narrows the
#               gap between high- and low-educated citizens in the way they
#               frame the EU. Three fits per framing dimension. The published
#               model with its cross-level interactions, respondents inside
#               country-waves inside countries, which is the model behind
#               Table 3 Model 1 of the paper. The same interaction with country
#               and year fixed effects, where the level of unemployment is
#               absorbed and only its difference between bands is estimated.
#               And the aggregate route on the committed education-band panel,
#               which anyone can refit, so the page can show that the two
#               levels answer the same interaction question. Every table is an
#               aggregate summary; no respondent record leaves this script.
# Reads:        the respondent file, through _load_respondents.R (licensed,
#               local only)
#               data/EUframes_cy_edu.csv
# Writes:       companion/_model-outputs/claim2_fits.csv
# Author:       Chris Moreh
# Last updated: 2026-09-09
# ########################################################################### #

suppressPackageStartupMessages({
  library(dplyr); library(purrr); library(readr); library(tibble); library(tidyr)
  library(lme4); library(lmerTest); library(fixest)
})

source("companion/_model-outputs/_load_respondents.R")

# Reference categories as published: manual workers, large towns, the lowest
# education band; macro predictors centred on their grand means so that the
# main effect of unemployment is the slope at the reference band, which is how
# the published table reads.
ind <- ind |>
  filter(!is.na(edu3), !is.na(ses), !is.na(urban), !is.na(age), !is.na(female)) |>
  mutate(edu3  = factor(edu3, levels = c("low", "mid", "high")),
         ses   = factor(ses, levels = c("manual", "self_employed", "manager",
                                        "white_collar", "house_person",
                                        "unemployed", "retired", "student")),
         urban = factor(urban, levels = c("large_town", "rural", "small_town")),
         mage    = age - mean(age),
         munemp  = unemp - mean(unemp),
         mgrowth = growth - mean(growth))

DIMS <- c("cosmo", "util", "comm", "lib")

tidy_terms <- function(est, se, stat, p, terms, keep) {
  tibble(term = terms, estimate = est, se = se, statistic = stat, p = p) |>
    filter(term %in% keep)
}
keep <- c("munemp", "mgrowth", "edu3mid", "edu3high",
          "edu3mid:munemp", "edu3high:munemp", "edu3mid:mgrowth", "edu3high:mgrowth",
          "munemp:edu3mid", "munemp:edu3high", "mgrowth:edu3mid", "mgrowth:edu3high")

# --- 1. the published model, interactions included ------------------------------
# Twice: once on the respondents who named at least one item, which is what the
# published Stata code did by dividing by a mentions total with no zero guard
# (its level-1 N of 390,373 is exactly that count), and once with the zero rule
# that the course and the Multi100 reanalyses use. The respondents who named
# nothing are disproportionately low-educated, so the rule bears on the
# education gap and on its interaction, and the page shows both.
fit_published <- function(y, data, rule) {
  f <- reformulate(c("female", "mage", "ses", "urban",
                     "edu3 * munemp", "edu3 * mgrowth",
                     "(1 | cntry)", "(1 | cyw)"), response = y)
  m <- lmer(f, data = data, REML = FALSE,
            control = lmerControl(calc.derivs = FALSE))
  ct <- coef(summary(m))
  tidy_terms(ct[, "Estimate"], ct[, "Std. Error"], ct[, "t value"], ct[, "Pr(>|t|)"],
             rownames(ct), keep) |>
    mutate(outcome = y,
           model = paste0("published: respondents in country-waves in countries, no-opinion ", rule),
           level = "respondent", n = nrow(data))
}
published <- bind_rows(
  map(DIMS, \(y) fit_published(y, filter(ind, k > 0), "dropped")) |> list_rbind(),
  map(DIMS, \(y) fit_published(y, ind, "scored zero")) |> list_rbind()
)

# --- 2. the same interaction under country and year fixed effects ----------------
# Under both no-opinion rules, as above.
fit_fe <- function(y, data, rule) {
  f <- as.formula(paste(y, "~ female + mage + ses + urban + edu3 * munemp + edu3 * mgrowth | cntry + year"))
  m <- feols(f, data = data, vcov = ~cy)
  ct <- coeftable(m)
  tidy_terms(ct[, 1], ct[, 2], ct[, 3], ct[, 4], rownames(ct), keep) |>
    mutate(outcome = y,
           model = paste0("respondents, country and year fixed effects, errors clustered by country-year, no-opinion ", rule),
           level = "respondent", n = nobs(m))
}
fe_resp <- bind_rows(
  map(DIMS, \(y) fit_fe(y, filter(ind, k > 0), "dropped")) |> list_rbind(),
  map(DIMS, \(y) fit_fe(y, ind, "scored zero")) |> list_rbind()
)

# --- 3. the aggregate route on the education-band panel --------------------------
edu <- read_csv("data/EUframes_cy_edu.csv", show_col_types = FALSE) |>
  mutate(edu3 = factor(edu3, levels = c("low", "mid", "high")),
         munemp  = unemp - mean(unemp),
         mgrowth = growth - mean(growth))

fe_cells <- map(DIMS, \(y) {
  f <- as.formula(paste0("m", y, " ~ edu3 * munemp + edu3 * mgrowth | cntry + year"))
  m <- feols(f, data = edu, weights = ~n, vcov = ~cntry)
  ct <- coeftable(m)
  tidy_terms(ct[, 1], ct[, 2], ct[, 3], ct[, 4], rownames(ct), keep) |>
    mutate(outcome = y, model = "education-band cells, country and year fixed effects, weighted by n",
           level = "cell", n = nobs(m))
}) |> list_rbind()

# Interaction terms are named in whichever order the package chose; one name
# per quantity so the page can join on it.
canon <- c("munemp" = "unemployment", "mgrowth" = "growth",
           "edu3mid" = "education: mid", "edu3high" = "education: high",
           "edu3mid:munemp" = "mid x unemployment", "munemp:edu3mid" = "mid x unemployment",
           "edu3high:munemp" = "high x unemployment", "munemp:edu3high" = "high x unemployment",
           "edu3mid:mgrowth" = "mid x growth", "mgrowth:edu3mid" = "mid x growth",
           "edu3high:mgrowth" = "high x growth", "mgrowth:edu3high" = "high x growth")

fits <- bind_rows(published, fe_resp, fe_cells) |>
  mutate(term = unname(canon[term])) |>
  select(outcome, level, model, n, term, estimate, se, statistic, p)

write_csv(fits, "companion/_model-outputs/claim2_fits.csv")
