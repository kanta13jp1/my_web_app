# [VSCode版宛] Notion Agent Skills — LP「credit増加ループ」訴求追加 [Done]

**発行**: PS版#4 競合モニタリング / 2026-04-24
**宛先**: VSCode版 (UI/デザイン担当)
**優先度**: 🔴 5/4課金前に実施 (期限 2026-05-03)
**関連**: `20260421_notion_ai_lp_update.md` (既存PR) の追補

---

## 背景

Notion AIが2026-04-14にAgent Skills機能をリリース:
- 頻繁なワークフローを「スキル」として保存 → コマンド実行化
- Calendar/Mail/Slack統合がUI内でネイティブ化
- n8n MCP連携で既存オートメーション呼び出し可能

**新たな脅威構造**:
Skills機能により「使い勝手向上 → Agent使用頻度上昇 → credit消費加速 → 月次リセットで損した感 → 強制利用プレッシャー」のループが形成。

5/4課金開始後、このループに気づいたユーザーが離脱マーケットになる可能性大。

---

## VSCode版へのアクション依頼

### LP訴求文案 (追加提案)

`lib/pages/landing_page.dart` の Notion比較行 or 差別化セクションに追加:

```
Notionのカスタムエージェント
→ 便利になるほどcreditを消費
→ 月次リセットで使い切れなければ損
→ 5/4から$10/1000 credit課金 (1回 $0.11-$0.33)

自分株式会社
→ 機能を使い込むほどデータが蓄積
→ 永続保存・月次リセットなし
→ 完全無料・コミット枠ゼロ
```

### SNS弾候補 (PS#2への転送も可)

- 「Notion Agentがスキルで便利になるほど、creditが飛ぶ。自分株式会社は使うほどデータが増える。」
- 「Notion 5/4課金: スキル保存→実行→credit消費→月次消滅→また課金。自分株式会社: 使い込むだけ。$0。」

### 期待する成果物

LP差別化軸の「Notion」行に上記ロジックを追加 (1-2行で可)。
大規模変更は不要。5/3までに反映でSEO弾として機能。

---

*参照: `docs/competitor-reports/2026-04-24.md`*
*参照: `docs/competitor-reports/SCOREBOARD_2026-04-20.md` #S17 Notion課金詳細*

## ✅ 完了 (VSCode版 S14 2026-04-29)
- commit: 788e520fa
- FAQ 2件追加 + _buildNotionVsSection() 5行対比表
