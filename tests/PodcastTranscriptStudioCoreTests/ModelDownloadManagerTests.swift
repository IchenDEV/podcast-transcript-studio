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

        let statuses = ModelDownloadManager(configuration: config, assets: ModelAssets.required).statuses()

        XCTAssertEqual(statuses.count, ModelAssets.required.count)
        XCTAssertTrue(statuses.allSatisfy(\.isInstalled))
    }

    func test_statuses_include_optional_models_as_missing_by_default() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let config = AppConfiguration.preview(baseDirectory: base)

        let statuses = ModelDownloadManager(configuration: config).statuses()

        XCTAssertEqual(statuses.count, ModelAssets.all.count)
        XCTAssertTrue(statuses.contains { $0.asset.directoryName == "Qwen3-ASR-1.7B" && $0.availability == .missingModel })
        XCTAssertTrue(statuses.contains { $0.asset.directoryName == "MiMo-V2.5-ASR" && $0.availability == .missingModel })
    }

    func test_statuses_mark_installed_model_with_missing_python_dependency() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let config = AppConfiguration.preview(baseDirectory: base)
        let asset = ModelAsset(
            repository: "local/test",
            directoryName: "test-model",
            requiredFiles: ["config.json"],
            requiredPythonModules: ["definitely_missing_podcast_transcript_module"]
        )
        let directory = config.modelsDirectory.appendingPathComponent(asset.directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: directory.appendingPathComponent("config.json").path, contents: Data())

        let status = ModelDownloadManager(configuration: config, assets: [asset]).statuses().first

        XCTAssertEqual(status?.availability, .missingDependency)
        XCTAssertEqual(status?.isInstalled, false)
    }
}
