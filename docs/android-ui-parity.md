# Android UI を iOS に揃える変更

> 過去の調査・実装・比較の記録。現行の製品仕様・OS別方針・構造は [設計正本](design-doc.md) に集約済み。本書の当時の目標や案を、現行の仕様・未採用案の実行指示として扱わない。

前の Android UI は、機能検証用の画面構成を製品 UI として拡張してしまっていた。ホームの大きなイラスト、別画面の作成フォーム、下部タブは iOS の設計ではなかった。今回は現行 SwiftUI を基準に Android の画面を組み直した。

## 実装した対応

| 項目 | Android の変更 |
|---|---|
| ホーム | 同じ BrandHeaderLogo と設定ボタン。対象カード、ロック状態、作成フォーム、ロック予定を同一スクロール内へ配置。下部タブを撤去 |
| 対象選択 | 折りたたみ詳細、アプリ／カテゴリ／Web 件数、最近の選択、ピン留め／解除／削除。選択保存を永続化し、キャンセル・画面再生成時のドラフトを分離 |
| 小画面・文字拡大 | 360dp 未満または font scale 120% 超ではモードとプリセットを横スクロールにし、文字を縦に潰さず操作できるよう調整 |
| 今すぐ | 120 分を初期値とし、15〜720 分のスライダーと 15／30／60／120 分のプリセット |
| 後で | 30 分を初期値とする 5〜240 分のステッパー。開始・起床時刻もフォーム内に表示 |
| 日時指定 | 日時選択と同じ時間スライダー。OS の日付・時刻ダイアログから入力 |
| 繰り返し | 日曜始まりの横一列、初期選択は月〜金。開始 23:00、終了 7:00。翌日をまたぐ時間を計算 |
| 確認 | BearVisualArming、タイトル、変更不可の説明、対象／開始／起床の要約、確定／キャンセルをボトムシートへ |
| ロック中 | BearVisualSleeping を使用。青いカード、残り時間、起床時刻。実行中は対象変更不可、「今すぐ」を隠して次の予約へ |
| セットアップ | BrandHero と同じ説明・二つの主操作。Android の権限手順は専用の状態画面へ |
| 編集・削除 | ホームの予定行から編集・削除。繰り返しの有効／無効を追加し永続化。既存の保存データは enabled 欠落時に true として読み込み |
| 設定 | 同じ Ready の熊、データの扱い、プライバシー／サポート／バージョンのグループ。Android 固有の権限・対応範囲・言語を追加。診断は Debug のみ |
| ブロック画面 | iOS と同じ Locked の熊、対象名、終了時刻、OK。Android ではユーザー補助オーバーレイで表示 |

繰り返しを無効化しても、既に開始している Session は変更しない。再有効化時は他の予約との重複を再検証する。対象や予約の更新で既存の実行中ロックを解除する経路は追加していない。

## スクショ比較の条件

- iOS はリポジトリの `ci-screenshots/app-store-ja` / `app-store-en` にある CI 撮影画像。画像更新コミットは `c0cee2703cb0883e0b2c6f28a1c9fa48a5f84303`。
- iOS は `BearLock/App/ScreenshotSupport.swift` のプレビュー状態を使った画面。今回 WSL で iOS Simulator を新しく実行したわけではない。
- Android は Pixel 9a / Android 15 API 35 エミュレーター。比較時のみ 1284×2778、density 480、font scale 1.0 に設定し、428×926 dp とした。終了時に元の設定へ戻す。
- Android 比較画像も Debug 専用 `ScreenshotActivity` の読み取り専用フィクスチャ。製品と同じ UI コンポーネントを描画するが、ルールを書かず、タッチによる操作も無効。Release APK には含まれない。
- 実際の保存・編集・ブロックは別の通常 MainActivity / GuardService で検証し、`interactions` / `verification` に証拠を分ける。
- 元 PNG は無加工。並列図だけを同じ幅に縮小し、ピクセル差分は全画面で RGB 各チャンネルの最大絶対差が 24 を超える位置を赤で表示。位置合わせ、日時の置換、OS バーの隠蔽はしていない。

## 残る差分

| 差分 | 理由・扱い |
|---|---|
| フォントの太さ、文字幅、改行、アイコンの線 | iOS のシステムフォント・SF Symbols と Android のフォント・独自ベクター描画の差。同じ画面構造でも完全なピクセル一致にはならない |
| ステータスバー、ナビゲーションバー、上端の余白 | OS のシステム領域と safe area / insets の差 |
| ホームの件数内訳 | iOS CI はトークンのないプレビューで「保存済みの選択」を表示。Android はアプリ 2・Web 1 を表示。実 iOS の件数ピルを定義する TargetSelectionButton.swift の構造へ合わせている |
| 日時・残り時間 | 撮影日時とタイムゾーンが異なる。アクティブ比較の残り時間はレイアウト確認用固定値。実終了の証拠にはしない |
| 許可手順 | iOS は Screen Time、Android はユーザー補助と正確なアラーム。iOS の権限名を Android に表示しない |
| 対象ピッカー | iOS の FamilyActivityPicker は Android にない。保存・キャンセルの枠組みを揃え、内部は検索可能なアプリ一覧、ドメイン入力、端末カテゴリ |
| 日時入力・モーダル・ブロック画面 | Android の OS ピッカー／Dialog／ユーザー補助オーバーレイで実装。iOS のシステムシートや ManagedSettings の描画そのものは移植できない |

ピクセル差分率は描画の違いを示す数値であり、機能一致率・品質スコアではない。残る Android の制限能力・端末別動作の検証範囲は [release preparation](android-release-preparation.md) を参照。今回の UI 修正で OS による制約が解消したとは扱わない。

## 検証方法

- `:product:assembleDebug :product:assembleRelease :product:bundleRelease :product:testDebugUnitTest :product:lintDebug :app:testDebugUnitTest :probe:lintDebug`
- 14 product tests と 6 comparison tests。追加テストは、繰り返し無効化後も実行中ロックが継続すること、将来の開始がなくなること、再有効化時の重複検証。
- `product_ui_parity_verify.py`: 実 UI の対象保存・取消、ドメイン永続化、履歴ピン留め、確認取消、予約作成・編集・削除、繰り返し作成・切替・削除、設定。
- 通常の `uiautomator dump` は他のユーザー補助サービスを一時停止するため、フォーム検証には Debug Probe の `QAInstrumentation` と `FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES` を使用。最初の停止を伴う検査の失敗は成功に数えていない。
- Probe の入力遮断計測中はこの Instrumentation も使わない。開始前後の正の対照、ロック中にタップが届かないこと、自然終了後にタップが届くことをログで判定。

最終実行結果と画像は [比較ギャラリー](../ANDROID_SCREENSHOTS.md) に集約する。
