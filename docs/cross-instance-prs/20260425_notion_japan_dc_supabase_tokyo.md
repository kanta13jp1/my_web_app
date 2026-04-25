# Cross-Instance PR: Notion 日本DC対抗 — Supabase Tokyo リージョン移行検討

**発行**: PS版#4 S42 / 2026-04-25 夕
**宛先**: Win版 (アーキテクチャ判断)
**優先度**: 🔴 HIGH
**期限**: 2026-05-15

---

## 背景

Notion が **2026年5月〜** 日本・韓国の Enterprise ユーザー向けに国内データセンターを提供開始。
(`supabase/migrations/` などへの影響なし — 設計判断のみ)

**発見**: Notion Blog "Notion is expanding data residency to Japan and South Korea"

---

## 問題

現在の自分株式会社インフラ:
- **Supabase**: US East (Virginia) リージョン
- **Firebase Hosting**: CDN (グローバル)

Notion が JP データセンターを展開すると:
- 日本企業が Notion Enterprise を選ぶ際の **個人情報保護法の障壁が消滅**
- 「データが海外に行くから Notion は使えない」という理由が Enterprise 顧客には通用しなくなる
- 現在の自分株式会社は **Supabase = 米国** → 日本エンタープライズ訴求で劣位

---

## 調査依頼 (Win版)

### Q1: Supabase Tokyo リージョン移行コスト

```bash
# 現状確認
# Supabase Dashboard > Project Settings > Infrastructure > Region
# 現在: us-east-1 or ap-northeast-1 ?
```

- Supabase は **ap-northeast-1 (Tokyo)** リージョンをサポート済み
- 新プロジェクト作成 vs 既存プロジェクト移行 どちらが現実的か？
- 移行時の downtime / データ移行コストを評価

### Q2: 現状ターゲット市場の再確認

- 自分株式会社の現ユーザーは個人 (B2C) が主 → データ residency は法的には必須ではない
- エンタープライズ (B2B) に将来進出予定があるかどうかで優先度が変わる

### Q3: 代替戦略

もし Supabase 移行コストが高い場合:
- **戦略A**: 個人 CEO 特化を徹底 → エンタープライズ市場への直接参入を見送り
- **戦略B**: 日本 DC 移行後に B2B SaaS として再ポジショニング
- **戦略C**: Supabase Self-Hosted (on Tokyo VM) で代替

---

## 推奨アクション

1. Supabase Dashboard で現在のリージョンを確認 (5分)
2. ap-northeast-1 移行の公式 migration guide を確認
3. 現フェーズでの優先度判断 → `docs/GROWTH_STRATEGY_ROADMAP.md` に記録

---

## 関連情報

- Notion Blog: "Notion is expanding data residency to Japan and South Korea" (starting May 2026)
- Supabase Docs: "Moving between projects" / "Region" settings
- 競合モニタリング: `docs/competitor-reports/2026-04-25.md` S42 セクション

---

*PS版#4 S42 発行 / Win版対応後に DONE でマーク*
