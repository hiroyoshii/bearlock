# iOS ロック判定の再構成と検証

## 今回の範囲

保存するロックの正本を `LockState.rules` と対象データに一本化した。実行中かどうかは現在時刻から求める。Androidは変更しない。

報告された実機で何が起きたかは未特定。今回の変更は判定・保存・監視登録の整理であり、OSのcallback配信やShield Configurationの再実行を保証するものではない。旧データ・旧監視の移行は実装しない。ユーザーテスト中のため、旧ビルドから検証するときはアプリとその制限をリセットして予定を作り直す。

## 残すもの・削除するもの

| 項目 | 変更後 |
|---|---|
| `rules`、対象のtokenData、対象の再利用履歴 | 維持。対象の再利用履歴はロック実行履歴とは別の機能 |
| `activeLock` / `completedLocks` の保存 | 削除。`activeLocks(at:)` で現在の予定から計算 |
| `scheduledEndsAt` と実行状態側の終了時刻 | 削除。対象となる予定の発生期間の終了時刻だけを使用 |
| 予定の `.completed` | 削除。有効・無効のみを保存。単発の終了は時刻で判定 |
| callback種別・rule ID・過去の完了履歴による解除可否 | 削除。自分の監視callbackを入口として、最新の全予定を評価 |
| 実行中の繰り返し予定の編集・無効化・削除 | 禁止。画面と保存時の両方で判定 |
| 親予定の変更後も実行中ロックを残す処理・終了専用監視 | 削除。実行中の親を変更しないため不要 |
| `ActiveLock` 型 | 画面表示用として維持。予定ID、開始、終了、対象から生成。保存しない |
| JSON repository、ファイル保護、プロセス間の排他 | 維持。読込・判定・shield適用を同じ排他区間で処理 |
| 既存診断ログ | 維持。Shield Configurationの重複loggerは共通loggerに統合。新しい診断基盤は追加しない |

## モジュールと状態

```mermaid
flowchart TD
    UI[本体: 作成・編集・削除] --> Store[LockStore: 保存時に検証]
    Store --> JSON[共有JSON: 予定と対象]
    UI --> Schedule[ScheduleController: 保存された予定とOS登録の差分を同期]
    Schedule --> OS[DeviceActivity]
    OS --> Monitor[Monitor extension]
    Target[遮断画面の構成要求] --> Config[Shield Configuration extension]
    UI --> Lifecycle[LockLifecycle: 現在有効な全予定の対象を求める]
    Monitor --> Lifecycle
    Config --> Lifecycle
    JSON --> Lifecycle
    Lifecycle --> Shield[共通ShieldController: 対象の和集合を適用 / 空なら解除]
```

```mermaid
stateDiagram-v2
    [*] --> 待機: 有効な予定を保存
    待機 --> 実行中: 開始時刻に到達
    実行中 --> 待機: 繰り返しの終了時刻に到達
    実行中 --> 終了: 単発の終了時刻に到達
    待機 --> 無効: 無効化を保存
    無効 --> 待機: 有効化を保存
    無効 --> 実行中: 期間内に有効化を保存
    待機 --> [*]: 削除
    無効 --> [*]: 削除
```

待機・実行中・終了は保存状態ではなく、時刻から求める状態。有効な繰り返し予定は、現在の発生期間の終了後に編集可能になる。実行中から無効・削除への操作は認めない。

## 判定と失敗時の処理

- 開始を含み終了を含まない期間、`start <= now < end` を使用。遅れて呼ばれても終了時刻を動かさない。
- 現在有効な予定の対象集合を合成。古い予定の終了callbackが来ても、別の実行中の対象を消さない。同じ対象の重複は一度にまとめる。
- Shieldの時刻表示も、その対象に該当する現在の予定から求める。複数該当時は最も遅い終了時刻を表示する。
- 判定は実行履歴を書かない。保存失敗が解除処理の前提条件にならない。データの読込失敗・実行中の対象データ欠損はエラーとし、不完全な対象集合を適用しない。
- 正常に空状態を読めた場合は残っている制限を解除する。App Groupにアクセスできない場合を空状態として扱って制限を変更しない。
- 本体は予定保存→監視同期→shield再評価の順に実行。監視登録に失敗しても、保存済み予定を取り消さない。登録失敗を表示し、次の本体再表示または予定操作で同期を再試行する。保存済みの場合は編集画面を閉じ、二重作成を防ぐ。
- 監視同期が失敗しても期限の再評価は実行する。個別の監視登録が失敗しても他の登録を試す。再試行ではOSに残っている同一登録を再登録しない。
- OS監視のstart/stop中は共有JSONの排他を保持しない。同期callbackによる待ち合わせを避ける。
- 登録済みの古い時刻がOSに残る失敗はあり得る。そのcallbackでも解除・適用の判定には保存済みの最新予定を使う。ただし、登録されなかった時刻に新たなcallbackが来る保証はない。本体を開くまで再登録できない場合がある。
- 繰り返し監視には曜日・時刻・timezoneを登録し、初回の日付を含めない。日またぎと夏時間でも予定の終了時刻に合わせる。単発監視の秒単位の正規化は維持。

## 自動検証

実施済み（WSL / Swift）:

- `swift test`: 52件成功。開始・終了境界、遅延・重複呼出し、長時間後、日またぎ、翌週、重複対象、読込・保存・適用失敗、保存時の変更禁止、登録差分の部分失敗と再試行、夏時間、古い単発予定の重複判定など。
- `python3 Scripts/test-lock-repository-processes.py`: 4つの独立プロセスからの保存160件を欠落なく確認。
- 変更したiOS Swiftファイルの構文解析、YAML解析、`git diff --check`。

GitHub Actionsの `iOS Lock Lifecycle` に用意した検証（今回の実行結果は未確認）:

1. 上記のSwiftテストと独立プロセスのテスト。
2. `BearLockLogicTests` 5件。本体に本物のLockStoreと失敗する監視adapterを接続し、保存成功後の登録失敗・再試行、保存失敗、期限切れ解除、実行中の変更禁止、削除後の登録解除再試行を確認。
3. 本体と全extensionのDebug/Release Simulatorビルド、スクリーンショット用アプリのビルド。
4. mock UIテスト。入口・権限復旧・即時作成・予約編集削除・実行中の操作制限に加え、実行中の繰り返しを一覧に残すこと、繰り返しの有効状態の変更をキャンセルできることを確認。

`iOS CI` にも追加した2つの画面テストと実行中の繰り返しのスクリーンショット収集を含めている。

## 実機確認（未実施）

署名・Family Controls entitlementのある新ビルドで実施する。各手順では、対象アプリが使えるかを**Bear Lockを開く前に**確認する。

| ケース | 操作と確認 |
|---|---|
| 長時間スリープ | ロック開始後に画面を消し、終了時刻を十分過ぎてから対象アプリを開く。Bear Lockなしで解除されるか |
| 画面オンで期限通過 | 別アプリを使用して期限を越え、対象アプリが使えるか |
| 開始中・終了後に初めて端末を使用 | 予約前にスリープし、期間内または終了後に端末を使う。遅い開始で終了が延びたり、終了済み対象を再ロックしないか |
| 次の繰り返し | 本体を開かず次回の曜日まで経過させる。開始・終了と日またぎを確認。週末の曜日折返しも含める |
| 実行中の操作禁止 | 予定を実行中にし、一覧から編集・削除できないこと。編集画面を開いたまま開始時刻をまたいでも保存できないこと |
| 重なる繰り返し | 別対象・同じ対象の両方で確認。先の終了で後の対象まで解除されないこと |
| Shield Configuration経由 | 遮断画面の構成要求が本当に発生したか、共通判定とAPI適用まで進んだか、対象アプリが使えるかを分けて観察 |
| 強制終了・再起動 | 本体を強制終了した場合、再起動後の初回認証前後の場合を分け、共有ファイルの読込とOSの実行を確認 |
| 登録失敗から復旧 | エラー表示後に本体を開き直し、予定が増えず、実際のOS監視が再登録されること |

`DeviceActivity.intervalDidStart/End`、`DeviceActivity.reconcile`、`ShieldRecovery.reconcile`、`Lock.reconcile` と `Shield.apply/clear.requested` を既存ログで区別する。`requested` はAPI呼出しまでの記録であり、実際に遮断が外れた証明ではない。ログがないだけで未呼出しとも断定しない。

Shield ConfigurationはOSが構成を要求したときの入口であり、対象アプリを開くたびに必ず呼ばれるという前提を置かない。独立した常駐処理や時刻トリガーは追加していない。

参考: [DeviceActivityの終了callback](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidend(for:))、[ShieldConfigurationDataSource](https://developer.apple.com/documentation/managedsettingsui/shieldconfigurationdatasource)、[ManagedSettingsのcategory policy比較](https://developer.apple.com/documentation/managedsettings/shieldsettings/activitycategorypolicy)。
