import XCTest
@testable import BearLockCore

final class LockContractTests: XCTestCase {
    func testSharedHistoryOperations() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let fixture = try JSONDecoder().decode(OperationFixture.self,
            from: Data(contentsOf: root.appendingPathComponent("ContractFixtures/lock-operations.json")))
        let specification = try String(contentsOf: root.deletingLastPathComponent().appendingPathComponent("docs/design-doc.md"))
        XCTAssertEqual(fixture.version, 1)
        XCTAssertFalse(fixture.historyCases.isEmpty)
        let allIDs = fixture.cases.map(\.id) + fixture.historyCases.map(\.id)
        XCTAssertEqual(Set(allIDs).count, allIDs.count)
        let epoch = Date(timeIntervalSince1970: 1_800_000_000)
        func time(_ seconds: Double) -> Date { epoch.addingTimeInterval(seconds) }
        for scenario in fixture.historyCases {
            let contract = scenario.id.split(separator: ".").first!
            XCTAssertTrue(specification.contains("- \(contract):"), scenario.id)
            let targets = Dictionary(uniqueKeysWithValues: scenario.recent.map { ($0.target, LockTargetSelectionRef(displayName: $0.target)) })
            let recent = scenario.recent.map { RecentLockTarget(targetSelectionID: targets[$0.target]!.id,
                lastUsedAt: time($0.usedAt), pinnedAt: $0.pinnedAt.map(time)) }
            let rule = LockRule(kind: .fixedDateTime, startsAt: epoch, duration: 7200, targetSelectionID: targets["A"]!.id)
            let initial = LockState(targetSelections: Array(targets.values), recentLockTargets: recent, rules: [rule],
                selectedTargetID: targets["A"]!.id, wakeState: WakeState(requests: [WakeRequest(ruleID: rule.id,
                    occurrenceStartedAt: epoch, requestedAt: epoch, wakesAt: time(1800), source: .delayed)]))
            let repository = ContractRepository(state: initial)
            let store = LockStore(repository: repository)
            func label(_ item: RecentLockTarget) -> String { targets.first { $0.value.id == item.targetSelectionID }!.key }
            XCTAssertFalse(scenario.steps.isEmpty)
            for (index, step) in scenario.steps.enumerated() {
                let name = "\(scenario.id)/\(index):\(step.action.rawValue)"
                let original = repository.state
                var result = "ok"
                do {
                    if step.action != .evaluate {
                        let item = try XCTUnwrap(original.recentLockTargets.first { label($0) == step.target })
                        switch step.action {
                        case .pin, .unpin:
                            try await store.setRecentLockTargetPinned(id: item.id, pinned: step.action == .pin, at: time(step.at))
                        case .delete: try await store.deleteRecentLockTarget(id: item.id)
                        case .evaluate: break
                        }
                    }
                } catch {
                    result = error as? RecentLockTargetError == .pinnedTargetLimitReached ? "pinLimit" : "unexpected:\(error)"
                    XCTAssertEqual(repository.state, original, name)
                }
                let state = repository.state
                XCTAssertEqual(result, step.result, name)
                XCTAssertEqual(state.recentLockTargets.count, step.stored.count, name)
                XCTAssertEqual(Set(state.recentLockTargets.map(label)), Set(step.stored), name)
                XCTAssertEqual(Set(state.recentLockTargets.filter(\.isPinned).map(label)), Set(step.pinned), name)
                XCTAssertEqual(state.displayedRecentLockTargets().map(label), step.displayed, name)
                XCTAssertEqual(state.rules, initial.rules, name)
                XCTAssertEqual(state.wakeState, initial.wakeState, name)
                XCTAssertEqual(state.selectedTargetID, initial.selectedTargetID, name)
                XCTAssertEqual(state.targetSelections, initial.targetSelections, name)
            }
        }
    }

    func testSharedOperations() async throws {
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ContractFixtures/lock-operations.json")
        let fixture = try JSONDecoder().decode(OperationFixture.self, from: Data(contentsOf: path))
        XCTAssertEqual(fixture.version, 1)
        XCTAssertFalse(fixture.cases.isEmpty)
        XCTAssertEqual(Set(fixture.cases.map(\.id)).count, fixture.cases.count)
        let specificationPath = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("docs/design-doc.md")
        let specification = try String(contentsOf: specificationPath)
        let epoch = Date(timeIntervalSince1970: 1_800_000_000)
        func time(_ seconds: Double) -> Date { epoch.addingTimeInterval(seconds) }
        for scenario in fixture.cases {
            let contractID = scenario.id.split(separator: ".").first.map(String.init) ?? ""
            XCTAssertTrue(specification.contains("- \(contractID):"), "Undeclared contract: \(scenario.id)")
            XCTAssertFalse(scenario.steps.isEmpty, scenario.id)
            let target = LockTargetSelectionRef(displayName: "A")
            let otherTarget = LockTargetSelectionRef(displayName: "B")
            let rule = LockRule(kind: .fixedDateTime, startsAt: time(scenario.start ?? 0),
                                duration: scenario.duration, targetSelectionID: target.id)
            let repository = ContractRepository(state: LockState(targetSelections: [target, otherTarget], rules: [rule], selectedTargetID: target.id))
            let store = LockStore(repository: repository)
            for (index, step) in scenario.steps.enumerated() {
                let name = "\(scenario.id)/\(index):\(step.action.rawValue)"
                let original = repository.state
                let now = time(step.at)
                let id = step.rule == "missing" ? UUID() : rule.id
                let requestedLock = ActiveLock(id: id, startedAt: time(step.occurrenceStart ?? scenario.start ?? 0),
                    endsAt: time((scenario.start ?? 0) + scenario.duration), targetSelectionID: target.id)
                var result = "ok"
                do {
                    switch step.action {
                    case .wake: _ = try await store.scheduleFreeWake(for: requestedLock, at: now)
                    case .cancel: try await store.cancelFreeWake(for: requestedLock, at: now)
                    case .evaluate: break
                    case .select: _ = try await store.saveTargetSelection(otherTarget, now: now)
                    case .create:
                        // A different target must not make an overlapping single lock valid.
                        _ = try await store.createRule(.fixed(startsAt: time(try XCTUnwrap(step.start)),
                            duration: try XCTUnwrap(step.duration), targetSelectionID: otherTarget.id), now: now)
                    case .replace:
                        var replacement = rule
                        replacement.schedule = .single(SingleLockSchedule(kind: .fixedDateTime,
                            startsAt: time(try XCTUnwrap(step.start)), duration: try XCTUnwrap(step.duration)))
                        try await store.replaceRule(replacement, now: now)
                    case .delete: try await store.deleteRule(id: rule.id, now: now)
                    }
                } catch {
                    switch error {
                    case WakeError.freeWakeUnavailable: result = "wakeUnavailable"
                    case WakeError.activeLockNotFound: result = "inactiveOccurrence"
                    case WakeError.noWakeRequest: result = "noWakeRequest"
                    case LockValidationError.overlappingLock: result = "overlap"
                    case LockValidationError.activeLockIsImmutable: result = "activeImmutable"
                    case LockValidationError.ruleNotFound: result = "missingRule"
                    default: result = "unexpected:\(error)"
                    }
                    XCTAssertEqual(repository.state, original, "\(name): rejection must not mutate state")
                }
                XCTAssertEqual(result, step.result, name)
                let state = try await store.snapshot(at: now)
                XCTAssertEqual(state.rules.count, step.ruleCount, name)
                if let selection = step.selection {
                    XCTAssertEqual(state.selectedTarget?.displayName, selection, name)
                }
                if [.wake, .cancel, .evaluate].contains(step.action) {
                    XCTAssertEqual(state.rules, original.rules, "\(name): wake must not rewrite schedules")
                }
                if step.result == "ok", step.action == .replace {
                    let saved = try XCTUnwrap(state.rules.first { $0.id == rule.id }?.single)
                    XCTAssertEqual(saved.startsAt, time(try XCTUnwrap(step.start)), name)
                    XCTAssertEqual(saved.duration, step.duration, name)
                }
                if step.result == "ok", step.action == .create {
                    let saved = try XCTUnwrap(state.rules.first { $0.id != rule.id })
                    XCTAssertEqual(saved.single?.startsAt, time(try XCTUnwrap(step.start)), name)
                    XCTAssertEqual(saved.single?.duration, step.duration, name)
                    XCTAssertEqual(saved.targetSelectionID, otherTarget.id, name)
                }
                XCTAssertEqual(state.wakeState.requests.first { $0.ruleID == rule.id }?.wakesAt,
                               step.wakeAt.map(time), name)
                XCTAssertEqual(state.activeLocks(at: now).contains { $0.id == rule.id }, step.active, name)
            }
        }
    }

    func testSharedWakeContract() throws {
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ContractFixtures/wake-contract.tsv")
        let rows = try String(contentsOf: path).split(separator: "\n")
            .filter { !$0.hasPrefix("#") }.map { $0.split(separator: " ").map(String.init) }
        XCTAssertFalse(rows.isEmpty)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        func time(_ value: String) -> Date { start.addingTimeInterval(Double(value)!) }
        for c in rows {
            let rule = LockRule(kind: .immediate, startsAt: start, duration: 7200,
                                targetSelectionID: UUID())
            let lock = ActiveLock(id: rule.id, startedAt: start, endsAt: start.addingTimeInterval(7200),
                                  targetSelectionID: rule.targetSelectionID)
            let requests: [WakeRequest] = c[2] == "-" ? [] : [WakeRequest(
                ruleID: c[2] == "current" ? rule.id : UUID(), occurrenceStartedAt: time(c[3]),
                requestedAt: start, wakesAt: time(c[4]), source: .delayed)]
            let state = LockState(rules: [rule], wakeState: WakeState(requests: requests))
            XCTAssertEqual(state.wakeState.effectiveEnd(of: lock), time(c[5]), c[0])
            XCTAssertEqual(state.activeLocks(at: time(c[1])).contains { $0.id == rule.id },
                           c[6] == "true", c[0])
        }
    }

    func testSharedContract() throws {
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ContractFixtures/lock-contract.tsv")
        let rows = try String(contentsOf: path).split(separator: "\n")
            .filter { !$0.hasPrefix("#") }.map { $0.split(separator: " ").map(String.init) }
        XCTAssertFalse(rows.isEmpty)
        let formatter = ISO8601DateFormatter()
        func time(_ text: String) -> Date { formatter.date(from: text)! }
        for (name, group) in Dictionary(grouping: rows, by: { $0[0] }) {
            let now = time(group[0][9])
            let targets = Dictionary(uniqueKeysWithValues: Set(group.map { $0[1] }).map {
                ($0, LockTargetSelectionRef(displayName: $0))
            })
            let rules = group.map { c in
                let start = Int(c[3])!, end = Int(c[4])!
                let recurrence: RecurrenceRule? = c[2] == "-" ? nil : RecurrenceRule(
                    weekdays: Set(c[2].split(separator: ",").map { Weekday(rawValue: Int($0)! % 7 + 1)! }),
                    startsAt: TimeOfDay(hour: start / 60, minute: start % 60),
                    endsAt: TimeOfDay(hour: end / 60, minute: end % 60), timeZoneIdentifier: c[5])
                var rule = recurrence.map { LockRule(recurrence: $0, targetSelectionID: targets[c[1]]!.id) }
                    ?? LockRule(kind: .fixedDateTime, startsAt: time(c[7]),
                        duration: time(c[8]).timeIntervalSince(time(c[7])), targetSelectionID: targets[c[1]]!.id)
                rule.status = c[6] == "true" ? .scheduled : .disabled
                return rule
            }
            let state = LockState(targetSelections: Array(targets.values), rules: rules)
            let locks = state.activeLocks(at: now)
            for (index, c) in group.enumerated() {
                let active = locks.first { $0.id == rules[index].id }
                XCTAssertEqual((try? state.validateEditable(rules[index], at: now)) != nil, c[10] == "-", name)
                XCTAssertEqual(active?.startedAt, c[10] == "-" ? nil : time(c[10]), name)
                XCTAssertEqual(active?.endsAt, c[11] == "-" ? nil : time(c[11]), name)
            }
            XCTAssertEqual(Set(try state.shieldSlotDecisions(at: now).map(\.selection.displayName)),
                           Set(group.filter { $0[11] != "-" }.map { $0[1] }), name)
            for (label, target) in targets {
                let end = group.filter { $0[1] == label && $0[11] != "-" }.map { time($0[11]) }.max()
                XCTAssertEqual(locks.filter { $0.targetSelectionID == target.id }.map(\.endsAt).max(), end, name)
            }
        }
    }
}

private struct OperationFixture: Decodable {
    let version: Int
    let cases: [Scenario]
    let historyCases: [HistoryScenario]
    struct HistoryScenario: Decodable {
        let id: String
        let recent: [Recent]
        let steps: [HistoryStep]
    }
    struct Recent: Decodable {
        let target: String
        let usedAt: Double
        let pinnedAt: Double?
    }
    struct HistoryStep: Decodable {
        enum Action: String, Decodable { case pin, unpin, delete, evaluate }
        let action: Action
        let target: String?
        let at: Double
        let result: String
        let stored: [String]
        let pinned: [String]
        let displayed: [String]
    }
    struct Scenario: Decodable {
        let id: String
        let start: Double?
        let duration: Double
        let steps: [Step]
    }
    struct Step: Decodable {
        enum Action: String, Decodable { case wake, cancel, evaluate, create, replace, delete, select }
        let action: Action
        let at: Double
        let rule: String?
        let occurrenceStart: Double?
        let start: Double?
        let duration: Double?
        let result: String
        let wakeAt: Double?
        let active: Bool
        let ruleCount: Int
        let selection: String?
    }
}

private final class ContractRepository: LockRepository, @unchecked Sendable {
    var state: LockState
    init(state: LockState) { self.state = state }
    func load() throws -> LockState { state }
    func save(_ state: LockState) throws { self.state = state }
}
