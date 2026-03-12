import Foundation
import Yams

struct ContractDocumentLoader {
    func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let text = try String(contentsOf: url, encoding: .utf8)
        switch url.pathExtension.lowercased() {
        case "yaml", "yml":
            return try YAMLDecoder().decode(T.self, from: text)
        case "json":
            return try JSONDecoder().decode(T.self, from: Data(text.utf8))
        default:
            throw ProjectError.invalidArgument("Unsupported contract format at \(url.path). Use .yaml, .yml, or .json")
        }
    }
}

struct ScreenContext {
    let contractRoot: URL
    let appURL: URL
    let appSpec: AppSpec
    let flowURL: URL
    let flowSpec: FlowSpec
    let screenURL: URL
    let screenSpec: ScreenSpec
    let registryURL: URL
    let registry: ComponentRegistry
    let motionURL: URL
    let motion: MotionSpec
    let reviewURL: URL
    let review: ReviewChecklist
}

public struct ContractValidator {
    private let loader = ContractDocumentLoader()
    private let fileManager = FileManager.default

    public init() {}

    public func validateApp(at appURL: URL) throws -> ValidationReport {
        let appSpec = try loader.load(AppSpec.self, from: appURL)
        return validate(appSpec, at: appURL)
    }

    public func validateFlow(at flowURL: URL) throws -> ValidationReport {
        let flowSpec = try loader.load(FlowSpec.self, from: flowURL)
        let contractRoot = resolveContractRoot(startingAt: flowURL.deletingLastPathComponent())
        let appSpecs = try discoverAppSpecs(contractRoot: contractRoot)
        var issues: [ValidationIssue] = []

        guard let appMatch = resolveParentApp(for: flowSpec, flowURL: flowURL, appSpecs: appSpecs, contractRoot: contractRoot, issues: &issues) else {
            return ValidationReport(issues: issues)
        }

        let registryURL = resolveReference(appMatch.spec.componentRegistry, contractRoot: contractRoot, relativeTo: appMatch.url)
        let motionURL = resolveReference(appMatch.spec.motionSet, contractRoot: contractRoot, relativeTo: appMatch.url)
        let reviewURL = resolveReference(appMatch.spec.reviewSet, contractRoot: contractRoot, relativeTo: appMatch.url)

        let registry = loadReferenced(ComponentRegistry.self, at: registryURL, issuePath: "app.componentRegistry", original: appMatch.spec.componentRegistry, issues: &issues)
        let motion = loadReferenced(MotionSpec.self, at: motionURL, issuePath: "app.motionSet", original: appMatch.spec.motionSet, issues: &issues)
        let review = loadReferenced(ReviewChecklist.self, at: reviewURL, issuePath: "app.reviewSet", original: appMatch.spec.reviewSet, issues: &issues)

        let registryItems = validateRegistry(registry, issues: &issues)
        let motionPatternIDs = validateMotion(motion, issues: &issues)
        let reviewCheckIDs = validateReview(review, issues: &issues)

        validateFlow(
            flowSpec,
            flowURL: flowURL,
            expectedAppID: appMatch.spec.appId,
            expectedFlowID: flowSpec.flowId,
            contractRoot: contractRoot,
            registryItems: registryItems,
            motionPatternIDs: motionPatternIDs,
            reviewCheckIDs: reviewCheckIDs,
            issues: &issues
        )

        return ValidationReport(issues: issues)
    }

    public func validateScreen(at screenURL: URL) throws -> ValidationReport {
        let screenSpec = try loader.load(ScreenSpec.self, from: screenURL)
        let contractRoot = resolveContractRoot(startingAt: screenURL.deletingLastPathComponent())
        let flowSpecs = try discoverFlowSpecs(contractRoot: contractRoot)
        var issues: [ValidationIssue] = []

        guard let flowMatch = resolveParentFlow(for: screenSpec, screenURL: screenURL, flowSpecs: flowSpecs, contractRoot: contractRoot, issues: &issues) else {
            return ValidationReport(issues: issues)
        }

        let appSpecs = try discoverAppSpecs(contractRoot: contractRoot)
        guard let appMatch = resolveParentApp(for: flowMatch.spec, flowURL: flowMatch.url, appSpecs: appSpecs, contractRoot: contractRoot, issues: &issues) else {
            return ValidationReport(issues: issues)
        }

        let registryURL = resolveReference(appMatch.spec.componentRegistry, contractRoot: contractRoot, relativeTo: appMatch.url)
        let motionURL = resolveReference(appMatch.spec.motionSet, contractRoot: contractRoot, relativeTo: appMatch.url)
        let reviewURL = resolveReference(appMatch.spec.reviewSet, contractRoot: contractRoot, relativeTo: appMatch.url)

        let registry = loadReferenced(ComponentRegistry.self, at: registryURL, issuePath: "app.componentRegistry", original: appMatch.spec.componentRegistry, issues: &issues)
        let motion = loadReferenced(MotionSpec.self, at: motionURL, issuePath: "app.motionSet", original: appMatch.spec.motionSet, issues: &issues)
        let review = loadReferenced(ReviewChecklist.self, at: reviewURL, issuePath: "app.reviewSet", original: appMatch.spec.reviewSet, issues: &issues)

        let registryItems = validateRegistry(registry, issues: &issues)
        let motionPatternIDs = validateMotion(motion, issues: &issues)
        let reviewCheckIDs = validateReview(review, issues: &issues)

        validateScreen(
            screenSpec,
            screenURL: screenURL,
            expectedAppID: flowMatch.spec.appId,
            expectedFlowID: flowMatch.spec.flowId,
            expectedScreenID: screenSpec.screenId,
            registryItems: registryItems,
            motionPatternIDs: motionPatternIDs,
            reviewCheckIDs: reviewCheckIDs,
            issues: &issues
        )

        return ValidationReport(issues: issues)
    }

    func resolveScreenContext(at screenURL: URL) throws -> ScreenContext {
        let screenSpec = try loader.load(ScreenSpec.self, from: screenURL)
        let contractRoot = resolveContractRoot(startingAt: screenURL.deletingLastPathComponent())
        var issues: [ValidationIssue] = []
        let flowSpecs = try discoverFlowSpecs(contractRoot: contractRoot)

        guard let flowMatch = resolveParentFlow(
            for: screenSpec,
            screenURL: screenURL,
            flowSpecs: flowSpecs,
            contractRoot: contractRoot,
            issues: &issues
        ) else {
            throw ProjectError.invalidArgument(ValidationReport(issues: issues).summary)
        }

        let appSpecs = try discoverAppSpecs(contractRoot: contractRoot)
        guard let appMatch = resolveParentApp(
            for: flowMatch.spec,
            flowURL: flowMatch.url,
            appSpecs: appSpecs,
            contractRoot: contractRoot,
            issues: &issues
        ) else {
            throw ProjectError.invalidArgument(ValidationReport(issues: issues).summary)
        }

        let registryURL = resolveReference(appMatch.spec.componentRegistry, contractRoot: contractRoot, relativeTo: appMatch.url)
        let motionURL = resolveReference(appMatch.spec.motionSet, contractRoot: contractRoot, relativeTo: appMatch.url)
        let reviewURL = resolveReference(appMatch.spec.reviewSet, contractRoot: contractRoot, relativeTo: appMatch.url)

        guard let registry = loadReferenced(
            ComponentRegistry.self,
            at: registryURL,
            issuePath: "app.componentRegistry",
            original: appMatch.spec.componentRegistry,
            issues: &issues
        ) else {
            throw ProjectError.invalidArgument(ValidationReport(issues: issues).summary)
        }

        guard let motion = loadReferenced(
            MotionSpec.self,
            at: motionURL,
            issuePath: "app.motionSet",
            original: appMatch.spec.motionSet,
            issues: &issues
        ) else {
            throw ProjectError.invalidArgument(ValidationReport(issues: issues).summary)
        }

        guard let review = loadReferenced(
            ReviewChecklist.self,
            at: reviewURL,
            issuePath: "app.reviewSet",
            original: appMatch.spec.reviewSet,
            issues: &issues
        ) else {
            throw ProjectError.invalidArgument(ValidationReport(issues: issues).summary)
        }

        return ScreenContext(
            contractRoot: contractRoot,
            appURL: appMatch.url,
            appSpec: appMatch.spec,
            flowURL: flowMatch.url,
            flowSpec: flowMatch.spec,
            screenURL: screenURL.standardizedFileURL,
            screenSpec: screenSpec,
            registryURL: registryURL,
            registry: registry,
            motionURL: motionURL,
            motion: motion,
            reviewURL: reviewURL,
            review: review
        )
    }

    public func validate(_ appSpec: AppSpec, at appURL: URL) -> ValidationReport {
        let contractRoot = resolveContractRoot(startingAt: appURL.deletingLastPathComponent())
        var issues: [ValidationIssue] = []

        validateSchemaVersion(appSpec.schemaVersion, expected: "2.1", path: "app.schemaVersion", issues: &issues)
        validateIdentifier(appSpec.appId, path: "app.appId", label: "appId", issues: &issues)
        validateNonEmpty(appSpec.title, path: "app.title", message: "title must not be empty", issues: &issues)
        validatePlatformList(appSpec.targetPlatforms, path: "app.targetPlatforms", issues: &issues)
        validateDistinctStrings(appSpec.brands, path: "app.brands", itemLabel: "brand", issues: &issues)

        let tokenSetURL = resolveReference(appSpec.tokenSet, contractRoot: contractRoot, relativeTo: appURL)
        validateExistingPath(tokenSetURL, path: "app.tokenSet", original: appSpec.tokenSet, issues: &issues)

        let registryURL = resolveReference(appSpec.componentRegistry, contractRoot: contractRoot, relativeTo: appURL)
        let motionURL = resolveReference(appSpec.motionSet, contractRoot: contractRoot, relativeTo: appURL)
        let reviewURL = resolveReference(appSpec.reviewSet, contractRoot: contractRoot, relativeTo: appURL)

        let registry = loadReferenced(ComponentRegistry.self, at: registryURL, issuePath: "app.componentRegistry", original: appSpec.componentRegistry, issues: &issues)
        let motion = loadReferenced(MotionSpec.self, at: motionURL, issuePath: "app.motionSet", original: appSpec.motionSet, issues: &issues)
        let review = loadReferenced(ReviewChecklist.self, at: reviewURL, issuePath: "app.reviewSet", original: appSpec.reviewSet, issues: &issues)

        let registryItems = validateRegistry(registry, issues: &issues)
        let motionPatternIDs = validateMotion(motion, issues: &issues)
        let reviewCheckIDs = validateReview(review, issues: &issues)

        var flowIDs: Set<String> = []
        for (index, flowRef) in appSpec.flows.enumerated() {
            validateIdentifier(flowRef.id, path: "app.flows[\(index)].id", label: "flow id", issues: &issues)
            if !flowIDs.insert(flowRef.id).inserted {
                issues.append(.init(code: "flow.duplicate", path: "app.flows[\(index)].id", message: "flow ids must be unique within the app"))
            }

            let flowURL = resolveReference(flowRef.path, contractRoot: contractRoot, relativeTo: appURL)
            guard let flow = loadReferenced(FlowSpec.self, at: flowURL, issuePath: "app.flows[\(index)].path", original: flowRef.path, issues: &issues) else {
                continue
            }

            validateFlow(
                flow,
                flowURL: flowURL,
                expectedAppID: appSpec.appId,
                expectedFlowID: flowRef.id,
                contractRoot: contractRoot,
                registryItems: registryItems,
                motionPatternIDs: motionPatternIDs,
                reviewCheckIDs: reviewCheckIDs,
                issues: &issues
            )
        }

        if appSpec.flows.isEmpty {
            issues.append(.init(code: "app.flows", path: "app.flows", message: "app must declare at least one flow"))
        }

        return ValidationReport(issues: issues)
    }

    private func validateFlow(
        _ flow: FlowSpec,
        flowURL: URL,
        expectedAppID: String,
        expectedFlowID: String,
        contractRoot: URL,
        registryItems: [String: RegistryItem],
        motionPatternIDs: Set<String>,
        reviewCheckIDs: Set<String>,
        issues: inout [ValidationIssue]
    ) {
        validateSchemaVersion(flow.schemaVersion, expected: "2.1", path: "flow[\(flow.flowId)].schemaVersion", issues: &issues)
        validateIdentifier(flow.appId, path: "flow[\(flow.flowId)].appId", label: "appId", issues: &issues)
        validateIdentifier(flow.flowId, path: "flow[\(flow.flowId)].flowId", label: "flowId", issues: &issues)
        validateNonEmpty(flow.title, path: "flow[\(flow.flowId)].title", message: "title must not be empty", issues: &issues)

        if flow.appId != expectedAppID {
            issues.append(.init(code: "flow.appId", path: "flow[\(flow.flowId)].appId", message: "flow appId must match AppSpec appId \(expectedAppID)"))
        }
        if flow.flowId != expectedFlowID {
            issues.append(.init(code: "flow.flowId", path: "flow[\(flow.flowId)].flowId", message: "flow id must match AppSpec reference id \(expectedFlowID)"))
        }

        var screenIDs: Set<String> = []
        if flow.screens.isEmpty {
            issues.append(.init(code: "flow.screens", path: "flow[\(flow.flowId)].screens", message: "flow must declare at least one screen"))
        }

        for (index, deepLink) in flow.deepLinks.enumerated() {
            validateRoute(deepLink.route, path: "flow[\(flow.flowId)].deepLinks[\(index)].route", issues: &issues)
            validateIdentifier(deepLink.targetScreen, path: "flow[\(flow.flowId)].deepLinks[\(index)].targetScreen", label: "targetScreen", issues: &issues)
        }

        for (index, screenRef) in flow.screens.enumerated() {
            validateIdentifier(screenRef.id, path: "flow[\(flow.flowId)].screens[\(index)].id", label: "screen id", issues: &issues)
            if !screenIDs.insert(screenRef.id).inserted {
                issues.append(.init(code: "screen.duplicate", path: "flow[\(flow.flowId)].screens[\(index)].id", message: "screen ids must be unique within the flow"))
            }

            let screenURL = resolveReference(screenRef.path, contractRoot: contractRoot, relativeTo: flowURL)
            guard let screen = loadReferenced(ScreenSpec.self, at: screenURL, issuePath: "flow[\(flow.flowId)].screens[\(index)].path", original: screenRef.path, issues: &issues) else {
                continue
            }

            validateScreen(
                screen,
                screenURL: screenURL,
                expectedAppID: expectedAppID,
                expectedFlowID: flow.flowId,
                expectedScreenID: screenRef.id,
                registryItems: registryItems,
                motionPatternIDs: motionPatternIDs,
                reviewCheckIDs: reviewCheckIDs,
                issues: &issues
            )
        }

        if !screenIDs.contains(flow.entryScreen) {
            issues.append(.init(code: "flow.entryScreen", path: "flow[\(flow.flowId)].entryScreen", message: "entryScreen must reference one of the declared screens"))
        }

        for (index, transition) in flow.transitions.enumerated() {
            validateIdentifier(transition.from, path: "flow[\(flow.flowId)].transitions[\(index)].from", label: "transition source", issues: &issues)
            validateNonEmpty(transition.event, path: "flow[\(flow.flowId)].transitions[\(index)].event", message: "transition event must not be empty", issues: &issues)
            validateIdentifier(transition.to, path: "flow[\(flow.flowId)].transitions[\(index)].to", label: "transition target", issues: &issues)

            if !screenIDs.contains(transition.from) {
                issues.append(.init(code: "transition.from", path: "flow[\(flow.flowId)].transitions[\(index)].from", message: "transition source must reference a declared screen"))
            }
            if !screenIDs.contains(transition.to) {
                issues.append(.init(code: "transition.to", path: "flow[\(flow.flowId)].transitions[\(index)].to", message: "transition target must reference a declared screen"))
            }
        }
    }

    private func validateScreen(
        _ screen: ScreenSpec,
        screenURL: URL,
        expectedAppID: String,
        expectedFlowID: String,
        expectedScreenID: String,
        registryItems: [String: RegistryItem],
        motionPatternIDs: Set<String>,
        reviewCheckIDs: Set<String>,
        issues: inout [ValidationIssue]
    ) {
        let prefix = "screen[\(screen.screenId)]"

        validateSchemaVersion(screen.schemaVersion, expected: "2.1", path: "\(prefix).schemaVersion", issues: &issues)
        validateIdentifier(screen.appId, path: "\(prefix).appId", label: "appId", issues: &issues)
        validateIdentifier(screen.flowId, path: "\(prefix).flowId", label: "flowId", issues: &issues)
        validateIdentifier(screen.screenId, path: "\(prefix).screenId", label: "screenId", issues: &issues)
        validateNonEmpty(screen.title, path: "\(prefix).title", message: "title must not be empty", issues: &issues)
        validateRoute(screen.route, path: "\(prefix).route", issues: &issues)
        validatePlatformList(screen.targets, path: "\(prefix).targets", issues: &issues)
        validateAlias(screen.surface.backgroundColor, path: "\(prefix).surface.backgroundColor", issues: &issues)
        validateAlias(screen.surface.padding, path: "\(prefix).surface.padding", issues: &issues)

        if screen.appId != expectedAppID {
            issues.append(.init(code: "screen.appId", path: "\(prefix).appId", message: "screen appId must match parent app id \(expectedAppID)"))
        }
        if screen.flowId != expectedFlowID {
            issues.append(.init(code: "screen.flowId", path: "\(prefix).flowId", message: "screen flowId must match parent flow id \(expectedFlowID)"))
        }
        if screen.screenId != expectedScreenID {
            issues.append(.init(code: "screen.screenId", path: "\(prefix).screenId", message: "screen id must match FlowSpec reference id \(expectedScreenID)"))
        }

        let stateFieldMap = validateStateFields(screen.stateFields, path: "\(prefix).stateFields", issues: &issues)
        let actionIDs = validateActions(screen.actions, path: "\(prefix).actions", issues: &issues)
        let navigationIDs = validateNavigation(screen.navigation, path: "\(prefix).navigation", issues: &issues)
        _ = validateAssets(screen.assets, path: "\(prefix).assets", issues: &issues)

        let declaredStates = validateStringIDs(screen.states, path: "\(prefix).states", itemLabel: "state", issues: &issues)
        let previewIDs = validatePreviewStates(screen.previewStates, stateFields: stateFieldMap, path: "\(prefix).previewStates", issues: &issues)
        let missingPreviewStates = declaredStates.subtracting(previewIDs)
        for state in missingPreviewStates.sorted() {
            issues.append(.init(code: "preview.coverage", path: "\(prefix).previewStates", message: "missing preview state for declared state '\(state)'"))
        }

        for (index, motionRef) in screen.motion.enumerated() {
            validateNonEmpty(motionRef.patternId, path: "\(prefix).motion[\(index)].patternId", message: "patternId must not be empty", issues: &issues)
            validateNonEmpty(motionRef.trigger, path: "\(prefix).motion[\(index)].trigger", message: "trigger must not be empty", issues: &issues)
            if !motionPatternIDs.contains(motionRef.patternId) {
                issues.append(.init(code: "motion.pattern", path: "\(prefix).motion[\(index)].patternId", message: "unknown motion pattern id: \(motionRef.patternId)"))
            }
        }

        for (index, checkID) in screen.reviewChecklist.enumerated() {
            validateNonEmpty(checkID, path: "\(prefix).reviewChecklist[\(index)]", message: "review checklist id must not be empty", issues: &issues)
            if !reviewCheckIDs.contains(checkID) {
                issues.append(.init(code: "review.check", path: "\(prefix).reviewChecklist[\(index)]", message: "unknown review checklist id: \(checkID)"))
            }
        }

        validateLayoutNode(
            screen.layout,
            path: "\(prefix).layout",
            screenURL: screenURL,
            stateFields: stateFieldMap,
            actionIDs: actionIDs,
            navigationIDs: navigationIDs,
            registryItems: registryItems,
            issues: &issues
        )
    }

    private func validateLayoutNode(
        _ node: LayoutNode,
        path: String,
        screenURL: URL,
        stateFields: [String: StateField],
        actionIDs: Set<String>,
        navigationIDs: Set<String>,
        registryItems: [String: RegistryItem],
        issues: inout [ValidationIssue]
    ) {
        let allowedKinds: Set<String> = ["stack", "grid", "slot", "component", "conditional", "repeat"]
        let containerKinds: Set<String> = ["stack", "grid", "slot", "conditional", "repeat"]

        if !allowedKinds.contains(node.kind) {
            issues.append(.init(code: "layout.kind", path: "\(path).kind", message: "unsupported layout kind: \(node.kind)"))
        }

        if let spacing = node.spacing {
            validateAlias(spacing, path: "\(path).spacing", issues: &issues)
        }

        if node.kind == "component" {
            guard let componentID = node.componentId?.trimmingCharacters(in: .whitespacesAndNewlines), !componentID.isEmpty else {
                issues.append(.init(code: "layout.componentId", path: "\(path).componentId", message: "component nodes require componentId"))
                return
            }

            guard let item = registryItems[componentID] else {
                issues.append(.init(code: "layout.componentReference", path: "\(path).componentId", message: "unknown registry item id: \(componentID)"))
                return
            }

            if !node.children.isEmpty {
                issues.append(.init(code: "layout.componentChildren", path: "\(path).children", message: "component nodes must not declare children"))
            }

            validateComponentProps(node.props, item: item, path: path, issues: &issues)
            validateBindings(
                node.bindings,
                path: "\(path).bindings",
                stateFields: stateFields,
                actionIDs: actionIDs,
                navigationIDs: navigationIDs,
                component: item,
                issues: &issues
            )
        } else if containerKinds.contains(node.kind) {
            if node.kind == "grid", let columns = node.columns, columns < 1 {
                issues.append(.init(code: "layout.columns", path: "\(path).columns", message: "grid columns must be at least 1"))
            }
            for (index, child) in node.children.enumerated() {
                validateLayoutNode(
                    child,
                    path: "\(path).children[\(index)]",
                    screenURL: screenURL,
                    stateFields: stateFields,
                    actionIDs: actionIDs,
                    navigationIDs: navigationIDs,
                    registryItems: registryItems,
                    issues: &issues
                )
            }
        }
    }

    private func validateComponentProps(
        _ props: [String: JSONValue],
        item: RegistryItem,
        path: String,
        issues: inout [ValidationIssue]
    ) {
        let allowedProps = Dictionary(uniqueKeysWithValues: item.allowedProps.map { ($0.name, $0) })

        for requiredProp in item.allowedProps where requiredProp.required && props[requiredProp.name] == nil {
            issues.append(.init(code: "prop.required", path: "\(path).props.\(requiredProp.name)", message: "missing required prop '\(requiredProp.name)' for \(item.id)"))
        }

        for (propName, value) in props {
            guard let definition = allowedProps[propName] else {
                issues.append(.init(code: "prop.unknown", path: "\(path).props.\(propName)", message: "unknown prop '\(propName)' for \(item.id)"))
                continue
            }

            switch definition.type {
            case "string", "imageRef", "iconRef":
                if !isJSONString(value) {
                    issues.append(.init(code: "prop.type", path: "\(path).props.\(propName)", message: "prop '\(propName)' for \(item.id) must be a string"))
                }
            case "boolean":
                if !isJSONBool(value) {
                    issues.append(.init(code: "prop.type", path: "\(path).props.\(propName)", message: "prop '\(propName)' for \(item.id) must be a boolean"))
                }
            case "enum":
                guard case .string(let rawValue) = value else {
                    issues.append(.init(code: "prop.type", path: "\(path).props.\(propName)", message: "prop '\(propName)' for \(item.id) must be a string enum"))
                    continue
                }
                if !definition.allowedValues.isEmpty, !definition.allowedValues.contains(rawValue) {
                    issues.append(.init(code: "prop.enum", path: "\(path).props.\(propName)", message: "prop '\(propName)' for \(item.id) must be one of \(definition.allowedValues.joined(separator: ", "))"))
                }
            case "token":
                guard case .string(let rawValue) = value else {
                    issues.append(.init(code: "prop.type", path: "\(path).props.\(propName)", message: "token prop '\(propName)' for \(item.id) must be a string alias"))
                    continue
                }
                validateAlias(rawValue, path: "\(path).props.\(propName)", issues: &issues)
            default:
                issues.append(.init(code: "prop.definition", path: "\(path).props.\(propName)", message: "unsupported prop type '\(definition.type)' in registry item \(item.id)"))
            }
        }
    }

    private func validateBindings(
        _ bindings: [LayoutBinding],
        path: String,
        stateFields: [String: StateField],
        actionIDs: Set<String>,
        navigationIDs: Set<String>,
        component: RegistryItem,
        issues: inout [ValidationIssue]
    ) {
        let boundFields = Set(bindings.map(\.field))

        for requiredField in component.stateRequirements?.fields ?? [] {
            if !boundFields.contains(requiredField) {
                issues.append(.init(code: "binding.required-field", path: path, message: "\(component.id) requires a binding for field '\(requiredField)'"))
            }
        }

        for requiredAction in component.stateRequirements?.actions ?? [] where !actionIDs.contains(requiredAction) {
            issues.append(.init(code: "binding.required-action", path: path, message: "\(component.id) requires declared action '\(requiredAction)'"))
        }

        for requiredNavigation in component.stateRequirements?.navigation ?? [] where !navigationIDs.contains(requiredNavigation) {
            issues.append(.init(code: "binding.required-navigation", path: path, message: "\(component.id) requires declared navigation '\(requiredNavigation)'"))
        }

        for (index, binding) in bindings.enumerated() {
            if stateFields[binding.field] == nil {
                issues.append(.init(code: "binding.field", path: "\(path)[\(index)].field", message: "unknown state field '\(binding.field)'"))
            }

            if let action = binding.action, !action.isEmpty, !actionIDs.contains(action) {
                issues.append(.init(code: "binding.action", path: "\(path)[\(index)].action", message: "unknown action '\(action)'"))
            }

            if let navigation = binding.navigation, !navigation.isEmpty, !navigationIDs.contains(navigation) {
                issues.append(.init(code: "binding.navigation", path: "\(path)[\(index)].navigation", message: "unknown navigation '\(navigation)'"))
            }
        }
    }

    private func validateRegistry(_ registry: ComponentRegistry?, issues: inout [ValidationIssue]) -> [String: RegistryItem] {
        guard let registry else { return [:] }

        validateSchemaVersion(registry.schemaVersion, expected: "2.1", path: "registry.schemaVersion", issues: &issues)
        validateNonEmpty(registry.registryId, path: "registry.registryId", message: "registryId must not be empty", issues: &issues)
        validateNonEmpty(registry.namespace, path: "registry.namespace", message: "namespace must not be empty", issues: &issues)

        var items: [String: RegistryItem] = [:]
        let allowedKinds: Set<String> = ["primitive", "mobile", "flow-shell"]
        let allowedPropTypes: Set<String> = ["string", "boolean", "enum", "token", "imageRef", "iconRef"]

        for (index, item) in registry.items.enumerated() {
            validateIdentifier(item.id, path: "registry.items[\(index)].id", label: "registry item id", issues: &issues)
            if items[item.id] != nil {
                issues.append(.init(code: "registry.item.duplicate", path: "registry.items[\(index)].id", message: "registry item ids must be unique"))
            } else {
                items[item.id] = item
            }

            if !allowedKinds.contains(item.kind) {
                issues.append(.init(code: "registry.item.kind", path: "registry.items[\(index)].kind", message: "unsupported registry item kind: \(item.kind)"))
            }
            if item.web.source != "private-shadcn-registry" {
                issues.append(.init(code: "registry.item.web.source", path: "registry.items[\(index)].web.source", message: "web source must be private-shadcn-registry"))
            }
            validateNonEmpty(item.web.importPath, path: "registry.items[\(index)].web.importPath", message: "importPath must not be empty", issues: &issues)
            validateNonEmpty(item.web.exportName, path: "registry.items[\(index)].web.exportName", message: "exportName must not be empty", issues: &issues)
            validateNonEmpty(item.native.ios.component, path: "registry.items[\(index)].native.ios.component", message: "iOS component must not be empty", issues: &issues)
            validateNonEmpty(item.native.android.component, path: "registry.items[\(index)].native.android.component", message: "Android component must not be empty", issues: &issues)

            var propNames: Set<String> = []
            for (propIndex, prop) in item.allowedProps.enumerated() {
                validateNonEmpty(prop.name, path: "registry.items[\(index)].allowedProps[\(propIndex)].name", message: "prop name must not be empty", issues: &issues)
                if !propNames.insert(prop.name).inserted {
                    issues.append(.init(code: "registry.prop.duplicate", path: "registry.items[\(index)].allowedProps[\(propIndex)].name", message: "allowed prop names must be unique"))
                }
                if !allowedPropTypes.contains(prop.type) {
                    issues.append(.init(code: "registry.prop.type", path: "registry.items[\(index)].allowedProps[\(propIndex)].type", message: "unsupported registry prop type: \(prop.type)"))
                }
                if prop.type == "enum", prop.allowedValues.isEmpty {
                    issues.append(.init(code: "registry.prop.enum", path: "registry.items[\(index)].allowedProps[\(propIndex)].allowedValues", message: "enum props must declare allowedValues"))
                }
            }
        }

        return items
    }

    private func validateMotion(_ motion: MotionSpec?, issues: inout [ValidationIssue]) -> Set<String> {
        guard let motion else { return [] }

        validateSchemaVersion(motion.schemaVersion, expected: "2.1", path: "motion.schemaVersion", issues: &issues)
        validateNonEmpty(motion.motionSetId, path: "motion.motionSetId", message: "motionSetId must not be empty", issues: &issues)

        let durationIDs = Set(motion.durations.map(\.id))
        let easingIDs = Set(motion.easings.map(\.id))
        var patternIDs: Set<String> = []

        for (index, pattern) in motion.patterns.enumerated() {
            validateNonEmpty(pattern.id, path: "motion.patterns[\(index)].id", message: "pattern id must not be empty", issues: &issues)
            if !patternIDs.insert(pattern.id).inserted {
                issues.append(.init(code: "motion.pattern.duplicate", path: "motion.patterns[\(index)].id", message: "motion pattern ids must be unique"))
            }
            validateNonEmpty(pattern.trigger, path: "motion.patterns[\(index)].trigger", message: "pattern trigger must not be empty", issues: &issues)
            validateNonEmpty(pattern.enter, path: "motion.patterns[\(index)].enter", message: "enter motion must not be empty", issues: &issues)
            validateNonEmpty(pattern.exit, path: "motion.patterns[\(index)].exit", message: "exit motion must not be empty", issues: &issues)
            validateNonEmpty(pattern.reducedMotion, path: "motion.patterns[\(index)].reducedMotion", message: "reducedMotion fallback must not be empty", issues: &issues)

            if !durationIDs.contains(pattern.durationToken) {
                issues.append(.init(code: "motion.durationToken", path: "motion.patterns[\(index)].durationToken", message: "unknown duration token '\(pattern.durationToken)'"))
            }
            if !easingIDs.contains(pattern.easingToken) {
                issues.append(.init(code: "motion.easingToken", path: "motion.patterns[\(index)].easingToken", message: "unknown easing token '\(pattern.easingToken)'"))
            }
        }

        return patternIDs
    }

    private func validateReview(_ review: ReviewChecklist?, issues: inout [ValidationIssue]) -> Set<String> {
        guard let review else { return [] }

        validateSchemaVersion(review.schemaVersion, expected: "2.1", path: "review.schemaVersion", issues: &issues)
        validateNonEmpty(review.reviewSetId, path: "review.reviewSetId", message: "reviewSetId must not be empty", issues: &issues)

        let allowedCategories: Set<String> = ["structure", "semantics", "tokens", "motion", "native-viability"]
        var checkIDs: Set<String> = []

        for (index, check) in review.checks.enumerated() {
            validateNonEmpty(check.id, path: "review.checks[\(index)].id", message: "check id must not be empty", issues: &issues)
            if !checkIDs.insert(check.id).inserted {
                issues.append(.init(code: "review.check.duplicate", path: "review.checks[\(index)].id", message: "review check ids must be unique"))
            }
            if !allowedCategories.contains(check.category) {
                issues.append(.init(code: "review.check.category", path: "review.checks[\(index)].category", message: "unsupported review category: \(check.category)"))
            }
            validateNonEmpty(check.description, path: "review.checks[\(index)].description", message: "description must not be empty", issues: &issues)
        }

        return checkIDs
    }

    private func validateStateFields(_ fields: [StateField], path: String, issues: inout [ValidationIssue]) -> [String: StateField] {
        let allowedTypes: Set<String> = ["string", "boolean", "integer", "number", "enum"]
        var result: [String: StateField] = [:]

        for (index, field) in fields.enumerated() {
            validateNonEmpty(field.id, path: "\(path)[\(index)].id", message: "state field id must not be empty", issues: &issues)
            if result[field.id] != nil {
                issues.append(.init(code: "stateField.duplicate", path: "\(path)[\(index)].id", message: "state field ids must be unique"))
                continue
            }
            if !allowedTypes.contains(field.type) {
                issues.append(.init(code: "stateField.type", path: "\(path)[\(index)].type", message: "unsupported state field type: \(field.type)"))
            } else if let defaultValue = field.defaultValue, !isCompatible(defaultValue, with: field.type) {
                issues.append(.init(code: "stateField.defaultValue", path: "\(path)[\(index)].defaultValue", message: "defaultValue does not match type \(field.type)"))
            }
            result[field.id] = field
        }

        return result
    }

    private func validateActions(_ actions: [Action], path: String, issues: inout [ValidationIssue]) -> Set<String> {
        var result: Set<String> = []

        for (index, action) in actions.enumerated() {
            validateNonEmpty(action.id, path: "\(path)[\(index)].id", message: "action id must not be empty", issues: &issues)
            if !result.insert(action.id).inserted {
                issues.append(.init(code: "action.duplicate", path: "\(path)[\(index)].id", message: "action ids must be unique"))
            }
        }

        return result
    }

    private func validateNavigation(_ navigation: [Navigation], path: String, issues: inout [ValidationIssue]) -> Set<String> {
        var result: Set<String> = []

        for (index, item) in navigation.enumerated() {
            validateNonEmpty(item.id, path: "\(path)[\(index)].id", message: "navigation id must not be empty", issues: &issues)
            if !result.insert(item.id).inserted {
                issues.append(.init(code: "navigation.duplicate", path: "\(path)[\(index)].id", message: "navigation ids must be unique"))
            }
            validateRoute(item.route, path: "\(path)[\(index)].route", issues: &issues)
        }

        return result
    }

    private func validateAssets(_ assets: [Asset], path: String, issues: inout [ValidationIssue]) -> Set<String> {
        let allowedKinds: Set<String> = ["image", "icon", "video", "lottie"]
        var result: Set<String> = []

        for (index, asset) in assets.enumerated() {
            validateNonEmpty(asset.name, path: "\(path)[\(index)].name", message: "asset name must not be empty", issues: &issues)
            if !result.insert(asset.name).inserted {
                issues.append(.init(code: "asset.duplicate", path: "\(path)[\(index)].name", message: "asset names must be unique"))
            }
            if !allowedKinds.contains(asset.kind) {
                issues.append(.init(code: "asset.kind", path: "\(path)[\(index)].kind", message: "unsupported asset kind: \(asset.kind)"))
            }
        }

        return result
    }

    private func validatePreviewStates(
        _ previewStates: [PreviewState],
        stateFields: [String: StateField],
        path: String,
        issues: inout [ValidationIssue]
    ) -> Set<String> {
        var ids: Set<String> = []

        for (index, previewState) in previewStates.enumerated() {
            validateNonEmpty(previewState.id, path: "\(path)[\(index)].id", message: "preview state id must not be empty", issues: &issues)
            if !ids.insert(previewState.id).inserted {
                issues.append(.init(code: "previewState.duplicate", path: "\(path)[\(index)].id", message: "preview state ids must be unique"))
            }

            for (fieldID, value) in previewState.values {
                guard let definition = stateFields[fieldID] else {
                    issues.append(.init(code: "previewState.field", path: "\(path)[\(index)].values.\(fieldID)", message: "unknown state field '\(fieldID)'"))
                    continue
                }
                if !isCompatible(value, with: definition.type) {
                    issues.append(.init(code: "previewState.value", path: "\(path)[\(index)].values.\(fieldID)", message: "preview value does not match state field type \(definition.type)"))
                }
            }
        }

        return ids
    }

    private func validateDistinctStrings(_ values: [String], path: String, itemLabel: String, issues: inout [ValidationIssue]) {
        _ = validateStringIDs(values, path: path, itemLabel: itemLabel, issues: &issues)
    }

    private func validateStringIDs(_ values: [String], path: String, itemLabel: String, issues: inout [ValidationIssue]) -> Set<String> {
        var result: Set<String> = []

        for (index, value) in values.enumerated() {
            validateNonEmpty(value, path: "\(path)[\(index)]", message: "\(itemLabel) must not be empty", issues: &issues)
            if !result.insert(value).inserted {
                issues.append(.init(code: "\(itemLabel).duplicate", path: "\(path)[\(index)]", message: "\(itemLabel) values must be unique"))
            }
        }

        return result
    }

    private func validatePlatformList(_ platforms: [Platform], path: String, issues: inout [ValidationIssue]) {
        let rawValues = platforms.map(\.rawValue)
        if rawValues.isEmpty {
            issues.append(.init(code: "platforms.empty", path: path, message: "platform list must not be empty"))
        }
        if Set(rawValues).count != rawValues.count {
            issues.append(.init(code: "platforms.duplicate", path: path, message: "platform list must be unique"))
        }
    }

    private func validateExistingPath(_ url: URL, path: String, original: String, issues: inout [ValidationIssue]) {
        guard fileManager.fileExists(atPath: url.path) else {
            issues.append(.init(code: "path.missing", path: path, message: "missing referenced file: \(original)"))
            return
        }
    }

    private func validateSchemaVersion(_ value: String, expected: String, path: String, issues: inout [ValidationIssue]) {
        if value != expected {
            issues.append(.init(code: "schemaVersion", path: path, message: "schemaVersion must be \(expected)"))
        }
    }

    private func validateIdentifier(_ value: String, path: String, label: String, issues: inout [ValidationIssue]) {
        if !Self.identifierPattern.matches(in: value, options: [], range: NSRange(location: 0, length: value.utf16.count)).isEmpty {
            return
        }
        issues.append(.init(code: "identifier", path: path, message: "\(label) must match ^[a-z0-9]+(?:-[a-z0-9]+)*$"))
    }

    private func validateNonEmpty(_ value: String, path: String, message: String, issues: inout [ValidationIssue]) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(code: "empty", path: path, message: message))
        }
    }

    private func validateRoute(_ route: String, path: String, issues: inout [ValidationIssue]) {
        if route.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !route.hasPrefix("/") || route.contains(" ") {
            issues.append(.init(code: "route", path: path, message: "route must start with '/' and contain no spaces"))
        }
    }

    private func validateAlias(_ alias: String, path: String, issues: inout [ValidationIssue]) {
        guard TokenStore.path(fromAlias: alias) != nil else {
            issues.append(.init(code: "token.alias", path: path, message: "expected token alias format like {color.surface.canvas}"))
            return
        }
    }

    private func isCompatible(_ value: JSONValue, with type: String) -> Bool {
        switch type {
        case "string", "enum":
            if case .string = value { return true }
            return false
        case "boolean":
            if case .bool = value { return true }
            return false
        case "integer":
            if case .integer = value { return true }
            return false
        case "number":
            if case .integer = value { return true }
            if case .double = value { return true }
            return false
        default:
            return false
        }
    }

    private func isJSONString(_ value: JSONValue) -> Bool {
        if case .string = value {
            return true
        }
        return false
    }

    private func isJSONBool(_ value: JSONValue) -> Bool {
        if case .bool = value {
            return true
        }
        return false
    }

    private func loadReferenced<T: Decodable>(
        _ type: T.Type,
        at url: URL,
        issuePath: String,
        original: String,
        issues: inout [ValidationIssue]
    ) -> T? {
        guard fileManager.fileExists(atPath: url.path) else {
            issues.append(.init(code: "path.missing", path: issuePath, message: "missing referenced file: \(original)"))
            return nil
        }

        do {
            return try loader.load(T.self, from: url)
        } catch {
            issues.append(.init(code: "decode", path: issuePath, message: "failed to load \(original): \(error.localizedDescription)"))
            return nil
        }
    }

    func resolveContractRoot(startingAt directory: URL) -> URL {
        var current = directory.standardizedFileURL
        while true {
            if fileManager.fileExists(atPath: current.appendingPathComponent("MASTER_BLUEPRINT.md").path) {
                return current
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }

        return URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true).standardizedFileURL
    }

    func resolveReference(_ rawPath: String, contractRoot: URL, relativeTo sourceURL: URL) -> URL {
        let standardized = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if standardized.hasPrefix("/") {
            return URL(fileURLWithPath: standardized).standardizedFileURL
        }

        let rootCandidate = contractRoot.appendingPathComponent(standardized).standardizedFileURL
        if fileManager.fileExists(atPath: rootCandidate.path) {
            return rootCandidate
        }

        let sourceDirectory = sourceURL.deletingLastPathComponent()
        let localCandidate = sourceDirectory.appendingPathComponent(standardized).standardizedFileURL
        if fileManager.fileExists(atPath: localCandidate.path) {
            return localCandidate
        }

        return rootCandidate
    }

    private func discoverAppSpecs(contractRoot: URL) throws -> [(url: URL, spec: AppSpec)] {
        try discoverDocuments(
            contractRoot: contractRoot,
            suffixes: [".app.yaml", ".app.yml", ".app.json"],
            as: AppSpec.self
        )
    }

    private func discoverFlowSpecs(contractRoot: URL) throws -> [(url: URL, spec: FlowSpec)] {
        try discoverDocuments(
            contractRoot: contractRoot,
            suffixes: [".flow.yaml", ".flow.yml", ".flow.json"],
            as: FlowSpec.self
        )
    }

    private func discoverDocuments<T: Decodable>(
        contractRoot: URL,
        suffixes: [String],
        as type: T.Type
    ) throws -> [(url: URL, spec: T)] {
        guard let enumerator = fileManager.enumerator(
            at: contractRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [(url: URL, spec: T)] = []
        for case let url as URL in enumerator {
            guard suffixes.contains(where: { url.lastPathComponent.hasSuffix($0) }) else { continue }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            if let decoded = try? loader.load(T.self, from: url) {
                results.append((url.standardizedFileURL, decoded))
            }
        }
        return results.sorted { $0.url.path < $1.url.path }
    }

    private func resolveParentApp(
        for flowSpec: FlowSpec,
        flowURL: URL,
        appSpecs: [(url: URL, spec: AppSpec)],
        contractRoot: URL,
        issues: inout [ValidationIssue]
    ) -> (url: URL, spec: AppSpec)? {
        let exactMatches = appSpecs.filter { candidate in
            candidate.spec.appId == flowSpec.appId &&
            candidate.spec.flows.contains { ref in
                resolveReference(ref.path, contractRoot: contractRoot, relativeTo: candidate.url).standardizedFileURL.path == flowURL.standardizedFileURL.path
            }
        }

        if exactMatches.count == 1 {
            return exactMatches[0]
        }
        if exactMatches.count > 1 {
            issues.append(.init(code: "app.parent.ambiguous", path: "flow[\(flowSpec.flowId)].appId", message: "multiple AppSpec files reference this FlowSpec"))
            return nil
        }

        let idMatches = appSpecs.filter { candidate in
            candidate.spec.appId == flowSpec.appId &&
            candidate.spec.flows.contains { $0.id == flowSpec.flowId }
        }

        if idMatches.count == 1 {
            return idMatches[0]
        }
        if idMatches.count > 1 {
            issues.append(.init(code: "app.parent.ambiguous", path: "flow[\(flowSpec.flowId)].appId", message: "multiple AppSpec files match this flow id"))
            return nil
        }

        issues.append(.init(code: "app.parent.missing", path: "flow[\(flowSpec.flowId)].appId", message: "could not resolve a parent AppSpec for this FlowSpec"))
        return nil
    }

    private func resolveParentFlow(
        for screenSpec: ScreenSpec,
        screenURL: URL,
        flowSpecs: [(url: URL, spec: FlowSpec)],
        contractRoot: URL,
        issues: inout [ValidationIssue]
    ) -> (url: URL, spec: FlowSpec)? {
        let exactMatches = flowSpecs.filter { candidate in
            candidate.spec.appId == screenSpec.appId &&
            candidate.spec.flowId == screenSpec.flowId &&
            candidate.spec.screens.contains { ref in
                resolveReference(ref.path, contractRoot: contractRoot, relativeTo: candidate.url).standardizedFileURL.path == screenURL.standardizedFileURL.path
            }
        }

        if exactMatches.count == 1 {
            return exactMatches[0]
        }
        if exactMatches.count > 1 {
            issues.append(.init(code: "flow.parent.ambiguous", path: "screen[\(screenSpec.screenId)].flowId", message: "multiple FlowSpec files reference this ScreenSpec"))
            return nil
        }

        let idMatches = flowSpecs.filter { candidate in
            candidate.spec.appId == screenSpec.appId &&
            candidate.spec.flowId == screenSpec.flowId &&
            candidate.spec.screens.contains { $0.id == screenSpec.screenId }
        }

        if idMatches.count == 1 {
            return idMatches[0]
        }
        if idMatches.count > 1 {
            issues.append(.init(code: "flow.parent.ambiguous", path: "screen[\(screenSpec.screenId)].flowId", message: "multiple FlowSpec files match this screen id"))
            return nil
        }

        issues.append(.init(code: "flow.parent.missing", path: "screen[\(screenSpec.screenId)].flowId", message: "could not resolve a parent FlowSpec for this ScreenSpec"))
        return nil
    }

    private static let identifierPattern = try! NSRegularExpression(pattern: "^[a-z0-9]+(?:-[a-z0-9]+)*$")
}
