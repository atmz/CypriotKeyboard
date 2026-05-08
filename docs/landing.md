# Marketing Landing Page

Single-page site for Cypriot Keyboard. Lives in `docs/` (next to the existing `docs/superpowers/` and `docs/privacy.md`) so GitHub Pages can serve it directly — Pages only supports `/` or `/docs` as source folders, not arbitrary paths.

Live at `https://atmz.github.io/CypriotKeyboard/` once Pages is enabled (Settings → Pages → Source: `main` branch, folder `/docs`). With a CNAME, a custom domain.

Goals: convert visitors arriving from the App Store URL share, give Greek mainland audiences (who can read Cypriot dialect) a local-feeling intro, give press something to link to.

## What's in it

- Hero with the **animated demo loop** — pure CSS+JS, no images. Cycles through `Lefkosia → Λευκωσία`, `je → τζ̆αι`, `pe je stous allous → πε τζ̆αι στους άλλους` every 5 seconds. Mirrors the in-app `DemoLoopView` so the website matches the app.
- 3 feature cards (Greeklish autocorrect / Cypriot characters / Tonos done right)
- Screenshots gallery in iPhone frames, drawn from the canonical captures in `app-store/screenshots/raw/`
- 30-second setup walk-through
- Privacy panel — leans into the "no internet, no SDKs, open source" angle
- Made-in-Cyprus credits row
- Locale toggle (EN / EL) at top — switches the entire page between English and Cypriot dialect
- Auto dark-mode via `prefers-color-scheme: dark`
- iOS Smart Banner meta tag (`apple-itunes-app`) — Safari iOS shows a "Open in App Store" banner above the page

## File structure

```
docs/
├── landing.md           # this file (notes, not served)
├── privacy.md           # privacy policy (served at /privacy)
├── index.html           # the landing page itself
├── og-card.html         # 1200×630 social-share template
├── og-card.png          # rendered share image (referenced by og:image)
├── icon/
│   ├── icon-1024.png    # apple-touch-icon + nav brand
│   └── icon-512.png
├── screenshots/
│   ├── welcome-en.png
│   ├── welcome-en-je.png
│   ├── welcome-en-allous.png
│   ├── postinstall-en.png
│   ├── welcome-el.png
│   ├── postinstall-el.png
│   └── ipad-en.png
└── superpowers/         # spec + plan archive (also served, not linked)
    ├── specs/
    └── plans/
```

Screenshots are copies of `app-store/screenshots/raw/` filtered for the marketing-relevant ones. If you re-capture for App Store Connect, copy the updates into `docs/screenshots/` too.

## Local preview

```bash
cd /Users/alext/CypriotKeyboard
python3 -m http.server 8765
# open http://localhost:8765/docs/
```

The page won't render screenshots from `file://` because the relative paths break with `file://` permissions in most browsers — always serve over HTTP.

## Deploy via GitHub Pages

1. **Settings → Pages** on the GitHub repo
2. Source: **Deploy from a branch**
3. Branch: `main`, folder: `/docs`
4. Save. Live in ~1 minute at `https://atmz.github.io/CypriotKeyboard/`.

For a custom domain (e.g. `cypriotkeyboard.app`):
1. Buy the domain
2. Add a `CNAME` file inside `docs/` containing just the domain (one line, no protocol)
3. Configure DNS: ALIAS / CNAME `<your-domain>` → `atmz.github.io`
4. GitHub Pages settings → enable "Enforce HTTPS" once provisioning finishes

## Editing copy

Most strings appear twice — once in the EN panel, once in EL. Search-replace the EN string first, find the matching EL string nearby, update both. Keep Cypriot dialect on personality lines (`τζ̆αι`, `δαμαί`) and standard Greek on imperative steps so they read clearly.

The main marketing copy is duplicated from `app-store/copy/{en,el}.md`. If you tighten copy in one place, sync the other.

## Open Graph / sharing

The `og:image` meta tag points at `./og-card.png` (1200×630). When the URL is shared on Slack/Twitter/iMessage, the card previews with title + tagline + icon.

To regenerate `og-card.png` after editing `og-card.html`:

```bash
# headless Chrome — works on macOS with Chrome installed
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --window-size=1200,630 --hide-scrollbars \
  --screenshot=docs/og-card.png \
  http://localhost:8765/docs/og-card.html
```

## What's not included

- A "What's new in 1.9" blog post — could live alongside as `docs/posts/1.9.html` if you want.
- Press contact form (would need a backend or a Formspree-style service).
- Analytics. Intentionally — keeping the privacy claim clean. If you ever want minimal usage data, [GoatCounter](https://goatcounter.com) and [Plausible](https://plausible.io) are both privacy-friendly and don't break the "no tracking" claim materially.

## Co-tenancy with `docs/superpowers/`

The `docs/superpowers/` folder contains design specs and implementation plans (committed alongside the code as part of the development process). Pages will technically serve those files too — visitors who guess paths like `/superpowers/specs/...md` will get raw markdown rendered by Jekyll. That's fine for an open-source repo, but if you'd rather not expose those, add a `_config.yml` exclude:

```yaml
exclude:
  - superpowers
```
