# Bear Lock Manual Device QA Checklist

## 前提

- 実機iPhone。
- Family Controls entitlementが有効なApple Developer Team。
- App Group、bundle identifier、provisioning profileが一致している。

## Smoke Test

- 初回起動でFamily Controls権限要求が表示される。
- 権限拒否時にSetupへ戻る。
- `FamilyActivityPicker` で対象アプリを選択できる。
- 選択後、Homeに選択数が表示される。

## Immediate Lock

- 1分のNow lockを開始する。
- 確定直後に対象アプリへShieldが出る。
- Bear LockのActive画面に残り時間が出る。
- Active画面に早期解除ボタンがない。
- 終了時刻後、対象アプリが開ける。

## Delayed Lock

- 1分後開始、1分継続で予約する。
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

## Known Limitations To Confirm

- iOS Settingsで権限を取り消す回避経路は完全には防げない。
- アプリ削除などOS/account levelの操作はBear Lockだけでは防げない。
