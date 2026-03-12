import DSCore
import Foundation
import Testing

@Suite("DSCLI flow and screen smoke")
struct FlowAndScreenCLISmokeTests {
    @Test("dsctl validate-flow validates a checked-in flow contract")
    func validateFlow() throws {
        let root = repositoryRoot()
        let result = try runCLI([
            "validate-flow",
            "--flow", root.appendingPathComponent("contracts/flows/commerce-checkout.flow.yaml").path,
            "--json",
        ])

        let report = try JSONDecoder().decode(ValidationReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
    }

    @Test("dsctl validate-screen validates a checked-in screen contract")
    func validateScreen() throws {
        let root = repositoryRoot()
        let result = try runCLI([
            "validate-screen",
            "--screen", root.appendingPathComponent("contracts/screens/checkout-payment.screen.yaml").path,
            "--json",
        ])

        let report = try JSONDecoder().decode(ValidationReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
    }

    @Test("dsctl help exposes validate-flow and validate-screen")
    func v2Help() throws {
        let result = try runCLI(["--help"])

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("validate-flow"))
        #expect(result.stdout.contains("validate-screen"))
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
