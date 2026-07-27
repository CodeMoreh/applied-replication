# ============================================================================ #
# Title        : fit_models.R
# Purpose      : Fits the person-level and Bayesian exhibit models whose
#                printed summaries are displayed verbatim in
#                companion/stats-methods.qmd, capturing each output to a text
#                artifact in this folder. These are illustrative single fits
#                for teaching – NOT the registered Phase-2 analyses of the
#                companion Replication Research project, which remain
#                uncomputed until its OSF registration is filed.
# Reads        : D:/GitHub/papers/26-RR-teney-multiverse/data_private/person_level.rds
#                (GESIS-licensed person-level rebuild, 416,698 respondents –
#                exists only on the facilitator's machine, never in any repo)
#                data/EUframes_cy.csv (committed country-year aggregates)
# Writes       : companion/_model-outputs/*.txt (captured model summaries –
#                aggregate statistical output only, no microdata)
#                _planning_data/brms_panel.rds, _planning_data/ordbetareg_sub.rds
#                (fitted Bayesian objects, kept locally so the summaries can be
#                re-printed without resampling; gitignored – they embed data)
# Author       : Chris Moreh
# Last updated : 2026-07-17
# ============================================================================ #

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lmerTest)   # loads lme4; adds Satterthwaite df to lmer summaries
  library(survey)
  library(WeMix)
  library(glmmTMB)
  library(brms)
  library(ordbetareg)
})

options(width = 88)
outdir <- "d:/GitHub/courses/2026_OR_NCL/companion/_model-outputs"

person <- readRDS("D:/GitHub/papers/26-RR-teney-multiverse/data_private/person_level.rds") |>
  as.data.frame()
euframes <- read_csv("d:/GitHub/courses/2026_OR_NCL/data/EUframes_cy.csv",
                  show_col_types = FALSE)

save_out <- function(lines, file) writeLines(lines, file.path(outdir, file))

# --- 1. logistic GLM – mentions at least one cosmopolitan meaning ----------- #
m_logit <- glm(I(cosmo > 0) ~ unemp, family = binomial(), data = person)
save_out(capture.output(summary(m_logit)), "glm_logit.txt")
cat("logit  b_unemp =", round(coef(m_logit)["unemp"], 5), "\n")

# --- 2. design-weighted GLM via the survey package --------------------------- #
des <- svydesign(ids = ~1, weights = ~w1, data = person)
m_svy <- svyglm(cosmo ~ unemp, design = des)
save_out(capture.output(summary(m_svy)), "svyglm.txt")
cat("svyglm b_unemp =", round(coef(m_svy)["unemp"], 5), "\n")

# --- 3. two-level random intercepts – respondents in countries --------------- #
m_l2 <- lmer(cosmo ~ unemp + (1 | cntry), data = person)
save_out(capture.output(summary(m_l2)), "lmer_2lvl.txt")
cat("lmer2  b_unemp =", round(fixef(m_l2)["unemp"], 5), "\n")

# --- 4. three-level random intercepts – respondents in country-years in
#        countries (the structure used in the original author's (OA) anchor
#        model) --------------------------------------------------------------- #
m_l3 <- lmer(cosmo ~ unemp + (1 | cntry) + (1 | cntry:year), data = person)
save_out(capture.output(summary(m_l3)), "lmer_3lvl.txt")
cat("lmer3  b_unemp =", round(fixef(m_l3)["unemp"], 5), "\n")

# --- 5. random slopes – the unemployment effect varies by country ------------ #
m_rs <- tryCatch(
  lmer(cosmo ~ unemp + (1 + unemp | cntry) + (1 | cntry:year), data = person),
  error = function(e) e
)
if (inherits(m_rs, "error")) {
  save_out(paste("random-slope fit failed:", conditionMessage(m_rs)), "lmer_slopes.txt")
} else {
  save_out(capture.output(summary(m_rs)), "lmer_slopes.txt")
  cat("lmerRS b_unemp =", round(fixef(m_rs)["unemp"], 5), "\n")
}

# --- 6. weighted multilevel via WeMix (level-1 nation weight W1) ------------- #
person <- person |>
  mutate(w_lvl2 = 1)   # unit weight at the country level – weighting at level 1 only
m_wemix <- mix(cosmo ~ unemp + (1 | cntry), data = person,
               weights = c("w1", "w_lvl2"))
save_out(capture.output(summary(m_wemix)), "wemix_2lvl.txt")
cat("wemix  b_unemp =", round(m_wemix$coef["unemp"], 5), "\n")

# --- 7. frequentist ordered beta regression on the full microdata ------------ #
m_tmb <- glmmTMB(cosmo ~ unemp + (1 | cntry) + (1 | cntry:year),
                 family = ordbeta(), data = person)
save_out(capture.output(summary(m_tmb)), "glmmtmb_ordbeta.txt")
cat("glmmTMB(ordbeta) b_unemp =", round(fixef(m_tmb)$cond["unemp"], 5), "\n")

# --- 8. Bayesian hierarchical model on the committed aggregate panel --------- #
m_brm <- brm(mcosmo ~ unemp + (1 | cntry) + (1 | year), data = euframes,
             backend = "cmdstanr", chains = 4, cores = 4, iter = 4000,
             seed = 2026, refresh = 0, silent = 2)
save_out(capture.output(print(summary(m_brm), digits = 4)), "brms_panel.txt")
save_out(capture.output(print(prior_summary(m_brm))), "brms_priors.txt")
saveRDS(m_brm, "d:/GitHub/courses/2026_OR_NCL/_planning_data/brms_panel.rds")
cat("brms   b_unemp =", round(fixef(m_brm)["unemp", "Estimate"], 5), "\n")

# --- 9. Bayesian ordered beta regression (ordbetareg wraps brms) -------------
#     Fitted on a 20,000-respondent random subsample: the ordered-beta
#     likelihood on all 416,698 rows would sample for many hours, and the
#     exhibit's purpose is the shape of the output, not a production estimate.
set.seed(2026)
person_sub <- slice_sample(person, n = 20000)
m_ord <- ordbetareg(cosmo ~ unemp + (1 | cntry), data = person_sub,
                    true_bounds = c(0, 1), backend = "cmdstanr",
                    chains = 4, cores = 4, iter = 2000, seed = 2026,
                    refresh = 0, silent = 2)
save_out(capture.output(print(summary(m_ord), digits = 4)), "ordbetareg_sub.txt")
saveRDS(m_ord, "d:/GitHub/courses/2026_OR_NCL/_planning_data/ordbetareg_sub.rds")
cat("ordbetareg b_unemp =",
    round(fixef(m_ord)["unemp", "Estimate"], 5), "\n")

# --- 10. person-level outcome distribution (aggregate counts only) ----------- #
person |>
  count(cosmo, name = "n_respondents") |>
  write_csv(file.path(outdir, "cosmo_dist.csv"))

# --- provenance manifest ------------------------------------------------------ #
save_out(c(
  paste("Fitted:", format(Sys.time(), "%Y-%m-%d %H:%M")),
  paste("R", getRversion()),
  paste("person-level rows:", nrow(person)),
  paste("ordbetareg subsample rows:", nrow(person_sub), "(set.seed 2026)"),
  paste("lme4", packageVersion("lme4"), "| lmerTest", packageVersion("lmerTest"),
        "| survey", packageVersion("survey"), "| WeMix", packageVersion("WeMix")),
  paste("glmmTMB", packageVersion("glmmTMB"), "| brms", packageVersion("brms"),
        "| cmdstanr", packageVersion("cmdstanr"), "| ordbetareg",
        packageVersion("ordbetareg"))
), "manifest.txt")
cat("ALL FITS DONE\n")
