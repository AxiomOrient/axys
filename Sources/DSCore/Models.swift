import Foundation

public enum Platform: String, Codable, CaseIterable, Sendable {
    case ios
    case android
    case html
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
    public let requiredPathsPresent: Bool
    public let schemaValidation: Bool
    public let markdownRelativeLinks: Bool
    public let legacyArtifactsAbsent: Bool
    public let contractCrossReference: Bool
    public let docCount: Int
    public let schemaCount: Int
    public let contractFileCount: Int

    public init(
        requiredPathsPresent: Bool,
        schemaValidation: Bool,
        markdownRelativeLinks: Bool,
        legacyArtifactsAbsent: Bool,
        contractCrossReference: Bool,
        docCount: Int,
        schemaCount: Int,
        contractFileCount: Int
    ) {
        self.requiredPathsPresent = requiredPathsPresent
        self.schemaValidation = schemaValidation
        self.markdownRelativeLinks = markdownRelativeLinks
        self.legacyArtifactsAbsent = legacyArtifactsAbsent
        self.contractCrossReference = contractCrossReference
        self.docCount = docCount
        self.schemaCount = schemaCount
        self.contractFileCount = contractFileCount
    }

    private enum CodingKeys: String, CodingKey {
        case requiredPathsPresent = "required_paths_present"
        case schemaValidation = "schema_validation"
        case markdownRelativeLinks = "markdown_relative_links"
        case legacyArtifactsAbsent = "legacy_artifacts_absent"
        case contractCrossReference = "contract_cross_reference"
        case docCount = "doc_count"
        case schemaCount = "schema_count"
        case contractFileCount = "contract_file_count"
    }
}

public struct RepoAuditReport: Codable, Sendable {
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

public struct RenderHTMLReport: Codable, Sendable {
    public let ok: Bool
    public let screenId: String
    public let outputDirectory: String
    public let entrypointPath: String
    public let artifacts: [GeneratedArtifact]
    public let reviewReportPath: String

    public init(
        ok: Bool,
        screenId: String,
        outputDirectory: String,
        entrypointPath: String,
        artifacts: [GeneratedArtifact],
        reviewReportPath: String
    ) {
        self.ok = ok
        self.screenId = screenId
        self.outputDirectory = outputDirectory
        self.entrypointPath = entrypointPath
        self.artifacts = artifacts.sorted { ($0.kind, $0.path) < ($1.kind, $1.path) }
        self.reviewReportPath = reviewReportPath
    }
}

public struct GenerateNativeReport: Codable, Sendable {
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

public enum AdapterKind: String, Codable, Sendable {
    case penpot
    case pencil
}

public struct AdapterFlowSyncReport: Codable, Sendable {
    public let flowId: String
    public let payloadPath: String
    public let screenIds: [String]

    public init(flowId: String, payloadPath: String, screenIds: [String]) {
        self.flowId = flowId
        self.payloadPath = payloadPath
        self.screenIds = screenIds.sorted()
    }
}

public struct AdapterSyncReport: Codable, Sendable {
    public let ok: Bool
    public let adapter: AdapterKind
    public let appId: String
    public let outputDirectory: String
    public let manifestPath: String
    public let tokenPayloadPath: String
    public let flows: [AdapterFlowSyncReport]
    public let artifacts: [GeneratedArtifact]

    public init(
        ok: Bool,
        adapter: AdapterKind,
        appId: String,
        outputDirectory: String,
        manifestPath: String,
        tokenPayloadPath: String,
        flows: [AdapterFlowSyncReport],
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

public struct SampleAppScreenBuildReport: Codable, Sendable {
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

public struct SampleAppPlatformBuildReport: Codable, Sendable {
    public let platform: Platform
    public let sampleAppPath: String
    public let proofManifestPath: String
    public let screens: [SampleAppScreenBuildReport]

    public init(platform: Platform, sampleAppPath: String, proofManifestPath: String, screens: [SampleAppScreenBuildReport]) {
        self.platform = platform
        self.sampleAppPath = sampleAppPath
        self.proofManifestPath = proofManifestPath
        self.screens = screens.sorted { $0.screenId < $1.screenId }
    }
}

public struct HostProofLevelReport: Codable, Sendable {
    public let id: String
    public let title: String
    public let path: String
    public let summary: String

    public init(id: String, title: String, path: String, summary: String) {
        self.id = id
        self.title = title
        self.path = path
        self.summary = summary
    }
}

public struct HostProofScreenEvidence: Codable, Sendable {
    public let screenId: String
    public let generatedMountPath: String
    public let wrapperPath: String
    public let buildLogPath: String
    public let runtimeLogPath: String

    public init(
        screenId: String,
        generatedMountPath: String,
        wrapperPath: String,
        buildLogPath: String,
        runtimeLogPath: String
    ) {
        self.screenId = screenId
        self.generatedMountPath = generatedMountPath
        self.wrapperPath = wrapperPath
        self.buildLogPath = buildLogPath
        self.runtimeLogPath = runtimeLogPath
    }
}

public struct HostProofManifest: Codable, Sendable {
    public let ok: Bool
    public let platform: Platform
    public let sampleAppPath: String
    public let generatedMountRoot: String
    public let wrapperRoot: String
    public let logsRoot: String
    public let levels: [HostProofLevelReport]
    public let screens: [HostProofScreenEvidence]

    public init(
        ok: Bool,
        platform: Platform,
        sampleAppPath: String,
        generatedMountRoot: String,
        wrapperRoot: String,
        logsRoot: String,
        levels: [HostProofLevelReport],
        screens: [HostProofScreenEvidence]
    ) {
        self.ok = ok
        self.platform = platform
        self.sampleAppPath = sampleAppPath
        self.generatedMountRoot = generatedMountRoot
        self.wrapperRoot = wrapperRoot
        self.logsRoot = logsRoot
        self.levels = levels
        self.screens = screens.sorted { $0.screenId < $1.screenId }
    }
}

public struct SampleAppsBuildReport: Codable, Sendable {
    public let ok: Bool
    public let appId: String
    public let platforms: [SampleAppPlatformBuildReport]

    public init(ok: Bool, appId: String, platforms: [SampleAppPlatformBuildReport]) {
        self.ok = ok
        self.appId = appId
        self.platforms = platforms.sorted { $0.platform.rawValue < $1.platform.rawValue }
    }
}

public struct AppAuditReport: Codable, Sendable {
    public let ok: Bool
    public let appId: String
    public let outputDirectory: String
    public let validationReportPath: String
    public let htmlScreens: [RenderHTMLReport]
    public let penpotSync: AdapterSyncReport
    public let pencilSync: AdapterSyncReport
    public let sampleApps: SampleAppsBuildReport
    public let sampleAppsReportPath: String
    public let artifacts: [GeneratedArtifact]

    public init(
        ok: Bool,
        appId: String,
        outputDirectory: String,
        validationReportPath: String,
        htmlScreens: [RenderHTMLReport],
        penpotSync: AdapterSyncReport,
        pencilSync: AdapterSyncReport,
        sampleApps: SampleAppsBuildReport,
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
    case auditFailed(RepoAuditReport)

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
