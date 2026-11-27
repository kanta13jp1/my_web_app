# 段階的アクセス制御（Geo-RBAC）とインフラ保護仕様 (#2811)

## 1. 方針（中立的・非遮断型の段階防御）

特定国・地域を政治的に一律遮断するのではなく、Geo-IP ヘッダ（`cf-ipcountry` / `x-country-code`）と短時間バーストカウンタを組み合わせた **中立的なトラフィックベース段階防御** を適用する。

## 2. 段階的アクセス制御ティア (`AccessControlTier`)

1. `normal`: 通常アクセス（摩擦なし、`Set` / `Map` による `O(1)` 判定）
2. `elevated_rate_limit`: 対象地域外または閾値超過時のレート制限強化（`retryAfterSeconds` 返却）
3. `step_up_challenge`: 高負荷バースト時の追加認証要求（`requiresStepUp = true`、CAPTCHA/再認証等）

## 3. パフォーマンス分離

- 主要サービス地域（既定 `["JP"]`）およびクライアントキーごとに独立したウィンドウバケットを保持するため、対象地域外からの過剰バーストが発生しても国内通常ユーザーの判定は `O(1)` で完結しレスポンスへ影響しない。

## 4. 実装ファイル

- `supabase/functions/_shared/adaptive_geo_rbac.ts`
- `supabase/functions/_shared/adaptive_geo_rbac_test.ts`
