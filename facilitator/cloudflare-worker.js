// =============================================================================
// Cloudflare Worker: class-results CORS proxy
// =============================================================================
//
// WHAT IT DOES
//   The live "Class results" chart on results.qmd runs in the browser (webR).
//   A browser can only fetch a remote file if that file is served with the right
//   CORS header (Access-Control-Allow-Origin). Google Sheets does NOT reliably
//   send that header to a third-party site like codemoreh.github.io, so reading
//   the sheet straight from the browser is fragile.
//
//   This Worker sits in between. The browser fetches THE WORKER (which we fully
//   control), the Worker fetches the Google Sheet server-to-server (no browser,
//   so no CORS involved on that hop), and the Worker hands the CSV back to the
//   browser with `Access-Control-Allow-Origin: *`. Bulletproof, and immune to
//   Google changing its CORS posture.
//
//   Flow:   browser (webR)  ->  THIS WORKER  ->  Google Sheet (gviz CSV)
//                            <-  CSV + CORS  <-
//
// SETUP  (full walkthrough in facilitator/live-results-setup.md)
//   1. Create the Google Form + linked responses Sheet; set the Sheet to
//      "Anyone with the link -> Viewer".
//   2. Copy the Sheet ID from its URL:
//        https://docs.google.com/spreadsheets/d/THIS_LONG_ID/edit
//      and paste it into SHEET_ID below.
//   3. Deploy this file as a Worker (dashboard or `wrangler deploy`), then put
//      the Worker's URL (e.g. https://class-results.you.workers.dev) into:
//        - results.qmd          -> the `worker_url` line in the live cell
//        - facilitator/live-results-setup.md notes (for your own record)
//
// TEST
//   Open the Worker URL in a browser: you should see the sheet as raw CSV.
//   Then open it from the deployed site's origin (DevTools console on
//   https://codemoreh.github.io/applied-replication/):
//     fetch("https://class-results.you.workers.dev").then(r=>r.text()).then(console.log)
//   No CORS error + CSV text printed = working.
// =============================================================================

const SHEET_ID = "PASTE_YOUR_SHEET_ID_HERE";

// The tab (worksheet) name that holds the form responses. Google's default for
// a form-linked sheet is "Form Responses 1". Change only if you renamed the tab.
const SHEET_NAME = "Form Responses 1";

export default {
  async fetch(request) {
    // Preflight (some browsers send an OPTIONS request first).
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }

    // gviz reads the LIVE sheet (not a cached "publish to web" snapshot), so new
    // submissions appear within seconds.
    const src =
      `https://docs.google.com/spreadsheets/d/${SHEET_ID}/gviz/tq` +
      `?tqx=out:csv&headers=1&sheet=${encodeURIComponent(SHEET_NAME)}`;

    try {
      const upstream = await fetch(src, { cf: { cacheTtl: 0 } });
      const body = await upstream.text();
      return new Response(body, {
        status: upstream.status,
        headers: {
          ...corsHeaders(),
          "Content-Type": "text/csv; charset=utf-8",
          // Never cache, so each "Run Code" press pulls the newest rows.
          "Cache-Control": "no-store",
        },
      });
    } catch (err) {
      // Return an empty CSV (header only) on failure so the webR cell degrades
      // to "no submissions yet" rather than erroring.
      return new Response("spec,b,se,t,df,n,r\n", {
        status: 200,
        headers: { ...corsHeaders(), "Content-Type": "text/csv; charset=utf-8" },
      });
    }
  },
};

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "*",
  };
}
