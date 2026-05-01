import SwiftUI
import PodcastTranscriptStudioCore

@main
struct PodcastTranscriptStudioApp: App {
    private let configuration: AppConfiguration
    @StateObject private var viewModel: AppViewModel

    init() {
        let configuration = AppConfiguration.live(baseDirectory: URL(fileURLWithPath: NSHomeDirectory()))
        self.configuration = configuration
        _viewModel = StateObject(wrappedValue: AppViewModel(configuration: configuration))
    }

    var body: some Scene {
        WindowGroup("Podcast Transcript Studio") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .defaultSize(width: 1280, height: 820)
    }
}
