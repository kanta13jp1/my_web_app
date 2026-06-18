# ADR: Edge-Function-first アーキテクチャ (EF-FIRST / EF-CAP-50)

Date: 2026-06-05
Status: Accepted

> 注: 運用ルール [EF-FIRST] / [EF-CAP-50] として既に毎ターン inject されている判断を、
> ADR 運用開始 (part 241) にあわせて根拠つきで backfill 記録したもの。

## Context

ビジネスロジックを「Flutter クライアント側」と「サーバー (Edge Function) 側」のどちらに置くかは
繰り返し発生する設計判断。クライアント側に複雑ロジックを置くと:

- シークレット / API キーがクライアントに露出する
- 信頼境界がクライアントに移り、検証不能な入力を信じることになる
- Web とモバイルでロジックが二重実装される

一方で Edge Function を無制限に増やすと、deploy-prod のビルド/デプロイ時間とデプロイ面が肥大し、
依存解決の失敗面 (= 先行 ADR [EF dependency resolution](2026-04-30-edge-function-dependency-resolution.md))
も増える。

## Decision

- **EF-FIRST**: 複雑ロジックは Supabase Edge Function に置く。Flutter widget は **表示 + 操作のみ**。
- **既存 hub への action 追加を最優先**: 新機能はまず既存 hub EF (core-hub / enterprise-hub 等) に
  action を 1 つ足す形で実装する。新規 EF 作成は最後の手段。
- **EF-CAP-50**: deploy-prod の EF 数 ≤ 50 を上限とする。超えそうなら hub 統合を先に行う。
- **認可は deny-by-default**: EF は認証・認可を明示的に通す ([`../AI_DEV_PRINCIPLES.md`](../AI_DEV_PRINCIPLES.md))。
- **依存は `npm:` specifier**: Supabase JS は `npm:@supabase/supabase-js@2` で import
  (= 先行 ADR の決定を継承)。

## Consequences

- シークレットとビジネスロジックがサーバー側に留まり、Web/モバイルで単一ロジックパスを共有できる。
- hub パターンにより EF 数が抑制され、デプロイ面と依存解決リスクが bounded に保たれる。
- 「ついで実装」でクライアントにロジックが漏れるのを構造的に防ぐ ([NO-SCOPE-CREEP] と整合)。
- トレードオフ: 単純な表示専用機能でも「まず hub action」を検討するため、ごく軽量な処理には
  わずかにオーバーヘッドが乗る。判断に迷う場合は EF-CAP-50 を超えないことを優先する。

## Links

- 運用ルール: [EF-FIRST] / [EF-CAP-50] (= `~/.claude/hooks/inject-rules.txt`)
- EF 一覧: [`../EDGE_FUNCTION_LIST.md`](../EDGE_FUNCTION_LIST.md)
- 先行 ADR: [Supabase Edge Function Dependency Resolution](2026-04-30-edge-function-dependency-resolution.md)
- 関連 ADR: [スタック選定](2026-06-05-flutter-web-supabase-firebase-stack.md)
