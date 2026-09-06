# Android 版アプリブロック方式の調査

調査日: 2026-09-06。対象は一般ユーザーが自分の端末に入れる集中アプリ。
公式ヘルプと Android / Google Play の一次資料による机上調査。競合の実機動作、内部コード、個別の審査条件は未確認。以下の採用案は確定仕様ではない。

同日追記: Bearlock の小規模試作を作成し、Android 15 エミュレーターで比較した。[比較結果](android-comparison-results.md)と[iOS 機能対応表](android-feature-parity.md)を参照。以下は試作前の調査と検証案。

## 結論

既存製品には「使用状況へのアクセスで対象アプリを検知して画面を重ねる方式」と「Accessibility で対象アプリを検知・介入する方式」がある。Accessibility だけを前提にせず、この2方式の反応速度・電池消費・復旧性を比較する。

Bearlock の既存仕様「開始後、Bearlock 自身から終了・短縮・対象削減できない」は維持する。OS 設定からの無効化に対する耐性は別の評価項目とする。

## 既存製品の公開説明

| 製品 | 公式に説明されている仕組み | Bearlock への示唆 |
| --- | --- | --- |
| AppBlock | Usage Access で前面アプリを検知、Display Over Other Apps でブロック画面、Alarm & Reminders で時間指定。Accessibility は Web・設定・分割画面などの高度な制御にも利用。Strict Mode を提供。 | 基本のアプリブロックと追加の強制機能を分けて検証できる。全機能の権限を初期版に持ち込む必要はない。 |
| Freedom | アプリ・Web ブロックに Accessibility を要求。電池最適化の除外を案内。任意の Device Admin はホーム画面からの削除を妨げるが、設定からの削除は防がないと明記。 | 権限設定・動作状態の確認・復旧案内も製品の一部。 |
| one sec | Accessibility と Overlay の権限を案内。Accessibility の代わりに Usage Access を使う選択肢も提供。イベント受信の方式はポーリング方式より反応・安定性に優れるとの説明。 | 2方式を比較する直接的な先例。ただし one sec の介入体験と Bearlock の解除なしロックは同一要件ではない。 |

出典: [AppBlock の設定・権限説明](https://appblock.app/help/android/settings/)、[Freedom の Android セットアップ](https://support.freedom.to/en/articles/4523583-how-to-install-freedom-for-android)、[one sec の初回設定](https://tutorials.one-sec.app/en/articles/3034754)、[one sec の Accessibility なしの方式](https://tutorials.one-sec.app/en/articles/3148866)。権限の説明から非公開のサービス構成やポーリング間隔までは断定できない。

## 消灯・省電力・予約をどう扱うか

AppBlock はメーカー別の電池・自動起動設定や、分割画面の対策を案内している。Freedom も省電力設定や権限の再有効化を案内する。競合もこの問題を完全に隠蔽できているわけではなく、設定ガイドとトラブル対応で支えている。
出典: [AppBlock のトラブル対応](https://appblock.app/help/android/troubleshoot/)、[Freedom のトラブル対応](https://support.freedom.to/en/articles/4529927-freedom-for-android-troubleshooting)。

Android の AlarmManager はアプリの画面が閉じていても時刻ベースの処理を実行する仕組み。正確なアラームには権限・利用条件があり、再起動後の再登録も必要。競合が使用する内部の予約 API の詳細は、この調査では確認できていない。
出典: [Android: Schedule alarms](https://developer.android.com/develop/background-work/services/alarms)。

Bearlock の設計案:

- 開始・終了予定を永続化し、アラームに加えて対象アプリ検知時・サービス復帰時にも現在時刻と照合する。
- 「予定は存在する」と「実際に制限できる」を区別して表示する。
- 画面消灯中の処理だけでなく、画面復帰後の最初の対象アプリ操作を止められるかを測る。
- 終了時刻を過ぎたブロック画面を残さない。通知の遅れと実際の制限の遅れは別に記録する。
- 権限喪失・強制停止中も動き続けるとは約束しない。復帰した際の予定の整合を確認する。

## 強制モードとストア規約

AppBlock や Freedom は設定アクセス・削除を制限する機能を公式に説明している。ただし、公開されている事実から、その実装を Bearlock がそのまま採用して審査に通るとは判断できない。Device Admin と、管理端末用の Device Owner は別のもの。

Google Play は Accessibility によるアプリ・サービスの無効化や削除の妨害を、保護者管理・企業管理の例外を除いて禁止している。また一般アプリで Accessibility を使う場合、用途申告、アプリ内での明確な開示・同意、審査が必要。集中アプリという理由だけでアクセシビリティ支援ツールのフラグを付けてよいわけではない。
出典: [権限と機密情報 API のポリシー](https://support.google.com/googleplay/android-developer/answer/16558241?hl=en)、[Accessibility API の申告要件](https://support.google.com/googleplay/android-developer/answer/10964491?hl=en)。

初期試作では Bearlock 内の変更禁止を実装対象とし、設定画面全体の封鎖や削除妨害は採用しない。必要性が生じた場合は個別機能として公開要件を再評価する。

## Android 17 の追加条件

Google は Android 17 の Advanced Protection（高度な保護）で、アクセシビリティ支援ツール以外の Accessibility 利用を制限すると説明している。Freedom もこの設定が有効な場合の非互換を案内している。Android 17 全体でアプリブロッカーが使えないという意味ではなく、特定のセキュリティ設定が条件になる。
出典: [Google の Android セキュリティ発表](https://blog.google/security/whats-new-in-android-security-privacy-2026/)、[Freedom のトラブル対応](https://support.freedom.to/en/articles/4529927-freedom-for-android-troubleshooting)。

Bearlock は高度な保護が有効な環境も試験に含める。Usage Access 方式が同じ環境で必要品質を満たすかは未検証であり、動作保証しない。安全設定の無効化を当然の初回手順にせず、方式変更または非対応表示を検討する。

## 次の技術検証案

対象アプリ1つ・最大5分間の即時ロック・消灯中に開始する予約ロックに絞り、下記を比較する案。実施済みの範囲は上記の比較結果に記録した。

| 比較項目 | 使用状況取得＋Overlay | Accessibility による検知＋ブロック表示 |
| --- | --- | --- |
| 検知 | UsageStatsManager のイベントを確認する方式を試す | 対象アプリのイベント受信を試す |
| 主な不確実性 | 確認頻度と電池消費、処理の存続 | 権限の維持、審査、高度な保護との互換性 |
| 共通の測定 | 表示までの遅延、操作が通る時間、開始・終了の遅延、失敗回数、電池消費 | 同左 |

UsageStatsManager は利用イベントを取得する API であり、それ自体がアプリを停止するものではない。
出典: [UsageStatsManager API](https://developer.android.com/reference/android/app/usage/UsageStatsManager.html)。

試験条件:

1. 通常起動、通知経由の起動、対象アプリを開いたまま予約時刻を迎える。
2. 消灯・Doze・省電力・長時間放置からの復帰。
3. 再起動、プロセス終了、ユーザーの強制停止、権限取消と再付与をそれぞれ分ける。
4. 分割画面・PiP・ホームへの移動と再起動。
5. 日付・タイムゾーン変更と終了時刻の整合。
6. Pixel と Galaxy を最低限とし、可能なら独自の省電力制御がある別メーカーも追加する。
7. Android 17 の高度な保護オン／オフ。

結果から、必要な設定数に見合う安定性があるか、予約ロックの約束を満たせるかを判断し、方式と対応端末・OS を決める。2方式とも不十分なら、UI の本格移植前に Android 版の仕様を見直す。
