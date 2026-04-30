import SwiftUI
import UniformTypeIdentifiers
import PodcastTranscriptStudioCore

struct ContentView: View {
    @StateObject var viewModel: AppViewModel
    let configuration: AppConfiguration
    @State private var exportMessage: String?
    @State private var showingImporter = false
    @State private var diarize = true
    @State private var cleanFillers = true

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            TabView {
                JobDetailView(viewModel: viewModel)
                    .tabItem { Label("结果", systemImage: "doc.text") }
                SettingsView(configuration: configuration)
                    .tabItem { Label("设置", systemImage: "gearshape") }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("导入音频") { showingImporter = true }
                Toggle("多说话人", isOn: $diarize)
                Toggle("清理语气词", isOn: $cleanFillers)
                Button("导出 TXT") { export(.txt) }
                    .disabled(viewModel.selectedJob == nil || viewModel.isRunningJob)
                Button("导出 JSON") { export(.json) }
                    .disabled(viewModel.selectedJob == nil || viewModel.isRunningJob)
                Button("导出 SRT") { export(.srt) }
                    .disabled(viewModel.selectedJob == nil || viewModel.isRunningJob)
            }
        }
        .overlay(alignment: .top) {
            if viewModel.isRunningJob {
                ProgressView("正在本地转写...")
                    .padding(12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 12)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.audio, .movie, .mpeg4Movie, .mpeg4Audio],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("处理结果", isPresented: Binding(
            get: { exportMessage != nil },
            set: { if !$0 { exportMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(exportMessage ?? "")
        }
        .task {
            do {
                try viewModel.bootstrap()
            } catch {
                exportMessage = "加载历史任务失败：\(error.localizedDescription)"
            }
            viewModel.loadDemoIfNeeded()
        }
    }

    private func export(_ format: ExportFormat) {
        do {
            let url = try viewModel.exportSelectedJob(as: format)
            exportMessage = "已导出到：\(url.path)"
        } catch {
            exportMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else {
            if case let .failure(error) = result {
                exportMessage = "导入失败：\(error.localizedDescription)"
            }
            return
        }

        Task {
            do {
                try await viewModel.startTranscription(sourceURL: url, diarize: diarize, cleanFillers: cleanFillers)
                exportMessage = "转写完成：\(url.lastPathComponent)"
            } catch {
                exportMessage = "转写失败：\(error.localizedDescription)"
            }
        }
    }
}
