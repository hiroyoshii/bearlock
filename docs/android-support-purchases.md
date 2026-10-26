# Android 応援導線の配布・設定メモ

製品方針は [設計正本のAndroid固有仕様](design-doc.md#android) を参照。本書は配布・外部リンク設定のメモであり、課金方針を別に定義しない。

- 日本語: https://bearlock.hiyozoo.com/support/development/
- 英語: https://bearlock.hiyozoo.com/en/support/development/
- 0.2.2 / versionCode 7でPlay向け購入処理と依存を削除した配布記録。
- BEARLOCK_PLAY_LICENSE_KEY は不要。アプリ配布用の署名鍵は引き続き必要。
- WebはStripe Payment Linksに対応。本番リンクの作成・設定が完了するまでは決済を表示しない。[作成・公開手順](stripe-support-setup.md)。

Play Console上の商品・販売者設定はこのコード変更では変更されない。
