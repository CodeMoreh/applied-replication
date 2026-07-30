# Codebook: `EUframes_cy.csv`

Country-year panel built for the workshop "Applied Replication for Data Skills" (first delivered at the Open Research Conference, Newcastle University, June 2026). One row per EU member state per year, 2004–2013 (27 countries × 10 years = 270 rows).

## Sources and construction

Individual-level data: 16 Eurobarometer waves (EB 61.0, 62.0, 63.4, 64.2, 65.2, 67.2, 69.2, 70.1, 72.4, 73.4, 74.2, 75.3, 76.3, 77.3, 78.1, 79.3), GESIS scientific-use files, as analysed in Teney (2016, *European Sociological Review* 32(5): 619–633) and in the Multi100 reanalysis of that paper (analyst C6HJR, https://osf.io/8rtwe/). The raw microdata are **not redistributable** – obtain them from GESIS (https://search.gesis.org/) under their usage terms. This file contains only derived country-year aggregates.

The four framing scales follow Teney (2016: 623): for each respondent, the number of mentioned items belonging to a dimension divided by the respondent's total number of mentioned items (13 items; the 'Euro' item is excluded, following the original paper's footnote 1). Respondents who mention no items score 0, matching the convention in the published replication script. Scales are then averaged within country-year.

Dimension item assignment (questionnaire item → dimension):

| Dimension | Items |
|------------------------------------|------------------------------------|
| Cosmopolitan (positive, non-materialist) | Peace; Democracy; Freedom to travel, study and work anywhere in the EU; Cultural diversity; Stronger say in the world |
| Utilitarian (positive, materialist) | Economic prosperity; Social protection |
| Communitarian (negative, non-materialist) | Unemployment; Loss of cultural identity; More crime; Not enough control at external borders |
| Libertarian (negative, materialist) | Bureaucracy; Waste of money |

**Provenance note.** This panel was rebuilt independently from the raw GESIS files, using the sixteen-wave inventory above. The as-submitted Multi100 artefact (`rep_data.csv`) is preserved unchanged alongside it, and how the two builds relate is worked through during the workshop's Block 2.

## Variables

| Variable | Description |
|------------------------------------|------------------------------------|
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

Three different regimes apply to the three layers of this file.

- **Derived aggregate data** (this file): CC BY 4.0.
- **Underlying microdata**: GESIS Eurobarometer terms apply, and nothing individual-level may be redistributed.
- **Macro indicators**: World Bank Open Data (CC BY 4.0).
