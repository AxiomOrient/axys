import Foundation

public struct V2AppSpec: Codable, Sendable {
    public let schemaVersion: String
    public let appId: String
    public let title: String
    public let description: String?
    public let brands: [String]
    public let targetPlatforms: [Platform]
    public let tokenSet: String
    public let componentRegistry: String
    public let motionSet: String
    public let reviewSet: String
    public let sampleApps: V2SampleApps?
    public let reviewBenchmarks: [V2BenchmarkReference]
    public let flows: [V2FlowReference]

    public init(
        schemaVersion: String,
        appId: String,
        title: String,
        description: String? = nil,
        brands: [String] = [],
        targetPlatforms: [Platform],
        tokenSet: String,
        componentRegistry: String,
        motionSet: String,
        reviewSet: String,
        sampleApps: V2SampleApps? = nil,
        reviewBenchmarks: [V2BenchmarkReference] = [],
        flows: [V2FlowReference]
    ) {
        self.schemaVersion = schemaVersion
        self.appId = appId
        self.title = title
        self.description = description
        self.brands = brands
        self.targetPlatforms = targetPlatforms
        self.tokenSet = tokenSet
        self.componentRegistry = componentRegistry
        self.motionSet = motionSet
        self.reviewSet = reviewSet
        self.sampleApps = sampleApps
        self.reviewBenchmarks = reviewBenchmarks
        self.flows = flows
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case appId
        case title
        case description
        case brands
        case targetPlatforms
        case tokenSet
        case componentRegistry
        case motionSet
        case reviewSet
        case sampleApps
        case reviewBenchmarks
        case flows
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        appId = try container.decode(String.self, forKey: .appId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        brands = try container.decodeIfPresent([String].self, forKey: .brands) ?? []
        targetPlatforms = try container.decode([Platform].self, forKey: .targetPlatforms)
        tokenSet = try container.decode(String.self, forKey: .tokenSet)
        componentRegistry = try container.decode(String.self, forKey: .componentRegistry)
        motionSet = try container.decode(String.self, forKey: .motionSet)
        reviewSet = try container.decode(String.self, forKey: .reviewSet)
        sampleApps = try container.decodeIfPresent(V2SampleApps.self, forKey: .sampleApps)
        reviewBenchmarks = try container.decodeIfPresent([V2BenchmarkReference].self, forKey: .reviewBenchmarks) ?? []
        flows = try container.decode([V2FlowReference].self, forKey: .flows)
    }
}

public struct V2SampleApps: Codable, Sendable {
    public let ios: String?
    public let android: String?

    public init(ios: String? = nil, android: String? = nil) {
        self.ios = ios
        self.android = android
    }
}

public struct V2BenchmarkReference: Codable, Sendable {
    public let source: String
    public let url: String
    public let tags: [String]

    public init(source: String, url: String, tags: [String] = []) {
        self.source = source
        self.url = url
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case source
        case url
        case tags
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(String.self, forKey: .source)
        url = try container.decode(String.self, forKey: .url)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

public struct V2FlowReference: Codable, Sendable {
    public let id: String
    public let path: String

    public init(id: String, path: String) {
        self.id = id
        self.path = path
    }
}

public struct V2FlowSpec: Codable, Sendable {
    public let schemaVersion: String
    public let appId: String
    public let flowId: String
    public let title: String
    public let entryScreen: String
    public let deepLinks: [V2DeepLink]
    public let screens: [V2ScreenReference]
    public let transitions: [V2FlowTransition]

    public init(
        schemaVersion: String,
        appId: String,
        flowId: String,
        title: String,
        entryScreen: String,
        deepLinks: [V2DeepLink] = [],
        screens: [V2ScreenReference],
        transitions: [V2FlowTransition]
    ) {
        self.schemaVersion = schemaVersion
        self.appId = appId
        self.flowId = flowId
        self.title = title
        self.entryScreen = entryScreen
        self.deepLinks = deepLinks
        self.screens = screens
        self.transitions = transitions
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case appId
        case flowId
        case title
        case entryScreen
        case deepLinks
        case screens
        case transitions
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        appId = try container.decode(String.self, forKey: .appId)
        flowId = try container.decode(String.self, forKey: .flowId)
        title = try container.decode(String.self, forKey: .title)
        entryScreen = try container.decode(String.self, forKey: .entryScreen)
        deepLinks = try container.decodeIfPresent([V2DeepLink].self, forKey: .deepLinks) ?? []
        screens = try container.decode([V2ScreenReference].self, forKey: .screens)
        transitions = try container.decode([V2FlowTransition].self, forKey: .transitions)
    }
}

public struct V2DeepLink: Codable, Sendable {
    public let route: String
    public let targetScreen: String

    public init(route: String, targetScreen: String) {
        self.route = route
        self.targetScreen = targetScreen
    }
}

public struct V2ScreenReference: Codable, Sendable {
    public let id: String
    public let path: String
    public let role: String?

    public init(id: String, path: String, role: String? = nil) {
        self.id = id
        self.path = path
        self.role = role
    }
}

public struct V2FlowTransition: Codable, Sendable {
    public let from: String
    public let event: String
    public let to: String
    public let guardCondition: String?
    public let effect: String?

    public init(from: String, event: String, to: String, guardCondition: String? = nil, effect: String? = nil) {
        self.from = from
        self.event = event
        self.to = to
        self.guardCondition = guardCondition
        self.effect = effect
    }

    private enum CodingKeys: String, CodingKey {
        case from
        case event
        case to
        case guardCondition = "guard"
        case effect
    }
}

public struct V2ScreenSpec: Codable, Sendable {
    public let schemaVersion: String
    public let appId: String
    public let flowId: String
    public let screenId: String
    public let title: String
    public let route: String
    public let targets: [Platform]
    public let intent: String?
    public let surface: V2ScreenSurface
    public let states: [String]
    public let stateFields: [V2StateField]
    public let actions: [V2Action]
    public let navigation: [V2Navigation]
    public let assets: [V2Asset]
    public let previewStates: [V2PreviewState]
    public let motion: [V2MotionReference]
    public let reviewChecklist: [String]
    public let layout: V2LayoutNode

    public init(
        schemaVersion: String,
        appId: String,
        flowId: String,
        screenId: String,
        title: String,
        route: String,
        targets: [Platform],
        intent: String? = nil,
        surface: V2ScreenSurface,
        states: [String],
        stateFields: [V2StateField] = [],
        actions: [V2Action] = [],
        navigation: [V2Navigation] = [],
        assets: [V2Asset] = [],
        previewStates: [V2PreviewState],
        motion: [V2MotionReference] = [],
        reviewChecklist: [String] = [],
        layout: V2LayoutNode
    ) {
        self.schemaVersion = schemaVersion
        self.appId = appId
        self.flowId = flowId
        self.screenId = screenId
        self.title = title
        self.route = route
        self.targets = targets
        self.intent = intent
        self.surface = surface
        self.states = states
        self.stateFields = stateFields
        self.actions = actions
        self.navigation = navigation
        self.assets = assets
        self.previewStates = previewStates
        self.motion = motion
        self.reviewChecklist = reviewChecklist
        self.layout = layout
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case appId
        case flowId
        case screenId
        case title
        case route
        case targets
        case intent
        case surface
        case states
        case stateFields
        case actions
        case navigation
        case assets
        case previewStates
        case motion
        case reviewChecklist
        case layout
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        appId = try container.decode(String.self, forKey: .appId)
        flowId = try container.decode(String.self, forKey: .flowId)
        screenId = try container.decode(String.self, forKey: .screenId)
        title = try container.decode(String.self, forKey: .title)
        route = try container.decode(String.self, forKey: .route)
        targets = try container.decode([Platform].self, forKey: .targets)
        intent = try container.decodeIfPresent(String.self, forKey: .intent)
        surface = try container.decode(V2ScreenSurface.self, forKey: .surface)
        states = try container.decode([String].self, forKey: .states)
        stateFields = try container.decodeIfPresent([V2StateField].self, forKey: .stateFields) ?? []
        actions = try container.decodeIfPresent([V2Action].self, forKey: .actions) ?? []
        navigation = try container.decodeIfPresent([V2Navigation].self, forKey: .navigation) ?? []
        assets = try container.decodeIfPresent([V2Asset].self, forKey: .assets) ?? []
        previewStates = try container.decode([V2PreviewState].self, forKey: .previewStates)
        motion = try container.decodeIfPresent([V2MotionReference].self, forKey: .motion) ?? []
        reviewChecklist = try container.decodeIfPresent([String].self, forKey: .reviewChecklist) ?? []
        layout = try container.decode(V2LayoutNode.self, forKey: .layout)
    }
}

public struct V2ScreenSurface: Codable, Sendable {
    public let backgroundColor: String
    public let padding: String

    public init(backgroundColor: String, padding: String) {
        self.backgroundColor = backgroundColor
        self.padding = padding
    }
}

public struct V2StateField: Codable, Sendable {
    public let id: String
    public let type: String
    public let defaultValue: JSONValue?

    public init(id: String, type: String, defaultValue: JSONValue? = nil) {
        self.id = id
        self.type = type
        self.defaultValue = defaultValue
    }
}

public struct V2Action: Codable, Sendable {
    public let id: String
    public let kind: String?

    public init(id: String, kind: String? = nil) {
        self.id = id
        self.kind = kind
    }
}

public struct V2Navigation: Codable, Sendable {
    public let id: String
    public let route: String

    public init(id: String, route: String) {
        self.id = id
        self.route = route
    }
}

public struct V2Asset: Codable, Sendable {
    public let name: String
    public let kind: String

    public init(name: String, kind: String) {
        self.name = name
        self.kind = kind
    }
}

public struct V2PreviewState: Codable, Sendable {
    public let id: String
    public let values: [String: JSONValue]
    public let note: String?

    public init(id: String, values: [String: JSONValue] = [:], note: String? = nil) {
        self.id = id
        self.values = values
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case values
        case note
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        values = try container.decodeIfPresent([String: JSONValue].self, forKey: .values) ?? [:]
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}

public struct V2MotionReference: Codable, Sendable {
    public let patternId: String
    public let trigger: String

    public init(patternId: String, trigger: String) {
        self.patternId = patternId
        self.trigger = trigger
    }
}

public struct V2LayoutBinding: Codable, Sendable {
    public let field: String
    public let action: String?
    public let navigation: String?

    public init(field: String, action: String? = nil, navigation: String? = nil) {
        self.field = field
        self.action = action
        self.navigation = navigation
    }
}

public struct V2LayoutNode: Codable, Sendable {
    public let kind: String
    public let id: String?
    public let direction: String?
    public let spacing: String?
    public let columns: Int?
    public let slot: String?
    public let componentId: String?
    public let stateGuard: String?
    public let repeatSource: String?
    public let props: [String: JSONValue]
    public let bindings: [V2LayoutBinding]
    public let children: [V2LayoutNode]

    public init(
        kind: String,
        id: String? = nil,
        direction: String? = nil,
        spacing: String? = nil,
        columns: Int? = nil,
        slot: String? = nil,
        componentId: String? = nil,
        stateGuard: String? = nil,
        repeatSource: String? = nil,
        props: [String: JSONValue] = [:],
        bindings: [V2LayoutBinding] = [],
        children: [V2LayoutNode] = []
    ) {
        self.kind = kind
        self.id = id
        self.direction = direction
        self.spacing = spacing
        self.columns = columns
        self.slot = slot
        self.componentId = componentId
        self.stateGuard = stateGuard
        self.repeatSource = repeatSource
        self.props = props
        self.bindings = bindings
        self.children = children
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case id
        case direction
        case spacing
        case columns
        case slot
        case componentId
        case stateGuard
        case repeatSource
        case props
        case bindings
        case children
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(String.self, forKey: .kind)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        direction = try container.decodeIfPresent(String.self, forKey: .direction)
        spacing = try container.decodeIfPresent(String.self, forKey: .spacing)
        columns = try container.decodeIfPresent(Int.self, forKey: .columns)
        slot = try container.decodeIfPresent(String.self, forKey: .slot)
        componentId = try container.decodeIfPresent(String.self, forKey: .componentId)
        stateGuard = try container.decodeIfPresent(String.self, forKey: .stateGuard)
        repeatSource = try container.decodeIfPresent(String.self, forKey: .repeatSource)
        props = try container.decodeIfPresent([String: JSONValue].self, forKey: .props) ?? [:]
        bindings = try container.decodeIfPresent([V2LayoutBinding].self, forKey: .bindings) ?? []
        children = try container.decodeIfPresent([V2LayoutNode].self, forKey: .children) ?? []
    }
}

public struct V2ComponentRegistry: Codable, Sendable {
    public let schemaVersion: String
    public let registryId: String
    public let namespace: String
    public let items: [V2RegistryItem]

    public init(schemaVersion: String, registryId: String, namespace: String, items: [V2RegistryItem]) {
        self.schemaVersion = schemaVersion
        self.registryId = registryId
        self.namespace = namespace
        self.items = items
    }
}

public struct V2RegistryItem: Codable, Sendable {
    public let id: String
    public let kind: String
    public let allowedProps: [V2RegistryProp]
    public let slots: [V2RegistrySlot]
    public let stateRequirements: V2RegistryStateRequirements?
    public let motionSlots: [String]
    public let reviewHints: [String]
    public let web: V2WebRegistryMapping
    public let native: V2NativeRegistryMapping

    public init(
        id: String,
        kind: String,
        allowedProps: [V2RegistryProp] = [],
        slots: [V2RegistrySlot] = [],
        stateRequirements: V2RegistryStateRequirements? = nil,
        motionSlots: [String] = [],
        reviewHints: [String] = [],
        web: V2WebRegistryMapping,
        native: V2NativeRegistryMapping
    ) {
        self.id = id
        self.kind = kind
        self.allowedProps = allowedProps
        self.slots = slots
        self.stateRequirements = stateRequirements
        self.motionSlots = motionSlots
        self.reviewHints = reviewHints
        self.web = web
        self.native = native
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case allowedProps
        case slots
        case stateRequirements
        case motionSlots
        case reviewHints
        case web
        case native
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(String.self, forKey: .kind)
        allowedProps = try container.decodeIfPresent([V2RegistryProp].self, forKey: .allowedProps) ?? []
        slots = try container.decodeIfPresent([V2RegistrySlot].self, forKey: .slots) ?? []
        stateRequirements = try container.decodeIfPresent(V2RegistryStateRequirements.self, forKey: .stateRequirements)
        motionSlots = try container.decodeIfPresent([String].self, forKey: .motionSlots) ?? []
        reviewHints = try container.decodeIfPresent([String].self, forKey: .reviewHints) ?? []
        web = try container.decode(V2WebRegistryMapping.self, forKey: .web)
        native = try container.decode(V2NativeRegistryMapping.self, forKey: .native)
    }
}

public struct V2RegistryProp: Codable, Sendable {
    public let name: String
    public let type: String
    public let required: Bool
    public let allowedValues: [String]

    public init(name: String, type: String, required: Bool = false, allowedValues: [String] = []) {
        self.name = name
        self.type = type
        self.required = required
        self.allowedValues = allowedValues
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case type
        case required
        case allowedValues
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        allowedValues = try container.decodeIfPresent([String].self, forKey: .allowedValues) ?? []
    }
}

public struct V2RegistrySlot: Codable, Sendable {
    public let name: String
    public let required: Bool
    public let accepts: [String]

    public init(name: String, required: Bool = false, accepts: [String] = []) {
        self.name = name
        self.required = required
        self.accepts = accepts
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case required
        case accepts
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        accepts = try container.decodeIfPresent([String].self, forKey: .accepts) ?? []
    }
}

public struct V2RegistryStateRequirements: Codable, Sendable {
    public let fields: [String]
    public let actions: [String]
    public let navigation: [String]

    public init(fields: [String] = [], actions: [String] = [], navigation: [String] = []) {
        self.fields = fields
        self.actions = actions
        self.navigation = navigation
    }

    private enum CodingKeys: String, CodingKey {
        case fields
        case actions
        case navigation
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fields = try container.decodeIfPresent([String].self, forKey: .fields) ?? []
        actions = try container.decodeIfPresent([String].self, forKey: .actions) ?? []
        navigation = try container.decodeIfPresent([String].self, forKey: .navigation) ?? []
    }
}

public struct V2WebRegistryMapping: Codable, Sendable {
    public let source: String
    public let importPath: String
    public let exportName: String

    public init(source: String, importPath: String, exportName: String) {
        self.source = source
        self.importPath = importPath
        self.exportName = exportName
    }
}

public struct V2NativeRegistryMapping: Codable, Sendable {
    public let ios: V2PlatformRegistryMapping
    public let android: V2PlatformRegistryMapping

    public init(ios: V2PlatformRegistryMapping, android: V2PlatformRegistryMapping) {
        self.ios = ios
        self.android = android
    }
}

public struct V2PlatformRegistryMapping: Codable, Sendable {
    public let component: String
    public let props: [String: String]

    public init(component: String, props: [String: String] = [:]) {
        self.component = component
        self.props = props
    }

    private enum CodingKeys: String, CodingKey {
        case component
        case props
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        component = try container.decode(String.self, forKey: .component)
        props = try container.decodeIfPresent([String: String].self, forKey: .props) ?? [:]
    }
}

public struct V2MotionSpec: Codable, Sendable {
    public let schemaVersion: String
    public let motionSetId: String
    public let durations: [V2TokenDefinition]
    public let easings: [V2TokenDefinition]
    public let patterns: [V2MotionPattern]

    public init(
        schemaVersion: String,
        motionSetId: String,
        durations: [V2TokenDefinition] = [],
        easings: [V2TokenDefinition] = [],
        patterns: [V2MotionPattern]
    ) {
        self.schemaVersion = schemaVersion
        self.motionSetId = motionSetId
        self.durations = durations
        self.easings = easings
        self.patterns = patterns
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case motionSetId
        case durations
        case easings
        case patterns
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        motionSetId = try container.decode(String.self, forKey: .motionSetId)
        durations = try container.decodeIfPresent([V2TokenDefinition].self, forKey: .durations) ?? []
        easings = try container.decodeIfPresent([V2TokenDefinition].self, forKey: .easings) ?? []
        patterns = try container.decode([V2MotionPattern].self, forKey: .patterns)
    }
}

public struct V2TokenDefinition: Codable, Sendable {
    public let id: String
    public let value: String

    public init(id: String, value: String) {
        self.id = id
        self.value = value
    }
}

public struct V2MotionPattern: Codable, Sendable {
    public let id: String
    public let trigger: String
    public let durationToken: String
    public let easingToken: String
    public let enter: String
    public let exit: String
    public let sharedElementGroup: String?
    public let reducedMotion: String

    public init(
        id: String,
        trigger: String,
        durationToken: String,
        easingToken: String,
        enter: String,
        exit: String,
        sharedElementGroup: String? = nil,
        reducedMotion: String
    ) {
        self.id = id
        self.trigger = trigger
        self.durationToken = durationToken
        self.easingToken = easingToken
        self.enter = enter
        self.exit = exit
        self.sharedElementGroup = sharedElementGroup
        self.reducedMotion = reducedMotion
    }
}

public struct V2ReviewChecklist: Codable, Sendable {
    public let schemaVersion: String
    public let reviewSetId: String
    public let checks: [V2ReviewCheck]

    public init(schemaVersion: String, reviewSetId: String, checks: [V2ReviewCheck]) {
        self.schemaVersion = schemaVersion
        self.reviewSetId = reviewSetId
        self.checks = checks
    }
}

public struct V2ReviewCheck: Codable, Sendable {
    public let id: String
    public let category: String
    public let description: String
    public let required: Bool
    public let evidenceTypes: [String]

    public init(id: String, category: String, description: String, required: Bool, evidenceTypes: [String] = []) {
        self.id = id
        self.category = category
        self.description = description
        self.required = required
        self.evidenceTypes = evidenceTypes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case category
        case description
        case required
        case evidenceTypes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(String.self, forKey: .category)
        description = try container.decode(String.self, forKey: .description)
        required = try container.decode(Bool.self, forKey: .required)
        evidenceTypes = try container.decodeIfPresent([String].self, forKey: .evidenceTypes) ?? []
    }
}
