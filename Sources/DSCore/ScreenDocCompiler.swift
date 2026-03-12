import Foundation

public struct ScreenDoc: Sendable {
    public let screenId: String
    public let title: String
    public let route: String?
    public let platforms: [Platform]
    public let intent: String?
    public let constraints: [String]
    public let states: [String]
    public let stateFields: [ScreenStateField]
    public let actions: [ScreenAction]
    public let assets: [ScreenAsset]
    public let previewStates: [ScreenPreviewState]
    public let navigation: [ScreenNavigationDestination]
    public let components: [String]
    public let componentDetails: [String: ScreenDocComponentDetail]
    public let body: String

    public init(
        screenId: String,
        title: String,
        route: String?,
        platforms: [Platform],
        intent: String?,
        constraints: [String],
        states: [String],
        stateFields: [ScreenStateField] = [],
        actions: [ScreenAction] = [],
        assets: [ScreenAsset] = [],
        previewStates: [ScreenPreviewState] = [],
        navigation: [ScreenNavigationDestination] = [],
        components: [String],
        componentDetails: [String: ScreenDocComponentDetail] = [:],
        body: String
    ) {
        self.screenId = screenId
        self.title = title
        self.route = route
        self.platforms = platforms
        self.intent = intent
        self.constraints = constraints
        self.states = states
        self.stateFields = stateFields
        self.actions = actions
        self.assets = assets
        self.previewStates = previewStates
        self.navigation = navigation
        self.components = components
        self.componentDetails = componentDetails
        self.body = body
    }
}

public struct ScreenDocComponentDetail: Sendable, Equatable {
    public let component: String
    public let attributes: [String: String]

    public init(component: String, attributes: [String: String]) {
        self.component = component
        self.attributes = attributes
    }

    public func value(for key: String) -> String? {
        attributes[key]
    }
}

public struct CompileScreenDocReport: Codable, Sendable, Equatable {
    public let ok: Bool
    public let screenId: String
    public let inputPath: String
    public let outputPath: String
    public let reportPath: String
    public let completionStatus: CompileScreenDocCompletionStatus
    public let warnings: [String]
    public let unresolvedItems: [CompileScreenDocIssue]

    public init(
        ok: Bool,
        screenId: String,
        inputPath: String,
        outputPath: String,
        reportPath: String,
        completionStatus: CompileScreenDocCompletionStatus,
        warnings: [String],
        unresolvedItems: [CompileScreenDocIssue]
    ) {
        self.ok = ok
        self.screenId = screenId
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.reportPath = reportPath
        self.completionStatus = completionStatus
        self.warnings = warnings.sorted()
        self.unresolvedItems = unresolvedItems.sorted { ($0.path, $0.code, $0.message) < ($1.path, $1.code, $1.message) }
    }

    private enum CodingKeys: String, CodingKey {
        case ok
        case screenId = "screen_id"
        case inputPath = "input_path"
        case outputPath = "output_path"
        case reportPath = "report_path"
        case completionStatus = "completion_status"
        case warnings
        case unresolvedItems = "unresolved_items"
    }
}

public enum CompileScreenDocCompletionStatus: String, Codable, Sendable {
    case starter
    case complete
}

public struct CompileScreenDocIssue: Codable, Sendable, Equatable {
    public let code: String
    public let path: String
    public let message: String

    public init(code: String, path: String, message: String) {
        self.code = code
        self.path = path
        self.message = message
    }
}

public struct CompiledScreenDoc: Sendable {
    public let screenDoc: ScreenDoc
    public let spec: ScreenSpec
    public let warnings: [String]
    public let unresolvedItems: [CompileScreenDocIssue]

    public init(screenDoc: ScreenDoc, spec: ScreenSpec, warnings: [String], unresolvedItems: [CompileScreenDocIssue]) {
        self.screenDoc = screenDoc
        self.spec = spec
        self.warnings = warnings.sorted()
        self.unresolvedItems = unresolvedItems.sorted { ($0.path, $0.code, $0.message) < ($1.path, $1.code, $1.message) }
    }
}

public struct ScreenDocCompiler {
    public init() {}

    public func load(_ url: URL) throws -> ScreenDoc {
        let text = try String(contentsOf: url)
        return try parse(text: text, source: url.lastPathComponent)
    }

    public func compile(documentURL: URL, defaultPlatforms: [Platform]? = nil) throws -> CompiledScreenDoc {
        try compile(load(documentURL), defaultPlatforms: defaultPlatforms)
    }

    public func compile(_ screenDoc: ScreenDoc, defaultPlatforms: [Platform]? = nil) throws -> CompiledScreenDoc {
        let result = compileComponents(screenDoc)
        let spec = ScreenSpec(
            schemaVersion: "1.0",
            screenId: screenDoc.screenId,
            title: screenDoc.title,
            route: screenDoc.route,
            intent: screenDoc.intent,
            constraints: screenDoc.constraints,
            states: screenDoc.states,
            stateFields: screenDoc.stateFields,
            actions: screenDoc.actions,
            assets: screenDoc.assets,
            previewStates: screenDoc.previewStates,
            navigation: screenDoc.navigation,
            platforms: resolvedPlatforms(screenDoc.platforms, defaultPlatforms: defaultPlatforms),
            surface: ScreenSurface(
                backgroundColor: "{color.surface.primary}",
                padding: "{space.6}"
            ),
            root: ScreenNode(
                kind: "vstack",
                spacing: "{space.4}",
                children: result.nodes
            )
        )
        return CompiledScreenDoc(
            screenDoc: screenDoc,
            spec: spec,
            warnings: result.warnings,
            unresolvedItems: result.unresolvedItems + previewStateCompletionIssues(for: screenDoc)
        )
    }

    private func parse(text: String, source: String) throws -> ScreenDoc {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") || normalized == "---" else {
            throw ProjectError.invalidArgument("screen-doc must start with front matter fence in \(source)")
        }

        let lines = normalized.components(separatedBy: "\n")
        guard let closingIndex = lines.dropFirst().firstIndex(of: "---") else {
            throw ProjectError.invalidArgument("screen-doc front matter fence is not closed in \(source)")
        }

        let frontMatterLines = Array(lines[1..<closingIndex])
        let body = lines.dropFirst(closingIndex + 1).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let frontMatter = try parseFrontMatter(lines: frontMatterLines, source: source)
        let parsedBody = try parseBody(body, source: source)

        let screenId = try requiredString(frontMatter["screenId"], key: "screenId", source: source)
        let title = try requiredString(frontMatter["title"], key: "title", source: source)
        let platforms = try parsePlatforms(frontMatter["platforms"], source: source)

        return ScreenDoc(
            screenId: screenId,
            title: title,
            route: frontMatter["route"]?.stringValue,
            platforms: platforms,
            intent: frontMatter["intent"]?.stringValue,
            constraints: frontMatter["constraints"]?.arrayValue ?? [],
            states: frontMatter["states"]?.arrayValue ?? [],
            stateFields: parsedBody.stateFields,
            actions: parsedBody.actions,
            assets: parsedBody.assets,
            previewStates: parsedBody.previewStates,
            navigation: parsedBody.navigation,
            components: frontMatter["components"]?.arrayValue ?? [],
            componentDetails: parsedBody.componentDetails,
            body: parsedBody.narrativeBody
        )
    }

    private func parseFrontMatter(lines: [String], source: String) throws -> [String: FrontMatterValue] {
        var values: [String: FrontMatterValue] = [:]
        var currentListKey: String?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                continue
            }

            if line.hasPrefix("- ") {
                guard let currentListKey else {
                    throw ProjectError.invalidArgument("Unexpected list item in screen-doc front matter: \(source)")
                }
                let item = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                let existing = values[currentListKey]?.arrayValue ?? []
                values[currentListKey] = .array(existing + [item])
                continue
            }

            guard let separator = line.firstIndex(of: ":") else {
                throw ProjectError.invalidArgument("Invalid front matter line in \(source): \(line)")
            }

            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let remainder = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)

            if remainder.isEmpty {
                currentListKey = key
                values[key] = .array([])
                continue
            }

            currentListKey = nil
            if remainder.hasPrefix("[") && remainder.hasSuffix("]") {
                let inner = remainder.dropFirst().dropLast()
                let items = inner
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                values[key] = .array(items)
            } else {
                values[key] = .string(remainder)
            }
        }

        return values
    }

    private func requiredString(_ value: FrontMatterValue?, key: String, source: String) throws -> String {
        guard let text = value?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw ProjectError.invalidArgument("Missing required front matter key '\(key)' in \(source)")
        }
        return text
    }

    private func parsePlatforms(_ value: FrontMatterValue?, source: String) throws -> [Platform] {
        let rawValues = value?.arrayValue ?? []
        return try rawValues.map { raw in
            guard let platform = Platform(rawValue: raw) else {
                throw ProjectError.invalidArgument("Unknown platform '\(raw)' in \(source)")
            }
            return platform
        }
    }

    private func resolvedPlatforms(_ platforms: [Platform], defaultPlatforms: [Platform]?) -> [Platform] {
        if !platforms.isEmpty {
            return platforms
        }
        if let defaultPlatforms, !defaultPlatforms.isEmpty {
            return defaultPlatforms
        }
        return Platform.allCases
    }

    private func compileComponents(_ screenDoc: ScreenDoc) -> (nodes: [ScreenNode], warnings: [String], unresolvedItems: [CompileScreenDocIssue]) {
        var nodes: [ScreenNode] = []
        var warnings: [String] = []
        var unresolvedItems: [CompileScreenDocIssue] = []

        for (index, component) in screenDoc.components.enumerated() {
            let path = "components[\(index)]"
            let detail = screenDoc.componentDetails[component]
            switch component {
            case "text.title":
                nodes.append(ScreenNode(kind: "text", role: "title", text: detail?.value(for: "text") ?? screenDoc.title))
            case "text.body":
                nodes.append(ScreenNode(kind: "text", role: "body", text: detail?.value(for: "text") ?? primaryBodyText(for: screenDoc)))
            case "text.caption":
                nodes.append(ScreenNode(kind: "text", role: "caption", text: detail?.value(for: "text") ?? secondaryBodyText(for: screenDoc)))
            case "text.label":
                nodes.append(ScreenNode(kind: "text", role: "label", text: detail?.value(for: "text") ?? screenDoc.intent ?? screenDoc.title))
            case "card":
                if let cardNode = explicitCardNode(from: detail) {
                    nodes.append(cardNode)
                } else {
                    warnings.append("card content is inferred from screen-doc narrative")
                    unresolvedItems.append(
                        CompileScreenDocIssue(
                            code: "card.inferred-content",
                            path: path,
                            message: "card requires explicit child content before the spec is complete"
                        )
                    )
                    nodes.append(
                        ScreenNode(
                            kind: "card",
                            spacing: "{space.2}",
                            children: inferredCardChildren(for: screenDoc)
                        )
                    )
                }
            default:
                if component.hasPrefix("textField.") {
                    let field = String(component.dropFirst("textField.".count))
                    if let explicitNode = explicitFieldNode(kind: "textField", field: field, detail: detail) {
                        nodes.append(explicitNode)
                    } else {
                        unresolvedItems.append(
                            CompileScreenDocIssue(
                                code: "textField.missing-binding",
                                path: path,
                                message: "textField requires explicit state field and binding completion"
                            )
                        )
                        nodes.append(inferredTextField(for: field))
                    }
                } else if component.hasPrefix("secureField.") {
                    let field = String(component.dropFirst("secureField.".count))
                    if let explicitNode = explicitFieldNode(kind: "secureField", field: field, detail: detail) {
                        nodes.append(explicitNode)
                    } else {
                        unresolvedItems.append(
                            CompileScreenDocIssue(
                                code: "secureField.missing-binding",
                                path: path,
                                message: "secureField requires explicit state field and binding completion"
                            )
                        )
                        nodes.append(inferredSecureField(for: field))
                    }
                } else if component.hasPrefix("button.") {
                    let variant = String(component.dropFirst("button.".count))
                    if let explicitNode = explicitButtonNode(variant: variant, detail: detail) {
                        nodes.append(explicitNode)
                    } else {
                        let action = inferredButton(for: screenDoc, variant: variant)
                        unresolvedItems.append(
                            CompileScreenDocIssue(
                                code: "button.missing-action",
                                path: path,
                                message: "button requires explicit action or navigation contract completion"
                            )
                        )
                        nodes.append(
                            ScreenNode(
                                kind: "button",
                                variant: variant,
                                title: action.title,
                                action: action.action
                            )
                        )
                    }
                } else if component == "image" || component.hasPrefix("image.") {
                    if let explicitNode = explicitMediaNode(kind: "image", detail: detail) {
                        nodes.append(explicitNode)
                    } else {
                        unresolvedItems.append(
                            CompileScreenDocIssue(
                                code: "image.missing-asset",
                                path: path,
                                message: "image requires explicit assetName contract completion"
                            )
                        )
                        nodes.append(placeholderNode(for: component))
                    }
                } else if component == "icon" || component.hasPrefix("icon.") {
                    if let explicitNode = explicitMediaNode(kind: "icon", detail: detail) {
                        nodes.append(explicitNode)
                    } else {
                        unresolvedItems.append(
                            CompileScreenDocIssue(
                                code: "icon.missing-asset",
                                path: path,
                                message: "icon requires explicit assetName contract completion"
                            )
                        )
                        nodes.append(placeholderNode(for: component))
                    }
                } else {
                    warnings.append("component '\(component)' is not compiled in v1; placeholder node inserted")
                    unresolvedItems.append(
                        CompileScreenDocIssue(
                            code: "component.unsupported",
                            path: path,
                            message: "unsupported component '\(component)' requires explicit upstream support before the spec is complete"
                        )
                    )
                    nodes.append(placeholderNode(for: component))
                }
            }
        }

        if nodes.isEmpty {
            warnings.append("screen-doc did not declare compilable components; fallback text nodes were inserted")
            unresolvedItems.append(
                CompileScreenDocIssue(
                    code: "components.missing",
                    path: "components",
                    message: "screen-doc requires explicit supported components before the starter spec is complete"
                )
            )
            nodes = [
                ScreenNode(kind: "text", role: "title", text: screenDoc.title),
                ScreenNode(kind: "text", role: "body", text: primaryBodyText(for: screenDoc))
            ]
        }

        return (nodes, warnings, unresolvedItems)
    }

    private func parseBody(_ body: String, source: String) throws -> ParsedScreenDocBody {
        let lines = body.components(separatedBy: .newlines)
        guard let firstStructuredIndex = lines.firstIndex(where: { structuredBodySection(from: $0) != nil }) else {
            return ParsedScreenDocBody(narrativeBody: body, stateFields: [], actions: [], assets: [], previewStates: [], navigation: [], componentDetails: [:])
        }

        let narrativeBody = lines[..<firstStructuredIndex].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        var currentSection: StructuredBodySection?
        var stateFields: [ScreenStateField] = []
        var actions: [ScreenAction] = []
        var assets: [ScreenAsset] = []
        var previewStates: [ScreenPreviewState] = []
        var navigation: [ScreenNavigationDestination] = []
        var componentDetails: [String: ScreenDocComponentDetail] = [:]

        for rawLine in lines[firstStructuredIndex...] {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                continue
            }

            if let section = structuredBodySection(from: trimmed) {
                currentSection = section
                continue
            }

            guard let currentSection else {
                continue
            }

            guard trimmed.hasPrefix("- ") else {
                throw ProjectError.invalidArgument("Structured screen-doc section '\(currentSection.rawValue)' only accepts bullet items in \(source)")
            }

            let item = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            switch currentSection {
            case .stateFields:
                stateFields.append(try parseStateField(item, source: source))
            case .actions:
                actions.append(try parseAction(item, source: source))
            case .assets:
                assets.append(try parseAsset(item, source: source))
            case .previewStates:
                previewStates.append(try parsePreviewState(item, source: source))
            case .navigation:
                navigation.append(try parseNavigationDestination(item, source: source))
            case .componentDetails:
                let detail = try parseComponentDetail(item, source: source)
                if componentDetails[detail.component] != nil {
                    throw ProjectError.invalidArgument("Duplicate component detail '\(detail.component)' in \(source)")
                }
                componentDetails[detail.component] = detail
            }
        }

        return ParsedScreenDocBody(
            narrativeBody: narrativeBody,
            stateFields: stateFields,
            actions: actions,
            assets: assets,
            previewStates: previewStates,
            navigation: navigation,
            componentDetails: componentDetails
        )
    }

    private func previewStateCompletionIssues(for screenDoc: ScreenDoc) -> [CompileScreenDocIssue] {
        guard !screenDoc.states.isEmpty else {
            return []
        }

        let previewStateIDs = Set(
            screenDoc.previewStates
                .map(\.id)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        return screenDoc.states.enumerated().compactMap { index, state in
            let trimmedState = state.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedState.isEmpty, !previewStateIDs.contains(trimmedState) else {
                return nil
            }

            return CompileScreenDocIssue(
                code: "previewState.missing",
                path: "states[\(index)]",
                message: "state '\(trimmedState)' requires a matching preview state before the spec is complete"
            )
        }
    }

    private func primaryBodyText(for screenDoc: ScreenDoc) -> String {
        paragraphLines(in: screenDoc.body).first ?? screenDoc.intent ?? "Describe the screen intent here."
    }

    private func secondaryBodyText(for screenDoc: ScreenDoc) -> String {
        paragraphLines(in: screenDoc.body).dropFirst().first ?? screenDoc.intent ?? "Keep the interface direct and minimal."
    }

    private func paragraphLines(in text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func inferredTextField(for field: String) -> ScreenNode {
        let normalizedField = field.trimmingCharacters(in: .whitespacesAndNewlines)
        let inputType: String
        switch normalizedField {
        case "email":
            inputType = "email"
        case "number", "quantity":
            inputType = "number"
        default:
            inputType = "text"
        }
        return ScreenNode(
            kind: "textField",
            id: camelCase(from: normalizedField),
            label: titleCase(from: normalizedField),
            inputType: inputType
        )
    }

    private func inferredSecureField(for field: String) -> ScreenNode {
        let normalizedField = field.trimmingCharacters(in: .whitespacesAndNewlines)
        return ScreenNode(
            kind: "secureField",
            id: camelCase(from: normalizedField),
            label: titleCase(from: normalizedField)
        )
    }

    private func inferredButton(for screenDoc: ScreenDoc, variant: String) -> (title: String, action: String) {
        let body = screenDoc.body.lowercased()
        let hasPasswordField = screenDoc.components.contains { $0.hasPrefix("secureField.") }

        if variant == "secondary" {
            return ("Learn more", "secondaryAction")
        }

        if hasPasswordField || screenDoc.screenId.contains("login") || body.contains("account") {
            return ("Continue", "submit\(pascalCase(from: screenDoc.screenId))")
        }

        if body.contains("cart") || body.contains("purchase") || body.contains("buy") {
            return ("Add to cart", "addToCart")
        }

        return ("Continue", "primaryAction")
    }

    private func explicitFieldNode(kind: String, field: String, detail: ScreenDocComponentDetail?) -> ScreenNode? {
        guard let binding = detail?.value(for: "binding"), !binding.isEmpty else {
            return nil
        }

        let inferredNode = kind == "textField" ? inferredTextField(for: field) : inferredSecureField(for: field)
        return ScreenNode(
            kind: kind,
            id: detail?.value(for: "id") ?? inferredNode.id,
            label: detail?.value(for: "label") ?? inferredNode.label,
            binding: binding,
            inputType: kind == "textField" ? detail?.value(for: "inputType") ?? inferredNode.inputType : nil
        )
    }

    private func explicitButtonNode(variant: String, detail: ScreenDocComponentDetail?) -> ScreenNode? {
        guard
            let title = detail?.value(for: "title"),
            !title.isEmpty
        else {
            return nil
        }

        let action = detail?.value(for: "action")
        let navigation = detail?.value(for: "navigation")
        guard (action?.isEmpty == false) || (navigation?.isEmpty == false) else {
            return nil
        }

        return ScreenNode(kind: "button", variant: variant, title: title, action: action, navigation: navigation)
    }

    private func explicitMediaNode(kind: String, detail: ScreenDocComponentDetail?) -> ScreenNode? {
        guard let assetName = detail?.value(for: "assetName"), !assetName.isEmpty else {
            return nil
        }

        return ScreenNode(
            kind: kind,
            id: detail?.value(for: "id"),
            assetName: assetName
        )
    }

    private func explicitCardNode(from detail: ScreenDocComponentDetail?) -> ScreenNode? {
        guard
            let label = detail?.value(for: "label"),
            !label.isEmpty,
            let body = detail?.value(for: "body"),
            !body.isEmpty,
            let caption = detail?.value(for: "caption"),
            !caption.isEmpty
        else {
            return nil
        }

        return ScreenNode(
            kind: "card",
            spacing: "{space.2}",
            children: [
                ScreenNode(kind: "text", role: "label", text: label),
                ScreenNode(kind: "text", role: "body", text: body),
                ScreenNode(kind: "text", role: "caption", text: caption),
            ]
        )
    }

    private func placeholderNode(for component: String) -> ScreenNode {
        ScreenNode(
            kind: "text",
            role: "caption",
            text: "Unsupported component: \(component)"
        )
    }

    private func inferredCardChildren(for screenDoc: ScreenDoc) -> [ScreenNode] {
        [
            ScreenNode(kind: "text", role: "label", text: inferredCardLabel(for: screenDoc)),
            ScreenNode(kind: "text", role: "body", text: primaryBodyText(for: screenDoc)),
            ScreenNode(kind: "text", role: "caption", text: secondaryBodyText(for: screenDoc))
        ]
    }

    private func inferredCardLabel(for screenDoc: ScreenDoc) -> String {
        let body = screenDoc.body.lowercased()
        if body.contains("price") || body.contains("purchase") || body.contains("cart") {
            return "Details"
        }
        return "Summary"
    }

    private func titleCase(from raw: String) -> String {
        identifierParts(from: raw).map { part in
            guard let first = part.first else { return part }
            return first.uppercased() + part.dropFirst()
        }.joined(separator: " ")
    }

    private func camelCase(from raw: String) -> String {
        let parts = identifierParts(from: raw)
        guard let first = parts.first else {
            return "field"
        }
        return first.lowercased() + parts.dropFirst().map(capitalized).joined()
    }

    private func pascalCase(from raw: String) -> String {
        let parts = identifierParts(from: raw)
        guard !parts.isEmpty else {
            return "Screen"
        }
        return parts.map(capitalized).joined()
    }

    private func capitalized(_ value: String) -> String {
        guard let first = value.first else {
            return value
        }
        return first.uppercased() + value.dropFirst()
    }

    private func identifierParts(from raw: String) -> [String] {
        raw
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func structuredBodySection(from rawLine: String) -> StructuredBodySection? {
        switch rawLine.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "## state fields", "## state-fields":
            return .stateFields
        case "## actions":
            return .actions
        case "## assets":
            return .assets
        case "## preview states", "## preview-states":
            return .previewStates
        case "## navigation":
            return .navigation
        case "## component details", "## component-details":
            return .componentDetails
        default:
            return nil
        }
    }

    private func parseStateField(_ item: String, source: String) throws -> ScreenStateField {
        let entry = try parseStructuredEntry(item, source: source, section: .stateFields)
        guard let rawType = entry.attributes["type"], let type = ScreenStateFieldType(rawValue: rawType) else {
            throw ProjectError.invalidArgument("State field '\(entry.identifier)' requires type=string|boolean|integer|number in \(source)")
        }

        let defaultValue = try parseDefaultValue(entry.attributes["default"], source: source, fieldID: entry.identifier)
        return ScreenStateField(id: entry.identifier, type: type, defaultValue: defaultValue)
    }

    private func parseAction(_ item: String, source: String) throws -> ScreenAction {
        let entry = try parseStructuredEntry(item, source: source, section: .actions)
        guard entry.attributes.isEmpty else {
            throw ProjectError.invalidArgument("Action '\(entry.identifier)' does not accept extra attributes in \(source)")
        }
        return ScreenAction(id: entry.identifier)
    }

    private func parseAsset(_ item: String, source: String) throws -> ScreenAsset {
        let entry = try parseStructuredEntry(item, source: source, section: .assets)
        guard let rawKind = entry.attributes["kind"], let kind = ScreenAssetKind(rawValue: rawKind) else {
            throw ProjectError.invalidArgument("Asset '\(entry.identifier)' requires kind=image|icon in \(source)")
        }
        guard entry.attributes.count == 1 else {
            throw ProjectError.invalidArgument("Asset '\(entry.identifier)' only accepts kind=image|icon in \(source)")
        }
        return ScreenAsset(name: entry.identifier, kind: kind)
    }

    private func parsePreviewState(_ item: String, source: String) throws -> ScreenPreviewState {
        let entry = try parseStructuredEntry(item, source: source, section: .previewStates)
        let supportedKeys: Set<String> = ["values", "note"]
        let unsupportedKeys = Set(entry.attributes.keys).subtracting(supportedKeys)
        guard unsupportedKeys.isEmpty else {
            let keys = unsupportedKeys.sorted().joined(separator: ", ")
            throw ProjectError.invalidArgument("Preview state '\(entry.identifier)' has unsupported attributes \(keys) in \(source)")
        }

        let values = try parsePreviewStateValues(entry.attributes["values"], source: source, stateID: entry.identifier)
        return ScreenPreviewState(id: entry.identifier, values: values, note: entry.attributes["note"])
    }

    private func parseNavigationDestination(_ item: String, source: String) throws -> ScreenNavigationDestination {
        let entry = try parseStructuredEntry(item, source: source, section: .navigation)
        guard let route = entry.attributes["route"], !route.isEmpty else {
            throw ProjectError.invalidArgument("Navigation destination '\(entry.identifier)' requires route=/path in \(source)")
        }
        guard entry.attributes.count == 1 else {
            throw ProjectError.invalidArgument("Navigation destination '\(entry.identifier)' only accepts route=/path in \(source)")
        }
        return ScreenNavigationDestination(id: entry.identifier, route: route)
    }

    private func parseComponentDetail(_ item: String, source: String) throws -> ScreenDocComponentDetail {
        let entry = try parseStructuredEntry(item, source: source, section: .componentDetails)
        guard !entry.attributes.isEmpty else {
            throw ProjectError.invalidArgument("Component detail '\(entry.identifier)' requires at least one key=value attribute in \(source)")
        }
        return ScreenDocComponentDetail(component: entry.identifier, attributes: entry.attributes)
    }

    private func parseStructuredEntry(_ item: String, source: String, section: StructuredBodySection) throws -> StructuredEntry {
        let segments = item
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let rawIdentifier = segments.first, !rawIdentifier.isEmpty else {
            throw ProjectError.invalidArgument("Empty structured entry in section '\(section.rawValue)' for \(source)")
        }

        let identifier = stripBackticks(from: rawIdentifier)
        var attributes: [String: String] = [:]

        for segment in segments.dropFirst() {
            guard !segment.isEmpty else {
                throw ProjectError.invalidArgument("Empty attribute segment in section '\(section.rawValue)' for \(source)")
            }
            guard let separator = segment.firstIndex(of: "=") else {
                throw ProjectError.invalidArgument("Structured entry '\(identifier)' in section '\(section.rawValue)' requires key=value attributes in \(source)")
            }

            let key = String(segment[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(segment[segment.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else {
                throw ProjectError.invalidArgument("Structured entry '\(identifier)' has an empty key or value in \(source)")
            }
            if attributes[key] != nil {
                throw ProjectError.invalidArgument("Structured entry '\(identifier)' repeats attribute '\(key)' in \(source)")
            }
            attributes[key] = stripBackticks(from: value)
        }

        return StructuredEntry(identifier: identifier, attributes: attributes)
    }

    private func parseDefaultValue(_ rawValue: String?, source: String, fieldID: String) throws -> JSONValue? {
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }

        let data = Data(rawValue.utf8)
        do {
            let value = try JSONDecoder().decode(JSONValue.self, from: data)
            switch value {
            case .object, .array:
                throw ProjectError.invalidArgument("State field '\(fieldID)' default must be a JSON scalar in \(source)")
            default:
                return value
            }
        } catch {
            throw ProjectError.invalidArgument("State field '\(fieldID)' default must be a JSON scalar in \(source)")
        }
    }

    private func parsePreviewStateValues(_ rawValue: String?, source: String, stateID: String) throws -> [String: JSONValue] {
        guard let rawValue, !rawValue.isEmpty else {
            return [:]
        }

        let data = Data(rawValue.utf8)
        do {
            let value = try JSONDecoder().decode(JSONValue.self, from: data)
            guard case .object(let object) = value else {
                throw ProjectError.invalidArgument("Preview state '\(stateID)' values must be a JSON object in \(source)")
            }
            return object
        } catch {
            throw ProjectError.invalidArgument("Preview state '\(stateID)' values must be a JSON object in \(source)")
        }
    }

    private func stripBackticks(from value: String) -> String {
        guard value.hasPrefix("`"), value.hasSuffix("`"), value.count >= 2 else {
            return value
        }
        return String(value.dropFirst().dropLast())
    }
}

private enum FrontMatterValue {
    case string(String)
    case array([String])

    var stringValue: String? {
        guard case .string(let value) = self else {
            return nil
        }
        return value
    }

    var arrayValue: [String]? {
        guard case .array(let value) = self else {
            return nil
        }
        return value
    }
}

private struct ParsedScreenDocBody {
    let narrativeBody: String
    let stateFields: [ScreenStateField]
    let actions: [ScreenAction]
    let assets: [ScreenAsset]
    let previewStates: [ScreenPreviewState]
    let navigation: [ScreenNavigationDestination]
    let componentDetails: [String: ScreenDocComponentDetail]
}

private enum StructuredBodySection: String {
    case stateFields = "State Fields"
    case actions = "Actions"
    case assets = "Assets"
    case previewStates = "Preview States"
    case navigation = "Navigation"
    case componentDetails = "Component Details"
}

private struct StructuredEntry {
    let identifier: String
    let attributes: [String: String]
}
