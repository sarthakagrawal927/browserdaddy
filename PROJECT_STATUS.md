# BrowserDaddy — project status

## Current state

Scaffolded 2026-09-19. SwiftPM package forked from the storagedaddy/
performancedaddy template: `BrowserCore` library + `BrowserDaddy` SwiftUI
executable + XCTest targets.

Prototype reference implementation lives at ~/browserdaddy/ (Python):
extract.py (history archive), watch.py (AppleScript focus watcher),
stats.py (report), out/browserdaddy.db (~109k archived visits).
The app ports that pipeline natively and imports the existing archive DB.

## Features (shipped)

v1 implementation landed 2026-09-19 (tracking issue #1):

- BrowserCore: SQLite store, archive schema (visits/searches/focus/meta),
  merge-dedupe on (browser, profile, visit_id)
- Browser discovery: all Chromium roots + profiles (stat-probe fallback
  when TCC blocks listing), Firefox, Safari; snapshot past SQLite locks
- Three engine extractors + epoch normalization (Chromium µs-1601,
  Firefox µs-unix, Safari s-2001); omnibox search terms
- One-time import of python archive ~/browserdaddy/out/browserdaddy.db
- FocusWatcher: NSWorkspace frontmost polling + AppleScript tab URL +
  CGEventSource idle gating → focus segments (2s ticks, 60s idle limit,
  miss tolerance, blip dropping)
- ReportEngine: attention leaderboards, eTLD+1 rollup, per-profile
  personalities, hourly/DOW rhythm, sessions & rabbit holes, searches
- App: Dashboard / History / Permissions surfaces, launch-at-login toggle

## In flight

- Tracking issue #1 (spec-driven). Tasks 1–7, 9–10 done; task 8 partial —
  python launchd agents kept as backstop until app holds its own grants.
- First launch pending: FDA + per-browser Automation grants for the app.
