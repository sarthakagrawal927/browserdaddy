# browserdaddy

Native, local-only macOS browsing-intelligence app — unified cross-browser
history archive + real attention tracking.

## Development

```sh
swift build                    # build all targets
swift test                     # run tests
scripts/run-local.sh           # build + bundle + launch .build/BrowserDaddy.app
scripts/classify-domains.sh    # batch-tag archive domains (opt-in, manual)
scripts/classify-pages.sh      # batch-tag archive pages (opt-in, manual)
```

Layout: `Sources/BrowserCore` (archive, extraction, watcher, report engine,
classifier), `Sources/BrowserDaddy` (SwiftUI app), `Tests/` (XCTest).

Data lives at `~/Library/Application Support/BrowserDaddy/browserdaddy.db`.
See PRODUCT.md for scope and AGENTS.md for boundaries.

## First launch

Onboarding runs once: Full Disk Access (System Settings → Privacy &
Security), per-browser Automation consent when you focus each browser,
and an optional topic-tagging opt-in. Archive extraction runs on boot
and every 6h; the focus watcher runs while the app is alive. First boot
also imports the python archive at `~/browserdaddy/out/browserdaddy.db`.

Classification (classifier.dev) is the app's only network call and only
runs when you allow it — in onboarding or via Permissions → TAGGING.
Everything else is on-device.

Until the app holds its own grants, the python launchd agents stay as
backstop collectors. Retire them once verified:
`launchctl bootout gui/$UID/com.browserdaddy.watch` and
`com.browserdaddy.extract`.
