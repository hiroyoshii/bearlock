# iOS応援課金版のリリース差分調査

2026-09-10時点。一般的な初回公開手順ではなく、過去の会話、Git履歴、Actions履歴、公開ストアを突き合わせた結果。

## 確認済みの経緯

- 「Bear Lockの設計計画を策定」でユーザーが「IAPは追加済み」と報告している。3商品は新規作成から始めず、既存レコードを使う。
- 「Review privacy and support pages」で、住所変更反映、税務フォーム、有料契約・銀行口座の処理待ちのため、課金を外して初回公開を先に進めると決めた。商品自体は削除せず保持する方針だった。
- 同タスクにあるAppleの審査原文では、2.1(b)の理由はIAPが審査に提出されていないこと。新バイナリとIAPの提出、およびIAP審査用スクリーンショットが要求された。別件の権限誘導ボタンの問題は「続ける / Continue」へ修正済み。
- 後続の「Explain W-8BEN form entry」で税務フォームの入力を扱っている。入力の相談は確認できるが、提出・承認完了の明示は確認できない。古い税務入力例を再利用する資料ではない。
- `05afb87` でiOSの課金実装・画面・画像と公開ページの課金説明を除去した。`074223b` でコードを復元、`682ef8a` で指定の短い文言に変更した。

## 現在の証拠

| 対象 | 確認できた状態 | 意味 |
|---|---|---|
| 公開アプリ | Apple ID 6806725013、1.0。Apple lookup APIの公開日時は2026-09-08T13:35:58Z | 初回公開は完了している |
| 本体価格 | 日本500円、米国2.99ドル（公開ページとlookup API） | 「無料で使えます」と不一致。リリース前に解消する |
| 最新TestFlight Upload | run 34238624935、build 29、`599c95c`、成功 | 署名・アップロード経路は利用実績あり。ただし課金復元前のビルド |
| 復元時のiOS CI | run 34245276386、`074223b`、成功 | ビルド・モック画面・画像生成は確認済み |
| 文言更新後の専用CI | run 34490176841、`87a5d62`、成功 | アプリ・全extensionのビルド、60件のcoreテスト、モック画面回帰が成功 |
| 文言更新後の通常CI | run 34490176835、成功を後続確認 | 最新文言のビルド・モック画面・スクリーンショット生成が成功 |
| StoreKit決済検証 | UIテストはStoreKitを呼ばず商品未取得状態を確認。StoreKit設定ファイル・決済用テストは見つからない | CI成功は実購入・保留・未完了取引の検証完了を意味しない |
| 公開Privacy/Support | 今回のHTTP取得は403。作業ツリーには別のAndroid対応と一緒に応援購入説明を追加する未コミット変更あり | ローカル変更を公開済みと扱わない。既存作業へ混ぜてcommitしない |

## 今回残る作業（順序）

1. **本体価格と説明を揃える。** 会話で採用した「無料＋任意支援」にするならApp Store Connectの本体価格を無料にする。有料を維持するなら画面とストア説明の「無料」を変更する。この調査では価格変更は実行しない。
2. **以前の保留事項の現在値を確認する。** 契約・税務・銀行の有効化と既存3商品の状態をConnectで確認する。有料公開されている事実はあるため、全て未着手という前提で再登録・再提出させない。現在の管理画面は取得できていないため、個別の完了までは断定しない。
3. **課金復元後のmainから新しいTestFlightビルドを作る。** 既存の `iOS TestFlight Upload` を利用する。build 29は今回の提出物に使わない。マーケティングバージョンは1.1設定済み。公開版は1.0だが、Connect内部の1.1審査状態は未確認。
4. **追加した決済経路を検証する。** 3商品の取得・価格、購入成功、再購入、キャンセル、保留からの完了、アプリ再起動後の未完了取引処理、オフラインからの再読み込み。StoreKit Testingで自動化できる部分とTestFlight/SandboxでApple側の商品設定を確認する部分を分ける。全項目を実機でしか検証できないとは扱わない。以前の通常機能の実機確認はユーザー報告済み。ただし、その後追加したロック終了修正の実機項目は別途 `docs/qa/ios-lock-expiry.md` に残る。
5. **申請内容をIAPなし版から更新する。** 既存IAPの審査画像を最新文言のものへ更新し、Review Notesに下記を追加。「1.0からIAPを削除した」等の旧提出用説明は今回の申請に残さない。Privacy/Supportの課金説明も今回の実装と整合させる。ストア掲載5枚は応援画面を含まないので、課金追加だけを理由に全て交換する必要はない。
6. **新ビルドと既存3商品を同じ審査提出に含める。** 前回2.1(b)の再発防止の核心。商品の「作成済み」「提出準備完了」と「審査への追加済み」を混同しない。

## 今回の追加審査メモ案

既存のScreen Timeテスト手順は維持し、IAP削除の旧説明を以下へ差し替える。

```text
This version adds optional consumable support purchases: Coffee, Lunch, and Dinner.
Open Settings > Support to view the products and make a purchase.
These purchases support development and do not unlock features or change app blocking.
The three consumable products are included in this submission together with the new app binary.
```

最後の文は実際に同じ提出へ3商品を追加してから使用する。

今回のアップデート説明案：`設定画面から、開発を応援できるようになりました。`

## 参照

- [日本の公開ストア](https://apps.apple.com/jp/app/bear-lock/id6806725013)
- [Apple lookup API（日本）](https://itunes.apple.com/lookup?id=6806725013&country=jp)
- [成功済みTestFlight build 29](https://github.com/hiroyoshii/bearlock/actions/runs/34238624935)
- [復元時のCI](https://github.com/hiroyoshii/bearlock/actions/runs/34245276386)
- [文言更新後の専用CI](https://github.com/hiroyoshii/bearlock/actions/runs/34490176841)
- [文言更新後の通常CI](https://github.com/hiroyoshii/bearlock/actions/runs/34490176835)
- [Apple：IAPの審査提出](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)


## 後続作業

- 本体価格の設定ミスはユーザーが訂正。2026-09-11 JSTにlookup APIで日本「無料」、米国「Free」へ反映済みと確認した。上の価格欄は調査開始時点の記録。
- 最新文言の日英審査画像と追加審査メモを `ios-support-release/` に保存した。
- StoreKit Testingによる決済回帰テスト7件を追加し、run 34494303902で成功。詳細と最終CI結果は `ios-support-release/README.md` を参照する。上の「StoreKit決済検証」欄は調査開始時点の不足を記録したもの。
