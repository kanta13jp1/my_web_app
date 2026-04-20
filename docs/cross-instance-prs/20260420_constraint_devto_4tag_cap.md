# 制約周知: dev.to 4-tag cap silent truncation (PS#2 S14 発見)

- **From**: PS版#2 (T-1 dispatch 専任)
- **To**: 全 draft 執筆 instance (VSCode / Win / PS#3 / PS#4 / Web / Mobile / 他)
- **Priority**: MEDIUM (新規 draft 執筆時は必読)
- **Date**: 2026-04-20 20:30 JST
- **Commit (並び替え実装)**: `976eaf92`

---

## 発見した制約

`supabase/functions/schedule-hub/index.ts:303`:

```typescript
const cleanTags = rawTags.slice(0, 4).map((t: string) =>
  t.toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 30)
).filter((t: string) => t.length > 0);
```

- dev.to は **最初 4 個のタグのみ送信** (5 番目以降は silent に drop)
- 警告 log ゼロ・CI fail ゼロ → **draft 側で気付けない沈黙バグ扱い**
- Qiita 側は別制限 (未調査だがこの EF では Qiita にも同 slice が適用される可能性あり → 要確認)

## 影響範囲 (S14 時点の全 5 EN drafts)

| Draft | 元タグ順 | 5 番目 drop 内容 | 対応 |
| --- | --- | --- | --- |
| `2026-04-24-*-three-way-positioning-sns-en.md` | `AI,Claude,OpenAI,buildinpublic,webdev` | `webdev` (汎用 · 許容) | 放置 OK |
| `2026-04-26-*-ai-vendor-dependency-portfolio-bs-framework-en.md` | `AI,Claude,OpenAI,buildinpublic,webdev` | `webdev` (汎用 · 許容) | 放置 OK |
| `2026-04-28-notion-custom-agents-paywall-vs-free-6-departments-en.md` | `Notion,AI,buildinpublic,webdev,SaaS` | **`SaaS`** (specific · 失うと痛い) | 並び替え済 |
| `2026-05-02-notion-paywall-d2-parallel-6-departments-en.md` | 同上 | 同上 | 並び替え済 |
| `2026-05-04-notion-paywall-d0-alternative-6-departments-en.md` | 同上 | 同上 | 並び替え済 |

## 新 draft 執筆ルール (提案)

frontmatter `tags:` を **価値降順** で 4 個目までに詰める:

```
最具体 (製品名 Notion/Claude/OpenAI) > 技術カテゴリ (AI) > 業界 (SaaS) > 運動 (buildinpublic) > 汎用 (webdev)
```

- 4 個で収める: 5 個目は silent drop されるので最初から削ってよい
- 5 個書く場合: 4 個目までに価値タグを寄せる (webdev / programming のような汎用は 5 個目 OK)

## 対策候補 (将来の S15+ 検討用 · 今回は未実装)

- (A) `schedule-hub/index.ts:303` に `console.warn(`tag truncated: ${rawTags.slice(4).join(",")}`)` 追加 → silent → explicit 化 / EF deploy コスト
- (B) `blog-publish.yml` 側で **5 tags 検出 → warn output** で CI 時点で気付ける化 / workflow edit コスト
- (C) `.claude/skills/t1-blog-dispatch/SKILL.md` の Step 2 frontmatter 確認に tag 数 echo 追加 / skill edit のみで低コスト

→ 今回は (C) を PS#2 次セッションで検討 (最小コスト · PS#2 scope 内)

## 関連 commit / memory

- Commit: `976eaf92 — docs: PS版#2 S14 — dev.to 4-tag cap hygiene`
- Memory: `memory/project_20260420_ps2_s14.md`
- ROADMAP: Session 14 block (docs/GROWTH_STRATEGY_ROADMAP.md 末尾)

## Qiita 側について (解決 — PS#2 S15 2026-04-20 20:45)

`schedule-hub/index.ts:270` で Qiita path は **`rawTags.slice(0, 5)`** を使用 = 5 tags 全て送信される。
Qiita 側は dev.to と独立の slice 実装のため、**JA drafts の 5 tags は問題なし**。
dev.to (line 303 = `slice(0, 4)`) のみ 4-cap truncation の影響を受ける。

→ 結論: **EN drafts (dev.to 送信) のみ タグ 4 個以内 or 価値降順 sort 必要**。
JA drafts (Qiita 送信) は 5 tags まで自由。

## S15 追加実装 (2026-04-20 20:45)

`.claude/skills/t1-blog-dispatch/SKILL.md` に **Step 2.1: dev.to 4-tag cap pre-check** 新設。
dispatch 前に JA+EN 両 draft のタグ数を echo し、5+ で specific タグが 5 番目なら並び替え要求。
