import DSCore
import Foundation
import Testing

@Suite("DSCLI v2 adapter and audit smoke")
struct V2AdapterAndAuditCLISmokeTests {
    @Test("dsctl v2 sync-penpot writes adapter payloads")
    func syncPenpot() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let outputDirectory = fixture.root.appendingPathComponent("build/penpot", isDirectory: true)
        let result = try runCLI([
            "v2",
            "sync-penpot",
            "--app", fixture.appURL.path,
            "--out", outputDirectory.path,
            "--json",
        ], root: fixture.root)

        let report = try JSONDecoder().decode(V2AdapterSyncReport.self, from: Data(result.stdout.utf8))

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.adapter == .penpot)
        #expect(FileManager.default.fileExists(atPath: report.manifestPath))
    }

    @Test("dsctl v2 sync-pencil writes adapter payloads")
    func syncPencil() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let outputDirectory = fixture.root.appendingPathComponent("build/pencil", isDirectory: true)
        let result = try runCLI([
            "v2",
            "sync-pencil",
            "--app", fixture.appURL.path,
            "--out", outputDirectory.path,
            "--json",
        ], root: fixture.root)

        let report = try JSONDecoder().decode(V2AdapterSyncReport.self, from: Data(result.stdout.utf8))

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.adapter == .pencil)
        #expect(FileManager.default.fileExists(atPath: report.tokenPayloadPath))
    }

    @Test("dsctl v2 audit runs the full app loop")
    func auditV2() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let outputDirectory = fixture.root.appendingPathComponent("build/audit", isDirectory: true)
        let result = try runCLI([
            "v2",
            "audit",
            "--app", fixture.appURL.path,
            "--out", outputDirectory.path,
            "--json",
        ], root: fixture.root)

        let report = try JSONDecoder().decode(V2AuditReport.self, from: Data(result.stdout.utf8))

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.htmlScreens.count == 3)
        #expect(FileManager.default.fileExists(atPath: report.sampleAppsReportPath))
    }

    @Test("dsctl v2 help exposes adapter sync and audit commands")
    func v2Help() throws {
        let result = try runCLI(["v2", "--help"], root: repositoryRoot())

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
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-v2-adapter-cli-tests-\(UUID().uuidString)", isDirectory: true)
        let fileManager = FileManager.default

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try "# Fixture root\n".write(to: root.appendingPathComponent("MASTER_BLUEPRINT.md"), atomically: true, encoding: .utf8)
        try fileManager.copyItem(at: repositoryRoot().appendingPathComponent("examples", isDirectory: true), to: root.appendingPathComponent("examples", isDirectory: true))
        try fileManager.copyItem(at: repositoryRoot().appendingPathComponent("registries", isDirectory: true), to: root.appendingPathComponent("registries", isDirectory: true))

        return (root, root.appendingPathComponent("examples/v2/apps/commerce.app.yaml"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct CLIResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
