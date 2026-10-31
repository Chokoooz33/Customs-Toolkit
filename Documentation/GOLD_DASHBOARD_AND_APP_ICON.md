# Gold Dashboard + App Icon Pass

## Native gold dashboard
- Added `GoldPriceService` to fetch the approved Oman gold-price source without rendering its consent/advertising UI during normal dashboard use.
- Parses 24K, 22K, 21K and 18K OMR/gram values.
- Caches the latest successful snapshot in `UserDefaults` for instant display on subsequent launches.
- Refresh interval: 10 minutes; manual refresh remains available.
- If the live refresh fails, the last cached snapshot remains visible.
- The original `GoldPriceWebView` remains available via **View Source** as the fallback/reference page.
- The fallback WebView explicitly uses the persistent default website data store so a consent choice can persist normally.

## App identity
- Added `Assets.xcassets`.
- Added a full `AppIcon` set including 1024×1024 marketing icon.
- Added `BrandMark` and replaced the temporary SF Symbol header mark with the real brand asset.
- Added `AccentColor` asset.
- Updated `generate_project.py` and `Package.swift` so the asset catalog remains part of regenerated builds.

## Verification performed in this environment
- All Swift source/test files: `swiftc -parse` passed.
- `swift package dump-package` passed.
- Asset catalog JSON files validated.
- AppIcon 1024 image verified as RGB (no alpha).

Full Xcode/iOS build must still be run on macOS/Xcode.
