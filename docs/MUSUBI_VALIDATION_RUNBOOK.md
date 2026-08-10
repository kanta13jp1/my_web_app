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
- migration適用、Firebase staging channel再作成、専用JWT負荷試験、2ブラウザー製品検証は、検証済みcommitをpushしてworkflowを実行した後に記録する。
- Production DB、既存ユーザー、公開募集チャネルへの変更は実施していない。
