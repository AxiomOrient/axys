import Foundation

struct V2AdapterManifest: Codable {
    let schemaVersion: String
    let adapter: V2AdapterKind
    let appId: String
    let title: String
    let targetSurface: String
    let flowPayloads: [V2AdapterFlowManifest]
    let generatedFiles: [String]
    let sourcePaths: [String: String]
}

struct V2AdapterFlowManifest: Codable {
    let flowId: String
    let title: String
    let payloadPath: String
    let screenIds: [String]
}

struct V2AdapterTokensPayload: Codable {
    let schemaVersion: String
    let adapter: V2AdapterKind
    let appId: String
    let tokenSet: [ResolvedToken]
}

struct V2AdapterFlowPayload: Codable {
    let schemaVersion: String
    let adapter: V2AdapterKind
    let appId: String
    let flowId: String
    let title: String
    let containerName: String
    let entryScreen: String
    let deepLinks: [V2DeepLink]
    let transitions: [V2FlowTransition]
    let benchmarks: [V2BenchmarkReference]
    let screens: [V2AdapterScreenPayload]
}

struct V2AdapterScreenPayload: Codable {
    let screenId: String
    let title: String
    let route: String
    let intent: String?
    let targets: [Platform]
    let states: [String]
    let surface: V2ScreenSurface
    let previewStates: [V2PreviewState]
    let reviewChecks: [V2ReviewCheck]
    let motion: [V2MotionPattern]
    let components: [String]
    let sourcePaths: [String: String]
    let frame: V2AdapterNodePayload
}

struct V2AdapterNodePayload: Codable {
    let kind: String
    let id: String?
    let slot: String?
    let stateGuard: String?
    let repeatSource: String?
    let componentId: String?
    let props: [String: JSONValue]
    let bindings: [V2LayoutBinding]
    let componentMeta: V2AdapterComponentMeta?
    let children: [V2AdapterNodePayload]
}

struct V2AdapterComponentMeta: Codable {
    let id: String
    let kind: String
    let reviewHints: [String]
    let motionSlots: [String]
    let webImportPath: String
    let webExportName: String
    let iosComponent: String
    let androidComponent: String
}

struct V2AdapterSyncRenderer {
    init() {}

    func render(
        adapter: V2AdapterKind,
        appURL: URL,
        appSpec: V2AppSpec,
        contexts: [V2ResolvedScreenContext],
        tokens: TokenStore,
        outputDirectory: URL
    ) throws -> V2AdapterSyncReport {
        let fileManager = FileManager.default
        let flowsDirectory = outputDirectory.appendingPathComponent("flows", isDirectory: true)
        try fileManager.createDirectory(at: flowsDirectory, withIntermediateDirectories: true)

        let tokenPayloadURL = outputDirectory.appendingPathComponent("tokens.json")
        let manifestURL = outputDirectory.appendingPathComponent("manifest.json")

        try writeJSON(
            V2AdapterTokensPayload(
                schemaVersion: "2.1",
                adapter: adapter,
                appId: appSpec.appId,
                tokenSet: tokens.tokens
            ),
            to: tokenPayloadURL
        )

        var flowReports: [V2AdapterFlowSyncReport] = []
        var manifestFlows: [V2AdapterFlowManifest] = []
        var artifacts: [GeneratedArtifact] = [
            .init(kind: "\(adapter.rawValue)_tokens", path: tokenPayloadURL.path),
        ]

        let contextsByFlow = Dictionary(grouping: contexts, by: { $0.flowSpec.flowId })
        for flowRef in appSpec.flows {
            guard let flowContexts = contextsByFlow[flowRef.id], let firstContext = flowContexts.first else {
                continue
            }

            let payloadURL = flowsDirectory.appendingPathComponent("\(flowRef.id).json")
            let screens = flowContexts.map { context in
                makeScreenPayload(context: context)
            }
            let payload = V2AdapterFlowPayload(
                schemaVersion: "2.1",
                adapter: adapter,
                appId: appSpec.appId,
                flowId: firstContext.flowSpec.flowId,
                title: firstContext.flowSpec.title,
                containerName: containerName(for: firstContext.flowSpec, adapter: adapter),
                entryScreen: firstContext.flowSpec.entryScreen,
                deepLinks: firstContext.flowSpec.deepLinks,
                transitions: firstContext.flowSpec.transitions,
                benchmarks: appSpec.reviewBenchmarks,
                screens: screens
            )
            try writeJSON(payload, to: payloadURL)

            let screenIds = screens.map(\.screenId)
            flowReports.append(
                .init(
                    flowId: firstContext.flowSpec.flowId,
                    payloadPath: payloadURL.path,
                    screenIds: screenIds
                )
            )
            manifestFlows.append(
                .init(
                    flowId: firstContext.flowSpec.flowId,
                    title: firstContext.flowSpec.title,
                    payloadPath: payloadURL.path,
                    screenIds: screenIds.sorted()
                )
            )
            artifacts.append(.init(kind: "\(adapter.rawValue)_flow_payload", path: payloadURL.path))
        }

        let manifest = V2AdapterManifest(
            schemaVersion: "2.1",
            adapter: adapter,
            appId: appSpec.appId,
            title: appSpec.title,
            targetSurface: targetSurfaceName(for: adapter),
            flowPayloads: manifestFlows.sorted { $0.flowId < $1.flowId },
            generatedFiles: (artifacts.map(\.path) + [manifestURL.path]).sorted(),
            sourcePaths: [
                "app": appURL.path,
                "registry": contexts.first?.registryURL.path ?? "",
                "motion": contexts.first?.motionURL.path ?? "",
                "review": contexts.first?.reviewURL.path ?? "",
            ]
        )
        try writeJSON(manifest, to: manifestURL)
        artifacts.append(.init(kind: "\(adapter.rawValue)_manifest", path: manifestURL.path))

        return V2AdapterSyncReport(
            ok: true,
            adapter: adapter,
            appId: appSpec.appId,
            outputDirectory: outputDirectory.path,
            manifestPath: manifestURL.path,
            tokenPayloadPath: tokenPayloadURL.path,
            flows: flowReports,
            artifacts: artifacts
        )
    }

    private func makeScreenPayload(context: V2ResolvedScreenContext) -> V2AdapterScreenPayload {
        let reviewChecksById = Dictionary(uniqueKeysWithValues: context.review.checks.map { ($0.id, $0) })
        let motionById = Dictionary(uniqueKeysWithValues: context.motion.patterns.map { ($0.id, $0) })

        let reviewChecks = context.screenSpec.reviewChecklist.compactMap { reviewChecksById[$0] }
        let motion = context.screenSpec.motion.compactMap { motionById[$0.patternId] }

        return V2AdapterScreenPayload(
            screenId: context.screenSpec.screenId,
            title: context.screenSpec.title,
            route: context.screenSpec.route,
            intent: context.screenSpec.intent,
            targets: context.screenSpec.targets,
            states: context.screenSpec.states,
            surface: context.screenSpec.surface,
            previewStates: context.screenSpec.previewStates.sorted { $0.id < $1.id },
            reviewChecks: reviewChecks.sorted { $0.id < $1.id },
            motion: motion.sorted { $0.id < $1.id },
            components: collectComponentIDs(in: context.screenSpec.layout),
            sourcePaths: [
                "flow": context.flowURL.path,
                "screen": context.screenURL.path,
            ],
            frame: makeNodePayload(context.screenSpec.layout, registry: context.registry)
        )
    }

    private func makeNodePayload(_ node: V2LayoutNode, registry: V2ComponentRegistry) -> V2AdapterNodePayload {
        let componentMeta = node.componentId.flatMap { componentID in
            registry.items.first(where: { $0.id == componentID }).map { item in
                V2AdapterComponentMeta(
                    id: item.id,
                    kind: item.kind,
                    reviewHints: item.reviewHints.sorted(),
                    motionSlots: item.motionSlots.sorted(),
                    webImportPath: item.web.importPath,
                    webExportName: item.web.exportName,
                    iosComponent: item.native.ios.component,
                    androidComponent: item.native.android.component
                )
            }
        }

        return V2AdapterNodePayload(
            kind: node.kind,
            id: node.id,
            slot: node.slot,
            stateGuard: node.stateGuard,
            repeatSource: node.repeatSource,
            componentId: node.componentId,
            props: node.props,
            bindings: node.bindings,
            componentMeta: componentMeta,
            children: node.children.map { makeNodePayload($0, registry: registry) }
        )
    }

    private func collectComponentIDs(in node: V2LayoutNode) -> [String] {
        var ids: Set<String> = []
        collectComponentIDs(in: node, into: &ids)
        return ids.sorted()
    }

    private func collectComponentIDs(in node: V2LayoutNode, into ids: inout Set<String>) {
        if let componentID = node.componentId {
            ids.insert(componentID)
        }
        for child in node.children {
            collectComponentIDs(in: child, into: &ids)
        }
    }

    private func containerName(for flow: V2FlowSpec, adapter: V2AdapterKind) -> String {
        switch adapter {
        case .penpot:
            return "\(flow.title) Page"
        case .pencil:
            return "\(flow.title) Canvas"
        }
    }

    private func targetSurfaceName(for adapter: V2AdapterKind) -> String {
        switch adapter {
        case .penpot:
            return "penpot-plugin"
        case .pencil:
            return "pencil-workspace"
        }
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url)
    }
}
