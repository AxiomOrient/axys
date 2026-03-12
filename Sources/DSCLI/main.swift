import ArgumentParser
import DSCore
import Foundation

@main
struct DSCTL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dsctl",
        abstract: "Deterministic design-system control plane",
        subcommands: [
            DoctorCommand.self,
            CompileScreenDocCommand.self,
            ValidateCommand.self,
            GenerateCommand.self,
            GenerateBundleCommand.self,
            PreviewServeCommand.self,
            AuditCommand.self,
            V2Command.self,
        ]
    )
}

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor", abstract: "Report environment capabilities")

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        try printJSON(service.doctor())
    }
}

struct ValidateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate", abstract: "Validate one ScreenSpec")

    @OptionGroup var configOptions: ConfigOptions

    @Option(name: .long, help: "Path to the .screen.json file. Optional when --config and --screen-id are provided.")
    var spec: String?

    @Option(name: .long, help: "Path to the screen-doc markdown file. Optional when --config is provided.")
    var screenDoc: String?

    @Option(name: .long, help: "Screen id such as 'login'. Resolves to <screenSpecDir>/<screen-id>.screen.json when --config is provided.")
    var screenID: String?

    @Option(name: .long, help: "Path to the token directory. Optional when --config is provided.")
    var tokens: String?

    @Option(name: .long, help: "Path to the component catalog JSON file. Optional when --config is provided.")
    var catalog: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report: ValidationReport
            try validatePrimaryInput(screenID: screenID, spec: spec, screenDoc: screenDoc)

            if let configPath = configOptions.configURL {
                let resolvedConfig = try service.resolveConfig(at: configPath)
                let rawConfig = try service.loadConfig(at: configPath)
                if let screenID {
                    report = try service.validate(screenID: screenID, configPath: configPath)
                } else if let screenDoc {
                    report = try service.validate(
                        screenDocPath: resolveURL(path: screenDoc, relativeTo: resolvedConfig.projectRoot),
                        tokensDirectory: resolvedConfig.tokenDirectory,
                        catalogPath: resolvedConfig.catalogPath,
                        defaultPlatforms: rawConfig.defaultPlatforms
                    )
                } else {
                    report = try service.validate(
                        specPath: try resolvedURL(spec, name: "--spec", relativeTo: resolvedConfig.projectRoot),
                        tokensDirectory: resolvedConfig.tokenDirectory,
                        catalogPath: resolvedConfig.catalogPath
                    )
                }
            } else {
                if let screenDoc {
                    report = try service.validate(
                        screenDocPath: URL(fileURLWithPath: screenDoc),
                        tokensDirectory: try explicitURL(tokens, name: "--tokens"),
                        catalogPath: try explicitURL(catalog, name: "--catalog")
                    )
                } else {
                    report = try service.validate(
                        specPath: try explicitURL(spec, name: "--spec"),
                        tokensDirectory: try explicitURL(tokens, name: "--tokens"),
                        catalogPath: try explicitURL(catalog, name: "--catalog")
                    )
                }
            }

            try printJSON(report)
            if !report.ok {
                throw ExitCode(rawValue: 2)
            }
        } catch let code as ExitCode {
            throw code
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct CompileScreenDocCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "compile-screen-doc", abstract: "Compile one screen-doc markdown file into a ScreenSpec JSON file")

    @OptionGroup var configOptions: ConfigOptions

    @Option(name: .long, help: "Path to the screen-doc markdown file. Optional when --config and --screen-id are provided.")
    var screenDoc: String?

    @Option(name: .long, help: "Screen id such as 'login'. Resolves to <screenDocDir>/<screen-id>.md when --config is provided.")
    var screenID: String?

    @Option(name: .long, help: "Output ScreenSpec path. Optional when --config and --screen-id are provided.")
    var out: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report: CompileScreenDocReport

            if let configPath = configOptions.configURL {
                let resolvedConfig = try service.resolveConfig(at: configPath)
                if let screenID {
                    report = try service.compileScreenDoc(
                        screenID: screenID,
                        configPath: configPath,
                        outputPath: out.map { resolveURL(path: $0, relativeTo: resolvedConfig.projectRoot) }
                    )
                } else {
                    report = try service.compileScreenDoc(
                        documentPath: try resolvedURL(screenDoc, name: "--screen-doc", relativeTo: resolvedConfig.projectRoot),
                        outputPath: try resolvedURL(out, name: "--out", relativeTo: resolvedConfig.projectRoot)
                    )
                }
            } else {
                report = try service.compileScreenDoc(
                    documentPath: try explicitURL(screenDoc, name: "--screen-doc"),
                    outputPath: try explicitURL(out, name: "--out")
                )
            }

            try printJSON(report)
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct GenerateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "generate", abstract: "Generate artifacts for one ScreenSpec")

    @OptionGroup var configOptions: ConfigOptions

    @Option(name: .long, help: "Path to the .screen.json file. Optional when --config and --screen-id are provided.")
    var spec: String?

    @Option(name: .long, help: "Path to the screen-doc markdown file. Optional when --config is provided.")
    var screenDoc: String?

    @Option(name: .long, help: "Screen id such as 'login'. Resolves to <screenSpecDir>/<screen-id>.screen.json when --config is provided.")
    var screenID: String?

    @Option(name: .long, help: "Path to the token directory. Optional when --config is provided.")
    var tokens: String?

    @Option(name: .long, help: "Path to the component catalog JSON file. Optional when --config is provided.")
    var catalog: String?

    @Option(name: .long, help: "Output directory. Optional when --config and --screen-id are provided.")
    var out: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report: GenerateReport
            try validatePrimaryInput(screenID: screenID, spec: spec, screenDoc: screenDoc)

            if let configPath = configOptions.configURL {
                let resolvedConfig = try service.resolveConfig(at: configPath)
                let rawConfig = try service.loadConfig(at: configPath)
                if let screenID {
                    let outputDirectory = out.map {
                        resolveURL(path: $0, relativeTo: resolvedConfig.projectRoot)
                    }
                    report = try service.generate(screenID: screenID, configPath: configPath, outputDirectory: outputDirectory)
                } else if let screenDoc {
                    report = try service.generate(
                        screenDocPath: resolveURL(path: screenDoc, relativeTo: resolvedConfig.projectRoot),
                        tokensDirectory: resolvedConfig.tokenDirectory,
                        catalogPath: resolvedConfig.catalogPath,
                        outputDirectory: try resolvedURL(out, name: "--out", relativeTo: resolvedConfig.projectRoot),
                        defaultPlatforms: rawConfig.defaultPlatforms
                    )
                } else {
                    report = try service.generate(
                        specPath: try resolvedURL(spec, name: "--spec", relativeTo: resolvedConfig.projectRoot),
                        tokensDirectory: resolvedConfig.tokenDirectory,
                        catalogPath: resolvedConfig.catalogPath,
                        outputDirectory: try resolvedURL(out, name: "--out", relativeTo: resolvedConfig.projectRoot)
                    )
                }
            } else if let screenDoc {
                report = try service.generate(
                    screenDocPath: URL(fileURLWithPath: screenDoc),
                    tokensDirectory: try explicitURL(tokens, name: "--tokens"),
                    catalogPath: try explicitURL(catalog, name: "--catalog"),
                    outputDirectory: try explicitURL(out, name: "--out")
                )
            } else {
                report = try service.generate(
                    specPath: try explicitURL(spec, name: "--spec"),
                    tokensDirectory: try explicitURL(tokens, name: "--tokens"),
                    catalogPath: try explicitURL(catalog, name: "--catalog"),
                    outputDirectory: try explicitURL(out, name: "--out")
                )
            }

            try printJSON(report)
        } catch ProjectError.validationFailed(let report) {
            try printJSON(report)
            throw ExitCode(rawValue: 2)
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct GenerateBundleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "generate-bundle", abstract: "Generate artifacts for every ScreenSpec in a directory")

    @OptionGroup var configOptions: ConfigOptions

    @Option(name: .long, help: "Path to the ScreenSpec directory. Optional when --config is provided.")
    var specDir: String?

    @Option(name: .long, help: "Path to the screen-doc directory. Optional when --config is provided.")
    var screenDocDir: String?

    @Option(name: .long, help: "Path to the token directory. Optional when --config is provided.")
    var tokens: String?

    @Option(name: .long, help: "Path to the component catalog JSON file. Optional when --config is provided.")
    var catalog: String?

    @Option(name: .long, help: "Output directory. Optional when --config is provided.")
    var out: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report: GenerateBundleReport
            try validateBundlePrimaryInput(specDir: specDir, screenDocDir: screenDocDir, requiresOne: configOptions.configURL == nil)

            if let configPath = configOptions.configURL {
                let resolvedConfig = try service.resolveConfig(at: configPath)
                report = try service.generateBundle(
                    configPath: configPath,
                    specDirectory: specDir.map { resolveURL(path: $0, relativeTo: resolvedConfig.projectRoot) },
                    screenDocDirectory: screenDocDir.map { resolveURL(path: $0, relativeTo: resolvedConfig.projectRoot) },
                    outputDirectory: out.map { resolveURL(path: $0, relativeTo: resolvedConfig.projectRoot) }
                )
            } else if let screenDocDir {
                report = try service.generateBundle(
                    screenDocDirectory: URL(fileURLWithPath: screenDocDir),
                    tokensDirectory: try explicitURL(tokens, name: "--tokens"),
                    catalogPath: try explicitURL(catalog, name: "--catalog"),
                    outputDirectory: try explicitURL(out, name: "--out")
                )
            } else {
                report = try service.generateBundle(
                    specDirectory: try explicitURL(specDir, name: "--spec-dir"),
                    tokensDirectory: try explicitURL(tokens, name: "--tokens"),
                    catalogPath: try explicitURL(catalog, name: "--catalog"),
                    outputDirectory: try explicitURL(out, name: "--out")
                )
            }

            try printJSON(report)
            if !report.ok {
                throw ExitCode(rawValue: 4)
            }
        } catch let code as ExitCode {
            throw code
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct PreviewServeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "preview-serve", abstract: "Start a local preview server")

    @Option(name: .long) var dir: String
    @Option(name: .long) var port: Int = 4173
    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.previewServe(directory: URL(fileURLWithPath: dir), port: port)
            try printJSON(report)
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct AuditCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "audit", abstract: "Audit docs, schemas, examples, and prompts")

    @OptionGroup var configOptions: ConfigOptions

    @Option(name: .long, help: "Project root directory. Optional when --config is provided.")
    var projectRoot: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        let rootURL: URL

        if let configPath = configOptions.configURL {
            rootURL = try service.resolveConfig(at: configPath).projectRoot
        } else {
            rootURL = try explicitURL(projectRoot, name: "--project-root")
        }

        let report = try service.audit(projectRoot: rootURL)
        try printJSON(report)
        if !report.ok {
            throw ExitCode(rawValue: 5)
        }
    }
}

struct V2Command: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "v2",
        abstract: "V2 contract workflows",
        subcommands: [
            V2ValidateAppCommand.self,
            V2ValidateFlowCommand.self,
            V2ValidateScreenCommand.self,
            V2RenderHTMLCommand.self,
            V2SyncPenpotCommand.self,
            V2SyncPencilCommand.self,
            V2GenerateNativeCommand.self,
            V2BuildSampleAppsCommand.self,
            V2AuditCommand.self,
        ]
    )
}

struct V2ValidateAppCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate-app", abstract: "Validate one v2 AppSpec and its transitive contracts")

    @Option(name: .long, help: "Path to the v2 AppSpec YAML or JSON file.")
    var app: String

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.validateV2App(appPath: URL(fileURLWithPath: app))
            try printJSON(report)
            if !report.ok {
                throw ExitCode(rawValue: 2)
            }
        } catch let code as ExitCode {
            throw code
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct V2ValidateFlowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate-flow", abstract: "Validate one v2 FlowSpec and its transitive screens")

    @Option(name: .long, help: "Path to the v2 FlowSpec YAML or JSON file.")
    var flow: String

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.validateV2Flow(flowPath: URL(fileURLWithPath: flow))
            try printJSON(report)
            if !report.ok {
                throw ExitCode(rawValue: 2)
            }
        } catch let code as ExitCode {
            throw code
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct V2ValidateScreenCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate-screen", abstract: "Validate one v2 ScreenSpec in parent flow/app context")

    @Option(name: .long, help: "Path to the v2 ScreenSpec YAML or JSON file.")
    var screen: String

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.validateV2Screen(screenPath: URL(fileURLWithPath: screen))
            try printJSON(report)
            if !report.ok {
                throw ExitCode(rawValue: 2)
            }
        } catch let code as ExitCode {
            throw code
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct V2RenderHTMLCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "render-html", abstract: "Render one v2 ScreenSpec into an HTML review bundle")

    @Option(name: .long, help: "Path to the v2 ScreenSpec YAML or JSON file.")
    var screen: String

    @Option(name: .long, help: "Output directory. Defaults to build/v2-html/<screen-id> under the current working directory.")
    var out: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.renderV2HTML(
                screenPath: URL(fileURLWithPath: screen),
                outputDirectory: out.map { URL(fileURLWithPath: $0) }
            )
            try printJSON(report)
        } catch ProjectError.validationFailed(let report) {
            try printJSON(report)
            throw ExitCode(rawValue: 2)
        } catch let code as ExitCode {
            throw code
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct V2GenerateNativeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "generate-native", abstract: "Generate one v2 ScreenSpec into registry-backed native source")

    @Option(name: .long, help: "Path to the v2 ScreenSpec YAML or JSON file.")
    var screen: String

    @Option(name: .long, help: "Native platform. Supported values: ios, android.")
    var platform: String

    @Option(name: .long, help: "Output directory. Defaults to build/v2-native/<platform>/<screen-id> under the current working directory.")
    var out: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.generateV2Native(
                screenPath: URL(fileURLWithPath: screen),
                platform: try nativePlatform(from: platform),
                outputDirectory: out.map { URL(fileURLWithPath: $0) }
            )
            try printJSON(report)
        } catch ProjectError.validationFailed(let report) {
            try printJSON(report)
            throw ExitCode(rawValue: 2)
        } catch let code as ExitCode {
            throw code
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct V2SyncPenpotCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync-penpot", abstract: "Export one v2 AppSpec into a deterministic Penpot adapter payload")

    @Option(name: .long, help: "Path to the v2 AppSpec YAML or JSON file.")
    var app: String

    @Option(name: .long, help: "Output directory. Defaults to build/v2-adapters/penpot/<app-id> under the current working directory.")
    var out: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.syncV2Penpot(
                appPath: URL(fileURLWithPath: app),
                outputDirectory: out.map { URL(fileURLWithPath: $0) }
            )
            try printJSON(report)
        } catch ProjectError.validationFailed(let report) {
            try printJSON(report)
            throw ExitCode(rawValue: 2)
        } catch let code as ExitCode {
            throw code
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct V2SyncPencilCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync-pencil", abstract: "Export one v2 AppSpec into a deterministic Pencil adapter payload")

    @Option(name: .long, help: "Path to the v2 AppSpec YAML or JSON file.")
    var app: String

    @Option(name: .long, help: "Output directory. Defaults to build/v2-adapters/pencil/<app-id> under the current working directory.")
    var out: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.syncV2Pencil(
                appPath: URL(fileURLWithPath: app),
                outputDirectory: out.map { URL(fileURLWithPath: $0) }
            )
            try printJSON(report)
        } catch ProjectError.validationFailed(let report) {
            try printJSON(report)
            throw ExitCode(rawValue: 2)
        } catch let code as ExitCode {
            throw code
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct V2BuildSampleAppsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "build-sample-apps", abstract: "Build and runtime-smoke v2 sample app harnesses for one AppSpec")

    @Option(name: .long, help: "Path to the v2 AppSpec YAML or JSON file.")
    var app: String

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.buildV2SampleApps(appPath: URL(fileURLWithPath: app))
            try printJSON(report)
        } catch ProjectError.validationFailed(let report) {
            try printJSON(report)
            throw ExitCode(rawValue: 2)
        } catch let code as ExitCode {
            throw code
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct V2AuditCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "audit", abstract: "Run the full v2 app contract, adapter, HTML, and sample-build audit loop")

    @Option(name: .long, help: "Path to the v2 AppSpec YAML or JSON file.")
    var app: String

    @Option(name: .long, help: "Output directory. Defaults to build/v2-audit/<app-id> under the current working directory.")
    var out: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.auditV2(
                appPath: URL(fileURLWithPath: app),
                outputDirectory: out.map { URL(fileURLWithPath: $0) }
            )
            try printJSON(report)
        } catch ProjectError.validationFailed(let report) {
            try printJSON(report)
            throw ExitCode(rawValue: 2)
        } catch let code as ExitCode {
            throw code
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct ConfigOptions: ParsableArguments {
    @Option(name: .long, help: "Path to dsctl.config.json. When present, token/catalog/build defaults are resolved from this file.")
    var config: String?

    var configURL: URL? {
        config.map { URL(fileURLWithPath: $0) }
    }
}

private func explicitURL(_ value: String?, name: String) throws -> URL {
    guard let value, !value.isEmpty else {
        throw ProjectError.invalidArgument("Missing required option \(name)")
    }
    return URL(fileURLWithPath: value)
}

private func resolvedURL(_ value: String?, name: String, relativeTo base: URL) throws -> URL {
    guard let value, !value.isEmpty else {
        throw ProjectError.invalidArgument("Missing required option \(name)")
    }
    return resolveURL(path: value, relativeTo: base)
}

private func resolveURL(path: String, relativeTo base: URL) -> URL {
    if path.hasPrefix("/") {
        return URL(fileURLWithPath: path).standardizedFileURL
    }
    return base.appendingPathComponent(path).standardizedFileURL
}

private func nativePlatform(from raw: String) throws -> Platform {
    guard let platform = Platform(rawValue: raw), platform != .html else {
        throw ProjectError.invalidArgument("Unsupported native platform '\(raw)'. Use ios or android.")
    }
    return platform
}

private func printJSON<T: Encodable>(_ value: T) throws {
    let service = ProjectService()
    let output = try service.encodeJSON(value)
    print(output)
}

private func printOperationalError(_ error: Error) throws {
    try printJSON(OperationErrorReport(error: error.localizedDescription))
}

private func validatePrimaryInput(screenID: String?, spec: String?, screenDoc: String?) throws {
    let providedInputs = [screenID, spec, screenDoc].compactMap { value in
        value?.isEmpty == false ? value : nil
    }
    if providedInputs.count != 1 {
        throw ProjectError.invalidArgument("Use exactly one of --screen-id, --spec, or --screen-doc")
    }
}

private func validateBundlePrimaryInput(specDir: String?, screenDocDir: String?, requiresOne: Bool) throws {
    let providedInputs = [specDir, screenDocDir].compactMap { value in
        value?.isEmpty == false ? value : nil
    }
    if providedInputs.count > 1 {
        throw ProjectError.invalidArgument("Use exactly one of --spec-dir or --screen-doc-dir")
    }
    if requiresOne && providedInputs.isEmpty {
        throw ProjectError.invalidArgument("Missing required option --spec-dir or --screen-doc-dir")
    }
}
