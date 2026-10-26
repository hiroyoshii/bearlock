# Android / iOS ロック判定の実装・検証記録（2026-09-13）

現行の [共通契約](../design-doc.md#common)、[iOS固有仕様](../design-doc.md#ios)、[Android固有仕様](../design-doc.md#android)、[責務対応](../design-doc.md#structure) は設計正本へ集約した。本書は当時の変更・テスト手順・結果の記録であり、製品仕様を別に定義しない。

特に、過去の『繰り返しは即時削除』という共通扱いを現在のiOSへ適用しない。適用先は正本のOS別仕様で確認する。無料起床・時刻/DST・失敗時処理・保存型・編集状態の仕様本文と図は本書から移した。

## 変更箇所

| 箇所 | 変更 |
| --- | --- |
| `Planner.kt` / `State` | `sessions`・`completed`・`reconcile` を廃止。`activeLocks` / `blockingLock` に判定を集約。DST、重複、実行中の編集禁止をiOSに統一 |
| `Store.kt` | 予定と対象履歴だけ保存。読み取り失敗を呼び出し元へ返し、ログ保存失敗が本処理を止めないよう変更 |
| `GuardService.kt` | 保存済み実行状態の更新を廃止。取得済み予定と現在時刻から遮断／解除を判断。読取失敗時は最後に読めた予定を保持 |
| `BoundaryReceiver.kt` | アラーム更新前の取消を廃止。同一PendingIntentで更新。登録失敗でもGuardを再評価し、画面に失敗・再試行を返す |
| `Shield.kt` | 除去に失敗した、まだ接続中のViewを保持して次の呼び出しで再試行。除去失敗後の二重追加を防ぐ |
| `MainActivity.kt` / `Composer.kt` / `HomeComponents.kt` | 実行中の繰り返しを一覧に残す。編集は無効化し、削除は確認後に許可する。編集画面も開始時に無効化。保存時刻はStoreの排他区間内で取得。保存後の監視失敗に再試行を用意 |
| テスト・CI | Swift/Kotlin共通の22件の時刻・対象データ、Androidの保存・OS操作失敗テスト、既存E2Eの保存形式対応 |

現在の状態・責務対応とOS固有の実行方式は、冒頭リンク先の設計正本へ集約した。

## テストの実行方法

```sh
swift test
ANDROID_HOME=/home/hiroyoshii/Android/Sdk ./android-lab/gradlew -p android-lab \
  :product:testDebugUnitTest :product:assembleDebug :product:assembleRelease :product:lintDebug :probe:assembleDebug
adb shell am instrument -w com.hiyozoo.bearlock/.LockInstrumentation
ADB=adb ANDROID_SERIAL=emulator-5554 BEARLOCK_QA_WITHOUT_EXACT_ALARM=1 \
  BEARLOCK_QA_SLEEP_THROUGH_EXPIRY=1 python3 android-lab/scripts/product_verify.py
```

`Tests/ContractFixtures/lock-contract.tsv` は両言語が直接読む期待値。タイムゾーン・境界・日またぎ・時刻巻き戻し・重複対象・夏時間の欠落／二重時刻を含む。native instrumentationは隔離したcache配下の保存領域で読取破損／書込失敗／ログ失敗を起こす。WindowManagerの除去失敗は注入したテスト用実装で再試行を検証する。実際の画面による遮断・自然解除はprobe E2Eで別に検証する。

今回の最終コードではSwift 57テスト（Linux）、Android 30テストが成功。共通データは22件。AndroidのDebug APK、Release AAB、lint（0 errors、13 warnings）が成功。native instrumentationの破損読取・AtomicFile書込失敗・ログ失敗・アラーム失敗後の再評価／再試行・View除去再試行も成功した。

追加テストでは、iOSの対象データと選択IDの保存失敗・再試行・JSON往復、重複ロックのホーム終了表示、Androidの入力タブの保持、編集元を変更しない下書き、30日先の単発予約を検証。Androidの実際のActivity再作成でも、設定の往復と、権限→対象選択→ホームの戻り先・取消前の対象・日時・時間が保持されることを確認した。`EditorInstrumentation` はAndroid 14 Acceptanceにも追加した。iOSの4プロセスによる保存競合テストも `LockStore.saveTargetSelection` を直接使う形へ変更し、160件の対象データと最後の選択IDが同時に保存されることを確認した。

Android 14エミュレーターでは、重複する繰り返しの実行中の編集／削除禁止、最初の期限後の遮断維持、最後の期限で本体を開かずに解除、終了後の編集／削除の再有効化、制限評価で保存ファイルが変化しないことを確認。既存の権限説明、対象選択の保存／取消、予約確認の取消、遅延予約の作成／編集／削除、通常の単発自然解除も成功した。正確なアラーム権限なしの通常／消灯中の期限経過についても、Bear Lock本体を開かずにProbeのタップが復帰することを確認した。

GitHub ActionsのAndroid CIは共通データ変更でも起動し、Android 14 Acceptanceは上記nativeテストと既存の通常・正確なアラーム権限なし・画面消灯中の自然解除試験を実行する。ローカル実行の合格とGitHub上の実行成功は別に扱う。この作業環境のGitHub CLIは未認証のため、GitHub上の実行結果は未確認。WSLではiOS SDKとXcodeを実行できないため、今回のiOS本体・Extensionのビルド、AppModelの6テストとUI E2Eは未確認（SwiftCoreテストとSwift構文解析は実行済み）。追加したAppModelの対象保存失敗／再試行テストは既存のiOS CI対象に含めた。

## テスト版データと実機での残確認

Androidの現行形式はschema 4で、schema 3の予定・対象履歴は保持して読み込む（起床予約・即時識別は上記契約参照）。schema 3より前のテスト形式は移行対象外。iOSの旧テスト形式も移行対象外であり、その形式から再インストールする検証端末では旧版のロック・監視を先に解除する。現行形式のデータ消去を通常の更新手順にはしない。旧データを読み取れない場合に勝手に上書きする救済処理は追加しない。ファイル名は既存の `locks-v1.json` のまま、形式は内部のschema値で判定する。

- iOS: 配布ビルドで長時間消灯→期限経過→対象アプリを開く。本体を開く前の解除を確認する。拡張が呼ばれるタイミングとScreen Timeの実際の解除はSwift unit testでは保証できない。
- Android: 複数メーカーの実機で長時間消灯／Doze／省電力設定／サービス再接続／再起動後の遮断と期限解除を確認する。エミュレーターの消灯試験はメーカー固有の停止動作を再現しない。
- 両方: 重複する繰り返しの先の期限で解除されず、最後の期限で解除されること、時刻巻き戻し時の再ロック、タイムゾーン変更時にも保存した地域の時刻が使われることを配布ビルドで確認する。

## 削除試験の記録

当時のAndroid検証対象: 毎日24時間の繰り返し、削除確認のキャンセル、同じ対象への重複予定を一つずつ削除した場合、削除保存失敗、監視停止失敗、アプリ再起動後の予定。現行仕様の定義は上記正本を参照する。

## 共通化の前提確認（2026-10-25）

`Tests/ContractFixtures/wake-contract.tsv` に14件の期待値を追加し、既存のSwift/KotlinのLockContractテストから、それぞれの製品コードを検証した。自然終了、起床期限の直前・到達・経過、時刻巻き戻し、開始時刻での起床、期間外の要求、異なるルール・前回・次回の要求を含む。両言語の日時単位はテスト入口で変換し、同じ期待値を読む。

`swift test` は72テスト、Androidの `:product:testDebugUnitTest` は58テストが成功した。共有したのは期待値であり、製品コードの実行実装ではない。製品コード・保存形式・課金・削除仕様・UIは変更していない。iOSアプリのビルドや実機の制限解除を検証したものでもない。

このデータは発生回あたり起床要求1件の範囲を扱う。複数一致時は現状、Swiftの `WakeState.effectiveEnd` が有効な要求の最短を採用し、Kotlinの `State.effective` は最初の一致要求を評価する。今回この挙動は変更せず、複数要求時まで両実装が同一とは判定していない。

同日の追加作業で共通の操作列とCI接続を拡張した。最新の基準・担当・適合状況・検証範囲は [仕様・責務・コード・テストの対応表](android-ios-structure-audit-2026-10-25.md) を参照する（2026-10-26に分類を再整理）。
