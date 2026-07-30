################################################################################
# Title:        Simulated person-level teaching twin (EUframes_person_sim)
# Purpose:      Generate a fully synthetic person-level dataset that reproduces
#               the EU-frames case's own structure closely enough to carry the
#               original analysis: all four framing dimensions and both
#               composites, each with its own response to unemployment and to
#               growth, individual demographics with their real effects, and a
#               survey weight that corrects a real distortion. No microdata is
#               read here, so the output is committable and redistributable
#               (CC BY 4.0), unlike any extract of the licensed files.
# Reads:        data/EUframes_cy.csv
#               companion/_model-outputs/sim_calibration.csv
#               companion/_model-outputs/sim_calibration_kdist.csv
#               companion/_model-outputs/sim_calibration_person.csv
# Writes:       data/EUframes_person_sim.csv
#               companion/_model-outputs/sim_planted.csv
#               the file named by $SIM_SWEEP, when that is set
# Author:       Chris Moreh (with Claude)
# Last updated: 2026-07-30
################################################################################

library(dplyr)
library(tidyr)
library(readr)
library(purrr)
library(fixest)

# The committed file is the default seed's draw. Override $SIM_SEED to inspect
# a different one – the estimates move, the planted values do not, which is the
# point.
set.seed(as.integer(Sys.getenv("SIM_SEED", "20260727")))

DIMS <- c("cosmo", "util", "comm", "lib")

cal   <- read_csv("companion/_model-outputs/sim_calibration.csv",
                  show_col_types = FALSE)
kdist <- read_csv("companion/_model-outputs/sim_calibration_kdist.csv",
                  show_col_types = FALSE)
pcoef <- read_csv("companion/_model-outputs/sim_calibration_person.csv",
                  show_col_types = FALSE)
# Both lookups are strict on purpose. Every quantity looked up here is one the
# calibration script writes, so a miss means a calibration file has been
# renamed, truncated or duplicated - and a silent fallback would then hand back
# a complete, plausible, quietly different twin with no warning anywhere.
cget <- function(nm) {
  v <- cal$value[cal$parameter == nm]
  if (length(v) != 1)
    stop("sim_calibration.csv: expected exactly one row for '", nm,
         "', found ", length(v), call. = FALSE)
  v
}
pget <- function(out, term) {
  v <- pcoef$value[pcoef$outcome == out & pcoef$term == term]
  if (length(v) != 1)
    stop("sim_calibration_person.csv: expected exactly one row for '", out,
         "' x '", term, "', found ", length(v), call. = FALSE)
  v
}

# A cell has two things going on: what share of its respondents mention
# anything at all, and how the mentions of those who do divide across the four
# dimensions. Both are read off the public panel, because the four dimension
# means and the mentioning rate determine each other exactly.
panel <- read_csv("data/EUframes_cy.csv", show_col_types = FALSE) |>
  mutate(mention = mcosmo + mutil + mcomm + mlib,
         across(all_of(paste0("m", DIMS)), \(x) x / mention,
                .names = "cond_{.col}"))

# --- authored constants -----------------------------------------------------
# Three constants here correspond to nothing measured; everything else in the
# file is estimated from the public panel or calibrated from the licensed
# respondents. NONE of them is an effect on what a respondent answers – every
# individual-level effect in the twin is calibrated. What these govern is who
# ends up in the sample and how many of them there are. A fourth authored
# quantity sits outside this script: lambda_k in sim_calibration.csv, the mean
# mention count, which the recorded shares cannot identify and which phi
# absorbs whatever value it takes.
#
# A respondent's own employment status is deliberately absent. Eurobarometer
# does record occupation, so an individual indicator could in principle be
# calibrated from the licensed file, but nothing here was: an earlier version
# authored one and gave it a prevalence linear in the country's unemployment
# rate, which fused two different constructs. A national unemployment rate is a
# property of a labour market; being out of work is a property of a person, and
# the case's claim is about the first. Wiring them together opened a second path
# from the macro rate into the cell mean that the tuning loop never saw, and so
# split every planted unemployment coefficient into two. Nothing in the twin is
# authored at the individual level now, and each macro slope plants exactly one
# number.
SIM_YOUTH_TILT    <- 0.15      # fieldwork distortion: selection odds per
                               # decade below the mean age
SIM_DISTORT_SLOPE <- 0         # >0 makes the distortion stronger where
                               # unemployment is higher, which biases the macro
                               # slopes themselves unless w1 is used. 0.01
                               # demonstrates it; above 0.03 the tilt turns
                               # negative in the calmest labour markets
SIM_FRACTION      <- 0.10      # cell sizes as a fraction of the real n_cy.
                               # The twin's cell means are averages over this
                               # many people, so they are noisier than the
                               # panel's; at 0.10 a cell-level slope carries a
                               # standard error near a third of the anchor's
                               # size, which the module teaches rather than
                               # hides. Raising it improves precision and the
                               # file size together

# --- calibrated marginals ---------------------------------------------------
PHI      <- cget("phi")
AGE_MEAN <- cget("age_mean"); AGE_SD <- cget("age_sd")
AGE_MIN  <- cget("age_min");  AGE_MAX <- cget("age_max")
FEMALE   <- cget("female_share")
EDU      <- c(le15 = cget("edu_le15"), e16_19 = cget("edu_e16_19"),
              e20plus = cget("edu_e20plus"), studying = cget("edu_studying"))

# --- the cell-level recipe, estimated from the public panel -----------------
# One specification, the same one the day's own anchor uses, fitted to the
# mentioning rate and to each of the four conditional shares. Because the
# conditional shares sum to 1 by construction, an identical linear projection
# gives coefficients that sum to zero across dimensions and residuals that do
# the same: the simplex holds without any dimension being held passive, and
# every dimension keeps its own response to unemployment and to growth.
cell_form <- \(y) as.formula(
  paste0(y, " ~ unemp + growth + factor(year) + factor(cntry)"))
fit_cond <- set_names(DIMS) |>
  map(\(d) lm(cell_form(paste0("cond_m", d)), data = panel))
fit_mention <- lm(cell_form("mention"), data = panel)

country_terms <- \(m) coef(m)[grepl("^factor\\(cntry\\)", names(coef(m)))]
centred_fitted <- function(m) {
  cf <- coef(m)
  yr <- cf[grepl("^factor\\(year\\)", names(cf))]
  yr_map <- setNames(c(0, unname(yr)), sort(unique(panel$year)))
  cf[["(Intercept)"]] + mean(c(0, unname(country_terms(m)))) +
    cf[["unemp"]] * panel$unemp + cf[["growth"]] * panel$growth +
    yr_map[as.character(panel$year)]
}

p_cell    <- centred_fitted(fit_mention)
cond_base <- sapply(DIMS, \(d) centred_fitted(fit_cond[[d]]))

# The tuning target is the panel's own observed-scale coefficient: what a
# participant fits is the dimension score with its zeros in, and the twin
# should reproduce the coefficient the real panel gives under the same model.
target <- map(DIMS, \(d) coef(lm(cell_form(paste0("m", d)), data = panel))) |>
  set_names(DIMS)
tgt <- sapply(c("unemp", "growth"), \(k) map_dbl(target, \(x) x[[k]]))

# An observed dimension mean is the mentioning rate times the conditional
# share, so its slope mixes both responses and is not simply the conditional
# one. Rather than approximate that, tune the conditional slopes until the
# product reproduces the panel's coefficients exactly. The loop runs on the
# 270 expected cell values, with no sampling noise in it, and converges in a
# few passes; the deviations added afterwards are orthogonal to the macro
# series, so they leave these slopes alone.
delta <- matrix(0, 4, 2, dimnames = list(DIMS, c("unemp", "growth")))
for (i in 1:12) {
  cond_now <- cond_base + panel$unemp %o% delta[, "unemp"] +
    panel$growth %o% delta[, "growth"]
  induced <- sapply(DIMS, \(d) {
    y <- p_cell * cond_now[, d]
    coef(lm(cell_form("y"), data = mutate(panel, y = y)))[c("unemp", "growth")]
  }) |> t()
  gap <- tgt - induced
  if (max(abs(gap)) < 1e-9) break
  delta <- delta + gap / mean(p_cell)
  delta <- sweep(delta, 2, colMeans(delta))   # keep the composition closing
}
cond_fixed <- cond_base + panel$unemp %o% delta[, "unemp"] +
  panel$growth %o% delta[, "growth"]

# --- fresh country and cell deviations --------------------------------------
# Drawn rather than reused, so the twin's countries are not copies of the real
# ones, and residualised against the full cell-level design – year included,
# because growth is dominated by common shocks and a draw orthogonal to raw
# growth can still correlate with it once year is absorbed. Three dimensions
# are drawn and the fourth closes the composition.
free       <- DIMS[1:3]
country_sd <- map_dbl(free, \(d) sd(country_terms(fit_cond[[d]])))
cell_cov   <- cov(sapply(free, \(d) residuals(fit_cond[[d]])))

draw_free <- function(n, Sigma) {
  matrix(rnorm(n * ncol(Sigma)), n) %*% chol(Sigma + diag(1e-12, ncol(Sigma)))
}
# Only sd(x) travels from the first argument: what comes back is the fit's
# residual rescaled to that spread. The two mentioning lines below hand the fit
# a second, fresh rnorm draw instead of the vector they scale by. Orthogonality
# to the design holds either way, because the result is a residual of that
# design whichever vector went in; the constructions differ only in whether the
# realised scale and orientation are dependent. Handing over one vector would
# consume half as many draws and so rewrite every random quantity after this
# point, committed twin included, which is why the fit here takes its own.
orthogonalise <- function(x, fit) {
  r <- residuals(fit)
  r / sd(r) * sd(x)
}
cell_design <- \(x) lm(x ~ panel$unemp + panel$growth + factor(panel$year) +
                         factor(panel$cntry))

cmac <- panel |> summarise(u = mean(unemp), g = mean(growth), .by = cntry)
cdev <- draw_free(nrow(cmac), diag(country_sd^2, 3)) |>
  apply(2, \(x) orthogonalise(x, lm(x ~ cmac$u + cmac$g)))
country_dev <- as_tibble(cbind(cdev, -rowSums(cdev)), .name_repair = ~DIMS) |>
  mutate(cntry = cmac$cntry,
         mention = orthogonalise(rnorm(nrow(cmac), 0,
                                       sd(country_terms(fit_mention))),
                                 lm(rnorm(nrow(cmac)) ~ cmac$u + cmac$g)))

edev <- draw_free(nrow(panel), cell_cov) |>
  apply(2, \(x) orthogonalise(x, cell_design(x)))
cell_dev <- as_tibble(cbind(edev, -rowSums(edev)), .name_repair = ~DIMS) |>
  mutate(cntry = panel$cntry, year = panel$year,
         mention = orthogonalise(rnorm(nrow(panel), 0, sigma(fit_mention)),
                                 cell_design(rnorm(nrow(panel)))))

cells <- as_tibble(cond_fixed) |>
  mutate(cntry = panel$cntry, year = panel$year, mention = p_cell) |>
  left_join(country_dev, by = "cntry", suffix = c("", "_c")) |>
  left_join(cell_dev, by = c("cntry", "year"), suffix = c("", "_e")) |>
  mutate(across(all_of(c(DIMS, "mention")),
                \(x) x + get(paste0(cur_column(), "_c")) +
                  get(paste0(cur_column(), "_e")))) |>
  select(cntry, year, all_of(DIMS), mention) |>
  left_join(panel |> select(cntry, year, n_cy, unemp, growth, bailout),
            by = c("cntry", "year")) |>
  mutate(n_sim = pmax(1L, as.integer(round(n_cy * SIM_FRACTION))),
         tilt = SIM_YOUTH_TILT + SIM_DISTORT_SLOPE * (unemp - mean(unemp)))

sim <- cells |> uncount(n_sim)
n_person <- nrow(sim)

# --- respondents ------------------------------------------------------------
# Age is drawn from the calibrated population distribution, tilted towards the
# young by the selection factor exp(-tilt (age - mean)/10). Tilting a normal
# density that way shifts its mean and leaves its spread alone, so the tilted
# population is another truncated normal, sampled here exactly by inverse CDF –
# which matters because w1 is the exact reciprocal of the same factor, and only
# then does weighting recover the untilted population.
age_shift <- (sim$tilt / 10) * AGE_SD^2
sim <- sim |>
  mutate(
    pid   = row_number(),
    age   = as.integer(round(qnorm(
      runif(n_person,
            pnorm(AGE_MIN, AGE_MEAN - age_shift, AGE_SD),
            pnorm(AGE_MAX, AGE_MEAN - age_shift, AGE_SD)),
      AGE_MEAN - age_shift, AGE_SD))),
    age10  = (age - 48) / 10,
    female = rbinom(n_person, 1, FEMALE),
    edu4   = sample(names(EDU), n_person, replace = TRUE, prob = EDU),
    w1_raw = exp(tilt * (age - AGE_MEAN) / 10)
  ) |>
  mutate(w1 = round(w1_raw / mean(w1_raw), 4), .by = c(cntry, year))

# Each respondent's characteristics move them away from their cell, by the
# amounts calibrated from the real respondents. The shifts are centred on the
# population marginals, so a representative sample reproduces the panel's cell
# values and only the deliberate age distortion moves them. Mentioning shifts
# on the logit scale, which keeps every probability inside (0, 1); the
# composition shifts linearly, where the parts are large enough that it stays
# on the simplex.
age10_ref <- (AGE_MEAN + AGE_SD *
  (dnorm((AGE_MIN - AGE_MEAN) / AGE_SD) - dnorm((AGE_MAX - AGE_MEAN) / AGE_SD)) /
  (pnorm(AGE_MAX, AGE_MEAN, AGE_SD) - pnorm(AGE_MIN, AGE_MEAN, AGE_SD)) - 48) / 10

demo_shift <- function(out) {
  pget(out, "age10")           * (sim$age10 - age10_ref) +
    pget(out, "female")        * (sim$female - FEMALE) +
    pget(out, "edu4e16_19")    * ((sim$edu4 == "e16_19")   - EDU[["e16_19"]]) +
    pget(out, "edu4e20plus")   * ((sim$edu4 == "e20plus")  - EDU[["e20plus"]]) +
    pget(out, "edu4studying")  * ((sim$edu4 == "studying") - EDU[["studying"]])
}

p_mention <- plogis(qlogis(pmin(0.999, pmax(0.5, sim$mention))) +
                      demo_shift("mention_logit"))

shift <- sapply(DIMS, demo_shift)
base <- as.matrix(sim[, DIMS])
# A respondent's shift can push a small part below zero, and the Dirichlet
# needs every part positive. Rather than clip each part and renormalise the
# whole composition – which damps the large shifts wherever any part is tight –
# the shift vector is scaled back just far enough to keep the smallest part at
# the floor. The direction of the shift survives, its size is reduced only for
# the respondents who need it, and the share affected is reported below.
FLOOR <- 0.002
# Around seven per cent of cells sit below the floor on their smallest
# dimension once the drawn deviations are added, and none does before them.
# Those cells are lifted first, so the scaling below always has a non-negative
# amount of room to work with. Both shares below are worth watching: the cell
# one says how much of the panel the lift touches, the person one how many
# respondents inherit a lifted cell, and cells are not equally populated.
floor_cells <- mean(apply(as.matrix(cells[, DIMS]), 1, min) < FLOOR)
base_share  <- mean(apply(base, 1, min) < FLOOR)
base <- pmax(base, FLOOR)
base <- base / rowSums(base)
room  <- (base - FLOOR) / pmax(1e-12, -shift)
step  <- pmax(0, pmin(1, apply(ifelse(shift < 0, room, Inf), 1, min)))
clamp_share <- mean(step < 1)
cond <- base + shift * step
stopifnot("composition must stay strictly positive" = all(cond > 0))

# --- the framing instrument -------------------------------------------------
# A respondent either mentions nothing or mentions K items, which divide across
# the four dimensions in the proportions above. Simulating the instrument
# rather than the four scores is what makes the shares sum to one, gives them
# their exact zeros and ones, and lets every dimension carry its own response.
k <- ifelse(rbinom(n_person, 1, p_mention) == 0, 0L,
            sample(kdist$k, n_person, replace = TRUE, prob = kdist$prob))

gam <- matrix(rgamma(n_person * 4, shape = cond * PHI), nrow = n_person)
p <- gam / rowSums(gam)

# Sequential binomials draw the multinomial counts without looping: each
# dimension takes its share of the mentions still unallocated.
c1 <- rbinom(n_person, k, p[, 1])
c2 <- rbinom(n_person, k - c1, pmin(1, p[, 2] / pmax(1e-9, 1 - p[, 1])))
c3 <- rbinom(n_person, k - c1 - c2,
             pmin(1, p[, 3] / pmax(1e-9, 1 - p[, 1] - p[, 2])))
c4 <- k - c1 - c2 - c3

sim <- sim |>
  mutate(k = k,
         cosmo = ifelse(k == 0, 0, c1 / pmax(1, k)),
         util  = ifelse(k == 0, 0, c2 / pmax(1, k)),
         comm  = ifelse(k == 0, 0, c3 / pmax(1, k)),
         lib   = ifelse(k == 0, 0, c4 / pmax(1, k)),
         pos   = cosmo + util,
         neg   = comm + lib)

# --- what the recipe plants -------------------------------------------------
# Every dimension's planted coefficient is the one the real panel yields under
# the same specification, so a model fitted to the twin lands where the same
# model fitted to the real panel lands. The composites inherit the sums of
# their parts, and nothing is induced from any one privileged dimension.
#
# Each macro slope plants exactly one number. The only route from a country's
# unemployment rate to a respondent's answer runs through the cell recipe, and
# the tuning loop above sees that route in full, so there is no second quantity
# for a reader to have to choose between.
slope_of <- function(y) coef(lm(cell_form("y"),
                                data = mutate(panel, y = y)))[["unemp"]]

planted <- map(c(DIMS, "pos", "neg"), \(v) {
  cf <- coef(lm(cell_form(paste0("m", v)), data = panel))
  tibble(outcome        = v,
         planted_unemp  = cf[["unemp"]],
         planted_growth = cf[["growth"]])
}) |>
  list_rbind()

write_csv(planted |> mutate(across(where(is.numeric), \(x) signif(x, 6))),
          "companion/_model-outputs/sim_planted.csv")

# --- validation report (this block IS the script's output) ------------------
sim_cells <- sim |>
  summarise(across(c(cosmo, util, comm, lib, pos, neg), mean),
            unemp = first(unemp), growth = first(growth), .by = c(cntry, year))

comparison <- map(c(DIMS, "pos", "neg"), \(v) {
  cf <- coef(lm(cell_form(v), data = sim_cells))
  tibble(outcome = v, sim_unemp = cf[["unemp"]], sim_growth = cf[["growth"]])
}) |>
  list_rbind() |>
  left_join(planted, by = "outcome") |>
  select(outcome, planted_unemp, sim_unemp, planted_growth, sim_growth) |>
  mutate(across(where(is.numeric), \(x) signif(x, 4)))

# The education reference category has to match the one the calibration used,
# or the contrast recovered here is against a different band and looks wrong.
m_ind <- feols(cosmo ~ age10 + female + edu4 | cntry^year,
               data = sim |>
                 filter(k > 0) |>
                 mutate(edu4 = factor(edu4, levels = names(EDU))))

# Where any gap between the planted coefficient and the simulated slope enters,
# on the cosmopolitan dimension: the tuning target, the tuned cell expectation,
# that expectation carried down to individuals (which adds the covariance
# between mentioning and composition, and the simplex scale-back), and the
# realised draw.
expected_person <- tibble(cntry = sim$cntry, year = sim$year,
                          e = p_mention * cond[, "cosmo"]) |>
  summarise(e = mean(e), .by = c(cntry, year)) |>
  right_join(panel |> select(cntry, year), by = c("cntry", "year"))
slope_trace <- c(
  planted       = tgt["cosmo", "unemp"],
  tuned_cell    = slope_of(p_cell * cond_fixed[, "cosmo"]),
  expected_pers = slope_of(expected_person$e),
  realised      = coef(lm(cell_form("cosmo"), data = sim_cells))[["unemp"]])

report <- list(
  rows         = n_person,
  cells        = n_distinct(sim$cntry, sim$year),
  floor_shares = c(cells_lifted   = round(floor_cells, 4),
                   persons_lifted = round(base_share, 4),
                   persons_scaled = round(clamp_share, 4)),
  mention_rate = c(sim = round(mean(sim$k > 0), 4),
                   real = round(mean(panel$mention), 4)),
  mean_shares  = round(colMeans(sim[c(DIMS, "pos", "neg")]), 4),
  real_shares  = round(colMeans(panel[c(paste0("m", DIMS), "mpos", "mneg")]), 4),
  simplex_ok   = all(abs(rowSums(sim[DIMS][sim$k > 0, ]) - 1) < 1e-9),
  exact_zeros  = round(colMeans(sim[DIMS] == 0), 3),
  macro_slopes = as.data.frame(comparison),
  slope_trace  = signif(slope_trace, 4),
  individual   = rbind(
    calibrated = c(age10 = pget("cosmo", "age10"),
                   female = pget("cosmo", "female"),
                   e20plus = pget("cosmo", "edu4e20plus")),
    recovered  = round(coef(m_ind)[c("age10", "female", "edu4e20plus")], 5)),
  age        = c(unweighted = round(mean(sim$age), 1),
                 weighted = round(weighted.mean(sim$age, sim$w1), 1)),
  # The twin's respondents are drawn in proportion to n_cy, so a person-level
  # mean of theirs targets the panel's respondent-weighted value, not the
  # average of its 270 cell means.
  cosmo_mean = c(unweighted = round(mean(sim$cosmo), 4),
                 weighted = round(weighted.mean(sim$cosmo, sim$w1), 4),
                 real = round(weighted.mean(panel$mcosmo, panel$n_cy), 4))
)
print(report)

# Point $SIM_SWEEP at a file and each run appends its estimates to it: the same
# recipe, a different draw, one row each. That is a simulation study in the
# ordinary sense, and the module reads the result back to show what the
# sampling distribution of a cell-level estimate looks like when the planted
# value is known.
sweep_file <- Sys.getenv("SIM_SWEEP")
if (nzchar(sweep_file)) {
  comparison |>
    select(outcome, sim_unemp, sim_growth) |>
    mutate(seed = Sys.getenv("SIM_SEED", "20260727"), .before = 1) |>
    write_csv(sweep_file, append = file.exists(sweep_file))
}

sim |>
  mutate(across(c(cosmo, util, comm, lib, pos, neg), \(x) round(x, 6))) |>
  select(pid, cntry, year, w1, age, female, edu4,
         cosmo, util, comm, lib, pos, neg, unemp, growth, bailout) |>
  write_csv(Sys.getenv("SIM_OUT", "data/EUframes_person_sim.csv"))
