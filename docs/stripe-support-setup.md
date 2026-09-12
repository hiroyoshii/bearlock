# Bear Lock：Stripe応援決済の作成・公開手順

2026-09-13。日本の個人開発者による、利用済みの無料アプリへの任意・単発・特典なしのチップを想定。

## 今回用意したもの

- 日本語の応援ページ: https://bearlock.hiyozoo.com/support/development/
- 英語の応援ページ: https://bearlock.hiyozoo.com/en/support/development/
- 特商法表記: https://bearlock.hiyozoo.com/commerce/ （英語 `/en/commerce/`）
- 決済後の案内: https://bearlock.hiyozoo.com/support/thanks/ （英語 `/en/support/thanks/`）
- Androidの応援ボタンから応援ページへ移動。
- GitHub Actionsで公開Payment Linkを組み込み。APIキー・Webhook・課金サーバーは不要。
- 未設定時は準備中表示。実在しないリンクやテスト用リンクを本番の決済として表示しない。

本番Stripeアカウントの有効化、Payment Linkの作成、Stripe上の領収書設定、本番公開と実取引確認は、このコード実装だけでは完了しない。

## 1. Stripeの本番アカウントを有効化する

https://dashboard.stripe.com/ にログインし、本人確認・事業情報・入金口座など、Dashboardが要求する設定を完了する。
事業の実態に合った個人／個人事業主の情報を登録する。秘密鍵、本人確認書類、口座情報をGitHubやチャットに載せない。

説明の例（実態と一致することを確認）:

> 自分で開発・提供している無料アプリ Bear Lock の利用者から、その利用に対する任意のチップを受け取ります。追加機能、限定コンテンツ、会員権、物品などの対価はありません。支払いは単発で、アプリは支払いの有無にかかわらず利用できます。

Stripeは日本の個人への「寄付」は扱わず、提供済みの商品・サービスへの「チップ」は別に説明している。単に名称を変えるのではなく、この運用を実態と一致させる。Bear Lock個別の可否がStripeから確認されたという意味ではない。
公式: https://support.stripe.com/questions/requirements-for-accepting-tips-or-donations?locale=ja-JP

## 2. Webの表記を先に公開・確認する

本番リンク未設定でも応援ページ・特商法表記・プライバシーを公開できる（準備中表示）。
- https://bearlock.hiyozoo.com/commerce/
- https://bearlock.hiyozoo.com/privacy/
- support@hiyozoo.com が実際に受信・返信できることを確認する。
- 特商法表記の「氏名・住所・電話番号は請求時に開示」は、その請求に遅滞なく対応できる運用が必要。
- Stripeへ登録する本人情報自体は正しい実情報とする。
- サイトの表示だけでなく、決済画面・確認メール・領収書の住所表示も別途確認する。

Stripe Dashboardの事業詳細に、上記の特商法表記URLを登録する。設定名は「商取引に関する開示」等。
公開情報のサポートメールは support@hiyozoo.com、表示名・明細表記は実態に沿って設定する。表記が審査で認められることや住所が自動的に非表示になることは保証しない。
公式: https://support.stripe.com/questions/how-to-create-and-display-a-commerce-disclosure-page?locale=ja-JP

## 3. 本番Payment Linkを作成する

Webブラウザ版Dashboardで「テストモード／サンドボックス」ではなく本番アカウントを選ぶ。

1. [Payment Links](https://dashboard.stripe.com/payment-links) を開き、「作成」または「＋」を選ぶ。
2. 料金モデルで **顧客が支払う金額を選択する（Customers choose what to pay）** を選ぶ。
3. 次を設定する。金額は初期案で、アプリやサイト内には固定表示していない。

| 項目 | 設定 |
| --- | --- |
| タイトル | Bear Lock の開発を応援する / Support Bear Lock development |
| 説明 | いただいた応援は、Bear Lock の開発と運営に使わせていただきます。継続課金ではありません。すべての機能は無料で使えます。 / Support the development and operation of Bear Lock. One-time payment. All features remain free. |
| 通貨 | JPY（日本円） |
| 推奨額 | 300円 |
| 最低額 | 100円 |
| 最高額 | 10,000円 |

4. 定期課金、数量の変更、追加商品の提案、会員特典、任意の上乗せ料金を付けない。
5. 最初はカード決済で設定する。Apple Pay/Google Payの表示は対応端末・ブラウザ等による。配送先住所・電話番号の追加収集は有効にしない。決済に必要な情報の収集まで省略できるという意味ではない。
6. 「支払い後」の設定で、自社サイトへリダイレクトする場合は `https://bearlock.hiyozoo.com/support/thanks/` を指定する。日英切替あり。Stripeの標準完了画面を使っても受付は可能。
7. リンクを作成し、`https://buy.stripe.com/…` の **本番URL** をコピーする。

1本のリンクに日本語側は `?locale=ja`、英語側は `?locale=en` を付けて案内する。任意で入力した商品名・説明は自動翻訳されるとは限らないため、上記のように併記する。

公式: https://docs.stripe.com/payment-links/create
支払い後: https://docs.stripe.com/payment-links/post-payment

## 4. 確認メールと問い合わせ先を設定する

Stripe Dashboardの「顧客へのメール（Customer emails）」で成功した支払いの領収書メールを有効にする。
公開事業情報と領収書のプレビューを確認する。Stripeのテスト環境でも決済を試し、金額、単発払い、表示名、メール、住所表示、戻り先を確認する。
このサイトは決済成功をWebhookで判定せず、アプリの機能解放もしない。支払い状態の正本はStripe Dashboard。
公式: https://docs.stripe.com/receipts

## 5. GitHub Actionsに公開URLを登録する

本番Payment Linkは秘密鍵ではなく、利用者に公開するURL。GitHub Repository variableを使う。

1. https://github.com/hiroyoshii/bearlock/settings/variables/actions を開く。
2. 「New repository variable」。
3. 名前: `BEARLOCK_STRIPE_PAYMENT_LINK`
4. 値: 作成した `https://buy.stripe.com/…` の本番URL（クエリ文字列なし）。
5. 保存。
6. この変更をmainへpushした後、Actions → **Cloudflare Workers** → Run workflow → main を実行する。

既存のCloudflare用Secretsが必要。Stripe用のAPIキー・Secretは不要。
設定値がある場合、CIはテストURL・Stripe以外のURL・余計なクエリを拒否する。
設定値が空なら `site/stripe-payment-link.json` を読む。両方空なら決済導線は準備中のまま。

CLIがログイン済みなら、公開URLは対話入力で登録できる:

```bash
gh variable set BEARLOCK_STRIPE_PAYMENT_LINK --repo hiroyoshii/bearlock
```

Cloudflare Dashboardから直接ビルドする場合は、同名のビルド環境変数を登録し、ビルドコマンドに `python3 tools/configure_stripe.py` を設定する。

## 6. 本番公開後の確認

- 日英の応援ページから、自分のStripeアカウントの本番決済ページへ進む。
- 日本円、金額範囲、単発払い、商品名、特商法表記、連絡先を確認する。
- Androidの応援画面から同じページへ進む。
- テストモードでの成功・取消・失敗を確認済みとする。本番の実課金をする場合は、支払人の明示的な同意を得て行う。
- 完了ページを直接開いただけで支払い済みと判断しない。Dashboard／領収書で照合する。
- 二重支払いを促す再試行ボタンやアプリ内特典がないことを確認する。

## 7. Androidからの案内に残る確認事項

Google Playの公式FAQは「支援額の100%がクリエイターに渡り、デジタル特典がない」場合をPlay課金不要の例としている。通常のカード決済手数料の扱いとBear Lockへの適用は、このコード変更や資料調査で承認を得たものではない。
確認する場合は、上記の実態と「Stripe決済手数料以外の取り分はなく、追加特典なし」を具体的に伝える。
https://support.google.com/googleplay/android-developer/answer/10281818?hl=en

Play Consoleの販売者設定や住所公開の扱いは別件で、Stripe導入により変更されたとは扱わない。

## 開発・検証

```bash
python3 -m unittest discover -s tools/tests -v
python3 tools/configure_stripe.py
# 本番公開前に設定を必須にしたい場合
python3 tools/configure_stripe.py --require-live
```

本番URLがない現在、コード・ローカル検査の完了と、本番決済受付の完了を区別する。

### 今回の検証結果

- 決済URL検査・日英描画・未設定への切替・テンプレート不備の4テスト成功。
- サイト内のページ・アセットリンクがすべて実ファイルへ解決することを確認。
- Android `:product:assembleDebug` 成功（応援ページへのリンク変更を含む）。
- Stripe本番リンクは未作成。実決済、領収書、本番デプロイ、GitHub Actionsの成功は未確認。

## 本番リンクの設定状況

2026-09-13: 利用者が作成した本番 Payment Link を `site/stripe-payment-link.json` に登録。

https://buy.stripe.com/9B614m8fFcm12JQ9xvaAw00

GitHub の変数が未設定の場合も、このファイルからリンクを生成する。決済画面の設定・税カテゴリー・メール送信設定は、このリポジトリからは検証していない。
