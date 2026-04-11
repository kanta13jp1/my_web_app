---
name: ai-university-add-provider
description: |
  Evaluates and adds new AI providers to the AI大学 (AI University) feature of 自分株式会社.
  Use this skill whenever the user wants to:
  - Find which new AI providers should be added to AI大学 (discovery mode)
  - Add a specific AI provider to AI大学 (add mode)
  - Keep AI大学 provider list up to date with the latest AI landscape
  - Run the periodic "Step 0" provider evaluation from the CLAUDE.md ai-university-update task

  Triggers on: "/ai-university-add-provider", "AI大学にプロバイダーを追加", "新しいAIプロバイダーを評価", "which AI providers should we add", "add [provider] to AI大学", "Step 0" provider check.

  Two modes:
  - Discovery (no arg): WebSearch → evaluate candidates → recommend top 1-2
  - Add (provider name as arg): research → SQL migration → yml update → CLAUDE.md update → commit
---

# AI大学 プロバイダー追加スキル

このスキルは自分株式会社の AI大学機能に新しい AI プロバイダーを追加します。
**発見モード**と**追加モード**の2つで動作します。

## プロジェクトパス

```
C:\Users\kanta\GitHub\my_web_app\
├── CLAUDE.md                                          ← 「現在の登録プロバイダー」リストを更新
├── .github/
│   ├── COMPRESSED_PROMPT_V3.md                       ← 同リストを更新
│   └── workflows/ai-university-update.yml            ← upsert_provider 行を追加
└── supabase/migrations/
    └── YYYYMMDDXXXXXX_seed_{provider}_ai_university.sql  ← 新規作成
```

---

## モード判定

- 引数なし → **発見モード**
- 引数あり (例: `mistral`, `cohere`) → **追加モード**

---

## 発見モード (Discovery Mode)

### Step 1: 登録済みプロバイダーを確認

`CLAUDE.md` の「現在の登録プロバイダー」セクションを読む。
現在の登録: google, openai, anthropic, microsoft, meta, x, deepseek (随時変わる)

### Step 2: 新興AIプロバイダーを WebSearch で調査

以下のクエリで検索:
- `"new AI model provider API release 2026"`
- `"AI startup foundation model launch 2026"`
- `"best AI APIs developers 2026"`

### Step 3: 3軸評価

各候補を以下の基準でスコアリング (各軸 0〜3点):

| 軸 | 追加する (高スコア) | 見送る (低スコア) |
| --- | --- | --- |
| **技術革新性** | 新アーキテクチャ・SOTA達成・ユニークな能力 | 既存モデルの軽微な改訂のみ |
| **API可用性** | 公開 API あり・広く利用可能 | クローズドβのみ・招待制 |
| **話題性** | 直近2週間でSNS/主要ニュースに多数言及 | マイナーな言及のみ |

合計スコア 6点以上を推奨候補とする。

### Step 4: 推奨レポートを出力

```
## AI大学 新規プロバイダー候補 (YYYY-MM-DD)

### 推奨: [プロバイダー名]
- 技術革新性 (X/3): [理由]
- API可用性 (X/3): [API URL]
- 話題性 (X/3): [根拠となるソース]
合計: X/9

### 次点: [プロバイダー名]
...

### 見送り
- [名前]: [理由]
```

追加を実行する場合は「追加モード」で `/ai-university-add-provider [provider-id]` を実行するよう案内する。

---

## 追加モード (Add Mode)

引数として受け取ったプロバイダー ID (例: `mistral`, `cohere`, `perplexity`) を追加する。

### Step 1: プロバイダーを調査

WebSearch で以下を検索:
- `"[provider] AI latest models 2026"`
- `"[provider] API pricing documentation"`
- `"[provider] official blog"`

公式サイト・APIドキュメント・料金ページのURLを確認する。

### Step 2: SQL migration ファイルを作成

**ファイル名**: `supabase/migrations/[YYYYMMDDHHmmss]_seed_[provider]_ai_university.sql`
- タイムスタンプは `date +%Y%m%d%H%M%S` または現在時刻で生成

**必須要件**:
- 3レコード: `overview`, `models`, `api` カテゴリ
- コンテンツは**日本語で記述**
- `$$...$$` ドル引用でMarkdown本文を囲む
- 末尾に `ON CONFLICT DO NOTHING`
- `sort_order`: overview=1, models=2, api=3

**SQL テンプレート**:

```sql
-- [ProviderDisplayName] 初期コンテンツシード (YYYY-MM-DD)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('[provider-id]', 'overview', '[ProviderDisplayName] 概要',
$$[概要のMarkdown。以下を含む:]
- 企業・モデルの背景 (2〜3段落)
- ## 主要サービス セクション (箇条書き)
- ## 強み セクション (箇条書き)$$,
'[公式URL]', 'YYYY-MM-DD', 1),

('[provider-id]', 'models', '[ProviderDisplayName] モデル一覧 (YYYY)',
$$[モデル一覧のMarkdown。以下を含む:]
## [主要モデルシリーズ名]

| モデル | コンテキスト | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **[モデル名]** | [値] | [特徴] | [用途] |

## 特徴的な機能
- [機能1]
- [機能2]$$,
'[モデルドキュメントURL]', 'YYYY-MM-DD', 2),

('[provider-id]', 'api', '[ProviderDisplayName] API 入門',
$$[APIのMarkdown。以下を含む:]
## [ProviderDisplayName] API の始め方

```python
# Python のコードスニペット (実際の公式APIコード)
```

## 料金 (YYYY年M月時点)
- **[モデル名]**: $X.XX / 100万入力token$$,
'[APIドキュメントURL]', 'YYYY-MM-DD', 3)

ON CONFLICT DO NOTHING;
```

### Step 3: ai-university-update.yml を更新

`.github/workflows/ai-university-update.yml` の `upsert_provider` 呼び出しブロックに1行追加:

```bash
upsert_provider "[provider-id]"  "[RSS-URL または公式ブログURL/rss]"  "[Display Name]"
```

既存の行の直後、コメント行 `# 新規プロバイダーを追加する場合はここに` の**前**に追加する。

RSSが存在しない場合は公式ブログURLにフォールバック（URLが無効でも `upsert_provider` はエラーメッセージをセットするだけで処理継続する）。

### Step 4: CLAUDE.md の登録プロバイダーリストを更新

`CLAUDE.md` の以下のセクションを探して更新:

```
#### 現在の登録プロバイダー

\```text
google, openai, anthropic, microsoft, meta, x, deepseek
\```
```

末尾に `, [provider-id]` を追記する。

### Step 5: COMPRESSED_PROMPT_V3.md を更新

`.github/COMPRESSED_PROMPT_V3.md` の `#T3` セクション内「現在の登録プロバイダー」を同様に更新。

### Step 6: markdownlint で確認

```bash
cd [project-root]
npx markdownlint-cli --dot "CLAUDE.md" ".github/COMPRESSED_PROMPT_V3.md"
```

エラーがあれば修正してからコミットする。

### Step 7: git commit

```bash
git add supabase/migrations/[新ファイル] CLAUDE.md .github/COMPRESSED_PROMPT_V3.md .github/workflows/ai-university-update.yml
git commit -m "feat: AI大学 [ProviderDisplayName] プロバイダー追加"
git push origin main
```

### Step 8: 完了報告

```
✅ [ProviderDisplayName] を AI大学に追加しました

- migration: supabase/migrations/[ファイル名]
- 登録プロバイダー数: [旧数] → [新数]
- 週次自動更新: ai-university-update.yml に追加済み
- commit: [hash]

次回 /ai-university-add-provider で別のプロバイダーを評価できます。
```

---

## 制約・注意事項

- **SQLコンテンツは日本語**で書く（英語NG）
- **ON CONFLICT DO NOTHING** を必ず末尾に記載
- プロバイダー数は CLAUDE.md から動的に読み取る（ハードコードしない）
- markdownlint が通らなければコミットしない
- provider-id はすべて小文字・英数字・ハイフンのみ (`mistral`, `cohere`, `amazon-nova` 等)
- 公式APIが存在しないサービス（クローズドβ等）は発見モードで「見送り」と判定し追加しない
