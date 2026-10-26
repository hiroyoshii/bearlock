# Android / iOS 整合の実装・検証記録

現行の製品仕様・OS別方針・構造は [設計正本](design-doc.md) に集約した。本書は実施日・APK・参照画像・検証結果と限界の記録であり、製品仕様や今後の実行計画の正本ではない。

2026-10-25整理: iOS課金廃止を前提にした記述、未採用のA〜F計画、古い差分/着手候補表を削除した。iOSの課金・チケットは維持する確定仕様である。以下の記録は当時の版・条件に限る。旧UIや古い完了件数を現在の保証としない。公開作業の進捗は [Android TODO](android-implementation-todo.md) と既存のtodo.mdで管理する。

### 2026-10-26 共通文言の日英を統一

[設計正本のUI-10](design-doc.md#ui)に従い、Androidの初回説明、対象サマリー・履歴メニュー、作成確認・編集、予定一覧、無料起床・取消、設定・サポート、読込失敗・監視失敗、Shield、読み上げをiOSの翻訳後の表示値に揃えた。実行中カードの独自の予約済み表示と「30分以内に自然に起床します」を削除し、予約有無にかかわらず入口を「熊を起こす」に統一。起床予約済みの時刻は既存の起床時刻表示で示す。

Androidに存在しない有料起床の説明は省略し、繰り返し削除の即時反映、Accessibility・アラーム権限、独自の対象picker、Web遮断の制約、保存失敗時の下書き保持など、実装に即した説明は維持。診断の保存状態「正常」はOKボタンとは文脈が異なるため維持する。iOSにもあった「30分未満」「終了後に変更できます」は、それぞれ「30分以下」「開始後は予定の編集・削除はできません」に修正し、ロジックは変更していない。影響する既存UI検証の操作先・期待値も更新した。

Android Debug/未署名Releaseビルド、製品単体74件、Release lintが成功。iOSの翻訳後の英語表示が対応するAndroidの静的文言145箇所を照合し、保存状態「正常」/OKの1箇所以外は日本語も一致。動的な時刻・件数・Shield文言は該当するiOSの書式と照合した。日英翻訳キーの一意性・対応、変更SwiftのDebug/Release条件での構文解析、Python検証スクリプトの構文確認も成功。エミュレーターの画面操作・スクリーンショット更新とXcodeビルドは今回未実施。

### 2026-10-26 診断画面をDebug限定へ戻す

ユーザー指示により、[設計正本のUI-09](design-doc.md#ui)で診断UIを両OSともDebug限定に確定。iOSは設定の入口・DebugDiagnosticsView本体・読込失敗画面の入口を `#if DEBUG` に戻した。Androidは設定の診断セクションと診断画面の描画をBuildConfig.DEBUGで制限し、Releaseで診断ルートが復元された場合も通常設定へ戻す。読込失敗の案内は、利用できない診断画面ではなく再読込と通常のサポートへ誘導する。端末内ログ記録、権限・動作状態の確認、再読込処理は維持。

AndroidのDebug/未署名Release APK生成・製品単体74件（失敗0）が成功。両APKのDEXで診断入口と診断記録の文言がDebugだけに存在すること、およびコンパイル後のコードでReleaseの診断描画・ログ読出しが除外され、診断ルートが通常設定へ戻ることを確認。iOSはDebug/Release両方の条件でSwift構文解析が成功し、診断画面本体と全参照のDebug条件を確認。WSLではmacOS専用のPlistBuddyを使うプロジェクト検証と、Xcodeのビルド・UI操作は未実施。ローカルAndroidエミュレーターも再開していない。

### 2026-10-26 繰り返しの次回プレビュー表記

表示基準を[設計正本のUI-08](design-doc.md#ui)に追加。Androidの作成・編集に残っていた「次回: 開始 → 終了」を「次回の開始」「次回の起床」の2行へ変更し、プレビュー・作成確認・削除確認からタイムゾーンIDの生表示を除去した。iOSの繰り返し編集にもASCIIの `->` が残っていたため、標準LabeledContentの開始・起床の2行へ変更し、日英の文言を追加。iOSの繰り返し作成画面には従来から次回プレビューもタイムゾーンIDも表示しておらず、新たな表示は追加しない。発生回計算・保存・起床の処理は変更しない。

AndroidのDebug/Releaseビルド・製品単体74件（失敗0）・Debug lintが成功。iOSはSwift構文解析と日英の追加キーの一意性・存在を確認。WSLではSwiftUIのビルドや画面操作を実行できないため、これらをiOSシミュレーター検証の成功とは扱わない。予約一覧の短い期間表記は今回の次回プレビュー変更の対象外。

### 2026-10-25 両OSのセグメント式と日時ボタン共通化

追加依頼により、iOSを含めてモード切替をセグメント式に変更する。直前の「現行iOSの独立アイコンボタンを維持する」はこの依頼で更新された。iOSの既存変更を取り消さず、今回許可されたモードと日時入力だけを変更する。

- iOS: 独立ボタンの描画/モード用SF Symbols定義を削除し、標準 `Picker(.segmented)` を使用。アクセシビリティ文字サイズでは既存の標準メニューを維持。UIテストの選択先もsegmentedControlsへ変更。
- Android: 独立ボタン群をMaterial Components 1.13.0の `MaterialButtonToggleGroup` へ置換。単一選択・選択必須。通常幅は均等配置、狭幅/大文字は横スクロールで文字を潰さない。チェックやモードアイコンは追加しない。不要になったbolt/timerリソースと対応定義を削除し、残る既成アイコンは19種類。
- 日時ボタンは古い画像だけの問題ではなかった。Androidの日時指定15sp/上下余白0と繰り返し17sp/上下余白6dpが別経路で残っていた。全て `Ui.dateTimeButton` にまとめ、17sp・最小高さ44dp・横12/縦6dp・同じ灰色/角丸へ統一。作成と各編集画面で共通使用。日付と時刻の独立確定、タイムゾーン、起床ロジックは変更しない。
- iOSは全作成/編集で共有する `ScheduleDatePicker` の通常/大文字両経路に `.compact` を明示。OS標準部品の形状を使い、独自描画でのピクセル一致はしない。

検証APK: `93c882fea3179ba6644fac2d0127bed5303815be212102a4239cd9602055b507`。Debug/Releaseビルド、Android単体57件、Lint 0 errors / 41 warnings（Material導入でUseKtx推奨20件が追加）。既存EditorInstrumentationで単一選択と、日時指定/繰り返し/各編集の文字サイズ・最小サイズ・余白・角丸の一致を検査する。Swiftコア71件と変更したSwift/UIテストの構文解析は成功。Linux環境にはXcode/iOS SDKがなく、iOSアプリビルド・UIテスト・変更後撮影は未実施。コアテストをiOS UIの完了根拠にしない。

比較のiOS画像4e9e377は変更前の公開fixture。比較ページにも旧画像・変更後未撮影と明記し、両OS変更後の一致を示すものとして扱わない。Androidの再撮影先は `artifacts/android-product/segments-time-2026-10-25/`、Beforeは直前の11c2e351。

最終APKでAPI26通常幅のEditor/Lock/Picker/Recovery、320dp・文字200%のEditor/Recoveryが成功。途中の狭幅Recoveryでは旧ボタン行のLinearLayoutを前提にしたテストの型変換が失敗し、新しいライブラリセグメント＋横スクロール容器の検査へ変更して再実行した。製品側の代替描画経路やテスト用フォールバックは追加していない。

同じ93c882fe APKで日英各16状態・128枚・16フローを再撮影し、撮影完了フラグとインストール済みAPK/画像ハッシュの一致を確認。日時指定・繰り返し・各編集の時刻ボタンは撮影XMLでも同じ高さ132px（44dp）で、同じ時刻書式なら幅も一致。作成4モードと予定一覧の部品切り出し範囲を両言語の新XMLと照合した。iOS変更後の画像は含まない。

比較ページは部品20枚の元画像一致、画像260点のリンク切れゼロ、ページ内リンク、日英切替、320/768/1024/1440幅の横はみ出しなしを確認。新APKクエリ `apk=93c882fe` で表示を確認し、iOS旧画像とBeforeの11c2e351の表示も検査した。画像取得済みをiOS側の視覚受入完了へ読み替えない。

### 2026-10-25 自作アイコンの撤去

Androidの `LineIcon.kt` による手書きのパス描画と、Unicode記号からのアイコン変換を撤去。設定・編集・削除・モード・対象種別など、使用する全21種類をGoogle公式Material Icons Outlined（24dp）のAndroid VectorDrawableへ置換した。未使用の手描きアイコンも残さない。モード切替の配置や操作、熊・ロゴ・インストール済みアプリの正規アイコンは変更しない。

配布元は `google/material-design-icons` の `10ecc14790612ca8fd164e3f4ffe9c16fc50d5b7`。パス形状は無変更。標準Androidテーマで解決するためtint属性だけ `?android:attr/colorControlNormal` に修正し、色とサイズを既存UI側で指定する。出典・上流SHA256・変更内容・Apache-2.0ライセンスを `android-lab/product/src/main/assets/material-icons/` に同梱した。全21種類を上流ハッシュと照合済み。iOSのSF Symbolsと同じ図形という主張ではなく、Android側を既成の公式アイコンへ統一する変更。

検証用APK: `11c2e35147929156734fe6d7d32ee206101b4dcfc497240916dbabe197979094`。Debug/Releaseビルド、単体57件、Lint 0 errors / 21 warnings。既存EditorInstrumentationで出典一覧にある全アイコンのVectorDrawable読み込み・非空描画・色付けを検査する。ピン留め・Web削除・カテゴリ開閉の記号文字も既成アイコンへ置換した。新しい診断画面や代替描画経路は追加しない。

同じ最終APKでAPI26通常幅のEditor/Lock/Picker/Recovery、320dp・文字200%のEditor/Recoveryが成功。途中の通常幅Recoveryでは自動クリックが一度失敗し、同条件の再実行は成功。最終APKで改めて全系統を通した。日英16状態ずつ、操作前後128枚・16フローを `artifacts/android-product/material-icons-final-2026-10-25/capture-result.json` に記録し、完了フラグと画像/APKハッシュを照合した。比較のBeforeはアイコン置換直前の86558651へ更新し、現在のiOS画像は4e9e377のまま維持。実機/OEM・TalkBack音声・全OS検証を完了したという意味ではない。

Webの追加→公式closeアイコンから削除→空の選択を保存する実操作も成功（同撮影フォルダー内 `web-remove-verification/result.json`）。ギャラリーは20部品切り出しの元画像一致、画像260点のリンク切れゼロ、ページ内リンク、日英切替、320/768/1024/1440幅の横はみ出しなしを検査した。比較サイトは同じ8765ポートを維持し、新APKクエリ `apk=11c2e351` でキャッシュを区別する。

### 2026-10-25 不要なUI差分の実装修正

今回の基準はrepo内の現在のiOS画像 `4e9e377` / run `39049336403` と対応コード。以前のdd83005はモードがセグメント式だったが、現在はアイコン付き個別ボタンと灰色の未選択曜日へ戻っている。したがって「セグメントにする」「未選択曜日を白にする」は撤回し、現在のiOSと共通の形を維持した。過去の9/21・10/18の課題表はこの更新を上書きする根拠にしない。

- 選択プリセットを濃紺＋白文字、非選択を淡色＋濃紺に統一し、通常幅のカプセル高さを調整。
- 作成/単発編集の日付と時刻を別カプセルへ。日付だけ確定すると元の時刻を維持し、時刻pickerを自動で続けて開かない。時刻は独立して確定/取消する。大きな文字では縦配置。
- 繰り返しの開始/終了時刻をカプセルに統一。次回プレビューとタイムゾーンは保持。
- 単発編集を予定/確認、繰り返し編集を状態/曜日/時刻/注意文のグループへ。灰系背景、大見出し、取消/保存のカプセルへ整理。
- 設定を大見出し、画像/データ/情報/診断のグループ、青いリンク、行区切りへ。Android権限/対応制限は別グループで保持。
- 起床入口・予約済み表示を実行中カード内へ移し、カード外の重複見出しと専用領域を撤去。無料30分のみ・予約/取消/予約不可の判定は変更しない。
- 診断の長文dialogを廃止し、状態一覧→共有→アプリ/端末→既存ログ→消去のページへ置換。Backは設定へ戻り、編集中の値は維持する。ログ保存処理は複製しない。

検証: Debug/Releaseビルド、単体57件成功、Lintは0 errors（既存を含む21 warnings）。同じ最終Debug APK `86558651ffd11a64e11244241723d6b9588b1d0371278b413b3e415fa49c1e4f` でAPI26通常幅のEditor/Lock/Picker/Recoveryが全成功。320dp・文字200%でもEditor/Recoveryが成功。Recoveryの通常幅専用auto-size検査を大文字設定へ無条件に適用していたテストを修正し、大文字では自動縮小しないことを検査した。最初のRecovery撮影失敗は残っていた論理解像度overrideを標準へ戻して解消し、同じテストを再実行済み。

日英各16状態・操作前後128枚・16フローの撮影が完了し、`artifacts/android-product/ios-align-final-2026-10-25/capture-result.json` の `completeLatestCapture=true`、各画像/インストール済みAPKのハッシュ一致を確認した。Before/After18組と、現在のiOSとの部品/画面比較をギャラリーへ反映。部品切り出し20枚が元画像の宣言座標と完全一致することも検査した。iOSとの同条件の遷移連写、全OS/実機、TalkBack音声、実30分待機は今回の完了条件に含めず、未確認のまま明示する。比較レポートは画面/部品/機能/非対応を分け、ピクセル一致をUI受入の完了根拠にしない。

### U1の実装・検証状況

2026-10-11進捗: Androidのカード/無料起床操作、予約保存（schema 3読込→4保存）、実効終了、重複判定、次の境界、Service/Shield連動を実装。課金や新しい対象選択画面は追加していない。現在の契約は [設計正本の共通仕様](design-doc.md#common) へ集約済み。コード/単体検証と、UI/実機の完了を分けて記録し、後者が未確認ならU1全体を完了扱いにしない。

- 確認済み: `0640730` + Android作業差分。採用したiOSカード/起床ダイアログは `cade62c` から変更なし。単体48件（既存31、起床14、Codec3）成功。Debug/ReleaseビルドとLint成功（0 errors、17 warnings）。JSON依存はテスト限定。
- Windowsのread-only Pixel 9a/API35で、日英の実画面、schema 3→4、予約/取消/再予約、アプリ再起動での保持、短縮fixtureで本体を開かない背景解除とProbe入力復帰が成功。幅320dp・文字200%でも同じ操作が成功。証拠は `artifacts/android-product/free-wake/` と `free-wake-compact/` の `result.json`・スクショ。
- 最終レビューで、起床済みの繰り返しが「実行中・編集不可」に残る不具合も修正した。編集可否をStateの実効終了へ統一し、期限前の拒否・期限後の編集・今回の再ロック防止・次週の反映を単体と実画面で確認。
- 同じ不具合をiOS編集画面でも修正（2026-10-11）。`RecurringRuleEditorView` の元の終了時刻による独自判定を削除し、一覧・保存処理と同じ `LockState.validateEditable` を参照。Coreの期限前/期限後/取消後/翌日の回帰を含む71件成功、変更Swiftファイルの構文検査成功。既存UIテストに起床済み繰り返しの操作・保存回帰を追加したが、Windows/WSLではXcodeがないためiOSビルド/UI実行は未確認。
- 最終APKで正確なアラーム権限なしの警告、予約/取消/再起動保持、本体を開かない背景解除とProbe入力復帰も成功（短縮fixture）。証拠は `artifacts/android-product/free-wake-without-exact/result.json`。同じ試験を既存Acceptance CIにも追加。
- `RecoveryInstrumentation` は隔離した保存領域で予約/取消の保存失敗、保存成功後のOS登録失敗、再試行での期限保持、別代表へ変わった確認の拒否、30分以下の予約禁止、起床済み繰り返しの編集を確認。`LockInstrumentation` のnative保存/監視/Shield失敗回帰、`EditorInstrumentation` の再生成/下書き保持も最終APKで成功。各ログと画面は `artifacts/android-product/recovery/`。テスト終了時は実保存状態から監視を復旧する。
- 30分実待ちも成功（2026-10-11、日本時間15:07:38に再予約→15:37:38期限）。時計・保存期限を短縮せず、前面Probeを維持したまま本体を開かず入力復帰。期限+226msにShield除去ログ、期限+3,524msの入力対照で復帰を観測した。これはこのエミュレーターでの観測でありOS/OEMの精度保証ではない。`free-wake-real-time/result.json` と同配下の保存状態・診断ログを証拠とする。実待ちAPKは `ed28cfcd…`（その後の編集可否修正は解除処理を変更せず、単体と最終APKで再検証）。
- 最終APKのSHA-256: Debug `ff7625a02597beb932016cd94733cec3d411bc901b4b4cb83edcfaec070cad3c`、未署名Release `11f8e416c7746704e2fcdcc9665e9bccc91615f38031f564e8219a3a33037fa3`。最初の長時間試験は前面がホームへ変わり入力対照が不成立だったため合格に含めない。
- 未確認: TalkBackの音声/実操作、実機/OEM。今回のAndroid実装とローカルQAのFIXは、公開ゲート完了とは分ける。実機結果が揃うまでU1の公開ゲートは未完了。
- 再現手順は `android-lab/product/README.md` のQA節を参照。無料起床の短縮試験は既存Android 14 Acceptanceにも追加したが、リモートCIの実行成功は未確認。

### U2〜U8・C3の実装状況（2026-10-11）

既存のMainActivity/HomeComponents/Composer/EditorDraft/Plannerを変更し、別の保存先・再照合経路・UIフレームワークは追加していない。以下の実装とローカル検証、公開ゲートを分けて管理する。

| 単位 | 実装した変更 | 検証する条件 |
| --- | --- | --- |
| U2 | 警告/復旧を対象より前の一か所に集約。読込・登録・権限異常を同時表示。選択読込失敗を空選択で上書きしない | 警告順、同時異常、再許可からの復帰、破損原本保持、再読込、作成停止 |
| U3 | 開始済みの予約単発を元の終了まで表示。即時を除外。起床後も単発の開始前限定をUI/保存/削除で維持 | 開始境界・起床・自然終了・確認中の開始・再生成。旧形式の識別限界は契約に記録 |
| U4 | 曜日・時刻に追従する次回開始/終了・保存zone表示。Plannerの発生回を使用 | 日跨ぎ/DST/zone保持、曜日変更、空曜日 |
| U5 | 日時指定の初回値を30分後へ変更 | タブ往復・再生成で変更値を保持 |
| U6 | 選択済み対象のアプリ/Web/カテゴリをゼロ件も表示 | 詳細・履歴・ピン・選択禁止・下書き保持の回帰 |
| U7 | 確認の対象→開始→起床順、曜日/zone、削除の対象/日時/影響を明示。Web起動失敗を専用エラーへ | 取消/Backは未保存、競合対象、開始境界、OS別削除維持 |
| U8 | 共通素材、操作域、12/24時間、日本語説明の実装・ローカル検証済み。ただし一律8dp角丸や共通色だけではiOSの見た目の一致を満たさない | 見た目の統一は未完了。下記V01〜V17で画像根拠・採用する差分・完了条件を管理する |
| C3 | Shieldから元のルールID/発生回の起床確認へ戻る。遷移自体では未保存、期限到達/削除後は拒否、ホーム操作/遷移失敗案内を維持 | navigation失敗/成功・対象固定・未保存、実際のoverlay操作 |

単体53件（Planner26、Editor7、Contract1、Wake15、Codec4）成功。曜日未選択・過去日時では実行/保存を無効化し、確認確定時にも検証する。既存RecoveryInstrumentationに一覧・プレビュー・警告順・破損復旧の回帰を追加し、LockInstrumentationにShield遷移の失敗/成功・未保存確認を追加した。EditorInstrumentationも同じ隔離Activityを使い、実ユーザーの実行中予定に依存させない。画面取得は描画フレーム後に行う。

ローカル再検証（Windows側Pixel 9a、Android 15/API 35、read-only QAエミュレーター）:

- Debug/Release APK・Release AABビルド成功。lintは0 errors / 17 warnings。Swift Coreも71件成功。Release manifestに検証用Activity/instrumentation、課金・INTERNET権限がないことを確認。Release成果物は未署名であり配布成功を意味しない。
- 最終Debug APKのSHA-256: `97232f1626d72de933cdc86413b7b060f6638a195067456e811b01fa4d5a09f1`。Release APK: `d763eb393582da13ca0e2a623be1d7be57b073e32fe2b97472daf0a7cc0d5e8d`。AAB: `c3197b750f91d162d63e11d0e38d440df4e158783c0b5089e01598430925fe5e`。
- 最終APKでRecovery/Editor/LockInstrumentation成功。通常権限・正確なアラーム権限なしの無料起床予約/取消/再起動/前面Probeのバックグラウンド解除を再検証。短縮fixtureの試験であり、上記U1の30分実待ちと実機/OEM試験とは区別する。
- 通常幅・320dp/文字200%・横画面それぞれの日英で、対象3種類のゼロ件表示、曜日の選択状態/フルラベル、次回プレビュー、確認画面のスクロール/取消・保存原本不変を確認。12/24時間のプレビューと標準pickerのAM/PM・午前/午後表示も確認。証拠は `artifacts/android-product/ui-parity-u2-u8/layouts/result.json` と同配下のPNG/XML。
- 重複する繰り返しの実行中編集禁止、最初の期限で遮断維持・最後の期限で本体を開かず入力復帰、実行中繰り返しの削除取消・一件削除後の残りの遮断・最終削除で入力復帰が成功。証拠は `artifacts/android14/recurring-contract/result.json` / `recurring-deletion/result.json`。Android 15で診断出力の `ty` 表記が名称へ変わるため、既存試験のoverlay検出はWindowTokenの数値 `type=2032` を使うよう修正した。
- 初回説明→対象選択→権限の取消/開示拒否/OS設定→元の30分draftの確認→再起動で初回説明を繰り返さない導線が成功。証拠は `artifacts/android14/onboarding/result.json`。Shieldの実際の「熊を起こす」→該当回の起床確認→取消でも保存原本不変を確認（`ui-parity-u2-u8/shield`）。
- 最終APKで既存UI取引試験15条件が成功（選択取消/保存、アプリ+Web、再起動、履歴・ピン、確認取消、遅延作成/編集/削除、繰り返し有効切替の取消/保存、削除、権限設定）。証拠は `artifacts/android-product/ui-parity-u2-u8/interactions/result.json`。日英ともブラウザなしの設定リンク/応援リンクが専用エラーを表示することも確認し、QAエミュレーターのChromeは再有効化した（`browser-unavailable/result.json`）。

実機はユーザー回答により現在USB接続不可。AND-03〜09等の実機/OEM/ブラウザ保証、TalkBack音声、署名/配布は未完了。GitHub CLI未認証でAND-01のリモートCI結果も未確認。デザイン比較は以下の保存済みiOS画像で進められる。画像不足の画面と実機操作検証は別に未完了とする。

### 機能差分の修正・検証記録（2026-10-11）

今回の機能修正はV16/D1とブラウザ対応境界。保存データを読めないときは保持中の対象をSavedと表示せず、復旧導線だけを表示する。Targetsは既存StoreのAtomicFileへ統合し、保存失敗時は下書きと旧保存データを維持する。復旧UIは失敗理由と再試行/取消を明示し、新しい保存経路は作らない。

Firefox 153のComposeアドレス欄が旧View IDでは取得できず、通常タブでもドメイン遮断できなかった実不具合を修正。既知のtoolbar内のURL表示タグのみ読む。ページ本文や入力中の欄は読まない。対応説明も通常タブの読取可能なアドレス欄に限定した。

証拠の正本は `artifacts/android-product/storage-recovery-fix/`。Android 8（API26）/14（API34）/15（API35）の各 `native/result.json` はRecovery/Editor/Lockの3試験成功と同じ最終Debug APKを記録する。API34の `interactions/result.json` は通常幅393dpで15操作の成功、`chrome/result.json` / `firefox/result.json` はChrome 113.0.5672.136 / Firefox 153.0の無関係ドメイン対照・遮断中の入力・自然終了後の入力復帰を記録する。Web試験は外部ページのリンクとアドレス欄を同時に見せる720×2600の縦長viewportであり、通常幅の画面デザイン受入ではない。

単体57件成功、Debug/unsigned Releaseビルド成功、lint 0 errors / 21 warnings。最終Debug SHA256は `8793c263af5cb7e0efb25c3e5b874a61bf5af17a9de01458fea04cf4c5d9b465`、unsigned Releaseは `2f20ed3554c626e76d66382695cadb40e959bdc74cf6c967e9f9da3c005ff8a8`。ReleaseにDebug QA経路がないことも確認した。署名/配布やリモートCI成功を意味しない。

無料起床はAndroid各バージョンの `free-wake/result.json` で成功確認済み。実UIで30分予約・取消・強制停止後の保存維持、OSユーザー補助切断/再接続、API31以降の正確なアラーム許可取消/復旧を確認した。Android15の強制停止後はOSのBOOT_COMPLETEDを待ち、明示的なOFF→ONで再接続する。OS側の停止処理中に同じON値を書くだけの試験は競合して失敗したため成功扱いにせず再試験した。アプリが権限を自動復旧する実装は追加していない。期限到達の入力復帰だけ保存期限を8秒へ短縮するfixtureを使用し、実際の30分待機・長時間継続動作は未検証。API26はアラーム許可取消が非該当。実機/OEM、TalkBack、非表示/編集中アドレス欄、private/custom tabs、全ブラウザ更新、Android17はこの成功範囲に含めない。

### HOME表示の修正・検証記録（2026-10-11）

V01/V02/V03/V04/V09を修正。参照は9/21のI1/I5。白いカプセルの既存ロゴ素材、白丸の設定、見出し右の総数、大きな数字と種類の3枚カード、淡色の対象選択カプセル、アイコン付き太字の対象一覧、枠を除いた詳細、開始/予約/確認/取消の役割別カプセルを実装した。既存Uiの色・描画を使い、汎用ボタン全体や保存・無料30分後起床・課金・曜日の契約は変更していない。V12の確認画面全体は未完了。

比較画像は `docs/qa/android-home-design-2026-10-11/`。通常英語は3 Apps / 0 Categories / 0 Websites、Now / 120 min、展開/折畳み、履歴件数5/3/2を揃えた。ロゴ形・ボタン形・情報順を一致させ、実アプリアイコン/名前とOSフォントは理由付きOS差とする。履歴の代表名表示はV05の残差。320dp日本語でも通常は3枚、文字200%では数字カードを縦積みにして読めることを優先する。選択の青文字は淡色背景とのコントラスト4.73:1、実行中の対象固定は読める説明を維持する。操作域は設定48dp、一覧44dp、対象選択/主要操作50dp以上を維持する。

最終画像照合で文字200%のスクロール後に固定ヘッダーが消える描画不具合も修正した。固定ヘッダー自身の背景と描画順を明示し、同条件のスクロール後画像でロゴ・設定の残存を確認した。画像の座標情報だけを合格判定にはしていない。

証拠は `artifacts/android-product/home-design-fix/`。単体57件、Debug/unsigned Releaseビルド、lint 0 errors / 21 warnings。Debug SHA256: `c789b3600235a55c8960704f95db0fd1864692fcd506ad67c27b002ee39f0bbe`、unsigned Release: `2a24b25d6119342d21167b297507f1b2358ee6520fa4e392bfd4ee39d61bdea9`。API34の実操作15件、native回帰3系統、通常/320dp/文字200%/横画面/キーボード5確認がすべて成功。同じ最終Debug APKのハッシュを各result.jsonに記録した。対象fixtureはQA用、実機/OEM・TalkBack音声・30分実時間の検証ではない。OS起動時のSystemUI ANRや失敗した診断は成功件数に含めない。

回帰試験は既存経路を拡張した。空/混合/実行中のサマリーと対象固定をRecoveryで検証、Editorは前の試験状態を引き継がない初期化へ置換。操作ヘルパーは祖先の表示領域との交差内をタップするように修正し、画面外座標の擬似成功を除いた。別のテスト一覧や保存経路は増やしていない。

### 一覧密度・実行中・確認の追加修正（2026-10-11）

上のHOME記録は前段APKの履歴。この追加変更でV05〜V15とV02〜V04/V09の残る密度・文字階層を修正した。参照正本は9/21コミット `483eec28bdb9dd30a33ab3dde9f2c78e54343c34` のI1〜I5と対応SwiftUIソース。最新Android比較画像は `docs/qa/android-ios-density-2026-10-11/`。

一致させたアプリ所有の表示:

- 空対象はNone/未選択説明、通常は総数→3枚の数字/種類カード→対象一覧→履歴→対象選択。単一種類の詳細は余分なApps見出しを除き、混合種類では区分を残す。履歴は区切り線、Recent targets、件数主見出し、Saved target補助表示。選択枠・ピン・メニュー・再利用は保持し、実名は詳細とアクセシビリティ名で確認可能。
- 作成モードの太字・非選択枠・In文言、低いプリセットカプセル、遅延±の丸54dp、時間見出しと値の太字、開始/予約の17spカプセル。重複した行間を除き、440dp×956dpで3 Apps/0 Categories/0 Websites、展開した3件、履歴5/3/2、Now/120 minと50dp開始ボタン全体がスクロールなしで収まる。
- 実行中カードは28dp内側余白、幅300dp相当の角丸睡眠画像、薄い枠、28spタイトル/17sp説明/44sp時計/15sp起床時刻、18dp間隔。カード内の汎用Wakeを除き、次の白い領域に問いかけ、無料30分操作、予約状態/取消を表示。元の対象固定確認とPlanner/Store保存経路のみを利用する。
- 確認は角丸シート、画像→問いかけ→説明→種類別対象件数/開始/起床→主要カプセル→小さい白い取消。対象名の代表表示は種類別件数へ置換し、iOS I3の情報階層に一致。Back/取消で保存しない。予約日時は通常は自然改行、拡大時のみ明示改行。監視警告は警告アイコン＋説明と控えめな青いRetry。

意図的な差分は以下に限定する。アプリ所有のカード・ボタン・情報順を「Androidらしさ」で免責しない。

- OSフォント/アイコン描画、標準SeekBar、標準警告dialog、Back、権限、システムバー、日時のロケール表記、iOS固有のblur/ガラス描画。HOMEロゴ/設定は両者とも固定ツールバー（9/21 HomeViewのtoolbarを確認）。
- iOS simulatorのMessages/Video/GamesとAndroidの実アプリ名/アイコンのfixture差。選択内容を虚偽の名前へ置換しない。実行中画像は同じ3対象でAndroid2時間、iOS約23時間の時間fixture差で、上限契約を変えていない。
- 操作域44dp以上、淡色背景の青文字コントラスト4.73:1、無効表示の可読性、320dp/文字200%/横画面の折返し・スクロール。通常幅の一覧密度を揃えた上で拡大時の収まりを優先する。
- このAndroid変更では無料30分のみとし、9/21のiOS画像の即時課金/購入説明は移植しなかった。保存失敗と監視登録失敗、複数ロック、OS別削除契約、対象固定確認は変更していない。

無料操作の表示改善に伴い、ホームを開いたまま残り30分を跨ぐとボタンが残る経路も修正。Plannerの `canScheduleFreeWake` を保存/ホーム/確認の判定正本とし、既存heartbeatの表示キーへ資格変化を含めた。クリックや画面遷移なしに4.5秒の実時計経過でボタンが消え、保存予定が不変である回帰試験を既存Recoveryへ追加。予約済みの取消は引き続き表示する。

最終Debug SHA256: `2dd5c1b74c78faba0b2025667028ada0092c4717cd065da5b42077cd6d90e4d1`、unsigned Release: `384dd30e990398fd1f899262eef387b749962926a350e4a82cbcb224baa08758`。単体57件、Debug/unsigned Releaseビルド、lint 0 errors / 21 warnings。証拠正本は `artifacts/android-product/home-density-fix/` のnative/interactions/free-wake/visual各result.json。同じDebug APKでnative3系統、実操作15件、画面/操作11確認、無料起床の予約・取消・保存維持・ユーザー補助/アラーム許可の切断復旧・期限後入力復帰が成功。4つの結果のAPKハッシュ一致も確認済み。最終画面は上記docsの画像、nativeの最終証拠は3つのInstrumentationログで、途中診断の画像を最終APK画像として扱わない。

期限後入力復帰のみ8秒へ短縮したfixtureを使う。30分実待機、実機/OEM、TalkBack音声、API26/35での今回の視覚受入、リモートCI・署名配布はこの結果に含めない。失敗した診断・試験前提や再接続準備の修正前結果は成功扱いにしない。最新実機iOSの実行確認ではなく9/21基準の照合。V13は対応予約行、V15は比較画面の横断整理で、V17の未提示画面を一致済みとしない。

### スクショ対比後の仕上げ（2026-10-17）

10/11の「統一済み」は情報階層と主要形状の確認であり、対比レビューで残ったモード文字・モード下の間隔・本文色まで一致したという意味ではなかった。この3点を既存 `Composer` / `TargetRows` / `Palette` で仕上げた。保存、課金、起床、対象固定、OS操作の契約は変更しない。

- モード文字は11sp固定からiOS caption相当の12sp基準へ変更。通常幅の長いラベルのみ10〜12spで自動調整し、iOSのminimumScaleFactor(0.82)相当の縮小範囲とする。狭幅/文字拡大は既存2列と文字拡大を維持し、自動縮小しない。操作域44dp以上は維持。
- モード行の下は8dpからiOSのVStackに合わせ18dpへ。プリセットは44dpの操作域内に上下6dpの透明余白があるため、隣接するslider/補助説明との外側間隔を4dpに調整し、見えるカプセルからは10dpの間隔を保つ。新しい余白補正用の状態や別の描画経路は追加しない。
- 対象詳細の名称とDuration見出しを `Palette.textPrimary` の黒へ変更。件数・選択色・補助文字は従来の濃紺/読みやすい補助色を維持する。汎用ラベルの既定色を一括変更せず、iOSでprimary色になる役割だけを指定。
- 遅延±で直後に上書きしていた古い背景指定2箇所を除去。同じ役割に二重の背景生成を残さない。

既存RecoveryのHOME検証へ12sp上限、44dp操作域、18dp行間、本文色のチェックを追加。別のテスト一覧やUI実装は作らない。単体57件成功、Debug/unsigned Releaseビルド成功、lint 0 errors / 21 warnings、API34 native回帰3系統成功。Debug SHA256 `f14d3e35b3888ecc505c022c0a282e0ea025ed777ec9121b7774fc2249dbba9f`、unsigned Release `bbe4e5f6d374a019f5ca642f1e369820125278987bd3d0ba33dc8d623b4d1f7a`。証拠は `artifacts/android-product/ios-polish-2026-10-17/` に分離し、前段APKの画像・ハッシュを上書きしない。

実操作15件も同じDebug APKで成功し、native/interactions各result.jsonのハッシュ一致を確認した。この時点では最終スクショ照合は未完了だったが、後続の2026-10-17再撮影で同一APKの日英16状態ずつをAndroid 8/API26で取得した。操作前後124枚・日英計16フロー、APK実体と画像のSHA-256は `artifacts/android-product/full-capture-2026-10-17/capture-result.json` に記録した。2026-10-18に比較粒度を訂正し、[比較一覧](../ANDROID_SCREENSHOTS.md)を画面6・部品5・目的4・非対応1へ分離。現在のiOS公開画像はdd83005 / run 39010305244（曜日修正後）。撮影専用の部品ホストをAndroid実ホームと全画面比較していた経路と、OS間RGB差分を撤去した。蜂蜜による課金起床結果と自然終了ホームは別操作のためペア解除し、Androidの不足機能とはしない。モード構成、選択色、日時入力、編集/設定のグループ構成などの実在する差と、状態・OS・方針差を分けて定義JSONで管理する。撮影完了をUI一致やV01〜V17の視覚受入完了とは扱わない。実機、TalkBack、iOSとの同条件の遷移撮影、Android 14の最新全画面撮影は未実施。

撮影時に旧 `bearlock-qa-api34` でANR。保存した `diagnostics/anr.txt` ではmainがRenderProxy.setStopped待ち、RenderThreadがqemu_pipe_read経由のglCreateProgram待ちだった。再起動後はOSのnetdが `libnetd_resolv.so` 欠損で起動を繰り返した。既存AVDは消去せず停止。新規 `bearlock-polish-api34` / swangleでもSystem UI・system processの応答待ちが続き、host GPU（D3D12 / Intel Iris Xe認識）でも安定接続に至らなかった。最後に既存API26は起動完了ログが出たがADB/console接続が確立せず、当該コマンドを確認した専用emulatorプロセスだけSIGTERMで停止した。元のAVDデータと新規AVDは残している。他の作業プロセスやWSL自体の再起動は実施しない。

失敗画像/XMLは `artifacts/android-product/ios-polish-2026-10-17/diagnostics/` へ移動し、repoの最終画像フォルダーには置かない。visual/result.jsonの成功記録も作成していない。環境復旧後、同じAPKで440dpの3対象・履歴5/3/2・Now120分・50dp開始ボタン全体、日本語320dp/200%/横画面、確認/取消を再撮影・照合する作業が残る。前回APKの画像を今回の仕上げの証拠として再利用しない。

9/21 iOSとの比較、V17の参照不足、実機/OEM・TalkBack音声・今回のAPI26/35視覚受入・30分実待機の未確認という境界は維持する。意図的なOS/操作性/承認済み無料30分の差以外まで、全画面がピクセル一致したとは表現しない。

### 曜日UIのiOS追従（2026-10-11）

初回は現行 `WeekdayPicker.swift` / `SelectionButtonStyle.swift` とレビュー記録に追従し、実画面との照合を欠いた。repo内 `docs/qa/android-ui-refresh/ios/en/composeRepeat.png` はチェックなしの角丸ボタン、ユーザー提示のiOS実画面はチェックなしの丸ボタンで、ソースと画像には世代差がある。今回の見た目の正本はユーザー提示画面とする。iOSソースは変更せず、Androidの既存Composer共通フィールドを変更した。

- 通常表示は略称だけの44dp丸ボタン。選択済みは濃紺背景・白文字、未選択は薄いグレー背景・枠線。チェックと空丸アイコン、および専用LineIcon分岐を削除した。Android標準ripple、曜日の正式名称の読み上げとネイティブ選択属性は維持する。
- 7個の44dp操作域と最小4dp間隔が収まるときは一列、狭い画面では4列。fontScale 1.5以上では正式名称の縦並びにし、読みやすさを優先して丸ではなく横長ボタンを使う。これはAndroidの文字拡大対応として明示する差分。日曜始まり・選択集合・次回計算・保存方式は変更しない。
- 作成・編集は既存の同じComposerフィールド処理を使い、新しい状態や別部品は追加しない。検証も既存RecoveryInstrumentationのチェックなし・真円・44dp操作域のアサーションへ置き換える。
- 前回の検証証拠 `artifacts/android-product/weekday-ios-parity` はチェック付きUIの結果であり今回の証拠ではない。上記U2〜U8のAPK/AAB・解除試験も今回のUI修正前の結果。この変更で解除ロジックは変更していない。
- 修正版の単体53件、Debug/Release APKビルド、lint（0 errors / 17 warnings）が成功。通常サイズと320dp・文字200%のRecoveryInstrumentationで選択/解除、チェックなし、通常時の真円、44dp操作域、正式名称、空曜日の保存禁止・次回プレビューを確認した。実画面の証拠は `artifacts/android-product/weekday-circles`。Debug APK SHA-256: `5746ec636d547596a5630703294b4ed681a03cad6b6e56598baf6b7a9fef6f4d`。iOS最新ビルドの実行や、画面全体の一致を確認したという意味ではない。
