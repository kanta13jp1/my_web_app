# Prompt Caching × Claude Opus 4.7 — コスト最適化ガイド

> **作成**: 2026-05-07 Win版#132 part 177 (Issue #1756 / NotebookLM `bc58b50b` 推奨 #14)
>
> **目的**: 1M context Opus 4.7 を月 $20 プランで安全運用するためのキャッシュ戦略集。
> CLAUDE.md ハブ + 各 docs を「キャッシュ可能な安定 block」として設計し、
> 通常読み込み比 ~90% コスト削減を狙う。
>
> **対象**: Win Claude / Win Codex / Codex CLI / Anthropic SDK / Claude Agent SDK 利用 instance 全部。

---

## 1. なぜ Prompt Caching が必須か

### 1.1 Opus 4.7 1M context 価格 (2026-05 時点)

| 項目 | 通常 input | cache write | cache read | output |
| --- | --- | --- | --- | --- |
| ≤200K context | $3.00 / Mtok | $3.75 / Mtok | $0.30 / Mtok | $15.00 / Mtok |
| >200K context (1M tier) | $6.25 / Mtok | $7.81 / Mtok | $0.625 / Mtok | $22.50 / Mtok |

**重要**:
- 1M tier は ≤200K の **2 倍** 課金。
- cache read = 通常 input の **10%**。
- cache write = 通常 input の **125%** (= 初回のみ余分に払う)。
- 2 ターン以上 hit すれば元が取れる(= break-even は 1 hit で達成)。

### 1.2 ナイーブ運用との比較

> 1M context フルロード × 50 ターン/日 (= 開発 1 セッション)

- **キャッシュなし**: 50 × $6.25 = **$312.50 / day**
- **5min cache 維持**: $7.81 (初回 write) + 49 × $0.625 = **$38.43 / day** (= 88% 削減)
- **1h cache 維持**: $12.50 (初回 write / +60%) + 49 × $0.625 = **$43.13 / day**

(注) 1h cache = 5min cache の 2 倍 write 単価 / 12 倍 TTL。長時間休憩を挟む session で有利。

### 1.3 当社 fleet での試算

- 2 instance 並列 (= Win Claude + Win Codex) × 各 50 turn × 月 25 日 = **2,500 turn / 月**
- 通常運用: 2,500 × $6.25 = **$15,625 / 月** (= 月 $20 プラン全壊滅)
- キャッシュ運用: ~ $1,900 / 月 (= 88% 削減 / プラン内収まる)

---

## 2. キャッシュ tier の選び分け

| tier | TTL | write 単価 (1M) | read 単価 (1M) | 使うべき場面 |
| --- | --- | --- | --- | --- |
| **5-min ephemeral** | 5 分 | $7.81 / Mtok | $0.625 / Mtok | 通常開発 / 連続ターン (= デフォルト) |
| **1-hour** | 1 時間 | $12.50 / Mtok | $0.625 / Mtok | 中断挟む長時間 session / wrap-up + resume |
| **未指定** | なし | (= 通常 input) | (= 通常 input) | 単発 query / one-shot |

### 2.1 break-even 計算式 (= 何ターン hit すれば元が取れるか)

```
break_even_hits = (write_cost - read_cost) / read_cost
              = ($7.81 - $0.625) / $0.625
              = 11.5
```

> **誤解注意**: break-even = 通常 input より安くなる hit 回数 = **1 hit** (= write は cache 経由 + 通常 input より少しだけ高い 25% 上乗せのみ)。
> 上の `11.5` は「通常 read を tier 0 として比較した完全相殺点」。

簡略則:
- **1 hit 以上で必ず黒字**。
- **5 hits で 80% 削減**。
- **20 hits で 90%+ 削減**。

---

## 3. CLAUDE.md / context 構造設計

### 3.1 cache breakpoint = 「stable / unstable 境界」

Anthropic API は最大 **4 個** の `cache_control` breakpoint を持てる(`type: "ephemeral"` または `"1h"`)。
context を以下の 4 ブロックに切り分ける:

```
┌─────────────────────────────────────────────┐
│ Block 1: tool 定義 (= stable / 月 1 変更)   │ ← cache breakpoint #1 (1h)
├─────────────────────────────────────────────┤
│ Block 2: system prompt 本体 (= 週 1 変更)   │ ← cache breakpoint #2 (1h)
├─────────────────────────────────────────────┤
│ Block 3: CLAUDE.md + docs hub (= 日次)      │ ← cache breakpoint #3 (5min)
├─────────────────────────────────────────────┤
│ Block 4: 直近 N ターン user/assistant       │ ← cache breakpoint #4 (5min)
├─────────────────────────────────────────────┤
│ (current turn / 動的 / 非 cache)             │
└─────────────────────────────────────────────┘
```

### 3.2 当社 CLAUDE.md (= part 132 で 80 行 KPI 達成 / pointer hub) の cache 適性

- **cache 友好**: 80 行 / 12 軸 docs link / **stable** = 完璧 cache 候補。
- **改善必要**: docs hub の各 `docs/*.md` (= 12 軸) はそれ自体が大型(各 200-500 行)。
  - **対策**: 「session で実際に読んだ docs」のみ context 注入 (= 全 12 docs 同時注入は浪費)。
  - Karpathy Compile cycle (= `scripts/wiki_compile.py`) が `docs/concepts/` を自動生成 → cache 可。

### 3.3 timestamp / 動的要素の扱い

**NG**: CLAUDE.md 冒頭に `> 最終更新: 2026-05-07 14:32` を毎ターン更新

**OK**: timestamp を末尾 1 行に分離 / または別ファイル `MEMORY.md` 末尾に集約

**理由**: cache breakpoint 直前の任意 1 文字変更で **breakpoint 以降全部 invalidated**。

### 3.4 tool 定義の安定化

```typescript
// NG: 毎ターン tool 順序変動
tools: shuffleArray([Bash, Read, Edit, Write, ...])

// OK: alphabetical sort + stable
tools: [Bash, Edit, Glob, Grep, Read, Write].sort(byName)
```

---

## 4. Session lifecycle 別 戦略

### 4.1 Cold start (= 新規 session)

1. CLAUDE.md + docs hub 読み込み = **cache write** (= $7.81 / Mtok 1M tier)
2. 初回 turn から `cache_control: ephemeral` 付与
3. 5min 以内に 2 ターン目開始 → **cache hit** ($0.625 / Mtok)

### 4.2 Hot session (= 連続開発)

- 各 turn 5min 以内なら自動 cache hit。
- > 5min idle → cache 失効 → 再 write 発生。
- **対策**: 長時間 idle 前に明示的 wrap-up + new session が安全 ([COMPACTION-RESUME] 90min 以内 wrap-up と整合)。

### 4.3 Long session (= 1h+ 連続作業)

- **5min cache** だと idle 毎に再 write → トータル割高化。
- **1h cache** に切り替え (= write +60% / TTL 12 倍)。
- Anthropic SDK で `extended-cache-ttl-2025-04-11` beta header + `cache_control: {"type": "ephemeral", "ttl": "1h"}`。

### 4.4 Compaction / wrap-up 後 resume

- compaction = context 再構築 → 必ず cache miss。
- wrap-up 直後に 1h cache を仕込んでも、再 hit は 1h 以内 resume が前提。
- 推奨: wrap-up = 完全終了 / 翌日は cold start で新規 session。

---

## 5. Anti-patterns (= cache 破壊)

| パターン | 影響 | 対策 |
| --- | --- | --- |
| CLAUDE.md 冒頭に動的 timestamp | breakpoint #2 全 invalidated | timestamp を別ファイル末尾へ |
| tool 定義の random shuffle | breakpoint #1 全 invalidated | sort 安定化 |
| 毎ターン inject-rules.txt 内容変更 | breakpoint #2 全 invalidated | rule 追加は週次 batch |
| docs/*.md の inline edit + 同 turn 参照 | breakpoint #3 invalidated | edit と参照を別 session に分割 |
| memory file YYYYMMDD 注入 | breakpoint #4 invalidated | date は user message のみ |

---

## 6. Karpathy 4 サイクルとの統合

| サイクル | cache 対象 | tier 推奨 |
| --- | --- | --- |
| **Ingest** (`memory_ingest.py`) | 入力 raw / 一過性 | **キャッシュ不要** (= 1 回 write のみ) |
| **Compile** (`wiki_compile.py`) | `docs/concepts/` + `docs/INDEX.md` | **1h cache** (= 月数回参照) |
| **Query** (`notebooklm`) | NotebookLM 別 API | **対象外** (= Anthropic API 経由しない) |
| **Lint** (`knowledge_vault_lint.py`) | vault hash | **キャッシュ不要** |

**メリット**: Compile cycle が出す `docs/concepts/` は安定 → 月 1 程度の write で済む = cache write 償却 OK。

---

## 7. NotebookLM / Master Brain 連携

NotebookLM は **別 API** (= Google) で Anthropic prompt caching 対象外。
**ゼロトークンリサーチ** (= NotebookLM CLI) 利用が最強コスト削減策(= Anthropic API call そのものを発生させない)。

`docs/NOTEBOOKLM_GUIDE.md` 参照。

優先順:
1. NotebookLM Query で済むなら NotebookLM (= **$0** / Anthropic 非経由)
2. Anthropic 必要なら **必ず cache** 経由
3. cache 不可な動的 query は **Sonnet 4.6 / Haiku 4.5** に降格

---

## 8. Anthropic SDK 実装例 (= Python)

```python
import anthropic

client = anthropic.Anthropic()

# 5-min ephemeral (= 通常開発)
response = client.messages.create(
    model="claude-opus-4-7",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": load("docs/CLAUDE.md") + load("docs/PHILOSOPHY.md"),
            "cache_control": {"type": "ephemeral"}
        }
    ],
    messages=conversation_history,
)

# 1-hour cache (= 中断あり long session)
response = client.messages.create(
    model="claude-opus-4-7",
    max_tokens=1024,
    extra_headers={"anthropic-beta": "extended-cache-ttl-2025-04-11"},
    system=[
        {
            "type": "text",
            "text": stable_context,
            "cache_control": {"type": "ephemeral", "ttl": "1h"}
        }
    ],
    messages=conversation_history,
)

# usage 監視
print(f"cache_write: {response.usage.cache_creation_input_tokens}")
print(f"cache_read:  {response.usage.cache_read_input_tokens}")
print(f"input:       {response.usage.input_tokens}")
print(f"output:      {response.usage.output_tokens}")
```

---

## 9. KPI 監視 (= GHA cron 候補)

### 9.1 計測指標

- **cache hit rate** = `cache_read / (cache_read + cache_creation + input)` ≥ **70%** target
- **avg cost / turn** ≤ **$0.50** (1M tier)
- **monthly Anthropic spend** ≤ **$200** (= プラン上限内)

### 9.2 実装案 (= 既存 GHA cron 流用)

`.github/workflows/quota-monitor.yml` に拡張案:

```yaml
- name: Cache hit rate audit
  run: |
    python scripts/cache_hit_audit.py \
      --window 7d \
      --threshold 0.70 \
      --alert-slack
```

(注) 実装は別 Issue として切り出し可。本 spec では設計のみ。

---

## 10. 実装 Checklist

### 10.1 一次対応 (= part 177 で完了)

- [x] `docs/PROMPT_CACHING_OPUS47_COST_GUIDE.md` 起票 (= 本ファイル)
- [x] `CLAUDE.md` に 1 行 pointer 追加
- [x] `docs/DEV_PROCESS_MULTI_AI.md` に「コスト管理」セクション pointer 追加

### 10.2 二次対応 (= 将来 Issue 候補)

- [ ] `scripts/cache_hit_audit.py` 実装 (= Anthropic usage API 経由)
- [ ] GHA cron に cache hit rate alert 追加
- [ ] `docs/CLAUDE_CODE_MASTERCLASS_AGENTIC_WORKFLOW.md` への cache 章 追記
- [ ] CLAUDE.md 冒頭の `> Win版#132 part XXX` を別ファイル化 (= cache 破壊源)

### 10.3 運用ルール (= 全 instance 共通)

- [ ] CLAUDE.md / docs/*.md 編集後の **同 session 内** 参照は避ける
- [ ] timestamp / session# / part# を **末尾 + 別ファイル** に隔離
- [ ] memory/MEMORY.md は **read-only / 週 1 batch update**

---

## 11. References

- [Anthropic Prompt Caching docs](https://docs.claude.com/en/docs/build-with-claude/prompt-caching)
- [Anthropic Pricing](https://www.anthropic.com/pricing)
- [`docs/CLAUDE_CODE_MASTERCLASS_AGENTIC_WORKFLOW.md`](CLAUDE_CODE_MASTERCLASS_AGENTIC_WORKFLOW.md)
- [`docs/AI_FALLBACK_RUNBOOK.md`](AI_FALLBACK_RUNBOOK.md) (= quota 超過時 fallback)
- [`docs/NOTEBOOKLM_GUIDE.md`](NOTEBOOKLM_GUIDE.md) (= ゼロトークンリサーチ)
- [`docs/SECOND_BRAIN_PRINCIPLES.md`](SECOND_BRAIN_PRINCIPLES.md) (= Karpathy 4 サイクル)
- Issue [#1756](https://github.com/kanta13jp1/my-web-app/issues/1756) (= 親 Issue)

---

## 12. Philosophy Alignment (= 12 軸 principle 整合)

- **PHILOSOPHY**: 「資本=時間」 — cache 88% 削減 = 月 $13K 浮き = 13K 時間の future budget
- **AI-DEV**: deny-by-default — cache_control を明示的に付与する設計を default にせず、必要時のみ
- **VIBE-CODING**: cost transparency — usage 監視を CI に組み込み、AI 開発の隠れコストを可視化
- **PLATFORM-EVOLUTION**: cache 戦略は「設計判断」レベル / 機能追加ではない / 月次レビュー
- **INDIE-VELOCITY**: cost ceiling 設定で「個人開発で Opus 4.7 を回す」現実解
