# Onboarding Redesign — Design Spec

**Date:** 2026-05-06
**Status:** Approved (decisions locked via brainstorming session)
**Scope:** The container app's first-launch experience (`Cypriot Keyboard/ContentView.swift` and supporting views). The keyboard extension is **not** touched.

---

## Goals

1. **Conversion** — reduce drop-off on the install steps. Current 6-step list intimidates and is partially redundant (steps 2–4 are skipped by the existing deep link).
2. **Delight** — make the first-launch screen feel like a polished iOS app rather than a wall of bullet points. Doubles as App Store screenshot material.
3. **Education / hook** — showcase Greeklish autocorrect (the app's strongest selling point) on the welcome screen, before the user has to commit to installing.

## Non-goals

- Changing the keyboard extension itself.
- Redesigning the App Store listing in this scope (separate followup).
- Adding analytics, opt-in flows, or tracking.
- Changing the app icon, app name, or bundle metadata.
- Producing a real `.mp4` / `.gif` hero asset (the demo loop is built in SwiftUI; a real asset can be recorded from it later for the App Store).

## Constraints

- iOS deployment target **14.4**. No iOS 15+ APIs (`presentationDetents`, etc.) without fallbacks.
- The keyboard extension has `RequestsOpenAccess = false`. No App Groups, no shared UserDefaults, no network from the extension. This redesign is in the container app only, so it is unconstrained on that axis, but it should not introduce new things that *require* open access.
- Universal (iPhone + iPad). iPhone is the primary target; iPad gets sensible padding, not a custom layout.
- Localized in `en` + `el` (`el` is in **Cypriot dialect** and stays so).
- Existing localized strings reference the `🔄` toggle, which was removed in commit `194bd52`. Those strings are stale and will be removed by this work.

---

## Architecture

### State machine

```
                     +---------------------------+
                     |    .notInstalled (Welcome)|
                     +-------------+-------------+
                                   |
                    user taps "Install in 3 taps"
                                   v
                     +---------------------------+
                     |  .notInstalled            |
                     |  + InstallSheet presented |
                     +-------------+-------------+
                                   |
              user taps "Open Settings" → Settings opens
                                   |
              user enables keyboard, returns to app
                                   |
                  app foreground → re-check AppleKeyboards
                                   v
                     +---------------------------+
                     |     .installed (Done)     |
                     +---------------------------+
```

State source: `UserDefaults.standard.dictionaryRepresentation()["AppleKeyboards"]` filtered by bundle identifier prefix — this is what the existing `isKeyboardExtensionEnabled()` already does.

State refresh: subscribe to `UIApplication.didBecomeActiveNotification` and recompute. Today's code only reads at init, so the user has to relaunch after enabling — fixing this is a clear win regardless of the rest of the redesign.

### View tree

```
ContentView
└── OnboardingShell                  (owns OnboardingState observable)
    ├── if .notInstalled:
    │   ├── WelcomeHeroView
    │   │   ├── BrandWordmark
    │   │   ├── DemoLoopView          (animated SwiftUI, loops Lefkosia → Λευκωσία)
    │   │   ├── PrimaryCTAButton      ("Install in 3 taps")
    │   │   └── CreditsFooter
    │   └── .sheet → InstallSheetView
    │       ├── 3 numbered steps
    │       ├── PrimaryCTAButton      ("Open Settings", deep link)
    │       └── DismissButton
    └── if .installed:
        └── PostInstallView           (vertically scrollable)
            ├── DoneHeader            ("🇨🇾 Έτοιμο!" — replaces full wordmark)
            ├── DemoLoopView          (same component, smaller)
            ├── TryItTextField
            ├── FeatureCard × 3       (Greeklish / breve / accents)
            └── SwitchHintBanner      ("Tap 🌐 in any app")
```

### Files

**Create:**
- `Cypriot Keyboard/Onboarding/OnboardingState.swift` — `enum InstallState { case notInstalled, installed }` + `ObservableObject` that recomputes on foreground.
- `Cypriot Keyboard/Onboarding/OnboardingShell.swift` — top-level switcher view, replaces what `ContentView` currently does.
- `Cypriot Keyboard/Onboarding/WelcomeHeroView.swift`
- `Cypriot Keyboard/Onboarding/InstallSheetView.swift`
- `Cypriot Keyboard/Onboarding/PostInstallView.swift`
- `Cypriot Keyboard/Onboarding/DemoLoopView.swift`
- `Cypriot Keyboard/Onboarding/Components/BrandWordmark.swift`
- `Cypriot Keyboard/Onboarding/Components/PrimaryCTAButton.swift`
- `Cypriot Keyboard/Onboarding/Components/FeatureCard.swift`
- `Cypriot Keyboard/Onboarding/Components/SwitchHintBanner.swift`
- `Cypriot Keyboard/Onboarding/BrandTheme.swift` — `Color.cypriotCopper` (`#D57800`), `Color.cypriotOlive` (`#6B7F3A`).
- `Cypriot KeyboardTests/OnboardingStateTests.swift`

**Modify:**
- `Cypriot Keyboard/ContentView.swift` — collapse to a thin shell that hosts `OnboardingShell`.
- `Cypriot Keyboard/en.lproj/Localizable.strings` — replace the old keys with the new copy below.
- `Cypriot Keyboard/el.lproj/Localizable.strings` — same, in Cypriot dialect.
- `Cypriot Keyboard.xcodeproj/project.pbxproj` — add new files to the **app target only** (not the extension).

**Delete:**
- (None — `ContentView.swift` stays, it just gets thinner.)

---

## Visual design

### Brand color tokens

| Token | Hex | Use |
|---|---|---|
| `cypriotCopper` | `#D57800` | Primary CTAs, links, brand wordmark accent, suggestion-pill background |
| `cypriotOlive` | `#6B7F3A` | Secondary CTAs, feature card numerals/icons, tag pills |
| (system white) | — | Background |
| (system label) | — | Body text |
| (system secondaryLabel) | — | Captions |

Both copper and olive defined as a SwiftUI `Color` extension in `BrandTheme.swift`. No light/dark variants for v1 — the app stays light-mode friendly with system labels handling text color in dark mode.

### Typography

- All text uses SF Pro (system font). No custom fonts in v1.
- Hierarchy: `largeTitle` for the wordmark, `title2` for hero tagline, `headline` for sheet title, `body` for steps, `subheadline` for feature card title, `caption` for footer / credits.
- The wordmark's "Cypriot" can use `.bold()` and the flag emoji 🇨🇾 inline; no custom display font.

### Demo loop (SwiftUI animation)

A self-contained `DemoLoopView` that cycles through this animation indefinitely:

1. Empty fake textfield, gray suggestion bar above it.
2. Letters appear one at a time: `L`, `Le`, `Lef`, `Lefk`, `Lefko`, `Lefkos`, `Lefkosi`, `Lefkosia` (40ms per letter so the typing feels real, not mechanical).
3. Suggestion bar populates: `[Lefkosia | Λευκωσία | …]` with `Λευκωσία` highlighted in copper.
4. After ~700ms pause, the textfield content swaps to `Λευκωσία ` (with trailing space), as if the user pressed space and triggered the auto-replace.
5. Pause ~1.5s, fade out, restart from step 1.

Implementation note: this is just `Text` views animated with `.animation` on offset/opacity, not a real keyboard. The fake suggestion bar mirrors the real one's look (gray buttons, copper highlight on the auto-replace candidate).

### Layout sketches

**Welcome hero (state: `.notInstalled`):**
```
+------------------------------+
|                              |
|      🇨🇾                     |  ← top padding 60
|   Κύπριακο                   |
|   Πληκτρολόγιο               |  ← largeTitle, bold
|                              |
|   Γράφε Ελληνικά εύκολα      |  ← title2, secondary
|                              |
|  +------------------------+  |
|  | DemoLoopView           |  |  ← height 220, white card with shadow
|  | [fake bar]             |  |
|  | [fake textfield]       |  |
|  +------------------------+  |
|                              |
|                              |
|  [ Install in 3 taps  →  ]   |  ← copper CTA, fills width with H padding 20
|                              |
|        Σπύρος Αρμοστής       |  ← caption, secondary
|        Aceras Anthropophorum |
|        Daniel Saidi          |
+------------------------------+
```

**Install sheet (presented from welcome):**
```
+------------------------------+
|             ━━━              |  ← grab handle (visual; iOS 14 sheet has no handle by default)
|                              |
|    Σε 3 βήματα               |  ← headline
|                              |
|    1   Ανοίει τες ρυθμίσεις  |  ← olive numeral, body text
|        για σένα              |
|                              |
|    2   Πάτα "Add New         |
|        Keyboard"             |
|                              |
|    3   Πάτα "Κυπριακά"       |
|                              |
|                              |
|  [ Άνοιξε Ρυθμίσεις  →  ]    |  ← copper CTA, deep link
|                              |
|         Ακύρωση              |  ← link-style dismiss
+------------------------------+
```

**Post-install (state: `.installed`):**
```
+------------------------------+
|                              |
|      🇨🇾                     |
|   Έτοιμο!                    |  ← largeTitle
|                              |
|  +------------------------+  |
|  | DemoLoopView (smaller) |  |  ← height 160
|  +------------------------+  |
|                              |
|  +------------------------+  |
|  | Δοκίμασε δαμαί         |  |  ← TextField, copper border
|  +------------------------+  |
|                              |
|  +------------------------+  |
|  | ✦  Greeklish → Greek   |  |  ← FeatureCard, olive icon
|  | Γράφε Lefkosia, παίρνεις|  |
|  | Λευκωσία               |  |
|  +------------------------+  |
|  +------------------------+  |
|  | σ̆  Κυπριακοί ήχοι       |  |
|  | σ̆ ζ̆ ξ̆ ψ̆ για ήχους που   |  |
|  | δεν έχει η κοινή        |  |
|  +------------------------+  |
|  +------------------------+  |
|  | ´  Τόνοι αυτόματα       |  |
|  | Κρατά τους τόνους τζαι  |  |
|  | το τελικό σ→ς           |  |
|  +------------------------+  |
|                              |
|  ───────────────────────     |
|  Σε άλλη εφαρμογή, πάτα 🌐  |  ← SwitchHintBanner
|  για να αλλάξεις             |
+------------------------------+
```

---

## Copy

All keys live in `Localizable.strings`. New keys use a `onboarding.` prefix to avoid collisions with old keys (which are removed).

### English (`en.lproj/Localizable.strings`)

```
"onboarding.brand.title" = "Cypriot Keyboard";
"onboarding.brand.tagline" = "Type Greek the easy way";

"onboarding.welcome.cta" = "Install in 3 taps  →";

"onboarding.install.title" = "In 3 steps";
"onboarding.install.step.1" = "We'll open Settings for you";
"onboarding.install.step.2" = "Tap \"Add New Keyboard\"";
"onboarding.install.step.3" = "Tap \"Κυπριακά\"";
"onboarding.install.cta" = "Open Settings  →";
"onboarding.install.dismiss" = "Cancel";

"onboarding.done.title" = "All set!";
"onboarding.done.tryit.placeholder" = "Try it here";

"onboarding.feature.greeklish.title" = "Greeklish → Greek";
"onboarding.feature.greeklish.body" = "Type \"Lefkosia\", get \"Λευκωσία\".";
"onboarding.feature.cypriot.title" = "Cypriot sounds";
"onboarding.feature.cypriot.body" = "σ̆ ζ̆ ξ̆ ψ̆ for sounds standard Greek doesn't have.";
"onboarding.feature.accents.title" = "Accents handled";
"onboarding.feature.accents.body" = "Accents and final-σ done automatically.";

"onboarding.switchhint" = "In any app, tap 🌐 to switch to Cypriot.";

"onboarding.credits" = "Spyros Armostis · Aceras Anthropophorum · Daniel Saidi";
"onboarding.author" = "By Alex Toumazis";
```

### Greek — Cypriot dialect (`el.lproj/Localizable.strings`)

Restraint: dialect on personality lines (taglines, "δαμαί", "τζαι"), neutral verbs on imperative steps so they read clearly.

```
"onboarding.brand.title" = "Κύπριακο Πληκτρολόγιο";
"onboarding.brand.tagline" = "Γράφε Ελληνικά εύκολα";

"onboarding.welcome.cta" = "Σε 3 βήματα  →";

"onboarding.install.title" = "Σε 3 βήματα";
"onboarding.install.step.1" = "Ανοίει τες Ρυθμίσεις για σένα";
"onboarding.install.step.2" = "Πάτα \"Add New Keyboard\"";
"onboarding.install.step.3" = "Πάτα \"Κυπριακά\"";
"onboarding.install.cta" = "Άνοιξε Ρυθμίσεις  →";
"onboarding.install.dismiss" = "Ακύρωση";

"onboarding.done.title" = "Έτοιμο!";
"onboarding.done.tryit.placeholder" = "Δοκίμασε δαμαί";

"onboarding.feature.greeklish.title" = "Greeklish → Ελληνικά";
"onboarding.feature.greeklish.body" = "Γράφε \"Lefkosia\", παίρνεις \"Λευκωσία\".";
"onboarding.feature.cypriot.title" = "Κυπριακοί ήχοι";
"onboarding.feature.cypriot.body" = "σ̆ ζ̆ ξ̆ ψ̆ για ήχους που δεν έχει η κοινή.";
"onboarding.feature.accents.title" = "Τόνοι αυτόματα";
"onboarding.feature.accents.body" = "Τόνοι τζαι το τελικό σ→ς γίνουνται μόνα τους.";

"onboarding.switchhint" = "Σε άλλη εφαρμογή, πάτα 🌐 για να αλλάξεις πληκτρολόγιο.";

"onboarding.credits" = "Σπύρος Αρμοστής · Aceras Anthropophorum · Daniel Saidi";
"onboarding.author" = "Αλέξανδρος Τουμαζής";
```

### Old strings to delete

From both `.strings` files: `"Installation"`, `"Use"`, `"1. Open 'Settings'"` through `"6. Tap 'Κυπριακά'"`, `"Click 🌐 to switch keyboard..."`, `"Click 🔄 to switch between..."`, `"The bar above the keyboard..."`, `"Test Here"`, `"Alex"`, `"Credits"`. Removed because the toggle no longer exists and the new copy uses fresh keys.

---

## Behavior details

### Foreground refresh

`OnboardingState` registers for `UIApplication.didBecomeActiveNotification` in `init` and unregisters in `deinit`. On notification it recomputes the install check and updates `@Published var state`. SwiftUI re-renders the shell. The transition from `.notInstalled` to `.installed` should fade — `withAnimation(.easeInOut(duration: 0.3))` around the state assignment.

For testability, `OnboardingState.init` accepts an injected `keyboardCheck: () -> Bool` closure (defaulting to the production `isKeyboardExtensionEnabled()` function). Tests inject a stub closure and verify the state observer reacts correctly — they do not poke `UserDefaults.standard`.

### Sheet dismissal

iOS 14 sheets dismiss via swipe-down or programmatic `isPresented = false`. The "Cancel" button just sets the binding to false. The "Open Settings" CTA opens the deep link and **does not dismiss the sheet** — the sheet stays so that when the user comes back, they see the same install context, and the foreground-refresh promotes the whole shell to the post-install state (which replaces the sheet's content anyway).

### Try-it textfield

Standard SwiftUI `TextField`. No custom autocorrect logic in this view — the system keyboard is the user's choice. If they have Cypriot active they'll see real autocomplete; if they're using the default keyboard they won't. This is honest behavior, not a fake.

### Demo loop animation timing

| Phase | Duration |
|---|---|
| Type each character (8 chars) | 40ms each = 320ms |
| Suggestion bar populates | 100ms ease-in |
| Pause showing suggestions | 700ms |
| Replacement (text swaps) | 200ms ease-in-out |
| Hold replaced state | 1500ms |
| Fade out + reset | 400ms |
| **Total cycle** | **~3.2 seconds** |

The loop runs unconditionally while the view is on screen (`onAppear` starts a `Timer.publish`, `onDisappear` cancels). No interaction; if the user wants to interact they use the real textfield below.

---

## Testing

Tests focus on `OnboardingState` (the only piece with non-trivial logic):

- `testInitialStateReflectsCurrentInstall` — when `AppleKeyboards` includes our bundle prefix at init, state is `.installed`; otherwise `.notInstalled`.
- `testForegroundNotificationTriggersRecompute` — post a fake `didBecomeActiveNotification` and verify the published state updates.
- `testInstallStateChangeAnimates` — verify `objectWillChange` fires on transition.

View code (animations, layout) is not unit-tested. Manual QA in simulator:

- Fresh install (keyboard not yet enabled) → welcome screen, demo loops, sheet opens, deep link opens Settings.
- Enable keyboard in Settings → return to app → welcome fades to "All set" automatically.
- Try-it field accepts text in active keyboard.
- Both `en` and `el` locales render correctly (no truncation, no missing keys).
- Welcome screen fits without scrolling on iPhone SE (568pt) and looks balanced on Pro Max.
- Post-install screen scrolls naturally — content is meant to be more than a single screen.
- iPad: both screens center in a max-width column (~480pt), don't stretch absurdly wide.

---

## Out of scope (followups)

- Recording the SwiftUI demo loop to `.mp4` for the App Store preview.
- Refreshed App Store screenshots derived from the new screens.
- Settings deep-link fallback if `App-prefs:` is broken on a future iOS version.
- Dark mode polish (the design works in dark mode via system colors, but copper-on-dark hasn't been tuned).
- Onboarding telemetry / analytics.
