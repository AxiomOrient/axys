import DSCore
import Foundation
import Testing

@Suite("ContractValidator")
struct ContractValidatorTests {
    private let service = ProjectService()

    @Test("contract AppSpec validates transitive flow, screen, motion, review, and registry contracts")
    func validateApp() throws {
        let root = repositoryRoot()

        let report = try service.validateApp(
            appPath: root.appendingPathComponent("contracts/apps/commerce.app.yaml")
        )

        #expect(report.ok)
        #expect(report.issues.isEmpty)
    }

    @Test("checked-in banking app contract validates")
    func validateBankingV2App() throws {
        let root = repositoryRoot()

        let report = try service.validateApp(
            appPath: root.appendingPathComponent("contracts/apps/banking.app.yaml")
        )

        #expect(report.ok)
        #expect(report.issues.isEmpty)
    }

    @Test("contract validation reports unknown registry items from screen layout nodes")
    func validateAppUnknownComponent() throws {
        let fixtureRoot = try makeV2Fixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let screenPath = fixtureRoot.appendingPathComponent("contracts/screens/checkout-cart.screen.yaml")
        var screenSource = try String(contentsOf: screenPath, encoding: .utf8)
        screenSource = screenSource.replacingOccurrences(of: "componentId: checkout-summary", with: "componentId: missing-summary")
        try screenSource.write(to: screenPath, atomically: true, encoding: .utf8)

        let report = try service.validateApp(
            appPath: fixtureRoot.appendingPathComponent("contracts/apps/commerce.app.yaml")
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
            .appendingPathComponent("axys-contract-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeV2Fixture() throws -> URL {
        let root = repositoryRoot()
        let fixtureRoot = try makeTemporaryDirectory()
        let fileManager = FileManager.default

        try fileManager.copyItem(
            at: root.appendingPathComponent("MASTER_BLUEPRINT.md"),
            to: fixtureRoot.appendingPathComponent("MASTER_BLUEPRINT.md")
        )
        try fileManager.copyItem(
            at: root.appendingPathComponent("contracts", isDirectory: true),
            to: fixtureRoot.appendingPathComponent("contracts", isDirectory: true)
        )

        return fixtureRoot
    }
}
