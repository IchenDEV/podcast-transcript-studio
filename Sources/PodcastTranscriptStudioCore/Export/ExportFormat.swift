import Foundation

public enum ExportFormat: String, CaseIterable, Sendable {
    case txt
    case json
    case markdown = "md"
    case srt

    public func outputFilename(base: String) -> String {
        "\(base).\(rawValue)"
    }
}
