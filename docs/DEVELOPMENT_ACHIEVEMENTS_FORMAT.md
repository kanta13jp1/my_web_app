# 開発実績の記録方法 + migration 命名規則

> Win版#132 part 133 (2026-05-05): 旧 CLAUDE.md L449-462 を移行 (= Karpathy 80 行 KPI 達成).

## 開発実績の記録

新しい機能を実装したら **必ず** `supabase/migrations/` に seed ファイルを作成:

```sql
-- Session XX: 実装内容の概要
INSERT INTO development_achievements (title, description, completed_at)
VALUES ('タイトル', '詳細説明', 'YYYY-MM-DD')
ON CONFLICT DO NOTHING;
```

### 用途

- フロントエンドの development_achievements ページ (= 開発実績一覧 / `/admin-analytics` などで参照) が反映
- セッション間で「何を実装したか」が可視化される (= 失われない L2 記憶層)

## マイグレーションファイルの命名規則

```
YYYYMMDDXXXXXX_descriptive_name.sql
```

例:
- `20260326000010_seed_achievements_session20.sql`
- `20260504010000_seed_achievements_ps3_s153_blog.sql`
- `20260504003000_seed_achievements_ps6_s165.sql`

### ルール

- `YYYYMMDD` = 作成日 (= UTC でも JST でも揃っていれば可 / instance 別に間隔を空けるのが慣習)
- `XXXXXX` = HHMMSS 形式の 6 桁時刻 (= 並列 instance 衝突回避のため秒精度推奨)
- `descriptive_name` = ケバブケース or アンダースコア区切り (= 例: `seed_achievements_<instance>_<session>`)

### 衝突回避

複数 instance が同時間帯に migration を作る場合:
- 秒精度を活用 (= `20260504010000` vs `20260504010030` で 30 秒差)
- collision detected (= part 47 detector) → rename + WIP commit
- CI Check で `migration timestamp collision` warning が出たら即修正

## 関連

- [`docs/DIRECTORY_STRUCTURE.md`](DIRECTORY_STRUCTURE.md) — リポジトリ構成
- [`docs/EDGE_FUNCTION_LIST.md`](EDGE_FUNCTION_LIST.md) — EF 一覧
- [`CLAUDE.md`](../CLAUDE.md) — pointer hub
