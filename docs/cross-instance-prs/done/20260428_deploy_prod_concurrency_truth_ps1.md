# Cross-Instance PR: deploy-prod concurrency 真実 (15/20 cancelled の実害)

**作成**: Win版#132 part 51 / 2026-04-28
**依頼先**: PS版#1 (`.github/workflows/` 専任 / Rule 17 WF health)
**優先度**: HIGH — production deploy verification trail 75% 欠損 (構造的負債)
**推定工数**: 2-4 hours / 案 A (post-verify step) なら 30 min 短縮可

---

## 背景

Win版#132 part 50 で memo-reactions hotfix (commit 45590ce4) を push 後、
deploy-prod 履歴を確認すると **直近 20 runs で 15 cancelled (75%) / 1 success のみ**。
本部の hotfix run 自体も cancelled。

調査結果 (= memory/feedback_correction_20260428_concurrency_cancel_in_progress_misconception.md):

Win版#109 で `cancel-in-progress: false` に設定したが、これは GitHub Actions の
concurrency 仕様を **誤認** した fix だった:

> GitHub の concurrency は `cancel-in-progress` に関わらず **queue 待機 run を 1 件
> しか保持しない**。並行 5 push の場合: 1 件 running + 1 件 queued + 残り 3 件は
> queued が来るたびに入れ替わる = 中間 3 件が cancelled される。

`cancel-in-progress: false` は「実行中 run を新着 push で kill しない」だけで、
queue 制限は別仕様として適用される。

## 影響

| 項目 | 状態 |
| --- | --- |
| production deploy 自体 | ✅ 最新 HEAD は反映される (cancel-in-progress: false 効果) |
| 中間 commit の deploy verification trail | ❌ 75% 欠損 |
| OPS-28 5 正本層 #1 (Issues/PR 完了判定) | ❌ 崩壊 (PR merge ≠ deploy 確認) |
| OPS-28 5 正本層 #5 (worktree/main) | ⚠️ 部分崩壊 (main commit ↔ production hash の対応不明) |

## 観測データ (本部 51 起票時点 = 2026-04-28 朝)

```
last 20 deploy-prod runs:
  cancelled: 15  (75%)
  in_progress: 2
  failure: 2
  success: 1
```

最終的に push した commit は production に反映されているが、
**「この commit が deploy された」と Issue / PR で完了報告できない**
状態 = OPS-28 charter の根幹である「PR を実完了判定の正本」前提が機能不全。

## 対策候補

### 案 A: post-deploy verification step 追加 (推奨 / 30 min)

deploy-prod.yml の最後に新 step:

```yaml
- name: Verify deploy reflected current commit
  run: |
    EXPECTED_SHA=${{ github.sha }}
    # main.dart.js に commit hash が埋め込まれているか確認
    DEPLOYED_SHA=$(curl -s https://my-web-app-b67f4.web.app/main.dart.js \
      | grep -oE 'commit:[a-f0-9]{40}' | head -1 | cut -d: -f2)
    if [ "$DEPLOYED_SHA" != "$EXPECTED_SHA" ]; then
      echo "::warning::deploy not yet reflecting $EXPECTED_SHA (current: $DEPLOYED_SHA)"
      # cancel された後継 run が反映するなら問題なし → warning のみ
    fi
```

= cancelled でも warning のみで成功扱い (副作用なし)。同 group の別 commit が
反映していれば実害ゼロ確認の証跡を残す。

### 案 B: deploy queue scheduler 化 (heavy / 2-3 hours)

別 workflow `deploy-queue-scheduler.yml` (cron 2 min 毎) で `gh workflow run
deploy-prod.yml` を pending list から 1 件ずつ dispatch。pending list は新規
table or repo internal file で管理。完全な順次実行を保証するが実装複雑。

### 案 C: deploy-prod を job matrix 化 (1-2 hours)

deploy-prod.yml の job を matrix で 1 件ずつ実行する内部 queue を持たせる。
GHA matrix の `max-parallel: 1` を使うが、push trigger ベースだと結局 concurrency
group に戻るため効果限定的。

### 案 D (暫定 mitigation / 30 min): push burst alert

scripts/check_push_burst.py + GHA cron で「1 min 以内に 5 push 以上検出」時 Slack
alert → User に「同期 push を 2 min 間隔に分散」依頼。実害は減らないが可視化は可。

## 推奨実装順序

1. **案 A を即適用** (30 min / 副作用ゼロ / 実害ゼロ確認の trail を残す)
2. **案 D を 1 週間後**に追加 (push burst pattern 監視)
3. **案 B / C は需要を見てから判断**

## 完了条件

- [ ] 案 A の verification step を deploy-prod.yml に追加 + main merge
- [ ] 直近の cancelled run の commit が production に反映されているか手動確認
      (sitemap.xml + main.dart.js grep で 1 度確認 → 結果を docs に記録)
- [ ] feedback_correction 記録 (memory/feedback_correction_20260428_concurrency_cancel_in_progress_misconception.md
      = 本部 51 で起票済) を Win版#109 memo に shadow として明示参照
- [ ] Push 後この cross-instance-pr を `docs/cross-instance-prs/done/` に移動

## OPERATIONS_CHARTER 整合

- 改善トリガー **#5 (形骸化した運用)** = Win版#109 fix の前提が崩れていた
- 改善トリガー **#4 (正本ズレ)** = main commit ↔ deploy state の対応不明
- 5 正本層 **#1 (Issues / PR)** = PR merge を完了判定とする前提を案 A で復活させる
- 5 正本層 **#5 (worktree / main)** = main HEAD と production hash を案 A で整合確認

## 補助情報

GitHub Actions concurrency 仕様 (公式 docs):
> If a workflow run is queued, but has not yet been started, and another run is
> queued for the same concurrency group, the previously queued run will be
> cancelled.

この仕様は `cancel-in-progress` 設定に **関係なく** 適用される。

---

*Win版#132 part 51 / 2026-04-28 起票*
