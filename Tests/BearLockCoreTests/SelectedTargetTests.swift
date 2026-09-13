import XCTest
@testable import BearLockCore

final class SelectedTargetTests: XCTestCase {
    func testSelectionAndDataCommitTogetherAndFailureKeepsBoth() async throws {
        let repository = SelectionRepository()
        let store = LockStore(repository: repository)
        let first = try await store.saveTargetSelection(LockTargetSelectionRef(tokenData: Data([1])))
        let original = try await store.snapshot()
        XCTAssertEqual(original.selectedTarget, first)
        repository.failWrite = true
        do {
            _ = try await store.saveTargetSelection(LockTargetSelectionRef(tokenData: Data([2])))
            XCTFail("Expected save failure")
        } catch {}
        let after = try await store.snapshot()
        XCTAssertEqual(after, original)
        repository.failWrite = false
        let second = try await store.saveTargetSelection(LockTargetSelectionRef(tokenData: Data([2])))
        try await store.selectTarget(id: first.id)
        let selected = try await store.snapshot()
        XCTAssertEqual(selected.selectedTarget, first)
        XCTAssertEqual(selected.targetSelections, [first, second])
        XCTAssertEqual(try JSONDecoder().decode(LockState.self, from: JSONEncoder().encode(selected)), selected)
        XCTAssertNil(LockState(targetSelections: [first, second]).selectedTarget)
    }

    func testSelectionCannotChangeDuringActivePeriod() async throws {
        let repository = SelectionRepository()
        let store = LockStore(repository: repository)
        let target = try await store.saveTargetSelection(LockTargetSelectionRef())
        let start = Date()
        _ = try await store.createRule(.now(duration: 60, targetSelectionID: target.id), now: start)
        let original = try await store.snapshot()
        do { try await store.selectTarget(id: UUID(), now: start); XCTFail() } catch {
            XCTAssertEqual(error as? LockValidationError, .activeLockIsImmutable)
        }
        do { _ = try await store.saveTargetSelection(LockTargetSelectionRef(), now: start); XCTFail() } catch {
            XCTAssertEqual(error as? LockValidationError, .activeLockIsImmutable)
        }
        let after = try await store.snapshot()
        XCTAssertEqual(after, original)
    }

    func testRecurringEncodingContainsNoSingleDatesAndDisplayUsesLatestEnd() throws {
        let now = ISO8601DateFormatter().date(from: "2026-09-08T01:00:00Z")!
        let rules = [(23,7), (0,8)].map { start,end in
            LockRule(recurrence: RecurrenceRule(weekdays: Set(Weekday.allCases),
                startsAt: TimeOfDay(hour: start,minute: 0), endsAt: TimeOfDay(hour: end,minute: 0),
                timeZoneIdentifier: "UTC"),targetSelectionID: UUID())
        }
        XCTAssertTrue(rules.allSatisfy { $0.single == nil })
        let encoded = try JSONEncoder().encode(rules)
        XCTAssertFalse(String(decoding: encoded,as: UTF8.self).contains("duration"))
        XCTAssertEqual(try JSONDecoder().decode([LockRule].self,from: encoded),rules)
        let display = LockState(rules: rules).activeLockForDisplay(at: now)
        XCTAssertEqual(display?.endsAt, ISO8601DateFormatter().date(from:"2026-09-08T08:00:00Z"))
    }
}

private final class SelectionRepository: LockRepository, @unchecked Sendable {
    var state = LockState()
    var failWrite = false
    func load() throws -> LockState { state }
    func save(_ state: LockState) throws {
        if failWrite { throw CocoaError(.fileWriteUnknown) }
        self.state = state
    }
    func withExclusiveAccess<T>(_ body: () throws -> T) throws -> T { try body() }
}
