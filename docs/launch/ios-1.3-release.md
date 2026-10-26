# iOS 1.3 リリース準備

## バージョンと対象

- 2026-10-26 JST、Apple lookup APIで日本/米国の公開版1.2（公開日2026-09-28）、無料を確認。次版は1.3とする。公開済み1.2はApp Store Connectでbuild 35と確認した。
- 確認先: [日本](https://itunes.apple.com/lookup?id=6806725013&country=jp) / [米国](https://itunes.apple.com/lookup?id=6806725013&country=us)。Webページの古いキャッシュではなく取得時のlookup応答を基準とする。
- 対象はmain。利用者の最終変更 `c719d9a` を統合した製品ソースは `e3af31e`。提出用1.3 build 39は、このソースの [TestFlight run 39](https://github.com/hiroyoshii/bearlock/actions/runs/40289265145) からアップロード済み。設定の正本は `project.yml` の `MARKETING_VERSION` で、本体と3extensionは1.3。
- UIテスト操作の修正を含むmain `5766aa1` の [iOS CI run 207](https://github.com/hiroyoshii/bearlock/actions/runs/40295110542) は完了。通常UIは27成功・1失敗・skip 0、小型は7成功・失敗0・skip 0。StoreKitジョブと撮影は成功。残るモード切替1件は原因未確定。製品コード・project.yml・Package.swiftは `e3af31e` と同一で、build 39をテスト修正や素材更新だけで作り直さない。
- build番号は既存 `iOS TestFlight Upload` workflowの `github.run_number` を使う。ローカルの既定build 1を配布build番号に使わず、別の番号管理やupload経路を追加しない。

## 更新説明（日本語、App Store Connect用）

・実行中の繰り返し予定を削除した場合、現在の回の終了後に削除するようにしました。削除予約の取消にも対応しています。
・予定が重複する作成・編集を防止するようにしました。無料の解除予約を取り消すことで他の予定と重なる場合も、予約を保持して取消を止めます。
・保存できなかった場合に、選択内容や編集中の予定を保持する処理を改善しました。
・ロック方法、曜日、日付・時刻の選択と、大きな文字サイズでの表示を改善しました。
・購入が完了しなかった場合の案内を統一しました。

## What's New（English、App Store Connect用）

• Deleting an active recurring schedule now takes effect after the current occurrence ends. Pending deletion can also be cancelled.
• Creating or editing overlapping schedules is now prevented. Cancelling a free wake-up is also prevented, preserving the request, if it would conflict with another schedule.
• Improved preservation of your selections and schedule edits when saving fails.
• Improved lock mode, weekday, date and time controls, including larger text sizes.
• Unified the message shown when a purchase is not completed.

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

## App Store Connectへの設定履歴（2026-10-26 JST）

- main `8ab300f` の [TestFlight run 37](https://github.com/hiroyoshii/bearlock/actions/runs/40279497407) は成功。配信1.3にbuild 37を選択・保存し、暗号化質問を実装内容に合わせて回答した。
- 日本語の更新説明と概要、App Reviewメモを保存。旧「途中解除できない」の説明を現在の無料/有料起床へ修正。ストアの既存ローカライズは日本語のみで、英語ローカライズの追加はしていない。既存画像は保持した。
- 1.3 (37) を提出下書きに追加し、「審査準備完了」を確認。「審査へ提出」は未操作。公開方法は従来の「承認後自動リリース」のまま。
- 通常iOS CI run 200のStoreKitは、macos-15/Xcode 16.4で対象シミュレーターが存在せず未実行。既存ジョブを本体CIと同じmacos-26/iPhone 17 Pro Maxへ変更し、テスト・期待値・ジョブ数は維持した。通常UIステップも失敗しているため、新しいCI全体の結果確認が必要。CI合格の確認前に審査提出しない。
- run 201では、iOS 26.5の最初のStoreKitテストで `SKInternalErrorDomain Code=3` が発生し、設定保存や取引リセットに失敗したまま20分でタイムアウトした。Appleの[既知のCLI問題の報告](https://developer.apple.com/forums/thread/826971)と一致する。既存runnerには26.2/26.4/26.5があるため、StoreKitジョブだけ26.2の新規端末を明示して実行する。非公開APIや製品側の回避処理、テストのskipは追加しない。修正後のCI成功は未確認。
- 公開済み1.2はApp Store Connectでbuild 35と確認（TestFlight元commit `150b970`）。それ以降の差分で更新説明を具体化して保存し直した。旧画像をそのまま保持した前回の準備報告は不十分であり、1.3のCI撮影成果物での差し替えは未完了。審査提出前に完了する。
- 後続のUI変更を含むmain `95ea8eb` はTestFlight run 38でアップロード成功。ただし、さらにmainへ修正が追加されているため、このbuildを最終提出物と確定していない。通常UIの修正候補と未確認範囲は[対応表第19節](../qa/android-ios-structure-audit-2026-10-25.md#19-2026-10-26-ciの大文字メニュー操作失敗の追跡)を参照する。最終mainが揃うまで撮影・提出ビルドの作り直しを繰り返さない。

- 最終製品ソース `e3af31e` のbuild 39へ関連付けを変更・保存し、暗号化質問も回答済み。旧build 37の提出下書きからアプリを外し、画像差し替えのため1.3を「提出準備中」に戻した。日本語の更新説明・商品説明・審査メモは保存済み。既存の承認済み消耗品4件を確認した。最新CIの全件成功、スクリーンショット差し替え、提出下書きへの再追加は未完了であり、審査提出はしていない。
- run 207の画像32枚を回収・検査し、従来と同じ5画面の日英10枚をアップロード用に準備した。素材の正本はmain `80b15a5` にpush済み。App Store Connectの既存ギャラリーはまだ変更していない。画面操作ツールが `cgWindowNotFound` で接続できず、差し替えと提出下書きへの再追加が残っている。状態を「審査準備完了」とは報告しない。
