import DSCore
import Foundation
import Testing

@Suite("DSCLI adapter and audit smoke")
struct AdapterAndAuditCLISmokeTests {
    @Test("dsctl sync-penpot writes an adapter manifest")
    func syncPenpot() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let outputDirectory = fixture.root.appendingPathComponent("build/penpot", isDirectory: true)
        let result = try runCLI([
            "sync-penpot",
            "--app", fixture.appURL.path,
            "--out", outputDirectory.path,
            "--json",
        ], root: fixture.root)

        let report = try JSONDecoder().decode(AdapterSyncReport.self, from: Data(result.stdout.utf8))

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.adapter == .penpot)
        #expect(FileManager.default.fileExists(atPath: report.manifestPath))
    }

    @Test("dsctl sync-pencil writes an adapter manifest")
    func syncPencil() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let outputDirectory = fixture.root.appendingPathComponent("build/pencil", isDirectory: true)
        let result = try runCLI([
            "sync-pencil",
            "--app", fixture.appURL.path,
            "--out", outputDirectory.path,
            "--json",
        ], root: fixture.root)

        let report = try JSONDecoder().decode(AdapterSyncReport.self, from: Data(result.stdout.utf8))

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.adapter == .pencil)
        #expect(FileManager.default.fileExists(atPath: report.tokenPayloadPath))
    }

    @Test("dsctl audit runs the contract/adapter/native loop")
    func auditApp() throws {
        let result = try runCLI([
            "audit",
            "--project-root", repositoryRoot().path,
            "--json",
        ], root: repositoryRoot())

        let report = try JSONDecoder().decode(RepoAuditReport.self, from: Data(result.stdout.utf8))

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.errors.isEmpty)
    }

    @Test("dsctl help exposes adapter sync and audit commands")
    func help() throws {
        let result = try runCLI(["--help"], root: repositoryRoot())

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("sync-penpot"))
        #expect(result.stdout.contains("sync-pencil"))
        #expect(result.stdout.contains("audit"))
    }

    private func runCLI(_ arguments: [String], root: URL) throws -> CLIResult {
        let process = Process()
        process.executableURL = repositoryRoot().appendingPathComponent(".build/debug/dsctl")
        process.arguments = arguments
        process.currentDirectoryURL = root

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        return CLIResult(
            exitCode: Int(process.terminationStatus),
            stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }

    private func makeFixture() throws -> (root: URL, appURL: URL) {
        let root = try makeTemporaryDirectory()
        let appURL = repositoryRoot().appendingPathComponent("contracts/apps/commerce.app.yaml")
        return (root, appURL)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-contract-adapter-cli-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct CLIResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
