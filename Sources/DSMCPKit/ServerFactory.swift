import DSCore
import Foundation
import MCP

public enum DSMCPServerFactory {
    public static let toolNames = [
        "doctor",
        "compile_screen_doc",
        "validate_spec",
        "generate_screen",
        "generate_bundle",
        "preview_serve",
        "audit_project",
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
                    name: "compile_screen_doc",
                    description: "Compile one screen-doc markdown file into a ScreenSpec JSON file",
                    inputSchema: .object([
                        "properties": .object([
                            "config": .string("Path to dsctl.config.json"),
                            "screenId": .string("Screen id such as 'login'"),
                            "screenDoc": .string("Path to the screen-doc markdown file"),
                            "out": .string("Output path for the compiled .screen.json file"),
                        ])
                    ])
                ),
                Tool(
                    name: "validate_spec",
                    description: "Validate one ScreenSpec or one screen-doc",
                    inputSchema: .object([
                        "properties": .object([
                            "spec": .string("Path to the .screen.json file"),
                            "screenDoc": .string("Path to the screen-doc markdown file"),
                            "tokens": .string("Path to the token directory"),
                            "catalog": .string("Path to the component catalog JSON file"),
                        ])
                    ])
                ),
                Tool(
                    name: "generate_bundle",
                    description: "Generate artifacts for every ScreenSpec or screen-doc in a directory",
                    inputSchema: .object([
                        "properties": .object([
                            "specDir": .string("Path to the ScreenSpec directory"),
                            "screenDocDir": .string("Path to the screen-doc directory"),
                            "tokens": .string("Path to the token directory"),
                            "catalog": .string("Path to the component catalog JSON file"),
                            "out": .string("Output directory for generated artifacts"),
                        ])
                    ])
                ),
                Tool(
                    name: "generate_screen",
                    description: "Generate artifacts for one ScreenSpec or one screen-doc",
                    inputSchema: .object([
                        "properties": .object([
                            "spec": .string("Path to the .screen.json file"),
                            "screenDoc": .string("Path to the screen-doc markdown file"),
                            "tokens": .string("Path to the token directory"),
                            "catalog": .string("Path to the component catalog JSON file"),
                            "out": .string("Output directory for generated artifacts"),
                        ])
                    ])
                ),
                Tool(
                    name: "preview_serve",
                    description: "Start a local HTML preview server",
                    inputSchema: .object([
                        "properties": .object([
                            "dir": .string("Directory that contains generated HTML preview artifacts"),
                            "port": .string("Port number to serve on"),
                        ])
                    ])
                ),
                Tool(
                    name: "audit_project",
                    description: "Audit docs, schemas, examples, and prompts",
                    inputSchema: .object([
                        "properties": .object([
                            "projectRoot": .string("Project root path"),
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
                case "compile_screen_doc":
                    let report: CompileScreenDocReport
                    if let config = optionalString("config", in: params.arguments) {
                        let configURL = URL(fileURLWithPath: config)
                        let resolvedConfig = try service.resolveConfig(at: configURL)

                        if let screenID = optionalString("screenId", in: params.arguments) {
                            report = try service.compileScreenDoc(
                                screenID: screenID,
                                configPath: configURL,
                                outputPath: optionalString("out", in: params.arguments).map {
                                    resolveFileURL(path: $0, relativeTo: resolvedConfig.projectRoot)
                                }
                            )
                        } else {
                            let screenDoc = try requiredString("screenDoc", in: params.arguments)
                            let outputPath = try requiredString("out", in: params.arguments)
                            report = try service.compileScreenDoc(
                                documentPath: resolveFileURL(path: screenDoc, relativeTo: resolvedConfig.projectRoot),
                                outputPath: resolveFileURL(path: outputPath, relativeTo: resolvedConfig.projectRoot)
                            )
                        }
                    } else {
                        let screenDoc = try requiredString("screenDoc", in: params.arguments)
                        let outputPath = try requiredString("out", in: params.arguments)
                        report = try service.compileScreenDoc(
                            documentPath: URL(fileURLWithPath: screenDoc),
                            outputPath: URL(fileURLWithPath: outputPath)
                        )
                    }
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                case "validate_spec":
                    let tokens = try requiredString("tokens", in: params.arguments)
                    let catalog = try requiredString("catalog", in: params.arguments)
                    let selection = try exclusiveStringPair("spec", "screenDoc", in: params.arguments)

                    let report: ValidationReport
                    if selection.selectedKey == "screenDoc" {
                        report = try service.validate(
                            screenDocPath: URL(fileURLWithPath: selection.value),
                            tokensDirectory: URL(fileURLWithPath: tokens),
                            catalogPath: URL(fileURLWithPath: catalog)
                        )
                    } else {
                        report = try service.validate(
                            specPath: URL(fileURLWithPath: selection.value),
                            tokensDirectory: URL(fileURLWithPath: tokens),
                            catalogPath: URL(fileURLWithPath: catalog)
                        )
                    }
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                case "generate_bundle":
                    let tokens = try requiredString("tokens", in: params.arguments)
                    let catalog = try requiredString("catalog", in: params.arguments)
                    let outputDirectory = try requiredString("out", in: params.arguments)
                    let selection = try exclusiveStringPair("specDir", "screenDocDir", in: params.arguments)

                    let report: GenerateBundleReport
                    if selection.selectedKey == "screenDocDir" {
                        report = try service.generateBundle(
                            screenDocDirectory: URL(fileURLWithPath: selection.value),
                            tokensDirectory: URL(fileURLWithPath: tokens),
                            catalogPath: URL(fileURLWithPath: catalog),
                            outputDirectory: URL(fileURLWithPath: outputDirectory)
                        )
                    } else {
                        report = try service.generateBundle(
                            specDirectory: URL(fileURLWithPath: selection.value),
                            tokensDirectory: URL(fileURLWithPath: tokens),
                            catalogPath: URL(fileURLWithPath: catalog),
                            outputDirectory: URL(fileURLWithPath: outputDirectory)
                        )
                    }
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                case "generate_screen":
                    let tokens = try requiredString("tokens", in: params.arguments)
                    let catalog = try requiredString("catalog", in: params.arguments)
                    let outputDirectory = try requiredString("out", in: params.arguments)
                    let selection = try exclusiveStringPair("spec", "screenDoc", in: params.arguments)

                    let report: GenerateReport
                    if selection.selectedKey == "screenDoc" {
                        report = try service.generate(
                            screenDocPath: URL(fileURLWithPath: selection.value),
                            tokensDirectory: URL(fileURLWithPath: tokens),
                            catalogPath: URL(fileURLWithPath: catalog),
                            outputDirectory: URL(fileURLWithPath: outputDirectory)
                        )
                    } else {
                        report = try service.generate(
                            specPath: URL(fileURLWithPath: selection.value),
                            tokensDirectory: URL(fileURLWithPath: tokens),
                            catalogPath: URL(fileURLWithPath: catalog),
                            outputDirectory: URL(fileURLWithPath: outputDirectory)
                        )
                    }
                    return .init(content: [.text(try service.encodeJSON(report))], isError: !report.ok)
                case "preview_serve":
                    let directory = try requiredString("dir", in: params.arguments)
                    let port = try previewPort(in: params.arguments)
                    let report = try service.previewServe(directory: URL(fileURLWithPath: directory), port: port)
                    return .init(content: [.text(try service.encodeJSON(report))], isError: false)
                case "audit_project":
                    let projectRoot = try requiredString("projectRoot", in: params.arguments)
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

    private static func exclusiveStringPair(_ firstKey: String, _ secondKey: String, in arguments: [String: Value]?) throws -> (selectedKey: String, value: String) {
        let firstValue = optionalString(firstKey, in: arguments)
        let secondValue = optionalString(secondKey, in: arguments)

        switch (firstValue, secondValue) {
        case let (.some(value), nil):
            return (firstKey, value)
        case let (nil, .some(value)):
            return (secondKey, value)
        default:
            throw ProjectError.invalidArgument("Use exactly one of \(firstKey) or \(secondKey)")
        }
    }

    private static func previewPort(in arguments: [String: Value]?) throws -> Int {
        guard let raw = optionalString("port", in: arguments) else {
            return 4173
        }
        guard let port = Int(raw) else {
            throw ProjectError.invalidArgument("Preview port must be an integer: \(raw)")
        }
        return port
    }

    private static func resolveFileURL(path: String, relativeTo base: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return base.appendingPathComponent(path)
    }
}
