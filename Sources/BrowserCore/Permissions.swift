import AppKit
import Foundation

/// Honest permission state — probe reality, don't assume.
public enum Permissions {
    public enum AutomationState: Sendable, Equatable {
        case granted, denied, notRunning, unknown
    }

    /// Per-browser Automation consent. NSRunningApplication avoids scripting
    /// System Events; the browser probe runs only when that exact app is open.
    public static func automationState(
        bundleID: String, scriptName: String
    ) -> AutomationState {
        guard !NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID).isEmpty else { return .notRunning }

        let probe = NSAppleScript(source: """
            tell application "\(scriptName)" to count windows
        """)
        var probeErr: NSDictionary?
        _ = probe?.executeAndReturnError(&probeErr)
        guard let e = probeErr else { return .granted }
        let code = e[NSAppleScript.errorNumber] as? Int ?? 0
        return code == -1743 ? .denied : .granted  // -1719 no window = granted
    }

    public static func openAutomationSettings() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }
}
