import DSCore
import Foundation
import Testing

@Suite("Contract adapter sync")
struct AdapterSyncTests {
    private let service = ProjectService()

    @Test("contract penpot sync exports deterministic flow payloads")
    func syncPenpot() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let outputDirectory = fixture.root.appendingPathComponent("build/penpot", isDirectory: true)
        let report = try service.syncPenpot(appPath: fixture.appURL, outputDirectory: outputDirectory)
        let manifest = try JSONDecoder().decode(AdapterManifest.self, from: Data(contentsOf: outputDirectory.appendingPathComponent("manifest.json")))

        #expect(report.ok)
        #expect(report.adapter == .penpot)
        #expect(FileManager.default.fileExists(atPath: report.tokenPayloadPath))
        #expect(FileManager.default.fileExists(atPath: report.manifestPath))
        #expect(manifest.adapter == "penpot")
        #expect(manifest.appId == "commerce")
        #expect(manifest.flowPayloads.count == 2)
        #expect(FileManager.default.fileExists(atPath: report.flows[0].payloadPath))
    }

    @Test("contract pencil sync exports deterministic flow payloads")
    func syncPencil() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let outputDirectory = fixture.root.appendingPathComponent("build/pencil", isDirectory: true)
        let report = try service.syncPencil(appPath: fixture.appURL, outputDirectory: outputDirectory)
        let flowPayload = try String(contentsOfFile: report.flows[0].payloadPath)

        #expect(report.ok)
        #expect(report.adapter == .pencil)
        #expect(flowPayload.contains("\"containerName\" : \"Checkout Flow Canvas\""))
        #expect(flowPayload.contains("\"screenId\" : \"payment\""))
    }

    private func makeFixture() throws -> (root: URL, appURL: URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-contract-adapter-sync-tests-\(UUID().uuidString)", isDirectory: true)
        let fileManager = FileManager.default
        let repositoryRoot = repositoryRoot()

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try "# Fixture root\n".write(to: root.appendingPathComponent("MASTER_BLUEPRINT.md"), atomically: true, encoding: .utf8)
        try fileManager.copyItem(at: repositoryRoot.appendingPathComponent("contracts", isDirectory: true), to: root.appendingPathComponent("contracts", isDirectory: true))

        return (root, root.appendingPathComponent("contracts/apps/commerce.app.yaml"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct AdapterManifest: Decodable {
    let adapter: String
    let appId: String
    let flowPayloads: [FlowPayload]
}

private struct FlowPayload: Decodable {
    let flowId: String
}
