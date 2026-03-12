import DSCore
import Foundation
import Testing

@Suite("V2ProjectValidator")
struct V2ProjectValidatorTests {
    private let service = ProjectService()

    @Test("v2 AppSpec validates transitive flow, screen, motion, review, and registry contracts")
    func validateV2App() throws {
        let root = repositoryRoot()

        let report = try service.validateV2App(
            appPath: root.appendingPathComponent("examples/v2/apps/commerce.app.yaml")
        )

        #expect(report.ok)
        #expect(report.issues.isEmpty)
    }

    @Test("checked-in banking v2 AppSpec validates")
    func validateBankingV2App() throws {
        let root = repositoryRoot()

        let report = try service.validateV2App(
            appPath: root.appendingPathComponent("examples/v2/apps/banking.app.yaml")
        )

        #expect(report.ok)
        #expect(report.issues.isEmpty)
    }

    @Test("v2 validation reports unknown registry items from screen layout nodes")
    func validateV2AppUnknownComponent() throws {
        let fixtureRoot = try makeV2Fixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let screenPath = fixtureRoot.appendingPathComponent("examples/v2/screens/checkout-cart.screen.yaml")
        var screenSource = try String(contentsOf: screenPath, encoding: .utf8)
        screenSource = screenSource.replacingOccurrences(of: "componentId: checkout-summary", with: "componentId: missing-summary")
        try screenSource.write(to: screenPath, atomically: true, encoding: .utf8)

        let report = try service.validateV2App(
            appPath: fixtureRoot.appendingPathComponent("examples/v2/apps/commerce.app.yaml")
        )

        #expect(!report.ok)
        #expect(report.issues.contains {
            $0.code == "layout.componentReference" &&
            $0.path.contains("screen[cart].layout.children[1].componentId")
        })
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-v2-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeV2Fixture() throws -> URL {
        let root = repositoryRoot()
        let fixtureRoot = try makeTemporaryDirectory()
        let fileManager = FileManager.default

        try fileManager.createDirectory(at: fixtureRoot.appendingPathComponent("examples", isDirectory: true), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: fixtureRoot.appendingPathComponent("registries", isDirectory: true), withIntermediateDirectories: true)

        try fileManager.copyItem(
            at: root.appendingPathComponent("MASTER_BLUEPRINT.md"),
            to: fixtureRoot.appendingPathComponent("MASTER_BLUEPRINT.md")
        )
        try fileManager.copyItem(
            at: root.appendingPathComponent("examples/v2", isDirectory: true),
            to: fixtureRoot.appendingPathComponent("examples/v2", isDirectory: true)
        )
        try fileManager.copyItem(
            at: root.appendingPathComponent("examples/tokens", isDirectory: true),
            to: fixtureRoot.appendingPathComponent("examples/tokens", isDirectory: true)
        )
        try fileManager.copyItem(
            at: root.appendingPathComponent("registries/shadcn", isDirectory: true),
            to: fixtureRoot.appendingPathComponent("registries/shadcn", isDirectory: true)
        )

        return fixtureRoot
    }
}
