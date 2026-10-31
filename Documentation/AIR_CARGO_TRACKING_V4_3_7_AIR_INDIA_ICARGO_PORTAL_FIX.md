# V4.3.7 — Air India 098 iCargo Portal Fix

- Official 098 source is now the exact Air India iCargo Neo guest portal route: `https://aicargoportal.airindia.com/icargoneoportal/app/main/#/app`.
- Waits for the hydrated `#shipmentValue` AWB field instead of treating the initial Loading shell as failure.
- Enters the full 11-digit AWB (`098` + 8-digit serial), matching the live portal.
- Clicks the exact **Next** button after it becomes enabled; it never selects the **Track Shipments** tab as the submit action.
- Adds Air India-specific result evidence for **AWB Activity Timeline**.
- Parses the official activity milestones (Delivered, Consignee Notified, Broken Down, Arrived, Departed, Manifested, Accepted), preserving official English event names and showing stable Arabic labels in the UI.
- Track-Trace remains fallback only.
- No changes to HS Code, Duty Calculator, Transom, or other airline adapters.
