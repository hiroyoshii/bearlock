# Bear Lock TODO

2026-08-31時点の残タスク。TestFlight経由の実機インストール、Family Controls Distribution承認、CIでのbuild / mock e2e / screenshot取得までは完了済み。ここには、リリース前にまだ判断または確認が必要なものだけを残す。

## 実機前に進める

- [ ] ブランド用の抽象動物アイコンを制作する。
  - ロゴ、favicon、LP、SNSアイコンに使える単純化された熊/動物シンボル。
  - 現在のアプリアイコンより小サイズで潰れにくい形にする。
  - SVGまたは高解像度PNGを用意する。
  - favicon用に正方形、単色/2色、背景あり/なしを検討する。
  - アプリ本体のBrandHeroとは別に、Web/LP/小サイズ表示で使える記号として作る。
- [x] App Store / entitlement審査向けのプロダクト説明を作る。
  - Bear Lockが何をするアプリか。
  - Screen Time / Family Controls APIを使う理由。
  - 早期解除できない設計の意図と、安全上の制限。
  - 収集しないデータ、端末内保存、クラウド非利用。
- [x] Family Controls entitlement申請用メモを作る。
  - 想定ユーザー。
  - 利用シナリオ。
  - ブロック対象選択、スケジュール、Shield表示の流れ。
  - 保護者監視ではなく、本人の自己制御アプリとしての位置づけ。
- [x] Privacy Policy草案を作る。
  - アカウントなし。
  - 分析・広告・トラッキングなし。
  - 選択アプリとスケジュールは端末/App Group内保存。
  - Diagnosticsは端末内ログで、ユーザーがスクショ共有する前提。
- [x] Support / FAQ草案を作る。
  - ロックが効かない場合。
  - 権限が出ない場合。
  - ロック終了後も解除されない場合。
  - Diagnostics画面で確認する項目。
- [x] TestFlight CI署名素材とGitHub Secrets登録手順を作る。
- [x] アプリ用LPの構成案を作る。
  - First view: Bear Lockの価値とブランドビジュアル。
  - How it works: 選ぶ、時間を決める、眠らせる。
  - Privacy: 端末内完結。
  - FAQ / Contact。
- [x] App Store Connect用素材の下書きを作る。
  - App name。
  - Subtitle。
  - Promotional text。
  - Description。
  - Keywords。
  - Review notes。
- [x] READMEを現状に合わせて更新する。
  - 最新テスト数。
  - Diagnostics / Safety policy。
  - CI screenshot artifact。
- [x] CI artifactから申請/LP用スクショ候補を選ぶ。
  - Setup。
  - Home。
  - Confirmation。
  - Active Lock。
  - Settings / Diagnostics。
- [x] 日本語/英語の基本ローカライズを入れる。
- [x] Setup画面をBrandHero中心のシンプルな構成にする。
- [x] ロック設定画面の余白、タブ選択状態、文字コントラストを調整する。
- [x] Shield画像をextensionのメモリ制限に合わせて軽量化する。

## Macが来たら進める

- [x] `project.yml` にApple Developer Team IDを設定する。
  - `DEVELOPMENT_TEAM`: `3M4M7DRUZY`
- [x] `project.yml` / entitlements / App Group serviceの本番識別子を決めて置き換える。
  - `PRODUCT_BUNDLE_IDENTIFIER`: `com.hiyozoo.bearlock*`
  - App Group ID: `group.com.hiyozoo.bearlock`
- [x] XcodeGenで `BearLock.xcodeproj` を生成する。
- [x] XcodeでSigning & Capabilitiesを確認する。
- [x] Apple DeveloperでFamily Controls entitlementを申請する。
- [x] Family Controls Distribution承認を確認する。
- [x] entitlement承認後、実機向けprovisioning profileでビルドする。
- [x] TestFlight upload用のGitHub Secretsを登録する。
- [x] GitHub ActionsでTestFlight upload workflowを追加する。
- [x] TestFlightでiPadへインストールする。
- [ ] iPadで手動QAを完了する。
- [ ] App Store Connectにアプリ情報、スクショ、Privacy Nutrition Labelsを登録する。

## 実機/iPadで確認する

- [x] Family Controls権限要求が表示される。
- [x] `FamilyActivityPicker` で対象アプリを選べる。
- [ ] 空選択で保存/ロック開始できない。
- [x] 1から2分のNow lockで対象アプリにShieldが出る。
- [x] カスタムShield画像が表示される。
- [ ] カスタムShield画像の表示サイズ、文言、余白が自然か確認する。
- [x] Shield側に「解除予定時刻」を明確に表示する。
- [ ] ロック中にBear Lock側から早期解除できない。
- [ ] 終了時刻後にShieldが解除される。
- [ ] Delayed lockがバックグラウンド中に開始する。
- [ ] Recurring lockが指定時刻に開始する。
- [ ] active中の親recurring編集で現在のlockが解除されない。
- [ ] 権限取消時のrecovery表示が破綻しない。
- [ ] `Settings > Diagnostics` に必要な状態とログが残り、実機トラブル時に原因追跡できる。
- [ ] Webサイトロックを実機で確認する。

## リリース前の判断事項

- [ ] ブランド画像の利用権・最終版を確定する。
- [ ] アプリ名を `Bear Lock` で最終確定する。
- [ ] 初回リリースでiPhoneのみか、iPad表示も正式サポートするか決める。
- [x] 初回リリースの主要言語を日本語/英語の両対応で進める方針にする。
- [ ] Debug安全制限をReleaseで外す前提でよいか、Releaseにも最大時間を設けるか決める。
- [x] ログはMVPでは端末内Diagnosticsだけにする。
- [x] MVPは無料、広告なし、アカウントなし、クラウド同期なしで進める方針にする。
- [x] v0.2以降の任意サポートを検討する。
  - Settingsに邪魔にならない支援導線を置く。
  - 機能差は付けず、支援後はありがとう表示だけにする。
  - StoreKit / Consumable In-App Purchaseで `Coffee`, `Lunch`, `Dinner` を使う。
  - 価格はおおよそ `¥500`, `¥1,000`, `¥2,000`。
  - 案A: 無料 + 任意サポート Consumableを第一候補にする。
  - 100件の外部ベンチマーク: `docs/launch/support-iap-research.md`
  - 画面側は実装済み。App Store Connectの商品審査とStoreKit Sandbox購入確認は別途行う。
- [x] App Store審査前に「寄付」ではなく「任意サポート」表現に統一する。

## 参考リンク

- 実機QA: `docs/qa/manual-device-checklist.md`
- 実装計画: `docs/implementation-plan.md`
- CI: `.github/workflows/ios-ci.yml`
- Visual Snapshot CI: `.github/workflows/ios-visual-snapshot.yml`
- Launch docs: `docs/launch/README.md`
