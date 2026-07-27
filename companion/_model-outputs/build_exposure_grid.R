# ============================================================================ #
# Title        : build_exposure_grid.R
# Purpose      : Builds data/spec_grid_full.csv – the specification grid with
#                the predictor axis added: 2,520 rows. The family universe of
#                1,680 rows (data/spec_grid_family.csv) is imported verbatim
#                (predictor = "unemp"); the growth half adds GDP growth as the
#                claim-carrying predictor (predictor = "growth"), in one form
#                (raw annual %, World Bank series already in the panel), alone
#                or with raw unemployment as co-predictor – the mirror of the
#                canonical grid's unemployment-with-growth cells. A workshop
#                extension: Multi100's Task 2 fixed unemployment as the
#                measure; Task 1 shows three of the five analysts freely chose
#                GDP measures. Affine forms (centred, z) of either variable
#                are deliberately not fitted: they leave t, p and partial r
#                exactly unchanged, so on an r-ranked curve they would only
#                ever duplicate a point that is already there (set ADD_Z_FORM
#                to TRUE to mirror the canonical grid's inert-pair pedagogy).
#                Claim direction for growth predictors is reversed relative to
#                unemployment: the claim predicts POSITIVE growth coefficients
#                on the positive framings. Estimator, weight, df and
#                significance conventions mirror build_family_grid.R and the
#                canonical grid script (RR repo, R/01_spec_grid.R).
# Reads        : data/EUframes_cy.csv, data/spec_grid_family.csv
# Writes       : data/spec_grid_full.csv (2,520 rows)
# Author       : Chris Moreh
# Last updated : 2026-07-18
# ============================================================================ #

suppressPackageStartupMessages({
  library(dplyr); library(purrr); library(tidyr); library(readr)
  library(fixest); library(betareg); library(glmmTMB); library(sandwich); library(lmtest)
})

ADD_Z_FORM <- FALSE   # TRUE adds z-standardised growth twins (identical t/r)

root <- "d:/GitHub/courses/2026_OR_NCL"
panel <- read_csv(file.path(root, "data/EUframes_cy.csv"), show_col_types = FALSE)
fam   <- read_csv(file.path(root, "data/spec_grid_family.csv"), show_col_types = FALSE)

outcomes    <- c("mcosmo", "mutil", "mcomm", "mlib", "mpos", "mneg")
pred_forms  <- if (ADD_Z_FORM) c("raw", "z") else "raw"
copreds     <- c("none", "unemp")
estimators  <- c("fe_twoway", "fe_country", "re", "pooled_cl")
samples     <- c("all", "y2004_2008", "y2009_2013", "no_bailout", "no_GR_ES")
weights_o   <- c("none", "n_cy")
families    <- c("gaussian", "beta")

grid <- expand_grid(outcome = outcomes, pred_form = pred_forms, copredictor = copreds,
                    estimator = estimators, sample = samples, weights = weights_o,
                    family = families) |>
  filter(!(estimator == "re" & weights == "n_cy"))

prep_sample <- function(d, s) {
  switch(s,
    all        = d,
    y2004_2008 = filter(d, year <= 2008),
    y2009_2013 = filter(d, year >= 2009),
    no_bailout = filter(d, !cntry %in% unique(d$cntry[d$bailout == 1])),
    no_GR_ES   = filter(d, !cntry %in% c("GR", "ES")))
}

fit_one <- function(row) {
  d <- panel |> prep_sample(row$sample)
  d$x <- if (row$pred_form == "z") as.numeric(scale(d$growth)) else d$growth
  d$y <- d[[row$outcome]]
  fml_rhs <- if (row$copredictor == "unemp") "x + unemp" else "x"

  out <- tryCatch({
    if (row$family == "gaussian") {
      d$w <- if (row$weights == "n_cy") d$n_cy else rep(1, nrow(d))
      if (row$estimator == "re") {
        # plm-style RE via feols is unavailable; mirror the canonical grid,
        # which fits RE through plm
        m <- plm::plm(as.formula(paste("y ~", fml_rhs)), data = d,
                      index = c("cntry", "year"), model = "random")
        ct <- lmtest::coeftest(m)
        est <- ct["x", "Estimate"]; se <- ct["x", "Std. Error"]
        stat <- ct["x", "t value"]; dfres <- m$df.residual
      } else {
        fml <- switch(row$estimator,
          fe_twoway  = as.formula(paste("y ~", fml_rhs, "| cntry + year")),
          fe_country = as.formula(paste("y ~", fml_rhs, "| cntry")),
          pooled_cl  = as.formula(paste("y ~", fml_rhs)))
        vc <- if (row$estimator == "pooled_cl") ~cntry else "iid"
        m <- feols(fml, data = d, weights = d$w, vcov = vc)
        ct <- coeftable(m)
        est <- ct["x", "Estimate"]; se <- ct["x", "Std. Error"]
        stat <- ct["x", "t value"]
        dfres <- degrees_freedom(m, type = "resid")
      }
    } else {
      w_raw <- if (row$weights == "n_cy") d$n_cy else rep(1, nrow(d))
      d$w <- w_raw * nrow(d) / sum(w_raw)   # normalised case weights
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
        ct <- if (row$estimator == "pooled_cl") {
          coeftest(m, vcov = vcovCL(m, cluster = d$cntry))
        } else {
          coeftest(m)
        }
        est <- ct["x", "Estimate"]; se <- ct["x", "Std. Error"]
        stat <- ct["x", "z value"]
        dfres <- df.residual(m)
      }
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

cat("Fitting", nrow(grid), "growth-predictor specifications...\n")
growth_res <- map(seq_len(nrow(grid)), \(i) fit_one(grid[i, ])) |> bind_rows()
cat("Failed fits:", sum(!growth_res$ok), "\n")

growth_res <- growth_res |> filter(ok) |> select(-ok) |>
  mutate(positive_outcome = outcome %in% c("mcosmo", "mutil", "mpos"),
         sig = abs(statistic) > qt(0.975, df),
         # the claim predicts growth UP -> positive framing UP
         supports_claim = if_else(positive_outcome, estimate > 0, estimate < 0),
         baseline = FALSE,
         predictor = "growth")

full <- bind_rows(fam |> mutate(predictor = "unemp"), growth_res) |>
  relocate(predictor, .after = family)

write_csv(full, file.path(root, "data/spec_grid_full.csv"))

# -- verification report ------------------------------------------------------
cat("rows:", nrow(full), " (unemp", sum(full$predictor == "unemp"),
    "+ growth", sum(full$predictor == "growth"), ")\n")
reimport <- read_csv(file.path(root, "data/spec_grid_full.csv"),
                     show_col_types = FALSE) |>
  filter(predictor == "unemp") |> select(-predictor)
cat("verbatim import check (all.equal vs spec_grid_family.csv):",
    isTRUE(all.equal(as.data.frame(reimport), as.data.frame(fam),
                     tolerance = 1e-12)), "\n")
# the anchor's growth mirror: mpos ~ growth + unemp, two-way FE, all, unweighted
mir <- full |> filter(predictor == "growth", family == "gaussian",
                      outcome == "mpos", copredictor == "unemp",
                      estimator == "fe_twoway", sample == "all", weights == "none")
cat("growth mirror of C6HJR Task 1 (corrected panel): b =",
    signif(mir$estimate, 4), " t =", round(mir$statistic, 3), "\n")
al <- full |> mutate(r_ca = r * if_else(positive_outcome, 1, -1) *
                       if_else(predictor == "growth", -1, 1))
cat("claim-aligned check: supportive growth rows below zero:",
    all(al$r_ca[al$predictor == "growth" & al$supports_claim] < 0), "\n")
shares <- full |> group_by(predictor, family) |>
  summarise(claim_dir = round(mean(supports_claim) * 100, 1),
            sig_share = round(mean(sig) * 100, 1), .groups = "drop")
print(as.data.frame(shares))
