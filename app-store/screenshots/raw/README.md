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

## Current contents (captured 2026-05-12)

All captured at the "hold replaced" phase of the demo loop animation (clean frame, no transition overlap), against the v1.9 onboarding with the **3-tap copy**: hero CTA "Install in 3 taps →", install sheet "Install in 3 taps" with the verified path (Open Settings · Tap Keyboards · Toggle Κυπριακό Keyboard on), and `UIApplication.openSettingsURLString` as the underlying deep link. Real-device testing confirmed the 3-tap promise — Apple shows a "Keyboards" entry directly on the app's per-app Settings page that lets users toggle the keyboard on without further navigation.

| File                                          | State        | Locale | Device                | Demo phrase shown |
|-----------------------------------------------|--------------|--------|-----------------------|-------------------|
| `welcome-en-iphone17promax.png`               | Welcome      | en     | iPhone 17 Pro Max (6.9") | Lefkosia → Λευκωσία |
| `welcome-el-iphone17promax.png`               | Welcome      | el     | iPhone 17 Pro Max (6.9") | Lefkosia → Λευκωσία |
| `welcome-en-iphone17promax-je.png`            | Welcome      | en     | iPhone 17 Pro Max (6.9") | je → τζ̆αι |
| `welcome-en-iphone17promax-allous.png`        | Welcome      | en     | iPhone 17 Pro Max (6.9") | pe je stous allous → πε τζ̆αι στους άλλους |
| `welcome-en-iphone17pro.png`                  | Welcome      | en     | iPhone 17 Pro (6.3")  | Lefkosia |
| `welcome-el-iphone17pro.png`                  | Welcome      | el     | iPhone 17 Pro (6.3")  | Lefkosia |
| `welcome-en-iphone16e.png`                    | Welcome      | en     | iPhone 16e (6.1")     | Lefkosia |
| `welcome-el-iphone16e.png`                    | Welcome      | el     | iPhone 16e (6.1")     | Lefkosia |
| `postinstall-en-iphone17.png`                 | Post-install | en     | iPhone 17 (6.1")      | Lefkosia |
| `postinstall-el-iphone17.png`                 | Post-install | el     | iPhone 17 (6.1")      | Lefkosia |
| `welcome-en-ipadpro13.png`                    | Welcome      | en     | iPad Pro 13" (M4)     | Lefkosia |
| `welcome-el-ipadpro13.png`                    | Welcome      | el     | iPad Pro 13" (M4)     | Lefkosia |

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

## Still missing or pending re-capture against the 3-tap copy

- **iPhone 16e (6.1") welcome captures** — sim display didn't initialise during the May 12 batch run (every `simctl io screenshot` against it returned a 0-byte file). Existing files in this folder for that device still have the old "Set up the keyboard" CTA. Re-capture once the sim display is back: shut down + reboot the sim, ensure Simulator.app is foregrounded showing it, then run the capture script.
- **iPad Pro 13" welcome captures** — same display issue as 16e. Same fix.
- **iPhone 17 (6.1") post-install captures** — same display issue. Existing files don't show the welcome CTA so they're still visually accurate even pre-fix.
- **iPhone 17 Pro Max (6.9") post-install** — sim was erased to capture welcome state, so it no longer has the Cypriot keyboard installed. Re-add the keyboard manually (Settings → General → Keyboard → Keyboards → Add → Κυπριακά) on that sim, then re-launch and capture for both en and el.
- **Install sheet open state** — needs a tap mid-launch (simctl has no tap subcommand). Easiest by hand: launch app in the simulator, tap "Install in 3 taps" CTA to open the sheet, then run `xcrun simctl io booted screenshot ...` from another terminal.
- **el variants of the `je` and `allous` phrase carousel** — only `Lefkosia` was captured in el. The other two are en only.
