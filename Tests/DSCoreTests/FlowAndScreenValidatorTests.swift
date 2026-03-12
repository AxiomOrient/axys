import DSCore
import Foundation
import Testing

@Suite("Contract flow and screen validation")
struct FlowAndScreenValidatorTests {
    private let service = ProjectService()

    @Test("contract FlowSpec validates in discovered app context")
    func validateFlow() throws {
        let root = repositoryRoot()

        let report = try service.validateFlow(
            flowPath: root.appendingPathComponent("contracts/flows/commerce-checkout.flow.yaml")
        )

        #expect(report.ok)
        #expect(report.issues.isEmpty)
    }

    @Test("contract ScreenSpec validates in discovered flow and app context")
    func validateScreen() throws {
        let root = repositoryRoot()

        let report = try service.validateScreen(
            screenPath: root.appendingPathComponent("contracts/screens/checkout-payment.screen.yaml")
        )

        #expect(report.ok)
        #expect(report.issues.isEmpty)
    }

    @Test("contract ScreenSpec fails when no parent FlowSpec can be resolved")
    func validateScreenWithoutParentFlow() throws {
        let fixtureRoot = try makeV2Fixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        try FileManager.default.removeItem(at: fixtureRoot.appendingPathComponent("contracts/flows/banking-onboarding.flow.yaml"))
        try FileManager.default.removeItem(at: fixtureRoot.appendingPathComponent("contracts/flows/commerce-checkout.flow.yaml"))

        let report = try service.validateScreen(
            screenPath: fixtureRoot.appendingPathComponent("contracts/screens/checkout-payment.screen.yaml")
        )

        #expect(!report.ok)
        #expect(report.issues.contains {
            $0.code == "flow.parent.missing" &&
            $0.path == "screen[payment].flowId"
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
            .appendingPathComponent("axys-contract-flow-screen-tests-\(UUID().uuidString)", isDirectory: true)
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
