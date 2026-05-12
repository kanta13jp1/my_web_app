# Cross-Instance PR: AI Tool Changelog Watch (Claude Code + Codex CLI 月次 fetch)

**2026-05-07 Codex #1 closeout**: The monthly workflow, summarizer, Issue creation,
and H-priority cross-instance draft bundle are implemented under the canonical
Claude Code #1 + Codex #1 two-instance flow. Historical Codex#2 ownership in this
packet is retained below only as archival context.

**作成**: Win版#132 part 98 / 2026-04-30
**FROM**: Win版 (User 要望 + AI_FLEET_SYNERGY 原則 #3 dogfood)
**TO**: Codex#2 (GHA / EF / 自動化補助 territory)
**優先度**: HIGH (= User 直接要望 / fleet 自身の進化基盤)
**期限**: 2026-05-07 (1 週間)
**親軸**: AI_FLEET_SYNERGY #3 + PLATFORM_EVOLUTION #2 + INDIE_DEV_VELOCITY #7

---

## 1. 背景

User 要望:
> 「スケジュールタスクや Claude Code、CodeX の新機能なども考慮して、開発フローの完全自動化は常に検討するようにしてください。
> 毎回のセッションで Claude Code と CodeX の最新情報をネットから取得して新機能の追加などを開発フローの改善に反映できるような仕組みを常に検討するようにしてください」

= **fleet 自身が fleet 自身を進化** させる infrastructure 要望.

AI_FLEET_SYNERGY 原則 #3 (Automate Feature Monitoring) を即 dogfood する形で具体化.

## 2. 期待する実装

### 2.1 GHA workflow 新規

`.github/workflows/ai-tool-changelog-watch.yml`:

```yaml
name: AI Tool Changelog Watch
on:
  schedule:
    - cron: '0 0 1 * *'  # monthly / 1 日 0:00 UTC
  workflow_dispatch: {}

jobs:
  fetch-and-summarize:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - name: Fetch Anthropic Claude Code changelog
        run: |
          curl -s https://docs.claude.com/en/docs/claude-code/changelog \
            > .ci-logs/claude-code-changelog-$(date +%Y%m).html
      - name: Fetch OpenAI Codex CLI changelog
        run: |
          curl -s https://github.com/openai/codex/releases \
            > .ci-logs/codex-cli-releases-$(date +%Y%m).html
      - name: Summarize via Claude API
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          python scripts/ai_tool_changelog_summarize.py \
            --claude-input  .ci-logs/claude-code-changelog-$(date +%Y%m).html \
            --codex-input   .ci-logs/codex-cli-releases-$(date +%Y%m).html \
            --output         docs/ai-tool-changelog/$(date +%Y%m).md
      - name: Create GitHub Issues for high-priority items
        run: |
          python scripts/ai_tool_changelog_to_issues.py \
            --input docs/ai-tool-changelog/$(date +%Y%m).md \
            --label  ai-tool-update
      - name: Commit summary
        run: |
          git add docs/ai-tool-changelog/
          git commit -m "docs(ai-tool): monthly changelog watch $(date +%Y%m)"
          git push
```

### 2.2 Python script 新規

`scripts/ai_tool_changelog_summarize.py`:
- HTML/markdown を Claude API (haiku) で要約
- 新機能 candidate 抽出
- 重要度 H/M/L 自動分類

`scripts/ai_tool_changelog_to_issues.py`:
- 要約から GitHub Issue 生成
- label = `ai-tool-update`
- 重要度 H = cross-instance-pr 自動 draft 候補

### 2.3 docs ディレクトリ

`docs/ai-tool-changelog/202604.md` (= テンプレート):
```markdown
# AI Tool Changelog 2026-04 (auto-generated)

## Anthropic Claude Code
- 新機能 X (link / 重要度 H / 想定影響)
- ...

## OpenAI Codex CLI
- 新機能 Y (link / 重要度 M / 想定影響)
- ...

## fleet 適用候補
- 高重要度 → cross-instance-pr 自動起票候補
- 中重要度 → CLAUDE.md routing matrix 更新候補
- 低重要度 → 参考情報のみ
```

## 3. 受入基準

- [ ] `.github/workflows/ai-tool-changelog-watch.yml` 新規 + cron 動作
- [ ] `scripts/ai_tool_changelog_summarize.py` 新規 + Claude API 連携
- [ ] `scripts/ai_tool_changelog_to_issues.py` 新規 + label ルール
- [ ] `docs/ai-tool-changelog/` ディレクトリ初期化 + 1 sample
- [ ] 初回 manual dispatch で 1 月分 sample 出力
- [ ] cross-instance-pr 完了時 `done/` 移動

## 4. 並行 task

User 同セッション要望:
- インスタンス担当分担 monthly review → docs/MULTI_INSTANCE_FLEET.md 行数 + 過去 30 日 commit 分布 audit
- 開発フロー完全自動化 → 本 PR が第一歩

= AI_FLEET_SYNERGY #1 (Strict Instance Routing audit) と一体運用.

## 5. fleet 自進化 loop の意義

```
[Anthropic / OpenAI が新機能 release]
       ↓ monthly cron
[Codex#2 が fetch + summarize]
       ↓
[GitHub Issue 自動起票]
       ↓
[CEO (= 自分) review → cross-instance-pr 起票]
       ↓
[各 instance が新機能を fleet に取込]
       ↓
[fleet 全体が 1 ヶ月遅れで最新化]
```

= 「**手動 watch 不要** / fleet 自身が fleet を進化」インフラ.

---

*Win版#132 part 98 / 2026-04-30 起票 / AI Tool Changelog Watch / Win → Codex#2 lane / AI_FLEET_SYNERGY #3 dogfood*
