# ########################################################################### #
# Title:        Joint calibration for the simulated person-level twin
# Purpose:      Estimate the joint distribution of the framing instrument and
#               the covariates, so the twin reproduces the relationships among
#               them rather than only their separate marginal effects. The
#               earlier calibration estimated one coefficient per variable per
#               dimension and applied the shifts additively, which fixes a set
#               of conditional means and nothing else. A regression run on data
#               built that way recovers the coefficients that went in, and
#               anything depending on how the variables covary comes out wrong.
#
#               The structure estimated here is a latent multivariate normal.
#               Every observed variable is a monotone transform of one latent
#               coordinate: the thirteen framing items and the binary
#               covariates by a threshold, the ordinal ones by cutpoints, age
#               and education by their quantile functions. Simulation then
#               needs the correlation matrix and the marginals, and reproduces
#               every pairwise association by construction.
#
#               Occupation is handled in two parts. Being unemployed enters the
#               latent block directly, because the individual-versus-contextual
#               reading of the case turns on it and its joint structure has to
#               be exact. The remaining seven categories are drawn afterwards
#               from a multinomial model conditional on the latent block.
#
# Reads:        _planning_data/person_level_full.rds   (licensed, local only)
# Writes:       companion/_model-outputs/joint_corr.csv
#               companion/_model-outputs/joint_marginals.csv
#               companion/_model-outputs/joint_ses_conditional.csv
#               companion/_model-outputs/joint_item_split.csv
#               Correlations, marginal distributions and coefficient tables:
#               aggregate throughout, and no respondent record is written.
# Author:       Chris Moreh
# Last updated: 2026-07-30
# ########################################################################### #

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(purrr); library(readr)
  library(psych); library(nnet)
})

set.seed(20260730)

ind <- readRDS("_planning_data/person_level_full.rds")
items <- paste0("it", c(1:7, 9:14))

# Left-right is absent from the four 2013-and-earlier-numbered waves that use
# named variables; the twin mirrors that pattern rather than inventing values,
# so the share is recorded and the correlations are estimated where it exists.
RILE_COVERAGE <- mean(!is.na(ind$rile))

# --- the latent block -------------------------------------------------------
# Ordinals are integer-coded for the polychoric step. Education enters as the
# age full-time schooling finished, the form the published cut is made on,
# rather than as its three bands: banding first would throw away variation the
# twin then could not put back.
lat <- ind |>
  transmute(
    age, edu, female, unemployed,
    urban_i = match(urban, c("rural", "small_town", "large_town")),
    rile,
    across(all_of(items), \(x) as.integer(x))
  )

# Left-right is a ten-point scale, which the polychoric estimator declines to
# treat as ordinal and which is conventionally read as continuous at that
# length. Its latent coordinate is still mapped back through the observed
# category shares at simulation, so the twin's values stay integers 1 to 10.
CONT <- c("age", "edu", "rile")
POLY <- c("urban_i")
DICH <- c("female", "unemployed", items)

# Correlations are estimated on a subsample: at sixty thousand respondents the
# standard error of any one of these is under 0.005, and the polychoric step
# over 190 pairs is quadratic in nothing but time.
N_CORR <- 60000
sub <- lat |> slice_sample(n = min(N_CORR, nrow(lat)))

cat("Estimating the latent correlation matrix on", nrow(sub), "respondents",
    "over", ncol(sub), "variables...\n")
mc <- mixedCor(data = as.data.frame(sub), c = CONT, p = POLY, d = DICH,
               use = "pairwise.complete.obs", smooth = TRUE)
R <- mc$rho
# mixedCor returns the blocks in c/p/d order regardless of input order, so the
# matrix is put back into a stated order here; the generator reads the names,
# not the positions, but a stated order makes the committed file readable.
ord <- c(CONT, POLY, DICH)
R <- R[ord, ord]

corr_long <- as.data.frame(as.table(R)) |>
  setNames(c("var1", "var2", "r")) |>
  filter(as.character(var1) < as.character(var2)) |>
  mutate(r = signif(r, 6))
write_csv(corr_long, "companion/_model-outputs/joint_corr.csv")
cat("  wrote", nrow(corr_long), "correlations\n")

# --- marginals --------------------------------------------------------------
# Continuous variables travel as a hundred-point quantile grid, which carries
# the shape without carrying anyone's value: every printed number is the
# boundary between two centiles of a 400,000-respondent distribution.
q_grid <- seq(0.005, 0.995, length.out = 100)
cont_marg <- map(c("age", "edu"), \(v) tibble(
  variable = v, kind = "quantile", level = as.character(q_grid),
  value = as.numeric(quantile(ind[[v]], q_grid, na.rm = TRUE)))) |>
  list_rbind()

cat_marg <- bind_rows(
  ind |> count(urban) |> filter(!is.na(urban)) |>
    transmute(variable = "urban", kind = "share", level = urban,
              value = n / sum(n)),
  ind |> filter(!is.na(rile)) |> count(rile) |>
    transmute(variable = "rile", kind = "share", level = as.character(rile),
              value = n / sum(n)),
  tibble(variable = c("female", "unemployed", "rile_observed"),
         kind = "rate", level = "1",
         value = c(mean(ind$female, na.rm = TRUE),
                   mean(ind$unemployed, na.rm = TRUE), RILE_COVERAGE))
)

item_marg <- ind |>
  summarise(across(all_of(items), \(x) mean(x, na.rm = TRUE))) |>
  pivot_longer(everything(), names_to = "variable", values_to = "value") |>
  mutate(kind = "rate", level = "1")

write_csv(bind_rows(cont_marg, cat_marg, item_marg) |>
            mutate(value = signif(value, 6)),
          "companion/_model-outputs/joint_marginals.csv")

# --- how each dimension's mentions divide across its items ------------------
# The cell-level dimension means come from the public panel, as they always
# have. What the panel cannot supply is the split inside each dimension, and
# that is thirteen numbers rather than thirteen per cell: the twin reproduces
# the average salience of each item and not its country-by-country variation,
# which is a stated limit rather than an oversight. Nothing in the target model
# reads individual items.
dim_of <- c(it1 = "cosmo", it3 = "cosmo", it5 = "cosmo", it6 = "cosmo",
            it7 = "cosmo", it2 = "util",  it4 = "util",
            it9 = "comm",  it12 = "comm", it13 = "comm", it14 = "comm",
            it10 = "lib",  it11 = "lib")
item_split <- item_marg |>
  mutate(dimension = dim_of[variable]) |>
  mutate(share_within_dimension = value / sum(value), .by = dimension) |>
  select(item = variable, dimension, mention_rate = value,
         share_within_dimension) |>
  mutate(across(where(is.numeric), \(x) signif(x, 6)))
write_csv(item_split, "companion/_model-outputs/joint_item_split.csv")

# --- occupation beyond the unemployed indicator ------------------------------
# Conditional on not being unemployed, which of the seven remaining groups a
# respondent falls into. Fitted on a subsample for speed; the coefficients are
# a small table and the categories are large, so the estimates are stable.
ses_all <- ind |>
  filter(!is.na(ses), ses != "unemployed",
         !is.na(age), !is.na(edu), !is.na(urban)) |>
  mutate(ses = factor(ses, levels = c("manual", "self_employed", "manager",
                                      "white_collar", "house_person",
                                      "retired", "student")))
ses_dat <- ses_all |> slice_sample(n = min(80000L, nrow(ses_all)))

cat("Fitting the conditional occupation model on", nrow(ses_dat), "respondents...\n")
m_ses <- multinom(ses ~ age + I(age^2) + edu + female + urban,
                  data = ses_dat, trace = FALSE, maxit = 400)
ses_coef <- as.data.frame(coef(m_ses)) |>
  tibble::rownames_to_column("category") |>
  pivot_longer(-category, names_to = "term", values_to = "estimate") |>
  mutate(estimate = signif(estimate, 6))
write_csv(ses_coef, "companion/_model-outputs/joint_ses_conditional.csv")

# --- what the calibration says ----------------------------------------------
cat("\n--- correlations worth reading ---\n")
show <- corr_long |>
  filter((var1 %in% c("age", "edu", "female", "unemployed", "urban_i") &
          var2 %in% c("age", "edu", "female", "unemployed", "urban_i")) |
         (var1 == "unemployed" & var2 %in% items) |
         (var2 == "unemployed" & var1 %in% items)) |>
  arrange(desc(abs(r)))
print(head(as.data.frame(show), 18), right = FALSE)

cat("\n--- how far the independence assumption was off ---\n")
covs <- c("age", "edu", "female", "unemployed", "urban_i")
off <- corr_long |> filter(var1 %in% covs, var2 %in% covs)
cat("  largest covariate-covariate correlation:", signif(max(abs(off$r)), 3),
    "between", off$var1[which.max(abs(off$r))], "and",
    off$var2[which.max(abs(off$r))], "\n")
cat("  the previous generator drew all of these independently\n")

item_pairs <- corr_long |> filter(var1 %in% items, var2 %in% items)
cat("\n  item-item correlations: median", signif(median(item_pairs$r), 3),
    "| range", signif(min(item_pairs$r), 3), "to",
    signif(max(item_pairs$r), 3), "over", nrow(item_pairs), "pairs\n")
cat("  left-right observed for", sprintf("%.1f%%", 100 * RILE_COVERAGE),
    "of respondents (12 of 16 waves)\n")
