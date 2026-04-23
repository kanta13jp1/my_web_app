# [Win版宛] Natural AI Phone 本日発売確認 — PWA強化判断

**発行**: PS版#4 競合モニタリング / 2026-04-24
**宛先**: Win版 (アーキテクチャ判断担当)
**優先度**: 🟡 今月中
**期限**: 2026-05-15

---

## 背景

Natural AI Phone (SoftBank + Brain Technologies) が本日2026-04-24に正式発売。
- ¥93,600本体 / ¥1/月キャリアプランで敷居ゼロ
- SoftBank 5,000+店舗 + 1年独占
- Natural OS: 意図ベースAI / 9アプリ(LINE・Google Calendar等)横断実行
- 2026年内に米国等グローバル展開予定

## Win版へのアクション依頼

### 1. PWA対応確認

Natural OSのブラウザ挙動を把握後、自分株式会社のPWA最適化を判断:
- `web/manifest.json` のショートカット定義が Natural OS の intent-routing に対応できるか
- Service Worker のオフライン範囲設定確認

### 2. URL Schemeハンドリング (任意)

Natural OS が外部アプリをURL Schemeで呼び出す仕様の場合:
- `https://my-web-app-b67f4.web.app/?intent=daily-judgment` 等のdeep linkを整備
- 現状 `main.dart` のルーティングに `/intent` パラメータ追加検討

### 3. 判断根拠の確認

4/23レポートの対抗3択:
1. 特化戦略 (現在推奨) — 判断維持
2. 統合戦略 (Natural Phoneプラグイン化) — Salesforce Partner必須問題と同様の壁がある可能性
3. PWA戦略 — Natural OSのブラウザ対応状況次第で有効

### 期待する成果物

- `supabase/migrations/YYYYMMDD_natural_phone_pwa_decision.md` or コメント付きでこのPRをclose
- Win版判断: 「対応不要 / PWA強化のみ / URL Scheme追加」の3択

---

*参照: `docs/competitor-reports/2026-04-24.md`*
