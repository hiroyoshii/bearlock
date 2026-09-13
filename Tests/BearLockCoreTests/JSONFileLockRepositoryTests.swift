import XCTest
@testable import BearLockCore

final class JSONFileLockRepositoryTests: XCTestCase {
    func testPersistsAndReloadsLockState() throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONFileLockRepository(fileURL: directory.appending(path: "state.json"))
        let targetID = UUID(uuidString: "11111111-AAAA-BBBB-CCCC-111111111111")!
        let ruleID = UUID(uuidString: "22222222-AAAA-BBBB-CCCC-222222222222")!
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
            ]
        )

        try repository.save(state)

        let reloaded = try JSONFileLockRepository(fileURL: directory.appending(path: "state.json")).load()
        XCTAssertEqual(reloaded, state)
    }

    func testSaveTargetSelectionReplacesExistingSelectionWithSameID() async throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONFileLockRepository(fileURL: directory.appending(path: "state.json"))
        let store = LockStore(repository: repository)
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

    func testFractionalRuleDatesRoundTripWithoutPersistingExecutionState() throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "state.json")
        let repository = JSONFileLockRepository(fileURL: url)
        let end = date("2026-08-27T11:00:00Z").addingTimeInterval(0.125)
        let rule = LockRule(kind: .immediate, startsAt: end.addingTimeInterval(-1800), duration: 1800, targetSelectionID: UUID())
        let state = LockState(rules: [rule])
        try repository.save(state)
        XCTAssertEqual(try repository.load(), state)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["targetSelections", "recentLockTargets", "rules"])
        XCTAssertTrue(try repository.load().activeLocks(at: end).isEmpty)
    }

    func testFreshReadsSeeRuleDeletedByAnotherStore() async throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "state.json")
        let app = LockStore(repository: JSONFileLockRepository(fileURL: url))
        let other = LockStore(repository: JSONFileLockRepository(fileURL: url))
        let now = date("2026-08-27T10:00:00Z")
        let rule = try await app.createRule(.delayed(delay: 3600, duration: 3600, targetSelectionID: UUID()), now: now)
        try await other.deleteRule(id: rule.id, now: now)
        _ = try await app.saveTargetSelection(LockTargetSelectionRef(displayName: "New"))
        let fresh = try await app.snapshot()
        XCTAssertTrue(fresh.rules.isEmpty)
        XCTAssertEqual(fresh.targetSelections.count, 1)
    }

    func testConcurrentRepositoryInstancesDoNotLoseUpdates() async throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "state.json")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<24 {
                group.addTask {
                    let store = LockStore(repository: JSONFileLockRepository(fileURL: url))
                    _ = try await store.saveTargetSelection(LockTargetSelectionRef())
                }
            }
            try await group.waitForAll()
        }
        XCTAssertEqual(try JSONFileLockRepository(fileURL: url).load().targetSelections.count, 24)
    }

    func testMonitoringSynchronizationReloadsAndReleasesFileLockBeforeCallingOS() async throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "state.json")
        let store = LockStore(repository: JSONFileLockRepository(fileURL: url))
        _ = try await store.snapshot() // UI snapshot predates the new rule.
        let now = Date()
        let rule = try await store.createRule(.delayed(delay: 3600, duration: 900, targetSelectionID: UUID()), now: now)
        try await store.synchronizeMonitoring { rules, _ in
            XCTAssertEqual(rules, [rule])
            // A synchronous OS callback uses a separate repository/process.
            // It must be able to acquire the file lock while registration is in progress.
            let done = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                defer { done.signal() }
                do {
                    let callbackState = try JSONFileLockRepository(fileURL: url).load()
                    XCTAssertEqual(callbackState.rules, [rule])
                } catch { XCTFail("Callback could not read: \(error)") }
            }
            XCTAssertEqual(done.wait(timeout: .now() + 2), .success)
        }
    }

    private func uniqueTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "bearlock-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    private func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
}
