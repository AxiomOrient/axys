import DSDocSyncKit
import Foundation
import Testing

@Suite("DocSyncService")
struct DocSyncServiceTests {
    @Test("render updates a generated region from the manifest")
    func renderUpdatesDocument() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let documentPath = tempDirectory.appendingPathComponent("doc.md")
        try """
        # Demo

        <!-- GENERATED:BEGIN summary -->
        stale
        <!-- GENERATED:END summary -->
        """.write(to: documentPath, atomically: true, encoding: .utf8)

        let manifestPath = tempDirectory.appendingPathComponent("docsync.json")
        try JSONEncoder().encode(
            DocSyncManifest(documents: [
                DocSyncDocument(
                    path: "doc.md",
                    regions: [DocSyncRegion(id: "summary", content: "fresh\ncontent")]
                ),
            ])
        ).write(to: manifestPath)

        let report = try DocSyncService().render(manifestPath: manifestPath, projectRoot: tempDirectory)
        let content = try String(contentsOf: documentPath)

        #expect(report.ok)
        #expect(report.renderedDocuments == ["doc.md"])
        #expect(content.contains("fresh\ncontent"))
    }

    @Test("verify detects stale generated regions")
    func verifyDetectsStaleDocument() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let documentPath = tempDirectory.appendingPathComponent("doc.md")
        try """
        # Demo

        <!-- GENERATED:BEGIN summary -->
        stale
        <!-- GENERATED:END summary -->
        """.write(to: documentPath, atomically: true, encoding: .utf8)

        let manifestPath = tempDirectory.appendingPathComponent("docsync.json")
        try JSONEncoder().encode(
            DocSyncManifest(documents: [
                DocSyncDocument(
                    path: "doc.md",
                    regions: [DocSyncRegion(id: "summary", content: "fresh")]
                ),
            ])
        ).write(to: manifestPath)

        let report = try DocSyncService().verify(manifestPath: manifestPath, projectRoot: tempDirectory)

        #expect(!report.ok)
        #expect(report.staleDocuments == ["doc.md"])
        #expect(report.errors.isEmpty)
    }

    @Test("render loads region content from a fragment file relative to the manifest")
    func renderUsesFragmentFile() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let documentPath = tempDirectory.appendingPathComponent("doc.md")
        try """
        # Demo

        <!-- GENERATED:BEGIN summary -->
        stale
        <!-- GENERATED:END summary -->
        """.write(to: documentPath, atomically: true, encoding: .utf8)

        let fragmentsDirectory = tempDirectory.appendingPathComponent("fragments", isDirectory: true)
        try FileManager.default.createDirectory(at: fragmentsDirectory, withIntermediateDirectories: true)
        try "fresh\ncontent\n".write(
            to: fragmentsDirectory.appendingPathComponent("summary.md"),
            atomically: true,
            encoding: .utf8
        )

        let manifestPath = tempDirectory.appendingPathComponent("docsync.json")
        try JSONEncoder().encode(
            DocSyncManifest(documents: [
                DocSyncDocument(
                    path: "doc.md",
                    regions: [DocSyncRegion(id: "summary", contentPath: "fragments/summary.md")]
                ),
            ])
        ).write(to: manifestPath)

        let report = try DocSyncService().render(manifestPath: manifestPath, projectRoot: tempDirectory)
        let content = try String(contentsOf: documentPath)

        #expect(report.ok)
        #expect(report.renderedDocuments == ["doc.md"])
        #expect(content.contains("fresh\ncontent"))
    }

    @Test("sync exports fragments, renders documents, and verifies freshness")
    func syncCoordinatesExportRenderAndVerify() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let viewsDirectory = tempDirectory.appendingPathComponent("meta/views", isDirectory: true)
        try FileManager.default.createDirectory(at: viewsDirectory, withIntermediateDirectories: true)

        let documentPath = tempDirectory.appendingPathComponent("docs/plan.md")
        try FileManager.default.createDirectory(at: documentPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        # Plan

        <!-- GENERATED:BEGIN summary -->
        stale
        <!-- GENERATED:END summary -->
        """.write(to: documentPath, atomically: true, encoding: .utf8)

        let spec = DocFragmentExportSpec(fragments: [
            DocFragment(
                path: "meta/views/fragments/summary.md",
                kind: .markdownTable,
                headers: ["Key", "Value"],
                rows: [["status", "fresh"]]
            ),
        ])
        let specPath = viewsDirectory.appendingPathComponent("governance.fragments.json")
        try JSONEncoder().encode(spec).write(to: specPath)

        let manifest = DocSyncManifest(documents: [
            DocSyncDocument(
                path: "docs/plan.md",
                regions: [DocSyncRegion(id: "summary", contentPath: "fragments/summary.md")]
            ),
        ])
        let manifestPath = viewsDirectory.appendingPathComponent("docsync.manifest.json")
        try JSONEncoder().encode(manifest).write(to: manifestPath)

        let report = try DocSyncService().sync(
            specPath: specPath,
            manifestPath: manifestPath,
            projectRoot: tempDirectory
        )
        let content = try String(contentsOf: documentPath)

        #expect(report.ok)
        #expect(report.exportedContractViews.isEmpty)
        #expect(report.unchangedContractViews.isEmpty)
        #expect(report.exportedFragments == ["meta/views/fragments/summary.md"])
        #expect(report.renderedDocuments == ["docs/plan.md"])
        #expect(report.freshDocuments == ["docs/plan.md"])
        #expect(report.errors.isEmpty)
        #expect(content.contains("| Key | Value |"))
        #expect(content.contains("| status | fresh |"))
    }

    @Test("repo doc-sync manifest verifies against the checked-in docs")
    func repoManifestVerifyPasses() throws {
        let root = repositoryRoot()
        let report = try DocSyncService().verify(
            manifestPath: root.appendingPathComponent("meta/views/docsync.manifest.json"),
            projectRoot: root
        )

        #expect(report.ok)
        #expect(report.staleDocuments.isEmpty)
        #expect(report.errors.isEmpty)
        #expect(report.freshDocuments.contains("docs/11-execution-plan.md"))
        #expect(report.freshDocuments.contains("docs/12-task-matrix.md"))
        #expect(report.freshDocuments.contains("docs/20-traceability-matrix.md"))
        #expect(report.freshDocuments.contains("docs/23-authoritative-source-architecture.md"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-docsync-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
