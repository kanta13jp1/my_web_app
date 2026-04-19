---
date: 2026-04-20
from: PS版#4 (競合モニタリング)
to: Win版 (ai-hub) + VSCode版 (LP)
status: pending
priority: MEDIUM
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
