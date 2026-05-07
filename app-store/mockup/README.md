# App Store Listing Mockup

Self-contained HTML preview of how the Cypriot Keyboard App Store listing would look with the v1.9 marketing assets.

## What's in it

- App Store-style hero (icon, name, subtitle, "Get" button, star rating)
- Key facts strip (Age, Category, Developer, Languages)
- Screenshots **carousel** — un-framed, exactly as Apple displays them
- About this app — full description (collapsible "more")
- What's New — version 1.9 changelog
- Marketing/press section — same screenshots **wrapped in iPhone device frames** for blog posts, social, press kits
- Information grid (provider, size, compatibility, copyright, etc.)
- Locale toggle at the top — switches en/el (Cypriot dialect)

## How to view

The mockup uses relative paths into `../screenshots/raw/`, so it needs to be served (file:// won't load the screenshots due to CORS).

```bash
cd /Users/alext/CypriotKeyboard
python3 -m http.server 8765 --directory app-store
# then open http://localhost:8765/mockup/
```

## Editing

Everything is in one `index.html`. Copy comes from `app-store/copy/{en,el}.md` — edit there first, then sync the mockup so they don't drift. Star ratings, install count, "1d ago" are placeholder.

## Why not Frameit?

Tried `gem install fastlane` — failed on this machine because Ruby 2.6 is too old (`domain_name` dep needs Ruby ≥2.7). Two ways forward:

1. **Use Homebrew Ruby** — `brew install ruby`, prepend its bin to PATH, then `gem install fastlane`. Then run frameit on `app-store/screenshots/edited/{en-US,el-CY}/` (already staged with the right files).
2. **Stay with the HTML mockup** — the framed-iPhone CSS section in this mockup serves the same purpose for press / social / blog use. Right-click → Save Image on any framed iPhone to get a usable PNG.

`app-store/screenshots/edited/{en-US,el-CY}/` is staged for option 1 if you choose to install fastlane later.
