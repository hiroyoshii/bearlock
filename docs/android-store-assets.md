# Google Play のスマートフォン画像

GitHub Actions の **Android Store Assets** を main で実行する。Android 製品コード・撮影スクリプト・workflow の main 更新時にも自動実行する。

1. 実行完了後、Artifacts の `bearlock-android-store-assets` をダウンロードして展開する。
2. 日本語の掲載情報には `ja/`、英語には `en/` の PNG を使用する。
3. ホーム、初期設定、繰り返し、遅延開始、ロック中、確認の各6枚。必要な画像を選んでアップロードする。

すべて1080×1920、RGB PNG、8MB未満。Android 15 のエミュレーターを400dpi・文字100%に設定して直接撮影する。画像の切り取りや縦横の引き伸ばしは行わない。画像寸法、容量、撮影対象のアプリ、画面の見出し、言語を検証する。

撮影にはDebug限定のScreenshotActivityと本番UIコンポーネントを使用する。表示する予約・残り時間はサンプルデータ。実際のロックや決済は発生せず、Accessibility申告動画や機能の動作証明には使用しない。

撮影結果は [ci-screenshots/android-store](../ci-screenshots/android-store/README.md) にもCIが保存する。`capture.json` に撮影元commit・Actions実行ID・画像SHA-256を記録する。画像保存commitは `[skip ci]` とし再実行ループを防ぐ。

アプリアイコン（512×512）とフィーチャーグラフィック（1024×500）は別のアセット。このworkflowはスマートフォンのスクリーンショットを対象とする。
