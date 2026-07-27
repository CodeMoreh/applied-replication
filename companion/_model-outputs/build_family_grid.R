# ============================================================================ #
# Title        : build_family_grid.R
# Purpose      : Builds data/spec_grid_family.csv – the specification grid with
#                the outcome-family axis added: the family universe of 1,680
#                rows. The Gaussian half (840 rows) is imported verbatim from
#                the committed spec_grid.csv, which the companion Replication
#                Research project computed; the beta half (840 rows) is the
#                family twin of every cell, fitted here by logit-link beta
#                regression. Predictor forms are raw and log only – centred
#                and z-standardised forms are affine-inert twins of raw and
#                log (identical t, r, p) and are not fitted or stored. The
#                family axis is not part of the Multi100 menu. In the
#                companion article the aggregated family grid is disclosed as
#                Phase-1 prior work and a person-level family twin is
#                registered; this workshop copy is the verified sibling of the
#                canonical build (RR repo, R/07_family_grid.R), retained so
#                the workshop pipeline stands alone.
#                Conventions mirror the canonical grid script (RR repo,
#                R/01_spec_grid.R): same six axes (outcome, pred_form,
#                copredictor, estimator, sample, weights), same re-with-weights
#                exclusion, statistic/df under each estimator's own definition,
#                r = stat / sqrt(stat^2 + df), CI and significance via qt.
#                Beta-half estimator mapping: pooled_cl and the two FE designs
#                use betareg (FE via country/year dummies) – pooled_cl with
#                cluster-robust (sandwich vcovCL, by country) z-statistics,
#                FE with model-based z; re uses glmmTMB's beta family with a
#                country random intercept (df = n minus fixed coefficients,
#                mirroring the plm rule). n_cy weights enter betareg as case
#                weights normalised to sum to the sample size, so they act as
#                relative precision weights rather than inflating the
#                likelihood's effective N.
# Reads        : data/EUframes_cy.csv, data/spec_grid.csv
# Writes       : data/spec_grid_family.csv (the family universe of 1,680 rows)
# Author       : Chris Moreh
# Last updated : 2026-07-18
# ============================================================================ #

suppressPackageStartupMessages({
  library(dplyr); library(purrr); library(tidyr); library(readr)
  library(betareg); library(glmmTMB); library(sandwich); library(lmtest)
})

root <- "d:/GitHub/courses/2026_OR_NCL"
panel <- read_csv(file.path(root, "data/EUframes_cy.csv"), show_col_types = FALSE)
gauss <- read_csv(file.path(root, "data/spec_grid.csv"), show_col_types = FALSE)

outcomes    <- c("mcosmo", "mutil", "mcomm", "mlib", "mpos", "mneg")
pred_forms  <- c("raw", "log")
copreds     <- c("none", "growth")
estimators  <- c("fe_twoway", "fe_country", "re", "pooled_cl")
samples     <- c("all", "y2004_2008", "y2009_2013", "no_bailout", "no_GR_ES")
weights_o   <- c("none", "n_cy")

grid <- expand_grid(outcome = outcomes, pred_form = pred_forms, copredictor = copreds,
                    estimator = estimators, sample = samples, weights = weights_o) |>
  filter(!(estimator == "re" & weights == "n_cy"))

prep_sample <- function(d, s) {
  switch(s,
    all        = d,
    y2004_2008 = filter(d, year <= 2008),
    y2009_2013 = filter(d, year >= 2009),
    no_bailout = filter(d, !cntry %in% unique(d$cntry[d$bailout == 1])),
    no_GR_ES   = filter(d, !cntry %in% c("GR", "ES")))
}

prep_predictor <- function(d, form) {
  d$x <- switch(form,
    raw = d$unemp,
    log = log(d$unemp))
  d
}

fit_one_beta <- function(row) {
  d <- panel |> prep_sample(row$sample) |> prep_predictor(row$pred_form)
  d$y <- d[[row$outcome]]
  w_raw <- if (row$weights == "n_cy") d$n_cy else rep(1, nrow(d))
  d$w <- w_raw * nrow(d) / sum(w_raw)   # normalised case weights
  fml_rhs <- if (row$copredictor == "growth") "x + growth" else "x"

  out <- tryCatch({
    if (row$estimator == "re") {
      m <- glmmTMB(as.formula(paste("y ~", fml_rhs, "+ (1 | cntry)")),
                   family = beta_family(), data = d)
      s <- summary(m)$coefficients$cond
      est <- s["x", 1]; se <- s["x", 2]; stat <- s["x", 3]
      dfres <- nrow(d) - length(fixef(m)$cond)
    } else {
      fml <- switch(row$estimator,
        fe_twoway  = as.formula(paste("y ~", fml_rhs, "+ factor(cntry) + factor(year)")),
        fe_country = as.formula(paste("y ~", fml_rhs, "+ factor(cntry)")),
        pooled_cl  = as.formula(paste("y ~", fml_rhs)))
      m <- betareg(fml, data = d, weights = d$w)
      if (row$estimator == "pooled_cl") {
        ct <- coeftest(m, vcov = vcovCL(m, cluster = d$cntry))
      } else {
        ct <- coeftest(m)
      }
      est <- ct["x", "Estimate"]; se <- ct["x", "Std. Error"]; stat <- ct["x", "z value"]
      dfres <- df.residual(m)
    }
    r <- stat / sqrt(stat^2 + dfres)
    tibble(estimate = est, se = se, statistic = stat, df = dfres,
           n = nrow(d), r = r,
           conf_low = est - qt(0.975, dfres) * se,
           conf_high = est + qt(0.975, dfres) * se,
           ok = TRUE)
  }, error = function(e) tibble(estimate = NA, se = NA, statistic = NA, df = NA,
                                n = NA, r = NA, conf_low = NA, conf_high = NA, ok = FALSE))
  bind_cols(as_tibble(row), out)
}

cat("Fitting", nrow(grid), "beta-family specifications...\n")
beta_res <- map(seq_len(nrow(grid)), \(i) fit_one_beta(grid[i, ])) |> bind_rows()
cat("Failed fits:", sum(!beta_res$ok), "\n")

beta_res <- beta_res |> filter(ok) |> select(-ok) |>
  mutate(positive_outcome = outcome %in% c("mcosmo", "mutil", "mpos"),
         sig = abs(statistic) > qt(0.975, df),
         supports_claim = if_else(positive_outcome, estimate < 0, estimate > 0),
         baseline = FALSE,   # the anchor cell is Gaussian; the beta twin is not it
         family = "beta")

full <- bind_rows(gauss |> mutate(family = "gaussian"), beta_res) |>
  relocate(family, .after = weights)

write_csv(full, file.path(root, "data/spec_grid_family.csv"))

# -- computed facts reported for the teaching pages ---------------------------
bg <- full |> filter(family == "gaussian", baseline)
bb <- full |> filter(family == "beta", outcome == "mcosmo", pred_form == "raw",
                     copredictor == "none", estimator == "fe_twoway",
                     sample == "all", weights == "none")
cat("rows:", nrow(full), " (gaussian", sum(full$family == "gaussian"),
    "+ beta", sum(full$family == "beta"), ")\n")
cat("gaussian anchor : t =", round(bg$statistic, 3), " r =", round(bg$r, 3), "\n")
cat("beta twin       : z =", round(bb$statistic, 3), " r =", round(bb$r, 3),
    " b(logit) =", round(bb$estimate, 5), "\n")
shares <- full |> group_by(family) |>
  summarise(claim_dir = mean(supports_claim) * 100,
            sig_and_dir = mean(supports_claim & sig) * 100, .groups = "drop")
print(as.data.frame(shares))
mc <- full |> filter(outcome == "mcosmo")
cat("mcosmo universe wrong-sign by family:\n")
print(mc |> filter(!supports_claim) |> count(family, estimator) |> as.data.frame())
