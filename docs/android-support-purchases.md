# Android 応援購入の配信設定

実装: Android 0.2.0 / versionCode 4。Coffee / Lunch / Dinner の任意の消費型購入。購入の有無でロック機能は変わらない。金額はアプリに固定せずGoogle Playの商品情報を表示する。

## 1. Play Consoleに商品を作成

Bear Lock（`com.hiyozoo.bearlock`）の一回限りの商品に以下の3商品を作成する。購入オプションは通常の購入を1つずつ設定し、配信する国・地域の価格を確認して有効にする。

| 商品ID | 表示名 | iOSコードの参考価格（AndroidではConsoleで設定） |
|---|---|---|
| `com.hiyozoo.bearlock.support.coffee` | Coffee | ¥500 |
| `com.hiyozoo.bearlock.support.lunch` | Lunch | ¥1,000 |
| `com.hiyozoo.bearlock.support.dinner` | Dinner | ¥2,000 |

消費型として購入後にconsumeする実装なので、同じ商品を繰り返し購入できる。サブスクリプションや機能解放には使用しない。

## 2. 購入検証用の公開鍵を登録

Play Consoleのこのアプリの「収益化の設定」等に表示される、ライセンス／アプリ内課金用のBase64 RSA公開鍵を取得する。これはアップロード用JKSの秘密鍵やサービスアカウントJSONとは別物。

GitHubリポジトリ → Settings → Environments → `android-internal` → Environment secrets に、`BEARLOCK_PLAY_LICENSE_KEY`として公開鍵を1行で登録する。

`Android Internal Release` workflowはこの値をビルドへ渡す。公開鍵はアプリ内でGoogle Playの購入データの署名検証に使用する。公開鍵なのでAPKに含まれる。署名用秘密鍵や決済カード情報はアプリへ含めない。

公開鍵未設定のビルドでは購入ボタンを無効にして「現在購入できません」を表示する。UI・ロック機能の修正版は未設定でも署名して配布できる。応援購入を有効にするには、公開鍵と商品を設定してから再ビルドする。

## 3. 内部テスト版を作る

1. GitHub Actions → Android Internal Release → mainで実行する。
2. 既存のアップロード鍵関連Secretsも従来通り必要。
3. 初回は署名済みAABをダウンロードしてPlay Consoleの内部テストへアップロードする。API設定済みの場合はworkflowのupload_to_playを利用できる。
4. テスターとして登録したGoogleアカウントで、Play経由の内部テスト版に更新する。
5. 課金テストにはPlay Consoleのライセンステスター設定も行い、Googleのテスト支払い方法が出ていることを確認する。

## 4. Data safetyと権限の確認

Billing 8.3.0のマージ後Manifestには`com.android.vending.BILLING`、`INTERNET`、`ACCESS_NETWORK_STATE`が加わる。0.1.2以前の「ネットワーク権限なし」という説明をこの版に流用しない。対象・予約・アクセスしたドメインをアプリから送信する処理は追加していないが、ストアの決済処理とSDKを含めて[Googleのデータ申告ガイド](https://developer.android.com/privacy-and-security/declare-data-use)を確認し、配布前にPlay ConsoleのData safetyを更新する。

日英Privacy/Supportのソースも更新した。配信時はアプリ内リンク先で更新版が公開されていることを確認する。

## 5. 実決済前の必須確認（未実施）

- 3商品の価格・通貨がConsoleと一致する。
- テスト購入の承認後、署名検証と消費が完了してお礼が表示され、同じ商品を再購入できる。
- キャンセルでは成功表示にならない。
- 保留中の支払いを完了扱いにせず、支払い完了後・アプリ再起動後に再照合できる。
- 通信切断・Google Play切断から再読み込みできる。
- consumeの失敗後は再購入せず再照合で完了できる。
- 購入の失敗・成功にかかわらず対象選択とロック機能が変わらない。

購入状態はGoogle Playを照会し、認識する商品・購入済み状態・正しい署名を確認してからconsumeする。アプリ独自の課金サーバーは追加していない。トークンや決済情報を診断ログへ記録しない。

ユーザー回答（2026-09-10）: 商品と公開鍵は未設定。ローカルの検証は実課金成功の証明ではない。

公式: [Billing統合](https://developer.android.com/google/play/billing/integrate) / [一回限りの購入](https://developer.android.com/google/play/billing/lifecycle/one-time) / [課金テスト](https://developer.android.com/google/play/billing/test)
