---
title: "Flutter Web + AI Integration in 2026: Patterns That Work and Traps to Avoid"
tags: flutter,ai,programming,webdev
published: false
---

# Flutter Web + AI Integration in 2026: Patterns That Work and Traps to Avoid

## The Reality of AI-Powered Flutter Web Apps

Demand for AI-integrated Flutter Web apps is growing. But the path from "I want to add AI" to "it's live and working" has more friction than tutorials suggest.

Jibun Kaisha runs Flutter Web + Supabase Edge Functions + Claude/Gemini/OpenAI in production. Here's what I've learned.

---

## Architecture Decision: Never Call AI APIs Directly

Calling AI APIs directly from Flutter Web is a hard no:

```dart
// ❌ Never do this
final response = await http.post(
  Uri.parse('https://api.anthropic.com/v1/messages'),
  headers: {'x-api-key': 'sk-ant-XXXXX'}, // exposed in browser DevTools
  body: jsonEncode({...}),
);
```

Flutter Web compiles to JavaScript. Your API key is visible in network requests.

**The right pattern**: route through Supabase Edge Functions:

```dart
// ✅ Correct
final response = await supabase.functions.invoke(
  'ai-assistant',
  body: {'message': userMessage, 'context': sessionContext},
);
```

API keys stay server-side. Row Level Security handles auth.

---

## Implementation Patterns

### 1. Basic AI Call (Async)

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

### 2. Streaming Display

For long responses — requires SSE from the Edge Function:

```dart
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
```

### 3. Caching with Riverpod

Avoid redundant API calls:

```dart
@riverpod
Future<String> aiAnalysis(AiAnalysisRef ref, String key) async {
  ref.keepAlive(); // cache for widget lifetime
  final service = ref.watch(aiServiceProvider);
  return service.analyze(key);
}
```

### 4. Client-Side Circuit Breaker

When Edge Functions return 503, stop retrying for 5 minutes:

```dart
class AiCircuitBreaker {
  DateTime? _openedAt;
  static const _timeout = Duration(minutes: 5);

  bool get isOpen =>
      _openedAt != null && DateTime.now().difference(_openedAt!) < _timeout;

  void trip() => _openedAt = DateTime.now();
  void reset() => _openedAt = null;
}
```

---

## Common Traps

### Trap 1: CORS Errors

**Symptom**: API calls fail in browser but work in curl.

**Cause**: Missing `corsHeaders` in the Edge Function.

```typescript
// Required in every Deno EF
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

if (req.method === "OPTIONS") {
  return new Response("ok", { headers: corsHeaders });
}
```

### Trap 2: `Supabase.instance.client` vs Global `supabase`

```dart
// ❌ Requires import — causes 'unused import' CI error if removed carelessly
final client = Supabase.instance.client;

// ✅ If main.dart defines a top-level `supabase` variable, use it directly
// No additional import needed
final supabase = Supabase.instance.client; // defined once in main.dart
```

### Trap 3: Async Initialization in Flutter Web

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // required before async work
  await Supabase.initialize(
    url: 'https://xxx.supabase.co',
    anonKey: 'eyJ...',
  );
  runApp(const MyApp());
}
```

### Trap 4: AI Response JSON Parsing

Models often wrap JSON in markdown code blocks even when you ask for raw JSON:

```dart
String extractJson(String raw) {
  final match = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(raw);
  return match?.group(1) ?? raw.trim();
}

final jsonStr = extractJson(aiResponse);
final parsed = jsonDecode(jsonStr);
```

### Trap 5: Blocking UI During AI Calls

AI takes 2–5 seconds. Show progress:

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
        Text('AI is thinking...', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
```

---

## Performance Optimization

### Isolate-Ready Service Layer

Flutter Web doesn't support `compute()`, but structuring your service layer this way makes future native app migration easier:

```dart
abstract class AiProvider {
  Future<String> complete(String prompt);
}

class SupabaseAiProvider implements AiProvider {
  @override
  Future<String> complete(String prompt) async { /* EF call */ }
}
```

### Prevent Unnecessary Rebuilds

Scope your `ConsumerWidget` to only the AI-dependent parts:

```dart
// ❌ Entire page rebuilds on every AI update
class BigPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiResult = ref.watch(aiResultProvider);
    return Scaffold(body: Column(children: [
      Header(),       // doesn't need AI
      AiResult(...),
      Footer(),       // doesn't need AI
    ]));
  }
}

// ✅ Only the AI section rebuilds
class AiResultSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiResult = ref.watch(aiResultProvider);
    return AiResult(result: aiResult);
  }
}
```

---

## Current Integration Status at Jibun Kaisha

| Feature | AI Model | Status |
|---------|----------|--------|
| Daily Judgment | claude-sonnet-4-6 | ✅ Production |
| AI Assistant | claude-sonnet-4-6 | ✅ Production |
| CS Auto-Reply (GHA) | claude-sonnet-4-6 | ✅ Production |
| AI University Updates | gemini-1.5-flash | ✅ 2hr cron |
| Competitor Monitoring | gemini-1.5-flash | ✅ Production |
| Streaming Chat | (planned) | 🔲 Not yet |

---

## Summary

Key principles for Flutter Web + AI:

1. **Never expose API keys** — always proxy through Supabase Edge Functions
2. **Use streaming** to beat timeouts and improve perceived performance
3. **Circuit breaker + caching** to control cost and handle outages
4. **Fix the three common traps** (CORS, imports, async init) before they bite you in prod
5. **Scope your state management** to prevent unnecessary rebuilds

Flutter Web handles AI-powered apps well. Pair it with Supabase and you get auth, database, and serverless compute in one platform — so you can focus on the AI features, not infrastructure.

---

## Related Posts

- [Supabase Edge Functions + AI: Real Cost Breakdown](./2026-08-22-supabase-edge-functions-ai-cost-en.md)
- [litellm: One Gateway for All AI APIs](./2026-08-01-litellm-unified-ai-gateway-en.md)
- [Real Costs of a Multi-AI Workflow](./2026-07-25-multi-ai-workflow-real-costs-en.md)

---

*Jibun Kaisha — integrating the best of 21 competitors into one life management app*  
*Live: https://my-web-app-b67f4.web.app/*
