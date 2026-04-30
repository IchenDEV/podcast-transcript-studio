import SwiftUI
import PodcastTranscriptStudioCore

struct SettingsView: View {
    let configuration: AppConfiguration

    var body: some View {
        Form {
            LabeledContent("模型目录", value: configuration.modelsDirectory.path)
            LabeledContent("脚本目录", value: configuration.scriptsDirectory.path)
            LabeledContent("任务目录", value: configuration.jobsDirectory.path)
            LabeledContent("导出目录", value: configuration.exportsDirectory.path)
        }
        .padding()
        .navigationTitle("设置")
    }
}
