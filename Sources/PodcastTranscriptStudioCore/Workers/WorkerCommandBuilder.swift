import Foundation

public struct WorkerCommand: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]
    public let environment: [String: String]
    public let outputTextURL: URL
    public let outputJSONURL: URL
}

public enum WorkerCommandError: Error {
    case unsupportedSource
}

public struct WorkerCommandBuilder {
    public let configuration: AppConfiguration

    public init(configuration: AppConfiguration) {
        self.configuration = configuration
    }

    public func makeCommand(job: TranscriptionJob, sourceURL: URL, diarize: Bool, cleanFillers: Bool) throws -> WorkerCommand {
        guard !sourceURL.path.isEmpty else { throw WorkerCommandError.unsupportedSource }

        let outputDirectory = configuration.jobsDirectory.appendingPathComponent(job.id.uuidString, isDirectory: true)
        let outputTextURL = outputDirectory.appendingPathComponent("transcript.txt")
        let outputJSONURL = outputDirectory.appendingPathComponent("transcript.json")
        let scriptURL = configuration.scriptsDirectory.appendingPathComponent("cli.py")

        var arguments = [
            scriptURL.path,
            "--audio", sourceURL.path,
            "--output", outputTextURL.path,
            "--json", outputJSONURL.path,
            "--preset", "balanced",
        ]
        if diarize { arguments.append("--diarize") }
        if !cleanFillers { arguments.append("--keep-fillers") }

        let bundledPython = configuration.pythonExecutableURL
        let executable = FileManager.default.fileExists(atPath: bundledPython.path) ? bundledPython.path : "/usr/bin/python3"

        var environment: [String: String] = [
            "PODCAST_MODELS_DIR": configuration.modelsDirectory.path,
            "PODCAST_SCRIPTS_DIR": configuration.scriptsDirectory.path,
        ]
        if executable == bundledPython.path {
            environment["PYTHONHOME"] = configuration.pythonHomeURL.path
            environment["PYTHONPATH"] = configuration.pythonSitePackagesURL.path
            environment["PYTHONNOUSERSITE"] = "1"
        }

        return WorkerCommand(
            executable: executable,
            arguments: arguments,
            environment: environment,
            outputTextURL: outputTextURL,
            outputJSONURL: outputJSONURL
        )
    }
}
