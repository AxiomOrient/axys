import Foundation

public struct DocFragmentExportSpec: Codable, Sendable {
    public let fragments: [DocFragment]

    public init(fragments: [DocFragment]) {
        self.fragments = fragments
    }
}

public struct DocFragment: Codable, Sendable {
    public let path: String
    public let kind: DocFragmentKind
    public let headers: [String]
    public let rows: [[String]]

    public init(path: String, kind: DocFragmentKind, headers: [String], rows: [[String]]) {
        self.path = path
        self.kind = kind
        self.headers = headers
        self.rows = rows
    }
}

public enum DocFragmentKind: String, Codable, Sendable {
    case markdownTable = "markdown_table"
}

public struct DocFragmentExportReport: Codable, Sendable {
    public let ok: Bool
    public let exportedFragments: [String]
    public let unchangedFragments: [String]
    public let errors: [String]

    public init(exportedFragments: [String], unchangedFragments: [String], errors: [String] = []) {
        self.ok = errors.isEmpty
        self.exportedFragments = exportedFragments.sorted()
        self.unchangedFragments = unchangedFragments.sorted()
        self.errors = errors.sorted()
    }
}

extension DocSyncService {
    public func exportFragments(specPath: URL, projectRoot: URL) throws -> DocFragmentExportReport {
        let data = try Data(contentsOf: specPath)
        let spec = try JSONDecoder().decode(DocFragmentExportSpec.self, from: data)
        var exportedFragments: [String] = []
        var unchangedFragments: [String] = []

        for fragment in spec.fragments {
            let outputURL = resolveOutput(path: fragment.path, relativeTo: projectRoot)
            let rendered = try render(fragment: fragment)

            if let current = try? String(contentsOf: outputURL), current == rendered {
                unchangedFragments.append(fragment.path)
                continue
            }

            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try rendered.write(to: outputURL, atomically: true, encoding: .utf8)
            exportedFragments.append(fragment.path)
        }

        return DocFragmentExportReport(
            exportedFragments: exportedFragments,
            unchangedFragments: unchangedFragments
        )
    }

    private func resolveOutput(path: String, relativeTo projectRoot: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return projectRoot.appendingPathComponent(path)
    }

    private func render(fragment: DocFragment) throws -> String {
        switch fragment.kind {
        case .markdownTable:
            guard fragment.rows.allSatisfy({ $0.count == fragment.headers.count }) else {
                throw DocSyncError.invalidManifest("Fragment \(fragment.path) row width does not match headers")
            }
            let header = "| " + fragment.headers.joined(separator: " | ") + " |"
            let divider = "|" + Array(repeating: "---", count: fragment.headers.count).joined(separator: "|") + "|"
            let rows = fragment.rows.map { "| " + $0.joined(separator: " | ") + " |" }
            return ([header, divider] + rows).joined(separator: "\n") + "\n"
        }
    }
}
