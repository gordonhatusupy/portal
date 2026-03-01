import Foundation

public final class ProcessInspectionService: @unchecked Sendable {
    private let shellCommandRunner: ShellCommandRunner
    private let psDateFormatter: DateFormatter

    public init(shellCommandRunner: ShellCommandRunner = ShellCommandRunner()) {
        self.shellCommandRunner = shellCommandRunner
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"
        self.psDateFormatter = formatter
    }

    public func listListeningSockets() async throws -> [ListeningSocket] {
        let result = try await shellCommandRunner.run(
            executable: "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"],
            timeout: 1.0
        )

        if result.status != 0 && result.stdout.isEmpty {
            throw ShellCommandError.failedToLaunch(result.stderr)
        }

        return LsofParser.parseListeningSockets(result.stdout)
    }

    public func processContext(for socket: ListeningSocket) async -> ProcessContext {
        async let cwd = currentWorkingDirectory(for: socket.pid)
        async let executablePath = executablePath(for: socket.pid)
        async let startedAt = processStartDate(for: socket.pid)

        let resolvedExecutablePath = await executablePath
        let resolvedStartedAt = await startedAt
        let resolvedCwd = await cwd

        return ProcessContext(
            pid: socket.pid,
            processName: socket.processName,
            executablePath: resolvedExecutablePath,
            currentWorkingDirectory: resolvedCwd,
            startedAt: resolvedStartedAt
        )
    }

    private func currentWorkingDirectory(for pid: Int32) async -> URL? {
        do {
            let result = try await shellCommandRunner.run(
                executable: "/usr/sbin/lsof",
                arguments: ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"],
                timeout: 0.75
            )
            return LsofParser.parseCurrentWorkingDirectory(result.stdout)
        } catch {
            return nil
        }
    }

    private func executablePath(for pid: Int32) async -> URL? {
        do {
            let result = try await shellCommandRunner.run(
                executable: "/bin/ps",
                arguments: ["-p", "\(pid)", "-o", "comm="],
                timeout: 0.75
            )

            let command = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            guard command.hasPrefix("/") else { return nil }
            return URL(fileURLWithPath: command)
        } catch {
            return nil
        }
    }

    private func processStartDate(for pid: Int32) async -> Date? {
        do {
            let result = try await shellCommandRunner.run(
                executable: "/bin/ps",
                arguments: ["-p", "\(pid)", "-o", "lstart="],
                timeout: 0.75
            )

            let rawDate = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return psDateFormatter.date(from: rawDate)
        } catch {
            return nil
        }
    }
}
