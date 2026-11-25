# Satellite

By Warhound. Orbit's sibling: a feed reader for iPhone. SwiftUI and SwiftData, iOS 17+, needs Xcode 16 or later.

Screenshots appear in `docs/screenshots` after running Actions → iOS build → Run workflow with screenshots ticked.

## What it does

- One screen. The newest unread article fills it; swipe left for the next, right to go back.
  Articles are marked read as they're shown and stay in the run, so swiping back always works.
- Only the last 7 days count as unread (3, 7, 14 or 30 in Settings). Older articles drop out
  without being marked read, so time away never leaves a pile.
- New articles found while you read go straight after the one on screen. Back after half an
  hour or more, you start a fresh run.
- Add a site by pasting its address: Satellite finds the feed (RSS, Atom, RSS 1.0 or JSON Feed).
  Import and export OPML.
- Feeds that only carry a summary: tap the page icon, or turn on Always Load Full Article for the
  source. Satellite fetches the web page and keeps the text, using Mozilla's Readability on the
  phone. No server.
- Save articles to read again. Share, or open in Safari.
- Checks feeds when opened (if it's been 15 minutes), when you pull down in Sources, and in the
  background. Unchanged feeds cost almost nothing: requests carry ETag and Last-Modified.
- Orbit's ten colour themes and appearance choice, with matching app icons; San Francisco or
  New York for article text, at eight sizes on top of the iOS text size.

The mark is a dish made from Orbit's own ring: the half opposite Orbit's gap, with the feed dot
exactly where Orbit's satellite sits. All ten themes: `design/icon-themes.png`. The options that
were considered are in `design/logo-options/`.

Not built yet: a share extension ("Follow in Satellite" from Safari), search, folders, Spotlight, iPad layout tuning.

## Run on your Mac

    git clone -b claude/focused-volta-9s1swz https://github.com/tom-landy/Satellite.git
    cd Satellite
    open Satellite.xcodeproj

Pick an iPhone simulator in the toolbar and press Cmd+R. To see the app full of sample articles,
Product → Scheme → Edit Scheme → Run → Arguments, and add `-demo`.

Running on your iPhone and TestFlight: [docs/DEPLOYING.md](docs/DEPLOYING.md). The bundle ID is
`com.warhound.satellite`, set once as `SATELLITE_BUNDLE_ID` in the project's build settings.

## Layout

    Satellite/
      SatelliteApp.swift     app entry, storage, refresh on open and in the background
      FeedKit/               feed parsing (RSS, Atom, RDF, JSON Feed), discovery, fetching, OPML.
                             Foundation only, so it builds outside the app and can become a
                             package shared with Orbit
      Models/                Source, Article (SwiftData)
      Services/              refresh and merge, the reading run, full-text extraction
      Reader/                the swipe pager, article pages and how they're rendered
      Views/                 sources, add, import, settings, welcome, themes and logo
      DemoData.swift         sample articles for screenshots (-demo)
    Satellite-Info.plist     background refresh, OPML file type
    design/                  logo template, theme colours, icon renderer
    tools/feedtest/          offline parser tests with fixtures
    tools/feedcheck/         parser and discovery against real feeds
    tools/readability/       Mozilla Readability and the script that embeds it

FeedKit's tests run without Xcode, on a Mac or on Linux:

    swiftc Satellite/FeedKit/*.swift tools/feedtest/main.swift -o /tmp/feedtest && /tmp/feedtest tools/feedtest/fixtures

To change the logo or add a theme: edit `design/logo-template.svg` or `design/themes.json`,
run `node design/render-icons.js` (needs Playwright) to regenerate every app icon, and mirror
the change in `Satellite/Views/AccentTheme.swift` (colours and the in-app `LogoView`).

The Xcode project uses a synchronised folder, so any file added under `Satellite/` is picked up
automatically with no project-file edits.

Version: shown in Settings → About. Run `tools/bump-version.sh` before committing an update
(0.1 → 0.2, build number in step).

`.github/workflows/ios.yml` runs the feed tests and builds for the simulator on every push.
Running it by hand can also take screenshots and commit them to `docs/screenshots`.
`.github/workflows/testflight.yml` archives, signs and uploads to TestFlight (run by hand).
