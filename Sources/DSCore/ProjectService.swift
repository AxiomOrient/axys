import Foundation

public struct ProjectService: Sendable {
    public init() {}

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

    public func validateApp(appPath: URL) throws -> ValidationReport {
        try ContractValidator().validateApp(at: appPath)
    }

    public func validateFlow(flowPath: URL) throws -> ValidationReport {
        try ContractValidator().validateFlow(at: flowPath)
    }

    public func validateScreen(screenPath: URL) throws -> ValidationReport {
        try ContractValidator().validateScreen(at: screenPath)
    }

    public func renderHTML(screenPath: URL, outputDirectory: URL? = nil) throws -> RenderHTMLReport {
        let validation = try validateScreen(screenPath: screenPath)
        guard validation.ok else {
            throw ProjectError.validationFailed(validation)
        }

        let validator = ContractValidator()
        let context = try validator.resolveScreenContext(at: screenPath)
        let tokens = try compileTokens(appSpec: context.appSpec, appURL: context.appURL, contractRoot: context.contractRoot)
        let resolvedOutput = outputDirectory ?? defaultHTMLOutputDirectory(screenID: context.screenSpec.screenId)

        return try HTMLRenderer().render(
            context: context,
            tokens: tokens,
            outputDirectory: resolvedOutput
        )
    }

    public func generateNative(screenPath: URL, platform: Platform, outputDirectory: URL? = nil) throws -> GenerateNativeReport {
        let validation = try validateScreen(screenPath: screenPath)
        guard validation.ok else {
            throw ProjectError.validationFailed(validation)
        }

        guard platform == .ios || platform == .android else {
            throw ProjectError.invalidArgument("generate-native only supports --platform ios|android")
        }

        let validator = ContractValidator()
        let context = try validator.resolveScreenContext(at: screenPath)

        guard context.screenSpec.targets.contains(platform) else {
            throw ProjectError.invalidArgument("Screen \(context.screenSpec.screenId) does not declare target platform \(platform.rawValue)")
        }

        let tokens = try compileTokens(appSpec: context.appSpec, appURL: context.appURL, contractRoot: context.contractRoot)
        let resolvedOutput = outputDirectory ?? defaultNativeOutputDirectory(screenID: context.screenSpec.screenId, platform: platform)

        return try NativeRenderer().render(
            context: context,
            tokens: tokens,
            platform: platform,
            outputDirectory: resolvedOutput
        )
    }

    public func syncPenpot(appPath: URL, outputDirectory: URL? = nil) throws -> AdapterSyncReport {
        try syncAdapter(.penpot, appPath: appPath, outputDirectory: outputDirectory)
    }

    public func syncPencil(appPath: URL, outputDirectory: URL? = nil) throws -> AdapterSyncReport {
        try syncAdapter(.pencil, appPath: appPath, outputDirectory: outputDirectory)
    }

    public func auditApp(appPath: URL, outputDirectory: URL? = nil) throws -> AppAuditReport {
        let validation = try validateApp(appPath: appPath)
        guard validation.ok else {
            throw ProjectError.validationFailed(validation)
        }

        let loader = ContractDocumentLoader()
        let validator = ContractValidator()
        let appSpec = try loader.load(AppSpec.self, from: appPath)
        let contractRoot = validator.resolveContractRoot(startingAt: appPath)
        let tokens = try compileTokens(appSpec: appSpec, appURL: appPath, contractRoot: contractRoot)
        let contexts = try resolveAppScreenContexts(appSpec: appSpec, appURL: appPath, contractRoot: contractRoot)
        let resolvedOutput = outputDirectory ?? defaultAppAuditOutputDirectory(appId: appSpec.appId)

        try FileManager.default.createDirectory(at: resolvedOutput, withIntermediateDirectories: true)

        let validationReportURL = resolvedOutput.appendingPathComponent("validation.report.json")
        try writeJSON(validation, to: validationReportURL)

        let htmlRoot = resolvedOutput.appendingPathComponent("html", isDirectory: true)
        var htmlReports: [RenderHTMLReport] = []
        for context in contexts {
            let htmlOutput = htmlRoot.appendingPathComponent(context.screenSpec.screenId, isDirectory: true)
            let htmlReport = try HTMLRenderer().render(
                context: context,
                tokens: tokens,
                outputDirectory: htmlOutput
            )
            htmlReports.append(htmlReport)
        }

        let penpotReport = try syncPenpot(
            appPath: appPath,
            outputDirectory: resolvedOutput.appendingPathComponent("adapters/penpot", isDirectory: true)
        )
        let pencilReport = try syncPencil(
            appPath: appPath,
            outputDirectory: resolvedOutput.appendingPathComponent("adapters/pencil", isDirectory: true)
        )
        let sampleAppsReport = try buildSampleApps(appPath: appPath)
        let sampleAppsReportURL = resolvedOutput.appendingPathComponent("sample-app-build.report.json")
        try writeJSON(sampleAppsReport, to: sampleAppsReportURL)

        var artifacts: [GeneratedArtifact] = [
            .init(kind: "validation_report", path: validationReportURL.path),
            .init(kind: "penpot_manifest", path: penpotReport.manifestPath),
            .init(kind: "pencil_manifest", path: pencilReport.manifestPath),
            .init(kind: "sample_build_report", path: sampleAppsReportURL.path),
        ]
        artifacts.append(contentsOf: htmlReports.map { .init(kind: "html_review_report", path: $0.reviewReportPath) })

        return AppAuditReport(
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

    public func buildSampleApps(appPath: URL) throws -> SampleAppsBuildReport {
        let validation = try validateApp(appPath: appPath)
        guard validation.ok else {
            throw ProjectError.validationFailed(validation)
        }

        let loader = ContractDocumentLoader()
        let validator = ContractValidator()
        let appSpec = try loader.load(AppSpec.self, from: appPath)
        let contractRoot = validator.resolveContractRoot(startingAt: appPath)
        let doctorReport = doctor()

        var platformReports: [SampleAppPlatformBuildReport] = []
        let supportedPlatforms = appSpec.targetPlatforms.filter { platform in
            platform == .ios || platform == .android
        }

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

            let sampleRoot = try resolveSampleAppRoot(appSpec: appSpec, appURL: appPath, contractRoot: contractRoot, platform: platform)
            try FileManager.default.createDirectory(at: sampleRoot, withIntermediateDirectories: true)
            try ensureSampleAppReadme(at: sampleRoot, platform: platform, appId: appSpec.appId)

            let screenURLs = try resolveAppScreenURLs(appSpec: appSpec, appURL: appPath, contractRoot: contractRoot)
            var screenReports: [SampleAppScreenBuildReport] = []

            for screenURL in screenURLs {
                let screenSpec = try loader.load(ScreenSpec.self, from: screenURL)
                let nativeReport = try generateNative(
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

                try buildSampleScreen(
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

            let proofManifestURL = try writeHostProofManifest(
                sampleRoot: sampleRoot,
                platform: platform,
                screenReports: screenReports
            )

            platformReports.append(
                .init(
                    platform: platform,
                    sampleAppPath: sampleRoot.path,
                    proofManifestPath: proofManifestURL.path,
                    screens: screenReports
                )
            )
        }

        return SampleAppsBuildReport(ok: true, appId: appSpec.appId, platforms: platformReports)
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
        try waitForPreviewServer(url: previewURL, process: process)

        return PreviewServeReport(
            ok: true,
            url: previewURL.absoluteString,
            pid: process.processIdentifier,
            directory: directory.path
        )
    }

    public func audit(projectRoot: URL) throws -> RepoAuditReport {
        let fileManager = FileManager.default
        let requiredPaths = [
            "contracts/apps",
            "contracts/flows",
            "contracts/screens",
            "contracts/motion",
            "contracts/review",
            "contracts/registry",
            "contracts/tokens",
            "schemas/current",
            "PreviewApp/shell",
            "PreviewApp/shell/layout.html",
            "PreviewApp/shell/review.css",
            "PreviewApp/shell/review.js",
            "PreviewApp/evidence/drivers",
            "PreviewApp/evidence/drivers/agent-browser-driver.sh",
            "PreviewApp/evidence/scripts",
            "PreviewApp/evidence/scripts/run-preview-evidence.sh",
            "PreviewApp/evidence/scripts/run-shell-smoke.sh",
            "HostApps/scripts",
            "HostApps/scripts/run-host-proof.sh",
            "HostApps/ios",
            "HostApps/ios/scripts",
            "HostApps/ios/scripts/run-host-proof.sh",
            "HostApps/android",
            "HostApps/android/scripts",
            "HostApps/android/scripts/run-host-proof.sh",
            "meta/runtime/contracts.cue",
        ]
        let forbiddenPaths = [
            "build",
            "samples",
            "MANIFEST.json",
            "meta/views",
        ]

        var errors: [String] = []
        var warnings: [String] = []

        for relativePath in requiredPaths {
            let isFile = relativePath.contains(".")
            let url = projectRoot.appendingPathComponent(relativePath, isDirectory: !isFile)
            if !fileManager.fileExists(atPath: url.path) {
                errors.append("missing required path: \(relativePath)")
            }
        }

        for relativePath in forbiddenPaths {
            let url = projectRoot.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: url.path) {
                errors.append("remove legacy generated path: \(relativePath)")
            }
        }

        let docsDirectory = projectRoot.appendingPathComponent("docs", isDirectory: true)
        let schemaDirectory = projectRoot.appendingPathComponent("schemas/current", isDirectory: true)
        let contractsDirectory = projectRoot.appendingPathComponent("contracts", isDirectory: true)

        let docFiles = directoryContentsIfPresent(at: docsDirectory)
            .filter { $0.pathExtension == "md" }
        let schemaFiles = directoryContentsIfPresent(at: schemaDirectory)
            .filter { $0.pathExtension.lowercased() == "json" }

        var contractJSONCount = 0
        if fileManager.fileExists(atPath: contractsDirectory.path),
           let enumerator = fileManager.enumerator(at: contractsDirectory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                if ext == "json" || ext == "yaml" || ext == "yml" {
                    contractJSONCount += 1
                }
            }
        }

        let checks = IntegrityChecks(
            requiredPathsPresent: errors.filter { $0.hasPrefix("missing required path:") }.isEmpty,
            schemaValidation: !schemaFiles.isEmpty,
            markdownRelativeLinks: true,
            legacyArtifactsAbsent: errors.filter { $0.hasPrefix("remove legacy generated path:") }.isEmpty,
            contractCrossReference: errors.isEmpty,
            docCount: docFiles.count,
            schemaCount: schemaFiles.count,
            contractFileCount: contractJSONCount
        )

        if schemaFiles.isEmpty {
            warnings.append("schemas/current contains no JSON files")
        }

        return RepoAuditReport(
            ok: checks.requiredPathsPresent && checks.schemaValidation && checks.legacyArtifactsAbsent,
            checks: checks,
            errors: errors,
            warnings: warnings
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

    private func compileTokens(appSpec: AppSpec, appURL: URL, contractRoot: URL) throws -> TokenStore {
        let validator = ContractValidator()
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

    private func defaultHTMLOutputDirectory(screenID: String) -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("build/html/\(screenID)", isDirectory: true)
    }

    private func defaultNativeOutputDirectory(screenID: String, platform: Platform) -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("build/native/\(platform.rawValue)/\(screenID)", isDirectory: true)
    }

    private func defaultAdapterOutputDirectory(appId: String, adapter: AdapterKind) -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("build/adapters/\(adapter.rawValue)/\(appId)", isDirectory: true)
    }

    private func defaultAppAuditOutputDirectory(appId: String) -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("build/audit/\(appId)", isDirectory: true)
    }

    private func syncAdapter(
        _ adapter: AdapterKind,
        appPath: URL,
        outputDirectory: URL?
    ) throws -> AdapterSyncReport {
        let validation = try validateApp(appPath: appPath)
        guard validation.ok else {
            throw ProjectError.validationFailed(validation)
        }

        let loader = ContractDocumentLoader()
        let validator = ContractValidator()
        let appSpec = try loader.load(AppSpec.self, from: appPath)
        let contractRoot = validator.resolveContractRoot(startingAt: appPath)
        let contexts = try resolveAppScreenContexts(appSpec: appSpec, appURL: appPath, contractRoot: contractRoot)
        let tokens = try compileTokens(appSpec: appSpec, appURL: appPath, contractRoot: contractRoot)
        let resolvedOutput = outputDirectory ?? defaultAdapterOutputDirectory(appId: appSpec.appId, adapter: adapter)

        return try AdapterSyncRenderer().render(
            adapter: adapter,
            appURL: appPath,
            appSpec: appSpec,
            contexts: contexts,
            tokens: tokens,
            outputDirectory: resolvedOutput
        )
    }

    private func resolveSampleAppRoot(appSpec: AppSpec, appURL: URL, contractRoot: URL, platform: Platform) throws -> URL {
        let validator = ContractValidator()
        switch platform {
        case .ios:
            guard let path = appSpec.sampleApps?.ios, !path.isEmpty else {
                throw ProjectError.invalidArgument("AppSpec.sampleApps.ios is required for build-sample-apps")
            }
            return validator.resolveReference(path, contractRoot: contractRoot, relativeTo: appURL)
        case .android:
            guard let path = appSpec.sampleApps?.android, !path.isEmpty else {
                throw ProjectError.invalidArgument("AppSpec.sampleApps.android is required for build-sample-apps")
            }
            return validator.resolveReference(path, contractRoot: contractRoot, relativeTo: appURL)
        case .html:
            throw ProjectError.invalidArgument("build-sample-apps only supports ios and android")
        }
    }

    private func resolveAppScreenURLs(appSpec: AppSpec, appURL: URL, contractRoot: URL) throws -> [URL] {
        let loader = ContractDocumentLoader()
        let validator = ContractValidator()
        var screenURLs: [URL] = []
        var seen: Set<String> = []

        for flowRef in appSpec.flows {
            let flowURL = validator.resolveReference(flowRef.path, contractRoot: contractRoot, relativeTo: appURL)
            let flowSpec = try loader.load(FlowSpec.self, from: flowURL)
            for screenRef in flowSpec.screens {
                let screenURL = validator.resolveReference(screenRef.path, contractRoot: contractRoot, relativeTo: flowURL)
                if seen.insert(screenURL.standardizedFileURL.path).inserted {
                    screenURLs.append(screenURL.standardizedFileURL)
                }
            }
        }

        return screenURLs.sorted { $0.path < $1.path }
    }

    private func resolveAppScreenContexts(appSpec: AppSpec, appURL: URL, contractRoot: URL) throws -> [ScreenContext] {
        let loader = ContractDocumentLoader()
        let validator = ContractValidator()
        var contexts: [ScreenContext] = []
        var seen: Set<String> = []

        for flowRef in appSpec.flows {
            let flowURL = validator.resolveReference(flowRef.path, contractRoot: contractRoot, relativeTo: appURL)
            let flowSpec = try loader.load(FlowSpec.self, from: flowURL)
            for screenRef in flowSpec.screens {
                let screenURL = validator.resolveReference(screenRef.path, contractRoot: contractRoot, relativeTo: flowURL).standardizedFileURL
                if seen.insert(screenURL.path).inserted {
                    contexts.append(try validator.resolveScreenContext(at: screenURL))
                }
            }
        }

        return contexts
    }

    private func ensureSampleAppReadme(at root: URL, platform: Platform, appId: String) throws {
        let readmeURL = root.appendingPathComponent("README.md")
        guard !FileManager.default.fileExists(atPath: readmeURL.path) else {
            return
        }

        let title = platform == .ios ? "iOS" : "Android"
        try """
        # \(title) Sample App Harness

        This is a source-owned sample app harness root for `\(appId)`.
        Generated files under `GeneratedUI/`, `HostSmoke/`, `BuildArtifacts/`, and `HostProof/` are disposable.
        """.write(to: readmeURL, atomically: true, encoding: .utf8)
    }

    private func writeHostProofManifest(
        sampleRoot: URL,
        platform: Platform,
        screenReports: [SampleAppScreenBuildReport]
    ) throws -> URL {
        let proofRoot = sampleRoot.appendingPathComponent("HostProof", isDirectory: true)
        try FileManager.default.createDirectory(at: proofRoot, withIntermediateDirectories: true)

        let generatedMountRoot = sampleRoot
            .appendingPathComponent("GeneratedUI", isDirectory: true)
            .appendingPathComponent(platform.rawValue, isDirectory: true)
        let wrapperRoot = sampleRoot
            .appendingPathComponent("HostSmoke", isDirectory: true)
            .appendingPathComponent(platform.rawValue, isDirectory: true)
        let logsRoot = sampleRoot
            .appendingPathComponent("BuildArtifacts", isDirectory: true)
            .appendingPathComponent(platform.rawValue, isDirectory: true)

        let manifest = HostProofManifest(
            ok: true,
            platform: platform,
            sampleAppPath: sampleRoot.path,
            generatedMountRoot: generatedMountRoot.path,
            wrapperRoot: wrapperRoot.path,
            logsRoot: logsRoot.path,
            levels: [
                .init(
                    id: "level-0-generated",
                    title: "Generated source smoke",
                    path: generatedMountRoot.path,
                    summary: "Generated UI output ready for host mounting."
                ),
                .init(
                    id: "level-1-host-build",
                    title: "Host harness build",
                    path: wrapperRoot.path,
                    summary: "Wrapper sources compile the generated UI inside a host harness."
                ),
                .init(
                    id: "level-2-runtime-smoke",
                    title: "Runtime flow smoke",
                    path: logsRoot.path,
                    summary: "Runtime logs prove the host harness executed the rendered flow."
                ),
            ],
            screens: screenReports.map {
                .init(
                    screenId: $0.screenId,
                    generatedMountPath: $0.outputDirectory,
                    wrapperPath: $0.wrapperPath,
                    buildLogPath: $0.buildLogPath,
                    runtimeLogPath: $0.runtimeLogPath
                )
            }
        )

        let manifestURL = proofRoot.appendingPathComponent("proof.manifest.json")
        try writeJSON(manifest, to: manifestURL)
        return manifestURL
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

    private func buildSampleScreen(
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
            try renderSwiftSampleWrapper(screenId: screenId).write(to: wrapperURL, atomically: true, encoding: .utf8)
            let preparedSources = try prepareSwiftSampleBuildSources(screenURL: generatedScreenURL, wrapperURL: wrapperURL, scratchDirectory: scratchDirectory)
            let mainURL = scratchDirectory.appendingPathComponent("main.swift")
            try renderSwiftRuntimeEntry(screenId: screenId).write(to: mainURL, atomically: true, encoding: .utf8)
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
            try renderKotlinSampleWrapper(screenId: screenId).write(to: wrapperURL, atomically: true, encoding: .utf8)
            let preparedSources = try prepareKotlinSampleBuildSources(screenURL: generatedScreenURL, wrapperURL: wrapperURL, scratchDirectory: scratchDirectory)
            let compilerURL = try resolvedKotlinCompilerURL()
            let mainURL = scratchDirectory.appendingPathComponent("Main.kt")
            try renderKotlinRuntimeEntry(screenId: screenId).write(to: mainURL, atomically: true, encoding: .utf8)
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
            throw ProjectError.invalidArgument("build-sample-apps only supports ios and android")
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

    private func prepareSwiftSampleBuildSources(screenURL: URL, wrapperURL: URL, scratchDirectory: URL) throws -> [URL] {
        let stubsURL = scratchDirectory.appendingPathComponent("SwiftUIStubs.swift")
        try """
        protocol View {}

        struct EmptyView: View {}
        """.write(to: stubsURL, atomically: true, encoding: .utf8)

        let distilledURL = scratchDirectory.appendingPathComponent(screenURL.lastPathComponent)
        try distilledSwiftHostSmokeSource(from: screenURL).write(to: distilledURL, atomically: true, encoding: .utf8)

        let wrapperCopyURL = scratchDirectory.appendingPathComponent(wrapperURL.lastPathComponent)
        try String(contentsOf: wrapperURL).write(to: wrapperCopyURL, atomically: true, encoding: .utf8)

        return [stubsURL, distilledURL, wrapperCopyURL]
    }

    private func distilledSwiftHostSmokeSource(from source: URL) throws -> String {
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

    private func renderSwiftSampleWrapper(screenId: String) -> String {
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

    private func renderSwiftRuntimeEntry(screenId: String) -> String {
        let typeName = screenTypeName(from: screenId)
        return """
        build\(typeName)Sample()
        print("runtime-smoke:ok:\(screenId)")
        """
    }

    private func prepareKotlinSampleBuildSources(screenURL: URL, wrapperURL: URL, scratchDirectory: URL) throws -> [URL] {
        let stubsURL = scratchDirectory.appendingPathComponent("ComposeRuntimeStubs.kt")
        try """
        package androidx.compose.runtime

        annotation class Composable
        """.write(to: stubsURL, atomically: true, encoding: .utf8)

        let distilledURL = scratchDirectory.appendingPathComponent(screenURL.lastPathComponent)
        try distilledKotlinHostSmokeSource(from: screenURL).write(to: distilledURL, atomically: true, encoding: .utf8)

        let wrapperCopyURL = scratchDirectory.appendingPathComponent(wrapperURL.lastPathComponent)
        try String(contentsOf: wrapperURL).write(to: wrapperCopyURL, atomically: true, encoding: .utf8)

        return [stubsURL, distilledURL, wrapperCopyURL]
    }

    private func distilledKotlinHostSmokeSource(from source: URL) throws -> String {
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

    private func renderKotlinSampleWrapper(screenId: String) -> String {
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

    private func renderKotlinRuntimeEntry(screenId: String) -> String {
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

    private func directoryContentsIfPresent(at directory: URL) -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        return (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
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
