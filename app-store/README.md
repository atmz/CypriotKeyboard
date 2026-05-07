# App Store Assets

Source of truth for everything that goes into the App Store Connect listing. The store page itself is the live artifact — this folder is where the inputs are drafted, edited, and version-controlled before they get uploaded.

## Layout

```
app-store/
├── README.md            # this file
├── copy/
│   ├── en.md            # English: name, subtitle, promo, description, keywords, what's new
│   └── el.md            # Cypriot dialect
├── screenshots/
│   ├── raw/             # direct simulator captures (source material)
│   └── edited/          # framed / captioned final assets, per device size
└── videos/
    ├── README.md        # spec for the App Store preview video
    ├── raw/             # screen recordings before editing
    └── edited/          # final ≤30s previews per device size
```

## Why this lives in the repo

- The **copy** is small and high-leverage; tracking it in git lets us see what changed between releases and revert quickly if a wording experiment doesn't pay off.
- The **raw screenshots** are reproducible at any time from the app, so we don't need to keep a giant trove — just enough to seed editing.
- The **edited screenshots** and **videos** can be large; if they balloon past a few MB each, consider git-lfs or moving the binary outputs to a dedicated assets bucket and only keeping the source files (e.g. Figma exports as `.fig` checked-in via Figma export, or Frameit configs).

## Workflow

1. Update `copy/{en,el}.md` for the next release. Bump the "What's new" section.
2. Capture fresh screenshots from the iOS simulator (script in `../scripts/` once we have one — for now do it by hand, see [Capturing screenshots](#capturing-screenshots) below).
3. Drop the raw PNGs into `screenshots/raw/`.
4. Run them through your editor of choice (Figma / Sketch / [Fastlane Frameit](https://docs.fastlane.tools/actions/frameit/) / Apple's Marketing Resources). Save final framed PNGs into `screenshots/edited/<device-size>/`.
5. Record the demo video (or export from a screen recording of the simulator) into `videos/raw/`. Edit, export to `videos/edited/<device-size>/`.
6. Upload to App Store Connect manually or via [`fastlane deliver`](https://docs.fastlane.tools/actions/deliver/).
7. Commit the new copy and edited assets back to `main`.

## Capturing screenshots

For now (no script yet):

```bash
# 1. Boot the device sim you want
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl boot "iPhone 17 Pro Max"

# 2. Build + install (run from the project root)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -sdk iphonesimulator -configuration Debug build

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Cypriot_Keyboard-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name "Cypriot Keyboard.app" | head -1)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl install booted "$APP_PATH"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch booted alextoumazis.Cypriot-Keyboard

# 3. Snapshot
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io booted screenshot \
  "app-store/screenshots/raw/iphone-67-welcome.png"
```

To capture the **welcome (uninstalled) state**, use a fresh simulator that doesn't have the keyboard added — `iPhone 16e` was clean as of 2026-05-06. To capture the **post-install state**, manually enable the Cypriot keyboard in that simulator's Settings first.

To switch between **en** and **el** locales for screenshots, change the simulator's language under Settings → General → Language & Region or pass `-AppleLanguages '(el)'` to `xcrun simctl launch`.

## Required device sizes

App Store Connect (as of iOS 17+ / 2024) accepts:

| Device class            | Display size | Resolution        | Required? |
|-------------------------|--------------|-------------------|-----------|
| iPhone 6.9"             | 6.9"         | 1320×2868 px      | One of these required for iPhone |
| iPhone 6.7"             | 6.7"         | 1290×2796 px      | (legacy) |
| iPhone 5.5"             | 5.5"         | 1242×2208 px      | Not strictly required if 6.9" provided |
| iPad Pro M4 13"         | 13"          | 2064×2752 px      | Required if app supports iPad |
| iPad Pro 12.9" (gen 2)  | 12.9"        | 2048×2732 px      | (legacy fallback) |

Min 1, max 10 screenshots per device size per locale.

## Locales

App Store listings are per-locale. We ship `en` (English) and `el` (Greek — Cypriot dialect, same as the in-app strings). Other Greek-speaking locales (`el-GR`) inherit from `el` unless we add a separate listing.
