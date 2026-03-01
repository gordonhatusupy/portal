import Foundation

public struct ProjectRootResolver {
    public let fileManager: FileManager
    public let homeDirectoryOverride: URL?
    private let markers = [
        ".git",
        "package.json",
        "Cargo.toml",
        "Gemfile",
        "pyproject.toml",
        "go.mod",
        "composer.json",
        "mix.exs",
        "Package.swift"
    ]

    public init(fileManager: FileManager = .default, homeDirectoryOverride: URL? = nil) {
        self.fileManager = fileManager
        self.homeDirectoryOverride = homeDirectoryOverride
    }

    public func resolveBest(cwd: URL?, executablePath: URL?) -> URL? {
        if let cwd, let resolved = resolve(from: cwd) {
            return resolved
        }

        if let executablePath {
            let start = executablePath.hasDirectoryPath ? executablePath : executablePath.deletingLastPathComponent()
            return resolve(from: start)
        }

        return nil
    }

    public func resolve(from seed: URL?) -> URL? {
        guard var current = seed?.standardizedFileURL else { return nil }
        let homeDirectory = (homeDirectoryOverride ?? fileManager.homeDirectoryForCurrentUser).standardizedFileURL
        let stopAtHome = current.path == homeDirectory.path || current.path.hasPrefix(homeDirectory.path + "/")

        if !fileManager.fileExists(atPath: current.path), current.path != "/" {
            current = current.deletingLastPathComponent()
        }

        while true {
            if containsProjectMarker(at: current) {
                return current
            }

            if stopAtHome && current.path == homeDirectory.path {
                return nil
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                return nil
            }
            current = parent
        }
    }

    private func containsProjectMarker(at directory: URL) -> Bool {
        markers.contains { marker in
            fileManager.fileExists(atPath: directory.appendingPathComponent(marker).path)
        }
    }
}
