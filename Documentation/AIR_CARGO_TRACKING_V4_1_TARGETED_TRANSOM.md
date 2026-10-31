# Air Cargo Tracking V4.1 — Targeted Transom Cargo Pass

## Target production fixture

AWB: `910-18733654`

Observed manually on Transom Cargo Webtrack:
- Total Pieces: 14
- Origin: LHR
- Destination: MCT
- Received Pieces: 14
- Agent: (BSA) BADAR SHIPPING AGENCIES LLC
- Flight No: WY0104
- Flight Date: 16 AUGUST 2026
- Flight Arrival: 16 AUGUST 2026 18:50, 14 PCS
- Shipment ready for delivery: 16 AUGUST 2026 20:26, 14 PCS
- Document Released: 25 AUGUST 2026 14:02

## Automation changes

- Transom submission is now delayed until Angular/Material validation has updated.
- First strategy types the 11 digits character-by-character and emits keyboard/input/change events.
- Fallback formats: `910 - 18733654`, then `910-18733654`.
- Track button disabled/aria-disabled state is checked and logged before click.
- Real result markers are targeted: `AWB Details`, `Freight Information`, `Events Status`, `Received Pieces`, operational events.
- Result DOM table rows are appended to the captured text using `__CT_TABLE_ROWS__` to preserve label/value relationships.
- No iframe DOM traversal is used.

## Parser/UI changes

Transom snapshot now supports:
- Origin / destination
- Flight number / flight date
- Import / Export
- Agent
- Received / expected pieces and short-land derivation
- Operational status and latest event

The tracking card and Cargo Board detail screen expose these fields when present.

## Local verification

1. Swift syntax parse: 69/69 files passed.
2. Production Transom fixture parser: PASS.
3. Partial-arrival / short-land fixture: PASS.
4. Empty Transom entry form rejected as live data: PASS.
5. Automation source checks: real result markers, formatted fallback, delayed validation, table-row capture, and no iframe traversal are present.

Final end-to-end Transom verification still requires the iPhone because the live Webtrack site times out from the build environment.
