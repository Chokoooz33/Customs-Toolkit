# Difference Calculator — Confirmed Business Rules

Updated from the provided company workbook `احتساب الفارق.xlsx` and the user-confirmed VAT-only rule.

- Duty + VAT fixed adjustment: **97.566 OMR**
  - Workbook evidence: Sheet2 uses `=E5-97.566`; Sheet3 also uses `=I9-97.566`.
- VAT Only fixed adjustment: **200.000 OMR**
  - Confirmed directly by the user.
- VAT/base rate remains **5%**.
- Currency exchange-rate convention remains **PENDING_VERIFICATION** and was not changed.

These values are centralized in `AppConfig.Calculator` and consumed by `DifferenceCalculatorService.Configuration`.
