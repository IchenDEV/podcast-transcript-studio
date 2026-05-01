import XCTest
@testable import PodcastTranscriptStudioCore

final class ModelDownloadManagerTests: XCTestCase {
    func test_statuses_mark_required_models_when_files_exist() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let config = AppConfiguration.preview(baseDirectory: base)

        for asset in ModelAssets.required {
            let directory = config.modelsDirectory.appendingPathComponent(asset.directoryName, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for file in asset.requiredFiles {
                FileManager.default.createFile(atPath: directory.appendingPathComponent(file).path, contents: Data())
            }
        }

        let statuses = ModelDownloadManager(configuration: config).statuses()

        XCTAssertEqual(statuses.count, ModelAssets.required.count)
        XCTAssertTrue(statuses.allSatisfy(\.isInstalled))
    }
}
