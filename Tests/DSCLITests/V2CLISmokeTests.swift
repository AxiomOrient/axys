import DSCore
import Foundation
import Testing

@Suite("DSCLI v2 smoke")
struct V2CLISmokeTests {
    @Test("dsctl v2 validate-app validates a checked-in v2 app")
    func validateApp() throws {
        let root = repositoryRoot()
        let result = try runCLI([
            "v2",
            "validate-app",
            "--app", root.appendingPathComponent("examples/v2/apps/commerce.app.yaml").path,
            "--json",
        ])

        let report = try JSONDecoder().decode(ValidationReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
    }

    @Test("dsctl v2 help exposes validate-app")
    func v2Help() throws {
        let result = try runCLI(["v2", "--help"])

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("validate-app"))
    }

    private func runCLI(_ arguments: [String]) throws -> CLIResult {
        let process = Process()
        process.executableURL = repositoryRoot().appendingPathComponent(".build/debug/dsctl")
        process.arguments = arguments
        process.currentDirectoryURL = repositoryRoot()

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

        return CLIResult(
            exitCode: Int(process.terminationStatus),
            stdout: String(data: outputData, encoding: .utf8) ?? "",
            stderr: String(data: errorData, encoding: .utf8) ?? ""
        )
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
