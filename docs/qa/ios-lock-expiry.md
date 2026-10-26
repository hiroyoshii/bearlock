# iOS ロック判定の再構成・検証記録

製品仕様・状態/削除/失敗時処理は [設計正本](../design-doc.md#ios)、現在の責務対応は [現行構造](../design-doc.md#structure) へ集約した。本書の重複した仕様表・構造図は移管済み。以下は変更時点の実測・検証手順・結果であり、現在の実装や実機解除の保証ではない。

報告された実機で何が起きたかは、この記録だけでは特定していない。古いテスト版から検証する際のリセット手順と、現行形式の通常更新を混同しない。

## 変更量（実測）

比較元は `b59e44d`。今回変更したSwiftファイルの物理行数。新規ファイルは変更前0行、削除ファイルは変更後0行として集計。テスト・文書・設定を本体コードの削減量に含めない。

| 区分 | 変更前 | 変更後 | 差分 |
|---|---:|---:|---:|
| 本体モデル | 634 | 525 | -109 |
| 画面・表示fixture | 1349 | 1368 | +19 |
| extension | 325 | 143 | -182 |
| サービス | 211 | 199 | -12 |
| テスト | 1538 | 1497 | -41 |
| 共有ロジック | 917 | 752 | -165 |
| 本体コード計 | 3436 | 2987 | **-449** |

## 自動検証

実施済み（WSL / Swift）:

- `swift test`: 70件成功。開始・終了境界、遅延・重複呼出し、長時間後、日またぎ、翌週、重複対象、読込・保存・適用失敗、保存時の変更禁止、繰り返し削除予約の永続化・期限反映・取消時の競合・起床との併用、登録差分の部分失敗と再試行、夏時間、古い単発予定の重複判定など。
- `python3 Scripts/test-lock-repository-processes.py`: 4つの独立プロセスからの保存200件を欠落なく確認。
- 変更したiOS Swiftファイルの構文解析、YAML解析、`git diff --check`。

GitHub Actionsの `iOS Lock Lifecycle` に用意した検証（今回の実行結果は未確認）:

1. 上記のSwiftテストと独立プロセスのテスト。
2. `BearLockLogicTests`。本体に本物のLockStoreと失敗する監視adapterを接続し、保存成功後の登録失敗・再試行、保存失敗、期限切れ解除、実行中の変更禁止、実行中の削除予約を確認。
3. 本体と全extensionのDebug/Release Simulatorビルド、スクリーンショット用アプリのビルド。
4. mock UIテスト。入口・権限復旧・即時作成・予約編集削除・実行中の操作制限に加え、実行中の繰り返し削除が予約表示になり、取消・再予約ができ、再起動後も現在回を維持することを確認。

`iOS CI` にも追加した2つの画面テストと実行中の繰り返しのスクリーンショット収集を含めている。

## 実機確認（未実施）

署名・Family Controls entitlementのある新ビルドで実施する。各手順では、対象アプリが使えるかを**Bear Lockを開く前に**確認する。

| ケース | 操作と確認 |
|---|---|
| 長時間スリープ | ロック開始後に画面を消し、終了時刻を十分過ぎてから対象アプリを開く。Bear Lockなしで解除されるか |
| 画面オンで期限通過 | 別アプリを使用して期限を越え、対象アプリが使えるか |
| 開始中・終了後に初めて端末を使用 | 予約前にスリープし、期間内または終了後に端末を使う。遅い開始で終了が延びたり、終了済み対象を再ロックしないか |
| 次の繰り返し | 本体を開かず次回の曜日まで経過させる。開始・終了と日またぎを確認。週末の曜日折返しも含める |
| 実行中の操作禁止 | 実行中は時刻・曜日の編集と無効化ができず、単発ロックは削除もできないこと。繰り返しは削除確認のキャンセルで維持され、確定後も現在回の終了時刻までは制限が続き、その後の回だけが実行されないこと。終了前の削除予約取消と、競合時に予約が維持されること。他の予定の制限は残ること。編集画面を開いたまま開始時刻をまたいでも保存できないこと |
| 重なる繰り返し | 別対象・同じ対象の両方で確認。先の終了で後の対象まで解除されないこと |
| Shield Configuration経由 | 遮断画面の構成要求が本当に発生したか、共通判定とAPI適用まで進んだか、対象アプリが使えるかを分けて観察 |
| 強制終了・再起動 | 本体を強制終了した場合、再起動後の初回認証前後の場合を分け、共有ファイルの読込とOSの実行を確認 |
| 登録失敗から復旧 | エラー表示後に本体を開き直し、予定が増えず、実際のOS監視が再登録されること |

`DeviceActivity.intervalDidStart/End`、`DeviceActivity.reconcile`、`ShieldRecovery.reconcile`、`Lock.reconcile` と `Shield.apply/clear.requested` を既存ログで区別する。`requested` はAPI呼出しまでの記録であり、実際に遮断が外れた証明ではない。ログがないだけで未呼出しとも断定しない。

Shield ConfigurationはOSが構成を要求したときの入口であり、対象アプリを開くたびに必ず呼ばれるという前提を置かない。独立した常駐処理や時刻トリガーは追加していない。

参考: [DeviceActivityの終了callback](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidend(for:))、[ShieldConfigurationDataSource](https://developer.apple.com/documentation/managedsettingsui/shieldconfigurationdatasource)、[ManagedSettingsのcategory policy比較](https://developer.apple.com/documentation/managedsettings/shieldsettings/activitycategorypolicy)。
