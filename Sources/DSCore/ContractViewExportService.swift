import Foundation

public struct ContractViewExportReport: Codable, Sendable {
    public let ok: Bool
    public let runtimeOutputPath: String
    public let governanceOutputPath: String
    public let exportedViews: [String]
    public let unchangedViews: [String]
    public let errors: [String]

    public init(
        runtimeOutputPath: String,
        governanceOutputPath: String,
        exportedViews: [String],
        unchangedViews: [String],
        errors: [String] = []
    ) {
        self.ok = errors.isEmpty
        self.runtimeOutputPath = runtimeOutputPath
        self.governanceOutputPath = governanceOutputPath
        self.exportedViews = exportedViews.sorted()
        self.unchangedViews = unchangedViews.sorted()
        self.errors = errors.sorted()
    }
}

public struct ContractViewVerifyReport: Codable, Sendable {
    public let ok: Bool
    public let runtimeOutputPath: String
    public let governanceOutputPath: String
    public let freshViews: [String]
    public let staleViews: [String]
    public let errors: [String]

    public init(
        runtimeOutputPath: String,
        governanceOutputPath: String,
        freshViews: [String],
        staleViews: [String],
        errors: [String] = []
    ) {
        self.ok = staleViews.isEmpty && errors.isEmpty
        self.runtimeOutputPath = runtimeOutputPath
        self.governanceOutputPath = governanceOutputPath
        self.freshViews = freshViews.sorted()
        self.staleViews = staleViews.sorted()
        self.errors = errors.sorted()
    }
}

public struct ContractViewExportService: Sendable {
    public init() {}

    public func export(
        projectRoot: URL,
        runtimeOutputPath: URL? = nil,
        governanceOutputPath: URL? = nil
    ) throws -> ContractViewExportReport {
        let rendered = try render(projectRoot: projectRoot, runtimeOutputPath: runtimeOutputPath, governanceOutputPath: governanceOutputPath)
        var exportedViews: [String] = []
        var unchangedViews: [String] = []

        for view in rendered.views {
            if let current = try? String(contentsOf: view.outputURL), current == view.content {
                unchangedViews.append(view.relativeOutputPath)
                continue
            }

            try FileManager.default.createDirectory(
                at: view.outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try view.content.write(to: view.outputURL, atomically: true, encoding: .utf8)
            exportedViews.append(view.relativeOutputPath)
        }

        return ContractViewExportReport(
            runtimeOutputPath: rendered.runtimeOutputPath,
            governanceOutputPath: rendered.governanceOutputPath,
            exportedViews: exportedViews,
            unchangedViews: unchangedViews
        )
    }

    public func verify(
        projectRoot: URL,
        runtimeOutputPath: URL? = nil,
        governanceOutputPath: URL? = nil
    ) throws -> ContractViewVerifyReport {
        let rendered = try render(projectRoot: projectRoot, runtimeOutputPath: runtimeOutputPath, governanceOutputPath: governanceOutputPath)
        var freshViews: [String] = []
        var staleViews: [String] = []
        var errors: [String] = []

        for view in rendered.views {
            do {
                let current = try String(contentsOf: view.outputURL)
                if current == view.content {
                    freshViews.append(view.relativeOutputPath)
                } else {
                    staleViews.append(view.relativeOutputPath)
                }
            } catch {
                errors.append("\(view.relativeOutputPath): \(error.localizedDescription)")
            }
        }

        return ContractViewVerifyReport(
            runtimeOutputPath: rendered.runtimeOutputPath,
            governanceOutputPath: rendered.governanceOutputPath,
            freshViews: freshViews,
            staleViews: staleViews,
            errors: errors
        )
    }

    private func render(
        projectRoot: URL,
        runtimeOutputPath: URL?,
        governanceOutputPath: URL?
    ) throws -> RenderedContractViews {
        let runtimeContracts = try RuntimeContractLoader().load(from: projectRoot.appendingPathComponent("meta/runtime/contracts.cue"))
        let governanceContracts = try GovernanceContractLoader().load(from: projectRoot.appendingPathComponent("meta/governance/contracts.cue"))

        let runtimeOutputURL = runtimeOutputPath ?? projectRoot.appendingPathComponent(runtimeContracts.paths.runtimeContractView)
        let governanceOutputURL = governanceOutputPath ?? projectRoot.appendingPathComponent(runtimeContracts.paths.governanceContractView)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let runtimeContent = String(
            data: try encoder.encode(runtimeContracts),
            encoding: .utf8
        ) else {
            throw ProjectError.io("Unable to encode runtime contract view")
        }
        guard let governanceContent = String(
            data: try encoder.encode(governanceContracts),
            encoding: .utf8
        ) else {
            throw ProjectError.io("Unable to encode governance contract view")
        }

        return RenderedContractViews(
            runtimeOutputPath: relativePath(of: runtimeOutputURL, from: projectRoot),
            governanceOutputPath: relativePath(of: governanceOutputURL, from: projectRoot),
            views: [
                RenderedContractView(
                    relativeOutputPath: relativePath(of: runtimeOutputURL, from: projectRoot),
                    outputURL: runtimeOutputURL,
                    content: runtimeContent + "\n"
                ),
                RenderedContractView(
                    relativeOutputPath: relativePath(of: governanceOutputURL, from: projectRoot),
                    outputURL: governanceOutputURL,
                    content: governanceContent + "\n"
                ),
            ]
        )
    }

    private func relativePath(of url: URL, from projectRoot: URL) -> String {
        let standardizedRoot = projectRoot.standardizedFileURL.path
        let standardizedURL = url.standardizedFileURL.path
        if standardizedURL.hasPrefix(standardizedRoot + "/") {
            return String(standardizedURL.dropFirst(standardizedRoot.count + 1))
        }
        return standardizedURL
    }
}

private struct RenderedContractViews {
    let runtimeOutputPath: String
    let governanceOutputPath: String
    let views: [RenderedContractView]
}

private struct RenderedContractView {
    let relativeOutputPath: String
    let outputURL: URL
    let content: String
}
