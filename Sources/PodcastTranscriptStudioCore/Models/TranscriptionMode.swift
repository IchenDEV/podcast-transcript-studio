import Foundation

public enum TranscriptionMode: String, CaseIterable, Identifiable, Sendable {
    case quick
    case standard
    case highQuality = "high_quality"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .quick:
            "快速"
        case .standard:
            "标准"
        case .highQuality:
            "高质量"
        }
    }

    public var workerPreset: String {
        switch self {
        case .quick:
            "lite"
        case .standard:
            "balanced"
        case .highQuality:
            "production"
        }
    }

    public var defaultASRProvider: String {
        switch self {
        case .quick, .standard:
            "whisper"
        case .highQuality:
            "auto"
        }
    }
}
