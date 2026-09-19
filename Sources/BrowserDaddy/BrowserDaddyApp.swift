import SwiftUI

@main
struct BrowserDaddyApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("browserdaddy") {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 880, minHeight: 600)
                .onAppear { model.boot() }
        }
        .defaultSize(width: 1200, height: 780)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Extract History") { model.runExtract() }
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
    case dashboard = "Dashboard", history = "History", permissions = "Permissions"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.xaxis"
        case .history: return "clock.arrow.circlepath"
        case .permissions: return "lock.shield"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var workspace: Workspace = .dashboard

    var body: some View {
        NavigationSplitView {
            List(Workspace.allCases, selection: $workspace) { ws in
                Label(ws.rawValue, systemImage: ws.icon).tag(ws)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            switch workspace {
            case .dashboard: DashboardView()
            case .history: HistoryView()
            case .permissions: PermissionsView()
            }
        }
    }
}
