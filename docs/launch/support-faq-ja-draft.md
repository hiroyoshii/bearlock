# Bear Lock サポート / FAQ 草案

## Bear Lockとは？

Bear Lockは、使いすぎてしまうアプリやカテゴリを選び、指定した時間だけiOSのScreen Timeシールドでブロックする自己制御アプリです。ロック開始後、Bear Lock内に早期解除ボタンはありません。

## アプリがブロックされない

次を確認してください。

- Screen Time / Family Controls権限が許可されている。
- 少なくとも1つのアプリまたはカテゴリが選択されている。
- 現在時刻がロック時間内である。
- 開こうとしているアプリが直接選択されている、または選択カテゴリに含まれている。
- `Settings > Diagnostics` で `Diagnostics writable: Yes` になっている。
- Recent Eventsに `Shield.apply.succeeded` がある。

ロック中のはずなのに対象アプリが開ける場合は、Active Lock画面と `Settings > Diagnostics` のスクリーンショットを残してください。

## 権限ダイアログが出ない

次を試してください。

- iOS設定でScreen Timeが利用可能か確認する。
- Bear Lockを再起動する。
- 開発ビルドの場合はアプリを再インストールする。
- インストールしたビルドにFamily Controls entitlementが含まれているか確認する。

この機能はSimulatorだけでは完全に確認できません。Family Controls entitlementが有効な実機iPhoneまたはiPadが必要です。

## ロック終了後もアプリがブロックされたまま

次を確認してください。

- Bear Lockを開いて更新を待つ。
- Active Lockの終了時刻が過ぎているか確認する。
- `Settings > Diagnostics` で `ActiveLock.completed` と `Shield.clear.succeeded` を探す。
- テスト中で解除されない場合は、iOS設定からScreen Time権限を取り消して再許可する。

## なぜ解除ボタンがない？

Bear Lockは、ロック開始前に決めた約束を守るためのアプリです。アプリ内に早期解除ボタンを置かないことが、中心的な機能です。

ただし、iOS設定の変更、アプリ削除、アカウント側の操作など、Bear Lock外のシステム操作はiOSの管理下にあります。

## Bear Lockはどんなデータを送信する？

MVPではデータ送信を行いません。アカウント、クラウド同期、分析、広告、トラッキングはありません。ロック予定、アプリ選択トークン、Diagnosticsは端末内に保存されます。

## 問い合わせ時に必要な情報

- 期待していた動作。
- 実際に起きたこと。
- 端末モデルとiOSバージョン。
- 該当画面のスクリーンショット。
- `Settings > Diagnostics` のスクリーンショット。

サポート連絡先: TBD
