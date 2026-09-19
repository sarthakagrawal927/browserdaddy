import SwiftUI
import BrowserCore

struct PermissionsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                access
                automation
                collection
                data
            }
            .padding(28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }

    private var access: some View {
        BrowserBand(label: "HISTORY",
                    subtitle: "Full Disk Access lets BrowserDaddy read browser databases") {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Circle()
                        .fill(model.fda ? BrowserTheme.mintInk : BrowserTheme.coral)
                        .frame(width: 10, height: 10)
                    Text(model.fda
                         ? "Full Disk Access granted"
                         : "Not granted — extraction is blocked")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BrowserTheme.ink)
                }
                Text("Add BrowserDaddy in System Settings → Privacy & Security "
                     + "→ Full Disk Access, then relaunch. Stores that stay "
                     + "unreadable are reported in the sync log, never silently skipped.")
                    .font(.callout).foregroundStyle(BrowserTheme.secondaryInk)
                Button("Open Full Disk Access Settings") {
                    Permissions.openFullDiskAccessSettings()
                }
            }
        }
    }

    private var automation: some View {
        BrowserBand(label: "TABS",
                    subtitle: "Per-browser Automation consent for active-tab URLs") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(FocusWatcher.scriptableBrowsers.values.sorted(),
                        id: \.self) { name in
                    HStack {
                        Circle()
                            .fill(dotColor(model.automation[name]))
                            .frame(width: 8, height: 8)
                        Text(name).font(.callout)
                            .foregroundStyle(BrowserTheme.ink)
                        Spacer()
                        Text(stateLabel(model.automation[name]))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Spacer()
                    Button("Re-check") { model.refreshPermissions() }
                    Button("Open Automation Settings") {
                        Permissions.openAutomationSettings()
                    }
                }
            }
        }
    }

    private var collection: some View {
        BrowserBand(label: "COLLECTION",
                    subtitle: "What runs while the app is alive") {
            VStack(alignment: .leading, spacing: 13) {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }))
                    .tint(BrowserTheme.mintInk)
                HStack(spacing: 12) {
                    Button(model.extracting ? "Syncing…" : "Sync history now") {
                        model.runExtract()
                    }
                    .buttonStyle(DaddyButtonStyle(prominent: true))
                    .disabled(model.extracting)
                    if model.extracting { ProgressView().controlSize(.small) }
                }
                if !model.extractLog.isEmpty {
                    Divider().overlay(BrowserTheme.divider)
                    ForEach(model.extractLog, id: \.self) {
                        Text($0).font(.caption.monospaced())
                            .foregroundStyle(BrowserTheme.secondaryInk)
                    }
                }
            }
        }
    }

    private var data: some View {
        BrowserBand(label: "DATA",
                    subtitle: "Local archive location — nothing leaves this Mac") {
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundStyle(BrowserTheme.mintInk)
                Text(ArchiveStore.defaultURL.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(BrowserTheme.secondaryInk)
                    .textSelection(.enabled)
                Spacer()
                Button("Reveal") {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [ArchiveStore.defaultURL])
                }
            }
        }
    }

    private func dotColor(_ s: Permissions.AutomationState?) -> Color {
        switch s {
        case .granted: BrowserTheme.mintInk
        case .denied: BrowserTheme.coral
        default: BrowserTheme.secondaryInk.opacity(0.5)
        }
    }

    private func stateLabel(_ s: Permissions.AutomationState?) -> String {
        switch s {
        case .granted: "granted"
        case .denied: "denied — enable in Settings"
        case .notRunning: "browser not running"
        default: "unknown"
        }
    }
}
