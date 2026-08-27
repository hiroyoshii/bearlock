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

    func testCorruptedStateIsQuarantinedAndLoadsEmptyState() throws {
        let directory = uniqueTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stateURL = directory.appending(path: "state.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "{ broken json".write(to: stateURL, atomically: true, encoding: .utf8)

        let state = try JSONFileLockRepository(fileURL: stateURL).load()
        let quarantinedFiles = try FileManager.default.contentsOfDirectory(atPath: directory.path)

        XCTAssertEqual(state, LockState())
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL.path))
        XCTAssertTrue(quarantinedFiles.contains { $0.hasPrefix("state.corrupt-") && $0.hasSuffix(".json") })
    }

    private func uniqueTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "bearlock-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    private func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
}
