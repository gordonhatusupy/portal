import AppKit
import Combine
import PortalCore
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private enum Layout {
        static let width: CGFloat = 420
        static let loadingHeight: CGFloat = 122
        static let emptyHeight: CGFloat = 168
        static let minimumReadyHeight: CGFloat = 144
        static let maximumReadyHeight: CGFloat = 360
        static let chromeHeight: CGFloat = 66
        static let rowHeight: CGFloat = 58
        static let rowSpacing: CGFloat = 1
        static let topOffset: CGFloat = 6
        static let screenPadding: CGFloat = 8
    }

    private final class FloatingPanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }

    private final class ClickThroughHostingController<Content: View>: NSHostingController<Content> {
        override func loadView() {
            view = ClickThroughHostingView(rootView: rootView)
        }
    }

    private let statusItem: NSStatusItem
    private let panel: FloatingPanel
    private let hostingController: ClickThroughHostingController<PortalPopoverView>
    private let viewModel: PortalViewModel
    private let onQuit: () -> Void

    private var stateCancellable: AnyCancellable?
    private var lastActionErrorCancellable: AnyCancellable?
    private var lastActionSuccessCancellable: AnyCancellable?
    private var isAttemptingToOpen = false
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    init(viewModel: PortalViewModel, onQuit: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onQuit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.hostingController = ClickThroughHostingController(
            rootView: PortalPopoverView(viewModel: viewModel, onQuit: onQuit)
        )
        self.panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: Layout.width, height: Layout.loadingHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )

        super.init()
        configureStatusItem()
        configurePanel()
        bindPanelSize()
    }

    @objc private func togglePanel(_ sender: AnyObject?) {
        if panel.isVisible {
            closePanel()
        } else {
            requestOpenPanel()
        }
    }

    func openPanelFromDock() {
        if panel.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            return
        }

        requestOpenPanel()
    }

    private func closePanel() {
        isAttemptingToOpen = false
        panel.orderOut(nil)
        removeEventMonitors()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "bolt.horizontal.circle", accessibilityDescription: "Portal")
        button.image?.isTemplate = true
        button.action = #selector(togglePanel(_:))
        button.target = self
        button.toolTip = "Portal"
    }

    private func configurePanel() {
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.contentViewController = hostingController
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func bindPanelSize() {
        stateCancellable = viewModel.$state
            .sink { [weak self] state in
                self?.updatePanelSize(for: state)
            }

        lastActionErrorCancellable = viewModel.$lastActionError
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.updatePanelSize(for: self.viewModel.state)
            }

        lastActionSuccessCancellable = viewModel.$lastActionSuccess
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.updatePanelSize(for: self.viewModel.state)
            }

        updatePanelSize(for: viewModel.state)
    }

    private func installEventMonitors() {
        guard globalEventMonitor == nil, localEventMonitor == nil else { return }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closeIfNeededForCurrentMouseLocation()
            }
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            Task { @MainActor in
                self?.closeIfNeededForCurrentMouseLocation()
            }
            return event
        }
    }

    private func removeEventMonitors() {
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }

        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
    }

    private func closeIfNeededForCurrentMouseLocation() {
        guard panel.isVisible else { return }

        let mouseLocation = NSEvent.mouseLocation
        if panel.frame.contains(mouseLocation) {
            return
        }

        if let buttonFrame = resolvedStatusButtonScreenFrame(), buttonFrame.contains(mouseLocation) {
            return
        }

        closePanel()
    }

    private func requestOpenPanel() {
        guard !panel.isVisible, !isAttemptingToOpen else { return }

        isAttemptingToOpen = true
        showPanel(retryCount: 0)
    }

    private func showPanel(retryCount: Int) {
        guard !panel.isVisible else {
            isAttemptingToOpen = false
            return
        }

        guard let buttonFrame = resolvedStatusButtonScreenFrame() else {
            if retryCount < 3 {
                DispatchQueue.main.async { [weak self] in
                    self?.showPanel(retryCount: retryCount + 1)
                }
            } else {
                isAttemptingToOpen = false
            }
            return
        }

        updatePanelSize(for: viewModel.state)
        positionPanel(relativeTo: buttonFrame)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installEventMonitors()
        isAttemptingToOpen = false

        DispatchQueue.main.async { [weak self] in
            self?.viewModel.refreshNow()
        }
    }

    private func resolvedStatusButtonScreenFrame() -> NSRect? {
        guard
            let button = statusItem.button,
            let window = button.window
        else {
            return nil
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let frame = window.convertToScreen(buttonFrameInWindow)
        guard frame.width > 0, frame.height > 0 else {
            return nil
        }
        return frame
    }

    private func positionPanel(relativeTo buttonFrame: NSRect) {
        let screenFrame = buttonFrame == .zero
            ? NSScreen.main?.visibleFrame ?? .zero
            : (statusItem.button?.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero)

        let panelSize = panel.frame.size

        let proposedX = buttonFrame.maxX - panelSize.width
        let minX = screenFrame.minX + Layout.screenPadding
        let maxX = screenFrame.maxX - panelSize.width - Layout.screenPadding
        let clampedX = min(max(proposedX, minX), maxX)

        let proposedY = buttonFrame.minY - panelSize.height - Layout.topOffset
        let minY = screenFrame.minY + Layout.screenPadding
        let finalY = max(proposedY, minY)

        panel.setFrameOrigin(NSPoint(x: clampedX, y: finalY))
    }

    private func updatePanelSize(for state: ServerListState) {
        let height: CGFloat

        switch state {
        case .loading, .softError:
            height = Layout.loadingHeight
        case .empty:
            height = Layout.emptyHeight
        case let .ready(servers):
            let rowCount = max(1, servers.count)
            let contentHeight =
                Layout.chromeHeight +
                (CGFloat(rowCount) * Layout.rowHeight) +
                (CGFloat(max(0, rowCount - 1)) * Layout.rowSpacing)

            height = min(
                max(Layout.minimumReadyHeight, contentHeight),
                Layout.maximumReadyHeight
            )
        }

        let accessoryHeight: CGFloat =
            (viewModel.lastActionSuccess == nil ? 0 : 34) +
            (viewModel.lastActionError == nil ? 0 : 34)
        let totalHeight = height + accessoryHeight

        panel.setContentSize(NSSize(width: Layout.width, height: totalHeight))

        if panel.isVisible, let buttonFrame = resolvedStatusButtonScreenFrame() {
            positionPanel(relativeTo: buttonFrame)
        }
    }
}
