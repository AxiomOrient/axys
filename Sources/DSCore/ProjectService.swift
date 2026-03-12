import DSDocSyncKit
import Foundation

public struct ProjectService: Sendable {
    private let requiredAcceptanceReviewCheckIDs: Set<String> = [
        "structure.primary_intent",
        "semantics.preview_coverage",
        "tokens.alias_usage",
        "native.adapter_viability",
    ]

    public init() {}

    public func compileScreenDoc(screenID: String, configPath: URL, outputPath: URL? = nil) throws -> CompileScreenDocReport {
        let config = try resolveConfig(at: configPath)
        let rawConfig = try loadConfig(at: configPath)
        return try compileScreenDoc(
            documentPath: config.screenDocDirectory.appendingPathComponent("\(screenID).md"),
            outputPath: outputPath ?? config.defaultCompiledSpecPath(screenID: screenID),
            defaultPlatforms: rawConfig.defaultPlatforms
        )
    }

    public func compileScreenDoc(documentPath: URL, outputPath: URL, defaultPlatforms: [Platform]? = nil) throws -> CompileScreenDocReport {
        let compiled = try ScreenDocCompiler().compile(documentURL: documentPath, defaultPlatforms: defaultPlatforms)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let directory = outputPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(compiled.spec).write(to: outputPath)

        let reportPath = compileReportPath(for: outputPath)
        let report = CompileScreenDocReport(
            ok: true,
            screenId: compiled.spec.screenId,
            inputPath: documentPath.path,
            outputPath: outputPath.path,
            reportPath: reportPath.path,
            completionStatus: compiled.unresolvedItems.isEmpty ? .complete : .starter,
            warnings: compiled.warnings,
            unresolvedItems: compiled.unresolvedItems
        )
        try encoder.encode(report).write(to: reportPath)

        return report
    }

    public func doctor() -> DoctorReport {
        let toolchains = DoctorToolchains(
            swiftc: commandSucceeds("swiftc", arguments: ["--version"]),
            python3: commandSucceeds("python3", arguments: ["--version"]),
            javaRuntime: commandSucceeds("java", arguments: ["-version"]),
            kotlin: commandSucceeds("kotlin", arguments: ["-version"]),
            kotlinc: commandSucceeds("kotlinc", arguments: ["-version"]),
            gradle: commandSucceeds("gradle", arguments: ["--version"])
        )
        return DoctorReport(
            ok: true,
            swiftVersion: swiftVersionString(),
            capabilities: DoctorCapabilities(
                cli: true,
                mcp: true,
                iosRenderer: true,
                androidRenderer: true,
                htmlPreview: toolchains.python3,
                iosHostSmoke: toolchains.swiftc,
                androidHostSmoke: toolchains.javaRuntime && (toolchains.kotlinc || toolchains.gradle)
            ),
            toolchains: toolchains
        )
    }

    public func loadConfig(at url: URL) throws -> DSConfig {
        try decode(DSConfig.self, from: url)
    }

    public func resolveConfig(at url: URL) throws -> ResolvedDSConfig {
        try loadConfig(at: url).resolvePaths(configPath: url)
    }

    public func validate(screenID: String, configPath: URL) throws -> ValidationReport {
        let config = try resolveConfig(at: configPath)
        return try validate(
            specPath: config.screenSpecPath(screenID: screenID),
            tokensDirectory: config.tokenDirectory,
            catalogPath: config.catalogPath
        )
    }

    public func validate(screenDocPath: URL, tokensDirectory: URL, catalogPath: URL, defaultPlatforms: [Platform]? = nil) throws -> ValidationReport {
        let compiled = try ScreenDocCompiler().compile(documentURL: screenDocPath, defaultPlatforms: defaultPlatforms)
        return try validate(compiledScreenDoc: compiled, tokensDirectory: tokensDirectory, catalogPath: catalogPath)
    }

    public func validate(specPath: URL, tokensDirectory: URL, catalogPath: URL) throws -> ValidationReport {
        let spec = try decode(ScreenSpec.self, from: specPath)
        return try validate(
            spec: spec,
            tokensDirectory: tokensDirectory,
            catalogPath: catalogPath
        )
    }

    public func validate(spec: ScreenSpec, tokensDirectory: URL, catalogPath: URL) throws -> ValidationReport {
        let catalog = try decode(ComponentCatalog.self, from: catalogPath)
        let tokenFiles = try listJSONFiles(in: tokensDirectory)
        let tokens = try TokenCompiler().compile(tokenFiles: tokenFiles)
        return ProjectValidator().validate(spec: spec, tokens: tokens, catalog: catalog)
    }

    public func validateV2App(appPath: URL) throws -> ValidationReport {
        try V2ProjectValidator().validateApp(at: appPath)
    }

    public func validateV2Flow(flowPath: URL) throws -> ValidationReport {
        try V2ProjectValidator().validateFlow(at: flowPath)
    }

    public func validateV2Screen(screenPath: URL) throws -> ValidationReport {
        try V2ProjectValidator().validateScreen(at: screenPath)
    }

    public func renderV2HTML(screenPath: URL, outputDirectory: URL? = nil) throws -> V2RenderHTMLReport {
        let validation = try validateV2Screen(screenPath: screenPath)
        guard validation.ok else {
            throw ProjectError.validationFailed(validation)
        }

        let validator = V2ProjectValidator()
        let context = try validator.resolveScreenContext(at: screenPath)
        let tokens = try compileV2Tokens(appSpec: context.appSpec, appURL: context.appURL, contractRoot: context.contractRoot)
        let resolvedOutput = outputDirectory ?? defaultV2HTMLOutputDirectory(screenID: context.screenSpec.screenId)

        return try V2HTMLRenderer().render(
            context: context,
            tokens: tokens,
            outputDirectory: resolvedOutput
        )
    }

    public func generateV2Native(screenPath: URL, platform: Platform, outputDirectory: URL? = nil) throws -> V2GenerateNativeReport {
        let validation = try validateV2Screen(screenPath: screenPath)
        guard validation.ok else {
            throw ProjectError.validationFailed(validation)
        }

        guard platform == .ios || platform == .android else {
            throw ProjectError.invalidArgument("v2 generate-native only supports --platform ios|android")
        }

        let validator = V2ProjectValidator()
        let context = try validator.resolveScreenContext(at: screenPath)

        guard context.screenSpec.targets.contains(platform) else {
            throw ProjectError.invalidArgument("Screen \(context.screenSpec.screenId) does not declare target platform \(platform.rawValue)")
        }

        let tokens = try compileV2Tokens(appSpec: context.appSpec, appURL: context.appURL, contractRoot: context.contractRoot)
        let resolvedOutput = outputDirectory ?? defaultV2NativeOutputDirectory(screenID: context.screenSpec.screenId, platform: platform)

        return try V2NativeRenderer().render(
            context: context,
            tokens: tokens,
            platform: platform,
            outputDirectory: resolvedOutput
        )
    }

    public func syncV2Penpot(appPath: URL, outputDirectory: URL? = nil) throws -> V2AdapterSyncReport {
        try syncV2Adapter(.penpot, appPath: appPath, outputDirectory: outputDirectory)
    }

    public func syncV2Pencil(appPath: URL, outputDirectory: URL? = nil) throws -> V2AdapterSyncReport {
        try syncV2Adapter(.pencil, appPath: appPath, outputDirectory: outputDirectory)
    }

    public func auditV2(appPath: URL, outputDirectory: URL? = nil) throws -> V2AuditReport {
        let validation = try validateV2App(appPath: appPath)
        guard validation.ok else {
            throw ProjectError.validationFailed(validation)
        }

        let loader = V2DocumentLoader()
        let validator = V2ProjectValidator()
        let appSpec = try loader.load(V2AppSpec.self, from: appPath)
        let contractRoot = validator.resolveContractRoot(startingAt: appPath)
        let tokens = try compileV2Tokens(appSpec: appSpec, appURL: appPath, contractRoot: contractRoot)
        let contexts = try resolveV2AppScreenContexts(appSpec: appSpec, appURL: appPath, contractRoot: contractRoot)
        let resolvedOutput = outputDirectory ?? defaultV2AuditOutputDirectory(appId: appSpec.appId)

        try FileManager.default.createDirectory(at: resolvedOutput, withIntermediateDirectories: true)

        let validationReportURL = resolvedOutput.appendingPathComponent("validation.report.json")
        try writeJSON(validation, to: validationReportURL)

        let htmlRoot = resolvedOutput.appendingPathComponent("html", isDirectory: true)
        var htmlReports: [V2RenderHTMLReport] = []
        for context in contexts {
            let htmlOutput = htmlRoot.appendingPathComponent(context.screenSpec.screenId, isDirectory: true)
            let htmlReport = try V2HTMLRenderer().render(
                context: context,
                tokens: tokens,
                outputDirectory: htmlOutput
            )
            htmlReports.append(htmlReport)
        }

        let penpotReport = try syncV2Penpot(
            appPath: appPath,
            outputDirectory: resolvedOutput.appendingPathComponent("adapters/penpot", isDirectory: true)
        )
        let pencilReport = try syncV2Pencil(
            appPath: appPath,
            outputDirectory: resolvedOutput.appendingPathComponent("adapters/pencil", isDirectory: true)
        )
        let sampleAppsReport = try buildV2SampleApps(appPath: appPath)
        let sampleAppsReportURL = resolvedOutput.appendingPathComponent("sample-app-build.report.json")
        try writeJSON(sampleAppsReport, to: sampleAppsReportURL)

        var artifacts: [GeneratedArtifact] = [
            .init(kind: "v2_validation_report", path: validationReportURL.path),
            .init(kind: "v2_penpot_manifest", path: penpotReport.manifestPath),
            .init(kind: "v2_pencil_manifest", path: pencilReport.manifestPath),
            .init(kind: "v2_sample_build_report", path: sampleAppsReportURL.path),
        ]
        artifacts.append(contentsOf: htmlReports.map { .init(kind: "v2_html_review_report", path: $0.reviewReportPath) })

        return V2AuditReport(
            ok: true,
            appId: appSpec.appId,
            outputDirectory: resolvedOutput.path,
            validationReportPath: validationReportURL.path,
            htmlScreens: htmlReports,
            penpotSync: penpotReport,
            pencilSync: pencilReport,
            sampleApps: sampleAppsReport,
            sampleAppsReportPath: sampleAppsReportURL.path,
            artifacts: artifacts
        )
    }

    public func buildV2SampleApps(appPath: URL) throws -> V2BuildSampleAppsReport {
        let validation = try validateV2App(appPath: appPath)
        guard validation.ok else {
            throw ProjectError.validationFailed(validation)
        }

        let loader = V2DocumentLoader()
        let validator = V2ProjectValidator()
        let appSpec = try loader.load(V2AppSpec.self, from: appPath)
        let contractRoot = validator.resolveContractRoot(startingAt: appPath)
        let doctorReport = doctor()

        var platformReports: [V2SampleAppPlatformBuildReport] = []
        let supportedPlatforms = appSpec.targetPlatforms.filter { $0 == .ios || $0 == .android }

        for platform in supportedPlatforms {
            switch platform {
            case .ios:
                guard doctorReport.capabilities.iosHostSmoke else {
                    throw ProjectError.invalidArgument("iOS sample app build requires doctor ios_host_smoke=true")
                }
            case .android:
                guard doctorReport.capabilities.androidHostSmoke else {
                    throw ProjectError.invalidArgument("Android sample app build requires doctor android_host_smoke=true")
                }
            case .html:
                continue
            }

            let sampleRoot = try resolveV2SampleAppRoot(appSpec: appSpec, appURL: appPath, contractRoot: contractRoot, platform: platform)
            try FileManager.default.createDirectory(at: sampleRoot, withIntermediateDirectories: true)
            try ensureV2SampleAppReadme(at: sampleRoot, platform: platform, appId: appSpec.appId)

            let screenURLs = try resolveV2AppScreenURLs(appSpec: appSpec, appURL: appPath, contractRoot: contractRoot)
            var screenReports: [V2SampleAppScreenBuildReport] = []

            for screenURL in screenURLs {
                let screenSpec = try loader.load(V2ScreenSpec.self, from: screenURL)
                let nativeReport = try generateV2Native(
                    screenPath: screenURL,
                    platform: platform,
                    outputDirectory: sampleRoot
                        .appendingPathComponent("GeneratedUI", isDirectory: true)
                        .appendingPathComponent(platform.rawValue, isDirectory: true)
                        .appendingPathComponent(screenSpec.screenId, isDirectory: true)
                )

                let wrapperDirectory = sampleRoot
                    .appendingPathComponent("HostSmoke", isDirectory: true)
                    .appendingPathComponent(platform.rawValue, isDirectory: true)
                let logsDirectory = sampleRoot
                    .appendingPathComponent("BuildArtifacts", isDirectory: true)
                    .appendingPathComponent(platform.rawValue, isDirectory: true)

                try FileManager.default.createDirectory(at: wrapperDirectory, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

                let wrapperURL = wrapperDirectory.appendingPathComponent(nativeReport.screenId + sampleWrapperExtension(for: platform))
                let buildLogURL = logsDirectory.appendingPathComponent("\(nativeReport.screenId).build.log")
                let runtimeLogURL = logsDirectory.appendingPathComponent("\(nativeReport.screenId).runtime.log")

                try buildV2SampleScreen(
                    generatedOutputDirectory: URL(fileURLWithPath: nativeReport.outputDirectory, isDirectory: true),
                    screenId: nativeReport.screenId,
                    platform: platform,
                    wrapperURL: wrapperURL,
                    buildLogURL: buildLogURL,
                    runtimeLogURL: runtimeLogURL
                )

                screenReports.append(
                    .init(
                        screenId: nativeReport.screenId,
                        outputDirectory: nativeReport.outputDirectory,
                        wrapperPath: wrapperURL.path,
                        buildLogPath: buildLogURL.path,
                        runtimeLogPath: runtimeLogURL.path
                    )
                )
            }

            platformReports.append(
                .init(
                    platform: platform,
                    sampleAppPath: sampleRoot.path,
                    screens: screenReports
                )
            )
        }

        return V2BuildSampleAppsReport(ok: true, appId: appSpec.appId, platforms: platformReports)
    }

    public func generate(screenID: String, configPath: URL, outputDirectory: URL? = nil) throws -> GenerateReport {
        let config = try resolveConfig(at: configPath)
        return try generate(
            specPath: config.screenSpecPath(screenID: screenID),
            tokensDirectory: config.tokenDirectory,
            catalogPath: config.catalogPath,
            outputDirectory: outputDirectory ?? config.defaultScreenOutputDirectory(screenID: screenID)
        )
    }

    public func generate(screenDocPath: URL, tokensDirectory: URL, catalogPath: URL, outputDirectory: URL, defaultPlatforms: [Platform]? = nil) throws -> GenerateReport {
        let compiled = try ScreenDocCompiler().compile(documentURL: screenDocPath, defaultPlatforms: defaultPlatforms)
        let validation = try validate(compiledScreenDoc: compiled, tokensDirectory: tokensDirectory, catalogPath: catalogPath)

        guard validation.ok else {
            throw ProjectError.validationFailed(validation)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let compiledSpecPath = outputDirectory.appendingPathComponent("compiled.screen.json")
        try encoder.encode(compiled.spec).write(to: compiledSpecPath)

        return try generate(
            specPath: compiledSpecPath,
            tokensDirectory: tokensDirectory,
            catalogPath: catalogPath,
            outputDirectory: outputDirectory
        )
    }

    public func generate(specPath: URL, tokensDirectory: URL, catalogPath: URL, outputDirectory: URL) throws -> GenerateReport {
        let spec = try decode(ScreenSpec.self, from: specPath)
        let catalog = try decode(ComponentCatalog.self, from: catalogPath)
        let tokenFiles = try listJSONFiles(in: tokensDirectory)
        let tokens = try TokenCompiler().compile(tokenFiles: tokenFiles)
        let validation = ProjectValidator().validate(spec: spec, tokens: tokens, catalog: catalog)

        guard validation.ok else {
            throw ProjectError.validationFailed(validation)
        }

        return try ProjectGenerator().generate(
            spec: spec,
            tokens: tokens,
            specPath: specPath,
            tokenPaths: tokenFiles,
            outputDirectory: outputDirectory,
            validationReport: validation
        )
    }

    public func generateBundle(configPath: URL, specDirectory: URL? = nil, screenDocDirectory: URL? = nil, outputDirectory: URL? = nil) throws -> GenerateBundleReport {
        let config = try resolveConfig(at: configPath)
        let rawConfig = try loadConfig(at: configPath)

        if let screenDocDirectory {
            return try generateBundle(
                screenDocDirectory: screenDocDirectory,
                tokensDirectory: config.tokenDirectory,
                catalogPath: config.catalogPath,
                outputDirectory: outputDirectory ?? config.defaultBundleOutputDirectory,
                defaultPlatforms: rawConfig.defaultPlatforms
            )
        }

        return try generateBundle(
            specDirectory: specDirectory ?? config.screenSpecDirectory,
            tokensDirectory: config.tokenDirectory,
            catalogPath: config.catalogPath,
            outputDirectory: outputDirectory ?? config.defaultBundleOutputDirectory
        )
    }

    public func generateBundle(specDirectory: URL, tokensDirectory: URL, catalogPath: URL, outputDirectory: URL) throws -> GenerateBundleReport {
        let fileManager = FileManager.default
        let specFiles = try fileManager.contentsOfDirectory(at: specDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasSuffix(".screen.json") }
            .sorted { $0.path < $1.path }

        var reports: [GenerateReport] = []
        var failures: [String] = []

        for specPath in specFiles {
            let screenName = specPath.deletingPathExtension().deletingPathExtension().lastPathComponent
            let screenOutput = outputDirectory.appendingPathComponent(screenName, isDirectory: true)
            do {
                let report = try generate(
                    specPath: specPath,
                    tokensDirectory: tokensDirectory,
                    catalogPath: catalogPath,
                    outputDirectory: screenOutput
                )
                reports.append(report)
            } catch {
                failures.append("\(specPath.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return GenerateBundleReport(reports: reports, failures: failures)
    }

    public func generateBundle(screenDocDirectory: URL, tokensDirectory: URL, catalogPath: URL, outputDirectory: URL, defaultPlatforms: [Platform]? = nil) throws -> GenerateBundleReport {
        let fileManager = FileManager.default
        let screenDocFiles = try fileManager.contentsOfDirectory(at: screenDocDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
            .sorted { $0.path < $1.path }

        var reports: [GenerateReport] = []
        var failures: [String] = []

        for screenDocPath in screenDocFiles {
            let screenName = screenDocPath.deletingPathExtension().lastPathComponent
            let screenOutput = outputDirectory.appendingPathComponent(screenName, isDirectory: true)
            do {
                let report = try generate(
                    screenDocPath: screenDocPath,
                    tokensDirectory: tokensDirectory,
                    catalogPath: catalogPath,
                    outputDirectory: screenOutput,
                    defaultPlatforms: defaultPlatforms
                )
                reports.append(report)
            } catch {
                failures.append("\(screenDocPath.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return GenerateBundleReport(reports: reports, failures: failures)
    }

    public func audit(projectRoot: URL) throws -> AuditReport {
        let fileManager = FileManager.default
        let docsDirectory = projectRoot.appendingPathComponent("docs", isDirectory: true)
        let schemasDirectory = projectRoot.appendingPathComponent("schemas", isDirectory: true)
        let examplesDirectory = projectRoot.appendingPathComponent("examples", isDirectory: true)
        let promptsDirectory = projectRoot.appendingPathComponent("prompts", isDirectory: true)

        let coreFiles = [
            "README.md",
            "MASTER_BLUEPRINT.md",
            "AGENTS.md",
            "docs/11-execution-plan.md",
            "docs/12-task-matrix.md",
            "docs/20-traceability-matrix.md",
            "schemas/screen-spec.schema.json",
            "schemas/component-catalog.schema.json",
            "schemas/dsctl.config.schema.json",
            "examples/catalogs/component-catalog.json",
            "examples/configs/dsctl.config.json",
            "examples/screens/login.screen.json",
            "examples/screens/product-detail.screen.json",
            "examples/tokens/core.tokens.json",
            "examples/tokens/theme.light.tokens.json",
            "prompts/spec-generation.md",
            "prompts/review-and-fix.md",
        ]

        let missingFiles = coreFiles.filter { !fileManager.fileExists(atPath: projectRoot.appendingPathComponent($0).path) }

        let docFiles = directoryContentsIfPresent(at: docsDirectory)
            .filter { $0.pathExtension == "md" }
            .sorted { $0.path < $1.path }
        let schemaFiles = directoryContentsIfPresent(at: schemasDirectory)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.path < $1.path }
        let exampleJSONFiles = fileManager.enumerator(at: examplesDirectory, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "json" }
            .sorted { $0.path < $1.path } ?? []
        let promptFiles = directoryContentsIfPresent(at: promptsDirectory)
            .filter { $0.pathExtension == "md" }
            .sorted { $0.path < $1.path }

        var parseErrors: [String] = []
        for url in schemaFiles + exampleJSONFiles + [
            projectRoot.appendingPathComponent("MANIFEST.json"),
        ] where fileManager.fileExists(atPath: url.path) {
            do {
                _ = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
            } catch {
                parseErrors.append("\(url.path): \(error.localizedDescription)")
            }
        }

        var markdownErrors: [String] = []
        for url in [projectRoot.appendingPathComponent("README.md"), projectRoot.appendingPathComponent("MASTER_BLUEPRINT.md"), projectRoot.appendingPathComponent("AGENTS.md")] + docFiles + promptFiles {
            guard fileManager.fileExists(atPath: url.path) else {
                continue
            }
            let content = try String(contentsOf: url)
            markdownErrors.append(contentsOf: brokenRelativeLinks(in: content, file: url))
        }

        let configURL = projectRoot.appendingPathComponent("examples/configs/dsctl.config.json")
        let catalogURL = projectRoot.appendingPathComponent("examples/catalogs/component-catalog.json")
        let tokensDirectory = projectRoot.appendingPathComponent("examples/tokens", isDirectory: true)
        let loginReport = try? validate(
            specPath: projectRoot.appendingPathComponent("examples/screens/login.screen.json"),
            tokensDirectory: tokensDirectory,
            catalogPath: catalogURL
        )
        if loginReport == nil {
            parseErrors.append("\(projectRoot.appendingPathComponent("examples/screens/login.screen.json").path): validation input is unavailable")
        }
        let productReport = try? validate(
            specPath: projectRoot.appendingPathComponent("examples/screens/product-detail.screen.json"),
            tokensDirectory: tokensDirectory,
            catalogPath: catalogURL
        )
        if productReport == nil {
            parseErrors.append("\(projectRoot.appendingPathComponent("examples/screens/product-detail.screen.json").path): validation input is unavailable")
        }

        var warnings: [String] = []

        if
            let resolvedConfig = try? resolveConfig(at: configURL),
            let rawConfig = try? loadConfig(at: configURL),
            let catalog = try? decode(ComponentCatalog.self, from: catalogURL),
            let tokenFiles = try? listJSONFiles(in: tokensDirectory),
            let compiledTokens = try? TokenCompiler().compile(tokenFiles: tokenFiles)
        {
            let compiler = ScreenDocCompiler()
            let screenDocFiles = directoryContentsIfPresent(at: resolvedConfig.screenDocDirectory)
                .filter { $0.pathExtension == "md" }
                .sorted { $0.path < $1.path }

            for url in screenDocFiles {
                do {
                    let compiled = try compiler.compile(documentURL: url, defaultPlatforms: rawConfig.defaultPlatforms)
                    warnings.append(contentsOf: compiled.warnings.map { "\(url.lastPathComponent): \($0)" })
                    let compiledReport = ProjectValidator().validate(spec: compiled.spec, tokens: compiledTokens, catalog: catalog)
                    if !compiledReport.ok {
                        parseErrors.append("\(url.path): compiled screen-doc does not validate")
                    }
                } catch {
                    parseErrors.append("\(url.path): \(error.localizedDescription)")
                }
            }
        } else if fileManager.fileExists(atPath: configURL.path) {
            parseErrors.append("\(configURL.path): audit dependencies could not be loaded")
        }

        let docSyncManifestURL = {
            if let contracts = runtimeContracts(projectRoot: projectRoot) {
                return resolveProjectPath(contracts.paths.docSyncManifest, relativeTo: projectRoot)
            }
            return projectRoot.appendingPathComponent("meta/views/docsync.manifest.json")
        }()
        var docSyncErrors: [String] = []
        var docSyncFreshness = true
        if fileManager.fileExists(atPath: docSyncManifestURL.path) {
            do {
                let report = try DocSyncService().verify(manifestPath: docSyncManifestURL, projectRoot: projectRoot)
                docSyncFreshness = report.ok
                docSyncErrors.append(contentsOf: report.staleDocuments.map { "doc-sync freshness failed: \($0)" })
                docSyncErrors.append(contentsOf: report.errors.map { "doc-sync verify failed: \($0)" })
            } catch {
                docSyncFreshness = false
                docSyncErrors.append("doc-sync verify failed: \(error.localizedDescription)")
            }
        }

        let contractViewVerifyReport = try? ContractViewExportService().verify(projectRoot: projectRoot)
        let contractViewFreshness = contractViewVerifyReport?.ok ?? false
        let contractViewErrors = contractViewVerifyReport.map {
            $0.staleViews.map { "contract view freshness failed: \($0)" } +
            $0.errors.map { "contract view verify failed: \($0)" }
        } ?? ["contract view verify failed: unable to render authoritative contract views"]

        let contractCheck = validateAuthoritativeContractReferences(projectRoot: projectRoot)
        let evidenceArtifactErrors = validateGovernanceEvidenceArtifacts(projectRoot: projectRoot)

        let missingFileErrors = missingFiles.map { "Missing core file: \($0)" }
        let errors =
            missingFileErrors +
            parseErrors +
            markdownErrors +
            docSyncErrors +
            contractViewErrors +
            evidenceArtifactErrors +
            contractCheck.errors
        let checks = IntegrityChecks(
            coreFilesExist: missingFiles.isEmpty,
            jsonParse: parseErrors.isEmpty && evidenceArtifactErrors.isEmpty,
            schemaValidation: (loginReport?.ok ?? false) && (productReport?.ok ?? false),
            markdownRelativeLinks: markdownErrors.isEmpty,
            docSyncFreshness: docSyncFreshness,
            contractViewFreshness: contractViewFreshness,
            contractCrossReference: contractCheck.ok,
            docCount: docFiles.count,
            schemaCount: schemaFiles.count,
            exampleJSONCount: exampleJSONFiles.count,
            promptCount: promptFiles.count
        )

        return AuditReport(
            ok: checks.coreFilesExist && checks.jsonParse && checks.schemaValidation && checks.markdownRelativeLinks && checks.docSyncFreshness && checks.contractViewFreshness && checks.contractCrossReference,
            checks: checks,
            errors: errors,
            warnings: warnings
        )
    }

    public func previewServe(directory: URL, port: Int) throws -> PreviewServeReport {
        guard (1...65_535).contains(port) else {
            throw ProjectError.invalidArgument("Preview port must be between 1 and 65535: \(port)")
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory) else {
            throw ProjectError.invalidArgument("Preview directory does not exist: \(directory.path)")
        }
        guard isDirectory.boolValue else {
            throw ProjectError.invalidArgument("Preview directory is not a directory: \(directory.path)")
        }

        let previewURL = try URL(string: "http://127.0.0.1:\(port)/").unwrap("Unable to construct preview URL")
        guard localPreviewPortIsAvailable(port) else {
            throw ProjectError.generationFailed("Preview server failed to start at \(previewURL.absoluteString). The port may already be in use.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-m", "http.server", String(port), "--directory", directory.path]

        let nullHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: "/dev/null"))
        defer { try? nullHandle.close() }
        process.standardOutput = nullHandle
        process.standardError = nullHandle

        try process.run()

        do {
            try waitForPreviewServer(url: previewURL, process: process)
        } catch {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }

            if let projectError = error as? ProjectError {
                throw projectError
            }
            throw ProjectError.generationFailed("Preview server failed to start at \(previewURL.absoluteString). The port may already be in use.")
        }

        return PreviewServeReport(
            ok: true,
            url: previewURL.absoluteString,
            pid: process.processIdentifier,
            directory: directory.path
        )
    }

    public func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        return try String(data: data, encoding: .utf8).unwrap("Unable to encode JSON output")
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url)
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }

    private func compileV2Tokens(appSpec: V2AppSpec, appURL: URL, contractRoot: URL) throws -> TokenStore {
        let validator = V2ProjectValidator()
        let tokenReference = validator.resolveReference(appSpec.tokenSet, contractRoot: contractRoot, relativeTo: appURL)
        let tokenFiles: [URL]

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: tokenReference.path, isDirectory: &isDirectory), isDirectory.boolValue {
            tokenFiles = try listJSONFiles(in: tokenReference)
        } else {
            let directory = tokenReference.deletingLastPathComponent()
            tokenFiles = try listJSONFiles(in: directory)
        }

        return try TokenCompiler().compile(tokenFiles: tokenFiles)
    }

    private func defaultV2HTMLOutputDirectory(screenID: String) -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("build/v2-html/\(screenID)", isDirectory: true)
    }

    private func defaultV2NativeOutputDirectory(screenID: String, platform: Platform) -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("build/v2-native/\(platform.rawValue)/\(screenID)", isDirectory: true)
    }

    private func defaultV2AdapterOutputDirectory(appId: String, adapter: V2AdapterKind) -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("build/v2-adapters/\(adapter.rawValue)/\(appId)", isDirectory: true)
    }

    private func defaultV2AuditOutputDirectory(appId: String) -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("build/v2-audit/\(appId)", isDirectory: true)
    }

    private func syncV2Adapter(
        _ adapter: V2AdapterKind,
        appPath: URL,
        outputDirectory: URL?
    ) throws -> V2AdapterSyncReport {
        let validation = try validateV2App(appPath: appPath)
        guard validation.ok else {
            throw ProjectError.validationFailed(validation)
        }

        let loader = V2DocumentLoader()
        let validator = V2ProjectValidator()
        let appSpec = try loader.load(V2AppSpec.self, from: appPath)
        let contractRoot = validator.resolveContractRoot(startingAt: appPath)
        let contexts = try resolveV2AppScreenContexts(appSpec: appSpec, appURL: appPath, contractRoot: contractRoot)
        let tokens = try compileV2Tokens(appSpec: appSpec, appURL: appPath, contractRoot: contractRoot)
        let resolvedOutput = outputDirectory ?? defaultV2AdapterOutputDirectory(appId: appSpec.appId, adapter: adapter)

        return try V2AdapterSyncRenderer().render(
            adapter: adapter,
            appURL: appPath,
            appSpec: appSpec,
            contexts: contexts,
            tokens: tokens,
            outputDirectory: resolvedOutput
        )
    }

    private func resolveV2SampleAppRoot(appSpec: V2AppSpec, appURL: URL, contractRoot: URL, platform: Platform) throws -> URL {
        let validator = V2ProjectValidator()
        switch platform {
        case .ios:
            guard let path = appSpec.sampleApps?.ios, !path.isEmpty else {
                throw ProjectError.invalidArgument("AppSpec.sampleApps.ios is required for v2 build-sample-apps")
            }
            return validator.resolveReference(path, contractRoot: contractRoot, relativeTo: appURL)
        case .android:
            guard let path = appSpec.sampleApps?.android, !path.isEmpty else {
                throw ProjectError.invalidArgument("AppSpec.sampleApps.android is required for v2 build-sample-apps")
            }
            return validator.resolveReference(path, contractRoot: contractRoot, relativeTo: appURL)
        case .html:
            throw ProjectError.invalidArgument("v2 build-sample-apps only supports ios and android")
        }
    }

    private func resolveV2AppScreenURLs(appSpec: V2AppSpec, appURL: URL, contractRoot: URL) throws -> [URL] {
        let loader = V2DocumentLoader()
        let validator = V2ProjectValidator()
        var screenURLs: [URL] = []
        var seen: Set<String> = []

        for flowRef in appSpec.flows {
            let flowURL = validator.resolveReference(flowRef.path, contractRoot: contractRoot, relativeTo: appURL)
            let flowSpec = try loader.load(V2FlowSpec.self, from: flowURL)
            for screenRef in flowSpec.screens {
                let screenURL = validator.resolveReference(screenRef.path, contractRoot: contractRoot, relativeTo: flowURL)
                if seen.insert(screenURL.standardizedFileURL.path).inserted {
                    screenURLs.append(screenURL.standardizedFileURL)
                }
            }
        }

        return screenURLs.sorted { $0.path < $1.path }
    }

    private func resolveV2AppScreenContexts(appSpec: V2AppSpec, appURL: URL, contractRoot: URL) throws -> [V2ResolvedScreenContext] {
        let loader = V2DocumentLoader()
        let validator = V2ProjectValidator()
        var contexts: [V2ResolvedScreenContext] = []
        var seen: Set<String> = []

        for flowRef in appSpec.flows {
            let flowURL = validator.resolveReference(flowRef.path, contractRoot: contractRoot, relativeTo: appURL)
            let flowSpec = try loader.load(V2FlowSpec.self, from: flowURL)
            for screenRef in flowSpec.screens {
                let screenURL = validator.resolveReference(screenRef.path, contractRoot: contractRoot, relativeTo: flowURL).standardizedFileURL
                if seen.insert(screenURL.path).inserted {
                    contexts.append(try validator.resolveScreenContext(at: screenURL))
                }
            }
        }

        return contexts
    }

    private func ensureV2SampleAppReadme(at root: URL, platform: Platform, appId: String) throws {
        let readmeURL = root.appendingPathComponent("README.md")
        guard !FileManager.default.fileExists(atPath: readmeURL.path) else {
            return
        }

        let title = platform == .ios ? "iOS" : "Android"
        try """
        # \(title) Sample App Harness

        This is a source-owned v2 sample app harness root for `\(appId)`.
        Generated files under `GeneratedUI/` and `BuildArtifacts/` are disposable.
        """.write(to: readmeURL, atomically: true, encoding: .utf8)
    }

    private func sampleWrapperExtension(for platform: Platform) -> String {
        switch platform {
        case .ios:
            return "SampleHost.swift"
        case .android:
            return "SampleHost.kt"
        case .html:
            return ".txt"
        }
    }

    private func buildV2SampleScreen(
        generatedOutputDirectory: URL,
        screenId: String,
        platform: Platform,
        wrapperURL: URL,
        buildLogURL: URL,
        runtimeLogURL: URL
    ) throws {
        let scratchDirectory = generatedOutputDirectory.appendingPathComponent(".host-smoke", isDirectory: true)
        try FileManager.default.createDirectory(at: scratchDirectory, withIntermediateDirectories: true)

        switch platform {
        case .ios:
            let generatedScreenURL = generatedOutputDirectory.appendingPathComponent(screenTypeName(from: screenId) + ".swift")
            try renderV2SwiftSampleWrapper(screenId: screenId).write(to: wrapperURL, atomically: true, encoding: .utf8)
            let preparedSources = try prepareV2SwiftSampleBuildSources(screenURL: generatedScreenURL, wrapperURL: wrapperURL, scratchDirectory: scratchDirectory)
            let mainURL = scratchDirectory.appendingPathComponent("main.swift")
            try renderV2SwiftRuntimeEntry(screenId: screenId).write(to: mainURL, atomically: true, encoding: .utf8)
            let executableURL = scratchDirectory.appendingPathComponent("sample-host")
            let buildResult = try runProcess(
                executableURL: URL(fileURLWithPath: "/usr/bin/swiftc"),
                arguments: preparedSources.map(\.path) + [mainURL.path, "-o", executableURL.path],
                currentDirectoryURL: generatedOutputDirectory
            )
            try (buildResult.stdout + buildResult.stderr).write(to: buildLogURL, atomically: true, encoding: .utf8)

            let runtimeResult = try runProcess(
                executableURL: executableURL,
                arguments: [],
                currentDirectoryURL: generatedOutputDirectory
            )
            try (runtimeResult.stdout + runtimeResult.stderr).write(to: runtimeLogURL, atomically: true, encoding: .utf8)
        case .android:
            let generatedScreenURL = generatedOutputDirectory.appendingPathComponent(screenTypeName(from: screenId) + ".kt")
            try renderV2KotlinSampleWrapper(screenId: screenId).write(to: wrapperURL, atomically: true, encoding: .utf8)
            let preparedSources = try prepareV2KotlinSampleBuildSources(screenURL: generatedScreenURL, wrapperURL: wrapperURL, scratchDirectory: scratchDirectory)
            let compilerURL = try resolvedKotlinCompilerURL()
            let mainURL = scratchDirectory.appendingPathComponent("Main.kt")
            try renderV2KotlinRuntimeEntry(screenId: screenId).write(to: mainURL, atomically: true, encoding: .utf8)
            let outputURL = scratchDirectory.appendingPathComponent("sample-host.jar")
            let buildResult = try runProcess(
                executableURL: compilerURL,
                arguments: preparedSources.map(\.path) + [mainURL.path, "-include-runtime", "-d", outputURL.path],
                currentDirectoryURL: generatedOutputDirectory,
                environment: kotlinSmokeEnvironment()
            )
            try (buildResult.stdout + buildResult.stderr).write(to: buildLogURL, atomically: true, encoding: .utf8)

            let javaURL = try resolvedJavaCommandURL()
            let runtimeResult = try runProcess(
                executableURL: javaURL,
                arguments: ["-jar", outputURL.path],
                currentDirectoryURL: generatedOutputDirectory,
                environment: commandEnvironment(for: "java", executableURL: javaURL)
            )
            try (runtimeResult.stdout + runtimeResult.stderr).write(to: runtimeLogURL, atomically: true, encoding: .utf8)
        case .html:
            throw ProjectError.invalidArgument("v2 build-sample-apps only supports ios and android")
        }
    }

    private func swiftVersionString() -> String {
        let toolCandidates = ["/usr/bin/swift", "/usr/bin/xcrun"]

        for tool in toolCandidates where FileManager.default.isExecutableFile(atPath: tool) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = tool.hasSuffix("xcrun") ? ["swift", "--version"] : ["--version"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty {
                    return output
                }
            } catch {
                continue
            }
        }

        return "unknown"
    }

    private func commandSucceeds(_ command: String, arguments: [String]) -> Bool {
        guard let executableURL = resolvedCommandURL(for: command) else {
            return false
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = commandEnvironment(for: command, executableURL: executableURL)
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func commandEnvironment(for command: String, executableURL: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        var pathEntries = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }

        let executableDirectory = executableURL.deletingLastPathComponent().path
        if !pathEntries.contains(executableDirectory) {
            pathEntries.insert(executableDirectory, at: 0)
        }

        if command == "java", environment["JAVA_HOME"]?.isEmpty != false {
            let javaHomeCandidate = executableURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path

            if FileManager.default.isExecutableFile(atPath: executableURL.path) {
                environment["JAVA_HOME"] = javaHomeCandidate
                let javaBin = "\(javaHomeCandidate)/bin"
                if !pathEntries.contains(javaBin) {
                    pathEntries.insert(javaBin, at: 0)
                }
            }
        }

        environment["PATH"] = pathEntries.joined(separator: ":")
        return environment
    }

    private func resolvedCommandURL(for command: String) -> URL? {
        let fileManager = FileManager.default
        let environment = ProcessInfo.processInfo.environment

        if let javaHome = environment["JAVA_HOME"], command == "java" {
            let javaHomeCandidate = URL(fileURLWithPath: javaHome, isDirectory: true)
                .appendingPathComponent("bin")
                .appendingPathComponent("java")
            if fileManager.isExecutableFile(atPath: javaHomeCandidate.path) {
                return javaHomeCandidate
            }
        }

        if command == "java" {
            for fallbackPath in fallbackCommandPaths(for: command) {
                if fileManager.isExecutableFile(atPath: fallbackPath) {
                    return URL(fileURLWithPath: fallbackPath)
                }
            }
        }

        let pathEntries = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }

        for entry in pathEntries {
            let candidate = URL(fileURLWithPath: entry, isDirectory: true).appendingPathComponent(command)
            if command == "java", candidate.path == "/usr/bin/java" {
                continue
            }
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        for fallbackPath in fallbackCommandPaths(for: command) {
            if fileManager.isExecutableFile(atPath: fallbackPath) {
                return URL(fileURLWithPath: fallbackPath)
            }
        }

        return nil
    }

    private func fallbackCommandPaths(for command: String) -> [String] {
        switch command {
        case "java":
            return [
                "/opt/homebrew/opt/openjdk/bin/java",
                "/usr/local/opt/openjdk/bin/java",
                "/Library/Java/JavaVirtualMachines/openjdk.jdk/Contents/Home/bin/java",
            ]
        case "kotlin", "kotlinc", "gradle":
            return [
                "/opt/homebrew/bin/\(command)",
                "/usr/local/bin/\(command)",
            ]
        default:
            return []
        }
    }

    private func runProcess(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL,
        environment: [String: String]? = nil
    ) throws -> ProcessExecution {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        if let environment {
            process.environment = environment
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let stdoutText = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderrText = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw ProjectError.io(
                [
                    "Command failed: \(executableURL.path) \(arguments.joined(separator: " "))",
                    stdoutText.trimmingCharacters(in: .whitespacesAndNewlines),
                    stderrText.trimmingCharacters(in: .whitespacesAndNewlines),
                ]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            )
        }

        return ProcessExecution(stdout: stdoutText, stderr: stderrText)
    }

    private func prepareV2SwiftSampleBuildSources(screenURL: URL, wrapperURL: URL, scratchDirectory: URL) throws -> [URL] {
        let stubsURL = scratchDirectory.appendingPathComponent("SwiftUIStubs.swift")
        try """
        protocol View {}

        struct EmptyView: View {}
        """.write(to: stubsURL, atomically: true, encoding: .utf8)

        let distilledURL = scratchDirectory.appendingPathComponent(screenURL.lastPathComponent)
        try distilledV2SwiftHostSmokeSource(from: screenURL).write(to: distilledURL, atomically: true, encoding: .utf8)

        let wrapperCopyURL = scratchDirectory.appendingPathComponent(wrapperURL.lastPathComponent)
        try String(contentsOf: wrapperURL).write(to: wrapperCopyURL, atomically: true, encoding: .utf8)

        return [stubsURL, distilledURL, wrapperCopyURL]
    }

    private func distilledV2SwiftHostSmokeSource(from source: URL) throws -> String {
        let withoutPreviews = try strippedSwiftUIImports(from: source).components(separatedBy: "\n#Preview").first ?? ""
        let lines = withoutPreviews.components(separatedBy: "\n")

        guard
            let screenStructIndex = lines.lastIndex(where: {
                $0.trimmingCharacters(in: .whitespaces).hasPrefix("struct ") &&
                $0.contains(": View {")
            }),
            let bodyIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "var body: some View {" })
        else {
            return withoutPreviews
        }

        let prefix = lines[..<bodyIndex].joined(separator: "\n")
        let indent = String(lines[bodyIndex].prefix { $0 == " " })
        let properties = lines[(screenStructIndex + 1)..<bodyIndex].compactMap(hostSmokeProperty)
        let initializer = properties.isEmpty
            ? ""
            : """

        \(indent)init(\(properties.map(\.parameter).joined(separator: ", "))) {
        \(properties.map { "\(indent)    \($0.assignment)" }.joined(separator: "\n"))
        \(indent)}
        """

        return """
        \(prefix)
        \(initializer)
        \(indent)var body: some View {
        \(indent)    EmptyView()
        \(indent)}
        }
        """
    }

    private func hostSmokeProperty(from line: String) -> HostSmokeProperty? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.hasPrefix("let ") || trimmed.hasPrefix("var ") {
            let declaration = String(trimmed.dropFirst(4))
            let parts = declaration.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2 else {
                return nil
            }
            return HostSmokeProperty(
                parameter: "\(parts[0]): \(parts[1])",
                assignment: "self.\(parts[0]) = \(parts[0])"
            )
        }

        return nil
    }

    private func strippedSwiftUIImports(from source: URL) throws -> String {
        try String(contentsOf: source)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.trimmingCharacters(in: .whitespaces) != "import SwiftUI" }
            .joined(separator: "\n")
    }

    private func renderV2SwiftSampleWrapper(screenId: String) -> String {
        let typeName = screenTypeName(from: screenId)
        return """
        func build\(typeName)Sample() {
            _ = \(typeName)(
                state: \(typeName)State(),
                actions: \(typeName)Actions(),
                navigation: \(typeName)Navigation()
            )
        }
        """
    }

    private func renderV2SwiftRuntimeEntry(screenId: String) -> String {
        let typeName = screenTypeName(from: screenId)
        return """
        build\(typeName)Sample()
        print("runtime-smoke:ok:\(screenId)")
        """
    }

    private func prepareV2KotlinSampleBuildSources(screenURL: URL, wrapperURL: URL, scratchDirectory: URL) throws -> [URL] {
        let stubsURL = scratchDirectory.appendingPathComponent("ComposeRuntimeStubs.kt")
        try """
        package androidx.compose.runtime

        annotation class Composable
        """.write(to: stubsURL, atomically: true, encoding: .utf8)

        let distilledURL = scratchDirectory.appendingPathComponent(screenURL.lastPathComponent)
        try distilledV2KotlinHostSmokeSource(from: screenURL).write(to: distilledURL, atomically: true, encoding: .utf8)

        let wrapperCopyURL = scratchDirectory.appendingPathComponent(wrapperURL.lastPathComponent)
        try String(contentsOf: wrapperURL).write(to: wrapperCopyURL, atomically: true, encoding: .utf8)

        return [stubsURL, distilledURL, wrapperCopyURL]
    }

    private func distilledV2KotlinHostSmokeSource(from source: URL) throws -> String {
        let withoutPreviews = (
            try strippedKotlinImports(
                from: source,
                keeping: ["androidx.compose.runtime.Composable"]
            )
        ).components(separatedBy: "\n@Preview").first ?? ""
        let lines = withoutPreviews.components(separatedBy: "\n")

        guard
            let composableIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "@Composable" }),
            let functionStartIndex = lines[(composableIndex + 1)...].firstIndex(where: {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("fun ")
            }),
            let signatureEndIndex = lines[functionStartIndex...].firstIndex(where: {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(") {")
            })
        else {
            return withoutPreviews
        }

        let prefix = lines[...signatureEndIndex].joined(separator: "\n")
        let indent = String(lines[signatureEndIndex].prefix { $0 == " " || $0 == "\t" })

        return """
        \(prefix)
        \(indent)}
        """
    }

    private func strippedKotlinImports(from source: URL, keeping keptImports: Set<String>) throws -> String {
        try String(contentsOf: source)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") else {
                    return true
                }
                let importPath = String(trimmed.dropFirst("import ".count))
                return keptImports.contains(importPath)
            }
            .joined(separator: "\n")
    }

    private func renderV2KotlinSampleWrapper(screenId: String) -> String {
        let typeName = screenTypeName(from: screenId)
        return """
        import androidx.compose.runtime.Composable

        @Composable
        fun build\(typeName)Sample() {
            \(typeName)(
                state = \(typeName)State(),
                actions = \(typeName)Actions(),
                navigation = \(typeName)Navigation()
            )
        }
        """
    }

    private func renderV2KotlinRuntimeEntry(screenId: String) -> String {
        let typeName = screenTypeName(from: screenId)
        return """
        fun main() {
            build\(typeName)Sample()
            println("runtime-smoke:ok:\(screenId)")
        }
        """
    }

    private func resolvedKotlinCompilerURL() throws -> URL {
        if let compilerURL = resolvedCommandURL(for: "kotlinc") {
            return compilerURL
        }

        throw ProjectError.io("Missing kotlinc for Android sample app build")
    }

    private func resolvedJavaCommandURL() throws -> URL {
        if let javaURL = resolvedCommandURL(for: "java") {
            return javaURL
        }

        throw ProjectError.io("Missing java for Android sample app runtime smoke")
    }

    private func kotlinSmokeEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let fallbackJavaHomes = [
            "/opt/homebrew/opt/openjdk",
            "/usr/local/opt/openjdk",
            "/Library/Java/JavaVirtualMachines/openjdk.jdk/Contents/Home",
        ]

        if environment["JAVA_HOME"]?.isEmpty != false {
            if let javaHome = fallbackJavaHomes.first(where: {
                FileManager.default.isExecutableFile(atPath: "\($0)/bin/java")
            }) {
                environment["JAVA_HOME"] = javaHome
            }
        }

        var pathEntries = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        for entry in ["/opt/homebrew/bin", "/usr/local/bin"] where !pathEntries.contains(entry) {
            pathEntries.insert(entry, at: 0)
        }
        if let javaHome = environment["JAVA_HOME"] {
            let javaBin = "\(javaHome)/bin"
            if !pathEntries.contains(javaBin) {
                pathEntries.insert(javaBin, at: 0)
            }
        }
        environment["PATH"] = pathEntries.joined(separator: ":")
        return environment
    }

    private func screenTypeName(from screenID: String) -> String {
        let parts = screenID
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else {
            return "Screen"
        }

        return parts.map { part in
            guard let first = part.first else { return part }
            return first.uppercased() + part.dropFirst()
        }.joined() + "Screen"
    }

    private func listJSONFiles(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.path < $1.path }
    }

    private func compileReportPath(for specOutputPath: URL) -> URL {
        let filename = specOutputPath.lastPathComponent
        let directory = specOutputPath.deletingLastPathComponent()

        if filename.hasSuffix(".screen.json") {
            let stem = String(filename.dropLast(".screen.json".count))
            return directory.appendingPathComponent("\(stem).compile-report.json")
        }

        if filename.hasSuffix(".json") {
            let stem = String(filename.dropLast(".json".count))
            return directory.appendingPathComponent("\(stem).compile-report.json")
        }

        return directory.appendingPathComponent("\(filename).compile-report.json")
    }

    private func validate(compiledScreenDoc: CompiledScreenDoc, tokensDirectory: URL, catalogPath: URL) throws -> ValidationReport {
        let specValidation = try validate(
            spec: compiledScreenDoc.spec,
            tokensDirectory: tokensDirectory,
            catalogPath: catalogPath
        )

        guard !compiledScreenDoc.unresolvedItems.isEmpty else {
            return specValidation
        }

        let authoringIssues = compiledScreenDoc.unresolvedItems.map { issue in
            ValidationIssue(
                code: issue.code,
                path: "screenDoc.\(issue.path)",
                message: issue.message
            )
        }

        return ValidationReport(issues: specValidation.issues + authoringIssues)
    }

    private func waitForPreviewServer(url: URL, process: Process) throws {
        var lastError: Error?

        for _ in 0..<20 {
            if !process.isRunning {
                throw ProjectError.generationFailed("Preview server failed to start at \(url.absoluteString). The port may already be in use.")
            }

            do {
                _ = try String(contentsOf: url)
                for _ in 0..<3 {
                    Thread.sleep(forTimeInterval: 0.1)
                    guard process.isRunning else {
                        throw ProjectError.generationFailed("Preview server failed to stay running at \(url.absoluteString). The port may already be in use.")
                    }
                }
                return
            } catch {
                lastError = error
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        throw ProjectError.generationFailed(
            "Preview server did not become reachable at \(url.absoluteString). The port may already be in use. \(lastError?.localizedDescription ?? "")"
                .trimmingCharacters(in: .whitespaces)
        )
    }

    private func localPreviewPortIsAvailable(_ port: Int) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            "-c",
            """
            import socket

            sock = socket.socket()
            try:
                sock.bind(("0.0.0.0", \(port)))
            finally:
                sock.close()
            """
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func runtimeContracts(projectRoot: URL) -> RuntimeContracts? {
        let url = projectRoot.appendingPathComponent("meta/runtime/contracts.cue")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try? RuntimeContractLoader().load(from: url)
    }

    private func governanceContracts(projectRoot: URL) -> GovernanceContracts? {
        let url = projectRoot.appendingPathComponent("meta/governance/contracts.cue")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try? GovernanceContractLoader().load(from: url)
    }

    private func resolveProjectPath(_ path: String, relativeTo projectRoot: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return projectRoot.appendingPathComponent(path)
    }

    private func validateAuthoritativeContractReferences(projectRoot: URL) -> (ok: Bool, errors: [String]) {
        let runtimeURL = projectRoot.appendingPathComponent("meta/runtime/contracts.cue")
        let governanceURL = projectRoot.appendingPathComponent("meta/governance/contracts.cue")

        guard FileManager.default.fileExists(atPath: runtimeURL.path) else {
            return (false, ["authoritative contract check failed: missing runtime root \(runtimeURL.path)"])
        }
        guard FileManager.default.fileExists(atPath: governanceURL.path) else {
            return (false, ["authoritative contract check failed: missing governance root \(governanceURL.path)"])
        }

        do {
            let runtime = try RuntimeContractLoader().load(from: runtimeURL)
            let governance = try GovernanceContractLoader().load(from: governanceURL)
            let missingEvidenceKeys = Set(governance.evidenceRefs).subtracting(runtime.evidenceKeys).sorted()
            let inventoryArtifacts =
                governance.runtimeArtifacts +
                governance.planningArtifacts +
                governance.integrationArtifacts +
                governance.acceptanceArtifacts
            let missingArtifactEvidenceRefs = Set(inventoryArtifacts.map(\.evidenceRef)).subtracting(governance.evidenceRefs).sorted()

            let manifestURL = resolveProjectPath(runtime.paths.docSyncManifest, relativeTo: projectRoot)
            let manifestPaths: Set<String>
            if FileManager.default.fileExists(atPath: manifestURL.path) {
                let manifest = try DocSyncService().loadManifest(at: manifestURL)
                manifestPaths = Set(manifest.documents.map(\.path))
            } else {
                return (false, ["authoritative contract check failed: missing doc-sync manifest \(manifestURL.path)"])
            }

            let generatedDocInventory = Set(governance.generatedDocs)
            let missingFromManifest = generatedDocInventory.subtracting(manifestPaths).sorted()
            let missingFromGovernanceInventory = manifestPaths.subtracting(generatedDocInventory).sorted()

            let missingInventoryPaths = (
                governance.generatedDocs +
                governance.authoritativeRoots +
                inventoryArtifacts.map(\.path)
            )
                .filter { !FileManager.default.fileExists(atPath: resolveProjectPath($0, relativeTo: projectRoot).path) }
                .sorted()

            var errors: [String] = []

            if !missingEvidenceKeys.isEmpty {
                errors.append(
                    "authoritative contract check failed: governance evidence refs are not declared in runtime root: \(missingEvidenceKeys.joined(separator: ", "))"
                )
            }

            if !missingArtifactEvidenceRefs.isEmpty {
                errors.append(
                    "authoritative contract check failed: governance inventory references undeclared evidence refs: \(missingArtifactEvidenceRefs.joined(separator: ", "))"
                )
            }

            if !missingFromManifest.isEmpty || !missingFromGovernanceInventory.isEmpty {
                var details: [String] = []
                if !missingFromManifest.isEmpty {
                    details.append("missing from manifest: \(missingFromManifest.joined(separator: ", "))")
                }
                if !missingFromGovernanceInventory.isEmpty {
                    details.append("missing from governance inventory: \(missingFromGovernanceInventory.joined(separator: ", "))")
                }
                errors.append(
                    "authoritative contract check failed: governance generatedDocs inventory does not match doc-sync manifest (\(details.joined(separator: "; ")))"
                )
            }

            if !missingInventoryPaths.isEmpty {
                errors.append(
                    "authoritative contract check failed: governance inventory paths do not exist: \(missingInventoryPaths.joined(separator: ", "))"
                )
            }

            return (errors.isEmpty, errors)
        } catch {
            return (false, ["authoritative contract check failed: \(error.localizedDescription)"])
        }
    }

    private func validateGovernanceEvidenceArtifacts(projectRoot: URL) -> [String] {
        guard let governance = governanceContracts(projectRoot: projectRoot) else {
            return []
        }

        let runtimeCapabilities = Set(runtimeContracts(projectRoot: projectRoot)?.doctorCapabilities ?? [])
        let runtimeInventory = Dictionary(uniqueKeysWithValues: governance.runtimeArtifacts.map { ($0.path, $0) })
        let integrationInventory = Dictionary(uniqueKeysWithValues: governance.integrationArtifacts.map { ($0.path, $0) })
        var integrationReports: [String: IntegrationSmokeEvidence] = [:]
        var acceptanceReports: [String: AcceptanceEvidenceReport] = [:]
        var doctorReports: [String: DoctorEvidenceReport] = [:]
        var errors: [String] = []

        for artifact in governance.runtimeArtifacts {
            let artifactURL = resolveProjectPath(artifact.path, relativeTo: projectRoot)
            guard FileManager.default.fileExists(atPath: artifactURL.path) else {
                continue
            }

            do {
                let report = try decode(DoctorEvidenceReport.self, from: artifactURL)
                doctorReports[artifact.path] = report
                errors.append(contentsOf: validateDoctorEvidenceReport(
                    report,
                    inventory: artifact,
                    runtimeCapabilities: runtimeCapabilities,
                    projectRoot: projectRoot
                ))
            } catch {
                errors.append("\(artifact.path): \(error.localizedDescription)")
            }
        }

        for artifact in governance.planningArtifacts {
            let artifactURL = resolveProjectPath(artifact.path, relativeTo: projectRoot)
            guard FileManager.default.fileExists(atPath: artifactURL.path) else {
                continue
            }

            do {
                let report = try decode(PlanningRereadEvidenceReport.self, from: artifactURL)
                errors.append(contentsOf: validatePlanningRereadEvidenceReport(
                    report,
                    inventory: artifact,
                    projectRoot: projectRoot
                ))
            } catch {
                errors.append("\(artifact.path): \(error.localizedDescription)")
            }
        }

        for artifact in governance.integrationArtifacts {
            let artifactURL = resolveProjectPath(artifact.path, relativeTo: projectRoot)
            guard FileManager.default.fileExists(atPath: artifactURL.path) else {
                continue
            }

            do {
                let report = try decode(IntegrationSmokeEvidence.self, from: artifactURL)
                integrationReports[artifact.path] = report
                errors.append(contentsOf: validateIntegrationEvidenceReport(
                    report,
                    inventory: artifact,
                    runtimeInventory: runtimeInventory,
                    runtimeCapabilities: runtimeCapabilities,
                    doctorReports: doctorReports,
                    projectRoot: projectRoot
                ))
            } catch {
                errors.append("\(artifact.path): \(error.localizedDescription)")
            }
        }

        for artifact in governance.acceptanceArtifacts {
            let artifactURL = resolveProjectPath(artifact.path, relativeTo: projectRoot)
            guard FileManager.default.fileExists(atPath: artifactURL.path) else {
                continue
            }

            do {
                let report = try decode(AcceptanceEvidenceReport.self, from: artifactURL)
                acceptanceReports[artifact.path] = report
                errors.append(contentsOf: validateAcceptanceEvidenceReport(
                    report,
                    inventory: artifact,
                    integrationInventory: integrationInventory,
                    integrationReports: integrationReports,
                    projectRoot: projectRoot
                ))
            } catch {
                errors.append("\(artifact.path): \(error.localizedDescription)")
            }
        }

        errors.append(contentsOf: validatePlanningLedgerEvidenceAlignment(
            projectRoot: projectRoot,
            integrationReports: integrationReports,
            acceptanceReports: acceptanceReports
        ))

        return errors.sorted()
    }

    private struct GovernanceFragmentFile: Decodable {
        let fragments: [GovernanceFragment]
    }

    private struct GovernanceFragment: Decodable {
        let path: String
        let rows: [[String]]
    }

    private func validateDoctorEvidenceReport(
        _ report: DoctorEvidenceReport,
        inventory: GovernanceArtifact,
        runtimeCapabilities: Set<String>,
        projectRoot: URL
    ) -> [String] {
        var errors: [String] = []

        if report.artifactId != inventory.id {
            errors.append("\(inventory.path): artifactId must match governance inventory id '\(inventory.id)'")
        }
        if report.artifactType != inventory.evidenceRef {
            errors.append("\(inventory.path): artifactType must match governance inventory evidenceRef '\(inventory.evidenceRef)'")
        }
        if !isValidCalendarDate(report.verifiedOn) {
            errors.append("\(inventory.path): verifiedOn must use YYYY-MM-DD")
        }

        errors.append(contentsOf: validateVerificationEvidence(
            report.verification,
            inventoryPath: inventory.path,
            projectRoot: projectRoot,
            requiredCommands: ["swift run dsctl doctor --json"]
        ))

        if !report.report.ok {
            errors.append("\(inventory.path): report.ok must be true")
        }
        if !report.report.capabilities.cli || !report.report.capabilities.mcp {
            errors.append("\(inventory.path): report.capabilities must declare cli and mcp support")
        }
        if !report.report.capabilities.iosRenderer || !report.report.capabilities.androidRenderer {
            errors.append("\(inventory.path): renderer capabilities must remain true in the doctor snapshot")
        }
        if report.report.capabilities.htmlPreview != report.report.toolchains.python3 {
            errors.append("\(inventory.path): html_preview must match toolchains.python3")
        }
        if report.report.capabilities.iosHostSmoke != report.report.toolchains.swiftc {
            errors.append("\(inventory.path): ios_host_smoke must match toolchains.swiftc")
        }
        if report.report.capabilities.androidHostSmoke != (report.report.toolchains.javaRuntime && (report.report.toolchains.kotlinc || report.report.toolchains.gradle)) {
            errors.append("\(inventory.path): android_host_smoke must match java_runtime && (kotlinc || gradle)")
        }

        let requiredCapabilities: Set<String> = [
            "cli",
            "mcp",
            "ios_renderer",
            "android_renderer",
            "html_preview",
            "ios_host_smoke",
            "android_host_smoke",
        ]
        if !requiredCapabilities.isSubset(of: runtimeCapabilities) {
            errors.append("\(inventory.path): runtime root doctorCapabilities is missing required doctor fields")
        }

        let currentDoctorReport = doctor()
        if report.report != currentDoctorReport {
            errors.append("\(inventory.path): doctor snapshot does not match current local doctor output")
        }

        return errors
    }

    private func validatePlanningRereadEvidenceReport(
        _ report: PlanningRereadEvidenceReport,
        inventory: GovernanceArtifact,
        projectRoot: URL
    ) -> [String] {
        var errors: [String] = []

        if report.artifactId != inventory.id {
            errors.append("\(inventory.path): artifactId must match governance inventory id '\(inventory.id)'")
        }
        if report.artifactType != inventory.evidenceRef {
            errors.append("\(inventory.path): artifactType must match governance inventory evidenceRef '\(inventory.evidenceRef)'")
        }
        if !isValidCalendarDate(report.verifiedOn) {
            errors.append("\(inventory.path): verifiedOn must use YYYY-MM-DD")
        }

        let documents = report.documents.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if documents.isEmpty {
            errors.append("\(inventory.path): documents must not be empty")
        }
        if documents.contains(where: \.isEmpty) {
            errors.append("\(inventory.path): documents must not contain empty values")
        }
        if Set(documents).count != documents.count {
            errors.append("\(inventory.path): documents must be unique")
        }
        for document in documents where !document.isEmpty {
            let resolvedDocument = resolveProjectPath(document, relativeTo: projectRoot)
            if !FileManager.default.fileExists(atPath: resolvedDocument.path) {
                errors.append("\(inventory.path): missing reread checklist document \(document)")
            }
        }

        let missingDocuments = requiredPlanningRereadDocuments.subtracting(documents).sorted()
        if !missingDocuments.isEmpty {
            errors.append(
                "\(inventory.path): documents must include canonical planning reread set: \(missingDocuments.joined(separator: ", "))"
            )
        }

        let notes = report.notes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if notes.isEmpty {
            errors.append("\(inventory.path): notes must not be empty")
        }
        if notes.contains(where: \.isEmpty) {
            errors.append("\(inventory.path): notes must not contain empty values")
        }

        return errors
    }

    private func validateIntegrationEvidenceReport(
        _ report: IntegrationSmokeEvidence,
        inventory: GovernanceArtifact,
        runtimeInventory: [String: GovernanceArtifact],
        runtimeCapabilities: Set<String>,
        doctorReports: [String: DoctorEvidenceReport],
        projectRoot: URL
    ) -> [String] {
        var errors: [String] = []

        if report.artifactId != inventory.id {
            errors.append("\(inventory.path): artifactId must match governance inventory id '\(inventory.id)'")
        }
        if report.artifactType != inventory.evidenceRef {
            errors.append("\(inventory.path): artifactType must match governance inventory evidenceRef '\(inventory.evidenceRef)'")
        }
        if !isValidCalendarDate(report.verifiedOn) {
            errors.append("\(inventory.path): verifiedOn must use YYYY-MM-DD")
        }
        if !["ios", "android"].contains(report.platform) {
            errors.append("\(inventory.path): platform must be ios or android")
        }
        if report.requiredCapability.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("\(inventory.path): requiredCapability must not be empty")
        } else if !runtimeCapabilities.contains(report.requiredCapability) {
            errors.append("\(inventory.path): requiredCapability is not declared in runtime doctorCapabilities: \(report.requiredCapability)")
        }
        if report.doctorEvidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("\(inventory.path): doctorEvidence must not be empty")
        } else {
            let resolvedDoctorEvidence = resolveProjectPath(report.doctorEvidence, relativeTo: projectRoot)
            if !FileManager.default.fileExists(atPath: resolvedDoctorEvidence.path) {
                errors.append("\(inventory.path): missing doctor evidence artifact \(report.doctorEvidence)")
            }
            if runtimeInventory[report.doctorEvidence] == nil {
                errors.append("\(inventory.path): doctor evidence is not declared in governance runtimeArtifacts: \(report.doctorEvidence)")
            }
        }
        if report.wrapperSources.isEmpty {
            errors.append("\(inventory.path): wrapperSources must not be empty")
        }

        for wrapperPath in report.wrapperSources {
            let wrapperURL = resolveProjectPath(wrapperPath, relativeTo: projectRoot)
            if !FileManager.default.fileExists(atPath: wrapperURL.path) {
                errors.append("\(inventory.path): missing wrapper source \(wrapperPath)")
            }
        }

        errors.append(contentsOf: validateVerificationEvidence(
            report.verification,
            inventoryPath: inventory.path,
            projectRoot: projectRoot,
            requiredCommands: ["swift test"]
        ))

        if report.platform == "ios", report.requiredCapability != "ios_host_smoke" {
            errors.append("\(inventory.path): ios integration smoke must require ios_host_smoke")
        }
        if report.platform == "android", report.requiredCapability != "android_host_smoke" {
            errors.append("\(inventory.path): android integration smoke must require android_host_smoke")
        }

        if let doctorReport = doctorReports[report.doctorEvidence],
           let capabilityValue = doctorCapabilityValue(in: doctorReport.report, named: report.requiredCapability),
           report.status == .pass,
           !capabilityValue {
            errors.append("\(inventory.path): pass evidence requires \(report.requiredCapability)=true in \(report.doctorEvidence)")
        }
        if let doctorReport = doctorReports[report.doctorEvidence], report.verifiedOn != doctorReport.verifiedOn {
            errors.append("\(inventory.path): verifiedOn must match referenced doctorEvidence \(report.doctorEvidence)")
        }

        let knownGap = report.knownGap?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch report.status {
        case .pass:
            if let knownGap, !knownGap.isEmpty {
                errors.append("\(inventory.path): pass evidence must not declare knownGap")
            }
        case .partial, .blocked:
            if knownGap?.isEmpty != false {
                errors.append("\(inventory.path): \(report.status.rawValue) evidence must declare knownGap")
            }
        }

        return errors
    }

    private func validateVerificationEvidence(
        _ verification: GovernanceVerificationEvidence,
        inventoryPath: String,
        projectRoot: URL,
        requiredCommands: Set<String> = []
    ) -> [String] {
        var errors: [String] = []
        let trimmedCommand = verification.command.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTestCase = verification.testCase.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTestSource = verification.testSource.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedCommand.isEmpty {
            errors.append("\(inventoryPath): verification.command must not be empty")
        } else if !requiredCommands.isEmpty, !requiredCommands.contains(trimmedCommand) {
            errors.append(
                "\(inventoryPath): verification.command must be one of: \(requiredCommands.sorted().joined(separator: ", "))"
            )
        }
        if trimmedTestCase.isEmpty {
            errors.append("\(inventoryPath): verification.testCase must not be empty")
        }
        if trimmedTestSource.isEmpty {
            errors.append("\(inventoryPath): verification.testSource must not be empty")
        } else if let sourceLocation = sourceLocation(from: trimmedTestSource) {
            let resolved = resolveProjectPath(sourceLocation.path, relativeTo: projectRoot)
            if !FileManager.default.fileExists(atPath: resolved.path) {
                errors.append("\(inventoryPath): verification.testSource file does not exist: \(sourceLocation.path)")
            } else if !trimmedTestCase.isEmpty {
                do {
                    let testSource = try String(contentsOf: resolved)
                    let expectedAnnotation = #"@Test("\#(trimmedTestCase)")"#

                    guard let declaredLine = lineNumber(containing: expectedAnnotation, in: testSource) else {
                        errors.append(
                            "\(inventoryPath): verification.testCase must match an @Test declaration in \(sourceLocation.path)"
                        )
                        return errors
                    }

                    if let referencedLine = sourceLocation.line, referencedLine != declaredLine {
                        errors.append(
                            "\(inventoryPath): verification.testSource line must point to \(expectedAnnotation) in \(sourceLocation.path)"
                        )
                    }
                } catch {
                    errors.append("\(inventoryPath): verification.testSource could not be read: \(sourceLocation.path)")
                }
            }
        } else {
            errors.append("\(inventoryPath): verification.testSource must use path or path:line")
        }

        return errors
    }

    private func validateAcceptanceEvidenceReport(
        _ report: AcceptanceEvidenceReport,
        inventory: GovernanceArtifact,
        integrationInventory: [String: GovernanceArtifact],
        integrationReports: [String: IntegrationSmokeEvidence],
        projectRoot: URL
    ) -> [String] {
        var errors: [String] = []

        if report.artifactId != inventory.id {
            errors.append("\(inventory.path): artifactId must match governance inventory id '\(inventory.id)'")
        }
        if report.artifactType != inventory.evidenceRef {
            errors.append("\(inventory.path): artifactType must match governance inventory evidenceRef '\(inventory.evidenceRef)'")
        }
        if !isValidCalendarDate(report.verifiedOn) {
            errors.append("\(inventory.path): verifiedOn must use YYYY-MM-DD")
        }

        let screenDocURL = resolveProjectPath(report.authoringInputs.screenDoc, relativeTo: projectRoot)
        if !FileManager.default.fileExists(atPath: screenDocURL.path) {
            errors.append("\(inventory.path): missing authoring screen-doc \(report.authoringInputs.screenDoc)")
        }

        let screenSpecURL = resolveProjectPath(report.authoringInputs.screenSpec, relativeTo: projectRoot)
        if !FileManager.default.fileExists(atPath: screenSpecURL.path) {
            errors.append("\(inventory.path): missing authoring screen-spec \(report.authoringInputs.screenSpec)")
        }

        var authoringSpec: ScreenSpec?
        if FileManager.default.fileExists(atPath: screenSpecURL.path) {
            do {
                authoringSpec = try decode(ScreenSpec.self, from: screenSpecURL)
            } catch {
                errors.append("\(inventory.path): could not decode authoring screen-spec \(report.authoringInputs.screenSpec)")
            }
        }

        let reviewSurfaceURL = resolveProjectPath(report.reviewSurface, relativeTo: projectRoot)
        if !FileManager.default.fileExists(atPath: reviewSurfaceURL.path) {
            errors.append("\(inventory.path): missing review surface \(report.reviewSurface)")
        }

        let generatedManifestURL = resolveProjectPath(report.generatedManifest, relativeTo: projectRoot)
        if !FileManager.default.fileExists(atPath: generatedManifestURL.path) {
            errors.append("\(inventory.path): missing generated manifest \(report.generatedManifest)")
        }

        let reviewedPreviewStates = report.review.reviewedPreviewStates.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if reviewedPreviewStates.isEmpty {
            errors.append("\(inventory.path): review.reviewedPreviewStates must not be empty")
        }
        if reviewedPreviewStates.contains(where: \.isEmpty) {
            errors.append("\(inventory.path): review.reviewedPreviewStates must not contain empty values")
        }
        if Set(reviewedPreviewStates).count != reviewedPreviewStates.count {
            errors.append("\(inventory.path): review.reviewedPreviewStates must be unique")
        }

        if report.review.checklist.isEmpty {
            errors.append("\(inventory.path): review.checklist must not be empty")
        }

        let reviewCheckIDs = report.review.checklist.map { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) }
        if reviewCheckIDs.contains(where: \.isEmpty) {
            errors.append("\(inventory.path): review.checklist ids must not be empty")
        }
        if Set(reviewCheckIDs).count != reviewCheckIDs.count {
            errors.append("\(inventory.path): review.checklist ids must be unique")
        }
        if report.review.checklist.contains(where: { $0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            errors.append("\(inventory.path): review.checklist notes must not be empty")
        }

        let missingReviewCheckIDs = requiredAcceptanceReviewCheckIDs.subtracting(reviewCheckIDs)
        if !missingReviewCheckIDs.isEmpty {
            errors.append(
                "\(inventory.path): review.checklist must include required ids: \(missingReviewCheckIDs.sorted().joined(separator: ", "))"
            )
        }

        if let authoringSpec {
            if report.screenId != authoringSpec.screenId {
                errors.append("\(inventory.path): screenId must match authoring screen-spec screenId '\(authoringSpec.screenId)'")
            }

            let declaredPreviewStates = authoringSpec.previewStates
                .map { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) }
                .sorted()
            if declaredPreviewStates != reviewedPreviewStates.sorted() {
                errors.append("\(inventory.path): review.reviewedPreviewStates must match declared previewStates in \(report.authoringInputs.screenSpec)")
            }
        }

        if FileManager.default.fileExists(atPath: reviewSurfaceURL.path) {
            do {
                let reviewSurface = try String(contentsOf: reviewSurfaceURL)
                for stateID in reviewedPreviewStates {
                    guard !stateID.isEmpty else { continue }
                    if !reviewSurface.contains("data-preview-state=\"\(stateID)\"") {
                        errors.append("\(inventory.path): review surface is missing data-preview-state=\"\(stateID)\"")
                    }
                }
            } catch {
                errors.append("\(inventory.path): could not read review surface \(report.reviewSurface)")
            }
        }

        if report.verification.isEmpty || report.verification.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            errors.append("\(inventory.path): verification must contain non-empty command entries")
        }
        let normalizedVerificationCommands = Set(
            report.verification.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        let missingVerificationCommands = requiredAcceptanceVerificationCommands(screenID: report.screenId)
            .subtracting(normalizedVerificationCommands)
            .sorted()
        if !missingVerificationCommands.isEmpty {
            errors.append(
                "\(inventory.path): verification must include required commands: \(missingVerificationCommands.joined(separator: ", "))"
            )
        }

        if FileManager.default.fileExists(atPath: generatedManifestURL.path) {
            do {
                let manifest = try decode(Manifest.self, from: generatedManifestURL)
                if !path(manifest.inputSpecPath, matchesProjectRelativePath: report.authoringInputs.screenSpec) {
                    errors.append("\(inventory.path): generatedManifest inputSpecPath must match authoring screen-spec \(report.authoringInputs.screenSpec)")
                }
                if !manifest.generatedFiles.contains(where: { path($0, matchesProjectRelativePath: report.reviewSurface) }) {
                    errors.append("\(inventory.path): generatedManifest must include reviewSurface \(report.reviewSurface)")
                }
                if !manifest.generatedFiles.contains(where: { $0.hasSuffix("/report.validation.json") }) {
                    errors.append("\(inventory.path): generatedManifest must include report.validation.json")
                }

                if let authoringSpec {
                    let missingGeneratedPlatforms = Set(authoringSpec.platforms.compactMap { platform in
                        switch platform {
                        case .ios, .android, .html:
                            return manifest.generatedFiles.contains(where: { $0.contains("/\(platform.rawValue)/") }) ? nil : platform.rawValue
                        }
                    }).sorted()
                    if !missingGeneratedPlatforms.isEmpty {
                        errors.append(
                            "\(inventory.path): generatedManifest must cover declared platforms in \(report.authoringInputs.screenSpec): \(missingGeneratedPlatforms.joined(separator: ", "))"
                        )
                    }
                }
            } catch {
                errors.append("\(inventory.path): could not decode generated manifest \(report.generatedManifest)")
            }
        }

        if report.hostEvidence.isEmpty {
            errors.append("\(inventory.path): hostEvidence must not be empty")
        }

        let hostEvidencePaths = report.hostEvidence.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if hostEvidencePaths.contains(where: \.isEmpty) {
            errors.append("\(inventory.path): hostEvidence must not contain empty values")
        }
        if Set(hostEvidencePaths).count != hostEvidencePaths.count {
            errors.append("\(inventory.path): hostEvidence must be unique")
        }

        for hostEvidencePath in report.hostEvidence {
            let resolved = resolveProjectPath(hostEvidencePath, relativeTo: projectRoot)
            if !FileManager.default.fileExists(atPath: resolved.path) {
                errors.append("\(inventory.path): missing host evidence artifact \(hostEvidencePath)")
            }
            if integrationInventory[hostEvidencePath] == nil {
                errors.append("\(inventory.path): host evidence is not declared in governance integrationArtifacts: \(hostEvidencePath)")
            }
        }

        let blockingHostEvidence = report.blockingHostEvidence.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if blockingHostEvidence.contains(where: \.isEmpty) {
            errors.append("\(inventory.path): blockingHostEvidence must not contain empty values")
        }
        if Set(blockingHostEvidence).count != blockingHostEvidence.count {
            errors.append("\(inventory.path): blockingHostEvidence must be unique")
        }
        let blockingOutsideHostEvidence = Set(blockingHostEvidence).subtracting(hostEvidencePaths).sorted()
        if !blockingOutsideHostEvidence.isEmpty {
            errors.append(
                "\(inventory.path): blockingHostEvidence must be a subset of hostEvidence: \(blockingOutsideHostEvidence.joined(separator: ", "))"
            )
        }

        let nonPassHostEvidence = hostEvidencePaths.filter {
            guard let integrationReport = integrationReports[$0] else { return false }
            return integrationReport.status != .pass
        }
        let blockingHostEvidenceSet = Set(blockingHostEvidence)
        let referencedHostPlatforms = Set(hostEvidencePaths.compactMap { integrationReports[$0]?.platform })

        let hostEvidenceDateDrift = hostEvidencePaths.filter {
            guard let integrationReport = integrationReports[$0] else { return false }
            return integrationReport.verifiedOn != report.verifiedOn
        }.sorted()
        if !hostEvidenceDateDrift.isEmpty {
            errors.append(
                "\(inventory.path): verifiedOn must match referenced hostEvidence dates: \(hostEvidenceDateDrift.joined(separator: ", "))"
            )
        }

        for hostEvidencePath in blockingHostEvidence {
            if let integrationReport = integrationReports[hostEvidencePath], integrationReport.status == .pass {
                errors.append(
                    "\(inventory.path): blockingHostEvidence must reference only non-pass host evidence: \(hostEvidencePath)"
                )
            }
        }

        if let authoringSpec {
            let requiredNativeHostPlatforms = Set(authoringSpec.platforms.compactMap { platform in
                switch platform {
                case .ios, .android:
                    return platform.rawValue
                case .html:
                    return nil
                }
            })
            let missingNativeHostPlatforms = requiredNativeHostPlatforms.subtracting(referencedHostPlatforms).sorted()
            if !missingNativeHostPlatforms.isEmpty {
                errors.append(
                    "\(inventory.path): hostEvidence must cover declared native platforms in \(report.authoringInputs.screenSpec): \(missingNativeHostPlatforms.joined(separator: ", "))"
                )
            }
        }

        let residualGaps = report.residualGaps.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        switch report.status {
        case .pass:
            if !residualGaps.isEmpty {
                errors.append("\(inventory.path): pass acceptance evidence must not declare residualGaps")
            }
            if !blockingHostEvidence.isEmpty {
                errors.append("\(inventory.path): pass acceptance evidence must not declare blockingHostEvidence")
            }
            let nonPassHostEvidenceList = nonPassHostEvidence.sorted()
            if !nonPassHostEvidenceList.isEmpty {
                errors.append(
                    "\(inventory.path): pass acceptance evidence requires all hostEvidence to have status=pass: \(nonPassHostEvidenceList.joined(separator: ", "))"
                )
            }
        case .partial, .blocked:
            if residualGaps.isEmpty {
                errors.append("\(inventory.path): \(report.status.rawValue) acceptance evidence must declare residualGaps")
            }
            let missingBlockingHostEvidence = Set(nonPassHostEvidence).subtracting(blockingHostEvidenceSet).sorted()
            if !missingBlockingHostEvidence.isEmpty {
                errors.append(
                    "\(inventory.path): \(report.status.rawValue) acceptance evidence must declare blockingHostEvidence for non-pass host evidence: \(missingBlockingHostEvidence.joined(separator: ", "))"
                )
            }
        }

        return errors
    }

    private func validatePlanningLedgerEvidenceAlignment(
        projectRoot: URL,
        integrationReports: [String: IntegrationSmokeEvidence],
        acceptanceReports: [String: AcceptanceEvidenceReport]
    ) -> [String] {
        let fragmentsURL: URL
        if let runtime = runtimeContracts(projectRoot: projectRoot) {
            fragmentsURL = resolveProjectPath(runtime.paths.governanceFragmentSpec, relativeTo: projectRoot)
        } else {
            fragmentsURL = projectRoot.appendingPathComponent("meta/views/governance.fragments.json")
        }

        guard FileManager.default.fileExists(atPath: fragmentsURL.path) else {
            return ["planning ledger check failed: missing governance fragment spec \(fragmentsURL.path)"]
        }

        let fragmentFile: GovernanceFragmentFile
        do {
            fragmentFile = try decode(GovernanceFragmentFile.self, from: fragmentsURL)
        } catch {
            return ["planning ledger check failed: could not decode \(fragmentsURL.path)"]
        }

        let taskStatusByID = fragmentStatusMap(
            from: fragmentFile,
            path: "meta/views/fragments/12-task-matrix-task-rows.md"
        )
        let phaseStatusByID = fragmentStatusMap(
            from: fragmentFile,
            path: "meta/views/fragments/11-execution-plan-critical-path.md"
        )

        let expectedTaskStatuses: [String: String] = [
            "INTEGRATE-01": expectedStatus(for: integrationReports["audit/evidence/integration/ios-host-smoke.json"]?.status),
            "INTEGRATE-02": expectedStatus(for: integrationReports["audit/evidence/integration/android-host-smoke.json"]?.status),
            "E2E-01": expectedStatus(for: acceptanceReports["audit/evidence/acceptance/login.json"]?.status),
            "E2E-02": expectedStatus(for: acceptanceReports["audit/evidence/acceptance/product-detail.json"]?.status),
            "VERIFY-01": expectedVerificationLedgerStatus(
                integrationReports: integrationReports,
                acceptanceReports: acceptanceReports
            ),
        ]

        let expectedPhaseStatuses: [String: String] = [
            "P5": expectedIntegrationPhaseStatus(integrationReports: integrationReports),
            "P7": expectedAcceptancePhaseStatus(
                integrationReports: integrationReports,
                acceptanceReports: acceptanceReports
            ),
        ]

        var errors: [String] = []

        for (taskID, expectedStatus) in expectedTaskStatuses.sorted(by: { $0.key < $1.key }) {
            guard let actualStatus = taskStatusByID[taskID] else {
                errors.append("planning ledger check failed: missing task row \(taskID) in meta/views/governance.fragments.json")
                continue
            }

            if actualStatus != expectedStatus {
                errors.append(
                    "planning ledger check failed: task \(taskID) status must be \(expectedStatus) to match source-owned evidence"
                )
            }
        }

        for (phaseID, expectedStatus) in expectedPhaseStatuses.sorted(by: { $0.key < $1.key }) {
            guard let actualStatus = phaseStatusByID[phaseID] else {
                errors.append("planning ledger check failed: missing phase row \(phaseID) in meta/views/governance.fragments.json")
                continue
            }

            if actualStatus != expectedStatus {
                errors.append(
                    "planning ledger check failed: phase \(phaseID) status must be \(expectedStatus) to match source-owned evidence"
                )
            }
        }

        return errors
    }

    private func fragmentStatusMap(
        from fragmentFile: GovernanceFragmentFile,
        path: String
    ) -> [String: String] {
        guard let fragment = fragmentFile.fragments.first(where: { $0.path == path }) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: fragment.rows.compactMap { row in
            guard row.count >= 2 else {
                return nil
            }
            return (row[0], row[1])
        })
    }

    private func expectedStatus(for evidenceStatus: GovernanceEvidenceStatus?) -> String {
        switch evidenceStatus {
        case .pass:
            return "Done"
        case .partial, .blocked:
            return "In Progress"
        case nil:
            return "Planned"
        }
    }

    private func expectedVerificationLedgerStatus(
        integrationReports: [String: IntegrationSmokeEvidence],
        acceptanceReports: [String: AcceptanceEvidenceReport]
    ) -> String {
        let integrationStatuses = [
            integrationReports["audit/evidence/integration/ios-host-smoke.json"]?.status,
            integrationReports["audit/evidence/integration/android-host-smoke.json"]?.status,
        ]
        let acceptanceStatuses = [
            acceptanceReports["audit/evidence/acceptance/login.json"]?.status,
            acceptanceReports["audit/evidence/acceptance/product-detail.json"]?.status,
        ]

        let allStatuses = integrationStatuses + acceptanceStatuses
        guard allStatuses.allSatisfy({ $0 != nil }) else {
            return "Planned"
        }
        if allStatuses.allSatisfy({ $0 == .pass }) {
            return "Done"
        }
        return "In Progress"
    }

    private func expectedIntegrationPhaseStatus(
        integrationReports: [String: IntegrationSmokeEvidence]
    ) -> String {
        let integrationStatuses = [
            integrationReports["audit/evidence/integration/ios-host-smoke.json"]?.status,
            integrationReports["audit/evidence/integration/android-host-smoke.json"]?.status,
        ]

        guard integrationStatuses.allSatisfy({ $0 != nil }) else {
            return integrationStatuses.contains(where: { $0 != nil }) ? "In Progress" : "Planned"
        }

        if integrationStatuses.allSatisfy({ $0 == .pass }) {
            return "Done"
        }

        return "In Progress"
    }

    private func expectedAcceptancePhaseStatus(
        integrationReports: [String: IntegrationSmokeEvidence],
        acceptanceReports: [String: AcceptanceEvidenceReport]
    ) -> String {
        let verificationStatus = expectedVerificationLedgerStatus(
            integrationReports: integrationReports,
            acceptanceReports: acceptanceReports
        )
        if verificationStatus == "Done" {
            return "Done"
        }
        return acceptanceReports.isEmpty ? "Planned" : "In Progress"
    }

    private func isValidCalendarDate(_ value: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}$"#) else {
            return false
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard regex.firstMatch(in: value, options: [], range: range) != nil else {
            return false
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = false
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value) != nil
    }

    private func requiredAcceptanceVerificationCommands(screenID: String) -> Set<String> {
        [
            "swift test",
            "swift run ds-doc-sync sync --project-root . --json",
            "swift run dsctl audit --project-root . --json",
            "swift run dsctl generate --config examples/configs/dsctl.config.json --screen-id \(screenID) --json",
        ]
    }

    private var requiredPlanningRereadDocuments: Set<String> {
        [
            "MASTER_BLUEPRINT.md",
            "docs/11-execution-plan.md",
            "docs/12-task-matrix.md",
            "docs/18-a-to-z-onboarding.md",
            "docs/20-traceability-matrix.md",
            "docs/23-authoritative-source-architecture.md",
            "docs/24-authoritative-source-execution-plan.md",
            "docs/25-authoritative-source-task-matrix.md",
        ]
    }

    private struct SourceLocationReference {
        let path: String
        let line: Int?
    }

    private func sourceLocation(from reference: String) -> SourceLocationReference? {
        let trimmedReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReference.isEmpty else {
            return nil
        }

        let components = trimmedReference.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let path = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            return nil
        }

        guard components.count == 2 else {
            return SourceLocationReference(path: path, line: nil)
        }

        let lineText = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let line = Int(lineText), line > 0 else {
            return nil
        }

        return SourceLocationReference(path: path, line: line)
    }

    private func lineNumber(containing needle: String, in text: String) -> Int? {
        for (index, line) in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated() {
            if line.contains(needle) {
                return index + 1
            }
        }
        return nil
    }

    private func path(_ candidate: String, matchesProjectRelativePath relativePath: String) -> Bool {
        let relativeComponents = URL(fileURLWithPath: relativePath).standardized.pathComponents
        let candidateComponents = URL(fileURLWithPath: candidate).standardized.pathComponents
        guard !relativeComponents.isEmpty, candidateComponents.count >= relativeComponents.count else {
            return false
        }
        return Array(candidateComponents.suffix(relativeComponents.count)) == relativeComponents
    }

    private func doctorCapabilityValue(in report: DoctorReport, named capability: String) -> Bool? {
        switch capability {
        case "cli":
            return report.capabilities.cli
        case "mcp":
            return report.capabilities.mcp
        case "ios_renderer":
            return report.capabilities.iosRenderer
        case "android_renderer":
            return report.capabilities.androidRenderer
        case "html_preview":
            return report.capabilities.htmlPreview
        case "ios_host_smoke":
            return report.capabilities.iosHostSmoke
        case "android_host_smoke":
            return report.capabilities.androidHostSmoke
        default:
            return nil
        }
    }

    private func directoryContentsIfPresent(at directory: URL) -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        return (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    }

    private func brokenRelativeLinks(in content: String, file: URL) -> [String] {
        let pattern = #"\[[^\]]+\]\(([^)#]+)(?:#[^)]+)?\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        return regex.matches(in: content, range: range).compactMap { match in
            guard let range = Range(match.range(at: 1), in: content) else {
                return nil
            }
            let target = String(content[range])
            guard !target.contains("://") else {
                return nil
            }
            let resolved = file.deletingLastPathComponent().appendingPathComponent(target).standardizedFileURL
            return FileManager.default.fileExists(atPath: resolved.path) ? nil : "\(file.path) -> \(target)"
        }
    }
}

private extension Optional {
    func unwrap(_ message: @autoclosure () -> String) throws -> Wrapped {
        guard let value = self else {
            throw ProjectError.io(message())
        }
        return value
    }
}

private struct ProcessExecution {
    let stdout: String
    let stderr: String
}

private struct HostSmokeProperty {
    let parameter: String
    let assignment: String
}
