# Codex Hand-off: Pleias Citation UAT Post-Merge (#1719 Phase 4)

PR gate note: this is a docs-only hand-off/playbook update; live UAT evidence is produced after merge by Codex #1.

**Issue**: #1719 (parent #1263 / impl PR #1709) | **期限**: 2026-05-21
**Win Claude 完了済 (part 181 / 2026-05-10)**:

- `docs/offline_local_rag_runtime.md` に **Pleias Citation Token Contract** 章 + **UAT Playbook** 章追加 (= 68 -> 217 行 / 既存 doc 章追加 pattern 第 6 例)
- token contract 5 項目固定 (= request payload / Format A native span / Format B bracket marker / 4-step ID resolution / UI rendering rules)
- UAT playbook A-E (= 5 segment) で acceptance criteria (1)(2)(5) を実行可能化

## 残作業 (Codex #1 = live UAT)

PR #1709 が main に merge された **直後** (= GitHub Actions の deploy-prod 完走後) に、
production URL https://my-web-app-b67f4.web.app/ で以下を実施:

### 必須実装 (= acceptance 1, 2, 5)

1. **Citation chip interactions** (= UAT Playbook §A)
   - Edge LLM Playground を開き、 hover tooltip + click dialog を 1 サイクル目視
   - 既存 `test/widgets/pleias_citation_text_test.dart` の fixture (`Common Corpus [source:1]`) をそのまま入力で OK
   - 結果: PASS / FAIL を #1263 にコメント

2. **Layout matrix** (= UAT Playbook §B)
   - 5 viewport (= 1440 / 1024 / 768 / 414 / 360) で chip rail + tooltip + dialog overflow を確認
   - Playwright MCP `browser_resize` で width 切替 -> `browser_take_screenshot` で 5 枚
   - `tmp/uat-1719/<width>.png` に保存 (= path だけ #1263 にコメント、画像は upload 不要)

3. **Edge-case fixtures** (= UAT Playbook §C-1〜7)
   - 7 fixture を順に入力 -> chip 表示 / dialog 内容を確認
   - 特に §C-5 (= 未解決 ID) で dialog に "No source metadata was returned." が出ること

4. **#1263 sign-off comment**
   - Browser + viewport matrix 実施結果
   - Real runtime token format observation (= まだ実 Pleias 接続前なら "extractive harness only" と記載)
   - `flutter analyze` / `flutter test` 出力 (= 既に PR #1709 で SUCCESS なので参照のみ)

### 任意 (= acceptance 3 = 実モデル token format 実測)

実 Pleias / llama.cpp / Ollama 接続が **既に**手元で動く環境なら:

- `temperature: 0` + `include_citations: true` の probe query で raw response capture
- token format が Format A / Format B / 新 envelope のどれかを確認
- 新 envelope の場合は `docs/offline_local_rag_runtime.md` §"Adding a new runtime token format" の手順で follow-up Issue 起票

実モデル未接続なら **skip OK** (= follow-up Issue として残す)。

## 完了条件

- [ ] #1263 に sign-off comment (= browser matrix + viewport + token format + flutter analyze 出力)
- [ ] #1719 close (= acceptance 5 件 全 PASS)
- [ ] 必要なら `docs/offline_local_rag_runtime.md` UAT Playbook §D に dated bullet 追記 (= 実 runtime 観測あれば)

## Codex 振分 5 質問 (docs/CODEX_WORKFLOW.md §6)

1. Code edit 30+ 行? **NO** (= comment + screenshot only)
2. test fixture 編集? **NO** (= 既存 fixture 流用)
3. 既存 PR 修正 commit? **NO** (= post-merge UAT)
4. CI workflow 編集? **NO**
5. EF schema 変更? **NO**

-> 0/5 YES = **Codex 案件**. ただし Win Claude (mobile UAT role) も同等に対応可。
PR #1709 merge SLA 短縮のため Codex 並走 OK。

## 関連 docs

- `docs/offline_local_rag_runtime.md` (= 全 contract + UAT playbook の正本)
- `lib/widgets/pleias_citation_text.dart` (= UI 実装)
- `lib/services/local_rag_runtime_service.dart` (= parser 実装)
- `test/widgets/pleias_citation_text_test.dart` (= fixture)
