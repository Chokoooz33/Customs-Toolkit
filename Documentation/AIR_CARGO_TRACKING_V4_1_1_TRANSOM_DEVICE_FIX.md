# Air Cargo Tracking V4.1.1 — Transom Device Fix

Target AWB: `91018733654`

This pass is based on the real-device log where the exact Transom action was found and `action.click()` returned successfully, but no result DOM appeared.

Changes:
- Transom still never falls back to generic Search / Submit / Enter controls.
- Angular Material icon text (`search`) is stripped only when deriving the button label, so `searchTrack and Trace` is recognized as the single `Track and Trace` button rather than a separate Search action.
- AWB is now entered first through WebKit's browser editing path (`execCommand('insertText')`) one digit at a time. This lets Transom's own input mask / form binding produce and own the displayed AWB value instead of relying only on direct DOM value assignment.
- HAWB is explicitly cleared before lookup.
- If the exact Track and Trace click produces no XHR/fetch at all for six seconds, the same exact button is retried once with the visible spaced AWB value. No other action is eligible.
- A Transom-only XHR/fetch response reader was added. If the SPA request succeeds but the hidden WKWebView does not render the result panel, JSON response keys are humanized and fed through the existing verified parser. DOM extraction remains the primary path.
- Transom diagnostics now include normalized action label, form validity, network request/response counts, a short page sample, and a short network-response sample.
- The Cargo Board stable-ID refresh fix from the previous pass remains unchanged.

Verification performed in this environment:
- Swift parse: 69/69 source + test files passed.
- Generated Transom JavaScript: `node --check` passed.
- Full `swift test` cannot execute in this Linux environment because the project imports iOS-only SwiftUI/WebKit/UIKit modules; end-to-end WebKit verification must be run on the iPhone/Xcode target.
