import Foundation

public struct TokenCompiler {
    public init() {}

    public func compile(tokenFiles: [URL]) throws -> TokenStore {
        var rawTokens: [String: RawToken] = [:]

        for url in tokenFiles.sorted(by: { $0.path < $1.path }) {
            let data = try Data(contentsOf: url)
            let value = try JSONDecoder().decode(JSONValue.self, from: data)
            guard let object = value.objectValue else {
                throw ProjectError.io("Token file must contain a JSON object: \(url.path)")
            }
            collectTokens(from: object, inheritedType: nil, path: [], sourceFile: url.lastPathComponent, rawTokens: &rawTokens)
        }

        var resolved: [String: ResolvedToken] = [:]
        for path in rawTokens.keys.sorted() {
            _ = try resolve(path: path, rawTokens: rawTokens, resolved: &resolved, stack: [])
        }

        return TokenStore(tokens: resolved.values.sorted { $0.path < $1.path })
    }

    private func collectTokens(
        from object: [String: JSONValue],
        inheritedType: String?,
        path: [String],
        sourceFile: String,
        rawTokens: inout [String: RawToken]
    ) {
        let currentType = object["$type"]?.stringValue ?? inheritedType

        if let rawValue = object["$value"] {
            let tokenPath = path.joined(separator: ".")
            rawTokens[tokenPath] = RawToken(path: tokenPath, type: currentType, rawValue: rawValue, sourceFile: sourceFile)
            return
        }

        for key in object.keys.sorted() where !key.hasPrefix("$") {
            guard let childObject = object[key]?.objectValue else {
                continue
            }
            collectTokens(
                from: childObject,
                inheritedType: currentType,
                path: path + [key],
                sourceFile: sourceFile,
                rawTokens: &rawTokens
            )
        }
    }

    private func resolve(
        path: String,
        rawTokens: [String: RawToken],
        resolved: inout [String: ResolvedToken],
        stack: [String]
    ) throws -> ResolvedToken {
        if let token = resolved[path] {
            return token
        }

        guard !stack.contains(path) else {
            throw ProjectError.invalidArgument("Token alias cycle detected: \((stack + [path]).joined(separator: " -> "))")
        }

        guard let rawToken = rawTokens[path] else {
            throw ProjectError.invalidArgument("Unknown token reference: \(path)")
        }

        let nextStack = stack + [path]

        if let alias = rawToken.rawValue.stringValue, let aliasPath = TokenStore.path(fromAlias: alias) {
            let resolvedAlias = try resolve(path: aliasPath, rawTokens: rawTokens, resolved: &resolved, stack: nextStack)
            let token = ResolvedToken(
                path: path,
                type: rawToken.type ?? resolvedAlias.type,
                value: resolvedAlias.value
            )
            resolved[path] = token
            return token
        }

        guard let literal = rawToken.rawValue.stringValue else {
            throw ProjectError.invalidArgument("Unsupported token literal at \(path) in \(rawToken.sourceFile)")
        }

        let token = ResolvedToken(path: path, type: rawToken.type ?? "string", value: literal)
        resolved[path] = token
        return token
    }
}

private struct RawToken {
    let path: String
    let type: String?
    let rawValue: JSONValue
    let sourceFile: String
}
