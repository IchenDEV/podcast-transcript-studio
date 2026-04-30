import Foundation

public struct JobStoreRepository {
    public let configuration: AppConfiguration
    public let fileURL: URL

    public init(configuration: AppConfiguration) {
        self.configuration = configuration
        self.fileURL = configuration.supportDirectory.appendingPathComponent("jobs.json")
    }

    public func loadJobs() throws -> [TranscriptionJob] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([TranscriptionJob].self, from: data)
    }

    public func save(jobs: [TranscriptionJob]) throws {
        try FileManager.default.createDirectory(at: configuration.supportDirectory, withIntermediateDirectories: true, attributes: nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(jobs)
        try data.write(to: fileURL, options: Data.WritingOptions.atomic)
    }
}
