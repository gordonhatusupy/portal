import Foundation

public actor GitInfoService {
    private struct CacheEntry {
        let branch: String?
        let expiresAt: Date
    }

    private let shellCommandRunner: ShellCommandRunner
    private var cache: [URL: CacheEntry] = [:]
    private let cacheTTL: TimeInterval

    public init(shellCommandRunner: ShellCommandRunner = ShellCommandRunner(), cacheTTL: TimeInterval = 10) {
        self.shellCommandRunner = shellCommandRunner
        self.cacheTTL = cacheTTL
    }

    public func branch(for projectRoot: URL) async -> String? {
        let normalizedURL = projectRoot.standardizedFileURL

        if let entry = cache[normalizedURL], entry.expiresAt > Date() {
            return entry.branch
        }

        let branch: String?
        do {
            let result = try await shellCommandRunner.run(
                executable: "/usr/bin/git",
                arguments: ["-C", normalizedURL.path, "rev-parse", "--abbrev-ref", "HEAD"],
                timeout: 1.0
            )
            let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            branch = value.isEmpty ? nil : value
        } catch {
            branch = nil
        }

        cache[normalizedURL] = CacheEntry(branch: branch, expiresAt: Date().addingTimeInterval(cacheTTL))
        return branch
    }
}
