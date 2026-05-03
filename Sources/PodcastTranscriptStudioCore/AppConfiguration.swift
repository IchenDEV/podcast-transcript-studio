import Foundation

public enum ChineseTextVariant: String, CaseIterable, Codable, Identifiable, Sendable {
    case simplified
    case traditional
    case original

    public var id: String { rawValue }
}

public struct AppConfiguration: Equatable, Sendable {
    public let appName: String
    public let baseDirectory: URL
    public let supportDirectory: URL
    public let jobsDirectory: URL
    public let exportsDirectory: URL
    public let logsDirectory: URL
    public let bundledResourcesDirectory: URL
    public let runtimeDirectory: URL
    public let modelsDirectory: URL
    public let bundledModelsDirectory: URL
    public let scriptsDirectory: URL
    public let chineseTextVariant: ChineseTextVariant

    public init(
        appName: String = "Podcast Transcript Studio",
        baseDirectory: URL,
        bundledResourcesDirectory: URL,
        overrides: AppConfigurationOverrides = AppConfigurationOverrides()
    ) {
        self.appName = appName
        self.baseDirectory = baseDirectory
        let defaultSupportDirectory = baseDirectory.appendingPathComponent("Application Support/PodcastTranscriptStudio", isDirectory: true)
        self.supportDirectory = defaultSupportDirectory
        self.jobsDirectory = overrides.jobsDirectoryURL ?? defaultSupportDirectory.appendingPathComponent("jobs", isDirectory: true)
        self.exportsDirectory = overrides.exportsDirectoryURL ?? defaultSupportDirectory.appendingPathComponent("exports", isDirectory: true)
        self.logsDirectory = overrides.logsDirectoryURL ?? defaultSupportDirectory.appendingPathComponent("logs", isDirectory: true)
        self.bundledResourcesDirectory = bundledResourcesDirectory
        self.runtimeDirectory = bundledResourcesDirectory.appendingPathComponent("Runtime", isDirectory: true)
        self.bundledModelsDirectory = bundledResourcesDirectory.appendingPathComponent("Models", isDirectory: true)
        self.modelsDirectory = overrides.modelsDirectoryURL ?? defaultSupportDirectory.appendingPathComponent("Models", isDirectory: true)
        self.scriptsDirectory = bundledResourcesDirectory.appendingPathComponent("Scripts", isDirectory: true)
        self.chineseTextVariant = overrides.chineseTextVariant ?? .simplified
    }

    public static func preview(baseDirectory: URL) -> AppConfiguration {
        AppConfiguration(baseDirectory: baseDirectory, bundledResourcesDirectory: baseDirectory.appendingPathComponent("BundledResources", isDirectory: true))
    }

    public static func live(
        baseDirectory: URL,
        bundle: Bundle,
        overrides: AppConfigurationOverrides? = nil
    ) -> AppConfiguration {
        let resourceRoot = bundle.resourceURL
            ?? baseDirectory.appendingPathComponent("BundledResources", isDirectory: true)
        return AppConfiguration(
            baseDirectory: baseDirectory,
            bundledResourcesDirectory: resourceRoot,
            overrides: overrides ?? AppConfigurationStore.load()
        )
    }

    public static func live(baseDirectory: URL) -> AppConfiguration {
        live(baseDirectory: baseDirectory, bundle: .module)
    }

    public var pythonHomeURL: URL {
        runtimeDirectory.appendingPathComponent("python-home", isDirectory: true)
    }

    public var pythonExecutableURL: URL {
        pythonHomeURL.appendingPathComponent("bin/python3")
    }

    public var pythonSitePackagesURL: URL {
        runtimeDirectory.appendingPathComponent("site-packages", isDirectory: true)
    }

    public func resolvedPythonRuntime(fileManager: FileManager = .default) -> PythonRuntimeConfiguration? {
        if fileManager.fileExists(atPath: pythonExecutableURL.path) {
            return PythonRuntimeConfiguration(
                executableURL: pythonExecutableURL,
                pythonHomeURL: pythonHomeURL,
                pythonPathURL: pythonSitePackagesURL
            )
        }

        if let developmentPythonURL = developmentWorkerPythonURL(fileManager: fileManager) {
            return PythonRuntimeConfiguration(
                executableURL: developmentPythonURL,
                pythonHomeURL: nil,
                pythonPathURL: nil
            )
        }

        return nil
    }

    private func developmentWorkerPythonURL(fileManager: FileManager) -> URL? {
        for root in developmentProjectRoots(fileManager: fileManager) {
            for relativePath in [".worker-venv/bin/python", ".worker-venv/bin/python3"] {
                let url = root.appendingPathComponent(relativePath)
                if fileManager.fileExists(atPath: url.path) {
                    return url
                }
            }
        }
        return nil
    }

    private func developmentProjectRoots(fileManager: FileManager) -> [URL] {
        var roots: [URL] = []
        let starts = [
            bundledResourcesDirectory,
            baseDirectory,
        ]

        for start in starts {
            roots.append(contentsOf: projectRoots(startingAt: start, fileManager: fileManager))
        }

        var seen = Set<String>()
        return roots.filter { root in
            let key = root.standardizedFileURL.path
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private func projectRoots(startingAt start: URL, fileManager: FileManager) -> [URL] {
        var roots: [URL] = []
        let initialURL = start.standardizedFileURL
        var current = initialURL
        if !current.hasDirectoryPath {
            current.deleteLastPathComponent()
        }
        var currentPath = current.path
        var visited = Set<String>()

        while !currentPath.isEmpty {
            guard visited.insert(currentPath).inserted else {
                break
            }

            let packagePath = (currentPath as NSString).appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: packagePath) {
                roots.append(URL(fileURLWithPath: currentPath, isDirectory: true))
            }

            let parentPath = (currentPath as NSString).deletingLastPathComponent
            if parentPath == currentPath || parentPath.isEmpty {
                break
            }
            currentPath = parentPath
        }

        return roots
    }
}

public struct PythonRuntimeConfiguration: Equatable, Sendable {
    public let executableURL: URL
    public let pythonHomeURL: URL?
    public let pythonPathURL: URL?

    public var environment: [String: String] {
        var values = ["PYTHONNOUSERSITE": "1"]
        if let pythonHomeURL {
            values["PYTHONHOME"] = pythonHomeURL.path
        }
        if let pythonPathURL {
            values["PYTHONPATH"] = pythonPathURL.path
        }
        return values
    }
}

public struct AppConfigurationOverrides: Codable, Equatable, Sendable {
    public var jobsDirectoryPath: String?
    public var exportsDirectoryPath: String?
    public var logsDirectoryPath: String?
    public var modelsDirectoryPath: String?
    public var chineseTextVariant: ChineseTextVariant?

    public init(
        jobsDirectoryPath: String? = nil,
        exportsDirectoryPath: String? = nil,
        logsDirectoryPath: String? = nil,
        modelsDirectoryPath: String? = nil,
        chineseTextVariant: ChineseTextVariant? = nil
    ) {
        self.jobsDirectoryPath = jobsDirectoryPath
        self.exportsDirectoryPath = exportsDirectoryPath
        self.logsDirectoryPath = logsDirectoryPath
        self.modelsDirectoryPath = modelsDirectoryPath
        self.chineseTextVariant = chineseTextVariant
    }

    public var jobsDirectoryURL: URL? { url(from: jobsDirectoryPath) }
    public var exportsDirectoryURL: URL? { url(from: exportsDirectoryPath) }
    public var logsDirectoryURL: URL? { url(from: logsDirectoryPath) }
    public var modelsDirectoryURL: URL? { url(from: modelsDirectoryPath) }

    private func url(from path: String?) -> URL? {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
    }
}

public enum AppConfigurationStore {
    private static let key = "PodcastTranscriptStudio.AppConfigurationOverrides"

    public static func load(defaults: UserDefaults = .standard) -> AppConfigurationOverrides {
        guard let data = defaults.data(forKey: key) else {
            return AppConfigurationOverrides()
        }
        return (try? JSONDecoder().decode(AppConfigurationOverrides.self, from: data)) ?? AppConfigurationOverrides()
    }

    public static func save(_ overrides: AppConfigurationOverrides, defaults: UserDefaults = .standard) throws {
        let data = try JSONEncoder().encode(overrides)
        defaults.set(data, forKey: key)
    }

    public static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
