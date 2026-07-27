################################################################################
# Title:        Calibration parameters for the simulated person-level twin
# Purpose:      Estimate the marginal summaries the twin's generator needs -
#               the composition of the framing instrument, its individual-level
#               dispersion, and the demographic and weight marginals - and
#               write them out as a small committed parameter table. Only
#               aggregate summaries leave this script: every quantity written
#               is of a kind that could be printed in a published appendix
#               table, and no respondent record is written anywhere.
# Reads:        the licensed person-level file, held locally OUTSIDE this repo.
#               Point $EUFRAMES_PERSON_FILE at it; it is never committed and
#               the generator does not need it.
# Writes:       companion/_model-outputs/sim_calibration.csv
#               companion/_model-outputs/sim_calibration_kdist.csv
# Author:       Chris Moreh (with Claude)
# Last updated: 2026-07-27
################################################################################

library(dplyr)
library(readr)
library(purrr)

person_file <- Sys.getenv("EUFRAMES_PERSON_FILE")
stopifnot("Set $EUFRAMES_PERSON_FILE to the local person-level file" =
            nzchar(person_file) && file.exists(person_file))

person <- readRDS(person_file)

# --- the mention process ----------------------------------------------------
# The four dimension scores are shares of one instrument: a respondent's
# mentions in a dimension over their total mentions across the 13 items. They
# therefore sum to 1 for anyone who mentioned anything, and to 0 for anyone who
# mentioned nothing - which is what makes the zero-mention group exactly
# identifiable without touching the item indicators themselves.
mentioners <- person |>
  mutate(total = cosmo + util + comm + lib) |>
  filter(total > 0.5)

p_zero <- 1 - nrow(mentioners) / nrow(person)

mu <- mentioners |>
  summarise(across(c(cosmo, util, comm, lib), mean))

# Individual-level dispersion has to be measured WITHIN country-years: the
# between-cell part is what the generator's random effects reproduce, so
# pooling it in here would double-count it.
var_within <- mentioners |>
  summarise(across(c(cosmo, util, comm, lib), var), n = n(),
            .by = c(cntry, year)) |>
  summarise(across(c(cosmo, util, comm, lib), \(v) weighted.mean(v, n)))

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
# assumption. The identity below treats every respondent in a cell as sharing
# one expected composition, whereas the simulation also lets age and own
# unemployment move it, so the achieved dispersion lands about 9% under the
# target. And the four dimensions' ratios differ by 16% although the identity
# forces them equal, so r_bar averages over a genuine misfit.
k_support <- 1:13
k_probs <- function(lambda) {
  p <- dpois(k_support - 1, lambda)
  p / sum(p)
}
grid <- tibble(lambda = seq(0.6, 6, by = 0.05)) |>
  mutate(
    p = map(lambda, k_probs),
    e_k = map2_dbl(p, list(k_support), \(p, k) sum(p * k)),
    m = map2_dbl(p, list(k_support), \(p, k) sum(p / k)),
    phi = (1 - r_bar) / (r_bar - m)
  ) |>
  filter(phi > 0.2, phi < 50)

stopifnot("no admissible (lambda, phi) pair - inspect r_bar" = nrow(grid) > 0)

chosen <- grid |> slice_min(abs(e_k - 3.4), n = 1)
lambda_k <- chosen$lambda
phi <- chosen$phi

# --- demographic and weight marginals ---------------------------------------
demo <- person |>
  summarise(
    age_mean     = mean(age, na.rm = TRUE),
    age_sd       = sd(age, na.rm = TRUE),
    age_min      = min(age, na.rm = TRUE),
    age_max      = max(age, na.rm = TRUE),
    female_share = mean(female, na.rm = TRUE),
    w1_sd_log    = sd(log(w1[w1 > 0])),
    w1_p99       = quantile(w1, 0.99)
  )

edu <- person |>
  filter(!is.na(edu4)) |>
  count(edu4) |>
  mutate(share = n / sum(n))

params <- bind_rows(
  tibble(parameter = "p_zero_mention", value = p_zero,
         provenance = "share of respondents mentioning no item"),
  tibble(parameter = paste0("mu_", names(mu)), value = as.numeric(mu[1, ]),
         provenance = "mean dimension share among mentioners"),
  tibble(parameter = paste0("var_ratio_", names(mu)), value = var_ratio,
         provenance = "within-cell Var(share) / mu(1-mu)"),
  tibble(parameter = c("lambda_k", "phi", "e_k"),
         value = c(lambda_k, phi, chosen$e_k),
         provenance = c("authored: K = 1 + Poisson(lambda), truncated at 13",
                        "Dirichlet concentration implied by the dispersion",
                        "implied mean mention count")),
  tibble(parameter = names(demo), value = as.numeric(demo[1, ]),
         provenance = "demographic and weight marginal"),
  tibble(parameter = paste0("edu_", edu$edu4), value = edu$share,
         provenance = "education band share, complete cases")
) |>
  mutate(value = round(value, 6))

write_csv(params, "companion/_model-outputs/sim_calibration.csv")
write_csv(tibble(k = k_support, prob = round(k_probs(lambda_k), 6)),
          "companion/_model-outputs/sim_calibration_kdist.csv")

print(params, n = Inf)
