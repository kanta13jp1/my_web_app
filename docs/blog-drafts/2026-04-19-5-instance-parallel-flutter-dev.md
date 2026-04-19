---
title: "Claude Code 5インスタンス並行でFlutter Webを開発する — 役割分担と衝突回避"
tags: ClaudeCode,Flutter,CI/CD,個人開発,buildinpublic
published: false
---

# Claude Code 5インスタンス並行でFlutter Webを開発する

## 5インスタンス体制とは

自分株式会社では Claude Code を5つの環境で同時に動かしている:

| インスタンス | 専任作業 |
|------------|---------|
| **VSCode版** | UI/DESIGN.md 準拠・Rule 12/19 |
| **PowerShell版** | T-1 ブログ投稿・Rule 17 WF管理 |
| **Windowsアプリ版** | AI大学プロバイダー追加・migration・動画編集 |
| **WEB版** | ブログ研究・競合モニタリング (CLI不可) |
| **📱 スマホ版** | 実機UAT・モバイル不具合トリアージ |

同じ Flutter プロジェクトを5つの AI エージェントが同時に触る。
衝突しないためのルールを整理する。

## 衝突パターンと対策

### 1. 同じファイルへの同時書き込み

```bash
# 問題: VSCode版とPS版が同時に ROADMAP を更新
VSCode: git add docs/GROWTH_STRATEGY_ROADMAP.md && git push  
PS:     git add docs/GROWTH_STRATEGY_ROADMAP.md && git push  # → rejected!
```

**対策**: push 前に必ず fetch + rebase:

```bash
git fetch origin main && git log HEAD..origin/main --oneline
# 並行 commit があれば rebase で吸収
git pull --rebase origin main
```

ROADMAP の衝突は merge conflict になりやすい。
各インスタンスが末尾に `### InX版#N` セクションを **追記** する形式なら
rebase で自動解決できる場合が多い。

### 2. cancel-in-progress による deploy 消失

5インスタンスが30秒以内に連続 push するとデプロイキューが詰まる。

```yaml
# ❌ cancel-in-progress: true だと後発が前発をキャンセル
concurrency:
  group: deploy-production
  cancel-in-progress: true  # 後発 push で前発の deploy が死ぬ
```

```yaml
# ✅ cancel-in-progress: false で全 commit を順次 deploy
concurrency:
  group: deploy-production
  cancel-in-progress: false  # 最大 11min × N 待機するが全て反映
```

5インスタンス並行時代は `cancel-in-progress: false` が必須。

### 3. 役割専任制による範囲分離

衝突を防ぐ最良の方法は「誰が何を触るか」を決めること:

```text
lib/pages/**        → VSCode版 (UI 専任)
supabase/functions/ → Windowsアプリ版 (EF 専任)
docs/blog-drafts/   → PS版 (ブログ専任)
.github/workflows/  → PS版 (WF 専任)
supabase/migrations/ → Windowsアプリ版 (migration 専任)
```

### 4. cross-instance-prs で越境依頼

専任外の作業が必要な場合は cross-instance-pr を作成する:

```markdown
# docs/cross-instance-prs/20260419_dart_format_fix.md
---
from: PS版
to: VSCode版
---
## 依頼: flutter analyze 修正
philosophy_page.dart に dart:ui_web 問題。
VSCode版でコンテキストが揃ったら修正をお願いします。
```

完了したら `docs/cross-instance-prs/done/` に移動。

## 実際の1日のタイムライン

```
06:00 JST  Win版: AI大学プロバイダー追加 migration push
06:05      PS版: blog-dispatch × 3本 (blog-publish.yml)
06:30      VSCode版: UI DESIGN.md 違反修正 push
06:31      PS版: rebase で Win版 commit を吸収 → push OK
07:00      WEB版: 競合モニタリング → cross-instance-pr 作成
09:00      📱スマホ版: 実機 iPhone で新 UI 検証 → Issue 作成
```

5インスタンスが独立した役割を持ちながら、同じ `main` ブランチに push し続ける。

## 効果

| 指標 | 1インスタンス | 5インスタンス |
|-----|-------------|-------------|
| T-1 ブログ記事/日 | 2-3本 | 12本 (本日記録) |
| UI 修正/日 | 2-3ページ | 5-10ページ |
| AI大学プロバイダー追加/日 | 2-3社 | 5-8社 |
| deploy 成功率 | ~95% | ~90% (衝突リスク増) |

トークン消費も5倍になるが、$20/月プランで月$200相当の作業が実現できる。

## まとめ

- **専任制**: 誰が何を触るかを決める
- **cross-instance-prs**: 越境作業の依頼チャンネル
- **cancel-in-progress: false**: 並行 push でも全 commit を反映
- **rebase**: push 前に必ず fetch → 衝突を事前に解決

個人開発でも CI/CD の設計で「チーム開発的な並行性」を実現できる。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#ClaudeCode #Flutter #CI/CD #buildinpublic #個人開発
