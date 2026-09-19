# BrowserDaddy — project status

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
stats.py, out/browserdaddy.db (~109k archived visits). The app ports
that pipeline natively and imports the existing archive DB on first boot.

Repo: github.com/sarthakagrawal927/browserdaddy (private).
Tracking: issue #1.

## Features (shipped)

**Collection**
- BrowserCore: SQLite store (recursive-locked, Sendable-safe), archive
  schema (visits/searches/focus/meta/domain_categories/page_categories),
  merge-dedupe on (browser, profile, visit_id)
- Discovery: all Chromium roots + profiles (stat-probe fallback),
  Firefox, Safari; snapshot past SQLite locks
- Three engine extractors + epoch normalization; omnibox search terms
- FocusWatcher: NSWorkspace frontmost polling + AppleScript tab URL +
  CGEventSource idle gating → focus segments (2s ticks, 60s idle,
  3-miss tolerance, real elapsed dt, blip dropping, name map)
- Auto-extract on boot + every 6h (launchd not required); first-boot
  import of the python archive

**App surfaces**
- Onboarding: FDA grant step, automation explainer, honest-collection
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
- Permissions: FDA status, per-browser Automation state, sync trigger,
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
- Read-only on browser stores; no launchd requirement; native APIs only

## Known thin spots / next steps

- Free-tier classifier quota throttles bulk re-runs; incremental is fine
- ~1.2k long-tail domains still <0.5 confidence — swept on next tag run
- from_visit chains stored but unexploited (navigation trees = next
  feature)
- Dashboard is long; could split into sub-pages if it grows further
- Python launchd agents can be retired once app grants are confirmed:
  `launchctl bootout gui/$UID/com.browserdaddy.{watch,extract}`
