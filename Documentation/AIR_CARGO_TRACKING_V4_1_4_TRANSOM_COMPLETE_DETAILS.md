# Air Cargo Tracking V4.1.4 — Transom Complete Details

Targeted follow-up to the verified split-AWB Transom submission fix.

## Changes
- Prefer the fully rendered Transom DOM over the first partial result marker or raw network payload.
- Wait for a stable result containing Transom result sections/events before returning from the hidden WKWebView.
- Parse the `Events Status` table deterministically and use its last operational row as Status / Last Event.
- Recover received piece count from `NNPCS` event rows when the AWB details table has not exposed the value yet.
- Fill missing shared shipment facts (expected pieces, weight, route, flight) from the already verified airline snapshot without replacing Transom operational events/state.
- Simplify the Transom result card around arrival, received pieces, weight, flight, route, status, and latest event.

No Qatar/other-airline adapter behavior was changed.
