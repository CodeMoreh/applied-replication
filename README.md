# Applied Replication for Data Skills

A hands-on, one-day workshop in applied replication for data skills. Facilitator: [Chris Moreh](https://chrismoreh.com). This repository holds the workshop website, the reveal.js slide deck and a zero-install browser lab. Most recently delivered at the Open Research Conference, Newcastle University, 16 June 2026.

Workshop participants will complete a guided robustness reanalysis of one of the same articles reanalysed by the facilitator as part of a large replication exercise recently published in *Nature* (Aczel et al., 2026) in a special section bringing together two other papers from the same multi-year meta-project (*Systematizing Confidence in Open Research and Evidence* (SCORE) – Alipourfard et al., 2021). Participants will import data directly from an OSF repository and reproduce a constrained model, then choose one analytical deviation, make a reasoned argument for their choices supported by a Directed Acyclic Graph (DAG), preregister that choice in a shortened but real preregistration template completed before anything is run, and submit the result to a live class specification curve.

## Where the site lives

The site deploys to GitHub Pages at <https://codemoreh.github.io/applied-replication/>.


## What happens

The session moves through three distinct concepts. First, the three Rs – reproducibility, robustness and replicability – grounded in three *Nature* (2026) reports measuring these outcomes across SCORE's sample of published social and behavioural science articles. Second, those three Rs are traced through the EU-frames case, a 2016 study of the correlates of EU framing in Eurobarometer data, written by the paper's original author (OA). Third, estimands and DAGs: distinguishing theoretical, empirical and estimation targets, and reading confounders, mediators and colliders off causal graphs.

## Two ways to take part

The two routes have full parity: every task exists in both, and both reach the same numbers.

- **Route 1 – Positron workspace.** Participants download the workspace as a zip from the companion repository [`CodeMoreh/replication-lab`](https://github.com/CodeMoreh/replication-lab), unzip it, and open the folder in Positron. No git, no cloning, no account. The folder holds the working script, the helper functions, the data and a report skeleton carrying Tasks 1–7 with the preregistration block. Models are fitted live.
- **Route 2 – Browser lab (zero-install).** Participants open the [browser lab](exercise/browser-lab.qmd), which runs Tasks 1–7 in-browser via webR and quarto-live. Nothing is installed, the data is pre-loaded, and work persists in the tab until refresh.

Both routes submit results through the same one-click `report_result()` link, which drops a dot on the live [Multiverse](results.qmd) chart.

## Repository layout

| Path | What it is |
|------------------------|-----------------------------------------------|
| `index.qmd` | Home: welcome, overview, route selection, schedule |
| `setup.qmd` | Pre-workshop preparation: the two routes, what you do not need, optional readings |
| `slides/index.qmd` | The reveal.js deck |
| `exercise/index.qmd` | Full task description: the claim, the five analysts, Tasks 1–7 |
| `exercise/browser-lab.qmd` | Runnable Route 2 version of Tasks 1–7 (webR / quarto-live) |
| `exercise/spec-menu.qmd` | Specification menu for the chosen deviation (eight analytical axes) |
| `exercise/cheatsheet.qmd` | Wallet card: URLs, the four cells that land a dot, fallbacks |
| `companion/` | Seven optional self-study modules around the day |
| `results.qmd` | Multiverse: specification curve chart and five-analyst comparison |
| `resources.qmd` | Readings, estimand theory, case-study references, tool docs |
| `data/` | Committed workshop datasets and codebooks (see below) |
| `.github/workflows/publish.yml` | CI: render and deploy to GitHub Pages |

## The data

The `data/` directory holds the committed workshop datasets and their codebooks, served verbatim so the browser lab can fetch them.

| File | What it is |
|------------------------|-----------------------------------------------|
| `rep_data.csv` | As-published aggregates (270 country-years), with the original wave set |
| `EUframes_cy.csv` | Corrected panel, rebuilt independently from the raw GESIS microdata |
| `EUframes_cy_codebook.md` | Codebook for `EUframes_cy.csv` (sources, scales, variables, licence) |
| `spec_grid.csv` | 840 pre-computed specifications across the task menu |
| `spec_grid_family.csv` | The family universe of 1,680: the 840 above plus a beta twin of each |
| `spec_grid_full.csv` | 2,520 specifications, adding GDP growth as a claim-carrying predictor |
| `fork_importance.csv` | Share of specification variance carried by each menu axis |
| `analysts5.csv` | The five Multi100 analysts' results for the constrained claim |
| `class_results.csv` | Committed fallback for the live class chart when the results feed is unreachable |
| `EUframes_person_sim.csv` | Simulated person-level teaching twin, with its own codebook alongside |

**OSF nodes.** The workshop fetches from [osf.io/6zqct](https://osf.io/6zqct), the facilitator's personal extended fork of the official archival Multi100 component for analyst C6HJR [osf.io/8rtwe](https://osf.io/8rtwe). The full SCORE dossier on the reanalysed paper is [osf.io/h7432](https://osf.io/h7432).

**Microdata are not redistributed.** The raw Eurobarometer microdata are GESIS-licensed and are not committed or redistributed here. Obtain them from GESIS (<https://search.gesis.org/>) under their usage terms if you want to reproduce the whole data pipeline, or to build alternative models that rely on individual-level data. This repository contains only derived country-year aggregates.

## Sources, credits and licensing

The macro indicators (growth, unemployment, bailout) come from World Bank Open Data (CC BY 4.0). The underlying Eurobarometer microdata remain subject to GESIS terms. The derived aggregate data and the rendered website content are released under [Creative Commons Attribution 4.0 International (CC BY 4.0)](LICENSE).