# Cypriot Keyboard

A Cypriot Greek keyboard for iPhone and iPad. Type "Lefkosia", get "Λευκωσία".

[![App Store](https://img.shields.io/badge/App_Store-Available-D57800?style=flat-square&logo=apple&logoColor=white)](https://apps.apple.com/us/app/cypriot-keyboard/id1553811546)
[![Made in Cyprus](https://img.shields.io/badge/Made_in-Cyprus_🇨🇾-6B7F3A?style=flat-square)](https://cyprus.com)

## What it does

- **Greeklish autocorrect** — type "kalimera", get "καλημέρα"; "Lefkosia" → "Λευκωσία".
- **Cypriot characters** — `σ̆ ζ̆ ξ̆ ψ̆` for sounds standard Greek doesn't have, on a dedicated breve key.
- **Smart accents** — automatic tonos placement on multi-syllable words.
- **Final-σ** done right (σ in the middle, ς at the end).
- **Privacy-first** — no internet permissions, no tracking, no analytics, no Open Access.

## Repository map

| Path | What's there |
|---|---|
| `Cypriot Keyboard/` | iOS container app (SwiftUI) |
| `Cypriot  Custom Keyboard/` | iOS keyboard extension (note: two spaces in the folder name — preserved for Xcode compat) |
| `Cypriot KeyboardTests/` | Unit + UI tests |
| `dict_generation/` | DAWG-based dictionary build pipeline (Python) |
| `dict/` | Generated `el_CY.dawg` shipped to the extension |
| `docs/superpowers/specs/` | Design specs |
| `docs/superpowers/plans/` | Implementation plans |
| `app-store/` | App Store listing copy, screenshots, mockup |
| `landing/` | Marketing one-pager (deploy via GitHub Pages from `landing/`) |
| `hunspell_src/` | Vendored Hunspell — kept for the eval pipeline only, no longer shipped |

## Build & run

Open `Cypriot Keyboard.xcodeproj` in Xcode. Run the **Cypriot Keyboard** scheme on a simulator or device. Then in iOS Settings → General → Keyboard → Keyboards → Add New Keyboard → **Κυπριακά**.

Command-line equivalents:
```bash
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -sdk iphonesimulator -configuration Debug build

xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

For the test destination, pick a sim from `xcrun simctl list devices available`.

## Marketing & assets

- **App Store listing mockup**: `app-store/mockup/index.html` (preview the listing locally before uploading; see `app-store/mockup/README.md`).
- **Marketing landing page**: `landing/index.html` (single-page site; see `landing/README.md` to deploy on GitHub Pages).
- **Copy drafts**: `app-store/copy/{en,el}.md` (English + Cypriot Greek).
- **Screenshots**: `app-store/screenshots/raw/` (native-resolution, ready to upload).

## Credits

- **Author** — Alex Toumazis
- **Linguistic data** — Dr Spyros Armostis (University of Cyprus)
- **Phonetic corrections** — Aceras Anthropophorum
- **Keyboard framework** — [KeyboardKit](https://github.com/danielsaidi/KeyboardKit) by Daniel Saidi

## License

Source available — see [LICENSE](LICENSE) for details.
