import Foundation
import BrowserCore
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var report: ReportEngine.Report?
    @Published var extracting = false
    @Published var extractLog: [String] = []
    @Published var fda = false
    @Published var automation: [String: Permissions.AutomationState] = [:]
    struct HistoryRow: Identifiable {
        let id = UUID()
        let time: Date?
        let browser, profile, title, url: String
    }
    @Published var historyRows: [HistoryRow] = []
    @Published var browsers: [String] = []
    @Published var searchTerm = "" { didSet { Task { await search() } } }
    @Published var browserFilter = "all" { didSet { Task { await search() } } }
    @Published var launchAtLogin = false
    @Published var showAbout = false

    let store: ArchiveStore
    let engine: ReportEngine
    let watcher: FocusWatcher

    init() {
        store = try! ArchiveStore()
        engine = ReportEngine(store: store)
        watcher = FocusWatcher(store: store)
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func boot() {
        refreshPermissions()
        watcher.onSegment = { [weak self] _, _ in
            Task { @MainActor in self?.reloadAttention() }
        }
        watcher.start()
        Task.detached(priority: .utility) { [store] in
            _ = try? ArchiveImporter.importIfNeeded(into: store)
            await self.reload()
            await self.runExtract()   // first-boot archive pass
        }
        // Archive stays fresh without launchd: re-extract while running.
        Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) {
            [weak self] _ in
            Task { @MainActor in self?.runExtract() }
        }
    }

    func refreshPermissions() {
        Task.detached(priority: .utility) {
            let fda = Permissions.hasFullDiskAccess()
            var states: [String: Permissions.AutomationState] = [:]
            for (_, scriptName) in FocusWatcher.scriptableBrowsers {
                states[scriptName] = Permissions.automationState(for: scriptName)
            }
            await MainActor.run {
                self.fda = fda
                self.automation = states
            }
        }
    }

    func reload() async {
        let engine = self.engine
        let r = try? await Task.detached(priority: .utility) {
            try engine.build()
        }.value
        report = r
        browsers = (try? engine.browsers()) ?? []
        await search()
    }

    func reloadAttention() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let apps = (try? self.engine.attentionApps()) ?? []
            let sites = (try? self.engine.attentionSites()) ?? []
            await MainActor.run {
                self.report?.attentionApps = apps
                self.report?.attentionSites = sites
            }
        }
    }

    func runExtract() {
        guard !extracting else { return }
        extracting = true
        extractLog = []
        let store = self.store
        Task.detached(priority: .utility) {
            let results = HistoryExtractor.run(into: store) { line in
                Task { @MainActor in self.extractLog.append(line) }
            }
            for r in results {
                if let err = r.error {
                    await MainActor.run {
                        self.extractLog.append(
                            "✗ \(r.source.browser)/\(r.source.profile): \(err)")
                    }
                }
            }
            await MainActor.run { self.extracting = false }
            await self.reload()
        }
    }

    func search() async {
        let engine = self.engine
        let term = searchTerm, filter = browserFilter
        let rows = (try? await Task.detached(priority: .userInitiated) {
            try engine.searchHistory(term: term, browser: filter)
        }.value) ?? []
        historyRows = rows.map {
            HistoryRow(
                time: ISO8601.parse($0["visit_time_utc"]?.text ?? ""),
                browser: $0["browser"]?.text ?? "",
                profile: $0["profile"]?.text ?? "",
                title: $0["title"]?.text ?? "",
                url: $0["url"]?.text ?? "")
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {}
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
