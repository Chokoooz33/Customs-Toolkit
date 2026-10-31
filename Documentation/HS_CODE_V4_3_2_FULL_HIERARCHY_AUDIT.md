# V4.3.2 — HS Code Full Hierarchy Audit

## What changed
- Rebuilt Classification Path context against the supplied official Oman Customs Tariff 2026 PDF across the full production dataset.
- Every production tariff row now carries official Chapter and Heading descriptions.
- Subheading wording is shown only when an official parent label could be resolved safely from the tariff. If the tariff has no distinct 6-digit parent wording, the UI skips that node instead of inventing one.
- Example: 73 11 00 20 00 00 now displays Chapter 73 → Heading 73.11 → HS. The fake/empty “7311.00” explanation is no longer shown.
- Example: 85 37 10 xx xx xx still displays Chapter 85 → Heading 85.37 → Subheading 8537.10 → HS because the official tariff explicitly contains “For a voltage not exceeding 1,000 V”.

## Dataset audit
- Previous rows: 14,369
- Audited rows: 14,365
- Four false-positive rows extracted from explanatory notes were removed:
  - 085900380852
  - 151419151411
  - 480525480524
  - 710811710610
- Audited unique normalized codes: 14,313
- Duplicate-code behavior from the official source remains preserved.
- All 14,365 remaining rows have an official Chapter description and official Heading description.
- 12,202 rows have a safely resolved official subheading description; rows without one intentionally omit the subheading node.

## Legal/data rule
No Chapter, Heading or Subheading description is generated from AI/general knowledge at runtime. The UI consumes source-derived fields bundled in the tariff dataset. Missing/ambiguous hierarchy levels are omitted rather than guessed.

## Source
Official Oman Customs Tariff 2026 supplied with the project audit (315 pages).
