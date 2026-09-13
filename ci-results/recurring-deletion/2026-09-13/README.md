# 繰り返し予定の削除検証（2026-09-13）

製品コード: `b8eb9c394923f2795e23503e58847e88c47e18bc`。以降の変更はテスト手順・文書・証跡のみ。

## 結果

| 検証 | 結果 |
| --- | --- |
| Swift Core | 58 tests / 0 failures |
| iOS AppModel integration | 7 tests / 0 failures。削除保存失敗後の維持、再試行、監視停止失敗時の独立した解除を含む |
| iOS CI UI E2E | 15 tests / 0 failures。24時間繰り返しの削除確認、キャンセル、削除、再起動後の維持を含む |
| iOS Lock Lifecycle UI E2E | 10 tests / 0 failures |
| Android unit | 31 tests / 0 failures |
| Android build / lint | Debug・Release・lint 成功。GitHub Actions Android CIも成功 |
| Android 削除 E2E（ローカル API 34） | 成功。24時間予定2件、キャンセル、片方削除後も実際に入力遮断、最後の削除後は入力が届くことを確認 |
| Android 14 Acceptance（GitHub Actions） | 2回ともエミュレータ起動時にport 5554 connection refused。機能テスト未実行 |
| Android Store Assets（GitHub Actions） | 2回ともPixel Launcher ANRで撮影失敗 |

[iOS CI](https://github.com/hiroyoshii/bearlock/actions/runs/34743284861) / [Lifecycle](https://github.com/hiroyoshii/bearlock/actions/runs/34743284850) / [Android CI](https://github.com/hiroyoshii/bearlock/actions/runs/34743284864)

[Actionsログと結果](../../ios-review/b8eb9c394923f2795e23503e58847e88c47e18bc/summary.json)

## スクリーンショット

- [iOS 削除確認](../../ios-review/b8eb9c394923f2795e23503e58847e88c47e18bc/screenshots/e2e-active-recurring-delete-confirmation.png)
- [Android 削除確認](android/delete-confirmation.png)
- [Android 片方削除後も遮断](android/remaining-schedule-blocks.png)
- [Android 最後の削除後は対象アプリを操作可能](android/deleted-schedules-release.png)
- [Android 削除後の一覧](android/empty-schedule-list.png)

## テストの準備と限界

Androidの検証用エミュレータはこのタスク専用で、Bear Lockのデータだけを初期化して試験した。初回起動前のサービス有効化は接続されない場合があったため、アプリ起動→サービス有効化→接続確認の順に修正した。確認ダイアログは実際の大文字のボタン名で操作する。遮断試験ではWindowManagerの実際の描画完了を待ってからタップし、サービスのコールバックだけでは成功判定しない。この試験は削除結果を検証し、アプリ起動直後の遮断表示までの遅延上限は保証しない。

iOS UIテストのScreen Time対象とAPIはテスト用実装を使用する。配布ビルドの実機で、削除確定後の実際の解除、重なる別予定の遮断継続を確認する必要がある。Androidもメーカー固有の省電力設定下での動作は別途実機確認が必要。
