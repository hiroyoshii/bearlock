# Bear Lock TODO

2026-08-27時点の残タスク。実機が来る前に進められるものと、Mac / iPad / Apple Developer環境が必要なものを分ける。

## 実機前に進める

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

## Macが来たら進める

- [ ] `project.yml` の本番識別子を決めて置き換える。
  - `DEVELOPMENT_TEAM`
  - `PRODUCT_BUNDLE_IDENTIFIER`
  - App Group ID
- [ ] XcodeGenで `BearLock.xcodeproj` を生成する。
- [ ] XcodeでSigning & Capabilitiesを確認する。
- [ ] Apple DeveloperでFamily Controls entitlementを申請する。
- [ ] entitlement承認後、実機向けprovisioning profileでビルドする。
- [ ] iPadへインストールして手動QAを実施する。
- [ ] App Store Connectにアプリ情報、スクショ、Privacy Nutrition Labelsを登録する。

## 実機/iPadで確認する

- [ ] Family Controls権限要求が表示される。
- [ ] `FamilyActivityPicker` で対象アプリを選べる。
- [ ] 空選択で保存/ロック開始できない。
- [ ] 1から2分のNow lockで対象アプリにShieldが出る。
- [ ] ロック中にBear Lock側から早期解除できない。
- [ ] 終了時刻後にShieldが解除される。
- [ ] Delayed lockがバックグラウンド中に開始する。
- [ ] Recurring lockが指定時刻に開始する。
- [ ] active中の親recurring編集で現在のlockが解除されない。
- [ ] 権限取消時のrecovery表示が破綻しない。
- [ ] `Settings > Diagnostics` に必要な状態とログが残る。

## リリース前の判断事項

- [ ] ブランド画像の利用権・最終版を確定する。
- [ ] アプリ名を `Bear Lock` で確定するか判断する。
- [ ] 初回リリースでiPhoneのみか、iPad表示も正式サポートするか決める。
- [ ] Debug安全制限をReleaseで外す前提でよいか、Releaseにも最大時間を設けるか決める。
- [ ] ログを端末内Diagnosticsだけにするか、将来のCrashlytics等を入れるか決める。
- [ ] 有料化、アカウント、クラウド同期をMVP後に回すことでよいか確認する。

## 参考リンク

- 実機QA: `docs/qa/manual-device-checklist.md`
- 実装計画: `docs/implementation-plan.md`
- CI: `.github/workflows/ios-ci.yml`
- Visual Snapshot CI: `.github/workflows/ios-visual-snapshot.yml`
- Launch docs: `docs/launch/README.md`
