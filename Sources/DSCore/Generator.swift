import Foundation

public struct ProjectGenerator {
    public init() {}

    public func generate(
        spec: ScreenSpec,
        tokens: TokenStore,
        specPath: URL,
        tokenPaths: [URL],
        outputDirectory: URL,
        validationReport: ValidationReport
    ) throws -> GenerateReport {
        let fileManager = FileManager.default
        let enabledPlatforms = Set(spec.platforms)

        let iosDirectory = outputDirectory.appendingPathComponent("ios", isDirectory: true)
        let androidDirectory = outputDirectory.appendingPathComponent("android", isDirectory: true)
        let htmlDirectory = outputDirectory.appendingPathComponent("html", isDirectory: true)

        if enabledPlatforms.contains(.ios) {
            try fileManager.createDirectory(at: iosDirectory, withIntermediateDirectories: true)
        }
        if enabledPlatforms.contains(.android) {
            try fileManager.createDirectory(at: androidDirectory, withIntermediateDirectories: true)
        }
        if enabledPlatforms.contains(.html) {
            try fileManager.createDirectory(at: htmlDirectory, withIntermediateDirectories: true)
        }

        let swiftScreenName = screenTypeName(from: spec.screenId) + ".swift"
        let composeScreenName = screenTypeName(from: spec.screenId) + ".kt"
        let htmlName = "\(spec.screenId).html"

        let swiftScreenURL = iosDirectory.appendingPathComponent(swiftScreenName)
        let swiftTokensURL = iosDirectory.appendingPathComponent("DesignTokens.swift")
        let composeScreenURL = androidDirectory.appendingPathComponent(composeScreenName)
        let composeTokensURL = androidDirectory.appendingPathComponent("DesignTokens.kt")
        let htmlURL = htmlDirectory.appendingPathComponent(htmlName)
        let indexURL = htmlDirectory.appendingPathComponent("index.html")
        let cssURL = htmlDirectory.appendingPathComponent("tokens.css")
        let validationURL = outputDirectory.appendingPathComponent("report.validation.json")
        let manifestURL = outputDirectory.appendingPathComponent("manifest.json")

        var artifacts: [GeneratedArtifact] = []

        if enabledPlatforms.contains(.ios) {
            try write(renderSwiftTokens(tokens), to: swiftTokensURL)
            try write(renderSwiftScreen(spec), to: swiftScreenURL)
            artifacts.append(.init(kind: "ios_screen", path: swiftScreenURL.path))
            artifacts.append(.init(kind: "ios_tokens", path: swiftTokensURL.path))
        }

        if enabledPlatforms.contains(.android) {
            try write(renderComposeTokens(tokens), to: composeTokensURL)
            try write(renderComposeScreen(spec), to: composeScreenURL)
            artifacts.append(.init(kind: "android_screen", path: composeScreenURL.path))
            artifacts.append(.init(kind: "android_tokens", path: composeTokensURL.path))
        }

        if enabledPlatforms.contains(.html) {
            try write(renderHTML(spec, tokens: tokens), to: htmlURL)
            try write(renderHTMLIndex(screenID: spec.screenId, htmlName: htmlName), to: indexURL)
            try write(renderTokensCSS(tokens), to: cssURL)
            artifacts.append(.init(kind: "html_screen", path: htmlURL.path))
            artifacts.append(.init(kind: "html_index", path: indexURL.path))
            artifacts.append(.init(kind: "html_tokens", path: cssURL.path))
        }

        let encoder = configuredEncoder()
        try encoder.encode(validationReport).write(to: validationURL)
        artifacts.append(.init(kind: "validation_report", path: validationURL.path))

        let manifest = Manifest(
            inputSpecPath: specPath.path,
            inputTokenPaths: tokenPaths.map(\.path),
            generatedFiles: artifacts.map(\.path),
            validationSummary: validationReport.summary,
            generatorVersion: "0.1.0",
            schemaVersion: spec.schemaVersion
        )
        try encoder.encode(manifest).write(to: manifestURL)

        return GenerateReport(
            ok: true,
            screenId: spec.screenId,
            outputDirectory: outputDirectory.path,
            artifacts: artifacts,
            manifestPath: manifestURL.path,
            validationReportPath: validationURL.path
        )
    }

    private func write(_ text: String, to url: URL) throws {
        try text.data(using: .utf8).unwrap("Unable to encode text at \(url.path)").write(to: url)
    }

    private func renderTokensCSS(_ tokens: TokenStore) -> String {
        let lines = tokens.tokens.map { token in
            "  --\(cssVariableName(for: token.path)): \(cssValue(for: token));"
        }

        return """
        :root {
        \(lines.joined(separator: "\n"))
        }

        body {
          margin: 0;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          color: var(--color-text-primary);
          background: var(--color-surface-primary);
        }

        .preview-shell {
          padding: var(--space-6);
          display: flex;
          flex-direction: column;
          gap: var(--space-6);
        }

        .preview-header {
          display: flex;
          flex-direction: column;
          gap: var(--space-2);
        }

        .preview-eyebrow {
          margin: 0;
          font-size: var(--font-size-caption);
          color: var(--color-text-secondary);
          text-transform: uppercase;
          letter-spacing: 0.08em;
        }

        .preview-title {
          margin: 0;
          font-size: var(--font-size-title);
          font-weight: 700;
        }

        .preview-summary {
          margin: 0;
          font-size: var(--font-size-body);
          color: var(--color-text-secondary);
        }

        .preview-stack {
          display: flex;
          flex-direction: column;
          gap: var(--space-6);
        }

        .preview-state {
          display: flex;
          flex-direction: column;
          gap: var(--space-3);
        }

        .preview-state-header {
          display: flex;
          flex-direction: column;
          gap: var(--space-1);
        }

        .preview-state-name {
          margin: 0;
          font-size: var(--font-size-label);
          font-weight: 700;
        }

        .preview-state-note {
          margin: 0;
          font-size: var(--font-size-caption);
          color: var(--color-text-secondary);
        }

        .screen {
          min-height: 100vh;
          box-sizing: border-box;
        }

        .stack {
          display: flex;
          flex-direction: column;
        }

        .row {
          display: flex;
          flex-direction: row;
        }

        .card {
          background: var(--color-surface-secondary);
          border-radius: var(--radius-card);
          padding: var(--space-4);
        }

        .text-role-title {
          font-size: var(--font-size-title);
          font-weight: 700;
          margin: 0;
        }

        .text-role-body {
          font-size: var(--font-size-body);
          margin: 0;
        }

        .text-role-caption,
        .text-role-label {
          font-size: var(--font-size-caption);
          color: var(--color-text-secondary);
          margin: 0;
        }

        .button {
          display: inline-block;
          padding: var(--space-2) var(--space-4);
          border-radius: var(--radius-card);
          border: 1px solid transparent;
          cursor: pointer;
          font-size: var(--font-size-label);
          text-decoration: none;
        }

        .button-primary {
          background: var(--color-action-primary);
          color: var(--color-text-on-action);
        }

        .button-secondary {
          background: transparent;
          border-color: var(--color-action-primary);
          color: var(--color-action-primary);
        }

        .field {
          display: flex;
          flex-direction: column;
          gap: var(--space-2);
        }

        .field input {
          padding: var(--space-2);
          border-radius: var(--radius-card);
          border: 1px solid var(--color-text-secondary);
          font-size: var(--font-size-body);
        }

        .image {
          display: block;
          max-width: 100%;
          height: auto;
          border-radius: var(--radius-card);
        }

        .icon {
          width: 20px;
          height: 20px;
          object-fit: contain;
        }
        """
    }

    private func renderHTMLIndex(screenID: String, htmlName: String) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta http-equiv="refresh" content="0; url=\(htmlName)" />
          <title>\(screenID) preview</title>
        </head>
        <body>
          <p>Redirecting to <a href="\(htmlName)">\(screenID)</a>…</p>
        </body>
        </html>
        """
    }

    private func renderHTML(_ spec: ScreenSpec, tokens: TokenStore) -> String {
        let background = cssReference(for: spec.surface.backgroundColor)
        let padding = cssReference(for: spec.surface.padding)
        let previewStates = resolvedPreviewStates(for: spec)

        if previewStates.count == 1 && spec.previewStates.isEmpty {
            return """
            <!doctype html>
            <html lang="en">
            <head>
              <meta charset="utf-8" />
              <meta name="viewport" content="width=device-width, initial-scale=1" />
              <title>\(escape(spec.title))</title>
              <link rel="stylesheet" href="tokens.css" />
            </head>
            <body>
              <main class="screen" style="background: \(background); padding: \(padding);">
            \(renderHTMLNode(spec.root, spec: spec, previewState: nil, depth: 2))
              </main>
            </body>
            </html>
            """
        }

        let summary = previewStates.map(\.id).joined(separator: ", ")
        let previewSections = previewStates.map { previewState in
            renderHTMLPreviewState(spec: spec, previewState: previewState, background: background, padding: padding)
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>\(escape(spec.title))</title>
          <link rel="stylesheet" href="tokens.css" />
        </head>
        <body>
          <div class="preview-shell">
            <header class="preview-header">
              <p class="preview-eyebrow">Review Surface</p>
              <h1 class="preview-title">\(escape(spec.title))</h1>
              <p class="preview-summary">Declared preview states: \(escape(summary))</p>
            </header>
            <section class="preview-stack">
              \(previewSections)
            </section>
          </div>
        </body>
        </html>
        """
    }

    private func renderHTMLPreviewState(spec: ScreenSpec, previewState: ScreenPreviewState, background: String, padding: String) -> String {
        let noteBlock = previewState.note.map { note in
            "                  <p class=\"preview-state-note\">\(escape(note))</p>"
        }

        let lines = [
            "              <section class=\"preview-state\" data-preview-state=\"\(escape(previewState.id))\">",
            "                <header class=\"preview-state-header\">",
            "                  <p class=\"preview-state-name\">\(escape(previewState.id))</p>",
            noteBlock,
            "                </header>",
            "                <main class=\"screen\" style=\"background: \(background); padding: \(padding);\">",
            renderHTMLNode(spec.root, spec: spec, previewState: previewState, depth: 9),
            "                </main>",
            "              </section>"
        ].compactMap { $0 }

        return lines.joined(separator: "\n")
    }

    private func renderHTMLNode(_ node: ScreenNode, spec: ScreenSpec, previewState: ScreenPreviewState?, depth: Int) -> String {
        let indent = String(repeating: "  ", count: depth)
        let spacingStyle = node.spacing.map { " style=\"gap: \(cssReference(for: $0));\"" } ?? ""

        switch node.kind {
        case "vstack":
            let children = renderChildren(node.children, spec: spec, previewState: previewState, depth: depth + 1)
            return """
        \(indent)<section class="stack"\(spacingStyle)>
        \(children)
        \(indent)</section>
        """
        case "hstack":
            let children = renderChildren(node.children, spec: spec, previewState: previewState, depth: depth + 1)
            return """
        \(indent)<section class="row"\(spacingStyle)>
        \(children)
        \(indent)</section>
        """
        case "card":
            let children = renderChildren(node.children, spec: spec, previewState: previewState, depth: depth + 1)
            let style = node.spacing.map { " style=\"display:flex; flex-direction:column; gap: \(cssReference(for: $0));\"" } ?? ""
            return """
        \(indent)<section class="card"\(style)>
        \(children)
        \(indent)</section>
        """
        case "text":
            let role = node.role ?? "body"
            return "\(indent)<p class=\"text-role-\(role)\">\(escape(node.text ?? ""))</p>"
        case "textField":
            let valueAttribute = htmlValueAttribute(for: node, spec: spec, previewState: previewState)
            return """
        \(indent)<label class="field">
        \(indent)  <span class="text-role-label">\(escape(node.label ?? ""))</span>
        \(indent)  <input type="\(htmlInputType(for: node))" name="\(escape(fieldBindingReference(for: node)))"\(valueAttribute) />
        \(indent)</label>
        """
        case "secureField":
            let valueAttribute = htmlValueAttribute(for: node, spec: spec, previewState: previewState)
            return """
        \(indent)<label class="field">
        \(indent)  <span class="text-role-label">\(escape(node.label ?? ""))</span>
        \(indent)  <input type="password" name="\(escape(fieldBindingReference(for: node)))"\(valueAttribute) autocomplete="current-password" />
        \(indent)</label>
        """
        case "button":
            let variant = node.variant ?? "primary"
            if let destination = navigationDestination(for: node, spec: spec) {
                return "\(indent)<a class=\"button button-\(variant)\" href=\"\(escape(destination.route))\" data-navigation-id=\"\(escape(destination.id))\">\(escape(node.title ?? ""))</a>"
            }
            return "\(indent)<button class=\"button button-\(variant)\">\(escape(node.title ?? ""))</button>"
        case "divider":
            return "\(indent)<hr />"
        case "spacer":
            return "\(indent)<div style=\"height: \(cssReference(for: node.spacing ?? "{space.2}") );\"></div>"
        case "image":
            return "\(indent)<img class=\"image\" src=\"\(escape(node.assetName ?? ""))\" alt=\"\(escape(node.assetName ?? ""))\" />"
        case "icon":
            return "\(indent)<img class=\"icon\" src=\"\(escape(node.assetName ?? ""))\" alt=\"\" aria-hidden=\"true\" />"
        default:
            return "\(indent)<div>Unsupported node: \(escape(node.kind))</div>"
        }
    }

    private func renderChildren(_ children: [ScreenNode]?, spec: ScreenSpec, previewState: ScreenPreviewState?, depth: Int) -> String {
        (children ?? []).map { renderHTMLNode($0, spec: spec, previewState: previewState, depth: depth) }.joined(separator: "\n")
    }

    private func renderSwiftTokens(_ tokens: TokenStore) -> String {
        let lines = tokens.tokens.map { token -> String in
            let identifier = swiftIdentifier(for: token.path)
            switch token.type {
            case "dimension":
                return "    static let \(identifier): CGFloat = \(token.value)"
            case "color":
                return "    static let \(identifier): Color = \(swiftColorLiteral(token.value))"
            default:
                return "    static let \(identifier): String = \"\(escapeSwift(token.value))\""
            }
        }

        return """
        import SwiftUI

        enum DesignTokens {
        \(lines.joined(separator: "\n"))
        }
        """
    }

    private func renderComposeTokens(_ tokens: TokenStore) -> String {
        let lines = tokens.tokens.map { token -> String in
            let identifier = swiftIdentifier(for: token.path)
            switch token.type {
            case "dimension":
                return "    val \(identifier) = \(token.value).dp"
            case "color":
                return "    val \(identifier) = \(composeColorLiteral(token.value))"
            default:
                return "    const val \(identifier): String = \"\(escapeKotlin(token.value))\""
            }
        }

        return """
        import androidx.compose.ui.graphics.Color
        import androidx.compose.ui.unit.dp

        object DesignTokens {
        \(lines.joined(separator: "\n"))
        }
        """
    }

    private func renderSwiftScreen(_ spec: ScreenSpec) -> String {
        let screenName = screenTypeName(from: spec.screenId)
        let declaredFields = stateFields(for: spec)
        let declaredActions = actions(for: spec)
        let declaredNavigation = navigationDestinations(for: spec)
        let body = renderSwiftNode(spec.root, indent: 2)
        let padding = swiftDimensionReference(spec.surface.padding)
        let background = swiftColorReference(spec.surface.backgroundColor)
        let stateName = "\(screenName)State"
        let actionsName = "\(screenName)Actions"
        let navigationName = "\(screenName)Navigation"
        let stateMembers = declaredFields.isEmpty
            ? "    init() {}\n"
            : declaredFields.map(renderSwiftStateField).joined(separator: "\n") + "\n"
        let actionMembers = declaredActions.isEmpty
            ? "    init() {}\n"
            : declaredActions.map { "    var \(swiftMemberName(from: $0.id)): () -> Void = {}" }.joined(separator: "\n") + "\n"
        let navigationBlock = declaredNavigation.isEmpty
            ? ""
            : """

        struct \(navigationName) {
        \(declaredNavigation.map { "    var \(swiftMemberName(from: $0.id)): () -> Void = {}" }.joined(separator: "\n"))
        }
        """
        let navigationProperty = declaredNavigation.isEmpty ? "" : "\n    let navigation: \(navigationName)"
        let previewBlocks = renderSwiftPreviewBlocks(
            spec: spec,
            stateName: stateName,
            screenName: screenName,
            actionsName: actionsName,
            navigationName: declaredNavigation.isEmpty ? nil : navigationName,
            declaredFields: declaredFields
        )

        return """
        import SwiftUI

        struct \(stateName) {
        \(stateMembers)}

        struct \(actionsName) {
        \(actionMembers)}
        \(navigationBlock)

        struct \(screenName): View {
            @Binding var state: \(stateName)
            let actions: \(actionsName)\(navigationProperty)

            var body: some View {
                ScrollView {
        \(body)
                        .padding(\(padding))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(\(background).ignoresSafeArea())
            }
        }

        \(previewBlocks)

        private struct StatefulPreviewContainer<Value, Content: View>: View {
            @State private var state: Value
            private let content: (Binding<Value>) -> Content

            init(_ initialState: Value, content: @escaping (Binding<Value>) -> Content) {
                _state = SwiftUI.State(initialValue: initialState)
                self.content = content
            }

            var body: some View {
                content($state)
            }
        }
        """
    }

    private func renderSwiftNode(_ node: ScreenNode, indent: Int) -> String {
        let prefix = String(repeating: "    ", count: indent)
        switch node.kind {
        case "vstack":
            let spacing = node.spacing.map(swiftTokenReference) ?? "0"
            let children = (node.children ?? []).map { renderSwiftNode($0, indent: indent + 1) }.joined(separator: "\n")
            return """
        \(prefix)VStack(alignment: .leading, spacing: \(spacing)) {
        \(children)
        \(prefix)}
        """
        case "hstack":
            let spacing = node.spacing.map(swiftTokenReference) ?? "0"
            let children = (node.children ?? []).map { renderSwiftNode($0, indent: indent + 1) }.joined(separator: "\n")
            return """
        \(prefix)HStack(spacing: \(spacing)) {
        \(children)
        \(prefix)}
        """
        case "card":
            let spacing = node.spacing.map(swiftTokenReference) ?? "0"
            let children = (node.children ?? []).map { renderSwiftNode($0, indent: indent + 1) }.joined(separator: "\n")
            return """
        \(prefix)VStack(alignment: .leading, spacing: \(spacing)) {
        \(children)
        \(prefix)}
        \(prefix).padding(DesignTokens.space4)
        \(prefix).background(DesignTokens.colorSurfaceSecondary)
        \(prefix).clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusCard))
        """
        case "text":
            return """
        \(prefix)Text("\(escapeSwift(node.text ?? ""))")
        \(prefix)\(swiftTextModifiers(for: node.role))
        """
        case "textField":
            return renderSwiftField(
                base: "TextField(\"\(escapeSwift(node.label ?? ""))\", text: $state.\(swiftFieldReference(for: node)))",
                node: node,
                prefix: prefix
            )
        case "secureField":
            return renderSwiftField(
                base: "SecureField(\"\(escapeSwift(node.label ?? ""))\", text: $state.\(swiftFieldReference(for: node)))",
                node: node,
                prefix: prefix
            )
        case "button":
            let target = node.navigation.map(swiftMemberName)
            let handler = target.map { "navigation.\($0)" } ?? "actions.\(swiftActionReference(for: node))"
            return """
        \(prefix)Button("\(escapeSwift(node.title ?? ""))", action: \(handler))
        \(prefix)\(swiftButtonModifier(for: node.variant))
        """
        case "divider":
            return "\(prefix)Divider()"
        case "spacer":
            return "\(prefix)Spacer(minLength: \(node.spacing.map(swiftTokenReference) ?? "0"))"
        case "image":
            return """
        \(prefix)Image("\(escapeSwift(node.assetName ?? ""))")
        \(prefix)    .resizable()
        \(prefix)    .scaledToFit()
        """
        case "icon":
            return """
        \(prefix)Image(systemName: "\(escapeSwift(node.assetName ?? ""))")
        \(prefix)    .imageScale(.large)
        \(prefix)    .foregroundStyle(.secondary)
        """
        default:
            return "\(prefix)Text(\"Unsupported: \(escapeSwift(node.kind))\")"
        }
    }

    private func renderComposeScreen(_ spec: ScreenSpec) -> String {
        let screenName = screenTypeName(from: spec.screenId)
        let declaredFields = stateFields(for: spec)
        let declaredInputBindings = inputBindings(for: spec)
        let declaredActions = actions(for: spec)
        let declaredNavigation = navigationDestinations(for: spec)
        let body = renderComposeNode(spec.root, indent: 1)
        let padding = composeDimensionReference(spec.surface.padding)
        let background = composeColorReference(spec.surface.backgroundColor)
        let imports = composeImportBlock(for: spec)
        let stateName = "\(screenName)State"
        let actionsName = "\(screenName)Actions"
        let navigationName = "\(screenName)Navigation"
        let stateMembers = declaredFields.isEmpty
            ? "data class \(stateName)(val unused: Unit = Unit)\n"
            : """
        data class \(stateName)(
        \(declaredFields.map(renderComposeStateField).joined(separator: ",\n"))
        )
        """
        let actionMembers = (declaredInputBindings.map { binding in
            "    val on\(pascalCase(from: binding))Changed: (String) -> Unit = {}"
        } + declaredActions.map { action in
            "    val on\(pascalCase(from: action.id)): () -> Unit = {}"
        })
        let actionsBlock = actionMembers.isEmpty
            ? "data class \(actionsName)(val unused: Unit = Unit)\n"
            : """
        data class \(actionsName)(
        \(actionMembers.joined(separator: ",\n"))
        )
        """
        let navigationMembers = declaredNavigation.map { destination in
            "    val on\(pascalCase(from: destination.id)): () -> Unit = {}"
        }
        let navigationBlock = navigationMembers.isEmpty
            ? ""
            : """

        data class \(navigationName)(
        \(navigationMembers.joined(separator: ",\n"))
        )
        """
        let navigationParameter = navigationMembers.isEmpty ? "" : ",\n    navigation: \(navigationName) = \(navigationName)()"
        let previewBlocks = renderComposePreviewBlocks(
            spec: spec,
            screenName: screenName,
            stateName: stateName,
            actionsName: actionsName,
            navigationName: navigationMembers.isEmpty ? nil : navigationName,
            declaredFields: declaredFields
        )

        return """
        \(imports)

        \(stateMembers)
        \(actionsBlock)
        \(navigationBlock)

        @Composable
        fun \(screenName)(
            state: \(stateName) = \(stateName)(),
            actions: \(actionsName) = \(actionsName)()\(navigationParameter)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(\(background))
                    .padding(\(padding))
            ) {
        \(body)
            }
        }

        \(previewBlocks)
        """
    }

    private func renderComposeNode(_ node: ScreenNode, indent: Int) -> String {
        let prefix = String(repeating: "    ", count: indent)
        switch node.kind {
        case "vstack":
            let spacing = node.spacing.map(composeDimensionReference) ?? "0.dp"
            let children = (node.children ?? []).map { renderComposeNode($0, indent: indent + 1) }.joined(separator: "\n")
            return """
        \(prefix)Column(verticalArrangement = Arrangement.spacedBy(\(spacing))) {
        \(children)
        \(prefix)}
        """
        case "hstack":
            let spacing = node.spacing.map(composeDimensionReference) ?? "0.dp"
            let children = (node.children ?? []).map { renderComposeNode($0, indent: indent + 1) }.joined(separator: "\n")
            return """
        \(prefix)Row(horizontalArrangement = Arrangement.spacedBy(\(spacing))) {
        \(children)
        \(prefix)}
        """
        case "card":
            let children = (node.children ?? []).map { renderComposeNode($0, indent: indent + 2) }.joined(separator: "\n")
            return """
        \(prefix)Card(
        \(prefix)    colors = CardDefaults.cardColors(containerColor = DesignTokens.colorSurfaceSecondary),
        \(prefix)    shape = RoundedCornerShape(DesignTokens.radiusCard),
        \(prefix)    modifier = Modifier.fillMaxWidth()
        \(prefix)) {
        \(prefix)    Column(
        \(prefix)        modifier = Modifier.padding(DesignTokens.space4),
        \(prefix)        verticalArrangement = Arrangement.spacedBy(\(node.spacing.map(composeDimensionReference) ?? "0.dp"))
        \(prefix)    ) {
        \(children)
        \(prefix)    }
        \(prefix)}
        """
        case "text":
            return "\(prefix)Text(text = \"\(escapeKotlin(node.text ?? ""))\", style = \(composeTextStyle(for: node.role)))"
        case "textField":
            return renderComposeField(node: node, prefix: prefix, secure: false)
        case "secureField":
            return renderComposeField(node: node, prefix: prefix, secure: true)
        case "button":
            let onClick = node.navigation.map { "navigation.on\(pascalCase(from: $0))" } ?? "actions.on\(pascalCase(from: node.action ?? node.title ?? "tap"))"
            if node.variant == "secondary" {
                return "\(prefix)OutlinedButton(onClick = \(onClick)) { Text(\"\(escapeKotlin(node.title ?? ""))\") }"
            }
            return "\(prefix)Button(onClick = \(onClick)) { Text(\"\(escapeKotlin(node.title ?? ""))\") }"
        case "divider":
            return "\(prefix)HorizontalDivider()"
        case "spacer":
            return "\(prefix)Spacer(modifier = Modifier.height(\(node.spacing.map(composeDimensionReference) ?? "0.dp")))"
        case "image":
            return "\(prefix)Image(painter = painterResource(id = \(composeDrawableReference(for: node.assetName ?? ""))), contentDescription = \"\(escapeKotlin(node.assetName ?? ""))\", contentScale = ContentScale.Fit)"
        case "icon":
            return "\(prefix)Icon(painter = painterResource(id = \(composeDrawableReference(for: node.assetName ?? ""))), contentDescription = null)"
        default:
            return "\(prefix)Text(text = \"Unsupported: \(escapeKotlin(node.kind))\")"
        }
    }

    private func htmlInputType(for node: ScreenNode) -> String {
        if node.kind == "secureField" {
            return "password"
        }

        switch node.inputType ?? "text" {
        case "email":
            return "email"
        case "number":
            return "number"
        default:
            return "text"
        }
    }

    private func renderSwiftField(base: String, node: ScreenNode, prefix: String) -> String {
        ([ "\(prefix)\(base)" ] + swiftFieldModifierLines(for: node, prefix: prefix)).joined(separator: "\n")
    }

    private func swiftFieldModifierLines(for node: ScreenNode, prefix: String) -> [String] {
        let modifiers: [String]

        switch node.kind {
        case "secureField":
            modifiers = [
                ".textContentType(.password)",
                ".textInputAutocapitalization(.never)",
                ".disableAutocorrection(true)"
            ]
        case "textField":
            switch node.inputType ?? "text" {
            case "email":
                modifiers = [
                    ".keyboardType(.emailAddress)",
                    ".textContentType(.emailAddress)",
                    ".textInputAutocapitalization(.never)",
                    ".disableAutocorrection(true)"
                ]
            case "number":
                modifiers = [
                    ".keyboardType(.numberPad)"
                ]
            default:
                modifiers = []
            }
        default:
            modifiers = []
        }

        return modifiers.map { "\(prefix)\($0)" }
    }

    private func renderComposeField(node: ScreenNode, prefix: String, secure: Bool) -> String {
        let keyboardOptions = composeKeyboardOptions(for: node, secure: secure)
        let visualTransformation = secure ? "\(prefix)    visualTransformation = PasswordVisualTransformation()," : nil
        let lines = [
            "\(prefix)OutlinedTextField(",
            "\(prefix)    value = state.\(kotlinFieldReference(for: node)),",
            "\(prefix)    onValueChange = actions.on\(pascalCase(from: fieldBindingReference(for: node)))Changed,",
            "\(prefix)    label = { Text(\"\(escapeKotlin(node.label ?? ""))\") },",
            "\(prefix)    keyboardOptions = \(keyboardOptions),",
            visualTransformation,
            "\(prefix)    singleLine = true",
            "\(prefix))"
        ].compactMap { $0 }
        return lines.joined(separator: "\n")
    }

    private func composeKeyboardOptions(for node: ScreenNode, secure: Bool) -> String {
        if secure {
            return "KeyboardOptions(keyboardType = KeyboardType.Password, autoCorrect = false)"
        }

        switch node.inputType ?? "text" {
        case "email":
            return "KeyboardOptions(keyboardType = KeyboardType.Email, autoCorrect = false)"
        case "number":
            return "KeyboardOptions(keyboardType = KeyboardType.Number)"
        default:
            return "KeyboardOptions.Default"
        }
    }

    private func composeImportBlock(for spec: ScreenSpec) -> String {
        let nodeKinds = collectedNodeKinds(in: spec.root)
        let needsFieldImports = !inputBindings(for: spec).isEmpty
        let needsPainterResource = nodeKinds.contains("image") || nodeKinds.contains("icon")
        let needsImageImports = nodeKinds.contains("image")
        let needsCardImports = nodeKinds.contains("card")
        let needsPasswordImport = nodeKinds.contains("secureField")
        let needsColorImport = TokenStore.path(fromAlias: spec.surface.backgroundColor) == nil && hexColorComponents(from: spec.surface.backgroundColor) != nil
        let needsPreviewImport = !spec.previewStates.isEmpty

        var imports = [
            "import androidx.compose.foundation.background",
            "import androidx.compose.foundation.layout.*",
            "import androidx.compose.material3.*",
            "import androidx.compose.runtime.Composable",
            "import androidx.compose.ui.Modifier"
        ]

        if needsImageImports {
            imports.append("import androidx.compose.foundation.Image")
            imports.append("import androidx.compose.ui.layout.ContentScale")
        }
        if needsCardImports {
            imports.append("import androidx.compose.foundation.shape.RoundedCornerShape")
        }
        if needsFieldImports {
            imports.append("import androidx.compose.foundation.text.KeyboardOptions")
            imports.append("import androidx.compose.ui.text.input.KeyboardType")
        }
        if needsPainterResource {
            imports.append("import androidx.compose.ui.res.painterResource")
        }
        if needsPasswordImport {
            imports.append("import androidx.compose.ui.text.input.PasswordVisualTransformation")
        }
        if needsColorImport {
            imports.append("import androidx.compose.ui.graphics.Color")
        }
        if needsPreviewImport {
            imports.append("import androidx.compose.ui.tooling.preview.Preview")
        }

        return imports.sorted().joined(separator: "\n")
    }

    private func cssReference(for alias: String) -> String {
        if let path = TokenStore.path(fromAlias: alias) {
            return "var(--\(cssVariableName(for: path)))"
        }
        return alias
    }

    private func cssValue(for token: ResolvedToken) -> String {
        switch token.type {
        case "dimension":
            return "\(token.value)px"
        default:
            return token.value
        }
    }

    private func screenTypeName(from screenID: String) -> String {
        pascalCase(from: screenID) + "Screen"
    }

    private func cssVariableName(for path: String) -> String {
        path.replacingOccurrences(of: ".", with: "-")
    }

    private func swiftIdentifier(for path: String) -> String {
        let parts = path.split(separator: ".").map(String.init)
        guard let first = parts.first else {
            return "value"
        }
        return first + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    private func swiftMemberName(from raw: String) -> String {
        let normalized = identifierParts(from: raw)
        guard let first = normalized.first else {
            return "value"
        }
        return first.lowercased() + normalized.dropFirst().map(capitalized).joined()
    }

    private func kotlinMemberName(from raw: String) -> String {
        swiftMemberName(from: raw)
    }

    private func pascalCase(from raw: String) -> String {
        let normalized = identifierParts(from: raw)
        guard !normalized.isEmpty else {
            return "Value"
        }
        return normalized.map(capitalized).joined()
    }

    private func capitalized(_ part: String) -> String {
        guard let first = part.first else {
            return part
        }
        return first.uppercased() + part.dropFirst()
    }

    private func identifierParts(from raw: String) -> [String] {
        var parts: [String] = []
        var current = ""

        for character in raw {
            if !character.isLetter && !character.isNumber {
                if !current.isEmpty {
                    parts.append(current)
                    current = ""
                }
                continue
            }

            if let last = current.last,
               last.isLowercase,
               character.isUppercase {
                parts.append(current)
                current = String(character)
                continue
            }

            current.append(character)
        }

        if !current.isEmpty {
            parts.append(current)
        }

        return parts
    }

    private func swiftFieldReference(for node: ScreenNode) -> String {
        swiftMemberName(from: fieldBindingReference(for: node))
    }

    private func kotlinFieldReference(for node: ScreenNode) -> String {
        kotlinMemberName(from: fieldBindingReference(for: node))
    }

    private func swiftActionReference(for node: ScreenNode) -> String {
        swiftMemberName(from: node.action ?? node.title ?? "tap")
    }

    private func composeDrawableReference(for assetName: String) -> String {
        let lastPathComponent = URL(fileURLWithPath: assetName).lastPathComponent
        let lowercase = lastPathComponent.lowercased()
        let knownExtensions = [".png", ".jpg", ".jpeg", ".webp", ".svg", ".pdf"]
        let basename = knownExtensions.first(where: { lowercase.hasSuffix($0) }).map {
            String(lastPathComponent.dropLast($0.count))
        } ?? lastPathComponent
        let normalized = basename.lowercased().map { character -> Character in
            (character.isLetter || character.isNumber) ? character : "_"
        }
        return "R.drawable.\(String(normalized))"
    }

    private func swiftTextModifiers(for role: String?) -> String {
        switch role ?? "body" {
        case "title":
            return ".font(.title).fontWeight(.semibold)"
        case "caption":
            return ".font(.caption).foregroundStyle(.secondary)"
        case "label":
            return ".font(.caption).fontWeight(.medium).foregroundStyle(.secondary)"
        default:
            return ".font(.body)"
        }
    }

    private func swiftButtonModifier(for variant: String?) -> String {
        switch variant ?? "primary" {
        case "secondary":
            return ".buttonStyle(.bordered)"
        default:
            return ".buttonStyle(.borderedProminent)"
        }
    }

    private func composeTextStyle(for role: String?) -> String {
        switch role ?? "body" {
        case "title":
            return "MaterialTheme.typography.titleLarge"
        case "caption":
            return "MaterialTheme.typography.bodySmall"
        case "label":
            return "MaterialTheme.typography.labelMedium"
        default:
            return "MaterialTheme.typography.bodyLarge"
        }
    }

    private func collectedFields(in node: ScreenNode) -> [ScreenNode] {
        let local = (node.kind == "textField" || node.kind == "secureField") ? [node] : []
        let descendants = (node.children ?? []).flatMap(collectedFields)
        var seen: Set<String> = []
        return (local + descendants).filter { field in
            let key = fieldBindingReference(for: field)
            return seen.insert(key).inserted
        }
    }

    private func collectedActions(in node: ScreenNode) -> [String] {
        let local = node.kind == "button" ? [node.action].compactMap { $0 } : []
        let descendants = (node.children ?? []).flatMap(collectedActions)
        var seen: Set<String> = []
        return (local + descendants).filter { action in
            let key = swiftMemberName(from: action)
            return seen.insert(key).inserted
        }
    }

    private func stateFields(for spec: ScreenSpec) -> [ScreenStateField] {
        if !spec.stateFields.isEmpty {
            return spec.stateFields
        }

        return collectedFields(in: spec.root).map {
            ScreenStateField(id: fieldBindingReference(for: $0), type: .string, defaultValue: .string(""))
        }
    }

    private func actions(for spec: ScreenSpec) -> [ScreenAction] {
        if !spec.actions.isEmpty {
            return spec.actions
        }

        return collectedActions(in: spec.root).map { ScreenAction(id: $0) }
    }

    private func resolvedPreviewStates(for spec: ScreenSpec) -> [ScreenPreviewState] {
        if !spec.previewStates.isEmpty {
            return spec.previewStates
        }

        return [ScreenPreviewState(id: "default")]
    }

    private func navigationDestinations(for spec: ScreenSpec) -> [ScreenNavigationDestination] {
        spec.navigation
    }

    private func inputBindings(for spec: ScreenSpec) -> [String] {
        collectedFields(in: spec.root).map(fieldBindingReference)
    }

    private func htmlValueAttribute(for node: ScreenNode, spec: ScreenSpec, previewState: ScreenPreviewState?) -> String {
        guard
            let previewState,
            let value = previewStateFieldValue(for: fieldBindingReference(for: node), spec: spec, previewState: previewState),
            !value.isEmpty
        else {
            return ""
        }

        return " value=\"\(escape(value))\""
    }

    private func renderSwiftPreviewBlocks(
        spec: ScreenSpec,
        stateName: String,
        screenName: String,
        actionsName: String,
        navigationName: String?,
        declaredFields: [ScreenStateField]
    ) -> String {
        resolvedPreviewStates(for: spec).map { previewState in
            let navigationArgument = navigationName.map { ", navigation: \($0)()" } ?? ""
            return """
            #Preview("\(escapeSwift(previewState.id))") {
                StatefulPreviewContainer(\(swiftPreviewStateLiteral(previewState, stateName: stateName, declaredFields: declaredFields))) { state in
                    \(screenName)(state: state, actions: \(actionsName)()\(navigationArgument))
                }
            }
            """
        }.joined(separator: "\n\n")
    }

    private func renderComposePreviewBlocks(
        spec: ScreenSpec,
        screenName: String,
        stateName: String,
        actionsName: String,
        navigationName: String?,
        declaredFields: [ScreenStateField]
    ) -> String {
        guard !spec.previewStates.isEmpty else {
            return ""
        }

        return spec.previewStates.map { previewState in
            let previewName = "\(screenName)\(pascalCase(from: previewState.id))Preview"
            let navigationArgument = navigationName.map { ",\n        navigation = \($0)()" } ?? ""
            return """
            @Preview(name = "\(escapeKotlin(previewState.id))")
            @Composable
            private fun \(previewName)() {
                \(screenName)(
                    state = \(kotlinPreviewStateLiteral(previewState, stateName: stateName, declaredFields: declaredFields)),
                    actions = \(actionsName)()\(navigationArgument)
                )
            }
            """
        }.joined(separator: "\n\n")
    }

    private func renderSwiftStateField(_ field: ScreenStateField) -> String {
        "    var \(swiftMemberName(from: field.id)): \(swiftTypeName(for: field.type)) = \(swiftLiteral(for: field))"
    }

    private func renderComposeStateField(_ field: ScreenStateField) -> String {
        "    val \(kotlinMemberName(from: field.id)): \(kotlinTypeName(for: field.type)) = \(kotlinLiteral(for: field))"
    }

    private func fieldBindingReference(for node: ScreenNode) -> String {
        node.binding ?? node.id ?? node.label ?? "field"
    }

    private func navigationDestination(for node: ScreenNode, spec: ScreenSpec) -> ScreenNavigationDestination? {
        guard let navigationID = node.navigation else {
            return nil
        }

        return navigationDestinations(for: spec).first { $0.id == navigationID }
    }

    private func previewStateFieldValue(for fieldID: String, spec: ScreenSpec, previewState: ScreenPreviewState) -> String? {
        if let explicitValue = previewState.values[fieldID]?.stringValue {
            return explicitValue
        }

        guard let field = stateFields(for: spec).first(where: { $0.id == fieldID }) else {
            return nil
        }

        return field.defaultValue?.stringValue
    }

    private func swiftPreviewStateLiteral(_ previewState: ScreenPreviewState, stateName: String, declaredFields: [ScreenStateField]) -> String {
        guard !declaredFields.isEmpty else {
            return "\(stateName)()"
        }

        let arguments = declaredFields.map { field in
            "\(swiftMemberName(from: field.id)): \(swiftLiteral(for: resolvedPreviewValue(for: field, previewState: previewState), type: field.type))"
        }.joined(separator: ", ")
        return "\(stateName)(\(arguments))"
    }

    private func kotlinPreviewStateLiteral(_ previewState: ScreenPreviewState, stateName: String, declaredFields: [ScreenStateField]) -> String {
        guard !declaredFields.isEmpty else {
            return "\(stateName)()"
        }

        let arguments = declaredFields.map { field in
            "\(kotlinMemberName(from: field.id)) = \(kotlinLiteral(for: resolvedPreviewValue(for: field, previewState: previewState), type: field.type))"
        }.joined(separator: ", ")
        return "\(stateName)(\(arguments))"
    }

    private func resolvedPreviewValue(for field: ScreenStateField, previewState: ScreenPreviewState) -> JSONValue {
        previewState.values[field.id] ?? field.defaultValue ?? defaultValue(for: field.type)
    }

    private func swiftTypeName(for type: ScreenStateFieldType) -> String {
        switch type {
        case .string:
            return "String"
        case .boolean:
            return "Bool"
        case .integer:
            return "Int"
        case .number:
            return "Double"
        }
    }

    private func kotlinTypeName(for type: ScreenStateFieldType) -> String {
        switch type {
        case .string:
            return "String"
        case .boolean:
            return "Boolean"
        case .integer:
            return "Int"
        case .number:
            return "Double"
        }
    }

    private func swiftLiteral(for field: ScreenStateField) -> String {
        swiftLiteral(for: field.defaultValue ?? defaultValue(for: field.type), type: field.type)
    }

    private func swiftLiteral(for value: JSONValue, type: ScreenStateFieldType) -> String {
        switch (type, value) {
        case (.string, .string(let raw)):
            return "\"\(escapeSwift(raw))\""
        case (.boolean, .bool(let raw)):
            return raw ? "true" : "false"
        case (.integer, .integer(let raw)):
            return String(raw)
        case (.number, .double(let raw)):
            return doubleLiteral(raw)
        case (.number, .integer(let raw)):
            return doubleLiteral(Double(raw))
        default:
            return swiftLiteral(for: defaultValue(for: type), type: type)
        }
    }

    private func kotlinLiteral(for field: ScreenStateField) -> String {
        kotlinLiteral(for: field.defaultValue ?? defaultValue(for: field.type), type: field.type)
    }

    private func kotlinLiteral(for value: JSONValue, type: ScreenStateFieldType) -> String {
        switch (type, value) {
        case (.string, .string(let raw)):
            return "\"\(escapeKotlin(raw))\""
        case (.boolean, .bool(let raw)):
            return raw ? "true" : "false"
        case (.integer, .integer(let raw)):
            return String(raw)
        case (.number, .double(let raw)):
            return doubleLiteral(raw)
        case (.number, .integer(let raw)):
            return doubleLiteral(Double(raw))
        default:
            return kotlinLiteral(for: defaultValue(for: type), type: type)
        }
    }

    private func defaultValue(for type: ScreenStateFieldType) -> JSONValue {
        switch type {
        case .string:
            return .string("")
        case .boolean:
            return .bool(false)
        case .integer:
            return .integer(0)
        case .number:
            return .double(0)
        }
    }

    private func doubleLiteral(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value)).0"
        }
        return String(value)
    }

    private func collectedNodeKinds(in node: ScreenNode) -> Set<String> {
        var kinds: Set<String> = [node.kind]
        for child in node.children ?? [] {
            kinds.formUnion(collectedNodeKinds(in: child))
        }
        return kinds
    }

    private func swiftTokenReference(_ alias: String) -> String {
        guard let path = TokenStore.path(fromAlias: alias) else {
            return alias
        }
        return "DesignTokens.\(swiftIdentifier(for: path))"
    }

    private func swiftDimensionReference(_ alias: String) -> String {
        if let path = TokenStore.path(fromAlias: alias) {
            return "DesignTokens.\(swiftIdentifier(for: path))"
        }
        if Double(alias) != nil {
            return alias
        }
        return "0"
    }

    private func swiftColorReference(_ alias: String) -> String {
        if let path = TokenStore.path(fromAlias: alias) {
            return "DesignTokens.\(swiftIdentifier(for: path))"
        }
        if hexColorComponents(from: alias) != nil {
            return swiftColorLiteral(alias)
        }
        return "Color.clear"
    }

    private func composeDimensionReference(_ alias: String) -> String {
        if let path = TokenStore.path(fromAlias: alias) {
            return "DesignTokens.\(swiftIdentifier(for: path))"
        }
        if Double(alias) != nil {
            return "\(alias).dp"
        }
        return "0.dp"
    }

    private func composeColorReference(_ alias: String) -> String {
        if let path = TokenStore.path(fromAlias: alias) {
            return "DesignTokens.\(swiftIdentifier(for: path))"
        }
        if hexColorComponents(from: alias) != nil {
            return composeColorLiteral(alias)
        }
        return "Color.Unspecified"
    }

    private func swiftColorLiteral(_ hex: String) -> String {
        guard let components = hexColorComponents(from: hex) else {
            return "Color.clear"
        }
        return "Color(.sRGB, red: \(components.red), green: \(components.green), blue: \(components.blue), opacity: \(components.alpha))"
    }

    private func composeColorLiteral(_ hex: String) -> String {
        guard let components = hexColorComponents(from: hex) else {
            return "Color.Unspecified"
        }
        return String(
            format: "Color(0x%02X%02X%02X%02X)",
            components.alphaInt,
            components.redInt,
            components.greenInt,
            components.blueInt
        )
    }

    private func hexColorComponents(from raw: String) -> (red: String, green: String, blue: String, alpha: String, redInt: Int, greenInt: Int, blueInt: Int, alphaInt: Int)? {
        let hex = raw.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let expanded: String

        switch hex.count {
        case 6, 8:
            expanded = hex
        case 3, 4:
            expanded = hex.map { "\($0)\($0)" }.joined()
        default:
            return nil
        }

        guard let value = UInt64(expanded, radix: 16) else {
            return nil
        }

        let redInt: Int
        let greenInt: Int
        let blueInt: Int
        let alphaInt: Int

        if expanded.count == 8 {
            alphaInt = Int((value >> 24) & 0xFF)
            redInt = Int((value >> 16) & 0xFF)
            greenInt = Int((value >> 8) & 0xFF)
            blueInt = Int(value & 0xFF)
        } else {
            alphaInt = 255
            redInt = Int((value >> 16) & 0xFF)
            greenInt = Int((value >> 8) & 0xFF)
            blueInt = Int(value & 0xFF)
        }

        func fraction(_ component: Int) -> String {
            let value = Double(component) / 255.0
            let rounded = (value * 10000).rounded() / 10000
            return String(format: "%.4f", rounded)
        }

        return (
            red: fraction(redInt),
            green: fraction(greenInt),
            blue: fraction(blueInt),
            alpha: fraction(alphaInt),
            redInt: redInt,
            greenInt: greenInt,
            blueInt: blueInt,
            alphaInt: alphaInt
        )
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func escapeSwift(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func escapeKotlin(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func configuredEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
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
