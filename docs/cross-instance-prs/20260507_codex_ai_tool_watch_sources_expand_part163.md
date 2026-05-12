# Cross-Instance PR: `ai_tool_watch.py` SOURCES 拡張 (Cursor / Gemini Code Assist / Devin) hand-off

> **作成**: Win版#132 part 163 / 2026-05-07
> **From**: Win Claude (= triage)
> **To**: Win Codex (= 実装)
> **優先度**: high (= Issue #1632 P1 / 期限 2026-05-21 / 残 14 日)
> **関連**: Issue [#1632](https://github.com/kanta13jp1/my_web_app/issues/1632)

---

## 概要

Issue #1632 の受け入れ条件「`ai_tool_watch.py` と `notebooklm_intake_gate.py` の公式ソース監視対象に Cursor/Gemini Code Assist を追加」のうち、**`ai_tool_watch.py` 側が未着手**であることが Win Claude triage で確定。

### 現状 (= 2026-05-07 part 163 確認)

| Component | Cursor | Gemini Code Assist | Devin | Status |
|-----------|--------|--------------------|-------|--------|
| `scripts/notebooklm_intake_gate.py` | ✅ (line 201) | ✅ (line 203) | ✅ (line 404) | DONE |
| `scripts/ai_tool_watch.py` SOURCES | ❌ | ❌ | ❌ | **PENDING** |

`ai_tool_watch.py` の SOURCES (line 37-74) は 6 entries = Claude Code 3 + Codex 3 のみ。Cursor + Gemini Code Assist + Devin の changelog URL は未登録。

### 2026-05-02 Codex #7 コメント

> Added watched official sources:
> - Cursor changelog: `https://cursor.com/changelog`
> - Gemini Code Assist release notes: `https://developers.google.com/gemini-code-assist/resources/release-notes`
> - Devin release notes: ...

→ **クレームと実装にギャップ**。`notebooklm_intake_gate.py` のみ更新済 / `ai_tool_watch.py` は未更新。

---

## Codex 依頼内容 (= 実装スコープ)

### `scripts/ai_tool_watch.py` の SOURCES 拡張

`SOURCES` list (line 37-74) に以下 3 entries を追加:

```python
Source(
    "cursor-changelog",
    "Cursor changelog",
    "https://cursor.com/changelog",
    "Cursor",
),
Source(
    "gemini-code-assist-release-notes",
    "Gemini Code Assist release notes",
    "https://developers.google.com/gemini-code-assist/resources/release-notes",
    "Gemini Code Assist",
),
Source(
    "devin-release-notes",
    "Devin release notes",
    "https://docs.devin.ai/release-notes",
    "Devin",
),
```

### `scripts/ai_tool_watch.py` の `process_source` 拡張 (= 必要な場合)

line 255+ で source.slug 別に specific HTML scrape ロジックがある場合、新 3 source の content extract (= changelog 本文 / 投稿日 / バージョン) を追加。

generic な extract で動作するなら不要。

---

## 受け入れ条件 (= Definition of Done)

- [ ] `ai_tool_watch.py` SOURCES に 3 entries 追加 (= cursor / gemini-code-assist / devin)
- [ ] `python scripts/ai_tool_watch.py` を smoke run → 各 source の取得成功確認 (= HTTP 200 / non-empty content)
- [ ] `docs/ai-tool-changelog/2026-05.md` に 3 source の latest signal 反映 (= 既存 Claude Code / Codex と同 format)
- [ ] `dart format --set-exit-if-changed` 不要 (= Python のみ)
- [ ] minimal-e2e-gate workflow pass (= `automation` label 付与)
- [ ] PR description に Issue #1632 close note 追加

---

## 注意事項

- **HTTP timeout**: Google docs domain は応答遅い場合あり / `requests.get(timeout=30)` 推奨
- **Rate limit**: cursor.com は CDN 経由 / Gemini docs は Google infra (= 通常問題なし)
- **既存 6 sources** との `keyword_groups` 共有: 既存 KEYWORDS dict (line 77-127) でカバー済 (= IDE extension / model picker etc) / 新規 keyword 追加不要
- [EF-CAP-50] EF 変更なし (= scripts のみ)

---

## Phase 0 hand-off (= Win Claude territory) 完了 note

本 hand-off 文書は Win Claude triage role の成果物 (= [INSTANCE-ROLES] 遵守 / Codex 振分 5 質問 全 NO で Codex territory 確定)。
