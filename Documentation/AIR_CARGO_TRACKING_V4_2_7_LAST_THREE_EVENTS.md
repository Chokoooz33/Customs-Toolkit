# Air Cargo Tracking V4.2.7 — Last Three Events

## Scope
Adds a compact recent-event timeline to both the airline card and Transom Cargo card without changing AWB submission behavior, Duty Calculator logic, HS tools, or carrier URLs.

## Behavior
- Each live source may expose up to 3 verified source events, newest first.
- If a source only exposes 1 or 2 events, only those events are shown. No missing milestones are fabricated.
- The current shipment status remains visible separately above the recent-event timeline.
- Saved Cargo Board records remain backward-compatible because `recentEvents` is optional in persisted snapshots.
- Cargo Board refresh preserves previously captured recent events when a successful live refresh has no event timeline.

## Source parsing
- Turkish Cargo: reads chronological station event cards (e.g. NFD, RCF, DEP) and keeps the newest three.
- Oman Air / SmartKargo: reads Arrived / Departed / Accepted / Booked milestones from the official status history.
- Emirates and other live airline adapters: uses generic verified event text present in the official rendered result; no synthetic milestones.
- Transom Cargo: reads the official Events Status table and keeps the newest three rows.

## UI
The source card shows a dedicated “Recent Updates / آخر 3 تحديثات” block. Known event codes are translated to concise Arabic labels while retaining source code, station and source timestamp.

## Validation
- All 80 Swift files pass `swiftc -parse` in the build container.
- Parser-only Foundation typecheck passes.
- Runtime parser fixtures verified Turkish NFD→RCF→DEP, Oman ARR→DEP→RCS and Transom DOC→RFD→ARR ordering.
- Full `swift test` cannot run in the Linux container because the iOS target imports SwiftUI; device/Xcode verification is still required.
