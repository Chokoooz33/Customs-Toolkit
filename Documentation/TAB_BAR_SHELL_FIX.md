# Tab Bar Shell Fix — V3.5

The native `TabView` container was removed from `MainTabView`.

On newer iOS versions, the system can retain a floating native tab-bar shell even when `.toolbar(.hidden, for: .tabBar)` is used. This caused the empty white/dark rounded pill visible on tool/detail screens after the custom Customs Toolkit bar itself was hidden.

`MainTabView` now owns navigation fully using a ZStack of the four root tabs plus the existing custom bottom bar. The root views remain alive to preserve their local state, while only the selected root is visible and interactive.

Result:
- No native/system tab bar exists in the hierarchy.
- Custom bar remains visible only on root tabs.
- Entire bottom navigation (including background/shell) disappears on detail/tool screens.
- No empty white/dark pill remains.
