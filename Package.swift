// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PodcastTranscriptStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PodcastTranscriptStudioCore", targets: ["PodcastTranscriptStudioCore"]),
        .executable(name: "PodcastTranscriptStudioApp", targets: ["PodcastTranscriptStudioApp"]),
    ],
    targets: [
        .target(
            name: "PodcastTranscriptStudioCore",
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "PodcastTranscriptStudioApp",
            dependencies: ["PodcastTranscriptStudioCore"]
        ),
        .testTarget(
            name: "PodcastTranscriptStudioCoreTests",
            dependencies: ["PodcastTranscriptStudioCore"]
        ),
    ]
)
