# Codex Hand-off: LLM Quality Gate CI 統合

**Issue**: #1598 | **Codex #2 スコープ** | **期限**: 2026-05-19
**Win Claude 完了済**: `docs/LLM_QUALITY_GATE_SPEC.md` + `eval/fixtures/llm-quality-gate.yaml`

---

## 実装スコープ (Codex #2)

### 必須実装 (3 ファイル)

1. **`.github/workflows/llm-quality-gate.yml`**
   - trigger: PR で `supabase/functions/ai-hub/**` / `_shared/ai_character_preamble.ts` / `eval/fixtures/**` 変更時
   - `npx --yes promptfoo@latest eval --config eval/fixtures/llm-quality-gate.yaml --output tmp/llm-quality-results.json --no-cache`
   - env: `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` (repo secrets 既存確認要)
   - artifact upload: `tmp/llm-quality-results.json` (失敗時も保存)
   - `PROMPTFOO_DISABLE_TELEMETRY: 1`

2. **PR コメント投稿ステップ** (workflow 内)
   - `tmp/llm-quality-results.json` をパース → pass/fail サマリ + 失敗テスト名 + 入力 + 期待値 を PR コメントに投稿
   - 既存パターン: `.github/workflows/minimal-e2e-gate.yml` の PR コメントステップを参照

3. **`README.md` または `eval/README.md`** 1 行追記
   - ローカル実行コマンド記載

### 参照 docs

- `docs/LLM_QUALITY_GATE_SPEC.md` §6 (GHA workflow skeleton あり)
- `eval/fixtures/llm-quality-gate.yaml` (promptfoo 設定完成済)
- `docs/BLOG_DRAFT_QUALITY_GATE.md` (先行品質ゲートパターン)

### コスト上限

- `--max-concurrency 2` 追加推奨
- `OPENAI_API_KEY` 未設定時は `--filter-providers mock` で degraded 動作 (non-blocking)

### 既存 secrets 確認

```bash
gh secret list | grep -E "OPENAI|ANTHROPIC"
```

`OPENAI_API_KEY` / `ANTHROPIC_API_KEY` が存在すれば OK。
なければ `gh secret set OPENAI_API_KEY` で設定 (Codex #2 担当)。

---

## 受け入れ条件

- [ ] `npx promptfoo eval` がローカルで実行可能 (mock only)
- [ ] GHA workflow が PR trigger で起動
- [ ] 失敗テスト名が PR コメントに表示される
- [ ] `tmp/llm-quality-results.json` が artifact に保存される
- [ ] Issue #1598 に完了コメント投稿

---

## 参考: 既存 workflow パターン

```bash
ls .github/workflows/ | grep -E "gate|quality|check"
```

`minimal-e2e-gate.yml` / `dependency-audit.yml` のステップ構造を流用推奨。
