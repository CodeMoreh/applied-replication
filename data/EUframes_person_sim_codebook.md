# Codebook: `EUframes_person_sim.csv`

> **Superseded.** This file documents the first person-level twin, which
> calibrated one coefficient per variable per dimension and applied the shifts
> additively. That construction fixes a set of conditional means and nothing
> else, so a regression run on it recovers the coefficients that went in while
> anything depending on how the variables covary comes out wrong. It also drew
> the demographics independently of one another, which they are not.
>
> It is replaced by [`EUframes_person_full.csv`](EUframes_person_full_codebook.md),
> built from the joint distribution and validated coefficient by coefficient
> against the real respondents. Nothing on the site reads the file this
> codebook describes. Both are kept for now so the comparison is available.

**This file is simulated.** No Eurobarometer respondent appears in it, and
nothing in it should be used for substantive inference about EU framing. It
exists for teaching: a person-level dataset built to carry the EU-frames
analysis as the original author carried it – all four framing dimensions and
both composites, both macro predictors, and the individual controls – while
being fully synthetic, so that for once the answer is planted before any model
runs. It is used throughout the [simulation
module](../companion/simulation.qmd).

## Every dimension gets its own response

Each framing dimension responds to unemployment and to growth on terms of its
own, estimated from the public country-year panel under the anchor
specification with GDP growth added as a co-predictor, one step along the day's
co-predictor fork. Nothing is induced from any one privileged dimension. The
four shares sum to one because that is what the survey instrument makes them do,
and a set of coefficients estimated the same way on all four automatically sums
to zero, so no dimension has to be held passive to keep the composition intact.
Individual characteristics carry the effects they carry in the real respondents.
Four quantities in the whole file are invented, none of them an effect on what a
respondent answers, and all four are named below.

## Estimated, calibrated, authored

**Estimated from the public panel** (`EUframes_cy.csv`, committed, so anyone
can re-derive these): each dimension's intercept, unemployment slope, growth
slope and year effects; the share of respondents who mention anything and its
own response to the same predictors; and the spread of country and country-year
deviations. The generator refits these every time it runs.

**Calibrated from the licensed person-level file** by
`companion/_model-outputs/calibrate_sim_params.R`, which writes only summaries
– marginal distributions and regression coefficients, the kind of quantity a
published appendix table carries. These are the age, sex and education
marginals; how each of those characteristics moves a respondent's framing
composition and their propensity to mention anything at all; and the
individual-level dispersion behind the Dirichlet concentration. The raw
microdata are GESIS-licensed and cannot be redistributed in any form, which is
why this file is simulated rather than sampled. The [repositories
module](../companion/repositories.qmd#sec-gesis) explains that regime. The
generator itself reads no microdata: only the committed summaries and the
public panel.

**Authored** – the four quantities corresponding to nothing measured. None of
them changes what a respondent answers; every individual-level effect in the
file is calibrated. What they govern is who ends up in the sample and how many
of them there are. They are the fieldwork selection tilt that gives `w1`
something to correct, at 0.15 per decade below the mean age; the switch that
makes that tilt grow with a cell's unemployment, zero by default; the cell size
as a fraction of the real respondent count, 0.10; and the mean mention count
`lambda_k` = 2.4 in `sim_calibration.csv`, which the recorded shares cannot
identify and which the Dirichlet concentration absorbs whatever value it takes.

**A respondent's own employment status is deliberately not in the file.**
Eurobarometer records occupation, so an indicator could in principle have been
calibrated from the licensed extract, but none was. An earlier version of this
twin authored one and set its prevalence to a fixed multiple of the country's
unemployment rate. That fused two constructs measured at different levels – a
labour market's unemployment rate and a person's employment status – and opened
a route from the macro rate into the cell mean that the cell-level recipe never
saw, which split every planted unemployment coefficient into two. It is gone,
and each macro slope now plants exactly one number.

## The recipe

A respondent either mentions nothing – with a probability that depends on their
own characteristics and on their country-year – or mentions K items, where
K = 1 + Poisson(2.4) truncated at 13. The mentions then divide across the four
dimensions by a Dirichlet-multinomial draw around an expected composition

$$
\text{composition}_{ict} \;=\; \underbrace{a_j + b_j\,\text{unemp}_{ct}
+ c_j\,\text{growth}_{ct} + \text{year}_{jt} + u_{jc} + u_{jct}}_{\text{the cell, from the public panel}}
\;+\; \underbrace{\text{own age, sex, education}}_{\text{from the calibration}} ,
$$

with the individual terms centred on the population marginals, so that a
representative sample comes close to the panel's cell values and the deliberate
age distortion is what moves them furthest. The match is close rather than
exact. Weighting the twin's respondents back to the population age
distribution, and averaging over the 270 cells, the positive composite lands
within a hundredth of a per cent of the panel's mean, the negative composite
1.8% below it, and the four dimensions between 0.5% and 2.4% away.

Two mechanisms produce that gap, in roughly one-to-three proportion. The
smaller is a covariance. Within a cell, education raises both the propensity to
mention anything and the cosmopolitan share while lowering the communitarian
one, so the mean of the product of mentioning and composition is not the
product of their means. On the communitarian dimension the expected conditional
share is 0.2032 and the expected observed share 0.1881, where independence
would give 0.1893; the panel's own mean is 0.1931, so the covariance accounts
for 0.0012 of a total gap of 0.0051. The larger mechanism is that the twin's
overall mentioning rate falls short of the panel's, 0.933 against 0.939, for
the reasons two paragraphs down.

Mentioning is modelled on the logit scale because it is the ceiling that binds
and not the floor. The modelled quantity is the probability of mentioning
something, which runs near 94%, and the calibrated education contrast of +1.11
on the logit works out as a marginal effect of about +0.064 at that rate. A
linear effect of that size puts graduates at 1.003 at the average rate and past
a probability of 1 in the majority of the panel's cells – equivalently, it
drives the probability of mentioning nothing below zero. The composition is
modelled linearly, where the parts are large enough for that to be safe.

The cell mentioning rate itself is built on the raw probability scale and only
then moved to the logit, which is where the shortfall above comes from. The
drawn cell rates run from 0.843 to 1.059, 31 of the 270 cells are drawn above 1
and 32 above 0.999, and the clip to [0.5, 0.999] that keeps `qlogis` finite
touches 11.8% of person-rows. The lower guard never binds anywhere in the
panel. Person-weighted, the drawn rate of 0.9372 falls to 0.9343 under the clip
and to 0.9314 under the demographic shift, because shifting on the logit scale
above one half costs a little through concavity; binomial luck then returns
0.9334.

Where a respondent's characteristics would still push a small dimension below a
floor of 0.002, their whole shift is scaled back just far enough to prevent it,
which preserves its direction; that touches about 5% of respondents, and for
3.2% the shift is scaled back to nothing at all. The floor is approximate
rather than exact, because a cell whose smallest dimension already sits below it
once the drawn deviations are added is lifted to the floor and renormalised
first. That happens to 18 of the 270 cells, about 7%, and to none of them before
the deviations are added. The realised minimum share is 0.00188.

Country and cell deviations are drawn fresh rather than copied from the real
countries, and are residualised against the full cell-level design – year
included, because growth is dominated by common shocks and a draw orthogonal to
raw growth can still correlate with it once year is absorbed. The projection is
exact in the metric it is carried out in. Regressed on that design, the
committed draw's cosmopolitan deviation has an unemployment slope of −2e-18,
which is zero to machine precision.

Weight the cells by their simulated size, or fit at person level, and a
residual reappears. Here it is −3.2e-04 on the conditional-share scale, which
once multiplied through by the mentioning rate is about 8% of the cosmopolitan
planted coefficient. That is a property of this particular draw rather than of
the recipe. Over 300 redraws of the same construction the size-weighted
residual is centred on zero, with a mean of −2.9e-05 against a spread of
3.8e-04, and the committed draw sits 0.84 of that spread out with 41% of
redraws further from zero.

## What the recipe plants

Each dimension's planted coefficient is the one the **real panel** yields under
the same specification, recorded in `companion/_model-outputs/sim_planted.csv`.
A model fitted to the twin should therefore land where the same model fitted to
the real data lands.

Each macro slope plants exactly one number. The only route from a country's
unemployment rate to a respondent's answer runs through the cell recipe, and
the generator's tuning loop sees that route in full, so there is no second
quantity for a reader to choose between. Growth is the same.

| Outcome | Unemployment | GDP growth |
|---|---:|---:|
| `cosmo` | −0.003561 | −0.000242 |
| `util` | −0.000678 | +0.001914 |
| `comm` | +0.005235 | −0.001629 |
| `lib` | +0.000105 | +0.000005 |
| `pos` | −0.004239 | +0.001672 |
| `neg` | +0.005340 | −0.001624 |

The substantive pattern is worth reading before modelling anything: rising
unemployment pushes framing away from *both* cosmopolitan and utilitarian
terms and towards communitarian ones, while libertarian framing barely moves.
Growth works differently again, lifting utilitarian framing most. Because the
dimensions share one instrument, an analyst who picks `util` and one who picks
`cosmo` are estimating genuinely different quantities, which is a large part of
why the outcome fork carries so much specification variance in the real
multiverse.

Every individual-level effect in the file is calibrated rather than authored,
and they sit in `sim_calibration_person.csv`. The largest is education, which moves
graduates about 0.12 towards cosmopolitan framing and 0.11 away from
communitarian, relative to those who left school by 15.

Every quantity in that calibration file is an effect on the composition among
respondents who mention something. The shares are undefined for anyone who
mentions nothing and are stored as zeros, so a fit that recovers these values
has to carry the filter `cosmo + util + comm + lib > 0`. The two estimands
genuinely differ, because education drives the propensity to mention as well as
the composition: the committed draw returns +0.112 for graduates on
cosmopolitan framing among mentioners, against a calibrated 0.124, but +0.140
on all rows.

Across the 20 independent draws recorded in
`companion/_model-outputs/sim_recovery_sweep.csv` the twin recovers the planted
values. The average of the 20 sits within 0.41 of a single draw's standard
deviation of the planted value on all twelve quantities. Measured instead
against the precision of that 20-draw average, every one of the twelve falls
inside two standard errors and the largest discrepancy is 1.8, which is what a
set of twelve should look like when there is nothing systematic in it. Twenty
draws cannot rule out a bias smaller than the noise, so this establishes that
the twin is unbiased to the precision twenty draws can see, not that it is
exactly unbiased.

That statement is stronger than it was. An earlier version of the generator
authored an `unemployed` indicator whose prevalence tracked the country's
unemployment rate, and the same sweep put its largest discrepancy at 2.8
standard errors – too large for twelve quantities to produce by chance. The
indicator was the source, and removing it removed the residual rather than
relabelling it.

A **single** draw lands on none of these values, and cannot: each cell mean is
an average over a tenth of the real respondents, so a cell-level slope carries a
standard error near a third of the anchor's own size. That is a property of the
design rather than a defect, and the simulation module makes it the lesson
rather than hiding it.

## The weight does real work

`w1` is a genuine weight, not decoration. The sample is drawn with a fieldwork
distortion – younger respondents over-selected by a factor of exp(0.15 ×
decades below the mean age), which pulls the achieved mean age down from the
population's 49.3 to about 45.4 – and `w1` is the exact reciprocal of that
selection factor, normalised to mean 1 within each country-year. Strictly it is
an inverse-probability-of-selection weight, since it undoes a selection rule
known exactly; the real Eurobarometer nation weight is a post-stratification
weight, reaching a similar place by aligning the achieved sample to known
population margins. Weighting recovers the population age, 49.4 against the
population's 49.3, and the positive composite to within a hundredth of a per
cent. The other five shares land between half a per cent and two and a half per
cent away rather than exactly on their values, for the reasons the recipe
section gives. Leaving the weight out biases all of them, because age genuinely
affects framing.

One row of `sim_calibration.csv` describes the real weight rather than this
one. `w1_sd_log` = 0.325 is the log spread of the Eurobarometer nation weight,
and the generator never reads it. The twin's weight is the exact reciprocal of
an authored age tilt, so its own spread – 0.239 in the committed draw – is
fixed by that tilt and the age distribution together, and could match a real
post-stratification weight's dispersion only by coincidence.

Because the distortion depends on age alone, `w1` is a deterministic function
of `age` within a cell, so adjusting for age does the same work as weighting.
That equivalence is specific to this construction – a real weight corrects
margins a model may not contain – but it is worth knowing before drawing
general conclusions from the comparison.

The distortion is constant across cells by default, so it shifts levels without
biasing the macro slopes. Set `SIM_DISTORT_SLOPE` above zero in the generator
and it grows with a cell's unemployment, at which point the slopes themselves
are biased unless the weight is used. Values up to about 0.03 keep the tilt
positive everywhere; 0.01 is a good setting to try.

## Variables

| Variable | Description |
|------------------------------------|------------------------------------|
| `pid` | Simulated person identifier |
| `cntry` | ISO 3166 two-letter code, as in `EUframes_cy.csv` |
| `year` | Year (2004–2013) |
| `w1` | Selection weight, mean 1 within country-year to within the 4-decimal rounding; the observed maximum deviation is 1.5e-5 (see above) |
| `age` | Simulated age, 15–98; carries its real calibrated effect |
| `female` | Simulated indicator at the calibrated marginal (0.546); carries its real calibrated effect |
| `edu4` | Simulated education band (`le15` / `e16_19` / `e20plus` / `studying`) at calibrated marginals; carries its real calibrated effects, the largest in the file |
| `cosmo`, `util`, `comm`, `lib` | Simulated dimension shares; sum to 1 for anyone who mentions anything, to 0 otherwise |
| `pos`, `neg` | Composites: `pos` = `cosmo` + `util`, `neg` = `comm` + `lib` |
| `unemp`, `growth`, `bailout` | Real published values, joined from `EUframes_cy.csv` |

The six share columns are stored rounded to six decimals, so the compositional
identities hold to a tolerance rather than exactly: test them with
`abs(cosmo + util + comm + lib - 1) < 5e-6`, not with `==`. The single identity
that survives exact comparison is `pos + neg == 1` for mentioners, because that
rounding is symmetric – and it is the identity the workshop's claim-alignment
convention actually rests on.

The shares are ratios of small integers, so exact 0 and exact 1 are common
rather than rare. Of all respondents, about 23% score exactly 0 on `cosmo` and
about 23% exactly 1. That is faithful to the real instrument, and it is why
beta regression cannot be used at person level. It can normally be used on
country-year means, where averaging moves cells inside the unit interval – but
check rather than assume, because at the smallest cell sizes it does not always.

## Scale and provenance

41,660 rows across all 270 country-year cells (27 countries × 10 years), each
cell sized at 10% of its real respondent count, from 50 respondents to 361. The
macro columns are real published aggregates carried over from the public panel
(World Bank and European Commission); everything at person level is synthetic.
Default seed 20260727, overridable with `$SIM_SEED`.

## Licence

Simulated data, generator and calibration summaries: CC BY 4.0. Attribute as
"Chris Moreh, *EU-frames simulated person-level twin*, CC BY 4.0", with a link
to the workshop site.

The file has four layers and they do not all sit under the same terms. The
person-level records are synthetic throughout, generated by
`simulate_person_twin.R` from the public country-year panel and the three
committed calibration files, and nothing else. The derived aggregates inherit
whatever governs that public panel. The macro columns `unemp`, `growth` and
`bailout` come from World Bank and European Commission series. And no
Eurobarometer microdata are present at any point.

On the GESIS terms, the position is a reading rather than a settled fact, and
it is worth stating as one. The licensed respondent file was read once, by
`calibrate_sim_params.R`, to estimate the marginal summaries and coefficients
listed above. Those are aggregate statistics of the kind the usage regulations
describe as "summarizing representations of the data typical to scientific
works and presentations", so releasing them is provided for. The regulations
are then silent on synthetic derivatives: no clause addresses whether a
generated file containing none of the original records falls inside or outside
"the provided data". Read on the ordinary meaning of that phrase, it falls
outside, which is why this file is released under CC BY. Anyone redistributing
it should carry this paragraph with it rather than the conclusion alone.
