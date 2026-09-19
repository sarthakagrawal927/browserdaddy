import Foundation

/// Finds on-disk history stores for installed browsers. Port of the Python
/// discover() — including the stat-probe fallback that works when TCC blocks
/// directory listing but not stat().
public enum BrowserDiscovery {
    private static let home = FileManager.default.homeDirectoryForCurrentUser
    private static let appSupport = home
        .appendingPathComponent("Library/Application Support")

    private static let chromiumRoots: [(browser: String, path: String)] = [
        ("chrome", "Google/Chrome"),
        ("brave", "BraveSoftware/Brave-Browser"),
        ("edge", "Microsoft Edge"),
        ("vivaldi", "Vivaldi"),
        ("opera", "com.operasoftware.Opera"),
        ("chromium", "Chromium"),
        ("arc", "Arc/User Data"),
    ]

    public static func discover() -> [HistorySource] {
        var sources: [HistorySource] = []
        let fm = FileManager.default

        for (browser, rel) in chromiumRoots {
            let root = appSupport.appendingPathComponent(rel)
            guard fm.fileExists(atPath: root.path) else { continue }

            let profiles: [URL]
            if browser == "opera" {
                profiles = [root]
            } else if let listing = try? fm.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil) {
                profiles = listing.filter {
                    (try? $0.resourceValues(forKeys: [.isDirectoryKey])
                        .isDirectory) == true && !$0.lastPathComponent.hasPrefix(".")
                }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            } else {
                // TCC blocks listing but stat() still works — probe names.
                let probe = ["Default", "Guest Profile"]
                    + (1...10).map { "Profile \($0)" }
                profiles = probe.map { root.appendingPathComponent($0) }
                    .filter { fm.fileExists(
                        atPath: $0.appendingPathComponent("History").path) }
            }
            for prof in profiles {
                let h = prof.appendingPathComponent("History")
                if fm.fileExists(atPath: h.path) {
                    sources.append(HistorySource(
                        browser: browser, profile: prof.lastPathComponent,
                        path: h, engine: .chromium))
                }
            }
        }

        // Firefox
        let ffRoot = appSupport.appendingPathComponent("Firefox/Profiles")
        if let profiles = try? fm.contentsOfDirectory(
            at: ffRoot, includingPropertiesForKeys: nil) {
            for prof in profiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let db = prof.appendingPathComponent("places.sqlite")
                if fm.fileExists(atPath: db.path) {
                    sources.append(HistorySource(
                        browser: "firefox", profile: prof.lastPathComponent,
                        path: db, engine: .firefox))
                }
            }
        }

        // Safari
        let safari = home.appendingPathComponent("Library/Safari/History.db")
        if fm.fileExists(atPath: safari.path) {
            sources.append(HistorySource(
                browser: "safari", profile: "default",
                path: safari, engine: .safari))
        }
        return sources
    }

    /// Copy the DB (+wal/shm) to a temp dir — a running browser's lock
    /// doesn't matter.
    public static func snapshot(_ src: HistorySource, into tmp: URL) throws -> URL {
        let dst = tmp.appendingPathComponent(
            "\(src.browser)_\(src.profile.replacingOccurrences(of: " ", with: "_")).db")
        try FileManager.default.copyItem(at: src.path, to: dst)
        for suffix in ["-wal", "-shm"] {
            let side = src.path.deletingLastPathComponent()
                .appendingPathComponent(src.path.lastPathComponent + suffix)
            if FileManager.default.fileExists(atPath: side.path) {
                try? FileManager.default.copyItem(
                    at: side, to: dst.deletingLastPathComponent()
                        .appendingPathComponent(dst.lastPathComponent + suffix))
            }
        }
        return dst
    }
}
