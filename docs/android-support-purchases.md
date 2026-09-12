# Android の応援導線

Android 0.2.2 / versionCode 7 で Google Play のアプリ内課金を削除。

- 設定 → Bear Lockを応援 → 公式サイトを開く。
- 日本語: https://bearlock.hiyozoo.com/support/development/
- 英語: https://bearlock.hiyozoo.com/en/support/development/
- 商品・価格・購入・再照会・消費処理、Billing依存、購入署名検証を削除。
- BEARLOCK_PLAY_LICENSE_KEY は不要。アプリ配布用の署名鍵は引き続き必要。
- WebはStripe Payment Linksに対応。本番リンクの作成・設定が完了するまでは決済を表示しない。[作成・公開手順](stripe-support-setup.md)。
- iOSの応援購入は変更しない。

Play Console上の商品・販売者設定はこのコード変更では変更されない。
