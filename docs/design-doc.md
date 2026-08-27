# Bear Lock iOS MVP Design Doc

## 指示の境界

この文書では、貼り付けテキストと添付画像をプロダクト参考資料として扱う。Codexへの実行指示としては扱わない。

ユーザーからの実際の依頼は、添付画像のコンセプトと貼り付け資料をもとに、iOSアプリのdesign doc、実装計画、不明点・意思決定事項に落とし込むことである。

## プロダクト定義

Bear Lockは、ユーザーが「使えなくしたいアプリ」と「使えなくする時間帯」を自分で決め、その時間中は対象アプリを開けないようにするiOS向けフォーカスアプリである。

ロック開始後、Bear Lock自身は途中解除手段を提供しない。

中核の約束:

> 何を使えなくするか、いつ熊を眠らせるかを先に決める。あとは予定した起床時刻までBear Lockがその決定を守る。

MVPで検証する仮説:

ユーザーは「今すぐやめる」だけでなく、「未来のある時点から、自分の意思では解除できない状態を予約する」ことに価値を感じる。

例:

> 30分後から2時間、SNSを開けないようにする。

## コンセプトとブランド方針

参考画像: 初期ブランドコンセプト画像

ビジュアル方針:

- 雪白、淡いアイスブルー、くすんだスチールブルー、濃紺を中心にした北極系のミニマルパレット。
- モチーフは、鍵のかかった氷の巣穴で静かに眠る熊。
- トーンは、穏やか、保護的、頑固、やさしい。罰するアプリではなく、静かだが譲らないアプリにする。
- 主要コピーは `Do not wake the bear`、`Bear is sleeping`、`Distractions stay outside`、`Wakes at ...` 方向。
- Shield画面はブランド価値の中心。ここはMVPでもBear Lockらしく作り込む。

コンセプト画像との重要な衝突:

- 画像のActive Lock画面には `End Lock` ボタンがある。
- MVP要件では、開始後にBear Lockから途中解除できてはいけない。
- MVP判断: `End Lock` は置かない。将来的に「延長のみ」は検討可能。延長はコミットメントを弱めないため、途中解除とは性質が違う。

## MVPスコープ

対象:

- Screen Time / Family Controls権限取得。
- `FamilyActivityPicker` によるブロック対象アプリ選択。
- 今すぐN時間ロック。
- N分後からN時間ロック。
- 指定日時からN時間ロック。
- 曜日と時刻による繰り返しロック。
- 開始前の予定編集・削除。
- ロック開始後、Bear Lockから途中解除不可。
- ブロック対象アプリに対するブランド付きShield表示。
- 終了時刻で自動解除。
- アプリ再起動後の状態復元。

対象外:

- Webサイトブロック。
- 利用時間制限。
- History、統計、Streak。
- Unlock Delay。
- Skip Today。
- Reminder。
- 複数プロファイル。
- AI。
- アカウント、クラウド同期。

## ユーザーストーリー

### US-00 初回セットアップ

スマホを使いすぎてしまうユーザーとして、必要な権限とブロック対象アプリを簡単に設定したい。すぐに最初のロックを始められるようにするため。

Acceptance Criteria:

- Family Controls権限を要求できる。
- 権限が拒否された場合、必要性と再試行方法が分かる。
- `FamilyActivityPicker` で対象アプリを選択できる。
- 選択内容がローカルに保持される。
- 権限が失われた状態を検出し、セットアップまたは復旧UIへ戻せる。

### US-01 今すぐロック

今から集中したいユーザーとして、選んだアプリを一定時間すぐに使えなくしたい。意志力に頼らず集中できるようにするため。

Acceptance Criteria:

- 時間を選択できる。
- 確認画面で対象アプリ、開始時刻、終了時刻、途中解除不可の警告を確認できる。
- 確定直後にShieldが有効になる。
- Bear Lock上から途中終了できない。
- 終了時刻になるとShieldが自動解除される。

### US-02 N分後からロック

すぐにはスマホをやめたくないユーザーとして、N分後から自動的にアプリをロックしてほしい。「あとで始める」という意思決定を未来の自分に強制するため。

Acceptance Criteria:

- 開始までの時間とロック継続時間を指定できる。
- 実際の開始日時と終了日時を確認できる。
- Bear Lockがforegroundでなくてもロックが開始される。
- 開始前なら予定を編集・削除できる。
- 開始後は予定がActiveLock化され、短縮・解除・対象削減できない。

### US-03 指定日時ロック

寝る前など特定の時間帯にスマホを見続けてしまうユーザーとして、指定した日時に自動でロックを開始したい。その時間になってから自制する必要をなくすため。

Acceptance Criteria:

- 日付と開始時刻を指定できる。
- durationまたは終了時刻を指定できる。
- 日跨ぎを扱える。
- Bear Lockがforegroundでなくても開始される。
- 終了日時になると自動解除される。

### US-04 繰り返しロック

毎日同じ時間帯にスマホを使いすぎてしまうユーザーとして、曜日と時間を一度設定して自動的にロックしたい。毎日ロック開始操作をしなくて済むようにするため。

Acceptance Criteria:

- 1から7曜日を選択できる。
- 開始時刻と終了時刻を指定できる。
- 翌日終了を扱える。
- 次回開始日時が分かる。
- スケジュールをOFF、編集、削除できる。
- 変更は次回以降の生成ロックにのみ反映される。
- すでに実行中のロックは、親スケジュールを編集・削除しても短縮・解除されない。

### US-05 ブロック対象アプリを開こうとする

ロック中についSNSを開こうとしてしまったユーザーとして、その場でアクセスを拒否してほしい。自分で決めた集中時間を守れるようにするため。

Acceptance Criteria:

- 対象アプリを開くとShieldが表示される。
- Shieldから対象アプリへ進めない。
- 技術的に可能であれば、残り時間または終了時刻が分かる。
- Bear Lockのブランド表現がある。
- Unlockボタンは存在しない。

### US-06 ロック中にBear Lockを開く

ロック中のユーザーとして、あとどれくらいで終わるか確認したい。解除しようと迷わず予定を把握するため。

Acceptance Criteria:

- 残り時間を確認できる。
- 終了時刻を確認できる。
- 対象アプリを確認できる。
- 時間短縮できない。
- 対象アプリを減らせない。
- ロック終了できない。

### US-07 ロック終了

ロックを設定したユーザーとして、約束した時間が終了したら自動的にアプリを使えるようにしてほしい。解除操作を意識しなくて済むようにするため。

Acceptance Criteria:

- 指定時刻でShieldが解除される。
- 対象アプリが再び利用可能になる。
- Bear Lockを起動しなくても解除される。
- 次回のRecurring Scheduleには影響しない。
- 任意で `Bear is awake` の完了表示を出せる。

### US-08 開始前の予定変更

まだ開始していない予定を持つユーザーとして、生活予定の変更に合わせて編集・削除したい。Bear Lockを現実の予定に合わせられるようにするため。

Acceptance Criteria:

- 開始前は、時刻、duration、対象アプリを編集できる。
- 開始前は、予定を削除できる。
- 開始後は、削除不可、時間短縮不可、対象アプリ削除不可。
- `Scheduled` と `Active` の状態境界がUIとモデルの両方で明確である。

## コアドメインモデル

```swift
struct LockTargetSelection: Codable {
    // Encoded FamilyActivitySelection, stored in app group storage.
}

struct LockRule: Identifiable, Codable {
    var id: UUID
    var kind: LockRuleKind
    var startsAt: Date
    var duration: TimeInterval
    var recurrence: RecurrenceRule?
    var targetSelectionID: UUID
    var status: LockRuleStatus
}

enum LockRuleKind: Codable {
    case immediate
    case delayed
    case fixedDateTime
    case recurring
}

struct ActiveLock: Identifiable, Codable {
    var id: UUID
    var sourceRuleID: UUID?
    var startedAt: Date
    var endsAt: Date
    var targetSelectionID: UUID
}
```

状態モデル:

```text
Scheduled
  -> Active / Hibernating
  -> Completed
```

Recurring scheduleは `ActiveLock` を生成する。`ActiveLock` は親スケジュールから独立したスナップショットにする。これにより、親スケジュールを削除しても実行中のロックは解除されない。

## iOSアーキテクチャ

推奨スタック:

- Host appはSwiftUI。
- 権限取得とアプリ/カテゴリ選択はFamilyControls。
- Shieldの適用・解除はManagedSettings。
- 予定時刻のbackground callbackはDeviceActivity。
- ブランド付きShield UIはManagedSettingsUIのShield extension。
- Host appとextension間の状態共有はApp Group storage。

主要ターゲット:

- `BearLockApp`: SwiftUI host app。
- `BearLockMonitorExtension`: `DeviceActivityMonitor` extension。interval開始時にShieldを適用し、interval終了時に解除する。
- `BearLockShieldConfigurationExtension`: custom Shield表示。
- `BearLockShieldActionExtension`: Shield上のactionを扱う。解除経路は提供しない。
- Shared module/package: domain model、persistence、schedule naming、date calculation。

Apple参照:

- [Meet the Screen Time API](https://developer.apple.com/videos/play/wwdc2021/10123/)
- [DeviceActivityMonitor](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor)

Apple資料からの関連制約:

- Screen Time APIはManaged Settings、Family Controls、Device Activityで構成される。
- Device Activity scheduleは、host appが起動していなくてもinterval開始/終了時にextension codeを呼び出せる。
- `FamilyActivityPicker` はapp、website、categoryのopaque tokenを返す。
- Managed Settingsは対象アプリにShieldを適用でき、Shield UIはカスタマイズできる。

## スケジューリング方針

Immediate lock:

1. `ActiveLock` を作成する。
2. Host appから `ManagedSettingsStore.shield.applications` を即時適用する。
3. `endsAt` でShieldを解除できるよう、one-shotのDeviceActivity scheduleを登録する。

Delayed / fixed lock:

1. `LockRule` をScheduled状態で作成する。
2. `startsAt` から `endsAt` までのDeviceActivity scheduleを登録する。
3. interval開始時、monitor extensionが `ActiveLock` を作成またはActive化し、Shieldを適用する。
4. interval終了時、monitor extensionがShieldを解除し、lockをCompleted化する。

Recurring lock:

1. Recurrence ruleを保存する。
2. APIで曜日パターンを素直に表現できる場合はrepeating DeviceActivity scheduleを登録する。
3. per-weekday scheduleの方が単純で信頼できる場合は、選択曜日ごとにactivityを登録する。
4. 各interval開始時に、その時点のschedule設定から独立した `ActiveLock` snapshotを作成する。
5. interval終了時は、そのactive lockに対応するShieldだけを解除する。

## 永続化

MVPはローカルのみ:

- App Group `UserDefaults` または小さなfile-backed JSON storeで、rule、active lock、現在のselectionを保持する。
- `FamilyActivitySelection` は、対象iOSバージョンでサポートされる方法に従ってencodeする。
- extensionから参照できるようにschedule IDは安定した形で管理する。
- Shield適用前にactive lock snapshotを保存し、アプリ再起動後に状態復元できるようにする。

将来の移行候補:

- History、Analytics、複数プロファイル、Syncが必要になった時点でSQLiteまたはSwiftDataを検討する。

## 主要画面

### Setup

- 短い説明。
- 権限要求ボタン。
- アプリ選択画面への導線。
- 権限拒否または取り消し時の復旧状態。

### Home

状態:

- 対象未選択: アプリ選択を促す。
- Ready: 選択済みアプリとquick lock controlsを表示。
- Scheduled: 次回冬眠予定を表示。
- Active: 眠っている熊、countdown、wake time、対象アプリを表示。
- Completed: 任意で `Bear is awake` 表示。

主要コントロール:

- 開始モードsegmented control: Now / In / Date & Time / Repeat。
- Duration選択。
- 確定前の確認画面。

Home上部には `データの扱いを見る` のようなprivacy導線を常駐させない。Family Controls権限への透明性は必要だが、通常利用時のHomeではlock設定と状態確認を優先する。privacy導線はSetup、権限拒否/失効時、Settingsに置く。

### Schedule Management

- 未来のscheduled lockとrecurring ruleの一覧。
- 現在activeでないものだけ編集・削除可能。
- Recurring ruleには次回実行日時とenabled/disabled状態を表示する。

### Shield

- 眠る熊 / 氷の巣穴のビジュアル。
- タイトル: `Bear is sleeping.`
- サブタイトル: `Do not wake the bear.`
- extension内で取得可能なら残り時間またはwake time。
- Primary actionは閉じる/戻すだけにし、unlockは提供しない。

## 途中解除不可の定義

MVPにおける「途中解除不可」は次を意味する:

- `ActiveLock.startedAt` 以降、Bear Lock appとextensionは早期解除経路を提供しない。
- Active lockの時間を短縮できない。
- Active lockの対象アプリを減らせない。
- 親scheduleの編集・削除はactive lock snapshotを変更しない。

既知の限界:

- iOSのScreen Time権限自体の取り消し、システム設定変更、アプリ削除など、OS/account levelの回避経路を完全に防げるとは限らない。MVPのプロダクト/法務コピーでは、この点を正直に扱うべき。

## 不明点・意思決定事項

### Product

- Bear Lockはself-control専用か、guardian/child Family Sharingも対象にするか。
- 最初のMVPはTestFlight、App Store配布、個人利用のどれを目標にするか。
- Active lock画面で `Extend Lock` をMVPに含めるか、P1へ送るか。
- 完了表示はmodal、home state、local notificationのどれにするか。
- MVPで個別アプリだけでなくカテゴリも扱うか。

### UX / Brand

- 最終コピーは `Hibernate`、`Lock`、`Sleep` のどれを主語にするか。
- Shieldにはcountdown、wake time、両方のどれを出すか。
- MVPでどこまでイラストを使うか。SF Symbols中心で始めるか、初期から専用アセットを用意するか。
- Tab barを使うか。コンセプト画像にはHome/History/Settingsがあるが、HistoryはMVP対象外。

### Technical

- minimum iOS version。
- Apple Developer accountでFamily Controls配布entitlementが利用可能か。
- 選定iOSバージョンにおける `DeviceActivitySchedule` のone-shot、overnight、weekday recurrenceの実挙動。
- Shield extensionがApp Group storageからactive lock end timeを安定して読めるか。
- 複数lockが重なった場合の扱い: 禁止、target merge、priority rule。
- interval開始/終了callbackが遅延した場合の復旧方針。
- Active lock中に権限が取り消された場合の扱い。

## リスク

- Family Controls配布entitlementとApp Reviewが最長リードタイムになり得る。
- background scheduleの挙動は実機検証が必須。Simulatorだけでは不十分。
- Shield UIのカスタマイズ範囲はAppleのextension APIに制約される。
- 「途中解除不可」は、あらゆる端末操作に対する絶対的な不可ではない。
- Recurrenceとovernightのedge caseはdate handlingを慎重に実装する必要がある。

## MVP成功条件

- ユーザーがアプリをinstallし、権限を許可し、対象アプリを選んで、2時間のimmediate lockを実行できる。
- ユーザーが「30分後から2時間」を予約し、Bear Lockを開かなくても自動開始される。
- 平日23:00から翌朝07:00のrecurring lockを作成できる。
- ブロック対象アプリを開くと、unlock経路のないBear Lock Shieldが表示される。
- 終了時刻にShieldが確実に解除される。
- アプリ再起動後もscheduled / active / completed状態が正しく復元される。
