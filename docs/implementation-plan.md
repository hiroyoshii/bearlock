# iOS初期実装の記録（2026-08-27）

現行の製品仕様と構造は [設計正本](design-doc.md)、現在の作業進捗は [TODO](../todo.md) を参照する。初期MVPの未採用フェーズ・課題候補・未決事項・雛形は削除した。以下は当時の版の実装記録であり、現行仕様ではない。初期の解除不可コピー・ActiveLock保存・Completed化は現行の正本を上書きしない。

## 実装状況

2026-08-27時点:

- `Package.swift` と `BearLockCore` を追加済み。
- `LockRule`, `ActiveLock`, `RecurrenceRule`, `LockStore`, `LockPlanner` を実装済み。
- now / delayed / fixed / recurringのdate mathとimmutability test scaffoldを追加済み。
- SwiftUI host app sourceを追加済み。
- Family Controls authorization、`FamilyActivityPicker`、ManagedSettings shield、DeviceActivity scheduleのservice wrapperを追加済み。
- Device Activity Monitor、Shield Configuration、Shield Action extension sourceを追加済み。
- `project.yml` を追加済み。macOS上のXcodeGenでXcode project生成する前提。
- WSL環境にSwift 6.3.3をSwiftlyで導入済み。
- `swift test` は `BearLockCore` で成功済み。2026-08-27時点で10 tests / 0 failures。
- Phase 4のImmediate Lock flowは、専用confirmation sheet、no early unlock copy、schedule登録失敗時の中途半端なactive状態回避、active保存失敗時のschedule rollbackまで実装済み。
- Phase 5のDelayed / Fixed Date lockは、開始前編集UI、開始済みruleの編集拒否、編集時のschedule上書き/rollback、restart時のscheduled -> active復元、期限切れone-shot ruleのcompleted化まで実装済み。
- Phase 6のRecurring Locksは、recurring専用編集UI、weekday/start/end編集、enabled/off toggle、次回実行表示、active中の親recurring rule編集許可とactive lock snapshot不変性のtestまで実装済み。
- `swift test` は2026-08-27時点で20 tests / 0 failures。
- GitHub Actions workflowを追加済み。`macos-15`上でXcodeGen生成、core test、iOS Simulator build、UI launch test、Simulator screenshot artifact保存を行う。
- Xcode / XcodeGen / iOS実機testはmacOS側が必要なため未実行。
