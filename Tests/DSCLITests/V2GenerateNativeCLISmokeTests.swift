import DSCore
import Foundation
import Testing

@Suite("DSCLI v2 generate-native smoke")
struct V2GenerateNativeCLISmokeTests {
    @Test("dsctl v2 generate-native writes registry-backed android source")
    func generateNative() throws {
        let root = repositoryRoot()
        let outputDirectory = try makeTemporaryDirectory().appendingPathComponent("payment-android", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory.deletingLastPathComponent()) }

        let result = try runCLI([
            "v2",
            "generate-native",
            "--screen", root.appendingPathComponent("examples/v2/screens/checkout-payment.screen.yaml").path,
            "--platform", "android",
            "--out", outputDirectory.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(V2GenerateNativeReport.self, from: Data(result.stdout.utf8))
        let source = try String(contentsOf: outputDirectory.appendingPathComponent("PaymentScreen.kt"), encoding: .utf8)

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.platform == .android)
        #expect(source.contains("AxysPaymentForm("))
    }

    @Test("dsctl v2 help exposes generate-native")
    func v2Help() throws {
        let result = try runCLI(["v2", "--help"])

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("generate-native"))
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

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-v2-native-cli-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct CLIResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
