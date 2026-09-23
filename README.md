# Applied Replication for Data Skills

A hands-on course in applied replication for data skills, deliverable from one day to a semester, with a one-day workshop at its centre. Facilitator: [Chris Moreh](https://chrismoreh.com). This repository holds the course website, the reveal.js slide deck and a zero-install browser lab. Most recently delivered online at the Făgăraș Summer School, 3 August 2026.

Course participants will complete a guided robustness reanalysis of one of the same articles reanalysed by the facilitator as part of a large replication exercise recently published in *Nature* (Aczel et al., 2026) in a special section bringing together two other papers from the same multi-year meta-project (*Systematizing Confidence in Open Research and Evidence* (SCORE) – Alipourfard et al., 2021). Participants will import data directly from an OSF repository and reproduce a constrained model, then choose one analytical deviation, make a reasoned argument for their choices supported by a Directed Acyclic Graph (DAG), preregister that choice in a shortened but real preregistration template completed before anything is run, and submit the result to a live class specification curve.

## Where the site lives

The site deploys to GitHub Pages at <https://codemoreh.github.io/applied-replication/>.


## What happens

The session moves through four concepts. First, the three Rs – reproducibility, robustness and replicability – grounded in three *Nature* (2026) reports measuring these outcomes across the SCORE sample of published social and behavioural science articles. Second, those three Rs are traced through the EU-frames case, a 2016 study of the correlates of EU framing in Eurobarometer data, written by the original author (OA). Third, estimands and DAGs: distinguishing theoretical, empirical and estimation targets, and reading confounders, mediators and colliders off causal graphs. Fourth, the specification menu and the multiverse, which show what each analytical choice does to the estimate, and what a curve of results across a whole set of defensible analyses can and cannot establish.

## How the work is done

Participants install R and an IDE (Positron, RStudio, VS Code, etc.) and download the workspace as a zip from the companion repository [`CodeMoreh/replication-lab`](https://github.com/CodeMoreh/replication-lab), unzip it, and open the folder in their IDE. No git, no cloning, no account. The folder holds the working script, the helper functions, the data and a report skeleton carrying Tasks 1–5 with the preregistration block. Models are fitted live.

The [browser lab](exercise/browser-lab.qmd) holds the same Tasks 1–5 on webR and quarto-live, with the data pre-loaded and nothing installed, reading its results from the pre-computed grid. It is the page the facilitator drives on a shared screen, a place for anyone to try the exercise without an installation, and the fallback when a machine fails. Both submit results through the same one-click `report_result()` link, which drops a dot on the live [Multiverse](results.qmd) chart.

## Repository layout

| Path | What it is |
|------------------------|-----------------------------------------------|
| `index.qmd` | Home: welcome, overview, how the work is done, schedule |
| `setup.qmd` | Pre-workshop preparation: the installation, the browser lab, what you do not need, optional readings |
| `tracks/` | Six tracks through the same material, one folder each with a docked sidebar: three one-day formats (open science and replication; social data science tools; the statistical methods), three days, a semester, self-study |
| `slides/` | The reveal.js decks: `index.qmd` is the full deck, the variants (`one-day-*.qmd`, `three-days.qmd`) include the same segment files under `_segments/` in their own order; each track's slides page embeds the deck it runs on |
| `exercise/index.qmd` | Full task description: the claim, the five analysts, Tasks 1–5 |
| `exercise/browser-lab.qmd` | Tasks 1–5 running in the browser (webR / quarto-live), for demonstration and practice |
| `exercise/spec-menu.qmd` | Specification menu for the chosen deviation: fourteen axes, grouped into estimand, measurement and estimation decisions |
| `exercise/estimand-dial.qmd` | Estimand choices (OJS): set the fourteen choices, read the question the six Level 1 ones ask, and watch how far the measurement and estimation options of that one question spread |
| `exercise/cheatsheet.qmd` | Wallet card: URLs, the four cells that land a dot, fallbacks |
| `companion/` | Nine self-study modules in three strands, carrying most of the teaching in the course |
| `results.qmd` | Multiverse: specification curve chart and five-analyst comparison |
| `resources.qmd` | Readings, estimand theory, case-study references, tool docs |
| `data/` | Committed course datasets and codebooks (see below) |
| `.github/workflows/publish.yml` | CI: render and deploy to GitHub Pages |

## The data

The `data/` directory holds the committed course datasets and their codebooks, served verbatim so the browser lab can fetch them.

| File | What it is |
|------------------------|-----------------------------------------------|
| `rep_data.csv` | The as-submitted Multi100 artefact (270 country-years), kept for provenance; nothing on the site reads it |
| `EUframes_cy.csv` | The EU-frames panel, rebuilt from the raw GESIS microdata |
| `EUframes_cy_codebook.md` | Codebook for `EUframes_cy.csv` (sources, scales, variables, licence) |
| `spec_grid.csv` | 840 pre-computed specifications across the task menu |
| `spec_grid_family.csv` | The family universe of 1,680: the 840 above plus a beta twin of each |
| `spec_grid_full.csv` | 2,520 specifications, adding GDP growth as a claim-carrying predictor |
| `grid/` | The maximal fourteen-axis grid, one gzipped file per estimand cell (named by the six Level 1 choices), with `manifest.csv`, `axes.csv`, `canonical_rca.csv` and `cells_summary.csv` alongside; the browser lab and the estimand choices page read these |
| `spec_grid_mi.csv` | Pooled multiple-imputation results for the no-opinion axis (mice and Amelia, ten imputations each), with `mi_diagnostics.csv` |
| `spec_grid_measure.csv`, `spec_grid_weights.csv` | The measure axis and the weighting axes fitted around the canonical menu |
| `teney_panel_measurement.csv` | The country-year panel under every measurement variant: outcome construction, item set, no-opinion rule, cell weighting |
| `teney_panel_weights.csv` | Per-cell respondent counts, effective sample sizes, no-opinion counts and adult population |
| `macro/predictor_measures.csv` | The published unemployment and growth series that the measure axis chooses between |
| `decision_levels_maximal.csv`, `decision_classes_maximal.csv`, `axis_level_summary_maximal.csv` | Every axis of the maximal grid classified as an estimand, measurement or estimation decision, with the share of variance and of p = .05 crossings it carries, the nested share by level, and every level's claim and significance shares |
| `fork_importance.csv` | Share of specification variance carried by each menu axis |
| `analysts5.csv` | The five Multi100 analysts' results for the constrained claim |
| `class_results.csv` | Committed fallback for the live class chart when the results feed is unreachable |
| `EUframes_person_full.csv` | Simulated person-level twin of the panel (41,660 rows), with its own codebook alongside |

**OSF nodes.** The course fetches from [osf.io/6zqct](https://osf.io/6zqct), the facilitator's personal extended fork of the official archival Multi100 component for analyst C6HJR [osf.io/8rtwe](https://osf.io/8rtwe). The full SCORE dossier on the reanalysed paper is [osf.io/h7432](https://osf.io/h7432).

**Microdata are not redistributed.** The raw Eurobarometer microdata are GESIS-licensed and are not committed or redistributed here. Obtain them from GESIS (<https://search.gesis.org/>) under their usage terms if you want to reproduce the whole data pipeline, or to build alternative models that rely on individual-level data. This repository contains only derived country-year aggregates.

## Sources, credits and licensing

The macro indicators (growth, unemployment, bailout) come from World Bank Open Data (CC BY 4.0). The underlying Eurobarometer microdata remain subject to GESIS terms. The derived aggregate data and the rendered website content are released under [Creative Commons Attribution 4.0 International (CC BY 4.0)](LICENSE).