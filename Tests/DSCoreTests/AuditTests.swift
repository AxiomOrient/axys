import DSCore
import Foundation
import Testing

@Suite("Contract audit")
struct AuditTests {
    private let service = ProjectService()

    @Test("contract audit runs validation, adapter sync, HTML review, and sample app smoke")
    func auditApp() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let outputDirectory = fixture.root.appendingPathComponent("build/audit", isDirectory: true)
        let report = try service.auditApp(appPath: fixture.appURL, outputDirectory: outputDirectory)
        let iosReport = try #require(report.sampleApps.platforms.first(where: { $0.platform == .ios }))
        let paymentScreen = try #require(iosReport.screens.first(where: { $0.screenId == "payment" }))

        #expect(report.ok)
        #expect(report.appId == "commerce")
        #expect(FileManager.default.fileExists(atPath: report.validationReportPath))
        #expect(report.htmlScreens.count == 3)
        #expect(FileManager.default.fileExists(atPath: report.penpotSync.manifestPath))
        #expect(FileManager.default.fileExists(atPath: report.pencilSync.manifestPath))
        #expect(FileManager.default.fileExists(atPath: report.sampleAppsReportPath))
        #expect(FileManager.default.fileExists(atPath: paymentScreen.runtimeLogPath))
        #expect(try String(contentsOfFile: paymentScreen.runtimeLogPath).contains("runtime-smoke:ok:payment"))
    }

    private func makeFixture() throws -> (root: URL, appURL: URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-contract-audit-tests-\(UUID().uuidString)", isDirectory: true)
        let fileManager = FileManager.default
        let repositoryRoot = repositoryRoot()

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try "# Fixture root\n".write(to: root.appendingPathComponent("MASTER_BLUEPRINT.md"), atomically: true, encoding: .utf8)
        try fileManager.copyItem(at: repositoryRoot.appendingPathComponent("contracts", isDirectory: true), to: root.appendingPathComponent("contracts", isDirectory: true))

        return (root, root.appendingPathComponent("contracts/apps/commerce.app.yaml"))
    }

    @Test("project audit succeeds when repo shape exists")
    func auditProjectShapeSuccess() throws {
        let root = try makeRenewalRepoFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let report = try service.audit(projectRoot: root)
        #expect(report.ok)
        #expect(report.errors.isEmpty)
    }

    @Test("project audit reports missing required paths")
    func auditProjectShapeMissingPath() throws {
        let root = try makeRenewalRepoFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let missingPath = root.appendingPathComponent("contracts/screens", isDirectory: true)
        try FileManager.default.removeItem(at: missingPath)

        let report = try service.audit(projectRoot: root)
        #expect(!report.ok)
        #expect(report.errors.contains(where: { $0.contains("contracts/screens") }))
    }

    private func makeRenewalRepoFixture() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-audit-repo-\(UUID().uuidString)", isDirectory: true)
        let fileManager = FileManager.default

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let requiredDirectories = [
            "contracts/apps",
            "contracts/flows",
            "contracts/screens",
            "contracts/motion",
            "contracts/review",
            "contracts/registry",
            "contracts/tokens",
            "schemas/current",
            "PreviewApp",
            "HostApps",
            "meta/runtime",
        ]

        for relative in requiredDirectories {
            let url = root.appendingPathComponent(relative, isDirectory: true)
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }

        try "{\"schema\":1}".write(
            to: root.appendingPathComponent("schemas/current/example.schema.json"),
            atomically: true,
            encoding: .utf8
        )
        try "".write(
            to: root.appendingPathComponent("meta/runtime/contracts.cue"),
            atomically: true,
            encoding: .utf8
        )

        return root
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
