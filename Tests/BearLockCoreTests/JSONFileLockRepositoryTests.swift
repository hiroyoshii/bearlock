import XCTest
@testable import BearLockCore

final class JSONFileLockRepositoryTests: XCTestCase {
    func testPersistsAndReloadsLockState() throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONFileLockRepository(fileURL: directory.appending(path: "state.json"))
        let targetID = UUID(uuidString: "11111111-AAAA-BBBB-CCCC-111111111111")!
        let ruleID = UUID(uuidString: "22222222-AAAA-BBBB-CCCC-222222222222")!
        let activeID = UUID(uuidString: "33333333-AAAA-BBBB-CCCC-333333333333")!
        let state = LockState(
            targetSelections: [
                LockTargetSelectionRef(id: targetID, displayName: "SNS, Video, Games", tokenData: Data([1, 2, 3]))
            ],
            recentLockTargets: [
                RecentLockTarget(
                    id: UUID(uuidString: "44444444-AAAA-BBBB-CCCC-444444444444")!,
                    targetSelectionID: targetID,
                    lastUsedAt: date("2026-08-27T22:00:00Z"),
                    pinnedAt: date("2026-08-27T22:05:00Z")
                )
            ],
            rules: [
                LockRule(
                    id: ruleID,
                    kind: .fixedDateTime,
                    startsAt: date("2026-08-27T23:00:00Z"),
                    duration: 2 * 60 * 60,
                    targetSelectionID: targetID
                )
            ],
            activeLock: ActiveLock(
                id: activeID,
                sourceRuleID: ruleID,
                startedAt: date("2026-08-27T23:00:00Z"),
                endsAt: date("2026-08-28T01:00:00Z"),
                targetSelectionID: targetID
            )
        )

        try repository.save(state)

        let reloaded = try JSONFileLockRepository(fileURL: directory.appending(path: "state.json")).load()
        XCTAssertEqual(reloaded, state)
    }

    func testLoadsStateSavedBeforeRecentTargetsWereAdded() throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stateURL = directory.appending(path: "state.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacyJSON = """
        {
          "targetSelections" : [],
          "rules" : [],
          "completedLocks" : []
        }
        """
        try legacyJSON.write(to: stateURL, atomically: true, encoding: .utf8)

        let state = try JSONFileLockRepository(fileURL: stateURL).load()

        XCTAssertEqual(state.recentLockTargets, [])
        XCTAssertEqual(state, LockState())
    }

    func testSaveTargetSelectionReplacesExistingSelectionWithSameID() async throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONFileLockRepository(fileURL: directory.appending(path: "state.json"))
        let store = try LockStore(repository: repository)
        let targetID = UUID(uuidString: "44444444-AAAA-BBBB-CCCC-444444444444")!

        try await store.saveTargetSelection(LockTargetSelectionRef(id: targetID, displayName: "Old Apps"))
        try await store.saveTargetSelection(LockTargetSelectionRef(id: targetID, displayName: "Updated Apps"))

        let state = try repository.load()
        XCTAssertEqual(state.targetSelections, [
            LockTargetSelectionRef(id: targetID, displayName: "Updated Apps")
        ])
    }

    func testCorruptedStateRemainsAnErrorOnRepeatedReads() throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stateURL = directory.appending(path: "state.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let broken = "{ broken json"
        try broken.write(to: stateURL, atomically: true, encoding: .utf8)
        let repository = JSONFileLockRepository(fileURL: stateURL)

        for _ in 0..<2 {
            XCTAssertThrowsError(try repository.load()) { error in
                guard case LockRepositoryError.corruptState = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
        }
        XCTAssertEqual(try String(contentsOf: stateURL), broken)
        XCTAssertEqual(try String(contentsOf: directory.appending(path: "state.corrupt.json")), broken)
    }

    func testIOFailureDoesNotQuarantineOrReturnEmptyState() throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stateURL = directory.appending(path: "state.json")
        // Reading a directory as JSON is an I/O error, without depending on chmod/root.
        try FileManager.default.createDirectory(at: stateURL, withIntermediateDirectories: true)
        let repository = JSONFileLockRepository(fileURL: stateURL)
        XCTAssertThrowsError(try repository.load()) { error in
            XCTAssertFalse(error is LockRepositoryError)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: stateURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appending(path: "state.corrupt.json").path))
    }

    func testFractionalDatesAndOccurrenceDeadlineRoundTrip() throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONFileLockRepository(fileURL: directory.appending(path: "state.json"))
        let end = date("2026-08-27T11:00:00Z").addingTimeInterval(0.125)
        let active = ActiveLock(sourceRuleID: nil, startedAt: end.addingTimeInterval(-1800), endsAt: end,
                                targetSelectionID: UUID(), scheduledEndsAt: end)
        try repository.save(LockState(activeLock: active))
        XCTAssertEqual(try repository.load().activeLock, active)
    }

    func testStoresReloadAndDoNotResurrectCompletedLock() async throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "state.json")
        let app = try LockStore(repository: JSONFileLockRepository(fileURL: url))
        let monitor = try LockStore(repository: JSONFileLockRepository(fileURL: url))
        let end = date("2026-08-27T11:00:00Z")
        let active = ActiveLock(sourceRuleID: nil, startedAt: end.addingTimeInterval(-1800), endsAt: end, targetSelectionID: UUID())
        try await app.activate(active)
        _ = try await monitor.completeActiveLock(at: end)
        _ = try await app.saveTargetSelection(LockTargetSelectionRef(displayName: "New"))
        let fresh = try await app.snapshot()
        XCTAssertNil(fresh.activeLock)
        XCTAssertEqual(fresh.completedLocks, [active])
        XCTAssertEqual(fresh.targetSelections.count, 1)
    }

    func testConcurrentRepositoryInstancesDoNotLoseUpdates() async throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "state.json")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<24 {
                group.addTask {
                    let store = try LockStore(repository: JSONFileLockRepository(fileURL: url))
                    _ = try await store.saveTargetSelection(LockTargetSelectionRef())
                }
            }
            try await group.waitForAll()
        }
        XCTAssertEqual(try JSONFileLockRepository(fileURL: url).load().targetSelections.count, 24)
    }

    private func uniqueTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "bearlock-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    private func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
}
