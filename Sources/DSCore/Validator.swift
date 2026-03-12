import Foundation

public struct ProjectValidator {
    public init() {}

    public func validate(spec: ScreenSpec, tokens: TokenStore, catalog: ComponentCatalog) -> ValidationReport {
        var issues: [ValidationIssue] = []
        let catalogMap = Dictionary(uniqueKeysWithValues: catalog.components.map { ($0.kind, $0) })
        let stateFields = validateStateFields(spec.stateFields, issues: &issues)
        let actionIDs = validateActions(spec.actions, issues: &issues)
        let assets = validateAssets(spec.assets, issues: &issues)
        _ = validatePreviewStates(spec.previewStates, states: spec.states, stateFields: stateFields, issues: &issues)
        let navigationIDs = validateNavigation(spec.navigation, issues: &issues)

        if spec.schemaVersion != "1.0" {
            issues.append(.init(code: "schemaVersion", path: "schemaVersion", message: "ScreenSpec schemaVersion must be 1.0"))
        }

        if !isValidScreenID(spec.screenId) {
            issues.append(.init(code: "screenId", path: "screenId", message: "screenId must match ^[a-z0-9]+(?:-[a-z0-9]+)*$"))
        }

        if spec.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(code: "title", path: "title", message: "title must not be empty"))
        }

        if let intent = spec.intent, intent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(code: "intent", path: "intent", message: "intent must not be empty when provided"))
        }

        validateRoute(spec.route, path: "route", issues: &issues)

        validateStringList(spec.constraints, path: "constraints", itemLabel: "constraint", issues: &issues)
        validateStringList(spec.states, path: "states", itemLabel: "state", issues: &issues)

        let uniquePlatforms = Set(spec.platforms.map(\.rawValue))
        if uniquePlatforms.count != spec.platforms.count || spec.platforms.isEmpty {
            issues.append(.init(code: "platforms", path: "platforms", message: "platforms must be non-empty and unique"))
        }

        validateAlias(spec.surface.backgroundColor, path: "surface.backgroundColor", tokens: tokens, issues: &issues)
        validateAlias(spec.surface.padding, path: "surface.padding", tokens: tokens, issues: &issues)

        validateNode(
            spec.root,
            path: "root",
            tokens: tokens,
            catalogMap: catalogMap,
            stateFields: stateFields,
            actionIDs: actionIDs,
            assets: assets,
            navigationIDs: navigationIDs,
            issues: &issues
        )

        return ValidationReport(issues: issues)
    }

    private func validateNode(
        _ node: ScreenNode,
        path: String,
        tokens: TokenStore,
        catalogMap: [String: ComponentDefinition],
        stateFields: [String: ScreenStateField],
        actionIDs: Set<String>,
        assets: [String: ScreenAsset],
        navigationIDs: Set<String>,
        issues: inout [ValidationIssue]
    ) {
        guard let definition = catalogMap[node.kind] else {
            issues.append(.init(code: "component.kind", path: "\(path).kind", message: "Unknown component kind: \(node.kind)"))
            return
        }

        let containerKinds: Set<String> = ["vstack", "hstack", "card"]

        if containerKinds.contains(node.kind) {
            if (node.children ?? []).isEmpty {
                issues.append(.init(code: "children", path: "\(path).children", message: "\(node.kind) requires at least one child"))
            }
        } else if node.children != nil {
            issues.append(.init(code: "leaf.children", path: "\(path).children", message: "\(node.kind) must not define children"))
        }

        switch node.kind {
        case "text":
            requireNonEmpty(node.text, path: "\(path).text", message: "text requires `text`", issues: &issues)
        case "textField":
            requireNonEmpty(node.label, path: "\(path).label", message: "textField requires `label`", issues: &issues)
        case "secureField":
            requireNonEmpty(node.label, path: "\(path).label", message: "secureField requires `label`", issues: &issues)
        case "button":
            requireNonEmpty(node.title, path: "\(path).title", message: "button requires `title`", issues: &issues)
            validateButtonInteraction(node, path: path, issues: &issues)
        case "image":
            requireNonEmpty(node.assetName, path: "\(path).assetName", message: "image requires `assetName`", issues: &issues)
        case "icon":
            requireNonEmpty(node.assetName, path: "\(path).assetName", message: "icon requires `assetName`", issues: &issues)
        default:
            break
        }

        if let role = node.role, let allowed = definition.roles, !allowed.contains(role) {
            issues.append(.init(code: "role", path: "\(path).role", message: "Role '\(role)' is not allowed for \(node.kind)"))
        }

        if let variant = node.variant, let allowed = definition.variants, !allowed.contains(variant) {
            issues.append(.init(code: "variant", path: "\(path).variant", message: "Variant '\(variant)' is not allowed for \(node.kind)"))
        }

        if let inputType = node.inputType, let allowed = definition.inputTypes, !allowed.contains(inputType) {
            issues.append(.init(code: "inputType", path: "\(path).inputType", message: "inputType '\(inputType)' is not allowed for \(node.kind)"))
        }

        validateBinding(node, path: path, stateFields: stateFields, issues: &issues)
        validateAssetReference(node, path: path, assets: assets, issues: &issues)
        validateNavigationReference(node, path: path, navigationIDs: navigationIDs, issues: &issues)

        if node.kind == "button", !actionIDs.isEmpty {
            let action = node.action?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !action.isEmpty, !actionIDs.contains(action) {
                issues.append(.init(code: "action.reference", path: "\(path).action", message: "Unknown action id: \(action)"))
            }
        }

        if let spacing = node.spacing {
            validateAlias(spacing, path: "\(path).spacing", tokens: tokens, issues: &issues)
        }

        for (index, child) in (node.children ?? []).enumerated() {
            validateNode(
                child,
                path: "\(path).children[\(index)]",
                tokens: tokens,
                catalogMap: catalogMap,
                stateFields: stateFields,
                actionIDs: actionIDs,
                assets: assets,
                navigationIDs: navigationIDs,
                issues: &issues
            )
        }
    }

    private func validateAlias(_ alias: String, path: String, tokens: TokenStore, issues: inout [ValidationIssue]) {
        guard TokenStore.path(fromAlias: alias) != nil else {
            issues.append(.init(code: "token.alias", path: path, message: "Expected token alias format like {space.6}"))
            return
        }

        if tokens.resolve(alias: alias) == nil {
            issues.append(.init(code: "token.reference", path: path, message: "Unknown token alias: \(alias)"))
        }
    }

    private func validateStateFields(_ fields: [ScreenStateField], issues: inout [ValidationIssue]) -> [String: ScreenStateField] {
        var seen: Set<String> = []
        var result: [String: ScreenStateField] = [:]

        for (index, field) in fields.enumerated() {
            let trimmedID = field.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedID.isEmpty {
                issues.append(.init(code: "stateField.empty", path: "stateFields[\(index)].id", message: "state field id must not be empty"))
                continue
            }

            if !seen.insert(trimmedID).inserted {
                issues.append(.init(code: "stateField.duplicate", path: "stateFields[\(index)].id", message: "state field ids must be unique"))
                continue
            }

            if !isCompatible(field.defaultValue, with: field.type) {
                issues.append(.init(code: "stateField.defaultValue", path: "stateFields[\(index)].defaultValue", message: "defaultValue does not match state field type \(field.type.rawValue)"))
            }

            result[trimmedID] = field
        }

        return result
    }

    private func validateActions(_ actions: [ScreenAction], issues: inout [ValidationIssue]) -> Set<String> {
        var seen: Set<String> = []

        for (index, action) in actions.enumerated() {
            let trimmedID = action.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedID.isEmpty {
                issues.append(.init(code: "action.empty", path: "actions[\(index)].id", message: "action id must not be empty"))
                continue
            }

            if !seen.insert(trimmedID).inserted {
                issues.append(.init(code: "action.duplicate", path: "actions[\(index)].id", message: "action ids must be unique"))
            }
        }

        return seen
    }

    private func validateAssets(_ assets: [ScreenAsset], issues: inout [ValidationIssue]) -> [String: ScreenAsset] {
        var seen: Set<String> = []
        var result: [String: ScreenAsset] = [:]

        for (index, asset) in assets.enumerated() {
            let trimmedName = asset.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                issues.append(.init(code: "asset.empty", path: "assets[\(index)].name", message: "asset name must not be empty"))
                continue
            }

            if !seen.insert(trimmedName).inserted {
                issues.append(.init(code: "asset.duplicate", path: "assets[\(index)].name", message: "asset names must be unique"))
                continue
            }

            result[trimmedName] = asset
        }

        return result
    }

    private func validateNavigation(_ navigation: [ScreenNavigationDestination], issues: inout [ValidationIssue]) -> Set<String> {
        var seen: Set<String> = []

        for (index, destination) in navigation.enumerated() {
            let trimmedID = destination.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedID.isEmpty {
                issues.append(.init(code: "navigation.empty", path: "navigation[\(index)].id", message: "navigation id must not be empty"))
                continue
            }

            if !seen.insert(trimmedID).inserted {
                issues.append(.init(code: "navigation.duplicate", path: "navigation[\(index)].id", message: "navigation ids must be unique"))
            }

            validateRoute(destination.route, path: "navigation[\(index)].route", issues: &issues)
        }

        return seen
    }

    private func validatePreviewStates(
        _ previewStates: [ScreenPreviewState],
        states: [String],
        stateFields: [String: ScreenStateField],
        issues: inout [ValidationIssue]
    ) -> [String: ScreenPreviewState] {
        var seen: Set<String> = []
        var result: [String: ScreenPreviewState] = [:]
        let declaredStates = Set(
            states
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        for (index, previewState) in previewStates.enumerated() {
            let trimmedID = previewState.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedID.isEmpty {
                issues.append(.init(code: "previewState.empty", path: "previewStates[\(index)].id", message: "preview state id must not be empty"))
                continue
            }

            if !seen.insert(trimmedID).inserted {
                issues.append(.init(code: "previewState.duplicate", path: "previewStates[\(index)].id", message: "preview state ids must be unique"))
                continue
            }

            if !declaredStates.isEmpty, !declaredStates.contains(trimmedID) {
                issues.append(.init(code: "previewState.state", path: "previewStates[\(index)].id", message: "preview state '\(trimmedID)' must reference a declared state"))
            }

            if let note = previewState.note, note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(code: "previewState.note", path: "previewStates[\(index)].note", message: "preview state note must not be empty when provided"))
            }

            for (fieldID, value) in previewState.values.sorted(by: { $0.key < $1.key }) {
                guard let field = stateFields[fieldID] else {
                    issues.append(.init(code: "previewState.value.reference", path: "previewStates[\(index)].values.\(fieldID)", message: "Unknown state field id: \(fieldID)"))
                    continue
                }

                if !isCompatible(value, with: field.type) {
                    issues.append(.init(code: "previewState.value.type", path: "previewStates[\(index)].values.\(fieldID)", message: "preview state value does not match state field type \(field.type.rawValue)"))
                }
            }

            result[trimmedID] = previewState
        }

        for (index, state) in states.enumerated() {
            let trimmedState = state.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedState.isEmpty, !result.keys.contains(trimmedState) else {
                continue
            }

            issues.append(.init(code: "previewState.missing", path: "states[\(index)]", message: "state '\(trimmedState)' requires a matching preview state"))
        }

        return result
    }

    private func validateBinding(
        _ node: ScreenNode,
        path: String,
        stateFields: [String: ScreenStateField],
        issues: inout [ValidationIssue]
    ) {
        let supportsBinding = node.kind == "textField" || node.kind == "secureField"

        if let binding = node.binding {
            let trimmedBinding = binding.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedBinding.isEmpty {
                issues.append(.init(code: "binding.empty", path: "\(path).binding", message: "binding must not be empty"))
                return
            }

            guard supportsBinding else {
                issues.append(.init(code: "binding.unsupported", path: "\(path).binding", message: "\(node.kind) does not support binding"))
                return
            }

            guard let field = stateFields[trimmedBinding] else {
                issues.append(.init(code: "binding.reference", path: "\(path).binding", message: "Unknown state field id: \(trimmedBinding)"))
                return
            }

            if field.type != .string {
                issues.append(.init(code: "binding.type", path: "\(path).binding", message: "\(node.kind) bindings must target string state fields"))
            }
        } else if supportsBinding, !stateFields.isEmpty {
            issues.append(.init(code: "binding.required", path: "\(path).binding", message: "\(node.kind) requires `binding` when stateFields are declared"))
        }
    }

    private func validateAssetReference(
        _ node: ScreenNode,
        path: String,
        assets: [String: ScreenAsset],
        issues: inout [ValidationIssue]
    ) {
        guard node.kind == "image" || node.kind == "icon" else {
            return
        }

        let trimmedName = node.assetName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedName.isEmpty else {
            return
        }

        guard let asset = assets[trimmedName] else {
            issues.append(.init(code: "asset.reference", path: "\(path).assetName", message: "Unknown asset name: \(trimmedName)"))
            return
        }

        if asset.kind.rawValue != node.kind {
            issues.append(.init(code: "asset.kind", path: "\(path).assetName", message: "\(node.kind) requires an asset declared with kind \(node.kind)"))
        }
    }

    private func validateNavigationReference(
        _ node: ScreenNode,
        path: String,
        navigationIDs: Set<String>,
        issues: inout [ValidationIssue]
    ) {
        guard let navigation = node.navigation else {
            return
        }

        let trimmedNavigation = navigation.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNavigation.isEmpty {
            issues.append(.init(code: "navigation.reference", path: "\(path).navigation", message: "navigation reference must not be empty"))
            return
        }

        guard node.kind == "button" else {
            issues.append(.init(code: "navigation.unsupported", path: "\(path).navigation", message: "\(node.kind) does not support navigation"))
            return
        }

        if !navigationIDs.contains(trimmedNavigation) {
            issues.append(.init(code: "navigation.reference", path: "\(path).navigation", message: "Unknown navigation id: \(trimmedNavigation)"))
        }
    }

    private func validateButtonInteraction(_ node: ScreenNode, path: String, issues: inout [ValidationIssue]) {
        let trimmedAction = node.action?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedNavigation = node.navigation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmedAction.isEmpty && trimmedNavigation.isEmpty {
            issues.append(.init(code: "button.interaction", path: path, message: "button requires exactly one of `action` or `navigation`"))
        }

        if !trimmedAction.isEmpty && !trimmedNavigation.isEmpty {
            issues.append(.init(code: "button.interaction", path: path, message: "button must not declare both `action` and `navigation`"))
        }
    }

    private func validateRoute(_ route: String?, path: String, issues: inout [ValidationIssue]) {
        guard let route else {
            return
        }

        let trimmedRoute = route.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedRoute.isEmpty || !trimmedRoute.hasPrefix("/") || trimmedRoute.contains(where: \.isWhitespace) {
            issues.append(.init(code: "route.invalid", path: path, message: "route must start with '/' and must not contain whitespace"))
        }
    }

    private func requireNonEmpty(_ value: String?, path: String, message: String, issues: inout [ValidationIssue]) {
        if value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            issues.append(.init(code: "required", path: path, message: message))
        }
    }

    private func validateStringList(_ values: [String], path: String, itemLabel: String, issues: inout [ValidationIssue]) {
        var seen: Set<String> = []

        for (index, value) in values.enumerated() {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                issues.append(.init(code: "\(itemLabel).empty", path: "\(path)[\(index)]", message: "\(itemLabel) entries must not be empty"))
                continue
            }

            if !seen.insert(trimmed).inserted {
                issues.append(.init(code: "\(itemLabel).duplicate", path: "\(path)[\(index)]", message: "\(itemLabel) entries must be unique"))
            }
        }
    }

    private func isValidScreenID(_ screenID: String) -> Bool {
        let pattern = "^[a-z0-9]+(?:-[a-z0-9]+)*$"
        return screenID.range(of: pattern, options: .regularExpression) != nil
    }

    private func isCompatible(_ value: JSONValue?, with type: ScreenStateFieldType) -> Bool {
        guard let value else {
            return true
        }

        switch (type, value) {
        case (.string, .string):
            return true
        case (.boolean, .bool):
            return true
        case (.integer, .integer):
            return true
        case (.number, .integer), (.number, .double):
            return true
        case (_, .null):
            return true
        default:
            return false
        }
    }
}
