# ########################################################################### #
# Title:        _load_respondents.R – the one respondent-level data frame
# Purpose:      Every script in this folder that touches the licensed
#               respondents reads the same file, the one that participants
#               build with prep/01_build_respondents.R, and derives the same
#               columns from it here: the thirteen-item mention count, the six
#               framing shares under the published scoring rule with the zero
#               rule for respondents who named nothing, the macro variables
#               joined by country-year from the committed panel, and the
#               cluster identifiers. A script that needs a different scoring
#               rule builds it from the items itself.
# Sourced by:   fit_measurement.R, calibrate_items.R, calibrate_joint.R,
#               fit_person_anchor.R, fit_person_multilevel.R, validate_twin.R,
#               fit_models.R, fit_items_glm.R
# Author:       Chris Moreh
# Last updated: 2026-09-09
# ########################################################################### #

# The file lives outside every repository. The default is the workspace's
# private folder on the facilitator's machine; a participant running these
# scripts sets EB_RESPONDENTS to their own copy. Paths are relative to the
# course root; a script run from elsewhere sets EB_COURSE_ROOT first.
.root <- Sys.getenv("EB_COURSE_ROOT", unset = ".")
.respondents_path <- Sys.getenv("EB_RESPONDENTS",
                                unset = file.path(.root, "_template/data_private/eb_respondents.rds"))
if (!file.exists(.respondents_path))
  stop("respondent file not found at '", .respondents_path,
       "': build it with prep/01_build_respondents.R in the workspace, or set ",
       "EB_RESPONDENTS to its path", call. = FALSE)

.items <- list(cosmo = paste0("it", c(1, 3, 5, 6, 7)),
               util  = paste0("it", c(2, 4)),
               comm  = paste0("it", c(9, 12, 13, 14)),
               lib   = paste0("it", c(10, 11)))
.items13 <- unlist(.items, use.names = FALSE)

.panel <- readr::read_csv(file.path(.root, "data/EUframes_cy.csv"), show_col_types = FALSE) |>
  dplyr::select(cntry, year, unemp, growth, bailout)

ind <- readRDS(.respondents_path) |>
  dplyr::mutate(
    k       = rowSums(dplyr::across(dplyr::all_of(.items13))),
    n_cosmo = rowSums(dplyr::across(dplyr::all_of(.items$cosmo))),
    n_util  = rowSums(dplyr::across(dplyr::all_of(.items$util))),
    n_comm  = rowSums(dplyr::across(dplyr::all_of(.items$comm))),
    n_lib   = rowSums(dplyr::across(dplyr::all_of(.items$lib))),
    cosmo   = dplyr::if_else(k == 0, 0, n_cosmo / k),
    util    = dplyr::if_else(k == 0, 0, n_util  / k),
    comm    = dplyr::if_else(k == 0, 0, n_comm  / k),
    lib     = dplyr::if_else(k == 0, 0, n_lib   / k),
    pos     = cosmo + util,
    neg     = comm + lib,
    cy      = paste(cntry, year, sep = "_"),
    cyw     = paste(cntry, eb, sep = "_")
  ) |>
  dplyr::left_join(.panel, by = c("cntry", "year"))

rm(.root, .respondents_path, .items, .items13, .panel)
