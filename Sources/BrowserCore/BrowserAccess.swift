import Foundation

public enum BrowserKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case chrome, safari, brave, firefox, edge, arc, vivaldi, opera, chromium

    public var id: String { rawValue }

    public var displayName: String {
        return switch self {
        case .chrome: "Google Chrome"
        case .safari: "Safari"
        case .brave: "Brave"
        case .firefox: "Firefox"
        case .edge: "Microsoft Edge"
        case .arc: "Arc"
        case .vivaldi: "Vivaldi"
        case .opera: "Opera"
        case .chromium: "Chromium"
        }
    }

    public var bundleIdentifier: String {
        switch self {
        case .chrome: "com.google.Chrome"
        case .safari: "com.apple.Safari"
        case .brave: "com.brave.Browser"
        case .firefox: "org.mozilla.firefox"
        case .edge: "com.microsoft.edgemac"
        case .arc: "company.thebrowser.Browser"
        case .vivaldi: "com.vivaldi.Vivaldi"
        case .opera: "com.operasoftware.Opera"
        case .chromium: "org.chromium.Chromium"
        }
    }

    public var suggestedRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let support = home.appendingPathComponent("Library/Application Support")
        return switch self {
        case .chrome: support.appendingPathComponent("Google/Chrome")
        case .safari: home.appendingPathComponent("Library/Safari")
        case .brave: support.appendingPathComponent("BraveSoftware/Brave-Browser")
        case .firefox: support.appendingPathComponent("Firefox/Profiles")
        case .edge: support.appendingPathComponent("Microsoft Edge")
        case .arc: support.appendingPathComponent("Arc/User Data")
        case .vivaldi: support.appendingPathComponent("Vivaldi")
        case .opera: support.appendingPathComponent("com.operasoftware.Opera")
        case .chromium: support.appendingPathComponent("Chromium")
        }
    }

    public var selectionHint: String {
        switch self {
        case .safari: "Select the Safari folder containing History.db."
        case .firefox: "Select the Profiles folder — or one profile folder inside it."
        default: "This folder holds the browser profiles. Select it — or one profile folder inside it — then Connect."
        }
    }

    /// "~"-abbreviated suggested folder, for directions copy.
    public var displayPath: String {
        suggestedRoot.path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~")
    }

    /// Exactly what to select when connecting, with the concrete path.
    public var connectDirections: String {
        switch self {
        case .safari:
            return "pick \(displayPath) — it contains History.db"
        case .firefox:
            return "pick \(displayPath), or one profile folder inside it"
        default:
            return "pick \(displayPath) — or a single profile folder inside it"
        }
    }
}

public struct BrowserRoot: Sendable, Equatable {
    public let kind: BrowserKind
    public let url: URL

    public init(kind: BrowserKind, url: URL) {
        self.kind = kind
        self.url = url
    }
}

public struct BrowserGrant: Codable, Sendable, Equatable {
    public let kind: BrowserKind
    public let bookmark: Data
}

public struct BrowserGrantFailure: Sendable, Equatable {
    public let kind: BrowserKind
    public let message: String
}

public enum BrowserAccessState: Sendable, Equatable {
    case notConnected
    case connected(path: String)
    case needsAccess(message: String)
}

public struct BrowserAccessStatus: Identifiable, Sendable, Equatable {
    public var id: BrowserKind { kind }
    public let kind: BrowserKind
    public let state: BrowserAccessState
}

public enum BrowserGrantError: LocalizedError, Equatable {
    case unsupportedFolder(String)
    case bookmarkFailed

    public var errorDescription: String? {
        switch self {
        case .unsupportedFolder(let hint): "No supported history database was found. \(hint)"
        case .bookmarkFailed: "macOS could not preserve read-only access to this folder."
        }
    }
}

/// Persistent, revocable read-only grants created only from user-selected URLs.
public final class BrowserGrantStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "browserdaddy.browser-folder-grants.v1"
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func grants() -> [BrowserGrant] {
        lock.withLock {
            guard let data = defaults.data(forKey: key) else { return [] }
            return (try? JSONDecoder().decode([BrowserGrant].self, from: data)) ?? []
        }
    }

    public func save(kind: BrowserKind, selectedURL: URL) throws {
        let started = selectedURL.startAccessingSecurityScopedResource()
        defer { if started { selectedURL.stopAccessingSecurityScopedResource() } }
        guard BrowserDiscovery.isValid(root: BrowserRoot(kind: kind, url: selectedURL)) else {
            throw BrowserGrantError.unsupportedFolder(kind.selectionHint)
        }
        let bookmark: Data
        do {
            bookmark = try selectedURL.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: [.isDirectoryKey], relativeTo: nil)
        } catch {
            throw BrowserGrantError.bookmarkFailed
        }
        lock.withLock {
            var values = grantsUnlocked().filter { $0.kind != kind }
            values.append(BrowserGrant(kind: kind, bookmark: bookmark))
            persistUnlocked(values)
        }
    }

    public func remove(kind: BrowserKind) {
        lock.withLock { persistUnlocked(grantsUnlocked().filter { $0.kind != kind }) }
    }

    public func statuses(for kinds: [BrowserKind]) -> [BrowserAccessStatus] {
        let saved = Dictionary(uniqueKeysWithValues: grants().map { ($0.kind, $0) })
        return kinds.map { kind in
            guard let grant = saved[kind] else {
                return BrowserAccessStatus(kind: kind, state: .notConnected)
            }
            switch resolve(grant) {
            case .success(let resolved):
                let started = resolved.url.startAccessingSecurityScopedResource()
                defer { if started { resolved.url.stopAccessingSecurityScopedResource() } }
                guard started else {
                    return BrowserAccessStatus(kind: kind,
                        state: .needsAccess(message: "Reconnect this browser folder."))
                }
                guard BrowserDiscovery.isValid(root: BrowserRoot(kind: kind, url: resolved.url)) else {
                    return BrowserAccessStatus(kind: kind,
                        state: .needsAccess(message: "Folder moved, changed, or is no longer readable."))
                }
                if resolved.stale { try? refresh(grant: grant, url: resolved.url) }
                return BrowserAccessStatus(kind: kind, state: .connected(path: resolved.url.path))
            case .failure:
                return BrowserAccessStatus(kind: kind,
                    state: .needsAccess(message: "Reconnect this browser folder."))
            }
        }
    }

    /// Holds every resolved scope only for the duration of one extraction pass.
    public func withAccessibleRoots<T>(
        _ body: ([BrowserRoot], [BrowserGrantFailure]) throws -> T
    ) rethrows -> T {
        var roots: [BrowserRoot] = []
        var failures: [BrowserGrantFailure] = []
        var active: [URL] = []
        for grant in grants() {
            switch resolve(grant) {
            case .success(let resolved):
                guard resolved.url.startAccessingSecurityScopedResource() else {
                    failures.append(BrowserGrantFailure(kind: grant.kind,
                        message: "folder access was revoked; reconnect it"))
                    continue
                }
                active.append(resolved.url)
                let root = BrowserRoot(kind: grant.kind, url: resolved.url)
                guard BrowserDiscovery.isValid(root: root) else {
                    failures.append(BrowserGrantFailure(kind: grant.kind,
                        message: "selected folder no longer contains supported history"))
                    continue
                }
                if resolved.stale { try? refresh(grant: grant, url: resolved.url) }
                roots.append(root)
            case .failure:
                failures.append(BrowserGrantFailure(kind: grant.kind,
                    message: "bookmark could not be resolved; reconnect it"))
            }
        }
        defer { active.forEach { $0.stopAccessingSecurityScopedResource() } }
        return try body(roots, failures)
    }

    private func resolve(_ grant: BrowserGrant) -> Result<(url: URL, stale: Bool), Error> {
        Result {
            var stale = false
            let url = try URL(resolvingBookmarkData: grant.bookmark,
                              options: [.withSecurityScope], relativeTo: nil,
                              bookmarkDataIsStale: &stale)
            return (url, stale)
        }
    }

    private func refresh(grant: BrowserGrant, url: URL) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: [.isDirectoryKey], relativeTo: nil)
        lock.withLock {
            var values = grantsUnlocked().filter { $0.kind != grant.kind }
            values.append(BrowserGrant(kind: grant.kind, bookmark: data))
            persistUnlocked(values)
        }
    }

    private func grantsUnlocked() -> [BrowserGrant] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([BrowserGrant].self, from: data)) ?? []
    }

    private func persistUnlocked(_ grants: [BrowserGrant]) {
        if grants.isEmpty { defaults.removeObject(forKey: key); return }
        guard let data = try? JSONEncoder().encode(grants) else { return }
        defaults.set(data, forKey: key)
    }
}
