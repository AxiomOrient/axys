import Foundation

public struct ResolvedDSConfig: Sendable {
    public let configPath: URL
    public let projectRoot: URL
    public let screenDocDirectory: URL
    public let screenSpecDirectory: URL
    public let tokenDirectory: URL
    public let catalogPath: URL
    public let buildDirectory: URL

    public init(
        configPath: URL,
        projectRoot: URL,
        screenDocDirectory: URL,
        screenSpecDirectory: URL,
        tokenDirectory: URL,
        catalogPath: URL,
        buildDirectory: URL
    ) {
        self.configPath = configPath
        self.projectRoot = projectRoot
        self.screenDocDirectory = screenDocDirectory
        self.screenSpecDirectory = screenSpecDirectory
        self.tokenDirectory = tokenDirectory
        self.catalogPath = catalogPath
        self.buildDirectory = buildDirectory
    }

    public func screenSpecPath(screenID: String) -> URL {
        screenSpecDirectory.appendingPathComponent("\(screenID).screen.json")
    }

    public func defaultScreenOutputDirectory(screenID: String) -> URL {
        buildDirectory.appendingPathComponent(screenID, isDirectory: true)
    }

    public func defaultCompiledSpecPath(screenID: String) -> URL {
        buildDirectory
            .appendingPathComponent("compiled", isDirectory: true)
            .appendingPathComponent("\(screenID).screen.json")
    }

    public var defaultBundleOutputDirectory: URL {
        buildDirectory.appendingPathComponent("bundle", isDirectory: true)
    }
}

public extension DSConfig {
    func resolvePaths(configPath: URL) -> ResolvedDSConfig {
        let configFile = configPath.standardizedFileURL
        let configDirectory = configFile.deletingLastPathComponent()
        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

        let projectRoot = resolveProjectRoot(
            path: projectRoot,
            configDirectory: configDirectory,
            workingDirectory: workingDirectory
        )

        return ResolvedDSConfig(
            configPath: configFile,
            projectRoot: projectRoot,
            screenDocDirectory: resolve(path: screenDocDir, relativeTo: projectRoot),
            screenSpecDirectory: resolve(path: screenSpecDir, relativeTo: projectRoot),
            tokenDirectory: resolve(path: tokenDir, relativeTo: projectRoot),
            catalogPath: resolve(path: catalogPath, relativeTo: projectRoot),
            buildDirectory: resolve(path: buildDir, relativeTo: projectRoot)
        )
    }

    private func resolveProjectRoot(path: String, configDirectory: URL, workingDirectory: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }

        let configRelative = configDirectory.appendingPathComponent(path).standardizedFileURL
        if looksLikeProjectRoot(configRelative) {
            return configRelative
        }

        return workingDirectory.appendingPathComponent(path).standardizedFileURL
    }

    private func resolve(path: String, relativeTo base: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }
        return base.appendingPathComponent(path).standardizedFileURL
    }

    private func looksLikeProjectRoot(_ candidate: URL) -> Bool {
        let fileManager = FileManager.default
        let expectedEntries = [
            screenDocDir,
            screenSpecDir,
            tokenDir,
            catalogPath,
        ]

        return expectedEntries.contains { entry in
            fileManager.fileExists(atPath: candidate.appendingPathComponent(entry).path)
        }
    }
}
