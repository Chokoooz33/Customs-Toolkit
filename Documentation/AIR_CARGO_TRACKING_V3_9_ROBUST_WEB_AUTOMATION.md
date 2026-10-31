# Air Cargo Tracking V3.9 — Robust Live Web Automation

This pass replaces the fixed-delay web scraper with a resilient WKWebView automation flow for the two agreed public sources:

- Airline public tracking (Oman Air / SmartKargo for prefix 910)
- Transom Cargo Webtrack+

## Key changes

1. Waits for JavaScript/framework hydration before searching for the tracking form.
2. Searches same-origin iframes as well as the top-level document.
3. Transom AWB selection explicitly excludes HAWB fields.
4. Uses the native input value setter plus `InputEvent`, `change`, keyboard and blur events so Angular/React form bindings are updated.
5. Transom tries `910-18733654` first, then `91018733654` automatically.
6. Airline prefers split prefix/serial inputs when available.
7. Clicks the visible Track/Track and Trace action and falls back to `form.requestSubmit()`.
8. Polls the rendered DOM after submission because both sites may update using AJAX without a navigation callback.
9. Collects visible text from same-origin frames and tables.
10. Adds a SmartKargo-specific parser matching the verified Oman Air result layout.
11. Keeps source-only fallback and never invents tracking data.

## Regression reference

Test fixture for AWB `910-18733654` is based on the user's verified SmartKargo screen and expects:

- Route: LHR → MCT
- Flight: WY104
- Pieces: 14
- Weight: 111.50 KG
- Departure: 16/08/2026 08:25
- Arrival: 16/08/2026 18:45
- Status: Arrived at MCT

The fixture is test-only and is never shipped as tracking production data.
