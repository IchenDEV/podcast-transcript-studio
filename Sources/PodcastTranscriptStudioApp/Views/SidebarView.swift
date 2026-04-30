import SwiftUI
import PodcastTranscriptStudioCore

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        List(selection: selectionBinding) {
            ForEach(viewModel.jobStore.jobs) { job in
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.filename).font(.headline)
                    Text(job.status.rawValue).font(.caption).foregroundStyle(.secondary)
                }
                .tag(job.id)
            }
        }
        .navigationTitle("任务")
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedJobID },
            set: { viewModel.select(jobID: $0) }
        )
    }
}
