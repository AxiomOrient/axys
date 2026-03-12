import DSCore
import Foundation
import Testing

@Suite("V2 audit")
struct V2AuditTests {
    private let service = ProjectService()

    @Test("v2 audit runs validation, adapter sync, HTML review, and sample app smoke")
    func auditV2() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let outputDirectory = fixture.root.appendingPathComponent("build/audit", isDirectory: true)
        let report = try service.auditV2(appPath: fixture.appURL, outputDirectory: outputDirectory)
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
            .appendingPathComponent("axys-v2-audit-tests-\(UUID().uuidString)", isDirectory: true)
        let fileManager = FileManager.default
        let repositoryRoot = repositoryRoot()

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try "# Fixture root\n".write(to: root.appendingPathComponent("MASTER_BLUEPRINT.md"), atomically: true, encoding: .utf8)
        try fileManager.copyItem(at: repositoryRoot.appendingPathComponent("examples", isDirectory: true), to: root.appendingPathComponent("examples", isDirectory: true))
        try fileManager.copyItem(at: repositoryRoot.appendingPathComponent("registries", isDirectory: true), to: root.appendingPathComponent("registries", isDirectory: true))

        return (root, root.appendingPathComponent("examples/v2/apps/commerce.app.yaml"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
