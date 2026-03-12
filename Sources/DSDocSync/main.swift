import ArgumentParser
import DSCore
import DSDocSyncKit
import Foundation

@main
struct DSDocSyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ds-doc-sync",
        abstract: "Render and verify generated markdown regions from a manifest",
        subcommands: [SyncCommand.self, ExportContractsCommand.self, RenderCommand.self, VerifyCommand.self, ExportFragmentsCommand.self]
    )
}

struct SyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Export fragment sources, render generated regions, and verify freshness in one pass"
    )

    @Option(name: .long) var spec: String?
    @Option(name: .long) var manifest: String?
    @Option(name: .long) var projectRoot: String = "."
    @Flag(name: .long) var json = false

    func run() async throws {
        let service = DocSyncService()
        let exporter = ContractViewExportService()
        let projectRootURL = URL(fileURLWithPath: projectRoot)
        let runtimeContracts = try? RuntimeContractLoader().load(
            from: projectRootURL.appendingPathComponent("meta/runtime/contracts.cue")
        )
        let resolvedSpecPath = spec ?? defaultSpecPath(projectRoot: projectRootURL, runtimeContracts: runtimeContracts).path
        let resolvedManifestPath = manifest ?? defaultManifestPath(projectRoot: projectRootURL, runtimeContracts: runtimeContracts).path

        do {
            let contractReport = try exporter.export(projectRoot: projectRootURL)
            let baseReport = try service.sync(
                specPath: URL(fileURLWithPath: resolvedSpecPath),
                manifestPath: URL(fileURLWithPath: resolvedManifestPath),
                projectRoot: projectRootURL
            )
            let report = DocSyncSyncReport(
                specPath: baseReport.specPath,
                manifestPath: baseReport.manifestPath,
                runtimeContractViewPath: contractReport.runtimeOutputPath,
                governanceContractViewPath: contractReport.governanceOutputPath,
                exportedContractViews: contractReport.exportedViews,
                unchangedContractViews: contractReport.unchangedViews,
                exportedFragments: baseReport.exportedFragments,
                unchangedFragments: baseReport.unchangedFragments,
                renderedDocuments: baseReport.renderedDocuments,
                unchangedDocuments: baseReport.unchangedDocuments,
                freshDocuments: baseReport.freshDocuments,
                staleDocuments: baseReport.staleDocuments,
                errors: contractReport.errors + baseReport.errors
            )
            try printJSON(service, report)
            if !report.ok {
                throw ExitCode(1)
            }
        } catch let code as ExitCode {
            throw code
        } catch {
            try printJSON(
                service,
                DocSyncSyncReport(
                    specPath: resolvedSpecPath,
                    manifestPath: resolvedManifestPath,
                    runtimeContractViewPath: projectRootURL.appendingPathComponent(runtimeContracts?.paths.runtimeContractView ?? "meta/views/runtime.contracts.json").path,
                    governanceContractViewPath: projectRootURL.appendingPathComponent(runtimeContracts?.paths.governanceContractView ?? "meta/views/governance.contracts.json").path,
                    exportedContractViews: [],
                    unchangedContractViews: [],
                    exportedFragments: [],
                    unchangedFragments: [],
                    renderedDocuments: [],
                    unchangedDocuments: [],
                    freshDocuments: [],
                    staleDocuments: [],
                    errors: [error.localizedDescription]
                )
            )
            throw ExitCode(1)
        }
    }
}

struct ExportContractsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export-contracts",
        abstract: "Export authoritative runtime/governance roots into concrete JSON views"
    )

    @Option(name: .long) var projectRoot: String = "."
    @Option(name: .long) var runtimeOut: String?
    @Option(name: .long) var governanceOut: String?
    @Flag(name: .long) var json = false

    func run() async throws {
        let service = DocSyncService()
        let exporter = ContractViewExportService()
        let projectRootURL = URL(fileURLWithPath: projectRoot)
        let runtimeContracts = try? RuntimeContractLoader().load(
            from: projectRootURL.appendingPathComponent("meta/runtime/contracts.cue")
        )

        do {
            let report = try exporter.export(
                projectRoot: projectRootURL,
                runtimeOutputPath: runtimeOut.map { URL(fileURLWithPath: $0) },
                governanceOutputPath: governanceOut.map { URL(fileURLWithPath: $0) }
            )
            try printJSON(service, report)
            if !report.ok {
                throw ExitCode(1)
            }
        } catch let code as ExitCode {
            throw code
        } catch {
            try printJSON(
                service,
                ContractViewExportReport(
                    runtimeOutputPath: runtimeOut ?? projectRootURL.appendingPathComponent(runtimeContracts?.paths.runtimeContractView ?? "meta/views/runtime.contracts.json").path,
                    governanceOutputPath: governanceOut ?? projectRootURL.appendingPathComponent(runtimeContracts?.paths.governanceContractView ?? "meta/views/governance.contracts.json").path,
                    exportedViews: [],
                    unchangedViews: [],
                    errors: [error.localizedDescription]
                )
            )
            throw ExitCode(1)
        }
    }
}

struct RenderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "render", abstract: "Render generated markdown regions")

    @Option(name: .long) var manifest: String
    @Option(name: .long) var projectRoot: String = "."
    @Flag(name: .long) var json = false

    func run() async throws {
        let service = DocSyncService()
        do {
            let report = try service.render(
                manifestPath: URL(fileURLWithPath: manifest),
                projectRoot: URL(fileURLWithPath: projectRoot)
            )
            try printJSON(service, report)
        } catch {
            try printJSON(service, DocSyncVerifyReport(freshDocuments: [], staleDocuments: [], errors: [error.localizedDescription]))
            throw ExitCode(1)
        }
    }
}

struct VerifyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "verify", abstract: "Verify generated markdown regions are fresh")

    @Option(name: .long) var manifest: String
    @Option(name: .long) var projectRoot: String = "."
    @Flag(name: .long) var json = false

    func run() async throws {
        let service = DocSyncService()
        do {
            let report = try service.verify(
                manifestPath: URL(fileURLWithPath: manifest),
                projectRoot: URL(fileURLWithPath: projectRoot)
            )
            try printJSON(service, report)
            if !report.ok {
                throw ExitCode(1)
            }
        } catch let code as ExitCode {
            throw code
        } catch {
            try printJSON(service, DocSyncVerifyReport(freshDocuments: [], staleDocuments: [], errors: [error.localizedDescription]))
            throw ExitCode(1)
        }
    }
}

struct ExportFragmentsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export-fragments",
        abstract: "Export markdown fragments from a structured JSON spec"
    )

    @Option(name: .long) var spec: String
    @Option(name: .long) var projectRoot: String = "."
    @Flag(name: .long) var json = false

    func run() async throws {
        let service = DocSyncService()
        do {
            let report = try service.exportFragments(
                specPath: URL(fileURLWithPath: spec),
                projectRoot: URL(fileURLWithPath: projectRoot)
            )
            try printJSON(service, report)
            if !report.ok {
                throw ExitCode(1)
            }
        } catch let code as ExitCode {
            throw code
        } catch {
            try printJSON(service, DocFragmentExportReport(exportedFragments: [], unchangedFragments: [], errors: [error.localizedDescription]))
            throw ExitCode(1)
        }
    }
}

private func printJSON<T: Encodable>(_ service: DocSyncService, _ value: T) throws {
    guard let data = try service.encodeJSON(value).data(using: .utf8) else {
        throw ExitCode(1)
    }
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

private func defaultSpecPath(projectRoot: URL, runtimeContracts: RuntimeContracts?) -> URL {
    projectRoot.appendingPathComponent(runtimeContracts?.paths.governanceFragmentSpec ?? "meta/views/governance.fragments.json")
}

private func defaultManifestPath(projectRoot: URL, runtimeContracts: RuntimeContracts?) -> URL {
    projectRoot.appendingPathComponent(runtimeContracts?.paths.docSyncManifest ?? "meta/views/docsync.manifest.json")
}
