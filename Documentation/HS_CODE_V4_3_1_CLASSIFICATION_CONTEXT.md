# V4.3.1 — HS Code Classification Context

## Scope
- Redesigned HS Code detail screen for professional customs workflow.
- Added Classification Path: Chapter → Heading → Subheading → final Oman HS tariff line.
- Added deterministic guidance that never invents a classification or product use.
- Added Google Images and web-search actions using the HS code plus available official English context.
- Preserved Permit Requirements, Duty Calculator handoff, Trade Agreement indicators, source/year/page reference.
- Added trade-agreement indicator warning: an indicator alone does not prove preferential eligibility.
- Added final action grid: Copy HS, Image Examples, Calculate Duty, Official Source.

## Official-source handling
The supplied Oman Customs Tariff 2026 PDF was treated as authoritative. Parent descriptions are displayed only where they were explicitly verified; otherwise the UI shows the numeric parent and states that the parent wording is not stored rather than guessing.

## Verified 85.37 context
For heading 85.37 and subheadings 8537.10 / 8537.20, the Classification Path wording was verified against the supplied 2026 tariff (pages 273–274).

## Dataset corrections
The existing JSON extraction truncated wrapped descriptions on several 85.37 rows. Ten 85.37 records were corrected against the supplied tariff PDF, including 853710000004–000007 and 853720000003–000008.

## Safety / legal UX
- Official descriptions remain visibly separate from guidance.
- “Other / غيرها” is explicitly explained as requiring parent-hierarchy context.
- Image search is labeled illustrative only; it does not determine classification.
- Permit verification remains routed to the official Oman Customs public HS portal.
