# Air Cargo Tracking V4.3.5 — Header Accuracy Fix

Scope: targeted UI corrections on top of V4.3.4. Tracking parsers, HS Code, Duty Calculator, and tariff data are unchanged.

## Fixes

1. **Route direction in Arabic UI**
   - Airport-code route rows are forced to left-to-right layout because route codes are technical data.
   - A route such as `LHR → MCT` no longer appears visually reversed as `MCT → LHR` in Arabic.

2. **AWB stays on one line**
   - The AWB header now uses a single line with tightening/minimum scale instead of wrapping the serial number onto a second line.

3. **Compact tracking-source labels**
   - Header source labels use compact carrier names (for example `Oman Air`, `Qatar Airways`, `Transom`) to avoid truncation such as `Oman Air C...`.
   - Full source names remain available in event/source/detail areas.

4. **Current-status provenance**
   - The header now shows which tracking source supplied the latest merged event, e.g. `آخر تحديث — Transom`.
   - The event wording and flight numbers remain source-derived; the app does not fabricate or reconcile differing source flight-number formats.

## Validation

- All Swift sources parse with Swift 6.2.1 on the available environment.
- No tracking web adapter / JavaScript changes in this release.
- No HS Code, tariff dataset, or Duty Calculator changes in this release.
