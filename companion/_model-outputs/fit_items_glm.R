# ########################################################################### #
# Title:        Binary-outcome models on single EU-meaning items
# Purpose:      Compute the tables the binary-outcomes companion page displays:
#               one item of the EU-meaning battery as the outcome, modelled as
#               a probability. Prevalence by education band and by year; a
#               logit and a probit of the same item on the respondent
#               characteristics, side by side, with odds ratios and average
#               marginal effects; the same logit with cluster-robust errors
#               and with country and year fixed effects, where the national
#               unemployment rate enters; the cross-level interaction between
#               education and unemployment on one item; and a random-intercept
#               logit for the cluster structure. Every table is an aggregate
#               summary of the kind a published appendix carries.
# Reads:        data_private/eb_respondents.rds  (licensed, local only; the
#               file that prep/01_build_respondents.R builds)
# Writes:       companion/_model-outputs/items_glm_prevalence.csv
#               companion/_model-outputs/items_glm_coefficients.csv
#               companion/_model-outputs/items_glm_ame.csv
#               companion/_model-outputs/items_glm_interaction.csv
#               companion/_model-outputs/items_glm_random.csv
# Author:       Chris Moreh
# Last updated: 2026-09-09
# ########################################################################### #

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(purrr); library(readr); library(tibble)
  library(fixest); library(marginaleffects); library(glmmTMB)
})

raw <- Sys.getenv("EB_RESPONDENTS", unset = "_template/data_private/eb_respondents.rds")
d <- readRDS(raw) |>
  mutate(cy    = paste(cntry, year, sep = "_"),
         edu3  = factor(edu3, levels = c("low", "mid", "high")),
         ses   = factor(ses, levels = c("manual", "self_employed", "manager",
                                        "white_collar", "house_person",
                                        "unemployed", "retired", "student")),
         age_c = age - mean(age, na.rm = TRUE)) |>
  filter(!is.na(edu3), !is.na(female), !is.na(age))

# The macro series join by country-year from the committed panel.
panel <- read_csv("data/EUframes_cy.csv", show_col_types = FALSE) |>
  select(cntry, year, unemp, growth)
d <- d |>
  left_join(panel, by = c("cntry", "year")) |>
  mutate(unemp_c = unemp - mean(panel$unemp))

# Two items carry the page: "unemployment" (it9), the item that shares content
# with the predictor, and "peace" (it1), the most-named positive item.
items <- c(it9 = "Unemployment", it1 = "Peace")

# --- 1. prevalence ------------------------------------------------------------
# Two named lists are concatenated and unnamed before binding: bind_rows()
# given two named lists of the same names nests them into a tibble of tibbles.
prevalence <- c(
  imap(items, \(lab, it) d |>
    summarise(share = mean(.data[[it]]), n = n(), .by = edu3) |>
    mutate(item = it, label = lab, by = "education", group = as.character(edu3)) |>
    select(item, label, by, group, share, n)),
  imap(items, \(lab, it) d |>
    summarise(share = mean(.data[[it]]), n = n(), .by = year) |>
    mutate(item = it, label = lab, by = "year", group = as.character(year)) |>
    select(item, label, by, group, share, n))
) |> unname() |> list_rbind()

# --- 2. logit and probit, side by side ------------------------------------------
# Same right-hand side under both links, conventional errors first, so the
# page can show that the two links order the coefficients identically and
# differ by a scale factor, while the average marginal effects agree closely.
rhs <- "edu3 + age_c + female + ses + urban"
fit_link <- function(it, link) {
  feglm(as.formula(paste(it, "~", rhs)), data = d, family = binomial(link = link))
}
tidy_fit <- function(m, it, link, vcov_label) {
  ct <- coeftable(m)
  tibble(item = it, link = link, vcov = vcov_label, term = rownames(ct),
         estimate = ct[, 1], se = ct[, 2], z = ct[, 3], p = ct[, 4])
}

coefficients <- imap(items, \(lab, it) {
  logit  <- fit_link(it, "logit")
  probit <- fit_link(it, "probit")
  # The same logit with errors clustered by country-year, which is the
  # structure the respondents actually sit in.
  logit_cl <- summary(logit, vcov = ~cy)
  ct <- coeftable(logit_cl)
  clustered <- tibble(item = it, link = "logit", vcov = "clustered by country-year",
                      term = rownames(ct), estimate = ct[, 1], se = ct[, 2],
                      z = ct[, 3], p = ct[, 4])
  bind_rows(tidy_fit(logit, it, "logit", "conventional"),
            tidy_fit(probit, it, "probit", "conventional"),
            clustered)
}) |> list_rbind() |>
  mutate(odds_ratio = if_else(link == "logit", exp(estimate), NA_real_))

out <- "companion/_model-outputs/"
write_csv(prevalence,   paste0(out, "items_glm_prevalence.csv"))
write_csv(coefficients, paste0(out, "items_glm_coefficients.csv"))
message("prevalence and coefficients written ", format(Sys.time(), "%H:%M:%S"))

# --- 3. average marginal effects ------------------------------------------------
# What a coefficient on the link scale is worth in percentage points, averaged
# over the respondents as they are: the quantity a reader can compare across
# links and across models. The average is taken over a random fifty thousand
# of the respondents rather than all four hundred thousand, which changes the
# third decimal at most and turns a long computation into a short one; the
# models themselves are fitted on everyone.
set.seed(20260909)
ame_rows <- slice_sample(d, n = 50000)
ame <- imap(items, \(lab, it) {
  map(c("logit", "probit"), \(link) {
    m <- fit_link(it, link)
    avg_slopes(m, variables = c("edu3", "age_c", "female"), newdata = ame_rows,
               vcov = ~cy) |>
      as_tibble() |>
      transmute(item = it, link = link, term, contrast,
                estimate, se = std.error, p = p.value)
  }) |> list_rbind()
}) |> list_rbind()
write_csv(ame, paste0(out, "items_glm_ame.csv"))
message("average marginal effects written ", format(Sys.time(), "%H:%M:%S"))

# --- 4. unemployment on one item, with and without fixed effects ------------------
# The national unemployment rate varies only across country-years. Without
# fixed effects its coefficient compares countries with one another; with
# country and year fixed effects it compares each country with itself over
# time, net of what all countries share in a year. The interaction with
# education asks whether that within-country movement differs by band: the
# main effect of unemployment is identified across cells, the interaction
# within them.
interaction <- imap(items, \(lab, it) {
  f_pooled <- as.formula(paste(it, "~ unemp_c * edu3 + age_c + female + ses + urban"))
  f_fe     <- as.formula(paste(it, "~ unemp_c * edu3 + age_c + female + ses + urban | cntry + year"))
  fits <- list(
    "pooled, clustered"            = feglm(f_pooled, data = d, family = binomial("logit"), vcov = ~cy),
    "country and year fixed effects" = feglm(f_fe, data = d, family = binomial("logit"), vcov = ~cy)
  )
  imap(fits, \(m, nm) {
    ct <- coeftable(m)
    keep <- grepl("unemp_c|edu3", rownames(ct))
    tibble(item = it, model = nm, term = rownames(ct)[keep],
           estimate = ct[keep, 1], se = ct[keep, 2], z = ct[keep, 3], p = ct[keep, 4])
  }) |> list_rbind()
}) |> list_rbind()
write_csv(interaction, paste0(out, "items_glm_interaction.csv"))
message("interaction models written ", format(Sys.time(), "%H:%M:%S"))

# --- 5. a random intercept for the cluster ------------------------------------------
# One item, one model: respondents inside country-years inside countries, the
# structure of the published analysis, fitted as a logit with glmmTMB, which
# is far faster than glmer on four hundred thousand rows. The variance
# components say how much of the item's variation sits at each level.
m_re <- glmmTMB(it9 ~ unemp_c * edu3 + age_c + female + ses + urban + (1 | cntry) + (1 | cy),
                data = d, family = binomial("logit"))
fx <- summary(m_re)$coefficients$cond
vc <- as.data.frame(VarCorr(m_re)$cond)
random <- bind_rows(
  tibble(item = "it9", part = "fixed", term = rownames(fx),
         estimate = fx[, "Estimate"], se = fx[, "Std. Error"], z = fx[, "z value"],
         p = fx[, "Pr(>|z|)"]),
  tibble(item = "it9", part = "random", term = c("sd(country)", "sd(country-year)"),
         estimate = c(attr(VarCorr(m_re)$cond$cntry, "stddev"),
                      attr(VarCorr(m_re)$cond$cy, "stddev")),
         se = NA_real_, z = NA_real_, p = NA_real_)
)

write_csv(random, paste0(out, "items_glm_random.csv"))
message("random-intercept model written ", format(Sys.time(), "%H:%M:%S"))
