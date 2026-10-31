# Air Cargo Tracking V4.3.4 — Full Shipment Tracking Details

## Scope

This release upgrades the tracking result from separate source cards into a shipment workspace while preserving the existing live airline adapters, Transom adapter, progressive refresh behavior, HS Code V4.3.3 work, and Duty Calculator.

## User experience

- The search result now shows one compact shipment summary, source health for the airline and Transom, and a three-event preview.
- **View Shipment Details** opens a dedicated page with three tabs: **Updates**, **Flight Details**, and **Shipment Details**.
- The Updates tab displays every verified event captured from the source rather than truncating storage to three events. The Arabic label is a fixed readability mapping; the exact source event wording remains visible beneath it in Arabic mode.
- Updates can be filtered by **All / Airline / Transom**. Airline and Transom events are merged by their source timestamps when a timestamp can be parsed.
- Flight Details derives flight legs only from captured source events/flight numbers. Missing source data stays missing; the app does not synthesize flight milestones.
- Shipment Details separates airline facts from Transom operational confirmation, including received pieces, short-landed pieces, flight/date, import-export status, agent, and current source status where available.
- Official source links remain available for both sources.

## Event storage and parsing

`recentEvents` remains the persisted property name for backward compatibility, but from V4.3.4 it stores **all verified captured events, newest first**. Existing Cargo Board records continue to decode because the model only adds optional fields.

- Generic airline event normalization no longer stops after three events.
- Qatar timeline parsing no longer stops after three cards and preserves QR flight numbers found in event titles.
- Turkish Cargo keeps all parsed event cards, newest first, and preserves the event flight number when present.
- Transom keeps the complete parsed Events Status history, newest first, and preserves flight numbers present in status text.

## Refresh

Cargo Board now has a targeted single-shipment refresh path, so refreshing an open shipment does not refresh every saved AWB. Progressive airline/Transom updates are still merged into the saved snapshot.

## Accuracy rule

The source event title is the auditable truth. Arabic wording is only a fixed user-facing explanation and must never promote a source event to a stronger operational state (for example, `Notified consignee` is not displayed as `Delivered`).
