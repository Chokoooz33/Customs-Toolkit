# Customs Toolkit V4.2 — Air / Sea Services Foundation

## Scope delivered

This release introduces a department/service split without changing the existing air-tracking implementation.

- Launch selector: **Air Services** or **Sea Services**.
- Air dashboard remains the existing dashboard; only the new shared Duty Calculator is added as an additional tool.
- Sea gets its own focused dashboard with no gold-price card and no air tracking.
- Sea primary tool: HS Code Search.
- Sea shared tools: Duty Calculator and Unit Converter.
- Settings includes a Change Air / Sea Service action.
- Existing Air Cargo Tracking, Transom logic, Emirates logic, and Cargo Board tracking files are intentionally frozen/unchanged in this release.

## Shared Import Duty Calculator

The new Duty Calculator is separate from the existing Difference Calculator.

### Import only

The first release is intentionally limited to the **Import** regime.

### Term of Delivery

Supported terms:

- CIF: user enters the complete CIF value.
- FOB / EXW: user enters Cost and Freight.

User-confirmed operating insurance rule for FOB / EXW:

`Insurance = 1% × (Cost + Freight)`

`CIF = Cost + Freight + Insurance`

### HS Code modes

1. HS Code: search the bundled Oman Tariff 2026 dataset and use the selected tariff duty rate.
2. Description: search the same local dataset by English/Arabic commodity description and select a tariff item.
3. Quick 5%: no HS Code required; use 5% customs duty and 5% VAT as an explicitly marked estimate.

A duty-free HS line (`0%`) flows through the calculator as zero customs duty.

### Currency

- OMR works directly.
- USD / AED / EUR / GBP accept a user-entered customs exchange rate defined explicitly as **OMR per 1 unit of foreign currency**.

### Calculation flow

`Duty = CIF(OMR) × HS Duty Rate`

For the base workflow:

`VAT taxable value = CIF(OMR) + Customs Duty`

`VAT = VAT taxable value × 5%`

`Total taxes = Duty + VAT`

`Landed value shown = CIF + Duty + VAT`

The tool does not invent preferential tariffs, excise tax, exemptions, or other fees. Those still require final verification in Bayan / Oman Customs.

## HS Permit / Import Requirements

The HS detail screen now includes:

- Permit & Import Requirements card.
- Prohibited status when the bundled tariff explicitly marks the line prohibited.
- Official verification action for other permit/restriction requirements.
- Direct action to open the new Duty Calculator with the selected HS Code already loaded.

Official Oman Customs Public HS Search uses CAPTCHA, so this release does **not** falsely claim an automatic permit yes/no result that cannot be verified from the offline tariff dataset. The in-app official check opens the Oman Customs service and prepares the HS Code for the user.

## Official reference URLs

- Duty Calculator: `https://www.customs.gov.om/esw/jsf/secure/esw/common/DutyCalculator.xhtml`
- Public HS / import requirements search: `https://www.customs.gov.om/esw/jsf/secure/esw/common/PublicHSCodeSearch.xhtml`

The official Duty Calculator exposes Import/Export, HS Code, CIF foreign-currency value, Currency, Rate of Exchange/CIF OMR, Quantity, UOM, Country of Origin and Preferential Tariff. Customs Toolkit currently automates the agreed operational subset and leaves fields that depend on official preferential/exemption rules to final customs verification.

## Verification performed in this workspace

- Swift syntax parse over all app and test `.swift` files: passed.
- New localized key reference check: passed.
- English and Arabic localization duplicate-key check: passed.
- Xcode project regenerated to include new files.
- Pure Foundation Duty Calculator engine compiled and executed with CIF, FOB insurance, VAT and FX checks: passed.
- Air tracking freeze comparison against uploaded V4.1.10: tracking resolver/service/view/view-model/CargoBoardStore unchanged.

Full iOS UI compilation/runtime still requires Xcode on macOS.
