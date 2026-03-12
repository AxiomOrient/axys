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
            ValidateAppCommand.self,
            ValidateFlowCommand.self,
            ValidateScreenCommand.self,
            RenderHTMLCommand.self,
            GenerateNativeCommand.self,
            SyncPenpotCommand.self,
            SyncPencilCommand.self,
            BuildSampleAppsCommand.self,
            PreviewServeCommand.self,
            AuditCommand.self,
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

struct ValidateAppCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate-app", abstract: "Validate one AppSpec and its transitive contracts")

    @Option(name: .long, help: "Path to the AppSpec YAML or JSON file.")
    var app: String

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.validateApp(appPath: URL(fileURLWithPath: app))
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

struct ValidateFlowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate-flow", abstract: "Validate one FlowSpec and its transitive screens")

    @Option(name: .long, help: "Path to the FlowSpec YAML or JSON file.")
    var flow: String

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.validateFlow(flowPath: URL(fileURLWithPath: flow))
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

struct ValidateScreenCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate-screen", abstract: "Validate one screen contract in parent flow/app context")

    @Option(name: .long, help: "Path to the screen contract YAML or JSON file.")
    var screen: String

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.validateScreen(screenPath: URL(fileURLWithPath: screen))
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

struct RenderHTMLCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "render-html", abstract: "Render one screen contract into an HTML review bundle")

    @Option(name: .long, help: "Path to the screen contract YAML or JSON file.")
    var screen: String

    @Option(name: .long, help: "Output directory. Defaults to build/html/<screen-id> under the current working directory.")
    var out: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.renderHTML(
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

struct GenerateNativeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "generate-native", abstract: "Generate one screen contract into registry-backed native source")

    @Option(name: .long, help: "Path to the screen contract YAML or JSON file.")
    var screen: String

    @Option(name: .long, help: "Native platform. Supported values: ios, android.")
    var platform: String

    @Option(name: .long, help: "Output directory. Defaults to build/native/<platform>/<screen-id> under the current working directory.")
    var out: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.generateNative(
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

struct SyncPenpotCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync-penpot", abstract: "Export one AppSpec into a deterministic Penpot adapter payload")

    @Option(name: .long, help: "Path to the AppSpec YAML or JSON file.")
    var app: String

    @Option(name: .long, help: "Output directory. Defaults to build/adapters/penpot/<app-id> under the current working directory.")
    var out: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.syncPenpot(
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

struct SyncPencilCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync-pencil", abstract: "Export one AppSpec into a deterministic Pencil adapter payload")

    @Option(name: .long, help: "Path to the AppSpec YAML or JSON file.")
    var app: String

    @Option(name: .long, help: "Output directory. Defaults to build/adapters/pencil/<app-id> under the current working directory.")
    var out: String?

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.syncPencil(
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

struct BuildSampleAppsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "build-sample-apps", abstract: "Build and runtime-smoke sample app harnesses for one AppSpec")

    @Option(name: .long, help: "Path to the AppSpec YAML or JSON file.")
    var app: String

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.buildSampleApps(appPath: URL(fileURLWithPath: app))
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

struct PreviewServeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "preview-serve", abstract: "Serve a preview bundle directory over HTTP")

    @Option(name: .long, help: "Directory to serve.")
    var directory: String

    @Option(name: .long, help: "Port to bind. Defaults to 4173.")
    var port: Int = 4173

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.previewServe(
                directory: URL(fileURLWithPath: directory),
                port: port
            )
            try printJSON(report)
        } catch let code as ExitCode {
            throw code
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
}

struct AuditCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "audit", abstract: "Check that the repo still matches the active contract-first shape")

    @Option(name: .long, help: "Project root to inspect. Defaults to the current working directory.")
    var projectRoot: String = "."

    @Flag(name: .long) var json = false

    func run() async throws {
        let service = ProjectService()
        do {
            let report = try service.audit(projectRoot: URL(fileURLWithPath: projectRoot))
            try printJSON(report)
        } catch let code as ExitCode {
            throw code
        } catch {
            try printOperationalError(error)
            throw ExitCode(rawValue: 1)
        }
    }
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
