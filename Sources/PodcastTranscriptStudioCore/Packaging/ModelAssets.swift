import Foundation

public struct ModelAsset: Identifiable, Equatable, Sendable {
    public let repository: String
    public let directoryName: String
    public let requiredFiles: [String]
    public let isOptional: Bool
    public let requiredPythonModules: [String]

    public var id: String { repository }

    public init(
        repository: String,
        directoryName: String,
        requiredFiles: [String],
        isOptional: Bool = false,
        requiredPythonModules: [String] = []
    ) {
        self.repository = repository
        self.directoryName = directoryName
        self.requiredFiles = requiredFiles
        self.isOptional = isOptional
        self.requiredPythonModules = requiredPythonModules
    }
}

public enum ModelAssetAvailability: String, Equatable, Sendable {
    case available
    case missingDependency
    case missingModel
}

public struct ModelAssetStatus: Identifiable, Equatable, Sendable {
    public let asset: ModelAsset
    public let directory: URL
    public let availability: ModelAssetAvailability

    public var id: String { asset.id }
    public var isInstalled: Bool { availability == .available }
}

public enum ModelAssets {
    public static let textRefinement = ModelAsset(
        repository: "Qwen/Qwen3-0.6B",
        directoryName: "Qwen3-0.6B",
        requiredFiles: ["config.json", "model.safetensors", "tokenizer.json"]
    )

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
        textRefinement,
    ]

    public static let optional: [ModelAsset] = [
        ModelAsset(
            repository: "Qwen/Qwen3-ASR-1.7B",
            directoryName: "Qwen3-ASR-1.7B",
            requiredFiles: ["config.json"],
            isOptional: true,
            requiredPythonModules: ["qwen_asr"]
        ),
        ModelAsset(
            repository: "Qwen/Qwen3-ForcedAligner-0.6B",
            directoryName: "Qwen3-ForcedAligner-0.6B",
            requiredFiles: ["config.json"],
            isOptional: true,
            requiredPythonModules: ["qwen_asr"]
        ),
        ModelAsset(
            repository: "XiaomiMiMo/MiMo-V2.5-ASR",
            directoryName: "MiMo-V2.5-ASR",
            requiredFiles: ["config.json"],
            isOptional: true
        ),
        ModelAsset(
            repository: "XiaomiMiMo/MiMo-Audio-Tokenizer",
            directoryName: "MiMo-Audio-Tokenizer",
            requiredFiles: ["config.json"],
            isOptional: true
        ),
        ModelAsset(
            repository: "github.com/XiaomiMiMo/MiMo-V2.5-ASR",
            directoryName: "MiMo-V2.5-ASR-source",
            requiredFiles: ["src/mimo_audio/mimo_audio.py"],
            isOptional: true
        ),
    ]

    public static let all: [ModelAsset] = required + optional
}
