import Foundation

public struct RuntimeContracts: Codable, Sendable, Equatable {
    public let cliCommands: [String]
    public let mcpTools: [String]
    public let docSyncCommands: [String]
    public let evidenceKeys: [String]
    public let doctorCapabilities: [String]
    public let doctorToolchains: [String]
    public let paths: RuntimeContractPaths
    public let exitCodes: RuntimeContractExitCodes

    public init(
        cliCommands: [String],
        mcpTools: [String],
        docSyncCommands: [String],
        evidenceKeys: [String],
        doctorCapabilities: [String],
        doctorToolchains: [String],
        paths: RuntimeContractPaths,
        exitCodes: RuntimeContractExitCodes
    ) {
        self.cliCommands = cliCommands
        self.mcpTools = mcpTools
        self.docSyncCommands = docSyncCommands
        self.evidenceKeys = evidenceKeys
        self.doctorCapabilities = doctorCapabilities
        self.doctorToolchains = doctorToolchains
        self.paths = paths
        self.exitCodes = exitCodes
    }
}

public struct RuntimeContractPaths: Codable, Sendable, Equatable {
    public let governanceFragmentSpec: String
    public let docSyncManifest: String
    public let runtimeContractView: String
    public let governanceContractView: String

    public init(
        governanceFragmentSpec: String,
        docSyncManifest: String,
        runtimeContractView: String,
        governanceContractView: String
    ) {
        self.governanceFragmentSpec = governanceFragmentSpec
        self.docSyncManifest = docSyncManifest
        self.runtimeContractView = runtimeContractView
        self.governanceContractView = governanceContractView
    }
}

public struct RuntimeContractExitCodes: Codable, Sendable, Equatable {
    public let operational: Int
    public let validationFailure: Int
    public let bundleFailure: Int
    public let auditFailure: Int

    public init(operational: Int, validationFailure: Int, bundleFailure: Int, auditFailure: Int) {
        self.operational = operational
        self.validationFailure = validationFailure
        self.bundleFailure = bundleFailure
        self.auditFailure = auditFailure
    }
}

public enum RuntimeContractError: Error, LocalizedError {
    case missingField(String)
    case invalidFormat(String)

    public var errorDescription: String? {
        switch self {
        case .missingField(let field):
            return "Missing runtime contract field: \(field)"
        case .invalidFormat(let message):
            return message
        }
    }
}

public struct RuntimeContractLoader: Sendable {
    public init() {}

    public func load(from url: URL) throws -> RuntimeContracts {
        let text = try String(contentsOf: url)

        return RuntimeContracts(
            cliCommands: try stringArray(named: "cliCommands", in: text),
            mcpTools: try stringArray(named: "mcpTools", in: text),
            docSyncCommands: try stringArray(named: "docSyncCommands", in: text),
            evidenceKeys: try stringArray(named: "evidenceKeys", in: text),
            doctorCapabilities: try stringArray(named: "doctorCapabilities", in: text),
            doctorToolchains: try stringArray(named: "doctorToolchains", in: text),
            paths: RuntimeContractPaths(
                governanceFragmentSpec: try stringValue(named: "governanceFragmentSpec", inObjectNamed: "paths", from: text),
                docSyncManifest: try stringValue(named: "docSyncManifest", inObjectNamed: "paths", from: text),
                runtimeContractView: try stringValue(named: "runtimeContractView", inObjectNamed: "paths", from: text),
                governanceContractView: try stringValue(named: "governanceContractView", inObjectNamed: "paths", from: text)
            ),
            exitCodes: RuntimeContractExitCodes(
                operational: try intValue(named: "operational", inObjectNamed: "exitCodes", from: text),
                validationFailure: try intValue(named: "validationFailure", inObjectNamed: "exitCodes", from: text),
                bundleFailure: try intValue(named: "bundleFailure", inObjectNamed: "exitCodes", from: text),
                auditFailure: try intValue(named: "auditFailure", inObjectNamed: "exitCodes", from: text)
            )
        )
    }

    private func stringArray(named field: String, in text: String) throws -> [String] {
        let block = try block(named: field, open: "[", close: "]", in: text)
        let matches = block.matches(of: /"([^"]+)"/)
        let values = matches.map { String($0.1) }
        guard !values.isEmpty else {
            throw RuntimeContractError.invalidFormat("Runtime contract array '\(field)' is empty or malformed")
        }
        return values
    }

    private func stringValue(named field: String, inObjectNamed objectName: String, from text: String) throws -> String {
        let object = try block(named: objectName, open: "{", close: "}", in: text)
        let pattern = "\(NSRegularExpression.escapedPattern(for: field)):\\s*\"([^\"]+)\""
        guard let value = firstCapture(in: object, pattern: pattern) else {
            throw RuntimeContractError.missingField("\(objectName).\(field)")
        }
        return value
    }

    private func intValue(named field: String, inObjectNamed objectName: String, from text: String) throws -> Int {
        let object = try block(named: objectName, open: "{", close: "}", in: text)
        let pattern = "\(NSRegularExpression.escapedPattern(for: field)):\\s*([0-9]+)"
        guard let capture = firstCapture(in: object, pattern: pattern) else {
            throw RuntimeContractError.missingField("\(objectName).\(field)")
        }
        guard let value = Int(capture) else {
            throw RuntimeContractError.invalidFormat("Runtime contract integer '\(objectName).\(field)' is malformed")
        }
        return value
    }

    private func block(named field: String, open: Character, close: Character, in text: String) throws -> String {
        guard let fieldRange = text.range(of: "\(field):") else {
            throw RuntimeContractError.missingField(field)
        }

        var cursor = fieldRange.upperBound
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }

        guard cursor < text.endIndex, text[cursor] == open else {
            throw RuntimeContractError.invalidFormat("Runtime contract field '\(field)' is not a \(open)...\(close) block")
        }

        let start = cursor
        var depth = 0
        while cursor < text.endIndex {
            let character = text[cursor]
            if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
                if depth == 0 {
                    return String(text[start...cursor])
                }
            }
            cursor = text.index(after: cursor)
        }

        throw RuntimeContractError.invalidFormat("Runtime contract field '\(field)' is missing closing \(close)")
    }

    private func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }
        guard let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}
