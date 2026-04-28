# Cypriot Keyboard — Android

Android port of the iOS Cypriot Greek keyboard. See `docs/superpowers/specs/2026-04-27-android-port-design.md` for the design rationale.

## Build

Easiest path: open the `android/` folder in **Android Studio**. The bundled
JBR (Java 21) and SDK manager handle everything.

For the CLI:
```bash
cd android
./gradlew :app:installDebug    # installs to a connected device/emulator
./gradlew :ime:test            # runs the unit-test suite (37 tests)
./gradlew :app:assembleDebug   # produces app/build/outputs/apk/debug/app-debug.apk (~25 MB)
```

The wrapper jar is committed, so the above runs out-of-the-box on any machine
with `JAVA_HOME` and `ANDROID_HOME` set.

Toolchain pinned by the Gradle scripts:
- AGP 8.12.3
- Kotlin 2.1.20 + Compose plugin
- Compose BOM 2025.04.01
- compileSdk / targetSdk = 36, minSdk = 24
- Gradle 8.14.3 (downloaded by the wrapper on first run)
- JDK 17+ (Studio's bundled JBR 21 works)

## Enable the keyboard on-device

1. Open Settings → System → Languages & input → On-screen keyboards → Manage keyboards
2. Toggle on "Cypriot Keyboard"
3. In any text field, tap 🌐 (or long-press space) and pick "Cypriot Keyboard"

## Layout

- Tap 🔄 to toggle Greek ↔ Latin (Greeklish) layouts
- Long-press letters for accented variants (deferred to v2)
- Final sigma is automatic: `σ` becomes `ς` at end-of-word, demoted back to `σ` if you keep typing
- Accent keys (΄ ˘ ¨ ΅) combine with the previous character if it's a valid base

## Architecture

- `app/` — container activity that detects whether the IME is enabled, shows installation steps or usage tips
- `ime/` — the input method service itself, including:
  - `input/` — Greekify, FinalSigmaRule, AccentCombiner, ActionHandler
  - `layout/` — KeySpec / LayoutSpec data, Greek/Latin/numeric/symbolic instances
  - `suggest/` — DawgReader, PhoneticFolder, DamerauSuggester, SuggestionEngine
  - `ui/` — Compose KeyboardView / SuggestionBar / KeyboardLayout
  - `assets/` — bundled `el_CY.dawg` (49 MB) + `phonetic_fold.json`

## What's NOT implemented (deferred)

- Hunspell engine (we ship only DAWG; faster, simpler, no NDK)
- Long-press popup with secondary characters (the data is in `KeySpec.popupChars` but the UI isn't wired)
- Gesture typing (not in iOS either)
- Theming, dark-mode polish, haptic feedback (not in iOS either)
- iPad-specific layout (Android tablets get the phone layout, scaled by `dp`)
