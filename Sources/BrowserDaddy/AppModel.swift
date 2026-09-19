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
    // attention surface
    @Published var nowApp = ""
    @Published var nowURL = ""
    @Published var focusDay = "" { didSet { loadFocusDay() } }
    @Published var focusDaysList: [String] = []
    @Published var daySegments: [ReportEngine.FocusSegRow] = []
    @Published var attentionAppsDetail: [ReportEngine.Count] = []
    @Published var attentionSitesDetail: [ReportEngine.Count] = []
    @Published var attentionHourly = [Int64](repeating: 0, count: 24)
    // analytics filters — applied across Dashboard + Attention
    @Published var filterSource = "all" { didSet { Task { await reloadFiltered() } } }
    @Published var filterDays = 0 { didSet { Task { await reloadFiltered() } } }
    /// Timeline granularity: 0 day, 1 week, 2 month.
    @Published var granularity = 0
    // onboarding + optional classification
    @Published var needsOnboarding = false
    @Published var classifyOptin = false
    @Published var classifying = false
    @Published var classifyLog: [String] = []
    @Published var classifySummary = ""

    let store: ArchiveStore
    let engine: ReportEngine
    let watcher: FocusWatcher

    init() {
        store = try! ArchiveStore()
        engine = ReportEngine(store: store)
        watcher = FocusWatcher(store: store)
        launchAtLogin = SMAppService.mainApp.status == .enabled
        needsOnboarding = store.metaGet("onboarded") != "1"
        classifyOptin = store.metaGet("classify_optin") == "1"
    }

    func boot() {
        refreshPermissions()
        watcher.onTick = { [weak self] app, url in
            Task { @MainActor in
                self?.nowApp = app
                self?.nowURL = url
            }
        }
        watcher.onSegment = { [weak self] _, _ in
            Task { @MainActor in
                self?.reloadAttention()
                self?.loadFocusDay()
            }
        }
        watcher.start()
        Task.detached(priority: .utility) { [store] in
            _ = try? ArchiveImporter.importIfNeeded(into: store)
            await self.reload()
            await MainActor.run { self.reloadAttention() }
            await MainActor.run { self.loadFocusDay() }
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
        let src = filterSource == "all" ? nil : filterSource
        let days = filterDays
        let r = try? await Task.detached(priority: .utility) {
            try engine.build(source: src, sinceDays: days)
        }.value
        report = r
        browsers = (try? engine.browsers()) ?? []
        await search()
    }

    /// Filter change → rebuild report + attention stats.
    func reloadFiltered() async {
        await reload()
        reloadAttention()
    }

    /// Opt-in classification of archive domains/pages via classifier.dev.
    /// The ONLY network call this app makes; gated on user consent.
    func runClassification() {
        guard classifyOptin, !classifying else { return }
        classifying = true
        classifyLog = []
        classifySummary = ""
        let store = self.store
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let log: @Sendable (String) -> Void = { s in
                Task { @MainActor in self.classifyLog.append(s) }
            }
            do {
                let r = try await Classifier(db: store.db).run(log: log)
                await MainActor.run {
                    self.classifySummary =
                        "+\(r.domains) domains, +\(r.pages) pages — "
                        + String(format: "%.0f%% of visits classified",
                                 r.coveragePct)
                    self.classifying = false
                }
                await self.reloadFiltered()
            } catch {
                log("error: \(error.localizedDescription)")
                await MainActor.run { self.classifying = false }
            }
        }
    }

    func setClassifyOptin(_ on: Bool) {
        classifyOptin = on
        store.metaSet("classify_optin", on ? "1" : "0")
    }

    func finishOnboarding() {
        store.metaSet("onboarded", "1")
        needsOnboarding = false
    }

    func reloadAttention() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let days = await MainActor.run { self.filterDays }
            let apps = (try? self.engine.attentionApps(sinceDays: days)) ?? []
            let sites = (try? self.engine.attentionSites(sinceDays: days)) ?? []
            let appsDetail = (try? self.engine.attentionAppsDetailed(sinceDays: days)) ?? []
            let sitesDetail = (try? self.engine.attentionSitesDetailed(sinceDays: days)) ?? []
            let hourly = (try? self.engine.attentionHourly(sinceDays: days)) ?? []
            let dayList = (try? self.engine.focusDays(sinceDays: days)) ?? []
            await MainActor.run {
                self.report?.attentionApps = apps
                self.report?.attentionSites = sites
                self.attentionAppsDetail = appsDetail
                self.attentionSitesDetail = sitesDetail
                self.attentionHourly = hourly
                self.focusDaysList = dayList
                if self.focusDay.isEmpty || !dayList.contains(self.focusDay) {
                    self.focusDay = dayList.first ?? ""
                }
            }
        }
    }

    func loadFocusDay() {
        let day = focusDay
        guard !day.isEmpty else { return }
        Task.detached(priority: .utility) { [weak self] in
            let segs = (try? self?.engine.focusSegments(day: day)) ?? []
            await MainActor.run { self?.daySegments = segs }
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
