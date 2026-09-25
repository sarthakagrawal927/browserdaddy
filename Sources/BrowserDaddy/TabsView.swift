import AppKit
import BrowserCore
import Combine
import SwiftUI

/// Live cross-browser tab inventory. Reads are AppleScript; closes/moves are
/// user-initiated. Chrome/Brave incognito windows are filtered at the source.
struct TabsView: View {
    @EnvironmentObject private var model: AppModel
    private let refreshTimer = Timer.publish(every: 15, on: .main,
                                             in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if model.tabGroups.isEmpty {
                emptyState
            } else {
                tabList
            }
        }
        .background(BrowserTheme.fog)
        .onAppear { model.refreshTabs() }
        .onReceive(refreshTimer) { _ in model.refreshTabs() }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            TextField("Filter tabs…", text: $model.tabSearch)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)
            if !model.tabSelection.isEmpty {
                Button("Focus") { focusSelected() }
                Button("Close \(model.tabSelection.count) tabs") {
                    let ids = model.tabSelection
                    model.closeTabs(model.allTabs.filter { ids.contains($0.id) })
                    model.tabSelection = []
                }
                .buttonStyle(DaddyButtonStyle(prominent: true))
            }
            Spacer()
            if model.tabsRefreshing {
                ProgressView().controlSize(.small)
            }
            Button("Refresh") { model.refreshTabs() }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            if model.tabsRefreshing {
                ProgressView()
                Text("Reading open tabs…")
            } else {
                Text("No scriptable browsers found")
                    .foregroundStyle(BrowserTheme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(BrowserTheme.secondaryInk)
    }

    private var tabList: some View {
        List(selection: $model.tabSelection) {
            ForEach(model.filteredTabGroups) { group in
                Section {
                    switch group.state {
                    case .tabs(let tabs):
                        ForEach(tabs) { tab in
                            tabRow(tab)
                        }
                    case .noWindows:
                        stateNote("no open windows")
                    case .needsConsent:
                        HStack(spacing: 8) {
                            Text("needs Automation permission — ")
                            Button("Allow \(group.kind.displayName)") {
                                model.requestTabConsent(group.kind)
                            }
                            .buttonStyle(.link)
                            Text("·")
                            Button("Open Settings") {
                                NSWorkspace.shared.open(URL(string:
                                    "x-apple.systempreferences:"
                                    + "com.apple.preference.security"
                                    + "?Privacy_Automation")!)
                            }
                            .buttonStyle(.link)
                        }
                        .font(.caption)
                        .foregroundStyle(BrowserTheme.secondaryInk.opacity(0.7))
                        .padding(.vertical, 4)
                    case .unsupported:
                        stateNote("not scriptable — tabs can't be listed")
                    case .failed(let msg):
                        stateNote("couldn't read tabs — \(msg)")
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text(group.kind.displayName)
                            .font(.headline)
                            .foregroundStyle(BrowserTheme.secondaryInk)
                        if case .tabs(let tabs) = group.state {
                            Text("\(tabs.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(BrowserTheme.mintInk)
                        }
                        Spacer()
                        Text("drop tabs here to move")
                            .font(.caption2)
                            .foregroundStyle(BrowserTheme.secondaryInk.opacity(0.5))
                    }
                    .padding(.vertical, 4)
                    .dropDestination(for: BrowserTab.self) { items, _ in
                        guard let tab = items.first,
                              tab.browser != group.kind else { return false }
                        model.moveTab(tab, to: model.firstTarget(for: group.kind))
                        return true
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .scrollContentBackground(.hidden)
    }

    private func tabRow(_ tab: BrowserTab) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title.isEmpty ? tab.url : tab.title)
                    .font(.callout)
                    .foregroundStyle(BrowserTheme.ink)
                    .lineLimit(1).truncationMode(.middle)
                Text(tab.host)
                    .font(.caption.monospaced())
                    .foregroundStyle(BrowserTheme.secondaryInk)
                    .lineLimit(1)
            }
            Spacer()
            Text("w\(tab.window)·t\(tab.index)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(BrowserTheme.secondaryInk.opacity(0.6))
            Button { model.closeTab(tab) } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BrowserTheme.coral)
            }
            .buttonStyle(.plain)
            .help("Close tab")
        }
        .padding(.vertical, 2)
        .draggable(tab)
        .onTapGesture(count: 2) { model.focusTab(tab) }
        .contextMenu {
            Button("Focus tab") { model.focusTab(tab) }
            Button("Close tab") { model.closeTab(tab) }
            Divider()
            Menu("Send to") {
                ForEach(model.routerTargets().filter {
                    $0.browser != tab.browser
                }) { target in
                    Button(targetLabel(target)) {
                        model.moveTab(tab, to: target)
                    }
                }
            }
            Divider()
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(tab.url, forType: .string)
            }
        }
        .tag(tab.id)
    }

    private func targetLabel(_ target: LinkTarget) -> String {
        guard !target.profile.isEmpty else { return target.browser.displayName }
        let name = model.routerProfileNames[target.id]
        let shown = name.map { $0 == target.profile ? $0
            : "\($0) (\(target.profile))" } ?? target.profile
        return "\(target.browser.displayName) · \(shown)"
    }

    private func stateNote(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(BrowserTheme.secondaryInk.opacity(0.7))
            .padding(.vertical, 4)
    }

    private func focusSelected() {
        guard let first = model.allTabs.first(where: {
            model.tabSelection.contains($0.id)
        }) else { return }
        model.focusTab(first)
    }
}
