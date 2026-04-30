import Foundation

public struct AppBundlePlan: Equatable, Sendable {
    public let appName: String
    public let outputRoot: URL
    public let executableName: String

    public init(
        appName: String = "Podcast Transcript Studio",
        outputRoot: URL,
        executableName: String = "PodcastTranscriptStudioApp"
    ) {
        self.appName = appName
        self.outputRoot = outputRoot
        self.executableName = executableName
    }

    public var appBundleURL: URL {
        outputRoot.appendingPathComponent("\(appName).app", isDirectory: true)
    }

    public var contentsURL: URL {
        appBundleURL.appendingPathComponent("Contents", isDirectory: true)
    }

    public var macosDirectoryURL: URL {
        contentsURL.appendingPathComponent("MacOS", isDirectory: true)
    }

    public var resourcesURL: URL {
        contentsURL.appendingPathComponent("Resources", isDirectory: true)
    }

    public var macosExecutableURL: URL {
        macosDirectoryURL.appendingPathComponent(executableName)
    }

    public var infoPlistURL: URL {
        contentsURL.appendingPathComponent("Info.plist")
    }
}
