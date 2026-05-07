# App Store Preview Videos

## Apple's spec (as of 2024)

- **Length:** 15–30 seconds
- **Orientation:** matches the device — portrait for iPhone, can be either for iPad
- **File size:** ≤500 MB
- **Format:** `.mov` or `.mp4`, H.264, ≤30 fps
- **Audio:** stereo AAC, optional but encouraged (the App Store mutes audio by default until the user taps)
- **Resolutions:**
  - iPhone 6.9": 886×1920 (portrait) or 1920×886 (landscape)
  - iPhone 6.7": 886×1920 (portrait) or 1920×886 (landscape)
  - iPad Pro 13": 1200×1600 (portrait) or 1600×1200 (landscape)

Up to **3 preview videos per locale per device size**. The first one auto-plays muted.

## What ours should show

Mirrors the in-app onboarding hero, but tighter:

1. **Hook (0–3s)** — a fake textfield typing `Lefkosia`, suggestion bar populates, the typed word swaps to `Λευκωσία`. The single most-important moment.
2. **Cypriot characters (3–9s)** — the breve key on the keyboard, typing `μάσ̆αλλα`. Cypriot dialect is the unique angle vs other Greek keyboards.
3. **Privacy reassurance (9–14s)** — text card or quick callout: "No internet. No tracking. Open Access OFF." Builds trust.
4. **CTA (14–30s)** — name + tagline + "Free on the App Store" / app icon hold.

Total: ~25s, comfortably under the 30s cap.

## Sources

- The in-app `DemoLoopView` in `Cypriot Keyboard/Onboarding/DemoLoopView.swift` already does step 1 — record the simulator running the app to capture it.
- For step 2 (real keyboard typing), launch any text-input app on the simulator with the Cypriot keyboard active and screen-record while typing.
- For text-overlay cards (step 3), edit in After Effects / Motion / DaVinci / Final Cut.

## Capture workflow

```bash
# Boot a sim of the right size
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl boot "iPhone 17 Pro Max"

# Start recording
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io booted recordVideo \
  --codec=h264 "app-store/videos/raw/iphone-69-preview-source.mov"
# (Press Ctrl+C to stop)
```

Edit the resulting `.mov`, then export final cuts to `app-store/videos/edited/<device-class>/`.
