# [cross-instance] MULTI_INSTANCE_COORDINATION.md — Opus 4.7 + WEB版モデル更新

**依頼元**: VSCode版 (2026-04-17)
**宛先**: PowerShell版 (docs/MULTI_INSTANCE_COORDINATION.md 担当)
**優先度**: 🟡 高
**状態**: ✅ 完了 (Windowsアプリ版#本セッション 2026-04-17)

---

## 変更内容

### 変更対象: `docs/MULTI_INSTANCE_COORDINATION.md`

**WEB版 インスタンス分担行を更新**:

現在:
```
| **WEB版 (復活)** | `docs/blog-drafts/` + `docs/research/` | Rule 21 NotebookLM Deep Research 専任 / ブログ英語翻訳・品質レビュー / AI大学コンテンツ調査 |
```

更新後:
```
| **WEB版** | `docs/blog-drafts/` + `docs/research/` | WebSearch/WebFetch 直接リサーチ専任 (notebooklm CLI 不可) / GitHub MCP PR・Issue管理 / ブログ英語翻訳・品質レビュー / **Opus 4.7** でアーキテクチャレビュー |
```

**理由**:
1. WEB版は `notebooklm` CLI が使用不可 (2026-04-16 確認済み)。「Rule 21 NotebookLM Deep Research 専任」という記載が誤り
2. Opus 4.7 リリースに伴い、WEB版のモデル推奨を Opus 4.7 に更新
3. 実際の WEB版役割 (WebSearch/WebFetch + GitHub MCP) を明記

### 変更対象: `docs/MULTI_INSTANCE_COORDINATION.md` フォールバックAI表

現在 (NotebookLM 行):
```
| NotebookLM | **常時使用必須 (Rule 21)** | 全種別 (3ファイル以上/URL分析/競合調査) |
```

補足コメント追加 (変更なし・注記として追記):
> **WEB版は notebooklm CLI 不可。代替: WebSearch/WebFetch を使用**

---

## 処理手順 (PowerShell版 が次セッションで実施)

```bash
# 1. 最新を pull
git pull --rebase origin main

# 2. MULTI_INSTANCE_COORDINATION.md の WEB版行を編集
# (上記変更内容を適用)

# 3. lint 確認
npx markdownlint-cli --dot docs/MULTI_INSTANCE_COORDINATION.md

# 4. commit + push
git add docs/MULTI_INSTANCE_COORDINATION.md
git commit -m "docs: MULTI_INSTANCE_COORDINATION WEB版役割更新 — notebooklm不可・Opus 4.7対応"
git push origin main
```

---

採否: **採用** → 実施後このファイルを削除
       **却下** → 却下理由を末尾に記載してこのファイルを残す
✅ 完了 (Windowsアプリ版#本セッション 2026-04-17)
