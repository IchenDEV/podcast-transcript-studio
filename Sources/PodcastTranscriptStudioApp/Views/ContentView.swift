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
    @State private var transcriptMode: TranscriptDisplayMode = .detail
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
                }
            )
            .navigationSplitViewColumnWidth(
                min: SidebarColumnWidth.minimum,
                ideal: SidebarColumnWidth.ideal,
                max: SidebarColumnWidth.maximum
            )
        } detail: {
            ZStack {
                backgroundLayer
                switch selectedPanel {
                case .result:
                    JobDetailView(viewModel: viewModel, displayMode: transcriptMode)
                case .settings:
                    SettingsView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                detailToolbar
            }
        }
        .background(backgroundLayer)
        .background(WindowGlassConfigurator())
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
            Rectangle().fill(.regularMaterial)
            Rectangle()
                .fill(colorScheme == .dark ? Color.black.opacity(0.24) : Color.white.opacity(0.56))
        }
        .ignoresSafeArea()
    }

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .navigation) {
                Text("Podcast Transcript Studio")
                    .font(.headline.weight(.semibold))
                    .padding(.leading, 18)
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigation) {
                Text("Podcast Transcript Studio")
                    .font(.headline.weight(.semibold))
                    .padding(.leading, 18)
            }
        }

        if selectedPanel == .result {
            ToolbarItem(placement: .principal) {
                DetailModeSegmentedControl(selection: $transcriptMode)
                    .disabled(viewModel.selectedJob == nil)
            }

            ToolbarItem(placement: .primaryAction) {
                exportToolbarMenu
            }
        }
    }

    private var exportToolbarMenu: some View {
        Menu {
            Button("导出 TXT") {
                export(.txt)
            }
            Button("导出 JSON") {
                export(.json)
            }
            Button("导出 SRT") {
                export(.srt)
            }
        } label: {
            Label("导出", systemImage: "square.and.arrow.up")
        }
        .menuStyle(.button)
        .disabled(viewModel.selectedJob == nil || viewModel.isRunningJob)
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

private struct DetailModeSegmentedControl: View {
    @Binding var selection: TranscriptDisplayMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 2) {
            ForEach(TranscriptDisplayMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 13)
                        Text(mode.title)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(selection == mode ? Color.primary : Color.secondary)
                    .frame(width: 64, height: 28)
                    .background(segmentFill(for: mode), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.separator.opacity(colorScheme == .dark ? 0.24 : 0.18))
        )
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func segmentFill(for mode: TranscriptDisplayMode) -> Color {
        guard selection == mode else { return .clear }
        if colorScheme == .dark {
            return Color.white.opacity(0.16)
        }
        return Color.white.opacity(0.70)
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

enum TranscriptDisplayMode: String, CaseIterable, Identifiable {
    case detail
    case raw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .detail: "详情"
        case .raw: "原文"
        }
    }

    var systemImage: String {
        switch self {
        case .detail: "list.bullet.rectangle"
        case .raw: "doc.plaintext"
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
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
    }
}
