# Bear Lock TODO

2026-09-02時点の残タスク。TestFlight経由の実機インストール、Family Controls Distribution承認、CIでのbuild / mock e2e / screenshot取得までは完了済み。ここには、リリース前にまだ判断または実機確認が必要なものだけを残す。

## リリースまでの実行順チェックリスト

TestFlight済みの現在地から、App Store提出までを上から順に潰す。

### 1. リリース対象ビルドを固定する

- [x] GitHub Actionsの最新 `iOS CI` が成功していることを確認する。
  - `swift test` が成功している。
  - simulator buildが成功している。
  - mock UI e2eが成功している。
  - screenshot artifactが生成されている。
  - 確認: 2026-09-02の最新runで成功。
- [ ] GitHub Actionsの最新 `iOS TestFlight Upload` が成功していることを確認する。
  - archiveが成功している。
  - ipa exportが成功している。
  - App Store Connect validateが成功している。
  - TestFlight uploadが成功している。
- [ ] App Store Connectで提出候補のBuild Numberを控える。
- [ ] 以後、審査提出まで原則このBuild Numberをリリース候補として扱う。
  - 実機QAで重大不具合が出た場合だけ修正して新Build Numberを作る。

### 2. iPad実機QAを完了する

- [x] TestFlightからリリース候補ビルドを新規インストールする。
  - 既存インストールがある場合は一度削除して、初回起動から確認する。
  - Screen Time / Family Controls権限状態も必要に応じてリセットする。
- [x] 初回起動でFamily Controls権限要求が表示される。
- [x] 権限拒否時にSetupへ戻る。
- [x] `FamilyActivityPicker` で対象アプリを選択できる。
- [x] 選択後、Homeに選択数が表示される。
- [ ] 空の対象選択では保存またはロック開始ができない。
- [x] 1から2分のNow lockを開始する。
- [x] 確定直後に対象アプリへShieldが出る。
- [x] カスタムShield画像の表示サイズ、文言、余白が自然に見える。
- [x] Shield側に解除予定時刻が明確に表示される。
- [x] Bear LockのActive画面に残り時間が表示される。
- [x] Active画面に早期解除ボタンがない。
- [x] 終了時刻後、対象アプリが開ける。
- [x] 1分後開始、1分継続のDelayed lockを予約する。
- [x] Bear Lockをバックグラウンドにしたまま、開始時刻に対象アプリへShieldが出る。
- [x] Delayed lockの終了時刻後、対象アプリが開ける。
- [x] 今日の曜日で数分後開始のRecurring ruleを作る。
- [x] Recurring lockの開始時刻に対象アプリへShieldが出る。
- [x] active中に親recurringを編集または削除しても、現在のlockが解除されない。
- [x] Recurring lockの終了時刻後、Shieldが解除される。
- [x] scheduled中にアプリを再起動して、予定が復元される。
- [x] active中にアプリを再起動して、Active画面が復元される。
- [x] iOS SettingsでScreen Time権限を取り消した場合、Setupまたはrecovery状態へ戻る。
- [x] `Settings > Diagnostics` にAuthorization、Target selections、Scheduled rules、Recurring rules、Active lock、Safety policyが表示される。
- [x] `Settings > Diagnostics` のRecent Eventsに操作ログが新しい順で残る。
- [x] ロック終了後も解除されない場合に備え、Diagnosticsのスクショ手順を確認する。
- [x] Webサイトロックを実機で確認する。
- [ ] QA中に見つけた問題は、再現手順、期待結果、実際の結果、Diagnosticsスクショ、端末/iOSバージョンをメモする。

#### QAで見つかった問題

- [x] 予約がある状態で `今すぐ` ロックを開始したときの挙動を仕様化する。
  - 現象: 既存予約と `今すぐ` ロックの時間帯が重なると `LockValidationError 3` が出る。
  - 原因候補: `LockValidationError.overlappingLock`。既存の予定ロックと新規ロックの時間帯重複を拒否している。
  - 期待仕様案A: 既存予約と重なる `今すぐ` ロックは拒否する。
  - 期待仕様案B: 既存予約の開始前までなら `今すぐ` ロックを短縮して開始できるようにする。
  - リリース前判断: MVPでは案A。既存予約と重なる `今すぐ` ロックは拒否し、ユーザー向けエラー文言を出す。
- [x] `LockValidationError 3` の生エラー表示をユーザー向け文言に置き換える。
  - 表示文言: `予約時間と重なっています。重ならない時間を選んでください。`
  - Diagnosticsには内部エラー種別として `overlappingLock` を残す。
- [ ] 予約あり状態の `今すぐ` QAケースを追加する。
  - 予約と重ならない時間の `今すぐ` ロックは開始できる。
  - 予約と重なる時間の `今すぐ` ロックは分かりやすい文言で拒否される。
  - 拒否後、既存予約は削除・変更されていない。
- [ ] Webサイト検索中でも対象選択を保存できることを確認する。
  - 現象: Webロック自体はできるが、`FamilyActivityPicker` でWebサイト検索中に保存ボタンが消え、検索結果を選んでも保存できないように見える。
  - 対応: 対象選択画面を独自シート化し、検索状態に依存しない固定下部バーの `保存` ボタンを追加した。
  - 確認: Webサイト検索、結果選択、検索キーボード表示中、検索終了後のすべてで `保存` が見える。
  - 確認: 保存後にHomeの選択数へWebサイト分が反映される。
- [ ] 保存済み対象リストで、アプリ名・カテゴリ名・Webサイト名が濃色で読めることを確認する。
  - 現象: ロック対象アプリのアイコン横に出る対象名が白字になり、白背景上で見えづらい。
  - 対応: 保存済み対象の `Label` に専用スタイルを適用し、タイトル文字色を `AppTheme.navy` に固定した。
  - 確認: アプリ、カテゴリ、Webサイトの各行で、アイコン横の名前が白字ではなく濃色で表示される。
- [ ] Shield画面のタイトルが、対象アプリ名を主語にして表示されることを確認する。
  - 対応: Shield configuration extension内で取得できる `Application.localizedDisplayName` を使い、`<アプリ名>は眠っています。` と表示する。
  - 確認: 対象アプリを開いたとき、`熊は眠っています。` ではなく対象アプリ名がタイトルに出る。
  - 確認: アプリ名が取得できない場合は `このアプリは眠っています。` と表示される。
  - 確認: Webサイトは `このWebサイトは眠っています。` と表示される。
- [ ] 日本語環境で曜日ボタンが `日 月 火 水 木 金 土` 表示になることを確認する。
  - 対応: `Weekday.shortName(locale:)` を追加し、日本語ロケールでは漢字1文字、英語などその他ロケールでは `S M T W T F S` を返すようにした。
  - 確認: 新規Recurring作成画面で曜日が日本語表示になる。
  - 確認: Recurring編集画面で曜日が日本語表示になる。
  - 確認: 英語環境では従来通り `S M T W T F S` 表示になる。
- [x] アプリ本体とShield拡張のローカライズキー差分がないことを確認する。
  - 対応: 本体 `en.lproj` / `ja.lproj`、Shield拡張 `en.lproj` / `ja.lproj` のキー差分が0件であることを確認した。
  - 対応: Active画面と予約サマリーの `Wakes at` / `Starts` / `Wakes` をローカライズキー経由にした。
  - 対応: Diagnosticsの未登録キーを追加した。

### 3. リリース範囲を決める

- [ ] アプリ名を `Bear Lock` で最終確定する。
- [ ] ブランド画像の利用権と最終版を確定する。
- [ ] 初回リリースでiPhoneのみ正式サポートにするか、iPadも正式サポートに含めるか決める。
  - iPadも出す場合は、iPadスクショとiPad表示のQA完了を必須にする。
  - iPhoneのみの場合は、App Store Connectの対応デバイスとスクショをiPhone中心に揃える。
- [ ] Release buildでも最大ロック時間を設けるか決める。
  - 上限なしにする場合は、長時間ロック時のユーザー説明をApp Review NotesとFAQに書く。
  - 上限ありにする場合は、UI文言、Safety policy、FAQの整合を確認する。
- [ ] MVPは無料、広告なし、アカウントなし、クラウド同期なしの方針で最終確認する。
- [ ] 任意サポートIAPを初回に含めるか、v0.2以降に送るか決める。
  - 初回に含める場合は、App Store Connectの商品登録、StoreKit Sandbox購入確認、審査提出対象への追加が必要。
  - 初回から外す場合は、アプリ内導線と説明文が未提供商品を案内していないか確認する。

### 4. App Store Connectを入力する

- [ ] App情報を登録する。
  - App name
  - Subtitle
  - Category
  - Content Rights
  - Age Rating
- [ ] 価格を無料に設定する。
- [ ] Privacy Policy URLを設定する。
  - Cloudflare Pages用の静的ページは `site/privacy/` と `site/en/privacy/` に用意済み。
  - GitHub ActionsからCloudflare Pagesへdeployするworkflowは `.github/workflows/cloudflare-pages.yml` に用意済み。
  - GitHub Secretsに `CLOUDFLARE_ACCOUNT_ID` と `CLOUDFLARE_API_TOKEN` を登録する。
  - デプロイ後、App Store Connectに本番URLを入力する。
- [ ] Support URLを設定する。
  - Cloudflare Pages用の静的ページは `site/support/` と `site/en/support/` に用意済み。
  - デプロイ前に `support@hiyozoo.com` が正しい連絡先か確認する。
  - デプロイ後、App Store Connectに本番URLを入力する。
- [ ] Marketing URLまたはLP URLを設定するか決める。
- [ ] 日本語メタデータを登録する。
  - 説明文
  - キーワード
  - プロモーションテキスト
  - サポート文言
- [ ] 英語メタデータを登録する。
  - Description
  - Keywords
  - Promotional text
  - Support copy
- [ ] App Privacy / Privacy Nutrition Labelsを登録する。
  - トラッキングなし。
  - アカウントなし。
  - 分析なし。
  - 広告なし。
  - クラウド送信なし。
  - 選択アプリ、スケジュール、Diagnosticsは端末内保存。
- [ ] スクリーンショットを登録する。
  - Setup
  - Home
  - Confirmation
  - Active Lock
  - SettingsまたはDiagnostics
- [ ] App Review Notesを登録する。
  - Family Controls / Screen Time APIを使う理由。
  - 本人の自己制御アプリであり、保護者監視アプリではないこと。
  - 早期解除できない設計意図。
  - 選択対象とスケジュールは端末内保存で、外部送信しないこと。
  - iOS Settingsやアプリ削除などOS/account levelの回避はBear Lock単体では防げないこと。
  - テスターが確認しやすい基本操作手順。
- [ ] 提出候補のTestFlight Build NumberをApp Store Versionに紐づける。

### 5. 提出前の最終品質ゲート

- [ ] リリース候補ビルドでSmoke Testを再実行する。
- [ ] ロック終了後にShieldが解除されることを最後にもう一度確認する。
- [ ] アプリ内にDebug専用文言、テスト用文言、未完成導線が残っていないか確認する。
- [ ] 日本語/英語の主要画面で文言切れがないか確認する。
- [ ] App Storeスクショと実アプリUIが大きく乖離していないか確認する。
- [ ] Privacy Policy、FAQ、App Store説明文、Review Notesの説明が矛盾していないか確認する。
- [ ] 重大不具合がない場合、App Store Reviewへ提出する。

### 6. 公開後の確認

- [ ] 初回公開は手動リリースか段階的リリースにするか決める。
- [ ] 公開後、App Storeの商品ページ、スクショ、説明文、Privacyリンクが正しく表示されるか確認する。
- [ ] 公開版をApp Storeからインストールして、初回起動とNow lockだけ再確認する。
- [ ] 問い合わせが来た場合は、Diagnosticsスクショ、端末名、iOSバージョン、ロック種別、発生時刻を聞く運用にする。

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
- [x] カスタムShield画像の表示サイズ、文言、余白が自然か確認する。
- [x] Shield側に「解除予定時刻」を明確に表示する。
- [x] ロック中にBear Lock側から早期解除できない。
- [x] 終了時刻後にShieldが解除される。
- [x] Delayed lockがバックグラウンド中に開始する。
- [x] Recurring lockが指定時刻に開始する。
- [x] active中の親recurring編集で現在のlockが解除されない。
- [x] 権限取消時のrecovery表示が破綻しない。
- [x] `Settings > Diagnostics` に必要な状態とログが残り、実機トラブル時に原因追跡できる。
- [x] Webサイトロックを実機で確認する。

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
