# V4.2.5 — Turkish Cargo Official Tracker

- Updated Turkish Cargo prefix 235 to the official public page: `https://www.turkishcargo.com/en/cargo-tracking`.
- Added a dedicated tokenized-AWB adapter instead of the generic adaptive form finder.
- Flow: prefix 235 -> 8-digit AWB serial -> Enter / exact Add token -> Search -> wait for the complete operational tracking card.
- Parses pieces, gross weight, route, current status/time and the last visible TK flight.
- Dismisses the Turkish Cargo cookie banner when present.
- No changes to Oman Air, Emirates, Transom, Cargo Board, Duty Calculator, HS Code or Sea Services.
