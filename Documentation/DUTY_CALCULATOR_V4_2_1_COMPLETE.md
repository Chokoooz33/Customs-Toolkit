# Customs Toolkit V4.2.1 — Duty Calculator Complete

## Scope
This update changes the shared Duty Calculator only. Air cargo tracking, Transom, Emirates tracking, Cargo Board, HS permit verification, Sea dashboard structure and the visual identity are intentionally left unchanged.

## Confirmed calculator workflow
- Import only.
- Supported delivery terms in the primary UI: CIF, CFR, FOB, EXW.
- CIF: enter CIF directly; no additional insurance is added.
- CFR: enter CFR directly; insurance = 1% of CFR; CIF = CFR + insurance.
- FOB / EXW: enter Cost and Freight; Cost and Freight may use different currencies and separate customs exchange rates; insurance = 1% of converted Cost + Freight; CIF = Cost + Freight + insurance.
- Duty source remains HS Code, description-based HS selection, or explicit Quick Estimate (5%).
- Duty = CIF × duty rate.
- VAT base = CIF + duty.
- VAT = VAT base × 5%.
- Total Duty + VAT = Duty + VAT.

## Documentation charges
- Importer Type:
  - Company: Bayan Documentation = 15 OMR.
  - Personal: Bayan Documentation = 5 OMR.
- Documentation Guarantee:
  - Applies only when Documents = Not Original AND CIF > 1,000 OMR.
  - Guarantee = 2% of CIF.
  - Kept separate from Duty and VAT bases.
- Final Total = Duty + VAT + applicable Documentation Guarantee + Bayan Documentation.
- The old `CIF + duty + VAT` result row is removed.

## Result actions
- Copy: copies a compact calculation summary suitable for WhatsApp/messages.
- Share: opens the iOS share sheet with the text result.
- PDF: creates an A4 branded Customs Toolkit PDF and opens the iOS share sheet.
- Print: sends the generated PDF to AirPrint.
- PDF includes term, importer type, document status, HS code + description when available, CIF, duty, VAT, documentation charges and final total.

## Validation performed
- Parsed every Swift source/test file with `swiftc -parse`.
- Added calculator tests for:
  - CIF standard calculation.
  - User-confirmed 2,000 OMR example resulting in 260 OMR for Company + Not Original.
  - Personal Bayan fee (5 OMR).
  - Guarantee threshold strictness (> 1,000 OMR only).
  - Different currencies for Cost and Freight.
  - CFR 1% insurance behavior.
  - Zero-duty HS behavior.
  - Foreign CIF currency conversion.
- Compared core Air tracking and Cargo Board files byte-for-byte against V4.2.0; they are unchanged.

## User-confirmed reference example
CIF = 2,000 OMR, Duty = 5%, Company, Documents = Not Original:
- Duty = 100 OMR
- VAT = 105 OMR
- Total Duty + VAT = 205 OMR
- Documentation Guarantee = 40 OMR
- Bayan Documentation = 15 OMR
- Final Total = 260 OMR
