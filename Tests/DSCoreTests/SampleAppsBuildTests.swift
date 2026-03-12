import DSCore
import Foundation
import Testing

@Suite("Contract sample app builds")
struct SampleAppsBuildTests {
    private let service = ProjectService()

    @Test("contract app builds compile-backed sample app harnesses for ios and android")
    func buildSampleApps() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let report = try service.buildSampleApps(appPath: fixture.appURL)
        let iosReport = try #require(report.platforms.first(where: { $0.platform == .ios }))
        let androidReport = try #require(report.platforms.first(where: { $0.platform == .android }))
        let iosCart = try #require(iosReport.screens.first(where: { $0.screenId == "cart" }))
        let androidPayment = try #require(androidReport.screens.first(where: { $0.screenId == "payment" }))

        #expect(report.ok)
        #expect(report.platforms.count == 2)
        #expect(iosReport.sampleAppPath.hasPrefix(fixture.root.path))
        #expect(androidReport.sampleAppPath.hasPrefix(fixture.root.path))
        #expect(FileManager.default.fileExists(atPath: URL(fileURLWithPath: iosCart.outputDirectory).appendingPathComponent("CartScreen.swift").path))
        #expect(FileManager.default.fileExists(atPath: iosCart.buildLogPath))
        #expect(FileManager.default.fileExists(atPath: iosCart.runtimeLogPath))
        #expect(try String(contentsOfFile: iosCart.runtimeLogPath).contains("runtime-smoke:ok:cart"))
        #expect(FileManager.default.fileExists(atPath: URL(fileURLWithPath: androidPayment.outputDirectory).appendingPathComponent("PaymentScreen.kt").path))
        #expect(FileManager.default.fileExists(atPath: androidPayment.buildLogPath))
        #expect(FileManager.default.fileExists(atPath: androidPayment.runtimeLogPath))
        #expect(try String(contentsOfFile: androidPayment.runtimeLogPath).contains("runtime-smoke:ok:payment"))
    }

    private func makeFixture() throws -> (root: URL, appURL: URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-contract-sample-app-tests-\(UUID().uuidString)", isDirectory: true)
        let fileManager = FileManager.default
        let repositoryRoot = repositoryRoot()

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try "# Fixture root\n".write(to: root.appendingPathComponent("MASTER_BLUEPRINT.md"), atomically: true, encoding: .utf8)
        try fileManager.copyItem(at: repositoryRoot.appendingPathComponent("contracts", isDirectory: true), to: root.appendingPathComponent("contracts", isDirectory: true))

        let appURL = root.appendingPathComponent("contracts/apps/commerce.app.yaml")
        let content = """
        schemaVersion: "2.1"
        appId: commerce
        title: Commerce Mobile
        description: Deterministic contract set for the commerce checkout app.
        brands:
          - default
        targetPlatforms:
          - html
          - ios
          - android
        tokenSet: contracts/tokens/theme.light.tokens.json
        componentRegistry: contracts/registry/shadcn/registry.json
        motionSet: contracts/motion/mobile-core.motion.yaml
        reviewSet: contracts/review/mobile-core.review.yaml
        sampleApps:
          ios: HostApps/ios/CommerceSample
          android: HostApps/android/commerce-sample
        reviewBenchmarks:
          - source: mobbin
            url: https://mobbin.com
            tags:
              - checkout
        flows:
          - id: checkout
            path: contracts/flows/commerce-checkout.flow.yaml
        """
        try content.write(to: appURL, atomically: true, encoding: .utf8)

        return (root, appURL)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
