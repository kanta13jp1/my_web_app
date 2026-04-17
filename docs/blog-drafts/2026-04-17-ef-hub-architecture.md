---
title: "Supabase Edge Function 50本制限を突破する Hub-and-Action アーキテクチャ"
tags: Flutter,Supabase,buildinpublic,個人開発,アーキテクチャ
published: true
---

# Supabase Edge Function 50本制限を突破する Hub-and-Action アーキテクチャ

## 問題: 50本のハードキャップ

Supabase の無料・Proプランには **Edge Function 50本** というハードキャップがある。21競合のメモ・タスク・家計・スケジュール・AI・競馬・不動産... を1アプリに統合しようとすると、あっという間に上限に達する。

[自分株式会社](https://my-web-app-b67f4.web.app/) はピーク時 **99本** の Edge Function をデプロイしていた。その後、制限が適用されて新規デプロイのたびに 402 エラーが出るようになった。解決策は機能削除ではなく、構造の見直しだった。

---

## Hub パターンとは

1つの EF が複数の独立したアクションを処理できる。50本の EF を作る代わりに、50以上のルートを持つ1本のハブ EF を作る:

```typescript
// tools-hub/index.ts
const { action, ...rest } = await req.json();

switch (action) {
  case 'horseracing.today':       return getHorseRacingToday(supabase);
  case 'horseracing.predict_all': return predictAllRaces(supabase, rest);
  case 'realestate.search':       return searchProperties(supabase, rest);
  case 'guitar.analyze':          return analyzeTab(supabase, rest);
  // ... さらに20以上のアクション
}
```

コールドスタートは1回、CORS設定は1箇所、デプロイも1ステップ。新機能追加のたびに EF スロットを消費しない。

---

## Hub 一覧

最終的な構成: **16本** で全機能を維持:

| Hub EF | ドメイン | アクション数 |
|--------|--------|---------|
| `core-hub` | ユーザー管理・プロフィール・設定 | 約8 |
| `growth-hub` | アナリティクス・CVR・紹介 | 約6 |
| `ai-hub` | Gemini/Claude/GPTルーティング | 約10 |
| `tools-hub` | 競馬・ギター・不動産 | 約12 |
| `lifestyle-hub` | 健康・家計・カレンダー | 約8 |
| `schedule-hub` | Cron・リマインダー | 約5 |
| スタンドアロン×5 | `ai-assistant`・`get-home-dashboard` 等 | 1アクション |

99本 → 16本。全機能は維持。

---

## 移行手順: スタンドアロン EF → Hub アクション

### Step 1: アクションハンドラを追加

```typescript
// tools-hub/index.ts に追記
case 'guitar.analyze':
  return analyzeGuitarTab(supabase, body);
```

旧 EF のハンドラロジックをここに移植する。

### Step 2: Flutter 呼び出し側を更新

```dart
// Before: スタンドアロン EF を呼ぶ
final response = await _supabase.functions.invoke('guitar-recording-studio');

// After: hub に action パラメータで呼ぶ
final response = await _supabase.functions.invoke(
  'tools-hub',
  body: {'action': 'guitar.analyze', ...params},
);
```

### Step 3: CORS はハブで1回だけ設定

```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

if (req.method === 'OPTIONS') {
  return new Response(null, { headers: corsHeaders, status: 200 });
}
```

全アクションのレスポンスにこのヘッダーを含める。アクション個別の CORS 設定は不要。

### Step 4: deploy-prod.yml から旧 EF を削除

```yaml
# deploy-prod.yml から削除
functions:
  - guitar-recording-studio  # ← この行を削除
  - tools-hub                # ← hub はすでに登録済み
```

旧 EF のコードは `supabase/functions/` に残るがデプロイされない。整理する場合はフォルダごと削除してよい。

---

## NO_AUTH ゾーンパターン

一部のアクションは GitHub Actions の cron ジョブから呼ばれる — ユーザーJWTが存在しない。バイパスリストを使えば、cron と通常ユーザーを共存できる:

```typescript
const NO_AUTH_ACTIONS = [
  'horseracing.today',       // 公開レースデータ取得
  'horseracing.predictions', // 公開予想 GET
];

if (!NO_AUTH_ACTIONS.includes(action)) {
  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) return new Response('Unauthorized', { status: 401 });
}
```

`NO_AUTH_ACTIONS` のアクションは JWT 検証をスキップするが、Supabase の APIゲートウェイでサービスキーは必要。セキュリティと自動化のバランスとして適切。

---

## Dart: 集約呼び出しラッパー

20ファイルに `'tools-hub'` 文字列を散在させないために、薄いラッパーを作る:

```dart
class ToolsHub {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> params = const {},
  }) async {
    final response = await _supabase.functions.invoke(
      'tools-hub',
      body: {'action': action, ...params},
    );
    if (response.status != 200) throw Exception('Hub error: ${response.status}');
    return response.data as Map<String, dynamic>;
  }
}

// 使用例:
final data = await ToolsHub.call('horseracing.today');
final result = await ToolsHub.call('realestate.search', params: {'city': 'Tokyo'});
```

ハブ EF 名が変わっても1箇所の変更で済む。

---

## Hub パターンが解決しないこと

**実行時間**: Hub アクションは Deno の 30秒タイムアウトを共有する。大量AI呼び出しや大ファイル処理は専用 EF スロットか非同期キューパターンが必要。

**エラー分離**: 1つのアクションのインポートバグがハブ全体をクラッシュさせる可能性がある。ハンドラは別ファイルに分けてインポートする:

```typescript
// tools-hub/handlers/horseracing.ts
export async function getHorseRacingToday(supabase: SupabaseClient) { ... }

// tools-hub/index.ts
import { getHorseRacingToday } from './handlers/horseracing.ts';
```

---

## まとめ

| 問題 | 解決策 |
|------|----|
| EF 50本ハードキャップ | Hub-and-action ルーティング (1 EF、多数アクション) |
| GitHub Actions cron (JWT なし) | `NO_AUTH_ACTIONS` バイパスリスト |
| 20ファイルに散在する EF 呼び出し | `ToolsHub.call(action, params)` ラッパー |
| 長時間実行アクションのタイムアウト | スタンドアロン EF スロットを確保 |

99本 → 16本。機能: そのまま。

自分株式会社: [https://my-web-app-b67f4.web.app/](https://my-web-app-b67f4.web.app/)

#buildinpublic #FlutterWeb #Supabase #個人開発 #アーキテクチャ
