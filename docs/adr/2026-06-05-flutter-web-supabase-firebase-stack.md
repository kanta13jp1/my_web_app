# ADR: Flutter Web + Supabase + Firebase Hosting スタック選定

Date: 2026-06-05
Status: Accepted

> 注: これは 2026-06-05 に新規に下した判断ではなく、本プロジェクト発足時から運用されてきた
> 基盤判断を ADR 運用開始 (part 241) にあわせて backfill 記録したもの。

## Context

「自分株式会社」は少人数 (実質ソロ + AI fleet) で運用する個人プロダクトであり、専任の
インフラ / 運用チームを持たない。次の制約下でスタックを選ぶ必要があった:

- UI / バックエンドを通して言語・思考コストを最小化したい (= 文脈切替の削減)
- 認証・DB・サーバーロジック・ストレージをマネージドで揃え、ops 負荷をほぼ 0 にしたい
- ホスティングは低コスト (実質無料枠) + CDN + 独自ドメイン対応
- 将来モバイル (iOS/Android) へ展開する可能性がある (= GitHub Issue #1495)
- CI/CD は無料で回せること

## Decision

以下を標準スタックとする:

- **フロントエンド**: Flutter Web (Dart) による単一コードベースの SPA。
- **バックエンド**: Supabase = PostgreSQL + Edge Functions (Deno) + Auth + Storage。
  データアクセス境界は **RLS (Row Level Security)** を一次防御線とする。
- **ホスティング**: Firebase Hosting (静的配信 + CDN)。本番 = <https://my-web-app-b67f4.web.app/>。
- **CI/CD**: GitHub Actions (deploy-prod / dev / staging)。

## Consequences

- Dart 単一言語で Web を構築でき、同一コードベースでモバイル展開の余地が残る。
- サーバーロジックの置き場所は Edge Function に寄せる (= 別 ADR
  [Edge-Function-first](2026-06-05-edge-function-first-architecture.md) で具体化)。
- Supabase + Firebase の **2 ベンダー混在** を受け入れる (DB/認証/EF は Supabase、配信は Firebase)。
  各々の無料/低額枠の良いとこ取りだが、障害切り分けは 2 系統を見る必要がある。
- セキュリティの主境界が RLS / EF 認可になるため、新機能では deny-by-default を徹底する
  (= [`../AI_DEV_PRINCIPLES.md`](../AI_DEV_PRINCIPLES.md))。
- Dart 編集は `dart format` + `flutter analyze` 0 を push 前ゲートにする ([DART-FORMAT])。

## Links

- 原則 docs: [`../PHILOSOPHY.md`](../PHILOSOPHY.md) / [`../AI_DEV_PRINCIPLES.md`](../AI_DEV_PRINCIPLES.md)
- 関連 ADR: [Edge-Function-first](2026-06-05-edge-function-first-architecture.md)
- CLAUDE.md `Facts` セクション (= 技術スタックの正本)
