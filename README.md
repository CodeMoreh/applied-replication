# Applied Replication for Data Skills

A hands-on workshop for the Open Research Conference, Newcastle University, on Tuesday 16 June 2026 (10:15–12:45, Room 1.06, Henry Daysh Building). Facilitator: [Chris Moreh](https://chrismoreh.com). This repository holds the workshop website, the reveal.js slide deck, and a zero-install browser lab.

Workshop participants will complete a guided robustness reanalysis of one of the same articles reanalysed by the facilitator as part of a large replication exercise recently published in *Nature* (Aczel et al., 2026) in a special section bringing together two other papers from the same multi-year meta-project (*Systematizing Confidence in Open Research and Evidence* (SCORE) – Alipourfard et al., 2021). Participants will import data directly from an OSF repository and reproduce a constrained model, then choose one analytical deviation, make a reasoned argument for their choices supported by a Directed Acyclic Graph (DAG), preregister that choice (a git commit on the full-pipeline track, a written note before running on the browser track), and publish their own reanalysis as a webpage via GitHub Pages.

## Live link

The site deploys to GitHub Pages at <https://codemoreh.github.io/applied-replication/>.


## What happens

The session moves through three distinct concepts. First, the three "R"s – reproducibility, robustness, and replicability – grounded in three *Nature* (2026) papers measuring these outcomes across SCORE's sample of published social and behavioural science papers. Second, those three Rs are traced through a single case: Teney's (2016) article on the correlates of EU framing based on Eurobarometer data. Third, estimands and DAGs – distinguishing theoretical, empirical, and estimation targets, and reading confounders, mediators, and colliders from causal graphs.

## Two ways to take part

- **Track A – Browser lab (zero-install).** Participants open the [browser lab](exercise/browser-lab.qmd), which runs Tasks A–D in-browser via webR and quarto-live. Nothing is installed; data is pre-loaded; work persists in the browser tab until refresh. Participants submit results via the one-click `report_result()` link – which drops a dot on the live [Multiverse](results.qmd) chart – rather than committing.
- **Track B – Template repo.** Participants click "Use this template" on the companion repository [`CodeMoreh/replication-lab`](https://github.com/CodeMoreh/replication-lab), clone it in Positron (or their IDE of choice), edit `index.qmd` locally, and run R directly. On push, that repo's own GitHub Actions workflow installs R, renders the report, and publishes to GitHub Pages.

## Repository layout

| Path | What it is |
|------------------------|-----------------------------------------------|
| `index.qmd` | Home: welcome, overview, two-track selection, schedule |
| `setup.qmd` | Three-level pre-workshop preparation (account, software, optional readings) |
| `slides/index.qmd` | The reveal.js deck |
| `exercise/index.qmd` | Full task description: the claim, the five analysts, Tasks A–F |
| `exercise/browser-lab.qmd` | Runnable Track A version of Tasks A–D (webR / quarto-live) |
| `exercise/spec-menu.qmd` | Specification menu for the chosen deviation (six analytical axes) |
| `exercise/cheatsheet.qmd` | Wallet card: URLs, git workflow, Quarto commands, fallbacks |
| `results.qmd` | Multiverse: specification curve chart and five-analyst comparison |
| `resources.qmd` | Readings, estimand theory, case-study references, tool docs |
| `data/` | Committed workshop datasets and codebook (see below) |
| `.github/workflows/publish.yml` | CI: render and deploy to GitHub Pages |

## The data

The `data/` directory holds four CSVs and a codebook, served verbatim so the browser lab can fetch them.

| File | What it is |
|------------------------|-----------------------------------------------|
| `rep_data.csv` | As-published aggregates (270 country-years), with the original wave set |
| `teney_panel.csv` | Corrected panel, rebuilt independently from the raw GESIS microdata |
| `teney_panel_codebook.md` | Codebook for `teney_panel.csv` (sources, scales, variables, licence) |
| `spec_grid.csv` | 1,680 pre-computed specifications across the task menu |
| `analysts5.csv` | The five Multi100 analysts' results for the constrained claim |

**OSF nodes.** The workshop fetches from [osf.io/6zqct](https://osf.io/6zqct), the facilitator's personal extended fork of the official archival Multi100 component for analyst C6HJR [osf.io/8rtwe](https://osf.io/8rtwe). The full SCORE dossier on the reanalysed paper is [osf.io/h7432](https://osf.io/h7432).

**Microdata are not redistributed.** The raw Eurobarometer microdata are GESIS-licensed and are not committed or redistributed here. Obtain them from GESIS (<https://search.gesis.org/>) under their usage terms if you want to reproduce the entire data pipeline and/or build alternative models that rely on individual-level data. This repository contains only derived country-year aggregates.

## Sources, credits, and licensing

The macro indicators (growth, unemployment, bailout) come from World Bank Open Data (CC BY 4.0). The underlying Eurobarometer microdata remain subject to GESIS terms. The derived aggregate data and the rendered website content are released under [Creative Commons Attribution 4.0 International (CC BY 4.0)](LICENSE).