import DSCore
import Foundation
import Testing

@Suite("V2 native renderer")
struct V2NativeRendererTests {
    private let service = ProjectService()

    @Test("v2 screen generates registry-backed SwiftUI source")
    func generateIOS() throws {
        let root = repositoryRoot()
        let outputDirectory = try makeTemporaryDirectory().appendingPathComponent("payment-ios", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory.deletingLastPathComponent()) }

        let report = try service.generateV2Native(
            screenPath: root.appendingPathComponent("examples/v2/screens/checkout-payment.screen.yaml"),
            platform: .ios,
            outputDirectory: outputDirectory
        )

        let screenPath = outputDirectory.appendingPathComponent("PaymentScreen.swift")
        let manifestPath = outputDirectory.appendingPathComponent("manifest.native.json")
        let source = try String(contentsOf: screenPath, encoding: .utf8)
        let manifest = try JSONDecoder().decode(NativeManifest.self, from: Data(contentsOf: manifestPath))

        #expect(report.ok)
        #expect(report.platform == .ios)
        #expect(source.contains("struct PaymentScreen: View"))
        #expect(source.contains("AXYSPaymentForm("))
        #expect(source.contains("#Preview(\"loading\")"))
        #expect(manifest.platform == .ios)
        #expect(manifest.screenId == "payment")
    }

    @Test("v2 screen generates registry-backed Compose source")
    func generateAndroid() throws {
        let root = repositoryRoot()
        let outputDirectory = try makeTemporaryDirectory().appendingPathComponent("payment-android", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory.deletingLastPathComponent()) }

        let report = try service.generateV2Native(
            screenPath: root.appendingPathComponent("examples/v2/screens/checkout-payment.screen.yaml"),
            platform: .android,
            outputDirectory: outputDirectory
        )

        let screenPath = outputDirectory.appendingPathComponent("PaymentScreen.kt")
        let source = try String(contentsOf: screenPath, encoding: .utf8)

        #expect(report.ok)
        #expect(report.platform == .android)
        #expect(source.contains("fun PaymentScreen("))
        #expect(source.contains("AxysPaymentForm("))
        #expect(source.contains("@Preview(name = \"loading\")"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-v2-native-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct NativeManifest: Decodable {
    let platform: Platform
    let screenId: String
}
