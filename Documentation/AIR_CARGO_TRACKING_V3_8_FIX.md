# Air Cargo Tracking V3.8 Fix

## AWB entry
- Numeric keyboard only.
- User types 11 digits; the UI inserts the dash automatically after the 3-digit airline prefix.
- Input is capped at 11 digits and stored internally without separators.
- Result AWB is forced to a single line with scale-down protection.

Example: `91018733654` is displayed as `910-18733654`.

## Live source attempt
`AirCargoTrackingService.shared` now uses `OfficialWebTrackingResolver` for both agreed sources:
1. Issuing airline official tracking page.
2. Transom Cargo public WebTrack page.

For Oman Air (prefix 910), the resolver prepares the no-login SmartKargo tracking URL with AWB prefix + serial and also performs an on-device WebKit form submission if needed.

For Transom Cargo, the resolver loads the agreed public WebTrack shipment-tracking page and fills the AWB prefix + serial on-device, then reads only values present in the rendered official page.

The parser does not invent missing shipment data. If the official site changes, blocks automation, times out, or no structured result can be read, the app falls back to the official-source card and direct link.

## Parsing
Native cards can populate verified fields detected in the rendered page, including where available:
- flight number
- origin / destination
- departure / arrival
- pieces
- weight
- status / last event
- Transom manifested/received pieces
- short landed difference when both manifested and received piece counts are present

## Validation
- All Swift files parse successfully with `swiftc -frontend -parse` in this environment.
- The Xcode project was regenerated to include the new resolver file.
- Full iOS build/runtime verification still requires Xcode + iOS SDK and real access to the external tracking sites.
