import Combine
import Foundation
import PortalCore

@MainActor
final class PortalViewModel: ObservableObject {
    @Published private(set) var state: ServerListState = .loading
    @Published private(set) var busyServerIDs: Set<String> = []
    @Published private(set) var lastActionError: String?
    @Published private(set) var lastActionSuccess: String?
    @Published private(set) var isRefreshing = false

    private let discoveryService: ServerDiscoveryServing
    private let actionService: ServerActionServing
    private var successResetTask: Task<Void, Never>?

    init(
        discoveryService: ServerDiscoveryServing = ServerDiscoveryService(),
        actionService: ServerActionServing = ServerActionService()
    ) {
        self.discoveryService = discoveryService
        self.actionService = actionService

        self.discoveryService.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.state = state
            }
        }

        self.discoveryService.start()
    }

    func refreshNow() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            await discoveryService.refreshNow()
            self.isRefreshing = false
        }
    }

    func open(_ server: ServerRecord) {
        lastActionSuccess = nil
        actionService.open(server)
    }

    func kill(_ server: ServerRecord) {
        guard !busyServerIDs.contains(server.id) else { return }
        var updatedBusyServerIDs = busyServerIDs
        updatedBusyServerIDs.insert(server.id)
        busyServerIDs = updatedBusyServerIDs
        lastActionError = nil
        lastActionSuccess = nil

        Task {
            do {
                try await actionService.kill(server)

                await MainActor.run {
                    if case let .ready(servers) = self.state {
                        let updatedServers = servers.filter { $0.id != server.id }
                        self.state = updatedServers.isEmpty ? .empty : .ready(updatedServers)
                    }
                }

                await MainActor.run {
                    self.showSuccess("Stopped \(server.appName)")
                }

                await discoveryService.refreshNow()
            } catch {
                await MainActor.run {
                    self.lastActionSuccess = nil
                    self.lastActionError = error.localizedDescription
                }
            }

            _ = await MainActor.run {
                var updatedBusyServerIDs = self.busyServerIDs
                updatedBusyServerIDs.remove(server.id)
                self.busyServerIDs = updatedBusyServerIDs
            }
        }
    }

    private func showSuccess(_ message: String) {
        successResetTask?.cancel()
        lastActionSuccess = message

        successResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self?.lastActionSuccess == message else { return }
                self?.lastActionSuccess = nil
            }
        }
    }
}
