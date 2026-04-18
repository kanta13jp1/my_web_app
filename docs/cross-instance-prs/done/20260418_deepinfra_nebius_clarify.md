---
date: 2026-04-18
from: Windowsアプリ版#95
to: PowerShell版
status: pending
priority: medium
---

# deepinfra / nebius を AI大学 86社 に正式参入させるか? (backend-only に留めるか?)

## 経緯

Windows版#95 の AI大学 Step 0 確認時に以下を発見:

`lib/models/ai_provider_registry.dart` (89 entries) と `lib/pages/gemini_university_v2_page.dart` `_providerMeta` (84→86 entries) に差分あり。

**registry には在るが UI に無い 4プロバイダー**:

1. `deepinfra` — registry ✅ / ai-hub PROVIDER_CONFIGS ✅ / migration ❌ / UI ❌ / yml ❌
2. `nebius` — registry ✅ / ai-hub ✅ / migration ❌ / UI ❌ / yml ❌
3. `siliconflow` — Win#95 で UI 追加完了 → 86社入り
4. `novita_ai` — Win#95 で UI 追加完了 → 86社入り

`siliconflow` + `novita_ai` は migration もあったため Win#95 で UI/CLAUDE.md/COMPRESSED_PROMPT に追記して 86社に正式昇格。

しかし `deepinfra` と `nebius` は **registry + ai-hub PROVIDER_CONFIGS のみ** に存在し、migration / UI / CLAUDE.md provider list / yml いずれも未追加 → AI大学 86 に含まれていない。

## 想定経緯

PS版#116 の "ai-hub Phase8 33プロバイダー(deepinfra+liquid)" で **AI ルーティング backend に追加した際に registry にも入れたが、AI大学 UI には意図的に追加しなかった** 可能性が高い。

## 依頼内容

以下のいずれかを選択して反映してほしい:

### Option A: AI大学 86→88 に正式昇格

`deepinfra` + `nebius` を完全な AI大学 プロバイダーとして扱う:

1. `supabase/migrations/YYYYMMDDXXXXXX_seed_deepinfra_ai_university.sql` 新規作成 (overview/models/api 3レコード)
2. `supabase/migrations/YYYYMMDDXXXXXX_seed_nebius_ai_university.sql` 新規作成 (同)
3. `lib/pages/gemini_university_v2_page.dart` の `_providerMeta` / `_quizzes` / `_fallback` に追加
4. `CLAUDE.md` + `.github/COMPRESSED_PROMPT_V3.md` の provider list 末尾に追記
5. `lib/pages/ai_provider_status_page.dart` + `lib/models/ai_provider_registry.dart` + `supabase/functions/ai-hub/index.ts` の "86社" → "88社"
6. `.github/workflows/ai-university-update.yml` に `upsert_provider "deepinfra" ...` / `upsert_provider "nebius" ...` 行を追加

→ 1 コミットで完結 (Win#95 の siliconflow/novita_ai と同手順)

### Option B: backend-only に留める (registry コメントで明示)

ルーティング backend 専用と割り切る場合:

1. `lib/models/ai_provider_registry.dart` の `deepinfra` / `nebius` エントリに **コメント追加**:
   ```dart
   AiProviderEntry(
     id: 'deepinfra',
     // backend-only: AI ルーティング (ai-hub) でのみ使用。AI大学 UI には未公開
     ...
   ```
2. `_providerMeta` に追加しない (= AI大学 ページに表示されない)
3. registry コメントの "86社" は据え置き (= AI大学 公開数のみカウント)

## 推奨

**Option A** を推奨。理由:

- DeepInfra (Llama/Qwen/FLUX 等の安価 inference)
- Nebius (Yandex 系 GPU クラウド + Llama hosting)

両方とも **OpenAI 互換 + 公開 API + 話題性 8/9 以上** あり、AI大学 9/9 評価基準を満たす。AI大学 88社化のメリット大。

## 注意

- 1 コミットで完結するなら Win#96 で実施しても良いが、ai-hub PROVIDER_CONFIGS は既に PS版が編集中の可能性 → PS で完結する方が conflict 少ない
- Windows版#95 のコミットには本 cross-instance-pr のみ含まれる (コード変更なし)
