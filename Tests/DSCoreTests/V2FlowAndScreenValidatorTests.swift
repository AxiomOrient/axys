import DSCore
import Foundation
import Testing

@Suite("V2 flow and screen validation")
struct V2FlowAndScreenValidatorTests {
    private let service = ProjectService()

    @Test("v2 FlowSpec validates in discovered app context")
    func validateV2Flow() throws {
        let root = repositoryRoot()

        let report = try service.validateV2Flow(
            flowPath: root.appendingPathComponent("examples/v2/flows/commerce-checkout.flow.yaml")
        )

        #expect(report.ok)
        #expect(report.issues.isEmpty)
    }

    @Test("v2 ScreenSpec validates in discovered flow and app context")
    func validateV2Screen() throws {
        let root = repositoryRoot()

        let report = try service.validateV2Screen(
            screenPath: root.appendingPathComponent("examples/v2/screens/checkout-payment.screen.yaml")
        )

        #expect(report.ok)
        #expect(report.issues.isEmpty)
    }

    @Test("v2 ScreenSpec fails when no parent FlowSpec can be resolved")
    func validateV2ScreenWithoutParentFlow() throws {
        let fixtureRoot = try makeV2Fixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        try FileManager.default.removeItem(at: fixtureRoot.appendingPathComponent("examples/v2/flows/banking-onboarding.flow.yaml"))
        try FileManager.default.removeItem(at: fixtureRoot.appendingPathComponent("examples/v2/flows/commerce-checkout.flow.yaml"))

        let report = try service.validateV2Screen(
            screenPath: fixtureRoot.appendingPathComponent("examples/v2/screens/checkout-payment.screen.yaml")
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
            .appendingPathComponent("axys-v2-flow-screen-tests-\(UUID().uuidString)", isDirectory: true)
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
