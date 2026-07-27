# Codebook: `EUframes_person_sim.csv`

**This file is simulated.** No Eurobarometer respondent appears in it, and
nothing in it should be used for substantive inference about EU framing. It
exists for teaching: a person-level dataset whose data-generating process is
written down, so that for once the true answer is known before any model runs.
It is used throughout the workshop's [simulation
module](../companion/simulation.qmd).

## What is calibrated, and what is authored

The file's construction separates two things that are usually tangled.

**Marginal distributions are calibrated** to the real Eurobarometer-derived
person file: how often respondents mention nothing at all, how mentions divide
across the four framing dimensions, how much individual variation there is
within a country-year, and the age, sex and education marginals. These
quantities were estimated once, locally, by
`companion/_model-outputs/calibrate_sim_params.R`, which reads the licensed
file and writes only summaries – each of a kind that could be printed in a
published appendix table. Those summaries are committed as
`companion/_model-outputs/sim_calibration.csv` and
`sim_calibration_kdist.csv`. The raw microdata are GESIS-licensed and cannot
be redistributed in any form, which is why this file is simulated rather than
sampled; the [repositories module](../companion/repositories.qmd#sec-gesis)
explains that regime.

**Every association is authored**, with its true value named as a constant in
the generator `companion/_model-outputs/simulate_person_twin.R` (seed
20260727, overridable with `$SIM_SEED`). The generator reads no microdata at
all: only the committed calibration summaries and the public country-year
panel `EUframes_cy.csv`.

## The recipe

A respondent mentions **K** items from the framing battery, where K is 0 with
probability 0.063 (the calibrated rate of mentioning nothing) and otherwise
1 + Poisson(2.4), truncated at 13. The mention count itself could not be
recovered from the real file – the dimension shares only identify their
reduced denominator, so someone scoring 1 on cosmopolitanism alone mentioned
one item or five, indistinguishably – so its distribution is authored, with
the concentration parameter (φ = 5.52) chosen so that the simulated
individual-level dispersion approximately reproduces the real within-cell
dispersion. It lands about 9% below it, because the inversion treats every
respondent in a cell as sharing one expected composition while in the
simulation age and own unemployment move it as well.

Given K > 0, the mentions divide across the four dimensions by a
Dirichlet-multinomial draw whose expected cosmopolitan share for person *i* in
country *c*, year *t* is

$$
\mu_{ict} \;=\; \beta_0 \;+\;
\frac{\beta_{\text{context}}\,\text{unemp}_{ct}
\;+\; \beta_{\text{unemployed}}\,\text{unemployed}_{i}
\;+\; \beta_{\text{age}}\,(\text{age}_i - 49.3)/10}{1 - p_{\text{zero}}}
\;+\; u_c \;+\; u_{ct},
$$

with the remaining share divided between the utilitarian, communitarian and
libertarian dimensions in the fixed proportions the real instrument shows
(0.226 / 0.445 / 0.328). Two details of that display matter to anyone
re-implementing it. $\mu$ is the expected share **among mentioners**, so the
named effects are divided by the mentioning rate $1 - p_\text{zero} = 0.937$
to put them on the observed scale, where a model fitted to the file estimates
them directly. And $\beta_\text{context}$ is the contextual part of the
unemployment effect, −0.004937, not the −0.005237 total: the remainder arrives
through the unemployed respondents a high-unemployment cell contains. The
value of $\mu$ is finally held inside [0.02, 0.98], a guard that never binds
at these parameter values. The two random intercepts take the between-country
and between-cell spread of the public panel's own cell means. They are drawn
and then **residualised against unemployment** – at country level against the
country's mean, at cell level within country – so that this particular draw
carries no accidental confounding: with only 27 countries, an unadjusted draw
correlates with the unemployment series often enough to move the recovered
slope by a third, which would defeat the purpose of a dataset whose truth is
supposed to be known. The residualisation is exact when cells count equally;
models that weight cells by their size, including the multilevel fits, still
see a trace of it, worth a few per cent of the slope in this draw.

## The named truths

All effects are stated on the **observed share scale**, so a model fitted to
this file estimates the constant below with no transformation in between.

| Quantity | True value | Status |
|---|---:|---|
| Cell-level unemployment, per point, on `cosmo` (total) | −0.005237 | the unemployment coefficient of the three-level model fitted once to the real respondents, recorded in `companion/_model-outputs/lmer_3lvl.txt` |
| The same, net of individual unemployment (contextual part) | −0.004937 | implied |
| Being unemployed oneself | −0.05 | authored |
| Per decade of age | −0.015 | authored |
| Population mean of `cosmo` | 0.50 | targeted |

Because the four dimensions are shares of one instrument, **every other
outcome inherits a truth** from the cosmopolitan one. A cell-level
unemployment slope of −0.005237 on `cosmo` implies +0.001186 on `util`,
+0.002333 on `comm`, +0.001718 on `lib`, −0.004051 on `pos` and +0.004051 on
`neg`.

Read that list carefully, because the sign split is not the one the workshop's
claim-alignment convention describes. It runs between the **chosen dimension
and its complement**: raising the cosmopolitan share must lower the other three
together, so `util` – a positive framing, and half of `pos` – carries a truth
of the same sign as the two negative framings. This file therefore contains a
built-in wrong-sign outcome whose true effect really does run against the
claim, which is a useful thing to have met before reading a real specification
curve. What does hold exactly here is the narrower identity the convention
rests on: `pos` and `neg` partition the mentions, so `neg` = 1 − `pos` for
every mentioner and reverse-coding the negative composite is exact arithmetic.

Note also that the six truths differ in *magnitude*: a single mechanism
produces effects ranging from −0.0052 to +0.0012 depending only on which
outcome an analyst chooses, which is a large part of why the outcome fork
carries so much specification variance in the real multiverse.

## The weight

`w1` is a genuine weight, not decoration. The sample is drawn with a
deliberate fieldwork distortion – younger respondents are over-selected by a
factor of exp(0.15 × decades below the mean age), which pulls the achieved
mean age down from the population's 49.3 to about 45.3 – and `w1` is the exact
reciprocal of that selection factor, normalised to mean 1 within each
country-year. Strictly it is an inverse-probability-of-selection weight, since
it undoes a selection rule known exactly; the real Eurobarometer nation weight
is a post-stratification weight, which reaches a similar place by aligning the
achieved sample to known population margins. Weighting recovers the population
age and the population mean of `cosmo`; leaving the weight out biases both,
because age has a real effect in the recipe.

Because the distortion depends on age alone, `w1` is a deterministic function
of `age` within a cell, and adjusting for age in the model does the same work
as weighting. That equivalence is specific to this construction – a real
weight corrects margins the model may not contain – but it is worth knowing
before drawing general conclusions from the comparison.

The distortion is constant across cells by default, so it shifts levels
without biasing the unemployment slope. Set `SIM_DISTORT_SLOPE` above zero in
the generator and the distortion grows with a cell's unemployment, at which
point the slope itself is biased unless the weight is used. Values up to about
0.03 keep the tilt positive everywhere; 0.01 is a good setting to try, giving
an age shift that runs from about three years in the calmest labour markets to
eleven in the most stressed.

## What carries no information

`female` and `edu4` are drawn independently of everything else and of each
other. Any association between them and an outcome in this file is sampling
noise, and the [simulation module](../companion/simulation.qmd#sec-noise) uses
them as a placebo bench. `age`, `unemployed`, `unemp` and `w1` all carry real,
named structure, so they are not part of that bench.

## Variables

| Variable | Description |
|------------------------------------|------------------------------------|
| `pid` | Simulated person identifier |
| `cntry` | ISO 3166 two-letter code, as in `EUframes_cy.csv` |
| `year` | Year (2004–2013) |
| `w1` | Post-stratification weight, mean 1 within country-year (see above) |
| `age` | Simulated age, 15–98 |
| `female` | Simulated indicator, drawn at the calibrated marginal (0.546); no effect |
| `edu4` | Simulated education band (`le15` / `e16_19` / `e20plus` / `studying`), calibrated marginals; no effect |
| `unemployed` | Simulated indicator; the probability is 0.6 × the cell's real unemployment rate expressed as a proportion, so about 5% of respondents at the average rate |
| `cosmo`, `util`, `comm`, `lib` | Simulated dimension shares; sum to 1 for anyone who mentions anything, to 0 otherwise |
| `pos`, `neg` | Composites: `pos` = `cosmo` + `util`, `neg` = `comm` + `lib` |
| `unemp`, `growth`, `bailout` | Real published values, joined from `EUframes_cy.csv` |

The six share columns are stored rounded to six decimals, so the compositional
identities hold to a tolerance rather than exactly: test them with
`abs(cosmo + util + comm + lib - 1) < 5e-6`, not with `==`. (The single
identity that does survive exact comparison is `pos + neg == 1`, because that
rounding is symmetric.) Likewise `w1` is rounded to four decimals, so its
within-cell mean is 1 to within 1e-5.

The shares are ratios of small integers, so they take exact 0 and exact 1
values in quantity: of all respondents, 22.9% score exactly 0 on `cosmo` and
22.6% exactly 1; among those who mention anything the figures are 17.9% and
24.0%. That is faithful to the real instrument, and it is the reason beta
regression cannot be used at person level. It can normally be used on
country-year means, where averaging moves cells inside the unit interval – but
check rather than assume, because at this file's smallest cell sizes it does
not always: cell LU 2006, with 25 simulated respondents, has a `util` mean of
exactly 0.

## Scale and provenance

20,829 rows across all 270 country-year cells (27 countries × 10 years), with
each cell sized at 5% of its real respondent count – between 25 and 181
respondents. The macro columns are real published aggregates carried over from
the public panel (World Bank and European Commission, via
`EUframes_cy.csv`); everything at person level is synthetic.

## Licence

Simulated data, generator and calibration summaries: CC BY 4.0. No GESIS terms
attach to this file, because it contains no Eurobarometer microdata: the
licensed file was read once to estimate the marginal summaries listed above,
which are aggregate statistics of the kind the usage terms describe as
"summarizing representations of the data typical to scientific works and
presentations".
