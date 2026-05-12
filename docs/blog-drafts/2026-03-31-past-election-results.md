---
title: "Flutter Web × Gemini AIで過去の選挙結果を自動取得・可視化する実装解説"
tags: Flutter,Supabase,個人開発,buildinpublic,GeminiAPI
published: true
---

# ブログ下書き 2026-03-31 — 2026-03-31-past-election-results

## タイトル案

1. Flutter Web × Gemini AIで過去の選挙結果を自動取得・可視化する実装解説
2. Gemini APIのJSONスキーマ拡張でAI選挙アナリスト機能を強化した話
3. 選挙データをAIで構造化取得 — `pastElectionResults` フィールド追加の全実装

## 投稿先候補

- [ ] Zenn
- [ ] Qiita
- [ ] note
- [ ] はてなブログ
- [ ] X Article

## 本文下書き

### はじめに

自分株式会社は「700人必達」を掲げる国民民主党の選挙インテリジェンス機能を持つFlutter Webアプリです。Gemini 2.5 Flash APIを使って地方議員情報・選挙スケジュール・KPI管理を自動取得しているのですが、今回新たに **「過去の選挙結果」** データも取得・表示できるよう機能拡張しました。

### 実装方法

#### 1. Deno Edge Function のJSONスキーマ拡張 (`docs/index.ts`)

Gemini APIへのプロンプトにある `required` JSONスキーマに `pastElectionResults` フィールドを追加しました。

```typescript
"pastElectionResults": {
  "type": "array",
  "description": "過去の主要な地方選挙の結果（2023年統一地方選など）",
  "items": {
    "type": "object",
    "properties": {
      "id": { "type": "number" },
      "electionName": { "type": "string" },
      "date": { "type": "string", "description": "投票日 (YYYY-MM-DD)" },
      "location": { "type": "string" },
      "dppCandidates": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "name": { "type": "string" },
            "status": { "type": "string", "description": "当選, 落選" },
            "votes": { "type": "number" }
          }
        }
      }
    }
  }
}
```

Gemini APIは `responseMimeType: "application/json"` を使うことで、このスキーマに従ったJSONを構造化出力として返してくれます。

#### 2. Flutter モデルクラスの追加 (`lib/models/local_election_reality.dart`)

```dart
class PastElectionCandidate {
  final String name;
  final String status;
  final int votes;

  bool get isWin => status.contains('当選');
  // ...
}

class PastElectionResult {
  final String electionName;
  final String date;
  final String location;
  final List<PastElectionCandidate> dppCandidates;

  int get winCount => dppCandidates.where((c) => c.isWin).length;
  // ...
}
```

既存の `LocalElectionRealitySnapshot` に `pastElectionResults` フィールドを追加し、デフォルト値 `const <PastElectionResult>[]` とすることでスキーマの後方互換性を維持しています。

#### 3. UI表示 (`lib/pages/election_victory_page.dart`)

当選/落選をChipウィジェットで色分け表示します。

```dart
Chip(
  label: Text(
    '${c.name} ${c.status}${c.votes > 0 ? " (${c.votes}票)" : ""}',
  ),
  backgroundColor: isWin
      ? Colors.green.withValues(alpha: 0.12)
      : Colors.red.withValues(alpha: 0.10),
)
```

また「未擁立・単騎をCSVコピー」ボタンも追加しました。今後の戦略策定に選挙スケジュールをCSVエクスポートして活用できるようになります。

### 詰まったポイント

- Gemini APIがまれにMarkdownのコードブロック（` ```json ` ）で囲んだJSONを返すことがある → レスポンスの前処理でコードブロックを除去する正規表現ロジックを追加
- `LocalElectionRealitySnapshot.empty()` コンストラクタにも新フィールドを追加し忘れると flutter analyze エラーが出る → const コンストラクタの初期化リストは明示的に管理する

### まとめ

Gemini APIのJSONスキーマ駆動の構造化出力と、DartモデルクラスのfromJson/toJsonパターンを組み合わせることで、AI取得データのフィールド追加をスムーズに拡張できました。flutter analyze 0件を維持しながら実装できるのはFlutter + Supabase構成の強みです。

---
URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #GeminiAPI #buildinpublic
