# MUSUBI Validation Runbook

## Purpose

MUSUBIの成功を滞在時間や無限スクロール量ではなく、次の4指標で判断する。

1. 投稿・DMがリアルタイムに反映される信頼性
2. 必要な人・投稿・コミュニティへ到達する検索成功率
3. 通報から初動・解決までの安全運用
4. 利用後の疲労感、情報への信頼、居場所感

## Environments and safety

- 負荷試験はstagingを既定とし、本番実行には運用担当の承認を必要とする。
- `scripts/musubi_load_test.py` は既定でdry-run。ネットワーク送信には `--execute` が必要。
- 初回は50 requests / concurrency 5から始め、DB CPU、Realtime接続数、エラー率を確認して段階的に増やす。
- P95 1.5秒超またはエラー率2%超で失敗とし、次の段階へ増やさない。
- DM本文や研究コメントをログ・負荷試験成果物へ保存しない。

```powershell
python scripts/musubi_load_test.py --scenario mixed --requests 50 --concurrency 5

$env:SUPABASE_URL='https://staging-project.supabase.co'
$env:SUPABASE_ANON_KEY='<staging anon key>'
$env:MUSUBI_TEST_JWT='<dedicated test user JWT>'
python scripts/musubi_load_test.py --scenario mixed --requests 50 --concurrency 5 --execute
```

## Realtime acceptance gates

- 2ブラウザーで同じ公開フィードを開き、投稿が2秒以内にもう一方へ現れる。
- 同じDM threadの2ユーザーで、メッセージが2秒以内に反映される。
- 回線を30秒切断して復帰後、重複せず最新snapshotへ収束する。
- 未参加ユーザーがDM threadをREST・Realtimeのどちらからも取得できないことを確認する。

## Moderation operations

| Priority | Example | First response | Action |
|---|---|---:|---|
| P0 | 具体的な自傷・他害、児童安全、差し迫った危険 | 15分 | 地域の緊急窓口を案内し、管理者へ即時エスカレーション |
| P1 | 脅迫、標的型嫌がらせ、なりすまし | 1時間 | 拡散抑制、証跡保全、担当者2名で審査 |
| P2 | 誤情報、スパム、反復的な規約違反 | 24時間 | 文脈ラベル、可視性制限、異議申立て導線 |

すべての解決は `musubi_reports` に状態と担当者を記録する。自動判定だけで永久停止しない。

## Real-user validation

### Recruitment

- 社内・既存ユーザーから自発参加者を募集し、知人への強制や報酬目的の自己取引を行わない。
- 第1コホートは5〜8名、第2コホートは15〜20名を目安にする。
- 参加前に目的、保存データ、撤回方法、問い合わせ先を説明する。

### Seven-day protocol

1. Day 0: 同意、現在使うSNS、期待と不安を確認。
2. Day 1–6: 1日10〜20分を上限に、検索、投稿、DM、通報導線を試す。
3. 各利用後: アプリ内チェックインで疲労・信頼・居場所感を1〜5で回答。
4. Day 7: 30分のインタビューとデータ削除・継続利用の意思確認。

### Decision gates

- 主要タスク完了率 80%以上。
- 検索上位5件で目的の結果を見つけられる参加者 70%以上。
- DM送受信成功率 99%以上。
- P0/P1模擬通報のSLA達成率 100%。
- 疲労感中央値が比較対象SNS以下、信頼・居場所感中央値が3.5/5以上。
- 重大なRLS漏えい、同意なし研究保存、通報者特定が1件でもあれば公開を停止する。

## Evidence to retain

- 匿名化した集計値、テスト日時、アプリcommit、migration version、環境名。
- 失敗したシナリオと回復手順。
- 参加同意のversionと撤回記録。
- 個人のDM本文、アクセストークン、自由記述の原文はCI成果物へ含めない。

## 2026-08-10 local validation record

外部環境へ書き込む前の証跡。JWT、password、service-role key、DM本文の原文は保存しない。

- Environment: Docker上の隔離Supabase project `musubi-local-validation-20260810`。
- Migration: `20260810090000_create_musubi_social_platform.sql` を空DBへ適用。8 tables、25 RLS policies、Realtime publication 2 tablesを確認。
- DB lint: `supabase db lint --schema public --level warning --fail-on warning` はexit 0、`No schema errors found`。
- Migration fix: PostgreSQL 17がgenerated column内の `array_to_string` をimmutableと認めないため、検索vector更新をBEFORE triggerへ変更。
- Repository baseline: 全migrationの空DB再生は、CREATE履歴がない既存 `user_stats` を `20251106000000_add_growth_metrics.sql` が参照して失敗。MUSUBI migrationとは別のbaseline修復課題として扱う。
- Dedicated users: ローカル専用A/B/Cの3ユーザーとJWTを発行し、tokenはプロセス外へ保存していない。
- Load stage 1: 50 requests / concurrency 5、error rate 0%、p95 253.89 ms。
- Load stage 2: 200 requests / concurrency 10、error rate 0%、p95 25.98 ms。
- Realtime: 独立originの認証済みsession A/B間で公開投稿を受信。DOM反映まで394 ms、DB行1件を確認。
- DM participant UI: AからB、BからAのthreadとメッセージを表示。
- DM non-member UI: 第三者CにはA/B、thread、保護メッセージのいずれも表示されない。
- DM RLS API: BのSELECTは1件、CのSELECTは0件、CのINSERTはHTTP 403。
- Browser limitation: Chrome拡張はローカルAuth endpointを `ERR_BLOCKED_BY_CLIENT` で遮断したため、Realtime計測はCodex内ブラウザーの独立origin sessionで実施。stagingではChromeを含む2ブラウザー製品で再検証する。

### External staging status

- 2026-08-10、東京リージョンに隔離project `atbqcmbtfypllnhqhqup` (`my-web-app-staging`) を作成。Production project `smmkxxavexumewbfaqpy` とは異なることを確認した。
- GitHub repository secretsのstaging project id、URL、anon key、DB passwordを更新し、staging専用service-role keyを追加した。秘密値はrunbook、ログ、成果物へ保存していない。
- staging workflowはProductionとの同一projectを拒否し、全migration履歴の一括repairを廃止。staging専用bootstrapとMUSUBI migrationだけを適用後、DB lintを必須実行する。
- GitHub Actions run `31368856394` でmigration、linked DB lint、Flutter build、Firebase staging channel deployが成功した。
- Staging URL: `https://my-web-app-b67f4--staging-ji7q5u7u.web.app`。
- Production DB、既存ユーザー、公開募集チャネルへの変更は実施していない。

## 2026-08-12 external staging validation record

専用テストユーザーA/B/Cだけを使用した。JWT、password、anon key、service-role key、DM本文の原文は保存しない。

- Load stage 1: 50 requests / concurrency 5、失敗0件、error rate 0%、p95 548.34 ms。
- Load stage 2: 200 requests / concurrency 10、失敗0件、error rate 0%、p95 222 ms。単発の最大10秒outlierは継続監視対象とする。
- Realtime browser products: ChromeとCodex In-app BrowserでA/Bを別sessionとして接続し、両方で `LIVE` を確認。
- Public post Realtime: BのUIから保存した一意markerをChrome Aが1,410 msで受信。staging DB行とBのauthor idを確認し、2秒gateを通過した。
- DM participant Realtime: BのUIから送信した一意markerをChrome Aが862 msで受信。staging DB行を確認し、2秒gateを通過した。
- DM RLS API: 参加者BのSELECTは3件、非参加者CのSELECTは0件、CのINSERTはHTTP 403。
- UI defect: 右下のUniversal AI Share FABがMUSUBIのDM送信アイコンを覆うことを実機で確認。`/musubi` と `/social-feed` ではFABを下端88 pxへ退避する修正と回帰テストを追加した。
- Production DB、Production site、実ユーザーには書き込んでいない。

## 2026-08-13 research-consent hardening record

第1コホート募集前のprivacy gateとして、研究データの保存境界と撤回を再検証した。

- Consent version: `2026-08-13-v1`。第1コホート識別子は `first-user-2026-08`。
- App boundary: 永続化済みの有効な同意がない場合、起動イベントを含む研究操作イベントを保存しない。
- DB boundary: `musubi_research_events` のINSERTは、同じuser、cohort、consent versionの有効な研究同意が存在するときだけ許可する。
- Withdrawal: 同意を先に無効化して新規イベントを止め、回答と全操作イベントを削除する。
- Local migration: Supabase公式Postgres 17の隔離DBへMUSUBI基礎migrationと `20260813090000_enforce_musubi_research_consent.sql` を適用した。
- Local DB lint: `supabase db lint --local --schema public --level warning --fail-on error` はexit 0、`No schema errors found`。
- RLS behavior: 同意前INSERT拒否、同一versionの同意後INSERT許可、version不一致拒否、撤回後INSERT拒否、撤回後の回答・イベント件数0を確認した。
- Repository baseline: 通常の `supabase start` は既知のbaseline欠落（`user_stats`）で停止するため、隔離DBではMUSUBIに必要な既存admin判定だけをfalse固定スタブとして用意した。Productionやstagingへはこのスタブを適用していない。

## First cohort recruitment handoff

### Recommended allocation

5〜8名を次の順で集め、8名に達したら募集を止める。

1. 既存Slackコミュニティのプロダクト検証チャンネル: 3名。
2. 運営者のXアカウント: 2〜3名。
3. 既存ユーザーまたは知人への個別メール: 不足分0〜2名。

公開投稿にはstaging URLを載せない。同意確認後、対象者へ個別にURLとテスト手順を送る。

### Public recruitment copy

```text
【先行テスター5〜8名募集】
人と文脈を主役にした新しいSNS「MUSUBI」の7日間テストに協力いただける方を募集します。

・1日10〜20分程度
・投稿、検索、DM、通報導線を試す
・利用後に疲労感／信頼感／居場所感を各1〜5で回答
・最終日に30分の振り返り

広告最適化ではなく、安心してつながれる体験を検証します。参加は任意で、途中撤回とデータ削除が可能です。興味のある方は「参加希望」とDMしてください。定員8名です。
```

### Private onboarding copy

```text
ご協力ありがとうございます。MUSUBI第1コホートは7日間、1日10〜20分が上限です。

保存対象: テスト用プロフィール、投稿、DM、アプリ内で研究同意した後の操作イベントと1〜5評価。
保存しないもの: パスワード、JWT、個人DM本文のCI成果物、研究同意前の回答・操作イベント。
研究同意文: 2026-08-13-v1。
撤回: いつでもこの連絡先へ「撤回」と返信するか、アプリ内の研究参加取り消しを実行してください。以後の研究利用を止め、研究回答と操作イベントを削除します。

上記に同意する場合は「同意します」と返信してください。確認後にstaging URL、専用アカウント、Day 0手順を個別送付します。
```

### Manual steps

1. 使用するXアカウント、Slack workspace/channel、個別メール候補を人間が指定する。
2. 上の公開文をXとSlackへ投稿する。外部送信前に宛先とアカウントを再確認する。
3. 応募者へprivate onboarding copyを送り、明示的な同意返信を得る。
4. staging URLを個別送信し、各参加者が本人のメールで登録する。パスワード、Magic Link、JWT、共有アカウントを運営者から配布しない。
5. 初回ログイン後、MUSUBI Safetyの7-day check-inで同意文 `2026-08-13-v1` を確認し、研究参加checkboxを選んで最初の回答を送信してもらう。このアプリ内操作が完了するまでは研究イベントを保存しない。
6. アプリ内同意済み5名で開始し、8名で締め切る。氏名ではなく `first-user-2026-08-01` のようなcohort participant idで管理する。
7. 撤回連絡を受けたら、まず本人にアプリ内の「研究参加を取り消して研究データを削除」を実行してもらい、運営者は完了時刻だけを記録する。実行できない場合は管理者がuser idを確認して回答・イベントを削除する。
8. Day 7に継続／削除を確認し、撤回者の研究データ削除とstaging access無効化を確認する。
