# ドキュメント構成

このフォルダには、プロジェクトに関連するすべてのドキュメントが含まれています。

**最終更新**: 2026-04-17

**AI tool update gate (2026-05-07 #1706)**: Claude/Codex/Gemini/Copilot capability claims are verified through official sources and the Claude Code #1 + Codex #1 two-instance flow before adoption.

**Guarded subagent orchestration (2026-05-17 #2535)**: Claude Code #1 and Codex
#1 remain the only top-level local owners, but bounded child subagents are
allowed for isolated research, critique, memory review, and disjoint scoped
implementation. See
[`SUBAGENT_ORCHESTRATION_POLICY.md`](./SUBAGENT_ORCHESTRATION_POLICY.md).

---

## 📌 常時参照ドキュメント

| ファイル | 内容 |
| --- | --- |
| [GROWTH_STRATEGY_ROADMAP.md](./GROWTH_STRATEGY_ROADMAP.md) | 全戦略・セッション記録（毎回更新） |
| [DESIGN.md](./DESIGN.md) | デザイントークン（唯一の真実ソース・Orange+Indigoダークテーマ） |
| [MULTI_INSTANCE_COORDINATION.md](./MULTI_INSTANCE_COORDINATION.md) | 3インスタンス + マルチAI並行開発・競合防止ガイド |
| [DESIGN_TOOLING_SETUP.md](./DESIGN_TOOLING_SETUP.md) | Figma MCP / AIDesigner MCP セットアップ |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | コーディング規約・PR作成ガイド |
| [CICD_SETUP_GUIDE.md](./CICD_SETUP_GUIDE.md) | GitHub Actions / Secrets セットアップ手順 |
| [SUPABASE_LOG_DRAINS_REQUIREMENTS.md](./SUPABASE_LOG_DRAINS_REQUIREMENTS.md) | Supabase外部ログ転送の費用・セキュリティ・90日保持方針 |
| [CONTAINER_RESOURCE_CLEANUP.md](./CONTAINER_RESOURCE_CLEANUP.md) | Docker/Dev Containerの安全な定期清掃とSupabaseローカルDB保護 |
| [ROOTLESS_CONTAINER_SETUP.md](./ROOTLESS_CONTAINER_SETUP.md) | Rootless Podman/DockerによるFlutter Dev Container・Supabase検証手順 |

---

## 📁 フォルダ構成

### 自動生成（Claude Schedule / GitHub Actions が書き込み）

| フォルダ | 内容 |
| --- | --- |
| `daily-reports/` | 日次レポート（毎朝 09:00 JST 生成） |
| `cs-notes/` | CSチェックメモ（毎時生成） |
| `weekly-drafts/` | 週次SNSドラフト（毎週月曜生成） |
| `blog-drafts/` | ブログ下書き（毎日 08:00 JST 生成） |
| `competitor-reports/` | 競合モニタリングレポート（毎日 07:00 JST 生成） |
| `incident-reports/` | インシデントレポート（異常時のみ生成） |
| `security-audit/` | 脆弱性チェックレポート（毎週月曜生成） |

### 参考・設計資料

| フォルダ | 内容 |
| --- | --- |
| `design-systems/` | 参考デザインシステム（note / freee / SmartHR / Apple JP / WIRED.jp） |
| `user-docs/` | ユーザー向け機能説明（GAMIFICATION_README.md / GROWTH_FEATURES.md） |
| `technical/` | 技術ドキュメント（CI_CD_GUIDE / DEPLOYMENT_GUIDE 等） |
| `archive/` | 歴史的参照用アーカイブ（変更不要） |
| `roadmaps/` | 旧ロードマップ（2025年以前・読み取り専用） |
| `email-templates/` | メールテンプレート（読み取り専用） |

---

## 🔑 開発ルール（要約）

1. `flutter analyze` — 常に 0エラー（CI強制ゲート）
2. `deno lint` — 常に 0エラー（CI強制ゲート）
3. `docs/GROWTH_STRATEGY_ROADMAP.md` — 毎セッション末尾追記
4. ダミーデータ禁止（Supabase実データ必須）
5. Edge Function ファースト（複雑ロジックはバックエンドへ）

詳細は [CLAUDE.md](../CLAUDE.md) および [.github/COMPRESSED_PROMPT_V3.md](../.github/COMPRESSED_PROMPT_V3.md) を参照。
