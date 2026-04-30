import XCTest
@testable import PodcastTranscriptStudioCore

@MainActor
final class JobStoreTests: XCTestCase {
    func test_add_update_and_sort_jobs() {
        let store = JobStore()
        let old = TranscriptionJob(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, filename: "old.m4a", createdAt: Date(timeIntervalSince1970: 100))
        let new = TranscriptionJob(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, filename: "new.m4a", createdAt: Date(timeIntervalSince1970: 200))

        store.upsert(old)
        store.upsert(new)
        store.updateStatus(for: old.id, status: .completed)

        XCTAssertEqual(store.jobs.map(\.filename), ["new.m4a", "old.m4a"])
        XCTAssertEqual(store.job(id: old.id)?.status, .completed)
    }
}
