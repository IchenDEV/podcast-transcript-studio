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
        if let asrModelURL = firstExistingModel(named: "whisper-tiny") {
            arguments.append(contentsOf: ["--asr-model", asrModelURL.path])
        }
        if diarize { arguments.append("--diarize") }
        if diarize, let diarizationModelURL = firstExistingModel(named: "speaker-diarization-3.1") {
            arguments.append(contentsOf: ["--diarization-model", diarizationModelURL.path])
        }
        if !cleanFillers { arguments.append("--keep-fillers") }

        let pythonRuntime = configuration.resolvedPythonRuntime()
        let executable = pythonRuntime?.executableURL.path ?? "/usr/bin/python3"

        var environment: [String: String] = [
            "PODCAST_MODELS_DIR": configuration.modelsDirectory.path,
            "PODCAST_BUNDLED_MODELS_DIR": configuration.bundledModelsDirectory.path,
            "PODCAST_SCRIPTS_DIR": configuration.scriptsDirectory.path,
        ]
        if let pythonRuntime {
            for (key, value) in pythonRuntime.environment {
                environment[key] = value
            }
        }

        return WorkerCommand(
            executable: executable,
            arguments: arguments,
            environment: environment,
            outputTextURL: outputTextURL,
            outputJSONURL: outputJSONURL
        )
    }

    private func firstExistingModel(named name: String) -> URL? {
        let candidates = [
            configuration.modelsDirectory.appendingPathComponent(name, isDirectory: true),
            configuration.bundledModelsDirectory.appendingPathComponent(name, isDirectory: true),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
