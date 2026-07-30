# ########################################################################### #
# Title:        Simulated person-level twin, joint construction
# Purpose:      Generate a synthetic person-level companion to the EU-frames
#               case that reproduces the joint distribution of the framing
#               instrument and the covariates, not merely their separate
#               marginal effects.
#
#               Two stages. A respondent's characteristics come from a latent
#               multivariate normal whose correlation matrix was estimated on
#               the real respondents, with each variable a monotone transform
#               of one coordinate: sex and employment status by a threshold,
#               urbanisation by cutpoints, age, education and left-right
#               through their quantile functions. Occupation beyond the
#               unemployed indicator follows from a conditional model.
#
#               Their answers then come from a multivariate probit. Each of the
#               thirteen framing items has a latent propensity linear in those
#               characteristics, shifted by the respondent's country-year, and
#               carrying a residual correlated with the other twelve. That
#               second stage is what an earlier version of this generator
#               lacked: it drew items from the characteristics' correlation
#               matrix alone, which left occupation with no path to framing at
#               all, and a regression containing occupation and education
#               together then split the association between them differently
#               from the real data. The macro slopes survived that; two thirds
#               of the coefficients did not.
#
#               Country-year structure enters as a shift in the item
#               thresholds. A respondent's four dimension scores are shares of
#               their own mentions, so the map from item rates to cell means is
#               nonlinear and has to be solved rather than set: for each of the
#               270 cells the four dimension shifts are found by Newton
#               iteration against a fixed reference sample.
#
# Reads:        data/EUframes_cy.csv
#               companion/_model-outputs/joint_corr.csv
#               companion/_model-outputs/joint_marginals.csv
#               companion/_model-outputs/joint_ses_conditional.csv
#               companion/_model-outputs/item_probit_coef.csv
#               companion/_model-outputs/item_residual_corr.csv
#               companion/_model-outputs/prevalence_gradient.csv
#               No microdata: every input is either the public panel or a
#               committed aggregate, so this script runs for anyone.
# Writes:       data/EUframes_person_full.csv       ($SIM_OUT overrides)
#               A second twin alongside the older EUframes_person_sim.csv,
#               which the existing simulation module still reads. This one
#               carries the full published variable set and is the file the
#               individual-level analysis works from.
#               the file named by $SIM_SWEEP, when that is set
# Author:       Chris Moreh
# Last updated: 2026-07-30
# ########################################################################### #

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(purrr); library(tibble)
})

set.seed(as.integer(Sys.getenv("SIM_SEED", "20260730")))

# --- authored constants -----------------------------------------------------
# Three constants correspond to nothing measured, and none of them is an effect
# on what a respondent answers: every individual-level effect in the twin is
# estimated. What these govern is who enters the sample and how many.
SIM_FRACTION   <- 0.10
SIM_YOUTH_TILT <- 0.15   # fieldwork distortion, which w1 exists to correct
REF_N          <- 40000  # reference sample for the per-cell threshold solve
OVERDRAW       <- 2.2    # surplus drawn before the selection thinning

DIMS  <- c("cosmo", "util", "comm", "lib")
ITEMS <- paste0("it", c(1:7, 9:14))
DIM_OF <- c(it1 = "cosmo", it3 = "cosmo", it5 = "cosmo", it6 = "cosmo",
            it7 = "cosmo", it2 = "util",  it4 = "util",
            it9 = "comm",  it12 = "comm", it13 = "comm", it14 = "comm",
            it10 = "lib",  it11 = "lib")
URBAN_ORDER <- c("rural", "small_town", "large_town")
SES_LEVELS  <- c("manual", "self_employed", "manager", "white_collar",
                 "house_person", "unemployed", "retired", "student")

# --- inputs -----------------------------------------------------------------
panel <- read_csv("data/EUframes_cy.csv", show_col_types = FALSE)
corr  <- read_csv("companion/_model-outputs/joint_corr.csv", show_col_types = FALSE)
marg  <- read_csv("companion/_model-outputs/joint_marginals.csv", show_col_types = FALSE)
sesc  <- read_csv("companion/_model-outputs/joint_ses_conditional.csv", show_col_types = FALSE)
bcoef <- read_csv("companion/_model-outputs/item_probit_coef.csv", show_col_types = FALSE)
rres  <- read_csv("companion/_model-outputs/item_residual_corr.csv", show_col_types = FALSE)
grad  <- read_csv("companion/_model-outputs/prevalence_gradient.csv", show_col_types = FALSE)

as_matrix <- function(long, a, b, val, vars) {
  M <- diag(length(vars)); dimnames(M) <- list(vars, vars)
  i <- match(long[[a]], vars); j <- match(long[[b]], vars)
  keep <- !is.na(i) & !is.na(j)
  M[cbind(i[keep], j[keep])] <- long[[val]][keep]
  M[cbind(j[keep], i[keep])] <- long[[val]][keep]
  M
}
# A matrix assembled from pairwise estimates need not be positive definite, and
# a bare chol() failure here would be unreadable.
make_chol <- function(M, what) {
  ev <- eigen(M, symmetric = TRUE)
  if (min(ev$values) < 1e-8) {
    M2 <- cov2cor(ev$vectors %*% diag(pmax(ev$values, 1e-8)) %*% t(ev$vectors))
    dimnames(M2) <- dimnames(M)
    cat("  ", what, "nudged positive definite; max change",
        signif(max(abs(M2 - M)), 3), "\n")
    M <- M2
  }
  chol(M)
}

# The characteristics block: the items live in the probit now, not here.
COVARS <- c("age", "edu", "female", "unemployed", "urban_i", "rile")
Lc <- make_chol(as_matrix(corr, "var1", "var2", "r", COVARS), "characteristics")
Le <- make_chol(as_matrix(rres, "item1", "item2", "r", ITEMS), "item residuals")

mget2 <- function(v, k) marg |> filter(variable == v, kind == k)
RATE  <- \(v) mget2(v, "rate")$value[1]
age_q  <- mget2("age", "quantile")$value
edu_q  <- mget2("edu", "quantile")$value
rile_p <- mget2("rile", "share")
urban_p <- mget2("urban", "share") |> arrange(match(level, URBAN_ORDER))
stopifnot("urbanisation categories not as calibrated" =
            identical(urban_p$level, URBAN_ORDER))
P_FEMALE   <- RATE("female")
RILE_COVER <- RATE("rile_observed")
item_rate  <- set_names(map_dbl(ITEMS, RATE), ITEMS)

# The centring constants the probit used. Recovered from the committed
# marginals rather than carried separately: a hundred-point quantile grid gives
# the mean to well inside a tenth of a year, and any residual offset is a
# uniform shift in the linear predictor that the per-cell solve absorbs.
AGE_MEAN  <- mean(age_q)
EDU_MEAN  <- mean(edu_q)
RILE_MEAN <- sum(as.numeric(rile_p$level) * rile_p$value)

B <- bcoef |> pivot_wider(names_from = term, values_from = estimate)
B_ITEMS <- B$item
BM <- as.matrix(B[, setdiff(names(B), "item")])
rownames(BM) <- B_ITEMS
BM <- BM[ITEMS, , drop = FALSE]

# The probit's design matrix, rebuilt from simulated respondents. Column order
# is taken from the coefficient file, so a change to the probit's right-hand
# side needs no edit here beyond adding the column.
design <- function(d) {
  X <- cbind(
    female = d$female,
    age_c = d$age - AGE_MEAN,
    age_c2 = (d$age - AGE_MEAN)^2,
    edu_c = d$edu - EDU_MEAN,
    edu3mid  = as.integer(d$edu >= 16 & d$edu <= 19),
    edu3high = as.integer(d$edu > 19),
    sesself_employed = as.integer(d$ses == "self_employed"),
    sesmanager       = as.integer(d$ses == "manager"),
    seswhite_collar  = as.integer(d$ses == "white_collar"),
    seshouse_person  = as.integer(d$ses == "house_person"),
    sesunemployed    = as.integer(d$ses == "unemployed"),
    sesretired       = as.integer(d$ses == "retired"),
    sesstudent       = as.integer(d$ses == "student"),
    urbanrural      = as.integer(d$urban == "rural"),
    urbansmall_town = as.integer(d$urban == "small_town"),
    rile_c = ifelse(is.na(d$rile), 0, d$rile - RILE_MEAN),
    rile_missing = as.integer(is.na(d$rile)))
  missing <- setdiff(colnames(BM), colnames(X))
  stopifnot("probit design has terms the generator does not build" =
              length(missing) == 0)
  X[, colnames(BM), drop = FALSE]
}

GRAD <- grad$gradient[grad$specification ==
                        "within country and year (two-way fixed effects)"]
cell_unemp_rate <- pmin(0.45, pmax(0.005,
  grad$mean_share[1] + GRAD * (panel$unemp - grad$mean_rate[1])))

# --- drawing respondents ----------------------------------------------------
# Characteristics first, then answers. Selection thinning acts on who is in the
# sample and not on what they say, which is what keeps every conditional
# relationship in the correlation matrix intact.
draw_people <- function(n, unemp_rate, tilt = TRUE) {
  n_draw <- if (tilt) as.integer(ceiling(n * OVERDRAW)) else n
  z <- matrix(rnorm(n_draw * length(COVARS)), n_draw) %*% Lc
  colnames(z) <- COVARS
  u <- pnorm(z)
  qmap <- \(uu, q) as.integer(round(approx(seq_along(q) / (length(q) + 1), q,
                                           xout = uu, rule = 2)$y))
  d <- tibble(
    age = qmap(u[, "age"], age_q), edu = qmap(u[, "edu"], edu_q),
    female = as.integer(z[, "female"] > qnorm(1 - P_FEMALE)),
    unemployed = as.integer(z[, "unemployed"] > qnorm(1 - unemp_rate)),
    urban = as.character(cut(u[, "urban_i"], c(0, cumsum(urban_p$value)),
                             labels = urban_p$level, include.lowest = TRUE)),
    rile = as.integer(cut(u[, "rile"], c(0, cumsum(rile_p$value)),
                          labels = FALSE, include.lowest = TRUE)))
  if (tilt) {
    keep_p <- exp(-SIM_YOUTH_TILT * (d$age - AGE_MEAN) / 10)
    keep_p <- keep_p / max(keep_p)
    keep <- which(runif(n_draw) < keep_p)
    if (length(keep) < n)
      keep <- c(keep, sample(setdiff(seq_len(n_draw), keep), n - length(keep)))
    keep <- keep[seq_len(n)]
    d <- d[keep, ]; d$w1 <- 1 / keep_p[keep]
  } else d$w1 <- 1
  d
}

# Occupation beyond the unemployed indicator. Everyone the characteristics
# block marked unemployed keeps that status; the model decides what the rest do.
ses_cats <- unique(sesc$category)
SB <- sesc |> pivot_wider(names_from = term, values_from = estimate)
assign_ses <- function(d) {
  X <- cbind(`(Intercept)` = 1, age = d$age, `I(age^2)` = d$age^2,
             edu = d$edu, female = d$female,
             urbanrural = as.integer(d$urban == "rural"),
             urbansmall_town = as.integer(d$urban == "small_town"))
  Bm <- as.matrix(SB[, colnames(X)])
  eta <- cbind(0, X %*% t(Bm))
  g <- eta - log(-log(matrix(runif(length(eta)), nrow(eta))))
  out <- c("manual", ses_cats)[max.col(g)]
  ifelse(d$unemployed == 1, "unemployed", out)
}

# --- the per-cell threshold solve -------------------------------------------
# The reference sample carries covariate variation as well as residual noise,
# because the linear predictor differs from respondent to respondent and the
# cell shift has to be solved against the mix that will actually be drawn.
cat("Building the reference sample...\n")
# The reference sample carries the selection tilt too. Without it the solve is
# calibrated against an older sample than the one actually drawn, and since age
# moves the item propensities the whole twin lands short on mentioning.
ref_people <- draw_people(REF_N, mean(cell_unemp_rate), tilt = TRUE)
ref_people$ses <- assign_ses(ref_people)
ref_eta <- design(ref_people) %*% t(BM)
ref_eps <- matrix(rnorm(REF_N * length(ITEMS)), REF_N) %*% Le
ref_lat <- ref_eta + ref_eps
colnames(ref_lat) <- ITEMS

# Item baselines are read off the reference sample so that each item's pooled
# rate matches its calibrated one; the four dimension shifts then move from
# there. The probit absorbed country-year effects, so it supplies no intercept
# and the level has to be set here.
base_tau <- map_dbl(ITEMS, \(j) quantile(ref_lat[, j], 1 - item_rate[[j]]))
names(base_tau) <- ITEMS
dim_index <- map(set_names(DIMS), \(d) which(DIM_OF[ITEMS] == d))

shares_at <- function(delta) {
  m <- sweep(ref_lat, 2, base_tau + delta[DIM_OF[ITEMS]], ">")
  tot <- rowSums(m); ok <- tot > 0
  map_dbl(dim_index, \(ix) {
    s <- numeric(REF_N)
    s[ok] <- rowSums(m[ok, ix, drop = FALSE]) / tot[ok]
    mean(s)
  })
}
jac <- function(delta, f0, h = 0.02) {
  vapply(seq_along(DIMS), \(k) {
    d <- delta; d[k] <- d[k] + h
    (shares_at(d) - f0) / h
  }, numeric(length(DIMS)))
}

# On tolerance. The objective is a step function rather than a smooth one:
# items are thresholded, so moving a threshold changes nothing at all until it
# crosses one of the reference draws. With REF_N draws the finest achievable
# resolution is around one part in REF_N of a share, so asking for much below
# 1e-5 makes the solver oscillate between neighbouring steps and burn its
# iteration budget for no gain. What follows lands two orders below the
# sampling error of a real cell mean, which is the scale that matters.
d0 <- set_names(rep(0, length(DIMS)), DIMS)
solve_cell <- function(target, start = d0, max_it = 40, tol = 5e-5) {
  delta <- start
  f <- shares_at(delta)
  Ji <- solve(jac(delta, f))
  for (i in seq_len(max_it)) {
    gap <- target - f
    if (max(abs(gap)) < tol) break
    # f(delta) ~ f + J (delta_new - delta), and we want f(delta_new) = target,
    # so the step solves J step = gap and ADDS it. Subtracting walks away from
    # the solution, which the cell means then report as total failure rather
    # than as a near miss.
    step <- as.numeric(Ji %*% gap)
    repeat {
      dn <- delta + step; names(dn) <- DIMS
      fn <- shares_at(dn)
      if (max(abs(target - fn)) < max(abs(gap)) || max(abs(step)) < 1e-10) break
      step <- step / 2
    }
    if (max(abs(target - fn)) > 0.5 * max(abs(gap)))
      Ji <- solve(jac(dn, fn))      # progress stalling: relinearise here
    delta <- dn; f <- fn
  }
  list(delta = delta, gap = max(abs(target - f)), iter = i)
}

cat("Solving item thresholds for", nrow(panel), "country-years...\n")
targets <- panel |> select(mcosmo, mutil, mcomm, mlib) |> as.matrix()
sol <- vector("list", nrow(panel)); prev <- d0
for (i in seq_len(nrow(panel))) {
  sol[[i]] <- solve_cell(targets[i, ], start = prev)
  prev <- sol[[i]]$delta
}
worst <- max(map_dbl(sol, "gap"))
cat("  worst residual across cells:", signif(worst, 3),
    "| mean iterations:", round(mean(map_dbl(sol, "iter")), 1), "\n")
# A failed solve produces a complete, plausible-looking file whose cell means
# are simply wrong, so it stops here instead.
stopifnot("threshold solve did not converge" = worst < 5e-4)

# --- draw the twin ----------------------------------------------------------
cat("Drawing respondents...\n")
draw_cell <- function(i) {
  n <- max(1L, as.integer(round(panel$n_cy[i] * SIM_FRACTION)))
  d <- draw_people(n, cell_unemp_rate[i])
  d$ses <- assign_ses(d)
  if (runif(1) > RILE_COVER) d$rile <- NA_integer_   # whole waves lack it
  lat <- design(d) %*% t(BM) +
    matrix(rnorm(n * length(ITEMS)), n) %*% Le
  m <- sweep(lat, 2, base_tau + sol[[i]]$delta[DIM_OF[ITEMS]], ">")
  tot <- rowSums(m); ok <- tot > 0
  for (dm in DIMS) {
    s <- numeric(n)
    s[ok] <- rowSums(m[ok, dim_index[[dm]], drop = FALSE]) / tot[ok]
    d[[dm]] <- s
  }
  d |> mutate(cntry = panel$cntry[i], year = panel$year[i], k = tot)
}

sim <- map(seq_len(nrow(panel)), draw_cell) |> list_rbind() |>
  mutate(pos = cosmo + util, neg = comm + lib,
         edu3 = case_when(edu < 16 ~ "low", edu <= 19 ~ "mid", TRUE ~ "high")) |>
  mutate(w1 = round(w1 / mean(w1), 4), .by = c(cntry, year)) |>
  mutate(pid = row_number())

out <- sim |>
  mutate(across(c(cosmo, util, comm, lib, pos, neg), \(x) round(x, 6))) |>
  left_join(panel |> select(cntry, year, unemp, growth, bailout),
            by = c("cntry", "year")) |>
  select(pid, cntry, year, w1, age, female, edu, edu3, ses, unemployed, urban,
         rile, k, cosmo, util, comm, lib, pos, neg, unemp, growth, bailout)

write_csv(out, Sys.getenv("SIM_OUT", "data/EUframes_person_full.csv"))
cat("written:", Sys.getenv("SIM_OUT", "data/EUframes_person_full.csv"),
    "(", nrow(out), "rows )\n")

# --- what came out ----------------------------------------------------------
agg <- out |>
  summarise(across(all_of(DIMS), mean), .by = c(cntry, year)) |>
  left_join(panel |> select(cntry, year, mcosmo, mutil, mcomm, mlib),
            by = c("cntry", "year"))
# Root-mean-square first: the maximum over 270 cells is a statement about
# sampling rather than about the solve, since each twin cell holds a tenth of
# its real respondents.
cat("\ncell means against the panel:\n")
walk(DIMS, \(d) {
  e <- agg[[d]] - agg[[paste0("m", d)]]
  cat(sprintf("  %-6s rms %.4f | max %.4f\n", d, sqrt(mean(e^2)), max(abs(e))))
})

cat("\nmarginals, twin against calibration:\n")
cat(sprintf("  female       %.4f / %.4f\n", mean(out$female), P_FEMALE))
cat(sprintf("  unemployed   %.4f / %.4f (weighted %.4f)\n",
            mean(out$unemployed), RATE("unemployed"),
            weighted.mean(out$unemployed, out$w1)))
cat(sprintf("  age mean     %.1f (weighted %.1f)\n",
            mean(out$age), weighted.mean(out$age, out$w1)))
cat(sprintf("  mention rate %.4f / %.4f\n", mean(out$k > 0),
            mean(panel$mcosmo + panel$mutil + panel$mcomm + panel$mlib)))
cat("\noccupation shares:\n")
print(out |> count(ses) |> mutate(share = round(n / sum(n), 4)) |>
        arrange(desc(n)) |> as.data.frame(), right = FALSE)

sweep_file <- Sys.getenv("SIM_SWEEP")
if (nzchar(sweep_file)) {
  cell_form <- \(y) as.formula(
    paste0(y, " ~ unemp + growth + factor(year) + factor(cntry)"))
  cells <- out |>
    summarise(across(c(all_of(DIMS), pos, neg), mean),
              unemp = first(unemp), growth = first(growth),
              .by = c(cntry, year))
  map(c(DIMS, "pos", "neg"), \(v) {
    cf <- coef(lm(cell_form(v), data = cells))
    tibble(seed = Sys.getenv("SIM_SEED", "20260730"), outcome = v,
           sim_unemp = cf[["unemp"]], sim_growth = cf[["growth"]])
  }) |> list_rbind() |>
    write_csv(sweep_file, append = file.exists(sweep_file))
}
