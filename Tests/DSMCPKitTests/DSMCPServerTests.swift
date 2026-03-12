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
        let runtimeContracts = try RuntimeContractLoader().load(
            from: repositoryRoot().appendingPathComponent("meta/runtime/contracts.cue")
        )

        #expect(names == DSMCPServerFactory.toolNames.sorted())
        #expect(names == runtimeContracts.mcpTools.sorted())

        await shutdown(session)
    }

    @Test("tools/call validates specs and audits the repository")
    func callTools() async throws {
        let session = try await makeSession()
        let root = repositoryRoot()
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let compileResult = try await session.client.callTool(
            name: "compile_screen_doc",
            arguments: [
                "screenDoc": .string(root.appendingPathComponent("examples/screen-doc/login.md").path),
                "out": .string(temporaryDirectory.appendingPathComponent("login.screen.json").path),
            ]
        )
        let compileText = try requiredText(from: compileResult.content)
        let compileReport = try JSONDecoder().decode(CompileScreenDocReport.self, from: Data(compileText.utf8))

        #expect(compileResult.isError != true)
        #expect(compileReport.ok)
        #expect(FileManager.default.fileExists(atPath: compileReport.outputPath))
        #expect(FileManager.default.fileExists(atPath: compileReport.reportPath))
        #expect(compileReport.completionStatus == .complete)

        let fixture = try makeConfigFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let compileFromConfigResult = try await session.client.callTool(
            name: "compile_screen_doc",
            arguments: [
                "config": .string(fixture.configPath.path),
                "screenId": .string("login"),
            ]
        )
        let compileFromConfigText = try requiredText(from: compileFromConfigResult.content)
        let compileFromConfigReport = try JSONDecoder().decode(CompileScreenDocReport.self, from: Data(compileFromConfigText.utf8))

        #expect(compileFromConfigResult.isError != true)
        #expect(compileFromConfigReport.ok)
        #expect(compileFromConfigReport.outputPath == fixture.buildDirectory.appendingPathComponent("compiled/login.screen.json").path)
        #expect(FileManager.default.fileExists(atPath: compileFromConfigReport.outputPath))
        #expect(FileManager.default.fileExists(atPath: compileFromConfigReport.reportPath))
        #expect(compileFromConfigReport.completionStatus == .complete)

        let validateResult = try await session.client.callTool(
            name: "validate_spec",
            arguments: [
                "spec": .string(root.appendingPathComponent("examples/screens/login.screen.json").path),
                "tokens": .string(root.appendingPathComponent("examples/tokens", isDirectory: true).path),
                "catalog": .string(root.appendingPathComponent("examples/catalogs/component-catalog.json").path),
            ]
        )
        let validateText = try requiredText(from: validateResult.content)
        let validateReport = try JSONDecoder().decode(ValidationReport.self, from: Data(validateText.utf8))

        #expect(validateResult.isError != true)
        #expect(validateReport.ok)

        let screenDocValidateResult = try await session.client.callTool(
            name: "validate_spec",
            arguments: [
                "screenDoc": .string(fixture.root.appendingPathComponent("examples/screen-doc/login.md").path),
                "tokens": .string(fixture.root.appendingPathComponent("examples/tokens", isDirectory: true).path),
                "catalog": .string(fixture.root.appendingPathComponent("examples/catalogs/component-catalog.json").path),
            ]
        )
        let screenDocValidateText = try requiredText(from: screenDocValidateResult.content)
        let screenDocValidateReport = try JSONDecoder().decode(ValidationReport.self, from: Data(screenDocValidateText.utf8))

        #expect(screenDocValidateResult.isError != true)
        #expect(screenDocValidateReport.ok)

        let invalidValidateResult = try await session.client.callTool(
            name: "validate_spec",
            arguments: [
                "spec": .string(root.appendingPathComponent("examples/screens/login.screen.json").path),
                "screenDoc": .string(root.appendingPathComponent("examples/screen-doc/login.md").path),
                "tokens": .string(root.appendingPathComponent("examples/tokens", isDirectory: true).path),
                "catalog": .string(root.appendingPathComponent("examples/catalogs/component-catalog.json").path),
            ]
        )
        let invalidValidateText = try requiredText(from: invalidValidateResult.content)
        let invalidValidateReport = try JSONDecoder().decode(OperationErrorReport.self, from: Data(invalidValidateText.utf8))

        #expect(invalidValidateResult.isError == true)
        #expect(!invalidValidateReport.ok)
        #expect(invalidValidateReport.error.contains("Use exactly one of spec or screenDoc"))

        let generateResult = try await session.client.callTool(
            name: "generate_screen",
            arguments: [
                "screenDoc": .string(fixture.root.appendingPathComponent("examples/screen-doc/login.md").path),
                "tokens": .string(fixture.root.appendingPathComponent("examples/tokens", isDirectory: true).path),
                "catalog": .string(fixture.root.appendingPathComponent("examples/catalogs/component-catalog.json").path),
                "out": .string(temporaryDirectory.appendingPathComponent("screen").path),
            ]
        )
        let generateText = try requiredText(from: generateResult.content)
        let generateReport = try JSONDecoder().decode(GenerateReport.self, from: Data(generateText.utf8))

        #expect(generateResult.isError != true)
        #expect(generateReport.ok)
        #expect(FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent("screen/compiled.screen.json").path))

        let previewPort = try freePort()
        let previewResult = try await session.client.callTool(
            name: "preview_serve",
            arguments: [
                "dir": .string(temporaryDirectory.appendingPathComponent("screen/html", isDirectory: true).path),
                "port": .string(String(previewPort)),
            ]
        )
        let previewText = try requiredText(from: previewResult.content)
        let previewReport = try JSONDecoder().decode(PreviewServeReport.self, from: Data(previewText.utf8))
        defer { try? terminateProcess(pid: previewReport.pid) }

        #expect(previewResult.isError != true)
        #expect(previewReport.ok)
        #expect(previewReport.url == "http://127.0.0.1:\(previewPort)/")
        let indexHTML = try waitForHTTPText(at: URL(string: previewReport.url)!)
        #expect(indexHTML.contains("login.html"))

        let bundleResult = try await session.client.callTool(
            name: "generate_bundle",
            arguments: [
                "screenDocDir": .string(fixture.root.appendingPathComponent("examples/screen-doc", isDirectory: true).path),
                "tokens": .string(fixture.root.appendingPathComponent("examples/tokens", isDirectory: true).path),
                "catalog": .string(fixture.root.appendingPathComponent("examples/catalogs/component-catalog.json").path),
                "out": .string(temporaryDirectory.appendingPathComponent("bundle").path),
            ]
        )
        let bundleText = try requiredText(from: bundleResult.content)
        let bundleReport = try JSONDecoder().decode(GenerateBundleReport.self, from: Data(bundleText.utf8))

        #expect(bundleResult.isError != true)
        #expect(bundleReport.ok)
        #expect(bundleReport.reports.map(\.screenId) == ["login", "product-detail"])
        #expect(FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent("bundle/login/compiled.screen.json").path))

        let auditResult = try await session.client.callTool(
            name: "audit_project",
            arguments: [
                "projectRoot": .string(root.path),
            ]
        )
        let auditText = try requiredText(from: auditResult.content)
        let auditReport = try JSONDecoder().decode(AuditReport.self, from: Data(auditText.utf8))

        #expect(auditResult.isError != true)
        #expect(auditReport.ok)

        await shutdown(session)
    }

    @Test("tools/call returns structured JSON errors for invalid input combinations")
    func callToolsRejectInvalidInputCombinations() async throws {
        let session = try await makeSession()
        let root = repositoryRoot()
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let missingValidateResult = try await session.client.callTool(
            name: "validate_spec",
            arguments: [
                "tokens": .string(root.appendingPathComponent("examples/tokens", isDirectory: true).path),
                "catalog": .string(root.appendingPathComponent("examples/catalogs/component-catalog.json").path),
            ]
        )
        let missingValidateText = try requiredText(from: missingValidateResult.content)
        let missingValidateReport = try JSONDecoder().decode(OperationErrorReport.self, from: Data(missingValidateText.utf8))

        #expect(missingValidateResult.isError == true)
        #expect(!missingValidateReport.ok)
        #expect(missingValidateReport.error.contains("Use exactly one of spec or screenDoc"))

        let conflictingGenerateResult = try await session.client.callTool(
            name: "generate_screen",
            arguments: [
                "spec": .string(root.appendingPathComponent("examples/screens/login.screen.json").path),
                "screenDoc": .string(root.appendingPathComponent("examples/screen-doc/login.md").path),
                "tokens": .string(root.appendingPathComponent("examples/tokens", isDirectory: true).path),
                "catalog": .string(root.appendingPathComponent("examples/catalogs/component-catalog.json").path),
                "out": .string(temporaryDirectory.appendingPathComponent("screen").path),
            ]
        )
        let conflictingGenerateText = try requiredText(from: conflictingGenerateResult.content)
        let conflictingGenerateReport = try JSONDecoder().decode(OperationErrorReport.self, from: Data(conflictingGenerateText.utf8))

        #expect(conflictingGenerateResult.isError == true)
        #expect(!conflictingGenerateReport.ok)
        #expect(conflictingGenerateReport.error.contains("Use exactly one of spec or screenDoc"))

        let missingBundleResult = try await session.client.callTool(
            name: "generate_bundle",
            arguments: [
                "tokens": .string(root.appendingPathComponent("examples/tokens", isDirectory: true).path),
                "catalog": .string(root.appendingPathComponent("examples/catalogs/component-catalog.json").path),
                "out": .string(temporaryDirectory.appendingPathComponent("bundle").path),
            ]
        )
        let missingBundleText = try requiredText(from: missingBundleResult.content)
        let missingBundleReport = try JSONDecoder().decode(OperationErrorReport.self, from: Data(missingBundleText.utf8))

        #expect(missingBundleResult.isError == true)
        #expect(!missingBundleReport.ok)
        #expect(missingBundleReport.error.contains("Use exactly one of specDir or screenDocDir"))

        await shutdown(session)
    }

    @Test("tools/call returns validation reports for starter screen-doc authoring gaps")
    func callToolsReportStarterScreenDocValidationFailures() async throws {
        let session = try await makeSession()
        let root = repositoryRoot()
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let screenDocPath = temporaryDirectory.appendingPathComponent("starter-login.md")
        try writeStarterLoginScreenDoc(to: screenDocPath)

        let validateResult = try await session.client.callTool(
            name: "validate_spec",
            arguments: [
                "screenDoc": .string(screenDocPath.path),
                "tokens": .string(root.appendingPathComponent("examples/tokens", isDirectory: true).path),
                "catalog": .string(root.appendingPathComponent("examples/catalogs/component-catalog.json").path),
            ]
        )
        let validateText = try requiredText(from: validateResult.content)
        let validateReport = try JSONDecoder().decode(ValidationReport.self, from: Data(validateText.utf8))

        #expect(validateResult.isError == true)
        #expect(!validateReport.ok)
        #expect(validateReport.issues.contains(where: { $0.code == "textField.missing-binding" && $0.path == "screenDoc.components[2]" }))

        let generateResult = try await session.client.callTool(
            name: "generate_screen",
            arguments: [
                "screenDoc": .string(screenDocPath.path),
                "tokens": .string(root.appendingPathComponent("examples/tokens", isDirectory: true).path),
                "catalog": .string(root.appendingPathComponent("examples/catalogs/component-catalog.json").path),
                "out": .string(temporaryDirectory.appendingPathComponent("screen").path),
            ]
        )
        let generateText = try requiredText(from: generateResult.content)
        let generateReport = try JSONDecoder().decode(ValidationReport.self, from: Data(generateText.utf8))

        #expect(generateResult.isError == true)
        #expect(!generateReport.ok)
        #expect(generateReport.issues.contains(where: { $0.code == "button.missing-action" && $0.path == "screenDoc.components[4]" }))
        #expect(!FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent("screen/compiled.screen.json").path))

        await shutdown(session)
    }

    @Test("tools/call returns a structured JSON error for unknown tools")
    func callToolsRejectUnknownToolNames() async throws {
        let session = try await makeSession()

        let result = try await session.client.callTool(
            name: "unknown_tool",
            arguments: [:]
        )
        let text = try requiredText(from: result.content)
        let report = try JSONDecoder().decode(OperationErrorReport.self, from: Data(text.utf8))

        #expect(result.isError == true)
        #expect(!report.ok)
        #expect(report.error.contains("Unknown tool: unknown_tool"))

        await shutdown(session)
    }

    @Test("tools/call returns a structured JSON error when preview_serve receives a file path")
    func callToolsRejectPreviewFilePath() async throws {
        let session = try await makeSession()
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let filePath = temporaryDirectory.appendingPathComponent("index.html")
        try "<html></html>".write(to: filePath, atomically: true, encoding: .utf8)

        let result = try await session.client.callTool(
            name: "preview_serve",
            arguments: [
                "dir": .string(filePath.path),
            ]
        )
        let text = try requiredText(from: result.content)
        let report = try JSONDecoder().decode(OperationErrorReport.self, from: Data(text.utf8))

        #expect(result.isError == true)
        #expect(!report.ok)
        #expect(report.error.contains("Preview directory is not a directory"))

        await shutdown(session)
    }

    @Test("tools/call returns a structured JSON error when preview_serve receives an occupied port")
    func callToolsRejectPreviewOccupiedPort() async throws {
        let session = try await makeSession()
        let root = repositoryRoot()
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let screenDocPath = temporaryDirectory.appendingPathComponent("login.md")
        try writeCompleteScreenDoc(
            to: screenDocPath,
            screenID: "login",
            title: "Login",
            body: "A compact login review surface."
        )
        let generateResult = try await session.client.callTool(
            name: "generate_screen",
            arguments: [
                "screenDoc": .string(screenDocPath.path),
                "tokens": .string(root.appendingPathComponent("examples/tokens", isDirectory: true).path),
                "catalog": .string(root.appendingPathComponent("examples/catalogs/component-catalog.json").path),
                "out": .string(temporaryDirectory.appendingPathComponent("screen").path),
            ]
        )
        let generateText = try requiredText(from: generateResult.content)
        let generateReport = try JSONDecoder().decode(GenerateReport.self, from: Data(generateText.utf8))
        #expect(generateResult.isError != true)
        #expect(generateReport.ok)

        let occupiedServer = try startOccupiedPortServer(
            directory: temporaryDirectory.appendingPathComponent("screen/html", isDirectory: true)
        )
        defer { try? terminateProcess(pid: occupiedServer.pid) }

        let result = try await session.client.callTool(
            name: "preview_serve",
            arguments: [
                "dir": .string(temporaryDirectory.appendingPathComponent("screen/html", isDirectory: true).path),
                "port": .string(String(occupiedServer.port)),
            ]
        )
        let text = try requiredText(from: result.content)
        let report = try JSONDecoder().decode(OperationErrorReport.self, from: Data(text.utf8))

        #expect(result.isError == true)
        #expect(!report.ok)
        #expect(report.error.contains("port may already be in use"))

        await shutdown(session)
    }

    @Test("tools/call returns a structured JSON error when preview_serve receives an invalid port")
    func callToolsRejectPreviewInvalidPort() async throws {
        let session = try await makeSession()
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let htmlDirectory = temporaryDirectory.appendingPathComponent("html", isDirectory: true)
        try FileManager.default.createDirectory(at: htmlDirectory, withIntermediateDirectories: true)
        try "<html></html>".write(to: htmlDirectory.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)

        let nonNumericResult = try await session.client.callTool(
            name: "preview_serve",
            arguments: [
                "dir": .string(htmlDirectory.path),
                "port": .string("abc"),
            ]
        )
        let nonNumericText = try requiredText(from: nonNumericResult.content)
        let nonNumericReport = try JSONDecoder().decode(OperationErrorReport.self, from: Data(nonNumericText.utf8))

        #expect(nonNumericResult.isError == true)
        #expect(!nonNumericReport.ok)
        #expect(nonNumericReport.error.contains("Preview port must be an integer"))

        let outOfRangeResult = try await session.client.callTool(
            name: "preview_serve",
            arguments: [
                "dir": .string(htmlDirectory.path),
                "port": .string("70000"),
            ]
        )
        let outOfRangeText = try requiredText(from: outOfRangeResult.content)
        let outOfRangeReport = try JSONDecoder().decode(OperationErrorReport.self, from: Data(outOfRangeText.utf8))

        #expect(outOfRangeResult.isError == true)
        #expect(!outOfRangeReport.ok)
        #expect(outOfRangeReport.error.contains("Preview port must be between 1 and 65535"))

        await shutdown(session)
    }

    private func makeSession() async throws -> (
        client: Client,
        server: Server
    ) {
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

    private func makeConfigFixture(projectRootValue: String? = nil) throws -> ConfigFixture {
        let root = repositoryRoot()
        let fixtureRoot = try makeTemporaryDirectory()
        let examplesSource = root.appendingPathComponent("examples", isDirectory: true)
        let examplesDirectory = fixtureRoot.appendingPathComponent("examples", isDirectory: true)

        try FileManager.default.copyItem(at: examplesSource, to: examplesDirectory)

        let config = DSConfig(
            schemaVersion: "1.0",
            projectRoot: projectRootValue ?? fixtureRoot.path,
            screenDocDir: "examples/screen-doc",
            screenSpecDir: "examples/screens",
            tokenDir: "examples/tokens",
            catalogPath: "examples/catalogs/component-catalog.json",
            buildDir: "build",
            defaultPlatforms: [.ios, .android, .html]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let configPath = examplesDirectory.appendingPathComponent("configs/dsctl.config.json")
        try encoder.encode(config).write(to: configPath)

        return ConfigFixture(
            root: fixtureRoot,
            configPath: configPath,
            buildDirectory: fixtureRoot.appendingPathComponent("build", isDirectory: true)
        )
    }

    private func requiredText(from content: [Tool.Content]) throws -> String {
        guard case .text(let text)? = content.first else {
            throw ProjectError.invalidArgument("Expected text tool content")
        }
        return text
    }

    private func freePort() throws -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            "-c",
            "import socket; s=socket.socket(); s.bind(('127.0.0.1', 0)); print(s.getsockname()[1]); s.close()",
        ]

        let stdout = Pipe()
        process.standardOutput = stdout
        try process.run()
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard
            process.terminationStatus == 0,
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            let port = Int(text)
        else {
            throw ProjectError.invalidArgument("Unable to allocate a free TCP port for preview smoke test")
        }

        return port
    }

    private func waitForHTTPText(at url: URL) throws -> String {
        var lastError: Error?

        for _ in 0..<20 {
            do {
                return try String(contentsOf: url)
            } catch {
                lastError = error
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        throw lastError ?? ProjectError.invalidArgument("Preview server did not become reachable")
    }

    private func startOccupiedPortServer(directory: URL) throws -> (pid: Int32, port: Int) {
        var lastError: Error?

        for _ in 0..<10 {
            let port = try freePort()
            do {
                let pid = try startOccupiedPortServer(on: port, directory: directory)
                return (pid, port)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? ProjectError.invalidArgument("Unable to start occupied port server for preview smoke test")
    }

    private func startOccupiedPortServer(on port: Int, directory: URL) throws -> Int32 {
        _ = directory
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            "-c",
            """
            import socket
            import time

            sock = socket.socket()
            sock.bind(("0.0.0.0", \(port)))
            sock.listen(1)
            time.sleep(60)
            """
        ]

        let nullHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: "/dev/null"))
        defer { try? nullHandle.close() }
        process.standardOutput = nullHandle
        process.standardError = nullHandle

        try process.run()

        Thread.sleep(forTimeInterval: 0.1)
        guard process.isRunning else {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
            throw ProjectError.invalidArgument("Occupied port server failed to stay running at \(port)")
        }

        return process.processIdentifier
    }

    private func terminateProcess(pid: Int32) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/kill")
        process.arguments = ["-TERM", String(pid)]
        try process.run()
        process.waitUntilExit()
    }

    private func writeCompleteScreenDoc(to url: URL, screenID: String, title: String, body: String) throws {
        try """
        ---
        screenId: \(screenID)
        title: \(title)
        components:
          - text.title
          - text.body
        ---
        \(body)
        """.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeStarterLoginScreenDoc(to url: URL) throws {
        try """
        ---
        screenId: login
        title: Login
        platforms: [ios, android, html]
        intent: quiet single-column login
        constraints:
          - one dominant primary action
          - no decorative elements
          - semantic tokens only
        states:
          - default
          - loading
          - error
        components:
          - text.title
          - text.body
          - textField.email
          - secureField.password
          - button.primary
        ---
        Use one title, two fields, and one primary action.
        The screen should feel calm, direct, and minimal.
        Errors should be short and explicit.
        """.write(to: url, atomically: true, encoding: .utf8)
    }
}

private struct ConfigFixture {
    let root: URL
    let configPath: URL
    let buildDirectory: URL
}
