################################################################################
# Title:        Calibration parameters for the simulated person-level twin
# Purpose:      Estimate the person-level structure the twin's generator needs
#               - how respondents differ from their country-year in what they
#               mention and in how their mentions divide across the four
#               framing dimensions - and write it out as a small committed
#               parameter table. Only aggregate summaries leave this script:
#               every quantity written is a marginal distribution or a
#               regression coefficient, the kind of thing a published appendix
#               table carries, and no respondent record is written anywhere.
# Reads:        the licensed person-level file, held locally OUTSIDE this repo.
#               Point $EUFRAMES_PERSON_FILE at it; it is never committed, and
#               the generator does not need it.
# Writes:       companion/_model-outputs/sim_calibration.csv
#               companion/_model-outputs/sim_calibration_kdist.csv
#               companion/_model-outputs/sim_calibration_person.csv
# Author:       Chris Moreh (with Claude)
# Last updated: 2026-07-27
################################################################################

library(dplyr)
library(tidyr)
library(readr)
library(purrr)
library(fixest)

person_file <- Sys.getenv("EUFRAMES_PERSON_FILE")
stopifnot("Set $EUFRAMES_PERSON_FILE to the local person-level file" =
            nzchar(person_file) && file.exists(person_file))

person <- readRDS(person_file) |>
  mutate(mention = as.integer(cosmo + util + comm + lib > 0.5),
         cell = paste(cntry, year, sep = "_"),
         age10 = (age - 48) / 10,
         edu4 = factor(edu4, levels = c("le15", "e16_19", "e20plus",
                                        "studying")))

DIMS <- c("cosmo", "util", "comm", "lib")

# --- whether a respondent mentions anything ---------------------------------
# On the logit scale, so that the generator can shift an individual's
# probability without it ever leaving (0, 1). A linear probability model would
# be the natural companion to the composition below, but mentioning something
# is common enough – about 94 per cent – that a linear education effect of the
# size recovered here pushes graduates past a probability of one in 86 per cent
# of cells. Read from the other end, it drives the probability of mentioning
# nothing below zero.
m_mention <- feglm(mention ~ age10 + female + edu4 | cell, data = person,
                   family = binomial())

# --- how the mentions divide, among those who mention -----------------------
# The four conditional shares sum to exactly 1 for every mentioner, so fitting
# them with one identical specification gives coefficients that sum to zero
# across dimensions and residuals that do the same. The simplex holds without
# any dimension being held passive, and each keeps its own response.
# Country-year is absorbed, so these coefficients describe differences between
# respondents inside a cell - exactly the part the generator has to supply.
mentioners <- person |> filter(mention == 1)
m_dims <- set_names(DIMS) |>
  map(\(v) feols(as.formula(paste0(v, " ~ age10 + female + edu4 | cell")),
                 data = mentioners))

person_params <- imap(m_dims, \(m, nm) {
  tibble(outcome = nm, term = names(coef(m)), value = unname(coef(m)))
}) |>
  list_rbind() |>
  bind_rows(tibble(outcome = "mention_logit", term = names(coef(m_mention)),
                   value = unname(coef(m_mention))))

# The sum-to-zero property is a consequence, not an imposition; assert it so a
# future change to the specification cannot break the simplex silently.
zero_check <- person_params |>
  filter(outcome != "mention_logit") |>
  summarise(total = sum(value), .by = term)
stopifnot("dimension coefficients must sum to zero across dimensions" =
            all(abs(zero_check$total) < 1e-9))

# --- individual dispersion in the composition -------------------------------
mu <- mentioners |> summarise(across(all_of(DIMS), mean))

# Measured within country-years, because the between-cell part is what the
# generator reproduces from the public panel.
var_within <- mentioners |>
  summarise(across(all_of(DIMS), var), n = n(), .by = c(cntry, year)) |>
  summarise(across(all_of(DIMS), \(v) weighted.mean(v, n)))

# For a Dirichlet-multinomial with K mentions, concentration phi and mean mu,
# Var(share_j) = mu_j (1 - mu_j) (1 + phi E[1/K]) / (1 + phi), so the ratio
# below is the same for every dimension and pins phi once K is fixed.
var_ratio <- map2_dbl(var_within, mu, \(v, m) v / (m * (1 - m)))
r_bar <- mean(var_ratio)

# K is authored, not recovered: the shares only identify their reduced
# denominator (a respondent scoring 1 on cosmopolitanism alone mentioned one
# item or five, indistinguishably), so the item-level count cannot be read back
# out of them. K = 1 + Poisson(lambda), truncated at 13. Any admissible lambda
# reproduces the dispersion, because phi absorbs it; lambda is therefore pinned
# by plausibility - the mention count closest to 3.4 - and phi follows. Two
# approximations are worth naming, since this is the script's main modelling
# assumption. The identity treats every respondent in a cell as sharing one
# expected composition, whereas the simulation also lets their own
# characteristics move it, so the achieved dispersion lands a little under the
# target. And the four dimensions' ratios differ by about 16% although the
# identity forces them equal, so r_bar averages over a genuine misfit.
k_support <- 1:13
k_probs <- function(lambda) {
  p <- dpois(k_support - 1, lambda)
  p / sum(p)
}
grid <- tibble(lambda = seq(0.6, 6, by = 0.05)) |>
  mutate(p = map(lambda, k_probs),
         e_k = map_dbl(p, \(p) sum(p * k_support)),
         m = map_dbl(p, \(p) sum(p / k_support)),
         phi = (1 - r_bar) / (r_bar - m)) |>
  filter(phi > 0.2, phi < 50)
stopifnot("no admissible (lambda, phi) pair - inspect r_bar" = nrow(grid) > 0)
chosen <- grid |> slice_min(abs(e_k - 3.4), n = 1)

# --- demographic and weight marginals ---------------------------------------
demo <- person |>
  summarise(age_mean = mean(age, na.rm = TRUE),
            age_sd   = sd(age, na.rm = TRUE),
            age_min  = min(age, na.rm = TRUE),
            age_max  = max(age, na.rm = TRUE),
            female_share = mean(female, na.rm = TRUE),
            w1_sd_log = sd(log(w1[w1 > 0])))

edu <- person |>
  filter(!is.na(edu4)) |>
  count(edu4) |>
  mutate(share = n / sum(n))

# w1_sd_log is measured but never read: the twin's weight is the exact
# reciprocal of its own authored age tilt, so its spread follows from
# SIM_YOUTH_TILT and the age distribution and could match a real
# post-stratification weight's only by coincidence. It stays in the table as
# the yardstick that makes that difference visible.
w1_note <- "real weight's log spread, not read by the generator"

params <- bind_rows(
  tibble(parameter = "p_zero_mention", value = 1 - mean(person$mention),
         provenance = "share of respondents mentioning no item"),
  tibble(parameter = paste0("mu_", names(mu)), value = as.numeric(mu[1, ]),
         provenance = "mean dimension share among mentioners"),
  tibble(parameter = paste0("var_ratio_", names(mu)), value = var_ratio,
         provenance = "within-cell Var(share) / mu(1-mu)"),
  tibble(parameter = c("lambda_k", "phi", "e_k"),
         value = c(chosen$lambda, chosen$phi, chosen$e_k),
         provenance = c("authored: K = 1 + Poisson(lambda), truncated at 13",
                        "Dirichlet concentration implied by the dispersion",
                        "implied mean mention count")),
  tibble(parameter = names(demo), value = as.numeric(demo[1, ]),
         provenance = if_else(names(demo) == "w1_sd_log", w1_note,
                              "demographic and weight marginal")),
  tibble(parameter = paste0("edu_", edu$edu4), value = edu$share,
         provenance = "education band share, complete cases")
) |>
  mutate(value = round(value, 6))

write_csv(params, "companion/_model-outputs/sim_calibration.csv")
write_csv(tibble(k = k_support, prob = round(k_probs(chosen$lambda), 6)),
          "companion/_model-outputs/sim_calibration_kdist.csv")
write_csv(person_params |> mutate(value = round(value, 6)),
          "companion/_model-outputs/sim_calibration_person.csv")

print(params, n = Inf)
print(person_params, n = Inf)
