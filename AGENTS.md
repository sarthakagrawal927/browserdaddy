# BrowserDaddy agent instructions

BrowserDaddy is a native, local-only macOS browsing-intelligence tool. It
archives browser history and measures real attention. Preserve these
boundaries:

- Sample and archive from measured evidence; never invent browsing activity.
- Keep collection read-only. Never delete or modify browser history files,
  profiles, cookies, or any browser data.
- Do not shell out to monitoring commands from the product. Use supported
  native macOS APIs (SQLite3, NSWorkspace, NSAppleScript, CGEventSource) and
  disclose unavailable evidence.
- Respect private browsing by design: it is never written to history and must
  never be reconstructed or approximated. Do not log incognito tab URLs even
  when AppleScript would expose them — filter them out when detectable.
- No analytics, telemetry, or sync. The archive stays on-device under
  ~/Library/Application Support/BrowserDaddy/. Owner-approved exception:
  optional classifier.dev requests require current, explicit, revocable consent
  disclosing domain names, truncated titles and paths. Never call these anonymous.
- BrowserDaddy owns browsing intelligence. StorageDaddy owns storage and
  configuration cleanup; PerformanceDaddy owns runtime diagnosis.
- Use XcodeBuildMCP for build, test, run, logging, and native UI verification.
- Run focused tests before the full package suite.
- Do not commit, push, sign, package, publish, or release without explicit
  owner approval.
