# Air Cargo Tracking V4.3.0 — Remaining Airlines Pack

## Scope

V4.3.0 promotes the 15 remaining configured airline prefixes away from the old one-size-fits-all adaptive behavior. Each prefix now has an ordered carrier profile made of official public tracking attempts where practical, plus a public fallback when the airline portal is account/session dependent or changes its client-side form.

This release does **not** change Transom submission, Duty Calculator, HS Code, Sea Services, Emirates, Turkish, Qatar, or Oman Air business rules.

## Carrier strategies

| Prefix | Carrier | Primary attempt | Fallback |
|---|---|---|---|
| 607 | Etihad Cargo | Track-Trace public air-cargo router | — |
| 065 | Saudia Cargo | Current official Digital Services / Track Shipment | legacy official AWB deep link, then Track-Trace |
| 020 | Lufthansa Cargo | official eTracking, prefix + serial | Track-Trace |
| 172 | Cargolux | official Track and Trace | Track-Trace |
| 071 | Ethiopian Cargo | official Track Your Shipment | Track-Trace |
| 072 | Gulf Air Cargo | official Falcon Cargo, 8-digit serial | Track-Trace |
| 160 | Cathay Cargo | official Track and Trace, prefix + serial | Track-Trace |
| 618 | Singapore Airlines Cargo | official public site / shipment tracker | Track-Trace |
| 057 | Air France KLM Martinair Cargo | official AFKL Track your shipment entry point | Track-Trace |
| 074 | KLM Cargo | official myCargo single search | Track-Trace |
| 125 | British Airways / IAG Cargo | official IAG Cargo Track and Trace entry point | Track-Trace |
| 098 | Air India Cargo | official iCargo Neo portal | Track-Trace |
| 229 | Kuwait Airways Cargo | official cargo tracking, prefix + serial | Track-Trace |
| 514 | Air Arabia Cargo | official Cargo Tracking, carrier selector + tracking ID | Track-Trace |
| 960 | SalamAir | Track-Trace public air-cargo router | TheDeliveryTracker fallback |

## WebKit hardening

- Airline pages use one `WKUserScript` injected locally into each frame. This is not the old V3.9 repeated `evaluateJavaScriptInFrame` polling approach.
- Each injected frame can discover normal DOM plus open Shadow DOM controls and report through the same `WKScriptMessageHandler`.
- AWB controls are selected using field metadata plus nearby labels/container text instead of a single selector.
- Submission supports full 11-digit AWB, formatted AWB, 8-digit serial, prefix + serial, form `requestSubmit`, and Enter fallback.
- Air Arabia gets a carrier-selector-aware path.
- Track-Trace gets a dedicated full-11-digit + `Track Direct` path.
- A no-result message is accepted only after that frame submitted the requested AWB or the request is present in the frame URL/text; unrelated shell frames cannot end the worker.
- Local frame timeouts do not cancel sibling tracker frames. The Swift watchdog owns final failure.

## Speed behavior

The four previously verified airline adapters keep their proven timing windows:

- 910 Oman Air
- 176 Emirates SkyCargo
- 235 Turkish Cargo
- 157 Qatar Airways Cargo

The new/unverified carrier attempts use a ~14 second per-attempt ceiling with a 16 second Swift watchdog. For these prefixes, the progressive service continues to show Transom first, so the user is not blocked waiting for an airline portal that changed or failed.

## Parsing / last three events

The generic parser now has fallbacks for:

- `AAA - BBB` route pairs
- `N PCS` / `N Pieces`
- `NNN.N KG`
- common two-character flight numbers such as `LH820`
- operational phrases including Accepted, Manifested, Departed, Arrived, Received, Released, Ready for Delivery / Collection, Notified Consignee, and Delivered

Only events visible in the returned source text are promoted. No milestone is fabricated. The UI still limits display to the latest three extracted events.

## Verification boundary

Live-device confirmed before this release: Oman Air, Emirates SkyCargo, Turkish Cargo, Qatar Airways Cargo, plus Transom.

V4.3.0 configures and hardens all remaining 15 airline paths, and source/syntax tests can be run without live AWBs. A carrier should only be marked **live-device confirmed** after a real AWB returns correctly on the iPhone. Website changes, bot protection, account gates, or regional redirects can still require a carrier-specific follow-up.
