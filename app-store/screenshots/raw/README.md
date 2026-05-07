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

All captured at the "hold replaced" phase of the demo loop animation (clean frame, no transition overlap, with the new opacity-stacking demo loop).

| File                                          | State        | Locale | Device                | Demo phrase shown |
|-----------------------------------------------|--------------|--------|-----------------------|-------------------|
| `welcome-en-iphone17promax.png`               | Welcome      | en     | iPhone 17 Pro Max (6.9") | Lefkosia → Λευκωσία |
| `welcome-el-iphone17promax.png`               | Welcome      | el     | iPhone 17 Pro Max (6.9") | Lefkosia → Λευκωσία |
| `welcome-en-iphone17promax-je.png`            | Welcome      | en     | iPhone 17 Pro Max (6.9") | je → τζαι |
| `welcome-en-iphone17promax-allous.png`        | Welcome      | en     | iPhone 17 Pro Max (6.9") | pe je stous allous → πε τζαι στους άλλους |
| `welcome-en-iphone17pro.png`                  | Welcome      | en     | iPhone 17 Pro (6.3")  | Lefkosia |
| `welcome-el-iphone17pro.png`                  | Welcome      | el     | iPhone 17 Pro (6.3")  | Lefkosia |
| `welcome-en-iphone16e.png`                    | Welcome      | en     | iPhone 16e (6.1")     | Lefkosia |
| `welcome-el-iphone16e.png`                    | Welcome      | el     | iPhone 16e (6.1")     | Lefkosia |
| `postinstall-en-iphone17promax.png`           | Post-install | en     | iPhone 17 Pro Max (6.9") | Lefkosia |
| `postinstall-el-iphone17promax.png`           | Post-install | el     | iPhone 17 Pro Max (6.9") | Lefkosia |
| `postinstall-en-iphone17.png`                 | Post-install | en     | iPhone 17 (6.1")      | Lefkosia |
| `postinstall-el-iphone17.png`                 | Post-install | el     | iPhone 17 (6.1")      | Lefkosia |

The 3 phrase variants on iPhone 17 Pro Max give you a carousel option for the App Store: lead with `Lefkosia` (canonical hook), follow with `je` (showcases Cypriot dialect), close with the full phrase (showcases multi-word handling).

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

- **iPad Pro 13"** captures — both states. Universal app supports iPad; Apple requires at least one iPad screenshot.
- **Install sheet open** state — needs a tap mid-launch. Easiest by hand in the simulator: launch app, tap "Install in 3 taps" CTA, then `xcrun simctl io booted screenshot ...` from another terminal.
- **el (Cypriot dialect) variants of the phrase carousel** — only `Lefkosia` was captured in el. The `je` and `allous` variants on iPhone 17 Pro Max are en only.
