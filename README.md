# browserdaddy

Native, local-first macOS browsing-intelligence app — unified cross-browser
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

Onboarding runs once: read-only folder selection for each browser you choose,
Chrome Automation consent for qualified normal-window tab capture, and an
optional topic-tagging opt-in. Browser folder grants are stored as revocable,
app-scoped security bookmarks. Full Disk Access is neither requested nor
required. Archive extraction runs on boot and every 6h; the focus watcher runs
while the app is alive.

Classification (classifier.dev) is the app's only network call and only
runs when you allow it — in onboarding or via Permissions → TAGGING.
Everything else is on-device.

History search composes browser, profile, date-range, category and tag-state
filters. Click a visit to expand its local evidence, then use **Retag** to apply
or clear a page, exact-domain or whole-site override. Local retagging never calls
classifier.dev and never modifies the browser's own history. Optional external
classification remains a separate consent-gated action in Permissions.

The current consent discloses domain names, truncated page titles and URL paths.
These requests are not anonymous: text can contain personal information and the
service receives the network address. URL credentials, query strings and fragments
are excluded. Old consent requires renewal. Opt-out cancels active requests and
remaining batches, but cannot recall data already sent. Existing local tags remain.

Use `scripts/run-local.sh --preview-fixture` for a synthetic History workspace
that contains no personal browsing data.

## Native release

Tracking: https://github.com/sarthakagrawal927/browserdaddy/issues/3

Build and test with XcodeBuildMCP using this Swift package path. Set session
configuration to Release and build arm64 + x86_64. Verify both Mach-O minimum
OS versions and architectures before using `scripts/package-release.py`.
The script requires a fresh output directory and an existing Developer ID identity;
it signs an isolated candidate, never installs or publishes it. Notarization,
stapling, Gatekeeper checks and native runtime qualification are separate gates.
Release bundles use `com.significanthobbies.browserdaddy`; development uses `.dev`.
Moving from development to release may require new user-granted permissions.
The release is sandboxed. `Support/container-migration.plist` moves the existing
BrowserDaddy Application Support folder into the stable app container on its
first sandboxed launch; packaging must retain that resource. Release qualification
must take a recoverable backup before that first launch.

Until the app holds its own grants, the python launchd agents stay as
backstop collectors. Retire them once verified:
`launchctl bootout gui/$UID/com.browserdaddy.watch` and
`com.browserdaddy.extract`.
