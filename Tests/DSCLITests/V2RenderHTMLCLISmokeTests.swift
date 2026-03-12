import DSCore
import Foundation
import Testing

@Suite("DSCLI v2 render-html smoke")
struct V2RenderHTMLCLISmokeTests {
    @Test("dsctl v2 render-html writes an HTML review bundle")
    func renderHTML() throws {
        let root = repositoryRoot()
        let outputDirectory = try makeTemporaryDirectory().appendingPathComponent("payment-review", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory.deletingLastPathComponent()) }

        let result = try runCLI([
            "v2",
            "render-html",
            "--screen", root.appendingPathComponent("examples/v2/screens/checkout-payment.screen.yaml").path,
            "--out", outputDirectory.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(V2RenderHTMLReport.self, from: Data(result.stdout.utf8))
        let html = try String(contentsOf: outputDirectory.appendingPathComponent("html/payment.html"), encoding: .utf8)

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(html.contains("data-preview-state=\"error\""))
    }

    @Test("dsctl v2 help exposes render-html")
    func v2Help() throws {
        let result = try runCLI(["v2", "--help"])

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("render-html"))
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
            .appendingPathComponent("axys-v2-render-cli-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct CLIResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
