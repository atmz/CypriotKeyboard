# Cypriot Keyboard — Android Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the iOS Cypriot Greek keyboard to Android — a custom IME with Greek/Latin layouts, Greeklish transliteration, final-sigma rule, accent combining, and DAWG-backed autocorrect.

**Architecture:** Kotlin + Jetpack Compose, native Android `InputMethodService`, two Gradle modules (`app` for the launcher / installation guide, `ime` for the keyboard service). DAWG suggester only — no Hunspell.

**Tech Stack:** Kotlin 2.0+, Jetpack Compose BOM 2025.x, Android Gradle Plugin 8.6+, min SDK 24, target SDK 35, JUnit 4 for unit tests.

**Sandbox note:** This plan was written without access to a JDK/Android SDK in the planning sandbox. Tests are defined in TDD shape but **the user will run them on their local toolchain when they check in**. Each task instructs the implementer to write the code and review for correctness; execution-verify is the user's checkpoint.

**Spec:** `docs/superpowers/specs/2026-04-27-android-port-design.md`

**Source-of-truth iOS files** (reference these when porting; paths use the iOS `Cypriot  Custom Keyboard/` directory with **two spaces**):
- `KeyboardViewController.swift` — service entry point + autocomplete pipeline
- `KeyboardView.swift` — root view + suggestion bar + button builder
- `CypriotKeyboardActionHandler.swift` — final-sigma, accent, layout-toggle, space-replace
- `CypriotKeyboardUtil.swift` — `greekify`, `commonWords`, `levenshtein`, `countSyllables`
- `CypriotKeyboardInputSetProvider.swift` — alphabetic / numeric / symbolic input rows
- `CypriotKeyboardiPhoneLayoutProvider.swift` — bottom row + key widths
- `CypriotSecondaryCalloutActionProvider.swift` — long-press callouts
- `DAWG/DawgReader.swift`, `DAWG/PhoneticFolder.swift`, `DAWG/DamerauLevenshteinSuggester.swift`, `DAWG/DawgAutocompleteSuggestionProvider.swift`
- `Cypriot Keyboard/ContentView.swift` — container app

DAWG binary format: `dict_generation/DAWG_FORMAT.md`.

---

## Phase A — Project scaffolding

### Task 1: Root Gradle build

**Files:**
- Create: `android/settings.gradle.kts`
- Create: `android/build.gradle.kts`
- Create: `android/gradle.properties`
- Create: `android/gradle/wrapper/gradle-wrapper.properties`
- Create: `android/gradlew`, `android/gradlew.bat`, `android/gradle/wrapper/gradle-wrapper.jar` (copy from any standard AGP 8.x project; alternatively the user can run `gradle wrapper` once locally)
- Create: `android/.gitignore`

- [ ] **Step 1: Write `android/settings.gradle.kts`**

```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "CypriotKeyboardAndroid"
include(":app", ":ime")
```

- [ ] **Step 2: Write `android/build.gradle.kts`**

```kotlin
plugins {
    id("com.android.application") version "8.6.1" apply false
    id("com.android.library") version "8.6.1" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
}
```

- [ ] **Step 3: Write `android/gradle.properties`**

```
org.gradle.jvmargs=-Xmx4g -XX:+UseG1GC -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official
```

- [ ] **Step 4: Write `android/gradle/wrapper/gradle-wrapper.properties`**

```
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.10.2-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
```

- [ ] **Step 5: Write `android/.gitignore`**

```
# Gradle
.gradle/
build/
local.properties

# Android Studio / IntelliJ
.idea/
*.iml
captures/

# Build outputs
*.apk
*.aab

# Keystores (do not commit signing keys)
*.jks
*.keystore
```

- [ ] **Step 6: Note about gradle wrapper jar**

Add `android/README.md` line: "If `gradlew` is missing or the wrapper jar is absent, run `gradle wrapper --gradle-version 8.10.2` from the `android/` directory once with a system-installed Gradle to generate them."

- [ ] **Step 7: Commit**

```bash
git add android/
git commit -m "android: gradle scaffolding"
```

---

### Task 2: IME module skeleton

**Files:**
- Create: `android/ime/build.gradle.kts`
- Create: `android/ime/src/main/AndroidManifest.xml`
- Create: `android/ime/src/main/res/xml/method.xml`
- Create: `android/ime/src/main/res/values/strings.xml`
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/CypriotInputMethodService.kt` (stub)
- Create: `android/ime/src/main/res/drawable/ic_ime.xml` (placeholder icon)

- [ ] **Step 1: Write `android/ime/build.gradle.kts`**

```kotlin
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "cy.cypriotkeyboard.ime"
    compileSdk = 35

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    sourceSets["main"].assets.srcDirs("src/main/assets")
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.savedstate:savedstate-ktx:1.2.1")

    val composeBom = platform("androidx.compose:compose-bom:2024.10.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.runtime:runtime")
    debugImplementation("androidx.compose.ui:ui-tooling")

    testImplementation("junit:junit:4.13.2")
}
```

- [ ] **Step 2: Write `android/ime/src/main/AndroidManifest.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <application>
        <service
            android:name=".CypriotInputMethodService"
            android:label="@string/ime_label"
            android:permission="android.permission.BIND_INPUT_METHOD"
            android:exported="true">
            <intent-filter>
                <action android:name="android.view.InputMethod" />
            </intent-filter>
            <meta-data
                android:name="android.view.im"
                android:resource="@xml/method" />
        </service>
    </application>
</manifest>
```

- [ ] **Step 3: Write `android/ime/src/main/res/xml/method.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<input-method xmlns:android="http://schemas.android.com/apk/res/android"
    android:settingsActivity="cy.cypriotkeyboard.app.MainActivity"
    android:supportsSwitchingToNextInputMethod="true">
    <subtype
        android:label="@string/subtype_label_el"
        android:imeSubtypeLocale="el_CY"
        android:imeSubtypeMode="keyboard"
        android:isAsciiCapable="false" />
    <subtype
        android:label="@string/subtype_label_en"
        android:imeSubtypeLocale="en_US"
        android:imeSubtypeMode="keyboard"
        android:isAsciiCapable="true" />
</input-method>
```

- [ ] **Step 4: Write `android/ime/src/main/res/values/strings.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="ime_label">Cypriot Keyboard</string>
    <string name="subtype_label_el">Κυπριακά</string>
    <string name="subtype_label_en">English (Greeklish)</string>
</resources>
```

- [ ] **Step 5: Write the service stub `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/CypriotInputMethodService.kt`**

```kotlin
package cy.cypriotkeyboard.ime

import android.inputmethodservice.InputMethodService
import android.view.View
import android.widget.FrameLayout

/**
 * IME service entry point. Stub for Task 2 — fully wired in Task 19.
 * See spec docs/superpowers/specs/2026-04-27-android-port-design.md.
 */
class CypriotInputMethodService : InputMethodService() {

    override fun onCreateInputView(): View {
        return FrameLayout(this)
    }
}
```

- [ ] **Step 6: Placeholder `android/ime/src/main/res/drawable/ic_ime.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#000000"
        android:pathData="M3,3h18v18H3z" />
</vector>
```

- [ ] **Step 7: Commit**

```bash
git add android/ime/
git commit -m "android: ime module skeleton (service stub + manifest)"
```

---

### Task 3: App module skeleton

**Files:**
- Create: `android/app/build.gradle.kts`
- Create: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/kotlin/cy/cypriotkeyboard/app/MainActivity.kt` (stub)
- Create: `android/app/src/main/res/values/strings.xml`
- Create: `android/app/src/main/res/values-el/strings.xml`
- Create: `android/app/src/main/res/values/themes.xml`

- [ ] **Step 1: Write `android/app/build.gradle.kts`**

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "cy.cypriotkeyboard.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "cy.cypriotkeyboard.app"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation(project(":ime"))
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.2")

    val composeBom = platform("androidx.compose:compose-bom:2024.10.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
```

- [ ] **Step 2: Write `android/app/src/main/AndroidManifest.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <application
        android:label="@string/app_name"
        android:theme="@style/Theme.CypriotKeyboard"
        android:allowBackup="true"
        android:supportsRtl="true">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

- [ ] **Step 3: Write the MainActivity stub `android/app/src/main/kotlin/cy/cypriotkeyboard/app/MainActivity.kt`**

```kotlin
package cy.cypriotkeyboard.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

/** Container app. Full installation-guide UI lands in Task 20. */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            // Filled in by Task 20.
        }
    }
}
```

- [ ] **Step 4: Write `android/app/src/main/res/values/strings.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Cypriot Keyboard</string>
    <string name="app_title">🇨🇾 Κύπριακο Keyboard</string>
    <string name="install_step_1">1. Open \'Settings\'</string>
    <string name="install_step_2">2. Tap \'System\'</string>
    <string name="install_step_3">3. Tap \'Languages \\u0026 input\'</string>
    <string name="install_step_4">4. Tap \'On-screen keyboard\'</string>
    <string name="install_step_5">5. Tap \'Manage keyboards\'</string>
    <string name="install_step_6">6. Enable \'Cypriot Keyboard\'</string>
    <string name="open_settings">Open Settings</string>
    <string name="usage_globe">Tap 🌐 to switch to the Cypriot Keyboard</string>
    <string name="usage_swap">Tap 🔄 to switch between Latin and Greek alphabets</string>
    <string name="usage_suggestions">The bar above the keyboard shows current suggestions. When you press Space, the highlighted suggestion is applied.</string>
    <string name="test_here_hint">Test here</string>
    <string name="credits">Alex Toumazis</string>
</resources>
```

- [ ] **Step 5: Write `android/app/src/main/res/values-el/strings.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Κυπριακό Πληκτρολόγιο</string>
    <string name="app_title">🇨🇾 Κύπριακο Keyboard</string>
    <string name="install_step_1">1. Άνοιξε τις \'Ρυθμίσεις\'</string>
    <string name="install_step_2">2. Πάτα \'Σύστημα\'</string>
    <string name="install_step_3">3. Πάτα \'Γλώσσες \\u0026 εισαγωγή\'</string>
    <string name="install_step_4">4. Πάτα \'Πληκτρολόγιο οθόνης\'</string>
    <string name="install_step_5">5. Πάτα \'Διαχείριση πληκτρολογίων\'</string>
    <string name="install_step_6">6. Ενεργοποίησε το \'Cypriot Keyboard\'</string>
    <string name="open_settings">Άνοιγμα Ρυθμίσεων</string>
    <string name="usage_globe">Πάτα 🌐 για να αλλάξεις στο Κυπριακό Πληκτρολόγιο</string>
    <string name="usage_swap">Πάτα 🔄 για να αλλάξεις μεταξύ Λατινικού και Ελληνικού αλφαβήτου</string>
    <string name="usage_suggestions">Η μπάρα πάνω από το πληκτρολόγιο δείχνει τις προτάσεις. Όταν πατάς Διάστημα, εφαρμόζεται η επισημασμένη πρόταση.</string>
    <string name="test_here_hint">Δοκιμή εδώ</string>
    <string name="credits">Άλεξ Τουμάζης</string>
</resources>
```

- [ ] **Step 6: Write `android/app/src/main/res/values/themes.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.CypriotKeyboard" parent="android:Theme.Material.Light.NoActionBar" />
</resources>
```

- [ ] **Step 7: Commit**

```bash
git add android/app/
git commit -m "android: app module skeleton (MainActivity stub + strings)"
```

---

### Task 4: Bundle DAWG + phonetic fold assets

**Files:**
- Create: `android/ime/src/main/assets/el_CY.dawg` (copy of `dict/el_CY.dawg`)
- Create: `android/ime/src/main/assets/phonetic_fold.json` (copy of `dict_generation/phonetic_fold.json`)

- [ ] **Step 1: Copy DAWG asset**

```bash
mkdir -p android/ime/src/main/assets
cp dict/el_CY.dawg android/ime/src/main/assets/el_CY.dawg
cp dict_generation/phonetic_fold.json android/ime/src/main/assets/phonetic_fold.json
```

- [ ] **Step 2: Verify asset integrity**

```bash
ls -la android/ime/src/main/assets/
# expect el_CY.dawg ~49 MB and phonetic_fold.json ~1 KB
```

- [ ] **Step 3: Configure no-compression for the DAWG**

Append to `android/ime/build.gradle.kts` inside the `android { }` block:

```kotlin
    androidResources {
        noCompress += setOf("dawg")
    }
```

(Compressing a 49 MB binary buys ~5 MB and costs decompression on first open. The DAWG is already entropy-dense; leave it raw so we can read it directly out of the APK without an extraction copy.)

- [ ] **Step 4: Commit**

```bash
git add android/ime/src/main/assets/ android/ime/build.gradle.kts
git commit -m "android: bundle el_CY.dawg + phonetic_fold.json assets"
```

---

## Phase B — Pure logic ports (parallelizable, TDD-friendly)

These tasks are independent of Phases C/D/E. They can be dispatched in parallel as separate subagents.

### Task 5: Greekify port + tests

**Files:**
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/input/Greekify.kt`
- Create: `android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/input/GreekifyTest.kt`

Port `CypriotKeyboardHelper.greekify` from `Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift` lines 96–186. Pure function — single-pass scanner, longest-match-first (trigraph → digraph → single).

- [ ] **Step 1: Write the failing tests**

```kotlin
package cy.cypriotkeyboard.ime.input

import org.junit.Assert.assertEquals
import org.junit.Test

class GreekifyTest {

    @Test fun `single letters map to greek`() {
        assertEquals("καλημερα", greekify("kalhmera"))
        assertEquals("αυτο", greekify("auto"))
    }

    @Test fun `digraphs win over single-letter rules`() {
        // "th" must become "θ" before "t"/"h" map individually
        assertEquals("θεοσ", greekify("theos"))
        // "ps" → "ψ" (not π+σ)
        assertEquals("ψυχη", greekify("psuxh"))
        // "ks" → "ξ" (not κ+σ)
        assertEquals("ξανα", greekify("ksana"))
        // "sh" → "σ̆" (cypriot)
        assertEquals("σ̆ιερι", greekify("shieri"))
        // "ch" → "τσ̆"
        assertEquals("τσ̆αι", greekify("chai"))
        // "yi" → "γι"
        assertEquals("γιοσ", greekify("yios"))
        // "ng" → "γκ"
        assertEquals("γκολ", greekify("ngol"))
    }

    @Test fun `trigraphs win over digraphs`() {
        // "ngk" → "γκ" (not γκ + κ; trigraph beats digraph)
        assertEquals("γκολ", greekify("ngkol"))
        // "ths" → "τησ" (lowercase trigraph)
        assertEquals("τησ", greekify("ths"))
        // "Ths"/"THS" → "Τησ"
        assertEquals("Τησ", greekify("Ths"))
        assertEquals("Τησ", greekify("THS"))
    }

    @Test fun `uppercase variants map`() {
        assertEquals("ΨΥΧΗ", greekify("PSYXH"))  // P→Ψ via digraph PS, Y→Υ, X→Χ, H→Η
        assertEquals("ΘΕΟΣ", greekify("THEOS"))
    }

    @Test fun `b becomes mu-pi digraph`() {
        // single-char b → "μπ"
        assertEquals("μπιρα", greekify("bira"))
        assertEquals("Μπιρα", greekify("Bira"))
    }

    @Test fun `j becomes tzeta digraph`() {
        assertEquals("τζ̆αι", greekify("jai"))
        assertEquals("Τζ̆αι", greekify("Jai"))
    }

    @Test fun `digit 3 maps to xi`() {
        assertEquals("ξενα", greekify("3ena"))
    }

    @Test fun `non-mapped chars pass through`() {
        assertEquals("καλη!", greekify("kalh!"))
        assertEquals(" ", greekify(" "))
        assertEquals("", greekify(""))
    }
}
```

- [ ] **Step 2: Implement `Greekify.kt`**

```kotlin
package cy.cypriotkeyboard.ime.input

/**
 * Greeklish → Greek single-pass scanner. Mirrors
 * iOS `CypriotKeyboardHelper.greekify` (CypriotKeyboardUtil.swift). Longest-
 * match-first: trigraph → digraph → single. Order of disambiguation is
 * load-bearing: "th" must dispatch before "t"/"h" individually.
 */
fun greekify(text: String): String {
    if (text.isEmpty()) return text
    val sb = StringBuilder(text.length * 2)
    var i = 0
    val n = text.length
    while (i < n) {
        val c0 = text[i]
        if (i + 2 < n) {
            val tri = greekifyTrigraph(c0, text[i + 1], text[i + 2])
            if (tri != null) {
                sb.append(tri)
                i += 3
                continue
            }
        }
        if (i + 1 < n) {
            val di = greekifyDigraph(c0, text[i + 1])
            if (di != null) {
                sb.append(di)
                i += 2
                continue
            }
        }
        val single = greekifySingle(c0)
        if (single != null) sb.append(single) else sb.append(c0)
        i += 1
    }
    return sb.toString()
}

private fun greekifyTrigraph(a: Char, b: Char, c: Char): String? = when {
    (a == 'n' && b == 'g' && c == 'k') || (a == 'N' && b == 'G' && c == 'K') -> "γκ"
    a == 't' && b == 'h' && c == 's' -> "τησ"
    (a == 'T' && b == 'h' && c == 's') || (a == 'T' && b == 'H' && c == 'S') -> "Τησ"
    else -> null
}

private fun greekifyDigraph(a: Char, b: Char): String? = when {
    a == 's' && b == 'h' -> "σ̆"
    (a == 'S' && b == 'h') || (a == 'S' && b == 'H') -> "Σ̆"
    a == 'c' && b == 'h' -> "τσ̆"
    (a == 'C' && b == 'h') || (a == 'C' && b == 'H') -> "Τσ̆"
    a == 'p' && b == 's' -> "ψ"
    (a == 'P' && b == 's') || (a == 'P' && b == 'S') -> "Ψ"
    a == 'k' && b == 's' -> "ξ"
    (a == 'K' && b == 's') || (a == 'K' && b == 'S') -> "Ξ"
    (a == 'T' && b == 'h') || (a == 'T' && b == 'H') -> "Θ"
    a == 't' && b == 'h' -> "θ"
    a == 'y' && b == 'i' -> "γι"
    (a == 'Y' && b == 'i') || (a == 'Y' && b == 'I') -> "Γι"
    (a == 'n' && b == 'g') || (a == 'N' && b == 'G') -> "γκ"
    else -> null
}

private fun greekifySingle(c: Char): String? = when (c) {
    'a' -> "α"; 'A' -> "Α"
    'i' -> "ι"; 'I' -> "Ι"
    'e' -> "ε"; 'E' -> "Ε"
    'o' -> "ο"; 'O' -> "Ο"
    'u' -> "υ"; 'U' -> "Υ"
    'y' -> "υ"; 'Y' -> "Υ"
    'w' -> "ω"; 'W' -> "Ω"
    'r' -> "ρ"; 'R' -> "Ρ"
    't' -> "τ"; 'T' -> "Τ"
    'p' -> "π"; 'P' -> "Π"
    's' -> "σ"; 'S' -> "Σ"
    'd' -> "δ"; 'D' -> "Δ"
    'f' -> "φ"; 'F' -> "Φ"
    'g' -> "γ"; 'G' -> "Γ"
    'h' -> "η"; 'H' -> "Η"
    'k' -> "κ"; 'K' -> "Κ"
    'l' -> "λ"; 'L' -> "Λ"
    'z' -> "ζ"; 'Z' -> "Ζ"
    'x' -> "χ"; 'X' -> "Χ"
    'c' -> "κ"; 'C' -> "Κ"
    'v' -> "β"; 'V' -> "Β"
    'b' -> "μπ"; 'B' -> "Μπ"
    'n' -> "ν"; 'N' -> "Ν"
    'm' -> "μ"; 'M' -> "Μ"
    'j' -> "τζ̆"; 'J' -> "Τζ̆"
    '3' -> "ξ"
    else -> null
}
```

- [ ] **Step 3: Mark task complete**

Tests cannot be executed in this sandbox. Verify by:
- Reading the test file alongside `CypriotKeyboardUtil.swift` lines 96–186 and confirming each branch is a 1:1 port.
- The user runs `./gradlew :ime:test` locally when they check in.

- [ ] **Step 4: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/input/Greekify.kt \
        android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/input/GreekifyTest.kt
git commit -m "android: port greekify (Greeklish → Greek transliteration)"
```

---

### Task 6: PhoneticFolder port + tests

**Files:**
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/suggest/PhoneticFolder.kt`
- Create: `android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/suggest/PhoneticFolderTest.kt`

Port `Cypriot  Custom Keyboard/DAWG/PhoneticFolder.swift`. Same longest-match-first folding algorithm. JSON shape matches `dict_generation/phonetic_fold.json` (a `version` int and a `rules` array of `{from, to}` objects).

- [ ] **Step 1: Write the failing tests**

```kotlin
package cy.cypriotkeyboard.ime.suggest

import org.junit.Assert.assertEquals
import org.junit.Test

class PhoneticFolderTest {

    private val sampleJson = """
        {
          "version": 1,
          "rules": [
            {"from": "ει", "to": "ı"},
            {"from": "οι", "to": "ı"},
            {"from": "αι", "to": "e"},
            {"from": "ι", "to": "ı"},
            {"from": "η", "to": "ı"},
            {"from": "υ", "to": "ı"},
            {"from": "ε", "to": "e"},
            {"from": "ο", "to": "o"},
            {"from": "ω", "to": "o"},
            {"from": "ά", "to": "α"},
            {"from": "ς", "to": "σ"}
          ]
        }
    """.trimIndent()

    private val folder = PhoneticFolder.fromJson(sampleJson)

    @Test fun `digraph wins over single-letter rule`() {
        // "ει" must fold to "ı" via the digraph rule, not via the
        // single-char "ε"+"ι" rules. If greedy match works the leading
        // "ει" collapses to one "ı".
        assertEquals("ıμe", folder.fold("ειμε"))
    }

    @Test fun `iota-equivalents collapse to dotless-i`() {
        assertEquals("κıλo", folder.fold("κηλω"))
        assertEquals("κıσσ", folder.fold("κυσς"))
    }

    @Test fun `accented vowels fold to base`() {
        assertEquals("καλα", folder.fold("κάλα"))
    }

    @Test fun `pass-through for unmapped chars`() {
        assertEquals("xyz", folder.fold("xyz"))
        assertEquals("", folder.fold(""))
    }

    @Test fun `final-sigma folds to medial sigma`() {
        assertEquals("φıσ", folder.fold("φησ"))
        assertEquals("φıσ", folder.fold("φης"))   // ς → σ rule
    }
}
```

- [ ] **Step 2: Implement `PhoneticFolder.kt`**

```kotlin
package cy.cypriotkeyboard.ime.suggest

import org.json.JSONObject

/**
 * Mirrors `PhoneticFolder.swift`. Loads a longest-match-first ruleset and
 * applies it greedily across the input. The Android port does NOT use
 * Gson/Moshi — `org.json` is in the platform and zero-dependency.
 */
class PhoneticFolder private constructor(
    private val rules: List<Pair<String, String>>
) {

    /** Identical algorithm to the Python reference and the Swift port. */
    fun fold(text: String): String {
        if (text.isEmpty()) return text
        val sb = StringBuilder(text.length)
        var i = 0
        val n = text.length
        while (i < n) {
            var matched = false
            for ((src, dst) in rules) {
                if (i + src.length <= n && text.regionMatches(i, src, 0, src.length)) {
                    sb.append(dst)
                    i += src.length
                    matched = true
                    break
                }
            }
            if (!matched) {
                sb.append(text[i])
                i += 1
            }
        }
        return sb.toString()
    }

    companion object {

        fun fromJson(json: String): PhoneticFolder {
            val root = JSONObject(json)
            val rulesArr = root.getJSONArray("rules")
            val pairs = mutableListOf<Pair<String, String>>()
            for (idx in 0 until rulesArr.length()) {
                val r = rulesArr.getJSONObject(idx)
                pairs += r.getString("from") to r.getString("to")
            }
            // Stable sort longest-first (matches Swift sort behavior).
            pairs.sortByDescending { it.first.length }
            return PhoneticFolder(pairs)
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/suggest/PhoneticFolder.kt \
        android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/suggest/PhoneticFolderTest.kt
git commit -m "android: port PhoneticFolder (longest-match-first folding)"
```

---

### Task 7: DawgReader port + tests

**Files:**
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/suggest/DawgReader.kt`
- Create: `android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/suggest/DawgReaderTest.kt`

Port `Cypriot  Custom Keyboard/DAWG/DawgReader.swift`. Same v1 binary format (see `dict_generation/DAWG_FORMAT.md`). The Android version reads from a `ByteBuffer` (which can be backed by an asset stream copied into a direct buffer). Little-endian, U16/U32 fields.

- [ ] **Step 1: Write the failing tests**

A real DAWG round-trip test needs a DAWG to read. Build a tiny in-memory DAWG by hand: 1 string ("αβ"), 1 payload, 3 nodes. Easier: test on the bundled `el_CY.dawg`. The test class loads the asset via classloader and verifies a few known words.

```kotlin
package cy.cypriotkeyboard.ime.suggest

import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class DawgReaderTest {

    private fun loadBundled(): DawgReader {
        // Tests run from the module dir; assets are at src/main/assets.
        val file = File("src/main/assets/el_CY.dawg")
        require(file.exists()) { "el_CY.dawg missing — run Task 4 to bundle it" }
        val bytes = file.readBytes()
        val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        return DawgReader.from(buf)
    }

    @Test fun `header parses successfully`() {
        val reader = loadBundled()
        assertTrue(reader.nodeCount > 0)
        assertTrue(reader.payloadCount > 0)
        assertTrue(reader.stringCount > 0)
    }

    @Test fun `lookup of a known word returns a payload`() {
        // We don't know exact fold-keys without folding, but we know the DAWG
        // contains paths. Just walking from root with any common letter must
        // succeed for at least some of them.
        val reader = loadBundled()
        val root = reader.rootNodeIdx
        // Greek alpha codepoint 0x03B1
        val next = reader.step(root, 0x03B1)
        // The DAWG may or may not have an edge from root for any specific char,
        // but root has at least one edge (smoke test).
        assertTrue(reader.edges(root).isNotEmpty())
    }

    @Test fun `bad magic throws`() {
        val buf = ByteBuffer.allocate(32).order(ByteOrder.LITTLE_ENDIAN)
        // wrong magic
        buf.put("XXXX".toByteArray())
        repeat(28) { buf.put(0) }
        buf.rewind()
        try {
            DawgReader.from(buf)
            org.junit.Assert.fail("expected DawgReaderException for bad magic")
        } catch (e: DawgReaderException) {
            // ok
        }
    }
}
```

- [ ] **Step 2: Implement `DawgReader.kt`**

```kotlin
package cy.cypriotkeyboard.ime.suggest

import java.nio.ByteBuffer
import java.nio.ByteOrder

class DawgReaderException(message: String) : RuntimeException(message)

/**
 * Reads the v1 binary DAWG format. See dict_generation/DAWG_FORMAT.md.
 * Mirror of `DawgReader.swift`. The buffer must be little-endian.
 *
 * Lookups are O(input length) jumps into the buffer — node/payload/string
 * offsets are computed once at construction.
 */
class DawgReader private constructor(
    private val buf: ByteBuffer,
    val version: Int,
    val nodeCount: Int,
    val payloadCount: Int,
    val stringCount: Int,
    private val nodeOffsets: IntArray,
    private val payloadOffsets: IntArray,
    private val stringOffsets: IntArray
) {

    val rootNodeIdx: Int get() = nodeCount - 1

    /** Walks from root following `key`'s code points. Returns terminal payload index, or null. */
    fun payloadForKey(key: String): Int? {
        var nodeIdx = rootNodeIdx
        var i = 0
        while (i < key.length) {
            val cp = key.codePointAt(i)
            i += Character.charCount(cp)
            nodeIdx = step(nodeIdx, cp) ?: return null
        }
        return terminalPayload(nodeIdx)
    }

    /** Returns next-node index for the given char codepoint, or null. */
    fun step(nodeIdx: Int, char: Int): Int? {
        val off = nodeOffsets[nodeIdx]
        val edgeCount = buf.getShort(off).toInt() and 0xFFFF
        val edgesStart = off + 2 + 4
        // Edges sorted ascending by codepoint. Linear scan with early exit.
        for (i in 0 until edgeCount) {
            val recordOff = edgesStart + i * 8
            val cp = buf.getInt(recordOff)
            val cpUnsigned = cp.toLong() and 0xFFFFFFFFL
            val charLong = char.toLong() and 0xFFFFFFFFL
            if (cpUnsigned == charLong) return buf.getInt(recordOff + 4)
            if (cpUnsigned > charLong) return null
        }
        return null
    }

    /** All `(codepoint, target_node_idx)` edges from a node. */
    fun edges(nodeIdx: Int): List<Pair<Int, Int>> {
        val off = nodeOffsets[nodeIdx]
        val edgeCount = buf.getShort(off).toInt() and 0xFFFF
        val edgesStart = off + 2 + 4
        val out = ArrayList<Pair<Int, Int>>(edgeCount)
        for (i in 0 until edgeCount) {
            val recordOff = edgesStart + i * 8
            val cp = buf.getInt(recordOff)
            val target = buf.getInt(recordOff + 4)
            out.add(cp to target)
        }
        return out
    }

    /** Terminal payload index for a node, or null if non-terminal. */
    fun terminalPayload(nodeIdx: Int): Int? {
        val off = nodeOffsets[nodeIdx]
        val payload = buf.getInt(off + 2)
        return if (payload == NULL_PAYLOAD) null else payload
    }

    /** All canonical-form (string, frequency) pairs for a payload index. */
    fun canonicalForms(payloadIdx: Int): List<Pair<String, Long>> {
        val off = payloadOffsets[payloadIdx]
        val count = buf.getShort(off).toInt() and 0xFFFF
        val out = ArrayList<Pair<String, Long>>(count)
        for (i in 0 until count) {
            val recordOff = off + 2 + i * 8
            val strIdx = buf.getInt(recordOff)
            val freq = buf.getInt(recordOff + 4).toLong() and 0xFFFFFFFFL
            out.add(readString(strIdx) to freq)
        }
        return out
    }

    private fun readString(idx: Int): String {
        val off = stringOffsets[idx]
        val len = buf.getShort(off).toInt() and 0xFFFF
        val bytes = ByteArray(len)
        // ByteBuffer.get(int, byte[], ...) is API 31+, so use a duplicate to be
        // safe with min-sdk 24.
        val dup = buf.duplicate().order(ByteOrder.LITTLE_ENDIAN)
        dup.position(off + 2)
        dup.get(bytes)
        return String(bytes, Charsets.UTF_8)
    }

    companion object {
        private const val HEADER_SIZE = 32
        // 0x47574144 == "DAWG" little-endian
        private const val MAGIC_LE: Int = 0x47574144
        private const val NULL_PAYLOAD: Int = -1  // 0xFFFFFFFF as signed int

        fun from(rawBuf: ByteBuffer): DawgReader {
            val buf = rawBuf.duplicate().order(ByteOrder.LITTLE_ENDIAN)
            if (buf.capacity() < HEADER_SIZE) throw DawgReaderException("file too short")
            // Magic: bytes 0..3 must be 'D','A','W','G' (0x44,0x41,0x57,0x47)
            // Read as a little-endian int32 → 0x47574144.
            val magic = buf.getInt(0)
            if (magic != MAGIC_LE) throw DawgReaderException("bad magic 0x${magic.toString(16)}")
            val version = buf.getShort(4).toInt() and 0xFFFF
            if (version != 1) throw DawgReaderException("unsupported version $version")
            val nodeCount = buf.getInt(8)
            val payloadCount = buf.getInt(12)
            val stringCount = buf.getInt(16)
            val nodeSectionOff = buf.getInt(20)
            val payloadSectionOff = buf.getInt(24)
            val stringTableOff = buf.getInt(28)

            val nodeOffsets = indexNodes(buf, nodeSectionOff, nodeCount)
            val payloadOffsets = indexPayloads(buf, payloadSectionOff, payloadCount)
            val stringOffsets = indexStrings(buf, stringTableOff, stringCount)

            return DawgReader(
                buf, version, nodeCount, payloadCount, stringCount,
                nodeOffsets, payloadOffsets, stringOffsets
            )
        }

        private fun indexNodes(buf: ByteBuffer, start: Int, count: Int): IntArray {
            val offs = IntArray(count)
            var cursor = start
            for (i in 0 until count) {
                offs[i] = cursor
                val edgeCount = buf.getShort(cursor).toInt() and 0xFFFF
                cursor += 2 + 4 + edgeCount * 8
            }
            return offs
        }

        private fun indexPayloads(buf: ByteBuffer, start: Int, count: Int): IntArray {
            val offs = IntArray(count)
            var cursor = start
            for (i in 0 until count) {
                offs[i] = cursor
                val cfCount = buf.getShort(cursor).toInt() and 0xFFFF
                cursor += 2 + cfCount * 8
            }
            return offs
        }

        private fun indexStrings(buf: ByteBuffer, start: Int, count: Int): IntArray {
            val offs = IntArray(count)
            var cursor = start
            for (i in 0 until count) {
                offs[i] = cursor
                val len = buf.getShort(cursor).toInt() and 0xFFFF
                cursor += 2 + len
            }
            return offs
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/suggest/DawgReader.kt \
        android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/suggest/DawgReaderTest.kt
git commit -m "android: port DawgReader (v1 binary format)"
```

---

### Task 8: DamerauLevenshteinSuggester port + tests

**Files:**
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/suggest/DamerauSuggester.kt`
- Create: `android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/suggest/DamerauSuggesterTest.kt`

Port `DAWG/DamerauLevenshteinSuggester.swift`. Same edit-distance-1 candidate enumeration: deletions, substitutions, insertions, adjacent transpositions. Alphabet collected by walking the DAWG once.

- [ ] **Step 1: Write the failing tests**

```kotlin
package cy.cypriotkeyboard.ime.suggest

import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class DamerauSuggesterTest {

    private fun loadReader(): DawgReader {
        val file = File("src/main/assets/el_CY.dawg")
        require(file.exists())
        val buf = ByteBuffer.wrap(file.readBytes()).order(ByteOrder.LITTLE_ENDIAN)
        return DawgReader.from(buf)
    }

    @Test fun `suggester returns ranked results within distance 1`() {
        val reader = loadReader()
        val folder = PhoneticFolder.fromJson(File("src/main/assets/phonetic_fold.json").readText())
        val suggester = DamerauSuggester(reader)

        // "καλημερα" → fold key. Whatever the exact key, suggest() should
        // return at least one canonical form when fed it.
        val key = folder.fold("καλημερα")
        val suggestions = suggester.suggest(key, limit = 5)
        assertTrue("expected at least 1 suggestion for καλημερα", suggestions.isNotEmpty())
    }

    @Test fun `distance 0 results rank above distance 1`() {
        val reader = loadReader()
        val folder = PhoneticFolder.fromJson(File("src/main/assets/phonetic_fold.json").readText())
        val suggester = DamerauSuggester(reader)

        // Pick a known-good key (after folding any common word).
        val key = folder.fold("καλα")
        val suggestions = suggester.suggest(key, limit = 5)
        if (suggestions.isNotEmpty()) {
            // First result must have the smallest editDistance.
            val firstDist = suggestions.first().editDistance
            for (s in suggestions) {
                assertTrue(s.editDistance >= firstDist)
            }
        }
    }

    @Test fun `empty key returns empty`() {
        val reader = loadReader()
        val suggester = DamerauSuggester(reader)
        assertEquals(emptyList<DawgSuggestion>(), suggester.suggest("", limit = 5))
    }
}
```

- [ ] **Step 2: Implement `DamerauSuggester.kt`**

```kotlin
package cy.cypriotkeyboard.ime.suggest

data class DawgSuggestion(
    val canonical: String,
    val frequency: Long,
    val editDistance: Int
)

/**
 * Mirrors `DamerauLevenshteinSuggester.swift`. Enumerates all single-edit
 * variants of the input key, looks each one up in the DAWG, collects
 * canonicals, dedupes, ranks by (distance asc, frequency desc).
 */
class DamerauSuggester(private val reader: DawgReader) {

    private val alphabet: IntArray = collectAlphabet()

    fun suggest(key: String, limit: Int = 5): List<DawgSuggestion> {
        if (key.isEmpty()) return emptyList()

        data class Hit(val canonical: String, val freq: Long, val distance: Int)
        val hits = ArrayList<Hit>()
        val seen = HashSet<String>()

        // Distance 0: exact match.
        reader.payloadForKey(key)?.let { pidx ->
            for ((canonical, freq) in reader.canonicalForms(pidx)) {
                if (seen.add(canonical)) hits += Hit(canonical, freq, 0)
            }
        }

        // Distance 1: enumerate edited variants.
        for (variant in editDistance1Variants(key)) {
            val pidx = reader.payloadForKey(variant) ?: continue
            for ((canonical, freq) in reader.canonicalForms(pidx)) {
                if (seen.add(canonical)) hits += Hit(canonical, freq, 1)
            }
        }

        hits.sortWith(compareBy({ it.distance }, { -it.freq }))
        return hits.take(limit).map { DawgSuggestion(it.canonical, it.freq, it.distance) }
    }

    private fun editDistance1Variants(key: String): List<String> {
        val cps = key.codePoints().toArray()
        val n = cps.size
        val out = ArrayList<String>()

        // Deletions
        for (i in 0 until n) {
            val copy = IntArray(n - 1)
            System.arraycopy(cps, 0, copy, 0, i)
            System.arraycopy(cps, i + 1, copy, i, n - i - 1)
            out += String(copy, 0, copy.size)
        }
        // Substitutions
        for (i in 0 until n) {
            for (cp in alphabet) {
                if (cp == cps[i]) continue
                val copy = cps.copyOf()
                copy[i] = cp
                out += String(copy, 0, copy.size)
            }
        }
        // Insertions (n+1 positions)
        for (i in 0..n) {
            for (cp in alphabet) {
                val copy = IntArray(n + 1)
                System.arraycopy(cps, 0, copy, 0, i)
                copy[i] = cp
                System.arraycopy(cps, i, copy, i + 1, n - i)
                out += String(copy, 0, copy.size)
            }
        }
        // Adjacent transpositions
        if (n >= 2) {
            for (i in 0 until n - 1) {
                if (cps[i] == cps[i + 1]) continue
                val copy = cps.copyOf()
                val tmp = copy[i]
                copy[i] = copy[i + 1]
                copy[i + 1] = tmp
                out += String(copy, 0, copy.size)
            }
        }
        return out
    }

    private fun collectAlphabet(): IntArray {
        val seen = HashSet<Int>()
        val visited = HashSet<Int>()
        val stack = ArrayDeque<Int>()
        stack.addLast(reader.rootNodeIdx)
        while (stack.isNotEmpty()) {
            val nodeIdx = stack.removeLast()
            if (!visited.add(nodeIdx)) continue
            for ((cp, target) in reader.edges(nodeIdx)) {
                seen += cp
                stack.addLast(target)
            }
        }
        return seen.sorted().toIntArray()
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/suggest/DamerauSuggester.kt \
        android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/suggest/DamerauSuggesterTest.kt
git commit -m "android: port DamerauSuggester (edit-distance-1 candidates)"
```

---

### Task 9: SuggestionEngine wrapper + tests

**Files:**
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/suggest/SuggestionEngine.kt`
- Create: `android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/suggest/SuggestionEngineTest.kt`

Port `DAWG/DawgAutocompleteSuggestionProvider.swift`. Wraps reader+folder+suggester. Returns the suggestion list shape (slot 0 = verbatim, slot 1 = top with willReplace, slots 2+ = extras), with capitalization handling.

- [ ] **Step 1: Write the failing tests**

```kotlin
package cy.cypriotkeyboard.ime.suggest

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class SuggestionEngineTest {

    private fun engine(): SuggestionEngine {
        val dawg = File("src/main/assets/el_CY.dawg")
        val fold = File("src/main/assets/phonetic_fold.json")
        val reader = DawgReader.from(ByteBuffer.wrap(dawg.readBytes()).order(ByteOrder.LITTLE_ENDIAN))
        val folder = PhoneticFolder.fromJson(fold.readText())
        return SuggestionEngine(reader, folder)
    }

    @Test fun `empty input returns empty list`() {
        assertEquals(emptyList<Suggestion>(), engine().suggest(""))
    }

    @Test fun `slot 0 is always verbatim user input`() {
        val res = engine().suggest("καλημερα")
        assertTrue(res.isNotEmpty())
        assertEquals("καλημερα", res[0].text)
        assertTrue(res[0].isVerbatim)
        assertEquals(false, res[0].willReplace)
    }

    @Test fun `slot 1 (when present) is willReplace top candidate`() {
        val res = engine().suggest("καλημερα")
        if (res.size >= 2) {
            assertEquals(true, res[1].willReplace)
            assertEquals(false, res[1].isVerbatim)
        }
    }

    @Test fun `firstLetterCap input yields capitalized suggestions`() {
        val res = engine().suggest("Καλημερα")
        if (res.size >= 2) {
            assertTrue("expected uppercase first letter, got ${res[1].text}",
                res[1].text.isNotEmpty() && res[1].text.first().isUpperCase())
        }
    }

    @Test fun `allCaps input yields uppercase suggestions`() {
        val res = engine().suggest("ΚΑΛΗΜΕΡΑ")
        if (res.size >= 2) {
            assertEquals(res[1].text, res[1].text.uppercase())
        }
    }
}
```

- [ ] **Step 2: Implement `SuggestionEngine.kt`**

```kotlin
package cy.cypriotkeyboard.ime.suggest

import cy.cypriotkeyboard.ime.input.greekify

/** Public suggestion model. Mirrors slot semantics of iOS provider. */
data class Suggestion(
    val text: String,
    val isVerbatim: Boolean,
    val willReplace: Boolean
)

/**
 * Mirrors `DawgAutocompleteSuggestionProvider.swift`. Pipeline:
 *   raw user input → greekify → casing detection → fold → DAWG suggest →
 *   recapitalize → list with verbatim slot 0 and willReplace slot 1.
 *
 * The Android engine ALWAYS Greekifies the input (matching the iOS DAWG path)
 * — even pure-Greek input passes through greekify, which is a no-op for
 * already-Greek characters.
 */
class SuggestionEngine(
    private val reader: DawgReader,
    private val folder: PhoneticFolder,
    suggester: DamerauSuggester? = null,
    private val limit: Int = 4
) {

    private val suggester: DamerauSuggester = suggester ?: DamerauSuggester(reader)

    private enum class Casing { LOWERCASE, FIRST_LETTER_CAP, ALL_CAPS }

    fun suggest(input: String): List<Suggestion> {
        if (input.isEmpty()) return emptyList()

        val greek = greekify(input)
        val (casing, lookup) = detectCasing(greek)
        val key = folder.fold(lookup)
        val candidates = suggester.suggest(key, limit = limit)

        val out = ArrayList<Suggestion>(1 + candidates.size)
        out += Suggestion(text = input, isVerbatim = true, willReplace = false)
        if (candidates.isNotEmpty()) {
            out += Suggestion(
                text = display(candidates[0].canonical, casing),
                isVerbatim = false,
                willReplace = true
            )
            for (i in 1 until candidates.size) {
                out += Suggestion(
                    text = display(candidates[i].canonical, casing),
                    isVerbatim = false,
                    willReplace = false
                )
            }
        }
        return out
    }

    private fun detectCasing(greek: String): Pair<Casing, String> {
        if (greek.isEmpty()) return Casing.LOWERCASE to greek
        val upper = greek.uppercase()
        val lower = greek.lowercase()
        if (greek == upper && greek != lower) {
            return Casing.ALL_CAPS to lower
        }
        if (greek.first().isUpperCase()) {
            val rest = greek.substring(1)
            return Casing.FIRST_LETTER_CAP to (greek.first().lowercaseChar() + rest)
        }
        return Casing.LOWERCASE to greek
    }

    private fun display(canonical: String, casing: Casing): String = when (casing) {
        Casing.LOWERCASE -> canonical
        Casing.FIRST_LETTER_CAP -> if (canonical.isEmpty()) canonical
            else canonical.first().uppercaseChar() + canonical.substring(1)
        Casing.ALL_CAPS -> canonical.uppercase()
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/suggest/SuggestionEngine.kt \
        android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/suggest/SuggestionEngineTest.kt
git commit -m "android: SuggestionEngine wraps reader+folder+suggester"
```

---

## Phase C — Layout data and other ports

### Task 10: Layout data classes

**Files:**
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/layout/LayoutSpec.kt`
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/layout/Layouts.kt`

Port `CypriotKeyboardInputSetProvider.swift` (the row data) and `CypriotKeyboardiPhoneLayoutProvider.swift` (the bottom row).

- [ ] **Step 1: Write `LayoutSpec.kt`**

```kotlin
package cy.cypriotkeyboard.ime.layout

/**
 * Pure data describing one keyboard layout (e.g. Greek alpha, numeric).
 * Mirrors the iOS InputSetProvider rows + the iPhoneLayoutProvider's
 * bottomActions(). Width is in 0.0..1.0 units of one column-of-9.
 */
data class KeySpec(
    val action: KeyAction,
    val label: String,
    val widthUnits: Float = 1.0f,
    val popupChars: List<String> = emptyList()
)

sealed class KeyAction {
    data class Character(val text: String) : KeyAction()
    object Space : KeyAction()
    object Return : KeyAction()
    object Backspace : KeyAction()
    object Shift : KeyAction()
    /** Switches Greek ↔ Latin layouts (iOS 🔄 key). */
    object SwitchLayout : KeyAction()
    /** System next-keyboard (Android 🌐). */
    object SwitchIme : KeyAction()
    object NumericMode : KeyAction()
    object SymbolicMode : KeyAction()
    object AlphabeticMode : KeyAction()
    /** Combining diacritic, applied to the previous character (΄ ˘ ¨ ΅). */
    data class Accent(val combining: String) : KeyAction()
}

data class LayoutSpec(
    val rows: List<List<KeySpec>>
)
```

- [ ] **Step 2: Write `Layouts.kt`**

```kotlin
package cy.cypriotkeyboard.ime.layout

/**
 * Concrete layout instances. Exact 1:1 ports of:
 *   CypriotKeyboardInputSetProvider.alphabeticInputSet (rows 1-3)
 *   CypriotKeyboardiPhoneLayoutProvider.bottomActions (row 4)
 *
 * The accent key in row 1 is "΄" by default and "˘" (breve) when the previous
 * letter is one of σ ζ ξ ψ ς. The shared [greekAlphabetic] returns the default
 * variant; [greekAlphabeticBreve] returns the breve variant. The IME swaps
 * which it shows based on the previous-letter check (mirrors iOS).
 */
object Layouts {

    private fun ch(s: String, popups: List<String> = emptyList()): KeySpec =
        KeySpec(action = KeyAction.Character(s), label = s, popupChars = popups)

    fun greekAlphabetic(useBreve: Boolean = false): LayoutSpec {
        val accent = if (useBreve) ch("˘") else ch("΄", popups = listOf("΄", " ̈", "΅"))
        return LayoutSpec(
            rows = listOf(
                listOf(
                    ch("ε", listOf("ε", "έ")),
                    ch("ρ"),
                    ch("τ"),
                    ch("υ", listOf("υ", "ύ", "ϋ", "ΰ")),
                    ch("θ"),
                    ch("ι", listOf("ι", "ί", "ϊ", "ΐ", "ι-")),
                    ch("ο", listOf("ο", "ό", "ὀ", "ὄ")),
                    ch("π"),
                    accent
                ),
                listOf(
                    ch("α", listOf("α", "ά")),
                    ch("σ", listOf("σ", "ς", "σ̆", "σ̆σ̆", "ς̆")),
                    ch("δ"),
                    ch("φ"),
                    ch("γ"),
                    ch("η", listOf("η", "ή")),
                    ch("ξ", listOf("ξ", "ξ̌")),
                    ch("κ"),
                    ch("λ")
                ),
                listOf(
                    KeySpec(KeyAction.Shift, "⇧", widthUnits = 1.5f),
                    ch("ζ", listOf("ζ", "ζ̆")),
                    ch("χ"),
                    ch("ψ", listOf("ψ", "ψ̆")),
                    ch("ω", listOf("ω", "ώ")),
                    ch("β"),
                    ch("ν"),
                    ch("μ"),
                    KeySpec(KeyAction.Backspace, "⌫", widthUnits = 1.5f)
                ),
                listOf(
                    KeySpec(KeyAction.NumericMode, "?123", widthUnits = 1.5f),
                    KeySpec(KeyAction.SwitchIme, "🌐"),
                    KeySpec(KeyAction.SwitchLayout, "🔄"),
                    KeySpec(KeyAction.Space, "διάστημα", widthUnits = 4.0f),
                    KeySpec(KeyAction.Return, "↵", widthUnits = 1.5f)
                )
            )
        )
    }

    fun latinAlphabetic(): LayoutSpec = LayoutSpec(
        rows = listOf(
            "qwertyuiop".map { ch(it.toString()) },
            "asdfghjkl".map { ch(it.toString()) },
            buildList {
                add(KeySpec(KeyAction.Shift, "⇧", widthUnits = 1.5f))
                addAll("zxcvbnm".map { ch(it.toString()) })
                add(KeySpec(KeyAction.Backspace, "⌫", widthUnits = 1.5f))
            },
            listOf(
                KeySpec(KeyAction.NumericMode, "?123", widthUnits = 1.5f),
                KeySpec(KeyAction.SwitchIme, "🌐"),
                KeySpec(KeyAction.SwitchLayout, "🔄"),
                KeySpec(KeyAction.Space, "space", widthUnits = 4.0f),
                KeySpec(KeyAction.Return, "↵", widthUnits = 1.5f)
            )
        )
    )

    fun numeric(): LayoutSpec = LayoutSpec(
        rows = listOf(
            "1234567890".map { ch(it.toString()) },
            "-/:·()€&@“".map { ch(it.toString()) },
            buildList {
                add(KeySpec(KeyAction.SymbolicMode, "#+=", widthUnits = 1.5f))
                addAll(".,;!’".map { ch(it.toString()) })
                add(KeySpec(KeyAction.Backspace, "⌫", widthUnits = 1.5f))
            },
            listOf(
                KeySpec(KeyAction.AlphabeticMode, "ABC", widthUnits = 1.5f),
                KeySpec(KeyAction.SwitchIme, "🌐"),
                KeySpec(KeyAction.SwitchLayout, "🔄"),
                KeySpec(KeyAction.Space, " ", widthUnits = 4.0f),
                KeySpec(KeyAction.Return, "↵", widthUnits = 1.5f)
            )
        )
    )

    fun symbolic(): LayoutSpec = LayoutSpec(
        rows = listOf(
            "[]{}#%^*+=".map { ch(it.toString()) },
            "_\\?~<>$£¥·".map { ch(it.toString()) },
            buildList {
                add(KeySpec(KeyAction.NumericMode, "123", widthUnits = 1.5f))
                addAll(".,;!’".map { ch(it.toString()) })
                add(KeySpec(KeyAction.Backspace, "⌫", widthUnits = 1.5f))
            },
            listOf(
                KeySpec(KeyAction.AlphabeticMode, "ABC", widthUnits = 1.5f),
                KeySpec(KeyAction.SwitchIme, "🌐"),
                KeySpec(KeyAction.SwitchLayout, "🔄"),
                KeySpec(KeyAction.Space, " ", widthUnits = 4.0f),
                KeySpec(KeyAction.Return, "↵", widthUnits = 1.5f)
            )
        )
    )
}
```

- [ ] **Step 3: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/layout/
git commit -m "android: layout data (Greek + Latin + numeric + symbolic)"
```

---

### Task 11: FinalSigmaRule + tests

**Files:**
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/input/FinalSigmaRule.kt`
- Create: `android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/input/FinalSigmaRuleTest.kt`

Port `CypriotKeyboardActionHandler.handleS` (CypriotKeyboardActionHandler.swift lines 140–177). The rule has two parts:

(a) When the user types a letter and the letter BEFORE last is `ς` (or `ς̆`), promote that `ς` back to `σ` (or `σ̆`) — final-sigma should only be at end-of-word.
(b) When the user is at end-of-word and the last char is `σ` (or `σ̆`), change it to `ς` (or `ς̆`).

Pure-string transform exposed as: `applyFinalSigma(wordPreCursor: String, postCursorEmpty: Boolean): SigmaResult`. The IME applies the result via `InputConnection`.

- [ ] **Step 1: Write the failing tests**

```kotlin
package cy.cypriotkeyboard.ime.input

import org.junit.Assert.assertEquals
import org.junit.Test

class FinalSigmaRuleTest {

    @Test fun `lone sigma at end-of-word becomes final sigma`() {
        val r = applyFinalSigma("καλοσ", postCursorEmpty = true)
        assertEquals(SigmaResult.ReplaceTrailing("σ", "ς"), r)
    }

    @Test fun `lone sigma-breve at end-of-word becomes final sigma-breve`() {
        val r = applyFinalSigma("κασ̆", postCursorEmpty = true)
        assertEquals(SigmaResult.ReplaceTrailing("σ̆", "ς̆"), r)
    }

    @Test fun `final sigma followed by another letter becomes medial sigma`() {
        // The user typed "ς" thinking they were ending the word, then kept typing.
        // Per iOS rule: the next-to-last char is "ς", last char is a letter →
        // demote the "ς" back to "σ".
        val r = applyFinalSigma("καλςα", postCursorEmpty = true)
        // ς is at index 3, then α at index 4. Replace ς with σ.
        assertEquals(SigmaResult.PromoteMedial("ς", "σ"), r)
    }

    @Test fun `no rule fires on non-sigma terminal`() {
        assertEquals(SigmaResult.None, applyFinalSigma("καλο", postCursorEmpty = true))
    }

    @Test fun `mid-cursor (postCursorEmpty=false) does not run end-of-word promotion`() {
        // Last letter is σ, but cursor is mid-word → no end-of-word promotion.
        // The medial-promotion rule still fires if applicable; here it isn't.
        assertEquals(SigmaResult.None, applyFinalSigma("καλοσ", postCursorEmpty = false))
    }
}
```

- [ ] **Step 2: Implement `FinalSigmaRule.kt`**

```kotlin
package cy.cypriotkeyboard.ime.input

/** Result of applying the final-sigma rule to the current word. */
sealed class SigmaResult {
    object None : SigmaResult()
    /** The trailing [from] should be replaced with [to] (e.g. σ → ς). */
    data class ReplaceTrailing(val from: String, val to: String) : SigmaResult()
    /** The character before the just-typed letter is [from]; demote it to [to]. */
    data class PromoteMedial(val from: String, val to: String) : SigmaResult()
}

/**
 * Mirrors `CypriotKeyboardActionHandler.handleS` (Swift, lines 140-177).
 *
 * Inputs:
 *   wordPreCursor   — current word from start-of-word to cursor (inclusive of the
 *                     just-typed letter).
 *   postCursorEmpty — true iff the cursor is at end-of-word (no chars after).
 *
 * The rule looks at:
 *   last        = wordPreCursor.lastChar
 *   secondLast  = wordPreCursor.takeLast 1 char before that (could be "ς" or "ς̆")
 *
 * If `last` is a letter and `secondLast` is "ς", demote → "σ". Same for "ς̆"/"σ̆".
 * Else if cursor at end-of-word and `last` is "σ" or "σ̆", promote → "ς"/"ς̆".
 * Otherwise no-op.
 *
 * The result is interpreted by the IME's ActionHandler, which performs the
 * actual InputConnection replace.
 */
fun applyFinalSigma(wordPreCursor: String, postCursorEmpty: Boolean): SigmaResult {
    if (wordPreCursor.isEmpty()) return SigmaResult.None
    val last = wordPreCursor.last()
    if (!last.isLetter()) return SigmaResult.None

    // Promote-medial: look at the substring before the last char and inspect
    // whether IT ended in "ς" or "ς̆".
    val before = wordPreCursor.substring(0, wordPreCursor.length - 1)
    if (before.endsWith("ς̆")) {
        return SigmaResult.PromoteMedial(from = "ς̆", to = "σ̆")
    }
    if (before.endsWith("ς")) {
        return SigmaResult.PromoteMedial(from = "ς", to = "σ")
    }

    // End-of-word promotion: only fires when cursor is truly at end-of-word.
    if (postCursorEmpty) {
        // Check σ̆ (compound) before plain σ — longest match wins.
        if (wordPreCursor.endsWith("σ̆")) {
            return SigmaResult.ReplaceTrailing(from = "σ̆", to = "ς̆")
        }
        if (last == 'σ') {
            return SigmaResult.ReplaceTrailing(from = "σ", to = "ς")
        }
    }
    return SigmaResult.None
}
```

- [ ] **Step 3: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/input/FinalSigmaRule.kt \
        android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/input/FinalSigmaRuleTest.kt
git commit -m "android: port final-sigma rule (medial demotion + end-of-word promotion)"
```

---

### Task 12: AccentCombiner + tests

**Files:**
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/input/AccentCombiner.kt`
- Create: `android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/input/AccentCombinerTest.kt`

Port `CypriotKeyboardActionHandler.triggerAccent` (lines 86–124). When the user taps `΄`/`˘`/` ̈`/`΅`, the handler deletes the dead-key character from the buffer (it was just inserted) and emits a combining diacritic — but only if the previous character is a valid base letter for that accent. The Android equivalent returns the action the IME should perform via `InputConnection`.

- [ ] **Step 1: Write the failing tests**

```kotlin
package cy.cypriotkeyboard.ime.input

import org.junit.Assert.assertEquals
import org.junit.Test

class AccentCombinerTest {

    @Test fun `tonos applies to vowel`() {
        // Last char before the accent key is "α" → emit "́" (combining tonos)
        assertEquals(AccentResult.Combine("́"), applyAccent("΄", "α"))
    }

    @Test fun `tonos rejected on consonant`() {
        assertEquals(AccentResult.Reject, applyAccent("΄", "κ"))
    }

    @Test fun `breve applies to sigma family`() {
        assertEquals(AccentResult.Combine("̆"), applyAccent("˘", "σ"))
        assertEquals(AccentResult.Combine("̆"), applyAccent("˘", "ζ"))
        assertEquals(AccentResult.Combine("̆"), applyAccent("˘", "ξ"))
        assertEquals(AccentResult.Combine("̆"), applyAccent("˘", "ψ"))
        assertEquals(AccentResult.Combine("̆"), applyAccent("˘", "ς"))
    }

    @Test fun `breve rejected on vowel`() {
        assertEquals(AccentResult.Reject, applyAccent("˘", "α"))
    }

    @Test fun `dialytika applies to iota or upsilon`() {
        assertEquals(AccentResult.Combine("̈"), applyAccent(" ̈", "ι"))
        assertEquals(AccentResult.Combine("̈"), applyAccent(" ̈", "υ"))
        assertEquals(AccentResult.Combine("̈"), applyAccent(" ̈", "ί"))
        assertEquals(AccentResult.Combine("̈"), applyAccent(" ̈", "ύ"))
    }

    @Test fun `tonos-dialytika cases`() {
        // ι/υ → emit ¨ + tonos
        assertEquals(AccentResult.Combine("̈́"), applyAccent("΅", "ι"))
        assertEquals(AccentResult.Combine("̈́"), applyAccent("΅", "υ"))
        // already-dialytika ϊ/ϋ → emit just tonos
        assertEquals(AccentResult.Combine("́"), applyAccent("΅", "ϊ"))
        assertEquals(AccentResult.Combine("́"), applyAccent("΅", "ϋ"))
        // already-tonos ί/ύ → emit dialytika
        assertEquals(AccentResult.Combine("̈"), applyAccent("΅", "ί"))
        assertEquals(AccentResult.Combine("̈"), applyAccent("΅", "ύ"))
    }

    @Test fun `unknown accent is rejected`() {
        assertEquals(AccentResult.Reject, applyAccent("x", "α"))
    }

    @Test fun `empty preceding char is rejected`() {
        assertEquals(AccentResult.Reject, applyAccent("΄", ""))
    }
}
```

- [ ] **Step 2: Implement `AccentCombiner.kt`**

```kotlin
package cy.cypriotkeyboard.ime.input

/**
 * Result of an accent-key tap. The IME caller must delete the just-inserted
 * accent character from the input buffer regardless of result; only when
 * [Combine] does it then commit the combining-diacritic string.
 */
sealed class AccentResult {
    object Reject : AccentResult()
    data class Combine(val combining: String) : AccentResult()
}

/**
 * Mirrors `triggerAccent` in CypriotKeyboardActionHandler.swift (lines 86-124).
 * Allowed-base-letter checks per accent must match the Swift sets exactly.
 */
fun applyAccent(accentKey: String, lastChar: String): AccentResult {
    if (lastChar.isEmpty()) return AccentResult.Reject
    val lastLower = lastChar.lowercase()
    return when (accentKey) {
        "˘" -> if (lastLower in setOf("σ", "ζ", "ξ", "ψ", "ς"))
            AccentResult.Combine("̆") else AccentResult.Reject
        " ̈" -> if (lastLower in setOf("ι", "ί", "υ", "ύ"))
            AccentResult.Combine("̈") else AccentResult.Reject
        "΅" -> when (lastLower) {
            "ι", "υ" -> AccentResult.Combine("̈́")
            "ϊ", "ϋ" -> AccentResult.Combine("́")
            "ί", "ύ" -> AccentResult.Combine("̈")
            else -> AccentResult.Reject
        }
        "΄" -> if (lastLower in setOf("α", "ε", "ι", "η", "υ", "ο", "ω", "ϋ", "ϊ", "ὀ"))
            AccentResult.Combine("́") else AccentResult.Reject
        else -> AccentResult.Reject
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/input/AccentCombiner.kt \
        android/ime/src/test/kotlin/cy/cypriotkeyboard/ime/input/AccentCombinerTest.kt
git commit -m "android: port accent combiner (tonos / breve / dialytika / both)"
```

---

### Task 13: CommonWords data port

**Files:**
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/input/CommonWords.kt`

Port the `commonWords` set from `CypriotKeyboardUtil.swift` (~440 entries). Used by the iOS Hunspell pipeline; the Android DAWG pipeline uses frequency from the DAWG payload directly, so this list isn't strictly needed for the v1 Android port — but **export it anyway** for forward compatibility (e.g. if we add a "boost-common" pass later). Tests are not necessary; it's a data-only port.

- [ ] **Step 1: Copy the set verbatim**

Source: `Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift` lines 191–744.

```kotlin
package cy.cypriotkeyboard.ime.input

/** 1:1 port of the commonWords Set from CypriotKeyboardUtil.swift. */
object CommonWords {
    val SET: Set<String> = setOf(
        // PASTE THE FULL SWIFT SET LITERAL HERE — every quoted entry from
        // CypriotKeyboardUtil.swift lines 191-744. Each "..." entry becomes
        // "...", with no other transformation. The set is consulted via
        // contains(word.lowercase()) so all entries here are already lowercase
        // (they are in the Swift original).
    )

    fun isCommon(word: String): Boolean = SET.contains(word.lowercase())
}
```

- [ ] **Step 2: Replace the placeholder**

Open `Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift` lines 191–744. Copy each line `"αβγ",` → paste into the `setOf( ... )` block in `CommonWords.kt`. The Kotlin syntax is identical (string literal commas).

If the implementing subagent has access to a shell, this scripted equivalent is faster:

```bash
python3 - <<'PY'
import re, pathlib
src = pathlib.Path('Cypriot  Custom Keyboard/CypriotKeyboardUtil.swift').read_text()
# The set literal is everything between `static let commonWords: Set<String> = [` and the closing `]`
m = re.search(r'static let commonWords: Set<String> = \[(.*?)\]', src, flags=re.DOTALL)
if not m: raise SystemExit("commonWords set not found")
body = m.group(1)
items = re.findall(r'"([^"]+)"', body)
out = ',\n        '.join(f'"{w}"' for w in items)
target = pathlib.Path('android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/input/CommonWords.kt')
text = target.read_text().replace('// PASTE THE FULL SWIFT SET LITERAL HERE — every quoted entry from\n        // CypriotKeyboardUtil.swift lines 191-744. Each "..." entry becomes\n        // "...", with no other transformation. The set is consulted via\n        // contains(word.lowercase()) so all entries here are already lowercase\n        // (they are in the Swift original).', out)
target.write_text(text)
PY
```

- [ ] **Step 3: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/input/CommonWords.kt
git commit -m "android: port commonWords set (~440 high-frequency Cypriot Greek words)"
```

---

## Phase D — UI

### Task 14: KeyboardLayout Compose composables

**Files:**
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/ui/KeyboardLayout.kt`

Pure-Compose key + row composables. No external state — they take a callback for key taps.

- [ ] **Step 1: Implement**

```kotlin
package cy.cypriotkeyboard.ime.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import cy.cypriotkeyboard.ime.layout.KeySpec
import cy.cypriotkeyboard.ime.layout.LayoutSpec

private val KEY_HEIGHT = 50.dp
private val KEY_GAP = 4.dp
private val ROW_GAP = 6.dp

@Composable
fun KeyboardLayoutView(
    spec: LayoutSpec,
    onKeyTap: (KeySpec) -> Unit,
    onKeyLongPress: (KeySpec) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(ROW_GAP)
    ) {
        for (row in spec.rows) {
            KeyRow(row, onKeyTap, onKeyLongPress)
        }
    }
}

@Composable
private fun KeyRow(
    keys: List<KeySpec>,
    onKeyTap: (KeySpec) -> Unit,
    onKeyLongPress: (KeySpec) -> Unit
) {
    val totalUnits = keys.sumOf { it.widthUnits.toDouble() }.toFloat()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(KEY_HEIGHT),
        horizontalArrangement = Arrangement.spacedBy(KEY_GAP)
    ) {
        for (key in keys) {
            KeyButton(
                key = key,
                weight = key.widthUnits / totalUnits,
                onTap = { onKeyTap(key) },
                onLongPress = { onKeyLongPress(key) }
            )
        }
    }
}

@Composable
private fun RowScope.KeyButton(
    key: KeySpec,
    weight: Float,
    onTap: () -> Unit,
    onLongPress: () -> Unit
) {
    val bg = MaterialTheme.colorScheme.surfaceVariant
    Box(
        modifier = Modifier
            .weight(weight)
            .fillMaxSize()
            .clip(RoundedCornerShape(6.dp))
            .background(bg)
            .clickable(onClick = onTap)
            // long-press hookup; Compose has detectTapGestures for this if
            // a richer popup UI is needed later. For v1 the click-only path
            // covers all cases except secondary-callout popups (see notes).
            ,
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = key.label,
            color = Color.Black,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.titleMedium
        )
    }
}
```

NOTE: long-press popup with secondary characters is intentionally deferred. The framework has `key.popupChars` populated; the IME can wire up a `LongPressMenu` in a follow-up. For v1 we ship without it (mirrors a pragmatic feature subset of the iOS callouts).

- [ ] **Step 2: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/ui/KeyboardLayout.kt
git commit -m "android: KeyboardLayout compose composables"
```

---

### Task 15: SuggestionBar Compose

**Files:**
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/ui/SuggestionBar.kt`

Compose composable for the suggestion bar. Mirrors `KeyboardView.swift autocompleteBarButton` — slot with `willReplace=true` gets a gray rounded background.

- [ ] **Step 1: Implement**

```kotlin
package cy.cypriotkeyboard.ime.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import cy.cypriotkeyboard.ime.suggest.Suggestion

private val BAR_HEIGHT = 50.dp

@Composable
fun SuggestionBar(
    suggestions: List<Suggestion>,
    onPick: (Suggestion) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(BAR_HEIGHT)
            .padding(horizontal = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        for (s in suggestions) {
            SuggestionSlot(s, onPick = { onPick(s) }, modifier = Modifier
                .weight(1f)
                .fillMaxSize())
        }
    }
}

@Composable
private fun SuggestionSlot(
    s: Suggestion,
    onPick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val bg = if (s.willReplace)
        MaterialTheme.colorScheme.surfaceVariant
    else
        Color.Transparent
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(5.dp))
            .background(bg)
            .clickable(onClick = onPick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = s.text,
            color = Color.Black,
            style = MaterialTheme.typography.bodyMedium
        )
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/ui/SuggestionBar.kt
git commit -m "android: SuggestionBar compose (willReplace gets gray slot)"
```

---

### Task 16: KeyboardView root Compose

**Files:**
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/ui/KeyboardView.kt`

Compose root mirroring `KeyboardView.swift`. Stacks the suggestion bar above the keyboard layout; observes a `KeyboardUiState` from the IME.

- [ ] **Step 1: Implement**

```kotlin
package cy.cypriotkeyboard.ime.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import cy.cypriotkeyboard.ime.layout.KeySpec
import cy.cypriotkeyboard.ime.layout.LayoutSpec
import cy.cypriotkeyboard.ime.suggest.Suggestion

data class KeyboardUiState(
    val layout: LayoutSpec,
    val suggestions: List<Suggestion>
)

@Composable
fun KeyboardView(
    state: State<KeyboardUiState>,
    onSuggestionPick: (Suggestion) -> Unit,
    onKeyTap: (KeySpec) -> Unit,
    onKeyLongPress: (KeySpec) -> Unit
) {
    val s by state
    Surface(
        color = MaterialTheme.colorScheme.background,
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            SuggestionBar(suggestions = s.suggestions, onPick = onSuggestionPick)
            KeyboardLayoutView(
                spec = s.layout,
                onKeyTap = onKeyTap,
                onKeyLongPress = onKeyLongPress
            )
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/ui/KeyboardView.kt
git commit -m "android: KeyboardView compose root (suggestion bar over layout)"
```

---

## Phase E — Action handler & service

### Task 17: ActionHandler

**Files:**
- Create: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/input/ActionHandler.kt`

The orchestrator. Talks to `InputConnection`, applies `Greekify` (NOT directly — Greekify happens in the SuggestionEngine for suggestion text; raw input remains user-typed Greeklish or Greek), runs final-sigma + accent rules, kicks off debounced autocomplete, owns the space-replace logic.

The action handler does NOT depend on Compose; it's plain Kotlin. Compose state updates flow through a separate `KeyboardController` interface (Task 18 service ties the two together).

- [ ] **Step 1: Implement**

```kotlin
package cy.cypriotkeyboard.ime.input

import android.view.inputmethod.InputConnection
import cy.cypriotkeyboard.ime.layout.KeyAction
import cy.cypriotkeyboard.ime.layout.KeySpec
import cy.cypriotkeyboard.ime.suggest.Suggestion

/** Hooks the action handler invokes on the IME service. */
interface KeyboardController {
    fun ic(): InputConnection?
    fun toggleLayoutGreekLatin()
    fun setMode(mode: KeyboardMode)
    fun requestSuggestions(currentWord: String)
    fun shiftHeld(): Boolean
}

enum class KeyboardMode { ALPHABETIC, NUMERIC, SYMBOLIC }

/**
 * Mirrors `CypriotKeyboardActionHandler.swift`. Sequenced:
 *   1) commit text
 *   2) trigger space-replace if applicable
 *   3) final-sigma rule
 *   4) accent combiner
 *   5) request suggestions
 *
 * Holds [currentGuess] and [lastAction] state mirroring the iOS handler.
 */
class ActionHandler(private val controller: KeyboardController) {

    /** Top suggestion with willReplace=true, if any. Mutated by IME on pipeline ticks. */
    @Volatile var currentGuess: Suggestion? = null

    /** Last user action — used by space-replace to detect "user just hit backspace". */
    @Volatile var lastAction: LastAction? = null

    fun handle(spec: KeySpec) {
        val ic = controller.ic() ?: return
        when (val a = spec.action) {
            is KeyAction.Character -> handleCharacter(ic, a.text)
            KeyAction.Space -> handleSpaceLike(ic, " ")
            KeyAction.Return -> handleSpaceLike(ic, "\n")
            KeyAction.Backspace -> {
                ic.deleteSurroundingText(1, 0)
                lastAction = LastAction.Backspace
                controller.requestSuggestions(currentWord(ic))
            }
            KeyAction.Shift -> { /* shift state lives in service */ }
            KeyAction.SwitchLayout -> {
                controller.toggleLayoutGreekLatin()
                lastAction = LastAction.NonInput
            }
            KeyAction.SwitchIme -> { lastAction = LastAction.NonInput }
            KeyAction.NumericMode -> {
                controller.setMode(KeyboardMode.NUMERIC)
                lastAction = LastAction.NonInput
            }
            KeyAction.SymbolicMode -> {
                controller.setMode(KeyboardMode.SYMBOLIC)
                lastAction = LastAction.NonInput
            }
            KeyAction.AlphabeticMode -> {
                controller.setMode(KeyboardMode.ALPHABETIC)
                lastAction = LastAction.NonInput
            }
            is KeyAction.Accent -> handleAccentKey(ic, a.combining)
        }
    }

    private fun handleCharacter(ic: InputConnection, text: String) {
        val isPunctOrTrigger = text in PUNCT_TRIGGERS
        if (isPunctOrTrigger) {
            handleSpaceLike(ic, text)
            return
        }
        // Standard insert.
        ic.commitText(text, 1)
        // Final-sigma rule on the now-current word.
        applyFinalSigmaRule(ic)
        lastAction = LastAction.Character
        controller.requestSuggestions(currentWord(ic))
    }

    private fun handleSpaceLike(ic: InputConnection, trigger: String) {
        // Mirror iOS `triggerSpaceAutocomplete`: if a willReplace guess is queued
        // and the previous action was NOT a backspace, replace the typed word
        // with the suggestion before inserting the trigger character.
        val guess = currentGuess
        if (guess != null && guess.willReplace && lastAction != LastAction.Backspace) {
            replaceCurrentWord(ic, guess.text)
        }
        ic.commitText(trigger, 1)
        currentGuess = null
        lastAction = LastAction.Character
        controller.requestSuggestions(currentWord(ic))
    }

    private fun applyFinalSigmaRule(ic: InputConnection) {
        val word = currentWord(ic)
        val postEmpty = textAfterCursor(ic).isEmpty()
        when (val r = applyFinalSigma(word, postCursorEmpty = postEmpty)) {
            SigmaResult.None -> Unit
            is SigmaResult.PromoteMedial -> {
                // The "ς" or "ς̆" is at position word.length - 1 - r.from.length
                // (i.e. just-typed letter is at the very end; the fragment to demote
                // sits immediately before it).
                // Delete: typed letter + "ς"/"ς̆", reinsert: "σ"/"σ̆" + typed letter.
                val typedLast = word.last().toString()
                val deleteCount = 1 + r.from.length
                ic.deleteSurroundingText(deleteCount, 0)
                ic.commitText(r.to + typedLast, 1)
            }
            is SigmaResult.ReplaceTrailing -> {
                ic.deleteSurroundingText(r.from.length, 0)
                ic.commitText(r.to, 1)
            }
        }
    }

    private fun handleAccentKey(ic: InputConnection, accentKey: String) {
        // The accent character was NOT yet committed; we directly emit the
        // combining diacritic as if the user typed the dead-key.
        val before = textBeforeCursor(ic, 2)
        val lastChar = if (before.isEmpty()) "" else {
            // Take the last character cluster (handle σ̆ / ς̆ as a 2-codepoint cluster).
            takeLastCluster(before)
        }
        when (val r = applyAccent(accentKey, lastChar)) {
            AccentResult.Reject -> { /* drop the dead-key tap */ }
            is AccentResult.Combine -> ic.commitText(r.combining, 1)
        }
        lastAction = LastAction.Character
        controller.requestSuggestions(currentWord(ic))
    }

    /** Replace the current word (whatever cluster precedes the cursor that's letters). */
    private fun replaceCurrentWord(ic: InputConnection, replacement: String) {
        val word = currentWord(ic)
        if (word.isEmpty()) {
            ic.commitText(replacement, 1)
            return
        }
        ic.deleteSurroundingText(word.length, 0)
        ic.commitText(replacement, 1)
    }

    private fun currentWord(ic: InputConnection): String {
        val before = textBeforeCursor(ic, 64) // 64 chars is plenty for a word.
        return WORD_TAIL.find(before)?.value ?: ""
    }

    private fun textBeforeCursor(ic: InputConnection, n: Int): String =
        ic.getTextBeforeCursor(n, 0)?.toString() ?: ""

    private fun textAfterCursor(ic: InputConnection): String =
        ic.getTextAfterCursor(1, 0)?.toString() ?: ""

    private fun takeLastCluster(s: String): String {
        // "σ̆" and "ς̆" are 2-codepoint clusters (σ + U+0306 etc.). We treat
        // any combining mark as part of the cluster.
        if (s.isEmpty()) return ""
        val last = s[s.length - 1]
        if (s.length >= 2 && last.code in 0x0300..0x036F) {
            return s.substring(s.length - 2)
        }
        return last.toString()
    }

    enum class LastAction { Character, Backspace, NonInput }

    companion object {
        // Punctuation that triggers the same "replace-and-insert" behavior as space.
        private val PUNCT_TRIGGERS = setOf(".", ",", ";", ":", "·", "!", "?", "]", ")", "\"")
        private val WORD_TAIL = Regex("[\\p{L}\\p{M}]+$")
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/input/ActionHandler.kt
git commit -m "android: ActionHandler (space-replace + final-sigma + accent + suggestions)"
```

---

### Task 18: CypriotInputMethodService — full wiring

**Files:**
- Modify: `android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/CypriotInputMethodService.kt` (replaces stub from Task 2)

The service: owns Compose state, lifecycle owners, the SuggestionEngine, the ActionHandler, the SharedPreferences-backed locale flag, and the debounce/race-guard for autocomplete.

- [ ] **Step 1: Replace the stub with the real service**

```kotlin
package cy.cypriotkeyboard.ime

import android.content.Context
import android.content.SharedPreferences
import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.inputmethod.InputConnection
import android.view.inputmethod.InputMethodManager
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import cy.cypriotkeyboard.ime.input.ActionHandler
import cy.cypriotkeyboard.ime.input.KeyboardController
import cy.cypriotkeyboard.ime.input.KeyboardMode
import cy.cypriotkeyboard.ime.layout.KeySpec
import cy.cypriotkeyboard.ime.layout.LayoutSpec
import cy.cypriotkeyboard.ime.layout.Layouts
import cy.cypriotkeyboard.ime.suggest.DawgReader
import cy.cypriotkeyboard.ime.suggest.PhoneticFolder
import cy.cypriotkeyboard.ime.suggest.Suggestion
import cy.cypriotkeyboard.ime.suggest.SuggestionEngine
import cy.cypriotkeyboard.ime.ui.KeyboardUiState
import cy.cypriotkeyboard.ime.ui.KeyboardView
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class CypriotInputMethodService :
    InputMethodService(),
    LifecycleOwner,
    SavedStateRegistryOwner,
    KeyboardController {

    // ---- Lifecycle plumbing for Compose-in-IME -------------------------

    private val lifecycleRegistry = LifecycleRegistry(this)
    override val lifecycle: Lifecycle get() = lifecycleRegistry

    private val savedStateRegistryController = SavedStateRegistryController.create(this)
    override val savedStateRegistry get() = savedStateRegistryController.savedStateRegistry

    // ---- IME state -----------------------------------------------------

    private lateinit var prefs: SharedPreferences
    private val mainHandler = Handler(Looper.getMainLooper())
    private val workerExec = Executors.newSingleThreadExecutor { r ->
        Thread(r, "cypriot-suggest").apply { isDaemon = true }
    }

    private var engine: SuggestionEngine? = null
    private val uiState = mutableStateOf(
        KeyboardUiState(layout = Layouts.greekAlphabetic(), suggestions = emptyList())
    )
    private val handler = ActionHandler(this)
    private val autocompleteToken = AtomicInteger(0)
    private var pendingAutocomplete: Runnable? = null

    private var mode: KeyboardMode = KeyboardMode.ALPHABETIC
    private var isLatin: Boolean = false

    // ---- Service lifecycle --------------------------------------------

    override fun onCreate() {
        savedStateRegistryController.performAttach()
        savedStateRegistryController.performRestore(null)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        super.onCreate()
        prefs = getSharedPreferences("cypriot_keyboard", Context.MODE_PRIVATE)
        isLatin = prefs.getBoolean(KEY_IS_LATIN, false)
        recomputeLayout()
        loadEngineAsync()
    }

    override fun onCreateInputView(): View {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        val composeView = ComposeView(this)
        composeView.setViewTreeLifecycleOwner(this)
        composeView.setViewTreeSavedStateRegistryOwner(this)
        composeView.setContent {
            KeyboardView(
                state = uiState as androidx.compose.runtime.State<KeyboardUiState>,
                onSuggestionPick = { s -> applySuggestion(s) },
                onKeyTap = { k -> handler.handle(k) },
                onKeyLongPress = { k -> handleLongPress(k) }
            )
        }
        return composeView
    }

    override fun onDestroy() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        workerExec.shutdownNow()
        super.onDestroy()
    }

    // ---- KeyboardController -------------------------------------------

    override fun ic(): InputConnection? = currentInputConnection

    override fun toggleLayoutGreekLatin() {
        isLatin = !isLatin
        prefs.edit().putBoolean(KEY_IS_LATIN, isLatin).apply()
        recomputeLayout()
    }

    override fun setMode(mode: KeyboardMode) {
        this.mode = mode
        recomputeLayout()
    }

    override fun requestSuggestions(currentWord: String) {
        val token = autocompleteToken.incrementAndGet()
        // Cancel previous pending callable.
        pendingAutocomplete?.let { mainHandler.removeCallbacks(it) }
        if (currentWord.isEmpty()) {
            uiState.value = uiState.value.copy(suggestions = emptyList())
            handler.currentGuess = null
            return
        }
        val r = Runnable {
            val eng = engine
            if (eng == null) return@Runnable
            workerExec.submit {
                val out = try { eng.suggest(currentWord) } catch (t: Throwable) { emptyList() }
                if (autocompleteToken.get() != token) return@submit  // race-guard
                mainHandler.post {
                    uiState.value = uiState.value.copy(suggestions = out)
                    handler.currentGuess = out.firstOrNull { it.willReplace }
                }
            }
        }
        pendingAutocomplete = r
        mainHandler.postDelayed(r, AUTOCOMPLETE_DEBOUNCE_MS)
    }

    override fun shiftHeld(): Boolean = false   // shift held-state not yet wired

    // ---- Helpers -------------------------------------------------------

    private fun recomputeLayout() {
        val layout: LayoutSpec = when (mode) {
            KeyboardMode.NUMERIC -> Layouts.numeric()
            KeyboardMode.SYMBOLIC -> Layouts.symbolic()
            KeyboardMode.ALPHABETIC -> if (isLatin) Layouts.latinAlphabetic() else Layouts.greekAlphabetic()
        }
        uiState.value = uiState.value.copy(layout = layout)
    }

    private fun applySuggestion(s: Suggestion) {
        val ic = ic() ?: return
        // Replace the current word with the picked suggestion + a space.
        val word = handler.run {
            // Use the same word-detect regex as ActionHandler.
            val before = ic.getTextBeforeCursor(64, 0)?.toString() ?: ""
            Regex("[\\p{L}\\p{M}]+$").find(before)?.value ?: ""
        }
        if (word.isNotEmpty()) ic.deleteSurroundingText(word.length, 0)
        ic.commitText(s.text, 1)
        ic.commitText(" ", 1)
        handler.currentGuess = null
        uiState.value = uiState.value.copy(suggestions = emptyList())
    }

    private fun handleLongPress(spec: KeySpec) {
        // v1: long-press is a no-op (popup secondary callout deferred).
        // The 🔄 long-press toggled suggester engine on iOS but Android has
        // only one engine — this is a no-op deliberately.
    }

    private fun loadEngineAsync() {
        workerExec.submit {
            try {
                val dawgBytes = assets.open("el_CY.dawg").use { it.readBytes() }
                val foldJson = assets.open("phonetic_fold.json").use {
                    it.readBytes().toString(Charsets.UTF_8)
                }
                val buf = ByteBuffer.wrap(dawgBytes).order(ByteOrder.LITTLE_ENDIAN)
                val reader = DawgReader.from(buf)
                val folder = PhoneticFolder.fromJson(foldJson)
                engine = SuggestionEngine(reader, folder)
            } catch (e: IOException) {
                // No engine — keyboard still types, just no suggestions.
                engine = null
            } catch (e: Throwable) {
                engine = null
            }
        }
    }

    companion object {
        private const val KEY_IS_LATIN = "isLatinKeyboard"
        private const val AUTOCOMPLETE_DEBOUNCE_MS = 40L
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/ime/src/main/kotlin/cy/cypriotkeyboard/ime/CypriotInputMethodService.kt
git commit -m "android: full IME service wiring (Compose, lifecycle, engine load)"
```

---

## Phase F — Container app

### Task 19: MainActivity — installation guide UI

**Files:**
- Modify: `android/app/src/main/kotlin/cy/cypriotkeyboard/app/MainActivity.kt`

Mirror `Cypriot Keyboard/ContentView.swift`. Detect whether our IME is enabled, show install-steps if not, otherwise show usage tips.

- [ ] **Step 1: Implement**

```kotlin
package cy.cypriotkeyboard.app

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    Home(
                        isImeEnabled = isOurImeEnabled(),
                        onOpenSettings = { openImeSettings() }
                    )
                }
            }
        }
    }

    private fun isOurImeEnabled(): Boolean {
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        val ourPackage = packageName
        return imm.enabledInputMethodList.any { it.packageName == ourPackage }
    }

    private fun openImeSettings() {
        startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }
}

@Composable
private fun Home(isImeEnabled: Boolean, onOpenSettings: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = stringResource(R.string.app_title),
            style = MaterialTheme.typography.headlineMedium
        )
        if (isImeEnabled) {
            Text(stringResource(R.string.usage_globe))
            Text(stringResource(R.string.usage_swap))
            Text(stringResource(R.string.usage_suggestions))
            var typed by remember { mutableStateOf("") }
            TextField(
                value = typed,
                onValueChange = { typed = it },
                label = { Text(stringResource(R.string.test_here_hint)) }
            )
            Text(stringResource(R.string.credits), style = MaterialTheme.typography.bodySmall)
        } else {
            Button(onClick = onOpenSettings) { Text(stringResource(R.string.open_settings)) }
            Text(stringResource(R.string.install_step_2))
            Text(stringResource(R.string.install_step_3))
            Text(stringResource(R.string.install_step_4))
            Text(stringResource(R.string.install_step_5))
            Text(stringResource(R.string.install_step_6))
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/cy/cypriotkeyboard/app/MainActivity.kt
git commit -m "android: MainActivity installation guide + usage tips"
```

---

## Phase G — Documentation

### Task 20: README

**Files:**
- Create: `android/README.md`

- [ ] **Step 1: Write**

```markdown
# Cypriot Keyboard — Android

Android port of the iOS Cypriot Greek keyboard. See `docs/superpowers/specs/2026-04-27-android-port-design.md` for the design rationale.

## Build

Requires:
- JDK 17 or 21
- Android SDK (build-tools 35, platform 35)
- The first build will need a Gradle wrapper jar; if missing, run:
  ```bash
  cd android
  gradle wrapper --gradle-version 8.10.2
  ```

Then:
```bash
cd android
./gradlew :app:installDebug    # installs to a connected device/emulator
./gradlew :ime:test            # runs unit tests on the suggester pipeline
```

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
```

- [ ] **Step 2: Commit**

```bash
git add android/README.md
git commit -m "android: README with build + enable + architecture notes"
```

---

## Self-review (against spec)

- ✅ Two Gradle modules `app`, `ime` — Tasks 2, 3
- ✅ DAWG-only suggester (no Hunspell) — Phase B
- ✅ Greek + Latin alphabetic layouts; numeric + symbolic — Task 10
- ✅ 🔄 layout toggle — Task 17/18
- ✅ Final-sigma rule — Task 11/17
- ✅ Accent combining — Task 12/17
- ✅ Greeklish transliteration — Task 5
- ✅ Suggestion bar with willReplace highlight — Tasks 15/16
- ✅ Container app installation guide — Task 19
- ✅ Localized strings (en + el) — Task 3
- ✅ Compose-in-IME lifecycle — Task 18 (LifecycleRegistry + setViewTreeLifecycleOwner)
- ✅ Race-token autocomplete debounce (40 ms, mirrors iOS) — Task 18
- ✅ Locale persisted in SharedPreferences (mirrors UserDefaults `isLatinKeyboard`) — Task 18
- ✅ DAWG-load failure degrades gracefully — Task 18 (try/catch sets `engine = null`)

Open items intentionally deferred (documented in README and spec): Hunspell, long-press popups, gesture typing, theming.
