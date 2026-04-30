import Foundation

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
    public let scriptsDirectory: URL

    public init(
        appName: String = "Podcast Transcript Studio",
        baseDirectory: URL,
        bundledResourcesDirectory: URL
    ) {
        self.appName = appName
        self.baseDirectory = baseDirectory
        self.supportDirectory = baseDirectory.appendingPathComponent("Application Support/PodcastTranscriptStudio", isDirectory: true)
        self.jobsDirectory = supportDirectory.appendingPathComponent("jobs", isDirectory: true)
        self.exportsDirectory = supportDirectory.appendingPathComponent("exports", isDirectory: true)
        self.logsDirectory = supportDirectory.appendingPathComponent("logs", isDirectory: true)
        self.bundledResourcesDirectory = bundledResourcesDirectory
        self.runtimeDirectory = bundledResourcesDirectory.appendingPathComponent("Runtime", isDirectory: true)
        self.modelsDirectory = bundledResourcesDirectory.appendingPathComponent("Models", isDirectory: true)
        self.scriptsDirectory = bundledResourcesDirectory.appendingPathComponent("Scripts", isDirectory: true)
    }

    public static func preview(baseDirectory: URL) -> AppConfiguration {
        AppConfiguration(baseDirectory: baseDirectory, bundledResourcesDirectory: baseDirectory.appendingPathComponent("BundledResources", isDirectory: true))
    }

    public static func live(baseDirectory: URL, bundle: Bundle) -> AppConfiguration {
        let resourceRoot = bundle.resourceURL
            ?? baseDirectory.appendingPathComponent("BundledResources", isDirectory: true)
        return AppConfiguration(baseDirectory: baseDirectory, bundledResourcesDirectory: resourceRoot)
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
}
