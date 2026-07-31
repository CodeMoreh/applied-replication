---
title: "silberzahn29.csv – codebook"
---

The 29 teams' results from Silberzahn et al. (2018), *Many Analysts, One Data
Set: Making Transparent How Variations in Analytic Choices Affect Results*,
**Advances in Methods and Practices in Psychological Science** 1(3): 337–356.
One row per team. These are the numbers behind the paper's Figure 3.

**Provenance.** Downloaded from the authors' public OSF project,
[osf.io/gvm2z](https://osf.io/gvm2z), component "Results: Data", file
`Crowdsourcing Effects in OR with Subgroups.csv`. Rebuilt by
`companion/_model-outputs/build_silberzahn29.R`, which fetches that file over
the network, renames the columns, and refuses to write unless the paper's own
summary still holds: 29 teams, median odds ratio 1.310, range 0.888 to 2.931,
20 significant.

Nothing here is licensed or restricted – these are published aggregate results
about 29 analyses, not the football data the teams analysed.

## The question the teams were given

Are football referees more likely to give red cards to dark-skinned players
than to light-skinned ones? Every team received the same dataset – 2,053
players, 146,028 player–referee dyads – and answered in whatever way they
judged correct.

## Variables

| Column | Type | Meaning |
|---|---|---|
| `team` | integer | The team's identifier in the published figure. Runs 1–32 with gaps: three teams that began did not deliver a usable estimate, so there are 29 rows |
| `approach` | character | The team's own description of its method, verbatim from the published table |
| `distribution` | character | The response distribution the team assumed: `Linear`, `Logistic`, `Poisson`, or `Other`. The paper's grouping; `Other` is its `misc`, holding the two teams (Dirichlet-process clustering, Tobit) that fit none of the three |
| `clustering` | character | How the team handled the non-independence of repeated players and referees: `random`, `clustered`, `fixed`, or `none` |
| `or` | double | The team's estimate as an odds ratio. Above 1 means dark-skinned players are red-carded more often |
| `or_lo`, `or_hi` | double | The 95% interval, on the same scale |
| `significant` | logical | Whether that interval excludes 1. Twenty teams, nine not |

## Two conversions worth knowing about

Not every team reported an odds ratio. Four reported a correlation or a
standardised mean difference, and the paper's own script converts these to the
odds-ratio scale so that all 29 sit on one axis. The conversion is theirs, not
ours – `1_meta_plot.R` in the same OSF project – and it is the reason team 21's
interval is so wide: converting a Tobit coefficient through a correlation
carries its uncertainty with it.

Teams 21 and 27 have intervals that run far past the right edge of any readable
plot (up to 11.5 and 78.7). The published figure truncates both at 5 and marks
them with an asterisk; the deck's version does the same, and says so.

## What the deck uses it for

- **Part 1**, before SCORE: the paper's Figure 3 rebuilt – every team, every
  interval, grouped by distribution family. The first many-analysts study, and
  the design SCORE later industrialised.
- **Part 2**, on "Two studies to set beside our five": the same 29 estimates as
  a single-row strip, a reminder before Auspurg and Brüderl's reanalysis.

The median of 1.310 is deliberately **not** marked on either figure. It belongs
to the later discussion of how a multi-analyst study combines estimates at all,
where Silberzahn's median sits beside Multi100's approach as one option among
several.
