# Android / iOS スクショ比較

## 2026-10-25 両OSセグメント式・日時ボタン共通化

[比較ギャラリー](artifacts/screenshot-diff-2026-10-17/index.html) · [今回の実装/検証](docs/android-ios-execution-plan.md#2026-10-25-両osのセグメント式と日時ボタン共通化)

iOSは標準segmented Picker、Androidは既成MaterialButtonToggleGroupへ変更。Androidの日時指定/繰り返し/各編集の時刻ボタンは共通部品へ統一した。旧実装には15sp/17sp・余白の差があり、古いスクショだけが原因ではなかった。iOSは共有DatePickerでcompactを明示した。

**iOS側は変更前の公開画像4e9e377のまま。** Xcodeがないため今回のiOSアプリビルド・UIテスト・変更後撮影は未実施。ギャラリーにも旧画像と明記し、変更後の両OSが視覚的に一致したという扱いにしない。Androidの再撮影先は `artifacts/android-product/segments-time-2026-10-25/`。Beforeは直前の11c2e351。以下の前回撮影記録とは区別する。

今回のAndroid Debug APKは `93c882fea3179ba6644fac2d0127bed5303815be212102a4239cd9602055b507`。日英各16状態・操作前後128枚・16フローを同じAPKで撮影済み。詳細・検証範囲・失敗した中間試行は上記実行計画へ記録。iOSのコアテストや構文解析の成功を、iOS UIの検証完了とはしない。

## 前回：2026-10-25 公式アイコンへの置換と比較（11c2e351）

[比較ギャラリー](artifacts/screenshot-diff-2026-10-17/index.html) · [画像対応・レビューの正本](docs/qa/screenshot-review-2026-10-17.json) · [実装と検証記録](docs/android-ios-execution-plan.md#2026-10-25-自作アイコンの撤去) · [現在のiOS画像の出典](ci-screenshots/app-store-source.json)

基準は現在のiOS **4e9e377 / run 39049336403**。アイコン付きモードと灰色の未選択曜日へ復元済みの版であり、10/18レビュー時のdd83005とは違う。「セグメントに変える」「未選択曜日を白にする」という旧課題は撤回した。現在のiOSとの共通部分は維持し、不要な差分をAndroidで修正した。

| 対象 | 今回の変更 |
|---|---|
| アイコン（今回の追記） | 自作LineIcon、ピン留め/Web削除/カテゴリ開閉の記号文字を廃止。Google公式Material Icons Outlined全21種類へ置換。形状無変更、出典・固定commit・上流SHA256・ライセンス同梱。以下の配置修正は置換前から維持 |
| 作成・単発編集 | プリセットの選択を濃紺＋白文字へ。カプセル高さを調整。日付/時刻は別カプセル・別確定/取消へ |
| 繰り返し | 開始/終了をカプセルへ。曜日の7個一列/チェックなし/灰色の未選択は現行iOSと共通。次回日時/タイムゾーンは保持 |
| 編集 | 灰系背景と大見出し、予定/確認または状態/曜日/時刻/注意文のグループ、取消/保存のカプセルへ |
| 設定 | 大見出し、画像/データ/情報/診断のグループ、青いリンクと区切り線へ。Androidの権限/制限グループは保持 |
| 実行中 | 起床入口と予約済み表示を睡眠カード内へ移動。独立した起床領域・重複見出しを撤去 |
| 診断 | 長文dialogを廃止し、状態一覧→共有→アプリ/端末→既存ログ→消去のページへ |

比較は **画面7項目・部品5項目・目的/機能3項目・非対応1項目**。診断は今回ページへ置換したため画面比較へ移した。作成4モードと予定一覧は同じ部品だけ切り出し、撮影専用見出しやホーム内の別領域は除外する。開始確認/起床操作/応援は操作条件や機能の違いを明記。蜂蜜による即時起床結果と自然終了ホームは別操作のため、ペアにしない。iOSとの同条件の操作連写がないので、操作フローはAndroid単独の証跡とする。

今回のDebug APK: `11c2e35147929156734fe6d7d32ee206101b4dcfc497240916dbabe197979094`。撮影・インストール済みAPK照合・画像ハッシュの証跡は `artifacts/android-product/material-icons-final-2026-10-25/capture-result.json`。日英それぞれの16状態と保存/取消/編集/削除/無料起床/外部画面から戻る操作、計128枚・16フローの撮影が完了し、`completeLatestCapture=true` と各画像ハッシュの一致を確認した。撮影完了はUI一致や全OS受入とは区別する。

AndroidはAPI26、428×926dp・文字100%。原画像は無加工で保持。表示ではAPI26の画面外の黒帯と、明示した部品領域のみ切り出し、内容の再配置や縦方向の引き伸ばしはしない。OS間のRGB差分は使用しない。Before/After18組は同じAPI26の10/25アイコン置換直前（86558651）と今回の修正後で、状態・日時差も含む。部品座標・元画像・SHA256はreview.jsonへ記録する。

検証はDebug/Releaseビルド、単体57件、Lint 0 errors（21 warnings）、API26通常幅のnative4系統、320dp/文字200%のEditor/Recoveryが成功。無料30分のみ・予約取消・OS標準picker/スイッチ等は維持した。実機、TalkBack音声、全画面の大文字視覚受入、全OS、実30分待機は未実施。

再生成（Python/Pillow）:

```sh
python3 android-lab/scripts/android_screenshot_diff.py --review-manifest docs/qa/screenshot-review-2026-10-17.json --directory artifacts/screenshot-diff-2026-10-17
```

## 以下は過去の比較記録

**最新: Android 0.2.0** — [iOSとの整合・日英スクショ比較・残作業](docs/android-ios-parity-2026-09-10.md)。応援購入はPlay側の設定待ちです。

**過去の修正版:** [0.1.2の対象選択ボタン・読み込み・履歴修正](docs/android-picker-fix-2026-09-08.md)。[0.1.1のスクショ・17項目への対応](docs/android-ui-refresh-2026-09-08.md)も参照できます。以下は修正前の比較を履歴として残しています。

**2026-09-08レビュー:** [余白・配置・文字の問題一覧（17項目）](docs/android-ui-review-2026-09-08.md)。以下の画像は前回撮影分です。当時の問題と今回の修正結果を上のリンクから確認できます。

**左が iOS、右が修正後の Android です。** 主要5画面を日本語・英語で比較しています。

ホームの独自ヒーローと下部タブを撤去し、iOS の画面構成・既存素材・入力操作を基準に実装し直しました。繰り返し予約のオン／オフ、対象の保存・取消、固定フッターなどの不足も対応しています。

[実装内容・残る差分](docs/android-ui-parity.md) · [TODO](docs/android-ui-parity-todo.md) · [Android ソース](android-lab/product/src/main/java/com/hiyozoo/bearlock)

iOS はリポジトリに保存されている CI 撮影画像、Android は今回のエミュレーター撮影です。比較用画像は両方ともプレビュー状態であり、制限機能の実証と混同しないよう区別しています。原寸は両方 1284×2778、Android は 428×926 dp / 文字100%です。

## 日本語

### ホーム

ロゴ、対象、時間設定、予定の順序を統一。Android は実際の件数内訳を表示するため、iOS CI の「保存済みの選択」より対象カードが高くなります。

![ホーム: 左 iOS / 右 Android](docs/qa/android-ui-parity/compare/ja/home.png)

[赤色のピクセル diff](docs/qa/android-ui-parity/compare/ja/home-diff.png) · [iOS 原寸](docs/qa/android-ui-parity/ios/ja/home.png) · [Android 原寸](docs/qa/android-ui-parity/android/ja/home.png)

### セットアップ

同じ BrandHero・説明・二つの主操作。アクセス先は Android のユーザー補助／アラーム設定です。

![セットアップ: 左 iOS / 右 Android](docs/qa/android-ui-parity/compare/ja/setup.png)

[赤色のピクセル diff](docs/qa/android-ui-parity/compare/ja/setup-diff.png) · [iOS 原寸](docs/qa/android-ui-parity/ios/ja/setup.png) · [Android 原寸](docs/qa/android-ui-parity/android/ja/setup.png)

### 繰り返し

同じ横一列のモードと曜日、23:00→7:00。OS の上端余白、時刻ボタンの高さ、字体・行間が異なります。

![繰り返し: 左 iOS / 右 Android](docs/qa/android-ui-parity/compare/ja/composeRepeat.png)

[赤色のピクセル diff](docs/qa/android-ui-parity/compare/ja/composeRepeat-diff.png) · [iOS 原寸](docs/qa/android-ui-parity/ios/ja/composeRepeat.png) · [Android 原寸](docs/qa/android-ui-parity/android/ja/composeRepeat.png)

### ロック中

同じ Sleeping の熊・青いカード・カウントダウン。字体、カード内の間隔、上端位置、起床時刻が異なります。これは表示用フィクスチャで、実ロックの証拠は下に分けています。

![ロック中: 左 iOS / 右 Android](docs/qa/android-ui-parity/compare/ja/activeLock.png)

[赤色のピクセル diff](docs/qa/android-ui-parity/compare/ja/activeLock-diff.png) · [iOS 原寸](docs/qa/android-ui-parity/ios/ja/activeLock.png) · [Android 原寸](docs/qa/android-ui-parity/android/ja/activeLock.png)

### 確認

同じ Arming の熊と対象／開始／起床の要約。Android のキャンセル操作はテキストボタン、実際の確認はボトムシートです。

![確認: 左 iOS / 右 Android](docs/qa/android-ui-parity/compare/ja/confirmation.png)

[赤色のピクセル diff](docs/qa/android-ui-parity/compare/ja/confirmation-diff.png) · [iOS 原寸](docs/qa/android-ui-parity/ios/ja/confirmation.png) · [Android 原寸](docs/qa/android-ui-parity/android/ja/confirmation.png)

## English

<details>
<summary>英語版の5画面を開く</summary>

### ホーム

![home: iOS left / Android right](docs/qa/android-ui-parity/compare/en/home.png)

### セットアップ

![setup: iOS left / Android right](docs/qa/android-ui-parity/compare/en/setup.png)

### 繰り返し

![composeRepeat: iOS left / Android right](docs/qa/android-ui-parity/compare/en/composeRepeat.png)

### ロック中

![activeLock: iOS left / Android right](docs/qa/android-ui-parity/compare/en/activeLock.png)

### 確認

![confirmation: iOS left / Android right](docs/qa/android-ui-parity/compare/en/confirmation.png)

</details>

## 実際の操作とロック

以下は比較用フィクスチャではなく、通常の製品画面／サービスで行った操作の記録です。

| 確認 | 証拠 |
|---|---|
| 対象の取消・保存、Web永続化、履歴ピン、予約の作成・編集・削除、繰り返し切替 | [UI検証結果](docs/qa/android-ui-parity/interactions/result.json) |
| 空の選択では保存不可、選択すると保存可能 | [フッター検証](docs/qa/android-ui-parity/interactions/footer-result.json) |
| アプリのタップ遮断と自然終了後の入力復帰 | [Probeログ](docs/qa/android-ui-parity/verification/result.json) |
| Chromeのリンク遮断と自然終了後の遷移 | [Chrome結果](docs/qa/android-ui-parity/web-verification/result.json) |
| Debug / Release / AAB / lint、20ユニットテスト | [ビルドログ](docs/qa/android-ui-parity/build.log) · [検証サマリー](docs/qa/android-ui-parity/summary.json) |

[対象アプリ](docs/qa/android-ui-parity/interactions/targets-apps.png) · [Web](docs/qa/android-ui-parity/interactions/targets-web.png) · [カテゴリ](docs/qa/android-ui-parity/interactions/targets-categories.png) · [確認シート](docs/qa/android-ui-parity/interactions/confirmation-sheet.png) · [予約編集](docs/qa/android-ui-parity/interactions/scheduled-editor.png) · [繰り返し編集](docs/qa/android-ui-parity/interactions/recurring-editor.png) · [権限](docs/qa/android-ui-parity/interactions/permissions.png)

[実ロック中のホーム](docs/qa/android-ui-parity/verification/active-home.png) · [実アプリのブロック画面](docs/qa/android-ui-parity/verification/shield-active.png) · [Webのブロック画面](docs/qa/android-ui-parity/web-verification/web-shield-active.png)

### 320dp・文字150%

文字が縦に潰れないよう、この条件ではモード・プリセットを横スクロールにしています。TalkBackや全ての文字サイズの検証完了を意味するものではありません。

[ホーム](docs/qa/android-ui-parity/accessibility/home-320dp-font150.png) · [繰り返し](docs/qa/android-ui-parity/accessibility/repeat-320dp-font150.png)

## ピクセル diff の読み方

赤は RGB 各チャンネルの最大絶対差が24を超えた画素です。OSバー、撮影日時、字体、内訳表示、余白も含みます。**この割合は機能一致率や品質スコアではありません。** 画像の位置合わせや日時置換は行っていません。

| 画面 | 日本語の変更画素 | 英語の変更画素 |
|---|---:|---:|
| ホーム | 25.9% | 18.0% |
| セットアップ | 8.8% | 9.2% |
| 繰り返し | 13.9% | 15.9% |
| ロック中 | 24.0% | 27.5% |
| 確認 | 7.4% | 6.5% |

[画素差分と元画像のSHA-256](docs/qa/android-ui-parity/pixel-diff.json) · [再生成スクリプト](android-lab/scripts/android_screenshot_diff.py)

初期実装のスクショは [旧ギャラリー](docs/qa/android-product/README.md) に残しています。現在の UI はこのページが基準です。
