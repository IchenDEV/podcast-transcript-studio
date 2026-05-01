import Foundation

public struct PackagingPlan: Equatable, Sendable {
    public let defaultASRModel: String
    public let requiredModelRepositories: [String]
    public let requiredScriptFiles: [String]

    public static let `default` = PackagingPlan(
        defaultASRModel: "openai/whisper-tiny",
        requiredModelRepositories: ModelAssets.required.map(\.repository),
        requiredScriptFiles: [
            "transcribe_with_speaker_segmentation.py"
        ]
    )
}
