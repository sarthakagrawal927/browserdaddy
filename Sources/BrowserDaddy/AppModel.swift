import Foundation
import BrowserCore
import ServiceManagement
import AppKit

@MainActor
final class AppModel: ObservableObject {
    @Published var report: ReportEngine.Report?
    @Published var extracting = false
    @Published var extractLog: [String] = []
    @Published var automation: [String: Permissions.AutomationState] = [:]
    @Published var browserAccess: [BrowserAccessStatus] = []
    @Published var browserAccessError = ""
    struct HistoryRow: Identifiable {
        let id: String
        let time: Date?
        let browser, profile, title, url, host: String
        let category, tagSource, tagScope: String?
        let pageCategory, pageTagSource, domainCategory, domainTagSource: String?
        var source: String { "\(browser)/\(profile)" }
    }
    enum HistoryTagScope: String, CaseIterable, Identifiable {
        case page = "This page"
        case domain = "Exact domain"
        case rollup = "Whole site"
        var id: Self { self }
    }
    @Published var historyRows: [HistoryRow] = []
    @Published var browsers: [String] = []
    @Published var historySources: [String] = []
    @Published var historyCategories: [String] = []
    @Published var historyActionError: String?
    @Published var searchTerm = "" { didSet { Task { await search() } } }
    @Published var browserFilter = "all" { didSet { Task { await search() } } }
    @Published var historySourceFilter = "all" { didSet { Task { await search() } } }
    @Published var historyDaysFilter = 0 { didSet { Task { await search() } } }
    @Published var historyCategoryFilter = "all" { didSet { Task { await search() } } }
    @Published var historyTagFilter = ReportEngine.HistoryTagFilter.all {
        didSet { Task { await search() } }
    }
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
    /// SPOT CHECK: selected domain + its month-over-month verdict.
    @Published var checkHost = "www.youtube.com"
    @Published var siteCheck: ReportEngine.SiteCheck?

    let store: ArchiveStore
    let engine: ReportEngine
    let watcher: FocusWatcher
    private var didStartCollection = false
    private var classificationTask: Task<Void, Never>?
    static let classificationConsentVersion = "2"
    private let startCollectionOverride: (() -> Void)?
    private let browserGrantStore: BrowserGrantStore

    init(store suppliedStore: ArchiveStore,
         startCollection: (() -> Void)? = nil,
         browserGrantStore: BrowserGrantStore = BrowserGrantStore()) {
        store = suppliedStore
        engine = ReportEngine(store: store)
        watcher = FocusWatcher(store: store)
        startCollectionOverride = startCollection
        self.browserGrantStore = browserGrantStore
        launchAtLogin = SMAppService.mainApp.status == .enabled
        needsOnboarding = store.metaGet("onboarded") != "1"
        classifyOptin = store.metaGet("classify_optin") == "1"
            && store.metaGet("classify_consent_version") == Self.classificationConsentVersion
    }

    func boot() {
        guard !needsOnboarding, !didStartCollection else { return }
        didStartCollection = true
        if let startCollectionOverride {
            startCollectionOverride()
            return
        }
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
        refreshBrowserAccess()
        Task.detached(priority: .utility) {
            var states: [String: Permissions.AutomationState] = [:]
            for (bundleID, scriptName) in FocusWatcher.tabCapableBrowsers {
                states[scriptName] = Permissions.automationState(
                    bundleID: bundleID, scriptName: scriptName)
            }
            await MainActor.run {
                self.automation = states
            }
        }
    }

    var visibleBrowserKinds: [BrowserKind] {
        let connected = Set(browserGrantStore.grants().map(\.kind))
        return BrowserKind.allCases.filter {
            connected.contains($0)
                || NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: $0.bundleIdentifier) != nil
        }
    }

    var hasConnectedBrowser: Bool {
        browserAccess.contains {
            if case .connected = $0.state { return true }
            return false
        }
    }

    func refreshBrowserAccess() {
        browserAccess = browserGrantStore.statuses(for: visibleBrowserKinds)
    }

    func connectBrowser(_ kind: BrowserKind) {
        browserAccessError = ""
        let panel = NSOpenPanel()
        panel.title = "Connect \(kind.displayName)"
        panel.message = kind.selectionHint
        panel.prompt = "Connect read-only"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        var suggestion = kind.suggestedRoot
        while !FileManager.default.fileExists(atPath: suggestion.path),
              suggestion.pathComponents.count > 2 {
            suggestion.deleteLastPathComponent()
        }
        panel.directoryURL = suggestion
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    try self.browserGrantStore.save(kind: kind, selectedURL: url)
                    self.refreshBrowserAccess()
                    self.runExtract()
                } catch {
                    self.browserAccessError = error.localizedDescription
                }
            }
        }
    }

    func removeBrowser(_ kind: BrowserKind) {
        browserGrantStore.remove(kind: kind)
        refreshBrowserAccess()
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
        historySources = (try? engine.historySources()) ?? []
        historyCategories = (try? engine.historyCategories()) ?? []
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
        classificationTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let log: @Sendable (String) -> Void = { s in
                Task { @MainActor in self.classifyLog.append(s) }
            }
            do {
                let r = try await Classifier(db: store.db).run(log: log)
                try Task.checkCancellation()
                await MainActor.run {
                    guard self.classifyOptin else { return }
                    self.classifySummary =
                        "+\(r.domains) domains, +\(r.pages) pages — "
                        + String(format: "%.0f%% of visits classified",
                                 r.coveragePct)
                }
                await self.reloadFiltered()
            } catch {
                if !Task.isCancelled { log("Classification failed. Please try again.") }
            }
            await MainActor.run {
                self.classifying = false
                self.classificationTask = nil
            }
        }
    }

    func setClassifyOptin(_ on: Bool) {
        classifyOptin = on
        store.metaSet("classify_optin", on ? "1" : "0")
        store.metaSet("classify_consent_version", on ? Self.classificationConsentVersion : "")
        if !on {
            classificationTask?.cancel()
            classifySummary = "Classification disabled. Previously sent data cannot be recalled."
        }
    }

    func finishOnboarding() {
        store.metaSet("onboarded", "1")
        needsOnboarding = false
        boot()
    }

    /// Manual domain tag — persisted as source='user', survives tag runs.
    func overrideDomain(_ host: String, _ category: String) {
        try? store.setDomainCategory(host, category)
        Task { await reloadFiltered() }
    }

    /// Rollup-level tag — applies to every host under the eTLD+1.
    func overrideRollup(_ rollup: String, _ category: String) {
        try? store.setRollupCategory(rollup, category)
        Task { await reloadFiltered() }
    }

    @discardableResult
    func setHistoryTag(_ row: HistoryRow, scope: HistoryTagScope, category: String) -> Bool {
        historyActionError = nil
        do {
            switch scope {
            case .page: try store.setPageCategory(row.url, category)
            case .domain: try store.setDomainCategory(row.host, category)
            case .rollup: try store.setRollupCategory(Domain.rollup(row.host), category)
            }
            Task { await reloadFiltered() }
            return true
        } catch {
            historyActionError = "Couldn’t save this local tag. The archive was not changed."
            return false
        }
    }

    @discardableResult
    func clearHistoryTag(_ row: HistoryRow, scope: HistoryTagScope) -> Bool {
        historyActionError = nil
        do {
            switch scope {
            case .page: try store.clearPageCategory(row.url)
            case .domain: try store.clearDomainCategory(row.host)
            case .rollup: try store.clearRollupCategory(Domain.rollup(row.host))
            }
            Task { await reloadFiltered() }
            return true
        } catch {
            historyActionError = "Couldn’t clear this local tag. The archive was not changed."
            return false
        }
    }

    var historyActiveFilterCount: Int {
        [browserFilter != "all", historySourceFilter != "all", historyDaysFilter != 0,
         historyCategoryFilter != "all", historyTagFilter != .all].filter { $0 }.count
    }

    func clearHistoryFilters() {
        browserFilter = "all"
        historySourceFilter = "all"
        historyDaysFilter = 0
        historyCategoryFilter = "all"
        historyTagFilter = .all
    }

    func runSiteCheck() {
        let h = checkHost
        Task.detached(priority: .utility) { [weak self] in
            let c = try? self?.engine.siteCheck(h)
            await MainActor.run { self?.siteCheck = c }
        }
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
        guard !needsOnboarding, !extracting else { return }
        extracting = true
        extractLog = []
        let store = self.store
        let grants = browserGrantStore
        Task.detached(priority: .utility) {
            let results = grants.withAccessibleRoots { roots, failures in
                for failure in failures {
                    Task { @MainActor in
                        self.extractLog.append("✗ \(failure.kind.displayName): \(failure.message)")
                    }
                }
                if roots.isEmpty && failures.isEmpty {
                    Task { @MainActor in
                        self.extractLog.append("No browser folders connected. Open Permissions to add one.")
                    }
                }
                return HistoryExtractor.run(into: store, roots: roots) { line in
                    Task { @MainActor in self.extractLog.append(line) }
                }
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
            await MainActor.run { self.refreshBrowserAccess() }
            await self.reload()
        }
    }

    func search() async {
        let engine = self.engine
        let query = ReportEngine.HistoryQuery(
            term: searchTerm, browser: browserFilter, source: historySourceFilter,
            sinceDays: historyDaysFilter, category: historyCategoryFilter,
            tag: historyTagFilter
        )
        let rows = (try? await Task.detached(priority: .userInitiated) {
            try engine.searchHistory(query)
        }.value) ?? []
        guard query == ReportEngine.HistoryQuery(
            term: searchTerm, browser: browserFilter, source: historySourceFilter,
            sinceDays: historyDaysFilter, category: historyCategoryFilter,
            tag: historyTagFilter
        ) else { return }
        historyRows = rows.map {
            HistoryRow(
                id: "\($0.browser)/\($0.profile)/\($0.visitID)",
                time: $0.visitedAt, browser: $0.browser, profile: $0.profile,
                title: $0.title, url: $0.url, host: $0.host,
                category: $0.category, tagSource: $0.tagSource, tagScope: $0.tagScope,
                pageCategory: $0.pageCategory, pageTagSource: $0.pageTagSource,
                domainCategory: $0.domainCategory, domainTagSource: $0.domainTagSource)
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
