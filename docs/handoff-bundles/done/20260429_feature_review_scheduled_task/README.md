# Handoff Bundle: 機能レビュー Scheduled Task

**作成**: Win版#132 part 77 / 2026-04-29
**機能種別**: GHA Cron + Python script + GitHub Issue 自動化
**優先度**: medium
**期限**: 2026-05-13 (= Codex#2 完成想定)
**親軸**: COLLAB_AI #5 Verifier-Generator / OPS-28 改善トリガー / VIBE_CODING #4 Black-Box I/O Verification

---

## 1. ユーザー要望

> 「各機能をレビューして、修正すべき問題を GitHub Issues に登録するというスケジュールタスクを追加できますか？」(Win版#132 part 77 / 2026-04-29)

= 自分株式会社の **既存機能を定期 audit** + **修正すべき問題を GitHub Issue 自動起票** する schedule task.

## 2. Plan (= 設計判断)

### 2.1 採用案: 毎時 GHA cron + ローテーション + Python script + Claude API レビュー

```
[毎時 cron / 0 分 / 13 機能を round-robin 巡回]
   ↓
[scripts/feature_review.py 実行 (= UTC 時刻 % 13 で対象機能選択)]
   ↓
[1 機能のみシグナル取得]
  - 本番 URL Playwright screenshot (= UI 状態)
  - flutter analyze cache (= lint 警告)
  - 直近 git log (= 最近触られたが test なし?)
  - source TODO/FIXME 検索
  - a11y ヒューリスティック
   ↓
[Claude API (Haiku 4.5 / effort=medium) で bundle 評価 / max 3 findings]
   ↓
[findings JSON → GitHub Issue 化 (de-dupe + label / max 1 issue/run)]
   ↓
[Slack 通知 (= 既存 webhook 流用 / 起票時のみ)]
```

### 2.1.1 毎時運用の意義

- **ノイズ抑制**: 毎時 1 機能 max 1 issue = 24h で max 24 issue (= 週次 30 issue よりも分散)
- **応答速度**: 1 機能変更 → 数時間以内にレビュー (= 週次 7 日待ちなし)
- **リソース効率**: 1 run timeout 15 分 (= GHA actions usage 抑制)
- **1.8 周/日**: 13 機能 / 24 時間 ≈ 1.8 周 → high priority 機能は 1 日 2 回見られる
- **dispatch 緊急 audit**: `force_full_scan=true` で全機能即時 audit 可能

### 2.2 不採用案

- **日次 cron**: ノイズ多すぎ (= weekly が適切)
- **Claude Code Schedule (= claude-mem worker)**: Claude quota 依存 = OPS-28 §6 fallback 違反
- **CI 統合 (= PR ごと)**: 「定期 audit」目的と異なる. PR は別 review GHA がある
- **専用 schedule-hub action**: 既存 EF と独立した方が運用容易 (= EF-CAP-50 への影響もなし)

### 2.3 影響範囲

| ファイル | 変更内容 | territory |
| --- | --- | --- |
| `.github/workflows/feature-review.yml` (新規) | 週次 cron + 実行ステップ | Win or Codex#2 |
| `scripts/feature_review.py` (新規) | レビューロジック + Issue 起票 | Win or Codex#2 |
| `scripts/feature_review_config.json` (新規) | レビュー対象機能列挙 | Win |
| `docs/SCHEDULE_TASKS.md` (更新) | 新 task 説明追加 | Win |
| `.github/labels.yml` or 手動設定 | `auto-review`, `severity:*` ラベル追加 | Codex#2 |

## 3. 受け入れ基準

- [ ] feature-review.yml 毎時 cron 動作 (= 0 分 / 13 機能 round-robin)
- [ ] feature_review.py が UTC 時刻 % 13 で対象機能選択
- [ ] 1 run = 1 機能のみ (= max 1 issue 起票)
- [ ] Playwright + Claude API で findings JSON 生成 (= max 3 findings/run)
- [ ] de-dupe: 既存 open issue (= title hash 一致) を skip
- [ ] new findings → GitHub Issue 起票 (= label 付き)
- [ ] Slack 通知 (= 起票時のみ / SLACK_WEBHOOK_URL)
- [ ] 24h soak: 初日 = 13 機能 1.8 周 = 0-13 件 issue 起票 + 翌日 = de-dupe で 0-3 件
- [ ] docs/SCHEDULE_TASKS.md に新 task 行追加
- [ ] integration_test/feature_review_test.py (= dry-run mode + rotation 検証)
- [ ] workflow_dispatch で `force_full_scan=true` 動作 (= 緊急時全機能即時 audit)
- [ ] flutter analyze / deno lint / 0 エラー

## 4. Routing (= 割り振り)

詳細: [[routing.md]]

| Section | Territory | Status |
| --- | --- | --- |
| `.github/workflows/feature-review.yml` | Codex#2 | ⏳ pending |
| `scripts/feature_review.py` | Codex#2 | ⏳ pending |
| `scripts/feature_review_config.json` | Win | ✅ done (= 本 bundle) |
| `docs/SCHEDULE_TASKS.md` 更新 | Win | ✅ done (= 本 bundle) |
| GitHub label 設定 | Codex#2 | ⏳ pending |
| `integration_test/` | Codex#2 | ⏳ pending |

## 5. 連携軸

| 軸 | 連携 |
| --- | --- |
| **COLLAB_AI #5** Verifier-Generator | feature-review = Verifier (= 既存機能を AI が verify) |
| **OPS-28 改善トリガー** | findings → GitHub Issue = 改善トリガーの自動化 |
| **VIBE_CODING #4** Black-Box I/O Verification | Playwright screenshot = I/O のみ確認 (= コード読まない) |
| **VIBE_CODING #5** Minimal E2E Tests | feature-review が間接的に E2E カバレッジを補完 |
| **PLATFORM #5** High-Res Vision | 2576px screenshot を Claude API に渡す (= future) |
| **MCP_AUTH** | (= GitHub PAT は既存 secret / 新規 auth なし) |

= 6 軸接続. 特に **OPS-28 charter §改善トリガー の自動化** = 軸の運用化.

## 6. 想定される findings カテゴリ

レビューで検出する問題の種類:

1. **UI バグ**: 表示崩れ / テキスト切れ / ボタン重複 / スクロール不具合
2. **a11y 違反**: コントラスト不足 / Semantics 欠落 / focus 順序
3. **未実装 TODO/FIXME**: source の `TODO`, `FIXME`, `XXX` で 30 日以上経過
4. **dead code**: 1 ヶ月以上 import / 参照 0 の関数 / widget
5. **outdated docs**: 機能変更後 docs 未更新 (= 関連 docs の最終更新と乖離)
6. **lint 警告**: flutter analyze の info / warning が累積
7. **performance 候補**: 画像が最適化されていない / 巨大 widget rebuild

= 各 finding に `severity: low/medium/high` ラベル + `feature: <slug>` ラベル付与.

## 7. de-dupe 戦略

```python
# 簡易 hash で重複 issue 検出
def issue_title_hash(finding):
    key = f"{finding['feature']}|{finding['category']}|{finding['summary'][:80]}"
    return hashlib.sha256(key.encode()).hexdigest()[:8]

# title prefix に hash を入れる
# Title 例: "[review:8a3f9c1d] /horse-racing UI コントラスト不足"
```

= 既存 open issue の title prefix が一致なら skip.

## 8. 失敗時 fallback

- Playwright timeout → 該当機能 skip + warning ログ
- Claude API rate limit → exponential backoff + max 3 retry
- GitHub API quota → 翌週まで待機 (= cron 自動再実行)
- 全機能失敗 → Slack alert で人間にエスカレーション

= **graceful degradation** 設計. 1 機能の失敗で全体停止しない.

---

## Implementation Status (2026-04-29 時点)

- ✅ Win territory done: `scripts/feature_review_config.json` + `docs/SCHEDULE_TASKS.md` 更新
- ⏳ Codex#2 territory pending: `.github/workflows/feature-review.yml` + `scripts/feature_review.py` + integration test + label 設定

= **Bundle 第 1 適用例**. cross-instance-pr (= part 70 / 74) と異なり、**Win 部分は本 bundle 内で完結**. Codex#2 は本 bundle 内に commit を追加して完成.

---

*Win版#132 part 77 / 2026-04-29 起票 / Handoff Bundle 第 1 適用例 (= part 76 で形式定義 → 即 dogfood) / OPS-28 改善トリガー自動化 / 機能レビュー schedule task*
