import Foundation

public struct DocSyncManifest: Codable, Sendable {
    public let documents: [DocSyncDocument]

    public init(documents: [DocSyncDocument]) {
        self.documents = documents
    }
}

public struct DocSyncDocument: Codable, Sendable {
    public let path: String
    public let regions: [DocSyncRegion]

    public init(path: String, regions: [DocSyncRegion]) {
        self.path = path
        self.regions = regions
    }
}

public struct DocSyncRegion: Codable, Sendable {
    public let id: String
    public let content: String?
    public let contentPath: String?

    public init(id: String, content: String) {
        self.id = id
        self.content = content
        self.contentPath = nil
    }

    public init(id: String, contentPath: String) {
        self.id = id
        self.content = nil
        self.contentPath = contentPath
    }
}

public struct DocSyncRenderReport: Codable, Sendable {
    public let ok: Bool
    public let renderedDocuments: [String]
    public let unchangedDocuments: [String]

    public init(renderedDocuments: [String], unchangedDocuments: [String]) {
        self.ok = true
        self.renderedDocuments = renderedDocuments.sorted()
        self.unchangedDocuments = unchangedDocuments.sorted()
    }
}

public struct DocSyncVerifyReport: Codable, Sendable {
    public let ok: Bool
    public let freshDocuments: [String]
    public let staleDocuments: [String]
    public let errors: [String]

    public init(freshDocuments: [String], staleDocuments: [String], errors: [String]) {
        self.ok = staleDocuments.isEmpty && errors.isEmpty
        self.freshDocuments = freshDocuments.sorted()
        self.staleDocuments = staleDocuments.sorted()
        self.errors = errors.sorted()
    }
}

public struct DocSyncSyncReport: Codable, Sendable {
    public let ok: Bool
    public let specPath: String
    public let manifestPath: String
    public let runtimeContractViewPath: String
    public let governanceContractViewPath: String
    public let exportedContractViews: [String]
    public let unchangedContractViews: [String]
    public let exportedFragments: [String]
    public let unchangedFragments: [String]
    public let renderedDocuments: [String]
    public let unchangedDocuments: [String]
    public let freshDocuments: [String]
    public let staleDocuments: [String]
    public let errors: [String]

    public init(
        specPath: String,
        manifestPath: String,
        runtimeContractViewPath: String,
        governanceContractViewPath: String,
        exportedContractViews: [String],
        unchangedContractViews: [String],
        exportedFragments: [String],
        unchangedFragments: [String],
        renderedDocuments: [String],
        unchangedDocuments: [String],
        freshDocuments: [String],
        staleDocuments: [String],
        errors: [String]
    ) {
        self.ok = staleDocuments.isEmpty && errors.isEmpty
        self.specPath = specPath
        self.manifestPath = manifestPath
        self.runtimeContractViewPath = runtimeContractViewPath
        self.governanceContractViewPath = governanceContractViewPath
        self.exportedContractViews = exportedContractViews.sorted()
        self.unchangedContractViews = unchangedContractViews.sorted()
        self.exportedFragments = exportedFragments.sorted()
        self.unchangedFragments = unchangedFragments.sorted()
        self.renderedDocuments = renderedDocuments.sorted()
        self.unchangedDocuments = unchangedDocuments.sorted()
        self.freshDocuments = freshDocuments.sorted()
        self.staleDocuments = staleDocuments.sorted()
        self.errors = errors.sorted()
    }
}

public enum DocSyncError: Error, LocalizedError {
    case invalidManifest(String)
    case renderFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidManifest(let message), .renderFailed(let message):
            return message
        }
    }
}

public struct DocSyncService: Sendable {
    public init() {}

    public func loadManifest(at url: URL) throws -> DocSyncManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(DocSyncManifest.self, from: data)
    }

    public func render(manifestPath: URL, projectRoot: URL) throws -> DocSyncRenderReport {
        let manifest = try loadManifest(at: manifestPath)
        let manifestDirectory = manifestPath.deletingLastPathComponent()
        var renderedDocuments: [String] = []
        var unchangedDocuments: [String] = []

        for document in manifest.documents {
            let url = resolve(path: document.path, relativeTo: projectRoot)
            let current = try String(contentsOf: url)
            let rendered = try render(document: document, current: current, manifestDirectory: manifestDirectory)

            if rendered == current {
                unchangedDocuments.append(document.path)
                continue
            }

            try rendered.write(to: url, atomically: true, encoding: .utf8)
            renderedDocuments.append(document.path)
        }

        return DocSyncRenderReport(
            renderedDocuments: renderedDocuments,
            unchangedDocuments: unchangedDocuments
        )
    }

    public func verify(manifestPath: URL, projectRoot: URL) throws -> DocSyncVerifyReport {
        let manifest = try loadManifest(at: manifestPath)
        let manifestDirectory = manifestPath.deletingLastPathComponent()
        var freshDocuments: [String] = []
        var staleDocuments: [String] = []
        var errors: [String] = []

        for document in manifest.documents {
            let url = resolve(path: document.path, relativeTo: projectRoot)
            do {
                let current = try String(contentsOf: url)
                let rendered = try render(document: document, current: current, manifestDirectory: manifestDirectory)
                if rendered == current {
                    freshDocuments.append(document.path)
                } else {
                    staleDocuments.append(document.path)
                }
            } catch {
                errors.append("\(document.path): \(error.localizedDescription)")
            }
        }

        return DocSyncVerifyReport(
            freshDocuments: freshDocuments,
            staleDocuments: staleDocuments,
            errors: errors
        )
    }

    public func sync(specPath: URL, manifestPath: URL, projectRoot: URL) throws -> DocSyncSyncReport {
        let exportReport = try exportFragments(specPath: specPath, projectRoot: projectRoot)
        let renderReport = try render(manifestPath: manifestPath, projectRoot: projectRoot)
        let verifyReport = try verify(manifestPath: manifestPath, projectRoot: projectRoot)

        return DocSyncSyncReport(
            specPath: specPath.path,
            manifestPath: manifestPath.path,
            runtimeContractViewPath: "",
            governanceContractViewPath: "",
            exportedContractViews: [],
            unchangedContractViews: [],
            exportedFragments: exportReport.exportedFragments,
            unchangedFragments: exportReport.unchangedFragments,
            renderedDocuments: renderReport.renderedDocuments,
            unchangedDocuments: renderReport.unchangedDocuments,
            freshDocuments: verifyReport.freshDocuments,
            staleDocuments: verifyReport.staleDocuments,
            errors: exportReport.errors + verifyReport.errors
        )
    }

    public func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw DocSyncError.renderFailed("Unable to encode JSON output")
        }
        return text
    }

    private func resolve(path: String, relativeTo projectRoot: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return projectRoot.appendingPathComponent(path)
    }

    private func render(document: DocSyncDocument, current: String, manifestDirectory: URL) throws -> String {
        var rendered = current
        for region in document.regions {
            let replacement = try resolveContent(for: region, manifestDirectory: manifestDirectory)
            rendered = try replaceRegion(region, replacement: replacement, in: rendered, path: document.path)
        }
        return rendered
    }

    private func replaceRegion(_ region: DocSyncRegion, replacement: String, in content: String, path: String) throws -> String {
        let beginMarker = "<!-- GENERATED:BEGIN \(region.id) -->"
        let endMarker = "<!-- GENERATED:END \(region.id) -->"
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        guard let beginIndex = lines.firstIndex(of: beginMarker) else {
            throw DocSyncError.invalidManifest("Missing begin marker \(beginMarker) in \(path)")
        }
        guard let endIndex = lines[(beginIndex + 1)...].firstIndex(of: endMarker) else {
            throw DocSyncError.invalidManifest("Missing end marker \(endMarker) in \(path)")
        }

        let replacementLines = replacement.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        lines.replaceSubrange((beginIndex + 1)..<endIndex, with: replacementLines)

        return lines.joined(separator: "\n")
    }

    private func resolveContent(for region: DocSyncRegion, manifestDirectory: URL) throws -> String {
        switch (region.content, region.contentPath) {
        case let (content?, nil):
            return content.replacingOccurrences(of: "\\n", with: "\n")
        case let (nil, contentPath?):
            let url = resolve(path: contentPath, relativeTo: manifestDirectory)
            return normalizeFragmentContent(try String(contentsOf: url))
        case (.none, .none):
            throw DocSyncError.invalidManifest("Region \(region.id) must provide content or contentPath")
        case (.some, .some):
            throw DocSyncError.invalidManifest("Region \(region.id) must not provide both content and contentPath")
        }
    }

    private func normalizeFragmentContent(_ content: String) -> String {
        var normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
        while normalized.hasSuffix("\n") {
            normalized.removeLast()
        }
        return normalized
    }
}
