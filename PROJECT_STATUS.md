# BrowserDaddy — project status

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
