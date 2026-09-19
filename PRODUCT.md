# BrowserDaddy

BrowserDaddy is a native, local-first browsing-intelligence app for macOS. It
answers "where does my time on the web actually go?" with two data sources no
browser exposes together: a permanent unified history archive across every
installed browser, and real frontmost-window attention time measured at the
OS level.

## North star

Browsers keep history for ~90 days and record no honest attention signal.
BrowserDaddy owns both problems: it archives every visit before Chrome prunes
it, and it watches which app/window/tab is actually in front to produce true
dwell time — Safari, Chrome, Brave, and every Chromium browser covered
uniformly via AppleScript, no extensions.

## Product surfaces (v1 wedge)

### Dashboard

Attention leaderboard (real focused time per app and per site), top domains
with eTLD+1 rollup, daily rhythm (hourly/day-of-week), profile personalities
(work vs personal split), sessions and rabbit-hole detection.

### History

Searchable, filterable unified timeline across all browsers and profiles —
survives browser pruning because the archive merges, never replaces.

### Permissions & onboarding

Full Disk Access check + guided grant flow (history reads), per-browser
Automation consent status (tab URL reads), launch-at-login toggle.

## Non-goals

- No sync, telemetry or analytics. Optional on-demand classifier.dev topic tagging
  requires explicit, revocable consent for domain names, truncated titles and
  paths. Requests are not anonymous. The archive remains local.
- No incognito reconstruction — private browsing is private.
- Not a screen-time blocker (StayFocusd et al. already exist); this is the
  measurement layer, not the enforcement layer.
