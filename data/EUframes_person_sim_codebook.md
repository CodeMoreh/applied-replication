# Codebook: `EUframes_person_sim.csv`

**This file is simulated.** No Eurobarometer respondent appears in it, and
nothing in it should be used for substantive inference about EU framing. It
exists for teaching: a person-level dataset built to carry the EU-frames
analysis as the original author carried it – all four framing dimensions and
both composites, both macro predictors, and the individual controls – while
being fully synthetic, so that for once the true answer is known before any
model runs. It is used throughout the [simulation
module](../companion/simulation.qmd).

## The design in one paragraph

Every framing dimension has its own response to unemployment and to growth,
estimated from the public country-year panel under the specification the
workshop's own anchor uses. Nothing is induced from any one privileged
dimension: the four shares sum to one because that is what the survey
instrument makes them do, and a set of coefficients estimated the same way on
all four automatically sums to zero, so no dimension has to be held passive to
keep the composition intact. Individual characteristics carry the effects they
carry in the real respondents. Only four quantities in the whole file are
invented, and they are named below.

## What is estimated, what is calibrated, what is authored

**Estimated from the public panel** (`EUframes_cy.csv`, committed, so anyone
can re-derive these): each dimension's intercept, unemployment slope, growth
slope and year effects; the share of respondents who mention anything and its
own response to the same predictors; and the spread of country and country-year
deviations. The generator refits these every time it runs.

**Calibrated from the licensed person-level file** by
`companion/_model-outputs/calibrate_sim_params.R`, which writes only summaries
– marginal distributions and regression coefficients, the kind of quantity a
published appendix table carries: the age, sex and education marginals; how
each of those characteristics moves a respondent's framing composition and
their propensity to mention anything at all; and the individual-level
dispersion behind the Dirichlet concentration. The raw microdata are
GESIS-licensed and cannot be redistributed in any form, which is why this file
is simulated rather than sampled; the [repositories
module](../companion/repositories.qmd#sec-gesis) explains that regime. The
generator itself reads no microdata: only the committed summaries and the
public panel.

**Authored** – the only quantities corresponding to nothing measured: the
`unemployed` indicator, its prevalence rule and its effect on framing; and the
fieldwork selection tilt that gives `w1` something to correct.

## The recipe

A respondent either mentions nothing – with a probability that depends on their
own characteristics and on their country-year – or mentions K items, where
K = 1 + Poisson(2.4) truncated at 13. The mentions then divide across the four
dimensions by a Dirichlet-multinomial draw around an expected composition

$$
\text{composition}_{ict} \;=\; \underbrace{a_j + b_j\,\text{unemp}_{ct}
+ c_j\,\text{growth}_{ct} + \text{year}_{jt} + u_{jc} + u_{jct}}_{\text{the cell, from the public panel}}
\;+\; \underbrace{\text{own age, sex, education, employment}}_{\text{from the calibration}} ,
$$

with the individual terms centred on the population marginals so that a
representative sample reproduces the panel's cell values and only the
deliberate age distortion moves them. Mentioning is modelled on the logit
scale, because at a base rate near six per cent a linear education effect would
drive the probability below zero for most graduates; the composition is
modelled linearly, where the parts are large enough for that to be safe. Where
a respondent's characteristics would still push a small dimension below a floor
of 0.002, their whole shift is scaled back just far enough to prevent it, which
preserves its direction; that touches about 5% of respondents.

Country and cell deviations are drawn fresh rather than copied from the real
countries, and are residualised against the full cell-level design – year
included, because growth is dominated by common shocks and a draw orthogonal to
raw growth can still correlate with it once year is absorbed. The result is
that this draw carries no accidental confounding.

## The truths

Each dimension's true coefficient is the one the **real panel** yields under
the same specification, recorded in `companion/_model-outputs/sim_truths.csv`.
A model fitted to the twin should therefore land where the same model fitted to
the real data lands.

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
terms and towards communitarian ones, while libertarian framing barely moves;
growth works differently again, lifting utilitarian framing most. Because the
dimensions share one instrument, an analyst who picks `util` and one who picks
`cosmo` are estimating genuinely different quantities, which is a large part of
why the outcome fork carries so much specification variance in the real
multiverse.

Authored individual-level truths, on the same share scale: being unemployed
oneself moves the composition by (−0.04 cosmopolitan, −0.01 utilitarian,
+0.04 communitarian, +0.01 libertarian). The calibrated demographic effects sit
in `sim_calibration_person.csv`; the largest is education, which moves
graduates about 0.12 towards cosmopolitan framing and 0.11 away from
communitarian, relative to those who left school by 15.

Across 20 independent draws the twin recovers every one of these within
sampling error. A **single** draw does not, and cannot: each cell mean is an
average over a tenth of the real respondents, so a cell-level slope carries a
standard error near a quarter of the anchor's own size. That is a property of
the design rather than a defect, and the simulation module makes it the lesson
rather than hiding it.

## The weight

`w1` is a genuine weight, not decoration. The sample is drawn with a fieldwork
distortion – younger respondents over-selected by a factor of exp(0.15 ×
decades below the mean age), which pulls the achieved mean age down from the
population's 49.3 to about 45.4 – and `w1` is the exact reciprocal of that
selection factor, normalised to mean 1 within each country-year. Strictly it is
an inverse-probability-of-selection weight, since it undoes a selection rule
known exactly; the real Eurobarometer nation weight is a post-stratification
weight, reaching a similar place by aligning the achieved sample to known
population margins. Weighting recovers the population age and the population
composition; leaving it out biases both, because age genuinely affects framing.

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
| `w1` | Selection weight, mean 1 within country-year to within 1e-5 (see above) |
| `age` | Simulated age, 15–98; carries its real calibrated effect |
| `female` | Simulated indicator at the calibrated marginal (0.546); carries its real calibrated effect |
| `edu4` | Simulated education band (`le15` / `e16_19` / `e20plus` / `studying`) at calibrated marginals; carries its real calibrated effects, the largest in the file |
| `unemployed` | **Authored** indicator; probability is 0.6 × the cell's real unemployment rate as a proportion, so about 5% at the average |
| `cosmo`, `util`, `comm`, `lib` | Simulated dimension shares; sum to 1 for anyone who mentions anything, to 0 otherwise |
| `pos`, `neg` | Composites: `pos` = `cosmo` + `util`, `neg` = `comm` + `lib` |
| `unemp`, `growth`, `bailout` | Real published values, joined from `EUframes_cy.csv` |

The six share columns are stored rounded to six decimals, so the compositional
identities hold to a tolerance rather than exactly: test them with
`abs(cosmo + util + comm + lib - 1) < 5e-6`, not with `==`. The single identity
that survives exact comparison is `pos + neg == 1` for mentioners, because that
rounding is symmetric – and it is the identity the workshop's claim-alignment
convention actually rests on.

The shares are ratios of small integers, so they take exact 0 and exact 1
values in quantity: of all respondents, about 23% score exactly 0 on `cosmo`
and about 23% exactly 1. That is faithful to the real instrument, and it is why
beta regression cannot be used at person level. It can normally be used on
country-year means, where averaging moves cells inside the unit interval – but
check rather than assume, because at the smallest cell sizes it does not always.

## Scale and provenance

41,658 rows across all 270 country-year cells (27 countries × 10 years), each
cell sized at 10% of its real respondent count. The macro columns are real
published aggregates carried over from the public panel (World Bank and
European Commission); everything at person level is synthetic. Default seed
20260727, overridable with `$SIM_SEED`.

## Licence

Simulated data, generator and calibration summaries: CC BY 4.0. No GESIS terms
attach to this file, because it contains no Eurobarometer microdata: the
licensed file was read once to estimate the marginal summaries and coefficients
listed above, which are aggregate statistics of the kind the usage terms
describe as "summarizing representations of the data typical to scientific
works and presentations".
