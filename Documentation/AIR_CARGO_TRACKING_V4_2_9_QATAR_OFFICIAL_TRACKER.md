# V4.2.9 — Qatar Airways Cargo Official Tracker

## Why this change

On-device V4.2.8 diagnostics for AWB `157-54645710` showed that Qatar Airways Cargo's public Experience Cloud page visibly rendered the MAWB form, while the WKWebView main document exposed zero editable inputs/actions to the generic adaptive adapter. Transom therefore returned live data first, but the Qatar card remained source-only.

## Qatar-specific adapter

- Prefix `157` now uses a dedicated `qatarMAWB` adapter.
- Primary path opens Qatar's official public MAWB deep-link using:
  - `documentNumber=<8-digit AWB serial>`
  - `documentPrefix=157`
  - `documentType=MAWB`
- The normal official page remains `https://www.qrcargo.com/s/track-your-shipment`.
- If the deep-link does not auto-hydrate, the injected script searches normal DOM plus any open LWC ShadowRoots for:
  - Prefix control
  - AWB Number(s) control
  - Track Shipment(s) action
  - Cookie action (`Yes, got it.`)
- No guessed/private cargo API is called.

## Result parsing

The Qatar parser understands the public result/timeline format and extracts:

- Full route, e.g. `ORD → MCT`
- Pieces and weight
- Latest destination flight, e.g. `QR1124`
- Current operational event
- Destination arrival timestamp
- Last three real Qatar timeline events, newest first

For the supplied example, the expected recent events are:

1. `Notified consignee` — MCT — `Thu, 27 Aug 2026 00:28`
2. `Received in MCT` — MCT — `Thu, 27 Aug 2026 00:25`
3. `Arrived in MCT on QR 1124/26-Aug-2026` — MCT — `Wed, 26 Aug 2026 21:34`

Arabic event-title fallbacks were added for Qatar's `Notified consignee`, `Received in ...`, arrival and departure wording.

## Speed / safety

Qatar remains Transom-first in progressive tracking for this iteration. That preserves V4.2.8's fast first result even if Qatar's Salesforce page changes or is slow. Qatar then updates the airline card as the second source.

## Validation

- All 80 Swift files parse successfully with `swiftc -parse`.
- Injected JavaScript passes `node --check` after materializing the Swift interpolation placeholders.
- The Qatar parser was compiled and executed independently against the supplied official timeline sample; it produced `ORD → MCT`, `1`, `452.7 KG`, `QR1124`, `Notified consignee`, and the expected latest three events.
