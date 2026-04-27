# Cypriot Keyboard — Android Port Design

Date: 2026-04-27
Author: autonomous brainstorm (Opus 4.7)
Status: proposed

## Goal

Port the iOS Cypriot Greek keyboard to Android, preserving feature parity for the
core typing experience: Greek/Greeklish input, autocorrect with the DAWG suggester,
final-sigma handling, accent combining, and the 🔄 layout-toggle key.

The Android port lives entirely under `/android/`. The iOS sources, dictionary
files, and Hunspell vendored library remain untouched.

## Non-goals

- **Hunspell engine.** The iOS DAWG path (Tier C) is the user's preferred
  suggester; it has phonetic folding and is well-tested. Porting Hunspell to
  Android requires NDK + JNI plumbing that we don't need. The Android port
  ships only the DAWG suggester. If the user later wants Hunspell on Android,
  it can be added in a separate phase.
- **Gesture typing / swipe input.** Not present on iOS; not in scope.
- **Emoji panel, theming engine, full clipboard.** Not present on iOS; not in
  scope. Standard Android emoji input (via the system 🌐 key) remains
  available.
- **Open-access features** (network, shared prefs across processes, photo
  library). The iOS extension explicitly avoids these; Android keeps the same
  posture.
- **iPad-specific layout.** Android tablets get the same layout as phones;
  density adapts via `dp` units. The iOS iPad layout was a near-clone of
  iPhone anyway.

## Framework decision

**Roll our own** on top of Android's `InputMethodService`, written in Kotlin
with Jetpack Compose for the keyboard view.

Reasoning:
- HeliBoard (the strongest fork-target candidate) carries gesture typing,
  emoji panel, theming engine, dictionary management UI, and a Java/C++ legacy
  we don't use. Forking it means inheriting ~50k LOC to navigate.
- The iOS keyboard is genuinely simple: a 9-column Greek layout, a suggestion
  bar, and ~5 hooks in the action handler. `InputMethodService` provides the
  same abstraction on Android that `KeyboardInputViewController` does on iOS.
- Compose for the keyboard view parallels SwiftUI structure on iOS — keeps the
  two ports legible to anyone reading both.
- License compatibility is a non-issue for this approach; the iOS code is
  GPL-3.0, and our new Android code will match.

If something forces a re-evaluation (e.g. we end up reimplementing Android
keyboard primitives that HeliBoard would give us free), HeliBoard remains the
fallback fork target.

## Architecture

```
android/
├── app/                                    # Container app (installation guide)
│   ├── src/main/kotlin/.../MainActivity.kt
│   ├── src/main/res/values/strings.xml     # en + el via -el qualifier
│   └── build.gradle.kts
├── ime/                                    # Input-method service (the keyboard)
│   ├── src/main/kotlin/.../
│   │   ├── CypriotInputMethodService.kt    # entry point (mirrors KeyboardViewController)
│   │   ├── ui/
│   │   │   ├── KeyboardView.kt             # Compose root (mirrors KeyboardView.swift)
│   │   │   ├── SuggestionBar.kt            # mirrors autocompleteBar + willReplace highlight
│   │   │   ├── KeyboardLayout.kt           # row/key composables
│   │   │   └── theme/                      # colors, typography
│   │   ├── layout/
│   │   │   ├── LayoutSpec.kt               # data class describing rows/keys
│   │   │   ├── GreekAlphabeticLayout.kt    # 9-col Greek (matches iOS InputSetProvider)
│   │   │   ├── LatinAlphabeticLayout.kt
│   │   │   ├── NumericLayout.kt
│   │   │   └── SymbolicLayout.kt
│   │   ├── input/
│   │   │   ├── ActionHandler.kt            # mirrors CypriotKeyboardActionHandler
│   │   │   ├── Greekify.kt                 # mirrors greekify() (pure function)
│   │   │   ├── FinalSigmaRule.kt           # mirrors handleS()
│   │   │   ├── AccentCombiner.kt           # mirrors triggerAccent()
│   │   │   └── SecondaryCallouts.kt        # mirrors CypriotSecondaryCalloutActionProvider
│   │   ├── suggest/
│   │   │   ├── DawgReader.kt               # mirrors DawgReader.swift (mmap binary)
│   │   │   ├── PhoneticFolder.kt           # mirrors PhoneticFolder.swift
│   │   │   ├── DamerauSuggester.kt         # mirrors DamerauLevenshteinSuggester.swift
│   │   │   └── SuggestionEngine.kt         # mirrors DawgAutocompleteSuggestionProvider
│   │   └── util/
│   │       └── CommonWords.kt              # mirrors commonWords set
│   ├── src/main/assets/
│   │   ├── el_CY.dawg                      # copied from /dict/
│   │   └── phonetic_fold.json              # copied from /dict_generation/
│   ├── src/main/res/xml/method.xml         # IME metadata
│   ├── src/main/AndroidManifest.xml        # registers IME service
│   └── build.gradle.kts
├── settings.gradle.kts
├── build.gradle.kts                        # root
├── gradle.properties
└── README.md                               # build/run instructions
```

Two Gradle modules: `app` (the launcher activity / installation guide) and
`ime` (the input method service itself). The container app and the IME ship
in a single APK; the IME is registered via `AndroidManifest.xml`'s
`<service android:name=".CypriotInputMethodService" ...>` and
`<intent-filter>` for `android.view.InputMethod`.

### Component contracts

**LayoutSpec** — pure data describing keyboard rows. Three concrete instances
(Greek alpha, Latin alpha, numeric, symbolic). Width is per-key (default 1.0 of
a 9-column unit). The Greek alpha layout is the iOS `alphabeticInputSet()` data:
- Row 1: ε ρ τ υ θ ι ο π ΄ (or `˘` when previous letter is σ ζ ξ ψ ς)
- Row 2: α σ δ φ γ η ξ κ λ
- Row 3: ζ χ ψ ω β ν μ
- Bottom: shift, 🔄, space, return

**Greekify** — `fun greekify(text: String): String`. Pure single-pass scanner.
Direct port of `CypriotKeyboardHelper.greekify` including the trigraph/digraph
priority. Has property tests on a few canonical inputs.

**DawgReader** — opens the bundled `el_CY.dawg` via `AssetManager` (read once
at IME init into a `ByteBuffer.allocateDirect`-backed structure, **not** mmap;
asset files are inside the APK and aren't directly mmappable on Android).
Same v1 binary format as iOS. Implements `payloadForKey`, `step`,
`canonicalForms`, `edges`, `terminalPayload`. Indexed offsets are computed
once on construction.

**PhoneticFolder** — loads `phonetic_fold.json` from assets. Same
longest-match-first folding algorithm as the Swift version.

**DamerauSuggester** — same edit-distance-1 candidate enumeration as iOS.
Returns up to N ranked `(canonical, freq, distance)` triples.

**SuggestionEngine** — wraps `DawgReader` + `PhoneticFolder` + `DamerauSuggester`.
Public API: `suspend fun suggest(input: String): List<Suggestion>` where
`Suggestion(text: String, willReplace: Boolean, isVerbatim: Boolean)`. Slot 0 is
always the verbatim input; slot 1 is the top candidate (with `willReplace=true`);
slots 2+ are extras. Mirrors `DawgAutocompleteSuggestionProvider.buildSuggestions`
including capitalization handling (lowercase / firstLetterCap / allCaps).

**ActionHandler** — sequenced just like the iOS handler:
1. Apply key (insert text via `InputConnection.commitText`)
2. `triggerSpaceAutocomplete` — if action is space/return/punctuation AND
   `currentGuess.willReplace` AND `lastAction != backspace`, replace the typed
   word with the suggestion before inserting the trigger char.
3. `handleS` — final-sigma rule.
4. `triggerAccent` — combining diacritics for `΄ ˘ ¨ ΅`.
5. Trigger autocomplete (debounced 40ms; race-token guarded; off main thread).
6. Update `lastAction`.

**CypriotInputMethodService** — owns:
- The Compose `KeyboardView` (set as input view via `onCreateInputView`).
- The current locale flag (Greek vs Latin) persisted in `SharedPreferences` under
  `isLatinKeyboard`, mirroring the iOS `UserDefaults` key.
- The `SuggestionEngine` (lazy-initialized off-thread).
- The `currentGuess`, `lastAction`, `autocompleteCount` race-guard token.

### Data flow

```
key tap → ActionHandler.handle(action)
           ├─ commitText → InputConnection
           ├─ post-effects (final-sigma, accent, space-replace)
           └─ triggerAutocomplete (debounced)
                 └─ SuggestionEngine.suggest(currentWord)
                       └─ updates Compose state → SuggestionBar recomposes
suggestion tap → ActionHandler.applySuggestion(s)
                  └─ replaceCurrentWord → InputConnection
```

### Error handling

- DAWG load failure → log, fall back to no-suggestion mode (keyboard still
  types). The user gets a verbatim-only suggestion bar. This matches iOS's
  behavior of falling through to the Hunspell provider, but on Android we
  simply degrade gracefully with no suggestions.
- Phonetic-fold JSON missing → same: degrade to no suggestions.
- DAWG corruption (bad magic, bad version) → same.
- All file I/O happens off the main thread; `IOException` is caught and logged.

### Testing

- **Unit tests** for `Greekify` (golden inputs from iOS tests, hand-verified).
- **Unit tests** for `PhoneticFolder` (load JSON, fold strings).
- **Unit tests** for `DawgReader` (open the bundled DAWG, look up known words).
- **Unit tests** for `DamerauSuggester` (known-input → known-candidate set).
- **Unit tests** for `FinalSigmaRule` (state transitions).
- **Instrumentation tests** for the IME service are out of scope for this
  iteration — they require the AndroidX IME test harness which is heavy.
  Manual testing on an emulator is the verification path.

## Build / run

- Gradle 8.x, Android Gradle Plugin 8.6+, Kotlin 2.0+, Jetpack Compose BOM
  2025.x.
- min SDK 24 (Android 7.0, ~99% device coverage).
- target SDK 35 (Android 15).
- Build: `cd android && ./gradlew :app:installDebug`.
- Enable: Settings → System → Languages & input → On-screen keyboards →
  Manage keyboards → toggle "Cypriot Keyboard".
- The container app's MainActivity mirrors `ContentView.swift` —
  detects whether the IME is enabled (via `InputMethodManager`'s
  enabled-IME list), shows install instructions if not, shows usage tips if
  yes.

## Out of scope (deliberate)

- CI / GitHub Actions for the Android build.
- Play Store packaging.
- Localization beyond el / en (the iOS app only ships these two).
- Dark-mode polish beyond Material defaults.
- Haptic / audio feedback (mirrors iOS `RequestsOpenAccess = false` posture).

## Risks

1. **Asset file size.** The DAWG is 49 MB. APK size becomes ~50 MB compressed.
   Mitigation: this is acceptable for a niche-language keyboard; users
   downloading specifically for Cypriot will accept it. If problematic later,
   we can ship as an Android App Bundle and use asset packs.
2. **Compose-in-IME stability.** Compose-based keyboards are well-understood
   in 2026 (FlorisBoard does it), but require careful lifecycle handling in
   `InputMethodService` (the service's view tree is detached/reattached on
   each input). We use `setViewTreeLifecycleOwner` /
   `setViewTreeSavedStateRegistryOwner` plumbing on the host view.
3. **DAWG mmap on Android.** Asset files inside an APK can be opened as
   `AssetFileDescriptor` but not directly `mmap`'d on all OEMs. We load the
   49 MB blob into a direct `ByteBuffer` once at startup. RAM cost is the
   same as iOS's mmap (the kernel caches mmap'd pages anyway). Init cost
   is a one-time ~100 ms read.

## Open questions (deferred)

- Should the 🔄 long-press do anything on Android? On iOS it toggles the
  suggester engine (Hunspell ↔ DAWG). Since we ship only DAWG, there's no
  engine to toggle. Long-press is a no-op for v1 and can be repurposed
  later.
- Should we ship the 50 MB DAWG inside the APK or download on first launch?
  v1: ship inside (keeps the keyboard offline and simple). Revisit if Play
  Store rejects on size grounds.
