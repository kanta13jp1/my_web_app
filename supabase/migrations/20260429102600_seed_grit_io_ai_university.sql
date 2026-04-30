-- PS#3 S126: AI大学 347→348社化 — Grit.io (コード移行・アップグレード自動化 / AI主導リファクタリング)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'grit-io', 'overview',
  'Grit.io — コード移行・ライブラリアップグレード自動化・AI主導リファクタリング・大規模コードベース対応 (9/9)',
  $$## Grit.io とは

**Grit.io** は**コードの移行・アップグレード・リファクタリングを自動化する AI ツール**。ライブラリのバージョンアップ・API 変更への対応・フレームワーク移行など、**大規模で反復的なコード変更**を AI が自動的に処理する。

従来は人間が数週間かけて行うような「React 16 → React 18 移行」「webpack → Vite 移行」などを**数時間〜1日で自動化**できる。

## Grit.io の特化領域

```
Grit.io が得意な移行・アップグレード:

  フレームワーク移行:
    ・React Class Components → Function Components + Hooks
    ・Vue 2 → Vue 3 (Composition API)
    ・Angular 12 → 14+
    ・Express → Fastify

  ビルドツール移行:
    ・webpack → Vite
    ・Babel → SWC
    ・Jest → Vitest

  ライブラリアップグレード:
    ・lodash → ES2023 native (map/filter/reduce)
    ・moment.js → date-fns / dayjs
    ・request → node-fetch / axios
    ・enzyme → React Testing Library

  コードスタイル統一:
    ・callback → Promise → async/await
    ・var → const/let
    ・CommonJS → ESM
    ・JavaScript → TypeScript 移行
```

## GritQL — 移行ルール定義言語

Grit.io の核心は **GritQL** という専用クエリ言語:

```gritql
# lodash の _.map を Array.prototype.map に変換
`_.map($arr, $fn)` => `$arr.map($fn)`

# callback パターンを async/await に変換
`$fn($args, function($err, $result) { $body })` =>
`const $result = await $fn($args); $body`
```

- **再現可能**: 同じルールで何度でも実行可能
- **共有可能**: チーム・コミュニティでルールを共有
- **テスト可能**: ルールの単体テストを書ける

## 料金体系

| プラン | 月額 | 特徴 |
|--------|------|------|
| Free | $0 | OSS + 基本ルール |
| Pro | $24/人 | カスタムルール + Private repo |
| Enterprise | 要問い合わせ | 大規模移行サポート + SLA |

## 実績と使用例

- **Shopify**: React 移行に活用
- **Stripe**: API バージョンアップに活用
- **コードベース 10 万行以上** の移行も対応

## Devin / SWE-agent との違い

| 観点 | Grit.io | Devin / SWE-agent |
|------|---------|-------------------|
| 得意タスク | 移行・アップグレード | 汎用タスク |
| 規模 | 大規模コードベース | 中小規模 |
| 再現性 | GritQL でルール化 | 非確定的 |
| 自律性 | ルールベース | LLM 自律 |

## 自分株式会社との関連

Grit.io のアプローチ（GritQL でコード変換ルールを定義）は、自分株式会社の Codex インスタンスが担う「横断的リファクタリング」タスクの参考になる。特に Flutter / Dart のバージョンアップや Supabase クライアント API 変更対応に適用できる概念。
$$,
  'https://grit.io',
  NOW(),
  348
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
