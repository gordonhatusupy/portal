import Foundation
import PortalCore
import XCTest

final class ProjectRootResolverTests: XCTestCase {
    func testResolvesGitRoot() throws {
        let tempDirectory = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let projectRoot = tempDirectory.appendingPathComponent("demo-app", isDirectory: true)
        let nestedDirectory = projectRoot.appendingPathComponent("Sources/Web", isDirectory: true)

        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: projectRoot.appendingPathComponent(".git").path, contents: Data())

        let resolver = ProjectRootResolver(homeDirectoryOverride: tempDirectory)
        XCTAssertEqual(resolver.resolve(from: nestedDirectory), projectRoot)
    }

    func testResolvesManifestRootWithoutGit() throws {
        let tempDirectory = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let projectRoot = tempDirectory.appendingPathComponent("portal", isDirectory: true)
        let nestedDirectory = projectRoot.appendingPathComponent("App/UI", isDirectory: true)

        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: projectRoot.appendingPathComponent("Package.swift").path, contents: Data())

        let resolver = ProjectRootResolver(homeDirectoryOverride: tempDirectory)
        XCTAssertEqual(resolver.resolve(from: nestedDirectory), projectRoot)
    }

    func testReturnsNilOutsideProjectBoundaries() throws {
        let tempDirectory = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let leafDirectory = tempDirectory.appendingPathComponent("scratch/demo", isDirectory: true)
        try FileManager.default.createDirectory(at: leafDirectory, withIntermediateDirectories: true)

        let resolver = ProjectRootResolver(homeDirectoryOverride: tempDirectory)
        XCTAssertNil(resolver.resolve(from: leafDirectory))
    }

    func testReturnsNilForRootDirectory() {
        let resolver = ProjectRootResolver()
        XCTAssertNil(resolver.resolve(from: URL(fileURLWithPath: "/")))
    }

    func testReturnsNilForRootDirectoryViaResolveBest() {
        let resolver = ProjectRootResolver()
        XCTAssertNil(resolver.resolveBest(cwd: URL(fileURLWithPath: "/"), executablePath: nil))
    }

    private func createTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
