import DSCore
import DSDocSyncKit
import Foundation
import Testing

@Suite("DSDocSync smoke")
struct DSDocSyncSmokeTests {
    @Test("runtime root command list matches ds-doc-sync help")
    func runtimeRootMatchesDocSyncHelp() throws {
        let result = try runCLI(["--help"])
        let contracts = try RuntimeContractLoader().load(
            from: repositoryRoot().appendingPathComponent("meta/runtime/contracts.cue")
        )

        #expect(result.exitCode == 0)
        for command in contracts.docSyncCommands {
            #expect(result.stdout.contains(command))
        }
    }

    @Test("export-contracts uses conventional project paths through the ds-doc-sync binary")
    func exportContractsUsesDefaultConventionalPaths() throws {
        let fixtureRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let runtimeDirectory = fixtureRoot.appendingPathComponent("meta/runtime", isDirectory: true)
        let governanceDirectory = fixtureRoot.appendingPathComponent("meta/governance", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: governanceDirectory, withIntermediateDirectories: true)

        try """
        package runtime

        cliCommands: [
            "doctor",
        ]

        mcpTools: [
            "doctor",
        ]

        docSyncCommands: [
            "sync",
            "export-contracts",
        ]

        evidenceKeys: [
            "audit_json",
        ]

        doctorCapabilities: [
            "cli",
            "android_host_smoke",
        ]

        doctorToolchains: [
            "swiftc",
            "java_runtime",
        ]

        paths: {
            governanceFragmentSpec: "meta/views/governance.fragments.json"
            docSyncManifest: "meta/views/docsync.manifest.json"
            runtimeContractView: "meta/views/runtime.contracts.json"
            governanceContractView: "meta/views/governance.contracts.json"
        }

        exitCodes: {
            operational: 1
            validationFailure: 2
            bundleFailure: 4
            auditFailure: 5
        }
        """.write(to: runtimeDirectory.appendingPathComponent("contracts.cue"), atomically: true, encoding: .utf8)

        try """
        package governance

        generatedDocs: [
            "docs/11-execution-plan.md",
        ]

        authoritativeRoots: [
            "meta/runtime",
            "meta/governance",
        ]

        evidenceRefs: [
            "audit_json",
        ]

        runtimeArtifacts: []

        planningArtifacts: []

        integrationArtifacts: []

        acceptanceArtifacts: []
        """.write(to: governanceDirectory.appendingPathComponent("contracts.cue"), atomically: true, encoding: .utf8)

        let result = try runCLI([
            "export-contracts",
            "--project-root", fixtureRoot.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(ContractViewExportReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.runtimeOutputPath == "meta/views/runtime.contracts.json")
        #expect(report.governanceOutputPath == "meta/views/governance.contracts.json")
        #expect(FileManager.default.fileExists(atPath: fixtureRoot.appendingPathComponent(report.runtimeOutputPath).path))
        #expect(FileManager.default.fileExists(atPath: fixtureRoot.appendingPathComponent(report.governanceOutputPath).path))
    }

    @Test("sync uses conventional project paths through the ds-doc-sync binary")
    func syncUsesDefaultConventionalPaths() throws {
        let fixtureRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let runtimeDirectory = fixtureRoot.appendingPathComponent("meta/runtime", isDirectory: true)
        let governanceDirectory = fixtureRoot.appendingPathComponent("meta/governance", isDirectory: true)
        let viewsDirectory = fixtureRoot.appendingPathComponent("meta/views", isDirectory: true)
        let docsDirectory = fixtureRoot.appendingPathComponent("docs", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: governanceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: viewsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: docsDirectory, withIntermediateDirectories: true)

        try """
        package runtime

        cliCommands: [
            "doctor",
        ]

        mcpTools: [
            "doctor",
        ]

        docSyncCommands: [
            "sync",
            "export-contracts",
            "export-fragments",
            "render",
            "verify",
        ]

        evidenceKeys: [
            "audit_json",
        ]

        doctorCapabilities: [
            "cli",
            "android_host_smoke",
        ]

        doctorToolchains: [
            "swiftc",
            "java_runtime",
        ]

        paths: {
            governanceFragmentSpec: "meta/views/governance.fragments.json"
            docSyncManifest: "meta/views/docsync.manifest.json"
            runtimeContractView: "meta/views/runtime.contracts.json"
            governanceContractView: "meta/views/governance.contracts.json"
        }

        exitCodes: {
            operational: 1
            validationFailure: 2
            bundleFailure: 4
            auditFailure: 5
        }
        """.write(to: runtimeDirectory.appendingPathComponent("contracts.cue"), atomically: true, encoding: .utf8)

        try """
        package governance

        generatedDocs: [
            "docs/status.md",
        ]

        authoritativeRoots: [
            "meta/runtime",
            "meta/governance",
        ]

        evidenceRefs: [
            "audit_json",
        ]

        runtimeArtifacts: []

        planningArtifacts: []

        integrationArtifacts: []

        acceptanceArtifacts: []
        """.write(to: governanceDirectory.appendingPathComponent("contracts.cue"), atomically: true, encoding: .utf8)

        let contracts = try RuntimeContractLoader().load(
            from: runtimeDirectory.appendingPathComponent("contracts.cue")
        )

        let spec = DocFragmentExportSpec(fragments: [
            DocFragment(
                path: "meta/views/fragments/status.md",
                kind: .markdownTable,
                headers: ["State", "Value"],
                rows: [["doc-sync", "ready"]]
            ),
        ])
        try JSONEncoder().encode(spec).write(to: viewsDirectory.appendingPathComponent("governance.fragments.json"))

        let manifest = DocSyncManifest(documents: [
            DocSyncDocument(
                path: "docs/status.md",
                regions: [DocSyncRegion(id: "status", contentPath: "fragments/status.md")]
            ),
        ])
        try JSONEncoder().encode(manifest).write(to: viewsDirectory.appendingPathComponent("docsync.manifest.json"))

        try """
        # Status

        <!-- GENERATED:BEGIN status -->
        stale
        <!-- GENERATED:END status -->
        """.write(to: docsDirectory.appendingPathComponent("status.md"), atomically: true, encoding: .utf8)

        let result = try runCLI([
            "sync",
            "--project-root", fixtureRoot.path,
            "--json",
        ])

        let report = try JSONDecoder().decode(DocSyncSyncReport.self, from: Data(result.stdout.utf8))
        #expect(result.exitCode == 0)
        #expect(report.ok)
        #expect(report.specPath == fixtureRoot.appendingPathComponent(contracts.paths.governanceFragmentSpec).path)
        #expect(report.manifestPath == fixtureRoot.appendingPathComponent(contracts.paths.docSyncManifest).path)
        #expect(report.runtimeContractViewPath == contracts.paths.runtimeContractView)
        #expect(report.governanceContractViewPath == contracts.paths.governanceContractView)
        #expect(report.exportedContractViews == [
            "meta/views/governance.contracts.json",
            "meta/views/runtime.contracts.json",
        ])
        #expect(report.exportedFragments == ["meta/views/fragments/status.md"])
        #expect(report.renderedDocuments == ["docs/status.md"])
        #expect(report.freshDocuments == ["docs/status.md"])
    }

    @Test("repo doc-sync manifest includes authoritative-source annex generated regions")
    func repositoryManifestIncludesAnnexGeneratedRegions() throws {
        let manifest = try DocSyncService().loadManifest(
            at: repositoryRoot().appendingPathComponent("meta/views/docsync.manifest.json")
        )

        let documentPaths = Set(manifest.documents.map(\.path))
        #expect(documentPaths.contains("docs/24-authoritative-source-execution-plan.md"))
        #expect(documentPaths.contains("docs/25-authoritative-source-task-matrix.md"))

        let annex24 = try #require(manifest.documents.first(where: { $0.path == "docs/24-authoritative-source-execution-plan.md" }))
        let annex25 = try #require(manifest.documents.first(where: { $0.path == "docs/25-authoritative-source-task-matrix.md" }))

        #expect(annex24.regions.map(\.id) == ["authoritative-source-execution-plan-phases"])
        #expect(annex25.regions.map(\.id) == ["authoritative-source-task-matrix-rows"])
    }

    private func runCLI(_ arguments: [String]) throws -> CLIResult {
        let process = Process()
        process.executableURL = try dsDocSyncURL()
        process.arguments = arguments
        process.currentDirectoryURL = repositoryRoot()

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        return CLIResult(
            exitCode: Int(process.terminationStatus),
            stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }

    private func dsDocSyncURL() throws -> URL {
        let root = repositoryRoot()
        let candidates = [
            root.appendingPathComponent(".build/debug/ds-doc-sync"),
            root.appendingPathComponent(".build/arm64-apple-macosx/debug/ds-doc-sync"),
            root.appendingPathComponent(".build/x86_64-apple-macosx/debug/ds-doc-sync"),
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate
        }

        throw DocSyncError.renderFailed("ds-doc-sync binary was not built before smoke tests")
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-docsync-cli-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct CLIResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
