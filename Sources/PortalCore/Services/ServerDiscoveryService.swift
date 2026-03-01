import Foundation

@MainActor
public protocol ServerDiscoveryServing: AnyObject {
    var onStateChange: (@Sendable (ServerListState) -> Void)? { get set }
    func start()
    func stop()
    func refreshNow() async
}

@MainActor
public final class ServerDiscoveryService: ServerDiscoveryServing {
    public var onStateChange: (@Sendable (ServerListState) -> Void)?

    private let processInspectionService: ProcessInspectionService
    private let gitInfoService: GitInfoService
    private let projectRootResolver: ProjectRootResolver
    private var pollingTask: Task<Void, Never>?
    private var isRefreshing = false
    private var pendingRefresh = false
    private var lastKnownRecords: [ServerRecord] = []

    public init(
        processInspectionService: ProcessInspectionService = ProcessInspectionService(),
        gitInfoService: GitInfoService = GitInfoService(),
        projectRootResolver: ProjectRootResolver = ProjectRootResolver()
    ) {
        self.processInspectionService = processInspectionService
        self.gitInfoService = gitInfoService
        self.projectRootResolver = projectRootResolver
    }

    deinit {
        pollingTask?.cancel()
    }

    public func start() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refreshNow()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    public func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func refreshNow() async {
        guard !isRefreshing else {
            pendingRefresh = true
            return
        }
        isRefreshing = true
        defer {
            isRefreshing = false

            if pendingRefresh {
                pendingRefresh = false
                Task { [weak self] in
                    await self?.refreshNow()
                }
            }
        }

        if lastKnownRecords.isEmpty {
            publish(.loading)
        }

        do {
            let sockets = try await processInspectionService.listListeningSockets()
            let now = Date()
            var records: [ServerRecord] = []
            var seenIDs = Set<String>()

            for socket in sockets {
                let context = await processInspectionService.processContext(for: socket)
                let projectRoot = projectRootResolver.resolveBest(
                    cwd: context.currentWorkingDirectory,
                    executablePath: context.executablePath
                )

                guard PortFilter.shouldInclude(host: socket.host, port: socket.port, projectRoot: projectRoot) else {
                    continue
                }

                guard let projectRoot else { continue }

                let branch = await gitInfoService.branch(for: projectRoot)
                let startedAt = context.startedAt ?? now
                let id = "\(socket.pid)-\(socket.port)"
                guard seenIDs.insert(id).inserted else { continue }

                let record = ServerRecord(
                    id: id,
                    pid: socket.pid,
                    port: socket.port,
                    host: socket.host,
                    projectRoot: projectRoot,
                    appName: projectRoot.lastPathComponent,
                    gitBranch: branch,
                    startedAt: startedAt,
                    lastSeenAt: now,
                    openURL: URL(string: "http://localhost:\(socket.port)") ?? URL(fileURLWithPath: "/"),
                    processName: context.processName
                )
                records.append(record)
            }

            records.sort {
                if $0.startedAt == $1.startedAt {
                    return $0.port < $1.port
                }
                return $0.startedAt > $1.startedAt
            }

            lastKnownRecords = records
            publish(records.isEmpty ? .empty : .ready(records))
        } catch {
            if !lastKnownRecords.isEmpty {
                publish(.ready(lastKnownRecords))
            } else {
                publish(.softError("Unable to inspect local servers right now."))
            }
        }
    }

    private func publish(_ state: ServerListState) {
        onStateChange?(state)
    }
}
