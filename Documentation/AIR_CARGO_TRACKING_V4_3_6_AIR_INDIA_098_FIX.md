# Air Cargo Tracking V4.3.6 — Air India 098 Tracking Fix

## Problem

Prefix 098 (Air India Cargo) was still configured against the legacy iCargo hash route and the generic adaptive submitter. On device this could fail to find/submit the current public tracking form, leaving the airline source unavailable even while Transom could resolve the AWB.

## Fix

- Air India 098 now starts from the current official public Cargo Tracking page: `https://cargo.airindia.com/in/en/track-shipment.html`.
- Added a dedicated `airIndiaCargo` automation mode.
- The adapter supports both shapes seen in carrier portals:
  - airline / prefix selector + 8-digit AWB serial;
  - separate airline-code text field + AWB serial.
- Carrier selector matching is limited to explicit `Air India`, `AI`, or `098` options.
- The official iCargo portal remains a second attempt using the current non-hash root: `https://aicargoportal.airindia.com/icargoneoportal/app/main/`.
- Track-Trace remains the final public fallback.
- The user-facing official-source link for 098 now opens the current Air India Cargo tracking page rather than the legacy hash route.

## Safety / scope

No changes to Oman Air, Emirates, Turkish, Qatar, Transom, HS Code, Duty Calculator, or the shipment-detail UI. The adapter only maps controls that are visibly part of the live carrier tracking form; it does not call undocumented private APIs.

## Verification boundary

Static source checks and Swift parsing can be completed off-device. A real 098 AWB is still required to mark Air India as live-device confirmed.
