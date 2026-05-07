# Raw Screenshots

Direct PNG dumps from `xcrun simctl io booted screenshot`. These are the source material for `../edited/`, not what gets uploaded to the App Store.

## Naming convention

```
<state>-<locale>-<device-model>.png
```

Examples:
- `welcome-en-iphone17pro.png` — welcome (uninstalled) state, English, iPhone 17 Pro
- `postinstall-el-iphone17promax.png` — installed state, Cypriot Greek, iPhone 17 Pro Max

## Device → App Store size mapping

App Store Connect groups by display size class. Apple downsamples for smaller classes automatically when one larger asset is provided, but uploading the right native size per class is still recommended.

| Capture from         | Native res    | Maps to App Store class |
|----------------------|---------------|-------------------------|
| iPhone 17 Pro Max    | 1320×2868     | 6.9" (preferred)        |
| iPhone 17 Pro        | 1206×2622     | 6.3"                    |
| iPhone 16e / 17      | 1170×2532     | 6.1"                    |
| iPad Pro 13" (M4)    | 2064×2752     | iPad 13"                |

## Current contents (captured 2026-05-07)

All captured at the "hold replaced" phase of the demo loop animation (clean frame, no transition overlap).

| File                                       | State        | Locale | Device              |
|--------------------------------------------|--------------|--------|---------------------|
| `welcome-en-iphone17pro.png`               | Welcome      | en     | iPhone 17 Pro (6.3") |
| `welcome-el-iphone17pro.png`               | Welcome      | el     | iPhone 17 Pro (6.3") |
| `welcome-en-iphone16e.png`                 | Welcome      | en     | iPhone 16e (6.1")   |
| `welcome-el-iphone16e.png`                 | Welcome      | el     | iPhone 16e (6.1")   |
| `postinstall-en-iphone17promax.png`        | Post-install | en     | iPhone 17 Pro Max (6.9") |
| `postinstall-el-iphone17promax.png`        | Post-install | el     | iPhone 17 Pro Max (6.9") |
| `postinstall-en-iphone17.png`              | Post-install | en     | iPhone 17 (6.1")    |
| `postinstall-el-iphone17.png`              | Post-install | el     | iPhone 17 (6.1")    |

## Capture command

The locale switch is handled by app-launch arguments — no need to change the simulator's system language.

```bash
DEV=/Applications/Xcode.app/Contents/Developer
DEVELOPER_DIR=$DEV xcrun simctl boot "iPhone 17 Pro Max"
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Cypriot_Keyboard-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name "Cypriot Keyboard.app" | head -1)
DEVELOPER_DIR=$DEV xcrun simctl install booted "$APP_PATH"

# Welcome (no keyboard installed) — keep this sim fresh
DEVELOPER_DIR=$DEV xcrun simctl launch booted alextoumazis.Cypriot-Keyboard \
    -AppleLanguages '(en)' -AppleLocale en_CY
sleep 3.5  # captures the demo loop's "hold replaced" phase
DEVELOPER_DIR=$DEV xcrun simctl io booted screenshot \
    app-store/screenshots/raw/welcome-en-iphone17promax.png
```

To capture the **post-install** state, the Cypriot keyboard must be added in iOS Settings on that simulator first (Settings → General → Keyboard → Keyboards → Add → Κυπριακά). The state is per-simulator, so once added it persists.

## Still missing

- **Welcome** state on iPhone 17 Pro Max — that sim has the keyboard installed. Erase content first (Device menu → Erase All Content and Settings) or use a fresh sim of the same class.
- **iPad Pro 13"** captures — both states. Universal app supports iPad; Apple requires at least one iPad screenshot.
- **Install sheet open** state — needs a tap mid-launch. Easiest by hand in the simulator: launch app, tap "Install in 3 taps" CTA, then `xcrun simctl io booted screenshot ...` from another terminal.
