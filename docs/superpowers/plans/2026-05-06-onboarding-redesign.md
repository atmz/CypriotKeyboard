# Onboarding Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current 6-step bullet-list `ContentView` with a hero+install-sheet onboarding flow (animated SwiftUI demo, copper/olive brand, Cypriot dialect copy, foreground-refresh state machine, post-install try-it field with 3 feature cards).

**Architecture:** Container app only — keyboard extension is untouched. New `Onboarding/` folder under `Cypriot Keyboard/` with a small `OnboardingState` model + a stack of focused SwiftUI views. State derives from `AppleKeyboards` in `UserDefaults.standard`, refreshed on `UIApplication.didBecomeActiveNotification`.

**Tech Stack:** SwiftUI on iOS 14.4+, no new dependencies, no extension changes.

**Branch:** `onboarding-redesign` (worktree at `.worktrees/onboarding-redesign/`).

**Spec:** `docs/superpowers/specs/2026-05-06-onboarding-redesign-design.md`

---

### Task 0: Worktree setup

**Files:**
- N/A (workspace setup)

- [ ] **Step 1: Create worktree on new branch**

```bash
git worktree add .worktrees/onboarding-redesign -b onboarding-redesign
cd .worktrees/onboarding-redesign
```

- [ ] **Step 2: Verify clean baseline build**

```bash
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -sdk iphonesimulator -configuration Debug build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Verify clean test baseline**

```bash
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' test
```

Expected: All tests pass (108 tests at time of writing per recent baseline).

---

### Task 1: BrandTheme — color tokens

**Files:**
- Create: `Cypriot Keyboard/Onboarding/BrandTheme.swift`

- [ ] **Step 1: Write file**

```swift
import SwiftUI

extension Color {
    static let cypriotCopper = Color(red: 0xD5/255.0, green: 0x78/255.0, blue: 0x00/255.0)
    static let cypriotOlive  = Color(red: 0x6B/255.0, green: 0x7F/255.0, blue: 0x3A/255.0)
}
```

- [ ] **Step 2: Add file to Xcode project (app target only)**

Use the helper script in Step 3 (`add-onboarding-files.sh`) which is created in Task 2 — for this task, the file is added but unreferenced; build won't break because nothing imports it yet.

- [ ] **Step 3: Commit**

```bash
git add "Cypriot Keyboard/Onboarding/BrandTheme.swift"
git commit -m "onboarding: brand color tokens (copper, olive)"
```

---

### Task 2: pbxproj helper + register all onboarding files

**Files:**
- Create: `scripts/add-onboarding-files.sh`

The pbxproj is fragile and hand-editing is error-prone. We script the additions once, then run it after each new file lands. All new files go into the **`Cypriot Keyboard`** PBXGroup and the app target's Sources build phase **only** (NOT the extension target).

- [ ] **Step 1: Write the helper script**

```bash
#!/usr/bin/env bash
# scripts/add-onboarding-files.sh
# Idempotently registers Cypriot Keyboard/Onboarding/**/*.swift in the app target.
# Uses xcodeproj-cli via Python (ruamel.yaml not available; use plistbuddy/sed approach
# or invoke `xcodebuild` with manual file list updates).

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$ROOT/Cypriot Keyboard.xcodeproj/project.pbxproj"

# Strategy: use Ruby + xcodeproj gem if available, else fall back to manual sed.
if command -v ruby >/dev/null 2>&1 && ruby -e "require 'xcodeproj'" 2>/dev/null; then
    ruby -e '
        require "xcodeproj"
        project_path = ENV["PBXPROJ_DIR"]
        project = Xcodeproj::Project.open(project_path)
        app_target = project.targets.find { |t| t.name == "Cypriot Keyboard" }
        abort "App target not found" if app_target.nil?
        main_group = project.main_group["Cypriot Keyboard"]
        onb_group = main_group["Onboarding"] || main_group.new_group("Onboarding", "Onboarding")
        Dir.glob(File.join(ENV["ONB_DIR"], "**/*.swift")).sort.each do |path|
            rel = path.sub(ENV["ONB_DIR"] + "/", "")
            next if onb_group.recursive_children.any? { |c| c.path == rel }
            ref = onb_group.new_file(path)
            app_target.add_file_references([ref])
            puts "added #{rel}"
        end
        project.save
    ' || echo "ruby+xcodeproj path failed; please add files manually in Xcode"
else
    echo "ruby+xcodeproj not available; please add files manually in Xcode" >&2
    echo "Files to add to the app target ('Cypriot Keyboard'):" >&2
    find "$ROOT/Cypriot Keyboard/Onboarding" -name "*.swift" >&2
    exit 1
fi
```

Set environment vars when invoking:

```bash
PBXPROJ_DIR="$ROOT/Cypriot Keyboard.xcodeproj" \
ONB_DIR="$ROOT/Cypriot Keyboard/Onboarding" \
bash scripts/add-onboarding-files.sh
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/add-onboarding-files.sh
```

- [ ] **Step 3: Test the gem availability**

```bash
ruby -e 'require "xcodeproj"; puts "ok"' 2>&1
```

If "ok": proceed. If error like "cannot load such file": run `gem install xcodeproj --user-install` then retry. If still failing, fall back to **manual `pbxproj` edits using sed/text patches as a separate sub-task**, but try the gem first.

- [ ] **Step 4: Run script to register `BrandTheme.swift`**

```bash
PBXPROJ_DIR="Cypriot Keyboard.xcodeproj" \
ONB_DIR="Cypriot Keyboard/Onboarding" \
bash scripts/add-onboarding-files.sh
```

Expected: `added BrandTheme.swift`

- [ ] **Step 5: Verify build still succeeds**

```bash
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -sdk iphonesimulator -configuration Debug build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add scripts/add-onboarding-files.sh "Cypriot Keyboard.xcodeproj/project.pbxproj"
git commit -m "onboarding: add pbxproj helper + register BrandTheme"
```

---

### Task 3: OnboardingState — model + tests

**Files:**
- Create: `Cypriot Keyboard/Onboarding/OnboardingState.swift`
- Create: `Cypriot KeyboardTests/OnboardingStateTests.swift`

- [ ] **Step 1: Write failing tests first**

```swift
// Cypriot KeyboardTests/OnboardingStateTests.swift
import XCTest
import Combine
@testable import Cypriot_Keyboard

final class OnboardingStateTests: XCTestCase {
    func testInitialStateReflectsCheckClosure_installed() {
        let s = OnboardingState(keyboardCheck: { true })
        XCTAssertEqual(s.installState, .installed)
    }

    func testInitialStateReflectsCheckClosure_notInstalled() {
        let s = OnboardingState(keyboardCheck: { false })
        XCTAssertEqual(s.installState, .notInstalled)
    }

    func testRefreshUpdatesStateWhenClosureFlips() {
        var current = false
        let s = OnboardingState(keyboardCheck: { current })
        XCTAssertEqual(s.installState, .notInstalled)
        current = true
        s.refresh()
        XCTAssertEqual(s.installState, .installed)
    }

    func testForegroundNotificationTriggersRefresh() {
        var current = false
        let s = OnboardingState(keyboardCheck: { current })
        XCTAssertEqual(s.installState, .notInstalled)
        current = true
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(s.installState, .installed)
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"Cypriot KeyboardTests/OnboardingStateTests" test 2>&1 | tail -20
```

Expected: BUILD FAILED — `OnboardingState` does not exist.

- [ ] **Step 3: Implement OnboardingState**

```swift
// Cypriot Keyboard/Onboarding/OnboardingState.swift
import SwiftUI
import Combine
import UIKit

enum InstallState {
    case notInstalled
    case installed
}

final class OnboardingState: ObservableObject {
    @Published private(set) var installState: InstallState

    private let keyboardCheck: () -> Bool

    init(keyboardCheck: @escaping () -> Bool = { isKeyboardExtensionEnabled() }) {
        self.keyboardCheck = keyboardCheck
        self.installState = keyboardCheck() ? .installed : .notInstalled

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleDidBecomeActive() {
        refresh()
    }

    func refresh() {
        let next: InstallState = keyboardCheck() ? .installed : .notInstalled
        guard next != installState else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            installState = next
        }
    }
}
```

- [ ] **Step 4: Add file to Xcode app target**

```bash
PBXPROJ_DIR="Cypriot Keyboard.xcodeproj" \
ONB_DIR="Cypriot Keyboard/Onboarding" \
bash scripts/add-onboarding-files.sh
```

Then add the test file to the test target — add it manually if `add-onboarding-files.sh` doesn't handle the test target; or extend the script with a test-target branch. Initial implementation: add manually via a quick `ruby -e` inline:

```bash
ruby -e '
    require "xcodeproj"
    project = Xcodeproj::Project.open("Cypriot Keyboard.xcodeproj")
    test_target = project.targets.find { |t| t.name == "Cypriot KeyboardTests" }
    group = project.main_group["Cypriot KeyboardTests"]
    path = "Cypriot KeyboardTests/OnboardingStateTests.swift"
    next if group.recursive_children.any? { |c| c.path == "OnboardingStateTests.swift" }
    ref = group.new_file(path)
    test_target.add_file_references([ref])
    project.save
'
```

- [ ] **Step 5: Run tests, verify pass**

```bash
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"Cypriot KeyboardTests/OnboardingStateTests" test 2>&1 | tail -20
```

Expected: 4 tests pass.

- [ ] **Step 6: Commit**

```bash
git add "Cypriot Keyboard/Onboarding/OnboardingState.swift" \
        "Cypriot KeyboardTests/OnboardingStateTests.swift" \
        "Cypriot Keyboard.xcodeproj/project.pbxproj"
git commit -m "onboarding: OnboardingState with foreground refresh + tests"
```

---

### Task 4: Brand wordmark + DemoLoopView

**Files:**
- Create: `Cypriot Keyboard/Onboarding/Components/BrandWordmark.swift`
- Create: `Cypriot Keyboard/Onboarding/DemoLoopView.swift`

- [ ] **Step 1: Write BrandWordmark.swift**

```swift
import SwiftUI

struct BrandWordmark: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("🇨🇾")
                .font(.system(size: 48))
            Text(NSLocalizedString("onboarding.brand.title", comment: "App brand"))
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text(NSLocalizedString("onboarding.brand.tagline", comment: "App tagline"))
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
```

- [ ] **Step 2: Write DemoLoopView.swift**

```swift
import SwiftUI

struct DemoLoopView: View {
    enum Size { case large, small }
    let size: Size

    @State private var typed: String = ""
    @State private var showSuggestions: Bool = false
    @State private var replaced: Bool = false

    private let target = "Lefkosia"
    private let replacement = "Λευκωσία "

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(typed.isEmpty ? "" : typed)
                    .opacity(showSuggestions ? 0.4 : 1)
                Spacer()
                Text(replacement.trimmingCharacters(in: .whitespaces))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.cypriotCopper)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .opacity(showSuggestions ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color(.systemGray6))

            HStack {
                Text(replaced ? replacement : typed)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: barFieldHeight)
            .background(Color.white)
        }
        .frame(maxWidth: 320, maxHeight: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .onAppear { startLoop() }
    }

    private var cardHeight: CGFloat { size == .large ? 220 : 160 }
    private var barFieldHeight: CGFloat { size == .large ? 180 : 120 }

    private func startLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                typed = ""
                showSuggestions = false
                replaced = false
                for i in 1...target.count {
                    try? await Task.sleep(nanoseconds: 40_000_000)
                    typed = String(target.prefix(i))
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation(.easeIn(duration: 0.2)) { showSuggestions = true }
                try? await Task.sleep(nanoseconds: 700_000_000)
                withAnimation(.easeInOut(duration: 0.2)) { replaced = true }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                withAnimation(.easeOut(duration: 0.4)) {
                    showSuggestions = false
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }
}
```

NB: `Task` and `async/await` require Swift 5.5 + iOS 13+ at runtime. iOS 14.4 + Xcode 13+ is fine — but if the build target's Swift toolchain rejects it, fall back to `DispatchQueue.main.asyncAfter` chains.

- [ ] **Step 3: Register both files**

```bash
PBXPROJ_DIR="Cypriot Keyboard.xcodeproj" \
ONB_DIR="Cypriot Keyboard/Onboarding" \
bash scripts/add-onboarding-files.sh
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -sdk iphonesimulator -configuration Debug build 2>&1 | tail -10
```

If `Task`/`async` errors: rewrite `startLoop()` using `DispatchQueue.main.asyncAfter` chained closures (helper file `loopAsync.swift`).

- [ ] **Step 5: Commit**

```bash
git add "Cypriot Keyboard/Onboarding/" "Cypriot Keyboard.xcodeproj/project.pbxproj"
git commit -m "onboarding: BrandWordmark + DemoLoopView animated demo"
```

---

### Task 5: PrimaryCTAButton + FeatureCard + SwitchHintBanner

**Files:**
- Create: `Cypriot Keyboard/Onboarding/Components/PrimaryCTAButton.swift`
- Create: `Cypriot Keyboard/Onboarding/Components/FeatureCard.swift`
- Create: `Cypriot Keyboard/Onboarding/Components/SwitchHintBanner.swift`

- [ ] **Step 1: PrimaryCTAButton.swift**

```swift
import SwiftUI

struct PrimaryCTAButton: View {
    let titleKey: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(NSLocalizedString(titleKey, comment: "Primary CTA"))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.cypriotCopper)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: FeatureCard.swift**

```swift
import SwiftUI

struct FeatureCard: View {
    let glyph: String      // e.g. "✦", "σ̆", "´"
    let titleKey: String
    let bodyKey: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(glyph)
                .font(.title2.weight(.semibold))
                .foregroundColor(.cypriotOlive)
                .frame(width: 32, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString(titleKey, comment: "Feature card title"))
                    .font(.headline)
                Text(NSLocalizedString(bodyKey, comment: "Feature card body"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
```

- [ ] **Step 3: SwitchHintBanner.swift**

```swift
import SwiftUI

struct SwitchHintBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text(NSLocalizedString("onboarding.switchhint", comment: "How to use after install"))
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
        }
    }
}
```

- [ ] **Step 4: Register, build, commit**

```bash
PBXPROJ_DIR="Cypriot Keyboard.xcodeproj" \
ONB_DIR="Cypriot Keyboard/Onboarding" \
bash scripts/add-onboarding-files.sh

xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5

git add "Cypriot Keyboard/Onboarding/Components/" "Cypriot Keyboard.xcodeproj/project.pbxproj"
git commit -m "onboarding: PrimaryCTAButton, FeatureCard, SwitchHintBanner"
```

---

### Task 6: WelcomeHeroView + InstallSheetView

**Files:**
- Create: `Cypriot Keyboard/Onboarding/WelcomeHeroView.swift`
- Create: `Cypriot Keyboard/Onboarding/InstallSheetView.swift`

- [ ] **Step 1: InstallSheetView.swift**

```swift
import SwiftUI
import UIKit

struct InstallSheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // visual grab handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            Text(NSLocalizedString("onboarding.install.title", comment: "Install sheet title"))
                .font(.title2.weight(.semibold))
                .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 18) {
                stepRow(number: "1", textKey: "onboarding.install.step.1")
                stepRow(number: "2", textKey: "onboarding.install.step.2")
                stepRow(number: "3", textKey: "onboarding.install.step.3")
            }
            .padding(.horizontal, 24)

            Spacer()

            PrimaryCTAButton(titleKey: "onboarding.install.cta") {
                if let url = URL(string: "App-prefs:root=General&path=Keyboard/KEYBOARDS") {
                    UIApplication.shared.open(url)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            Button(action: { isPresented = false }) {
                Text(NSLocalizedString("onboarding.install.dismiss", comment: "Dismiss sheet"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 24)
        }
    }

    private func stepRow(number: String, textKey: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.title3.weight(.bold))
                .foregroundColor(.cypriotOlive)
                .frame(width: 24, alignment: .center)
            Text(NSLocalizedString(textKey, comment: "Install step"))
                .font(.body)
                .multilineTextAlignment(.leading)
            Spacer()
        }
    }
}
```

- [ ] **Step 2: WelcomeHeroView.swift**

```swift
import SwiftUI

struct WelcomeHeroView: View {
    @State private var showSheet = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)
            BrandWordmark()
            DemoLoopView(size: .large)
            Spacer()
            PrimaryCTAButton(titleKey: "onboarding.welcome.cta") {
                showSheet = true
            }
            .padding(.horizontal, 20)
            VStack(spacing: 4) {
                Text(NSLocalizedString("onboarding.author", comment: "Author"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(NSLocalizedString("onboarding.credits", comment: "Credits"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showSheet) {
            InstallSheetView(isPresented: $showSheet)
        }
    }
}
```

- [ ] **Step 3: Register, build, commit**

```bash
PBXPROJ_DIR="Cypriot Keyboard.xcodeproj" \
ONB_DIR="Cypriot Keyboard/Onboarding" \
bash scripts/add-onboarding-files.sh

xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5

git add "Cypriot Keyboard/Onboarding/" "Cypriot Keyboard.xcodeproj/project.pbxproj"
git commit -m "onboarding: WelcomeHeroView + InstallSheetView"
```

---

### Task 7: PostInstallView

**Files:**
- Create: `Cypriot Keyboard/Onboarding/PostInstallView.swift`

- [ ] **Step 1: Write file**

```swift
import SwiftUI

struct PostInstallView: View {
    @State private var sample = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("🇨🇾").font(.system(size: 40))
                    Text(NSLocalizedString("onboarding.done.title", comment: "Installed title"))
                        .font(.largeTitle.weight(.bold))
                }
                .padding(.top, 24)

                DemoLoopView(size: .small)

                TextField(
                    NSLocalizedString("onboarding.done.tryit.placeholder", comment: "Try it field"),
                    text: $sample
                )
                .textFieldStyle(.roundedBorder)

                VStack(spacing: 12) {
                    FeatureCard(
                        glyph: "✦",
                        titleKey: "onboarding.feature.greeklish.title",
                        bodyKey: "onboarding.feature.greeklish.body"
                    )
                    FeatureCard(
                        glyph: "σ̆",
                        titleKey: "onboarding.feature.cypriot.title",
                        bodyKey: "onboarding.feature.cypriot.body"
                    )
                    FeatureCard(
                        glyph: "´",
                        titleKey: "onboarding.feature.accents.title",
                        bodyKey: "onboarding.feature.accents.body"
                    )
                }

                SwitchHintBanner()

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
    }
}
```

- [ ] **Step 2: Register, build, commit**

```bash
PBXPROJ_DIR="Cypriot Keyboard.xcodeproj" \
ONB_DIR="Cypriot Keyboard/Onboarding" \
bash scripts/add-onboarding-files.sh

xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5

git add "Cypriot Keyboard/Onboarding/" "Cypriot Keyboard.xcodeproj/project.pbxproj"
git commit -m "onboarding: PostInstallView with try-it field + 3 cards"
```

---

### Task 8: OnboardingShell + ContentView wiring

**Files:**
- Create: `Cypriot Keyboard/Onboarding/OnboardingShell.swift`
- Modify: `Cypriot Keyboard/ContentView.swift`

- [ ] **Step 1: OnboardingShell.swift**

```swift
import SwiftUI

struct OnboardingShell: View {
    @StateObject private var state = OnboardingState()

    var body: some View {
        Group {
            switch state.installState {
            case .notInstalled:
                WelcomeHeroView()
            case .installed:
                PostInstallView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state.installState)
    }
}
```

NB: `@StateObject` is iOS 14+, fits the 14.4 deployment target.

- [ ] **Step 2: Replace ContentView body**

```swift
// Cypriot Keyboard/ContentView.swift
import SwiftUI

func isKeyboardExtensionEnabled() -> Bool {
    guard let appBundleIdentifier = Bundle.main.bundleIdentifier else {
        return false
    }
    guard let keyboards = UserDefaults.standard.dictionaryRepresentation()["AppleKeyboards"] as? [String] else {
        return false
    }
    let prefix = appBundleIdentifier + "."
    return keyboards.contains { $0.hasPrefix(prefix) }
}

struct ContentView: View {
    var body: some View {
        OnboardingShell()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
```

NB: We **kept** `isKeyboardExtensionEnabled()` as a free function so `OnboardingState`'s default closure can call it. Removed: `fatalError` on missing bundle id (returns false instead — defensive default), the long debug comment block, the unused `textTyped`/`showInstall` state.

- [ ] **Step 3: Register OnboardingShell, build, run tests**

```bash
PBXPROJ_DIR="Cypriot Keyboard.xcodeproj" \
ONB_DIR="Cypriot Keyboard/Onboarding" \
bash scripts/add-onboarding-files.sh

xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -sdk iphonesimulator -configuration Debug build 2>&1 | tail -10

xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' test 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add "Cypriot Keyboard/Onboarding/OnboardingShell.swift" \
        "Cypriot Keyboard/ContentView.swift" \
        "Cypriot Keyboard.xcodeproj/project.pbxproj"
git commit -m "onboarding: OnboardingShell + collapse ContentView"
```

---

### Task 9: Localized strings refresh

**Files:**
- Modify: `Cypriot Keyboard/en.lproj/Localizable.strings`
- Modify: `Cypriot Keyboard/el.lproj/Localizable.strings`

- [ ] **Step 1: Replace en.lproj contents**

Replace the entire body (everything after the auto-generated comment header) with the en strings from the spec under "English (`en.lproj/Localizable.strings`)". Delete the old keys.

- [ ] **Step 2: Replace el.lproj contents**

Same as above for the el (Cypriot dialect) strings under "Greek — Cypriot dialect (`el.lproj/Localizable.strings`)".

- [ ] **Step 3: Build to verify no missing keys at runtime**

```bash
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add "Cypriot Keyboard/en.lproj/Localizable.strings" \
        "Cypriot Keyboard/el.lproj/Localizable.strings"
git commit -m "onboarding: refresh localized strings (en + Cypriot el)"
```

---

### Task 10: Final smoke + push

- [ ] **Step 1: Full test run**

```bash
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' test 2>&1 | tail -30
```

Expected: all tests pass (108 baseline + 4 new = 112).

- [ ] **Step 2: Build extension target separately to confirm no accidental coupling**

```bash
xcodebuild -project "Cypriot Keyboard.xcodeproj" \
  -scheme "Cypriot  Custom Keyboard" -sdk iphonesimulator build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Verify launch in simulator (manual / scripted)**

```bash
xcrun simctl boot "iPhone 15" 2>/dev/null || true
xcodebuild -project "Cypriot Keyboard.xcodeproj" -scheme "Cypriot Keyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' install 2>&1 | tail -5
xcrun simctl launch booted org.alextoumazis.Cypriot-Keyboard 2>&1 || \
  echo "manual launch needed — bundle id may differ; check Info.plist"
```

If launch succeeds and the welcome hero appears with a looping demo, manual smoke is done.

- [ ] **Step 4: Push branch**

```bash
git push -u origin onboarding-redesign
```

---

## Risk register

- **pbxproj scripting may fail.** If `gem install xcodeproj` is unavailable, fall back to opening Xcode and dragging files into the navigator (manual). Mitigation: each task commits incrementally, so a manual pbxproj patch is recoverable.
- **`async/await` in `DemoLoopView` may need a fallback** if the project's Swift toolchain rejects it. Mitigation: rewrite using `DispatchQueue.main.asyncAfter`.
- **`App-prefs:` deep link could be broken on a future iOS version.** Out of scope for this work; the existing app already relies on it.
- **Cypriot dialect copy may need a native-speaker pass.** I've drafted plausible dialect strings; the spec marks them for owner review at the end.
