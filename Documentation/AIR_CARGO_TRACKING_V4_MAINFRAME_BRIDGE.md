# Air Cargo Tracking V4 — Main-Frame Bridge

## Why V3.9 failed on device
The device logs repeatedly showed WebKit `runJavaScriptInFrameInScriptWorld` failures while V3.9 was polling with `evaluateJavaScript`. The resolver also attempted recursive iframe DOM inspection. V4 removes that entire approach.

## V4 tracking bridge
- One `WKUserScript` is injected at document end in the **main frame only**.
- No iframe `contentDocument` access.
- No repeated `evaluateJavaScript` calls.
- DOM/result updates are sent back to Swift through `WKScriptMessageHandler` (`trackingBridge`).
- The tracking WKWebView has a non-zero mobile viewport and is attached offscreen to the active iOS window while working, then removed.
- WebKit work is serialized to avoid two simultaneous hidden content processes fighting for resources.

## Transom-specific behavior
Source: `https://webtrack.omansats.om/shipment-tracking-details`

The page is a JavaScript application and publicly exposes an AWB + optional HAWB form. V4:
1. Finds AWB but explicitly rejects HAWB as the AWB target.
2. Uses the native HTMLInputElement value setter.
3. Dispatches `input`, `change`, and `blur` events for Angular/reactive-form compatibility.
4. Tries `910-18733654` then `91018733654` (and equivalent formats for any carrier prefix).
5. Clicks Track and Trace or uses `requestSubmit()` as fallback.
6. Watches DOM mutations for result text instead of polling from Swift.
7. Never invents arrival/short-land data if no verified result is returned.

## Airline coverage
The AWB-prefix directory includes Oman Air plus multiple carriers, including Emirates, Qatar Airways, Etihad, Turkish Cargo, Saudia, Lufthansa, Cargolux, Ethiopian, Gulf Air, Cathay, Singapore Airlines Cargo, Air France/KLM, British Airways/IAG, Air India, Kuwait Airways, Air Arabia, and SalamAir identification.

Oman Air uses a prepared SmartKargo direct URL for AWB 910. Other carriers use adaptive public-page form discovery where a public guest tracker is available. If a carrier requires login/CAPTCHA or blocks automation, the app falls back to the official source rather than fabricating data.

## Regression AWB
`910-18733654` remains the verified Oman Air regression case. Expected airline-side evidence from the user's official SmartKargo result:
- LHR → MCT
- WY104
- 14 PCS
- 111.50 KG
- Arrived at MCT

## Test limitations
The Linux build environment cannot run SwiftUI/WebKit/Xcode tests. All Swift files are syntax-parsed here. The true Transom end-to-end submission must be verified on an iPhone/iOS simulator because the public Transom site is JavaScript-driven and does not expose a documented public API in the project.
