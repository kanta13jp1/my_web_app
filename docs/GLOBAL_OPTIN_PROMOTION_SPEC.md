# 複数テナント評価に基づくグローバルデータのオプトイン昇格仕様

対象: Issue #2775。

## 1. 概要とデータ分離原則

単一テナントの利用傾向が他テナントの検索・推薦結果を汚染することを防ぐため、
評価データはテナント単位（`(tenant_id, item_id)`）で独立保存し、以下の条件をすべて満たした項目のみを
グローバルスコープへ昇格（オプトイン）します。

- **独立テナント数**: 既定 `3` テナント以上（環境変数 `OPTIN_MIN_QUALIFYING_TENANTS` / `GlobalOptInConfig.minQualifyingTenants` で調整可能）
- **評価閾値**: 各テナントの最新スコアが既定 `0.7` 以上（環境変数 `OPTIN_PROMOTION_THRESHOLD` / `GlobalOptInConfig.promotionThreshold` で調整可能）

## 2. 昇格・降格スイープ（`demotion_sweep`）

`runPromotionAndDemotionSweep`（Dart: `lib/services/global_optin_promotion_service.dart`、Edge 共通ヘルパー: `supabase/functions/_shared/global_optin_promotion.ts`）は定期バッチまたはトリガーから呼び出され、次を実行します。

1. 全評価を `(item_id, tenant_id)` の最新評価へ集約（同一テナントによる重複水増しを防止）。
2. `score >= promotionThreshold` を満たす独立テナント数が `minQualifyingTenants` 以上なら `promoted` へ昇格し、条件を満たすテナント群の平均スコアを `global_score` とする。
3. 既に `promoted` だった項目が再評価・削除等により要件を下回った場合、`demoted` へ降格し `global_score = 0.0` に戻す。

## 3. 検索・推薦ランキング式

`0.70 * localScore + 0.20 * globalScore + 0.10 * usageScore`（各項目・合算値とも `[0.0, 1.0]` にクランプ）。
未昇格項目（`isGlobalPromoted == false`）では `globalScore` を常に `0.0` とし、他テナントのローカル評価は一切参照しません。
