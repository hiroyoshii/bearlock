# Bear Lock Manual Device QA Checklist

## 前提

- 実機iPhoneまたはiPad。
- Family Controls entitlementが有効なApple Developer Team。
- App Group、bundle identifier、provisioning profileが一致している。
- Macがない場合は、トラブル時に `Settings > Diagnostics` のスクショを確認する。

## Smoke Test

- 初回起動でFamily Controls権限要求が表示される。
- 権限拒否時にSetupへ戻る。
- `FamilyActivityPicker` で対象アプリを選択できる。
- 選択後、Homeに選択数が表示される。
- 空の対象選択ではlockを開始できない。
- Debug buildでは長時間lockがSafety policyで拒否される。

## Immediate Lock

- Release/TestFlightで30分のNow lockを開始する（DeviceActivityが受理する継続時間を使う）。
- 確定直後に対象アプリへShieldが出る。
- Bear LockのActive画面に残り時間が出る。
- 30分を超えて残っているロックでは、無料解除を予約・取消できる。
- 10分を超えて残っているロックでは、500円の商品価格が表示され、購入確認後に現在のロックだけ解除される。
- Shieldの「熊を起こす」からBear Lockの解除画面を開ける。
- Ask to Buyの承認が元のロック終了後になった場合、次回使える起床チケットになる。
- 終了時刻後、対象アプリが開ける。

## Delayed Lock

- Release/TestFlightで1分後開始、30分継続で予約する。
- Bear Lockをbackgroundにする。
- 開始時刻に対象アプリへShieldが出る。
- 終了時刻後、対象アプリが開ける。

## Recurring Lock

- 今日の曜日で数分後開始のrecurring ruleを作る。
- 開始後に親scheduleを削除しようとしてもcurrent lockが解除されない。
- 終了時刻後、Shieldが解除される。

## Recovery

- scheduled中にapp restartして予定が復元される。
- active中にapp restartしてActive画面が復元される。
- Screen Time権限を取り消した場合、Setup/recovery状態へ戻る。
- 終了時刻後にBear Lockを起動すると、expired active lockが完了し、Shield clear eventがDiagnosticsに残る。

## Diagnostics

- `Settings > Diagnostics` が開ける。
- Authorization、Target selections、Scheduled rules、Recurring rules、Active lock、Safety policyが表示される。
- Diagnostics writableが `Yes` になっている。
- Recent Eventsに操作ログが新しい順で表示される。
- `Clear Diagnostics` でイベント履歴を消せる。
- トラブル時はDiagnostics画面と該当操作直後の画面をスクショする。

## 選択・無効状態のUI確認

- 曜日は丸いボタン・チェックなし。選択中の塗りつぶし／非選択の白地と枠線が実際の設定と一致する。作成と編集の両画面で確認する。
- 曜日を全部解除すると作成／保存できず、1曜日選ぶと再び操作できる。
- 時間プリセットはチェックなしの標準ボタンで、通常文字は1列。120分→30分へ変更し、濃い塗りつぶしと表示値が一致する。スライダーをプリセット以外へ動かすと、どのプリセットも選択中にならない。
- 開始モードを切り替え、選択表示と入力欄が一致する。実行中は「今すぐ」を選べない。
- 保存済み対象を切り替え、「選択中」表示と対象の内容が同時に変わる。
- ロック中は対象を変更できない理由が読める。予定の編集不可と削除可能を混同しない。
- VoiceOverで曜日・時間プリセット・開始モード・保存済み対象の現在の状態を判別できる。時間スライダーがロック時間と分単位を読み上げる。
- 小型iPhone、最大のアクセシビリティ文字サイズ、英語／日本語で、曜日・時間・作成・保存・取消まで操作できる。
- グレースケール／「カラー以外で区別」を有効にしても、塗りつぶしと輪郭の差から状態を判別できる。
- 選択前後・無効状態の実画面を目視レビューする。CIのスクショ保存やisSelected検証だけを視覚確認の代わりにしない。
- 修正前と同じ端末・文字サイズ・選択状態の画像を比較し、依頼していない形状・アイコン・配色の変更が増えていないことを確認する。
- 標準ツールバーの保存は、AX frameの高さだけでタップ領域を断定せず、実際に保存して再表示した値を確認する。

## Known Limitations To Confirm

- iOS Settingsで権限を取り消す回避経路は完全には防げない。
- アプリ削除などOS/account levelの操作はBear Lockだけでは防げない。

## ロック終了の回帰確認

長時間の画面オフ、終了後の端末使用再開、本体未起動での解除、親予定の変更、実機ログの確認は [ios-lock-expiry.md](ios-lock-expiry.md) を参照する。CI成功だけで実際のScreen Time解除を確認済みとはしない。
