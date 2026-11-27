# ゼロダウンタイム移行に向けた 14 日間デュアルライト標準プロセス

対象: Issue #2774。
本書は、スキーマやデータ構造の破壊的変更をダウンタイムなしで実施するための標準手順です。
既存のデプロイ手順（[`RELEASE_CHECKLIST_ROLLBACK.md`](./RELEASE_CHECKLIST_ROLLBACK.md)）と補完関係にあり、
既存マイグレーション履歴や本番 DB を直接変更するものではありません。

---

## 1. 目的と適用対象

Flutter Web / モバイルアプリでは、新バージョンのビルド配信後も旧クライアント（キャッシュ済み Web タブや
ストア審査待ち・未更新端末）が一定期間並行稼働します。旧構造を即座に削除・改変すると障害の原因になるため、
データ構造の互換性を壊す変更では **14 日間のデュアルライト（二重書き込み）期間** を必須とします。

適用対象となる変更例:

- テーブルのカラム名変更・型変更・別テーブルへの分離または統合
- `hub_data.metadata` 等 JSONB ペイロードの必須キー構造変更
- Edge Function のリクエスト/レスポンス契約における格納先変更

---

## 2. 標準 5 フェーズ（Expand → Dual-Write → Verify → Switch → Contract）

| Phase | 期間目安 | 実施内容 | 禁止事項 |
| --- | --- | --- | --- |
| **1. Expand** | Day 0 | 新カラム/新テーブルを追加する（NULL 許容またはデフォルト値付き）。旧構造はそのまま維持する。 | 旧カラムの `DROP` / `RENAME` / `NOT NULL` 強制 |
| **2. Dual-Write** | Day 0〜14 | 新旧双方へ同時に書き込む（クライアントだけでなく **Edge Functions / DB Trigger** で裏打ちする）。コード内に `DUAL-WRITE TRANSITION` マーカーを付与する。 | 旧カラムへの書き込み停止 |
| **3. Read Failsafe** | Day 0〜14 | 読み取り処理は **既存の旧データ構造を正（authoritative fallback）** として参照し、新構造が未設定でも欠損なく動作させる。 | 旧カラム未参照での片側読み取り切替 |
| **4. Backfill & Verify** | Day 1〜14 | 既存レコードのバックフィルを実施し、新旧データの一致率と旧クライアント残存率を確認する。 | 整合検証なしのクリーンアップ |
| **5. Contract** | Day 14+ (`sunset` 到達後) | 別 PR で旧書き込み・旧カラムを削除し、`DUAL-WRITE TRANSITION` マーカーを除去する。 | 14 日未満または未検証での早期削除 |

---

## 3. Supabase Edge Functions / DB Trigger と Flutter の併用設計

Flutter クライアント側だけで二重書き込みを行うと、旧バージョンのクライアントからの書き込みで新構造が欠損します。
そのため、サーバー側で次のいずれか（または併用）により背景の整合性を担保します。

1. **Supabase Edge Functions（例: `app-hub` / `core-hub`）での二重書き込み**:
   - リクエスト受信時に旧フィールド・新フィールドの双方を正規化し、1 トランザクション／1 `insert`/`update` で新旧両キーへ書き込む。
   - 読み取りレスポンスでは、旧データ構造を正として優先・フォールバック解決する。
2. **PostgreSQL Trigger (`BEFORE INSERT OR UPDATE`) による補完**:
   - クライアントが Supabase PostgREST へ直接書き込むテーブルでは、DB トリガーで `NEW.new_col := COALESCE(NEW.new_col, NEW.old_col)` および逆方向の同期を行い、旧クライアント由来の行も常に最新化する。
   - トリガー導入時も `supabase/migrations/` へ追加し、14 日後の Contract PR で安全に `DROP TRIGGER` する。

---

## 4. `DUAL-WRITE TRANSITION` マーカー規約

二重書き込み・読み取りフェールセーフを実装したすべての箇所（Dart / TypeScript / SQL / Python）には、
クリーンアップ漏れを防ぐため **削除用マーカーコメント** を必ず記載します。

### 必須フォーマット

```text
DUAL-WRITE TRANSITION: issue=#<Issue番号> sunset=YYYY-MM-DD read-failsafe=<旧構造の正本>
```

記述例（Dart / TypeScript / SQL）:

```dart
// DUAL-WRITE TRANSITION: issue=#2774 sunset=2026-12-10 read-failsafe=legacy_amount_yen
```

```sql
-- DUAL-WRITE TRANSITION: issue=#2774 sunset=2026-12-10 read-failsafe=metadata.legacy_key
```

### メタデータ規則

- `issue=#<番号>`: 移行を管理する GitHub Issue 番号（追跡用）。
- `sunset=YYYY-MM-DD`: 二重書き込み期間の終了予定日（原則として導入日の **14 日後**）。
- `read-failsafe=<識別子>`: 移行中に正として参照する旧カラム名・旧 JSON キー等の識別子。

---

## 5. 自動監査コマンド（オフライン検証）

`scripts/check_dual_write_markers.py` により、リポジトリ内のマーカー書式不備（必須属性欠落・不正日付）と
`sunset` 期限超過を検知できます。

```powershell
python -B scripts/check_dual_write_markers.py
python -B scripts/check_dual_write_markers.py --strict-expired
python -B -m unittest scripts/test_dual_write_markers.py -v
```

- 書式エラー（`sunset` / `issue` / `read-failsafe` 欠落や不正日付）は常に終了コード `1` で失敗します。
- `--strict-expired` を付与すると、`sunset < today` の期限切れマーカーが残存している場合に終了コード `1` を返します。

---

## 6. 改訂履歴

| 日付 | 内容 |
| --- | --- |
| 2026-11-26 | 初版作成（Issue #2774）。14 日間デュアルライト標準・Read Failsafe 原則・`DUAL-WRITE TRANSITION` マーカー規約・Edge Function / DB Trigger 併用設計を定義。 |
