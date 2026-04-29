# [CONSTRAINT-LOG] inject-rules.txt blog-publish AI_DEV score 更新 (2/7→5/7)

- **発見**: PS版#1 S12 (2026-04-20)
- **対象**: `~/.claude/hooks/inject-rules.txt` 102行
- **問題**: `[AI-DEV-23]` rule 内 "blog-publish (2/7)" は陳腐化 — 実際は 5/7 (CB+QG+TRACE_ID+DLQ 追加済 / commit 02bdea2d, PS版#1 2026-04-20)
- **修正**: 102 行を以下に置換

```text
既存要改善: blog-publish (5/7・残: retry policy + team memory score) ※competitor-monitoring 6/7 改善済 (PS版#4 · 2026-04-19) ※blog-publish CB+QG+TRACE_ID+DLQ 追加 (PS版#1 · 2026-04-20 commit 02bdea2d)
```

- **影響**: 全インスタンスの UserPromptSubmit hook で正しい現状が注入される
- **記録**: `docs/instance-constraints.md` 制約発見ログ追記済
- **残作業 (PS版#1 候補)**: blog-publish 5/7→7/7
  - **#6 retry policy**: workflow Step 3 (Qiita POST) で 5xx/429 時 `gh workflow run --ref main` で 1 回リトライ (現状: 失敗即終了)
  - **#5 team memory score**: 過去 30 件の Qiita post の view/like を `blog_posts.engagement_score` に集計 → 高スコア記事の文体を bot に注入
- **担当依頼**: なし (PS版#1 セッション内で完結)

## Philosophy Alignment

- 原則 6 (資本=時間): rule 鮮度維持で誤判断時間ゼロ
- 原則 8 (KPI=昨日の自分): 進捗 (2→5/7) を可視化
- 整合性: 7/9
