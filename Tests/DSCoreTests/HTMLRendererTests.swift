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
        let reviewPath = outputDirectory.appendingPathComponent("report.review.json")
        let html = try String(contentsOf: htmlPath, encoding: .utf8)
        let review = try JSONDecoder().decode(ReviewDocument.self, from: Data(contentsOf: reviewPath))

        #expect(report.ok)
        #expect(FileManager.default.fileExists(atPath: htmlPath.path))
        #expect(FileManager.default.fileExists(atPath: reviewPath.path))
        #expect(html.contains("data-preview-state=\"loading\""))
        #expect(html.contains("Review Checklist"))
        #expect(html.contains("Pay now"))
        #expect(review.screenId == "payment")
        #expect(review.previewStates == ["default", "loading", "error"])
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
}

private struct ReviewDocument: Decodable {
    let screenId: String
    let previewStates: [String]
}
