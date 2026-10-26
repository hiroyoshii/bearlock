# Bearlock: GitHub ActionsからGoogle Play内部テストへ配布する手順

対象アプリID: `com.hiyozoo.bearlock`。2026-10-26更新。

## 今回の更新版を内部テストへ進める

[Android Internal Release](../.github/workflows/android-internal.yml) は手動実行する配布用Actions。mainでのみ動作し、テスト・Release lint・署名済みAABの生成・署名検証・Artifact保存を行う。オプションでGoogle Playの **internal** トラックへアップロードする。通常のAndroid CIは引き続き署名鍵を使用しない。

アプリのPlay登録・アップロード鍵・GitHub Secrets・Play連携は設定済み（2026-10-26、ユーザー確認）。再設定や鍵の作り直しは不要。[過去の配布CI](https://github.com/hiroyoshii/bearlock/actions/runs/34709724321)でも署名済みAABの生成・署名検証・Artifact保存が成功している。この実行ではPlayアップロードはオフだったため、アップロード成功の証跡とは区別する。

バージョン値の正本は [product/build.gradle.kts](../android-lab/product/build.gradle.kts)。2026-10-26、ユーザーからPlayでversionCode 8が使用済みとの報告を受け、次のAAB用に9へ更新した。表示用のversionNameは0.2.3のまま。versionCodeはPlayが更新順を判定する整数で、同じ番号は再アップロードできない。既存AABの番号は設定変更だけでは変わらないため、更新後のmainで **Run workflow** を新しく実行し、生成されたAABを使用する。古い実行の **Re-run jobs** は古い設定で再ビルドするため使わない。

1. [Android Internal Release](https://github.com/hiroyoshii/bearlock/actions/workflows/android-internal.yml) → **Run workflow** → **main**。
2. `upload_to_play` を **オン**、`release_status` を **draft** にして実行する。署名・単体テスト・Release lintが成功すると、AABを内部テストの下書きへアップロードする。
3. Play Consoleの内部テストでバージョンと状態を確認し、[リリースノート](android-release-preparation.md#内部テスト版のリリースノート)を入力する。テスターへの配信を確定する。
4. 登録済みテスターが参加リンクから更新する。新規インストール、更新前の対象・予定の保持、通常UIでの作成→遮断→自然終了を確認する。30分後起床は残り30分超のロックから予約・取消・実時間での解除を確認する。

`completed` は内部テスターへの配信まで実行する指定。配信も同時に行うときに選ぶ。AAB生成だけを確認する場合は `upload_to_play` をオフにする。mainへのpushだけではこの配布workflowは実行されない。

今回の準備作業ではPlayアップロード・テスター配信・実端末での更新確認は実行していない。以下の初期設定手順は保守用の参照であり、今回やり直す手順ではない。

## 初期設定・保守用の参照

## 1. アップロード鍵を作る（初回のみ）

すでにこのアプリをPlayにアップロード済みなら、登録済みアップロード鍵を使う。毎回新しい鍵を作らない。

WSLのターミナルで実行する。保存場所はリポジトリ外。

```bash
install -d -m 700 "$HOME/.local/share/bearlock-signing"
keytool -genkeypair -v -storetype JKS \
  -keystore "$HOME/.local/share/bearlock-signing/upload.jks" \
  -alias bearlock-upload -keyalg RSA -keysize 3072 -validity 10000
```

画面の質問に従って、キーストアのパスワードと証明書の情報を入力する。最後の鍵パスワードはEnterでキーストアと同じにできる。パスワードはチャットやコマンド引数に書かず、対話入力する。

`upload.jks`、パスワード、alias `bearlock-upload` をパスワード管理ツール等にバックアップする。GitHub Secretsだけを唯一の保管場所にしない。

GitHubへ登録するためBase64ファイルを作る（Base64は暗号化ではなく、このファイルも秘密情報）。

```bash
umask 077
base64 -w 0 "$HOME/.local/share/bearlock-signing/upload.jks" \
  > "$HOME/.local/share/bearlock-signing/upload.jks.base64"
```

WSLでこのディレクトリを開くには `explorer.exe "$(wslpath -w "$HOME/.local/share/bearlock-signing")"`。Base64ファイルをエディタで開いて全文をコピーする。

## 2. GitHubに署名情報を登録する

1. [bearlockのSettings](https://github.com/hiroyoshii/bearlock/settings) → **Environments** → **New environment**。
2. 名前を **android-internal** にする。workflow内のenvironment名と一致させる。
3. 利用できる場合、Deployment branches and tagsをmainだけに制限する。
4. このEnvironmentの **Environment secrets → Add environment secret** に以下を登録する。

| Secret名 | 登録する値 |
| --- | --- |
| `BEARLOCK_KEYSTORE_BASE64` | `upload.jks.base64` の全文 |
| `BEARLOCK_STORE_PASSWORD` | キーストアのパスワード |
| `BEARLOCK_KEY_ALIAS` | `bearlock-upload` |
| `BEARLOCK_KEY_PASSWORD` | 鍵のパスワード。Enterで共通にしたならSTOREと同じ |

ファイルや値をGitへcommitしない。workflow側が一時ファイルに鍵を復元し、署名後に削除する。Secretsをコードに貼る必要はない。

## 3. 初回の署名済みAABをActionsで作る

1. [Actions](https://github.com/hiroyoshii/bearlock/actions) → **Android Internal Release**。
2. **Run workflow** → Branchは **main**。
3. `upload_to_play` は **オフ**。`release_status` はdraftのままでよい（アップロードしない場合は使わない）。
4. 実行が成功したら、その実行のArtifactsから **bearlock-signed-aab-番号** をダウンロード。
5. ZIPを展開し **product-release.aab** を取り出す。

既存の「Android CI」のArtifactと取り違えない。配布用workflowのAABが対象。テスト・lint・署名検証に失敗した場合、Playアップロードには進まない。

## 4. 初回だけPlay Consoleへ手動アップロードする

1. [Play Console](https://play.google.com/console/) でBearlockを開く。
2. **テストとリリース → テスト → 内部テスト → 新しいリリースを作成**。
3. **App Bundleのアップロード**へ手順3のAABをアップロードする。
4. パッケージ名が `com.hiyozoo.bearlock` であることを確認する。
5. リリース名、リリースノートを入力する。
6. **プレビューして確認**に進み、表示される必須設定・エラーを解決して内部テストへの公開を確定する。

新規アプリのPlayアプリ署名はGoogle生成鍵が標準。AABは自分のアップロード鍵で署名し、端末に配布するAPKはGoogleがアプリ署名鍵で署名する。Android Developer Consoleで鍵を追加する作業はこの配布手順には含まない。

初回の手動アップロードでパッケージをPlayに登録する。API連携用Actionもこの初回登録を前提としている。アカウント確認やアプリ内容の申告など、Consoleで要求される作業はAPIで自動完了しない。

## 5. 自分をテスターに登録してスマホへ入れる

1. **内部テスト → テスター**タブを開く。
2. メールリストを作成。名前は例として `Bearlock internal`。
3. スマホのGoogle Playで使っているGoogleアカウントのメールアドレスを追加。
4. 作成したリストにチェックを入れ、保存する。
5. 同じページのテスト参加リンクをコピーし、スマホで開く。
6. 登録したGoogleアカウントで参加し、Google Playからインストールする。

メールリストへの追加だけで完了ではなく、参加リンクでの参加操作も必要。一般公開前はストア検索では見つからないのでリンクを使う。反映に時間がかかる場合がある。

すでにDebug APKを入れている端末では署名が違うため上書きできない場合がある。その場合は既存アプリのデータが消えることを確認してからDebug版をアンインストールする。以後はPlay版で更新を確認する。

## 6. Google Playへの自動アップロードを接続する

署名鍵とは別に、Google Play Developer APIへアクセスするサービスアカウントを用意する。

1. [Google Cloud Console](https://console.cloud.google.com/) で使用するプロジェクトを選ぶ（なければ作成）。
2. [Google Play Android Developer API](https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com) をそのプロジェクトで有効化。
3. **IAMと管理 → サービスアカウント → サービスアカウントを作成**。名前は例として `bearlock-play-upload`。
4. この用途だけならプロジェクトのOwner/Editorロールは付与しない。
5. 作ったサービスアカウントの **鍵 → 鍵を追加 → 新しい鍵を作成 → JSON** でダウンロード。
6. サービスアカウントのメールアドレス（末尾 `iam.gserviceaccount.com`）をコピー。
7. Play Consoleの **ユーザーと権限 → 新しいユーザーを招待** にそのメールを入力。
8. アプリの権限で **Bearlockのみ** を対象とし、「アプリ情報を表示（読み取り専用）」と「テストトラックへのアプリのリリース」に相当する権限を付与して保存する。テスターのリストは手順5で人が管理する。製品版リリース・売上・管理者権限はこのworkflowには不要。
9. GitHubの **Settings → Environments → android-internal → Environment secrets** に次を追加する。

| Secret名 | 登録する値 |
| --- | --- |
| `PLAY_SERVICE_ACCOUNT_JSON` | ダウンロードしたJSONの全文（Base64化しない） |

JSONには秘密鍵が含まれるためGitやチャットに貼らない。この実装はSecrets経由のJSON鍵方式。組織ポリシーでJSON鍵作成が禁止されている場合は、ポリシーを解除せずWorkload Identity Federation方式へworkflowを変更する。

## 7. 更新配布時の注意

`android-lab/product/build.gradle.kts` のversionCodeをPlayにアップロード済みの最大値より大きくし、変更をmainへpushしてから、[冒頭の配布手順](#今回の更新版を内部テストへ進める)を使う。表示用のversionNameも必要に応じて更新する。配信先はinternal固定。Google側の審査や公開操作が別途必要な状態ではConsoleで対応する。

同じversionCodeを再アップロードしない。アップロード後にworkflowが失敗した場合も、Play側にAABが残っていないか確認する。登録済みならConsoleにあるAABを利用するか、versionCodeを増やして新規実行する。

## よくあるエラー

| 症状 | 確認すること |
| --- | --- |
| Actions一覧にworkflowがない | workflowがmainにpushされているか |
| main以外の実行がSkipped | mainを選んで再実行する |
| Missing secret / 鍵の復元失敗 | Environment名、Secret名、Base64全文を確認 |
| SDK setupで `Failed to find package 'tools'` | 修正済みmainから新規実行する。setup-android v3の既定値に含まれる廃止済みtoolsを避け、platform-toolsを明示している。[上流の説明](https://github.com/android-actions/setup-android/blob/main/README.md?plain=1) |
| Gradle ZIPのDownload timeout | Wrapperの待ち時間は120秒に設定。修正後のmainを選んでRun workflowで新規実行する。古い実行のRe-runは古い設定を使う |
| keystore password incorrect / key alias not found | STORE_PASSWORD、KEY_PASSWORD、aliasを確認 |
| version code already used | Playの最大versionCodeより大きくして新規実行 |
| Package not found | 初回の手動AABアップロード、アプリ権限を確認 |
| 403 / caller does not have permission | API有効化、JSONのサービスアカウント、Playのアプリ権限を確認 |
| Only releases with status draft… | draftでアップロードし、初回公開をConsoleで完了させる |
| Changes not sent for review… | Consoleで必要な申告・審査状態を確認。配布成功とは扱わない |
| テスターがインストールできない | メールリストの選択・保存、参加リンク、ログインアカウント、リリース状態を確認 |

## 参照

- [Google: アプリへの署名](https://developer.android.com/studio/publish/app-signing?hl=ja)
- [Google: Playアプリ署名](https://support.google.com/googleplay/android-developer/answer/9842756?hl=ja)
- [Google: 内部テストの設定](https://support.google.com/googleplay/android-developer/answer/9845334?hl=ja)
- [Google: Developer APIの初期設定](https://developers.google.com/android-publisher/getting_started)
- [Google: Play Consoleのユーザーと権限](https://support.google.com/googleplay/android-developer/answer/9844686?hl=ja)
- [使用するアップロードAction](https://github.com/r0adkll/upload-google-play/tree/e738b9dd8f2476ea806d921b64aacd24f34515a5)（第三者製、commit固定）
