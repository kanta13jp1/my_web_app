# Issue Fix Plan #3765

- Issue: [[追加要望] 🎥 AI動画シェア投稿をx_post_logに記録しA/B計測対象に含める](https://github.com/kanta13jp1/my_web_app/issues/3765)
- Labels: priority:high,追加要望,growth
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28916261579

## Goal

[追加要望] 🎥 AI動画シェア投稿をx_post_logに記録しA/B計測対象に含める

## Current Context

```text
## 背景
「Home をAIシェア→AI生成して投稿」の**動画投稿経路が x_post_log に variant/utm_content を残していない疑い**（テキストのpostGrowthは残す）。→ collectorが動画投稿のインプレを追跡できず、A/Bループから欠落。

## 検証（実施要）
- 今日の動画ポスト(status/2073240830903820523)が x_post_log / x_post_metric_snapshot に出現するか確認
- 出ないなら、動画投稿経路(universal_x_share_service の video 分岐 or viral-video-ad-generator後段)に x.post相当のログ書込(variant='ai_video', media_type='video', utm_content)を追加

## 受け入れ条件
- AI動画投稿が x_post_log に記録され、collectorがインプレを取得・snapshot化
- performance_context に動画投稿の実績が反映
統括 #3663

```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [ ] Reproduction is clear
- [ ] Smallest safe fix is implemented
- [ ] Analyze/tests/CI are checked
- [ ] PR notes explain the change and the remaining risk
