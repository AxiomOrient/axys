import DSCore
import Foundation
import MCP

public enum DSMCPServerFactory {
    public static let toolNames = [
        "doctor",
        "validate_app",
        "validate_flow",
        "validate_screen",
        "render_html",
        "generate_native",
        "sync_penpot",
        "sync_pencil",
        "build_sample_apps",
        "preview_serve",
        "audit",
    ]

    public static func makeServer(service: ProjectService = ProjectService()) async -> Server {
        let server = Server(
            name: "axys",
            version: "0.1.0",
            capabilities: .init(tools: .init(listChanged: true))
        )

        await registerToolList(on: server)
        await registerToolCalls(on: server, service: service)
        return server
    }

    private static func registerToolList(on server: Server) async {
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: [
                Tool(
                    name: "doctor",
                    description: "Report environment capabilities",
                    inputSchema: .object([:])
                ),
                Tool(
                    name: "validate_app",
                    description: "Validate one AppSpec and its contracts",
                    inputSchema: .object([
                        "properties": .object([
                            "app": .string("Path to the AppSpec YAML or JSON file"),
                        ])
                    ])
                ),
                Tool(
                    name: "validate_flow",
                    description: "Validate one FlowSpec and its screens",
                    inputSchema: .object([
                        "properties": .object([
                            "flow": .string("Path to the FlowSpec YAML or JSON file"),
                        ])
                    ])
                ),
                Tool(
                    name: "validate_screen",
                    description: "Validate one screen contract inside its flow/app context",
                    inputSchema: .object([
                        "properties": .object([
                            "screen": .string("Path to the screen contract YAML or JSON file"),
                        ])
                    ])
                ),
                Tool(
                    name: "render_html",
                    description: "Render one screen contract into an HTML review bundle",
                    inputSchema: .object([
                        "properties": .object([
                            "screen": .string("Path to the screen contract YAML or JSON file"),
                            "out": .string("Output directory for the HTML report"),
                        ])
                    ])
                ),
                Tool(
                    name: "generate_native",
                    description: "Generate one screen contract into registry-backed native source",
                    inputSchema: .object([
                        "properties": .object([
                            "screen": .string("Path to the screen contract YAML or JSON file"),
                            "platform": .string("Native platform (ios|android)"),
                            "out": .string("Output directory for generated native sources"),
                        ])
                    ])
                ),
                Tool(
                    name: "sync_penpot",
                    description: "Export one AppSpec into a deterministic Penpot payload",
                    inputSchema: .object([
                        "properties": .object([
                            "app": .string("Path to the AppSpec YAML or JSON file"),
                            "out": .string("Output directory for the adapter payload"),
                        ])
                    ])
                ),
                Tool(
                    name: "sync_pencil",
                    description: "Export one AppSpec into a deterministic Pencil payload",
                    inputSchema: .object([
                        "properties": .object([
                            "app": .string("Path to the AppSpec YAML or JSON file"),
                            "out": .string("Output directory for the adapter payload"),
                        ])
                    ])
                ),
                Tool(
                    name: "build_sample_apps",
                    description: "Build and smoke-test sample app harnesses",
                    inputSchema: .object([
                        "properties": .object([
                            "app": .string("Path to the AppSpec YAML or JSON file"),
                        ])
                    ])
                ),
                Tool(
                    name: "preview_serve",
                    description: "Serve a preview bundle directory over HTTP",
                    inputSchema: .object([
                        "properties": .object([
                            "directory": .string("Directory to serve"),
                            "port": .object(["type": .string("integer")]),
                        ])
                    ])
                ),
                Tool(
                    name: "audit",
                    description: "Check that the repo still matches the active contract-first shape",
                    inputSchema: .object([
                        "properties": .object([
                            "projectRoot": .string("Project root to inspect"),
                        ])
                    ])
                ),
            ])
        }
    }

    private static func registerToolCalls(on server: Server, service: ProjectService) async {
        await server.withMethodHandler(CallTool.self) { params in
            do {
                switch params.name {
                case "doctor":
                    return .init(content: [.text(try service.encodeJSON(service.doctor()))], isError: false)
                case "validate_app":
                    let report = try service.validateApp(appPath: URL(fileURLWithPath: try requiredString("app", in: params.arguments)))
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                case "validate_flow":
                    let report = try service.validateFlow(flowPath: URL(fileURLWithPath: try requiredString("flow", in: params.arguments)))
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                case "validate_screen":
                    let report = try service.validateScreen(screenPath: URL(fileURLWithPath: try requiredString("screen", in: params.arguments)))
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                case "render_html":
                    let screen = try requiredString("screen", in: params.arguments)
                    let outputURL = optionalString("out", in: params.arguments).map { URL(fileURLWithPath: $0) }
                    let report = try service.renderHTML(
                        screenPath: URL(fileURLWithPath: screen),
                        outputDirectory: outputURL
                    )
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                case "generate_native":
                    let screen = try requiredString("screen", in: params.arguments)
                    let platform = try nativePlatform(from: requiredString("platform", in: params.arguments))
                    let outputURL = optionalString("out", in: params.arguments).map { URL(fileURLWithPath: $0) }
                    let report = try service.generateNative(
                        screenPath: URL(fileURLWithPath: screen),
                        platform: platform,
                        outputDirectory: outputURL
                    )
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                case "sync_penpot":
                    let app = try requiredString("app", in: params.arguments)
                    let outputURL = optionalString("out", in: params.arguments).map { URL(fileURLWithPath: $0) }
                    let report = try service.syncPenpot(
                        appPath: URL(fileURLWithPath: app),
                        outputDirectory: outputURL
                    )
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                case "sync_pencil":
                    let app = try requiredString("app", in: params.arguments)
                    let outputURL = optionalString("out", in: params.arguments).map { URL(fileURLWithPath: $0) }
                    let report = try service.syncPencil(
                        appPath: URL(fileURLWithPath: app),
                        outputDirectory: outputURL
                    )
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                case "build_sample_apps":
                    let app = try requiredString("app", in: params.arguments)
                    let report = try service.buildSampleApps(
                        appPath: URL(fileURLWithPath: app)
                    )
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                case "preview_serve":
                    let report = try service.previewServe(
                        directory: URL(fileURLWithPath: try requiredString("directory", in: params.arguments)),
                        port: Int(optionalString("port", in: params.arguments) ?? "4173") ?? 4173
                    )
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                case "audit":
                    let projectRoot = optionalString("projectRoot", in: params.arguments) ?? "."
                    let report = try service.audit(projectRoot: URL(fileURLWithPath: projectRoot))
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                default:
                    let report = OperationErrorReport(error: "Unknown tool: \(params.name)")
                    return .init(content: [.text(try service.encodeJSON(report))], isError: true)
                }
            } catch ProjectError.validationFailed(let report) {
                let text = (try? service.encodeJSON(report)) ?? #"{"ok":false,"issues":[],"summary":"Validation failed"}"#
                return .init(content: [.text(text)], isError: true)
            } catch {
                let report = OperationErrorReport(error: error.localizedDescription)
                let text = (try? service.encodeJSON(report)) ?? #"{"ok":false,"error":"Unknown MCP error"}"#
                return .init(content: [.text(text)], isError: true)
            }
        }
    }

    private static func requiredString(_ key: String, in arguments: [String: Value]?) throws -> String {
        guard let value = arguments?[key]?.stringValue, !value.isEmpty else {
            throw ProjectError.invalidArgument("Missing required argument: \(key)")
        }
        return value
    }

    private static func optionalString(_ key: String, in arguments: [String: Value]?) -> String? {
        guard let value = arguments?[key]?.stringValue, !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func nativePlatform(from raw: String) throws -> Platform {
        guard let platform = Platform(rawValue: raw), platform != .html else {
            throw ProjectError.invalidArgument("Unsupported native platform '\(raw)'. Use ios or android.")
        }
        return platform
    }
}
