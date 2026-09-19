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
