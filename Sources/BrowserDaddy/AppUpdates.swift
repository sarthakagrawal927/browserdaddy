import AppKit
import Combine
import Sparkle

/// User-initiated updates only: automatic checks on, automatic install off.
/// Checks and relaunches wait for an idle app — never during a history sync.
/// In dev runs without a signed SUPublicEDKey this stays inert; no update
/// machinery touches the system.
@MainActor final class AppUpdates: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published var canCheck = false
    @Published var automaticallyChecks = true {
        didSet { controller?.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }
    @Published var waitingForIdle = false
    private var controller: SPUStandardUpdaterController?
    private weak var model: AppModel?
    private var deferredInstall: (() -> Void)?
    private var subscriptions: Set<AnyCancellable> = []

    func start(model: AppModel) {
        guard controller == nil,
              Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") is String else { return }
        self.model = model
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.resumeWhenIdle() }.store(in: &subscriptions)
        controller.startUpdater()
    }

    var isIdle: Bool {
        guard let model else { return false }
        return !model.extracting
    }

    func check() { controller?.checkForUpdates(nil) }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard isIdle else {
            throw NSError(domain: "BrowserDaddy.Updates", code: 1, userInfo: [NSLocalizedDescriptionKey: "Finish the current history sync before checking for updates."])
        }
    }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem, untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard !isIdle else { return false }
        deferredInstall = installHandler
        waitingForIdle = true
        return true
    }

    private func resumeWhenIdle() {
        guard isIdle, let install = deferredInstall else { return }
        deferredInstall = nil
        waitingForIdle = false
        install()
    }
}
