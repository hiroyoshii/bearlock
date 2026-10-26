# Android / iOS スクリーンショット

現在保持している撮影記録への入口です。撮影時点の画面であり、未コミット変更を含む現在のソースで再撮影した証拠とは区別します。

| 対象 | 保存先・出典 |
|---|---|
| iOS公開用fixture | [日英32画像](ci-screenshots/README.md)・[ソース、CI run、SHA-256](ci-screenshots/app-store-source.json) |
| iOS実操作の比較元 | [2026-10-26撮影](ci-results/ios-review/2026-10-26-f29448b/screenshots/)・[画像index](ci-results/ios-review/2026-10-26-f29448b/screenshots-index.json)。現行のAndroid比較で使用する `b7e0d74` の画面を保持 |
| Androidの最新一式（ローカル） | [日英画像・操作フロー](artifacts/android-ios-alignment-2026-10-26/final-capture/)・[撮影証跡](artifacts/android-ios-alignment-2026-10-26/final-capture/capture-result.json)。API 35、APK `89aa2e41`、134フレーム・15フロー |
| 最新比較レポート（ローカル） | [レビュー](artifacts/android-ios-alignment-2026-10-26/review/index.html) |

ローカルの `artifacts/` はGit管理外です。クローンだけでは付属しません。最新Android撮影は状態fixtureを含み、実際の制限動作や30分待機の証明ではありません。

現在の差分・未確認項目は [仕様・責務・コード・テストの対応表](docs/qa/android-ios-structure-audit-2026-10-25.md) を参照してください。iOS公開画像はfixture、iOS実操作画像とAndroid画像も撮影条件が異なり、画像の存在を両OSの同条件検証成功とは扱いません。

古い比較画像、Before/After、却下案、固定マニフェストとその専用生成スクリプトは整理しました。Git管理されていた記録は [整理前の履歴](https://github.com/hiroyoshii/bearlock/tree/44465600fe304f1ab53b97de3a9f79180650063d/docs/qa) で参照できます。新しい撮影には既存の [撮影スクリプト](android-lab/scripts/product_parity_capture.py) を使い、出力先を `artifacts/` 配下に指定します。
