# Bearlock: GitHub ActionsからGoogle Play内部テストへ配布する手順

対象アプリID: `com.hiyozoo.bearlock`。2026-09-07作成。

## 今回追加したもの・まだ必要なもの

[Android Internal Release](../.github/workflows/android-internal.yml) は手動実行する配布用Actions。mainでのみ動作し、テスト・Release lint・署名済みAABの生成・署名検証・Artifact保存を行う。オプションでGoogle Playの **internal** トラックへアップロードする。通常のAndroid CIは引き続き署名鍵を使用しない。

この手順とworkflowをmainにpushしてから設定する。実際の署名鍵作成、GitHub Secrets登録、Google Cloud/Play Console設定、リモートActions実行、配信確認は未実施。以下の作業で接続する。

初回: 鍵作成 → GitHub Secrets登録 → ActionsでAAB生成 → Play Consoleに手動アップロード → 自分をテスター登録。

2回目以降: versionCode更新 → mainへpush → Actions実行（Playアップロードをオン）→ 内部テストへ配布。

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
5. リリース名、リリースノートを入力する（例: `0.1.0 / 初回の実機テスト版`）。
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

## 7. 2回目以降はActionsから配布する

1. `android-lab/product/build.gradle.kts` の **versionCodeをPlayにアップロード済みの最大値より大きくする**。例: `1 → 2`。表示用のversionNameも必要に応じ `0.1.0 → 0.1.1` にする。
2. 変更をmainへpushする。
3. **Actions → Android Internal Release → Run workflow** を開く。
4. Branch **main**、`upload_to_play` **オン**にする。
5. `release_status` を選ぶ。
   - **draft**: AABをPlayにアップロードして下書き保存。Consoleで確認・公開する。
   - **completed**: 内部テストへのリリースまで実行。初回の手動配信完了後、継続配布で使う。
6. 成功後、Play Consoleの内部テストでversionCodeと配信状態を確認する。
7. スマホのGoogle Playで更新し、アプリのデータ・予約が引き継がれることを確認する。

pushだけでは配布は走らない。Run workflowが配布の開始操作で、その後の署名・検証・アップロードを自動化している。配信先はinternal固定。Google側の審査や公開操作が別途必要な状態ではConsoleで対応する。

同じversionCodeを再アップロードしない。アップロード後にworkflowが失敗した場合も、Play側にAABが残っていないか確認する。登録済みならConsoleにあるAABを利用するか、versionCodeを増やして新規実行する。

## よくあるエラー

| 症状 | 確認すること |
| --- | --- |
| Actions一覧にworkflowがない | workflowがmainにpushされているか |
| main以外の実行がSkipped | mainを選んで再実行する |
| Missing secret / 鍵の復元失敗 | Environment名、Secret名、Base64全文を確認 |
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
