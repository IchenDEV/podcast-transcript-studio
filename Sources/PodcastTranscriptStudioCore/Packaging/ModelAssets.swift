import Foundation

public struct ModelAsset: Identifiable, Equatable, Sendable {
    public let repository: String
    public let directoryName: String
    public let requiredFiles: [String]

    public var id: String { repository }

    public init(repository: String, directoryName: String, requiredFiles: [String]) {
        self.repository = repository
        self.directoryName = directoryName
        self.requiredFiles = requiredFiles
    }
}

public struct ModelAssetStatus: Identifiable, Equatable, Sendable {
    public let asset: ModelAsset
    public let directory: URL
    public let isInstalled: Bool

    public var id: String { asset.id }
}

public enum ModelAssets {
    public static let required: [ModelAsset] = [
        ModelAsset(
            repository: "openai/whisper-tiny",
            directoryName: "whisper-tiny",
            requiredFiles: ["config.json", "pytorch_model.bin"]
        ),
        ModelAsset(
            repository: "pyannote/speaker-diarization-3.1",
            directoryName: "speaker-diarization-3.1",
            requiredFiles: ["config.yaml"]
        ),
        ModelAsset(
            repository: "pyannote/segmentation-3.0",
            directoryName: "segmentation-3.0",
            requiredFiles: ["config.yaml", "pytorch_model.bin"]
        ),
        ModelAsset(
            repository: "pyannote/wespeaker-voxceleb-resnet34-LM",
            directoryName: "wespeaker-voxceleb-resnet34-LM",
            requiredFiles: ["config.yaml", "pytorch_model.bin"]
        ),
    ]
}
