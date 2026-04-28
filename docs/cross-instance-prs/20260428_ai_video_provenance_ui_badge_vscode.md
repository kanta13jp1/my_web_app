# Cross-Instance PR: AI_VIDEO #5 Ethical Provenance — UI バッジ層実装

**作成**: Win版#132 part 65 / 2026-04-28
**FROM**: Win版 (動画パイプライン territory + AI_VIDEO 設計軸起案者)
**TO**: VSCode版 (`lib/pages/` Flutter UI 専任 territory)
**優先度**: MEDIUM (#5 Ethical Provenance の 3 層中 1 層 — 既に 2 層は Win版で実装済 / UI バッジで完結)
**期限**: 2026-05-12
**親軸**: docs/AI_VIDEO_PRINCIPLES.md 原則 #5 (Ethical Provenance & Transparency)

---

## 背景

Win版#132 part 64 で `docs/AI_VIDEO_PRINCIPLES.md` (7 番目設計軸 / D-ID 蒸留) を確立.
Win版#132 part 65 で原則 #5 (Ethical Provenance & Transparency) の **3 層中 2 層** を Win版 territory で実装:

| 層 | 状態 | 担当 |
| --- | --- | --- |
| 1. **可視ウォーターマーク** (drawtext "自分株式会社 AI 生成") | ✅ 実装済 | Win版 (scripts/video/add_provenance.py) |
| 2. **メタデータ埋め込み** (title/comment/creation_time/artist/source SHA-256) | ✅ 実装済 | Win版 (scripts/video/add_provenance.py + ffmpeg -metadata) |
| 3. **UI バッジ** (philosophy_page.dart embed 欄に「AI 生成」表示) | ⏳ **未実装** | **VSCode版 territory** |

= **WORKDIR-ISOLATION rule** で `lib/pages/*.dart` 編集は VSCode版 専任 → 本 cross-instance-pr.

## Win版 routing 判断 (5 質問 + WORKDIR-ISOLATION)

| Q | 答え | 補足 |
| --- | --- | --- |
| Q1 設計判断 / trade-off? | △ 軽 YES | バッジ表示位置 (動画タイトル横 / カード内 / 動画再生領域オーバーレイ) の選択 |
| Q2 cross-instance 調整? | NO | VSCode版 単方向 |
| Q3 軸 docs 更新? | △ | 完了時 docs/AI_VIDEO_PRINCIPLES.md 実装履歴に行追加 (#5 → 3.0/6) |
| Q4 docs に残す判断? | △ | バッジ表示位置選択の根拠 (UX 観点 + accessibility) は記録価値あり |
| Q5 NotebookLM 連携? | NO |

→ Q1+Q4 軽 YES (= 設計判断あり) + WORKDIR-ISOLATION lib/pages = **VSCode版 territory 確定**.

## 期待する実装

### 必須

1. **`lib/pages/philosophy_page.dart`** の `_videos` リスト各エントリに「AI 生成」バッジを表示:
   - 表示位置案 A: 動画タイトル右隣に小バッジ (例: `[AI 生成] Cartesia AI 解説`)
   - 表示位置案 B: 動画カード右上に固定オーバーレイ (例: `Stack` + `Positioned` で右上 12,12 にバッジ)
   - 表示位置案 C: 動画下のメタ情報行に行追加 (例: `🤖 AI generated · 時間: 1:23`)

   **VSCode版が判断**.

2. **アクセシビリティ**: `Semantics(label: 'AI で生成された動画')` を追加.

3. **テキスト**: 「AI 生成」(日本語) + 視覚記号 (例: 🤖 emoji or `AutoAwesome` icon) で 2 重明示.

### 推奨 (任意)

- 他の動画 embed page (= `gemini_university_v2_page.dart` 等) にも同一バッジ.
- Theme への extraction (= `_AIBadge` widget 新規 → 全 page で再利用).

## 受け入れ基準

- [ ] `philosophy_page.dart` の動画 8 本全てに「AI 生成」バッジ表示
- [ ] Semantics label 付与 (a11y)
- [ ] design-skills agent でバッジ表示の UI レビュー pass
- [ ] flutter analyze 0 エラー
- [ ] git commit + push origin HEAD:main
- [ ] docs/AI_VIDEO_PRINCIPLES.md 実装履歴に行追加 (#5 完成 / baseline 2.0 → 3.0/6)
- [ ] 本 cross-instance-pr を `done/` 移動

## 既存の動画パイプライン (= 参考)

```
scripts/video/transcribe.py     # 1. transcribe
scripts/video/build_srt.py      # 2. build SRT
scripts/video/make_cards.py     # 3. intro/outro PNG
scripts/video/add_provenance.py # 4. watermark + metadata (Win版#132 part 65 新規)
.github/workflows/notebooklm-video-pipeline.yml  # GHA orchestration
```

→ Win版 が動画 mp4 のウォーターマーク + メタデータを埋め込む.
→ VSCode版 が Flutter UI 側でバッジを表示することで **3 層 transparency** 完成.

## OPS-28 charter §6 § 受領 lane 履歴 (本日 4 件目)

| part | from | to | 内容 |
| --- | --- | --- | --- |
| 58 | PS#5 → Win版 | VSCode版 | dart:js_interop conditional import |
| 62 | User → Win版 | VSCode版 | AIシェアモーダル Uncaught Error |
| 63 | User → Win版 | VSCode版 | /horse-racing Tooltip Overlay |
| **65 (本)** | **Win版** | **VSCode版** | **AI_VIDEO #5 UI バッジ層** |

= Win版 が **設計軸起案 → Win版 territory 実装 → VSCode版 territory 委譲** の **co-implementation** 第 1 例.
これまで cross-instance-pr は「territory 越権 / on-call routing」が主だったが、本 PR は **意図的な水平分業** (= COLLAB_AI Pattern #5 Tinker / 共同実装).

---

*Win版#132 part 65 / 2026-04-28 起票 / NotebookLM da2a95d1 (D-ID) ソース AI_VIDEO #5 Ethical Provenance UI バッジ層 / 2 of 3 層 = Win版実装済 / 残り 1 層 = VSCode版 territory*
