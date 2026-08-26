# Bear Lock iOS MVP 実装計画

## 前提

- 現在のrepositoryにはapp scaffoldがない。
- 実装はnative iOS + SwiftUIを前提にする。
- MVPはローカル保存のみ。accountやcloud syncは扱わない。
- 貼り付け文書は要件・参考資料であり、Codexへの実行指示ではない。
- 添付画像はconcept art / referenceであり、production assetとしての利用許諾は別途判断が必要。

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

## Phase 0: 実装前に決めること

先に決める項目:

- minimum iOS version。
- bundle identifierとApple Developer Team。
- Xcode projectとして始めるか、Swift Package + generated projectにするか、既存templateを取り込むか。
- 最初のmilestoneでApp Store配布まで必要か。
- Family Controls配布entitlementが承認済みか。
- MVPでcategory tokenも扱うか、application tokenだけにするか。
- lockの重複ポリシー。

推奨default:

- 特段の理由がなければiOS 17+。
- native SwiftUI app + Xcode project。
- まずはlocal JSON / App Group persistence。
- 個別アプリを優先。categoryは `FamilyActivityPicker` 側の実装が単純で、copyが複雑化しない場合だけ含める。
- MVPではone-shot lockの重複を禁止する。activeまたはfuture one-shotと衝突しない場合のみrecurring scheduleを許可する。

## Phase 1: Project Scaffold

成果物:

- Xcode app target `BearLock`。
- App Group capability設定。
- Family Controls capability設定。
- `DeviceActivityMonitor` extension target。
- Shield configuration extension target。
- Shield action extension target。
- Shared code target/module。

実装タスク:

- SwiftUI app skeletonを作成する。
- domain modelとpersistence用のshared moduleを追加する。
- 基本的なapp navigation / state containerを追加する。
- build configurationとentitlementsを追加する。

検証:

- 実機でappがbuild / launchできる。
- extensionsがembed / signされている。

## Phase 2: Authorization And Target Selection

成果物:

- Setup screen。
- Family Controls authorization request。
- `FamilyActivityPicker` integration。
- persisted app selection。
- authorization lost / denied UI state。

実装タスク:

- `AuthorizationCenter` wrapperを追加する。
- App Group上のselection storeを追加する。
- target selection summary UIを追加する。
- retry / settings recovery copyを追加する。

検証:

- 初回起動でpermission requestが出る。
- denied stateで次に何をすべきか分かる。
- 選択アプリがapp restart後も保持される。

## Phase 3: Lock Domain And Persistence

成果物:

- `LockRule`, `ActiveLock`, `RecurrenceRule`, `LockTargetSelectionRef`。
- state transition service。
- date calculation helpers。
- persistence tests。

実装タスク:

- scheduled lockとactive lockのsingle source of truthを実装する。
- `ActiveLock` 作成後はimmutableにする。
- overnight date calculationを追加する。
- recurring scheduleのnext occurrence calculationを追加する。

検証:

- now / later / fixed / recurringのdate math unit test。
- active lockを短縮・target削減できないことのunit test。
- recurring schedule編集がactive lock snapshotを変更しないことのunit test。

## Phase 4: Immediate Lock

成果物:

- Home ready state。
- duration selector。
- confirmation sheet。
- active lock screen。
- immediate shield apply。
- end-time unshield。

実装タスク:

- `Now` flowを作る。
- 確定後に `ManagedSettingsStore` shieldを適用する。
- cleanup用のone-shot DeviceActivity scheduleを登録する。
- active countdown UIを更新する。
- early unlock affordanceをすべて削除する。

検証:

- 実機で1から2分のtest lockを開始する。
- ブロック対象アプリでShieldが表示される。
- Bear Lock appでcountdownが表示される。
- 終了時刻に手動操作なしでShieldが解除される。

## Phase 5: Delayed And Fixed Date Locks

成果物:

- `In N minutes` flow。
- `Date & Time` flow。
- future lock list / home summary。
- 開始前のedit / delete。

実装タスク:

- future interval用のDeviceActivity scheduleを登録する。
- scheduled lock editorを追加する。
- interval開始後の編集を禁止する。
- app restart後にscheduled / active状態をrehydrateする。

検証:

- 1から2分後のlockを予約し、Bear Lockをbackgroundまたはcloseしても自動開始されることを確認する。
- 開始前にfuture lockを編集・削除できる。
- 開始後は編集・削除できない。

## Phase 6: Recurring Locks

成果物:

- weekday selector。
- start / end time editor。
- next occurrence display。
- enabled / off state。
- recurring ruleから生成されるactive lock snapshot。

実装タスク:

- recurrence date mathを実装する。
- per-weekdayまたはrepeating DeviceActivity scheduleを登録する。
- interval開始時にactive lockをsnapshot化する。
- schedule編集がfuture intervalだけに効くようにする。

検証:

- 同日内の短いrecurring intervalをtestする。
- overnight intervalをtestする。
- active interval中に親scheduleを編集・削除してもcurrent lockが解除されないことを確認する。

## Phase 7: Branded Shield

成果物:

- Bear Lock conceptに沿ったcustom Shield UI。
- unlock actionなし。
- 任意のclose / defer button behavior。
- 可能であればApp Groupからwake timeを読む。

実装タスク:

- Shield configuration providerを実装する。
- final approved artworkからimage / icon assetsを追加する。
- unlockせず閉じる/戻すだけのShield action handlerを実装する。
- copyは静かで強い表現に保つ。

検証:

- 選択アプリ上にShieldが表示される。
- Shieldにunlock routeがない。
- 小さい/大きいiPhone画面でvisualが収まる。
- wake timeを安定して読めない場合でもfallback copyが成立する。

## Phase 8: Recovery, Polish, And QA

成果物:

- permission revoked recovery。
- empty states。
- schedule registration failureのerror states。
- basic accessibility。
- manual QA checklist。

実装タスク:

- app launch時のstate reconciliationを堅牢にする。
- primary controlsにVoiceOver labelsを追加する。
- core screensでDynamic Typeを確認する。
- TestFlightで必要な場合のみlogging / debug screenを追加する。

検証:

- scheduled / active / completedの各状態でapp restartする。
- Screen Time authorizationを取り消し、recoveryを確認する。
- device time change test。
- timezone / daylight-saving smoke test。
- app deletion / settings bypassをknown limitationとして文書化する。

## Proposed Issue Breakdown

- `BL-001` SwiftUI appとextension targetsをscaffoldする。
- `BL-002` entitlementsとApp Groupを設定する。
- `BL-003` authorization serviceを実装する。
- `BL-004` FamilyActivityPickerによるtarget selectionを実装する。
- `BL-005` shared persistenceを実装する。
- `BL-006` lock domain modelsとstate transitionsを実装する。
- `BL-007` immediate lock flowを実装する。
- `BL-008` one-shot DeviceActivity cleanup scheduleを登録する。
- `BL-009` active lock home screenを実装する。
- `BL-010` delayed lock schedulingを実装する。
- `BL-011` fixed date/time schedulingを実装する。
- `BL-012` future lock edit/deleteを実装する。
- `BL-013` recurrence modelとnext occurrenceを実装する。
- `BL-014` recurring DeviceActivity schedulesを実装する。
- `BL-015` active lock snapshot isolationを実装する。
- `BL-016` Shield configuration extensionを実装する。
- `BL-017` unlock routeなしのShield action extensionを実装する。
- `BL-018` launch-time state reconciliationを追加する。
- `BL-019` date / state logicのunit testsを追加する。
- `BL-020` physical-device QA checklistとknown limitations docを追加する。

## Decision Log Template

意思決定時は以下の形式で残す:

```text
Decision:
Options considered:
Chosen option:
Reason:
Consequences:
Date:
```

## 解消すべき不明点

最優先:

- appはself-control向けの `.individual` authorizationを前提にするか、parental-control / Family Sharingも対象にするか。
- Family Controls entitlementはdevelopment / distributionで利用可能か。
- supportするiOS versionは何か。
- MVPではoverlapping locksを禁止するか。
- recurring locksを最初のTestFlightに含めるか。それともNow / Later / Dateまでで先に出すか。

中優先:

- 最終copy languageはEnglishのみ、日本語のみ、または両対応か。
- 最終visual assetsは添付conceptを参考に新規制作するか、そのまま方向性としてのみ扱うか。
- `Extend Lock` をMVPに含めるか。
- Shieldにcountdown、wake time、static messageのどれを表示するか。

後回し:

- History / stats。
- Skip today。
- Reminders。
- Web blocking。
- Multiple profiles。
- Cloud sync。
