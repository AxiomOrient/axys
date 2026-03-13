import DSCore
import Foundation
import Testing

@Suite("DSCLI build-sample-apps smoke")
struct BuildSampleAppsCLISmokeTests {
    @Test("dsctl build-sample-apps builds compile-backed sample harnesses")
    func buildSampleApps() throws {
        let fixtureRoot = try makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let contractPath = fixtureRoot.appendingPathComponent("contracts/apps/commerce.app.yaml")
        let result = try runCLI([
            "build-sample-apps",
            "--app", contractPath.path,
            "--json",
        ], root: fixtureRoot)

        let report = try JSONDecoder().decode(SampleAppsBuildReport.self, from: Data(result.stdout.utf8))
        let androidReport = try #require(report.platforms.first(where: { $0.platform == .android }))
        let paymentReport = try #require(androidReport.screens.first(where: { $0.screenId == "payment" }))

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(FileManager.default.fileExists(atPath: androidReport.proofManifestPath))
        #expect(FileManager.default.fileExists(atPath: paymentReport.runtimeLogPath))
        #expect(try String(contentsOfFile: paymentReport.runtimeLogPath).contains("runtime-smoke:ok:payment"))
    }

    @Test("dsctl help exposes build-sample-apps")
    func v2Help() throws {
        let result = try runCLI(["--help"], root: repositoryRoot())

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("build-sample-apps"))
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

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeFixtureRoot() throws -> URL {
        let root = try makeTemporaryDirectory()
        try "# Fixture root\n".write(to: root.appendingPathComponent("MASTER_BLUEPRINT.md"), atomically: true, encoding: .utf8)
        try FileManager.default.copyItem(
            at: repositoryRoot().appendingPathComponent("contracts", isDirectory: true),
            to: root.appendingPathComponent("contracts", isDirectory: true)
        )
        return root
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-build-sample-cli-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct CLIResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
