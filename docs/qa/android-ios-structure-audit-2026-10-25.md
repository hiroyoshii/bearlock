# 仕様・責務・コード・テストの対応表

初回調査: 2026-10-25。基準と対応の再整理: 2026-10-26。対象は現在の作業ツリーであり、配布済みAPK/iOS版の適合宣言ではない。

iOS全体のSDK/シミュレーター検証は第14節、main側の統合記録は第15節、StoreKit追跡は第16節、購入失敗表示の統一と検証は第17節。今回のmain取込み後の確認は第18節。第8〜12節の「未実行」は各記録時点の状態であり、実機・Android固有の未確認は引き続き未確認とする。

## 1. 何を基準に、何を判定するか

目的は、製品コードを共有せず、両OSで共通仕様を守り、意図的な差を維持できる構造・テストにすること。

- 製品の要求は [design-docの比較基準](../design-doc.md#baseline)、[共通仕様](../design-doc.md#common)、[iOS仕様](../design-doc.md#ios)、[Android仕様](../design-doc.md#android)、[UI仕様](../design-doc.md#ui) が正本。本書は要求を追加しない。
- その要求を誰が保証するかは、正本の [R01〜R06](../design-doc.md#responsibilities) が基準。論理的な担当であり、同じclass・ファイル分割を要求しない。
- 本書は「基準ID → 責務 → iOSの担当 → Androidの担当 → 適合状況 → テスト」を対応付ける。単なる実装差を不具合と呼ばない。
- 期待結果が未定義なら「仕様判断待ち」。期待結果はあるが確認できていなければ「未判定/検証不足」。基準を満たさない根拠がある場合にだけ「保証不足/不適合」とする。

### 判定と証拠の意味

| 表記 | 意味 |
|---|---|
| 整合確認 | 指定した範囲でソースと既存テストが要求に整合。全入力・実機までの保証ではない |
| 保証不足 | 明示した条件を保証すべき境界に検証/保持が欠ける。ユーザー操作での不具合再現とは分ける |
| 未判定 | コード確認だけでは満たす/満たさないを決められない。必要な試験も記載する |
| 仕様判断待ち | 正本から期待結果が一意に定まらない。不適合判定や恒久テスト期待値を決めない |
| 対象外 | 意図的なOS差。相手OSへの移植を要求しない |
| コード | 現行の処理・呼び出し・型を確認した証拠 |
| 自動 | 存在する単体/統合/UI試験。今回実行したかは末尾の検証記録で区別 |
| 実動 | 署名済みSDK・emulator・実機での結果。単体テストをこれに読み替えない |

テスト欄の記載は確認できる範囲を示すもので、その基準を完全に網羅したという意味ではない。

## 2. 責務の基準と現行の担当

以下の「不足」はRの保証条件に対するもの。新しいApplication classやViewModelを作ることを完了条件にしない。

| 基準 | iOSの現行担当・経路 | Androidの現行担当・経路 | 対応状況と必要な検証 |
|---|---|---|---|
| R01 | 作成/編集ViewのState、TargetSelectionButton、RootView、WakeOptionsDialog | EditorDraft、Route、TargetPicker、MainActivity.showWakeOptions | 対象選択の下書きを維持。iOSは起床dialogのBoolをActiveLockの保持へ置換し、確認時のID/発生回を固定。Androidも開いたidentityを保持する。Coreの古い回拒否を共有試験、アプリ入口の保持/拒否を各OSの操作試験で検証。取り込んだiOS SDK/AppModel/mock UIの実行結果は第14節。統合後のSDK実行と実機は未確認 |
| R02 | LockPlanner、RecurrenceRule、LockState、WakeState、ShieldSlotPlanner | Planner、Rule、State、Domain | SDKなしで判定できる点は整合。正常入力の発生回/起床/競合は共有データで一部検証。複数要求や不正zoneの結果はD03/D07で未定義。ファイル数が違うことは問題ではない |
| R03 | 対象選択/予定/無料起床/履歴はAppModel.performSavedOperation→LockStore actor→fresh load/validate/save | 対象選択/予定/無料起床/履歴はLockOperations→Store.change→Planner | 保存時刻/最新状態再検証と保存→必要な反映→結果を対応させた。画面内の直接保存と履歴用mutate経路を除去。履歴のpin/解除/削除はOS反映不要。iOSの削除予約取消も同じ入口。取り込んだSDK/mockの実行結果と実機未確認は第14節で区別。予定作成と履歴記録の原子性はD06で判断待ち |
| R04 | LockRepository protocol、JSONFileLockRepository、App Group | Storeの共有guard/AtomicFile、Codec、schema移行 | 原子的更新と原本保持はコード/故障テストに整合。プロセス構成/JSONを揃える必要なし。不正形式のすべての意味的検証を確認したわけではない |
| R05 | ScheduleController、ShieldController、Monitor/Shield Configuration拡張 | Scheduling、BoundaryReceiver、GuardService、Shield、SnapshotGate | 最新状態から再評価し、登録失敗と期限判定を分離する経路がある。取り込んだiOS SDKビルド/mock UIの実行結果は第14節。実OS遮断/実機は未判定。iOS容量事前検査の範囲はD08 |
| R06 | AppModelのOperationOutcome/readStatus/monitoringUpdateFailed、Home/Root/Settings、作成/編集View | LockOperationsのOperationOutcome、MainActivityの結果表示/statusWarnings、Composer | 対象選択/予定/無料起床は保存拒否と保存後反映失敗を区別。履歴の保存後読込失敗はiOSのsavedNeedsReload/readStatus.failedで保存拒否と区別。OS反映の不要な履歴変更で既存の監視エラーを消さない。終了表示/代表選択はD01。課金配送は別経路 |

### 主要コードへの入口

| 領域 | iOS | Android |
|---|---|---|
| モデル/判定 | [LockModels](../../Sources/BearLockCore/LockModels.swift)、[LockPlanner](../../Sources/BearLockCore/LockPlanner.swift)、[RecurrenceRule](../../Sources/BearLockCore/RecurrenceRule.swift)、[WakePolicy](../../Sources/BearLockCore/WakePolicy.swift)、[ShieldSlotPlanner](../../Sources/BearLockCore/ShieldSlotPlanner.swift) | [Planner.kt](../../android-lab/product/src/main/java/com/hiyozoo/bearlock/Planner.kt) |
| 更新/保存 | [LockState/LockStore](../../Sources/BearLockCore/LockRepository.swift)、[JSON repository](../../Sources/BearLockCore/JSONFileLockRepository.swift)、[AppModel](../../BearLock/App/BearLockAppModel.swift) | [LockOperations](../../android-lab/product/src/main/java/com/hiyozoo/bearlock/LockOperations.kt)、[Store/Codec](../../android-lab/product/src/main/java/com/hiyozoo/bearlock/Store.kt)、[MainActivity](../../android-lab/product/src/main/java/com/hiyozoo/bearlock/MainActivity.kt) |
| 下書き/確認 | [LockComposerView](../../BearLock/Features/Schedule/LockComposerView.swift)、[RecurringRuleEditorView](../../BearLock/Features/Schedule/RecurringRuleEditorView.swift)、[TargetSelectionButton](../../BearLock/Features/TargetSelection/TargetSelectionButton.swift) | [EditorState](../../android-lab/product/src/main/java/com/hiyozoo/bearlock/EditorState.kt)、[Composer](../../android-lab/product/src/main/java/com/hiyozoo/bearlock/Composer.kt)、[TargetPicker](../../android-lab/product/src/main/java/com/hiyozoo/bearlock/TargetPicker.kt) |
| 起床の入口/表示 | [RootView](../../BearLock/App/RootView.swift)、[WakeOptionsView](../../BearLock/Features/Home/WakeOptionsView.swift)、[WakeLaunchRequest](../../BearLock/Services/WakeLaunchRequest.swift)、[ActiveLockView](../../BearLock/Features/Home/ActiveLockView.swift) | MainActivity.onResume/showWakeOptions/changeWake、[HomeComponents](../../android-lab/product/src/main/java/com/hiyozoo/bearlock/HomeComponents.kt) |
| OS適用 | [MonitoringSchedule](../../Sources/BearLockCore/MonitoringSchedule.swift)、[ScheduleController](../../BearLock/Services/ScheduleController.swift)、[ShieldController](../../BearLock/Services/ShieldController.swift)、[Monitor](../../BearLock/Extensions/DeviceActivityMonitor/BearLockMonitorExtension.swift)、[Shield reader](../../BearLock/Extensions/ShieldConfiguration/ShieldActiveLockReader.swift) | [Scheduling/Receiver](../../android-lab/product/src/main/java/com/hiyozoo/bearlock/BoundaryReceiver.kt)、[GuardService](../../android-lab/product/src/main/java/com/hiyozoo/bearlock/GuardService.kt)、[Shield](../../android-lab/product/src/main/java/com/hiyozoo/bearlock/Shield.kt) |

## 3. 共通仕様とコード・テストの対応

この節は正本の共通仕様に付けた全IDを扱う。「共通テストなし」は要求が未実装という意味ではない。

| 基準ID / 責務 | iOSの担当 | Androidの担当 | 適合状況 / 既存テストと不足 |
|---|---|---|---|
| TGT-00 / R01,R05 | FamilyActivityTargetSelectionCodec、FamilyActivityPicker | Targets、Catalog、TargetPicker、GuardService | 取得/制限能力はOS別で整合。Picker UI/native試験あり。SDK実動の同一能力は要求しない |
| TGT-01 / R03,R04 | LockState、LockStore.recordRecentLockTarget、JSON repository | State、Planner.save、Store/Codec | 選択/予定/再利用履歴の区別は整合。JSON repository/Codec、SelectedTarget試験あり。作成と履歴の同時保存までは定義されずD06 |
| TGT-02 / R01,R03 | Viewの下書き→AppModel.performSavedOperation→LockStore.saveTargetSelection/selectTarget | EditorDraft/Route→LockOperations.selectTargets→Planner.selectTargets | 両OSの保存区間内チェックに対応。共有操作列に開始直前/開始時の選択保存を追加。AndroidはLockOperationsTestで区間に入る前の状態/時刻変化と拒否時の原本保持を確認。実画面の下書き保持・失敗表示もRecoveryInstrumentationへ追加 |
| TGT-03 / R02,R03,R06 | AppModel.performSavedOperation→LockStore.setRecentLockTargetPinned/deleteRecentLockTarget、displayedRecentLockTargets | LockOperations.setRecentPinned/deleteRecentTarget→Planner.pinRecent/deleteRecent/displayedRecent | 3件表示/3件pin/原本を切捨てない処理と、選択・予定・起床要求の不変を共有historyCasesで検証。保存区間内の時刻/最新pin数、保存故障、OS未呼出し、保存後読込失敗は各OSの操作試験に対応。実行範囲は第11節 |
| SCH-01 / R01,R02 | LockComposerMode、makeRequest、LockSchedule | ComposerMode、DraftTiming、makeRule、LockSchedule | 4モードは整合。LockPlannerTests、EditorStateTest、両OSの作成UI試験。クラス構成の一致は不要 |
| SCH-02 / R02,R03 | AppModel.performSavedOperation→validateEditable/replaceRule/deleteRule、各editor | LockOperations.updateSchedule/deleteSchedule→editable/scheduleEditable/replace/delete、MainActivity.edit | 単発の開始前/開始時の編集・削除と実行中拒否は共有操作列で整合。保存前の開始境界と削除済み編集はCore/LockOperations/AppModel試験へ対応。繰り返しの編集/無効化は各OS試験、削除はIOS-03/AND-02へ分離 |
| SCH-03 / R02,R03 | LockPlanner.overlaps、replaceRule、cancelScheduledDeletion | Planner.overlappingRules/save/replace | 繰り返し同士も含めた重複禁止へ変更。共有overlapCasesで作成/編集/有効化、曜日/日またぎ/週境界/zone/DST、隣接許可を確認。D02はユーザー判断により解決し、取消で衝突を戻す場合も拒否。最新記録は第13節 |
| SCH-04 / R01,R06 | LockComposerViewの初期値/slider/preset | DraftTiming、EditorDraft、Composer.fields | 通常UIの範囲・初期値（遅延/日時/繰り返しを含む）はコードで整合。SelectionControlsUITests、EditorStateTest/EditorInstrumentationあり。Core内部APIの許容範囲はD05で別論点 |
| SCH-05 / R01,R03,R06 | canSubmit、makeConfirmationDetails、AppModel.createLock/performSavedOperation→LockStore.createRule | EditorDraft.canSubmit、Composer.confirm/permissionsReady→LockOperations.createSchedule→Planner.save | 確認前の検査と保存区間での再検証を区別し、相対時刻は保存区間内で構築。保存/反映故障と再試行は操作試験、Core/LockOperationsは時計境界も検証。Androidのnative作成試験は確認後と同じ操作入口を使うが権限/確認sheet全体を通さない。iOS SDKと全権限組合せは未確認、参照存在チェックの保証も旧G13の検証不足を維持 |
| SCH-06 / R01,R02,R06 | ScheduleDatePicker、recurrence.nextInterval、編集View | DateFormat.is24HourFormat、Composerのpreview、Rule.nextOccurrence | 保存zoneでの次回表示はコード/EditorStateTestに整合。iOS/Android UIの12/24時間設定を組合せた実行は今回未確認 |
| TIM-01 / R02,R04 | LockState/LockSchedule、JSON encoding | State/LockSchedule、Codec | 保存は予定等、ActiveLockは派生値。JSON repository/SelectedTarget/Codec試験で整合。SDKの実行状態を保存正本へ加えない |
| TIM-02 / R02 | occurrence(containing:)、WakeState.effectiveEnd、activeLocks | Rule.occurrences、State.effective/activeLocks | 正常な要求1件の半開区間/照合/有効範囲はlock-contract.tsvとwake-contract.tsvで整合。返すActiveLockが元終了か実効終了かは表現差であり、それ自体は違反ではない。重複要求はD03 |
| TIM-03 / R02,R05 | shieldSlotDecisions、名前付きstoreの和集合 | activeLocks、blockingLockの対象照合/max end | 旧データに残る重複の安全な評価としてLockContract/LockLifecycle/PlannerTestを維持。新規作成を許可するテストではない。iOSのShield期限文字列は元終了を読むが、表示の意味はD01 |
| TIM-04 / R02 | RecurrenceRule.nextInterval、Calendar | Rule.occurrences、java.time | 正常zoneのDST/日またぎはlock-contract.tsvと各OS試験で整合。無効zone時の例外/fallbackはD07。Linux Swiftの合格をDarwin SDKでの確認としない |
| TIM-05 / R02,R04 | 保存済みDate、activeLocks、WakeState | 保存済みepoch、activeLocks、WakeRequest | 時計巻戻しと期限維持は共有データ/各OSのWake試験で整合。実経過時間の保証は要求しない |
| TIM-06 / R02,R05 | Monitor.handle→最新JSON→ShieldController | Receiver/Scheduling、GuardService.reconcile | 現在状態/時刻へ再評価する経路は整合。LockLifecycle/MonitoringScheduleの注入試験、Android native/probe試験あり。callback実動は今回未判定 |
| WAK-01 / R02,R03 | WakePolicy.freeDelay、LockStore.scheduleFreeWake | WAKE_DELAY、canScheduleFreeWake/scheduleWake | 新規閾値・30分期限・再送で延長しない点は共有操作列で整合。残り30分以下になった後の再送の成功/エラー差はD04であり、現行条項の違反とは断定しない |
| WAK-02 / R02,R03 | WakeRequest.matches、effectiveEnd、要求の保持 | WakeRequest.matches、effective、要求の保持 | 古い回/不在/期限と次回維持は共有データおよびWakePolicyTests/WakeTestで整合。weeklyと複数ロックの完全な共通操作列はない |
| WAK-03 / R02,R03 | LockStore.cancelFreeWake→LockPlanner.overlaps | Planner.cancelWake→overlappingRules | 通常取消・再予約・期限境界に加え、復元後の重複を拒否して保存済み予約を保持。共有操作列で拒否時の原本保持も検証。D02は解決済み |
| WAK-04 / R01,R03 | RootView.wakeTarget→WakeOptionsDialog.presenting→AppModel→activeOccurrence | intent/表示時のidentity→LockOperations→scheduleWake/cancelWake | 確認対象のID/発生回保持と保存側の再検証を実装。iOSの代表ロック再参照経路を除去。Core共有試験、Android LockOperationsTestで古い対象の予約/取消拒否を確認。iOS AppModelにも同じ試験を追加したがSDK実行は未確認 |
| ERR-01 / R04,R06 | JSON repository、AppModel.readStatus、RootViewの復旧 | Store.read/error、savedDataAvailable、statusWarnings | 読込失敗時の原本/最後のsnapshot保持と復旧はコードに整合。JSONFileLockRepositoryTests、AppModelTests、Lock/RecoveryInstrumentationに対応。実行範囲は末尾の記録を参照 |
| ERR-02 / R03,R04,R05,R06 | LockStore.update、AppModel.performSavedOperation/reloadState/synchronizeAndReconcile、Service protocols | LockOperations、Store.change、Scheduling.sync | 対象選択/予定/無料起床は保存拒否と保存後反映失敗をOperationOutcomeで返す。履歴はOS反映せず、iOSの保存後読込失敗も保存拒否にしない。操作故障/再試行はLockOperationsTest/RecoveryInstrumentation/AppModelTests、共有データは業務拒否時の不変まで。iOS統合試験の実行は未確認 |
| ERR-03 / R05,R06 | registrationログ、Shield反映、diagnostics | alarm登録ログ、service/overlay、diagnostics | API呼出しと実解除を別証拠にする。既存SDK/mock/probe試験の層は分かれているが、今回のCore/JVM合格から実解除適合を判定しない |

### 明示済み仕様の保証不足を閉じる試験

ここは新しい製品仕様ではなく、既存条項の具体的な合否条件。対象境界は今回実装した。iOSのSDK実行とAndroidの実画面試験の実行状況は末尾の記録で区別する。

| 対象 | 入力・操作 | 期待結果（正本から決まる） | 修正/検証すべき境界 |
|---|---|---|---|
| iOS WAK-04/R01 | Aの発生回を起床確認で開く→Aが終了しBだけが実行中になる→元の確認で無料起床を確定 | Aを操作できないと表示し、Bの起床要求・予定は変更しない。Bを操作するにはBを新たに選択/確認する | RootView/WakeOptionsDialogが保持するidentity→AppModel→LockStore。古いidentityを直接Coreへ渡す試験だけではUIの不足を閉じない |
| Android TGT-02/R03 | 実行中なしで対象pickerを開く→下書きを変更→保存区間に入るまでに予定が開始→保存を確定 | 対象変更を拒否し、保存済みselection/予定/起床要求を保持。下書きとエラーを表示し、保存成功として戻らない | MainActivity.selectTargets→LockOperations→Store.changeの境界。時刻と状態を制御した更新テスト＋実画面の保存失敗/下書き保持。区間外チェックだけの試験では不足 |

## 4. 意図的なOS差の対応

相手OSはすべて「対象外」。実装を揃えるTODOにしない。IDに続く正本の補足（商品・制限能力・移行等）も、この対応の対象。

| 基準ID / 責務 | 該当OSの現行担当 | 適合状況 / テスト・未確認範囲 |
|---|---|---|
| IOS-01 / R02,R03,R05 | WakePurchaseStore→AppModel→begin/deliverWakePurchase/useWakeCredit | 購入検証・重複配送・遅延承認のチケット化はコード/WakePolicyTests/StoreKit WakePurchaseTestsに整合。Androidへの導入は不要。今回StoreKit実行なし |
| IOS-02 / R05,R06 | SupportStore、SupportView | 起床とは別の応援IAPとして整合。SupportPurchaseTestsあり。今回StoreKit実行なし |
| IOS-03 / R02,R03 | AppModel.performSavedOperation→LockStore.deleteRule/cancelScheduledDeletion、scheduledDeletionAt、ScheduledLockListView | 現在回維持/将来停止/取消時の競合検査はLockStoreTests、WakePolicyTestsに整合。AppModelへ取消の保存/反映故障試験も追加（SDK未実行）。mock削除UI試験あり。Android即時削除へ変更しない |
| IOS-04 / R01,R05 | FamilyActivityTargetSelectionCodec、AuthorizationService、ScheduleController、ShieldController、各Extension | token・権限・DeviceActivity/ManagedSettingsの経路はコード確認。SDK制限・署名・entitlementを含む実機動作は未判定 |
| IOS-05 / R03,R04 | LockStore actor、JSONFileLockRepository、AppGroup、読取側の各Extension | 本体single writer/原子的置換/拡張readはコードとrepository試験に整合。通常Debug安全上限はBearLockSafetyPolicy、UIテスト指定/Releaseと分ける |
| AND-01 / R02,R06 | Planner.scheduleWake、MainActivity.showWakeOptions、SupportScreen | 無料30分のみ、外部応援、Billingなしで整合。WakeTest、manifest/依存/画面のコード確認。iOS購入試験の移植は不要 |
| AND-02 / R02,R03 | Planner.delete、ScheduleList、State.scheduledRules | 実行中繰り返しの即時削除・要求除去/他予定維持はPlannerTest/WakeTestで整合。開始済み単発の一覧/編集禁止もWakeTestにある |
| AND-03 / R01,R02,R05 | Targets、Catalog、Domain、TargetPicker、BrowserAddress、GuardService | package/domain/category、除外、既知アドレス欄限定の処理はコード/BrowserAddressTest/Picker試験に整合。実ブラウザー各版・private/custom tab等の網羅は未判定/保証対象外 |
| AND-04 / R05,R06 | Scheduling、BoundaryReceiver、GuardService、statusWarnings | exact/inexact登録と時刻再評価の分離はコード/既存native試験に整合。OEM省電力/Doze/再起動の実機結果は今回未判定 |
| AND-05 / R03,R04 | Store/Codec、restoreSelection、LockOperations.selectTargets | AtomicFile/schema 3→4/選択移行はCodecTest、Lock/RecoveryInstrumentationに対応。原本保持/故障試験あり。実行範囲は末尾の記録を参照 |

製品思想のプライバシー/端末内処理も比較対象とする。Androidはmanifest/backup設定、GuardServiceのアドレス欄限定、Storeの端末内ログ。iOSはApp Group/DiagnosticsLoggerと各Serviceが担当する。現行ソースの方針との整合確認であり、通信・ログ内容の全実動監査ではない。ブランドの画素一致を構造適合の条件にはしない。

## 5. 共通UI意図とnative実装の対応

UIの担当は主にR01/R06、保存時の意味はR03も担う。以下のコード確認を、最新の全画面スクショでの合格へ読み替えない。

| 基準ID | iOSの担当 | Androidの担当 | 確認できるもの / 不足 |
|---|---|---|---|
| UI-01 | Setup/Root/Home、各editor/confirmation、WakeOptionsDialog | MainActivity/Route、Composer/ConfirmationContent、TargetPicker | 基本導線と確認/取消はlaunch UI、Editor/RecoveryInstrumentationに対応。起床の対象固定はWAK-04の保証不足へ集約 |
| UI-02 | HomeView、TargetSelectionSummary、ActiveLockView、ScheduledLockListView | MainActivity.home/statusWarnings、SelectionSummary、ActiveCard、ScheduleList | 情報階層はコード確認。復旧/summaryは既存UI/native試験あり。代表ロック・終了表示はD01で判断待ち |
| UI-03 | Pickerのsegmented、アクセシビリティサイズ時のmenu | MaterialButtonToggleGroup、狭幅の横scroll | 標準/ライブラリ採用をコード確認。SelectionControlsUITests/EditorInstrumentationに対応。iOS UIは未実行、Androidの実行範囲は末尾の記録を参照 |
| UI-04 | ScheduleDatePicker.compact、各作成/編集View | Ui.dateTimeButton、DatePickerDialog/TimePickerDialog | 共有部品利用をコード確認。EditorInstrumentation/既存UI試験の範囲あり。全モード/設定の実動は今回未判定 |
| UI-05 | WeekdayPicker、RecurringRuleEditorView | Composer.fieldsの曜日選択 | 選択状態と丸ボタン/日曜始まりをコード確認。SelectionControlsUITests/EditorInstrumentationあり。読み上げ品質の実機確認は別 |
| UI-06 | L10n/strings、native picker/dialog、各View | tr/locale、native dialog/Back、Route | 日英/大文字/戻る/取消の既存UI試験あり。全画面で同じ論理操作を比較する共通シナリオは未整備 |
| UI-07 | SF Symbols、ブランドassets | Ui.icon、Material由来drawable、ブランドassets、AppIcons | 自作LineIcon経路が除去されたコード確認。アイコンの出典/採用と見た目の好みは別問題。スクショが古い場合はAPKとの同一性を確認する |

## 6. 仕様判断待ち — 不適合一覧には含めない

この節に結論・採用案・暫定期待値は置かない。正本の関連条項からは決まらない点だけを記録する。判断待ちがあることを明示することで、対応表自体は完成できるが、この範囲の実装適合は判定できない。

| ID | 関連する基準 | 何が未定義か | 現行の差・必要な判断 |
|---|---|---|---|
| D01 | TIM-02/03、UI-02、R06 | ホームの代表ロック選択基準、元の終了/実効終了のどちらをどの表示に使うか | iOSは元終了が最遅のActiveLock、Androidは実効終了が最遅。iOSのShield期限文字列も元終了。制限判定自体と表示仕様を分け、複数ロック/対象別/起床予約中の表示結果を定める必要がある |
| D03 | TIM-02、WAK-02、R02/R04 | 同一発生回の起床要求が複数保存されていた場合の読込/有効期限 | iOSは有効な最短、request(for:)はlast、Androidはfirst。一意性を保証するか、複数からどう評価するかが必要。破損データの無断初期化とは別に扱う |
| D04 | WAK-01、R03/R06 | 既存予約の再送時、期限不変に加えて成功/エラーも揃えるか | 31分ロックで予約し2分後に再送するとiOSはエラー、Androidは既存状態を返す。両方とも期限は延長せず、明示済みのWAK-01には整合 |
| D05 | SCH-04/05、R02/R03 | 通常UIの15〜720分と、内部API/旧保存/QA用の許容範囲の関係 | iOS Coreは正のduration、Android Plannerは単発1分〜24時間、EditorDraftは15〜720分。UI範囲が違うという指摘ではなく、内部入口まで同じ制約を求めるかの判断 |
| D06 | TGT-01、ERR-02、R03/R04 | 予定作成と再利用履歴の記録が一つの原子的操作か、履歴失敗だけを許容するか | iOSは二段保存で履歴失敗をwarning、Androidは同じ次状態。作成成功の条件を定めるまでは二段保存を不適合としない |
| D07 | TIM-04、ERR-01、R02/R04 | 保存zoneを解決できない場合の読込・制限・復旧の結果 | iOSは現在zoneへfallback、Androidは例外。正常zoneの契約だけで、不正zone時の期待値を決定しない |
| D08 | IOS-01、ERR-02/03、R03/R05 | iOSの監視容量事前検査に起床monitorを含めるか、保存後のOS登録失敗として扱うか | validateCapacityはrules版desired、起床追加はstate版desired。現行仕様は登録失敗時の保存維持/再試行を要求するが、全登録の事前成功保証までは要求していない |

D02は2026-10-26のユーザー判断「重複を許容しない」により解決済み。SCH-03/WAK-03を更新し、取消で他予定と重なる場合は取消を拒否する。実装・検証は第13節。残るD01/D03〜D08の判断は変更しない。

## 7. 以前のG01〜G16の扱い直し

旧IDは履歴参照として残すが、16件すべてを「確定仕様へのギャップ」「修正必須」と扱う一覧は廃止する。優先順位も種別をまたいで付けない。

| 旧ID | 比較基準への対応 | 正しい分類・判定 |
|---|---|---|
| G01 終了表示/代表選択 | D01、TIM-02/03、UI-02 | 仕様判断待ち。現状の表示差は確認したが、代表選択/全表示の結果仕様は未定義 |
| G02 起床確認対象 | WAK-04、R01/R03 | 確認時のActiveLockを保持する実装へ置換。Core試験とAppModel試験を追加。iOS SDK/UIでの実行は未確認であり実動完了とはしない |
| G03 取消で重複 | 解決済みD02、SCH-03/WAK-03 | ユーザー判断後、取消拒否と保存状態保持を正本・両OS・共有試験へ反映。第13節参照 |
| G04 複数起床要求 | D03、TIM-02/WAK-02 | 不正/重複入力の結果が未定義。OS差だけで違反としない |
| G05 再送結果 | D04、WAK-01 | 明示済みの期限不変には両OSとも整合。戻り値を共通化するかは別判断 |
| G06 選択保存の境界 | TGT-02、R03 | LockOperations→Store.change内のPlanner.selectTargetsで再検証する形へ修正。共有の開始境界/更新入口の故障試験と実画面の開始後拒否試験へ対応付けた |
| G07 入力範囲 | D05、SCH-04/05 | 通常UIと内部APIを混同した指摘を撤回。通常UIはコード上整合。内部範囲は判断待ち |
| G08 履歴の二段保存 | D06、TGT-01 | 原子性の要件が未定義。二段保存という構造だけでは違反ではない |
| G09 Activityへの集中 | R03/R06 | 分散/行数だけでは不適合でない。G06等の具体的な保証不足を直すために必要なら整理する任意の手段 |
| G10 下書きの別構築 | R01/R02、SCH-05 | 固定日時/確認対象の一致を試験する必要はあるが、View内のStateやDate()の個数だけで違反としない。今すぐ/遅延は確認後基点なので時刻差を一律に誤りとしない |
| G11 不正zone | D07、TIM-04/ERR-01 | 例外時の結果が未定義。正常zoneのDST一致と別に判断する |
| G12 Bool/flags/string | ERR-02、R03/R06 | 型の選択は任意の改善。全入口/並行操作で失敗状態を守れるかは検証不足。型を揃えれば適合するわけではない |
| G13 selection参照 | SCH-05、R03 | 内部Core APIは任意IDを受け付ける一方、UI/codecには検証がある。利用可能な操作入口から無効参照を保存できるかは未判定。Core単独入力を製品不具合と断定しない |
| G14 容量検査 | D08、IOS-01/ERR-02 | iOS固有の事前検査の範囲が未定義。OS登録失敗の扱いを先に基準にする |
| G15 テストの穴 | 各基準のテスト欄、検証記録 | 検証不足。仕様/実装の不適合とは別。未定義ケースを仮の期待値で埋めない |
| G16 ファイルの同居 | R01〜R06 | 任意の保守改善。class数/ファイル数の一致は要求しないため、同居だけを理由に修正しない |

### 現在の対応順序

1. 対象選択/無料起床・予定作成/編集/削除に加え、履歴pin/解除/削除も更新入口へ集約した。末尾の検証記録を確認し、iOS SDK/統合試験の未確認を残す。課金配送はiOS固有の別経路を維持する。
2. 仕様判断待ち: D01/D03〜D08。D02のみユーザー判断により解決済み。未決定の結果を「iOSに揃える」で処理しない。
3. 検証不足: 各表の必要な試験。既存の保証を確認するものと、未定義結果を決めないと作れないものを分ける。
4. 任意の構造改善: 1〜3を満たすため必要な範囲だけ行う。一律のActivity分割/DTO変更/interface追加は着手条件にしない。

## 8. テストの所在・仕組み・検証記録

仕組みの正本は [design-docの検証節](../design-doc.md#verification)。同じ仕様の期待値は共有データに置き、Swift/Kotlinアダプターがそれぞれの本番ロジックを呼ぶ。Core計算、アプリ操作、OS適用、UIを一つの試験で確認したことにしない。

| 試験層 | iOSの所在 | Androidの所在 | この表で確認するもの |
|---|---|---|---|
| 共有入力・期待値 | [LockContractTests](../../Tests/BearLockCoreTests/LockContractTests.swift) | [LockContractTest](../../android-lab/product/src/test/java/com/hiyozoo/bearlock/LockContractTest.kt) | [lock-contract.tsv](../../Tests/ContractFixtures/lock-contract.tsv)、[wake-contract.tsv](../../Tests/ContractFixtures/wake-contract.tsv)、[lock-operations.json](../../Tests/ContractFixtures/lock-operations.json)。計算境界と単発の操作列の一部 |
| OS非依存の業務/保存 | [Core tests](../../Tests/BearLockCoreTests) | [product unit tests](../../android-lab/product/src/test/java/com/hiyozoo/bearlock) | 各表記載のPlanner/Wake/履歴/保存形式。共有データだけでは覆わないOS別条件 |
| アプリ操作/故障 | [AppModelTests](../../BearLockLogicTests/BearLockAppModelTests.swift)、Coreのrepository/LockLifecycle試験 | [LockInstrumentation](../../android-lab/product/src/debug/java/com/hiyozoo/bearlock/LockInstrumentation.kt)、[RecoveryInstrumentation](../../android-lab/product/src/debug/java/com/hiyozoo/bearlock/RecoveryInstrumentation.kt) | 保存/登録失敗・再試行・画面状態。注入試験とSDK実動を区別 |
| native UI/購入 | [UI tests](../../BearLockUITests)、[Purchase tests](../../BearLockPurchaseTests) | [EditorInstrumentation](../../android-lab/product/src/debug/java/com/hiyozoo/bearlock/EditorInstrumentation.kt)、[PickerInstrumentation](../../android-lab/product/src/debug/java/com/hiyozoo/bearlock/PickerInstrumentation.kt)、probe E2E | 導線・取消・再作成・選択・OS固有課金/遮断 |
| CI | [iOS CI](../../.github/workflows/ios-ci.yml) | [Android CI](../../.github/workflows/android-ci.yml)、[Android 14 Acceptance](../../.github/workflows/android14-acceptance.yml) | 試験の実行接続。workflowの存在を外部実行成功としない |

### 記録

- 2026-10-25: 共有操作データ11シナリオ・27ステップを追加。最初の起床期待期限を1800→1801秒へ一時変更し、両OSが同じケースで失敗する接続の負例を確認して復元。Swift 73、Android 59単体テスト成功。これは全契約の網羅や未定義ケースの正当化ではない。
- 同日の一時診断: G01の代表値、G03の取消後重複、G04の複数要求、G05の再送差をCore/JVMで確認。診断用コードは残していない。確認した現状を恒久的な期待値にせず、現在はD01〜D04へ分類する。
- 2026-10-26: 今回は基準本文と対応表の再整理のみ。本番コード・テストロジック・保存形式・APK・CI構成を変更していない。仕様40件（共通23、OS固有10、UI7）と責務6件の各IDに対応表が一つずつ存在し、旧16件の再分類と判断待ち8件が欠落/重複していないこと、リンク/anchor/共有fixtureの仕様IDを機械的に確認した。Swift 73単体テスト成功。Androidも `:product:testDebugUnitTest --rerun-tasks` で再実行し59テスト成功（失敗/エラー/skipなし）。差分の空白検査も成功。
- 限界: 今回はWSLのSwiftCore/JVMと文書の整合性確認。Xcode/iOS SDK/StoreKit/UI、Android instrumentation/emulator、実機/OEM、GitHub上のCI実行は未確認。これらが必要な基準を実動適合にしない。

本書の完成条件は、全基準の担当・判定・検証範囲が追え、未定義/未検証/任意改善を混ぜずに区別できること。アプリの全不具合修正や全実機検証の完了ではない。

## 9. 2026-10-26 対象選択・無料起床の構造整合

### 対象範囲と対応

対象は対象選択の保存/履歴からの再選択、無料起床の予約/取消。予定作成・編集・削除の調停、課金/削除方式、D01〜D08の未決定結果は変更していない。

| 同じ責務 | iOS | Android |
|---|---|---|
| 入力・確認対象・結果表示 | TargetSelectionButton、FrequentTargetListView、RootView.wakeTarget、WakeOptionsDialog | MainActivity/TargetPicker/HomeComponentsの操作要求と結果表示、既存dialogのidentity |
| 保存と反映の調停 | AppModel.performSavedOperation | LockOperations.commit |
| 最新状態/操作時刻での検証 | LockStore actor内のupdate。無料起床のDate()もactor内で取得 | Store.changeのguard内でclock()を取得しPlanner.selectTargets/scheduleWake/cancelWake |
| 保存 | 既存JSONFileLockRepository。新しい保存先なし | 既存Store/AtomicFile。新しい保存先なし |
| OS反映と反映のみの再試行 | synchronizeAndReconcile / refresh→既存Service | retryReflection→既存Scheduling（ActivityのupdateMonitoringはOS adapterの接続点） |
| 操作結果 | OperationOutcomeのrejected/saved/savedNeedsReflectionとPublished状態 | OperationOutcome.Rejected、Saved(state, reflection) |

一致させたのはこの入出力と責務の境界であり、型の内部表現やclass数ではない。iOSは既存AppModelを使い、AndroidはSDK非依存の小さなLockOperationsを追加した。保存区間やOS adapterを重複実装していない。

### 除去した経路と維持した例外

- AndroidのpersistSelection、画面内の無料起床のStore.change、履歴再選択の画面内保存を除去。対象選択と無料起床はLockOperationsを通る。
- Androidの作成確認でselectionを重ねて書く経路を除去。選択は既に対象pickerの保存で確定しており、予定作成はselectionを上書きしない。
- iOSの対象保存/履歴選択/無料起床それぞれの保存後調停をperformSavedOperationへ置換。Debugの選択保存も同じ入口を使う。
- iOSの起床dialogが毎回model.activeLockを取り直す経路を除去し、開いたActiveLockを保持。保存側でもその回の存在・状態を再検証し、無効化/削除境界も拒否する。
- Androidの旧SharedPreferences選択移行は保存済みデータの復元であり、ユーザー編集とは違うため維持。iOSのShield→本体のlaunch要求はOSから対象identityを取得できない既存の制約を維持し、本体でdialogを開く時点から対象を固定する。

### 検証範囲

- 共通の操作データは13シナリオ・30ステップ。対象選択の開始直前/開始時/実行中を追加し、両言語の製品ロジックで同じ期待値を確認。
- SwiftCoreは75テスト成功。追加の無効化/削除済み発生回の起床予約・取消拒否と、読込中に期限をまたいだ場合の保存区間内時計取得を含む。
- Android JVMは64テスト成功。追加したLockOperationsTestは、保存区間に入る前の状態/時計変化、読込/書込失敗、保存後反映失敗、反映だけの再試行、古い起床対象の拒否を確認。
- iOS AppModel統合試験は6件追加し合計15件。保存後の読込/Shield/監視失敗、取消失敗、再試行で再保存しないこと、代表ロック交代/古い画面状態からの拒否を確認する内容。WSLにXcode/iOS SDKがないため、実行結果は未確認。変更したSwiftUI/AppModel/統合テストは構文解析まで成功。
- Android API 26のRecoveryInstrumentationは、保存故障・無料起床・再試行・再作成に加え、新しい対象選択の開始後拒否と反映失敗後の再試行まで成功。再試行前後で保存ファイルが変化しないことも確認。
- 初回のRecovery試験では、ファイル復元とheartbeatの画面再生成が競合して古い再読込ボタンへの操作が失敗した。ファイル復元と実際のretryボタン押下を同じUIターンに同期させ、同じ試験を再実行して成功。復旧の合否条件を省略していない。
- 最終APKでRecovery/Editor/LockInstrumentationを一連で再実行し、すべてPASSとresult code -1を確認。ログはローカルの `artifacts/structure-alignment-2026-10-26/Recovery.log`、`Editor.log`、`Lock.log`、選択保存の故障画面は同ディレクトリの `screenshots/` に保持する。全画面の新スクショ比較や実機/OEM/iOS SDKの実動完了とはしない。
- AndroidのDebug/Release APKビルドとlint（エラー0、警告41）が成功。実機ではなく所有するAPI 26 emulatorへDebug APKを入れて検証した。検証APKのSHA-256は `cd1c485647a73462ef8efdb8b62e8ece5546036a2ae4026a15d360462671c1df`。既存の全画面スクショ比較ページをこのAPKの結果として更新したわけではない。

## 10. 2026-10-26 予定作成・編集・削除の構造整合

第9節に続き、単発/繰り返し予定の作成・編集・削除、およびiOSの削除予約取消を同じ責務境界へ接続した。製品コード共有・新しい保存層・保存形式変更はない。この段階では履歴pin/履歴自体の削除、購入配送まで統合していない（履歴の後続対応は第11節）。

| 操作 | iOSの更新入口 | Androidの更新入口 |
|---|---|---|
| 作成 | createLock→performSavedOperation→LockStore.createRule | Composer.confirm→MainActivity.createSchedule→LockOperations.createSchedule→Planner.save |
| 編集 | updateScheduledRule/updateRecurringRule→saveRule→performSavedOperation→LockStore.replaceRule | Composer.saveEdit→MainActivity.updateSchedule→LockOperations.updateSchedule→Planner.replace |
| 削除 | deleteScheduledRule→performSavedOperation→LockStore.deleteRule | ScheduleList→MainActivity.deleteSchedule→LockOperations.deleteSchedule→Planner.delete |
| 削除予約取消 | cancelScheduledDeletion→performSavedOperation→LockStore.cancelScheduledDeletion | 該当機能なし。Androidは即時削除 |

### 完了した実装と除去した経路

- AndroidのComposer内の作成/編集のStore.changeと、ScheduleListの削除mutateラムダを除去。MainActivityは結果の表示/遷移を担い、LockOperationsが保存→反映の調停を一度だけ行う。Composer.confirmに残るPlanner.saveは確認前の事前検査で、結果を保存しない。確定時の権限はLockOperations→Store.change内の再検証にある。
- Androidの今すぐ/遅延は保存区間内の時計からRuleを構築する。編集ID・固定日時・曜日/時刻は下書きから渡す。開始後や削除済みの予定を、古い画面状態だけで編集できない。
- iOSの作成/編集/削除/削除予約取消に重複していたbusy guard・例外処理・保存後同期をperformSavedOperationへ集約。作成/編集のBoolをOperationOutcomeへ置換し、ViewはisSavedで確認/編集を閉じる。作成中のisCreatingLock表示は維持し、無料起床操作との重複も同じguardで拒否する。
- 保存拒否では下書き/保存済み状態を保持。保存後の監視・Shield・再読込の失敗は保存成功を取り消さず、再試行では保存済み状態の反映だけを行う。Androidの予定保存I/O失敗には予定用のエラーを表示する。
- iOSの現在回を残す繰り返し削除とAndroidの即時削除は維持。iOSの履歴別保存/warningとAndroidの予定・履歴同時保存も維持し、D06の判断を先取りしていない。D01〜D08は新たに決定していない。

### テストの対応と確認範囲

- 共有操作データは開始直前/開始時の編集・削除を追加し、14シナリオ・33ステップ。SwiftはLockStore、Androidは直接Plannerを呼ぶ経路から本番のLockOperationsを通すアダプターへ置換し、同じ期待値を実行する。OS反映/保存故障はこのfixtureのstubではなく各OS試験の担当。
- SwiftCoreは77件成功。追加したLockStoreTestsは、相対開始時刻を読込後に取得すること、読込中に予定開始をまたいだ場合の編集/削除拒否を確認する。
- Android JVMは69件成功。LockOperationsTestは10件となり、作成/編集/削除それぞれの保存故障・反映故障・再試行、保存前の時計/状態変化、削除済み編集、繰り返し即時削除で他予定/要求を保持することを追加確認する。
- iOS AppModelTestsは6件追加して合計21件。作成後読込失敗、履歴だけの保存失敗、編集の保存/反映失敗、古い編集対象、削除後読込失敗、繰り返し有効化/削除予約取消と再試行を検証する内容。変更したSwiftUI/AppModel/テストの構文解析は成功。ただしXcode/iOS SDKがないため21件は未実行。本体SDK型検査・ビルド・UI実動成功とは扱わない。
- AndroidのRecoveryInstrumentationへ予定操作試験を追加。作成は確認後と同じMainActivityの操作入口を使い、権限前段・確認sheet全体の試験ではない。編集はオフにした繰り返し予定の実際の保存ボタン、削除は一覧の削除ボタン/確認dialogを操作する。各操作の保存故障時の原本/下書き保持と、反映故障時の保存維持、反映再試行前後のファイル不変を確認する。故障画面6枚をローカルの `artifacts/schedule-structure-2026-10-26/screenshots/` に保持。
- Recoveryの成功出力は既存CIの判定文字列 `PASS: monitoring recovery UI` を保つ形へ修正。判定を省略したり、別のテスト一覧/runnerを追加したりしていない。

### 最終確認記録

- Android Debug/Releaseビルド、69件の単体テスト、lint成功（エラー0、警告41）。ログは `artifacts/schedule-structure-2026-10-26/android-build.log`、SwiftCore 77件のログは同ディレクトリの `swift-test.log`。
- 最終Debug APKのSHA-256は `5a5cd57cb2007fa4094d6f3d591d9351c1f7a84398fa87b48f90ab764518e27a`。所有するAPI 26 emulatorへ再インストールし、Recovery/Editor/LockInstrumentationを一連で再実行した。3本ともPASSおよび `INSTRUMENTATION_CODE: -1` を確認。rawログは同ディレクトリの `Recovery.log`、`Editor.log`、`Lock.log`。故障画面6枚も最終APKから取得し直した。
- 40仕様ID/6責務IDの対応表が各1行あり、共有fixtureの14ケースの仕様IDが正本に存在することを機械確認。置換範囲に画面からの予定保存/削除経路が残らず、共有試験もAndroidの本番更新入口を経由することを確認。差分の空白検査成功。
- 未確認はiOS SDKビルド・AppModel 21件の実行・iOS UI/StoreKit、全画面比較、実機/OEM、GitHub上のCI実行。Androidの作成確認/権限全体や、オン状態の全編集モードの故障UIを今回網羅したわけではない。意図した境界の実装と、この環境で可能な検証を完了した記録であり、全アプリの全検証完了ではない。

第9節のAPKや古いスクショ比較ページを今回の結果として流用しない。

## 11. 2026-10-26 履歴のピン留め・解除・削除の構造整合

対象はTGT-03の履歴管理操作。対象の再選択は既に対象選択の更新入口へ接続済みであり、履歴管理のためにその経路や予定作成時の履歴記録方式を置き換えてはいない。製品コードはSwift/Kotlin別実装のまま、仕様・責務とテスト期待値を共通化した。

### 責務と除去した経路

| 責務 | iOS | Android |
|---|---|---|
| 操作意図/結果表示 | FrequentTargetListView→AppModel.setRecentLockTargetPinned/deleteRecentLockTarget。失敗表示・読込復旧は既存RootView | SelectionSummaryの既存menu/dialog→MainActivity.setRecentPinned/deleteRecentTarget。履歴用保存エラーと結果表示 |
| 最新状態で検証/保存 | 同じperformSavedOperation→LockStore actorのfresh read/update。pin上限と操作時刻は保存区間内 | 同じLockOperations.commit→Store.changeの共有guard→Planner.pinRecent/deleteRecent |
| 保存後の処理 | OS反映は行わずreloadStateのみ。読込失敗はsavedNeedsReload/readStatus.failed、保存拒否はrejected | Store.changeが返したStateで表示を更新。監視処理は呼ばずSavedを返す |

- Androidの画面内pin/saveと履歴削除ラムダ、MainActivity.mutateを除去した。履歴の変更に付随してsyncSchedulesを呼ぶ旧経路は残さない。
- iOSの履歴2操作に重複していた保存・再読込・catchを既存の操作入口へ統合。保存が済んだ後の読込失敗を操作失敗のalertにせず、保存済みとして読込復旧へ進める。iOSのpin時刻の既定値もfresh read後に取得する。
- 履歴操作はScheduleController/ShieldController/Schedulingを呼ばず、既存の監視失敗フラグを消さない。iOSの読込復旧ボタンは従来の全状態refreshで、OS再評価も行うが履歴コマンドは再送しない。
- 履歴の削除は再利用候補だけを削除し、選択済み対象・予定・起床要求を変更しない。履歴の表示上限3件を保存件数上限に変えない。D06の予定作成と履歴記録の原子性は未変更。
- 既に消えた履歴への操作や同じpin要求の再送時の時刻/順序については、この変更で新しい共通結果を決めていない。iOSは不在IDを拒否、Androidは既存の対象集合に対するno-opを維持し、pin済み時刻の再設定/維持も従来どおり。今回の共有fixtureに未定義の期待値を混ぜない。

### テストの対応

- `lock-operations.json` に同じ共有ファイル内の `historyCases` を追加。2シナリオ・12ステップでpin/解除/削除/評価、保存集合・ピン集合・表示順、上限拒否時の原本保持、対象/予定/起床要求の不変を両OSで検証する。既存の予定操作14ケース33ステップと合わせ16ケース45ステップ。履歴操作のアダプターはSwiftのLockStore、Kotlinの本番LockOperationsを呼び、AndroidではOS監視の呼出し0回も確認する。
- AndroidのLockOperationsTestは3件追加し13件。pin/解除/削除の読込/書込故障、最新pin数での拒否、保存区間内の時計、OS反映を一切呼ばないことを検証する。
- SwiftCoreのLockStoreTestsに保存区間内のpin時計の試験を追加。共有履歴操作テストと合わせSwiftCoreは79件、Android単体は73件となる。
- iOS AppModelTestsは4件追加し25件。履歴の正常更新と監視/Shield未呼出し、読込/書込故障、保存後読込故障と再保存しない復旧、最新のpin数による拒否を扱う。構文解析は成功したが、Xcode/iOS SDKがないため25件は未実行。
- Androidの既存RecoveryInstrumentationへ、実際の履歴menu/dialogからのpin/解除/削除の保存拒否・再試行、監視呼出し数の不変、保存済み対象/予定/起床要求の不変、menu表示後にpin上限が変わった場合の拒否を追加。別runner/CI経路は増やしていない。

### 最終確認記録

- SwiftCore 79件、Android単体73件が成功（失敗/エラー/skipなし）。共有の16ケース45ステップ、40仕様/6責務の対応が各1行であること、参照先とanchor、差分の空白検査も確認した。ログはローカルの `artifacts/history-structure-2026-10-26/swift-test.log`、`android-unit-test.log`。
- Android Debug/Releaseビルドとlint成功（エラー0、警告41）。初回のビルド記録は同ディレクトリの `android-build.log`、native試験補助修正後の最終Debug/lintは `android-native-build.log`。テストdata/sourceの変更は既存のSwiftPM/JUnit/CI接続で実行し、CI設定の新規変更はしていない。
- 初回native試験は履歴の保存処理に到達する前に、PopupMenuの文字ノードへの直接ACTION_CLICKが拒否された。文字に対応する最寄りのクリック可能な項目を操作するよう既存clickヘルパーを修正。保存故障・再試行・不変条件を省略せず再実行し成功した。初回失敗ログは `Recovery.log`、最終成功ログは `Recovery-final.log` として区別する。
- 最終Debug APKのSHA-256は `6ec7626289d2f7d18494e124f65da2d49050c6de195f0608579350fde6a8c5e6`。所有するAPI 26 emulatorへインストールし、Recovery/Editor/LockInstrumentationすべてでPASSおよび `INSTRUMENTATION_CODE: -1` を確認した。rawログは `Recovery-final.log`、`Editor.log`、`Lock.log`。履歴の故障/保存/上限画面7枚は同ディレクトリの `screenshots/` に取得し、保存失敗とpin成功の画面を目視確認した。
- iOS AppModel 25件は構文解析までで、SDK型検査・本体ビルド・統合/UI/StoreKitは未実行。実機/OEM、全画面比較、GitHub上のCI実行も今回の完了範囲に含めない。古いスクショ比較ページや前節のAPKを最終APKの証拠として使わない。

## 12. 2026-10-26 Android 14疎通の中止とiOS検証への引継ぎ

- ユーザーの指示により、ローカルAndroid 14エミュレーターの疎通検証を打ち切った。既存AVDのデータは消去していない。新設した検証用AVDも停止し、検証成功として扱わない。
- 既存API 34環境ではPicker/Lock/EditorInstrumentationが成功したが、RecoveryInstrumentationはSystem UIのANR画面に阻まれた。同じ環境で通常のActivity起動もタイムアウトしたため、製品の起床ボタン不具合と断定していない。別AVDのOS起動やWindowsの空きメモリー確保も試したが、全ケースの再実行完了前に中止した。
- Android 14のRecovery・無料30分起床・権限・実際の遮断/自然終了の一連の回帰検証は完了していない。第11節のAPI 26成功をAPI 34成功へ読み替えない。試行ログとANR画面はローカルの `artifacts/android14-regression-2026-10-26/` に分離した。
- 今回の検証補助修正は既存経路に限定した。Recoveryは失敗時の画面と実際のwindow文字列を採取し、permission_scope_verifyは現在の確認タイトル/セグメント名へ追従、重複した座標tapを既存product_qa.tapへ置換した。権限・保存・監視の検証条件を緩めたり、代替runnerを追加したりしていない。permission_scope_verifyの修正後の実機能実行は未完了。
- iOSへ渡す検証経路は既存の [iOS CI](../../.github/workflows/ios-ci.yml) と [READMEのセットアップ/検証](../../README.md#github-actions-ios-ci)。Xcode環境でAppModel 25件、本体/extensionのSDKビルド、mock UI一連操作、StoreKitを確認する。WSLのSwift構文解析やCoreテスト成功は、それらの成功を意味しない。
- iOSシミュレーターで確認できるのはiOS実装の画面/導線/アプリ内状態遷移。AndroidのAccessibility・AlarmManager・省電力動作の代替検証でも、iOSの実Screen Time遮断の証明でもない。意図したOS別仕様は正本のまま維持する。

### push前の最終ローカル確認

- AndroidのDebug/Release APK・Release AAB、product単体73件、lab単体6件、product/probe lintが成功。product lintはエラー0・警告41。Debug APKのSHA-256は `f6a588ad9870a367ebfde8de5f926ef8aa535d0bf83f9990d0e41255af886cbd`。このAPKでAPI 34の全疎通が成功したという意味ではない。
- SwiftCore 79件、既存の別プロセス保存テスト（writer 200更新・reader 4プロセス）が成功。変更したSwiftの構文解析、Android検証用Pythonの構文検査、差分の空白検査も成功。iOS SDK型検査/実行は含まない。
- ログは同じローカル証拠ディレクトリの `final-build.log`、`final-swift-test.log`、`final-repository-processes.log`。過去の試行を上書きせず分離した。製品修正に新しい共通ランタイムや別の検証runnerは導入していない。

## 13. 2026-10-26 繰り返しを含む全予定の重複禁止

ユーザーの判断「重複を許容するのが間違い」により、従来の繰り返し同士だけを除外する実装を撤去した。製品仕様は正本のSCH-03/TIM-03/WAK-03を更新。D02は判断待ちから解決済みへ移し、他の判断待ちや課金・削除方式は変更していない。以前の節で重複を許可/判断待ちとした記録は、この判断前の履歴である。

### 判定と保存の経路

- SwiftのLockPlanner.overlapsとAndroidのPlanner.overlappingRulesを既存の重複判定の正本として変更。単発/繰り返しの各組合せを対象によらず検査し、同時刻の終了/開始は許可する。無効予定・編集元自身・終了済み区間は競合対象にしない。有効化も同じ保存入口で再検査する。
- 同一zoneの無期限の繰り返し同士は、曜日と分の週内区間で判定し、週境界を含めて比較する。一回の起床は将来の繰り返しを消さないため、現在回の短縮だけで恒久的な繰り返しの衝突を許可しない。
- 異なるzone、またはiOSの有限な削除予約がある場合は本番の発生回・実効終了を比較する。異なるzoneは既知のoffset遷移/起床境界で区切り、各区間の両端の8日を確認する。無期限の場合は現在のtimezoneデータとグレゴリオ暦の400年周期で評価し、直近1週間だけの判定で将来の夏時間衝突を見逃さない。OSのtimezoneデータの将来の改訂まで予言する保証ではない。
- 起床取消は要求を除いた候補状態で同じ重複判定を行い、競合すれば保存せず予約を保持する。Androidの画面はこの拒否を保存障害に変換せず、既存の重複エラーで案内する。
- iOSの削除予約取消も同じ判定へ接続し、元のルールIDを維持して起床済みの回を誤って元の長さとして扱わない。監視容量検査は既存のまま維持する。
- 旧データを読んだだけで予定を削除・無効化しない。既存の重複は従来の対象和集合/最後の期限で安全に評価し、削除時も残りの制限を落とさない。既存のnative/probeの重複fixtureはこの旧データ評価用であり、作成許可のテストではないことを明記した。

### テストと実行範囲

- 既存のlock-operations.jsonへ23件のoverlapCasesを追加し、SwiftのLockStore、AndroidのLockOperationsから同じ期待値を実行する。作成/編集/有効化、無効の下書き、曜日違い、包含、隣接、日またぎ、週境界、24時間、異なるzone、将来のDST、現在回の起床と翌週、取消拒否/隣接許可を扱う。別のfixture一覧/runnerは作っていない。
- 既存の単発操作列にも「起床で空いた区間へ予約→起床取消拒否」を追加し、拒否時の全状態不変を確認する。iOSの削除予約取消はCoreテストで繰り返し競合の拒否と、起床identityを保った空き区間の許可を追加。旧重複データの評価/削除テストも維持した。
- iOS AppModelに取消拒否時の保存/監視/Shield未更新のテストを1件追加し、計26件。構文解析は成功。Xcode/iOS SDKがないため26件のSDK実行は未確認。
- AndroidのRecoveryInstrumentationへ、実際の起床取消ボタンから重複エラーと予約保持、監視未呼出しを確認するケースを追加。ローカルエミュレーター検証の中止は維持し、今回このnativeケースの実行成功とは扱わない。
- SwiftCore 82件成功。今回の証拠はローカルの `artifacts/overlap-rejection-2026-10-26/` へ分離し、以前のAPK/スクショ/エミュレーター結果を今回の成功として流用しない。

### 最終確認記録

- 最終コードでSwiftCore 82件、Android product単体74件が成功（失敗/エラー/skipなし）。共有23件の重複シナリオと既存の操作/履歴ケースを含む。仕様40件の対応が各1行、共有39シナリオのIDが一意で宣言済み仕様に対応すること、差分の空白検査も確認した。
- Android Debug/Release APKビルドとlint成功（エラー0・警告41）。Debug APKのSHA-256は `aba940b143694aa67a11088be93026fe9f63077682f777c23c3321b3f907bfef`。ログは同証拠ディレクトリの `android-build.log`、`swift-test.log`。
- 最初のAndroidビルドは古いKotlin daemonへの接続待ちで進まなかったため、その実行だけcompilerをin-process指定して再実行した。repoのCI/configurationへ恒久的な回避処理は追加していない。
- 別プロセス保存試験の初回は並行コンパイル中に既存の120秒上限を超過した。Swiftの長い判定処理を同じPlanner内の小さな補助関数へ整理した最終コードでは、上限を変えず既存スクリプトの再実行が成功（writer 200更新・reader 4プロセス）。初回ログは `repository-processes.log`、最終成功ログは `repository-processes-final.log` と区別する。
- iOS SDK/AppModel 26件/StoreKit/UI、Android native UI・実機/OEMの今回の実行は未確認。追加したテストが存在することを実行成功に読み替えない。ローカルエミュレーターの疎通中止は継続する。

## 14. 2026-10-26 MacでのiOS SDK・シミュレーター検証（取り込んだブランチの記録）

### 基準・環境・証拠

- 取得した `origin/main` は `f29448bdd7e8eedc1c5b001d3afe96b0eff92f37`。このコミットの正本と本書第9〜12節を基準とした。元の `main` にある未コミットの画像・文書は変更せず、`codex/ios-structure-verification` の別worktreeで実施した。
- macOS 27.0.1 (26A434)、Xcode 27.1 (27A9275)、Swift 6.4、XcodeGen 2.46.0。XcodeGenは公式releaseのバイナリを使用。Homebrewは未導入だった。SDKはiPhoneSimulator 27.1。初期試行は既存のiPhone 18 Pro Max、最終の通常端末はiPhone 17 Pro Max、小型端末はiPhone SE (3rd generation)、いずれもiOS 27.0 (24A434)。StoreKit比較用にiPhone 16／iOS 26.2 (23C54)も使用した。
- 実行経路は既存の [iOS CI](../../.github/workflows/ios-ci.yml)。利用可能な端末・runtimeと通常UI試験の英語指定以外は同じscheme/操作を使用。小型試験は既存の `SelectionControlsUITests` 全体を実行し、別runner・テスト一覧・CI jobを追加していない。
- 証拠は [今回の記録](../../ci-results/ios-review/2026-10-26-f29448b/) に置く。環境、xcresulttoolの結果要約、圧縮したrawログ、今回の実操作スクショを同梱。元のxcresultと追加診断ログは検証worktreeの `artifacts/` に保持する。過去のApp Store画像やAndroidの証拠を今回の結果として流用していない。

検証した修正コードは `b7e0d74c59f53776025a84bde00a4cecbb2e6417`（この記録を追加するcommitの親）。最終試験は同commitと一致するソースから生成したバイナリを使う。

### 再現と修正

| 対象 | 再現条件・原因 | 修正・保持する期待値 |
|---|---|---|
| AppModel試験のSDKコンパイル | 別moduleから `SingleLockSchedule` の非公開memberwise initializerを呼び出していた | 公開 `LockRule` initializerで同じIDの開始済み予定を構築。古い編集/削除の拒否・状態不変のassertは維持 |
| AppModelの固定日時比較 | 小数秒を含む入力が既存の秒切上げ正規化を受け、入力値との完全一致に失敗 | 入力を整数秒境界にする。完全一致・保存/反映失敗・再送禁止のassertは維持 |
| mock対象pickerの保存拒否 | 保存前にsheetを閉じ、onDismissで保存していた。書込拒否時に選択下書きへ戻れない | onDismiss保存と余分なcount状態を除去。保存結果を待ち、本番pickerと同じ完了処理で成功時だけ閉じる。失敗時はsheet内エラー、下書きと取消を保持 |
| 作成確認の保存拒否 | 親のalertを閉じると確認sheetも消えることを実操作で再現 | 作成/予定編集の保存拒否はsheet内に表示し、親alertへ残さない。保存済みの反映失敗は従来どおり保存成功として閉じる |
| 起床済み繰り返し編集のUI試験 | Switchの行中央tapが値を切り替えず、元の有効値が再表示された | 既存のスイッチ操作helperをXCTestCase拡張へ移し共有。実コントロールのtap後の値変化と、保存後再オープンの値を検証 |

対象picker・作成確認のbefore/afterは `screenshots/before/` と `screenshots/after/` の同名画像で対応させる。同じ入力と書込拒否後の段階で取得した。コンパイル/時刻入力の問題は画面不具合ではないため、失敗ログと修正後の実行結果で対応させる。本番FamilyActivityPickerで同じmockを実際のopaque tokenや認可の代替にはしない。

日時指定の作成/確認取消/編集/削除、履歴のピン解除、日本語通常文字サイズの4モード確認・取消と日時指定の保存/編集/削除、対象pickerと作成/編集の保存拒否、保存後監視失敗からの再試行を、既存のUI試験へ追加した。D01〜D08、有料即時起床・チケット・応援IAP、現在回終了までの繰り返し削除保留は変更していない。

### 自動試験と操作結果

| 最終実行 | 成功 | 失敗 | skip | 未実行・判定範囲 |
|---|---:|---:|---:|---|
| XcodeGen生成・メタデータ検証 | 成功 | 0 | — | 既存validate scriptとproject.yml |
| SwiftCore XCTest | 79 | 0 | 0 | SwiftPM。新しいSwift Testingの0件出力とは区別 |
| 別プロセス保存整合性 | 成功 | 0 | — | writer 200更新、4 reader各2,000読込 |
| BearLockLogic / AppModel | 25 | 0 | 0 | 削除/終了した起床対象から別代表へ転送しない条件も追加して全件再実行 |
| 本体＋3 extension Debug / Release | 両方成功 | 0 | — | シミュレータービルド、署名なし |
| BearLock / 通常iPhone全UI | 28 | 0 | 0 | iPhone 17 Pro Max、最終コードの全件 |
| 小型iPhone / 選択UI | 7 | 0 | 0 | 既存selectionクラス全件。日英/大文字/通常日本語/日時popupを含む |
| BearLockPurchases / iOS 26.2 | 10 | 0 | 0 | StoreKitTest。実課金/実機ではない |
| BearLockPurchases / iOS 27.0比較 | 6 | 4 | 0 | 下記のruntime差が残る。26.2成功へ合算しない |

初回のAppModelはコンパイル失敗で25件未実行、初期化子修正後は24成功・1失敗、時刻入力修正後および終了済み起床対象の条件追加後は25成功。拡張UI試験の初回完走は26件中23成功・3失敗、小型選択の初回は5件中4成功・1失敗。失敗ログを残し、修正後に対象・回帰試験を再実行した。英語指定のない初回UI試行、追加修正に伴う途中試行、ユーザーによる中断時のUI実行は未完了として扱い、全件成功には数えない。テスト削除・skip・期待値の緩和はしていない。

#### 今回確認した責務の境界

| 操作・条件 | 正常／拒否／保存後故障／復旧の確認方法 |
|---|---|
| 対象選択・履歴再選択 | UIで保存と表示更新、故障pickerで下書き保持と取消後の原本保持。AppModelで書込拒否・最新の実行状態による拒否・保存後読込/Shield/監視故障を区別し、refresh前後の保存状態と書込回数が不変であることを検証 |
| 予定の作成・編集・削除 | UIで4モード、確認/取消、遅延/日時指定の編集・削除、繰り返しの有効/無効と取消。故障UIで作成確認と編集下書きを保持。AppModelで作成・編集・削除の保存拒否/保存後読込/反映故障、削除済み・開始済みの古い編集対象の拒否、復旧で再保存しないことを検証 |
| 無料起床 | UIで予約後に取消actionへ切替、取消後に予約actionへ戻ることを確認。AppModelで書込拒否・反映故障・復旧時の要求と期限/書込回数不変、確認した発生回が削除済み/終了済みとなり別代表へ交代した場合の予約/取消拒否を検証。Coreの共有fixtureと境界試験も実行 |
| 履歴pin/解除/削除 | UIでmenu操作と削除後の表示を確認。AppModelで各操作の読込/書込拒否、保存後読込失敗をsavedNeedsReloadとして扱うこと、復旧で再送しないことを検証。選択済み対象・予定・起床要求の不変、監視/Shield呼出し数不変、監視エラーの保持と最新pin上限もassert |
| iOS固有の繰り返し | UIで実行中の編集禁止・削除予約・取消・再起動後の予約保持、無料起床済みの元終了前に編集/無効化して再オープンの値を確認。AppModel/Coreで削除予約取消の拒否/反映失敗と、起床処理が削除条件を消さないことを検証 |
| UIの操作と可読性 | 通常/小型でセグメント、プリセット、曜日、無効操作、日英の最大アクセシビリティサイズでメニュー/曜日/日時表示/確認取消/編集保存。日本語通常サイズも4モードを操作。日時入力は別々の標準popupを開き、日付popupを閉じた際の値保持と、時刻wheel変更後の下書き更新を確認。静的画像だけを合格根拠にはしていない |
| 設定・課金 | UIで設定/任意の応援の入口と操作不能状態。StoreKitでは3商品の各2回購入、未取得商品、失敗からの再購入、取消、Ask to Buy、未完了取引の起動時配送、無関係な取引保持、有料起床の検証済み配送/取消/チケット化を既存10件で確認。実課金ではない |

#### StoreKitのruntime差と限界

- iOS 27.0のCLI初回は商品取得後にApple Accountサインイン画面へ進み停止したため中断。その[画面](../../ci-results/ios-review/2026-10-26-f29448b/screenshots/storekit-ios27-signin.png)を保持し、成功/skipとは数えない。同じ既存schemeをXcodeから実行してローカルStoreKit設定を適用した後は、CLIでも10件実行され、6成功・4失敗・skip 0だった。
- 27.0の失敗は、同一商品連続購入で最後に同じ取引IDが返り6件でなく5件となるもの、`.generic(.userCancelled)` の注入が `ASDServerErrorDomain 907` → `StoreKitError` の別エラーとして返る応援/起床の2件、無関係な取引がunfinished列挙に現れない1件。これを未公開エラー番号の特別扱い・テスト削除・skip・期待値緩和で通していない。
- Appleの公開download機能でiOS 26.2 runtimeを追加し、同じコード・StoreKitファイル・既存10件をiPhone 16でCLI実行すると10成功・失敗0・skip 0。26.2の成功を27.0の失敗解消とは扱わない。runtimeをまたぐ比較結果であり、27.0のStoreKit再検証は残る。
- Simulatorのmock認可・対象名・NoopのShield/監視は、実Family Controls認可、実Screen Time遮断/解除、署名/entitlement付きDeviceActivity callbackの実機成功ではない。実機・実App Store/Sandbox課金・全OS版/全端末の保証は含まない。Android 14のRecovery/権限/無料起床/遮断/自然終了の未完了項目も、そのまま未完了とする。

#### 証拠の対応と最終確認

- [結果要約](../../ci-results/ios-review/2026-10-26-f29448b/verification-results.json)、[環境](../../ci-results/ios-review/2026-10-26-f29448b/environment.json)、[ソース指紋](../../ci-results/ios-review/2026-10-26-f29448b/source-sha256.json)、[Debugアプリ指紋](../../ci-results/ios-review/2026-10-26-f29448b/debug-app-sha256.json)を保存した。生成済みアプリの指紋と最終ソースの一致を回収時にも再確認した。
- 画像は138枚（最終ビルドの添付画像135枚、修正前2枚、StoreKit比較の停止画面1枚）。[画像index](../../ci-results/ios-review/2026-10-26-f29448b/screenshots-index.json)にテスト名・操作段階を表す添付名・端末・時刻・結果bundle・SHA-256を対応付けた。日英の大文字比較は、同じ端末/画面幅・同じ操作段階の `accessibility-en-*` と `accessibility-ja-*` を使う。確認/取消へスクロールした画像を、sheet初期表示の画像と混ぜない。
- 小型7件と追加の故障UI 2件は、通常端末の28件に含まれるテストの再実行を含む。独立した35件/37件のテストへ水増ししない。StoreKit 27.0のrawログにある6 failuresはassertion数であり、失敗test caseは結果要約どおり4件。
- 最終ログは同ディレクトリ `logs/` の `ui-complete.log.gz`、`selection-small-complete.log.gz`、`failure-ui-verified.log.gz`、`logic-verified.log.gz`、`purchases-ios26.log.gz`、`debug-verified.log.gz`、`release-verified.log.gz`。初回失敗のログ/結果要約も別名で保持し、上書きしていない。

| 操作段階 | 修正前 | 修正後 | 比較条件 |
|---|---|---|---|
| 対象1件を選んで保存、書込拒否後 | [before](../../ci-results/ios-review/2026-10-26-f29448b/screenshots/before/target-save-rejected.png) | [after](../../ci-results/ios-review/2026-10-26-f29448b/screenshots/after/target-save-rejected.png) | 同じSE 3rd generation、375pt。取消後の3件保持もassert |
| 遅延30分/継続30分の確認で保存、書込拒否後 | [before](../../ci-results/ios-review/2026-10-26-f29448b/screenshots/before/schedule-create-rejected.png) | [after](../../ci-results/ios-review/2026-10-26-f29448b/screenshots/after/schedule-create-rejected.png) | beforeは18 Pro Max、afterは17 Pro Max、両方440pt・1320×2868。同一端末のpixel比較とはしない |
| 繰り返し編集の有効化を保存、書込拒否後 | — | [下書きとエラー](../../ci-results/ios-review/2026-10-26-f29448b/screenshots/after/schedule-edit-rejected.png) | SE、375pt。取消/再オープンで原本の無効値もassert |
| 大文字の繰り返し確認、確認/取消ボタン到達後 | [English](../../ci-results/ios-review/2026-10-26-f29448b/screenshots/small/selection-375-accessibility-en-confirmation.png) | [日本語](../../ci-results/ios-review/2026-10-26-f29448b/screenshots/small/selection-375-accessibility-ja-confirmation.png) | 同じSE、最大アクセシビリティ文字サイズ、同じ曜日/時刻設定と操作段階 |

テストの削除・skip・期待値緩和、CI/別runnerの追加、Kotlin製品コード/共有fixture/保存形式の変更はない。置換したmock pickerのonDismiss保存経路と余分なcount状態を削除し、スイッチ操作helperも既存の一か所へ統一した。元の作業ツリーの未コミット変更は保持した。GitHub上でのCI実行成功を今回のローカル結果へ追加してはいない。

## 15. 2026-10-26 iOS検証ブランチの取込みとAndroidへのフィードバック

- `origin/codex/ios-structure-verification` の `b7e0d74`（修正）と `083e4e6`（実行証拠）を、統合用 `codex/android-overlap-feedback` へmergeした。重複禁止の変更は `792dd2c`、取込みmergeは `b58ff94`。mainと作業中のiOSブランチは書き換えていない。
- 第13節の重複禁止と第14節のiOS検証記録は別の変更・別の実行結果として保持した。iOSブランチの証拠ディレクトリもそのまま取り込み、元の画像・ログ・指紋を統合版の実行結果へ書き換えない。
- 取り込んだ指紋128ファイルを照合。重複禁止に伴うCore/テスト/fixtureの8ファイルだけが異なり、iOSの本体・UIテストソースは検証ブランチと一致する。AppModel 25件のSDK成功はb7e0d74時点の結果で、追加後の26件や新しい重複禁止のSDK成功ではない。

### Android側へ適用するかの判断

| iOSで見つかった問題 | Androidの対応経路とフィードバック |
|---|---|
| 保存前にmock対象pickerを閉じ、拒否時に下書きへ戻れない | AndroidのsaveSelectionはselectTargets成功後だけnavigateし、拒否時はpicker/下書きを保持。onDismiss保存経路はない。既存RecoveryInstrumentationの保存拒否/取消/再試行を維持し、iOS固有のmock経路は追加しない |
| 親alert終了に伴って作成確認/編集sheetも消える | AndroidのfinishScheduleOperationはSavedだけでonSavedを呼ぶ。Composerの確認dialog dismissと編集終了はそのcallback内。Rejectedはエラー表示だけで、下書きを破棄しない。既存RecoveryへエラーOK後の下書き/原本保持、実際の編集Cancel後の原本保持、再オープン時に原本の値へ戻るassertを追加した。作成試験は従来同様、確認後と同じ保存入口であり権限前段/確認dialog全体の実動試験ではない |
| Swiftの非公開初期化子を別moduleの試験から使用 | iOSの公開LockRule初期化子を使う修正をそのまま取り込む。Kotlin側へSwiftのアクセス制御回避や別のテスト用モデルを追加しない |
| 小数秒入力と秒切上げ正規化の完全一致失敗 | iOS試験の整数秒境界入力を取り込む。Androidはepochミリ秒の期待値を既存のJVM/共有試験で検証し、不要な秒丸めを製品処理へ追加しない |
| XCTestのSwitch中央tapが値を変えない | iOSの実コントロール操作helper統合を取り込む。Androidの既存native制御と別のSwift用helperは共有しない |
| StoreKitのiOS 27.0で残る4件の失敗 | 第14節のruntime別結果を保持。AndroidはBillingなしのため課金処理/非公開エラーコード特例を移植しない。26.2の10件成功で27.0の失敗を解消済みにしない |

今回のAndroidへのフィードバックで新しい製品経路を追加していない。同型の画面終了不具合があると断定できるコードはなく、既存の成功時限定callbackと失敗時の下書き保持を再確認し、直接関係する既存native試験を補強した。ローカルエミュレーター検証は再開せず、追加assertはコンパイル確認と実行未確認を区別する。

### 統合後の確認と引継ぎ

- SwiftCore 82件、別プロセス保存試験（writer 200更新・reader 4プロセス）、Android product単体74件、Debug/Release APKビルド・lint成功。失敗/エラー/skipは0、lintはエラー0・既存警告41。取り込んだSwiftUI/AppModel/UIテストと追加AppModelテストの構文解析、40仕様の一意な対応、競合marker/空白検査も成功。
- 証拠はローカルの `artifacts/ios-feedback-integration-2026-10-26/` の `swift-test.log`、`repository-processes.log`、`android-build.log`。Debug APK SHA-256は `9fa91df0119f8298f4286b261a4728672c0baff756d9ae62d631954a584225c3`。追加したnative assertを含むAPKのコンパイル成功であり、操作成功の記録ではない。
- 最終fetch時のiOSブランチは `083e4e6d79b257fd7145a6e972c3ce7ab498c29f` で、統合ブランチに含まれることを確認した。取込み先はmainでも検証中のiOSブランチでもなく、`codex/android-overlap-feedback`。
- Mac側の次の確認対象は、この統合ブランチのCore 82件、AppModel 26件、SDKビルド、既存の通常/小型UI・StoreKit。特に重複する繰り返しの作成/編集/有効化拒否、起床取消の拒否と予約保持、保存拒否時の確認/編集画面の維持を組み合わせて再確認する。b7e0d74でのUI 28件/AppModel 25件成功を、この統合版の成功へ読み替えない。iOS 27.0 StoreKitの4件とAndroid固有の未確認は残す。

## 16. 2026-10-26 iOS 27.0 StoreKit失敗の追跡

**4件のうち取引状態に関する2件を解消。取消の2件はこの環境のStoreKitTest経路で再現が残り、全4件の解消完了とはしない。** 製品の課金コード、商品、期待する取消表示を変更して通したものではない。

### 環境と変更範囲

- 基準は第14節の記録commit `083e4e6d79b257fd7145a6e972c3ce7ab498c29f`。修正ソースは `a8124042c1d95a5e5b962220af0029d66c029c0b`。元のmainの未コミット変更は引き続き保護した。
- Xcode 27.1 (27A9275)、iPhoneSimulator SDK 27.1、iPhone 16／iOS 27.0 (24A434)、比較はiPhone 16／iOS 26.2 (23C54)。StoreKit設定は同じJPN storefront。既存 `BearLockPurchases` schemeを、既存CIと同じ `CODE_SIGNING_ALLOWED=NO`、並列実行なしで使用した。最終試験は各runtimeで直列に実行し、`-test-iterations 3` で全10件を各3回検証した。
- 変更は `BearLockPurchaseTests` の2ファイルのみ。テスト名/10件をすべて維持。テスト削除・skip・期待値緩和・タイムアウト延長・製品用fallback・CI/別runnerの追加はない。診断用の一時test/printは最終ソースから削除した。
- [今回の証拠](../../ci-results/ios-review/2026-10-26-storekit-ios27/) に環境、ソース指紋、rawログ、xcresulttoolの要約とtestごとの反復結果を保存。元のxcresultは `artifacts/storekit-ios27-followup/` に保持する。

### 原因と処置

| 対象 | 切り分けた原因 | 処置・結果 |
|---|---|---|
| 同じ消耗品を2回ずつ購入、合計6件 | StoreKitTestのサーバー状態とStoreKit 2クライアントの取引情報が揃う前に次の購入へ進み、直前の取引IDが再返却される。finish済みでもクライアントのunfinishedに古い取引が残る例があった | テストの取引状態確認に `AppStore.sync()` を入れ、finishの反映確認後に次の購入へ進む。6件の最終assertに加え、各購入で件数と一意なID数が1件ずつ増えることもassert。27.0で3回とも成功 |
| 無関係な取引をSupportStoreが終了しないこと | `SKTestSession.buyProduct` で作った取引がクライアントのunfinishedに反映されていない/古い一覧を読む。製品を呼ばない直接APIの診断でも、サーバーの2件に対してクライアントは1件しか返さず、同期後は同じ2件を返した | 作成した商品IDと処理前のunfinishedへの存在を追加assert。アプリ処理後も同期済みの同じIDの保持をassert。27.0で3回とも成功。アプリのfinish対象判定は変更していない |
| 応援購入の取消 | `setSimulatedError(.generic(.userCancelled), forAPI: .purchase)` は設定の読戻しも正しいが、`Product.purchase()` が返すのは `.userCancelled` でも `.userCancelled` resultでもなく `StoreKitError.unknown`。NSErrorのuserInfoも空 | 同じ注入・取消メッセージ・cancelled診断のassertを維持。27.0は3回とも失敗。26.2は同じテストが3回とも成功 |
| 有料起床購入の取消 | 同じStoreKitTestの取消注入で判別情報が失われ、WakePurchaseStoreも通常の失敗として受け取る | pending意図破棄、配送なし、lastDeliveryなしは合格。取消表示とcancelled診断のassertが27.0で3回とも失敗。期待値は変更せず残した |

共通の `synchronizedUnfinishedTransactionIDs` が同期と状態読込を担当し、2つあった旧 `unfinishedIDs` を置換した。リセット直後に空であることも確認する。同期エラーを握りつぶさずテスト失敗へ伝える。[Appleのsync仕様](https://developer.apple.com/documentation/storekit/appstore/sync%28%29)に基づくテスト環境の取引情報更新であり、製品の通常購入処理へ自動syncを追加してはいない。

今回の変更は、6件を4件で許す、無関係な取引の保持assertを外す、といった緩和ではない。テストserver操作とクライアント観測を同期し、元の期待値に加えて生成/finishの前後条件を強めたもの。

### 残る取消2件のSDK境界の証拠

- アプリのStoreを経由しない `Product.purchase(confirmIn:)` でも取消注入後に `StoreKitError.unknown [:]` を返した（`transport-sync-diagnostic.log.gz`）。正しいBundle IDでアドホック署名した比較でも4件の失敗は解消せず、署名識別子は解決策ではなかった（`adhoc-signed-summary.json`）。製品へ署名用設定変更は残していない。
- `synchronization.log.gz` では、取消設定の読戻しが `Optional(...generic(StoreKit.StoreKitError.userCancelled))` なのに、API返却は `StoreKit.StoreKitError.unknown [:]`。ネットワーク故障の注入でも同じunknown/空userInfoを返すため、このAPIの公開情報だけから両者を区別できない。
- `ASDServerErrorDomain 907` はシステムログに現れるが、返されたErrorの情報ではない。非公開番号やOSログの推測でunknown全体を取消に変換しない。元の取消testをstub resultに差し替えて成功させてもいない。[StoreKitError.userCancelled](https://developer.apple.com/documentation/storekit/storekiterror/usercancelled)と[購入resultのuserCancelled](https://developer.apple.com/documentation/storekit/product/purchaseresult/usercancelled)という公開された意味を保つ。
- 注入を使わず通常の購入UIで取り消す追加診断も試したが、CLI起動では購入処理が待機したまま確認dialogを取得できなかった。[待機画面](../../ci-results/ios-review/2026-10-26-storekit-ios27/native-cancel-no-dialog.png)を残して中断し、この試行を成功/skipには数えない。認証情報入力・実支払は行っていない。これは通常の取消UIが成功した証拠ではない。
- 公開download機能では既存27.0はdownload済み、27.0.1 simulatorはdownload不可だった（`runtime-check.log.gz`、`runtime-patch-check.log.gz`）。別runtimeの成功を27.0の解消とせず、取消を識別できるSDK/runtimeまたは正しい返却経路での再検証を残す。

### 最終結果

| 実行 | test case数 | 成功/失敗/skip | 反復結果 |
|---|---:|---|---|
| iOS 27.0、最終コード | 10 | 8 / 2 / 0 | 各test 3回。成功24実行、失敗6実行。同じ取消2件だけが各3回失敗 |
| iOS 26.2、最終コード | 10 | 10 / 0 / 0 | 各test 3回。30実行すべて成功 |

初回の再現ではキャッシュ状態により、既存4件に加え起動時回収/finish確認も失敗し4成功・6失敗だった。同期後はこれらも3回ずつ成功した。反復回数を独立した30種類のテストへ数えず、診断用testのPassedも製品の合格件数に加算しない。

[最終集計](../../ci-results/ios-review/2026-10-26-storekit-ios27/verification-results.json)、[27.0の結果要約](../../ci-results/ios-review/2026-10-26-storekit-ios27/ios27-final-summary.json)、[26.2の結果要約](../../ci-results/ios-review/2026-10-26-storekit-ios27/ios26-final-summary.json)を参照する。今回Core/AppModel/全UIを再実行したわけではなく、それらの結果は第14節のcommit/実行記録のまま。実機・実課金・Androidの未確認項目も変更しない。

## 17. 2026-10-26 購入未完了時の表示統一

利用者の明示指示「取消でも購入失敗表示でよい」に従い、仕様正本のiOS課金節を更新した。取消・ネットワーク障害・不明エラーの購入API結果を、日英とも同一の購入失敗案内（日本語「購入できませんでした。」）に統一する。第16節は変更前の期待値での履歴として残す。SDKが取消をunknownへ変換する現象を修正したという意味ではない。

### 変更と検証条件

- 応援/有料起床の既存Storeで失敗表示と診断名を統一。取得できた取消result・商品ID・エラー詳細は診断に保持。不要になった取消/起床専用失敗の翻訳キーを削除した。
- 購入成功の検証/finish/配送、承認待ち案内、起床意図の破棄・チケット化は維持。実行中の繰り返し削除、D01〜D08、Android仕様へ変更はない。
- 既存10件のテスト名・取消/ネットワーク故障注入を維持。取消テストは新仕様の失敗表示と診断をassertし、成功/finish診断なし、成功取引なし、未完了取引なしを検証。起床では配送なし・意図破棄1回・購入中解除もassertする。テスト削除・skip・成功取引数/配送条件の緩和はない。表示の期待値変更は失敗隠蔽ではなく、今回明示された製品要件の変更である。
- CIは変更せず既存 `BearLockPurchases` schemeを使用。Xcode 27.1 (27A9275)、SDK 27.1、iPhone 16／iOS 27.0 (24A434) と26.2 (23C54)、並列なし、各10件を3反復。重複していた通知待ちhelperは一か所へ統一。待機時間は変更していない。テストserver操作によるunfinished情報の確認のみ公開 `AppStore.sync()` で同期し、製品へ自動syncは追加していない。

### 途中経過も含めた証拠

[今回の証拠](../../ci-results/ios-review/2026-10-26-purchase-failure-message/)に結果要約、rawログ、環境とソース指紋を保存する。途中の失敗を最終成功で上書きしない。

- 最初の27.0反復では取消2件は各3回成功したが、応援の承認後通知待ちが1反復失敗。承認直後の同期を追加した次の試行では、起動時回収の通知待ちが1反復失敗した（`ios27.log.gz` / `ios27-final.log.gz`）。
- 通知待ちでも毎回同期する試行は27.0で10件×3回成功したが、26.2では承認待ち2件が失敗。この広範な同期を撤去し、通知待ちは元の条件、unfinished情報確認は同期済みsnapshotという分担に戻した（`ios27-verified` / `ios26-verified`）。
- 26.2の再起動直後の再実行は、test hostの起動preflightがBusyで拒否され、テスト未実行。この試行をskipや成功として数えない（`ios26-final` / `ios26-ready` / `ios26-reinstalled`）。テスト終了後に長時間のsimctl診断収集のみ中断した。

実機Screen Time遮断・Family Controls認可・DeviceActivity、実App Store/Sandbox課金、Android固有項目の未確認は維持する。今回は全Core/AppModel/UIを再実行したものではなく、第14節の結果を参照する。新しい課金表示のUIスクリーンショットは取得していないため、既存画像を変更後の表示証拠に流用しない。

26.2端末を明示的にbootしてbootstatus完了を待ち、テストhostだけを再導入した `ios26-booted` では承認待ち2件は各3回成功した。一方、無関係な取引の最終snapshotへの再反映が1反復遅れた。処理前の存在確認と同様に、処理後も同期済みsnapshotで同じIDが存在するまで既存helperで待機するよう修正した。ID/商品/成功件数・タイムアウトは維持し、取引を再作成する操作は追加していない。

最終コード前の27.0再確認 `ios27-confirmed` では起動時回収が1反復失敗した。準備で不要なSupportStoreを一度作って破棄してから回収を試す構成を除去し、各テストで必要な時点に一度だけ生成する形へ変更した。回収テストは「サービスがない状態で取引作成→未完了の存在確認→初回サービス起動」という元の説明どおりの条件になる。製品の起動時回収経路は変更していない。

### 最終結果（修正ソース `cca3db1986bd9866512162ff04ab99b9cabde384`）

| 実行 | test case数 | 成功/失敗/skip | 反復 |
|---|---:|---|---|
| iOS 27.0 (`ios27-lifecycle`) | 10 | 10 / 0 / 0 | 各3回、30実行すべて成功 |
| iOS 26.2 (`ios26-lifecycle`) | 10 | 10 / 0 / 0 | 各3回、30実行すべて成功 |
| XcodeGenプロジェクトのメタデータ検証 | — | 成功 | `metadata.log.gz` |
| 本体・3extensionのDebug/Release simulator build | — | 両方成功 | `debug.log.gz` / `release.log.gz` |

[最終集計](../../ci-results/ios-review/2026-10-26-purchase-failure-message/verification-results.json)、[27.0要約](../../ci-results/ios-review/2026-10-26-purchase-failure-message/ios27-lifecycle-summary.json)、[26.2要約](../../ci-results/ios-review/2026-10-26-purchase-failure-message/ios26-lifecycle-summary.json)を参照。最初の4件は、取引状態の同期と今回承認された失敗表示方針の下で全件成功。取消とネットワーク障害をSDK内部で識別できるようにしたという主張ではない。元の作業ツリーの未コミット変更は保持した。

## 18. 2026-10-26 最新mainのiOS作業ブランチへの取込み

- 取込み前のiOSブランチは `10b6cb4bf667318de7f58de6b7123ca3c9b44f08`、取り込んだ `origin/main` は `3e433c9937f75e991e94c0c400c9a3b7fdf9c488`。mainへのマージではなく、`codex/ios-structure-verification` にmainを取り込む。
- コード/仕様正本は自動merge。対応表の導入文と末尾追記の競合は、重複禁止・Androidフィードバック・iOS SDK・StoreKit追跡・購入表示変更の記録をすべて残して解消した。main側の第13〜15節を維持し、iOS側の追記を第16〜17節へ整理した。購入失敗表示の統一とmain側の重複禁止の両方を保持する。
- 統合後に既存生成済みprojectのメタデータ検証、Core 82件、別プロセス保存整合性（writer 200更新・reader 4プロセス）、AppModel 26件を実行し成功。テスト失敗0・skip 0。本体と3extensionのDebug/Release simulator buildも成功。Xcode 27.1 (27A9275)、SDK 27.1、AppModelはiPhone 16／iOS 27.0 (24A434)を使用。
- [今回の集計](../../ci-results/ios-review/2026-10-26-main-integration/verification-results.json)と同ディレクトリの圧縮ログ・AppModel結果要約を保持した。通常/小型UI、StoreKit、Android試験は今回のmerge後には再実行していない。第14〜17節の履歴を統合後の新しい実行結果へ読み替えない。実機と実課金の未確認も維持する。
- 元のmain作業ツリーの未コミット変更と、iOS作業ツリーの未追跡生成プロジェクトは保持した。テスト削除・skip・期待値緩和、CIや別runnerの追加はない。

第18節のXcodeGen再生成について訂正: `main-integration/xcodegen.log.gz` はPATH上のコマンド未検出を記録しており、この時点では再生成できていなかった。メタデータ検証・テスト・ビルドは既存projectで成功した結果である（取込みでproject.ymlの変更はなかった）。1.3準備では既存XcodeGen実体の絶対パスで再生成し、アーカイブ内の本体と3extensionのversion一致まで検証する。旧ログは削除・改変しない。

## 19. 2026-10-26 CIの大文字メニュー操作失敗の追跡

- [run 201](https://github.com/hiroyoshii/bearlock/actions/runs/40281488393)の通常UIは27成功・1失敗・skip 0。ソースは `d901649`、Xcode 26.6、iPhone 17 Pro Max / iOS 26.5 (23F77)。小型試験とApp Store画像撮影は、後続main更新によるキャンセルのため完了していない。テスト添付を商品ページ用の撮影成果物と混同しない。
- 失敗は `SelectionControlsUITests.testSelectionAtAccessibilityTextSizeInEnglishAndJapanese`。英語の最大文字サイズでDate & TimeからRepeatへ切り替える操作後、メニューが残り、選択はDate & Timeのままだった。[画面録画の操作後フレーム](../../ci-results/ios-review/2026-10-26-ci-ui-menu/before.png)、[AX情報](../../ci-results/ios-review/2026-10-26-ci-ui-menu/before-ax.txt)、[結果要約](../../ci-results/ios-review/2026-10-26-ci-ui-menu/before-summary.json)を保持した。押下座標(217,528)はRepeatのAX範囲(17,465,400,126)の中心に一致する。表示だけで成功としていない。
- 既存helperの「主ウインドウを明示して座標を押す」経路を、Application基準の単回tapへ置換する修正候補を作成した。ネイティブメニューの別ウインドウを主ウインドウへ固定しないための変更である。旧ウインドウ探索とguardを削除し、選択成功の期待値・5秒の待機条件・既存全件を維持。操作の再送・タイムアウト延長・skipは追加していない。
- Application基準の候補を最終mainへ統合した `e3af31e` / CI run 206では、元の英語Repeat切替は通過したが、日本語通常サイズと日英最大文字サイズの2テストが失敗した。座標の参照先変更だけで解消したとはしない。既存CIの撮影成果物を回収し、公開用画像とテスト失敗の証拠を分けて保持する。
- 次の候補では、モード切替とメニュー項目選択を既存要素への単回のネイティブ `tap()` に統一し、200msのpressとApplication基準の座標回避処理を削除した。表示範囲/有限座標の検査、切替成功の期待値、5秒の待機は維持し、操作の再送はしない。
- [事前確認](../../ci-results/ios-review/2026-10-26-ci-ui-menu/native-tap-local/summary.json)はXcode 27.1 / iOS 27.0 / iPhone 17 Pro Maxで、CIで失敗した既存2件を対象に2成功・失敗0・skip 0。日本語通常サイズと日英最大文字サイズの実操作を含む。これはCIのiOS 26.5成功ではなく、ネイティブtapの事前検証に限る。最終CIの全通常/小型試験とafter画像の確認は未完了。

### run 207の結果と残る制約

- [run 207](https://github.com/hiroyoshii/bearlock/actions/runs/40295110542)、ソース `5766aa10d12a8f537925617111d197df1539fcc0`。通常UIは27成功・1失敗・skip 0、小型iPhone SE第3世代は7成功・失敗0・skip 0（既存7件の再実行）。両者はiOS 26.5 (23F77)。AppModelは26成功・失敗0・skip 0。メタデータ/XcodeGen、Core、別プロセス保存整合性、本体・3extensionのDebug/Releaseビルド、撮影は成功。StoreKitジョブも成功しているが、この回の課金xcresultは未回収で件数/skipの確定は未完了。
- 前回の日本語通常サイズと日英最大文字サイズの失敗2件は成功した。今回の失敗は `testDurationPresetsAndModeReflectCurrentValue` のスライダー調整後の「In」選択。50msのタップのdown/upは同じ(174,383.67)で、ボタンAX範囲(128,367.67,92,32)の中心と一致する。録画でも操作後にNowのままである。座標ずれとは断定しない。[要約・ログ・操作後画像・AX・入力イベント](../../ci-results/ios-review/2026-10-26-ci-ui-menu/ci-run-207/)を保持した。
- 同じ未変更コードの単独確認はXcode 27.1 / iOS 27.0で1回成功し、さらに10反復も成功した。CI 26.5の失敗解消の証拠ではない。ホームの定期更新とモードBindingの干渉は仮説であり、モード状態を子Viewへ移す修正候補は確証がないため撤去した。候補の局所テストは中断し、成功/skipや提出コードの検証には数えない。テスト削除、期待値緩和、再試行による成功扱いはしていない。
- 同じCIからPNG 32枚を回収し、全画像の1284x2778を検査。従来と同じ5画面（home/composeRepeat/confirmation/activeLock/setup）の日英10枚を目視確認した。[素材の正本](../../ci-screenshots/app-store-source.json)へソースと各SHA-256を保存し、main `80b15a5` へpush。製品コードはbuild 39 (`e3af31e`)と同一。静的fixture画像であり、実操作成功、実Screen Time遮断・Family Controls・DeviceActivity・Sandbox課金の証明ではない。App Store Connectへの差し替えは、画面操作ツールの接続エラー `cgWindowNotFound` のため未完了。
