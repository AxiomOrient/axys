import DSCore
import Foundation
import Testing

@Suite("DSCLI v2 build-sample-apps smoke")
struct V2BuildSampleAppsCLISmokeTests {
    @Test("dsctl v2 build-sample-apps builds compile-backed sample harnesses")
    func buildSampleApps() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let result = try runCLI([
            "v2",
            "build-sample-apps",
            "--app", fixture.appURL.path,
            "--json",
        ], root: fixture.root)

        let report = try JSONDecoder().decode(V2BuildSampleAppsReport.self, from: Data(result.stdout.utf8))
        let androidScreen = fixture.root.appendingPathComponent("samples/android/commerce-sample/GeneratedUI/android/payment/PaymentScreen.kt")
        let androidReport = try #require(report.platforms.first(where: { $0.platform == .android }))
        let paymentReport = try #require(androidReport.screens.first(where: { $0.screenId == "payment" }))

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(FileManager.default.fileExists(atPath: androidScreen.path))
        #expect(FileManager.default.fileExists(atPath: paymentReport.runtimeLogPath))
        #expect(try String(contentsOfFile: paymentReport.runtimeLogPath).contains("runtime-smoke:ok:payment"))
    }

    @Test("dsctl v2 help exposes build-sample-apps")
    func v2Help() throws {
        let result = try runCLI(["v2", "--help"], root: repositoryRoot())

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

    private func makeFixture() throws -> (root: URL, appURL: URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-v2-sample-app-cli-tests-\(UUID().uuidString)", isDirectory: true)
        let fileManager = FileManager.default

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try "# Fixture root\n".write(to: root.appendingPathComponent("MASTER_BLUEPRINT.md"), atomically: true, encoding: .utf8)
        try fileManager.copyItem(at: repositoryRoot().appendingPathComponent("examples", isDirectory: true), to: root.appendingPathComponent("examples", isDirectory: true))
        try fileManager.copyItem(at: repositoryRoot().appendingPathComponent("registries", isDirectory: true), to: root.appendingPathComponent("registries", isDirectory: true))

        let appURL = root.appendingPathComponent("examples/v2/apps/commerce.app.yaml")
        try """
        schemaVersion: "2.1"
        appId: commerce
        title: Commerce Mobile
        targetPlatforms:
          - html
          - ios
          - android
        tokenSet: examples/tokens/theme.light.tokens.json
        componentRegistry: registries/shadcn/registry.json
        motionSet: examples/v2/motion/mobile-core.motion.yaml
        reviewSet: examples/v2/review/mobile-core.review.yaml
        sampleApps:
          ios: samples/ios/CommerceSample
          android: samples/android/commerce-sample
        flows:
          - id: checkout
            path: examples/v2/flows/commerce-checkout.flow.yaml
        """.write(to: appURL, atomically: true, encoding: .utf8)

        return (root, appURL)
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
