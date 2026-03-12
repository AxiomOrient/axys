import DSCore
import DSMCPKit
import Foundation
import MCP
import Testing

@Suite("DSMCP server")
struct DSMCPServerTests {
    @Test("tools/list exposes the canonical thin adapter surface")
    func listTools() async throws {
        let session = try await makeSession()
        let listing = try await session.client.listTools()
        let names = listing.tools.map(\.name).sorted()
        let runtimeContracts = try RuntimeContractLoader().load(from: repositoryRoot().appendingPathComponent("meta/runtime/contracts.cue"))

        #expect(names == DSMCPServerFactory.toolNames.sorted())
        #expect(names == runtimeContracts.mcpTools.sorted())

        await shutdown(session)
    }

    @Test("tools/call executes the renewal command surface")
    func callTools() async throws {
        let session = try await makeSession()
        let root = repositoryRoot()
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let appPath = root.appendingPathComponent("contracts/apps/commerce.app.yaml")
        let flowPath = root.appendingPathComponent("contracts/flows/commerce-checkout.flow.yaml")
        let screenPath = root.appendingPathComponent("contracts/screens/checkout-payment.screen.yaml")

        let validationCalls: [(String, [String: Value])] = [
            ("validate_app", ["app": .string(appPath.path)]),
            ("validate_flow", ["flow": .string(flowPath.path)]),
            ("validate_screen", ["screen": .string(screenPath.path)]),
        ]

        for (name, arguments) in validationCalls {
            let result = try await session.client.callTool(name: name, arguments: arguments)
            let text = try requiredText(from: result.content)
            let report = try JSONDecoder().decode(ValidationReport.self, from: Data(text.utf8))
            #expect(result.isError != true)
            #expect(report.ok)
        }

        let renderOutput = tempDir.appendingPathComponent("render-html", isDirectory: true)
        try FileManager.default.createDirectory(at: renderOutput, withIntermediateDirectories: true)
        let renderResult = try await session.client.callTool(
            name: "render_html",
            arguments: [
                "screen": .string(screenPath.path),
                "out": .string(renderOutput.path),
            ]
        )
        let renderText = try requiredText(from: renderResult.content)
        let renderReport = try JSONDecoder().decode(RenderHTMLReport.self, from: Data(renderText.utf8))
        #expect(renderResult.isError != true)
        #expect(renderReport.ok)

        let nativeOutput = tempDir.appendingPathComponent("native", isDirectory: true)
        try FileManager.default.createDirectory(at: nativeOutput, withIntermediateDirectories: true)
        let nativeResult = try await session.client.callTool(
            name: "generate_native",
            arguments: [
                "screen": .string(screenPath.path),
                "platform": .string("ios"),
                "out": .string(nativeOutput.path),
            ]
        )
        let nativeText = try requiredText(from: nativeResult.content)
        let nativeReport = try JSONDecoder().decode(GenerateNativeReport.self, from: Data(nativeText.utf8))
        #expect(nativeResult.isError != true)
        #expect(nativeReport.ok)

        let penpotDir = tempDir.appendingPathComponent("penpot", isDirectory: true)
        try FileManager.default.createDirectory(at: penpotDir, withIntermediateDirectories: true)
        let penpotResult = try await session.client.callTool(
            name: "sync_penpot",
            arguments: [
                "app": .string(appPath.path),
                "out": .string(penpotDir.path),
            ]
        )
        let penpotText = try requiredText(from: penpotResult.content)
        let penpotReport = try JSONDecoder().decode(AdapterSyncReport.self, from: Data(penpotText.utf8))
        #expect(penpotResult.isError != true)
        #expect(penpotReport.ok)

        let pencilDir = tempDir.appendingPathComponent("pencil", isDirectory: true)
        try FileManager.default.createDirectory(at: pencilDir, withIntermediateDirectories: true)
        let pencilResult = try await session.client.callTool(
            name: "sync_pencil",
            arguments: [
                "app": .string(appPath.path),
                "out": .string(pencilDir.path),
            ]
        )
        let pencilText = try requiredText(from: pencilResult.content)
        let pencilReport = try JSONDecoder().decode(AdapterSyncReport.self, from: Data(pencilText.utf8))
        #expect(pencilResult.isError != true)
        #expect(pencilReport.ok)

        let auditResult = try await session.client.callTool(
            name: "audit",
            arguments: [
                "projectRoot": .string(root.path),
            ]
        )
        let auditText = try requiredText(from: auditResult.content)
        let auditReport = try JSONDecoder().decode(RepoAuditReport.self, from: Data(auditText.utf8))
        #expect(auditResult.isError != true)
        #expect(auditReport.ok)

        await shutdown(session)
    }

    @Test("tools/call reports unknown tool names cleanly")
    func callToolsRejectUnknownToolNames() async throws {
        let session = try await makeSession()

        let result = try await session.client.callTool(name: "unknown_tool", arguments: [:])
        let text = try requiredText(from: result.content)
        let report = try JSONDecoder().decode(OperationErrorReport.self, from: Data(text.utf8))

        #expect(result.isError == true)
        #expect(!report.ok)
        #expect(report.error.contains("Unknown tool: unknown_tool"))

        await shutdown(session)
    }

    private func makeSession() async throws -> (client: Client, server: Server) {
        let transports = await InMemoryTransport.createConnectedPair()
        let server = await DSMCPServerFactory.makeServer()
        try await server.start(transport: transports.server)

        let client = Client(name: "DSMCPKitTests", version: "0.1.0")
        _ = try await client.connect(transport: transports.client)

        return (client, server)
    }

    private func shutdown(_ session: (client: Client, server: Server)) async {
        await session.client.disconnect()
        await session.server.stop()
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-mcp-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func requiredText(from content: [Tool.Content]) throws -> String {
        guard case .text(let text)? = content.first else {
            throw ProjectError.invalidArgument("Expected text tool content")
        }
        return text
    }
}
