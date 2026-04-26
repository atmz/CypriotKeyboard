# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Native iOS app (`Cypriot Keyboard`) plus a keyboard extension (`Cypriot  Custom Keyboard` — note the **double space** in the folder name and target/scheme name) that implements a Cypriot Greek keyboard with spell-check and autocomplete. Built with Xcode + Swift/SwiftUI on top of [KeyboardKit](https://github.com/danielsaidi/KeyboardKit.git) (SPM, `~> 4.0`). The extension does **not** request open access (see `Cypriot  Custom Keyboard/Info.plist`), so it cannot use App Groups, network, or shared UserDefaults — only `UserDefaults.standard` inside the extension's own sandbox.

iOS deployment target: 14.4 (extension/app), 14.0 (tests). Universal (iPhone + iPad). Swift 5.

## Build / run / test

There is no Makefile or scripts directory — everything is driven through Xcode. Open `Cypriot Keyboard.xcodeproj` in Xcode and run the `Cypriot Keyboard` scheme on a simulator/device, then enable the keyboard under Settings → General → Keyboard → Keyboards → Add New Keyboard → Κυπριακά.

Command-line equivalents (mind the spaces — quote everything):

```bash
# Build the container app (which embeds the extension)
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -sdk iphonesimulator -configuration Debug build

# Build only the keyboard extension
xcodebuild -project "Cypriot Keyboard.xcodeproj" \
  -scheme "Cypriot  Custom Keyboard" -sdk iphonesimulator build

# Run unit + UI tests
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' test

# Single test (Xcode -only-testing format)
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"Cypriot KeyboardTests/Cypriot_KeyboardTests/testExample" test
```

Note: `Cypriot KeyboardTests/Cypriot_KeyboardTests.swift` currently contains only Xcode template stubs — there is no real test suite.

## Architecture

### Two-target layout, shared source

Most Swift files in `Cypriot  Custom Keyboard/` (e.g. `KeyboardView.swift`, `KeyboardViewController.swift`, `CypriotKeyboard*Provider.swift`, `CypriotKeyboardUtil.swift`) are compiled into **both** the app target and the extension target — the `project.pbxproj` lists each `PBXFileReference` twice in `Sources` build phases. When adding a new Swift file used by both, add it to both targets' build phases. The `el_CY.aff` / `el_CY.dic` resources under `dict/` are likewise bundled into both targets.

### Hunspell integration

`hunspell_src/` is a vendored copy of the Hunspell C++ library, exposed to Swift via:
- `hunspell_src/module.modulemap` declares `module hunspell [system][extern_c] { header "hunspell.h" }`.
- The two empty `*-Bridging-Header.h` files at the repo root are the targets' Swift bridging headers (Hunspell is loaded through the modulemap, not the bridging header).
- Swift code calls the C ABI directly: `Hunspell_create(affPath, dicPath)`, `Hunspell_suggest(...)`, `Hunspell_free_list(...)`, `Hunspell_destroy(...)`.

The `.cxx` files are compiled directly into each target. There is no separate framework build step.

### Autocomplete pipeline (the heart of the app)

`KeyboardViewController.performAutocomplete()` → `CypriotAutocompleteSuggestionProvider.asyncAutocompleteSuggestions(...)`:

1. **Greeklish detection / transliteration**: `CypriotKeyboardHelper.greekify(text:)` in `CypriotKeyboardUtil.swift` maps Latin (Greeklish) input to Greek characters using ordered `replacingOccurrences` chains (digraphs like `sh`/`ch`/`ps` first, then single letters). Order matters — do not reorder these calls without reasoning about overlap (e.g. `th` must be applied before single-letter `t`/`h`; `yi` before `y`/`i`).
2. **Hunspell lookup** on the Greek form. If the word is the first in a sentence and capitalized, lookup is forced to lowercase and capitalization is reapplied to results.
3. **Auto-replace decision** (`shouldReplace`): two distinct rules.
   - Pure-Greek input: only auto-replace if the only difference is diacritics (accents) **and** the word is ≥2 syllables (`countSyllables`).
   - Greeklish input: always biased toward auto-replace; uses Levenshtein distance (`distanceMeasure`) and a hand-curated `commonWords` list to bias toward common short words.
4. **Suggestion bar slot 1 is always the verbatim user input**; slot 2 is the autocomplete candidate (highlighted via `additionalInfo["willReplace"]`); remaining slots are extra hunspell suggestions. `KeyboardView.autocompleteBarButton` checks the `willReplace` flag and renders that slot with a gray background.
5. **Race guard**: `KeyboardViewController.autocompleteCount` is incremented per call and used as a lock token — out-of-order async results are dropped.

### Action handling

`CypriotKeyboardActionHandler` (subclass of `StandardKeyboardActionHandler`) overrides `handle(_:on:)` and adds these per-keystroke effects:

- `triggerSpaceAutocomplete`: when the user types space/return/punctuation, if `currentGuess.additionalInfo["willReplace"]` is set **and** the previous action was not `.backspace` (so the user can dismiss a suggestion by deleting), it deletes the typed word and replaces it with the suggestion. The backspace check is load-bearing — removing it breaks the "I really meant what I typed" UX.
- `handleS`: maintains Greek's final-sigma rule (`σ` mid-word, `ς` at end-of-word) and its accented variant `σ̆`/`ς̆`. Triggered on every input action; toggles based on whether the cursor is at end-of-word.
- `triggerAccent`: turns the `΄`/`˘`/` ̈`/`΅` keys into combining diacritics (`U+0301`, `U+0306`, `U+0308`, etc.) applied to the previous character, with allowed-base-letter checks.
- `handleSwitch`: the custom `🔄` character key toggles between Greek (`el_GR`) and Latin (`en_US`) layouts and persists the choice in `UserDefaults.standard` under `isLatinKeyboard` (read at startup in `KeyboardViewController.viewDidLoad`).

### Layout providers

`CypriotKeyboardLayoutProvider` dispatches to `CypriotKeyboardiPhoneLayoutProvider` or `CypriotKeyboardiPadLayoutProvider` based on `context.device.userInterfaceIdiom`. Both override `bottomActions` to insert the `🔄` language-toggle key. The iPhone provider also forces all alphabetic character keys to `0.1`-of-width to fit the 9-column Greek layout.

`CypriotKeyboardInputSetProvider.alphabeticInputSet()` swaps the trailing accent key on the top row from `΄` to `˘` (breve) when the previous character is one of `σ ζ ξ ψ ς` — Cypriot Greek uses `σ̆`/`ζ̆`/etc. for sounds absent from standard Greek.

### Container app

`Cypriot Keyboard/ContentView.swift` is a small SwiftUI screen whose only job is to (a) detect via `AppleKeyboards` in `UserDefaults.standard.dictionaryRepresentation()` whether the extension is enabled, and (b) deep-link to Settings (`App-prefs:root=General&path=Keyboard/KEYBOARDS`) with installation instructions. Localized strings live in `el.lproj/` and `en.lproj/Localizable.strings`.

## Conventions specific to this repo

- The folder/target name `Cypriot  Custom Keyboard` has **two spaces**. Preserve this exactly in any path or `xcodebuild -scheme` argument; otherwise the build won't find it.
- Greek string literals appear throughout source (suggestion overrides, vowel/consonant tables, callout actions). Edit them as UTF-8; the `greekify` chain and `commonWords` array assume lowercase Greek in their internal forms.
- `print(...)` calls in the autocomplete provider and action handler are intentional debug logging visible via Console.app when the extension runs — leave or remove deliberately, don't reflexively "clean them up".
- The extension has `RequestsOpenAccess = false`. Do not add code that would require open access (network, App Groups, photo library, audio/haptic feedback) without coordinating a plist change.
