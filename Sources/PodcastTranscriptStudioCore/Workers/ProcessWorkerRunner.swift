import Foundation

public protocol WorkerRunning: Sendable {
    func run(command: WorkerCommand) async throws
}

public enum ProcessWorkerRunnerError: Error {
    case nonZeroExit(code: Int32, stderr: String)
}

public struct ProcessWorkerRunner: WorkerRunning {
    public init() {}

    public func run(command: WorkerCommand) async throws {
        try FileManager.default.createDirectory(
            at: command.outputTextURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.environment = ProcessInfo.processInfo.environment.merging(command.environment) { _, new in new }

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(decoding: data, as: UTF8.self)
            throw ProcessWorkerRunnerError.nonZeroExit(code: process.terminationStatus, stderr: stderr)
        }
    }
}
