import Foundation

public enum ModelDownloadPhase: Equatable, Sendable {
    case idle
    case running
    case succeeded
    case failed
}

public struct ModelDownloadState: Equatable, Sendable {
    public let phase: ModelDownloadPhase
    public let message: String

    public init(phase: ModelDownloadPhase = .idle, message: String = "尚未开始") {
        self.phase = phase
        self.message = message
    }

    public var isRunning: Bool {
        phase == .running
    }
}

public enum ModelDownloadError: Error, LocalizedError {
    case missingScript(URL)
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .missingScript(let url):
            "找不到模型下载脚本：\(url.path)"
        case .failed(let message):
            message
        }
    }
}

public struct ModelDownloadManager: Sendable {
    public let configuration: AppConfiguration
    public let assets: [ModelAsset]

    public init(configuration: AppConfiguration, assets: [ModelAsset] = ModelAssets.required) {
        self.configuration = configuration
        self.assets = assets
    }

    public func statuses() -> [ModelAssetStatus] {
        assets.map { asset in
            let primaryDirectory = configuration.modelsDirectory.appendingPathComponent(asset.directoryName, isDirectory: true)
            let bundledDirectory = configuration.bundledModelsDirectory.appendingPathComponent(asset.directoryName, isDirectory: true)
            let installedDirectory = [primaryDirectory, bundledDirectory].first { directory in
                asset.requiredFiles.allSatisfy {
                    FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
                }
            }
            return ModelAssetStatus(
                asset: asset,
                directory: installedDirectory ?? primaryDirectory,
                isInstalled: installedDirectory != nil
            )
        }
    }

    public func downloadAll(huggingFaceToken: String?) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let scriptURL = configuration.scriptsDirectory.appendingPathComponent("download_models.py")
            guard FileManager.default.fileExists(atPath: scriptURL.path) else {
                throw ModelDownloadError.missingScript(scriptURL)
            }

            try FileManager.default.createDirectory(
                at: configuration.modelsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let bundledPython = configuration.pythonExecutableURL
            let executable = FileManager.default.fileExists(atPath: bundledPython.path) ? bundledPython.path : "/usr/bin/python3"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = [
                scriptURL.path,
                "--models-dir",
                configuration.modelsDirectory.path,
            ]

            var environment = ProcessInfo.processInfo.environment
            if executable == bundledPython.path {
                environment["PYTHONHOME"] = configuration.pythonHomeURL.path
                environment["PYTHONPATH"] = configuration.pythonSitePackagesURL.path
                environment["PYTHONNOUSERSITE"] = "1"
            }
            let token = huggingFaceToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !token.isEmpty {
                environment["HF_TOKEN"] = token
            }
            process.environment = environment

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            try process.run()
            process.waitUntilExit()

            let output = String(
                data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""

            guard process.terminationStatus == 0 else {
                throw ModelDownloadError.failed(output.isEmpty ? "模型下载失败" : output)
            }

            return output.isEmpty ? "模型已下载" : output
        }.value
    }
}
