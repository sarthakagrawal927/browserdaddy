import AppKit
import BrowserCore
import Carbon.HIToolbox

private func fourCharCode(_ s: String) -> OSType {
    s.utf8.reduce(0) { ($0 << 8) | OSType($1) }
}

/// Infra for the link router: receives GURL AppleEvents when BrowserDaddy
/// is the default browser, owns the Carbon global hotkeys, and drives the
/// picker panel. Behavior lives in AppModel — this is plumbing.
@MainActor
final class LinkRouterService: NSObject {
    static let shared = LinkRouterService()

    weak var model: AppModel?
    let picker = LinkPickerPanelController()
    private var pendingURL: URL?
    private var installed = false
    private var lastSuccessfulRouteAt: Date?

    var justRoutedLink: Bool {
        guard let lastSuccessfulRouteAt else { return false }
        return Date().timeIntervalSince(lastSuccessfulRouteAt) < 1
    }

    // ⌃⌥O — clipboard link picker; ⌃⌥Space — move current tab.
    static let clipboardKey = (code: UInt32(kVK_ANSI_O), name: "⌃⌥O")
    static let moveTabKey = (code: UInt32(kVK_Space), name: "⌃⌥Space")
    static let modifiers = UInt32(controlKey | optionKey)
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var clipboardTimer: Timer?
    private var lastChangeCount = 0

    func install() {
        guard !installed else { return }
        installed = true
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReply:)),
            forEventClass: AEEventClass(fourCharCode("GURL")),
            andEventID: AEEventID(fourCharCode("GURL")))
        hotKeyRefs = [
            GlobalHotKey.install(keyCode: Self.clipboardKey.code,
                                 modifiers: Self.modifiers) { [weak self] in
                Task { @MainActor in self?.model?.openClipboardLink() }
            },
            GlobalHotKey.install(keyCode: Self.moveTabKey.code,
                                 modifiers: Self.modifiers) { [weak self] in
                Task { @MainActor in self?.model?.moveCurrentTab() }
            },
        ]
        // No clipboard event on macOS — poll changeCount. Cheap and enough.
        lastChangeCount = NSPasteboard.general.changeCount
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.4,
                                              repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollClipboard() }
        }
    }

    private func pollClipboard() {
        let count = NSPasteboard.general.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        model?.clipboardPasted()
    }

    /// Clicked link while BrowserDaddy is default browser — silent routing.
    @objc private func handleGetURL(_ event: NSAppleEventDescriptor,
                                    withReply reply: NSAppleEventDescriptor) {
        guard let raw = event.paramDescriptor(forKeyword: keyDirectObject)?
                .stringValue,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return }
        if let model {
            if model.route(url) { hideAfterRouting() }
        } else {
            pendingURL = url
        }
    }

    /// Called once the AppModel exists — replays a link that arrived during
    /// startup before the model was bound.
    func drainPending() {
        guard let url = pendingURL, let model else { return }
        pendingURL = nil
        if model.route(url) { hideAfterRouting() }
    }

    private func hideAfterRouting() {
        lastSuccessfulRouteAt = Date()
        NSApplication.shared.hide(nil)
        // A cold launch can create its SwiftUI window after the URL event.
        DispatchQueue.main.async { NSApplication.shared.hide(nil) }
    }
}

/// Carbon RegisterEventHotKey — system-wide hotkeys with no accessibility
/// or input-monitoring permission. C callbacks can't be actor-isolated, so
/// shared state sits in a lock-guarded box.
enum GlobalHotKey {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var handlers: [UInt32: () -> Void] = [:]
        var dispatcherInstalled = false
        var nextID: UInt32 = 1
    }
    private static let state = State()

    @discardableResult
    static func install(keyCode: UInt32, modifiers: UInt32,
                        handler: @escaping () -> Void) -> EventHotKeyRef? {
        state.lock.lock()
        installDispatcherLocked()
        let id = state.nextID
        state.nextID += 1
        state.handlers[id] = handler
        state.lock.unlock()
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: fourCharCode("BDLK"), id: id)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetEventDispatcherTarget(), 0, &ref)
        return ref
    }

    private static func installDispatcherLocked() {
        guard !state.dispatcherInstalled else { return }
        state.dispatcherInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let handler: (() -> Void)? = GlobalHotKey.state.lock.withLock {
                GlobalHotKey.state.handlers[hotKeyID.id]
            }
            if let handler {
                DispatchQueue.main.async { handler() }
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
