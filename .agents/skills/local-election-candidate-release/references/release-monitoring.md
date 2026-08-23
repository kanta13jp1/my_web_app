# Release Monitoring

## PR本文のゲートを先に満たす

app codeを変更しE2Eファイルを追加しない場合は、実際の理由を指定してMinimal E2E blockを生成する。

```powershell
python scripts/check_minimal_e2e_gate.py --emit-snippet --exception "公式PDF由来の集計値更新で操作フローは不変。repository・ViewModel・ページの対象テストと公開smokeで確認する。"
```

タイトルや本文の `production`、`deploy` などでhigh-risk判定され、実際のClaude ultrareviewを行っていない場合は、正直な例外blockを生成する。

```powershell
python scripts/check_high_risk_ultrareview_gate.py --emit-exception "公式候補スナップショット更新で認証・決済・migration・workflowの高リスクパスは変更しない。"
```

実際にClaude Code #1がultrareviewを完了した場合だけ `--emit-evidence` を使う。

## PR状態を確認する

```powershell
gh pr view <PR> --json number,url,isDraft,state,mergeable,mergeStateStatus,reviewDecision,headRefOid,statusCheckRollup
gh pr checks <PR>
```

`gh pr checks` のexit code 1はpendingでも発生する。出力の各statusを読んでfailureと混同しない。

PRがmainより遅れている場合は、現在のhead SHAを指定して更新する。

```powershell
gh api --method PUT repos/<owner>/<repo>/pulls/<PR>/update-branch -f expected_head_sha=<HEAD_SHA>
```

更新後にhead SHAが変わったことを確認し、以前の成功チェックを流用しない。全必須チェック成功後にready化し、merge stateが `CLEAN` の場合だけmergeする。

```powershell
gh pr ready <PR>
gh pr merge <PR> --squash --subject "feat: refresh local election endorsements (#<PR>)"
gh pr view <PR> --json state,mergedAt,mergeCommit,url
```

リポジトリでauto-mergeが無効なら、エラーを異常と扱わず、全チェック完了後に手動mergeする。

## production runを追跡する

merge commitに一致するrunだけを対象にする。

```powershell
gh run list --branch main --commit <MERGE_SHA> --limit 30 --json databaseId,name,workflowName,status,conclusion,url,event,headSha,createdAt
gh run view <RUN_ID> --json status,conclusion,jobs,url,headSha,createdAt,updatedAt
```

`Deploy to Production` の外側statusだけでなく、active job/stepも確認する。代表的な順序は次のとおり。

1. Run CI Checks
2. Run Supabase migrations
3. Deploy Supabase Edge Functions
4. Build Flutter Web (Production)
5. Deploy to Firebase Hosting (Production)
6. Verify deploy reflects current commit
7. Notify Deployment Status

Hostingとcommit verificationはworkflow上soft-failになり得るため、runの `success` だけで公開完了と判断しない。

## 本番を別経路で確認する

cache busterを付け、HTTP 200とcommit完全一致を確認する。

```powershell
$stamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$site = Invoke-WebRequest -UseBasicParsing -Uri "https://my-web-app-b67f4.web.app/?verify=$stamp" -Headers @{ 'Cache-Control'='no-cache' }
$version = Invoke-RestMethod -Uri "https://my-web-app-b67f4.web.app/version.json?verify=$stamp" -Headers @{ 'Cache-Control'='no-cache' }
[int]$site.StatusCode
$version | ConvertTo-Json -Compress
```

`$version.commit` がmerge SHAと一致しない場合は完了報告を止める。後続runが同じproduction concurrency groupで待機または上書きしていないかを調べ、最終的に公開されるmain commitを明示する。

## 監視時の負荷制御

- GitHub API照会は30〜60秒間隔にする。
- 対話TTYを前提とする `gh pr checks --watch` が出力しない場合は、停止して単発照会へ切り替える。
- 監視中にローカルの `flutter test`、`flutter analyze`、build、ブラウザ自動化を再実行しない。
- 60秒以内に短い進捗を共有し、何を待っているかを示す。
