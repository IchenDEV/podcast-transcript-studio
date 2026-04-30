import Foundation

public enum TranscriptParserError: Error {
    case malformedSegment(String)
}

public struct TranscriptParser {
    private let sectionRegex = try! NSRegularExpression(pattern: #"^【(?<title>分节\d+)】"#)
    private let segmentRegex = try! NSRegularExpression(pattern: #"^\[(?<start>[^\]]+?) - (?<end>[^\]]+?)\]\s+(?<speaker>[^:]+):\s+(?<text>.+)$"#)

    public init() {}

    public func parse(_ input: String) throws -> [TranscriptSection] {
        var sections: [TranscriptSection] = []
        var current: TranscriptSection?

        for rawLine in input.split(whereSeparator: \ .isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if let title = matchFirst(in: line, regex: sectionRegex, group: "title") {
                if let current { sections.append(current) }
                current = TranscriptSection(title: title)
                continue
            }

            if let match = matchSegment(in: line) {
                if current == nil {
                    current = TranscriptSection(title: "未分节")
                }
                current?.segments.append(match)
                continue
            }
        }

        if let current { sections.append(current) }
        return sections
    }

    private func matchSegment(in line: String) -> TranscriptSegment? {
        guard let start = matchFirst(in: line, regex: segmentRegex, group: "start"),
              let end = matchFirst(in: line, regex: segmentRegex, group: "end"),
              let speaker = matchFirst(in: line, regex: segmentRegex, group: "speaker"),
              let text = matchFirst(in: line, regex: segmentRegex, group: "text")
        else {
            return nil
        }
        return TranscriptSegment(start: start, end: end, speaker: speaker, text: text)
    }

    private func matchFirst(in input: String, regex: NSRegularExpression, group: String) -> String? {
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let result = regex.firstMatch(in: input, range: range) else { return nil }
        let groupRange = result.range(withName: group)
        guard groupRange.location != NSNotFound, let swiftRange = Range(groupRange, in: input) else { return nil }
        return String(input[swiftRange])
    }
}
