---
title: "Flutter Web × AI 統合 2026 — 実装パターンと落とし穴"
tags: Flutter,AI,個人開発,webdev
published: true
---

# Flutter Web × AI 統合 2026 — 実装パターンと落とし穴

## Flutter Web に AI を組み込む現実

「Flutter Web でAIアプリを作りたい」という需要は増えている。しかし、実際に動かすまでに思わぬ壁がいくつかある。

自分株式会社は Flutter Web + Supabase Edge Functions + Claude/Gemini/OpenAI を組み合わせたアーキテクチャで運用中。2026年時点の実装知見をまとめる。

---

## アーキテクチャの選択

### 直接 API 呼び出しはやめる

Flutter Web から直接 AI API を呼ぶのは**NG**。

```dart
// ❌ やってはいけない
final response = await http.post(
  Uri.parse('https://api.anthropic.com/v1/messages'),
  headers: {'x-api-key': 'sk-ant-XXXXX'}, // APIキーが丸見え
  body: jsonEncode({...}),
);
```

Web ビルドは JavaScript に変換される。DevTools で通信を覗けば API キーが即バレる。

### Supabase Edge Function 経由が正解

```dart
// ✅ 正しいパターン
final response = await supabase.functions.invoke(
  'ai-assistant',
  body: {'message': userMessage, 'context': sessionContext},
);
```

Edge Function 内で API キーを管理し、RLS でユーザー認証も担保できる。

---

## 実装パターン集

### 1. 基本的なAI呼び出し (非同期)

```dart
class AiService {
  final SupabaseClient _supabase;

  AiService(this._supabase);

  Future<String> ask(String prompt) async {
    final response = await _supabase.functions.invoke(
      'ai-assistant',
      body: {'prompt': prompt},
    );

    if (response.status != 200) {
      throw Exception('AI error: ${response.data['error']}');
    }

    return response.data['result'] as String;
  }
}
```

### 2. ストリーミング表示

長い回答をリアルタイム表示する場合。Edge Function 側でSSEを返す前提。

```dart
class StreamingAiWidget extends StatefulWidget {
  final String prompt;
  const StreamingAiWidget({required this.prompt, super.key});

  @override
  State<StreamingAiWidget> createState() => _StreamingAiWidgetState();
}

class _StreamingAiWidgetState extends State<StreamingAiWidget> {
  final _buffer = StringBuffer();
  String _displayed = '';

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  Future<void> _startStream() async {
    final uri = Uri.parse(
      '${Supabase.instance.client.supabaseUrl}/functions/v1/ai-stream',
    );
    final request = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${Supabase.instance.client.supabaseKey}'
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'prompt': widget.prompt});

    final streamed = await request.send();
    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      _buffer.write(chunk);
      if (mounted) setState(() => _displayed = _buffer.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayed.isEmpty ? '考え中...' : _displayed);
  }
}
```

### 3. AI 結果のキャッシュ (Riverpod)

同じリクエストを何度も送らないよう、Riverpod でキャッシュ。

```dart
@riverpod
Future<String> aiAnalysis(AiAnalysisRef ref, String key) async {
  // 5分間キャッシュ
  ref.keepAlive();
  ref.onDispose(() {});

  final service = ref.watch(aiServiceProvider);
  return service.analyze(key);
}
```

### 4. Circuit Breaker (Flutter 側)

Edge Function が 503 を返したとき、一定時間リトライしない。

```dart
class AiCircuitBreaker {
  DateTime? _openedAt;
  static const _timeout = Duration(minutes: 5);

  bool get isOpen =>
      _openedAt != null && DateTime.now().difference(_openedAt!) < _timeout;

  void trip() => _openedAt = DateTime.now();
  void reset() => _openedAt = null;
}

// 使い方
if (circuitBreaker.isOpen) {
  return const Text('AI サービス一時停止中。しばらくお待ちください。');
}
```

---

## 落とし穴と対処法

### 落とし穴 1: CORS エラー

Flutter Web から Supabase Functions を呼ぶと CORS で詰まることがある。

**原因**: Edge Function の `corsHeaders` 設定漏れ。

```typescript
// Deno EF 側で必須
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// OPTIONS リクエストを必ず処理
if (req.method === "OPTIONS") {
  return new Response("ok", { headers: corsHeaders });
}
```

### 落とし穴 2: `Supabase.instance.client` vs `supabase` グローバル変数

Flutter で Supabase を使う際の典型的な罠。

```dart
// ❌ import なしで使うと SupabaseClient が見つからない
final client = Supabase.instance.client; // import 'package:supabase_flutter/supabase_flutter.dart'; が必要

// ✅ main.dart で初期化後、グローバル変数として使う (import 不要)
final supabase = Supabase.instance.client; // main.dart のトップレベルで定義済みなら OK
```

### 落とし穴 3: Web ビルドでの非同期初期化

Flutter Web は `main()` が同期的に実行されるが、Supabase の初期化は非同期。

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 必須
  await Supabase.initialize(
    url: 'https://xxx.supabase.co',
    anonKey: 'eyJ...',
  );
  runApp(const MyApp());
}
```

### 落とし穴 4: AI レスポンスの JSON パース

Claude や Gemini は「JSONを返して」と言っても、マークダウンコードブロックで囲んで返すことがある。

```dart
String extractJson(String raw) {
  // ```json ... ``` を剥がす
  final match = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(raw);
  return match?.group(1) ?? raw.trim();
}

// 使い方
final jsonStr = extractJson(aiResponse);
final parsed = jsonDecode(jsonStr);
```

### 落とし穴 5: ローディング中のUI

AIの応答に2〜5秒かかる。その間の UX が重要。

```dart
class AiLoadingIndicator extends StatelessWidget {
  const AiLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(
          'AI が考えています...',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
```

---

## パフォーマンス最適化

### AI 呼び出しを isolate に逃がす

Flutter Web では `compute()` が使えないが、将来の native アプリ移行を見越してサービス層を分離しておく。

```dart
// 将来的に isolate 対応できる構造にしておく
abstract class AiProvider {
  Future<String> complete(String prompt);
}

class SupabaseAiProvider implements AiProvider {
  @override
  Future<String> complete(String prompt) async {
    // Edge Function 経由
  }
}
```

### 不要な再描画を防ぐ

AI 結果が変わるたびに全体が再描画されないよう、`ConsumerWidget` を細かく分割。

```dart
// ❌ 大きなウィジェットで管理
class BigPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiResult = ref.watch(aiResultProvider); // 変更で全体再描画
    return Scaffold(body: Column(children: [
      Header(), // AI関係ない
      AiResult(result: aiResult),
      Footer(), // AI関係ない
    ]));
  }
}

// ✅ AI部分だけ ConsumerWidget に分離
class AiResultSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiResult = ref.watch(aiResultProvider);
    return AiResult(result: aiResult);
  }
}
```

---

## 自分株式会社での実装状況

| 機能 | AI モデル | 実装状況 |
|------|---------|---------|
| デイリー判定 | claude-sonnet-4-6 | ✅ 本番稼働 |
| AI アシスタント | claude-sonnet-4-6 | ✅ 本番稼働 |
| CS 自動返信 (GHA) | claude-sonnet-4-6 | ✅ 本番稼働 |
| AI 大学コンテンツ更新 | gemini-1.5-flash | ✅ 2時間毎 cron |
| 競合モニタリング | gemini-1.5-flash | ✅ 本番稼働 |
| ストリーミングチャット | (実装予定) | 🔲 未実装 |

---

## まとめ

Flutter Web × AI の要点:

1. **直接 API 呼び出しは禁止** → Supabase Edge Function 経由
2. **ストリーミング対応** でタイムアウトと UX 問題を解消
3. **Circuit Breaker + キャッシュ** でコストとエラーを抑制
4. **CORS / import / 初期化** の3大落とし穴を先に潰す
5. **Riverpod** で状態管理を整理するとスケールしやすい

Flutter Web は AI アプリのフロントとして十分実用的。バックエンドに Supabase を選べば、インフラ管理コストを最小化しながら AI 機能を段階的に追加できる。

---

## 関連記事

- [Supabase Edge Functions × AI コスト内訳](./2026-08-22-supabase-edge-functions-ai-cost.md)
- [litellm で複数AI APIを統合管理](./2026-08-01-litellm-unified-ai-gateway.md)
- [マルチAIワークフローの実際のコスト](./2026-07-25-multi-ai-workflow-real-costs.md)

---

*自分株式会社 — 21社競合のベストを1つに統合するライフマネジメントアプリ*  
*本番: https://my-web-app-b67f4.web.app/*
