import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let viewModel = PortalViewModel()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.statusBarController = StatusBarController(viewModel: self.viewModel) {
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.openPanelFromDock()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController = nil
    }
}
