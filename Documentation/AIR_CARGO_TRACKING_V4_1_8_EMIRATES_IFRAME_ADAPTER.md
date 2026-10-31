# Air Cargo Tracking V4.1.8 — Emirates Iframe Adapter

Scope is intentionally limited to Emirates SkyCargo (AWB prefix 176).

Device diagnostics from V4.1.7 showed the SkyCargo main document loaded successfully but exposed zero editable inputs for the full polling window. The generic adapter was injected only into the main frame, so any tracking form rendered in a child frame was invisible to the automation.

V4.1.8 changes WKUserScript injection to all frames only for airline prefix 176. The same adaptive form logic can therefore run inside the frame that owns the tracking controls, including cross-origin child frames, without main-frame DOM traversal. Oman Air, Transom, and all other airline profiles remain unchanged.

Diagnostics now include `isMainFrame`, `frameName`, and frame-local `href` so the exact Emirates frame can be promoted to a deterministic adapter after device verification.
