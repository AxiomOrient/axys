import Foundation
import Testing

@Suite("Host proof scripts")
struct HostProofScriptTests {
    @Test("iOS host proof script summarizes a sample root")
    func iosHostProofScript() throws {
        let sampleRoot = try makeSampleRoot(platform: "ios")
        defer { try? FileManager.default.removeItem(at: sampleRoot) }

        let result = try runScript(
            repositoryRoot().appendingPathComponent("HostApps/ios/scripts/run-host-proof.sh"),
            argument: sampleRoot.path
        )

        let summaryPath = sampleRoot.appendingPathComponent("HostProof/ios.host-proof.summary.txt")
        #expect(result.exitCode == 0)
        #expect(FileManager.default.fileExists(atPath: summaryPath.path))
        #expect(result.stdout.contains("platform=ios"))
        #expect(result.stdout.contains("checkout.runtime.log"))
    }

    @Test("android host proof script summarizes a sample root")
    func androidHostProofScript() throws {
        let sampleRoot = try makeSampleRoot(platform: "android")
        defer { try? FileManager.default.removeItem(at: sampleRoot) }

        let result = try runScript(
            repositoryRoot().appendingPathComponent("HostApps/android/scripts/run-host-proof.sh"),
            argument: sampleRoot.path
        )

        let summaryPath = sampleRoot.appendingPathComponent("HostProof/android.host-proof.summary.txt")
        #expect(result.exitCode == 0)
        #expect(FileManager.default.fileExists(atPath: summaryPath.path))
        #expect(result.stdout.contains("platform=android"))
        #expect(result.stdout.contains("checkout.runtime.log"))
    }

    private func makeSampleRoot(platform: String) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("axys-host-proof-script-\(platform)-\(UUID().uuidString)", isDirectory: true)

        let directories = [
            "GeneratedUI/\(platform)",
            "HostSmoke/\(platform)",
            "BuildArtifacts/\(platform)",
            "HostProof",
        ]

        for relative in directories {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(relative, isDirectory: true),
                withIntermediateDirectories: true
            )
        }

        try "{}".write(
            to: root.appendingPathComponent("HostProof/proof.manifest.json"),
            atomically: true,
            encoding: .utf8
        )
        try "runtime-smoke:ok:checkout\n".write(
            to: root.appendingPathComponent("BuildArtifacts/\(platform)/checkout.runtime.log"),
            atomically: true,
            encoding: .utf8
        )

        return root
    }

    private func runScript(_ scriptURL: URL, argument: String) throws -> ScriptResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path, argument]
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
