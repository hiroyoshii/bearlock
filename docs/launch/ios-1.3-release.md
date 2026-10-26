# iOS 1.3 リリース準備

## バージョンと対象

- 2026-10-26 JST、Apple lookup APIで日本/米国の公開版1.2（公開日2026-09-28）、無料を確認。次版は1.3とする。App Store Connect内部の作成済みバージョン/審査状態は未確認。
- 確認先: [日本](https://itunes.apple.com/lookup?id=6806725013&country=jp) / [米国](https://itunes.apple.com/lookup?id=6806725013&country=us)。Webページの古いキャッシュではなく取得時のlookup応答を基準とする。
- 対象は `codex/ios-release-1.3`。main `3e433c9` とiOS修正を統合した `9e6d21e` が基準。設定の正本は `project.yml` の `MARKETING_VERSION`。本体と3extensionへ1.3を適用する。
- build番号は既存 `iOS TestFlight Upload` workflowの `github.run_number` を使う。ローカルの既定build 1を配布build番号に使わず、別の番号管理やupload経路を追加しない。

## 更新説明（日本語、App Store Connect用）

予定作成や編集時の操作性と安定性を改善しました。

・予定が重複する場合に、保存前にお知らせするようにしました。
・保存できなかった場合に、選択内容や編集中の内容を保持するよう改善しました。
・曜日や時刻の選択、大きな文字サイズでの表示を改善しました。
・繰り返し予定の削除予約、起床操作、購入時の案内を改善しました。

## What's New（English、App Store Connect用）

Improved the usability and reliability of creating and editing schedules.

• Overlapping schedules are now detected before saving.
• Your selections and edits are preserved when a save cannot be completed.
• Improved weekday and time controls, including support for larger text sizes.
• Improved recurring schedule deletion, wake-up actions, and purchase messages.

## App Review用メモ（English）

Bear Lock uses Apple's Screen Time APIs for voluntary self-control. No account or sign-in is required.

Grant Family Controls authorization, select at least one app or category, and create a Now lock. Open the selected app to confirm that the Screen Time shield appears. Return to Bear Lock to inspect the active lock and its end time. Also test delayed, fixed-date and recurring schedules. New schedules cannot overlap another enabled schedule. Existing saved schedules are retained.

During an active lock, free wake-up can be scheduled for 30 minutes later when more than 30 minutes remain. Cancelling that request is rejected if restoring the original end time would conflict with another enabled schedule. A recurring schedule deleted during its active occurrence remains active until that occurrence ends; its pending deletion can be cancelled subject to schedule validation.

The consumable immediate wake-up product is com.hiyozoo.bearlock.wake.now. A verified purchase ends only the selected active occurrence. Future recurring occurrences remain scheduled. If a pending purchase is approved after that occurrence has ended, it becomes a wake-up ticket for later use. Pending purchases retain their pending status; cancelled or failed purchase attempts show the same unsuccessful purchase message and grant no delivery.

Settings also offers optional consumable support products: com.hiyozoo.bearlock.support.coffee, com.hiyozoo.bearlock.support.lunch, and com.hiyozoo.bearlock.support.dinner. These grant no entitlement and do not change any lock or schedule. Prices are loaded from StoreKit.

## 提出素材と配布手順

- 商品説明/審査メモの基礎は既存 [日本語](app-store-connect-ja-draft.md) / [英語](app-store-connect-draft.md)。公開ストアの古い「途中解除なし」等の説明が残る場合は、今回の起床仕様と整合する原稿へ更新する。
- スクリーンショットは [既存候補](screenshot-candidates.md) と元作業ツリーで編集中のApp Store素材を確認する。この準備ではユーザーの未コミット素材を取り込んだり上書きしたりしない。mock UIの試験画像を実Screen Time遮断の証拠にしない。
- このリリースブランチをmainへ取り込み、既存 [iOS TestFlight Upload](../../.github/workflows/ios-testflight.yml) をmainで実行する。生成した署名付きbuildの1.3、本体/extensionのversion一致、App Store Connectの処理完了を確認する。
- App Store Connectで1.3を作成/選択し、対応するbuild・日英更新説明・スクリーンショット・審査メモ・既存IAPの状態を確認する。商品登録や価格/販売状態はローカルStoreKit設定では確認できない。
- TestFlightの実機でFamily Controls認可、実遮断/自然終了、DeviceActivity、無料/有料起床とSandbox商品の取得・配送を確認してから審査提出する。実施記録は [既存対応表](../qa/android-ios-structure-audit-2026-10-25.md)へ追記する。

## CIへの引き渡し

`project.yml` の1.3設定とこの更新説明をmainへ取り込み、既存iOS CIを実行する。署名・TestFlight uploadは既存 `iOS TestFlight Upload` を使用する。新しいrunner、テスト一覧、署名/配布経路は追加しない。

ローカルのXcodeGen実行PATH・シミュレーター言語/StoreKitサーバーの問題は、既存CIや公開済み1.2の問題と混同しない。Privacy Manifestやテスト既定言語の追加は今回の変更から外した。

## App Store Connectへの設定（2026-10-26 JST）

- main `8ab300f` の [TestFlight run 37](https://github.com/hiroyoshii/bearlock/actions/runs/40279497407) は成功。配信1.3にbuild 37を選択・保存し、暗号化質問を実装内容に合わせて回答した。
- 日本語の更新説明と概要、App Reviewメモを保存。旧「途中解除できない」の説明を現在の無料/有料起床へ修正。ストアの既存ローカライズは日本語のみで、英語ローカライズの追加はしていない。既存画像は保持した。
- 1.3 (37) を提出下書きに追加し、「審査準備完了」を確認。「審査へ提出」は未操作。公開方法は従来の「承認後自動リリース」のまま。
- 通常iOS CI run 200のStoreKitは、macos-15/Xcode 16.4で対象シミュレーターが存在せず未実行。既存ジョブを本体CIと同じmacos-26/iPhone 17 Pro Maxへ変更し、テスト・期待値・ジョブ数は維持した。通常UIステップも失敗しているため、新しいCI全体の結果確認が必要。CI合格の確認前に審査提出しない。
