# Raw Screenshots

Direct PNG dumps from `xcrun simctl io booted screenshot`. These are the source material for `../edited/`, not what gets uploaded to the App Store.

## Naming convention

```
<state>-<locale>-<device-model>.png
```

Examples:
- `welcome-en-iphone17.png` — welcome (uninstalled) state, English, iPhone 17 simulator
- `postinstall-el-iphone17promax.png` — installed state, Cypriot Greek, iPhone 17 Pro Max

## Device → App Store size mapping

App Store Connect groups by display size class, not by device model. Capture from the largest device in a class — Apple downsamples for the smaller classes automatically.

| Capture from         | Native res    | Maps to App Store class |
|----------------------|---------------|-------------------------|
| iPhone 17 Pro Max    | 1320×2868     | 6.9" (preferred)        |
| iPhone 17 Pro        | 1206×2622     | 6.3"                    |
| iPhone 17            | 1170×2532     | 6.1" (legacy)           |
| iPad Pro 13" (M4)    | 2064×2752     | iPad 13"                |

## Current contents

| File                              | What it is | Captured | Note |
|-----------------------------------|-----------|----------|------|
| `welcome-en-iphone17.png`         | Onboarding welcome state, English, iPhone 17 sim | 2026-05-06 | Demo loop caught mid-replacement (visible "Lefkosia"/"Λευκωσία" overlap). Re-capture for final upload. |
| `postinstall-en-iphone17.png`     | Onboarding post-install state, English, iPhone 17 sim | 2026-05-07 | Renders correctly. |

## TODO before uploading

- Recapture at iPhone 17 Pro Max for the 6.9" class
- Capture el (Cypriot dialect) variants — switch the simulator's language under Settings → General → Language & Region, then re-launch
- Capture the install sheet open (need a tap mid-launch — easiest by hand in the simulator)
