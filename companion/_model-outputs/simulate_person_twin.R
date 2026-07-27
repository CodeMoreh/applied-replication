################################################################################
# Title:        Simulated person-level teaching twin (EUframes_person_sim)
# Purpose:      Generate a fully synthetic person-level dataset for the
#               simulation companion module. Marginal distributions are
#               calibrated to the real files through sim_calibration.csv;
#               every association is authored, with its true value named as a
#               constant below. No microdata is read here, so the output is
#               committable and redistributable (CC BY 4.0), unlike any
#               extract of the real Eurobarometer files.
# Reads:        data/EUframes_cy.csv
#               companion/_model-outputs/sim_calibration.csv
#               companion/_model-outputs/sim_calibration_kdist.csv
# Writes:       data/EUframes_person_sim.csv
# Author:       Chris Moreh (with Claude)
# Last updated: 2026-07-27
################################################################################

library(dplyr)
library(tidyr)
library(readr)
library(lmerTest)

# The committed file is the default seed's draw. Override $SIM_SEED to inspect
# a different one - the estimates move, the truths do not, which is the point.
set.seed(as.integer(Sys.getenv("SIM_SEED", "20260727")))

cal   <- read_csv("companion/_model-outputs/sim_calibration.csv",
                  show_col_types = FALSE)
kdist <- read_csv("companion/_model-outputs/sim_calibration_kdist.csv",
                  show_col_types = FALSE)
cget  <- function(nm) cal$value[cal$parameter == nm]

panel <- read_csv("data/EUframes_cy.csv", show_col_types = FALSE)

# --- the named truths -------------------------------------------------------
# The three effects below are stated on the OBSERVED share scale, so a model
# fitted to the file estimates the constant written here with no transformation
# in between; SIM_TARGET_COSMO is a population mean rather than an effect. Only
# the unemployment slope carries over from the real case - it is the
# coefficient of the three-level fit recorded in lmer_3lvl.txt. The
# individual-level effects are authored teaching values, chosen large enough to
# be recoverable at this sample size, and correspond to nothing measured in the
# world.
SIM_B_UNEMP      <- -0.005237  # cell-level unemployment, per point (real fit)
SIM_B_UNEMPLOYED <- -0.05      # authored: being unemployed oneself
SIM_B_AGE10      <- -0.015     # authored: per decade of age
SIM_TARGET_COSMO <- 0.50       # population mean the intercept is centred on

SIM_EMP_PARTICIPATION <- 0.6   # unemployed share of the 15+ population, as a
                               # fraction of the published unemployment rate
SIM_YOUTH_TILT    <- 0.15      # fieldwork distortion: selection odds per
                               # decade below the mean age
SIM_DISTORT_SLOPE <- 0         # >0 makes the distortion stronger where
                               # unemployment is higher, which biases the
                               # unemployment slope itself unless w1 is used.
                               # 0.01 is a good demonstration setting; above
                               # 0.03 the tilt turns negative in the calmest
                               # labour markets and over-selects the old there
SIM_FRACTION      <- 0.05      # cell sizes as a fraction of the real n_cy

# --- calibrated marginals ---------------------------------------------------
P_ZERO   <- cget("p_zero_mention")
PHI      <- cget("phi")
AGE_MEAN <- cget("age_mean")
AGE_SD   <- cget("age_sd")
AGE_MIN  <- cget("age_min")
AGE_MAX  <- cget("age_max")
FEMALE   <- cget("female_share")
MU       <- c(cosmo = cget("mu_cosmo"), util = cget("mu_util"),
              comm = cget("mu_comm"),  lib  = cget("mu_lib"))
EDU      <- c(le15 = cget("edu_le15"), e16_19 = cget("edu_e16_19"),
              e20plus = cget("edu_e20plus"), studying = cget("edu_studying"))

# Shares are drawn among respondents who mention something, so effects on the
# observed scale have to be divided by the mentioning rate to land there.
MENTION_RATE <- 1 - P_ZERO
# The three non-cosmopolitan dimensions divide whatever the cosmopolitan share
# leaves, in the proportions the real instrument shows. That constraint is what
# gives every other outcome its own induced truth.
W_REST <- MU[c("util", "comm", "lib")] / sum(MU[c("util", "comm", "lib")])

# Marginally, a cell's unemployment acts twice: directly, and through the
# unemployed respondents it contains. The direct part is set so that the two
# together reproduce the named total.
b_compositional <- SIM_B_UNEMPLOYED * SIM_EMP_PARTICIPATION / 100
b_contextual    <- SIM_B_UNEMP - b_compositional

# --- cell structure and random effects --------------------------------------
# Variance components come from the public panel, not from microdata: fitting
# the committed cell means gives the between-country and between-cell spread
# that unemployment does not already explain. SD_CY inherits the sampling error
# of the real cell means themselves, so the simulated between-cell spread runs
# a few per cent wider than the panel's true one.
m_cells  <- lmer(mcosmo ~ unemp + (1 | cntry), data = panel)
SD_CNTRY <- as.data.frame(VarCorr(m_cells))$sdcor[1] / MENTION_RATE
SD_CY    <- sigma(m_cells) / MENTION_RATE

# Both sets of effects are drawn and then residualised against unemployment -
# at country level against the country's mean, at cell level within country -
# so that this particular draw carries no accidental confounding. With only 27
# countries an unadjusted draw correlates with the unemployment series often
# enough to move the recovered slope by a third, which would defeat the point
# of a dataset whose truth is supposed to be known. Rescaling after
# residualising restores the intended spread. The projection is exact in the
# unweighted-cell metric; fits that weight cells by size, the multilevel ones
# included, still see a trace worth a few per cent of the slope.
orthogonalise <- function(x, fit) {
  r <- residuals(fit)
  r / sd(r) * sd(x)
}

country_re <- panel |>
  summarise(unemp_bar = mean(unemp), .by = cntry) |>
  mutate(u_raw = rnorm(n(), 0, SD_CNTRY)) |>
  mutate(u_c = orthogonalise(u_raw, lm(u_raw ~ unemp_bar))) |>
  select(cntry, u_c)

cells <- panel |>
  select(cntry, year, n_cy, unemp, growth, bailout) |>
  mutate(
    n_sim = pmax(1L, as.integer(round(n_cy * SIM_FRACTION))),
    u_raw = rnorm(n(), 0, SD_CY)
  ) |>
  mutate(u_cy = orthogonalise(u_raw, lm(u_raw ~ unemp + factor(cntry)))) |>
  left_join(country_re, by = "cntry") |>
  mutate(tilt = SIM_YOUTH_TILT + SIM_DISTORT_SLOPE * (unemp - mean(unemp)))

sim <- cells |> uncount(n_sim)
n_person <- nrow(sim)

# --- respondents ------------------------------------------------------------
# Age is drawn from the calibrated population distribution, tilted towards the
# young by the selection factor exp(-tilt (age - mean)/10). Tilting a normal
# density that way shifts its mean and leaves its spread alone, so the tilted
# population is another truncated normal and can be sampled exactly by inverse
# CDF - which matters because w1 below is the exact inverse of the same factor,
# and only then does weighting recover the untilted population.
age_shift <- (sim$tilt / 10) * AGE_SD^2
lo <- pnorm(AGE_MIN, AGE_MEAN - age_shift, AGE_SD)
hi <- pnorm(AGE_MAX, AGE_MEAN - age_shift, AGE_SD)

sim <- sim |>
  mutate(
    pid        = row_number(),
    age        = as.integer(round(qnorm(runif(n_person, lo, hi),
                                        AGE_MEAN - age_shift, AGE_SD))),
    female     = rbinom(n_person, 1, FEMALE),
    edu4       = sample(names(EDU), n_person, replace = TRUE, prob = EDU),
    unemployed = rbinom(n_person, 1,
                        pmin(0.9, SIM_EMP_PARTICIPATION * unemp / 100)),
    w1_raw     = exp(tilt * (age - AGE_MEAN) / 10)
  ) |>
  mutate(w1 = round(w1_raw / mean(w1_raw), 4), .by = c(cntry, year))

# Age enters the recipe centred on the untilted population mean, so the tilt
# shows up as a difference between the weighted and unweighted sample.
age_ref <- AGE_MEAN + AGE_SD *
  (dnorm((AGE_MIN - AGE_MEAN) / AGE_SD) - dnorm((AGE_MAX - AGE_MEAN) / AGE_SD)) /
  (pnorm(AGE_MAX, AGE_MEAN, AGE_SD) - pnorm(AGE_MIN, AGE_MEAN, AGE_SD))

unemp_bar <- weighted.mean(panel$unemp, panel$n_cy)
mu_intercept <- (SIM_TARGET_COSMO -
                   SIM_B_UNEMP * unemp_bar) / MENTION_RATE

# --- the framing instrument -------------------------------------------------
# Each respondent mentions K items; the four dimension scores are the shares of
# those mentions falling to each dimension. Drawing the shares this way rather
# than as four separate variables is what makes them sum to 1, gives them their
# exact zeros and ones, and links every outcome's truth to every other's.
sim <- sim |>
  mutate(
    mu_cosmo = pmin(pmax(
      mu_intercept +
        (b_contextual * unemp +
           SIM_B_UNEMPLOYED * unemployed +
           SIM_B_AGE10 * (age - age_ref) / 10) / MENTION_RATE +
        u_c + u_cy, 0.02), 0.98),
    k = ifelse(rbinom(n_person, 1, P_ZERO) == 1, 0L,
               sample(kdist$k, n_person, replace = TRUE, prob = kdist$prob))
  )

alpha <- cbind(sim$mu_cosmo, outer(1 - sim$mu_cosmo, W_REST)) * PHI
gam <- matrix(rgamma(n_person * 4, shape = alpha), nrow = n_person)
p <- gam / rowSums(gam)

# Sequential binomials draw the multinomial counts without looping: each
# dimension takes its share of the mentions still unallocated.
c1 <- rbinom(n_person, sim$k, p[, 1])
c2 <- rbinom(n_person, sim$k - c1, pmin(1, p[, 2] / pmax(1e-9, 1 - p[, 1])))
c3 <- rbinom(n_person, sim$k - c1 - c2,
             pmin(1, p[, 3] / pmax(1e-9, 1 - p[, 1] - p[, 2])))
c4 <- sim$k - c1 - c2 - c3

sim <- sim |>
  mutate(
    cosmo = ifelse(k == 0, 0, c1 / pmax(1, k)),
    util  = ifelse(k == 0, 0, c2 / pmax(1, k)),
    comm  = ifelse(k == 0, 0, c3 / pmax(1, k)),
    lib   = ifelse(k == 0, 0, c4 / pmax(1, k)),
    pos   = cosmo + util,
    neg   = comm + lib
  )

# --- the induced truths -----------------------------------------------------
# Only the cosmopolitan slope is set directly. Every other outcome inherits a
# truth from the compositional constraint, with the sign reversed for the
# negative framings - which is the claim-alignment convention, arrived at from
# the data-generating process rather than imposed on it.
truths <- c(
  cosmo = SIM_B_UNEMP,
  util  = -SIM_B_UNEMP * W_REST[["util"]],
  comm  = -SIM_B_UNEMP * W_REST[["comm"]],
  lib   = -SIM_B_UNEMP * W_REST[["lib"]],
  pos   =  SIM_B_UNEMP * (1 - W_REST[["util"]]),
  neg   = -SIM_B_UNEMP * (1 - W_REST[["util"]])
)

# --- validation report (this block IS the script's output) ------------------
cell_means <- sim |>
  summarise(across(c(cosmo, util, comm, lib, pos, neg), mean),
            unemp = first(unemp), .by = c(cntry, year))

recovery <- names(truths) |>
  sapply(\(v) coef(lm(reformulate("unemp", v), data = cell_means))[["unemp"]])

m3     <- lmer(cosmo ~ unemp + (1 | cntry) + (1 | cntry:year), data = sim)
m3_ctx <- lmer(cosmo ~ unemp + unemployed + (1 | cntry) + (1 | cntry:year),
               data = sim)
m_unw  <- lm(cosmo ~ unemp, data = sim)
m_wtd  <- lm(cosmo ~ unemp, data = sim, weights = w1)

report <- list(
  rows             = n_person,
  cells            = n_distinct(sim$cntry, sim$year),
  cell_sizes       = range(count(sim, cntry, year)$n),
  zero_mention     = round(mean(sim$k == 0), 4),
  mean_shares      = round(colMeans(sim[c("cosmo", "util", "comm", "lib",
                                          "pos", "neg")]), 4),
  sums_to_one      = all(abs(with(sim[sim$k > 0, ],
                                  cosmo + util + comm + lib) - 1) < 1e-9),
  pos_neg_exact    = all(abs(with(sim[sim$k > 0, ], pos + neg) - 1) < 1e-9),
  exact_zeros      = round(colMeans(sim[c("cosmo", "util", "comm", "lib")] == 0), 3),
  exact_ones       = round(colMeans(sim[c("cosmo", "util", "comm", "lib")] == 1), 3),
  truths           = round(truths, 6),
  recovered_cell   = round(recovery, 6),
  three_level      = round(fixef(m3)[["unemp"]], 6),
  contextual_truth = round(b_contextual, 6),
  contextual_fit   = round(fixef(m3_ctx)[["unemp"]], 6),
  unemployed_truth = SIM_B_UNEMPLOYED,
  unemployed_fit   = round(fixef(m3_ctx)[["unemployed"]], 4),
  # the target is the POPULATION mean, which the weighted figure estimates; the
  # unweighted one sits above it by the designed age tilt
  target_mean_weighted = SIM_TARGET_COSMO,
  mean_unweighted  = round(mean(sim$cosmo), 4),
  mean_weighted    = round(weighted.mean(sim$cosmo, sim$w1), 4),
  slope_unweighted = round(coef(m_unw)[["unemp"]], 6),
  slope_weighted   = round(coef(m_wtd)[["unemp"]], 6),
  age_population   = round(age_ref, 1),
  age_unweighted   = round(mean(sim$age), 1),
  age_weighted     = round(weighted.mean(sim$age, sim$w1), 1)
)
print(report)

# Point $SIM_SWEEP at a file and each run appends its estimates to it: the same
# recipe, a different draw, one row each. That is a simulation study in the
# ordinary sense, and the module reads the result back to show what the
# sampling distribution of a level-2 estimate looks like when the truth is
# known.
sweep_file <- Sys.getenv("SIM_SWEEP")
if (nzchar(sweep_file)) {
  tibble(
    seed        = Sys.getenv("SIM_SEED", "20260727"),
    cell_ols    = recovery[["cosmo"]],
    three_level = fixef(m3)[["unemp"]],
    contextual  = fixef(m3_ctx)[["unemp"]],
    unemployed  = fixef(m3_ctx)[["unemployed"]],
    mean_unw    = mean(sim$cosmo),
    mean_wtd    = weighted.mean(sim$cosmo, sim$w1)
  ) |>
    write_csv(sweep_file, append = file.exists(sweep_file))
}

sim |>
  mutate(across(c(cosmo, util, comm, lib, pos, neg), \(x) round(x, 6))) |>
  select(pid, cntry, year, w1, age, female, edu4, unemployed,
         cosmo, util, comm, lib, pos, neg, unemp, growth, bailout) |>
  write_csv(Sys.getenv("SIM_OUT", "data/EUframes_person_sim.csv"))
