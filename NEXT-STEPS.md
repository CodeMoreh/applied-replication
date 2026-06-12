## 1. Final local render + commit (today)

```         
quarto render          # refresh _freeze one last time (CI deploys without R) git init -b main git add -A git commit -m "Workshop site: initial build" 
```

Note `_planning/`, `_planning_data/` and `_template/` are gitignored by design – they stay on this machine only (worth a private backup of `_planning/`).

## 2. Create and push the two repos (today)

**Site:** on github.com → New repository → owner **CodeMoreh**, name **applied-replication**, **Public**, completely empty (no README/licence). Then:

```         
git remote add origin https://github.com/CodeMoreh/applied-replication.git git push -u origin main 
```

(First push opens a browser sign-in via Git Credential Manager.)

**Template:** same flow for **CodeMoreh/replication-lab** (Public, empty), then:

```         
cd _template git init -b main git add -A git commit -m "Replication lab template: initial build" git remote add origin https://github.com/CodeMoreh/replication-lab.git git push -u origin main 
```

## 3. Repo switches on GitHub (5 minutes)

- **applied-replication** → Settings → Pages → Source: **GitHub Actions**. The push has already queued the workflow; once Pages is set, the site goes live at `codemoreh.github.io/applied-replication` in a minute or two.

- **applied-replication** → Settings → General → Features → tick **Discussions**; create two threads from the prepared texts in `_planning/comms/` ("Results board & gallery" from `discussion-results-board.md` – delete the coordinator note when pasting – and "Help / I'm stuck" from `discussion-help.md`); **pin both**.

- **replication-lab** → Settings → General → tick **Template repository**; Settings → Pages → Source: **GitHub Actions** (optional but nice – publishes a reference copy of the rendered report).

## 4. Live tests you can only do online (tomorrow, 13 June)

- Open the live **browser lab** and watch the three things I couldn't test headlessly: the eight webR packages install on first load, the ggdag figure renders in wasm (it degrades gracefully if not), and the data loader wins the cold-start race (symptom if not: `object 'rep' not found`, cured by re-running the cell).

- Run `R/get_data.R`'s osfr path once from your normal R session (untestable from my sandbox).

- Full participant dry run from a throwaway GitHub account: Use this template → own public repo → Settings → Pages → GitHub Actions → clone in Positron → `quarto preview` → edit, commit, push → Action publishes → paste a RESULT line in the thread.

## 5. Comms and polling

- Send **email-T3** (in `_planning/comms/`) via the organisers tomorrow; **email-T1** on Sunday the 15th.

- Create the feedback poll (Vevox or your chosen tool) and replace the `[VEVOX-LINK]` placeholders – one in the deck's final slide, one in `facilitator/guide.qmd`.

## 6. Night before (15 June)

Work through the "night before" checklist at the top of [facilitator/guide.qmd](vscode-webview://1s9dni7efh5i7msa8b4bqc44l6j27qon1l01dakqvn67bkmsb2bd/facilitator/guide.qmd) – it covers printing cheatsheets, opening the right tabs, the projector QR codes, and charging everything. The guide itself will be live (unlisted) at `…/facilitator/guide.html`, readable from your phone in the room.

One standing rule once you're live: any edit to a page with executable R chunks needs a local `quarto render` before pushing on the **site** repo (its CI has no R – it deploys the committed freeze); the **template** repo's CI does install R, so it rebuilds participant edits on its own.