import DSCore
import Foundation
import Testing

@Suite("DSCLI smoke")
struct DSCLISmokeTests {
    @Test("runtime root command list matches dsctl help")
    func runtimeRootMatchesCLIHelp() throws {
        let result = try runCLI(["--help"])
        let contracts = try RuntimeContractLoader().load(
            from: repositoryRoot().appendingPathComponent("meta/runtime/contracts.cue")
        )

        #expect(result.exitCode == 0)
        for command in contracts.cliCommands {
            #expect(result.stdout.contains(command))
        }
    }

    @Test("doctor reports CLI and MCP capabilities through the dsctl binary")
    func doctor() throws {
        let result = try runCLI([
            "doctor",
            "--json",
        ])

        let report = try JSONDecoder().decode(DoctorReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.capabilities.cli)
        #expect(report.capabilities.mcp)
        #expect(report.capabilities.iosHostSmoke == report.toolchains.swiftc)
        #expect(report.capabilities.androidHostSmoke == (report.toolchains.javaRuntime && (report.toolchains.kotlinc || report.toolchains.gradle)))
    }

    @Test("compile-screen-doc writes a compiled spec through the dsctl binary")
    func compileScreenDoc() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let outputPath = tempDirectory.appendingPathComponent("compiled/login.screen.json")
        let result = try runCLI([
            "compile-screen-doc",
            "--config", root.appendingPathComponent("examples/configs/dsctl.config.json").path,
            "--screen-id", "login",
            "--out", outputPath.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(CompileScreenDocReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(FileManager.default.fileExists(atPath: outputPath.path))
        #expect(FileManager.default.fileExists(atPath: report.reportPath))
        #expect(report.completionStatus == .complete)
        #expect(report.unresolvedItems.isEmpty)
    }

    @Test("compile-screen-doc uses the config default output path when --out is omitted")
    func compileScreenDocUsesDefaultConfigOutputPath() throws {
        let fixture = try makeConfigFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let result = try runCLI([
            "compile-screen-doc",
            "--config", fixture.configPath.path,
            "--screen-id", "login",
            "--json",
        ])

        let report = try JSONDecoder().decode(CompileScreenDocReport.self, from: Data(result.stdout.utf8))
        let expectedOutput = fixture.buildDirectory.appendingPathComponent("compiled/login.screen.json")

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.outputPath == expectedOutput.path)
        #expect(FileManager.default.fileExists(atPath: expectedOutput.path))
        #expect(FileManager.default.fileExists(atPath: report.reportPath))
        #expect(report.completionStatus == .complete)
    }

    @Test("compile-screen-doc returns a structured JSON error on operational failure")
    func compileScreenDocOperationalFailure() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let result = try runCLI([
            "compile-screen-doc",
            "--screen-doc", tempDirectory.appendingPathComponent("missing.md").path,
            "--out", tempDirectory.appendingPathComponent("compiled/missing.screen.json").path,
            "--json",
        ])

        let report = try JSONDecoder().decode(OperationErrorReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 1)
        #expect(!report.ok)
        #expect(report.error.contains("missing.md"))
    }

    @Test("relative projectRoot in config resolves from the config file location through the dsctl binary")
    func configRelativeProjectRootWorksThroughCLI() throws {
        let fixture = try makeConfigFixture(projectRootValue: "../..")
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let result = try runCLI([
            "validate",
            "--config", fixture.configPath.path,
            "--screen-id", "login",
            "--json",
        ])

        let report = try JSONDecoder().decode(ValidationReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
    }

    @Test("validate accepts screen-id input through the dsctl binary")
    func validateScreenID() throws {
        let fixture = try makeConfigFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let result = try runCLI([
            "validate",
            "--config", fixture.configPath.path,
            "--screen-id", "login",
            "--json",
        ])

        let report = try JSONDecoder().decode(ValidationReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
    }

    @Test("validate accepts complete screen-doc input through the dsctl binary")
    func validateScreenDoc() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("static-copy.md")
        try writeCompleteScreenDoc(
            to: screenDocPath,
            screenID: "static-copy",
            title: "Static Copy",
            body: "A short explanatory screen."
        )

        let result = try runCLI([
            "validate",
            "--screen-doc", screenDocPath.path,
            "--tokens", root.appendingPathComponent("examples/tokens", isDirectory: true).path,
            "--catalog", root.appendingPathComponent("examples/catalogs/component-catalog.json").path,
            "--json",
        ])

        let report = try JSONDecoder().decode(ValidationReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
    }

    @Test("validate returns a structured JSON error for operational input failures")
    func validateRequiresExactlyOnePrimaryInput() throws {
        let root = repositoryRoot()
        let result = try runCLI([
            "validate",
            "--config", root.appendingPathComponent("examples/configs/dsctl.config.json").path,
            "--json",
        ])

        let report = try JSONDecoder().decode(OperationErrorReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 1)
        #expect(!report.ok)
        #expect(report.error.contains("Use exactly one of --screen-id, --spec, or --screen-doc"))
    }

    @Test("validate returns exit code 2 for validation failures")
    func validateFailureExitCode() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let specPath = tempDirectory.appendingPathComponent("invalid.screen.json")
        let invalidSpec = ScreenSpec(
            schemaVersion: "1.0",
            screenId: "invalid",
            title: "Invalid",
            platforms: [.html],
            surface: ScreenSurface(
                backgroundColor: "{color.missing}",
                padding: "{space.6}"
            ),
            root: ScreenNode(kind: "text", role: "body", text: "Broken token reference")
        )
        try JSONEncoder().encode(invalidSpec).write(to: specPath)

        let result = try runCLI([
            "validate",
            "--spec", specPath.path,
            "--tokens", root.appendingPathComponent("examples/tokens", isDirectory: true).path,
            "--catalog", root.appendingPathComponent("examples/catalogs/component-catalog.json").path,
            "--json",
        ])

        let report = try JSONDecoder().decode(ValidationReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 2)
        #expect(!report.ok)
        #expect(report.issues.contains(where: { $0.path.contains("surface.backgroundColor") }))
    }

    @Test("validate returns exit code 2 for starter screen-doc authoring gaps")
    func validateStarterScreenDocFailureExitCode() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("starter-login.md")
        try writeStarterLoginScreenDoc(to: screenDocPath)
        let result = try runCLI([
            "validate",
            "--screen-doc", screenDocPath.path,
            "--tokens", root.appendingPathComponent("examples/tokens", isDirectory: true).path,
            "--catalog", root.appendingPathComponent("examples/catalogs/component-catalog.json").path,
            "--json",
        ])

        let report = try JSONDecoder().decode(ValidationReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 2)
        #expect(!report.ok)
        #expect(report.issues.contains(where: { $0.code == "textField.missing-binding" && $0.path == "screenDoc.components[2]" }))
    }

    @Test("generate accepts complete screen-doc input through the dsctl binary")
    func generateScreenDoc() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("static-copy.md")
        try writeCompleteScreenDoc(
            to: screenDocPath,
            screenID: "static-copy",
            title: "Static Copy",
            body: "A short explanatory screen."
        )
        let outputDirectory = tempDirectory.appendingPathComponent("screen", isDirectory: true)
        let result = try runCLI([
            "generate",
            "--screen-doc", screenDocPath.path,
            "--tokens", root.appendingPathComponent("examples/tokens", isDirectory: true).path,
            "--catalog", root.appendingPathComponent("examples/catalogs/component-catalog.json").path,
            "--out", outputDirectory.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(GenerateReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("compiled.screen.json").path))
    }

    @Test("generate returns exit code 2 for starter screen-doc authoring gaps")
    func generateStarterScreenDocFailureExitCode() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("starter-login.md")
        try writeStarterLoginScreenDoc(to: screenDocPath)
        let outputDirectory = tempDirectory.appendingPathComponent("screen", isDirectory: true)
        let result = try runCLI([
            "generate",
            "--screen-doc", screenDocPath.path,
            "--tokens", root.appendingPathComponent("examples/tokens", isDirectory: true).path,
            "--catalog", root.appendingPathComponent("examples/catalogs/component-catalog.json").path,
            "--out", outputDirectory.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(ValidationReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 2)
        #expect(!report.ok)
        #expect(report.issues.contains(where: { $0.code == "button.missing-action" && $0.path == "screenDoc.components[4]" }))
        #expect(!FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("compiled.screen.json").path))
    }

    @Test("generate uses the config default output directory for screen-id input")
    func generateScreenIDUsesDefaultConfigOutputDirectory() throws {
        let fixture = try makeConfigFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let result = try runCLI([
            "generate",
            "--config", fixture.configPath.path,
            "--screen-id", "login",
            "--json",
        ])

        let report = try JSONDecoder().decode(GenerateReport.self, from: Data(result.stdout.utf8))
        let expectedOutput = fixture.buildDirectory.appendingPathComponent("login", isDirectory: true)

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.outputDirectory == expectedOutput.path)
        #expect(FileManager.default.fileExists(atPath: expectedOutput.appendingPathComponent("manifest.json").path))
    }

    @Test("generate returns a structured JSON error for operational input failures")
    func generateRejectsConflictingPrimaryInputs() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let result = try runCLI([
            "generate",
            "--spec", root.appendingPathComponent("examples/screens/login.screen.json").path,
            "--screen-doc", root.appendingPathComponent("examples/screen-doc/login.md").path,
            "--tokens", root.appendingPathComponent("examples/tokens", isDirectory: true).path,
            "--catalog", root.appendingPathComponent("examples/catalogs/component-catalog.json").path,
            "--out", tempDirectory.appendingPathComponent("screen", isDirectory: true).path,
            "--json",
        ])

        let report = try JSONDecoder().decode(OperationErrorReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 1)
        #expect(!report.ok)
        #expect(report.error.contains("Use exactly one of --screen-id, --spec, or --screen-doc"))
    }

    @Test("generate-bundle accepts complete screen-doc-dir input through the dsctl binary")
    func generateBundleFromScreenDocs() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let outputDirectory = tempDirectory.appendingPathComponent("bundle-explicit", isDirectory: true)
        let result = try runCLI([
            "generate-bundle",
            "--config", root.appendingPathComponent("examples/configs/dsctl.config.json").path,
            "--screen-doc-dir", root.appendingPathComponent("examples/screen-doc", isDirectory: true).path,
            "--out", outputDirectory.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(GenerateBundleReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.reports.map(\.screenId) == ["login", "product-detail"])
        #expect(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("login/compiled.screen.json").path))
    }

    @Test("generate-bundle uses config default directories when screen-doc inputs are complete")
    func generateBundleUsesConfigDefaults() throws {
        let fixture = try makeConfigFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let result = try runCLI([
            "generate-bundle",
            "--config", fixture.configPath.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(GenerateBundleReport.self, from: Data(result.stdout.utf8))
        let bundleDirectory = fixture.buildDirectory.appendingPathComponent("bundle", isDirectory: true)

        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.reports.map(\.screenId) == ["login", "product-detail"])
        #expect(FileManager.default.fileExists(atPath: bundleDirectory.appendingPathComponent("login/manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: bundleDirectory.appendingPathComponent("product-detail/manifest.json").path))
    }

    @Test("generate-bundle returns exit code 4 for starter screen-doc authoring gaps")
    func generateBundleStarterScreenDocsFailureExitCode() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocDirectory = tempDirectory.appendingPathComponent("screen-doc", isDirectory: true)
        try FileManager.default.createDirectory(at: screenDocDirectory, withIntermediateDirectories: true)
        try writeStarterLoginScreenDoc(to: screenDocDirectory.appendingPathComponent("login.md"))
        try writeStarterProductDetailScreenDoc(to: screenDocDirectory.appendingPathComponent("product-detail.md"))
        let result = try runCLI([
            "generate-bundle",
            "--screen-doc-dir", screenDocDirectory.path,
            "--tokens", root.appendingPathComponent("examples/tokens", isDirectory: true).path,
            "--catalog", root.appendingPathComponent("examples/catalogs/component-catalog.json").path,
            "--out", tempDirectory.appendingPathComponent("bundle", isDirectory: true).path,
            "--json",
        ])

        let report = try JSONDecoder().decode(GenerateBundleReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 4)
        #expect(!report.ok)
        #expect(report.failures.contains(where: { $0.contains("login.md") && $0.contains("screenDoc.components[2]") }))
        #expect(report.failures.contains(where: { $0.contains("product-detail.md") && $0.contains("screenDoc.components[2]") }))
    }

    @Test("generate-bundle returns a structured JSON error for operational input failures")
    func generateBundleRejectsConflictingSourceDirectories() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let result = try runCLI([
            "generate-bundle",
            "--spec-dir", root.appendingPathComponent("examples/screens", isDirectory: true).path,
            "--screen-doc-dir", root.appendingPathComponent("examples/screen-doc", isDirectory: true).path,
            "--tokens", root.appendingPathComponent("examples/tokens", isDirectory: true).path,
            "--catalog", root.appendingPathComponent("examples/catalogs/component-catalog.json").path,
            "--out", tempDirectory.appendingPathComponent("bundle", isDirectory: true).path,
            "--json",
        ])

        let report = try JSONDecoder().decode(OperationErrorReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 1)
        #expect(!report.ok)
        #expect(report.error.contains("Use exactly one of --spec-dir or --screen-doc-dir"))
    }

    @Test("audit reports repository integrity through the dsctl binary")
    func audit() throws {
        let root = repositoryRoot()
        let result = try runCLI([
            "audit",
            "--project-root", root.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(AuditReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.errors.isEmpty)
    }

    @Test("audit returns exit code 5 when generated docs are stale against the doc-sync manifest")
    func auditStaleGeneratedDocsFailure() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let generatedDocPath = fixtureRoot.appendingPathComponent("docs/23-authoritative-source-architecture.md")
        let staleContent = try String(contentsOf: generatedDocPath).replacingOccurrences(
            of: "| runtime root | CLI command, MCP tool, input contract, output path, exit code, evidence key | task priority, decision gate prose, roadmap sequencing |",
            with: "| runtime root | stale-runtime-contract | stale-governance-boundary |"
        )
        try staleContent.write(to: generatedDocPath, atomically: true, encoding: .utf8)

        let result = try runCLI([
            "audit",
            "--project-root", fixtureRoot.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(AuditReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 5)
        #expect(!report.ok)
        #expect(!report.checks.docSyncFreshness)
        #expect(report.errors.contains(where: { $0.contains("doc-sync freshness failed: docs/23-authoritative-source-architecture.md") }))
    }

    @Test("audit returns exit code 5 when exported contract views are stale")
    func auditStaleContractViewsFailure() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let runtimeViewPath = fixtureRoot.appendingPathComponent("meta/views/runtime.contracts.json")
        let staleContent = try String(contentsOf: runtimeViewPath).replacingOccurrences(
            of: "\"audit\"",
            with: "\"stale-audit\""
        )
        try staleContent.write(to: runtimeViewPath, atomically: true, encoding: .utf8)

        let result = try runCLI([
            "audit",
            "--project-root", fixtureRoot.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(AuditReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 5)
        #expect(!report.ok)
        #expect(!report.checks.contractViewFreshness)
        #expect(report.errors.contains(where: { $0.contains("contract view freshness failed: meta/views/runtime.contracts.json") }))
    }

    @Test("audit returns exit code 5 when governance evidence refs drift from runtime evidence keys")
    func auditContractCrossReferenceFailure() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let governancePath = fixtureRoot.appendingPathComponent("meta/governance/contracts.cue")
        let drifted = try String(contentsOf: governancePath).replacingOccurrences(
            of: "\"audit_json\"",
            with: "\"missing_audit_json\""
        )
        try drifted.write(to: governancePath, atomically: true, encoding: .utf8)

        let result = try runCLI([
            "audit",
            "--project-root", fixtureRoot.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(AuditReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 5)
        #expect(!report.ok)
        #expect(!report.checks.contractCrossReference)
        #expect(report.errors.contains(where: { $0.contains("missing_audit_json") }))
    }

    @Test("generate-bundle returns exit code 4 when a screen-doc cannot compile")
    func generateBundleFailureExitCode() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocDirectory = tempDirectory.appendingPathComponent("screen-doc", isDirectory: true)
        try FileManager.default.createDirectory(at: screenDocDirectory, withIntermediateDirectories: true)
        try "broken screen doc".write(
            to: screenDocDirectory.appendingPathComponent("broken.md"),
            atomically: true,
            encoding: .utf8
        )

        let result = try runCLI([
            "generate-bundle",
            "--screen-doc-dir", screenDocDirectory.path,
            "--tokens", root.appendingPathComponent("examples/tokens", isDirectory: true).path,
            "--catalog", root.appendingPathComponent("examples/catalogs/component-catalog.json").path,
            "--out", tempDirectory.appendingPathComponent("bundle", isDirectory: true).path,
            "--json",
        ])

        let report = try JSONDecoder().decode(GenerateBundleReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 4)
        #expect(!report.ok)
        #expect(report.failures.contains(where: { $0.contains("broken.md") }))
    }

    @Test("audit returns exit code 5 when the project root is invalid")
    func auditFailureExitCode() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let result = try runCLI([
            "audit",
            "--project-root", tempDirectory.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(AuditReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 5)
        #expect(!report.ok)
        #expect(!report.errors.isEmpty)
    }

    @Test("preview-serve starts an HTTP server for generated HTML")
    func previewServe() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("login.md")
        try writeCompleteScreenDoc(
            to: screenDocPath,
            screenID: "login",
            title: "Login",
            body: "A compact login review surface."
        )
        let outputDirectory = tempDirectory.appendingPathComponent("screen", isDirectory: true)
        _ = try runCLI([
            "generate",
            "--screen-doc", screenDocPath.path,
            "--tokens", root.appendingPathComponent("examples/tokens", isDirectory: true).path,
            "--catalog", root.appendingPathComponent("examples/catalogs/component-catalog.json").path,
            "--out", outputDirectory.path,
            "--json",
        ])

        let port = try freePort()
        let previewResult = try runCLI([
            "preview-serve",
            "--dir", outputDirectory.appendingPathComponent("html", isDirectory: true).path,
            "--port", String(port),
            "--json",
        ])

        let report = try JSONDecoder().decode(PreviewServeReport.self, from: Data(previewResult.stdout.utf8))
        defer { try? terminateProcess(pid: report.pid) }

        #expect(previewResult.exitCode == 0)
        #expect(report.ok)
        #expect(report.url == "http://127.0.0.1:\(port)/")

        let indexHTML = try waitForHTTPText(at: URL(string: report.url)!)
        #expect(indexHTML.contains("login.html"))
    }

    @Test("preview-serve returns a structured JSON error when the directory is missing")
    func previewServeOperationalFailure() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let result = try runCLI([
            "preview-serve",
            "--dir", tempDirectory.appendingPathComponent("missing-html", isDirectory: true).path,
            "--json",
        ])

        let report = try JSONDecoder().decode(OperationErrorReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 1)
        #expect(!report.ok)
        #expect(report.error.contains("Preview directory does not exist"))
    }

    @Test("preview-serve returns a structured JSON error when the path is a file")
    func previewServeRejectsFilePath() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let filePath = tempDirectory.appendingPathComponent("index.html")
        try "<html></html>".write(to: filePath, atomically: true, encoding: .utf8)

        let result = try runCLI([
            "preview-serve",
            "--dir", filePath.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(OperationErrorReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 1)
        #expect(!report.ok)
        #expect(report.error.contains("Preview directory is not a directory"))
    }

    @Test("preview-serve returns a structured JSON error when the port is already in use")
    func previewServeRejectsUnavailablePort() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("login.md")
        try writeCompleteScreenDoc(
            to: screenDocPath,
            screenID: "login",
            title: "Login",
            body: "A compact login review surface."
        )
        let outputDirectory = tempDirectory.appendingPathComponent("screen", isDirectory: true)
        _ = try runCLI([
            "generate",
            "--screen-doc", screenDocPath.path,
            "--tokens", root.appendingPathComponent("examples/tokens", isDirectory: true).path,
            "--catalog", root.appendingPathComponent("examples/catalogs/component-catalog.json").path,
            "--out", outputDirectory.path,
            "--json",
        ])

        let occupiedServer = try startOccupiedPortServer(
            directory: outputDirectory.appendingPathComponent("html", isDirectory: true)
        )
        defer { try? terminateProcess(pid: occupiedServer.pid) }

        let result = try runCLI([
            "preview-serve",
            "--dir", outputDirectory.appendingPathComponent("html", isDirectory: true).path,
            "--port", String(occupiedServer.port),
            "--json",
        ])

        let report = try JSONDecoder().decode(OperationErrorReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 1)
        #expect(!report.ok)
        #expect(report.error.contains("port may already be in use"))
    }

    @Test("preview-serve returns a structured JSON error when the port is out of range")
    func previewServeRejectsOutOfRangePort() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("login.md")
        try writeCompleteScreenDoc(
            to: screenDocPath,
            screenID: "login",
            title: "Login",
            body: "A compact login review surface."
        )
        let outputDirectory = tempDirectory.appendingPathComponent("screen", isDirectory: true)
        _ = try runCLI([
            "generate",
            "--screen-doc", screenDocPath.path,
            "--tokens", root.appendingPathComponent("examples/tokens", isDirectory: true).path,
            "--catalog", root.appendingPathComponent("examples/catalogs/component-catalog.json").path,
            "--out", outputDirectory.path,
            "--json",
        ])

        let result = try runCLI([
            "preview-serve",
            "--dir", outputDirectory.appendingPathComponent("html", isDirectory: true).path,
            "--port", "0",
            "--json",
        ])

        let report = try JSONDecoder().decode(OperationErrorReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 1)
        #expect(!report.ok)
        #expect(report.error.contains("Preview port must be between 1 and 65535"))
    }

    private func runCLI(_ arguments: [String]) throws -> CLIResult {
        let process = Process()
        process.executableURL = try dsctlURL()
        process.arguments = arguments
        process.currentDirectoryURL = repositoryRoot()

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()

        return CLIResult(
            exitCode: Int(process.terminationStatus),
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self)
        )
    }

    private func dsctlURL() throws -> URL {
        let root = repositoryRoot()
        let candidates = [
            root.appendingPathComponent(".build/debug/dsctl"),
            root.appendingPathComponent(".build/arm64-apple-macosx/debug/dsctl"),
            root.appendingPathComponent(".build/x86_64-apple-macosx/debug/dsctl"),
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate
        }

        throw ProjectError.invalidArgument("dsctl binary was not built before CLI smoke tests")
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

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
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

    private func makeAuditFixture() throws -> URL {
        let root = repositoryRoot()
        let fixtureRoot = try makeTemporaryDirectory()
        let fileManager = FileManager.default

        for file in ["README.md", "MASTER_BLUEPRINT.md", "AGENTS.md"] {
            try fileManager.copyItem(
                at: root.appendingPathComponent(file),
                to: fixtureRoot.appendingPathComponent(file)
            )
        }

        for directory in ["docs", "examples", "schemas", "prompts", "meta"] {
            try fileManager.copyItem(
                at: root.appendingPathComponent(directory, isDirectory: true),
                to: fixtureRoot.appendingPathComponent(directory, isDirectory: true)
            )
        }

        return fixtureRoot
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-cli-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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

    private func writeStarterProductDetailScreenDoc(to url: URL) throws {
        try """
        ---
        screenId: product-detail
        title: Product Detail
        platforms: [ios, android, html]
        intent: focused product summary with one purchase action
        constraints:
          - one clear information hierarchy
          - one primary CTA
          - semantic tokens only
        states:
          - default
        components:
          - text.title
          - text.body
          - card
          - button.primary
        ---
        Present the product name, short summary, price context, and one purchase action.
        The screen should remain quiet and compact.
        """.write(to: url, atomically: true, encoding: .utf8)
    }
}

private struct CLIResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}

private struct ConfigFixture {
    let root: URL
    let configPath: URL
    let buildDirectory: URL
}
