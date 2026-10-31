# Android 公開準備

設定済みのGitHub Actionsから内部テストへ進める具体的な操作は [内部テスト配布手順](android-internal-testing.md) を参照。製品仕様の正本は [設計仕様](design-doc.md)。

## 内部テスト版のリリースノート

0.2.4候補用。一般公開の告知ではなく、内部テスター向けの説明。

日本語:

```text
Android版Bear Lockの内部テスト版です。
・設定からオープンソースライセンスをオフラインで確認できるようになりました。
・アプリやWebサイトを、今すぐ・あとで・日時指定・曜日繰り返しで制限できます。
・実行中カードと予定の作成・確認画面を改善しました。
・無料で30分後の起床を予約・取消できます。
・時間が重なる予定の作成・変更を防ぐよう修正しました。
・予定の保存と、エラー発生時の復旧処理を改善しました。
```

English:

```text
Internal test build of Bear Lock for Android.
• View open source licenses offline from Settings.
• Block apps and websites now, after a delay, at a set date, or on repeating weekdays.
• Improved active lock cards and schedule creation and confirmation screens.
• Request a free wake-up after 30 minutes, or cancel the request.
• Prevented creating or changing schedules with overlapping times.
• Improved schedule saving and error recovery.
```

## ストア説明案

Bear Lockは、選んだアプリやWebサイトを指定時間だけ休ませる、端末内で完結する集中アプリです。今すぐ、あとで、日時指定、曜日指定の繰り返しに対応します。終了時刻で自動的に解除するほか、残り時間が30分を超える場合は、無料で30分後の起床を予約できます。Android版には有料の即時起床はありません。実行中の繰り返しを削除すると、現在回の制限も終了します。

アプリ制限にはユーザー補助サービス、予約実行にはアラーム権限を使います。OS設定からの権限取消、強制停止、アンインストールを防ぐ機能はありません。Web制限とカテゴリ分類の対応範囲は、ブラウザ・端末の検証結果に合わせて公開前に確定してください。

## Accessibility申告の下書き

- 主用途: ユーザー自身が指定した対象・開始時刻・終了時刻に基づくアプリ画面の制限。
- 取得情報: 前面アプリの識別情報。Web制限実行中のみ、対応ブラウザの既知のアドレス欄。
- 使用方法: 端末内で対象を照合し、専用のブロック画面を表示する。
- 取得しない情報: ページ本文、パスワード。URLや閲覧履歴を保存・送信しない。
- `isAccessibilityTool=false`。障害者支援ツールとして申告しない。
- 説明と明示的同意: 設定導線に独立した説明ダイアログがあり、「同意しない」または「同意して設定へ」を選択する。
- 動画に収める手順: 初回起動→権限説明→拒否→再説明→同意→OS設定で有効化→通常UIの15分ロック→対象画面での遮断→時間経過後の解除。Debugの1分試験や比較用フィクスチャは申告動画に使わない。

## データの扱い

ネットワーク権限なし。広告、分析SDK、アカウント、クラウド同期なし。対象・予約・履歴・診断は端末内保存。Androidのクラウドバックアップと端末間移行は除外。Data safetyとPrivacy Policyには実際のreleaseビルドと依存関係を再確認した内容を登録する。

## 一般公開に向けて残る準備

- 正式な対応OS・端末・ブラウザ範囲
- 日本語/英語のPrivacy PolicyとSupport URL（現在のiOS公開ページの説明と整合）
- スクリーンショット・Accessibility申告動画・テスター手順
- 実機/OEM省電力・Android17高度な保護・実ブラウザ検証

アプリ登録・署名鍵・Secrets・Play連携の初期設定は完了済み。上記は一般公開用の申請素材・対応範囲の準備であり、すべてを今回の内部テスト開始の前提にはしない。実端末を接続できないため、この環境ではPlay経由の更新と実機/OEM試験は未確認。

実行タスクと完了条件は [Android製品版TODO](android-implementation-todo.md) の AND-10〜13 で管理する。
