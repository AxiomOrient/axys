import DSCore
import Foundation
import Testing

@Suite("Contract HTML renderer")
struct HTMLRendererTests {
    private let service = ProjectService()

    @Test("contract screen renders an HTML review bundle with preview states and review report")
    func renderHTML() throws {
        let root = repositoryRoot()
        let outputDirectory = try makeTemporaryDirectory().appendingPathComponent("payment-review", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory.deletingLastPathComponent()) }

        let report = try service.renderHTML(
            screenPath: root.appendingPathComponent("contracts/screens/checkout-payment.screen.yaml"),
            outputDirectory: outputDirectory
        )

        let htmlPath = outputDirectory.appendingPathComponent("html/payment.html")
        let shellPath = outputDirectory.appendingPathComponent("index.html")
        let reviewPath = outputDirectory.appendingPathComponent("report.review.json")
        let html = try String(contentsOf: htmlPath, encoding: .utf8)
        let shell = try String(contentsOf: shellPath, encoding: .utf8)
        let review = try JSONDecoder().decode(ReviewDocument.self, from: Data(contentsOf: reviewPath))

        #expect(report.ok)
        #expect(report.entrypointPath == shellPath.path)
        #expect(FileManager.default.fileExists(atPath: htmlPath.path))
        #expect(FileManager.default.fileExists(atPath: shellPath.path))
        #expect(FileManager.default.fileExists(atPath: reviewPath.path))
        #expect(html.contains("data-preview-state=\"loading\""))
        #expect(shell.contains("shell/review.js"))
        #expect(shell.contains("html/payment.html"))
        #expect(html.contains("Pay now"))
        #expect(review.screenId == "payment")
        #expect(review.previewStates == ["default", "loading", "error"])
    }

    @Test("review metadata uses the same implicit default preview state resolution as screen rendering")
    func resolvedReviewPreviewStatesDefault() {
        let screen = makeScreenWithEmptyPreviewStates(targets: [.html])

        #expect(resolvedPreviewStateIDsForRendering(screen) == ["default"])
    }

    @Test("shell payload encoding keeps raw review text out of the shell document")
    func renderHTMLEscapesShellReviewPayload() throws {
        let fixture = try makeFixtureWithScriptLikeReviewText()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let outputDirectory = fixture.root.appendingPathComponent("build/html/payment-review", isDirectory: true)
        let report = try service.renderHTML(
            screenPath: fixture.screenURL,
            outputDirectory: outputDirectory
        )

        let shellPath = outputDirectory.appendingPathComponent("index.html")
        let shell = try String(contentsOf: shellPath, encoding: .utf8)

        #expect(report.ok)
        #expect(shell.contains("data-review-payload=\""))
        #expect(!shell.contains("<script id=\"review-data\""))
        #expect(!shell.contains("</script><p>broken</p>"))
    }

    @Test("renderer falls back to built-in shell assets when source shell assets are missing")
    func renderHTMLUsesBuiltInShellFallback() throws {
        let fixture = try makeFixtureWithoutPreviewShellAssets()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let outputDirectory = fixture.root.appendingPathComponent("build/html/payment-review", isDirectory: true)
        let report = try service.renderHTML(
            screenPath: fixture.screenURL,
            outputDirectory: outputDirectory
        )

        let shellPath = outputDirectory.appendingPathComponent("index.html")
        let shellCSSPath = outputDirectory.appendingPathComponent("shell/review.css")
        let shellJSPath = outputDirectory.appendingPathComponent("shell/review.js")
        let shell = try String(contentsOf: shellPath, encoding: .utf8)

        #expect(report.ok)
        #expect(FileManager.default.fileExists(atPath: shellCSSPath.path))
        #expect(FileManager.default.fileExists(atPath: shellJSPath.path))
        #expect(shell.contains("Built-in fallback shell is active"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-contract-html-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeFixtureWithScriptLikeReviewText() throws -> (root: URL, screenURL: URL) {
        let root = try makeTemporaryDirectory()
        let repositoryRoot = repositoryRoot()

        try "# Fixture root\n".write(
            to: root.appendingPathComponent("MASTER_BLUEPRINT.md"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.copyItem(
            at: repositoryRoot.appendingPathComponent("contracts", isDirectory: true),
            to: root.appendingPathComponent("contracts", isDirectory: true)
        )

        let screenURL = root.appendingPathComponent("contracts/screens/checkout-payment.screen.yaml")
        let original = try String(contentsOf: screenURL, encoding: .utf8)
        let updated = original
            .replacingOccurrences(of: "title: Payment", with: "title: \"</script><p>broken</p>\"")
            .replacingOccurrences(of: "intent: Capture card details and confirm payment before returning to order review.", with: "intent: \"</script><p>broken</p>\"")
        try updated.write(to: screenURL, atomically: true, encoding: .utf8)

        return (root, screenURL)
    }

    private func makeFixtureWithoutPreviewShellAssets() throws -> (root: URL, screenURL: URL) {
        let root = try makeTemporaryDirectory()
        let repositoryRoot = repositoryRoot()

        try "# Fixture root\n".write(
            to: root.appendingPathComponent("MASTER_BLUEPRINT.md"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.copyItem(
            at: repositoryRoot.appendingPathComponent("contracts", isDirectory: true),
            to: root.appendingPathComponent("contracts", isDirectory: true)
        )

        return (
            root,
            root.appendingPathComponent("contracts/screens/checkout-payment.screen.yaml")
        )
    }
}

private struct ReviewDocument: Decodable {
    let screenId: String
    let previewStates: [String]
}
