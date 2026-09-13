# P1・P2の復旧表示の検証

[仕様と検証観点](../../../docs/qa/monitoring-recovery.md)

Android製品コード: `5ed98779e3e017e0c834b6d4dd48bf96304c2d3e`。後続の製品変更はiOSの識別子と翻訳のみ。

## Android

- 単体テスト31件、Debug / Releaseビルド、lint成功。
- API 34の専用エミュレータでRecoveryInstrumentation成功。監視更新失敗→再試行失敗→画面移動→Activity再生成→再試行成功の順に実画面を操作し、保存した予定が変わらないことを確認。
- [GitHub Actions Android CI](https://github.com/hiroyoshii/bearlock/actions/runs/34746014798)も成功。
- [テスト結果](android/run.log)、[警告表示](android/monitoring-error.png)、[再試行後](android/monitoring-restored.png)。
- [Android 14 Acceptance](https://github.com/hiroyoshii/bearlock/actions/runs/34746014766)はエミュレータ起動時にport 5554 connection refusedで停止。機能テストには到達していない。
- Android Store AssetsはPixel LauncherのANRで停止。ストア用画像の生成成功は確認できていない。

## iOS

製品コード: `46aaacd`。Swift Core 58件、AppModel統合テスト9件は成功。AppModelの製品ロジックは`5ed9877`以降変更していない。

- 初回実行では読込失敗・復旧UIは成功したが、監視エラーの再試行ボタンをUIテストが識別できなかった。親VStackの識別子を除去し、ボタンの識別子を保持して再実行した。
- 再実行はiOS CIの「Assert mock UI e2e passed」を通過し、その後のスクリーンショット保存コミット`95a8f27`が生成された。ワークフローはE2E失敗時にこの保存ステップを実行しないため、E2E成功判定の通過を確認できる。
- 詳細ログ・テスト件数・今回の監視エラー画面の回収はGitHub Actionsの結果収集ジョブに依頼済み。記録時点では最新の収集コミットは未取得であり、ジョブ全体の最終conclusionは未確認。
- [初回のAppModel・UI結果](../../ios-review/5ed98779e3e017e0c834b6d4dd48bf96304c2d3e/34746014749.txt)
- [読込エラー画面](../../ios-review/5ed98779e3e017e0c834b6d4dd48bf96304c2d3e/screenshots/e2e-recovery-storage-error.png)
- [同じ保存データから復旧した画面](../../ios-review/5ed98779e3e017e0c834b6d4dd48bf96304c2d3e/screenshots/e2e-recovery-storage-restored.png)

## 実機での確認

障害を注入したテストで検証しているのは、処理失敗の保持・表示・再試行・復旧。iOSの実トークン、長時間消灯・再起動、Androidのメーカー固有の省電力設定下での自動解除は別途配布ビルドの実機で確認する。
