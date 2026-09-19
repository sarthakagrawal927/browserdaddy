# browserdaddy

Native, local-only macOS browsing-intelligence app — unified cross-browser
history archive + real attention tracking.

## Development

```sh
swift build                    # build all targets
swift test                     # run tests
scripts/run-local.sh           # build + bundle + launch .build/BrowserDaddy.app
```

Layout: `Sources/BrowserCore` (archive, extraction, watcher, report engine),
`Sources/BrowserDaddy` (SwiftUI app), `Tests/` (XCTest).

Data lives at `~/Library/Application Support/BrowserDaddy/browserdaddy.db`.
Requires Full Disk Access (history reads) and per-browser Automation consent
(tab URL reads). See PRODUCT.md for scope and AGENTS.md for boundaries.

## Grant flow (first launch)

1. Launch `.build/BrowserDaddy.app` (or `scripts/run-local.sh`).
2. **Permissions → Full Disk Access**: add BrowserDaddy in System Settings →
   Privacy & Security → Full Disk Access, relaunch. Without it, history
   extraction reports each store as blocked (visible in Permissions + log).
3. **Automation**: focus a browser; approve "BrowserDaddy wants to control X"
   once per browser. Permissions shows per-browser state.
4. First launch also imports the python archive at
   `~/browserdaddy/out/browserdaddy.db` (~109k visits) — one-time, flagged
   in `meta`.

Until the app holds its own grants, the python launchd agents stay as
backstop collectors (they write to the python DB — importer already covers
the handoff). Disable them once the app is verified:
`launchctl bootout gui/$UID/com.browserdaddy.watch` and
`com.browserdaddy.extract`.
