# Oman Customs Tariff 2026 — Dataset Integration

Production resource: `CustomsToolkit/Resources/oman_tariff_2026.json`

Source: user-provided official Oman Customs Tariff 2026 PDF (315 pages).

Integrated extraction statistics:
- 14,369 records
- 14,317 unique normalized tariff codes
- 6 duplicated normalized codes, intentionally preserved because the source lists multiple descriptions under those codes
- 94 row-level prohibited records
- 7 records missing Arabic description
- 2 records missing English description
- 149 records missing a parsed duty rate

Important: category-level restricted-items appendices were not automatically mapped to individual HS records unless a restriction was explicit on the tariff row. This avoids inventing legal classifications.
