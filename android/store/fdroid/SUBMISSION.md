# F-Droid submission

**SUBMITTED 2026-07-05:**
<https://gitlab.com/fdroid/fdroiddata/-/merge_requests/42167>
(from fork `alex.toumazis/fdroiddata`, branch `cy.cypriotkeyboard.app`)

Note: fork CI can't run (new GitLab account, shared runners want payment
validation) — the MR asks maintainers to trigger CI, which the template
explicitly sanctions. Watch the MR for the pipeline result and reviewer
questions.

Verified locally on 2026-07-05: a clean clone builds
`app-release-unsigned.apk` with no keystore.properties present, which is
exactly what F-Droid's build server does.

## Prerequisites (done)

- [x] GPL-3.0 `LICENSE` at repo root
- [x] Release build works unsigned from a clean checkout
- [x] No proprietary dependencies (pure AndroidX/Compose; no Play
      Services, no analytics, no INTERNET permission)
- [x] Metadata file drafted: `cy.cypriotkeyboard.app.yml` (this folder)
- [ ] Git tag `android_v1.1` pushed (F-Droid builds from tags)

## Filing the merge request

1. Create a GitLab account (or sign in): https://gitlab.com
2. Fork https://gitlab.com/fdroid/fdroiddata
3. In your fork, create `metadata/cy.cypriotkeyboard.app.yml` with the
   contents of the YAML file in this folder (GitLab web editor is fine —
   no local checkout needed).
4. Open a merge request against `fdroid/fdroiddata:master` titled:
   `New app: Cypriot Keyboard (cy.cypriotkeyboard.app)`
5. Paste this as the MR description:

   > Cypriot Greek keyboard IME (Greek + Greeklish input, on-device
   > autocorrect). GPL-3.0, no proprietary dependencies, and the app has
   > no INTERNET permission at all.
   >
   > Note on the binary asset: `android/ime/src/main/assets/el_CY.dawg`
   > (~49 MB) is a *data* file — a compiled dictionary (DAWG) of Cypriot
   > Greek words, not executable code. It is generated from the
   > `dict_generation/` sources in the same repo (format documented in
   > `dict_generation/DAWG_FORMAT.md`).
   >
   > Android project lives in the `android/` subdir of a repo shared
   > with the iOS app; `subdir: android/app` is set accordingly.

6. The bot (fdroid-bot) will run a test build on the MR; watch for its
   comment. Reviewers may ask questions on the MR — typical turnaround
   is days to a few weeks.

## Alternative: RFP (if you'd rather not write the MR)

Open an issue at https://gitlab.com/fdroid/rfp/-/issues with the app
name, repo URL, and license — a volunteer packager picks it up. Slower,
but zero effort.

## Per-release maintenance (after inclusion)

`AutoUpdateMode: Version` + `UpdateCheckMode: Tags ^android_v` means
F-Droid picks up new releases automatically when you push a tag matching
`android_v*` whose build.gradle.kts has a bumped versionCode/versionName.
No manual MR needed per release — just tag as part of the normal flow in
store/RELEASE.md.
