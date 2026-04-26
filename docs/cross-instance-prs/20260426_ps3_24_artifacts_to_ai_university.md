# PS#3 依頼: 24 NotebookLM Artifact を AI大学コンテンツ転用

**from**: Win版#132 part 29 (2026-04-26 evening)
**to**: PS版#3 (AI大学コンテンツ更新担当)
**priority**: medium
**deadline**: 1 week (next regular AI大学 sprint)

## 背景

Win版#132 part 25-28 で 3 本の NotebookLM 動画を D variant 化 + サイト埋め込み完了 (philosophy_page.dart #6-8)。各 notebook は **video 以外に 8 件の artifact** を持っており、AI大学コンテンツとして転用できる潜在資産が多数眠っている。

## 対象 3 notebook

| Notebook ID | Title | 動画 (完了) | 残 artifact 8 件 |
|-------------|-------|------------|------------------|
| `e89d2ca7-1dc9-41a1-8fe2-bad5103a757b` | Anthropic Evolution: Claude Apps, Opus 4.7, and Enterprise Expansion | youtu.be/Zclp_zK9cYM | Audio / Slide Deck / Infographic / Report / Flashcards / Quiz / Data Table / Mind Map |
| `579bd686-f17e-414a-894f-822f29b5c11e` | 8 Gemini Tips for Organizing Your Space and Life | youtu.be/di5SbHouAVY | Audio / Slide Deck / Infographic / Report / Flashcards / Quiz / Data Table / Mind Map |
| `284ad4be-ffca-449a-9725-cab9337f3325` | Nomic Platform: Domain-Specific AI for Project Delivery | youtu.be/shdsy9qqcNM | Audio / Slide Deck / Infographic / Report / Flashcards / Quiz / Data Table / Mind Map |

合計 **24 artifact** が未活用。

## 推奨アクション (優先度順)

### 1. **Quiz / Flashcards** (最優先 / 6 件)
`gemini_university_v2_page.dart` の `_quizzes` map に追加。各 notebook の Quiz artifact を JSON dump → Dart const data 化。すでに 224 social entry の registry が存在するため、quiz は対応 provider 単位で関連付け可能。

**手順**:
```bash
notebooklm use <notebook-id-prefix>
notebooklm artifact get <quiz-artifact-id>
# → Quiz Q&A を Dart `_Quiz(question:..., options:[...], correct: N)` に変換
```

### 2. **Mind Map / Infographic / Slide Deck** (中優先 / 9 件)
`docs/ai-university-content/` (新規ディレクトリ) に PNG/PDF を保存し、AI大学の各 provider ページで `Image.network` 表示。Mind Map は SVG export が available。

### 3. **Report (Markdown) / Data Table** (低優先 / 6 件)
`supabase/migrations/YYYYMMDDXXXXXX_seed_<provider>_ai_university_extended.sql` で `ai_university_content` に `category='report'` / `'data'` の追加レコードとして INSERT。

### 4. **Audio (Deep Dive)** (低優先 / 3 件)
YouTube unlisted upload (Win版#126 OAuth 流用)。philosophy_page.dart にオーディオ専用カードを追加するか、AI大学 provider page の audio セクションへ embed。

## ツール (確立済み)

- NotebookLM CLI: `notebooklm use / artifact list / download / generate`
- ElevenLabs Scribe: `~/.claude/skills/video-use/helpers/transcribe.py` (audio 系で使用)
- Win版確立 8-step pipeline: `videos/build_srt.py` + `make_cards.py` + ffmpeg + `scripts/upload_youtube.py`
- 新規 GHA workflow: `.github/workflows/notebooklm-video-pipeline.yml` (Win版#132 part 29 で skeleton 投入済)

## Philosophy Alignment 想定 (PS#3 が実装する場合)

- 5 (商品=価値): AI大学のコンテンツ深度が劇的に増加 ✅
- 8 (KPI 昨日の自分): 動画 8 本 → +24 artifact = +300% コンテンツ ✅
- 9 (IPO): AI大学のリッチコンテンツは IR 訴求材料 ✅

## 完了条件

- [ ] Quiz artifact 3 本 → `gemini_university_v2_page.dart` `_quizzes` 追加
- [ ] Flashcards artifact 3 本 → 既存 FSRS スケジューラに統合
- [ ] Mind Map / Slide Deck / Infographic 9 件 → 静的画像として `docs/ai-university-content/` 保存
- [ ] Report 3 件 → migration で `ai_university_content` extended seed
- [ ] Data Table 3 件 → 同上
- [ ] Audio 3 件 → YouTube unlisted upload (Win版#126 OAuth)

## 参考

- Win版#132 part 25-28 動画パイプライン詳細: `memory/project_20260426_win132_part{25,27,28}.md`
- AI大学 registry: `lib/models/ai_provider_registry.dart` (224 entry / 2026-04-26 時点)
- 8-step pipeline 確立記録: `memory/feedback_success_20260418_video_editing_workflow.md`
