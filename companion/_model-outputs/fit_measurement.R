# ########################################################################### #
# Title:        The thirteen EU-meaning items: dimensionality and the scales
# Purpose:      Everything the measurement module displays about the framing
#               instrument, computed once on the licensed respondent file and
#               written as aggregate tables. Item prevalences; the tetrachoric
#               correlations among the thirteen items; the eigenvalues of that
#               matrix; exploratory two- and four-factor solutions (minres,
#               oblimin) set against the published assignment of items to
#               scales; a confirmatory comparison of the published four-scale
#               model, the data-driven four-factor model and a two-factor
#               valence model, fitted on the binary items with the
#               diagonally weighted least squares estimator; and the
#               reliability of each scale, so that a two-item scale can be
#               read for what it is. The committed correlation matrix is
#               enough for a reader to repeat the exploratory analyses.
#
# Reads:        the respondent file, through _load_respondents.R (GESIS licensed, local only)
# Writes:       companion/_model-outputs/items_prevalence.csv
#               companion/_model-outputs/items_tetrachoric.csv
#               companion/_model-outputs/efa_eigen.csv
#               companion/_model-outputs/efa_loadings.csv
#               companion/_model-outputs/efa_factor_corr.csv
#               companion/_model-outputs/cfa_fit.csv
#               companion/_model-outputs/cfa_loadings.csv
#               companion/_model-outputs/scale_reliability.csv
#               All aggregate; nothing at the respondent level leaves the
#               directory.
# Author:       Chris Moreh
# Last updated: 2026-09-07
# ########################################################################### #

suppressPackageStartupMessages({
  library(dplyr); library(purrr); library(tidyr); library(psych); library(lavaan)
})
t0 <- Sys.time()
setwd("d:/ACADEMIC/TEACHING/2026_OR_NCL")
out <- "companion/_model-outputs"

source("companion/_model-outputs/_load_respondents.R")
p <- ind

# the fourteen response options of the battery, the Euro (position 8) excluded
# by the original paper; positions follow the questionnaire
items <- tibble::tribble(
  ~var,  ~item,                         ~scale,
  "it1",  "Peace",                       "cosmopolitan",
  "it2",  "Economic prosperity",         "utilitarian",
  "it3",  "Democracy",                   "cosmopolitan",
  "it4",  "Social protection",           "utilitarian",
  "it5",  "Freedom to travel",           "cosmopolitan",
  "it6",  "Cultural diversity",          "cosmopolitan",
  "it7",  "Stronger say in the world",   "cosmopolitan",
  "it9",  "Unemployment",                "communitarian",
  "it10", "Bureaucracy",                 "libertarian",
  "it11", "Waste of money",              "libertarian",
  "it12", "Loss of cultural identity",   "communitarian",
  "it13", "More crime",                  "communitarian",
  "it14", "Not enough border control",   "communitarian"
) |>
  mutate(valence = if_else(scale %in% c("cosmopolitan", "utilitarian"), "positive", "negative"))

X <- as.matrix(p[, items$var])
storage.mode(X) <- "numeric"
n <- nrow(X)

## ---- prevalence -------------------------------------------------------------------

prevalence <- items |>
  mutate(share_mentioning = colMeans(X)[var],
         n_respondents = n)
datawizard::data_write(prevalence, file.path(out, "items_prevalence.csv"), verbose = FALSE)

## ---- tetrachoric correlations and their eigenvalues ------------------------------

tet <- tetrachoric(X, correct = 0.5)$rho
dimnames(tet) <- list(items$item, items$item)
tet_long <- as.data.frame(tet) |>
  mutate(item = rownames(tet)) |>
  pivot_longer(-item, names_to = "with", values_to = "tetrachoric")
datawizard::data_write(tet_long, file.path(out, "items_tetrachoric.csv"), verbose = FALSE)

ev <- eigen(tet)$values
set.seed(20260907)
pa <- fa.parallel(tet, n.obs = n, fm = "minres", fa = "fa", plot = FALSE, n.iter = 20)
datawizard::data_write(tibble(factor = seq_along(ev), eigenvalue = ev,
                              parallel_mean = pa$fa.sim, n_respondents = n),
                       file.path(out, "efa_eigen.csv"), verbose = FALSE)

## ---- exploratory solutions ----------------------------------------------------------

efa <- map(c(2, 4), function(k) {
  f <- fa(tet, nfactors = k, n.obs = n, fm = "minres", rotate = "oblimin")
  L <- unclass(f$loadings)
  list(loadings = tibble(solution = paste0(k, "-factor"), item = items$item, scale = items$scale,
                         valence = items$valence, communality = f$communality) |>
         bind_cols(as_tibble(L) |> setNames(paste0("F", seq_len(k)))),
       phi = as_tibble(f$Phi, .name_repair = "minimal") |>
         setNames(paste0("F", seq_len(k))) |>
         mutate(solution = paste0(k, "-factor"), factor = paste0("F", seq_len(k)), .before = 1),
       varacc = 100 * sum(f$Vaccounted["Proportion Var", ]))
})
datawizard::data_write(bind_rows(map(efa, "loadings")), file.path(out, "efa_loadings.csv"), verbose = FALSE)
datawizard::data_write(bind_rows(map(efa, "phi")), file.path(out, "efa_factor_corr.csv"), verbose = FALSE)

## ---- confirmatory comparison ----------------------------------------------------------

# the published assignment, the data-driven assignment read off the
# four-factor solution, and a two-factor valence model
models <- list(
  published = "
    cosmopolitan  =~ it1 + it3 + it5 + it6 + it7
    utilitarian   =~ it2 + it4
    communitarian =~ it9 + it12 + it13 + it14
    libertarian   =~ it10 + it11",
  data_driven = "
    benefits      =~ it1 + it2 + it3 + it4 + it7
    mobility      =~ it5 + it6 + it7
    communitarian =~ it9 + it12 + it13 + it14
    libertarian   =~ it10 + it11",
  valence = "
    positive =~ it1 + it2 + it3 + it4 + it5 + it6 + it7
    negative =~ it9 + it10 + it11 + it12 + it13 + it14"
)
d_items <- as.data.frame(X)
fits <- imap(models, function(m, nm) {
  fit <- cfa(m, data = d_items, ordered = names(d_items), estimator = "WLSMV", std.lv = TRUE)
  fm <- fitMeasures(fit, c("chisq.scaled", "df.scaled", "cfi.scaled", "tli.scaled",
                            "rmsea.scaled", "srmr"))
  list(fit = tibble(model = nm, chisq = fm[["chisq.scaled"]], df = fm[["df.scaled"]],
                    cfi = fm[["cfi.scaled"]], tli = fm[["tli.scaled"]],
                    rmsea = fm[["rmsea.scaled"]], srmr = fm[["srmr"]], n_respondents = n),
       loadings = standardizedSolution(fit) |>
         filter(op == "=~") |>
         transmute(model = nm, factor = lhs, var = rhs, loading = est.std) |>
         left_join(items |> select(var, item), by = "var"),
       corr = standardizedSolution(fit) |>
         filter(op == "~~", lhs != rhs) |>
         transmute(model = nm, factor = lhs, with = rhs, correlation = est.std))
})
datawizard::data_write(bind_rows(map(fits, "fit")), file.path(out, "cfa_fit.csv"), verbose = FALSE)
datawizard::data_write(bind_rows(c(map(fits, "loadings"), map(fits, "corr"))) |>
                         select(model, factor, var, item, loading, with, correlation),
                       file.path(out, "cfa_loadings.csv"), verbose = FALSE)

## ---- reliability of each scale, as the items stand ------------------------------------

scales <- list(cosmopolitan = c("it1", "it3", "it5", "it6", "it7"), utilitarian = c("it2", "it4"),
               communitarian = c("it9", "it12", "it13", "it14"), libertarian = c("it10", "it11"),
               positive = c("it1", "it2", "it3", "it4", "it5", "it6", "it7"),
               negative = c("it9", "it10", "it11", "it12", "it13", "it14"))
reliability <- imap(scales, function(v, nm) {
  r <- tet[items$item[match(v, items$var)], items$item[match(v, items$var)]]
  k <- length(v)
  rbar <- mean(r[lower.tri(r)])
  tibble(scale = nm, items = k, mean_tetrachoric = rbar,
         ordinal_alpha = k * rbar / (1 + (k - 1) * rbar),
         mean_prevalence = mean(colMeans(X[, v])))
}) |> list_rbind()
datawizard::data_write(reliability, file.path(out, "scale_reliability.csv"), verbose = FALSE)

## ---- computed facts reported for verification ------------------------------------------

cat("respondents:", n, "\n")
cat("eigenvalues:", round(ev, 2), "\n")
cat("parallel analysis (a formality at this n):", pa$nfact, "factors\n")
cat("variance accounted, 2 and 4 factors:", round(map_dbl(efa, "varacc"), 1), "\n")
print(bind_rows(map(fits, "fit")) |> mutate(across(where(is.numeric), function(x) round(x, 3))))
print(reliability |> mutate(across(where(is.numeric), function(x) round(x, 3))))
cat("elapsed:", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "minutes\n")
