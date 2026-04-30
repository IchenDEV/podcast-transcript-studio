import XCTest
@testable import PodcastTranscriptStudioCore

@MainActor
final class AppViewModelPersistenceTests: XCTestCase {
    func test_bootstrap_loads_persisted_jobs() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let configuration = AppConfiguration.preview(baseDirectory: base)
        let repository = JobStoreRepository(configuration: configuration)
        let persisted = TranscriptionJob(filename: "persisted.m4a", status: .completed)
        try repository.save(jobs: [persisted])

        let viewModel = AppViewModel(configuration: configuration, repository: repository)
        try viewModel.bootstrap()

        XCTAssertEqual(viewModel.jobStore.jobs.count, 1)
        XCTAssertEqual(viewModel.jobStore.jobs[0].filename, "persisted.m4a")
        XCTAssertEqual(viewModel.selectedJob?.id, persisted.id)
    }
}
