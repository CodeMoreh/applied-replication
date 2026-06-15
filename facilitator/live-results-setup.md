# Live class-results system – setup and run guide

This is the facilitator's guide to the live "Class results" chart on the **Multiverse** page (`results.qmd`). It explains the whole pipeline, every setup step, what to paste where, and how to run it on the day. Budget about **45 minutes** the first time; once the Form and Worker exist they are reusable.

You do all of this; participants do nothing except click one link.

------------------------------------------------------------------------

## 1. How it works (the 30-second mental model)

```         
 participant            you control                google
 ───────────            ───────────                ──────
 report_result()  ──►   one-click Form link
                        (numbers pre-filled)
        │ click + Send
        ▼
 Google Form  ─────────────────────────────────►  responses Google Sheet
                                                          │
 browser (webR on results.qmd)                            │ server-side fetch
        │  fetch(worker_url)                               ▼
        └──────────────►  Cloudflare Worker  ──────►  Sheet as CSV (gviz)
                          adds CORS header
        ◄──────────────  CSV + Access-Control-Allow-Origin: *
        ▼
 orange dot appears on the chart
```

Why the Worker exists: a browser will only read a remote file if that file is served with an `Access-Control-Allow-Origin` (CORS) header. Google Sheets does **not** reliably send that header to a third-party site like `codemoreh.github.io`, and the URL it does serve redirects across origins, which browsers block. The Worker is a tiny relay that you control: the browser talks to the Worker, the Worker fetches the Sheet server-to-server (no browser, no CORS on that hop), and hands the CSV back with the right header. This removes the single biggest live-demo risk. It is \~20 lines and runs free.

**Design note (prereg + format).** This system handles the **results** submission only. Preregistration is deliberately kept as a lightweight gesture (Track B: a `prereg:` git commit; Track A: write your spec + reason in the cell and tell your partner) so that each participant makes **one** submission, not two. The earlier friction was Track A having to post twice; one results-Form keeps that gain. If you would rather make prereg fully digital and timestamped too, see section 9.

------------------------------------------------------------------------

## 2. Step 1 – the Google Form

### 2.1 Create the form and its questions

1.  Go to <https://forms.google.com> → blank form. Title it e.g. "Class results – Applied replication".

2.  Add **seven Short-answer questions**, titled **exactly** as below (lowercase, no extra words – these become the Sheet column names the chart reads):

    | Question title | Type         | Notes                                         |
    |------------------|------------------|------------------------------------|
    | `spec`         | Short answer | the specification string                      |
    | `b`            | Short answer | coefficient                                   |
    | `se`           | Short answer | standard error                                |
    | `t`            | Short answer | t statistic                                   |
    | `df`           | Short answer | residual degrees of freedom                   |
    | `n`            | Short answer | observations                                  |
    | `r`            | Short answer | partial correlation (the one the chart plots) |

    Short titles look terse, but that is fine: participants never type into the form – `report_result()` pre-fills every box and they just press Send. The only hard requirement is that the question for the partial correlation is titled **`r`**, because the chart reads a column called `r`.

### 2.2 Make it anonymous (no Google login)

In the form's **Settings** tab:

- **Responses → Collect email addresses → Do not collect.**
- **Responses → Limit to 1 response → OFF.** ← this is the setting that otherwise forces a Google sign-in. With it off, anyone can submit with no account. (Trade-off: a person could submit twice. Harmless for a workshop.)

### 2.3 Link a responses Sheet and make it readable

1.  Form **Responses** tab → green Sheets icon → "Create new spreadsheet". This makes a Sheet whose first tab is **"Form Responses 1"** with columns `Timestamp, spec, b, se, t, df, n, r`.

2.  Open that Sheet → **Share** → General access → **"Anyone with the link" → Viewer.** The Worker fetches the Sheet unauthenticated, so the Sheet must be link-viewable or the fetch returns nothing.

3.  Copy the **Sheet ID** from its URL – the long string between `/d/` and `/edit`: `https://docs.google.com/spreadsheets/d/THIS_IS_THE_SHEET_ID/edit`

    **ACTUAL**: [https://docs.google.com/spreadsheets/d/**13nQqw3iR-GwrDmH1H7sQc1CbBmdioarfBWmLIQqmr-k**/edit?usp=sharing](https://docs.google.com/spreadsheets/d/13nQqw3iR-GwrDmH1H7sQc1CbBmdioarfBWmLIQqmr-k/edit?usp=sharing)

    **ACTUAL**: 13nQqw3iR-GwrDmH1H7sQc1CbBmdioarfBWmLIQqmr-k

### 2.4 Get the pre-fill field codes and the Form ID

`report_result()` builds a pre-filled link, which needs the internal `entry.NNN` code for each question plus the form's published ID.

1.  In the form editor, **⋮ (top-right) → Get pre-filled link**.

2.  Type a dummy value into each box (e.g. `1` in each), then **Get link** → **Copy link**. Paste it somewhere temporary. It looks like:

    ```         
    https://docs.google.com/forms/d/e/1FAIpQLSxxxxxxxx/viewform?usp=pp_url
      &entry.111111=1&entry.222222=1&entry.333333=1&entry.444444=1
      &entry.555555=1&entry.666666=1&entry.777777=1
    ```

    **ACTUAL**: [https://docs.google.com/forms/d/e/**1FAIpQLSezoAEOnZUfP4pkfN28_XtEBwSyc2RLsXB-h8RPSegF7_t76A**/viewform?usp=pp_url&entry.832496914=1&entry.1656311800=1&entry.1337458262=1&entry.1940779437=1&entry.1682711955=1&entry.1586392724=1&entry.1660273001=1](https://docs.google.com/forms/d/e/1FAIpQLSezoAEOnZUfP4pkfN28_XtEBwSyc2RLsXB-h8RPSegF7_t76A/viewform?usp=pp_url&entry.832496914=1&entry.1656311800=1&entry.1337458262=1&entry.1940779437=1&entry.1682711955=1&entry.1586392724=1&entry.1660273001=1)

3.  From that URL read off:

    - the **Form ID** = the `1FAIpQLSxxxxxxxx` part (between `/d/e/` and `/viewform`);

      **ACTUAL**: 1FAIpQLSezoAEOnZUfP4pkfN28_XtEBwSyc2RLsXB-h8RPSegF7_t76A

    - the **seven `entry.NNN` codes**, in the order your questions appear. Match each to its field by the order you added them (spec, b, se, t, df, n, r). If unsure, fill the dummy values `spec`,`b`,`se`,`t`,`df`,`n`,`r` instead of `1` so each code is followed by a recognisable value.

      **ACTUAL**:

      - entry.832496914
      - entry.1656311800
      - entry.1337458262
      - entry.1940779437
      - entry.1682711955
      - entry.1586392724
      - entry.1660273001

4.  Also grab the **public short link** for the cheatsheet: form editor → **Send → link icon → Shorten URL** → something like `https://forms.gle/abc123`.

    **ACTUAL**: <https://forms.gle/MWhimagFDmGtprAPA>

You now have: Sheet ID, Form ID, seven entry codes, and the public form link.

------------------------------------------------------------------------

## 3. Step 2 – the Cloudflare Worker

You need a free Cloudflare account (<https://dash.cloudflare.com/sign-up>). No domain or payment is required; Workers get a free `*.workers.dev` subdomain.

### 3.1 Easiest route – dashboard

1.  Cloudflare dashboard → **Workers & Pages → Create → Create Worker**.
2.  Name it e.g. `class-results`. Deploy the default, then **Edit code**.
3.  Delete the sample and paste the entire contents of [`facilitator/cloudflare-worker.js`](cloudflare-worker.js).
4.  Set `SHEET_ID` near the top to your Sheet ID from step 2.3. Leave `SHEET_NAME` as `"Form Responses 1"` unless you renamed the tab.
5.  **Deploy.** The Worker URL is shown, e.g. `https://class-results.YOUR-SUBDOMAIN.workers.dev`.

### 3.2 Alternative – command line (wrangler)

``` bash
npm install -g wrangler
wrangler login
# put cloudflare-worker.js in a folder with a minimal wrangler.toml:
#   name = "class-results"
#   main = "cloudflare-worker.js"
#   compatibility_date = "2025-01-01"
wrangler deploy
```

### 3.3 Test the Worker

- Open the Worker URL in a browser tab → you should see the Sheet as raw CSV (header row plus any test rows). If you see an error or HTML, the Sheet is not link-viewable (revisit 2.3) or `SHEET_ID` is wrong.

  [**ACTUAL: IT DOES DOWNLOAD A CSV FILE WITH THE EXPECTED HEADERS, BUT IT DOES NOT OPEN IT IN THE BROWSER ON MY MACHINE**]{.underline}

- Test it the way the page will, **from the deploy origin**. Open <https://codemoreh.github.io/applied-replication/results.html>, open the browser DevTools console (F12), and run:

  ``` js
  fetch("https://class-results.YOUR-SUBDOMAIN.workers.dev")
    .then(r => r.text()).then(console.log)
  ```

  CSV printed and **no CORS error** = the load-bearing piece works.

  [**ACTUAL: NOT YET TESTED**]{.underline}

------------------------------------------------------------------------

## 4. Step 3 – wire the IDs into the repo

Four edits. Two carry a literal `PASTE_…` marker in the code (items 1 and 2); item 3 (the template repo) has no marker because that file lives in a different repo and is structured differently – replace its "section 4" as shown below; item 4 is a value in `_variables.yml`.

1.  **`results.qmd`** – in the `live-multiverse` cell, set:

    ``` r
    worker_url <- "https://class-results.YOUR-SUBDOMAIN.workers.dev"
    ```

2.  **`exercise/browser-lab.qmd`** – in `report_result()`, set the Form ID and the seven entry codes:

    ``` r
    FORM_ID <- "1FAIpQLSxxxxxxxx"
    field <- c(spec = "entry.111111", b = "entry.222222", se = "entry.333333",
               t = "entry.444444", df = "entry.555555", n = "entry.666666",
               r = "entry.777777")
    ```

3.  **The template repo** (`CodeMoreh/replication-lab`, the separate repo participants copy) – make the **same** edit to its `R/report_result.R` so Track B participants get working links too. (That file is gitignored from this repo; edit it in its own checkout.)

    [**ACTUAL: I CAN'T LOCATE THAT !!!**]{.underline}

4.  **`_variables.yml`** – set the public form link so the cheatsheet and slides point at it:

    ``` yaml
    results-form-url: "https://forms.gle/abc123"
    ```

Then **render and push**:

``` bash
quarto render results.qmd
quarto render exercise/browser-lab.qmd
quarto render exercise/spec-menu.qmd exercise/index.qmd exercise/cheatsheet.qmd
# (or just `quarto render` for the whole site)
git add -A
git commit -m "Wire live class-results Form + Worker"
git push
```

`_freeze/` must be committed (CI deploys without R). A full `quarto render` before pushing is safest.

> Note: the `worker_url` is baked into the page at render time, so changing it means a re-render + push. That is fine – you set it once before the workshop.

------------------------------------------------------------------------

## 5. Column-name contract

The chart reads a column literally named **`r`** (case/space-tolerant). The other columns are carried for the record but only `r` positions the dot.

- Live path: the Worker serves the Sheet's header row as CSV headers, which come from your Form question titles – so titling the question `r` (step 2.1) is what makes this work.
- Archive path (section 7): the committed `data/class_results.csv` must also have a column named `r`.

------------------------------------------------------------------------

## 6. The morning of (16 June) – re-test, do not assume

Google's anonymous-form and sharing behaviour has changed before, so verify on the day, not just the night before.

- [ ] **Anonymous submit:** open the public form link in an **incognito window with no Google account** and submit one test row. Confirm it is accepted without a login prompt.
- [ ] **Sheet got it:** the test row appears in "Form Responses 1".
- [ ] **Worker serves it:** open the Worker URL → the test row is in the CSV.
- [ ] **Chart shows it:** open the live Multiverse page, press **Run Code** on the Class-results chart → a test dot appears. Do this in incognito too (CORS can differ by login state).
- [ ] **Clear test rows** from the Sheet so the room starts clean (delete the test data rows; keep the header row).
- [ ] Confirm room wifi allows outbound HTTPS to `docs.google.com` and `*.workers.dev` (already in the night-before checklist in `guide.qmd`).

If the morning test fails, you still have two fallbacks (section 8) and the deck's static "The class multiverse" slide always works.

------------------------------------------------------------------------

## 7. Running it live (the 12:15 debrief)

1.  Project the live Multiverse page.
2.  As results arrive, press **Run Code** on the Class-results chart to pull the latest dots. Press it again every minute or so – each press re-fetches (the URL is cache-busted, so you always get the freshest rows).
3.  Talk to the picture: where did the room land, who flipped the sign, which choice moved the estimate most. The five analysts are the dashed lines; the pre-computed menu is the grey cloud; the orange dots are the room.

If the live fetch ever stalls in the room, fall back to the static spec curve on the slide "The class multiverse" – it is the same chart minus the live dots.

------------------------------------------------------------------------

## 8. Fallbacks (if the Worker route misbehaves)

- **Publish-to-web CSV instead of the Worker.** File → Share → Publish to web → the responses sheet → CSV. Point `worker_url` at that `…/pub?output=csv` URL. Simpler (no Worker) but it has a multi-minute publish cache and its cross-origin CORS is less reliable – use only if the Worker is unavailable.
- **Facilitator local render.** Forget the browser entirely: download the Sheet as CSV to `data/class_results.csv` on your laptop, run `quarto render results.qmd` locally (your laptop has R, so there is no CORS), and project/refresh that. This is bulletproof and is the recommended safety net if conference wifi is hostile.

------------------------------------------------------------------------

## 9. After the session

- [ ] **Archive a permanent snapshot.** The live chart depends on the Sheet and Worker staying up. To preserve the result independently, export the responses Sheet (**File → Download → CSV**), keep the columns including `r`, and save it over `data/class_results.csv` in this repo. Commit and push. The chart automatically reads this snapshot whenever the Worker is unset or unreachable, so the page keeps showing the room's multiverse forever.
- [ ] Optionally **set `worker_url <- ""`** in `results.qmd` and re-render, so the page serves the committed snapshot rather than calling a Worker you may later delete.
- [ ] Optionally **close the Form** (Responses tab → "Accepting responses" off) to stop late submissions.
- [ ] You can then safely delete the Worker and/or unshare the Sheet; the page runs on the committed snapshot.

------------------------------------------------------------------------

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
|------------------------|------------------------|------------------------|
| Form asks participants to sign in | "Limit to 1 response" is on, or email collection is on | Settings → both off (2.2) |
| Worker URL shows HTML / error, not CSV | Sheet not link-viewable, or wrong `SHEET_ID` | Share → Anyone with link → Viewer; recheck ID (2.3, 3.2) |
| CORS error in the browser console | Talking to Google directly, not the Worker; or wrong Worker URL | Confirm `worker_url` is the `*.workers.dev` URL, re-render (4) |
| Dots do not appear, no error | No column named `r`, or empty `r` values | Title the question `r` (2.1); check the pre-fill maps `r` correctly (2.4) |
| Dots in the wrong place | `r` holding the wrong number | `r` must be the partial correlation `t/sqrt(t^2+df)`; `report_result()` computes it |
| Pre-filled link 404s or is blank | Wrong `FORM_ID` or `entry.NNN` codes | Re-derive from "Get pre-filled link" (2.4); update both copies of `report_result()` (4) |
| New rows slow to show | Using Publish-to-web CSV (cached) | Switch to the Worker (gviz, uncached) |
| Everything dead on the day | wifi / Google outage | Facilitator local render (section 8) |