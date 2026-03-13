import DSCore
import Foundation
import Testing

@Suite("DSCLI render-html smoke")
struct RenderHTMLCLISmokeTests {
    @Test("dsctl render-html writes an HTML review bundle")
    func renderHTML() throws {
        let root = repositoryRoot()
        let outputDirectory = try makeTemporaryDirectory().appendingPathComponent("payment-review", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory.deletingLastPathComponent()) }

        let result = try runCLI([
            "render-html",
            "--screen", root.appendingPathComponent("contracts/screens/checkout-payment.screen.yaml").path,
            "--out", outputDirectory.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(RenderHTMLReport.self, from: Data(result.stdout.utf8))
        let html = try String(contentsOf: outputDirectory.appendingPathComponent("html/payment.html"), encoding: .utf8)
        let shell = try String(contentsOf: outputDirectory.appendingPathComponent("index.html"), encoding: .utf8)

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.entrypointPath == outputDirectory.appendingPathComponent("index.html").path)
        #expect(html.contains("data-preview-state=\"error\""))
        #expect(shell.contains("shell/review.css"))
        #expect(shell.contains("data-review-payload=\""))
        #expect(!shell.contains("<script id=\"review-data\""))
    }

    @Test("dsctl help exposes render-html")
    func v2Help() throws {
        let result = try runCLI(["--help"])

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
            .appendingPathComponent("axys-contract-render-cli-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct CLIResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
