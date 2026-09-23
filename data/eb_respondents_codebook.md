# Codebook: `eb_respondents.rds`

**This file is not distributed.** It is derived from sixteen Eurobarometer scientific-use files that GESIS licenses to each user individually, and it is built on your own machine by `prep/01_build_respondents.R` in the workspace from the files you downloaded under your own GESIS account. The [data sources module](../companion/data-sources.html#sec-gesis) walks through the download and the terms of use; the [data management module](../companion/data-management.html) walks through the build. The file lives in `data_private/`, which the workspace never commits. This codebook is published so that the respondent-level outputs on the course site can be read by anyone, whether or not they hold the file.

One row per respondent interviewed in one of the twenty-seven member states of the period, in the sixteen waves: 416,698 rows, 31 columns. The GESIS terms of use apply to every row: no redistribution, no publication of individual cases, no processing by AI systems.

## Sources

| Wave | Study | Version | Fieldwork year | Respondents (EU-27) |
|---|---|---|---|---:|
| EB 61.0 | ZA4056 | 1.0.1 | 2004 | 16,216 |
| EB 62.0 | ZA4229 | 1.1.0 | 2004 | 26,807 |
| EB 63.4 | ZA4411 | 1.1.0 | 2005 | 26,823 |
| EB 64.2 | ZA4414 | 1.1.0 | 2005 | 26,925 |
| EB 65.2 | ZA4506 | 1.0.1 | 2006 | 26,665 |
| EB 67.2 | ZA4530 | 2.1.0 | 2007 | 26,717 |
| EB 69.2 | ZA4744 | 5.0.0 | 2008 | 26,661 |
| EB 70.1 | ZA4819 | 3.0.2 | 2008 | 26,618 |
| EB 72.4 | ZA4994 | 3.0.0 | 2009 | 26,731 |
| EB 73.4 | ZA5234 | 2.0.1 | 2010 | 26,641 |
| EB 74.2 | ZA5449 | 2.2.0 | 2010 | 26,723 |
| EB 75.3 | ZA5481 | 2.0.1 | 2011 | 26,713 |
| EB 76.3 | ZA5567 | 2.0.1 | 2011 | 26,594 |
| EB 77.3 | ZA5612 | 2.0.0 | 2012 | 26,637 |
| EB 78.1 | ZA5685 | 2.0.0 | 2012 | 26,622 |
| EB 79.3 | ZA5689 | 2.0.0 | 2013 | 26,605 |

The spring 2004 wave predates the accession of the ten new member states, which is why it has fifteen states and fewer respondents. Germany and the United Kingdom are sampled as two regions each (East and West; Great Britain and Northern Ireland) and are combined into one country each, as in the published analysis.

## Variables

| Variable | Description |
|---|---|
| `study` | GESIS study number (`ZA4056` to `ZA5689`) |
| `eb` | Eurobarometer wave (`61.0` to `79.3`) |
| `year` | Fieldwork year the course assigns the wave to, 2004–2013; two waves share 2004, 2005, 2008, 2010, 2011 and 2012 |
| `cntry` | ISO 3166 two-letter code of the member state, as in `EUframes_cy.csv` |
| `w1` | The design weight GESIS supplies with each wave (variable `W1`), which corrects each national sample to its population on sex, age, region and community size; mean about 1 within a country |
| `it1` … `it14` | The fourteen items of "What does the European Union mean to you personally?", 1 if mentioned and 0 otherwise: 1 peace · 2 economic prosperity · 3 democracy · 4 social protection · 5 freedom to travel, study and work anywhere in the EU · 6 cultural diversity · 7 stronger say in the world · 8 euro · 9 unemployment · 10 bureaucracy · 11 waste of money · 12 loss of our cultural identity · 13 more crime · 14 not enough control at external frontiers |
| `oth` | 1 if the respondent gave a spontaneous other answer |
| `dk` | 1 if the respondent answered "don't know" |
| `age` | Age in years |
| `female` | 1 if female |
| `edu_raw` | The GESIS code for the age at which full-time education finished: the age itself, 97 for no full-time education, 98 for still studying |
| `edu` | Age at which full-time education finished, coded as the published analysis codes it: still studying replaced by the respondent's current age; no full-time education and refusals set to missing |
| `edu3` | The published three education bands from `edu`: `low` (under 16), `mid` (16 to 19), `high` (20 and over) |
| `edu4` | The four-band coding: `le15` (15 or under, including no full-time education), `e16_19`, `e20plus`, `studying` |
| `ses` | Socio-economic position from the occupation item, in the eight groups of the published models: `manual`, `self_employed`, `manager`, `white_collar`, `house_person`, `unemployed`, `retired`, `student` |
| `unemployed` | 1 if `ses` is `unemployed` |
| `urban` | Type of community: `rural`, `small_town`, `large_town` |
| `rile` | Left–right self-placement, 1 to 10; asked in twelve of the sixteen waves and missing by design in the other four |

The euro item (`it8`) is carried but not scored in any of the course's scales, following the published paper. The framing scales themselves are not in this file: they are built from the items in `prep/02_scales_and_panel.R`, where the scoring rule is a decision rather than a column.

## What is derived from it

| File | Rows | What |
|---|---:|---|
| `EUframes_cy.csv` | 270 | The course panel: as-interviewed cell means of the six scales, respondent counts, the macro series |
| `EUframes_cy_edu.csv` | 810 | The same means by country, year and education band (`edu3`), with the respondent count behind each |
| `teney_panel_weights.csv` | 270 | Design-weighted and count-built cell means, effective sample sizes, no-opinion counts, population denominators |
| `teney_panel_measurement.csv` | 38,880 | Cell means under every combination of scoring rule, item set, no-opinion rule and cell weighting |

All four are aggregates of at least several hundred respondents per cell and travel under CC BY 4.0.
