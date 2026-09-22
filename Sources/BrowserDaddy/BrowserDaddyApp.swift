import SwiftUI
import BrowserCore

@MainActor
final class AppStartup: ObservableObject {
    @Published private(set) var model: AppModel?
    init(openArchive: () throws -> ArchiveStore = { try ArchiveStore() }) {
        do {
            if CommandLine.arguments.contains("--preview-fixture") {
                model = AppModel(store: try PreviewArchive.make(), startCollection: {})
            } else {
                model = AppModel(store: try openArchive())
            }
        }
        catch { model = nil }
    }
}

private enum PreviewArchive {
    static func make() throws -> ArchiveStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserDaddy-preview-\(UUID().uuidString).db")
        let store = try ArchiveStore(url: url)
        store.metaSet("onboarded", "1")
        let now = Date()
        let chrome = HistorySource(browser: "chrome", profile: "Work",
                                   path: url, engine: .chromium)
        let safari = HistorySource(browser: "safari", profile: "Personal",
                                   path: url, engine: .safari)
        try store.merge(visits: [
            visit(1, "https://developer.apple.com/documentation/swiftui", "SwiftUI documentation", now),
            visit(2, "https://github.com/example/project/pulls", "Pull requests · example/project", now.addingTimeInterval(-840)),
            visit(3, "https://news.ycombinator.com/", "Hacker News", now.addingTimeInterval(-2_400)),
            visit(4, "https://docs.example.dev/performance", "Performance guide", now.addingTimeInterval(-8_400)),
        ], source: chrome)
        try store.merge(visits: [
            visit(10, "https://www.youtube.com/watch", "Design systems talk", now.addingTimeInterval(-1_500)),
            visit(11, "https://music.example/album", "Morning playlist", now.addingTimeInterval(-12_000)),
            visit(12, "https://travel.example/itinerary", "Weekend itinerary", now.addingTimeInterval(-92_000)),
        ], source: safari)
        try store.setDomainCategory("developer.apple.com", "documentation")
        try store.setPageCategory("https://github.com/example/project/pulls", "programming")
        try store.db.execute("""
            INSERT OR REPLACE INTO domain_categories
            (host, category, confidence, source) VALUES (?,?,?,'auto')
        """, [.text("www.youtube.com"), .text("video"), .double(0.94)])
        return store
    }

    private static func visit(_ id: Int64, _ url: String, _ title: String,
                              _ date: Date) -> HistoryVisit {
        HistoryVisit(browser: "", profile: "", visitID: id, url: url, title: title,
                     visitedAt: date, visitCount: 1, typedCount: 0,
                     transition: "link", fromVisit: nil)
    }
}

private struct BrowserDaddyContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.needsOnboarding { OnboardingView() }
            else { RootView() }
        }
        .environmentObject(model)
    }
}

@main
struct BrowserDaddyApp: App {
    @StateObject private var startup = AppStartup()
    @StateObject private var updates = AppUpdates()

    var body: some Scene {
        WindowGroup("browserdaddy") {
            Group {
                if let model = startup.model {
                    BrowserDaddyContent(model: model)
                    .onAppear { model.boot() }
                    .task { updates.start(model: model) }
                } else {
                    ContentUnavailableView {
                        Label("Couldn’t open your archive", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("BrowserDaddy has not started collection. Check available disk space and access to your Application Support folder, then reopen the app. Your archive has not been deleted or replaced.")
                    }
                }
            }
            .frame(minWidth: 920, minHeight: 620)
            .preferredColorScheme(.dark)
            .tint(BrowserTheme.action)
            .buttonStyle(DaddyButtonStyle())
        }
        .defaultSize(width: 1240, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About browserdaddy") { startup.model?.showAbout = true }
                    .disabled(startup.model == nil)
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updates.check() }
                    .disabled(!updates.canCheck || !updates.isIdle)
                Toggle("Automatically Check for Updates", isOn: $updates.automaticallyChecks)
            }
            CommandGroup(after: .newItem) {
                Button("Sync History") { startup.model?.runExtract() }
                    .keyboardShortcut("e")
                    .disabled(startup.model == nil || startup.model?.extracting == true)
                Button("Refresh Report") {
                    Task { await startup.model?.reload() }
                }.keyboardShortcut("r")
                    .disabled(startup.model == nil)
            }
        }

        Settings {
            Group {
                if let model = startup.model {
                    AlertSettingsView()
                        .environmentObject(model)
                } else {
                    Text("Archive unavailable — reopen the app.")
                        .foregroundStyle(BrowserTheme.secondaryInk)
                }
            }
            .padding(24).frame(width: 480)
            .preferredColorScheme(.dark)
            .tint(BrowserTheme.action)
            .buttonStyle(DaddyButtonStyle())
        }
    }
}

enum Workspace: String, CaseIterable, Identifiable {
    case attention = "Attention", dashboard = "Dashboard",
         history = "History", permissions = "Permissions"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .attention: return "eye"
        case .dashboard: return "chart.bar.xaxis"
        case .history: return "clock.arrow.circlepath"
        case .permissions: return "lock.shield"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var workspace: Workspace

    init() {
        _workspace = State(initialValue: CommandLine.arguments.contains("--preview-fixture")
                           ? .history : .attention)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 240)
        } detail: {
            VStack(spacing: 0) {
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider().overlay(BrowserTheme.divider)
                statusBar
            }
            .background(BrowserTheme.fog)
        }
        .preferredColorScheme(.dark)
        .tint(BrowserTheme.action)
        .buttonStyle(DaddyButtonStyle())
        .toolbar(.hidden, for: .windowToolbar)
        .sheet(isPresented: $model.showAbout) { about }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                DaddyArtwork(brand: true).frame(width: 24, height: 24)
                Text("browserdaddy")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .tracking(-0.6).lineLimit(1).minimumScaleFactor(0.8)
            }.padding(.top, 20).padding(.bottom, 10)

            Button { model.runExtract() } label: {
                Label(model.extracting ? "Syncing…" : "Sync History",
                      systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity).frame(height: 28)
            }
            .buttonStyle(DaddyButtonStyle(prominent: true))
            .disabled(model.extracting)

            VStack(alignment: .leading, spacing: 5) {
                navigationHeading("LIVE")
                navigationItem(.attention)
                navigationHeading("ARCHIVE").padding(.top, 9)
                navigationItem(.dashboard)
                navigationItem(.history)
                navigationHeading("SETUP").padding(.top, 9)
                navigationItem(.permissions)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 15).padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
    }

    private func navigationHeading(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .semibold)).tracking(1)
            .foregroundStyle(BrowserTheme.secondaryInk)
            .padding(.horizontal, 10).padding(.vertical, 4)
    }

    private func navigationItem(_ item: Workspace) -> some View {
        Button { workspace = item } label: {
            HStack {
                Image(systemName: item.icon).frame(width: 20)
                    .foregroundStyle(BrowserTheme.mintInk)
                Text(item.rawValue)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(workspace == item ? BrowserTheme.mintInk.opacity(0.11) : .clear,
                    in: RoundedRectangle(cornerRadius: 7))
        .accessibilityAddTraits(workspace == item ? .isSelected : [])
        .accessibilityIdentifier("workspace-\(item.rawValue)")
    }

    @ViewBuilder private var content: some View {
        switch workspace {
        case .attention: AttentionView()
        case .dashboard: DashboardView()
        case .history: HistoryView()
        case .permissions: PermissionsView()
        }
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            Text(statusText).lineLimit(1)
            if let last = model.extractLog.last {
                Text(last).lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(last.hasPrefix("✗")
                                     ? BrowserTheme.coral
                                     : BrowserTheme.secondaryInk)
                    .frame(maxWidth: 420, alignment: .leading)
            }
            Spacer()
            if let r = model.report {
                Text("\(r.totalVisits.formatted()) visits")
                    .monospacedDigit().foregroundStyle(BrowserTheme.secondaryInk)
            }
            Text(model.watcher.isRunning ? "Watching focus" : "Watcher off")
                .foregroundStyle(model.watcher.isRunning
                                 ? BrowserTheme.mintInk : BrowserTheme.coral)
            Text("Local archive · optional external tagging").foregroundStyle(BrowserTheme.secondaryInk)
        }
        .font(.caption).padding(10)
    }

    private var statusText: String {
        switch workspace {
        case .attention: "Real focused time, live"
        case .dashboard: "Unified browsing archive"
        case .history: "Every visit, every browser"
        case .permissions: "Access and grants"
        }
    }

    private var about: some View {
        VStack(spacing: 16) {
            DaddyArtwork().frame(width: 110, height: 110)
            Text("browserdaddy")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("Where your time on the web actually goes.")
                .foregroundStyle(BrowserTheme.secondaryInk)
            Text("Your archive stays on this Mac. Optional topic tagging sends selected browsing text to classifier.dev with your consent.")
                .font(.callout).foregroundStyle(BrowserTheme.mintInk)
            Button("Done") { model.showAbout = false }
                .buttonStyle(DaddyButtonStyle(prominent: true))
        }
        .padding(32).frame(width: 340).background(Color.black)
    }
}
