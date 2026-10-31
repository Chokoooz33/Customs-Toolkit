# Air Cargo Tracking V4.1.9 — Emirates Official Tracker Fix

Scope: Emirates SkyCargo (AWB prefix 176) only. Oman Air, Transom Cargo, and the remaining airline adapters are unchanged.

## Root cause

The previous Emirates source URL (`https://www.skycargo.com/shipping/track-shipments/`) now resolves to the public SkyCargo 404/help page. There is therefore no AWB input/form for the adaptive adapter to operate.

The current guest eSkyCargo workflow supplied and verified from the device is:

`https://eskycargo.emirates.com/app/offerandorder/#/home/find-offer`

It renders a `Doc. No.` control and a `Search` action, then a `Search Results` shipment card.

## Fix

- AirlineDirectory prefix 176 now opens the eSkyCargo Offer & Order SPA.
- Prefix 176 has a dedicated `emiratesDocNumber` automation mode.
- The adapter finds the `Doc. No.` field, inserts the complete 11-digit AWB, emits Enter to commit the token/chip, and presses the nearby exact `Search` action.
- Result detection requires the actual `Search Results` card, avoiding false positives from the Find Offers form itself.
- Emirates result parsing reads the overall route, Pieces, Gross Weight, and the shipment status displayed above the Doc. No. card.
- Cross-frame injection added in V4.1.8 is removed for Emirates because the verified eSkyCargo form is in the main SPA document.

## Device fixture used for parser verification

- AWB: 176-27188184
- Status: Delivered to the Consignee
- Route: ATH → MCT
- Pieces: 3
- Gross Weight: 84 KG

Swift syntax parse, injected JavaScript `node --check`, and the pure Swift Emirates result parser fixture all passed in the build environment. Full iOS WebKit execution still requires the device/Xcode runtime.
