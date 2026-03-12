import DSCore
import Foundation
import Testing

@Suite("DSCLI validate-app smoke")
struct CLISmokeTests {
    @Test("dsctl validate-app validates a checked-in app contract")
    func validateApp() throws {
        let root = repositoryRoot()
        let result = try runCLI([
            "validate-app",
            "--app", root.appendingPathComponent("contracts/apps/commerce.app.yaml").path,
            "--json",
        ])

        let report = try JSONDecoder().decode(ValidationReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
    }

    @Test("dsctl help exposes validate-app")
    func v2Help() throws {
        let result = try runCLI(["--help"])

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
