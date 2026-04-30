import Foundation

public struct PackagingPlan: Equatable, Sendable {
    public let defaultASRModel: String
    public let requiredModelRepositories: [String]
    public let requiredScriptFiles: [String]

    public static let `default` = PackagingPlan(
        defaultASRModel: "openai/whisper-tiny",
        requiredModelRepositories: [
            "openai/whisper-tiny",
            "pyannote/speaker-diarization-3.1",
            "pyannote/segmentation-3.0",
            "pyannote/wespeaker-voxceleb-resnet34-LM",
        ],
        requiredScriptFiles: [
            "transcribe_with_speaker_segmentation.py"
        ]
    )
}
