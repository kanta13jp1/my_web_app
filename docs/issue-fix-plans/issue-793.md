# Issue Fix Plan #793

- Issue: [[追加要望] Claude Apps/MCPからmy_web_appを直接操作できる連携基盤](https://github.com/kanta13jp1/my_web_app/issues/793)
- Labels: enhancement, 追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25240588332

## Goal

Claude Apps / MCP クライアントから `my_web_app` の代表的な業務データを参照し、確認付きで追加要望を作成できる最小プロトタイプを提供する。

## Implemented Slice

- `tools-hub` に MCP 互換の `tools/list` / `tools/call` facade を追加
- `mcp.tools.list` で公開ツールカタログを取得
- `mcp.wbs.list` / `wbs.tasks.list` で WBS タスクを期限順に取得
- `mcp.user_tasks.list` / `user_tasks.list` でユーザー担当タスクと最新報告を取得
- `mcp.feature_request.create` / `feature_request.create` で WBS-backed 追加要望を作成
- 書き込み系は `confirm=true` と `confirmation_phrase=create_feature_request` を必須化
- `/.well-known/oauth-protected-resource` と DCR-style `/register` を tools-hub に接続

## Acceptance Mapping

- MCP クライアントから代表的データを取得: `mcp.tools.list`, `mcp.wbs.list`, `mcp.user_tasks.list`
- 3操作の設計またはプロトタイプ化: WBS一覧、追加要望作成、ユーザータスク確認を実装
- 更新系の確認ガードレール: 追加要望作成に confirmation phrase を必須化

## Minimal E2E Gate

- Implementation-detail independent: MCP公開契約と tools-hub の観測可能な入出力を検証し、内部helperの形には依存しない
- Minimal 3 cases: tool catalog listing, read-only WBS/user task calls, denied write without confirmation
- E2E mechanism: public Playwright smoke remains the browser health gate; this PR adds Deno contract tests for the non-browser MCP facade
- E2E-Exception: browser UIを直接変更しないEdge Function facadeのため、MCP I/O契約をDeno testsで保証する

## Validation

- [x] `deno fmt supabase/functions/_shared/mcp_client_registration.ts supabase/functions/_shared/mcp_my_web_app_tools.ts supabase/functions/_shared/mcp_client_registration_test.ts supabase/functions/_shared/mcp_my_web_app_tools_test.ts supabase/functions/tools-hub/index.ts`
- [x] `deno lint --config supabase/functions/deno.json supabase/functions/_shared/mcp_client_registration.ts supabase/functions/_shared/mcp_my_web_app_tools.ts supabase/functions/_shared/mcp_client_registration_test.ts supabase/functions/_shared/mcp_my_web_app_tools_test.ts supabase/functions/tools-hub/index.ts`
- [x] `deno test --allow-all --config supabase/functions/deno.json supabase/functions/_shared/mcp_client_registration_test.ts supabase/functions/_shared/mcp_my_web_app_tools_test.ts`
- [x] `deno check --config supabase/functions/deno.json supabase/functions/tools-hub/index.ts`

## Remaining Risk

External Claude Apps / WorkOS token issuance still needs a deployed smoke test with real client credentials. This PR provides the deployable tools-hub facade and guardrails needed for that test.
