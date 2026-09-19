import SwiftUI
import BrowserCore

struct PermissionsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("History access (Full Disk Access)") {
                HStack {
                    statusDot(model.fda)
                    Text(model.fda
                         ? "Full Disk Access granted — history readable"
                         : "Not granted — history extraction is blocked")
                    Spacer()
                    Button("Open Full Disk Access Settings") {
                        Permissions.openFullDiskAccessSettings()
                    }
                }
                Text("Add BrowserDaddy to System Settings → Privacy & Security "
                     + "→ Full Disk Access, then relaunch.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Tab URLs (Automation consent per browser)") {
                ForEach(FocusWatcher.scriptableBrowsers.values.sorted(),
                        id: \.self) { name in
                    HStack {
                        statusDot(model.automation[name] == .granted)
                        Text(name)
                        Spacer()
                        Text(stateLabel(model.automation[name]))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Spacer()
                    Button("Open Automation Settings") {
                        Permissions.openAutomationSettings()
                    }
                    Button("Re-check") { model.refreshPermissions() }
                }
            }

            Section("Collection") {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }))
                HStack {
                    Button("Extract history now") { model.runExtract() }
                        .disabled(model.extracting)
                    if model.extracting { ProgressView() }
                }
                ForEach(model.extractLog, id: \.self) {
                    Text($0).font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Section("Data") {
                LabeledContent("Archive", value: ArchiveStore.defaultURL.path)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func statusDot(_ ok: Bool) -> some View {
        Circle().fill(ok ? .green : .orange).frame(width: 8, height: 8)
    }

    private func stateLabel(_ s: Permissions.AutomationState?) -> String {
        switch s {
        case .granted: return "granted"
        case .denied: return "denied — enable in Settings"
        case .notRunning: return "browser not running"
        default: return "unknown"
        }
    }
}
