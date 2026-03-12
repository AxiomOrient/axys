import Foundation

struct NativeManifest: Codable {
    let appId: String
    let flowId: String
    let screenId: String
    let platform: Platform
    let motionPatterns: [String]
    let generatedFiles: [String]
    let sourcePaths: [String: String]
}

struct NativeRenderer {
    init() {}

    func render(
        context: ScreenContext,
        tokens: TokenStore,
        platform: Platform,
        outputDirectory: URL
    ) throws -> GenerateNativeReport {
        guard platform == .ios || platform == .android else {
            throw ProjectError.invalidArgument("generate-native only supports --platform ios|android")
        }

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let screenFileName = screenTypeName(from: context.screenSpec.screenId) + (platform == .ios ? ".swift" : ".kt")
        let tokensFileName = platform == .ios ? "DesignTokens.swift" : "DesignTokens.kt"
        let screenURL = outputDirectory.appendingPathComponent(screenFileName)
        let tokensURL = outputDirectory.appendingPathComponent(tokensFileName)
        let manifestURL = outputDirectory.appendingPathComponent("manifest.native.json")

        switch platform {
        case .ios:
            try write(renderSwiftTokens(tokens), to: tokensURL)
            try write(renderSwiftScreen(context: context), to: screenURL)
        case .android:
            try write(renderComposeTokens(tokens), to: tokensURL)
            try write(renderComposeScreen(context: context), to: screenURL)
        case .html:
            break
        }

        let artifacts: [GeneratedArtifact] = [
            .init(kind: "\(platform.rawValue)_screen", path: screenURL.path),
            .init(kind: "\(platform.rawValue)_tokens", path: tokensURL.path),
            .init(kind: "native_manifest", path: manifestURL.path),
        ]

        let manifest = NativeManifest(
            appId: context.appSpec.appId,
            flowId: context.flowSpec.flowId,
            screenId: context.screenSpec.screenId,
            platform: platform,
            motionPatterns: context.screenSpec.motion.map(\.patternId),
            generatedFiles: artifacts.map(\.path).sorted(),
            sourcePaths: [
                "app": context.appURL.path,
                "flow": context.flowURL.path,
                "screen": context.screenURL.path,
                "registry": context.registryURL.path,
                "motion": context.motionURL.path,
                "review": context.reviewURL.path,
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: manifestURL)

        return GenerateNativeReport(
            ok: true,
            platform: platform,
            screenId: context.screenSpec.screenId,
            outputDirectory: outputDirectory.path,
            artifacts: artifacts,
            manifestPath: manifestURL.path
        )
    }

    private func write(_ text: String, to url: URL) throws {
        guard let data = text.data(using: .utf8) else {
            throw ProjectError.io("Unable to encode text at \(url.path)")
        }
        try data.write(to: url)
    }

    private func renderSwiftTokens(_ tokens: TokenStore) -> String {
        let lines = tokens.tokens.map { token -> String in
            let identifier = tokenIdentifier(for: token.path)
            switch token.type {
            case "dimension":
                return "    static let \(identifier): CGFloat = \(token.value)"
            case "color":
                return "    static let \(identifier): Color = \(swiftColorLiteral(token.value))"
            default:
                return "    static let \(identifier): String = \"\(escapeSwift(token.value))\""
            }
        }

        return """
        import SwiftUI

        enum DesignTokens {
        \(lines.joined(separator: "\n"))
        }
        """
    }

    private func renderComposeTokens(_ tokens: TokenStore) -> String {
        let lines = tokens.tokens.map { token -> String in
            let identifier = tokenIdentifier(for: token.path)
            switch token.type {
            case "dimension":
                return "    val \(identifier) = \(token.value).dp"
            case "color":
                return "    val \(identifier) = \(composeColorLiteral(token.value))"
            default:
                return "    const val \(identifier): String = \"\(escapeKotlin(token.value))\""
            }
        }

        return """
        import androidx.compose.ui.graphics.Color
        import androidx.compose.ui.unit.dp

        object DesignTokens {
        \(lines.joined(separator: "\n"))
        }
        """
    }

    private func renderSwiftScreen(context: ScreenContext) -> String {
        let screen = context.screenSpec
        let screenName = screenTypeName(from: screen.screenId)
        let stateName = "\(screenName)State"
        let actionsName = "\(screenName)Actions"
        let navigationName = "\(screenName)Navigation"
        let body = renderSwiftNode(screen.layout, context: context, indent: 3)

        return """
        import SwiftUI

        // Motion intent: \(motionComment(for: screen))
        struct \(stateName) {
        \(renderSwiftStateFields(screen.stateFields))
        }

        struct \(actionsName) {
        \(renderSwiftActions(screen))
        }

        struct \(navigationName) {
        \(renderSwiftNavigation(screen.navigation))
        }

        struct \(screenName): View {
            let state: \(stateName)
            let actions: \(actionsName)
            let navigation: \(navigationName)

            var body: some View {
                ScrollView {
                    VStack(alignment: .leading, spacing: \(swiftSpacingReference(screen.surface.padding))) {
        \(body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(\(swiftSpacingReference(screen.surface.padding)))
                }
                .background(\(swiftColorReference(screen.surface.backgroundColor)).ignoresSafeArea())
            }
        }

        \(renderSwiftPreviewBlocks(screen: screen, screenName: screenName, stateName: stateName, actionsName: actionsName, navigationName: navigationName))
        """
    }

    private func renderComposeScreen(context: ScreenContext) -> String {
        let screen = context.screenSpec
        let screenName = screenTypeName(from: screen.screenId)
        let stateName = "\(screenName)State"
        let actionsName = "\(screenName)Actions"
        let navigationName = "\(screenName)Navigation"
        let body = renderComposeNode(screen.layout, context: context, indent: 2)

        return """
        import androidx.compose.foundation.background
        import androidx.compose.foundation.layout.*
        import androidx.compose.foundation.rememberScrollState
        import androidx.compose.foundation.verticalScroll
        import androidx.compose.runtime.Composable
        import androidx.compose.ui.Modifier
        import androidx.compose.ui.graphics.Color
        import androidx.compose.ui.tooling.preview.Preview

        // Motion intent: \(motionComment(for: screen))
        data class \(stateName)(
        \(renderComposeStateFields(screen.stateFields))
        )

        data class \(actionsName)(
        \(renderComposeActions(screen))
        )

        data class \(navigationName)(
        \(renderComposeNavigation(screen.navigation))
        )

        @Composable
        fun \(screenName)(
            state: \(stateName) = \(stateName)(),
            actions: \(actionsName) = \(actionsName)(),
            navigation: \(navigationName) = \(navigationName)()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(\(composeColorReference(screen.surface.backgroundColor)))
                    .verticalScroll(rememberScrollState())
                    .padding(\(composeSpacingReference(screen.surface.padding))),
                verticalArrangement = Arrangement.spacedBy(\(composeSpacingReference(screen.surface.padding)))
            ) {
        \(body)
            }
        }

        \(renderComposePreviewBlocks(screen: screen, screenName: screenName, stateName: stateName, actionsName: actionsName, navigationName: navigationName))
        """
    }

    private func renderSwiftStateFields(_ fields: [StateField]) -> String {
        if fields.isEmpty {
            return "    init() {}"
        }

        return fields.map { field in
            "    var \(swiftSafeIdentifier(memberName(from: field.id))): \(swiftTypeName(for: field.type)) = \(swiftLiteral(for: field))"
        }.joined(separator: "\n")
    }

    private func renderComposeStateFields(_ fields: [StateField]) -> String {
        if fields.isEmpty {
            return "    val unused: Unit = Unit"
        }

        return fields.enumerated().map { index, field in
            let suffix = index == fields.count - 1 ? "" : ","
            return "    val \(kotlinSafeIdentifier(memberName(from: field.id))): \(kotlinTypeName(for: field.type)) = \(kotlinLiteral(for: field))\(suffix)"
        }.joined(separator: "\n")
    }

    private func renderSwiftActions(_ screen: ScreenSpec) -> String {
        let fields = actionHandlerNames(screen: screen)
        if fields.isEmpty {
            return "    init() {}"
        }
        return fields.map { "    var \(swiftSafeIdentifier($0)): () -> Void = {}" }.joined(separator: "\n")
    }

    private func renderComposeActions(_ screen: ScreenSpec) -> String {
        let fields = actionHandlerNames(screen: screen)
        if fields.isEmpty {
            return "    val unused: Unit = Unit"
        }

        return fields.enumerated().map { index, field in
            let suffix = index == fields.count - 1 ? "" : ","
            return "    val \(kotlinSafeIdentifier(field)): () -> Unit = {}\(suffix)"
        }.joined(separator: "\n")
    }

    private func renderSwiftNavigation(_ navigation: [Navigation]) -> String {
        if navigation.isEmpty {
            return "    init() {}"
        }
        return navigation.map { "    var \(swiftSafeIdentifier(memberName(from: $0.id))): () -> Void = {}" }.joined(separator: "\n")
    }

    private func renderComposeNavigation(_ navigation: [Navigation]) -> String {
        if navigation.isEmpty {
            return "    val unused: Unit = Unit"
        }

        return navigation.enumerated().map { index, item in
            let suffix = index == navigation.count - 1 ? "" : ","
            return "    val \(kotlinSafeIdentifier(memberName(from: item.id))): () -> Unit = {}\(suffix)"
        }.joined(separator: "\n")
    }

    private func renderSwiftNode(_ node: LayoutNode, context: ScreenContext, indent: Int) -> String {
        let prefix = String(repeating: "    ", count: indent)
        switch node.kind {
        case "stack", "slot", "conditional", "repeat", "grid":
            let children = node.children.map { renderSwiftNode($0, context: context, indent: indent + 1) }.joined(separator: "\n")
            return """
        \(prefix)\(layoutComment(for: node))
        \(prefix)VStack(alignment: .leading, spacing: \(swiftSpacingReference(node.spacing))) {
        \(children)
        \(prefix)}
        """
        case "component":
            return renderSwiftComponent(node, context: context, indent: indent)
        default:
            return "\(prefix)Text(\"Unsupported layout: \(escapeSwift(node.kind))\")"
        }
    }

    private func renderComposeNode(_ node: LayoutNode, context: ScreenContext, indent: Int) -> String {
        let prefix = String(repeating: "    ", count: indent)
        switch node.kind {
        case "stack", "slot", "conditional", "repeat", "grid":
            let children = node.children.map { renderComposeNode($0, context: context, indent: indent + 1) }.joined(separator: "\n")
            return """
        \(prefix)\(layoutComment(for: node))
        \(prefix)Column(verticalArrangement = Arrangement.spacedBy(\(composeSpacingReference(node.spacing)))) {
        \(children)
        \(prefix)}
        """
        case "component":
            return renderComposeComponent(node, context: context, indent: indent)
        default:
            return "\(prefix)androidx.compose.material3.Text(text = \"Unsupported layout: \(escapeKotlin(node.kind))\")"
        }
    }

    private func renderSwiftComponent(_ node: LayoutNode, context: ScreenContext, indent: Int) -> String {
        let prefix = String(repeating: "    ", count: indent)
        guard let item = registryItem(for: node, in: context) else {
            return "\(prefix)Text(\"Unknown component\")"
        }

        let arguments = swiftComponentArguments(node: node, item: item, screen: context.screenSpec)
        if arguments.isEmpty {
            return "\(prefix)\(item.native.ios.component)()"
        }

        return """
        \(prefix)\(item.native.ios.component)(
        \(indentArguments(arguments.joined(separator: ",\n"), level: indent + 1))
        \(prefix))
        """
    }

    private func renderComposeComponent(_ node: LayoutNode, context: ScreenContext, indent: Int) -> String {
        let prefix = String(repeating: "    ", count: indent)
        guard let item = registryItem(for: node, in: context) else {
            return "\(prefix)androidx.compose.material3.Text(text = \"Unknown component\")"
        }

        let arguments = composeComponentArguments(node: node, item: item, screen: context.screenSpec)
        if arguments.isEmpty {
            return "\(prefix)\(item.native.android.component)()"
        }

        return """
        \(prefix)\(item.native.android.component)(
        \(indentArguments(arguments.joined(separator: ",\n"), level: indent + 1))
        \(prefix))
        """
    }

    private func swiftComponentArguments(node: LayoutNode, item: RegistryItem, screen: ScreenSpec) -> [String] {
        componentArguments(node: node, propMapping: item.native.ios.props, screen: screen, swiftEscaped: true).map { key, value in
            "\(key): \(value)"
        }
    }

    private func composeComponentArguments(node: LayoutNode, item: RegistryItem, screen: ScreenSpec) -> [String] {
        componentArguments(node: node, propMapping: item.native.android.props, screen: screen, swiftEscaped: false).map { key, value in
            "\(key) = \(value)"
        }
    }

    private func componentArguments(node: LayoutNode, propMapping: [String: String], screen: ScreenSpec, swiftEscaped: Bool) -> [(String, String)] {
        var result: [(String, String)] = []

        for key in propMapping.keys.sorted() {
            guard let sourceValue = node.props[key]?.stringValue else { continue }
            result.append((propMapping[key] ?? key, quotedLiteral(sourceValue)))
        }

        for binding in node.bindings {
            let fieldName = escapedReferenceName(binding.field, swiftEscaped: swiftEscaped)
            result.append((fieldName, "state.\(fieldName)"))
            result.append(("on\(pascalCase(from: binding.field))Changed", "actions.\(escapedReferenceName(changeHandlerName(for: binding.field), swiftEscaped: swiftEscaped))"))

            if let action = binding.action {
                result.append(("on\(pascalCase(from: action))", "actions.\(escapedReferenceName(action, swiftEscaped: swiftEscaped))"))
            }
            if let navigation = binding.navigation {
                result.append(("on\(pascalCase(from: navigation))", "navigation.\(escapedReferenceName(navigation, swiftEscaped: swiftEscaped))"))
            }
        }

        if let primaryAction = inferredPrimaryAction(for: node, screen: screen) {
            result.append(("onTap", "actions.\(escapedReferenceName(primaryAction, swiftEscaped: swiftEscaped))"))
        } else if let primaryNavigation = inferredPrimaryNavigation(for: node, screen: screen) {
            result.append(("onTap", "navigation.\(escapedReferenceName(primaryNavigation, swiftEscaped: swiftEscaped))"))
        }

        return deduplicated(result)
    }

    private func inferredPrimaryAction(for node: LayoutNode, screen: ScreenSpec) -> String? {
        if let explicit = node.bindings.compactMap(\.action).first {
            return explicit
        }
        if node.componentId == "button", screen.actions.count == 1 {
            return screen.actions[0].id
        }
        return nil
    }

    private func inferredPrimaryNavigation(for node: LayoutNode, screen: ScreenSpec) -> String? {
        if let explicit = node.bindings.compactMap(\.navigation).first {
            return explicit
        }
        if node.componentId == "button", screen.actions.isEmpty, screen.navigation.count == 1 {
            return screen.navigation[0].id
        }
        return nil
    }

    private func deduplicated(_ pairs: [(String, String)]) -> [(String, String)] {
        var seen: Set<String> = []
        var result: [(String, String)] = []

        for pair in pairs where seen.insert(pair.0).inserted {
            result.append(pair)
        }

        return result
    }

    private func renderSwiftPreviewBlocks(screen: ScreenSpec, screenName: String, stateName: String, actionsName: String, navigationName: String) -> String {
        resolvedPreviewStates(for: screen).map { preview in
            """
            #Preview("\(escapeSwift(preview.id))") {
                \(screenName)(
                    state: \(swiftPreviewStateLiteral(preview, screen: screen, stateName: stateName)),
                    actions: \(actionsName)(),
                    navigation: \(navigationName)()
                )
            }
            """
        }.joined(separator: "\n\n")
    }

    private func renderComposePreviewBlocks(screen: ScreenSpec, screenName: String, stateName: String, actionsName: String, navigationName: String) -> String {
        resolvedPreviewStates(for: screen).map { preview in
            let previewName = "\(screenName)\(pascalCase(from: preview.id))Preview"
            return """
            @Preview(name = "\(escapeKotlin(preview.id))")
            @Composable
            private fun \(previewName)() {
                \(screenName)(
                    state = \(kotlinPreviewStateLiteral(preview, screen: screen, stateName: stateName)),
                    actions = \(actionsName)(),
                    navigation = \(navigationName)()
                )
            }
            """
        }.joined(separator: "\n\n")
    }

    private func actionHandlerNames(screen: ScreenSpec) -> [String] {
        var names = screen.actions.map { memberName(from: $0.id) }
        names.append(contentsOf: collectBindings(in: screen.layout).map { changeHandlerName(for: $0.field) })
        return deduplicateStrings(names)
    }

    private func collectBindings(in node: LayoutNode) -> [LayoutBinding] {
        node.bindings + node.children.flatMap(collectBindings)
    }

    private func resolvedPreviewStates(for screen: ScreenSpec) -> [PreviewState] {
        screen.previewStates.isEmpty ? [PreviewState(id: "default")] : screen.previewStates
    }

    private func swiftPreviewStateLiteral(_ preview: PreviewState, screen: ScreenSpec, stateName: String) -> String {
        if screen.stateFields.isEmpty {
            return "\(stateName)()"
        }

        let assignments = screen.stateFields.enumerated().map { index, field -> String in
            let value = preview.values[field.id] ?? field.defaultValue ?? defaultValue(for: field.type)
            let suffix = index == screen.stateFields.count - 1 ? "" : ","
            return "    \(swiftSafeIdentifier(memberName(from: field.id))): \(swiftLiteral(for: field.type, value: value))\(suffix)"
        }.joined(separator: "\n")

        return """
        \(stateName)(
        \(assignments)
        )
        """
    }

    private func kotlinPreviewStateLiteral(_ preview: PreviewState, screen: ScreenSpec, stateName: String) -> String {
        if screen.stateFields.isEmpty {
            return "\(stateName)()"
        }

        let assignments = screen.stateFields.enumerated().map { index, field -> String in
            let value = preview.values[field.id] ?? field.defaultValue ?? defaultValue(for: field.type)
            let suffix = index == screen.stateFields.count - 1 ? "" : ","
            return "        \(memberName(from: field.id)) = \(kotlinLiteral(for: field.type, value: value))\(suffix)"
        }.joined(separator: "\n")

        return """
        \(stateName)(
        \(assignments)
        )
        """
    }

    private func registryItem(for node: LayoutNode, in context: ScreenContext) -> RegistryItem? {
        guard let componentId = node.componentId else { return nil }
        return context.registry.items.first { $0.id == componentId }
    }

    private func layoutComment(for node: LayoutNode) -> String {
        switch node.kind {
        case "slot":
            return "// slot \(node.slot ?? "unnamed")"
        case "conditional":
            return "// conditional \(node.stateGuard ?? "unspecified")"
        case "repeat":
            return "// repeat \(node.repeatSource ?? "items")"
        case "grid":
            return "// grid columns: \(node.columns ?? 1)"
        default:
            return "// \(node.kind)"
        }
    }

    private func motionComment(for screen: ScreenSpec) -> String {
        if screen.motion.isEmpty {
            return "none"
        }
        return screen.motion.map { "\($0.patternId) via \($0.trigger)" }.joined(separator: ", ")
    }

    private func screenTypeName(from screenID: String) -> String {
        pascalCase(from: screenID) + "Screen"
    }

    private func escapedReferenceName(_ raw: String, swiftEscaped: Bool) -> String {
        let name = memberName(from: raw)
        return swiftEscaped ? swiftSafeIdentifier(name) : kotlinSafeIdentifier(name)
    }

    private func swiftSafeIdentifier(_ value: String) -> String {
        let keywords: Set<String> = [
            "associatedtype", "class", "continue", "deinit", "enum", "extension", "fileprivate", "for",
            "func", "if", "import", "init", "inout", "internal", "let", "operator", "private", "protocol",
            "public", "repeat", "return", "static", "struct", "subscript", "typealias", "var", "where", "while"
        ]
        if keywords.contains(value) {
            return "`\(value)`"
        }
        return value
    }

    private func kotlinSafeIdentifier(_ value: String) -> String {
        let keywords: Set<String> = [
            "as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if", "in", "interface",
            "is", "null", "object", "package", "return", "super", "this", "throw", "true", "try", "typealias",
            "val", "var", "when", "while"
        ]
        if keywords.contains(value) {
            return "`\(value)`"
        }
        return value
    }

    private func memberName(from raw: String) -> String {
        let parts = identifierParts(from: raw)
        guard let first = parts.first else { return "value" }
        return first.lowercased() + parts.dropFirst().map(capitalized).joined()
    }

    private func changeHandlerName(for field: String) -> String {
        "on\(pascalCase(from: field))Changed"
    }

    private func pascalCase(from raw: String) -> String {
        let parts = identifierParts(from: raw)
        guard !parts.isEmpty else { return "Value" }
        return parts.map(capitalized).joined()
    }

    private func identifierParts(from raw: String) -> [String] {
        var parts: [String] = []
        var current = ""

        for character in raw {
            if !character.isLetter && !character.isNumber {
                if !current.isEmpty {
                    parts.append(current)
                    current = ""
                }
                continue
            }

            if let last = current.last, last.isLowercase, character.isUppercase {
                parts.append(current)
                current = String(character)
                continue
            }

            current.append(character)
        }

        if !current.isEmpty {
            parts.append(current)
        }

        return parts
    }

    private func capitalized(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }

    private func tokenIdentifier(for path: String) -> String {
        let parts = path.split(separator: ".").map(String.init)
        guard let first = parts.first else { return "value" }
        return first + parts.dropFirst().map(capitalized).joined()
    }

    private func swiftTypeName(for type: String) -> String {
        switch type {
        case "boolean": return "Bool"
        case "integer": return "Int"
        case "number": return "Double"
        default: return "String"
        }
    }

    private func kotlinTypeName(for type: String) -> String {
        switch type {
        case "boolean": return "Boolean"
        case "integer": return "Int"
        case "number": return "Double"
        default: return "String"
        }
    }

    private func swiftLiteral(for field: StateField) -> String {
        swiftLiteral(for: field.type, value: field.defaultValue ?? defaultValue(for: field.type))
    }

    private func kotlinLiteral(for field: StateField) -> String {
        kotlinLiteral(for: field.type, value: field.defaultValue ?? defaultValue(for: field.type))
    }

    private func defaultValue(for type: String) -> JSONValue {
        switch type {
        case "boolean": return .bool(false)
        case "integer": return .integer(0)
        case "number": return .double(0)
        default: return .string("")
        }
    }

    private func swiftLiteral(for type: String, value: JSONValue) -> String {
        switch (type, value) {
        case ("string", .string(let text)):
            return quotedLiteral(text)
        case ("boolean", .bool(let flag)):
            return flag ? "true" : "false"
        case ("integer", .integer(let number)):
            return String(number)
        case ("integer", .double(let number)):
            return String(Int(number))
        case ("number", .double(let number)):
            return number.rounded() == number ? "\(Int(number)).0" : String(number)
        case ("number", .integer(let number)):
            return "\(number).0"
        default:
            return value.stringValue.map(quotedLiteral) ?? quotedLiteral("")
        }
    }

    private func kotlinLiteral(for type: String, value: JSONValue) -> String {
        switch (type, value) {
        case ("string", .string(let text)):
            return quotedLiteral(text)
        case ("boolean", .bool(let flag)):
            return flag ? "true" : "false"
        case ("integer", .integer(let number)):
            return String(number)
        case ("integer", .double(let number)):
            return String(Int(number))
        case ("number", .double(let number)):
            return number.rounded() == number ? "\(Int(number)).0" : String(number)
        case ("number", .integer(let number)):
            return "\(number).0"
        default:
            return value.stringValue.map(quotedLiteral) ?? quotedLiteral("")
        }
    }

    private func swiftSpacingReference(_ alias: String?) -> String {
        guard let alias, let path = TokenStore.path(fromAlias: alias) else {
            return "0"
        }
        return "DesignTokens.\(tokenIdentifier(for: path))"
    }

    private func composeSpacingReference(_ alias: String?) -> String {
        guard let alias, let path = TokenStore.path(fromAlias: alias) else {
            return "0.dp"
        }
        return "DesignTokens.\(tokenIdentifier(for: path))"
    }

    private func swiftColorReference(_ alias: String) -> String {
        if let path = TokenStore.path(fromAlias: alias) {
            return "DesignTokens.\(tokenIdentifier(for: path))"
        }
        return swiftColorLiteral(alias)
    }

    private func composeColorReference(_ alias: String) -> String {
        if let path = TokenStore.path(fromAlias: alias) {
            return "DesignTokens.\(tokenIdentifier(for: path))"
        }
        return composeColorLiteral(alias)
    }

    private func swiftColorLiteral(_ raw: String) -> String {
        let parts = hexColorComponents(from: raw) ?? (red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        return "Color(.sRGB, red: \(parts.red), green: \(parts.green), blue: \(parts.blue), opacity: \(parts.alpha))"
    }

    private func composeColorLiteral(_ raw: String) -> String {
        "Color(0x\(composeARGBHex(from: raw)))"
    }

    private func composeARGBHex(from raw: String) -> String {
        let parts = hexColorComponents(from: raw) ?? (red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let a = Int(round(parts.alpha * 255.0))
        let r = Int(round(parts.red * 255.0))
        let g = Int(round(parts.green * 255.0))
        let b = Int(round(parts.blue * 255.0))
        return String(format: "%02X%02X%02X%02X", a, r, g, b)
    }

    private func hexColorComponents(from raw: String) -> (red: Double, green: Double, blue: Double, alpha: Double)? {
        var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.hasPrefix("#") else { return nil }
        hex.removeFirst()

        switch hex.count {
        case 6:
            guard let value = Int(hex, radix: 16) else { return nil }
            return (
                red: Double((value >> 16) & 0xFF) / 255.0,
                green: Double((value >> 8) & 0xFF) / 255.0,
                blue: Double(value & 0xFF) / 255.0,
                alpha: 1.0
            )
        case 8:
            guard let value = Int(hex, radix: 16) else { return nil }
            return (
                red: Double((value >> 24) & 0xFF) / 255.0,
                green: Double((value >> 16) & 0xFF) / 255.0,
                blue: Double((value >> 8) & 0xFF) / 255.0,
                alpha: Double(value & 0xFF) / 255.0
            )
        default:
            return nil
        }
    }

    private func deduplicateStrings(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for value in values where seen.insert(value).inserted {
            result.append(value)
        }

        return result
    }

    private func indentArguments(_ text: String, level: Int) -> String {
        let prefix = String(repeating: "    ", count: level)
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { prefix + $0 }
            .joined(separator: "\n")
    }

    private func quotedLiteral(_ value: String) -> String {
        "\"\(escapeSwift(value))\""
    }

    private func escapeSwift(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func escapeKotlin(_ value: String) -> String {
        escapeSwift(value)
    }
}
