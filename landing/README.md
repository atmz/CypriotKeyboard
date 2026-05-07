# Marketing Landing Page

Single-page site for Cypriot Keyboard. Lives in `landing/` so it can deploy as the project's GitHub Pages site at `https://atmz.github.io/CypriotKeyboard/landing/` (or with a CNAME, a custom domain).

Goals: convert visitors arriving from the App Store URL share, give Greek mainland audiences (who can read Cypriot dialect) a local-feeling intro, and give the press something to link to.

## What's in it

- Hero with the **animated demo loop** — pure CSS+JS, no images. Cycles through `Lefkosia → Λευκωσία`, `je → τζαι`, `pe je stous allous → πε τζαι στους άλλους` every 5 seconds. Mirrors the in-app `DemoLoopView` so what you see on the website matches what you'll see in the app.
- 3 feature cards (Greeklish autocorrect / Cypriot characters / Tonos done right)
- Screenshots gallery in iPhone frames, drawn from the canonical 6.9" captures
- 30-second setup walk-through
- Privacy panel — leans into the "no internet, no SDKs, open source" angle
- Made-in-Cyprus credits row
- Locale toggle (EN / EL) at top — switches the entire page between English and Cypriot dialect
- Auto dark-mode via `prefers-color-scheme: dark`
- iOS Smart Banner meta tag (`apple-itunes-app`) — Safari iOS shows a "Open in App Store" banner above the page

## File structure

```
landing/
├── README.md            # this file
├── index.html           # the whole site, HTML+CSS+JS in one file
├── icon/
│   ├── icon-1024.png    # used as <apple-touch-icon> + nav brand
│   └── icon-512.png
└── screenshots/
    ├── welcome-en.png            # iPhone 17 Pro Max, Lefkosia frame
    ├── welcome-en-je.png
    ├── welcome-en-allous.png
    ├── postinstall-en.png
    ├── welcome-el.png
    ├── postinstall-el.png
    └── ipad-en.png
```

Screenshots are copied from `app-store/screenshots/raw/` so the landing page stays in sync with the App Store assets. If you re-capture, copy the new files into `landing/screenshots/` too — there's no symlinking because Pages doesn't follow them.

## Local preview

```bash
cd /Users/alext/CypriotKeyboard
python3 -m http.server 8765
# open http://localhost:8765/landing/
```

The page won't render screenshots from `file://` because the relative paths break with `file://` permissions on some browsers — always serve over HTTP.

## Deploy via GitHub Pages

1. **Settings → Pages** on the GitHub repo
2. Source: **Deploy from a branch**
3. Branch: `marketing-landing`, folder: `/landing`
4. Save. Live in ~1 minute at `https://atmz.github.io/CypriotKeyboard/`.

Or, if you'd rather have it on `main`:
- merge this branch to main first
- then in Settings → Pages, choose `main` / `/landing` as the source

For a custom domain (`cypriotkeyboard.app`, `kypriako.com`, etc.):
1. Buy domain
2. Add a `CNAME` file inside `landing/` with the domain
3. Configure DNS to point at `<username>.github.io`
4. GitHub Pages settings → enable HTTPS

## Editing copy

Most strings appear twice — once in the EN panel, once in EL. Search-replace the EN string first, find the matching EL string nearby, update both. Keep the Cypriot dialect on personality lines (`τζαι`, `δαμαί`) and standard Greek on imperative steps so they read clearly.

The main marketing copy is duplicated from `app-store/copy/{en,el}.md`. If you tighten copy in one place, sync the other.

## Open Graph / sharing

The `og:image` meta tag points at `./icon/icon-1024.png` — when the URL is shared on Slack/Twitter/iMessage, the icon previews. For a richer share image (a "card" with title and tagline), generate one and replace the meta tag — `og:image` should ideally be 1200×630 for Twitter / OG card consumers.

## What's not included

- A "What's new in 1.9" blog post — could live alongside as `landing/posts/1.9.html` if you want.
- Press contact form (would need a backend or a Formspree-style service).
- Analytics. Intentionally — keeping the privacy claim clean. If you ever want minimal usage data, [GoatCounter](https://goatcounter.com) and [Plausible](https://plausible.io) are both privacy-friendly and don't break the "no tracking" claim materially.
