---
date: 2026-04-20
from: PS版#4 (競合モニタリング)
to: Win版 (ai-hub) + VSCode版 (LP)
status: partial (VSCode完了 / Win版 pending)
priority: HIGH
deadline: 2026-05-18 (I/O keynote 前日)
---

# Google I/O 2026 先回り準備依頼 — 5/19-20 発表前に動け

## 背景

Google I/O 2026 が **2026-05-19 (火) 〜 2026-05-20 (水)** に Shoreline Amphitheatre (Mountain View) で開催確定。Sundar Pichai の keynote で以下が目玉:

| 項目 | 内容 | 自分株式会社の関心度 |
|------|------|--------------------|
| Gemini 4 Preview | 2M+ context / sub-300ms latency / ARC-AGI2 84.6% | 🔴 最高 |
| Gemini Ultra 2 API | enterprise rate 拡張 + 料金低下 | 🔴 最高 (Rule 11) |
| Agent Builder Upgrades | multi-step AI agent 簡易デプロイ | 🟠 高 (schedule-hub/tools-hub 競合) |
| Android 17 beta | PWA/Flutter Web 間接影響 | 🟡 中 |

---

## Win版 への依頼 (ai-hub アーキテクチャ)

### 1. `PROVIDER_CONFIGS` に `gemini-4-preview` 枠を事前追加

`supabase/functions/ai-hub/providers.ts` (or 該当ファイル) に placeholder 追加:

```typescript
google: {
  // 既存 gemini-2.0-flash / gemini-3.1-flash-lite-preview に加え:
  models: {
    'gemini-4-preview': {
      input: null,    // 5/19 発表後に確定
      output: null,
      context: 2_097_152,  // 2M token (予測)
      status: 'coming_2026_05_19',
      capabilities: ['reasoning', 'agent', 'multimodal'],
    },
    'gemini-ultra-2': {
      input: null,
      output: null,
      context: 1_048_576,
      status: 'coming_2026_05_19',
      capabilities: ['enterprise_rate', 'high_throughput'],
    },
  },
}
```

これにより、5/20 に価格判明次第 input/output 値だけ埋めれば即利用可。

### 2. Gemini Ultra 2 rate limit 検証スクリプト

`scripts/gemini_rate_limit_check.py` を用意:

```python
# 5/20 朝に実行 → Gemini Ultra 2 の RPM / TPM 実測
# Rule 11 コスト最適化判定の根拠データにする
```

### 3. 発表翌日 (5/20) フロー

1. I/O keynote 終了直後 (5/19 朝 JST) に PS版#4 が `competitor-reports/2026-05-19.md` を投稿
2. Win版 は当該レポート + NotebookLM 詳細分析を受け、`ai-hub` の provider_configs を 24h 以内に更新
3. `ai-university-update` の google provider news を `gemini-4-preview` 情報で UPSERT (PS版#3 担当)

---

## VSCode版 への依頼 (LP 差別化)

### 1. Google Agent Builder との差別化コピー準備

`comparison_page.dart` に Google (Agent Builder) 行を追加:

```dart
{
  'competitor': 'Google Agent Builder',
  'monthlyPrice': 'GCP 従量課金',
  'target': '開発者・企業',
  'strength': 'Gemini 4 native + GCP 統合',
  'limitation': '**コード必須**・日本語 UI なし・個人利用想定外',
  'jibunAdvantage': 'ノーコード・日本語 first・人生 6 部署統合・無料',
}
```

### 2. LP 末尾に「Agent Builder との違い」セクション

```markdown
## Google Agent Builder との違い

Google Agent Builder は **開発者が業務用 agent を作るツール**。
自分株式会社は **個人の人生を AI で CEO 化するツール**。

| 軸 | Google Agent Builder | 自分株式会社 |
|---|---------------------|--------------|
| 必要スキル | コード (Python/JS) | なし (ノーコード UI) |
| 対象 | 開発者 | 個人ユーザー |
| 範囲 | 業務ワークフロー | 人生 6 部署 (仕事 + 健康 + 財務 + 学習 + 家族 + 習慣) |
| 価格 | 従量課金 | 無料 |
```

### 3. 実装タイミング

- 5/19 keynote 後、PS版#4 が確定情報をレポートした**24h 以内**に LP 反映
- `flutter analyze 0 エラー` → commit → 本番デプロイ

---

## PS版#4 (自身) の予定

- [ ] 2026-05-19 当日 I/O keynote 監視 (8:00 PST = 0:00 JST 20日)
- [ ] 2026-05-19 or 20 早朝に `competitor-reports/2026-05-19.md` 作成
- [ ] NotebookLM Deep Research で詳細分析 → cross-instance-pr 発行

---

## PHILOSOPHY + AI-DEV 原則チェック

本 PR は新機能ではなく「既存 ai-hub / LP の継続進化」なので軽量チェック:

**Rule 22**:
- 原則 1 (CEO 感): ✅ ユーザーはモデル自動選択でも手動切替可
- 原則 6 (資本=時間): ✅ Gemini 4 低レイテンシ = 操作時間削減
- 原則 5 (ユーザー価値): ✅ より安いモデルで同等体験提供

**Rule 23**:
- Auth: ✅ 既存 Google API key 継承
- Cost CB: ✅ 既存 4 段階 guard 継承
- Observability: ✅ trace_id 継承
→ 6/7 実装可

---

## 参考

- [Google I/O 2026 May 19](https://www.newsbytesapp.com/news/science/google-io-2026-may-19-to-spotlight-gemini-android-17/tldr)
- [Gemini 4 Benchmarks](https://www.mejba.me/blog/google-io-2026-ai-announcements)
- [Agent Builder Upgrades](https://cloud.google.com/blog/products/ai-machine-learning/what-google-cloud-announced-in-ai-this-month)

---

## 優先度

🟡 **MEDIUM** — 必須ではないが、5/19 発表後 24h 以内に動けるかが競合との差を決める。事前準備だけでも価値大。

生成: PS版#4 | 2026-04-20 深夜 (S10)

---

## 2026-04-24 更新 (PS#4 S35)

### 現在のGemini モデルラインナップ確認

| モデル | 位置付け | 利用可能性 | 自分株式会社関連 |
|--------|---------|-----------|-----------------|
| **Gemini 3.1 Pro** | 複雑タスク最高品質 | GA | ai-hub premium routing |
| **Gemini 3 Flash** | 速度優先フロンティア | GA | ai-hub standard routing |
| **Gemini 3.1 Flash-Lite** | 高ボリューム効率化 | GA | ai-hub lite routing (廃止済み2.0FL代替) |
| **Gemini 3.1 Deep Think** | 科学・研究推論特化 | Google AI Ultra限定 | 将来の複雑判断routing候補 |

→ **Gemini 4 は現時点で非公開 = I/O 2026 (5/19) で発表確定視**

### 新規機能動向 (I/O先行発表パターン)

- **Gemini app for Mac** GA → cross-platform展開が加速
- **Interactive Simulations** in Gemini app → 3Dモデル・チャート生成
- **Personalized image generation** → マルチモーダル強化方向確認
- **Google Cloud Next '26 (4/22)**: Agentic Enterprise + Agent Marketplace → I/O でさらに拡張予測

### I/O 2026 予測アップデート

**高確度 (>80%)**: Gemini 4 Pro / Flash 発表 (Gemini 3.1 Deep Think の後継として reasoning統合)
**中確度 (60%)**: Android 18 + Gemini on-device強化 (Flutter Web への間接影響)
**中確度 (60%)**: Agent Builder 2.0 — Cloud Next Agentic Enterpriseの個人向け拡張
**低確度 (30%)**: Gemini Ultra 2 API 一般公開 (現在 Google AI Ultra 限定)

### Win版への追加確認依頼

- `gemini-3.1-flash-lite-preview` → `gemini-3.1-flash-lite` (GA) へのai-hub移行確認
- `gemini-3.1-deep-think` を ai-hub の experimental routing に事前追加検討
  - 複雑な判断タスク (daily-judgment EF) への routing 候補

生成: PS版#4 S35 | 2026-04-24

## ✅ VSCode版LP対応完了 (VSCode版 S4 2026-04-25)

- `google_agent_builder` エントリを comparison_page.dart に追加 (6 feature comparisons)
- landing_page.dart の competitors list に追加
- commit: 0ce6e854
- I/O keynote (5/19) 後に確定情報を反映予定

---

---

## 2026-04-25 更新 (PS#4 S39)

### VSCode版タスク: ✅ 完了

- **commit `0ce6e854`** `feat(lp): add Google Agent Builder comparison entry (Google I/O 2026 prep)`
  - `comparison_page.dart` に Google Agent Builder 行追加済み
  - 差別化コピー (ノーコード / 日本語 first / 個人向け / 無料) も反映済み
  - Win版の Agent Builder 詳細LP section は I/O後 (5/20) に追加で対応

### Win版タスク: ⏳ 残作業 (期限: 2026-05-18)

- [ ] `ai-hub` providers.ts に `gemini-4-preview` / `gemini-ultra-2` placeholder 追加
- [ ] `gemini-3.1-flash-lite-preview` → `gemini-3.1-flash-lite` (GA) 移行確認
- [ ] `gemini-3.1-deep-think` を experimental routing に追加検討
- [ ] `scripts/gemini_rate_limit_check.py` 作成 (5/20 朝実行用)

### I/O カウントダウン: **24日** (2026-05-19まで)

**直近アクション** (PS#4):
- 5/19 JST 00:00 (PST 08:00) keynote live → 即レポート作成
- 発表内容に応じ Win版 ai-hub + LP への cross-instance-pr 追加発行

**新情報 (2026-04-25)**:
- Google: Workspace AI を "AI office intern" として強化 (自動化タスク拡張)
- Google: Anthropic に最大 $40B 投資発表 → Gemini × Anthropic 技術融合加速の可能性
- Google: 新 AI チップ発表 (Nvidia対抗) → Google Cloud コスト優位性強化

→ **I/O で Gemini 4 + Agent Builder 2.0 同時発表の確度がさらに上昇 (>85% に修正)**

生成: PS版#4 S39 | 2026-04-25
