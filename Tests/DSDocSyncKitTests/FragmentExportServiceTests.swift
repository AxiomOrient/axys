import DSDocSyncKit
import Foundation
import Testing

@Suite("FragmentExportService")
struct FragmentExportServiceTests {
    @Test("export writes markdown table fragments from a structured JSON spec")
    func exportWritesTableFragments() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let spec = DocFragmentExportSpec(fragments: [
            DocFragment(
                path: "fragments/table.md",
                kind: .markdownTable,
                headers: ["ID", "Value"],
                rows: [["A", "one"], ["B", "two"]]
            ),
        ])
        let specPath = tempDirectory.appendingPathComponent("fragments.json")
        try JSONEncoder().encode(spec).write(to: specPath)

        let report = try DocSyncService().exportFragments(specPath: specPath, projectRoot: tempDirectory)
        let content = try String(contentsOf: tempDirectory.appendingPathComponent("fragments/table.md"))

        #expect(report.ok)
        #expect(report.exportedFragments == ["fragments/table.md"])
        #expect(content == "| ID | Value |\n|---|---|\n| A | one |\n| B | two |\n")
    }

    @Test("repo governance fragment spec exports the checked-in fragment set")
    func repoGovernanceFragmentSpecExports() throws {
        let root = repositoryRoot()
        let fixtureRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        let specSource = root.appendingPathComponent("meta/views/governance.fragments.json")
        let specDirectory = fixtureRoot.appendingPathComponent("meta/views", isDirectory: true)
        try FileManager.default.createDirectory(at: specDirectory, withIntermediateDirectories: true)
        let specPath = specDirectory.appendingPathComponent("governance.fragments.json")
        try FileManager.default.copyItem(at: specSource, to: specPath)

        let report = try DocSyncService().exportFragments(specPath: specPath, projectRoot: fixtureRoot)

        #expect(report.ok)
        #expect(!report.exportedFragments.isEmpty)
        #expect(FileManager.default.fileExists(atPath: fixtureRoot.appendingPathComponent("meta/views/fragments/12-task-matrix-task-rows.md").path))
        #expect(FileManager.default.fileExists(atPath: fixtureRoot.appendingPathComponent("meta/views/fragments/20-traceability-matrix-rows.md").path))
        #expect(FileManager.default.fileExists(atPath: fixtureRoot.appendingPathComponent("meta/views/fragments/24-authoritative-source-execution-plan-phases.md").path))
        #expect(FileManager.default.fileExists(atPath: fixtureRoot.appendingPathComponent("meta/views/fragments/25-authoritative-source-task-matrix-rows.md").path))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-fragment-export-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
