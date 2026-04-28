# CLAUDE.md (android/)

Guidance for Claude Code working inside `android/`. The root `CLAUDE.md` covers
the iOS app; this file covers the Android port. Prefer this file for any work
under `android/`.

## Project

Android port of the iOS Cypriot Greek keyboard. Two Gradle modules:
- `app/` — container app with the install-guide `MainActivity`. Mirrors
  `Cypriot Keyboard/ContentView.swift` on iOS.
- `ime/` — the input-method service. Mirrors the iOS extension
  (`Cypriot  Custom Keyboard/`).

The IME ships only the **DAWG** suggester (no Hunspell). The DAWG binary
(`el_CY.dawg`, ~49 MB) and `phonetic_fold.json` live under
`ime/src/main/assets/` and are copied from the repo's `dict/` and
`dict_generation/` directories — they are **not the source of truth**. Regenerate
the DAWG on the iOS side and re-copy when it changes.

Min SDK 24, target SDK 35, Kotlin 2.0, AGP 8.6, Jetpack Compose BOM 2024.10.

## Build / run / test

The wrapper jar (`gradle/wrapper/gradle-wrapper.jar`) is **not committed**. On a
fresh checkout, generate it once:

```bash
cd android
gradle wrapper --gradle-version 8.10.2
```

Then:

```bash
# Build the IME library + the container app
./gradlew :app:assembleDebug

# Install on a connected device / emulator
./gradlew :app:installDebug

# Run all unit tests in the :ime module
./gradlew :ime:test

# Single test class
./gradlew :ime:test --tests "cy.cypriotkeyboard.ime.input.GreekifyTest"
```

Easiest path for a human: open `android/` as a project in Android Studio.
Studio bundles a JDK + Android SDK + emulator and handles Gradle sync.

To enable the keyboard after installing: Settings → System → Languages & input
→ On-screen keyboards → Manage keyboards → toggle "Cypriot Keyboard".

### Running tests that load the bundled DAWG

`DawgReaderTest`, `DamerauSuggesterTest`, and `SuggestionEngineTest` open
`src/main/assets/el_CY.dawg` via a relative `File()` path. Gradle's default test
working directory is the module dir (`android/ime/`), so this works as-is for
`./gradlew :ime:test`. If you want to run a single test from Android Studio's
gutter, set the working directory of the run configuration to `$MODULE_DIR$`
(it usually defaults correctly).

## Architecture

### Two-module split

`app/` depends on `:ime` so the IME service class is bundled in the same APK.
The IME is registered in `ime/src/main/AndroidManifest.xml` as
`<service android:name=".CypriotInputMethodService" ...>` with the
`BIND_INPUT_METHOD` permission and an intent filter for
`android.view.InputMethod`. There is no separate process — the IME runs in the
same process as the launcher app on demand.

### IME entry point and lifecycle

`ime/src/main/kotlin/cy/cypriotkeyboard/ime/CypriotInputMethodService.kt` is the
single entry point. It implements:
- `InputMethodService` — Android's IME base class
- `LifecycleOwner` + `SavedStateRegistryOwner` — required so the Compose
  view-tree owners (`setViewTreeLifecycleOwner`, `setViewTreeSavedStateRegistryOwner`)
  resolve. Without these, `setContent { }` will crash on first composition.
- `KeyboardController` — interface defined in `ActionHandler.kt` that the
  ActionHandler calls for IME-side effects (request suggestions, switch IME,
  toggle layout).

Lifecycle events are pumped manually:
- `onCreate` → `ON_CREATE`
- `onCreateInputView` → `ON_START` + `ON_RESUME`
- `onDestroy` → `ON_DESTROY`

If you add long-running coroutines/observers, you can use
`lifecycleScope`/`repeatOnLifecycle` against the registry — but be aware that
the service stays in `RESUMED` between input sessions. Standard Activity
patterns don't 1:1 apply.

### Compose state flow

The service holds a `mutableStateOf(KeyboardUiState(layout, suggestions))`.
Compose composables observe it via the `State<KeyboardUiState>` parameter on
`KeyboardView`. Mutations always happen on the main thread:

- Layout changes (mode toggle, breve swap) → `recomputeLayout()` writes
  `uiState.value = uiState.value.copy(layout = ...)`
- Suggestion updates → posted from worker thread back through
  `mainHandler.post { ... uiState.value = ... }`

### Action pipeline (mirrors iOS)

`ActionHandler.handle(KeySpec)` is the orchestrator. Sequencing:
1. **Commit text** for `KeyAction.Character` (or trigger space-replace logic for
   space, return, and the punctuation set in `PUNCT_TRIGGERS`).
2. **Final-sigma rule** (`applyFinalSigma`) — promotes trailing `σ` → `ς` and
   demotes mid-word `ς` → `σ`. Mirrors iOS `handleS`. Pure function in
   `input/FinalSigmaRule.kt`; ActionHandler interprets the result and calls
   `InputConnection.deleteSurroundingText` + `commitText`.
3. **Accent dead-keys** — the four accent glyphs (΄ ˘ ¨ ΅) come through the
   layout as `KeyAction.Character`. ActionHandler intercepts them via
   `ACCENT_DEAD_KEYS` BEFORE commit, looks at the previous cluster (handling
   `σ̆`/`ς̆` 2-codepoint clusters in `takeLastCluster`), and emits a combining
   diacritic via `applyAccent` (`input/AccentCombiner.kt`). The dialytika key is
   the literal string `" ̈"` — a leading space + U+0308 — to match iOS exactly;
   if you change one side, change both.
4. **Request suggestions** — debounced 40ms via `mainHandler.postDelayed`,
   race-guarded via an `AtomicInteger` token. The token check sits inside the
   final `mainHandler.post` so stale results can never reach UI state.

### Suggestion pipeline

`SuggestionEngine.suggest(input: String)` runs synchronously on the worker
thread:
1. `greekify(input)` — Greeklish → Greek (`input/Greekify.kt`)
2. Casing detection → `lookupGreek` (lowercase form) + a `Casing` enum
3. `PhoneticFolder.fold(lookupGreek)` → fold-keyspace string
4. `DamerauSuggester.suggest(foldKey)` → ranked `(canonical, freq, distance)` list
5. Build `[verbatim, top with willReplace=true, ...extras]`, recapitalizing
   based on detected casing.

The DAWG binary format is documented at `dict_generation/DAWG_FORMAT.md` (root
of repo). `DawgReader.kt` is a 1:1 port of `DAWG/DawgReader.swift`. **Do not
diverge the formats** — both readers consume the same `el_CY.dawg`.

### Layout data

`layout/Layouts.kt` holds four concrete `LayoutSpec` instances: `greekAlphabetic`,
`latinAlphabetic`, `numeric`, `symbolic`. The Greek alpha rows are a 1:1 port of
`CypriotKeyboardInputSetProvider.alphabeticInputSet()` (3 rows of 9 letters).
The bottom row (?123, 🌐, 🔄, space, return) merges the iOS
`bottomActions` + Android-specific 🌐 next-keyboard.

The `useBreve` parameter to `greekAlphabetic()` swaps the top-row accent key
between `΄` (tonos) and `˘` (breve). The IME calls
`Layouts.greekAlphabetic(useBreve = previousLetterTakesBreve())` on every
keystroke (via `recomputeLayout()` inside `requestSuggestions`). The breve
appears when the previous letter is one of `σ ζ ξ ψ ς` — same trigger as iOS.

## Conventions specific to the Android port

### Greek strings in the codebase

UTF-8 throughout. Don't mass-rewrite Greek string literals — `commonWords` (in
`input/CommonWords.kt`) was extracted byte-for-byte from the iOS Swift set; if
you regenerate it, use the Python script in plan Task 13 to re-extract from
`Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift`.

### Combining marks

Some files contain literal combining marks (U+0301 tonos, U+0306 breve, U+0308
diaeresis). They render in editors as a "floating" accent over nothing. They
are real characters and load-bearing — don't "clean them up". The list:
- `input/AccentCombiner.kt` — `Combine("́")`, `Combine("̆")`, `Combine("̈")`,
  `Combine("̈́")`, `Combine("́")`
- `input/ActionHandler.kt` — `ACCENT_DEAD_KEYS` includes `" ̈"` (space +
  combining diaeresis)
- `layout/Layouts.kt` — popup-char strings for σ/ζ/ψ/ξ keys include `σ̆`, `ζ̆`,
  `ψ̆`, `ξ̌`

### Mirror with iOS

If you change Greek-language behavior on Android, check whether the iOS side
should change too:
- Greekify branches → `Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift`
- Final-sigma rule → `CypriotKeyboardActionHandler.swift handleS`
- Accent dispatch → `CypriotKeyboardActionHandler.swift triggerAccent`
- DAWG reader / fold / suggester → `Cypriot  Custom Keyboard/DAWG/*.swift`
- Layout rows → `CypriotKeyboardInputSetProvider.swift alphabeticInputSet()`

### `RequestsOpenAccess` posture

The iOS extension declines open access. Android's IME has equivalent permission
expectations: **no network, no clipboard scraping, no persistent
identifiers.** SharedPreferences is per-process and acceptable
(`isLatinKeyboard` is the only key we persist). Do not add network calls,
crash reporting, or analytics SDKs without coordinating a privacy-policy
update.

### `consumer-rules.pro`

`ime/consumer-rules.pro` is empty by design. The IME ships no
reflection-using code. If you ever add Kotlinx-serialization, Moshi, Gson,
Hilt, or anything else that needs `@Keep`, this is where consumer keep rules go.

## Files where the design is most easily broken

When making changes, be careful around:

1. **`CypriotInputMethodService.requestSuggestions`** — the debounce + race
   token + breve-recompute interleaving is fragile. The token check MUST stay
   inside the final `mainHandler.post`. The `pendingAutocomplete` Runnable must
   be cancelled (and cleared to null) on every entry.
2. **`ActionHandler.handleCharacter`** — the order is `ACCENT_DEAD_KEYS` first,
   then `PUNCT_TRIGGERS`, then commit. Reordering breaks accent-key dispatch
   (a typed `΄` would be left in the buffer instead of becoming a combining
   mark).
3. **`ActionHandler.handleSpaceLike`** — the `lastAction != Backspace` guard is
   load-bearing. It lets the user reject a willReplace suggestion by hitting
   backspace and then space.
4. **`DawgReader.from`** — magic check, version check, and the three indexing
   passes must all see a little-endian buffer. If you `ByteBuffer.wrap` without
   `.order(LITTLE_ENDIAN)`, every U16/U32 read silently produces garbage.

## Sandbox / CI

There is currently **no CI** for the Android build. The recommended local
verification before pushing is:

```bash
./gradlew :ime:test :app:assembleDebug
```

If you find yourself needing CI, GitHub Actions with `actions/setup-java@v4`
(Temurin 21) and `gradle/actions/setup-gradle@v3` is the standard recipe; the
SDK can be cached or installed via `android-actions/setup-android@v3`.

## Out of scope (deliberate)

These were considered and explicitly excluded from v1. If asked to add them,
read the spec section "Out of scope" first:

- Hunspell engine — DAWG-only is the path
- Long-press popups for secondary callouts — `KeySpec.popupChars` is populated
  but the UI isn't wired
- Gesture typing
- Theming engine, dark-mode polish beyond Material defaults
- Haptic / audio feedback
- iPad-specific layout (Android tablets use the phone layout)

Spec: `docs/superpowers/specs/2026-04-27-android-port-design.md`
Plan: `docs/superpowers/plans/2026-04-27-android-port.md`
