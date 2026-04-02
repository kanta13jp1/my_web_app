# Flutter WebでCRM営業パイプラインと競馬予想AIを同時実装した話 — Salesforce・netkeiba競合へ挑む

tags: FlutterWeb, Supabase, CRM, 競馬予想, EdgeFunction, buildinpublic

---

## はじめに

自分株式会社は「Notion・MoneyForward・Salesforce・netkeiba など 21 社の機能を1つに無料で提供する」という無謀なビジョンで開発を続けています。

今日は **CRM 営業パイプライン** と **競馬予想・分析** の2機能を同時実装したセッションを振り返ります。

---

## 実装した機能

### 1. CRM 営業パイプライン (`/crm-pipeline`)

**競合: Salesforce・Chatwork**

カンバン形式のパイプラインビューに加え、AIリードスコアリングを実装しました。

```
lead → qualified → proposal → negotiation → closed_won/lost
```

Edge Function 側でのスコアリングロジック:

```typescript
let score = 50;
if (email) score += 10;
if (company) score += 15;
if (phone) score += 10;
if (source === 'referral') score += 15;
```

Flutter 側は3タブ構成:
- **パイプライン**: ステージ別カンバンビュー (横スクロール)
- **リード**: リスト表示・スコアバッジ
- **統計**: 勝率・売上内訳・LinearProgressIndicator

### 2. 競馬予想・分析 (`/horse-racing`)

**競合: netkeiba (~1700万ユーザー)**

AI予想スコアリング式:

```
score = recent_form × 3 + jockey_win_rate × 2 + trainer_win_rate + track_affinity
```

Flutter 側は3タブ構成:
- **レース**: 登録一覧・グレード別カラーChip (G1=赤/G2=オレンジ)
- **予想**: 的中/未結果/失敗バッジ付き履歴
- **成績**: 的中率・回収率・損益サマリー

---

## 技術的なポイント

### DropdownButtonFormField の `value` → `initialValue` 移行

Flutter 3.33.0+ から `DropdownButtonFormField.value` が deprecated になりました。

```dart
// NG (deprecated)
DropdownButtonFormField<String>(value: _selected, ...)

// OK
DropdownButtonFormField<String>(initialValue: _selected, ...)
```

`flutter analyze` を実行すると `deprecated_member_use` エラーが検出されます。

### `use_build_context_synchronously` の修正パターン

`async` 関数内で `await` の後に `context.read<>()` を呼ぶと静的解析エラーになります。

```dart
// NG
Future<void> _doSomething() async {
  await someAsyncCall();
  final service = context.read<NotificationService>(); // ← エラー
}

// OK: context.read を await より前に移動する
Future<void> _doSomething() async {
  final service = context.read<NotificationService>(); // ← 先に取得
  await someAsyncCall();
}
```

---

## 現在の実装状況

- **Supabase Edge Functions**: 230+ 本体制
- **Flutter ページ数**: 125+ ページ
- **競合カバー率**: 21社を対象に機能実装中
- **flutter analyze**: 常時 0 エラー維持

---

## まとめ

CRM と競馬予想という一見無関係な2機能を同日実装できたのは、Edge Function First パターン (バックエンドに処理を集約し Flutter は表示に専念) のおかげです。

サービス URL: https://my-web-app-b67f4.web.app/

#FlutterWeb #Supabase #buildinpublic #CRM #競馬
