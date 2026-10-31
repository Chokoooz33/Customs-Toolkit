# V4.2.6 — Turkish Cargo Event Status Priority

- Turkish Cargo's event-card timeline now overrides the broad shipment summary when it is more specific.
- Priority: confirmed delivered event > NFD (Shipment Notified For Delivery) > RCF (Shipment Received From Flight) > general summary.
- NFD maps to `Ready for Delivery` and preserves the original NFD event in `lastEvent`.
- Destination RCF maps to `Arrived - <destination>` when NFD is not present.
- A grey/incomplete DLV milestone token is not treated as delivery; delivery requires an actual delivered event description.
- No changes to Oman Air, Transom, Emirates, Qatar, Duty Calculator, or Cargo Board behavior.
