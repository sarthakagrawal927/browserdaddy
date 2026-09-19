import SwiftUI

@main
struct BrowserDaddyApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("browserdaddy") {
            Group {
                if model.needsOnboarding { OnboardingView() }
                else { RootView() }
            }
            .environmentObject(model)
            .frame(minWidth: 920, minHeight: 620)
            .onAppear { model.boot() }
            .preferredColorScheme(.dark)
            .tint(BrowserTheme.action)
            .buttonStyle(DaddyButtonStyle())
        }
        .defaultSize(width: 1240, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About browserdaddy") { model.showAbout = true }
            }
            CommandGroup(after: .newItem) {
                Button("Sync History") { model.runExtract() }
                    .keyboardShortcut("e")
                    .disabled(model.extracting)
                Button("Refresh Report") {
                    Task { await model.reload() }
                }.keyboardShortcut("r")
            }
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
    @State private var workspace: Workspace = .attention

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

            VStack(alignment: .leading, spacing: 7) {
                navigationHeading("DADDY SERIES")
                Text("On your Mac. Under your control.").font(.caption)
                Text("Private browsing stays private.").font(.caption)
            }
            .foregroundStyle(BrowserTheme.secondaryInk)
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
            Spacer()
            if let r = model.report {
                Text("\(r.totalVisits.formatted()) visits")
                    .monospacedDigit().foregroundStyle(BrowserTheme.secondaryInk)
            }
            Text(model.watcher.isRunning ? "Watching focus" : "Watcher off")
                .foregroundStyle(model.watcher.isRunning
                                 ? BrowserTheme.mintInk : BrowserTheme.coral)
            Text("On-device only").foregroundStyle(BrowserTheme.secondaryInk)
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
            DaddyArtwork(brand: true).frame(width: 110, height: 110)
            Text("browserdaddy")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("Where your time on the web actually goes.")
                .foregroundStyle(BrowserTheme.secondaryInk)
            Text("Local archive. Real attention. Nothing leaves this Mac.")
                .font(.callout).foregroundStyle(BrowserTheme.mintInk)
            Button("Done") { model.showAbout = false }
                .buttonStyle(DaddyButtonStyle(prominent: true))
        }
        .padding(32).frame(width: 340).background(Color.black)
    }
}
