# Privacy Policy — Cypriot Keyboard

_Last updated: 2026-04-29_

This document describes the data practices of **Cypriot Keyboard** (the
"app"), an Android input-method app that lets you type Cypriot Greek using
either a Greek alphabetic layout or a Greeklish (Latin → Greek)
transliteration layout.

## What we collect

**Nothing.**

The app does not transmit any data over the network. It contains no
analytics SDKs, no crash-reporting SDKs, no advertising SDKs. The
`AndroidManifest.xml` requests no INTERNET permission; the app cannot
reach the network even if it tried.

## What we store on your device

A single key, `isLatinKeyboard`, in the app's private SharedPreferences,
recording whether you last left the keyboard on the Greek or the Latin
(Greeklish) input row. This file lives at
`/data/data/cy.cypriotkeyboard.app/shared_prefs/cypriot_keyboard.xml` on
your device and is readable only by the app itself. Nothing else is
persisted.

## What you type

Keystrokes flow only between you and the active text field. The app
processes each typed word locally to compute autocorrect suggestions
against a bundled dictionary (`el_CY.dawg`, included inside the APK).
**No keystrokes leave your device.** No keystrokes are logged, retained,
buffered, or shared with anyone, including us.

## Permissions

The app declares only `BIND_INPUT_METHOD`, the Android system permission
required of every input-method app so the OS can route keystrokes to it.
No other permissions are requested. The app cannot read your contacts,
your location, your camera, your microphone, your photos, or your
network. The app cannot start at boot, run as a foreground service, or
access other apps' data.

## Children

The app does not target children under 13 and does not knowingly collect
data from anyone of any age. Since no data is collected, COPPA / GDPR-K
considerations do not apply.

## Open source

The app's source is available at <https://github.com/atmz/CypriotKeyboard>
under GPL-3.0. You can verify all of the above by reading the source.

## Contact

Questions or concerns: alex.toumazis@gmail.com
