# BrowserDaddy — project status

## 2026-09-20 — daddy-series update stack

BrowserDaddy now shares the daddy-series structure and Sparkle update stack
with storagedaddy and performancedaddy (issue
sarthakagrawal927/storagedaddy#30): Sparkle 2.9.6 pinned, `AppUpdates` defers
checks and relaunches while a history sync is in flight, update items live in
the app menu, `SU*` keys are injected at packaging by
`scripts/package-release.py`, and `scripts/{sparkle_support,prepare-appcast,
test_sparkle_support}.py` match the sibling repos. An updates-only Worker owns
`browserdaddy.significanthobbies.com/updates/*` — deployed and verified live
alongside the ios-landings Pages site; the feed is a dormant empty channel
until the first release publishes an enclosure via `prepare-appcast.py`, which
gates on a signed, notarized, stapled DMG plus SHA256SUMS. EdDSA signing key
`browserdaddy-updates` stays in Keychain; only the public key is committed.
CI parity added (`swift test`, release build, sparkle unittest, worker test).
All package tests plus sparkle and worker tests pass.

## 2026-09-20 — expandable history, retagging and composable filters

History now combines text, browser, browser/profile, rolling date range,
effective category and tag-state filters in one parameterized local query.
Rows disclose source, exact visit time, full URL, separate page/domain categories
and whether each tag came from the user or classifier.dev. A visible Retag sheet
supports exact-page, exact-domain and registrable-domain overrides plus scoped
clearing. These operations change only derived archive metadata; they never edit
browser history or make a network request. Optional external classification stays
separate in Permissions behind consent v2.

Synthetic native verification covered expansion, accessible labels, scope switching,
filter menus/count/clear behavior and a saved local tag immediately leaving the
active untagged result set. No personal browsing data or real classifier request was
used. The design receipt passes in preserve mode and all 30 tests pass. Source is
pushed at `fc5a59f` and a universal Developer ID signed 0.2.1 build 4 candidate has
valid hardened-runtime sandbox entitlements and macOS 14 arm64/x86_64 slices.

Apple accepted app submission `cceadcd6-cb7d-4be4-93a8-5a79316d4657` and final
DMG submission `e559de82-4470-4766-87bd-adfdad583e0c`. Both artifacts were stapled
and Gatekeeper accepted them as Notarized Developer ID. The signed `v0.2.1-4` source
tag points at `fc5a59f`; its private GitHub release contains the final DMG and checksum
(`5672146c820c2044beb94065650bd69b91709a705f255eb8fd9e423efba42c17`). Installed
BrowserDaddy is now 0.2.1 build 4; the prior app bundle is recoverably retained under
`.build/BrowserDaddy-0.2.0-3-before-0.2.1.app`. The sandbox archive was not replaced;
its SQLite integrity check passes with 109,698 visit rows and 524 focus rows. Tracking:
GitHub issue #5.

## 2026-09-20 — browser-scoped folder grants

BrowserDaddy no longer requests Full Disk Access or scans browser locations
implicitly. Each connected browser uses a user-selected, read-only,
security-scoped folder bookmark. Discovery is restricted to that resolved root,
rejects symlink escapes and validates that the folder contains the expected
history database before persisting a grant. Disconnect stops future reads while
preserving already archived rows. The release entitlement set now enables App
Sandbox, read-only user-selected files, app-scoped bookmarks, outbound networking
for the optional classifier, and the Chrome-only Apple Events exception.

The first sandboxed release includes Apple's container migration manifest for the
existing BrowserDaddy Application Support directory. A separate sandbox probe
using a synthetic Chromium database verified onboarding, persistent bookmark
resolution after relaunch, extraction, and archive retention after disconnect.
No personal browser folder was selected or personal screenshot captured. All 26
Swift package tests pass.

Universal 0.2.0 build 3 was Developer ID signed, notarized and stapled. Apple
accepted the app submission `5dcba543-bb61-4907-8951-23d84fe6d15c` and final DMG
submission `d3dc616b-2430-47e3-8caf-3600f13fa83e`; Gatekeeper accepted both. The
installed 0.1.0 app and archive were backed up before replacement. On first launch,
macOS moved the archive into the stable sandbox container; SQLite integrity passed
and aggregate rows matched the backup (with one expected new focus row after the
watcher started). The legacy archive backup remains under Application Support.
Installed 0.2.0 build 3 launched as PID 82508 and remained running. Tracking:
GitHub issue #4. Actual browser-folder selection and owner-observed Chrome
normal/private-window acceptance remain before any public download.

## 2026-09-20 — signed native candidate and corrected optional consent

Owner approved optional external classification with accurate, revocable consent.
Consent v2 discloses hostnames, truncated titles and paths, network-address exposure,
and that sent data cannot be recalled. Requests are not described as anonymous.
Legacy opt-ins require renewal; revocation cancels the retained task and prevents
remaining requests. Response shape/label/confidence validation fails closed, including
extra/missing result counts. URL credentials/query/fragment are excluded from URL
hints; the remaining text may still contain personal information. Local features
remain independent. A failed archive open now shows recovery guidance instead of
force-crashing. Twenty-two synthetic tests pass; no real classification request was made.

Universal 0.1.0 build 2 targets macOS 14 (both Mach-O slices verified), uses the
Tab Scout icon and stable `com.significanthobbies.browserdaddy` release identity,
and is Developer ID signed with hardened runtime and the Apple Events entitlement.
Apple notarization `bfe584c6-13cf-4b44-8622-49152ce6f564` was Accepted. App and DMG
stapling and Gatekeeper checks passed. Installed app signature/ticket verified;
native launch returned PID 65420 and the process remained running on follow-up.
The old development app bundle is preserved under `.build/pre-release-app-backup-20260920/`.
No archive was deleted/replaced, permission grants approved, or personal screenshots taken.

This is a native prerelease candidate, not a fully qualified public release.
Real private-window exclusion and new-identity permission-flow acceptance remain;
no public landing download is enabled. Tracking: GitHub issue #3.

## 2026-09-20 — Tab Scout brand integration

Owner delegated the choice after three visual systems. Tab Scout now owns the
native compact mark, larger artwork and macOS icon, with independent copies in
ios-landings. Existing black/mint controls and the Editorial landing are preserved.
`scripts/build-icon.sh` regenerates native ICNS representations. Source assets
were generated with the built-in image tool; no personal browsing screenshots
were used. Landing inspected at 390, 768 and 1440px. Independent scoped reviews:
36.7/40 visual (normalized), 18/20 technical, 92/100 landing comprehension;
no branding P0/P1 found. This is not native release/privacy qualification.


## 2026-09-20 — bounded privacy fixes; release still blocked

Collection now waits for onboarding completion and starts only once. Keyboard
history sync cannot bypass onboarding. Chrome tab capture checks its immutable
window mode before reading tab URL/title; unavailable/private captures immediately
close the old URL segment. Other browsers remain app-only until their private
window detection is qualified, and do not receive unnecessary automation probes.
The report test now uses a synthetic temporary archive, never the user's real DB.
All 15 Swift package tests pass, including onboarding, capture policy, persisted
segment transitions and report fixtures. Chrome mode semantics were checked in
the installed scripting dictionary; real private-window runtime acceptance is
still outstanding. No personal archive was read for testing.

Native release remains blocked: the optional external classifier conflicts with
the written no-network policy, its disclosure omits transmitted paths, and opt-out
does not cancel an in-flight batch. Owner asked to choose local-only or a qualified
optional-network boundary. No app was signed, notarized, installed or released.
The historical privacy blocker above was addressed by the later consent-v2 candidate;
runtime acceptance remains. Tab Scout was subsequently selected and integrated.

## Current state

Native macOS app (SwiftUI + SwiftPM), forked from the storagedaddy/
performancedaddy template: `BrowserCore` library + `BrowserDaddy`
executable + XCTest. StorageDaddy visual language throughout — black
surfaces, mint accent, banded cards, doodle artwork.

Prototype reference at ~/browserdaddy/ (Python): extract.py, watch.py,
stats.py and its historical archive. The app ports that pipeline natively.
The stable native archive is migrated into the sandbox container on the first
sandboxed release launch.

Repo: github.com/sarthakagrawal927/browserdaddy (private).
Tracking: issue #1.

## Features (shipped)

**Collection**
- BrowserCore: SQLite store (recursive-locked, Sendable-safe), archive
  schema (visits/searches/focus/meta/domain_categories/page_categories),
  merge-dedupe on (browser, profile, visit_id)
- Discovery below explicitly connected, read-only browser roots only;
  Chromium profiles, Firefox and Safari; symlink-escape rejection and
  snapshots past SQLite locks
- Three engine extractors + epoch normalization; omnibox search terms
- FocusWatcher: NSWorkspace frontmost polling + AppleScript tab URL +
  CGEventSource idle gating → focus segments (2s ticks, 60s idle,
  3-miss tolerance, real elapsed dt, blip dropping, name map)
- Auto-extract on boot + every 6h (launchd not required)

**App surfaces**
- Onboarding: per-browser folder grants, automation explainer, honest-collection
  summary, opt-in tagging (one-shot, until meta.onboarded)
- Attention page: NOW (live app+tab), per-day timeline strip, WHERE IT
  GOES (apps/sites, active vs open), PATTERN (hourly)
- Dashboard: verdict, CHANGED LATELY (biggest MTD shifts), SPOT CHECK
  (per-domain month-to-date verdict + 60d sparkline + focus delta),
  TIMELINE (Day/Week/Month stacked by browser), MOVERS, TRENDS
  (focus/day, cumulative domains, new domains, novelty %, night-owl
  share, per-domain monthly), CATEGORIES + TOPICS (classifier.dev),
  SITES, DEEP READ (active-min per visit), HEATMAP (dow×hour),
  PROFILES (per-source hourly), DAYS (busiest, streaks, gaps, dow
  matrix), DAY EDGES (first/last site of day), HABITS (daily fixtures,
  return speed), DEPTH (concentration), SHARED (cross-browser),
  PACE (switch rate, median span), SESSIONS, SEARCHES
- History: search + per-browser filter
- Permissions: per-browser Connect/Change/Disconnect, Automation state, sync trigger,
  launch-at-login, TAGGING toggle + Tag button
- Global filters: source (browser/profile) + range (7/30/90d/all) —
  every band honors them; all grouping in local time

**Classification (classifier.dev, opt-in)**
- Batch scripts + in-app Classifier (the app's only network call,
  consent-gated via meta.classify_optin)
- Enriched inputs: domains send top page titles, pages send
  host/path/title; labels upgrade only when confidence improves
- Coverage: 4,048 domains (93% of visits), 35k pages (90% of visits)

## Boundaries

- Local-only by default; classification is opt-in and sends domain
  names / page titles only
- Private browsing is never reconstructed; visits ≠ attention — focus
  data is the real attention signal and only exists from watcher start
- Sandboxed and read-only on user-selected browser stores; no Full Disk Access,
  launchd requirement or implicit home-directory discovery; native APIs only

## Known thin spots / next steps

- Free-tier classifier quota throttles bulk re-runs; incremental is fine
- ~1.2k long-tail domains still <0.5 confidence — swept on next tag run
- from_visit chains stored but unexploited (navigation trees = next
  feature)
- Dashboard is long; could split into sub-pages if it grows further
- Python launchd agents can be retired once app grants are confirmed:
  `launchctl bootout gui/$UID/com.browserdaddy.{watch,extract}`
