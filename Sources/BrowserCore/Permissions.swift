import AppKit
import Foundation

/// Honest permission state — probe reality, don't assume.
public enum Permissions {
    public enum AutomationState: Sendable, Equatable {
        case granted, denied, notRunning, unknown
    }

    /// FDA probe: can we actually read bytes from a TCC-protected file?
    public static func hasFullDiskAccess() -> Bool {
        let probe = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari/History.db")
        guard let fh = try? FileHandle(forReadingFrom: probe) else {
            return false
        }
        defer { try? fh.close() }
        return (try? fh.read(upToCount: 16)) != nil
    }

    /// Per-browser Automation consent. Only probes running browsers —
    /// sending Apple events to a non-running app would launch it.
    public static func automationState(
        for scriptName: String
    ) -> AutomationState {
        let script = NSAppleScript(source: """
            tell application "System Events" to get exists \
            (first process whose name is "\(scriptName)")
        """)
        var err: NSDictionary?
        let running = script?.executeAndReturnError(&err)
            .booleanValue ?? false
        guard running else { return .notRunning }

        let probe = NSAppleScript(source: """
            tell application "\(scriptName)" to count windows
        """)
        var probeErr: NSDictionary?
        _ = probe?.executeAndReturnError(&probeErr)
        guard let e = probeErr else { return .granted }
        let code = e[NSAppleScript.errorNumber] as? Int ?? 0
        return code == -1743 ? .denied : .granted  // -1719 no window = granted
    }

    public static func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }

    public static func openAutomationSettings() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }
}
