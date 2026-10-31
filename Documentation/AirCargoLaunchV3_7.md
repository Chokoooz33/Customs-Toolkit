# Customs Toolkit V3.7 — Air Cargo Launch

## Approved feature scope

### 1. Air Cargo Tracking
- User enters a single 11-digit AWB.
- The app identifies the issuing airline from the three-digit AWB prefix when known.
- Two source cards are always kept conceptually separate:
  1. Airline tracking: flight / route / departure / arrival / pieces / weight / latest airline event when the provider exposes them.
  2. Transom Cargo: airport arrival confirmation / received pieces / short-land information / latest handler event.
- Transom Cargo source supplied for the project:
  `https://webtrack.omansats.om/shipment-tracking-details`
- The app never invents arrival, pieces, weight, flight, or short-land data.
- Airline and Transom live adapters are protocol-based so each provider can be connected and changed independently.
- Until a provider connector is verified, the official source is shown rather than guessed data.

### 2. HS Code Camera Scanner
- Not a separate dashboard tool.
- Camera icon is inside the existing HS Code Search field.
- Camera scans printed document text only — no barcode / QR workflow.
- Uses on-device live text scanning (VisionKit) on supported iPhones.
- Candidate codes are normalized using the existing HS normalizer.
- Multiple detected candidates are shown for user confirmation; the app never silently selects a legal classification.
- The confirmed code is sent directly into the existing Oman Tariff 2026 search.

### 3. Air Cargo Board
- Separate focused tool opened from the dashboard.
- Contains shipments that were previously tracked and added to the board.
- Persists locally between app launches.
- Refresh runs when the home/board loads and can also be triggered with pull-to-refresh or the refresh button.
- Existing last successful live data is preserved if a later provider refresh fails.
- Filters: all / arrived / partial / in transit / not arrived.
- Shipment detail keeps Airline and Transom Cargo sections separate.

## Integration status in V3.7
- UI, navigation, localization, persistence, AWB normalization, airline-prefix routing, HS camera scanning, Cargo Board and provider adapter architecture are implemented.
- Verified live Airline and Transom data extraction is intentionally not faked. Provider-specific live adapters still require a stable supported endpoint / web integration and any required authentication or anti-bot handling.
