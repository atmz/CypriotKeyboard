# Play Store release checklist

This file walks through everything needed to publish the Cypriot Keyboard
to the Google Play Store and to ship subsequent updates. Most steps are
one-time setup.

## Files in this directory
- `privacy.md` — privacy policy. Host this somewhere reachable (e.g.
  GitHub Pages on a `gh-pages` branch). The Play Console requires a public
  URL for the data-safety form.
- `listing-en.md`, `listing-el.md` — store listing copy in English and
  Greek. Paste into the Play Console's "Main store listing" → "App
  details" pages, one per language.

## One-time setup

### 1. Sign up for the Play Console ($25)
<https://play.google.com/console>. Pick a personal or organisation account.

### 2. Host the privacy policy
The simplest path: push `privacy.md` to a GitHub Pages branch and convert
to HTML. Example:

```bash
git checkout -b gh-pages
mkdir -p docs && cp android/store/privacy.md docs/privacy.md
# add a one-line index.html that redirects to privacy.md, or use
# Jekyll's default behaviour
git add docs && git commit -m "publish privacy policy"
git push origin gh-pages
```

Then in the GitHub repo settings → Pages, point to `gh-pages` / `/docs`.
The URL ends up at `https://<your-user>.github.io/CypriotKeyboard/privacy`.

### 3. Create the app entry in the Play Console
- App name: **Cypriot Keyboard — Κυπριακά** (en-US default)
- Default language: English (United States)
- App or game: App
- Free or paid: Free
- Confirm policies — Standard

After creation, configure these sections in the left sidebar:

#### Main store listing (per language)
- Languages: English (United States) + Greek (Greece) at minimum. For Greek,
  override the App name to **Κυπριακό Πληκτρολόγιο**.
- Paste short description and full description from `listing-en.md` and
  `listing-el.md`.
- App icon: upload a 512×512 PNG export of the launcher icon. (Easiest: open
  the in-app icon in Android Studio's icon studio and export at 512 px,
  or render `app/src/main/res/drawable/ic_launcher.xml` to PNG via any
  vector → raster tool.)
- Feature graphic: 1024×500 PNG. Suggested: white background, Cyprus copper
  accent strip, the kappa glyph + tagline.
- Screenshots: 2-8 phone screenshots showing the keyboard in use. Capture
  with the Android Studio device-frame tool: open the running emulator,
  Tools → Device Manager → camera icon, frame, save.

#### Privacy policy
URL of the page from step 2.

#### App content
- Privacy policy URL: as above.
- App access: app is fully usable without login or restrictions.
- Ads: none.
- Content rating: complete the questionnaire. The keyboard has no
  user-generated content visible to others — answer "no" to all
  violence/language/etc. questions. You'll get **Everyone** / **PEGI 3**.
- Target audience: 13+ is the safest declaration; the app doesn't target
  children but is suitable for any age.
- Data safety: declare zero collection. No data collected, no data shared,
  encrypted in transit (vacuously true), users can request deletion (no
  data exists, so trivially yes).

#### App category and tags
- Category: **Tools** (or Productivity).
- Tags: keyboard, ime, greek, cypriot, transliteration.

### 4. Set up Internal Testing
Left sidebar → Testing → Internal testing → Create new release.
- Add testers by Google Account email (up to 100). Make a Google Group if
  you want a stable list.
- Upload `app/build/outputs/bundle/release/app-release.aab`.
- Release name: same as `versionName` (1.0.0).
- Release notes: copy from the "What's new" section of `listing-en.md`
  / `listing-el.md`.
- Roll out — review is usually minutes for internal track.

Testers visit the opt-in link, click "Become a tester", and the app
appears on Play Store search for them. Updates auto-install like a normal
Play app.

## Per-release flow

1. Bump `versionCode` (integer, MUST increase) and `versionName` (human-readable)
   in `android/app/build.gradle.kts`.
2. From `android/`: `./gradlew :app:bundleRelease`.
3. Output is `app/build/outputs/bundle/release/app-release.aab`.
4. Play Console → Internal testing → Create new release → upload the AAB
   → write release notes → Save → Review release → Roll out.
5. (Optional) From Internal testing, promote to Closed → Open → Production
   when comfortable. Each track adds review time and tester rules.

## F-Droid (planned, after Play production launch)

Requested by testers on Reddit (degoogle crowd). The app is an unusually
good fit: GPL-3.0, no Google/proprietary dependencies, no Play Services,
no INTERNET permission. Steps when we get to it:

1. Tag a release in the GitHub repo (e.g. `android_v1.1`) — F-Droid
   builds from tags, not branches.
2. Fork <https://gitlab.com/fdroid/fdroiddata>, add
   `metadata/cy.cypriotkeyboard.app.yml` with `subdir: android/app`,
   the gradle flavor, and the tag; open a merge request.
3. F-Droid signs builds with their own key by default — that's fine and
   independent of our Play keystore. (Reproducible builds + our own
   signature is optional polish, not required.)
4. Review queue is typically a few weeks; the 49 MB DAWG asset is fine
   (F-Droid has no size gate).

Note: F-Droid installs do NOT count toward Play's 12-tester requirement.

## Things that will fail Play review (and how to avoid)

- **Missing privacy policy URL** for an IME → mandatory. Step 2 above.
- **Missing data safety form** → mandatory.
- **`android:debuggable="true"` in the merged manifest** → never. We don't
  set it; AGP only adds it for debug builds. Verify by inspecting
  `app-release.aab` (extract → `BundleConfig.pb` doesn't contain debug).
- **Reusing the debug keystore** → use the release keystore at
  `cypriot-release.jks`. The signing config in `app/build.gradle.kts`
  uses the gitignored `keystore.properties`.
- **Targeting an outdated SDK** → we're at compileSdk/targetSdk = 36 as of
  2026-04-29. Play raises the floor every August; bump and re-release if
  flagged.

## Critical: keystore backup

`cypriot-release.jks` and `keystore.properties` (both in `android/`, both
gitignored) are the ONLY way to sign updates to this app. Lose them and
the Play app is effectively bricked — Play will not accept a
re-signed-with-different-key upload. Back both up to two independent
locations.
