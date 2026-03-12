import Foundation

public struct AppSpec: Codable, Sendable {
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
    public let sampleApps: SampleApps?
    public let reviewBenchmarks: [BenchmarkReference]
    public let flows: [FlowReference]

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
        sampleApps: SampleApps? = nil,
        reviewBenchmarks: [BenchmarkReference] = [],
        flows: [FlowReference]
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
        sampleApps = try container.decodeIfPresent(SampleApps.self, forKey: .sampleApps)
        reviewBenchmarks = try container.decodeIfPresent([BenchmarkReference].self, forKey: .reviewBenchmarks) ?? []
        flows = try container.decode([FlowReference].self, forKey: .flows)
    }
}

public struct SampleApps: Codable, Sendable {
    public let ios: String?
    public let android: String?

    public init(ios: String? = nil, android: String? = nil) {
        self.ios = ios
        self.android = android
    }
}

public struct BenchmarkReference: Codable, Sendable {
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

public struct FlowReference: Codable, Sendable {
    public let id: String
    public let path: String

    public init(id: String, path: String) {
        self.id = id
        self.path = path
    }
}

public struct FlowSpec: Codable, Sendable {
    public let schemaVersion: String
    public let appId: String
    public let flowId: String
    public let title: String
    public let entryScreen: String
    public let deepLinks: [DeepLink]
    public let screens: [ScreenReference]
    public let transitions: [FlowTransition]

    public init(
        schemaVersion: String,
        appId: String,
        flowId: String,
        title: String,
        entryScreen: String,
        deepLinks: [DeepLink] = [],
        screens: [ScreenReference],
        transitions: [FlowTransition]
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
        deepLinks = try container.decodeIfPresent([DeepLink].self, forKey: .deepLinks) ?? []
        screens = try container.decode([ScreenReference].self, forKey: .screens)
        transitions = try container.decode([FlowTransition].self, forKey: .transitions)
    }
}

public struct DeepLink: Codable, Sendable {
    public let route: String
    public let targetScreen: String

    public init(route: String, targetScreen: String) {
        self.route = route
        self.targetScreen = targetScreen
    }
}

public struct ScreenReference: Codable, Sendable {
    public let id: String
    public let path: String
    public let role: String?

    public init(id: String, path: String, role: String? = nil) {
        self.id = id
        self.path = path
        self.role = role
    }
}

public struct FlowTransition: Codable, Sendable {
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

public struct ScreenSpec: Codable, Sendable {
    public let schemaVersion: String
    public let appId: String
    public let flowId: String
    public let screenId: String
    public let title: String
    public let route: String
    public let targets: [Platform]
    public let intent: String?
    public let surface: ScreenSurface
    public let states: [String]
    public let stateFields: [StateField]
    public let actions: [Action]
    public let navigation: [Navigation]
    public let assets: [Asset]
    public let previewStates: [PreviewState]
    public let motion: [MotionReference]
    public let reviewChecklist: [String]
    public let layout: LayoutNode

    public init(
        schemaVersion: String,
        appId: String,
        flowId: String,
        screenId: String,
        title: String,
        route: String,
        targets: [Platform],
        intent: String? = nil,
        surface: ScreenSurface,
        states: [String],
        stateFields: [StateField] = [],
        actions: [Action] = [],
        navigation: [Navigation] = [],
        assets: [Asset] = [],
        previewStates: [PreviewState],
        motion: [MotionReference] = [],
        reviewChecklist: [String] = [],
        layout: LayoutNode
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
        surface = try container.decode(ScreenSurface.self, forKey: .surface)
        states = try container.decode([String].self, forKey: .states)
        stateFields = try container.decodeIfPresent([StateField].self, forKey: .stateFields) ?? []
        actions = try container.decodeIfPresent([Action].self, forKey: .actions) ?? []
        navigation = try container.decodeIfPresent([Navigation].self, forKey: .navigation) ?? []
        assets = try container.decodeIfPresent([Asset].self, forKey: .assets) ?? []
        previewStates = try container.decode([PreviewState].self, forKey: .previewStates)
        motion = try container.decodeIfPresent([MotionReference].self, forKey: .motion) ?? []
        reviewChecklist = try container.decodeIfPresent([String].self, forKey: .reviewChecklist) ?? []
        layout = try container.decode(LayoutNode.self, forKey: .layout)
    }
}

public struct ScreenSurface: Codable, Sendable {
    public let backgroundColor: String
    public let padding: String

    public init(backgroundColor: String, padding: String) {
        self.backgroundColor = backgroundColor
        self.padding = padding
    }
}

public struct StateField: Codable, Sendable {
    public let id: String
    public let type: String
    public let defaultValue: JSONValue?

    public init(id: String, type: String, defaultValue: JSONValue? = nil) {
        self.id = id
        self.type = type
        self.defaultValue = defaultValue
    }
}

public struct Action: Codable, Sendable {
    public let id: String
    public let kind: String?

    public init(id: String, kind: String? = nil) {
        self.id = id
        self.kind = kind
    }
}

public struct Navigation: Codable, Sendable {
    public let id: String
    public let route: String

    public init(id: String, route: String) {
        self.id = id
        self.route = route
    }
}

public struct Asset: Codable, Sendable {
    public let name: String
    public let kind: String

    public init(name: String, kind: String) {
        self.name = name
        self.kind = kind
    }
}

public struct PreviewState: Codable, Sendable {
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

public struct MotionReference: Codable, Sendable {
    public let patternId: String
    public let trigger: String

    public init(patternId: String, trigger: String) {
        self.patternId = patternId
        self.trigger = trigger
    }
}

public struct LayoutBinding: Codable, Sendable {
    public let field: String
    public let action: String?
    public let navigation: String?

    public init(field: String, action: String? = nil, navigation: String? = nil) {
        self.field = field
        self.action = action
        self.navigation = navigation
    }
}

public struct LayoutNode: Codable, Sendable {
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
    public let bindings: [LayoutBinding]
    public let children: [LayoutNode]

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
        bindings: [LayoutBinding] = [],
        children: [LayoutNode] = []
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
        bindings = try container.decodeIfPresent([LayoutBinding].self, forKey: .bindings) ?? []
        children = try container.decodeIfPresent([LayoutNode].self, forKey: .children) ?? []
    }
}

public struct ComponentRegistry: Codable, Sendable {
    public let schemaVersion: String
    public let registryId: String
    public let namespace: String
    public let items: [RegistryItem]

    public init(schemaVersion: String, registryId: String, namespace: String, items: [RegistryItem]) {
        self.schemaVersion = schemaVersion
        self.registryId = registryId
        self.namespace = namespace
        self.items = items
    }
}

public struct RegistryItem: Codable, Sendable {
    public let id: String
    public let kind: String
    public let allowedProps: [RegistryProp]
    public let slots: [RegistrySlot]
    public let stateRequirements: RegistryStateRequirements?
    public let motionSlots: [String]
    public let reviewHints: [String]
    public let web: WebRegistryMapping
    public let native: NativeRegistryMapping

    public init(
        id: String,
        kind: String,
        allowedProps: [RegistryProp] = [],
        slots: [RegistrySlot] = [],
        stateRequirements: RegistryStateRequirements? = nil,
        motionSlots: [String] = [],
        reviewHints: [String] = [],
        web: WebRegistryMapping,
        native: NativeRegistryMapping
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
        allowedProps = try container.decodeIfPresent([RegistryProp].self, forKey: .allowedProps) ?? []
        slots = try container.decodeIfPresent([RegistrySlot].self, forKey: .slots) ?? []
        stateRequirements = try container.decodeIfPresent(RegistryStateRequirements.self, forKey: .stateRequirements)
        motionSlots = try container.decodeIfPresent([String].self, forKey: .motionSlots) ?? []
        reviewHints = try container.decodeIfPresent([String].self, forKey: .reviewHints) ?? []
        web = try container.decode(WebRegistryMapping.self, forKey: .web)
        native = try container.decode(NativeRegistryMapping.self, forKey: .native)
    }
}

public struct RegistryProp: Codable, Sendable {
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

public struct RegistrySlot: Codable, Sendable {
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

public struct RegistryStateRequirements: Codable, Sendable {
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

public struct WebRegistryMapping: Codable, Sendable {
    public let source: String
    public let importPath: String
    public let exportName: String

    public init(source: String, importPath: String, exportName: String) {
        self.source = source
        self.importPath = importPath
        self.exportName = exportName
    }
}

public struct NativeRegistryMapping: Codable, Sendable {
    public let ios: PlatformRegistryMapping
    public let android: PlatformRegistryMapping

    public init(ios: PlatformRegistryMapping, android: PlatformRegistryMapping) {
        self.ios = ios
        self.android = android
    }
}

public struct PlatformRegistryMapping: Codable, Sendable {
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

public struct MotionSpec: Codable, Sendable {
    public let schemaVersion: String
    public let motionSetId: String
    public let durations: [TokenDefinition]
    public let easings: [TokenDefinition]
    public let patterns: [MotionPattern]

    public init(
        schemaVersion: String,
        motionSetId: String,
        durations: [TokenDefinition] = [],
        easings: [TokenDefinition] = [],
        patterns: [MotionPattern]
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
        durations = try container.decodeIfPresent([TokenDefinition].self, forKey: .durations) ?? []
        easings = try container.decodeIfPresent([TokenDefinition].self, forKey: .easings) ?? []
        patterns = try container.decode([MotionPattern].self, forKey: .patterns)
    }
}

public struct TokenDefinition: Codable, Sendable {
    public let id: String
    public let value: String

    public init(id: String, value: String) {
        self.id = id
        self.value = value
    }
}

public struct MotionPattern: Codable, Sendable {
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

public struct ReviewChecklist: Codable, Sendable {
    public let schemaVersion: String
    public let reviewSetId: String
    public let checks: [ReviewCheck]

    public init(schemaVersion: String, reviewSetId: String, checks: [ReviewCheck]) {
        self.schemaVersion = schemaVersion
        self.reviewSetId = reviewSetId
        self.checks = checks
    }
}

public struct ReviewCheck: Codable, Sendable {
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
