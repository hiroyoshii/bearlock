import XCTest
@testable import BearLockCore

final class LockContractTests: XCTestCase {
    func testSharedContract() throws {
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ContractFixtures/lock-contract.tsv")
        let rows = try String(contentsOf: path).split(separator: "\n")
            .filter { !$0.hasPrefix("#") }.map { $0.split(separator: " ").map(String.init) }
        XCTAssertEqual(rows.count, 22)
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
                XCTAssertEqual((try? rules[index].validateEditable(at: now)) != nil, c[10] == "-", name)
                XCTAssertEqual(active?.startedAt, c[10] == "-" ? nil : time(c[10]), name)
                XCTAssertEqual(active?.endsAt, c[11] == "-" ? nil : time(c[11]), name)
            }
            XCTAssertEqual(Set(try state.selectionsToShield(at: now).map(\.displayName)),
                           Set(group.filter { $0[11] != "-" }.map { $0[1] }), name)
            for (label, target) in targets {
                let end = group.filter { $0[1] == label && $0[11] != "-" }.map { time($0[11]) }.max()
                XCTAssertEqual(locks.filter { $0.targetSelectionID == target.id }.map(\.endsAt).max(), end, name)
            }
        }
    }
}
