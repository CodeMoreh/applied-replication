################################################################################
# Title:        Simulated person-level teaching twin (EUframes_person_sim)
# Purpose:      Generate a fully synthetic person-level dataset for the
#               simulation companion module, by parametric simulation from
#               disclosed aggregate parameters only. No GESIS microdata is
#               read at any point, so the output is committable and
#               redistributable (CC BY 4.0), unlike any extract of the real
#               Eurobarometer files.
# Reads:        data/EUframes_cy.csv (committed public country-year panel)
# Writes:       data/EUframes_person_sim.csv
# Author:       Chris Moreh (with Claude)
# Last updated: 2026-07-27
################################################################################

# The data-generating process is the three-level random-intercept model of the
# stats-methods module, run forwards: person inside country-year inside
# country. Every parameter is a named constant transcribed from the committed
# captured fit companion/_model-outputs/lmer_3lvl.txt – a single teaching fit
# whose aggregate parameters are public. Demographics and the weight are
# stylised marginals, independent of the outcome BY CONSTRUCTION; the codebook
# says so, and no exercise should read demographic 'effects' out of this file.

library(dplyr)
library(tidyr)
library(readr)

set.seed(20260727)

# --- the named truth --------------------------------------------------------
SIM_B0       <- 0.5526     # intercept                    (lmer_3lvl.txt)
SIM_B_UNEMP  <- -0.005237  # level-2 unemployment slope   (lmer_3lvl.txt)
SIM_SD_CNTRY <- 0.06131    # country random-intercept SD  (lmer_3lvl.txt)
SIM_SD_CY    <- 0.03853    # country-year random-intercept SD (lmer_3lvl.txt)
SIM_SD_E     <- 0.36806    # person-level residual SD     (lmer_3lvl.txt)
SIM_FRACTION <- 0.05       # cell sizes = SIM_FRACTION x the real n_cy

# The latent outcome is Gaussian and gets clipped to the [0, 1] scale bounds,
# so the OBSERVED-scale slope is attenuated relative to SIM_B_UNEMP – roughly
# the same reason the family fork exists in the specification menu. The
# validation report below quantifies the attenuation; the module teaches it.

panel <- read_csv("data/EUframes_cy.csv", show_col_types = FALSE)

cells <- panel |>
  select(cntry, year, n_cy, unemp, growth, bailout) |>
  mutate(
    n_sim = pmax(1L, as.integer(round(n_cy * SIM_FRACTION))),
    u_cy  = rnorm(n(), 0, SIM_SD_CY)
  )

country_re <- cells |>
  distinct(cntry) |>
  mutate(u_c = rnorm(n(), 0, SIM_SD_CNTRY))

sim <- cells |>
  left_join(country_re, by = "cntry") |>
  uncount(n_sim) |>
  mutate(
    pid          = row_number(),
    cosmo_latent = SIM_B0 + SIM_B_UNEMP * unemp + u_c + u_cy +
                   rnorm(n(), 0, SIM_SD_E),
    cosmo        = pmin(pmax(cosmo_latent, 0), 1),
    age          = as.integer(round(pmin(pmax(rnorm(n(), 48, 17), 15), 98))),
    female       = rbinom(n(), 1, 0.55),
    edu4         = sample(c("le15", "e16_19", "e20plus", "studying"),
                          n(), replace = TRUE,
                          prob = c(0.30, 0.35, 0.28, 0.07)),
    w1_raw       = pmin(rlnorm(n(), meanlog = 0, sdlog = 0.5), 5)
  ) |>
  mutate(w1 = round(w1_raw / mean(w1_raw), 4), .by = c(cntry, year))

# --- validation report (this block IS the script's output) ------------------
library(lmerTest)

m3_obs    <- lmer(cosmo ~ unemp + (1 | cntry) + (1 | cntry:year), data = sim)
m3_latent <- lmer(cosmo_latent ~ unemp + (1 | cntry) + (1 | cntry:year),
                  data = sim)
m_naive   <- lm(cosmo ~ unemp, data = sim)

# Satterthwaite df, not the Wald default: the collapse from ~20k residual df
# to a few hundred effective df is the module's central teaching contrast.
report <- list(
  rows            = nrow(sim),
  cells           = n_distinct(sim$cntry, sim$year),
  cell_size_range = range(count(sim, cntry, year)$n),
  share_clipped   = mean(sim$cosmo_latent < 0 | sim$cosmo_latent > 1),
  true_slope      = SIM_B_UNEMP,
  latent_recovery = parameters::model_parameters(m3_latent,
                                                 ci_method = "satterthwaite"),
  observed_scale  = parameters::model_parameters(m3_obs,
                                                 ci_method = "satterthwaite"),
  naive_ols       = parameters::model_parameters(m_naive),
  # clipping attenuation proper: observed-scale slope over this draw's own
  # latent-scale slope, so Monte-Carlo error cancels out of the ratio
  attenuation     = unname(fixef(m3_obs)["unemp"] / fixef(m3_latent)["unemp"])
)
print(report)

sim |>
  mutate(cosmo = round(cosmo, 4)) |>
  select(pid, cntry, year, w1, age, female, edu4, cosmo,
         unemp, growth, bailout) |>
  write_csv("data/EUframes_person_sim.csv")
