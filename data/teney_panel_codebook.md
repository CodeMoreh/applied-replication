# Codebook: `teney_panel.csv`

Country-year panel built for the workshop "Applied replication for data skills" (Open Research Conference, Newcastle University, 16 June 2026). One row per EU member state per year, 2004–2013 (27 countries × 10 years = 270 rows).

## Sources and construction

Individual-level data: 16 Eurobarometer waves (EB 61.0, 62.0, 63.4, 64.2, 65.2, 67.2, 69.2, 70.1, 72.4, 73.4, 74.2, 75.3, 76.3, 77.3, 78.1, 79.3), GESIS scientific-use files, as analysed in Teney (2016, *European Sociological Review* 32(5): 619–633) and in the Multi100 reanalysis of that paper (analyst C6HJR, https://osf.io/8rtwe/). The raw microdata are **not redistributable** – obtain them from GESIS (https://search.gesis.org/) under their usage terms. This file contains only derived country-year aggregates.

The four framing scales follow Teney (2016: 623): for each respondent, the number of mentioned items belonging to a dimension divided by the respondent's total number of mentioned items (13 items; the 'Euro' item is excluded, following the original paper's footnote 1). Respondents who mention no items score 0, matching the convention in the published replication script. Scales are then averaged within country-year.

Dimension item assignment (questionnaire item → dimension):

| Dimension | Items |
|---|---|
| Cosmopolitan (positive, non-materialist) | Peace; Democracy; Freedom to travel, study and work anywhere in the EU; Cultural diversity; Stronger say in the world |
| Utilitarian (positive, materialist) | Economic prosperity; Social protection |
| Communitarian (negative, non-materialist) | Unemployment; Loss of cultural identity; More crime; Not enough control at external borders |
| Libertarian (negative, materialist) | Bureaucracy; Waste of money |

**Wave-set note.** The original data-prep script read the EB 70.1 file (ZA4819) twice: once for 2008 (correct) and again in place of EB 72.4 (ZA4994) for the year 2009 (incorrect). The analyst spotted and corrected this during the project – the annotated script in the fork's `moreh_rep_vAPR2025/` folder (osf.io/6zqct) carries the note "APRIL 2025 – Mistake in dataset here; the dataset associated with 'eb724' should be 'ZA4994_v3-0-0.dta'". The official Multi100 component (osf.io/8rtwe) preserved only the earlier, uncorrected folder; the correction is published in the fork. This panel uses the corrected wave set (ZA4994 for 2009) and was rebuilt independently from the raw GESIS files. A rebuild using the as-published wave set reproduces the `rep_data.csv` aggregates to machine precision (max diff 5.6e-17), which verifies that the rest of the pipeline is identical. The constrained Multi100 Task-2 model (`mcosmo ~ unemp_c`, two-way fixed effects) gives t = −3.853 on the published `rep_data.csv` and t = −3.804 on this corrected panel; the latter matches the result recorded for analyst C6HJR in the Multi100 dataset, confirming which dataset produced the recorded value.

## Variables

| Variable | Description |
|---|---|
| `country` | Country name |
| `cntry` | ISO 3166 two-letter code (DE combines East/West samples; GB combines Great Britain and Northern Ireland) |
| `year` | Survey year (2004–2013); years with two waves pool both |
| `mcosmo` | Mean cosmopolitan framing scale (0–1) |
| `mutil` | Mean utilitarian framing scale (0–1) |
| `mcomm` | Mean communitarian framing scale (0–1) |
| `mlib` | Mean libertarian framing scale (0–1) |
| `mpos` | Mean positive framing scale (cosmopolitan + utilitarian items) |
| `mneg` | Mean negative framing scale (communitarian + libertarian items) |
| `n_cy` | Number of respondents in the country-year cell |
| `growth` | GDP growth, annual % (World Bank, NY.GDP.MKTP.KD.ZG), as in the published replication |
| `unemp` | Unemployment, % of total labour force, national estimate (World Bank / ILOSTAT, SL.UEM.TOTL.NE.ZS), as in the published replication |
| `bailout` | 1 if an EU/IMF financial assistance programme was active in the country-year: HU 2008–2010, LV 2008–2011, RO 2009–2013 (balance-of-payments facility); GR 2010–2013, IE 2010–2013, PT 2011–2013, ES 2012–2013 (bank recapitalisation), CY 2013 (EFSF/EFSM/ESM). Source: European Commission, EU financial assistance programme records |

## Licence

Derived aggregate data: CC BY 4.0. Underlying microdata: GESIS Eurobarometer terms apply. Macro indicators: World Bank Open Data (CC BY 4.0).
