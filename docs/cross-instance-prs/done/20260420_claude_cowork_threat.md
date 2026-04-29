---
date: 2026-04-20
from: PS版#4 (競合モニタリング S13)
to: VSCode版 (LP/comparison) + Win版 (戦略判断)
status: done
completed_by: VSCode版 2026-04-24 (commit 8112a607)
priority: 🔴🔴 CRITICAL
deadline: 2026-05-01 (LP 反映・GW 前)
---

# Anthropic 公式 Claude Cowork GA — 直接戦略脅威 発生

## 背景 (PS版#4 S13 調査結果)

2026-04-09 に **Anthropic 自身が Claude Cowork を GA リリース** した。
これは「claude-cowork」という社内呼称では**なく**、Anthropic 公式のプロダクト
名 (Claude Cowork / 初期コードネーム "Claude for Enterprise Cowork")。

### 事実関係

| 項目 | 内容 |
|-----|-----|
| リリース日 | 2026-04-09 (GA) |
| 提供プラン | Pro ($20/月) / Max ($100/月) / Team / Enterprise |
| プラットフォーム | macOS + Windows ネイティブ app |
| 実行環境 | 分離 VM 内で自律 AI エージェントが動作 |
| 統合先 | Google Drive / Gmail / Sheets / DocuSign / FactSet / SAP Ariba |
| Microsoft 連携 | Microsoft Copilot Cowork も Claude 統合 (2026-04) |
| 追加発表 | Anthropic Labs Claude Design (Figma 代替・2026-04-17) |

### なぜ 🔴🔴 (最大脅威)

1. **技術スタック同一**: 自分株式会社は ai-hub で Claude を採用 → Anthropic が直接同じ基盤で参入
2. **ユーザーベース**: Claude Pro/Max 既存契約者が全員 Cowork 機能を入手 (ゼロマーケ CAC)
3. **統合先が知識労働者向け SaaS の主要 6 本**: 個人 CEO のうち「仕事 = 知識労働」セグメントを直撃
4. **技術コモディティ化を加速**: 自前で Claude + MCP を組んでも「本家に勝てない」認知が LP 読者に発生

---

## 残る差別化 — 6 軸 (従来 4 軸 → 2 軸追加)

S12 まで確立していた 4 軸 (個人 CEO / 6 部署 / 日本語 / 無料) に以下 2 軸を**追加**:

### 軸 5 — データ永続化 (Supabase 永続 vs VM 揮発)

- **Claude Cowork**: 分離 VM 内で実行 → セッション終了で状態消失
- **自分株式会社**: Supabase Postgres に「昨日の自分」「6 部署 BS」「KPI 履歴」永続保存
- **Philosophy 原則 8** (KPI = 昨日の自分) **はデータ永続が前提** — ここは Anthropic が構造上模倣できない領域

### 軸 6 — 人生統合 (6 部署) vs 仕事のみ (knowledge-work)

- **Claude Cowork**: 仕事 SaaS のみ統合 (Drive/Gmail/Sheets/DocuSign/FactSet/Ariba)
- **自分株式会社**: R&D / 財務 / マーケ営業 / 人事 / 本社 / 健康 の 6 部署
- **Philosophy 原則 4** (人事最優先 = 人生統合) はミッション駆動の本質

**転換シナリオ**:
> 「Claude Pro (月 $20) で Cowork 使っているけど、**仕事以外の家計・健康・学習**は別アプリで管理していてまとまらない」
→ 自分株式会社 (無料) に一元化

---

## LP への具体反映案 (VSCode版 タスク)

### 1. `landing_page.dart` ヒーローセクション

現行のコピーに**以下のバッジ/文言を追加**:

```
✨ Claude Cowork ユーザーへ
 仕事だけの AI エージェントを人生 6 部署に統合
 データは Supabase 永続 (VM 揮発セッションとの違い)
```

### 2. `comparison_page.dart` 比較行

Claude Cowork を新規 1 行として追加 (21 社 → 22 社):

| 比較項目 | Claude Cowork | 自分株式会社 |
|---------|---------------|--------------|
| 対象 | 仕事 (knowledge work) | 人生 6 部署 |
| 料金 | Pro $20/月 ~ Team $100/月 | **無料** |
| データ永続 | VM セッション限定 | Supabase 永続 |
| 言語 | 英語 first | **日本語 first** |
| 6 部署 KPI | なし | あり (CEO ダッシュボード) |
| AI | Claude (公式) | **Claude + Gemini + GPT 統合** (ai-hub 4-Tier) |

### 3. 戦略コピー (LP 上部の ticker 風バナー)

```
Anthropic 公式 Claude Cowork 登場。
知識労働 AI は commodity 化した。
自分株式会社は「人生の CEO」向けに、6 部署を統合する唯一のフレームワーク。
```

---

## Win版 への判断依頼

1. **ai-hub の Claude 採用維持** — はい (技術としては commodity ゆえ最良モデル使うべき・Anthropic 直接参入とは競合しない位置取り)
2. **Anthropic Labs Claude Design (Figma 代替) 利用検討** — 2026-04-17 発表済。既に `design@knowledge-work-plugins` v1.2.0 が CLAUDE.md Rule 16 に統合済。追加対応不要
3. **Claude Cowork Pro ユーザー向けマーケティング経路** — 自分株式会社が「Pro + 人生統合」として訴求するコピーを X (@kanta13jp1) で発信 (Win版 or 📱 スマホ版で 5/1 前に実施)

---

## 優先度

🔴🔴 **CRITICAL** — 5/1 までに LP 反映必須。理由:

- Claude Cowork 発表済みで認知が拡散中
- Pro ユーザー ($20/月契約者) が 2026-04-09 以降急増中 = まさに転換需要
- GW (5/3-5) 前に LP 更新していれば連休中に流入が期待できる
- Google I/O 2026 (5/19-20) より Claude Cowork の方が自分株の戦略に直接影響

---

## Philosophy 9 原則 照合 (LP 改修の妥当性)

1. CEO 感 ✅: データ永続で「昨日の自分」比較基盤を明示
2. ミッション駆動 ✅: 6 部署 = 人生ミッションの仕組み
3. 優しい mentor ✅: 監視ではなく比較 (Claude Cowork の自律 AI エージェント自動投稿とは違う)
4. 6 部署バランス ✅: まさに軸 6
5. 商品=ユーザー価値 ✅: 無料で価値提供
6. 資本=時間 ✅: 一元化で管理時間削減
7. 資産/負債 ✅: 永続化が負債化を防ぐ
8. KPI=昨日の自分 ✅: 永続化が前提
9. ウェルビーイング ✅: 仕事一辺倒にしない 6 部署

**9/9 達成 → LP 改修は即実装可**

---

## 参考

- [Anthropic Claude Cowork 発表 (2026-04-09)](https://www.anthropic.com/news/claude-cowork)
- [Claude Design (Anthropic Labs・2026-04-17)](https://www.anthropic.com/news/claude-design)
- [Microsoft Copilot Cowork + Claude 統合](https://www.microsoft.com/en-us/blog/copilot-cowork-claude/)

生成: PS版#4 S13 | 2026-04-20 深夜

---

## S14 追記 — Pricing 階層詳細 + 日付訂正 (2026-04-20 深夜)

### 日付訂正

| イベント | 日付 (訂正後) | S13 の誤記 |
|---------|---------------|-----------|
| 研究プレビュー | 2026-01-30 | — |
| **エンタープライズ GA** | **2026-02-24** | 04-09 と誤記 |
| Pro 組込み (月 $20 で利用可) | 2026-04-09 前後 | ✅ |
| 長文課金廃止 (Opus 4.7 / Sonnet 4.6) | 2026-03-13 | 未記録 |

### Pricing 階層 (LP 比較表に使用可)

| Plan | 月額 | Cowork | 注記 |
|------|------|--------|------|
| Free | 無料 | — | 日次制限 |
| **Pro** | **$20** | ✅ | Claude Code + 無制限 project + MCP + Google Workspace (Anthropic 公式で最安) |
| Max 5x | $100 | ✅ (5倍) | ~225 msg / 5h |
| Max 20x | $200 | ✅ (20倍) | 大量利用 |
| Team Standard | $25/seat (年 $20) | ✅ + 管理 | no-train policy |
| Team Premium | $125/seat (年 $100) | ✅ (5倍) | — |
| Enterprise | 要問合せ | ✅ | — |

### 統合先 (Pro に含まれる)

Excel (beta) / PowerPoint (beta) / Google Sheets+Drive+Gmail+Docs / Slack / DocuSign / FactSet / SAP Ariba / Claude Code / Remote MCP

### LP 追加訴求案 (Pro $20 既契約者向け)

```
Claude Pro $20/月 で Cowork 使ってるあなたへ。
仕事だけの AI エージェントを、人生 6 部署に統合しませんか?
自分株式会社 — 無料 / 日本語 first / Supabase 永続。
```

### 関連住み分け情報 (S14 追加発見)

- **MoneyForward AI Cowork** (2026-07 GA) = **法人バックオフィス専用** (経理・勤怠) → 個人家計は対象外 → 自分株式会社の個人 CEO 戦略は温存
- **Salesforce Agentforce 360** (TDX 2026・2026-04-15) = Claude/Gemini/Teams 全対応 → LP 比較表の Slack 行は「Claude/Gemini/Teams 全対応」追記必要
- **Anthropic 長文課金廃止 (3/13)** = 大規模リサーチ文書読み込みで価格優位減 → 自分株は「無料」+「日本語 first」+「人生統合」に軸足

生成更新: PS版#4 S14 | 2026-04-20 深夜
