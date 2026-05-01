import SwiftUI
import UniformTypeIdentifiers
import PodcastTranscriptStudioCore
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @StateObject var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var exportMessage: String?
    @State private var showingImporter = false
    @State private var showingPodcastLinkSheet = false
    @State private var podcastLink = ""
    @State private var diarize = true
    @State private var cleanFillers = true
    @State private var selectedPanel: DetailPanel = .result

    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: viewModel,
                selectedPanel: $selectedPanel,
                diarize: $diarize,
                cleanFillers: $cleanFillers,
                onImportAudio: {
                    showingImporter = true
                },
                onImportPodcast: {
                    showingPodcastLinkSheet = true
                },
                onExport: export
            )
        } detail: {
            ZStack {
                backgroundLayer
                switch selectedPanel {
                case .result:
                    JobDetailView(viewModel: viewModel)
                case .settings:
                    SettingsView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(backgroundLayer)
        .background(WindowGlassConfigurator())
        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        .overlay(alignment: .top) {
            if viewModel.isRunningJob {
                runningBanner
                    .padding(.top, 14)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.audio, .movie, .mpeg4Movie, .mpeg4Audio],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showingPodcastLinkSheet) {
            PodcastLinkImportSheet(
                urlText: $podcastLink,
                onCancel: {
                    showingPodcastLinkSheet = false
                },
                onSubmit: {
                    handlePodcastLinkImport()
                }
            )
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

    private var backgroundLayer: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            Rectangle()
                .fill(colorScheme == .dark ? Color.black.opacity(0.42) : Color.white.opacity(0.34))
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.025 : 0.16),
                    Color.gray.opacity(colorScheme == .dark ? 0.055 : 0.035),
                    Color.black.opacity(colorScheme == .dark ? 0.10 : 0.015),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var runningBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("正在本地转写")
                .font(.callout.weight(.medium))
            Text("请保持应用打开")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(.separator.opacity(colorScheme == .dark ? 0.38 : 0.55))
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.36 : 0.12), radius: 18, y: 8)
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

    private func handlePodcastLinkImport() {
        let trimmed = podcastLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            exportMessage = "请输入有效的 http 或 https 链接。"
            return
        }

        showingPodcastLinkSheet = false
        Task {
            do {
                try await viewModel.startTranscription(podcastURL: url, diarize: diarize, cleanFillers: cleanFillers)
                exportMessage = "转写完成：\(url.host ?? "播客链接")"
            } catch {
                exportMessage = "链接导入失败：\(error.localizedDescription)"
            }
        }
    }
}

private struct PodcastLinkImportSheet: View {
    @Binding var urlText: String
    let onCancel: () -> Void
    let onSubmit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("播客链接")
                    .font(.title3.weight(.semibold))
                Text("粘贴 Apple Podcasts、小宇宙或喜马拉雅单集链接。支持公开页面、RSS 和直连音频。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("https://", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(onSubmit)

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button {
                    onSubmit()
                } label: {
                    Label("下载并转写", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            focused = true
        }
    }
}

enum DetailPanel: String, CaseIterable, Identifiable {
    case result
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .result: "结果"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .result: "doc.text"
        case .settings: "gearshape"
        }
    }
}

private struct WindowGlassConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
    }
}
