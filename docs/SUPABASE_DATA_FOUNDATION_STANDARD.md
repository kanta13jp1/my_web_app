# AIエージェント向け Supabase データ基盤標準化・技術的負債解消基準 (#4131)

## 1. スキーマ正規化と棚卸し (`scripts/audit_supabase_rls_and_schema.py`)

`supabase/migrations/*.sql`（2,000 ファイル超）に散在するテーブル定義と Row Level Security (RLS) 適用状況を決定論的に棚卸しする。

- すべての新規 `CREATE TABLE` には同一マイグレーション内で `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` および最小権限の `CREATE POLICY` を必ず付与する。
- `python -B scripts/audit_supabase_rls_and_schema.py --markdown` により、RLS 未設定・ポリシー未設定テーブルを定量把握する。

## 2. エージェント可読な標準化 API エンベロープ規約

Edge Functions (`supabase/functions/*`) が AI エージェントおよび Flutter クライアントへ返却する JSON レスポンスは、以下の標準エンベロープに統一する。

```json
{
  "success": true,
  "data": {},
  "error": null,
  "meta": {
    "schemaVersion": "1.0",
    "generatedAt": "2026-11-26T00:00:00Z"
  }
}
```

## 3. 段階的マイグレーションガードレール

稼働中の Flutter Web アプリの破壊を防ぐため、スキーマ変更時は [DUAL_WRITE_TRANSITION_STANDARD.md](./DUAL_WRITE_TRANSITION_STANDARD.md) に従い **追加先行 → デュアルライト → バックフィル検証 → 旧列削除** の 4 段階を厳守する。

## 4. 外部参照に関する注記

- Issue 起票元メモに含まれる外部レポート（KPMG テックレポートの具体的数値・主張）は、本環境から一次原文を直接取得できていないため **未確認** として扱う。
