---
title: "競合190社を自動モニタリングする仕組み — ソロファウンダーが大企業に勝てる情報戦"
tags: saas,個人開発,startup,AI
published: true
---

# 競合190社を自動モニタリングする仕組み — ソロファウンダーが大企業に勝てる情報戦

## 「競合を常に把握する」は無理ゲーか

Notion・Evernote・Slack・Amazon・Google——大手 SaaS は数十人のプロダクトチームを抱え、競合調査専任のアナリストもいる。

ソロファウンダーが同じことをしようとすれば、1日の大半が競合チェックに消える。

自分株式会社は 190社の競合を **完全自動** でモニタリングしている。仕組みと設計思想を公開する。

---

## モニタリング対象の選定

### 直接競合 (21社) — 毎日チェック

自分株式会社が機能的に競合する 21社:

```
notion, evernote, moneyforward, slack, chatwork, x,
animaworks, claude-code, codex, netkeiba, openclaw,
claude-cowork, jobcan, amazon, google, microsoft,
discord, line, facebook, liven, github
```

この 21社は UI 変更・価格改定・新機能リリースを **毎日** 自動検知する。

### 間接競合・参考 (169社) — 週次チェック

市場に影響を与えるが直接競合ではない 169社。AI スタートアップ・投資先・業界動向。週次で主要な変化だけ抽出する。

---

## 技術アーキテクチャ

```
GHA cron (competitor-monitoring) → 毎日 09:00 JST
  ↓
admin-hub:competitor.check
  ├→ 各サービスの可用性チェック (HTTP HEAD)
  ├→ RSS/ニュースフィード取得
  ├→ Gemini 1.5 Flash で変化点を要約
  └→ Supabase competitor_features テーブルに保存

競合レポート生成 → docs/competitor-reports/YYYY-MM-DD.md
Slack 通知 (重要変化のみ)
```

### jp_strength スコアリング

競合 172社に対して「日本市場での脅威度」スコアを算出:

```sql
-- jp_strength スコア計算ロジック
UPDATE competitors SET jp_strength = 
  CASE 
    WHEN has_japanese_ui AND japan_user_base > 100000 THEN 'CRITICAL'
    WHEN has_japanese_ui OR japan_user_base > 10000 THEN 'HIGH'
    WHEN english_only AND enterprise_focus THEN 'MEDIUM'
    ELSE 'LOW'
  END;
```

CRITICAL (日本市場で最も脅威) → HIGH → MEDIUM → LOW の4段階。

**実例**:
- **Notion** → CRITICAL (日本語UI完備・大規模ユーザー)
- **Evernote** → HIGH (日本語対応・長年の実績)
- **Harvey AI** → LOW (英語のみ・法律特化)

---

## 何を監視するか: 10の機能軸

各競合を以下 10軸で評価:

| 軸 | 内容 | 例 |
|----|------|-----|
| AI Integration | AI 機能の深さ | Notion AI, Slack GPT |
| Pricing | 価格帯・プラン変更 | 値上げ・無料枠削減 |
| Mobile UX | スマホ対応品質 | PWA 対応・ネイティブアプリ |
| API/Integration | 外部連携の豊富さ | Zapier, Make 対応数 |
| Offline Support | オフライン機能 | ローカルストレージ |
| Privacy/Security | データ保護 | E2E 暗号化・SOC2 |
| Japan Localization | 日本語対応度 | UI・サポート・決済 |
| B2B Features | 法人向け機能 | 管理者コンソール・SSO |
| Data Export | データポータビリティ | エクスポート形式 |
| Performance | 速度・安定性 | Lighthouse スコア |

---

## 自動検知の実装

### 可用性チェック

```typescript
// admin-hub:competitor.check の核心
async function checkAvailability(url: string): Promise<CompetitorStatus> {
  const start = Date.now();
  try {
    const res = await fetch(url, {
      method: "HEAD",
      signal: AbortSignal.timeout(5000),
    });
    return {
      status: res.ok ? "up" : "degraded",
      latency_ms: Date.now() - start,
      http_status: res.status,
    };
  } catch {
    return { status: "down", latency_ms: -1, http_status: 0 };
  }
}
```

### 変化点検知

```typescript
// 前回スナップショットとの差分を AI で解析
const diff = await gemini.generateContent({
  contents: [{
    parts: [{
      text: `前回: ${previousSnapshot}\n今回: ${currentSnapshot}\n\n重要な変化を3点以内で日本語で要約して。変化がなければ「変化なし」と返して。`,
    }],
  }],
});

const change = diff.response.text().trim();
if (change !== "変化なし") {
  await saveChange(competitor, change);
  await notifySlack(competitor, change);
}
```

---

## 実際に検知した変化の例

2026年4月の検知実例:

| 競合 | 検知内容 | 重要度 |
|------|---------|-------|
| Notion | AI 機能を Pro プランに統合 (旧: 別料金) | CRITICAL |
| Slack | AI ハドル要約機能を全プランに展開 | HIGH |
| GitHub Copilot | Workspace 機能でマルチリポジトリ対応 | HIGH |
| Evernote | モバイルアプリのリデザイン | MEDIUM |
| Chatwork | 企業向けプランに AI 機能追加 | MEDIUM |

これらを人手でモニタリングすれば、週5〜10時間かかる情報を **毎日自動で** 取得している。

---

## レポート形式

```markdown
# 競合モニタリングレポート 2026-04-26

## CRITICAL 変化
- **Notion**: AI 機能価格改定 — Pro プランに統合 (影響: 自分株式会社の差別化要因が縮小)

## HIGH 変化  
- **Slack**: AI ハドル要約を全プラン展開 (影響: コミュニケーション機能の差は縮まる)

## 可用性サマリー
- 全 21社: 稼働中 (障害なし)
- 平均レスポンス: 342ms

## 今週のアクション提案
1. Notion の AI 価格変更に対する自分株式会社の価値提案を更新
2. AI ハドル代替機能の開発優先度を上げる
```

---

## ソロファウンダーが情報戦で勝つには

大企業は人海戦術で競合調査をする。ソロファウンダーが同じ土俵で戦う必要はない。

**設計で勝つ**: 自動化・AI・RSS の組み合わせで、1人でも 190社の動向を毎日把握できる。

重要なのは「情報量」ではなく「変化への反応速度」。競合が値上げした翌日に自分の価格ページを更新する、競合の新機能リリース翌週に差別化記事を出す——このスピードはチームの大小より設計で決まる。

---

## 関連記事

- [WBS × AI タスク管理設計](./2026-09-12-wbs-task-management-ai-assistant.md)
- [Supabase Edge Functions × AI コスト内訳](./2026-08-22-supabase-edge-functions-ai-cost.md)
- [AI大学 236社の学び方](./2026-09-19-ai-university-how-to-learn-providers.md)

---

*自分株式会社 — 21社競合のベストを1つに統合するライフマネジメントアプリ*  
*本番: https://my-web-app-b67f4.web.app/*
