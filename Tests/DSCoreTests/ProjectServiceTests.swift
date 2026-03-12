import DSCore
import Foundation
import Testing

@Suite("ProjectService")
struct ProjectServiceTests {
    private let service = ProjectService()

    @Test("runtime contracts parse from the authoritative runtime root")
    func runtimeContractsParse() throws {
        let contracts = try RuntimeContractLoader().load(
            from: repositoryRoot().appendingPathComponent("meta/runtime/contracts.cue")
        )

        #expect(contracts.cliCommands == [
            "doctor",
            "compile-screen-doc",
            "validate",
            "generate",
            "generate-bundle",
            "preview-serve",
            "audit",
            "v2",
        ])
        #expect(contracts.mcpTools == [
            "doctor",
            "compile_screen_doc",
            "validate_spec",
            "generate_screen",
            "generate_bundle",
            "preview_serve",
            "audit_project",
        ])
        #expect(contracts.docSyncCommands == [
            "sync",
            "export-contracts",
            "export-fragments",
            "render",
            "verify",
        ])
        #expect(contracts.evidenceKeys == [
            "swift_test",
            "cli_smoke",
            "mcp_smoke",
            "docsync_sync",
            "docsync_verify",
            "audit_json",
            "doctor_report",
            "integration_smoke",
            "acceptance_report",
            "reread_checklist",
        ])
        #expect(contracts.doctorCapabilities == [
            "cli",
            "mcp",
            "ios_renderer",
            "android_renderer",
            "html_preview",
            "ios_host_smoke",
            "android_host_smoke",
        ])
        #expect(contracts.doctorToolchains == [
            "swiftc",
            "python3",
            "java_runtime",
            "kotlin",
            "kotlinc",
            "gradle",
        ])
        #expect(contracts.paths.governanceFragmentSpec == "meta/views/governance.fragments.json")
        #expect(contracts.paths.docSyncManifest == "meta/views/docsync.manifest.json")
        #expect(contracts.paths.runtimeContractView == "meta/views/runtime.contracts.json")
        #expect(contracts.paths.governanceContractView == "meta/views/governance.contracts.json")
        #expect(contracts.exitCodes.operational == 1)
        #expect(contracts.exitCodes.validationFailure == 2)
        #expect(contracts.exitCodes.bundleFailure == 4)
        #expect(contracts.exitCodes.auditFailure == 5)
    }

    @Test("governance evidence refs align with runtime evidence keys in the baseline")
    func governanceEvidenceRefsAlignWithRuntimeContracts() throws {
        let runtime = try RuntimeContractLoader().load(
            from: repositoryRoot().appendingPathComponent("meta/runtime/contracts.cue")
        )
        let governance = try GovernanceContractLoader().load(
            from: repositoryRoot().appendingPathComponent("meta/governance/contracts.cue")
        )

        let missing = Set(governance.evidenceRefs).subtracting(runtime.evidenceKeys)
        #expect(missing.isEmpty)
        #expect(governance.generatedDocs.contains("docs/23-authoritative-source-architecture.md"))
        #expect(governance.generatedDocs.contains("docs/24-authoritative-source-execution-plan.md"))
        #expect(governance.generatedDocs.contains("docs/25-authoritative-source-task-matrix.md"))
        #expect(governance.authoritativeRoots.contains("docs/21-integrity-audit.md"))
        #expect(governance.authoritativeRoots.contains("docs/22-validation-report.md"))
        #expect(governance.runtimeArtifacts.map(\.id) == ["local_doctor"])
        #expect(governance.planningArtifacts.map(\.id) == ["authoritative_source_reread"])
        #expect(governance.integrationArtifacts.map(\.id) == ["android_host_smoke", "ios_host_smoke"])
        #expect(governance.acceptanceArtifacts.map(\.id) == ["login_acceptance", "product_detail_acceptance"])
    }

    @Test("authoritative contract views export into concrete JSON files")
    func exportContractViews() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let report = try ContractViewExportService().export(projectRoot: fixtureRoot)
        let runtimeContracts = try JSONDecoder().decode(
            RuntimeContracts.self,
            from: Data(contentsOf: fixtureRoot.appendingPathComponent("meta/views/runtime.contracts.json"))
        )
        let governanceContracts = try JSONDecoder().decode(
            GovernanceContracts.self,
            from: Data(contentsOf: fixtureRoot.appendingPathComponent("meta/views/governance.contracts.json"))
        )

        #expect(report.ok)
        #expect(report.runtimeOutputPath == "meta/views/runtime.contracts.json")
        #expect(report.governanceOutputPath == "meta/views/governance.contracts.json")
        #expect(Set(report.exportedViews + report.unchangedViews) == Set(["meta/views/runtime.contracts.json", "meta/views/governance.contracts.json"]))
        #expect(runtimeContracts.docSyncCommands.contains("export-contracts"))
        #expect(runtimeContracts.evidenceKeys.contains("integration_smoke"))
        #expect(runtimeContracts.evidenceKeys.contains("reread_checklist"))
        #expect(runtimeContracts.doctorCapabilities.contains("android_host_smoke"))
        #expect(runtimeContracts.doctorToolchains.contains("java_runtime"))
        #expect(governanceContracts.evidenceRefs.contains("acceptance_report"))
        #expect(governanceContracts.runtimeArtifacts.count == 1)
        #expect(governanceContracts.planningArtifacts.count == 1)
        #expect(governanceContracts.integrationArtifacts.count == 2)
        #expect(governanceContracts.acceptanceArtifacts.count == 2)
    }

    @Test("doctor separates renderer capability from host smoke readiness")
    func doctorReportsToolchainBackedHostSmokeReadiness() {
        let report = service.doctor()

        #expect(report.ok)
        #expect(report.capabilities.cli)
        #expect(report.capabilities.mcp)
        #expect(report.capabilities.iosRenderer)
        #expect(report.capabilities.androidRenderer)
        #expect(report.capabilities.htmlPreview == report.toolchains.python3)
        #expect(report.capabilities.iosHostSmoke == report.toolchains.swiftc)
        #expect(report.capabilities.androidHostSmoke == (report.toolchains.javaRuntime && (report.toolchains.kotlinc || report.toolchains.gradle)))
    }

    @Test("example ScreenSpecs validate successfully")
    func validateExamples() throws {
        let root = repositoryRoot()
        let tokensDirectory = root.appendingPathComponent("examples/tokens", isDirectory: true)
        let catalogPath = root.appendingPathComponent("examples/catalogs/component-catalog.json")

        let loginReport = try service.validate(
            specPath: root.appendingPathComponent("examples/screens/login.screen.json"),
            tokensDirectory: tokensDirectory,
            catalogPath: catalogPath
        )
        let productReport = try service.validate(
            specPath: root.appendingPathComponent("examples/screens/product-detail.screen.json"),
            tokensDirectory: tokensDirectory,
            catalogPath: catalogPath
        )

        #expect(loginReport.ok)
        #expect(productReport.ok)
        #expect(loginReport.issues.isEmpty)
        #expect(productReport.issues.isEmpty)
    }

    @Test("login screen-doc compiles into the complete interaction contract")
    func compileScreenDocIntoSpec() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let outputPath = tempDirectory.appendingPathComponent("compiled/login.screen.json")
        let compileReport = try service.compileScreenDoc(
            documentPath: root.appendingPathComponent("examples/screen-doc/login.md"),
            outputPath: outputPath
        )

        let compiledSpec = try decode(ScreenSpec.self, from: outputPath)
        let expectedSpec = try decode(ScreenSpec.self, from: root.appendingPathComponent("examples/screens/login.screen.json"))
        let persistedReport = try decode(CompileScreenDocReport.self, from: URL(fileURLWithPath: compileReport.reportPath))
        let validation = try service.validate(
            specPath: outputPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json")
        )

        #expect(compileReport.ok)
        #expect(compiledSpec.screenId == "login")
        #expect(compiledSpec.title == "Login")
        #expect(compiledSpec.intent == "quiet single-column login")
        #expect(compiledSpec.constraints == [
            "one dominant primary action",
            "no decorative elements",
            "semantic tokens only",
        ])
        #expect(compiledSpec.states == ["default", "loading", "error"])
        #expect(compiledSpec.stateFields.map(\.id) == ["email", "password"])
        #expect(compiledSpec.actions.map(\.id) == ["submitLogin"])
        #expect(compiledSpec.previewStates.map(\.id) == ["default", "loading", "error"])
        #expect(compiledSpec.previewStates[1].values["email"] == .string("alex@example.com"))
        #expect(compiledSpec.previewStates[1].note == "Submitting credentials")
        #expect(compiledSpec.platforms == [.ios, .android, .html])
        #expect(compiledSpec.root.kind == "vstack")
        #expect(compiledSpec.root.children?.contains(where: { $0.kind == "text" && $0.role == "title" && $0.text == "Welcome back" }) == true)
        #expect(compiledSpec.root.children?.contains(where: { $0.kind == "textField" && $0.binding == "email" && $0.id == "emailField" && $0.inputType == "email" }) == true)
        #expect(compiledSpec.root.children?.contains(where: { $0.kind == "secureField" && $0.binding == "password" && $0.id == "passwordField" }) == true)
        #expect(compiledSpec.root.children?.contains(where: { $0.kind == "button" && $0.action == "submitLogin" }) == true)
        #expect(compiledSpec.root.children?.contains(where: { $0.kind == "text" && $0.role == "caption" && $0.text == "No extra decoration. Just the essentials." }) == true)
        #expect(compileReport.completionStatus == .complete)
        #expect(compileReport.reportPath.hasSuffix("/login.compile-report.json"))
        #expect(persistedReport == compileReport)
        #expect(compileReport.unresolvedItems.isEmpty)
        #expect(compileReport.warnings.isEmpty)
        #expect(try canonicalJSON(compiledSpec) == canonicalJSON(expectedSpec))
        #expect(validation.ok)
    }

    @Test("product-detail screen-doc compiles into explicit card and action content")
    func compileProductDetailScreenDocIntoSpec() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let outputPath = tempDirectory.appendingPathComponent("compiled/product-detail.screen.json")
        let report = try service.compileScreenDoc(
            documentPath: root.appendingPathComponent("examples/screen-doc/product-detail.md"),
            outputPath: outputPath
        )
        let compiledSpec = try decode(ScreenSpec.self, from: outputPath)
        let expectedSpec = try decode(ScreenSpec.self, from: root.appendingPathComponent("examples/screens/product-detail.screen.json"))

        #expect(report.ok)
        #expect(report.completionStatus == .complete)
        #expect(report.unresolvedItems.isEmpty)
        #expect(report.warnings.isEmpty)
        #expect(compiledSpec.route == "/products/studio-chair")
        #expect(compiledSpec.actions.map(\.id) == ["addToCart"])
        #expect(compiledSpec.previewStates.map(\.id) == ["default"])
        #expect(compiledSpec.previewStates.first?.note == "Default purchase review state.")
        #expect(compiledSpec.assets.map(\.name) == ["studio-chair.png"])
        #expect(compiledSpec.assets.map(\.kind) == [.image])
        #expect(compiledSpec.navigation.map(\.id) == ["shippingDetails"])
        #expect(compiledSpec.navigation.map(\.route) == ["/products/studio-chair/shipping"])
        #expect(compiledSpec.root.children?.contains(where: { $0.kind == "image" && $0.assetName == "studio-chair.png" }) == true)
        #expect(compiledSpec.root.children?.contains(where: { $0.kind == "text" && $0.role == "title" && $0.text == "Studio Chair" }) == true)
        #expect(compiledSpec.root.children?.contains(where: { $0.kind == "button" && $0.title == "Add to cart" && $0.action == "addToCart" }) == true)
        #expect(compiledSpec.root.children?.contains(where: { $0.kind == "button" && $0.title == "Shipping details" && $0.navigation == "shippingDetails" }) == true)
        #expect(compiledSpec.root.children?.contains(where: {
            $0.kind == "card" &&
            $0.children?.count == 3 &&
            $0.children?[0].text == "Price" &&
            $0.children?[1].text == "$240" &&
            $0.children?[2].text == "Delivery included."
        }) == true)
        #expect(try canonicalJSON(compiledSpec) == canonicalJSON(expectedSpec))
    }

    @Test("screen-doc without platforms falls back to config defaultPlatforms")
    func compileScreenDocUsesDefaultPlatforms() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("html-only.md")
        try """
        ---
        screenId: html-only
        title: HTML Only
        components:
          - text.title
          - text.body
        ---
        A compact preview surface.
        """.write(to: screenDocPath, atomically: true, encoding: .utf8)

        let outputPath = tempDirectory.appendingPathComponent("compiled/html-only.screen.json")
        let report = try service.compileScreenDoc(
            documentPath: screenDocPath,
            outputPath: outputPath,
            defaultPlatforms: [.html]
        )
        let compiledSpec = try decode(ScreenSpec.self, from: outputPath)

        #expect(report.ok)
        #expect(compiledSpec.platforms == [.html])
    }

    @Test("screen-doc route is preserved in compiled ScreenSpec")
    func compileScreenDocPreservesRoute() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("routed.md")
        try """
        ---
        screenId: routed
        title: Routed Screen
        route: /settings/profile
        components:
          - text.title
          - text.body
        ---
        A routed screen.
        """.write(to: screenDocPath, atomically: true, encoding: .utf8)

        let outputPath = tempDirectory.appendingPathComponent("compiled/routed.screen.json")
        let report = try service.compileScreenDoc(
            documentPath: screenDocPath,
            outputPath: outputPath
        )
        let compiledSpec = try decode(ScreenSpec.self, from: outputPath)

        #expect(report.ok)
        #expect(compiledSpec.route == "/settings/profile")
    }

    @Test("unsupported screen-doc components compile into deterministic placeholder nodes")
    func compileScreenDocInsertsPlaceholderForUnsupportedComponent() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("unsupported.md")
        try """
        ---
        screenId: unsupported-demo
        title: Unsupported Demo
        components:
          - text.title
          - media.hero
        ---
        A screen that mentions an unsupported component.
        """.write(to: screenDocPath, atomically: true, encoding: .utf8)

        let outputPath = tempDirectory.appendingPathComponent("compiled/unsupported-demo.screen.json")
        let report = try service.compileScreenDoc(
            documentPath: screenDocPath,
            outputPath: outputPath
        )
        let compiledSpec = try decode(ScreenSpec.self, from: outputPath)
        let validation = try service.validate(
            specPath: outputPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json")
        )

        #expect(report.ok)
        #expect(report.completionStatus == .starter)
        #expect(report.warnings.contains("component 'media.hero' is not compiled in v1; placeholder node inserted"))
        #expect(report.unresolvedItems.contains(where: { $0.code == "component.unsupported" && $0.path == "components[1]" }))
        #expect(compiledSpec.root.children?.contains(where: {
            $0.kind == "text" && $0.role == "caption" && $0.text == "Unsupported component: media.hero"
        }) == true)
        #expect(validation.ok)
    }

    @Test("compile-screen-doc marks direct text-only starter specs as complete")
    func compileScreenDocMarksCompleteStarterSpec() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("static-copy.md")
        try """
        ---
        screenId: static-copy
        title: Static Copy
        components:
          - text.title
          - text.body
        ---
        A short explanatory screen.
        """.write(to: screenDocPath, atomically: true, encoding: .utf8)

        let outputPath = tempDirectory.appendingPathComponent("compiled/static-copy.screen.json")
        let report = try service.compileScreenDoc(
            documentPath: screenDocPath,
            outputPath: outputPath,
            defaultPlatforms: [.html]
        )

        #expect(report.ok)
        #expect(report.completionStatus == .complete)
        #expect(report.unresolvedItems.isEmpty)
        #expect(report.warnings.isEmpty)
        #expect(FileManager.default.fileExists(atPath: report.reportPath))
    }

    @Test("complete screen-doc can be validated directly without a checked-in ScreenSpec")
    func validateCompleteScreenDocDirectly() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("static-copy.md")
        try writeCompleteScreenDoc(
            to: screenDocPath,
            screenID: "static-copy",
            title: "Static Copy",
            body: "A short explanatory screen."
        )

        let report = try service.validate(
            screenDocPath: screenDocPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
            defaultPlatforms: [.html]
        )

        #expect(report.ok)
        #expect(report.issues.isEmpty)
    }

    @Test("starter screen-doc validation reports unresolved authoring gaps")
    func validateStarterScreenDocDirectly() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("starter-login.md")
        try writeStarterLoginScreenDoc(to: screenDocPath)
        let report = try service.validate(
            screenDocPath: screenDocPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json")
        )

        #expect(!report.ok)
        #expect(report.issues.contains(where: { $0.code == "textField.missing-binding" && $0.path == "screenDoc.components[2]" }))
        #expect(report.issues.contains(where: { $0.code == "secureField.missing-binding" && $0.path == "screenDoc.components[3]" }))
        #expect(report.issues.contains(where: { $0.code == "button.missing-action" && $0.path == "screenDoc.components[4]" }))
    }

    @Test("screen-doc generation writes a compiled spec into the output directory")
    func generateFromScreenDocWritesCompiledSpec() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("html-only.md")
        try writeCompleteScreenDoc(
            to: screenDocPath,
            screenID: "html-only",
            title: "HTML Only",
            body: "A compact preview surface."
        )

        let outputDirectory = tempDirectory.appendingPathComponent("out", isDirectory: true)
        let report = try service.generate(
            screenDocPath: screenDocPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
            outputDirectory: outputDirectory,
            defaultPlatforms: [.html]
        )

        let compiledSpecPath = outputDirectory.appendingPathComponent("compiled.screen.json")
        let compiledSpec = try decode(ScreenSpec.self, from: compiledSpecPath)
        let manifest = try decode(Manifest.self, from: outputDirectory.appendingPathComponent("manifest.json"))
        let artifactKinds = Set(report.artifacts.map(\.kind))

        #expect(report.ok)
        #expect(FileManager.default.fileExists(atPath: compiledSpecPath.path))
        #expect(compiledSpec.screenId == "html-only")
        #expect(compiledSpec.platforms == [.html])
        #expect(manifest.inputSpecPath == compiledSpecPath.path)
        #expect(artifactKinds.contains("html_screen"))
        #expect(!artifactKinds.contains("ios_screen"))
        #expect(!artifactKinds.contains("android_screen"))
    }

    @Test("starter screen-doc generation fails before artifacts are written")
    func generateFromStarterScreenDocFailsBeforeArtifacts() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocPath = tempDirectory.appendingPathComponent("starter-login.md")
        try writeStarterLoginScreenDoc(to: screenDocPath)
        let outputDirectory = tempDirectory.appendingPathComponent("out", isDirectory: true)

        do {
            _ = try service.generate(
                screenDocPath: screenDocPath,
                tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
                catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
                outputDirectory: outputDirectory
            )
            Issue.record("Expected starter screen-doc generation to fail validation")
        } catch ProjectError.validationFailed(let report) {
            #expect(!report.ok)
            #expect(report.issues.contains(where: { $0.code == "textField.missing-binding" && $0.path == "screenDoc.components[2]" }))
        }

        #expect(!FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("compiled.screen.json").path))
        #expect(!FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("manifest.json").path))
    }

    @Test("generation is deterministic when rerun into the same output directory")
    func generateIsDeterministic() throws {
        let root = repositoryRoot()
        let outputDirectory = try makeTemporaryDirectory().appendingPathComponent("login", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory.deletingLastPathComponent()) }

        let specPath = root.appendingPathComponent("examples/screens/login.screen.json")
        let tokensDirectory = root.appendingPathComponent("examples/tokens", isDirectory: true)
        let catalogPath = root.appendingPathComponent("examples/catalogs/component-catalog.json")

        _ = try service.generate(
            specPath: specPath,
            tokensDirectory: tokensDirectory,
            catalogPath: catalogPath,
            outputDirectory: outputDirectory
        )
        let firstPass = try fileContents(relativeTo: outputDirectory)

        _ = try service.generate(
            specPath: specPath,
            tokensDirectory: tokensDirectory,
            catalogPath: catalogPath,
            outputDirectory: outputDirectory
        )
        let secondPass = try fileContents(relativeTo: outputDirectory)

        #expect(firstPass == secondPass)
        #expect(firstPass.keys.contains("html/login.html"))
        #expect(firstPass.keys.contains("ios/LoginScreen.swift"))
        #expect(firstPass.keys.contains("android/LoginScreen.kt"))
        #expect(firstPass.keys.contains("manifest.json"))

        let swiftScreen = try requiredText(in: firstPass, at: "ios/LoginScreen.swift")
        let swiftTokens = try requiredText(in: firstPass, at: "ios/DesignTokens.swift")
        let composeScreen = try requiredText(in: firstPass, at: "android/LoginScreen.kt")
        let composeTokens = try requiredText(in: firstPass, at: "android/DesignTokens.kt")
        let htmlScreen = try requiredText(in: firstPass, at: "html/login.html")

        #expect(swiftScreen.contains("@Binding var state: LoginScreenState"))
        #expect(swiftScreen.contains("let actions: LoginScreenActions"))
        #expect(swiftScreen.contains("var email: String = \"\""))
        #expect(swiftScreen.contains("var password: String = \"\""))
        #expect(swiftScreen.contains("$state.email"))
        #expect(swiftScreen.contains("$state.password"))
        #expect(!swiftScreen.contains("$state.emailField"))
        #expect(swiftScreen.contains("actions.submitLogin"))
        #expect(swiftScreen.contains(".keyboardType(.emailAddress)"))
        #expect(swiftScreen.contains(".textContentType(.emailAddress)"))
        #expect(swiftScreen.contains(".textContentType(.password)"))
        #expect(swiftScreen.contains(".disableAutocorrection(true)"))
        #expect(swiftScreen.contains(".background(DesignTokens.colorSurfacePrimary.ignoresSafeArea())"))
        #expect(swiftScreen.contains(".font(.title).fontWeight(.semibold)"))
        #expect(swiftScreen.contains(".font(.caption).foregroundStyle(.secondary)"))
        #expect(swiftScreen.contains(".buttonStyle(.borderedProminent)"))
        #expect(!swiftScreen.contains("Color(hex:"))
        #expect(swiftTokens.contains("static let colorSurfacePrimary: Color = Color(.sRGB"))
        #expect(swiftTokens.contains("static let space6: CGFloat = 24"))

        #expect(composeScreen.contains("data class LoginScreenState"))
        #expect(composeScreen.contains("data class LoginScreenActions"))
        #expect(composeScreen.contains("val email: String = \"\""))
        #expect(composeScreen.contains("val password: String = \"\""))
        #expect(composeScreen.contains("value = state.email"))
        #expect(composeScreen.contains("value = state.password"))
        #expect(composeScreen.contains("actions.onEmailChanged"))
        #expect(composeScreen.contains("actions.onPasswordChanged"))
        #expect(!composeScreen.contains("actions.onEmailFieldChanged"))
        #expect(composeScreen.contains("actions.onSubmitLogin"))
        #expect(composeScreen.contains("KeyboardOptions(keyboardType = KeyboardType.Email, autoCorrect = false)"))
        #expect(composeScreen.contains("KeyboardOptions(keyboardType = KeyboardType.Password, autoCorrect = false)"))
        #expect(composeScreen.contains("visualTransformation = PasswordVisualTransformation()"))
        #expect(composeScreen.contains(".fillMaxSize()"))
        #expect(composeScreen.contains(".background(DesignTokens.colorSurfacePrimary)"))
        #expect(composeScreen.contains(".padding(DesignTokens.space6)"))
        #expect(composeScreen.contains("style = MaterialTheme.typography.titleLarge"))
        #expect(composeScreen.contains("style = MaterialTheme.typography.bodySmall"))
        #expect(composeTokens.contains("val colorSurfacePrimary = Color(0xFFFFFFFF)"))
        #expect(composeTokens.contains("val space6 = 24.dp"))
        #expect(htmlScreen.contains("<input type=\"email\" name=\"email\" />"))
        #expect(htmlScreen.contains("<input type=\"password\" name=\"password\" autocomplete=\"current-password\" />"))
        #expect(!htmlScreen.contains("name=\"emailField\""))
        #expect(swiftScreen.contains("#Preview(\"loading\")"))
        #expect(swiftScreen.contains("LoginScreenState(email: \"alex@example.com\", password: \"hunter2\")"))
        #expect(composeScreen.contains("@Preview(name = \"loading\")"))
        #expect(composeScreen.contains("state = LoginScreenState(email = \"alex@example.com\", password = \"hunter2\")"))
        #expect(htmlScreen.contains("Declared preview states: default, loading, error"))
        #expect(htmlScreen.contains("data-preview-state=\"loading\""))
        #expect(htmlScreen.contains("Submitting credentials"))
        #expect(htmlScreen.contains("<input type=\"email\" name=\"email\" value=\"alex@example.com\" />"))
    }

    @Test("complete screen-doc bundle generation writes compiled specs for each output")
    func generateBundleFromScreenDocs() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocDirectory = tempDirectory.appendingPathComponent("screen-doc", isDirectory: true)
        try FileManager.default.createDirectory(at: screenDocDirectory, withIntermediateDirectories: true)
        try writeCompleteScreenDoc(
            to: screenDocDirectory.appendingPathComponent("login.md"),
            screenID: "login",
            title: "Login",
            body: "A compact login review surface."
        )
        try writeCompleteScreenDoc(
            to: screenDocDirectory.appendingPathComponent("product-detail.md"),
            screenID: "product-detail",
            title: "Product Detail",
            body: "A compact product summary surface."
        )

        let outputDirectory = tempDirectory.appendingPathComponent("bundle", isDirectory: true)

        let report = try service.generateBundle(
            screenDocDirectory: screenDocDirectory,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
            outputDirectory: outputDirectory
        )

        #expect(report.ok)
        #expect(report.failures.isEmpty)
        #expect(report.reports.map(\.screenId) == ["login", "product-detail"])

        for screenID in ["login", "product-detail"] {
            let screenDirectory = outputDirectory.appendingPathComponent(screenID, isDirectory: true)
            let compiledSpecPath = screenDirectory.appendingPathComponent("compiled.screen.json")
            let manifestPath = screenDirectory.appendingPathComponent("manifest.json")
            let manifest = try decode(Manifest.self, from: manifestPath)

            #expect(FileManager.default.fileExists(atPath: compiledSpecPath.path))
            #expect(manifest.inputSpecPath == compiledSpecPath.path)
        }
    }

    @Test("starter screen-doc bundle generation reports validation failures")
    func generateBundleFromStarterScreenDocsFails() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let screenDocDirectory = tempDirectory.appendingPathComponent("screen-doc", isDirectory: true)
        try FileManager.default.createDirectory(at: screenDocDirectory, withIntermediateDirectories: true)
        try writeStarterLoginScreenDoc(to: screenDocDirectory.appendingPathComponent("login.md"))
        try writeStarterProductDetailScreenDoc(to: screenDocDirectory.appendingPathComponent("product-detail.md"))
        let outputDirectory = tempDirectory.appendingPathComponent("bundle", isDirectory: true)
        let report = try service.generateBundle(
            screenDocDirectory: screenDocDirectory,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
            outputDirectory: outputDirectory
        )

        #expect(!report.ok)
        #expect(report.reports.isEmpty)
        #expect(report.failures.contains(where: { $0.contains("login.md") && $0.contains("screenDoc.components[2]") }))
        #expect(report.failures.contains(where: { $0.contains("product-detail.md") && $0.contains("screenDoc.components[2]") }))
        #expect(!FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("login/compiled.screen.json").path))
    }

    @Test("repository audit passes against the checked-in baseline")
    func auditPasses() throws {
        let report = try service.audit(projectRoot: repositoryRoot())

        #expect(report.ok)
        #expect(report.checks.coreFilesExist)
        #expect(report.checks.jsonParse)
        #expect(report.checks.schemaValidation)
        #expect(report.checks.markdownRelativeLinks)
        #expect(report.checks.docSyncFreshness)
        #expect(report.checks.contractViewFreshness)
        #expect(report.checks.contractCrossReference)
        #expect(report.errors.isEmpty)
        #expect(report.warnings.isEmpty)
    }

    @Test("validation rejects duplicate states in ScreenSpec")
    func validateRejectsDuplicateStates() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let invalidSpec = ScreenSpec(
            schemaVersion: "1.0",
            screenId: "duplicate-states",
            title: "Duplicate States",
            states: ["default", "default"],
            platforms: [.html],
            surface: ScreenSurface(
                backgroundColor: "{color.surface.primary}",
                padding: "{space.6}"
            ),
            root: ScreenNode(kind: "text", role: "body", text: "Broken states")
        )
        let specPath = tempDirectory.appendingPathComponent("duplicate-states.screen.json")
        try JSONEncoder().encode(invalidSpec).write(to: specPath)

        let report = try service.validate(
            specPath: specPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json")
        )

        #expect(!report.ok)
        #expect(report.issues.contains(where: { $0.code == "state.duplicate" && $0.path == "states[1]" }))
    }

    @Test("validation rejects missing bindings when stateFields are declared")
    func validateRejectsMissingBindingWithDeclaredStateFields() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let invalidSpec = ScreenSpec(
            schemaVersion: "1.0",
            screenId: "missing-binding",
            title: "Missing Binding",
            stateFields: [
                ScreenStateField(id: "email", type: .string, defaultValue: .string("")),
            ],
            platforms: [.html],
            surface: ScreenSurface(
                backgroundColor: "{color.surface.primary}",
                padding: "{space.6}"
            ),
            root: ScreenNode(
                kind: "textField",
                label: "Email",
                inputType: "email"
            )
        )
        let specPath = tempDirectory.appendingPathComponent("missing-binding.screen.json")
        try JSONEncoder().encode(invalidSpec).write(to: specPath)

        let report = try service.validate(
            specPath: specPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json")
        )

        #expect(!report.ok)
        #expect(report.issues.contains(where: { $0.code == "binding.required" && $0.path == "root.binding" }))
    }

    @Test("validation rejects button actions outside the declared action registry")
    func validateRejectsUnknownExplicitActionReference() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let invalidSpec = ScreenSpec(
            schemaVersion: "1.0",
            screenId: "missing-action",
            title: "Missing Action",
            actions: [
                ScreenAction(id: "submit")
            ],
            platforms: [.html],
            surface: ScreenSurface(
                backgroundColor: "{color.surface.primary}",
                padding: "{space.6}"
            ),
            root: ScreenNode(
                kind: "button",
                title: "Continue",
                action: "submitLogin"
            )
        )
        let specPath = tempDirectory.appendingPathComponent("missing-action.screen.json")
        try JSONEncoder().encode(invalidSpec).write(to: specPath)

        let report = try service.validate(
            specPath: specPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json")
        )

        #expect(!report.ok)
        #expect(report.issues.contains(where: { $0.code == "action.reference" && $0.path == "root.action" }))
    }

    @Test("validation rejects button navigation outside the declared navigation registry")
    func validateRejectsUnknownNavigationReference() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let invalidSpec = ScreenSpec(
            schemaVersion: "1.0",
            screenId: "missing-navigation",
            title: "Missing Navigation",
            navigation: [
                ScreenNavigationDestination(id: "shippingDetails", route: "/products/studio-chair/shipping")
            ],
            platforms: [.html],
            surface: ScreenSurface(
                backgroundColor: "{color.surface.primary}",
                padding: "{space.6}"
            ),
            root: ScreenNode(
                kind: "button",
                title: "Shipping details",
                navigation: "returns"
            )
        )
        let specPath = tempDirectory.appendingPathComponent("missing-navigation.screen.json")
        try JSONEncoder().encode(invalidSpec).write(to: specPath)

        let report = try service.validate(
            specPath: specPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json")
        )

        #expect(!report.ok)
        #expect(report.issues.contains(where: { $0.code == "navigation.reference" && $0.path == "root.navigation" }))
    }

    @Test("validation rejects buttons that declare both action and navigation")
    func validateRejectsAmbiguousButtonInteraction() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let invalidSpec = ScreenSpec(
            schemaVersion: "1.0",
            screenId: "ambiguous-button",
            title: "Ambiguous Button",
            actions: [
                ScreenAction(id: "submit")
            ],
            navigation: [
                ScreenNavigationDestination(id: "next", route: "/checkout")
            ],
            platforms: [.html],
            surface: ScreenSurface(
                backgroundColor: "{color.surface.primary}",
                padding: "{space.6}"
            ),
            root: ScreenNode(
                kind: "button",
                title: "Continue",
                action: "submit",
                navigation: "next"
            )
        )
        let specPath = tempDirectory.appendingPathComponent("ambiguous-button.screen.json")
        try JSONEncoder().encode(invalidSpec).write(to: specPath)

        let report = try service.validate(
            specPath: specPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json")
        )

        #expect(!report.ok)
        #expect(report.issues.contains(where: { $0.code == "button.interaction" && $0.path == "root" }))
    }

    @Test("validation rejects image assets outside the declared asset registry")
    func validateRejectsUnknownAssetReference() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let invalidSpec = ScreenSpec(
            schemaVersion: "1.0",
            screenId: "missing-asset",
            title: "Missing Asset",
            assets: [
                ScreenAsset(name: "star.fill", kind: .icon)
            ],
            platforms: [.html],
            surface: ScreenSurface(
                backgroundColor: "{color.surface.primary}",
                padding: "{space.6}"
            ),
            root: ScreenNode(
                kind: "image",
                assetName: "hero-photo.png"
            )
        )
        let specPath = tempDirectory.appendingPathComponent("missing-asset.screen.json")
        try JSONEncoder().encode(invalidSpec).write(to: specPath)

        let report = try service.validate(
            specPath: specPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json")
        )

        #expect(!report.ok)
        #expect(report.issues.contains(where: { $0.code == "asset.reference" && $0.path == "root.assetName" }))
    }

    @Test("validation rejects missing preview states for declared states")
    func validateRejectsMissingPreviewStateCoverage() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let invalidSpec = ScreenSpec(
            schemaVersion: "1.0",
            screenId: "missing-preview-state",
            title: "Missing Preview State",
            states: ["default", "error"],
            previewStates: [
                ScreenPreviewState(id: "default")
            ],
            platforms: [.html],
            surface: ScreenSurface(
                backgroundColor: "{color.surface.primary}",
                padding: "{space.6}"
            ),
            root: ScreenNode(
                kind: "text",
                role: "body",
                text: "Preview coverage"
            )
        )
        let specPath = tempDirectory.appendingPathComponent("missing-preview-state.screen.json")
        try JSONEncoder().encode(invalidSpec).write(to: specPath)

        let report = try service.validate(
            specPath: specPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json")
        )

        #expect(!report.ok)
        #expect(report.issues.contains(where: { $0.code == "previewState.missing" && $0.path == "states[1]" }))
    }

    @Test("validation rejects invalid route formats")
    func validateRejectsInvalidRoutes() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let invalidSpec = ScreenSpec(
            schemaVersion: "1.0",
            screenId: "invalid-route",
            title: "Invalid Route",
            route: "settings profile",
            navigation: [
                ScreenNavigationDestination(id: "details", route: "/shipping details")
            ],
            platforms: [.html],
            surface: ScreenSurface(
                backgroundColor: "{color.surface.primary}",
                padding: "{space.6}"
            ),
            root: ScreenNode(
                kind: "button",
                title: "Shipping details",
                navigation: "details"
            )
        )
        let specPath = tempDirectory.appendingPathComponent("invalid-route.screen.json")
        try JSONEncoder().encode(invalidSpec).write(to: specPath)

        let report = try service.validate(
            specPath: specPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json")
        )

        #expect(!report.ok)
        #expect(report.issues.contains(where: { $0.code == "route.invalid" && $0.path == "route" }))
        #expect(report.issues.contains(where: { $0.code == "route.invalid" && $0.path == "navigation[0].route" }))
    }

    @Test("repository audit fails when governance evidence refs drift from runtime evidence keys")
    func auditFailsOnContractCrossReferenceDrift() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let governancePath = fixtureRoot.appendingPathComponent("meta/governance/contracts.cue")
        let drifted = try String(contentsOf: governancePath).replacingOccurrences(
            of: "\"audit_json\"",
            with: "\"missing_audit_json\""
        )
        try drifted.write(to: governancePath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.contractCrossReference)
        #expect(report.errors.contains(where: { $0.contains("governance evidence refs are not declared in runtime root: missing_audit_json") }))
    }

    @Test("repository audit fails when governance generatedDocs inventory drifts from the doc-sync manifest")
    func auditFailsOnGeneratedDocInventoryDrift() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let governancePath = fixtureRoot.appendingPathComponent("meta/governance/contracts.cue")
        let drifted = try String(contentsOf: governancePath).replacingOccurrences(
            of: "\"docs/23-authoritative-source-architecture.md\"",
            with: "\"docs/24-authoritative-source-execution-plan.md\""
        )
        try drifted.write(to: governancePath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.contractCrossReference)
        #expect(report.errors.contains(where: { $0.contains("generatedDocs inventory does not match doc-sync manifest") }))
        #expect(report.errors.contains(where: { $0.contains("docs/23-authoritative-source-architecture.md") }))
    }

    @Test("repository audit fails when governance artifact inventory points at a missing source-owned file")
    func auditFailsOnMissingGovernanceArtifactPath() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let missingArtifact = fixtureRoot.appendingPathComponent("audit/evidence/acceptance/login.json")
        try FileManager.default.removeItem(at: missingArtifact)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.contractCrossReference)
        #expect(report.errors.contains(where: { $0.contains("governance inventory paths do not exist") }))
        #expect(report.errors.contains(where: { $0.contains("audit/evidence/acceptance/login.json") }))
    }

    @Test("repository audit fails when planning reread checklist omits a canonical planning document")
    func auditFailsOnIncompletePlanningRereadChecklist() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/planning/reread-checklist.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "    \"docs/23-authoritative-source-architecture.md\",\n",
            with: ""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: {
            $0.contains("reread-checklist.json: documents must include canonical planning reread set: docs/23-authoritative-source-architecture.md")
        }))
    }

    @Test("repository audit fails when partial integration evidence omits knownGap")
    func auditFailsOnInvalidIntegrationEvidenceShape() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/integration/android-host-smoke.json")
        let invalid = try String(contentsOf: artifactPath)
            .replacingOccurrences(
                of: "\"status\": \"pass\"",
                with: "\"status\": \"partial\""
            )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("android-host-smoke.json: partial evidence must declare knownGap") }))
    }

    @Test("repository audit fails when doctor evidence references a test case that is not declared in the source test file")
    func auditFailsOnMissingVerificationTestCaseDeclaration() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/runtime/doctor.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"testCase\": \"doctor separates renderer capability from host smoke readiness\"",
            with: "\"testCase\": \"doctor reports local runtime capabilities and host smoke readiness\""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("verification.testCase must match an @Test declaration") }))
    }

    @Test("repository audit fails when doctor evidence uses a non-canonical verification command")
    func auditFailsOnUnexpectedDoctorVerificationCommand() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/runtime/doctor.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"command\": \"swift run dsctl doctor --json\"",
            with: "\"command\": \"swift test\""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("verification.command must be one of: swift run dsctl doctor --json") }))
    }

    @Test("repository audit fails when integration evidence testSource line does not point to the declared test")
    func auditFailsOnVerificationTestSourceLineDrift() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/integration/ios-host-smoke.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"testSource\": \"Tests/DSCoreTests/ProjectServiceTests.swift:1771\"",
            with: "\"testSource\": \"Tests/DSCoreTests/ProjectServiceTests.swift:1200\""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("verification.testSource line must point to") }))
    }

    @Test("repository audit fails when integration evidence uses a non-canonical verification command")
    func auditFailsOnUnexpectedIntegrationVerificationCommand() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/integration/ios-host-smoke.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"command\": \"swift test\"",
            with: "\"command\": \"swift run dsctl doctor --json\""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("verification.command must be one of: swift test") }))
    }

    @Test("repository audit fails when integration evidence verifiedOn drifts from the referenced doctor evidence date")
    func auditFailsOnIntegrationVerifiedOnDrift() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/integration/ios-host-smoke.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"verifiedOn\": \"2026-03-11\"",
            with: "\"verifiedOn\": \"2026-03-10\""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("verifiedOn must match referenced doctorEvidence") }))
    }

    @Test("repository audit fails when acceptance evidence references host evidence outside the governance inventory")
    func auditFailsOnUndeclaredAcceptanceHostEvidence() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/acceptance/login.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"audit/evidence/integration/android-host-smoke.json\"",
            with: "\"audit/evidence/acceptance/product-detail.json\""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("host evidence is not declared in governance integrationArtifacts") }))
        #expect(report.errors.contains(where: { $0.contains("audit/evidence/acceptance/product-detail.json") }))
    }

    @Test("repository audit fails when acceptance evidence references a generated manifest for another screen")
    func auditFailsOnMismatchedAcceptanceGeneratedManifest() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/acceptance/login.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"generatedManifest\": \"build/login/manifest.json\"",
            with: "\"generatedManifest\": \"build/product-detail/manifest.json\""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("generatedManifest inputSpecPath must match authoring screen-spec") }))
    }

    @Test("repository audit fails when acceptance evidence verifiedOn drifts from referenced host evidence dates")
    func auditFailsOnAcceptanceVerifiedOnDrift() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/acceptance/login.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"verifiedOn\": \"2026-03-11\"",
            with: "\"verifiedOn\": \"2026-03-10\""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("verifiedOn must match referenced hostEvidence dates") }))
    }

    @Test("repository audit fails when acceptance generated manifest omits a declared platform output")
    func auditFailsOnAcceptanceGeneratedManifestPlatformCoverage() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let manifestPath = fixtureRoot.appendingPathComponent("build/login/manifest.json")
        let invalid = try String(contentsOf: manifestPath).replacingOccurrences(
            of: #"\/build\/login\/android\/"#,
            with: #"\/build\/login\/missing\/"#
        )
        try invalid.write(to: manifestPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("generatedManifest must cover declared platforms") }))
        #expect(report.errors.contains(where: { $0.contains("android") }))
    }

    @Test("repository audit fails when acceptance evidence omits the canonical verification command for its own screen")
    func auditFailsOnMissingAcceptanceVerificationCommand() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/acceptance/login.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"swift run dsctl generate --config examples/configs/dsctl.config.json --screen-id login --json\"",
            with: "\"swift run dsctl generate --config examples/configs/dsctl.config.json --screen-id product-detail --json\""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("verification must include required commands") }))
        #expect(report.errors.contains(where: { $0.contains("--screen-id login --json") }))
    }

    @Test("repository audit fails when planning ledger leaves INTEGRATE-02 in progress despite pass Android evidence")
    func auditFailsOnPlannedIntegrationLedgerDrift() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let fragmentsPath = fixtureRoot.appendingPathComponent("meta/views/governance.fragments.json")
        let invalid = try String(contentsOf: fragmentsPath).replacingOccurrences(
            of: #"["INTEGRATE-02", "Done""#,
            with: #"["INTEGRATE-02", "In Progress""#
        )
        try invalid.write(to: fragmentsPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("task INTEGRATE-02 status must be Done") }))
    }

    @Test("repository audit fails when planning ledger leaves P7 in progress despite pass acceptance evidence")
    func auditFailsOnAcceptancePhaseLedgerDrift() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let fragmentsPath = fixtureRoot.appendingPathComponent("meta/views/governance.fragments.json")
        let invalid = try String(contentsOf: fragmentsPath).replacingOccurrences(
            of: #"["P7", "Done""#,
            with: #"["P7", "In Progress""#
        )
        try invalid.write(to: fragmentsPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("phase P7 status must be Done") }))
    }

    @Test("repository audit fails when acceptance evidence omits host coverage for a declared native platform")
    func auditFailsOnMissingAcceptanceHostPlatformCoverage() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/acceptance/login.json")
        let invalid = try String(contentsOf: artifactPath)
            .replacingOccurrences(
                of: "\"hostEvidence\": [\n    \"audit/evidence/integration/ios-host-smoke.json\",\n    \"audit/evidence/integration/android-host-smoke.json\"\n  ],",
                with: "\"hostEvidence\": [\n    \"audit/evidence/integration/ios-host-smoke.json\"\n  ],"
            )
            .replacingOccurrences(
                of: "\"blockingHostEvidence\": [\n    \"audit/evidence/integration/android-host-smoke.json\"\n  ],",
                with: "\"blockingHostEvidence\": [],"
            )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("hostEvidence must cover declared native platforms") }))
        #expect(report.errors.contains(where: { $0.contains("android") }))
    }

    @Test("repository audit fails when partial acceptance evidence omits blocking host evidence for a non-pass smoke artifact")
    func auditFailsOnMissingAcceptanceBlockingHostEvidence() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let androidHostArtifactPath = fixtureRoot.appendingPathComponent("audit/evidence/integration/android-host-smoke.json")
        let invalidAndroidHost = try String(contentsOf: androidHostArtifactPath)
            .replacingOccurrences(
                of: "\"status\": \"pass\"",
                with: "\"status\": \"partial\""
            )
            .replacingOccurrences(
                of: "\"notes\": [",
                with: "\"knownGap\": \"compile-backed Android smoke evidence is temporarily unavailable in this fixture.\",\n  \"notes\": ["
            )
        try invalidAndroidHost.write(to: androidHostArtifactPath, atomically: true, encoding: .utf8)

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/acceptance/login.json")
        let invalid = try String(contentsOf: artifactPath)
            .replacingOccurrences(
                of: "\"status\": \"pass\"",
                with: "\"status\": \"partial\""
            )
            .replacingOccurrences(
                of: "\"blockingHostEvidence\": [],",
                with: "\"blockingHostEvidence\": [],"
            )
            .replacingOccurrences(
                of: "\"residualGaps\": []",
                with: "\"residualGaps\": [\n    \"fixture-only residual\"\n  ]"
            )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("partial acceptance evidence must declare blockingHostEvidence for non-pass host evidence") }))
    }

    @Test("repository audit fails when pass acceptance evidence references non-pass host smoke")
    func auditFailsOnPassAcceptanceWithNonPassHostEvidence() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let androidHostArtifactPath = fixtureRoot.appendingPathComponent("audit/evidence/integration/android-host-smoke.json")
        let invalidAndroidHost = try String(contentsOf: androidHostArtifactPath)
            .replacingOccurrences(
                of: "\"status\": \"pass\"",
                with: "\"status\": \"partial\""
            )
            .replacingOccurrences(
                of: "\"notes\": [",
                with: "\"knownGap\": \"compile-backed Android smoke evidence is temporarily unavailable in this fixture.\",\n  \"notes\": ["
            )
        try invalidAndroidHost.write(to: androidHostArtifactPath, atomically: true, encoding: .utf8)

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/acceptance/login.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"status\": \"pass\"",
            with: "\"status\": \"pass\""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("pass acceptance evidence requires all hostEvidence to have status=pass") }))
    }

    @Test("repository audit fails when blocking host evidence points at a passing host smoke artifact")
    func auditFailsOnBlockingAcceptancePassHostEvidence() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/acceptance/login.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"blockingHostEvidence\": []",
            with: "\"blockingHostEvidence\": [\n    \"audit/evidence/integration/ios-host-smoke.json\"\n  ]"
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("blockingHostEvidence must reference only non-pass host evidence") }))
    }

    @Test("repository audit fails when integration evidence references doctor evidence outside the governance inventory")
    func auditFailsOnUndeclaredDoctorEvidence() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/integration/android-host-smoke.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"audit/evidence/runtime/doctor.json\"",
            with: "\"audit/evidence/acceptance/login.json\""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("doctor evidence is not declared in governance runtimeArtifacts") }))
    }

    @Test("repository audit fails when pass integration evidence requires a false doctor capability")
    func auditFailsOnPassIntegrationCapabilityDrift() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/runtime/doctor.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"ios_host_smoke\": true",
            with: "\"ios_host_smoke\": false"
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("pass evidence requires ios_host_smoke=true") }))
    }

    @Test("repository audit fails when the runtime doctor snapshot drifts from the local machine")
    func auditFailsOnStaleDoctorSnapshot() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/runtime/doctor.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "Target: arm64-apple-macosx26.0",
            with: "Target: stale-local-snapshot"
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("doctor snapshot does not match current local doctor output") }))
    }

    @Test("repository audit fails when acceptance review coverage drifts from declared preview states")
    func auditFailsOnAcceptanceReviewPreviewCoverageDrift() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/acceptance/login.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"loading\"",
            with: "\"missing\""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("review.reviewedPreviewStates must match declared previewStates") }))
    }

    @Test("repository audit fails when acceptance review checklist omits a required review domain")
    func auditFailsOnAcceptanceReviewChecklistDrift() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let artifactPath = fixtureRoot.appendingPathComponent("audit/evidence/acceptance/login.json")
        let invalid = try String(contentsOf: artifactPath).replacingOccurrences(
            of: "\"native.adapter_viability\"",
            with: "\"native.omitted\""
        )
        try invalid.write(to: artifactPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.jsonParse)
        #expect(report.errors.contains(where: { $0.contains("review.checklist must include required ids: native.adapter_viability") }))
    }

    @Test("repository audit fails when generated docs are stale against the doc-sync manifest")
    func auditFailsOnStaleGeneratedDocs() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let generatedDocPath = fixtureRoot.appendingPathComponent("docs/23-authoritative-source-architecture.md")
        let staleContent = try String(contentsOf: generatedDocPath).replacingOccurrences(
            of: "| runtime root | CLI command, MCP tool, input contract, output path, exit code, evidence key | task priority, decision gate prose, roadmap sequencing |",
            with: "| runtime root | stale-runtime-contract | stale-governance-boundary |"
        )
        try staleContent.write(to: generatedDocPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.docSyncFreshness)
        #expect(report.errors.contains(where: { $0.contains("doc-sync freshness failed: docs/23-authoritative-source-architecture.md") }))
    }

    @Test("repository audit fails when exported contract views are stale")
    func auditFailsOnStaleContractViews() throws {
        let fixtureRoot = try makeAuditFixture()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let runtimeViewPath = fixtureRoot.appendingPathComponent("meta/views/runtime.contracts.json")
        let staleContent = try String(contentsOf: runtimeViewPath).replacingOccurrences(
            of: "\"audit\"",
            with: "\"stale-audit\""
        )
        try staleContent.write(to: runtimeViewPath, atomically: true, encoding: .utf8)

        let report = try service.audit(projectRoot: fixtureRoot)

        #expect(!report.ok)
        #expect(!report.checks.contractViewFreshness)
        #expect(report.errors.contains(where: { $0.contains("contract view freshness failed: meta/views/runtime.contracts.json") }))
    }

    @Test("repository audit returns a structured failure report for an invalid root")
    func auditInvalidRoot() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let report = try service.audit(projectRoot: tempDirectory)

        #expect(!report.ok)
        #expect(!report.checks.coreFilesExist)
        #expect(!report.errors.isEmpty)
    }

    @Test("config paths resolve relative to the config file and drive validation")
    func configResolution() throws {
        let configPath = repositoryRoot().appendingPathComponent("examples/configs/dsctl.config.json")
        let resolved = try service.resolveConfig(at: configPath)
        let report = try service.validate(screenID: "login", configPath: configPath)

        #expect(resolved.projectRoot == repositoryRoot())
        #expect(resolved.screenSpecDirectory.path.hasSuffix("/examples/screens"))
        #expect(resolved.tokenDirectory.path.hasSuffix("/examples/tokens"))
        #expect(resolved.catalogPath.path.hasSuffix("/examples/catalogs/component-catalog.json"))
        #expect(resolved.defaultBundleOutputDirectory.path.hasSuffix("/build/bundle"))
        #expect(report.ok)
    }

    @Test("relative projectRoot resolves from the config file directory")
    func configResolutionWithRelativeProjectRoot() throws {
        let fixtureRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let examplesDirectory = fixtureRoot.appendingPathComponent("examples", isDirectory: true)
        try FileManager.default.copyItem(
            at: repositoryRoot().appendingPathComponent("examples", isDirectory: true),
            to: examplesDirectory
        )

        let config = DSConfig(
            schemaVersion: "1.0",
            projectRoot: "../..",
            screenDocDir: "examples/screen-doc",
            screenSpecDir: "examples/screens",
            tokenDir: "examples/tokens",
            catalogPath: "examples/catalogs/component-catalog.json",
            buildDir: "build",
            defaultPlatforms: [.ios, .android, .html]
        )

        let configPath = examplesDirectory.appendingPathComponent("configs/dsctl.config.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: configPath)

        let resolved = try service.resolveConfig(at: configPath)
        let report = try service.validate(screenID: "login", configPath: configPath)

        #expect(resolved.projectRoot == fixtureRoot)
        #expect(resolved.screenSpecDirectory == fixtureRoot.appendingPathComponent("examples/screens", isDirectory: true))
        #expect(resolved.tokenDirectory == fixtureRoot.appendingPathComponent("examples/tokens", isDirectory: true))
        #expect(report.ok)
    }

    @Test("generation respects the platforms declared in ScreenSpec")
    func generationRespectsPlatforms() throws {
        let root = repositoryRoot()
        let outputDirectory = try makeTemporaryDirectory().appendingPathComponent("html-only", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory.deletingLastPathComponent()) }

        let original = try decode(
            ScreenSpec.self,
            from: root.appendingPathComponent("examples/screens/login.screen.json")
        )
        let htmlOnlySpec = ScreenSpec(
            schemaVersion: original.schemaVersion,
            screenId: original.screenId,
            title: original.title,
            route: original.route,
            intent: original.intent,
            constraints: original.constraints,
            states: original.states,
            stateFields: original.stateFields,
            actions: original.actions,
            assets: original.assets,
            previewStates: original.previewStates,
            platforms: [.html],
            surface: original.surface,
            root: original.root
        )

        let specPath = outputDirectory.deletingLastPathComponent().appendingPathComponent("login-html-only.screen.json")
        try JSONEncoder().encode(htmlOnlySpec).write(to: specPath)

        let report = try service.generate(
            specPath: specPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
            outputDirectory: outputDirectory
        )

        let artifactKinds = Set(report.artifacts.map(\.kind))
        #expect(artifactKinds.contains("html_screen"))
        #expect(artifactKinds.contains("html_index"))
        #expect(artifactKinds.contains("html_tokens"))
        #expect(!artifactKinds.contains("ios_screen"))
        #expect(!artifactKinds.contains("android_screen"))
        #expect(!FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("ios").path))
        #expect(!FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("android").path))
        #expect(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("html/login.html").path))
    }

    @Test("image and icon nodes require assets and generate platform-specific primitives")
    func imageAndIconGeneration() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let spec = ScreenSpec(
            schemaVersion: "1.0",
            screenId: "media-demo",
            title: "Media Demo",
            assets: [
                ScreenAsset(name: "hero-photo.png", kind: .image),
                ScreenAsset(name: "star.fill", kind: .icon),
            ],
            platforms: [.ios, .android, .html],
            surface: ScreenSurface(
                backgroundColor: "{color.surface.primary}",
                padding: "{space.6}"
            ),
            root: ScreenNode(
                kind: "vstack",
                spacing: "{space.4}",
                children: [
                    ScreenNode(kind: "image", assetName: "hero-photo.png"),
                    ScreenNode(kind: "icon", assetName: "star.fill"),
                ]
            )
        )

        let specPath = tempDirectory.appendingPathComponent("media-demo.screen.json")
        try JSONEncoder().encode(spec).write(to: specPath)

        let validation = try service.validate(
            specPath: specPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json")
        )
        #expect(validation.ok)

        let report = try service.generate(
            specPath: specPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
            outputDirectory: tempDirectory.appendingPathComponent("out", isDirectory: true)
        )
        let contents = try fileContents(relativeTo: tempDirectory.appendingPathComponent("out", isDirectory: true))

        let swiftScreen = try requiredText(in: contents, at: "ios/MediaDemoScreen.swift")
        let composeScreen = try requiredText(in: contents, at: "android/MediaDemoScreen.kt")
        let htmlScreen = try requiredText(in: contents, at: "html/media-demo.html")

        #expect(report.ok)
        #expect(swiftScreen.contains("Image(\"hero-photo.png\")"))
        #expect(swiftScreen.contains("Image(systemName: \"star.fill\")"))
        #expect(composeScreen.contains("Image(painter = painterResource(id = R.drawable.hero_photo)"))
        #expect(composeScreen.contains("Icon(painter = painterResource(id = R.drawable.star_fill)"))
        #expect(htmlScreen.contains("<img class=\"image\" src=\"hero-photo.png\""))
        #expect(htmlScreen.contains("<img class=\"icon\" src=\"star.fill\""))
    }

    @Test("product cards inherit typed surface tokens in native outputs")
    func productCardSurfaceStyling() throws {
        let root = repositoryRoot()
        let outputDirectory = try makeTemporaryDirectory().appendingPathComponent("product-detail", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory.deletingLastPathComponent()) }

        _ = try service.generate(
            specPath: root.appendingPathComponent("examples/screens/product-detail.screen.json"),
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
            outputDirectory: outputDirectory
        )

        let contents = try fileContents(relativeTo: outputDirectory)
        let swiftScreen = try requiredText(in: contents, at: "ios/ProductDetailScreen.swift")
        let composeScreen = try requiredText(in: contents, at: "android/ProductDetailScreen.kt")

        #expect(swiftScreen.contains(".background(DesignTokens.colorSurfaceSecondary)"))
        #expect(swiftScreen.contains("RoundedRectangle(cornerRadius: DesignTokens.radiusCard)"))
        #expect(composeScreen.contains("CardDefaults.cardColors(containerColor = DesignTokens.colorSurfaceSecondary)"))
        #expect(composeScreen.contains("shape = RoundedCornerShape(DesignTokens.radiusCard)"))
    }

    @Test("product-detail navigation is preserved across generated outputs")
    func productDetailNavigationParity() throws {
        let root = repositoryRoot()
        let outputDirectory = try makeTemporaryDirectory().appendingPathComponent("product-detail", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory.deletingLastPathComponent()) }

        _ = try service.generate(
            specPath: root.appendingPathComponent("examples/screens/product-detail.screen.json"),
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
            outputDirectory: outputDirectory
        )

        let contents = try fileContents(relativeTo: outputDirectory)
        let swiftScreen = try requiredText(in: contents, at: "ios/ProductDetailScreen.swift")
        let composeScreen = try requiredText(in: contents, at: "android/ProductDetailScreen.kt")
        let htmlScreen = try requiredText(in: contents, at: "html/product-detail.html")

        #expect(swiftScreen.contains("struct ProductDetailScreenNavigation"))
        #expect(swiftScreen.contains("let navigation: ProductDetailScreenNavigation"))
        #expect(swiftScreen.contains("Button(\"Shipping details\", action: navigation.shippingDetails)"))
        #expect(composeScreen.contains("data class ProductDetailScreenNavigation("))
        #expect(composeScreen.contains("navigation: ProductDetailScreenNavigation = ProductDetailScreenNavigation()"))
        #expect(composeScreen.contains("OutlinedButton(onClick = navigation.onShippingDetails)"))
        #expect(htmlScreen.contains("href=\"/products/studio-chair/shipping\""))
        #expect(htmlScreen.contains("data-navigation-id=\"shippingDetails\""))
        #expect(htmlScreen.contains(">Shipping details</a>"))
    }

    @Test("ios host smoke wrappers typecheck generated login and product-detail screens")
    func iosHostIntegrationSmoke() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let loginOutputDirectory = tempDirectory.appendingPathComponent("login", isDirectory: true)
        let productOutputDirectory = tempDirectory.appendingPathComponent("product-detail", isDirectory: true)

        _ = try service.generate(
            specPath: root.appendingPathComponent("examples/screens/login.screen.json"),
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
            outputDirectory: loginOutputDirectory
        )
        _ = try service.generate(
            specPath: root.appendingPathComponent("examples/screens/product-detail.screen.json"),
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
            outputDirectory: productOutputDirectory
        )

        try typecheckSwiftSources(
            [
                loginOutputDirectory.appendingPathComponent("ios/DesignTokens.swift"),
                loginOutputDirectory.appendingPathComponent("ios/LoginScreen.swift"),
                root.appendingPathComponent("integration/ios/LoginHostScreen.swift"),
            ],
            scratchDirectory: tempDirectory.appendingPathComponent("login-typecheck", isDirectory: true)
        )
        try typecheckSwiftSources(
            [
                productOutputDirectory.appendingPathComponent("ios/DesignTokens.swift"),
                productOutputDirectory.appendingPathComponent("ios/ProductDetailScreen.swift"),
                root.appendingPathComponent("integration/ios/ProductDetailHostScreen.swift"),
            ],
            scratchDirectory: tempDirectory.appendingPathComponent("product-typecheck", isDirectory: true)
        )
    }

    @Test("android host smoke wrappers compile generated login and product-detail screens with kotlinc")
    func androidHostIntegrationCompileSmoke() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let loginOutputDirectory = tempDirectory.appendingPathComponent("login", isDirectory: true)
        let productOutputDirectory = tempDirectory.appendingPathComponent("product-detail", isDirectory: true)

        _ = try service.generate(
            specPath: root.appendingPathComponent("examples/screens/login.screen.json"),
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
            outputDirectory: loginOutputDirectory
        )
        _ = try service.generate(
            specPath: root.appendingPathComponent("examples/screens/product-detail.screen.json"),
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
            outputDirectory: productOutputDirectory
        )

        try typecheckKotlinSources(
            [
                loginOutputDirectory.appendingPathComponent("android/LoginScreen.kt"),
                root.appendingPathComponent("integration/android/LoginHostScreen.kt"),
            ],
            scratchDirectory: tempDirectory.appendingPathComponent("login-kotlin-typecheck", isDirectory: true)
        )
        try typecheckKotlinSources(
            [
                productOutputDirectory.appendingPathComponent("android/ProductDetailScreen.kt"),
                root.appendingPathComponent("integration/android/ProductDetailHostScreen.kt"),
            ],
            scratchDirectory: tempDirectory.appendingPathComponent("product-kotlin-typecheck", isDirectory: true)
        )
    }

    @Test("number input types map to platform keyboard hints")
    func numberInputMapsToPlatformHints() throws {
        let root = repositoryRoot()
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let spec = ScreenSpec(
            schemaVersion: "1.0",
            screenId: "quantity-entry",
            title: "Quantity Entry",
            platforms: [.ios, .android, .html],
            surface: ScreenSurface(
                backgroundColor: "{color.surface.primary}",
                padding: "{space.6}"
            ),
            root: ScreenNode(
                kind: "vstack",
                spacing: "{space.4}",
                children: [
                    ScreenNode(kind: "textField", id: "quantity", label: "Quantity", inputType: "number")
                ]
            )
        )

        let specPath = tempDirectory.appendingPathComponent("quantity-entry.screen.json")
        try JSONEncoder().encode(spec).write(to: specPath)

        _ = try service.generate(
            specPath: specPath,
            tokensDirectory: root.appendingPathComponent("examples/tokens", isDirectory: true),
            catalogPath: root.appendingPathComponent("examples/catalogs/component-catalog.json"),
            outputDirectory: tempDirectory.appendingPathComponent("out", isDirectory: true)
        )

        let contents = try fileContents(relativeTo: tempDirectory.appendingPathComponent("out", isDirectory: true))
        let swiftScreen = try requiredText(in: contents, at: "ios/QuantityEntryScreen.swift")
        let composeScreen = try requiredText(in: contents, at: "android/QuantityEntryScreen.kt")
        let htmlScreen = try requiredText(in: contents, at: "html/quantity-entry.html")

        #expect(swiftScreen.contains(".keyboardType(.numberPad)"))
        #expect(composeScreen.contains("KeyboardOptions(keyboardType = KeyboardType.Number)"))
        #expect(htmlScreen.contains("<input type=\"number\" name=\"quantity\" />"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeAuditFixture() throws -> URL {
        let root = repositoryRoot()
        let fixtureRoot = try makeTemporaryDirectory()
        let fileManager = FileManager.default

        for file in ["README.md", "MASTER_BLUEPRINT.md", "AGENTS.md"] {
            try fileManager.copyItem(
                at: root.appendingPathComponent(file),
                to: fixtureRoot.appendingPathComponent(file)
            )
        }

        for directory in ["docs", "examples", "schemas", "prompts", "meta", "audit", "integration", "build", "Tests"] {
            try fileManager.copyItem(
                at: root.appendingPathComponent(directory, isDirectory: true),
                to: fixtureRoot.appendingPathComponent(directory, isDirectory: true)
            )
        }

        return fixtureRoot
    }

    private func typecheckSwiftSources(_ sources: [URL], scratchDirectory: URL) throws {
        try FileManager.default.createDirectory(at: scratchDirectory, withIntermediateDirectories: true)

        let preparedSources = try prepareSwiftHostSmokeSources(sources, scratchDirectory: scratchDirectory)
        _ = try runProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/swiftc"),
            arguments: [
                "-typecheck",
                "-parse-as-library",
            ] + preparedSources.map(\.path),
            currentDirectoryURL: repositoryRoot()
        )
    }

    private func prepareSwiftHostSmokeSources(_ sources: [URL], scratchDirectory: URL) throws -> [URL] {
        var preparedSources: [URL] = [
            try writeSwiftUISmokeStubs(to: scratchDirectory.appendingPathComponent("SwiftUIStubs.swift"))
        ]

        for source in sources where source.pathExtension == "swift" {
            guard source.lastPathComponent != "DesignTokens.swift" else {
                continue
            }

            let sanitized: String
            if source.lastPathComponent.hasSuffix("HostScreen.swift") {
                sanitized = try strippedSwiftUIImports(from: source)
            } else {
                sanitized = try distilledSwiftHostSmokeSource(from: source)
            }

            let outputURL = scratchDirectory.appendingPathComponent(source.lastPathComponent)
            try sanitized.write(to: outputURL, atomically: true, encoding: .utf8)
            preparedSources.append(outputURL)
        }

        return preparedSources
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
        let properties = lines[(screenStructIndex + 1)..<bodyIndex]
            .compactMap(hostSmokeProperty)
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

        if trimmed.hasPrefix("@Binding var ") {
            let declaration = String(trimmed.dropFirst("@Binding var ".count))
            let parts = declaration.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2 else {
                return nil
            }
            return HostSmokeProperty(
                parameter: "\(parts[0]): Binding<\(parts[1])>",
                assignment: "self._\(parts[0]) = \(parts[0])"
            )
        }

        if trimmed.hasPrefix("let ") || trimmed.hasPrefix("var ") {
            let keywordLength = trimmed.hasPrefix("let ") ? 4 : 4
            let declaration = String(trimmed.dropFirst(keywordLength))
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

    private func writeSwiftUISmokeStubs(to url: URL) throws -> URL {
        try """
        protocol View {}

        struct EmptyView: View {}

        @propertyWrapper
        struct Binding<Value> {
            var wrappedValue: Value
            var projectedValue: Binding<Value> { self }
        }

        @propertyWrapper
        struct State<Value> {
            var wrappedValue: Value
            var projectedValue: Binding<Value> { Binding(wrappedValue: wrappedValue) }
        }
        """.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func typecheckKotlinSources(_ sources: [URL], scratchDirectory: URL) throws {
        try FileManager.default.createDirectory(at: scratchDirectory, withIntermediateDirectories: true)

        let preparedSources = try prepareKotlinHostSmokeSources(sources, scratchDirectory: scratchDirectory)
        let compilerURL = try resolvedKotlinCompilerURL()
        let outputURL = scratchDirectory.appendingPathComponent("host-smoke.jar")

        _ = try runProcess(
            executableURL: compilerURL,
            arguments: preparedSources.map(\.path) + ["-d", outputURL.path],
            currentDirectoryURL: repositoryRoot(),
            environment: kotlinSmokeEnvironment()
        )
    }

    private func prepareKotlinHostSmokeSources(_ sources: [URL], scratchDirectory: URL) throws -> [URL] {
        var preparedSources: [URL] = [
            try writeKotlinComposeSmokeStubs(to: scratchDirectory.appendingPathComponent("ComposeRuntimeStubs.kt"))
        ]

        for source in sources where source.pathExtension == "kt" {
            let sanitized: String
            if source.lastPathComponent.hasSuffix("HostScreen.kt") {
                sanitized = try strippedKotlinImports(
                    from: source,
                    keeping: ["androidx.compose.runtime.Composable"]
                )
            } else {
                sanitized = try distilledKotlinHostSmokeSource(from: source)
            }

            let outputURL = scratchDirectory.appendingPathComponent(source.lastPathComponent)
            try sanitized.write(to: outputURL, atomically: true, encoding: .utf8)
            preparedSources.append(outputURL)
        }

        return preparedSources
    }

    private func distilledKotlinHostSmokeSource(from source: URL) throws -> String {
        let withoutPreviews = (
            try strippedKotlinImports(
                from: source,
                keeping: ["androidx.compose.runtime.Composable"]
            )
        )
            .components(separatedBy: "\n@Preview").first ?? ""
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

    private func writeKotlinComposeSmokeStubs(to url: URL) throws -> URL {
        try """
        package androidx.compose.runtime

        annotation class Composable
        """.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func resolvedKotlinCompilerURL() throws -> URL {
        if let compilerURL = resolvedExecutableURL(
            named: "kotlinc",
            fallbackPaths: ["/opt/homebrew/bin/kotlinc", "/usr/local/bin/kotlinc"]
        ) {
            return compilerURL
        }

        throw ProjectError.io("Missing kotlinc for Android host smoke")
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

    @discardableResult
    private func runProcess(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL,
        environment: [String: String]? = nil
    ) throws -> ProcessResult {
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

        return ProcessResult(stdout: stdoutText, stderr: stderrText)
    }

    private func resolvedExecutableURL(named command: String, fallbackPaths: [String] = []) -> URL? {
        let fileManager = FileManager.default
        let environment = ProcessInfo.processInfo.environment

        let pathEntries = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }

        for entry in pathEntries {
            let candidate = URL(fileURLWithPath: entry, isDirectory: true).appendingPathComponent(command)
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        for fallbackPath in fallbackPaths where fileManager.isExecutableFile(atPath: fallbackPath) {
            return URL(fileURLWithPath: fallbackPath)
        }

        return nil
    }

    private func fileContents(relativeTo directory: URL) throws -> [String: Data] {
        let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { !$0.hasDirectoryPath }
            .sorted { $0.path < $1.path } ?? []
        let rootPathComponents = directory.resolvingSymlinksInPath().pathComponents

        var contents: [String: Data] = [:]
        for file in files {
            let relativePath = file.resolvingSymlinksInPath().pathComponents
                .dropFirst(rootPathComponents.count)
                .joined(separator: "/")
            contents[relativePath] = try Data(contentsOf: file)
        }
        return contents
    }

    private func requiredText(in contents: [String: Data], at path: String) throws -> String {
        guard let data = contents[path], let text = String(data: data, encoding: .utf8) else {
            throw ProjectError.io("Missing generated text artifact at \(path)")
        }
        return text
    }

    private func writeCompleteScreenDoc(to url: URL, screenID: String, title: String, body: String) throws {
        try """
        ---
        screenId: \(screenID)
        title: \(title)
        components:
          - text.title
          - text.body
        ---
        \(body)
        """.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeStarterLoginScreenDoc(to url: URL) throws {
        try """
        ---
        screenId: login
        title: Login
        platforms: [ios, android, html]
        intent: quiet single-column login
        constraints:
          - one dominant primary action
          - no decorative elements
          - semantic tokens only
        states:
          - default
          - loading
          - error
        components:
          - text.title
          - text.body
          - textField.email
          - secureField.password
          - button.primary
        ---
        Use one title, two fields, and one primary action.
        The screen should feel calm, direct, and minimal.
        Errors should be short and explicit.
        """.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeStarterProductDetailScreenDoc(to url: URL) throws {
        try """
        ---
        screenId: product-detail
        title: Product Detail
        platforms: [ios, android, html]
        intent: focused product summary with one purchase action
        constraints:
          - one clear information hierarchy
          - one primary CTA
          - semantic tokens only
        states:
          - default
        components:
          - text.title
          - text.body
          - card
          - button.primary
        ---
        Present the product name, short summary, price context, and one purchase action.
        The screen should remain quiet and compact.
        """.write(to: url, atomically: true, encoding: .utf8)
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    private func canonicalJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    private struct ProcessResult {
        let stdout: String
        let stderr: String
    }

    private struct HostSmokeProperty {
        let parameter: String
        let assignment: String
    }
}
