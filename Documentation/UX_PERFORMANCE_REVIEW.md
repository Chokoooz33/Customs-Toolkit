# Customs Toolkit — UX & Performance Review

## Changes in this pass

- HS search now pre-normalizes Arabic and English descriptions once when the tariff dataset loads instead of normalizing 14k+ descriptions on each keystroke.
- Search is debounced by 140 ms to avoid repeated full-dataset scans while the user is still typing.
- Pure code/description searches require at least two effective characters before searching, preventing extremely broad one-character queries such as `8` from rendering thousands of cards.
- UI search results are capped at 160 visible records while preserving the real total match count.
- HS result rendering uses `LazyVStack` instead of eagerly creating all result cards.
- Fixed `isSearching` state so it returns to false after a completed search.
- Removed duplicate search execution when selecting a recent query.
- Localized the Arabic UI labels that were still shown in English (`Normalized`, `Rate`, web error copy).
- Gold Price WebView no longer ignores the bottom safe area, reducing overlap with the persistent tab bar.
- Difference Calculator uses a scalable principal navigation title to prevent Arabic title truncation.
- Home header now includes a compact interim product mark and a more coherent brand card.

## Visual direction

Keep the current deep customs blue as the main product color. The app is strongest when it stays neutral, functional and iOS-native. Avoid adding multiple tool-specific colors. The permanent logo should use a compact customs/logistics symbol with a verification/check element, but should not mimic an official government emblem.
