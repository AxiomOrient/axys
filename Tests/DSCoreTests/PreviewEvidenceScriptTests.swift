import Foundation
import Testing

@Suite("Preview evidence scripts")
struct PreviewEvidenceScriptTests {
    @Test("shell smoke waits for the local preview server before invoking the driver")
    func shellSmokeWaitsForServerReadiness() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let result = try runScript(
            repositoryRoot().appendingPathComponent("PreviewApp/evidence/scripts/run-shell-smoke.sh"),
            arguments: [
                fixture.bundleRoot.path,
                "preview-shell-test",
                "43173",
                fixture.outputRoot.path,
                fixture.driverURL.path,
            ]
        )

        let markerPath = fixture.outputRoot.appendingPathComponent("preview-shell-test.driver.txt")
        let screenshotPath = fixture.outputRoot.appendingPathComponent("preview-shell-test.png")
        let serverLogPath = fixture.outputRoot.appendingPathComponent("preview-shell-test.server.log")

        #expect(result.exitCode == 0)
        #expect(FileManager.default.fileExists(atPath: markerPath.path))
        #expect(FileManager.default.fileExists(atPath: screenshotPath.path))
        #expect(FileManager.default.fileExists(atPath: serverLogPath.path))
        #expect(try String(contentsOf: markerPath, encoding: .utf8).contains("url=http://127.0.0.1:43173/"))
    }

    private func makeFixture() throws -> (root: URL, bundleRoot: URL, outputRoot: URL, driverURL: URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-preview-evidence-\(UUID().uuidString)", isDirectory: true)
        let bundleRoot = root.appendingPathComponent("bundle", isDirectory: true)
        let outputRoot = root.appendingPathComponent("output", isDirectory: true)
        let driverURL = root.appendingPathComponent("stub-driver.sh")

        try FileManager.default.createDirectory(at: bundleRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)

        try """
        <!doctype html>
        <html lang="en">
        <body>preview shell smoke fixture</body>
        </html>
        """.write(
            to: bundleRoot.appendingPathComponent("index.html"),
            atomically: true,
            encoding: .utf8
        )

        try """
        #!/usr/bin/env bash
        set -euo pipefail

        SESSION="${1:?session is required}"
        URL="${2:?url is required}"
        OUTDIR="${3:?outdir is required}"
        MARKER="$OUTDIR/${SESSION}.driver.txt"

        python3 -c 'import sys, urllib.request; urllib.request.urlopen(sys.argv[1], timeout=2).read(1)' "$URL" >/dev/null
        printf 'session=%s\nurl=%s\n' "$SESSION" "$URL" >"$MARKER"
        : >"$OUTDIR/${SESSION}.png"
        """.write(
            to: driverURL,
            atomically: true,
            encoding: .utf8
        )

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: driverURL.path
        )

        return (root, bundleRoot, outputRoot, driverURL)
    }

    private func runScript(_ scriptURL: URL, arguments: [String]) throws -> ScriptResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path] + arguments
        process.currentDirectoryURL = repositoryRoot()

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        return ScriptResult(
            exitCode: Int(process.terminationStatus),
            stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct ScriptResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
