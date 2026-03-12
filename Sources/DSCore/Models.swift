import Foundation

public enum Platform: String, Codable, CaseIterable, Sendable {
    case ios
    case android
    case html
}

public struct ScreenSurface: Codable, Sendable {
    public let backgroundColor: String
    public let padding: String

    public init(backgroundColor: String, padding: String) {
        self.backgroundColor = backgroundColor
        self.padding = padding
    }
}

public enum ScreenStateFieldType: String, Codable, Sendable {
    case string
    case boolean
    case integer
    case number
}

public struct ScreenStateField: Codable, Sendable {
    public let id: String
    public let type: ScreenStateFieldType
    public let defaultValue: JSONValue?

    public init(id: String, type: ScreenStateFieldType, defaultValue: JSONValue? = nil) {
        self.id = id
        self.type = type
        self.defaultValue = defaultValue
    }
}

public struct ScreenAction: Codable, Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

public struct ScreenPreviewState: Codable, Sendable {
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

public struct ScreenNavigationDestination: Codable, Sendable {
    public let id: String
    public let route: String

    public init(id: String, route: String) {
        self.id = id
        self.route = route
    }
}

public enum ScreenAssetKind: String, Codable, Sendable {
    case image
    case icon
}

public struct ScreenAsset: Codable, Sendable {
    public let name: String
    public let kind: ScreenAssetKind

    public init(name: String, kind: ScreenAssetKind) {
        self.name = name
        self.kind = kind
    }
}

public struct ScreenNode: Codable, Sendable {
    public let kind: String
    public let id: String?
    public let role: String?
    public let variant: String?
    public let text: String?
    public let title: String?
    public let label: String?
    public let action: String?
    public let navigation: String?
    public let binding: String?
    public let inputType: String?
    public let spacing: String?
    public let assetName: String?
    public let children: [ScreenNode]?

    public init(
        kind: String,
        id: String? = nil,
        role: String? = nil,
        variant: String? = nil,
        text: String? = nil,
        title: String? = nil,
        label: String? = nil,
        action: String? = nil,
        navigation: String? = nil,
        binding: String? = nil,
        inputType: String? = nil,
        spacing: String? = nil,
        assetName: String? = nil,
        children: [ScreenNode]? = nil
    ) {
        self.kind = kind
        self.id = id
        self.role = role
        self.variant = variant
        self.text = text
        self.title = title
        self.label = label
        self.action = action
        self.navigation = navigation
        self.binding = binding
        self.inputType = inputType
        self.spacing = spacing
        self.assetName = assetName
        self.children = children
    }
}

public struct ScreenSpec: Codable, Sendable {
    public let schemaVersion: String
    public let screenId: String
    public let title: String
    public let route: String?
    public let intent: String?
    public let constraints: [String]
    public let states: [String]
    public let stateFields: [ScreenStateField]
    public let actions: [ScreenAction]
    public let assets: [ScreenAsset]
    public let previewStates: [ScreenPreviewState]
    public let navigation: [ScreenNavigationDestination]
    public let platforms: [Platform]
    public let surface: ScreenSurface
    public let root: ScreenNode

    public init(
        schemaVersion: String,
        screenId: String,
        title: String,
        route: String? = nil,
        intent: String? = nil,
        constraints: [String] = [],
        states: [String] = [],
        stateFields: [ScreenStateField] = [],
        actions: [ScreenAction] = [],
        assets: [ScreenAsset] = [],
        previewStates: [ScreenPreviewState] = [],
        navigation: [ScreenNavigationDestination] = [],
        platforms: [Platform],
        surface: ScreenSurface,
        root: ScreenNode
    ) {
        self.schemaVersion = schemaVersion
        self.screenId = screenId
        self.title = title
        self.route = route
        self.intent = intent
        self.constraints = constraints
        self.states = states
        self.stateFields = stateFields
        self.actions = actions
        self.assets = assets
        self.previewStates = previewStates
        self.navigation = navigation
        self.platforms = platforms
        self.surface = surface
        self.root = root
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case screenId
        case title
        case route
        case intent
        case constraints
        case states
        case stateFields
        case actions
        case assets
        case previewStates
        case navigation
        case platforms
        case surface
        case root
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        screenId = try container.decode(String.self, forKey: .screenId)
        title = try container.decode(String.self, forKey: .title)
        route = try container.decodeIfPresent(String.self, forKey: .route)
        intent = try container.decodeIfPresent(String.self, forKey: .intent)
        constraints = try container.decodeIfPresent([String].self, forKey: .constraints) ?? []
        states = try container.decodeIfPresent([String].self, forKey: .states) ?? []
        stateFields = try container.decodeIfPresent([ScreenStateField].self, forKey: .stateFields) ?? []
        actions = try container.decodeIfPresent([ScreenAction].self, forKey: .actions) ?? []
        assets = try container.decodeIfPresent([ScreenAsset].self, forKey: .assets) ?? []
        previewStates = try container.decodeIfPresent([ScreenPreviewState].self, forKey: .previewStates) ?? []
        navigation = try container.decodeIfPresent([ScreenNavigationDestination].self, forKey: .navigation) ?? []
        platforms = try container.decode([Platform].self, forKey: .platforms)
        surface = try container.decode(ScreenSurface.self, forKey: .surface)
        root = try container.decode(ScreenNode.self, forKey: .root)
    }
}

public struct ComponentDefinition: Codable, Sendable {
    public let kind: String
    public let roles: [String]?
    public let variants: [String]?
    public let inputTypes: [String]?

    public init(kind: String, roles: [String]? = nil, variants: [String]? = nil, inputTypes: [String]? = nil) {
        self.kind = kind
        self.roles = roles
        self.variants = variants
        self.inputTypes = inputTypes
    }
}

public struct ComponentCatalog: Codable, Sendable {
    public let schemaVersion: String
    public let components: [ComponentDefinition]

    public init(schemaVersion: String, components: [ComponentDefinition]) {
        self.schemaVersion = schemaVersion
        self.components = components
    }
}

public struct DSConfig: Codable, Sendable {
    public let schemaVersion: String
    public let projectRoot: String
    public let screenDocDir: String
    public let screenSpecDir: String
    public let tokenDir: String
    public let catalogPath: String
    public let buildDir: String
    public let defaultPlatforms: [Platform]

    public init(
        schemaVersion: String,
        projectRoot: String,
        screenDocDir: String,
        screenSpecDir: String,
        tokenDir: String,
        catalogPath: String,
        buildDir: String,
        defaultPlatforms: [Platform]
    ) {
        self.schemaVersion = schemaVersion
        self.projectRoot = projectRoot
        self.screenDocDir = screenDocDir
        self.screenSpecDir = screenSpecDir
        self.tokenDir = tokenDir
        self.catalogPath = catalogPath
        self.buildDir = buildDir
        self.defaultPlatforms = defaultPlatforms
    }
}

public struct ResolvedToken: Codable, Sendable, Equatable {
    public let path: String
    public let type: String
    public let value: String

    public init(path: String, type: String, value: String) {
        self.path = path
        self.type = type
        self.value = value
    }
}

public struct TokenStore: Codable, Sendable {
    public let tokens: [ResolvedToken]

    public init(tokens: [ResolvedToken]) {
        self.tokens = tokens.sorted { $0.path < $1.path }
    }

    public func token(forPath path: String) -> ResolvedToken? {
        tokens.first(where: { $0.path == path })
    }

    public func resolve(alias: String) -> ResolvedToken? {
        guard let path = Self.path(fromAlias: alias) else {
            return nil
        }
        return token(forPath: path)
    }

    public static func path(fromAlias alias: String) -> String? {
        guard alias.hasPrefix("{"), alias.hasSuffix("}") else {
            return nil
        }
        let start = alias.index(after: alias.startIndex)
        let end = alias.index(before: alias.endIndex)
        return String(alias[start..<end])
    }
}

public enum ValidationSeverity: String, Codable, Sendable {
    case error
    case warning
}

public struct ValidationIssue: Codable, Sendable, Equatable {
    public let code: String
    public let path: String
    public let message: String
    public let severity: ValidationSeverity

    public init(code: String, path: String, message: String, severity: ValidationSeverity = .error) {
        self.code = code
        self.path = path
        self.message = message
        self.severity = severity
    }
}

public struct ValidationReport: Codable, Sendable {
    public let ok: Bool
    public let issues: [ValidationIssue]
    public let summary: String

    public init(issues: [ValidationIssue]) {
        let sorted = issues.sorted { ($0.path, $0.code) < ($1.path, $1.code) }
        self.ok = sorted.allSatisfy { $0.severity != .error }
        self.issues = sorted
        if sorted.isEmpty {
            self.summary = "Validation passed."
        } else {
            self.summary = sorted.map { "\($0.path): \($0.message)" }.joined(separator: "\n")
        }
    }
}

public struct GeneratedArtifact: Codable, Sendable {
    public let kind: String
    public let path: String

    public init(kind: String, path: String) {
        self.kind = kind
        self.path = path
    }
}

public struct Manifest: Codable, Sendable {
    public let inputSpecPath: String
    public let inputTokenPaths: [String]
    public let generatedFiles: [String]
    public let validationSummary: String
    public let generatorVersion: String
    public let schemaVersion: String

    public init(
        inputSpecPath: String,
        inputTokenPaths: [String],
        generatedFiles: [String],
        validationSummary: String,
        generatorVersion: String,
        schemaVersion: String
    ) {
        self.inputSpecPath = inputSpecPath
        self.inputTokenPaths = inputTokenPaths.sorted()
        self.generatedFiles = generatedFiles.sorted()
        self.validationSummary = validationSummary
        self.generatorVersion = generatorVersion
        self.schemaVersion = schemaVersion
    }
}

public struct GenerateReport: Codable, Sendable {
    public let ok: Bool
    public let screenId: String
    public let outputDirectory: String
    public let artifacts: [GeneratedArtifact]
    public let manifestPath: String
    public let validationReportPath: String

    public init(
        ok: Bool,
        screenId: String,
        outputDirectory: String,
        artifacts: [GeneratedArtifact],
        manifestPath: String,
        validationReportPath: String
    ) {
        self.ok = ok
        self.screenId = screenId
        self.outputDirectory = outputDirectory
        self.artifacts = artifacts.sorted { ($0.kind, $0.path) < ($1.kind, $1.path) }
        self.manifestPath = manifestPath
        self.validationReportPath = validationReportPath
    }
}

public struct GenerateBundleReport: Codable, Sendable {
    public let ok: Bool
    public let reports: [GenerateReport]
    public let failures: [String]

    public init(reports: [GenerateReport], failures: [String]) {
        self.ok = failures.isEmpty
        self.reports = reports.sorted { $0.screenId < $1.screenId }
        self.failures = failures.sorted()
    }
}

public struct DoctorCapabilities: Codable, Sendable, Equatable {
    public let cli: Bool
    public let mcp: Bool
    public let iosRenderer: Bool
    public let androidRenderer: Bool
    public let htmlPreview: Bool
    public let iosHostSmoke: Bool
    public let androidHostSmoke: Bool

    public init(
        cli: Bool,
        mcp: Bool,
        iosRenderer: Bool,
        androidRenderer: Bool,
        htmlPreview: Bool,
        iosHostSmoke: Bool,
        androidHostSmoke: Bool
    ) {
        self.cli = cli
        self.mcp = mcp
        self.iosRenderer = iosRenderer
        self.androidRenderer = androidRenderer
        self.htmlPreview = htmlPreview
        self.iosHostSmoke = iosHostSmoke
        self.androidHostSmoke = androidHostSmoke
    }

    private enum CodingKeys: String, CodingKey {
        case cli
        case mcp
        case iosRenderer = "ios_renderer"
        case androidRenderer = "android_renderer"
        case htmlPreview = "html_preview"
        case iosHostSmoke = "ios_host_smoke"
        case androidHostSmoke = "android_host_smoke"
    }
}

public struct DoctorToolchains: Codable, Sendable, Equatable {
    public let swiftc: Bool
    public let python3: Bool
    public let javaRuntime: Bool
    public let kotlin: Bool
    public let kotlinc: Bool
    public let gradle: Bool

    public init(swiftc: Bool, python3: Bool, javaRuntime: Bool, kotlin: Bool, kotlinc: Bool, gradle: Bool) {
        self.swiftc = swiftc
        self.python3 = python3
        self.javaRuntime = javaRuntime
        self.kotlin = kotlin
        self.kotlinc = kotlinc
        self.gradle = gradle
    }

    private enum CodingKeys: String, CodingKey {
        case swiftc
        case python3
        case javaRuntime = "java_runtime"
        case kotlin
        case kotlinc
        case gradle
    }
}

public struct DoctorReport: Codable, Sendable, Equatable {
    public let ok: Bool
    public let swiftVersion: String
    public let capabilities: DoctorCapabilities
    public let toolchains: DoctorToolchains

    public init(ok: Bool, swiftVersion: String, capabilities: DoctorCapabilities, toolchains: DoctorToolchains) {
        self.ok = ok
        self.swiftVersion = swiftVersion
        self.capabilities = capabilities
        self.toolchains = toolchains
    }

    private enum CodingKeys: String, CodingKey {
        case ok
        case swiftVersion = "swift_version"
        case capabilities
        case toolchains
    }
}

public struct IntegrityChecks: Codable, Sendable {
    public let coreFilesExist: Bool
    public let jsonParse: Bool
    public let schemaValidation: Bool
    public let markdownRelativeLinks: Bool
    public let docSyncFreshness: Bool
    public let contractViewFreshness: Bool
    public let contractCrossReference: Bool
    public let docCount: Int
    public let schemaCount: Int
    public let exampleJSONCount: Int
    public let promptCount: Int

    public init(
        coreFilesExist: Bool,
        jsonParse: Bool,
        schemaValidation: Bool,
        markdownRelativeLinks: Bool,
        docSyncFreshness: Bool,
        contractViewFreshness: Bool,
        contractCrossReference: Bool,
        docCount: Int,
        schemaCount: Int,
        exampleJSONCount: Int,
        promptCount: Int
    ) {
        self.coreFilesExist = coreFilesExist
        self.jsonParse = jsonParse
        self.schemaValidation = schemaValidation
        self.markdownRelativeLinks = markdownRelativeLinks
        self.docSyncFreshness = docSyncFreshness
        self.contractViewFreshness = contractViewFreshness
        self.contractCrossReference = contractCrossReference
        self.docCount = docCount
        self.schemaCount = schemaCount
        self.exampleJSONCount = exampleJSONCount
        self.promptCount = promptCount
    }

    private enum CodingKeys: String, CodingKey {
        case coreFilesExist = "core_files_exist"
        case jsonParse = "json_parse"
        case schemaValidation = "schema_validation"
        case markdownRelativeLinks = "markdown_relative_links"
        case docSyncFreshness = "doc_sync_freshness"
        case contractViewFreshness = "contract_view_freshness"
        case contractCrossReference = "contract_cross_reference"
        case docCount = "doc_count"
        case schemaCount = "schema_count"
        case exampleJSONCount = "example_json_count"
        case promptCount = "prompt_count"
    }
}

public struct AuditReport: Codable, Sendable {
    public let ok: Bool
    public let checks: IntegrityChecks
    public let errors: [String]
    public let warnings: [String]

    public init(ok: Bool, checks: IntegrityChecks, errors: [String], warnings: [String]) {
        self.ok = ok
        self.checks = checks
        self.errors = errors.sorted()
        self.warnings = warnings.sorted()
    }
}

public struct PreviewServeReport: Codable, Sendable {
    public let ok: Bool
    public let url: String
    public let pid: Int32
    public let directory: String

    public init(ok: Bool, url: String, pid: Int32, directory: String) {
        self.ok = ok
        self.url = url
        self.pid = pid
        self.directory = directory
    }
}

public struct V2RenderHTMLReport: Codable, Sendable {
    public let ok: Bool
    public let screenId: String
    public let outputDirectory: String
    public let artifacts: [GeneratedArtifact]
    public let reviewReportPath: String

    public init(
        ok: Bool,
        screenId: String,
        outputDirectory: String,
        artifacts: [GeneratedArtifact],
        reviewReportPath: String
    ) {
        self.ok = ok
        self.screenId = screenId
        self.outputDirectory = outputDirectory
        self.artifacts = artifacts.sorted { ($0.kind, $0.path) < ($1.kind, $1.path) }
        self.reviewReportPath = reviewReportPath
    }
}

public struct V2GenerateNativeReport: Codable, Sendable {
    public let ok: Bool
    public let platform: Platform
    public let screenId: String
    public let outputDirectory: String
    public let artifacts: [GeneratedArtifact]
    public let manifestPath: String

    public init(
        ok: Bool,
        platform: Platform,
        screenId: String,
        outputDirectory: String,
        artifacts: [GeneratedArtifact],
        manifestPath: String
    ) {
        self.ok = ok
        self.platform = platform
        self.screenId = screenId
        self.outputDirectory = outputDirectory
        self.artifacts = artifacts.sorted { ($0.kind, $0.path) < ($1.kind, $1.path) }
        self.manifestPath = manifestPath
    }
}

public enum V2AdapterKind: String, Codable, Sendable {
    case penpot
    case pencil
}

public struct V2AdapterFlowSyncReport: Codable, Sendable {
    public let flowId: String
    public let payloadPath: String
    public let screenIds: [String]

    public init(flowId: String, payloadPath: String, screenIds: [String]) {
        self.flowId = flowId
        self.payloadPath = payloadPath
        self.screenIds = screenIds.sorted()
    }
}

public struct V2AdapterSyncReport: Codable, Sendable {
    public let ok: Bool
    public let adapter: V2AdapterKind
    public let appId: String
    public let outputDirectory: String
    public let manifestPath: String
    public let tokenPayloadPath: String
    public let flows: [V2AdapterFlowSyncReport]
    public let artifacts: [GeneratedArtifact]

    public init(
        ok: Bool,
        adapter: V2AdapterKind,
        appId: String,
        outputDirectory: String,
        manifestPath: String,
        tokenPayloadPath: String,
        flows: [V2AdapterFlowSyncReport],
        artifacts: [GeneratedArtifact]
    ) {
        self.ok = ok
        self.adapter = adapter
        self.appId = appId
        self.outputDirectory = outputDirectory
        self.manifestPath = manifestPath
        self.tokenPayloadPath = tokenPayloadPath
        self.flows = flows.sorted { $0.flowId < $1.flowId }
        self.artifacts = artifacts.sorted { ($0.kind, $0.path) < ($1.kind, $1.path) }
    }
}

public struct V2SampleAppScreenBuildReport: Codable, Sendable {
    public let screenId: String
    public let outputDirectory: String
    public let wrapperPath: String
    public let buildLogPath: String
    public let runtimeLogPath: String

    public init(
        screenId: String,
        outputDirectory: String,
        wrapperPath: String,
        buildLogPath: String,
        runtimeLogPath: String
    ) {
        self.screenId = screenId
        self.outputDirectory = outputDirectory
        self.wrapperPath = wrapperPath
        self.buildLogPath = buildLogPath
        self.runtimeLogPath = runtimeLogPath
    }
}

public struct V2SampleAppPlatformBuildReport: Codable, Sendable {
    public let platform: Platform
    public let sampleAppPath: String
    public let screens: [V2SampleAppScreenBuildReport]

    public init(platform: Platform, sampleAppPath: String, screens: [V2SampleAppScreenBuildReport]) {
        self.platform = platform
        self.sampleAppPath = sampleAppPath
        self.screens = screens.sorted { $0.screenId < $1.screenId }
    }
}

public struct V2BuildSampleAppsReport: Codable, Sendable {
    public let ok: Bool
    public let appId: String
    public let platforms: [V2SampleAppPlatformBuildReport]

    public init(ok: Bool, appId: String, platforms: [V2SampleAppPlatformBuildReport]) {
        self.ok = ok
        self.appId = appId
        self.platforms = platforms.sorted { $0.platform.rawValue < $1.platform.rawValue }
    }
}

public struct V2AuditReport: Codable, Sendable {
    public let ok: Bool
    public let appId: String
    public let outputDirectory: String
    public let validationReportPath: String
    public let htmlScreens: [V2RenderHTMLReport]
    public let penpotSync: V2AdapterSyncReport
    public let pencilSync: V2AdapterSyncReport
    public let sampleApps: V2BuildSampleAppsReport
    public let sampleAppsReportPath: String
    public let artifacts: [GeneratedArtifact]

    public init(
        ok: Bool,
        appId: String,
        outputDirectory: String,
        validationReportPath: String,
        htmlScreens: [V2RenderHTMLReport],
        penpotSync: V2AdapterSyncReport,
        pencilSync: V2AdapterSyncReport,
        sampleApps: V2BuildSampleAppsReport,
        sampleAppsReportPath: String,
        artifacts: [GeneratedArtifact]
    ) {
        self.ok = ok
        self.appId = appId
        self.outputDirectory = outputDirectory
        self.validationReportPath = validationReportPath
        self.htmlScreens = htmlScreens.sorted { $0.screenId < $1.screenId }
        self.penpotSync = penpotSync
        self.pencilSync = pencilSync
        self.sampleApps = sampleApps
        self.sampleAppsReportPath = sampleAppsReportPath
        self.artifacts = artifacts.sorted { ($0.kind, $0.path) < ($1.kind, $1.path) }
    }
}

public struct OperationErrorReport: Codable, Sendable {
    public let ok: Bool
    public let error: String

    public init(error: String) {
        self.ok = false
        self.error = error
    }
}

public enum ProjectError: Error, LocalizedError {
    case io(String)
    case invalidArgument(String)
    case compileFailed(String)
    case validationFailed(ValidationReport)
    case generationFailed(String)
    case auditFailed(AuditReport)

    public var errorDescription: String? {
        switch self {
        case .io(let message), .invalidArgument(let message), .compileFailed(let message), .generationFailed(let message):
            return message
        case .validationFailed(let report):
            return report.summary
        case .auditFailed(let report):
            return report.errors.joined(separator: "\n")
        }
    }
}
