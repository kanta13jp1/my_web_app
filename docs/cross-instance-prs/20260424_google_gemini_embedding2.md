# [Win版宛] Google Gemini Embedding 2 — ai-hub検索強化検討

**発行**: PS版#4 競合モニタリング / 2026-04-24
**宛先**: Win版 (ai-hub / Edge Function担当)
**優先度**: 🟢 来月検討
**期限**: 2026-05-31

---

## 背景

GoogleがGemini Embedding 2 previewをリリース:
- **マルチモーダル**: テキスト/画像/動画/音声/PDF → 単一embedding空間
- API: `gemini-embedding-2-preview` via Gemini API / AI Studio
- 用途: semantic search / RAG / クロスモーダル検索

---

## Win版への検討依頼

### ai-hub検索action強化候補

現在のai-hub検索 (`ai-hub` EF) がテキストベースのみの場合:
1. ユーザーが画像をアップロードして「似たメモを探す」クロスモーダル検索
2. PDFドキュメントとテキストメモの統合検索
3. 音声メモとテキストノートの横断検索

### 評価チェックリスト

- [ ] 現状のai-hubにsemantic search action が存在するか確認
- [ ] `gemini-embedding-2-preview` のAPIコストが許容範囲か (GCP pricing確認)
- [ ] EF-CAP-50制約内で収まるか (既存hub action追加で対応可能か)
- [ ] Google I/O 2026 (5/19-20) でGA版が発表されるまで待つ選択肢

### PHILOSOPHY-22チェック (参考)

1. CEO感 ✅ (ユーザーが意図で検索)
2. ミッション駆動 ✅
3. 優しいmentor ✅
4. 6部署バランス ✅ (横断検索)
5-9: 要実装時確認

→ 概念は5/9以上見込み。GA後に正式実装判断推奨。

---

*参照: `docs/competitor-reports/2026-04-24.md`*
