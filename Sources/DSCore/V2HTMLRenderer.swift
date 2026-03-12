import Foundation

struct V2HTMLReviewDocument: Codable {
    let appId: String
    let flowId: String
    let screenId: String
    let title: String
    let route: String
    let previewStates: [String]
    let reviewChecklist: [String]
    let motionPatterns: [String]
    let sourcePaths: [String: String]
}

struct V2HTMLRenderer {
    init() {}

    func render(
        context: V2ResolvedScreenContext,
        tokens: TokenStore,
        outputDirectory: URL
    ) throws -> V2RenderHTMLReport {
        let fileManager = FileManager.default
        let htmlDirectory = outputDirectory.appendingPathComponent("html", isDirectory: true)
        try fileManager.createDirectory(at: htmlDirectory, withIntermediateDirectories: true)

        let htmlName = "\(context.screenSpec.screenId).html"
        let htmlURL = htmlDirectory.appendingPathComponent(htmlName)
        let indexURL = htmlDirectory.appendingPathComponent("index.html")
        let cssURL = htmlDirectory.appendingPathComponent("tokens.css")
        let reviewURL = outputDirectory.appendingPathComponent("report.review.json")

        try write(renderHTML(context: context), to: htmlURL)
        try write(renderIndex(htmlName: htmlName, screenId: context.screenSpec.screenId), to: indexURL)
        try write(renderTokensCSS(tokens: tokens), to: cssURL)

        let review = V2HTMLReviewDocument(
            appId: context.appSpec.appId,
            flowId: context.flowSpec.flowId,
            screenId: context.screenSpec.screenId,
            title: context.screenSpec.title,
            route: context.screenSpec.route,
            previewStates: context.screenSpec.previewStates.map(\.id),
            reviewChecklist: context.screenSpec.reviewChecklist,
            motionPatterns: context.screenSpec.motion.map(\.patternId),
            sourcePaths: [
                "app": context.appURL.path,
                "flow": context.flowURL.path,
                "screen": context.screenURL.path,
                "registry": context.registryURL.path,
                "motion": context.motionURL.path,
                "review": context.reviewURL.path,
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(review).write(to: reviewURL)

        return V2RenderHTMLReport(
            ok: true,
            screenId: context.screenSpec.screenId,
            outputDirectory: outputDirectory.path,
            artifacts: [
                .init(kind: "html_screen", path: htmlURL.path),
                .init(kind: "html_index", path: indexURL.path),
                .init(kind: "html_tokens", path: cssURL.path),
                .init(kind: "review_report", path: reviewURL.path),
            ],
            reviewReportPath: reviewURL.path
        )
    }

    private func write(_ text: String, to url: URL) throws {
        guard let data = text.data(using: .utf8) else {
            throw ProjectError.io("Unable to encode text at \(url.path)")
        }
        try data.write(to: url)
    }

    private func renderIndex(htmlName: String, screenId: String) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta http-equiv="refresh" content="0; url=\(htmlName)" />
          <title>\(escape(screenId)) review</title>
        </head>
        <body>
          <p>Redirecting to <a href="\(htmlName)">\(escape(screenId))</a>…</p>
        </body>
        </html>
        """
    }

    private func renderTokensCSS(tokens: TokenStore) -> String {
        let variables = tokens.tokens.map { token in
            "  --\(cssVariableName(for: token.path)): \(cssValue(for: token));"
        }.joined(separator: "\n")

        return """
        :root {
        \(variables)
        }

        * { box-sizing: border-box; }

        body {
          margin: 0;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          background: var(--color-surface-primary, #ffffff);
          color: var(--color-text-primary, #111111);
        }

        .review-shell {
          display: flex;
          flex-direction: column;
          gap: 24px;
          padding: 24px;
        }

        .review-header {
          display: flex;
          flex-direction: column;
          gap: 10px;
        }

        .review-kicker {
          margin: 0;
          color: var(--color-text-secondary, #666666);
          text-transform: uppercase;
          letter-spacing: 0.08em;
          font-size: 12px;
        }

        .review-title {
          margin: 0;
          font-size: 30px;
          line-height: 1.1;
        }

        .review-meta {
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
        }

        .chip {
          display: inline-flex;
          align-items: center;
          padding: 6px 10px;
          border-radius: 999px;
          background: var(--color-surface-secondary, #f6f6f6);
          color: var(--color-text-secondary, #666666);
          font-size: 12px;
        }

        .review-grid {
          display: grid;
          grid-template-columns: minmax(0, 2fr) minmax(260px, 1fr);
          gap: 24px;
          align-items: start;
        }

        .review-panel {
          display: flex;
          flex-direction: column;
          gap: 16px;
        }

        .review-card {
          background: var(--color-surface-secondary, #f6f6f6);
          border-radius: 20px;
          padding: 16px;
          display: flex;
          flex-direction: column;
          gap: 12px;
        }

        .review-section-title {
          margin: 0;
          font-size: 14px;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: var(--color-text-secondary, #666666);
        }

        .review-list {
          margin: 0;
          padding-left: 18px;
          display: flex;
          flex-direction: column;
          gap: 8px;
          font-size: 14px;
        }

        .preview-stack {
          display: flex;
          flex-direction: column;
          gap: 24px;
        }

        .preview-state {
          display: flex;
          flex-direction: column;
          gap: 12px;
        }

        .preview-state-name {
          margin: 0;
          font-size: 16px;
          font-weight: 700;
        }

        .preview-state-note {
          margin: 0;
          font-size: 13px;
          color: var(--color-text-secondary, #666666);
        }

        .screen-frame {
          min-height: 640px;
          border-radius: 28px;
          overflow: hidden;
          border: 1px solid rgba(17, 17, 17, 0.08);
          background: var(--color-surface-primary, #ffffff);
        }

        .screen-surface {
          min-height: 640px;
          display: flex;
          flex-direction: column;
        }

        .layout-stack,
        .layout-shell,
        .layout-conditional,
        .layout-repeat {
          display: flex;
          flex-direction: column;
        }

        .layout-grid {
          display: grid;
        }

        .component-box {
          display: flex;
          flex-direction: column;
          gap: 10px;
          background: rgba(255, 255, 255, 0.84);
          border: 1px solid rgba(17, 17, 17, 0.08);
          border-radius: 20px;
          padding: 16px;
        }

        .component-label {
          margin: 0;
          font-size: 12px;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          color: var(--color-text-secondary, #666666);
        }

        .top-app-bar-title {
          margin: 0;
          font-size: 22px;
          font-weight: 700;
        }

        .top-app-bar-subtitle,
        .component-subtle {
          margin: 0;
          font-size: 14px;
          color: var(--color-text-secondary, #666666);
        }

        .summary-total {
          margin: 0;
          font-size: 28px;
          font-weight: 700;
        }

        .field {
          display: flex;
          flex-direction: column;
          gap: 6px;
        }

        .field-label {
          font-size: 13px;
          color: var(--color-text-secondary, #666666);
        }

        .field-input {
          width: 100%;
          border: 1px solid rgba(17, 17, 17, 0.12);
          border-radius: 14px;
          padding: 12px 14px;
          font-size: 15px;
          background: #ffffff;
        }

        .button {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          min-height: 48px;
          padding: 0 18px;
          border-radius: 14px;
          border: 1px solid transparent;
          font-size: 15px;
          font-weight: 600;
        }

        .button-primary {
          background: var(--color-action-primary, #111111);
          color: var(--color-text-on-action, #ffffff);
        }

        .button-secondary {
          background: transparent;
          border-color: var(--color-action-primary, #111111);
          color: var(--color-action-primary, #111111);
        }

        .generic-props {
          margin: 0;
          display: grid;
          grid-template-columns: max-content 1fr;
          gap: 8px 12px;
          font-size: 14px;
        }

        @media (max-width: 960px) {
          .review-grid {
            grid-template-columns: 1fr;
          }
        }
        """
    }

    private func renderHTML(context: V2ResolvedScreenContext) -> String {
        let previewStates = resolvedPreviewStates(for: context.screenSpec)
        let previewSections = previewStates.map { state in
            renderPreviewState(state, context: context)
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>\(escape(context.screenSpec.title))</title>
          <link rel="stylesheet" href="tokens.css" />
        </head>
        <body>
          <main class="review-shell">
            <header class="review-header">
              <p class="review-kicker">V2 HTML Canonical Review</p>
              <h1 class="review-title">\(escape(context.screenSpec.title))</h1>
              <div class="review-meta">
                <span class="chip">app \(escape(context.appSpec.appId))</span>
                <span class="chip">flow \(escape(context.flowSpec.flowId))</span>
                <span class="chip">screen \(escape(context.screenSpec.screenId))</span>
                <span class="chip">route \(escape(context.screenSpec.route))</span>
              </div>
            </header>
            <section class="review-grid">
              <div class="review-panel">
                <section class="preview-stack">
                  \(previewSections)
                </section>
              </div>
              <aside class="review-panel">
                <section class="review-card">
                  <p class="review-section-title">Intent</p>
                  <p class="component-subtle">\(escape(context.screenSpec.intent ?? "No explicit intent."))</p>
                </section>
                <section class="review-card">
                  <p class="review-section-title">Review Checklist</p>
                  <ul class="review-list">
                    \(context.screenSpec.reviewChecklist.map { "<li>\(escape($0))</li>" }.joined(separator: "\n                    "))
                  </ul>
                </section>
                <section class="review-card">
                  <p class="review-section-title">Motion</p>
                  <ul class="review-list">
                    \(context.screenSpec.motion.isEmpty ? "<li>none</li>" : context.screenSpec.motion.map { "<li>\(escape($0.patternId)) via \(escape($0.trigger))</li>" }.joined(separator: "\n                    "))
                  </ul>
                </section>
              </aside>
            </section>
          </main>
        </body>
        </html>
        """
    }

    private func renderPreviewState(_ previewState: V2PreviewState, context: V2ResolvedScreenContext) -> String {
        let note = previewState.note.map { "<p class=\"preview-state-note\">\(escape($0))</p>" } ?? ""
        let background = cssReference(for: context.screenSpec.surface.backgroundColor)
        let padding = cssReference(for: context.screenSpec.surface.padding, fallback: "24px")
        let body = renderLayoutNode(
            context.screenSpec.layout,
            previewState: previewState,
            context: context
        )

        return """
        <section class="preview-state" data-preview-state="\(escape(previewState.id))">
          <div>
            <p class="preview-state-name">\(escape(previewState.id))</p>
            \(note)
          </div>
          <div class="screen-frame">
            <div class="screen-surface" style="background: \(background); padding: \(padding);">
              \(body)
            </div>
          </div>
        </section>
        """
    }

    private func renderLayoutNode(
        _ node: V2LayoutNode,
        previewState: V2PreviewState,
        context: V2ResolvedScreenContext
    ) -> String {
        switch node.kind {
        case "stack":
            return """
            <section class="layout-stack" style="gap: \(spacingStyle(node.spacing));">
              \(node.children.map { renderLayoutNode($0, previewState: previewState, context: context) }.joined(separator: "\n"))
            </section>
            """
        case "grid":
            return """
            <section class="layout-grid" style="gap: \(spacingStyle(node.spacing)); grid-template-columns: repeat(\(max(node.columns ?? 1, 1)), minmax(0, 1fr));">
              \(node.children.map { renderLayoutNode($0, previewState: previewState, context: context) }.joined(separator: "\n"))
            </section>
            """
        case "slot":
            return """
            <section class="layout-shell" data-slot="\(escape(node.slot ?? ""))" style="gap: \(spacingStyle(node.spacing));">
              \(node.children.map { renderLayoutNode($0, previewState: previewState, context: context) }.joined(separator: "\n"))
            </section>
            """
        case "conditional":
            return """
            <section class="layout-conditional" data-state-guard="\(escape(node.stateGuard ?? ""))" style="gap: \(spacingStyle(node.spacing));">
              \(node.children.map { renderLayoutNode($0, previewState: previewState, context: context) }.joined(separator: "\n"))
            </section>
            """
        case "repeat":
            return """
            <section class="layout-repeat" data-repeat-source="\(escape(node.repeatSource ?? ""))" style="gap: \(spacingStyle(node.spacing));">
              \(node.children.map { renderLayoutNode($0, previewState: previewState, context: context) }.joined(separator: "\n"))
            </section>
            """
        case "component":
            return renderComponentNode(node, previewState: previewState, context: context)
        default:
            return "<section class=\"component-box\"><p class=\"component-label\">Unsupported layout \(escape(node.kind))</p></section>"
        }
    }

    private func renderComponentNode(
        _ node: V2LayoutNode,
        previewState: V2PreviewState,
        context: V2ResolvedScreenContext
    ) -> String {
        guard let componentId = node.componentId,
              let item = context.registry.items.first(where: { $0.id == componentId }) else {
            return "<section class=\"component-box\"><p class=\"component-label\">Unknown component</p></section>"
        }

        switch item.id {
        case "top-app-bar":
            return """
            <section class="component-box">
              <p class="component-label">flow shell / \(escape(item.id))</p>
              <h2 class="top-app-bar-title">\(escape(stringProp("title", in: node.props) ?? ""))</h2>
              <p class="top-app-bar-subtitle">\(escape(stringProp("subtitle", in: node.props) ?? ""))</p>
            </section>
            """
        case "checkout-summary":
            return """
            <section class="component-box">
              <p class="component-label">mobile / \(escape(item.id))</p>
              <p class="component-subtle">\(escape(stringProp("itemCount", in: node.props) ?? "0")) items</p>
              <p class="summary-total">\(escape(stringProp("totalText", in: node.props) ?? ""))</p>
              <p class="component-subtle">\(escape(stringProp("secondaryText", in: node.props) ?? ""))</p>
            </section>
            """
        case "payment-form":
            let fields = node.bindings.map { binding in
                renderField(
                    label: humanize(binding.field),
                    value: previewValue(for: binding.field, previewState: previewState, screen: context.screenSpec) ?? "",
                    inputType: binding.field.lowercased().contains("card") ? "text" : "text"
                )
            }.joined(separator: "\n")
            let submitLabel = escape(stringProp("submitLabel", in: node.props) ?? "Submit")
            return """
            <section class="component-box">
              <p class="component-label">mobile / \(escape(item.id))</p>
              \(fields)
              <button class="button button-primary" type="button">\(submitLabel)</button>
            </section>
            """
        case "text-input":
            let fieldID = node.bindings.first?.field ?? "value"
            return """
            <section class="component-box">
              <p class="component-label">primitive / \(escape(item.id))</p>
              \(renderField(
                  label: stringProp("label", in: node.props) ?? humanize(fieldID),
                  value: previewValue(for: fieldID, previewState: previewState, screen: context.screenSpec) ?? "",
                  inputType: htmlInputType(for: stringProp("keyboard", in: node.props))
              ))
            </section>
            """
        case "button":
            let variant = escape(stringProp("variant", in: node.props) ?? "primary")
            return """
            <section class="component-box">
              <p class="component-label">primitive / \(escape(item.id))</p>
              <button class="button button-\(variant)" type="button">\(escape(stringProp("label", in: node.props) ?? "Button"))</button>
            </section>
            """
        default:
            let props = node.props.keys.sorted().map { key in
                "<dt>\(escape(key))</dt><dd>\(escape(node.props[key]?.stringValue ?? ""))</dd>"
            }.joined(separator: "")
            return """
            <section class="component-box">
              <p class="component-label">\(escape(item.kind)) / \(escape(item.id))</p>
              <dl class="generic-props">\(props)</dl>
            </section>
            """
        }
    }

    private func renderField(label: String, value: String, inputType: String) -> String {
        """
        <label class="field">
          <span class="field-label">\(escape(label))</span>
          <input class="field-input" type="\(escape(inputType))" value="\(escape(value))" />
        </label>
        """
    }

    private func resolvedPreviewStates(for screen: V2ScreenSpec) -> [V2PreviewState] {
        if screen.previewStates.isEmpty {
            return [V2PreviewState(id: "default")]
        }
        return screen.previewStates
    }

    private func previewValue(for fieldID: String, previewState: V2PreviewState, screen: V2ScreenSpec) -> String? {
        if let explicit = previewState.values[fieldID]?.stringValue {
            return explicit
        }
        if let defaultValue = screen.stateFields.first(where: { $0.id == fieldID })?.defaultValue?.stringValue {
            return defaultValue
        }
        return nil
    }

    private func htmlInputType(for keyboard: String?) -> String {
        switch keyboard {
        case "email":
            return "email"
        case "phone":
            return "tel"
        default:
            return "text"
        }
    }

    private func stringProp(_ name: String, in props: [String: JSONValue]) -> String? {
        props[name]?.stringValue
    }

    private func humanize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private func spacingStyle(_ alias: String?) -> String {
        cssReference(for: alias, fallback: "16px")
    }

    private func cssReference(for alias: String?, fallback: String = "#ffffff") -> String {
        guard let alias, let path = TokenStore.path(fromAlias: alias) else {
            return fallback
        }
        return "var(--\(cssVariableName(for: path)), \(fallback))"
    }

    private func cssVariableName(for path: String) -> String {
        path.replacingOccurrences(of: ".", with: "-")
    }

    private func cssValue(for token: ResolvedToken) -> String {
        switch token.type {
        case "dimension":
            return "\(token.value)px"
        default:
            return token.value
        }
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
